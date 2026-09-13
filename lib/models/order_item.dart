class OrderItem {
  final int? id;
  final int? importId;
  final String platform;
  final String orderNo;
  final String rawSku;
  final String sku;
  final String color;
  final String size;
  final int qty;
  final String courierPartner;
  final String importedAt;
  final int pageIndex; // Index in original or cropped PDF
  final bool multiOrder;
  final bool isKidsConversion;

  OrderItem({
    this.id,
    this.importId,
    required this.platform,
    required this.orderNo,
    required this.rawSku,
    required this.sku,
    required this.color,
    required this.size,
    required this.qty,
    this.courierPartner = 'Others',
    required this.importedAt,
    this.pageIndex = 0,
    this.multiOrder = false,
    this.isKidsConversion = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (importId != null) 'import_id': importId,
      'platform': platform,
      'order_no': orderNo,
      'raw_sku': rawSku,
      'sku': sku,
      'color': color,
      'size': size,
      'qty': qty,
      'courier_partner': courierPartner,
      'imported_at': importedAt,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      importId: map['import_id'] as int?,
      platform: (map['platform'] ?? 'Meesho') as String,
      orderNo: (map['order_no'] ?? '') as String,
      rawSku: (map['raw_sku'] ?? '') as String,
      sku: (map['sku'] ?? '') as String,
      color: (map['color'] ?? '') as String,
      size: (map['size'] ?? '') as String,
      qty: (map['qty'] ?? 1) as int,
      courierPartner: (map['courier_partner'] ?? 'Others') as String,
      importedAt: (map['imported_at'] ?? '') as String,
      pageIndex: 0,
      multiOrder: (map['multi_order'] == 1 || map['multi_order'] == true),
      isKidsConversion: (map['is_kids_conversion'] == 1 || map['is_kids_conversion'] == true),
    );
  }

  OrderItem copyWith({
    int? id,
    int? importId,
    String? platform,
    String? orderNo,
    String? rawSku,
    String? sku,
    String? color,
    String? size,
    int? qty,
    String? courierPartner,
    String? importedAt,
    int? pageIndex,
    bool? multiOrder,
    bool? isKidsConversion,
  }) {
    return OrderItem(
      id: id ?? this.id,
      importId: importId ?? this.importId,
      platform: platform ?? this.platform,
      orderNo: orderNo ?? this.orderNo,
      rawSku: rawSku ?? this.rawSku,
      sku: sku ?? this.sku,
      color: color ?? this.color,
      size: size ?? this.size,
      qty: qty ?? this.qty,
      courierPartner: courierPartner ?? this.courierPartner,
      importedAt: importedAt ?? this.importedAt,
      pageIndex: pageIndex ?? this.pageIndex,
      multiOrder: multiOrder ?? this.multiOrder,
      isKidsConversion: isKidsConversion ?? this.isKidsConversion,
    );
  }
}
