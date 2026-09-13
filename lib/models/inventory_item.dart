class InventoryItem {
  final int? id;
  final String sku;
  final String color;
  final String size;
  int quantity;
  int lowStockThreshold;
  final String updatedAt;

  InventoryItem({
    this.id,
    required this.sku,
    required this.color,
    required this.size,
    required this.quantity,
    this.lowStockThreshold = 5,
    required this.updatedAt,
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sku': sku,
      'color': color,
      'size': size,
      'quantity': quantity,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': updatedAt,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      sku: (map['sku'] ?? '') as String,
      color: (map['color'] ?? '') as String,
      size: (map['size'] ?? '') as String,
      quantity: (map['quantity'] ?? 0) as int,
      lowStockThreshold: (map['low_stock_threshold'] ?? 5) as int,
      updatedAt: (map['updated_at'] ?? '') as String,
    );
  }

  InventoryItem copyWith({
    int? id,
    String? sku,
    String? color,
    String? size,
    int? quantity,
    int? lowStockThreshold,
    String? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      color: color ?? this.color,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
