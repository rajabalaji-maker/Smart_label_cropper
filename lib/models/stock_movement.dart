class StockMovement {
  final int? id;
  final String movementAt;
  final String reason;
  final int? importId;
  final String sku;
  final String color;
  final String size;
  final int qtyChange;
  final String? note;

  StockMovement({
    this.id,
    required this.movementAt,
    required this.reason,
    this.importId,
    required this.sku,
    required this.color,
    required this.size,
    required this.qtyChange,
    this.note,
  });

  int get qtyDelta => qtyChange;
  String get timestamp => movementAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'movement_at': movementAt,
      'reason': reason,
      if (importId != null) 'import_id': importId,
      'sku': sku,
      'color': color,
      'size': size,
      'qty_change': qtyChange,
      'note': note,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      movementAt: (map['movement_at'] ?? '') as String,
      reason: (map['reason'] ?? '') as String,
      importId: map['import_id'] as int?,
      sku: (map['sku'] ?? '') as String,
      color: (map['color'] ?? '') as String,
      size: (map['size'] ?? '') as String,
      qtyChange: (map['qty_change'] ?? 0) as int,
      note: map['note'] as String?,
    );
  }
}
