import 'package:flutter/foundation.dart';
import '../models/inventory_item.dart';
import '../models/stock_movement.dart';
import '../services/database_helper.dart';

class InventoryProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<InventoryItem> _items = [];
  List<InventoryItem> _lowStockItems = [];
  List<StockMovement> _movements = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _skuFilter;

  List<InventoryItem> get items => _items;
  List<InventoryItem> get lowStockItems => _lowStockItems;
  List<StockMovement> get movements => _movements;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get skuFilter => _skuFilter;

  int get totalStockUnits => _items.fold(0, (sum, item) => sum + item.quantity);
  int get totalSkus => _items.map((e) => e.sku).toSet().length;

  List<InventoryItem> get filteredItems {
    return _items.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.size.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.color.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesSku = _skuFilter == null || _skuFilter!.isEmpty || item.sku == _skuFilter;

      return matchesSearch && matchesSku;
    }).toList();
  }

  Future<void> loadInventory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _db.getAllInventory();
      _lowStockItems = await _db.getLowStockInventory();
      _movements = await _db.getRecentMovements(limit: 40);
    } catch (e) {
      debugPrint("Error loading inventory: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStock(int id, int newQuantity, String reason) async {
    await _db.setInventoryStock(id, newQuantity, reason);
    await loadInventory();
  }

  Future<void> quickAdjust(int id, int delta) async {
    final item = _items.firstWhere((element) => element.id == id);
    final newQty = (item.quantity + delta).clamp(0, 999999);
    final reason = delta > 0 ? "MANUAL_RESTOCK" : "MANUAL_REDUCTION";
    await updateStock(id, newQty, reason);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSkuFilter(String? sku) {
    _skuFilter = sku;
    notifyListeners();
  }
}
