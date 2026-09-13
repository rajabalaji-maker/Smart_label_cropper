import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tony_max_mobile/services/pdf_cropper_service.dart';
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

  test('PdfCropperService processes real Meesho PDFs without crashing', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final samplePath = 'D:/Sub_Order_Labels_d48c6c1a-8a64-4af5-b86a-9a1bbbc68eca.pdf';
    final file = File(samplePath);
    if (!file.existsSync()) {
      print('File not found: ' + samplePath);
      return;
    }

    final bytes = await file.readAsBytes();
    print('Read ' + bytes.length.toString() + ' bytes from ' + samplePath);

    final result = await PdfCropperService.processPdfs(
      pdfFilesBytes: [bytes],
    );

    print('Cropped PDF bytes: ' + result.sortedCroppedPdfBytes.length.toString());
    print('Parsed items count: ' + result.parsedItems.length.toString());
    expect(result.sortedCroppedPdfBytes.isNotEmpty, isTrue);
  });
}
