import 'package:flutter_test/flutter_test.dart';
import 'package:tony_max_mobile/services/normalization_service.dart';
import 'package:tony_max_mobile/services/label_parser_service.dart';

void main() {
  group('NormalizationService Tests', () {
    test('Normalizes messy SKU variants correctly', () {
      expect(NormalizationService.normalizeSku('005 Little Luxe Kids Bloomers'), 'Kids Plain Bloomer');
      expect(NormalizationService.normalizeSku('5 Plain Bloomer'), 'Plain Bloomer');
      expect(NormalizationService.normalizeSku('printed bloomer'), 'Printed Bloomer');
      expect(NormalizationService.normalizeSku('Plain Panty'), 'Plain Panty');
      expect(NormalizationService.normalizeSku('Kids T-shirt'), 'Kids T-Shirt');
      expect(NormalizationService.normalizeSku('trunks'), 'Trunks IE');
      expect(NormalizationService.normalizeSku('SeriPrint'), 'Seri Print');
    });

    test('Normalizes sizes to standard labels', () {
      expect(NormalizationService.normalizeSize('80cm'), '80cm / S');
      expect(NormalizationService.normalizeSize('90'), '90cm / L');
      expect(NormalizationService.normalizeSize('XL'), '95cm / XL');
      expect(NormalizationService.normalizeSize('XXL'), '100cm / 2XL');
      expect(NormalizationService.normalizeSize('2XL'), '100cm / 2XL');
      expect(NormalizationService.normalizeSize('1-2 Years'), '1-2 Years');
      expect(NormalizationService.normalizeSize('6-12 Months'), '6-12 Months');
      expect(NormalizationService.normalizeSize('Free'), 'Free Size');
    });

    test('Forces Multicolor on designated SKUs', () {
      expect(NormalizationService.normalizeColor('Red', sku: 'Plain Bloomer'), 'Multicolor');
      expect(NormalizationService.normalizeColor('Blue', sku: 'Printed Bloomer'), 'Multicolor');
      expect(NormalizationService.normalizeColor('NA', sku: 'Kids T-Shirt'), 'Multicolor');
      expect(NormalizationService.normalizeColor('Navy', sku: 'Kids T-Shirt'), 'Navy');
    });

    test('Canonical SKU sorting rank', () {
      final rankBloomer = NormalizationService.skuSortRank('Plain Bloomer');
      final rankPanty = NormalizationService.skuSortRank('Plain Panty');
      final rankUnknown = NormalizationService.skuSortRank('Random Unknown Item');

      expect(rankBloomer < rankPanty, true);
      expect(rankPanty < rankUnknown, true);
    });
  });

  group('LabelParserService Tests', () {
    test('Detects Meesho platform from typical label text', () {
      const text = "MEESHO SHIPPING LABEL\nSKU SIZE QTY COLOR ORDER NO.\n123456789_1";
      expect(LabelParserService.detectPlatform(text), 'Meesho');
    });

    test('Extracts Courier Partner', () {
      expect(LabelParserService.extractCourier("DELHIVERY SURFACE AIRWAYBILL"), 'DELHIVERY');
      expect(LabelParserService.extractCourier("SHADOWFAX LOGISTICS PVT LTD"), 'SHADOWFAX');
      expect(LabelParserService.extractCourier("EKART LOGISTICS"), 'Ekart');
      expect(LabelParserService.extractCourier("XPRESSBEES LOGISTICS"), 'XPRESS BEES');
      expect(LabelParserService.extractCourier("Valmo Pickup 05/09 ENL-R0"), 'Valmo-ENL');
    });

    test('Kids Bloomer age size mapping', () {
      expect(NormalizationService.kidsBloomerSizeMap['5-6 Years'], '65');
      expect(NormalizationService.kidsBloomerSizeMap['7-8 Years'], '70');
      expect(NormalizationService.kidsBloomerSizeMap['11-12 Years'], '80');
    });
  });
}
