import '../models/order_item.dart';
import 'normalization_service.dart';

class LabelParserService {
  static final RegExp orderNoRegex = RegExp(
    r"Order(?:\s*No(?:\.|)|\s*Number)\s*[:\-]?\s*([0-9_]{6,}\b(?:_[0-9]+)?)",
    caseSensitive: false,
  );
  static final RegExp orderNoFallbackRegex = RegExp(r'\b[A-Za-z0-9-]*\d{8,}[_-]\d+\b');
  static final RegExp flipkartOrderRegex = RegExp(r'\bOD\d{15,18}\b', caseSensitive: false);
  static final RegExp amazonOrderRegex = RegExp(r'\b\d{3}-\d{7}-\d{7}\b');

  static final RegExp monthsRegex = RegExp(r'\b(\d{1,2})\s*[-/]\s*(\d{1,2})\s*(?:months|mon|m)\b', caseSensitive: false);
  static final RegExp yearsRegex = RegExp(r'\b(\d{1,2})\s*[-/]\s*(\d{1,2})\s*(?:years|year|yrs|yr|y)\b', caseSensitive: false);
  static final RegExp cmRegex = RegExp(r'\b(\d{2,3})\s*cm[s]?\b', caseSensitive: false);
  static final RegExp letterRegex = RegExp(r'\b(XXS|XS|S|M|L|XL|2XL|XXL|3XL|4XL|5XL|6XL)\b', caseSensitive: false);
  static final RegExp bareCmRegex = RegExp(r'\b(70|75|80|85|90|95|100|105|110|115|120)\b');

  /// Detect platform from page text
  static String detectPlatform(String text) {
    final upper = text.toUpperCase();
    if (upper.contains("MEESHO") || (upper.contains("SKU") && upper.contains("QTY"))) {
      return "Meesho";
    }
    if (amazonOrderRegex.hasMatch(upper) || upper.contains("AMAZON")) {
      return "Amazon";
    }
    if (flipkartOrderRegex.hasMatch(upper) || upper.contains("FLIPKART") || upper.contains("EKART")) {
      return "Flipkart";
    }
    return "Meesho";
  }

  /// Detect courier partner matching app.py
  static String extractCourier(String text) {
    if (text.isEmpty) return "Unknown";
    final tl = text.toLowerCase();

    if (RegExp(r'\b(ejh)\b', caseSensitive: false).hasMatch(tl) || RegExp(r'\bejh[-_]', caseSensitive: false).hasMatch(tl)) {
      return "Valmo-EJH";
    }
    if (RegExp(r'\b(ejz)\b', caseSensitive: false).hasMatch(tl) || RegExp(r'\bejz[-_]', caseSensitive: false).hasMatch(tl)) {
      return "Valmo-EJZ";
    }
    if (tl.contains("valmo-enl")) return "Valmo-ENL";
    if (tl.contains("valmo")) return "Valmo";
    if (tl.contains("delhivery") || tl.contains("dhl")) return "DELHIVERY";
    if (tl.contains("shadowfax")) return "SHADOWFAX";
    if (tl.contains("xpressbees") || tl.contains("xpress bees")) return "XPRESS BEES";
    if (tl.contains("ecom express") || tl.contains("ecomexpress")) return "Ecom Express";
    if (tl.contains("bluedart") || tl.contains("blue dart")) return "Bluedart";
    if (tl.contains("ekart")) return "Ekart";
    if (tl.contains("dtdc")) return "DTDC";
    if (tl.contains("fedex")) return "FedEx";
    if (tl.contains("loadshare") || tl.contains("load share")) return "Load Share";
    if (tl.contains("jusda")) return "Jusda";

    return "Unknown";
  }

  /// Check whether the page has multiple orders
  static (bool, int) isMultiOrderPage(String text) {
    if (text.isEmpty) return (false, 0);

    final prodMatch = RegExp(r'Product Details.*?(?=\n\n|TAX INVOICE|\Z)', caseSensitive: false, dotAll: true).firstMatch(text);
    final content = prodMatch != null ? prodMatch.group(0)! : text;
    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    int matches = 0;
    for (int i = 0; i < lines.length; i++) {
      final ln = lines[i].toLowerCase();
      bool skuFound = ln.contains("bloomer") ||
          ln.contains("panty") ||
          ln.contains("button") ||
          ln.contains("t-shirt") ||
          ln.contains("tshirt") ||
          ln.contains("trunk") ||
          ln.contains("seri");

      bool sizeFound = letterRegex.hasMatch(lines[i]) ||
          cmRegex.hasMatch(lines[i]) ||
          bareCmRegex.hasMatch(lines[i]) ||
          monthsRegex.hasMatch(lines[i]) ||
          yearsRegex.hasMatch(lines[i]);

      if (!sizeFound && i + 1 < lines.length) {
        sizeFound = letterRegex.hasMatch(lines[i + 1]) ||
            cmRegex.hasMatch(lines[i + 1]) ||
            bareCmRegex.hasMatch(lines[i + 1]) ||
            monthsRegex.hasMatch(lines[i + 1]) ||
            yearsRegex.hasMatch(lines[i + 1]);
      }

      if (skuFound && sizeFound) {
        matches++;
      }
    }
    return (matches >= 2, matches);
  }

  /// Detect Order Number from text
  static String detectOrderNumber(String text) {
    if (text.isEmpty) return "";
    final prodMatch = RegExp(r'Product Details.*?(?=\n\n|TAX INVOICE|\Z)', caseSensitive: false, dotAll: true).firstMatch(text);
    final block = prodMatch != null ? prodMatch.group(0)! : text;

    final m = orderNoRegex.firstMatch(block);
    if (m != null) {
      return m.group(1)!.trim();
    }
    final m2 = orderNoFallbackRegex.firstMatch(block);
    if (m2 != null) {
      return m2.group(0)!.trim();
    }
    return "";
  }

  /// Detect SKU matching app.py
  static (String, String) detectSku(String text) {
    final lower = text.toLowerCase();

    final prodMatch = RegExp(r'Product Details.*?(?=\n\n|TAX INVOICE|\Z)', caseSensitive: false, dotAll: true).firstMatch(text);
    if (prodMatch != null) {
      final section = prodMatch.group(0)!;
      final skuMatch = RegExp(r'SKU:\s*([^\n]+)', caseSensitive: false).firstMatch(section);
      if (skuMatch != null) {
        final val = skuMatch.group(1)!.trim().toLowerCase();
        if (val.contains("bloomer") && val.contains("plain")) return ("Plain Bloomer", "high");
        if (val.contains("bloomer") && val.contains("print")) return ("Printed Bloomer", "high");
        if (val.contains("panty") && val.contains("plain")) return ("Plain Panty", "high");
        if (val.contains("button") && val.contains("plain")) return ("Button Plain", "high");
        if (val.contains("button") && val.contains("print")) return ("Button Print", "high");
        if (val.contains("t-shirt") || val.contains("tshirt")) return ("Kids T-Shirt", "high");
      }
    }

    for (final sku in NormalizationService.canonicalSkuOrder) {
      if (lower.contains(sku.toLowerCase())) {
        return (sku, "high");
      }
    }

    for (final entry in NormalizationService.defaultSkuVariants.entries) {
      for (final variant in entry.value) {
        if (lower.contains(variant.toLowerCase())) {
          return (entry.key, "medium");
        }
      }
    }

    if (lower.contains("bloomer") && lower.contains("plain")) return ("Plain Bloomer", "low");
    if (lower.contains("bloomer") && lower.contains("print")) return ("Printed Bloomer", "low");
    if (lower.contains("panty") && lower.contains("plain")) return ("Plain Panty", "low");
    if (lower.contains("button") && lower.contains("plain")) return ("Button Plain", "low");
    if (lower.contains("button") && lower.contains("print")) return ("Button Print", "low");
    if (lower.contains("t-shirt") || lower.contains("tshirt")) return ("Kids T-Shirt", "low");
    if (lower.contains("trunk")) return ("Trunks IE", "low");
    if (lower.contains("seri")) return ("Seri Print", "low");

    return ("Unsorted", "low");
  }

  /// Detect Size and Qty matching app.py
  static (String, int, String) detectSizeAndQty(String text) {
    String sizeLabel = "";
    int qty = 1;
    String confidence = "low";

    final prodMatch = RegExp(r'Product Details.*?(?=\n\n|TAX INVOICE|\Z)', caseSensitive: false, dotAll: true).firstMatch(text);
    if (prodMatch != null) {
      final lines = prodMatch.group(0)!.split('\n').map((l) => l.trim()).toList();
      final skuKeywords = ["bloomer", "panty", "button", "t-shirt", "tshirt", "seri", "trunk"];

      final List<int> skuIndices = [];
      for (int i = 0; i < lines.length; i++) {
        final ln = lines[i].toLowerCase();
        if (skuKeywords.any((k) => ln.contains(k)) && ln.isNotEmpty) {
          skuIndices.add(i);
        }
      }

      for (final skuIdx in skuIndices) {
        int? sizeFoundIdx;
        for (int j = skuIdx + 1; j < lines.length && j <= skuIdx + 6; j++) {
          final cand = lines[j];
          if (cand.isEmpty) continue;

          final mLetter = letterRegex.firstMatch(cand);
          if (mLetter != null) {
            var key = mLetter.group(1)!.toUpperCase();
            if (key == "XXL") key = "2XL";
            if (NormalizationService.letterToLabel.containsKey(key)) {
              sizeLabel = NormalizationService.letterToLabel[key]!;
              sizeFoundIdx = j;
              confidence = "high";
              break;
            }
          }

          final mCm = cmRegex.firstMatch(cand);
          if (mCm != null) {
            final val = int.tryParse(mCm.group(1)!);
            if (val != null && NormalizationService.cmToLabel.containsKey(val)) {
              sizeLabel = NormalizationService.cmToLabel[val]!;
              sizeFoundIdx = j;
              confidence = "high";
              break;
            }
          }

          final mBare = RegExp(r'^(\d{2,3})$').firstMatch(cand);
          if (mBare != null) {
            final val = int.tryParse(mBare.group(1)!);
            if (val != null && NormalizationService.cmToLabel.containsKey(val)) {
              sizeLabel = NormalizationService.cmToLabel[val]!;
              sizeFoundIdx = j;
              confidence = "high";
              break;
            }
          }

          final mMonths = monthsRegex.firstMatch(cand);
          if (mMonths != null) {
            sizeLabel = "${mMonths.group(1)}-${mMonths.group(2)} Months";
            sizeFoundIdx = j;
            confidence = "high";
            break;
          }

          final mYears = yearsRegex.firstMatch(cand);
          if (mYears != null) {
            sizeLabel = "${mYears.group(1)}-${mYears.group(2)} Years";
            sizeFoundIdx = j;
            confidence = "high";
            break;
          }
        }

        if (sizeFoundIdx != null) {
          for (int k = sizeFoundIdx + 1; k < lines.length && k <= sizeFoundIdx + 5; k++) {
            final lk = lines[k];
            if (lk.isEmpty) continue;
            final mQty = RegExp(r'\b(?:Qty|QTY|Quantity)[:\s]*([0-9]{1,4})\b', caseSensitive: false).firstMatch(lk);
            if (mQty != null) {
              final parsed = int.tryParse(mQty.group(1)!);
              if (parsed != null && parsed > 0 && parsed <= 1000) {
                qty = parsed;
                return (sizeLabel, qty, "high");
              }
            }
            final pureInt = int.tryParse(lk);
            if (pureInt != null && pureInt > 0 && pureInt <= 1000) {
              qty = pureInt;
              return (sizeLabel, qty, "high");
            }
          }
          return (sizeLabel, qty, confidence);
        }
      }
    }

    // Fallback search across whole page
    final mAnyQty = RegExp(r'\b(?:Qty|Quantity)[:\s]*([0-9]{1,4})\b', caseSensitive: false).firstMatch(text);
    if (mAnyQty != null) {
      final parsed = int.tryParse(mAnyQty.group(1)!);
      if (parsed != null && parsed > 0 && parsed <= 1000) {
        qty = parsed;
        confidence = "medium";
      }
    }

    final mMonths = monthsRegex.firstMatch(text);
    if (mMonths != null && sizeLabel.isEmpty) {
      sizeLabel = "${mMonths.group(1)}-${mMonths.group(2)} Months";
      confidence = "medium";
    }

    final mYears = yearsRegex.firstMatch(text);
    if (mYears != null && sizeLabel.isEmpty) {
      sizeLabel = "${mYears.group(1)}-${mYears.group(2)} Years";
      confidence = "medium";
    }

    final mLetter = letterRegex.firstMatch(text);
    if (mLetter != null && sizeLabel.isEmpty) {
      var key = mLetter.group(1)!.toUpperCase();
      if (key == "XXL") key = "2XL";
      if (NormalizationService.letterToLabel.containsKey(key)) {
        sizeLabel = NormalizationService.letterToLabel[key]!;
        confidence = "medium";
      }
    }

    final mCm = cmRegex.firstMatch(text);
    if (mCm != null && sizeLabel.isEmpty) {
      final val = int.tryParse(mCm.group(1)!);
      if (val != null && NormalizationService.cmToLabel.containsKey(val)) {
        sizeLabel = NormalizationService.cmToLabel[val]!;
        confidence = "medium";
      }
    }

    return (sizeLabel.isEmpty ? "Free Size" : sizeLabel, qty, confidence);
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
    final orderNo = detectOrderNumber(text);
    var (sku, _) = detectSku(text);
    var (sizeLabel, qty, _) = detectSizeAndQty(text);
    final (multiOrder, _) = isMultiOrderPage(text);

    // Check Kids conversion 5/10
    bool isKidsConversion = false;
    final lower = text.toLowerCase();
    if (RegExp(r'\b10\s*[-_]?\s*kids\s+plain\s+bloomer', caseSensitive: false).hasMatch(lower)) {
      sku = "Plain Bloomer";
      qty = qty * 2;
      isKidsConversion = true;
    } else if (RegExp(r'\b5\s*[-_]?\s*kids\s+plain\s+bloomer', caseSensitive: false).hasMatch(lower)) {
      sku = "Plain Bloomer";
      isKidsConversion = true;
    }

    // Normalize size for Kids Bloomer conversion to CM equivalent
    if (isKidsConversion && sizeLabel.isNotEmpty) {
      for (final entry in NormalizationService.kidsBloomerSizeMap.entries) {
        if (sizeLabel.toLowerCase().contains(entry.key.toLowerCase())) {
          final cmVal = int.tryParse(entry.value);
          if (cmVal != null && NormalizationService.cmToLabel.containsKey(cmVal)) {
            sizeLabel = NormalizationService.cmToLabel[cmVal]!;
          }
          break;
        }
      }
    }

    return OrderItem(
      platform: "Meesho",
      orderNo: orderNo.isEmpty ? "UNKNOWN" : orderNo,
      rawSku: sku,
      sku: NormalizationService.normalizeSku(sku),
      color: NormalizationService.normalizeColor("Multicolor", sku: sku),
      size: NormalizationService.normalizeSize(sizeLabel),
      qty: qty,
      courierPartner: courier,
      importedAt: now,
      pageIndex: pageIndex,
      multiOrder: multiOrder,
      isKidsConversion: isKidsConversion,
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
      courierPartner: courier.isEmpty || courier == "Others" || courier == "Unknown" ? "Amazon ATS" : courier,
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
      courierPartner: courier.isEmpty || courier == "Others" || courier == "Unknown" ? "Ekart" : courier,
      importedAt: now,
      pageIndex: pageIndex,
    );
  }
}

