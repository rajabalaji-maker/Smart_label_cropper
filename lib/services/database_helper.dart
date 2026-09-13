import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/inventory_item.dart';
import '../models/order_item.dart';
import '../models/import_batch.dart';
import '../models/stock_movement.dart';
import 'normalization_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('drenx_inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add missing tables and columns safely
          await db.execute('CREATE TABLE IF NOT EXISTS sku_master_colors (sku TEXT NOT NULL, color TEXT NOT NULL, PRIMARY KEY(sku, color))');
          await db.execute('CREATE TABLE IF NOT EXISTS sku_master_sizes (sku TEXT NOT NULL, size TEXT NOT NULL, PRIMARY KEY(sku, size))');
          await db.execute('CREATE TABLE IF NOT EXISTS normalization_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, rule_type TEXT NOT NULL, pattern TEXT NOT NULL, sku TEXT NOT NULL, color TEXT NOT NULL, size TEXT NOT NULL, created_at TEXT NOT NULL)');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        updated_at TEXT NOT NULL,
        UNIQUE(sku, color, size)
      )
    ''');

    await db.execute('''
      CREATE TABLE imports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        platform TEXT NOT NULL,
        file_path TEXT,
        imported_at TEXT NOT NULL,
        total_items INTEGER NOT NULL DEFAULT 0,
        sorted_label_pdf TEXT,
        without_xpress_pdf TEXT,
        xpress_bees_pdf TEXT,
        pick_list_pdf TEXT,
        summary_pdf TEXT,
        courier_manifest_pdf TEXT,
        undone_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        import_id INTEGER NOT NULL,
        platform TEXT NOT NULL,
        order_no TEXT NOT NULL,
        raw_sku TEXT,
        sku TEXT NOT NULL,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        qty INTEGER NOT NULL DEFAULT 1,
        courier_partner TEXT NOT NULL DEFAULT 'Others',
        awb_no TEXT,
        pincode TEXT,
        state TEXT,
        price REAL DEFAULT 0.0,
        imported_at TEXT NOT NULL,
        FOREIGN KEY(import_id) REFERENCES imports(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movement_at TEXT NOT NULL,
        reason TEXT NOT NULL,
        import_id INTEGER,
        sku TEXT NOT NULL,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        qty_change INTEGER NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sku_master (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT UNIQUE NOT NULL,
        bin_location TEXT DEFAULT 'UNMAPPED',
        low_stock_threshold INTEGER DEFAULT 5,
        active INTEGER DEFAULT 1,
        notes TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sku_master_colors (
        sku TEXT NOT NULL,
        color TEXT NOT NULL,
        PRIMARY KEY(sku, color)
      )
    ''');

    await db.execute('''
      CREATE TABLE sku_master_sizes (
        sku TEXT NOT NULL,
        size TEXT NOT NULL,
        PRIMARY KEY(sku, size)
      )
    ''');

    await db.execute('''
      CREATE TABLE normalization_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rule_type TEXT NOT NULL,
        pattern TEXT NOT NULL,
        sku TEXT NOT NULL,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE system_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Pre-populate default seed items
    final now = DateTime.now().toIso8601String();
    for (final sku in NormalizationService.canonicalSkuOrder.take(5)) {
      await db.insert('sku_master', {
        'sku': sku,
        'low_stock_threshold': 5,
        'active': 1,
        'bin_location': 'A-1',
        'updated_at': now,
      });

      for (final size in ["75cm / XS", "80cm / S", "85cm / M", "90cm / L"]) {
        await db.insert('inventory', {
          'sku': sku,
          'color': 'Multicolor',
          'size': size,
          'quantity': 50,
          'low_stock_threshold': 5,
          'updated_at': now,
        });
      }
    }

    // Default system settings
    await db.insert('system_settings', {'key': 'brand_name', 'value': 'Drenx'});
    await db.insert('system_settings', {'key': 'primary_keyword', 'value': 'Original For Recipient'});
    await db.insert('system_settings', {'key': 'secondary_keyword', 'value': 'Exchange'});
    await db.insert('system_settings', {'key': 'secondary_crop_percent', 'value': '0.80'});
  }

  // ================= INVENTORY OPERATIONS =================

  Future<List<InventoryItem>> getAllInventory() async {
    final db = await instance.database;
    final result = await db.query('inventory', orderBy: 'sku ASC, size ASC');
    return result.map((json) => InventoryItem.fromMap(json)).toList();
  }

  Future<List<InventoryItem>> getLowStockInventory() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT * FROM inventory WHERE quantity <= low_stock_threshold ORDER BY quantity ASC',
    );
    return result.map((json) => InventoryItem.fromMap(json)).toList();
  }

  Future<int> setInventoryStock(int id, int newQuantity, String reason) async {
    final db = await instance.database;
    final itemQuery = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
    if (itemQuery.isEmpty) return 0;

    final current = InventoryItem.fromMap(itemQuery.first);
    final delta = newQuantity - current.quantity;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'inventory',
      {'quantity': newQuantity, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    await db.insert('inventory_movements', {
      'movement_at': now,
      'reason': reason,
      'sku': current.sku,
      'color': current.color,
      'size': current.size,
      'qty_change': delta,
      'note': 'Manual stock update',
    });

    return 1;
  }

  Future<void> adjustStockForOrders({
    required List<OrderItem> items,
    required int importId,
    required bool isDeduction,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final factor = isDeduction ? -1 : 1;
    final reason = isDeduction ? "BATCH_IMPORT" : "UNDO_IMPORT";

    for (final item in items) {
      final existing = await db.query(
        'inventory',
        where: 'sku = ? AND color = ? AND size = ?',
        whereArgs: [item.sku, item.color, item.size],
      );

      final change = factor * item.qty;

      if (existing.isNotEmpty) {
        final currentQty = existing.first['quantity'] as int;
        final newQty = (currentQty + change).clamp(0, 999999);
        await db.update(
          'inventory',
          {'quantity': newQty, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else if (isDeduction) {
        // Create entry with zero or negative not allowed, initialize at 0
        await db.insert('inventory', {
          'sku': item.sku,
          'color': item.color,
          'size': item.size,
          'quantity': 0,
          'low_stock_threshold': 5,
          'updated_at': now,
        });
      }

      await db.insert('inventory_movements', {
        'movement_at': now,
        'reason': reason,
        'import_id': importId,
        'sku': item.sku,
        'color': item.color,
        'size': item.size,
        'qty_change': change,
        'note': isDeduction ? 'Order deduction' : 'Restored from undo',
      });
    }
  }

  // ================= BATCH & ORDER OPERATIONS =================

  Future<int> saveImportBatch({
    required ImportBatch batch,
    required List<OrderItem> items,
    required bool deductStock,
  }) async {
    final db = await instance.database;
    int importId = 0;

    await db.transaction((txn) async {
      importId = await txn.insert('imports', batch.toMap());

      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['import_id'] = importId;
        await txn.insert('order_items', itemMap);
      }
    });

    if (deductStock && importId > 0) {
      await adjustStockForOrders(
        items: items,
        importId: importId,
        isDeduction: true,
      );
    }

    return importId;
  }

  Future<bool> undoImport(int importId) async {
    final db = await instance.database;
    final batchQuery = await db.query('imports', where: 'id = ?', whereArgs: [importId]);
    if (batchQuery.isEmpty) return false;

    final batch = ImportBatch.fromMap(batchQuery.first);
    if (batch.isUndone) return false; // Already undone

    final itemsQuery = await db.query('order_items', where: 'import_id = ?', whereArgs: [importId]);
    final items = itemsQuery.map((json) => OrderItem.fromMap(json)).toList();

    await adjustStockForOrders(
      items: items,
      importId: importId,
      isDeduction: false, // restore stock
    );

    final now = DateTime.now().toIso8601String();
    await db.update(
      'imports',
      {'undone_at': now},
      where: 'id = ?',
      whereArgs: [importId],
    );

    return true;
  }

  Future<List<ImportBatch>> getAllImports() async {
    final db = await instance.database;
    final result = await db.query('imports', orderBy: 'id DESC');
    return result.map((json) => ImportBatch.fromMap(json)).toList();
  }

  Future<List<OrderItem>> getOrderItemsForImport(int importId) async {
    final db = await instance.database;
    final result = await db.query('order_items', where: 'import_id = ?', whereArgs: [importId]);
    return result.map((json) => OrderItem.fromMap(json)).toList();
  }

  Future<List<StockMovement>> getRecentMovements({int limit = 50}) async {
    final db = await instance.database;
    final result = await db.query(
      'inventory_movements',
      orderBy: 'id DESC',
      limit: limit,
    );
    return result.map((json) => StockMovement.fromMap(json)).toList();
  }

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await instance.database;
    final res = await db.query('system_settings', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return (res.first['value'] ?? defaultValue) as String;
    }
    return defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'system_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
