import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/order_item.dart';
import 'label_parser_service.dart';
import 'normalization_service.dart';

class ProcessedBatchResult {
  final Uint8List sortedCroppedPdfBytes;
  final String savedPdfPath;
  final List<OrderItem> parsedItems;

  ProcessedBatchResult({
    required this.sortedCroppedPdfBytes,
    required this.savedPdfPath,
    required this.parsedItems,
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
  }) async {
    final List<Map<String, dynamic>> processedPages = [];
    final List<OrderItem> allOrderItems = [];

    for (final bytes in pdfFilesBytes) {
      final inputDoc = PdfDocument(inputBytes: bytes);
      final textExtractor = PdfTextExtractor(inputDoc);

      for (int i = 0; i < inputDoc.pages.count; i++) {
        final page = inputDoc.pages[i];
        final pageSize = page.size;
        final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);

        // Find primary keyword y-position
        double? primaryY;
        final lines = textExtractor.extractTextLines(startPageIndex: i, endPageIndex: i);
        for (final line in lines) {
          if (line.text.toLowerCase().contains(primaryKeyword.toLowerCase())) {
            primaryY = line.bounds.top;
            break;
          }
        }

        // Determine crop bounds
        Rect? cropRect;
        if (primaryY != null) {
          // Crop above the keyword line
          final cropHeight = (primaryY > 10) ? primaryY : (pageSize.height * 0.55);
          cropRect = Rect.fromLTWH(0, 0, pageSize.width, cropHeight);
        } else if (pageText.toLowerCase().contains(secondaryKeyword.toLowerCase())) {
          // Crop secondary percentage
          cropRect = Rect.fromLTWH(0, 0, pageSize.width, pageSize.height * secondaryCropPercent);
        } else {
          // If no keyword found, keep 60% standard label top
          cropRect = Rect.fromLTWH(0, 0, pageSize.width, pageSize.height * 0.60);
        }

        // Parse order details from text
        final orderItem = LabelParserService.parsePageText(pageText, i);
        allOrderItems.add(orderItem);

        processedPages.add({
          'sourceDoc': inputDoc,
          'pageIndex': i,
          'cropRect': cropRect,
          'orderItem': orderItem,
          'pageSize': pageSize,
        });
      }
    }

    // Sort pages by Canonical SKU order then Size Sequence
    processedPages.sort((a, b) {
      final OrderItem itemA = a['orderItem'];
      final OrderItem itemB = b['orderItem'];

      final skuCmp = NormalizationService.skuSortRank(itemA.sku).compareTo(
        NormalizationService.skuSortRank(itemB.sku),
      );
      if (skuCmp != 0) return skuCmp;

      return NormalizationService.sizeSortRank(itemA.size).compareTo(
        NormalizationService.sizeSortRank(itemB.size),
      );
    });

    // Create the final cropped output document
    final outputDoc = PdfDocument();
    outputDoc.pageSettings.margins.all = 0;

    for (final p in processedPages) {
      final PdfDocument srcDoc = p['sourceDoc'];
      final int pageIdx = p['pageIndex'];
      final Rect crop = p['cropRect'];
      final OrderItem item = p['orderItem'];

      // Extract template from source page
      final template = srcDoc.pages[pageIdx].createTemplate();

      // Configure output page dimension matching the crop box
      outputDoc.pageSettings.size = Size(crop.width, crop.height);
      final newPage = outputDoc.pages.add();

      // Draw cropped portion onto new page (offsetting by crop.left, crop.top)
      newPage.graphics.drawPdfTemplate(
        template,
        Offset(-crop.left, -crop.top),
        Size(p['pageSize'].width, p['pageSize'].height),
      );

      // Stamp QTY Box if qty > 1
      if (stampQtyBox && item.qty > 1) {
        _stampQtyAnnotation(newPage, item.qty, crop.width, crop.height);
      }
    }

    // Save output PDF
    final List<int> outputBytes = outputDoc.saveSync();
    outputDoc.dispose();

    // Persist to device directory
    final outputDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${outputDir.path}/meesho_cropped_$timestamp.pdf');
    await file.writeAsBytes(outputBytes);

    return ProcessedBatchResult(
      sortedCroppedPdfBytes: Uint8List.fromList(outputBytes),
      savedPdfPath: file.path,
      parsedItems: processedPages.map((p) => p['orderItem'] as OrderItem).toList(),
    );
  }

  /// Stamp red-highlighted QTY badge onto the shipping label
  static void _stampQtyAnnotation(PdfPage page, int qty, double pageWidth, double pageHeight) {
    const double boxWidth = 120;
    const double boxHeight = 26;
    final double x = 20;
    final double y = pageHeight - boxHeight - 20;

    // Draw background fill (soft pink)
    final brush = PdfSolidBrush(PdfColor(255, 240, 240));
    page.graphics.drawRectangle(
      brush: brush,
      bounds: Rect.fromLTWH(x, y, boxWidth, boxHeight),
    );

    // Draw border (bold red)
    final pen = PdfPen(PdfColor(220, 38, 38), width: 1.5);
    page.graphics.drawRectangle(
      pen: pen,
      bounds: Rect.fromLTWH(x, y, boxWidth, boxHeight),
    );

    // Draw QTY text
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final textBrush = PdfSolidBrush(PdfColor(185, 28, 28));
    page.graphics.drawString(
      "QTY: $qty PIECES",
      font,
      brush: textBrush,
      bounds: Rect.fromLTWH(x + 8, y + 5, boxWidth - 16, boxHeight - 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
  }
}
