import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/label_batch_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/stock_counter_dialog.dart';
import 'scan_station_screen.dart';
import 'order_form_screen.dart';
import 'print_center_screen.dart';
import 'pick_list_screen.dart';
import 'manifest_screen.dart';
import 'settings_rules_screen.dart';

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
            tooltip: 'Refresh Inventory',
            onPressed: () => inventory.loadInventory(),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Settings & Rules',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsRulesScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => inventory.loadInventory(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade800, Colors.purple.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Warehouse Control Terminal',
                    style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Meesho Order Sorter & Cropper',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigo.shade900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => onNavigateTab(1), // Cropper tab
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Process Shipping PDF'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ScanStationScreen()),
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan'),
                      ),
                    ],
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
                  title: 'Total Stock Units',
                  value: '${inventory.totalStockUnits}',
                  icon: Icons.inventory_2,
                  color: Colors.blue.shade700,
                  onTap: () => onNavigateTab(2),
                ),
                StatCard(
                  title: 'Active SKUs',
                  value: '${inventory.totalSkus}',
                  icon: Icons.category,
                  color: Colors.teal.shade700,
                  onTap: () => onNavigateTab(2),
                ),
                StatCard(
                  title: 'Low Stock Alert',
                  value: '${inventory.lowStockItems.length}',
                  icon: Icons.warning_amber_rounded,
                  color: inventory.lowStockItems.isEmpty ? Colors.green.shade700 : Colors.red.shade700,
                  onTap: () => onNavigateTab(2),
                ),
                StatCard(
                  title: 'Batches Processed',
                  value: '${batch.pastBatches.length}',
                  icon: Icons.history,
                  color: Colors.orange.shade800,
                  onTap: () => onNavigateTab(3),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Operations Hub
            const Text(
              'Quick Operations Hub',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                _HubCard(
                  title: 'Scan Station',
                  icon: Icons.qr_code_scanner,
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScanStationScreen()),
                    );
                  },
                ),
                _HubCard(
                  title: 'Print Center',
                  icon: Icons.print,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrintCenterScreen()),
                    );
                  },
                ),
                _HubCard(
                  title: 'Cutting Plan',
                  icon: Icons.content_cut,
                  color: Colors.pink,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrderFormScreen()),
                    );
                  },
                ),
                _HubCard(
                  title: 'Pick List',
                  icon: Icons.checklist,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PickListScreen(items: batch.activeOrderItems),
                      ),
                    );
                  },
                ),
                _HubCard(
                  title: 'Manifest',
                  icon: Icons.local_shipping,
                  color: Colors.green,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ManifestScreen(items: batch.activeOrderItems),
                      ),
                    );
                  },
                ),
                _HubCard(
                  title: 'Reports',
                  icon: Icons.history,
                  color: Colors.orange,
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
                        'Low Stock Items (${inventory.lowStockItems.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => onNavigateTab(2),
                    child: const Text('View All'),
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
                  subtitle: Text('${item.size} • ${item.color}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.quantity} left',
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

            // Recent Audit History
            const Text(
              'Recent Stock Audit Log',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (inventory.movements.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No stock movements logged yet.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
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
                    m.qtyChange < 0 ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    color: m.qtyChange < 0 ? Colors.red : Colors.green,
                  ),
                  title: Text(
                    '${m.sku} (${m.size}): ${m.qtyChange > 0 ? "+" : ""}${m.qtyChange} pcs',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${m.reason} • ${m.movementAt}'),
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
