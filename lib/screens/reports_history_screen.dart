import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/label_batch_provider.dart';
import '../providers/inventory_provider.dart';

class ReportsHistoryScreen extends StatelessWidget {
  const ReportsHistoryScreen({super.key});

  Future<void> _exportInventoryCsv(BuildContext context) async {
    final inventory = context.read<InventoryProvider>();
    final items = inventory.items;

    List<List<dynamic>> rows = [
      ["SKU", "Color", "Size", "Quantity", "Low Stock Threshold", "Updated At"]
    ];

    for (final item in items) {
      rows.add([
        item.sku,
        item.color,
        item.size,
        item.quantity,
        item.lowStockThreshold,
        item.updatedAt,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/inventory_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvString);

    await Share.shareXFiles([XFile(file.path)], text: "Inventory Stock CSV Export");
  }

  @override
  Widget build(BuildContext context) {
    final batch = context.watch<LabelBatchProvider>();
    final inventory = context.read<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Batch History & Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export Stock CSV",
            onPressed: () => _exportInventoryCsv(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => batch.loadPastBatches(),
          ),
        ],
      ),
      body: batch.pastBatches.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No past batches yet."),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _exportInventoryCsv(context),
                    icon: const Icon(Icons.file_download),
                    label: const Text("Export Stock CSV"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: batch.pastBatches.length,
              itemBuilder: (context, index) {
                final item = batch.pastBatches[index];

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: item.isUndone ? Colors.grey.shade300 : Colors.indigo.shade200,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Batch #${item.id} • ${item.platform}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: item.isUndone ? Colors.grey : Colors.indigo.shade900,
                              ),
                            ),
                            if (item.isUndone)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "UNDONE / RESTORED",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              )
                            else
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Undo This Batch?"),
                                      content: const Text(
                                        "This will restore all inventory deductions made when this batch was processed.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text("Undo & Restore Stock"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true && item.id != null) {
                                    final success = await batch.undoBatch(item.id!);
                                    if (success) {
                                      await inventory.loadInventory();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Batch successfully undone and stock restored.")),
                                        );
                                      }
                                    }
                                  }
                                },
                                icon: const Icon(Icons.undo, size: 16),
                                label: const Text("Undo"),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Imported: ${item.importedAt.replaceAll('T', ' ').substring(0, 19)}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        Text(
                          "Total Labels: ${item.totalItems}",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (item.sortedLabelPdf != null && File(item.sortedLabelPdf!).existsSync())
                              OutlinedButton.icon(
                                onPressed: () {
                                  Share.shareXFiles([XFile(item.sortedLabelPdf!)], text: "Cropped Labels PDF");
                                },
                                icon: const Icon(Icons.picture_as_pdf, size: 14),
                                label: const Text("Labels", style: TextStyle(fontSize: 12)),
                              ),
                            if (item.pickListPdf != null && File(item.pickListPdf!).existsSync())
                              OutlinedButton.icon(
                                onPressed: () {
                                  Share.shareXFiles([XFile(item.pickListPdf!)], text: "Pick List PDF");
                                },
                                icon: const Icon(Icons.checklist, size: 14),
                                label: const Text("Pick List", style: TextStyle(fontSize: 12)),
                              ),
                            if (item.courierManifestPdf != null && File(item.courierManifestPdf!).existsSync())
                              OutlinedButton.icon(
                                onPressed: () {
                                  Share.shareXFiles([XFile(item.courierManifestPdf!)], text: "Manifest PDF");
                                },
                                icon: const Icon(Icons.local_shipping, size: 14),
                                label: const Text("Manifest", style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
