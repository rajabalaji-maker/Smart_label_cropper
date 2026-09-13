import '../models/order_item.dart';
import 'normalization_service.dart';

class LabelParserService {
  static final RegExp orderNoRegex = RegExp(r'\b[A-Za-z0-9-]*\d{8,}[_-]\d+\b');
  static final RegExp flipkartOrderRegex = RegExp(r'\bOD\d{15,18}\b', caseSensitive: false);
  static final RegExp amazonOrderRegex = RegExp(r'\b\d{3}-\d{7}-\d{7}\b');

  static final List<String> courierKeywords = [
    "DELHIVERY",
    "SHADOWFAX",
    "XPRESSBEES",
    "EKART",
    "ECOM EXPRESS",
    "VALMO",
    "BLUEDART",
    "DTDC",
  ];

  /// Detect platform from page text
  static String detectPlatform(String text) {
    final upper = text.toUpperCase();
    if (upper.contains("MEESHO") || upper.contains("SKU SIZE QTY COLOR")) {
      return "Meesho";
    }
    if (amazonOrderRegex.hasMatch(upper) || upper.contains("AMAZON")) {
      return "Amazon";
    }
    if (flipkartOrderRegex.hasMatch(upper) || upper.contains("FLIPKART") || upper.contains("EKART")) {
      return "Flipkart";
    }
    return "Meesho"; // default fallback
  }

  /// Extract courier partner from text
  static String extractCourier(String text) {
    final upper = text.toUpperCase();
    for (final courier in courierKeywords) {
      if (upper.contains(courier)) {
        if (courier == "DELHIVERY") return "Delhivery";
        if (courier == "SHADOWFAX") return "Shadowfax";
        if (courier == "XPRESSBEES") return "Xpressbees";
        if (courier == "EKART") return "Ekart";
        if (courier == "ECOM EXPRESS") return "Ecom Express";
        if (courier == "VALMO") return "Valmo";
        if (courier == "BLUEDART") return "Blue Dart";
        if (courier == "DTDC") return "DTDC";
      }
    }
    return "Others";
  }

  /// Main parser entry point per page
  static OrderItem parsePageText(String text, int pageIndex, {String platform = 'Auto'}) {
    final effectivePlatform = platform == 'Auto' ? detectPlatform(text) : platform;
    final courier = extractCourier(text);
    final now = DateTime.now().toIso8601String();

    if (effectivePlatform == "Meesho") {
      return _parseMeesho(text, pageIndex, courier, now);
    } else if (effectivePlatform == "Amazon") {
      return _parseAmazon(text, pageIndex, courier, now);
    } else if (effectivePlatform == "Flipkart") {
      return _parseFlipkart(text, pageIndex, courier, now);
    }

    return _parseMeesho(text, pageIndex, courier, now);
  }

  static OrderItem _parseMeesho(String text, int pageIndex, String courier, String now) {
    String orderNo = "UNKNOWN";
    final orderMatch = orderNoRegex.firstMatch(text);
    if (orderMatch != null) {
      orderNo = orderMatch.group(0)!;
    }

    // Try Product Details section
    final productSectionMatch = RegExp(r'Product Details.*?(?=\n\n|TAX INVOICE|BILL TO|SHIP TO|\Z)', caseSensitive: false, dotAll: true).firstMatch(text);
    final scope = productSectionMatch != null ? productSectionMatch.group(0)! : text;

    String rawSku = "Unsorted";
    String rawSize = "Free Size";
    String rawColor = "Multicolor";
    int qty = 1;

    // Check SKU: line
    final skuMatch = RegExp(r'SKU:\s*([^\n]+)', caseSensitive: false).firstMatch(scope);
    if (skuMatch != null) {
      rawSku = skuMatch.group(1)!.trim();
    }

    // Check QTY: line
    final qtyMatch = RegExp(r'\b(?:Qty|Quantity)[:\s]*([0-9]{1,4})\b', caseSensitive: false).firstMatch(scope);
    if (qtyMatch != null) {
      final parsedQty = int.tryParse(qtyMatch.group(1)!);
      if (parsedQty != null && parsedQty > 0) {
        qty = parsedQty;
      }
    }

    // Check Size: line
    final sizeMatch = RegExp(r'\bSize[:\s]*([^\n,]+)', caseSensitive: false).firstMatch(scope);
    if (sizeMatch != null) {
      rawSize = sizeMatch.group(1)!.trim();
    } else {
      // Check for size tokens in text
      for (final sizeCand in NormalizationService.sizeSequence) {
        if (scope.contains(sizeCand)) {
          rawSize = sizeCand;
          break;
        }
      }
    }

    // Fallback: search for SKU keywords if still unsorted
    if (rawSku == "Unsorted") {
      for (final canonical in NormalizationService.canonicalSkuOrder) {
        if (text.toLowerCase().contains(canonical.toLowerCase())) {
          rawSku = canonical;
          break;
        }
      }
    }

    final normalizedSku = NormalizationService.normalizeSku(rawSku);
    final normalizedSize = NormalizationService.normalizeSize(rawSize);
    final normalizedColor = NormalizationService.normalizeColor(rawColor, sku: normalizedSku);

    return OrderItem(
      platform: "Meesho",
      orderNo: orderNo,
      rawSku: rawSku,
      sku: normalizedSku,
      color: normalizedColor,
      size: normalizedSize,
      qty: qty,
      courierPartner: courier,
      importedAt: now,
      pageIndex: pageIndex,
    );
  }

  static OrderItem _parseAmazon(String text, int pageIndex, String courier, String now) {
    String orderNo = "AMZ-ORDER";
    final match = amazonOrderRegex.firstMatch(text);
    if (match != null) {
      orderNo = match.group(0)!;
    }

    return OrderItem(
      platform: "Amazon",
      orderNo: orderNo,
      rawSku: "Amazon Item",
      sku: NormalizationService.normalizeSku("Amazon Item"),
      color: "Multicolor",
      size: "Free Size",
      qty: 1,
      courierPartner: courier.isEmpty || courier == "Others" ? "Amazon ATS" : courier,
      importedAt: now,
      pageIndex: pageIndex,
    );
  }

  static OrderItem _parseFlipkart(String text, int pageIndex, String courier, String now) {
    String orderNo = "FK-ORDER";
    final match = flipkartOrderRegex.firstMatch(text);
    if (match != null) {
      orderNo = match.group(0)!;
    }

    return OrderItem(
      platform: "Flipkart",
      orderNo: orderNo,
      rawSku: "Flipkart Item",
      sku: NormalizationService.normalizeSku("Flipkart Item"),
      color: "Multicolor",
      size: "Free Size",
      qty: 1,
      courierPartner: courier.isEmpty || courier == "Others" ? "Ekart" : courier,
      importedAt: now,
      pageIndex: pageIndex,
    );
  }
}
