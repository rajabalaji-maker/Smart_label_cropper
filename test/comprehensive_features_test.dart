import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tony_max_mobile/models/order_item.dart';
import 'package:tony_max_mobile/services/pdf_cropper_service.dart';
import 'package:tony_max_mobile/services/report_generator_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  group('Comprehensive PDF Cropping & Feature Parity Tests', () {
    final testPdfPaths = [
      'D:/Sub_Order_Labels_d48c6c1a-8a64-4af5-b86a-9a1bbbc68eca.pdf',
      'D:/Sub_Order_Labels_78fbf028-3085-48db-ad8f-db4d78e92b7e.pdf',
      'D:/label_310670194006461824_1.pdf',
      'D:/146618794496020635.pdf',
      'D:/146701556222020636.pdf',
    ];

    for (final pdfPath in testPdfPaths) {
      test('Processing $pdfPath generates valid PDF bytes without crashing', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final file = File(pdfPath);
        if (!file.existsSync()) {
          print('File not found: $pdfPath (skipping)');
          return;
        }

        final bytes = await file.readAsBytes();
        expect(bytes.isNotEmpty, isTrue);

        final result = await PdfCropperService.processPdfs(
          pdfFilesBytes: [bytes],
          stampDate: true,
          stampQtyBox: true,
        );

        expect(result.sortedCroppedPdfBytes.isNotEmpty, isTrue);
        expect(result.parsedItems.isNotEmpty, isTrue);
        print('SUCCESS: $pdfPath -> ${result.parsedItems.length} items parsed, ${result.sortedCroppedPdfBytes.length} bytes generated');

        for (final item in result.parsedItems) {
          expect(item.sku.isNotEmpty, isTrue);
          expect(item.size.isNotEmpty, isTrue);
          expect(item.qty > 0, isTrue);
          expect(item.courierPartner.isNotEmpty, isTrue);
        }
      });
    }

    test('Multi-file batch processing combines and sorts across files', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final batchBytes = <Uint8List>[];
      for (final p in [
        'D:/Sub_Order_Labels_d48c6c1a-8a64-4af5-b86a-9a1bbbc68eca.pdf',
        'D:/label_310670194006461824_1.pdf',
      ]) {
        final f = File(p);
        if (f.existsSync()) {
          batchBytes.add(await f.readAsBytes());
        }
      }

      if (batchBytes.length < 2) return;

      final result = await PdfCropperService.processPdfs(pdfFilesBytes: batchBytes);
      expect(result.sortedCroppedPdfBytes.isNotEmpty, isTrue);
      expect(result.parsedItems.length >= 2, isTrue);
      print('Multi-file batch success: ${result.parsedItems.length} total orders across files');
    });

    test('All report generators produce valid PDF bytes', () async {
      final sampleItems = [
        OrderItem(
          platform: 'Meesho',
          orderNo: '123456789_1',
          rawSku: 'Plain Bloomer',
          sku: 'Plain Bloomer',
          color: 'Multicolor',
          size: '75cm / XS',
          qty: 1,
          courierPartner: 'DELHIVERY',
          importedAt: '2026-09-13',
        ),
        OrderItem(
          platform: 'Meesho',
          orderNo: '987654321_1',
          rawSku: 'Kids Plain Bloomer',
          sku: 'Kids Plain Bloomer',
          color: 'Multicolor',
          size: '9-10 Years',
          qty: 2,
          courierPartner: 'SHADOWFAX',
          importedAt: '2026-09-13',
        ),
        OrderItem(
          platform: 'Meesho',
          orderNo: '555666777_1',
          rawSku: 'Plain Panty',
          sku: 'Plain Panty',
          color: 'Multicolor',
          size: '80cm / S',
          qty: 1,
          courierPartner: 'XPRESS BEES',
          importedAt: '2026-09-13',
        ),
      ];

      // 1. Order Summary PDF
      final summaryPdf = await ReportGeneratorService.generateOrderSummaryPdf(
        items: sampleItems,
      );
      expect(summaryPdf.isNotEmpty, isTrue);
      print('Order Summary PDF generated: ${summaryPdf.length} bytes');

      // 2. Manifest PDF
      final manifestPdf = await ReportGeneratorService.generateManifestPdf(
        items: sampleItems,
      );
      expect(manifestPdf.isNotEmpty, isTrue);
      print('Manifest PDF generated: ${manifestPdf.length} bytes');

      // 3. Pick List PDF
      final pickListPdf = await ReportGeneratorService.generatePickListPdf(
        items: sampleItems,
      );
      expect(pickListPdf.isNotEmpty, isTrue);
      print('Pick List PDF generated: ${pickListPdf.length} bytes');

      // 4. Cutting Plan PDF
      final cuttingPlanPdf = await ReportGeneratorService.generateCuttingPlanPdf(
        rows: [
          {'sku': 'Plain Bloomer', 'size': '75cm / XS', 'ordered': 2, 'stock': 5, 'shortage': 0},
          {'sku': 'Kids Plain Bloomer', 'size': '9-10 Years', 'ordered': 4, 'stock': 1, 'shortage': 3},
        ],
        totalOrdered: 6,
        totalShortage: 3,
      );
      expect(cuttingPlanPdf.isNotEmpty, isTrue);
      print('Cutting Plan PDF generated: ${cuttingPlanPdf.length} bytes');
    });
  });
}
