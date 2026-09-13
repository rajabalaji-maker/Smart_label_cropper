import 'package:flutter/foundation.dart';
import '../services/database_helper.dart';

class SettingsProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  String _brandName = "Tony Max";
  String _primaryKeyword = "Original For Recipient";
  String _secondaryKeyword = "Exchange";
  double _secondaryCropPercent = 0.80;
  int _defaultLowStockThreshold = 5;

  String get brandName => _brandName;
  String get primaryKeyword => _primaryKeyword;
  String get secondaryKeyword => _secondaryKeyword;
  double get secondaryCropPercent => _secondaryCropPercent;
  int get defaultLowStockThreshold => _defaultLowStockThreshold;

  Future<void> loadSettings() async {
    _brandName = await _db.getSetting('brand_name', defaultValue: 'Tony Max');
    _primaryKeyword = await _db.getSetting('primary_keyword', defaultValue: 'Original For Recipient');
    _secondaryKeyword = await _db.getSetting('secondary_keyword', defaultValue: 'Exchange');
    final cropStr = await _db.getSetting('secondary_crop_percent', defaultValue: '0.80');
    _secondaryCropPercent = double.tryParse(cropStr) ?? 0.80;
    final threshStr = await _db.getSetting('default_low_stock_threshold', defaultValue: '5');
    _defaultLowStockThreshold = int.tryParse(threshStr) ?? 5;
    notifyListeners();
  }

  Future<void> updateBrandName(String name) async {
    _brandName = name;
    await _db.setSetting('brand_name', name);
    notifyListeners();
  }

  Future<void> updateKeywords({
    required String primary,
    required String secondary,
    required double percent,
  }) async {
    _primaryKeyword = primary;
    _secondaryKeyword = secondary;
    _secondaryCropPercent = percent;

    await _db.setSetting('primary_keyword', primary);
    await _db.setSetting('secondary_keyword', secondary);
    await _db.setSetting('secondary_crop_percent', percent.toString());
    notifyListeners();
  }
}
