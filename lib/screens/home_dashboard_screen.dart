import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/label_batch_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/stock_counter_dialog.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int tabIndex) onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final batch = context.watch<LabelBatchProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.brandName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => inventory.loadInventory(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => onNavigateTab(4), // settings tab
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => inventory.loadInventory(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Warehouse Control Center",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Meesho Order Sorter & Label Cropper",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => onNavigateTab(1), // Cropper tab
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text("Process Shipping PDF"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stat Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                StatCard(
                  title: "Total Stock",
                  value: "${inventory.totalStockUnits}",
                  icon: Icons.inventory_2,
                  color: Colors.blue.shade700,
                  onTap: () => onNavigateTab(2),
                ),
                StatCard(
                  title: "Active SKUs",
                  value: "${inventory.totalSkus}",
                  icon: Icons.category,
                  color: Colors.teal.shade700,
                  onTap: () => onNavigateTab(2),
                ),
                StatCard(
                  title: "Low Stock Alert",
                  value: "${inventory.lowStockItems.length}",
                  icon: Icons.warning_amber_rounded,
                  color: inventory.lowStockItems.isEmpty ? Colors.green.shade700 : Colors.red.shade700,
                  onTap: () => onNavigateTab(2),
                ),
                StatCard(
                  title: "Batches Done",
                  value: "${batch.pastBatches.length}",
                  icon: Icons.history,
                  color: Colors.orange.shade800,
                  onTap: () => onNavigateTab(3),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Low Stock Warning Section
            if (inventory.lowStockItems.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "Low Stock Items (${inventory.lowStockItems.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => onNavigateTab(2),
                    child: const Text("View All"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...inventory.lowStockItems.take(4).map((item) => Card(
                elevation: 0,
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: ListTile(
                  title: Text(
                    item.sku,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text("${item.size} • ${item.color}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${item.quantity} left",
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => StockCounterDialog(
                              item: item,
                              onConfirm: (newQty, reason) =>
                                  inventory.updateStock(item.id!, newQty, reason),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 20),
            ],

            // Recent Movements
            const Text(
              "Recent Stock Audit History",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (inventory.movements.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text("No stock movements recorded yet.")),
              )
            else
              ...inventory.movements.take(5).map((m) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    m.qtyChange > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    color: m.qtyChange > 0 ? Colors.green : Colors.red,
                  ),
                  title: Text("${m.sku} (${m.size})"),
                  subtitle: Text(m.reason),
                  trailing: Text(
                    "${m.qtyChange > 0 ? '+' : ''}${m.qtyChange}",
                    style: TextStyle(
                      color: m.qtyChange > 0 ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}
