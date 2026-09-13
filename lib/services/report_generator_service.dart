import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/order_item.dart';
import 'normalization_service.dart';

class ReportGeneratorService {
  /// Generate printable Pick List PDF
  static Future<Uint8List> generatePickListPdf({
    required List<OrderItem> items,
    String brandName = "Tony Max",
  }) async {
    final pdf = pw.Document();

    // Group items by SKU -> Size -> Color
    final Map<String, int> grouped = {};
    for (final item in items) {
      final key = "${item.sku} | Size: ${item.size} | Color: ${item.color}";
      grouped[key] = (grouped[key] ?? 0) + item.qty;
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final totalUnits = items.fold<int>(0, (sum, item) => sum + item.qty);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "$brandName - Warehouse Pick List",
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    "Date: $dateStr",
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  "Total Units: $totalUnits",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8), // Checkbox
              1: const pw.FlexColumnWidth(5.0), // SKU & Details
              2: const pw.FlexColumnWidth(1.5), // Qty
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Check", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Product Description (SKU / Size / Color)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Pick QTY", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...sortedEntries.map(
                (entry) => pw.TableRow(
                  children: [
                    pw.Center(
                      child: pw.Container(
                        width: 14,
                        height: 14,
                        margin: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 1),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "${entry.value}",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generate printable Courier Manifest PDF
  static Future<Uint8List> generateManifestPdf({
    required List<OrderItem> items,
    String brandName = "Tony Max",
  }) async {
    final pdf = pw.Document();

    // Group items by Courier Partner
    final Map<String, List<OrderItem>> courierGroups = {};
    for (final item in items) {
      courierGroups.putIfAbsent(item.courierPartner, () => []).add(item);
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    for (final entry in courierGroups.entries) {
      final courier = entry.key;
      final courierItems = entry.value;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "$brandName - Courier Handover Manifest",
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      "Courier Partner: $courier",
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                    ),
                    pw.Text("Date: $dateStr", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    "Total Packets: ${courierItems.length}",
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8), // S.No
                1: const pw.FlexColumnWidth(3.0), // Order No
                2: const pw.FlexColumnWidth(4.0), // SKU Details
                3: const pw.FlexColumnWidth(1.2), // Qty
                4: const pw.FlexColumnWidth(2.0), // Signature/Handover
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("S.No", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Order No / AWB", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Product Details", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Rider Sign", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...courierItems.asMap().entries.map((itemEntry) {
                  final idx = itemEntry.key + 1;
                  final item = itemEntry.value;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("$idx")),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.orderNo, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${item.sku} (${item.size})", style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${item.qty}", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("")),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Seller Signature: __________________"),
                    pw.SizedBox(height: 4),
                    pw.Text("Handed Over By"),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Courier Pickup Agent: __________________"),
                    pw.SizedBox(height: 4),
                    pw.Text("Name & Phone No."),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  /// Generate Aggregated Order Summary PDF matching app.py
  static Future<Uint8List> generateOrderSummaryPdf({
    required List<OrderItem> items,
    String brandName = "Tony Max",
  }) async {
    final pdf = pw.Document();

    final Map<String, Map<String, int>> skuSizeTotals = {};
    final Map<String, int> skuOnlyTotals = {};
    int grandTotal = 0;

    for (final item in items) {
      final sizeMap = skuSizeTotals.putIfAbsent(item.sku, () => {});
      sizeMap[item.size] = (sizeMap[item.size] ?? 0) + item.qty;
      skuOnlyTotals[item.sku] = (skuOnlyTotals[item.sku] ?? 0) + item.qty;
      grandTotal += item.qty;
    }

    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    // Sort SKUs by canonical rank
    final sortedSkus = skuSizeTotals.keys.toList()
      ..sort((a, b) => NormalizationService.skuSortRank(a).compareTo(NormalizationService.skuSortRank(b)));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "$brandName - Aggregated Order Summary",
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    "Date: $dateStr",
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  "Grand Total: $grandTotal pcs",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // Detailed Table: SKU | SIZE | TOTAL ORDERS
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(4.5), // SKU
              1: const pw.FlexColumnWidth(3.0), // Size
              2: const pw.FlexColumnWidth(2.0), // Total Orders
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("SKU", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("SIZE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("TOTAL ORDERS", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              for (final sku in sortedSkus)
                ...(() {
                  final sizes = (skuSizeTotals[sku]?.keys.toList() ?? [])
                    ..sort((a, b) => NormalizationService.sizeSortRank(a).compareTo(NormalizationService.sizeSortRank(b)));
                  return sizes.map((size) {
                    final qty = skuSizeTotals[sku]?[size] ?? 0;
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(sku, style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(size, style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("$qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      ],
                    );
                  });
                })(),
              // Grand Total Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("GRAND TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("")),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("$grandTotal", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          // SKU-wise Summary Table (All Sizes Combined)
          pw.Text("SKU-WISE SUMMARY (All Sizes Combined)", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(6.0),
              1: const pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("SKU NAME", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("TOTAL QTY", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              for (final sku in sortedSkus)
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(sku, style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${skuOnlyTotals[sku] ?? 0}", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Save PDF bytes to file
  static Future<String> saveReportToFile(Uint8List pdfBytes, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/${prefix}_$timestamp.pdf');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }
}
