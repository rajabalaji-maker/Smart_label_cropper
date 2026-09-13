import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/inventory_provider.dart';
import '../providers/label_batch_provider.dart';
import '../providers/settings_provider.dart';
import '../services/normalization_service.dart';
import '../services/report_generator_service.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  String _selectedSkuFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final batch = context.watch<LabelBatchProvider>();
    final inventory = context.watch<InventoryProvider>();
    final settings = context.watch<SettingsProvider>();

    // Calculate aggregated demand from active batch or recent batches
    final Map<String, Map<String, int>> demand = {};
    for (final item in batch.activeOrderItems) {
      final sizeMap = demand.putIfAbsent(item.sku, () => {});
      sizeMap[item.size] = (sizeMap[item.size] ?? 0) + item.qty;
    }

    // Build rows of SKU, Size, Ordered, Current Stock, Shortage
    final List<Map<String, dynamic>> planRows = [];
    int totalOrdered = 0;
    int totalShortage = 0;

    for (final skuEntry in demand.entries) {
      final sku = skuEntry.key;
      for (final sizeEntry in skuEntry.value.entries) {
        final size = sizeEntry.key;
        final orderedQty = sizeEntry.value;

        final invItem = inventory.findItem(sku, size);
        final currentStock = invItem?.quantity ?? 0;
        final shortage = (orderedQty > currentStock) ? (orderedQty - currentStock) : 0;

        totalOrdered += orderedQty;
        totalShortage += shortage;

        if (_selectedSkuFilter == 'All' || _selectedSkuFilter == sku) {
          planRows.add({
            'sku': sku,
            'size': size,
            'ordered': orderedQty,
            'stock': currentStock,
            'shortage': shortage,
          });
        }
      }
    }

    // Sort by SKU rank then Size rank
    planRows.sort((a, b) {
      final sCmp = NormalizationService.skuSortRank(a['sku']).compareTo(
        NormalizationService.skuSortRank(b['sku']),
      );
      if (sCmp != 0) return sCmp;
      return NormalizationService.sizeSortRank(a['size']).compareTo(
        NormalizationService.sizeSortRank(b['size']),
      );
    });

    final allSkus = ['All', ...demand.keys.toList()..sort()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cutting & Stitching Order Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Stitching Plan PDF',
            onPressed: planRows.isEmpty
                ? null
                : () => _exportAndSharePlanPdf(context, planRows, settings.brandName, totalOrdered, totalShortage),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryCol(title: 'Total Needed', value: '$totalOrdered pcs', color: Colors.indigo.shade900),
                _SummaryCol(title: 'Active Items', value: '${planRows.length} lines', color: Colors.blue.shade900),
                _SummaryCol(
                  title: 'To Stitch (Short)',
                  value: '$totalShortage pcs',
                  color: totalShortage > 0 ? Colors.red.shade900 : Colors.green.shade900,
                ),
              ],
            ),
          ),

          // Filter bar
          if (demand.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Filter SKU: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedSkuFilter,
                    isDense: true,
                    items: allSkus.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSkuFilter = val);
                    },
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Plan Table
          Expanded(
            child: planRows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.content_cut, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No active orders found.',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Process shipping labels in the Cropper tab first, or load a batch to view the production cutting plan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: planRows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = planRows[index];
                      final int shortage = row['shortage'];
                      return Container(
                        color: shortage > 0 ? Colors.red.shade50.withOpacity(0.5) : Colors.transparent,
                        child: ListTile(
                          title: Text(
                            '${row['sku']} • ${row['size']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text('Demand: ${row['ordered']} pcs | Cur Stock: ${row['stock']} pcs'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: shortage > 0 ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              shortage > 0 ? 'CUT $shortage' : 'IN STOCK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: shortage > 0 ? Colors.red.shade900 : Colors.green.shade900,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAndSharePlanPdf(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    String brand,
    int totalOrdered,
    int totalShortage,
  ) async {
    final bytes = await ReportGeneratorService.generateCuttingPlanPdf(
      rows: rows,
      brand: brand,
      totalOrdered: totalOrdered,
      totalShortage: totalShortage,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/stitching_order_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Cutting & Stitching Order Form');
  }
}

class _SummaryCol extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCol({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
