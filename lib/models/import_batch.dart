class ImportBatch {
  final int? id;
  final String platform;
  final String filePath;
  final String importedAt;
  final int totalItems;
  final String? sortedLabelPdf;
  final String? pickListPdf;
  final String? summaryPdf;
  final String? courierManifestPdf;
  final String? undoneAt;

  ImportBatch({
    this.id,
    required this.platform,
    required this.filePath,
    required this.importedAt,
    required this.totalItems,
    this.sortedLabelPdf,
    this.pickListPdf,
    this.summaryPdf,
    this.courierManifestPdf,
    this.undoneAt,
  });

  bool get isUndone => undoneAt != null && undoneAt!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'platform': platform,
      'file_path': filePath,
      'imported_at': importedAt,
      'total_items': totalItems,
      'sorted_label_pdf': sortedLabelPdf,
      'pick_list_pdf': pickListPdf,
      'summary_pdf': summaryPdf,
      'courier_manifest_pdf': courierManifestPdf,
      'undone_at': undoneAt,
    };
  }

  factory ImportBatch.fromMap(Map<String, dynamic> map) {
    return ImportBatch(
      id: map['id'] as int?,
      platform: (map['platform'] ?? 'Meesho') as String,
      filePath: (map['file_path'] ?? '') as String,
      importedAt: (map['imported_at'] ?? '') as String,
      totalItems: (map['total_items'] ?? 0) as int,
      sortedLabelPdf: map['sorted_label_pdf'] as String?,
      pickListPdf: map['pick_list_pdf'] as String?,
      summaryPdf: map['summary_pdf'] as String?,
      courierManifestPdf: map['courier_manifest_pdf'] as String?,
      undoneAt: map['undone_at'] as String?,
    );
  }
}
