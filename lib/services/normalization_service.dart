class NormalizationService {
  static final List<String> canonicalSkuOrder = [
    "Kids Plain Bloomer",
    "Plain Bloomer",
    "Printed Bloomer",
    "Plain Panty",
    "Trunks IE",
    "Button Plain",
    "Button Print",
    "Kids T-Shirt",
    "Seri Print",
    "10 _Kids Plain Bloomer",
    "Seri Plain",
  ];

  static final Map<String, List<String>> defaultSkuVariants = {
    "Kids Plain Bloomer": [
      "Kids plain bloomer", "Kids Plain Bloomer", "Kids Plain", "005 Little Luxe Kids Bloomers", "005 RS Kids Plain Bloomer"
    ],
    "Plain Bloomer": [
      "Plain Bloomer", "Plain bloomer", "plain bloomer", "PLAIN BLOOMER",
      "5 Plain Bloomer", "-5 g Plain Bloomer", "5 g Plain Bloomer",
      "#5 Sultry Bloomer SA - B", "#5 Lovely Lady Bloomer SA - B",
      "#5-BL-FloralMist-B", "5 _Kids Plain Bloomer", "5 Girl Kids Plain Bloomer",
      "5 Kids Plain Bloomer", "#5-BL-LaceLull-B", "#5 Girl Kids Plain Bloomer", "BL SoftWhisper B"
    ],
    "Printed Bloomer": [
      "printed bloomer", "PRINTED BLOOMER", "Printed Bloomer", "Printed bloomer"
    ],
    "Plain Panty": [
      "Plain Panty", "plain panty", "Plain panty", "PLAIN PANTY"
    ],
    "Button Plain": [
      "Button Plain", "Plain Button"
    ],
    "Button Print": [
      "Button Print", "Print Button"
    ],
    "Kids T-Shirt": [
      "Kids T-Shirt", "Kids T-shirt"
    ],
    "Trunks IE": [
      "Trunks", "trunks"
    ],
    "Seri Print": [
      "Seri Print", "Print Seri", "seri print", "print seri", "SeriPrint"
    ],
    "10 _Kids Plain Bloomer": [
      "10 _Kids plain bloomer", "10 _Kids Plain Bloomer", "10 _Kids Plain",
      "10 _Kids Plain Bloomer t", "10 Stylus Plain Bloomer"
    ],
    "Seri Plain": [
      "R Seri Plain", "seri plain", "Seri plain", "SERI PLAIN"
    ],
  };

  static final List<String> sizeSequence = [
    "0-2 Months", "0-3 Months", "0-6 Months", "3-6 Months", "6-9 Months",
    "6-12 Months", "9-12 Months", "12-18 Months", "18-24 Months",
    "0-1 Years", "1-2 Years", "2-3 Years", "3-4 Years", "4-5 Years",
    "5-6 Years", "6-7 Years", "7-8 Years", "8-9 Years", "9-10 Years",
    "10-11 Years", "11-12 Years", "12-13 Years", "13-14 Years", "14-15 Years", "15-16 Years",
    "24", "26", "28", "30", "32", "34", "36", "38", "40", "42", "44",
    "45", "46", "48", "50", "52", "55", "60", "65", "70", "75", "80",
    "85", "90", "95", "100", "105", "110", "115", "120",
    "70cm / XXS", "75cm / XS", "80cm / S", "85cm / M", "90cm / L",
    "95cm / XL", "100cm / 2XL", "105cm / 3XL", "110cm / 4XL", "115cm / 5XL", "120cm / 6XL",
    "Free Size", "FREE", "Multicolor",
  ];

  static final Map<String, String> letterToLabel = {
    "XXS": "70cm / XXS",
    "XS": "75cm / XS",
    "S": "80cm / S",
    "M": "85cm / M",
    "L": "90cm / L",
    "XL": "95cm / XL",
    "2XL": "100cm / 2XL",
    "XXL": "100cm / 2XL",
    "3XL": "105cm / 3XL",
    "XXXL": "105cm / 3XL",
    "4XL": "110cm / 4XL",
    "XXXXL": "110cm / 4XL",
    "5XL": "115cm / 5XL",
    "6XL": "120cm / 6XL",
  };

  static final Map<int, String> cmToLabel = {
    70: "70cm / XXS",
    75: "75cm / XS",
    80: "80cm / S",
    85: "85cm / M",
    90: "90cm / L",
    95: "95cm / XL",
    100: "100cm / 2XL",
    105: "105cm / 3XL",
    110: "110cm / 4XL",
    115: "115cm / 5XL",
    120: "120cm / 6XL",
  };

  static final Set<String> forceMulticolorSkus = {
    "PLAIN BLOOMER",
    "PRINTED BLOOMER",
    "TRUNKS",
    "TRUNKS IE",
    "PLAIN PANTY",
  };

  /// Clean & normalize raw SKU to canonical name
  static String normalizeSku(String rawSku) {
    if (rawSku.trim().isEmpty) return "Unsorted";
    final lower = rawSku.trim().toLowerCase();

    // Check exact variants
    for (final entry in defaultSkuVariants.entries) {
      for (final variant in entry.value) {
        if (lower == variant.toLowerCase()) {
          return entry.key;
        }
      }
    }

    // Check substring match for variants
    for (final entry in defaultSkuVariants.entries) {
      for (final variant in entry.value) {
        if (lower.contains(variant.toLowerCase())) {
          return entry.key;
        }
      }
    }

    // Heuristics
    if (lower.contains("bloomer")) {
      if (lower.contains("print")) return "Printed Bloomer";
      if (lower.contains("kids")) return "Kids Plain Bloomer";
      return "Plain Bloomer";
    }
    if (lower.contains("panty")) return "Plain Panty";
    if (lower.contains("button")) {
      if (lower.contains("print")) return "Button Print";
      return "Button Plain";
    }
    if (lower.contains("t-shirt") || lower.contains("tshirt")) return "Kids T-Shirt";
    if (lower.contains("trunk")) return "Trunks IE";
    if (lower.contains("seri")) return "Seri Print";

    return rawSku.trim();
  }

  /// Normalize raw size string into standardized label
  static String normalizeSize(String rawSize) {
    final cleaned = rawSize.trim();
    if (cleaned.isEmpty) return "Free Size";

    final upper = cleaned.toUpperCase();
    if (letterToLabel.containsKey(upper)) {
      return letterToLabel[upper]!;
    }

    if (upper == "FREE" || upper == "FREE SIZE" || upper == "FS") {
      return "Free Size";
    }

    // Match CM format e.g. "80cm"
    final cmMatch = RegExp(r'^(\d{2,3})\s*cm[s]?$', caseSensitive: false).firstMatch(cleaned);
    if (cmMatch != null) {
      final val = int.tryParse(cmMatch.group(1)!);
      if (val != null && cmToLabel.containsKey(val)) {
        return cmToLabel[val]!;
      }
    }

    // Bare number in cm list
    final bareVal = int.tryParse(cleaned);
    if (bareVal != null && cmToLabel.containsKey(bareVal)) {
      return cmToLabel[bareVal]!;
    }

    // Age ranges
    final monthsMatch = RegExp(r'^(\d{1,2})\s*[-/]\s*(\d{1,2})\s*(?:months|m)$', caseSensitive: false).firstMatch(cleaned);
    if (monthsMatch != null) {
      return "${monthsMatch.group(1)}-${monthsMatch.group(2)} Months";
    }

    final yearsMatch = RegExp(r'^(\d{1,2})\s*[-/]\s*(\d{1,2})\s*(?:years|y)$', caseSensitive: false).firstMatch(cleaned);
    if (yearsMatch != null) {
      return "${yearsMatch.group(1)}-${yearsMatch.group(2)} Years";
    }

    return cleaned;
  }

  /// Normalize color string
  static String normalizeColor(String rawColor, {String? sku}) {
    if (sku != null && forceMulticolorSkus.contains(sku.toUpperCase())) {
      return "Multicolor";
    }
    final trimmed = rawColor.trim();
    if (trimmed.isEmpty || trimmed.toUpperCase() == "NA" || trimmed.toUpperCase() == "N A") {
      return "Multicolor";
    }
    return trimmed;
  }

  /// Sort rank for SKU
  static int skuSortRank(String sku) {
    final idx = canonicalSkuOrder.indexWhere((s) => s.toLowerCase() == sku.toLowerCase());
    return idx >= 0 ? idx : 999;
  }

  /// Sort rank for Size
  static int sizeSortRank(String size) {
    final idx = sizeSequence.indexWhere((s) => s.toLowerCase() == size.toLowerCase());
    return idx >= 0 ? idx : 999;
  }
}
