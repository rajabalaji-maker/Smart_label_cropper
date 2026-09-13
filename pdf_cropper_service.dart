import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/order_item.dart';
import 'label_parser_service.dart';
import 'normalization_service.dart';
import 'report_generator_service.dart';

class ProcessedBatchResult {
  final Uint8List sortedCroppedPdfBytes;
  final String savedPdfPath;
  final List<OrderItem> parsedItems;
  final Uint8List? withoutXpressBeesBytes;
  final Uint8List? xpressBeesBytes;
  final Uint8List? summaryPdfBytes;
  final Uint8List? manifestPdfBytes;
  final Map<String, Uint8List> perSkuPdfs;

  ProcessedBatchResult({
    required this.sortedCroppedPdfBytes,
    required this.savedPdfPath,
    required this.parsedItems,
    this.withoutXpressBeesBytes,
    this.xpressBeesBytes,
    this.summaryPdfBytes,
    this.manifestPdfBytes,
    this.perSkuPdfs = const {},
  });
}

class PdfCropperService {
  static const String defaultPrimaryKeyword = "Original For Recipient";
  static const String defaultSecondaryKeyword = "Exchange";
  static const double defaultSecondaryPercent = 0.80;

  /// Process input PDF files completely on-device
  static Future<ProcessedBatchResult> processPdfs({
    required List<Uint8List> pdfFilesBytes,
    String primaryKeyword = defaultPrimaryKeyword,
    String secondaryKeyword = defaultSecondaryKeyword,
    double secondaryCropPercent = defaultSecondaryPercent,
    bool stampQtyBox = true,
    bool stampDate = true,
  }) async {
    final List<Map<String, dynamic>> processedPages = [];

    for (final bytes in pdfFilesBytes) {
      final inputDoc = PdfDocument(inputBytes: bytes);
      final textExtractor = PdfTextExtractor(inputDoc);

      for (int i = 0; i < inputDoc.pages.count; i++) {
        final page = inputDoc.pages[i];
        final pageSize = page.size;
        final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
        final lines = textExtractor.extractTextLines(startPageIndex: i, endPageIndex: i);

        // Find primary invoice boundary line
        double? cutY;
        double? prodDetailsBottom;
        final List<Map<String, dynamic>> bloomerHighlightBoxes = [];

        for (final line in lines) {
          final lt = line.text.toLowerCase();
          // Find invoice boundary keywords
          if (lt.contains("tax invoice") ||
              lt.contains("original for recipient") ||
              lt.contains("bill to ship to") ||
              lt.contains("bill to / ship to") ||
              lt.contains("description hsn") ||
              lt.contains(primaryKeyword.toLowerCase())) {
            cutY = cutY == null ? line.bounds.top : min(cutY, line.bounds.top);
          }

          if (lt.contains("product details")) {
            prodDetailsBottom = line.bounds.bottom + 65.0;
          }

          // Check for kids bloomer size ranges on page for highlighting (e.g. "9-10 Years", "2-3 Years")
          for (final entry in NormalizationService.kidsBloomerSizeMap.entries) {
            if (line.text.contains(entry.key)) {
              bloomerHighlightBoxes.add({
                'bounds': line.bounds,
                'tag': entry.value,
              });
            }
          }
        }

        double cropHeight;
        if (cutY != null) {
          // Cut 6-8 points above the invoice boundary
          final candidate = cutY - 6.0;
          cropHeight = prodDetailsBottom != null ? max(candidate, prodDetailsBottom) : candidate;
        } else if (prodDetailsBottom != null) {
          cropHeight = prodDetailsBottom;
        } else if (pageText.toLowerCase().contains(secondaryKeyword.toLowerCase())) {
          cropHeight = pageSize.height * secondaryCropPercent;
        } else {
          cropHeight = pageSize.height * 0.42; // default top ~353 pt on A4
        }

        // Clamp crop height to standard label dimensions (between 290 and 375 pt)
        if (cropHeight < 290.0) cropHeight = 290.0;
        if (cropHeight > 375.0) cropHeight = 375.0;

        // Parse order details from text
        final orderItem = LabelParserService.parsePageText(pageText, i);

        processedPages.add({
          'sourceDoc': inputDoc,
          'pageIndex': i,
          'cropHeight': cropHeight,
          'pageSize': pageSize,
          'orderItem': orderItem,
          'bloomerHighlights': bloomerHighlightBoxes,
        });
      }
    }

    if (processedPages.isEmpty) {
      throw Exception("No pages found in the selected PDF file(s).");
    }

    // Sorting matching desktop app.py:
    // Group 0: Single-order Qty == 1 (SKU rank -> Size rank -> Partner rank)
    // Group 1: Single-order Qty > 1 (bulk)
    // Group 2: Multi-order pages
    // Xpress Bees: weight = 1 (placed at the very end of the batch)
    processedPages.sort((a, b) {
      final OrderItem itemA = a['orderItem'];
      final OrderItem itemB = b['orderItem'];

      final int isXpressA = itemA.courierPartner.toUpperCase().contains("XPRESS") ? 1 : 0;
      final int isXpressB = itemB.courierPartner.toUpperCase().contains("XPRESS") ? 1 : 0;
      if (isXpressA != isXpressB) return isXpressA.compareTo(isXpressB);

      final int groupA = itemA.multiOrder ? 2 : (itemA.qty > 1 ? 1 : 0);
      final int groupB = itemB.multiOrder ? 2 : (itemB.qty > 1 ? 1 : 0);
      if (groupA != groupB) return groupA.compareTo(groupB);

      final skuCmp = NormalizationService.skuSortRank(itemA.sku).compareTo(
        NormalizationService.skuSortRank(itemB.sku),
      );
      if (skuCmp != 0) return skuCmp;

      final sizeCmp = NormalizationService.sizeSortRank(itemA.size).compareTo(
        NormalizationService.sizeSortRank(itemB.size),
      );
      if (sizeCmp != 0) return sizeCmp;

      return NormalizationService.partnerSortRank(itemA.courierPartner).compareTo(
        NormalizationService.partnerSortRank(itemB.courierPartner),
      );
    });

    // Documents for various outputs:
    // 1. All sorted labels
    final fullDoc = PdfDocument();
    // 2. Without XpressBees
    final withoutXpressDoc = PdfDocument();
    // 3. XpressBees only
    final xpressDoc = PdfDocument();
    // 4. Per SKU documents
    final Map<String, PdfDocument> perSkuDocs = {};

    int xpressCount = 0;
    int nonXpressCount = 0;

    for (final p in processedPages) {
      final PdfDocument srcDoc = p['sourceDoc'];
      final int pageIdx = p['pageIndex'];
      final double cropH = p['cropHeight'];
      final Size srcSize = p['pageSize'];
      final OrderItem item = p['orderItem'];
      final List<Map<String, dynamic>> highlights = p['bloomerHighlights'];
      final bool isXpress = item.courierPartner.toUpperCase().contains("XPRESS");

      if (isXpress) {
        xpressCount++;
      } else {
        nonXpressCount++;
      }

      // Extract template from source page
      final template = srcDoc.pages[pageIdx].createTemplate();

      // Render to Full Document
      _drawCroppedPage(
        doc: fullDoc,
        template: template,
        srcSize: srcSize,
        cropHeight: cropH,
        item: item,
        stampQtyBox: stampQtyBox,
        stampDate: stampDate,
        highlights: highlights,
      );

      // Render to Without / With Xpress Bees
      if (isXpress) {
        _drawCroppedPage(
          doc: xpressDoc,
          template: template,
          srcSize: srcSize,
          cropHeight: cropH,
          item: item,
          stampQtyBox: stampQtyBox,
          stampDate: stampDate,
          highlights: highlights,
        );
      } else {
        _drawCroppedPage(
          doc: withoutXpressDoc,
          template: template,
          srcSize: srcSize,
          cropHeight: cropH,
          item: item,
          stampQtyBox: stampQtyBox,
          stampDate: stampDate,
          highlights: highlights,
        );
      }

      // Render to Per-SKU documents
      perSkuDocs.putIfAbsent(item.sku, () => PdfDocument());
      _drawCroppedPage(
        doc: perSkuDocs[item.sku]!,
        template: template,
        srcSize: srcSize,
        cropHeight: cropH,
        item: item,
        stampQtyBox: stampQtyBox,
        stampDate: stampDate,
        highlights: highlights,
      );
    }

    // Save outputs
    final List<int> fullOutputBytes = fullDoc.saveSync();
    fullDoc.dispose();

    List<int>? withoutXpressBytes;
    if (xpressCount > 0 && nonXpressCount > 0) {
      withoutXpressBytes = withoutXpressDoc.saveSync();
    }
    withoutXpressDoc.dispose();

    List<int>? xpressBytes;
    if (xpressCount > 0) {
      xpressBytes = xpressDoc.saveSync();
    }
    xpressDoc.dispose();

    // Save per-SKU PDFs
    final Map<String, Uint8List> perSkuPdfs = {};
    for (final entry in perSkuDocs.entries) {
      final bytes = entry.value.saveSync();
      entry.value.dispose();
      perSkuPdfs[entry.key] = Uint8List.fromList(bytes);
    }

    // Generate Order Summary & Manifest (safely wrapped so reports never abort label cropping)
    final allItems = processedPages.map((p) => p['orderItem'] as OrderItem).toList();
    Uint8List? summaryBytes;
    try {
      summaryBytes = await ReportGeneratorService.generateOrderSummaryPdf(items: allItems);
    } catch (_) {}

    Uint8List? manifestBytes;
    try {
      manifestBytes = await ReportGeneratorService.generateManifestPdf(items: allItems);
    } catch (_) {}

    // Persist full sorted PDF to device storage
    final outputDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${outputDir.path}/meesho_cropped_$timestamp.pdf');
    await file.writeAsBytes(fullOutputBytes);

    return ProcessedBatchResult(
      sortedCroppedPdfBytes: Uint8List.fromList(fullOutputBytes),
      savedPdfPath: file.path,
      parsedItems: allItems,
      withoutXpressBeesBytes: withoutXpressBytes != null ? Uint8List.fromList(withoutXpressBytes) : null,
      xpressBeesBytes: xpressBytes != null ? Uint8List.fromList(xpressBytes) : null,
      summaryPdfBytes: summaryBytes,
      manifestPdfBytes: manifestBytes,
      perSkuPdfs: perSkuPdfs,
    );
  }

  /// Draw one cropped shipping label page into target document
  static void _drawCroppedPage({
    required PdfDocument doc,
    required PdfTemplate template,
    required Size srcSize,
    required double cropHeight,
    required OrderItem item,
    required bool stampQtyBox,
    required bool stampDate,
    required List<Map<String, dynamic>> highlights,
  }) {
    // Create landscape section so dimensions are width: 595.0, height: cropHeight
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.orientation = PdfPageOrientation.landscape;
    section.pageSettings.size = Size(595.0, cropHeight);
    section.pageSettings.rotate = PdfPageRotateAngle.rotateAngle90;

    final page = section.pages.add();

    // Draw the source template starting from top-left (0, 0)
    // The page height clips out the Tax Invoice below cropHeight!
    page.graphics.drawPdfTemplate(
      template,
      const Offset(0, 0),
      Size(srcSize.width, srcSize.height),
    );

    // 1. Stamp vertical Date along the left margin (dd-MMM-yyyy)
    if (stampDate) {
      _stampDate(page, cropHeight);
    }

    // 2. Highlight Kids Bloomer sizes in soft green box if applicable
    if (item.sku == "Kids Plain Bloomer" || item.sku == "Plain Bloomer" || item.isKidsConversion) {
      for (final hl in highlights) {
        final Rect bounds = hl['bounds'];
        final String tag = hl['tag'];
        _drawGreenSizeBadge(page, bounds, tag);
      }
    }

    // 3. Stamp QTY Box if qty > 1
    if (stampQtyBox && item.qty > 1) {
      _stampQtyAnnotation(page, item.qty, cropHeight);
    }
  }

  /// Stamp vertical date along left edge matching desktop app.py
  static void _stampDate(PdfPage page, double pageHeight) {
    try {
      final dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now()).toUpperCase();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 8);
      final brush = PdfSolidBrush(PdfColor(0, 0, 0));

      page.graphics.save();
      page.graphics.translateTransform(6, pageHeight - 12);
      page.graphics.rotateTransform(-90);
      page.graphics.drawString(dateStr, font, brush: brush);
      page.graphics.restore();
    } catch (_) {}
  }

  /// Draw green age-size badge above age range text matching desktop app.py
  static void _drawGreenSizeBadge(PdfPage page, Rect textBounds, String tag) {
    try {
      const double boxW = 28;
      const double boxH = 16;
      final double cx = (textBounds.left + textBounds.right) / 2;
      final double x = cx - boxW / 2;
      final double y = textBounds.top - boxH - 2;

      if (y > 20 && x > 10 && x + boxW < 580) {
        // Soft green fill
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(204, 255, 204)),
          bounds: Rect.fromLTWH(x, y, boxW, boxH),
        );
        // Dark green border
        page.graphics.drawRectangle(
          pen: PdfPen(PdfColor(0, 128, 0), width: 0.8),
          bounds: Rect.fromLTWH(x, y, boxW, boxH),
        );
        // Size number text
        final font = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
        page.graphics.drawString(
          tag,
          font,
          brush: PdfSolidBrush(PdfColor(0, 80, 0)),
          bounds: Rect.fromLTWH(x, y + 2, boxW, boxH),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }
    } catch (_) {}
  }

  /// Stamp red-highlighted QTY badge onto shipping label
  static void _stampQtyAnnotation(PdfPage page, int qty, double pageHeight) {
    const double boxWidth = 110;
    const double boxHeight = 22;
    const double x = 125;
    final double y = max(10.0, pageHeight - 45);

    // Draw background fill (soft pink)
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 240, 240)),
      bounds: Rect.fromLTWH(x, y, boxWidth, boxHeight),
    );

    // Draw border (bold red)
    page.graphics.drawRectangle(
      pen: PdfPen(PdfColor(220, 38, 38), width: 1.2),
      bounds: Rect.fromLTWH(x, y, boxWidth, boxHeight),
    );

    // Draw QTY text
    final font = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    page.graphics.drawString(
      "QTY: $qty",
      font,
      brush: PdfSolidBrush(PdfColor(185, 28, 28)),
      bounds: Rect.fromLTWH(x + 4, y + 4, boxWidth - 8, boxHeight - 8),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
  }
}

