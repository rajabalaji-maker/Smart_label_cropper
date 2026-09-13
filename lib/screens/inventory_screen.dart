import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../services/normalization_service.dart';
import '../widgets/stock_counter_dialog.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => inventory.loadInventory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search SKU, size, or color...",
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: inventory.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => inventory.setSearchQuery(''),
                      )
                    : null,
              ),
              onChanged: (val) => inventory.setSearchQuery(val),
            ),
          ),

          // SKU Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text("All"),
                  selected: inventory.skuFilter == null,
                  onSelected: (_) => inventory.setSkuFilter(null),
                ),
                const SizedBox(width: 6),
                ...NormalizationService.canonicalSkuOrder.map((sku) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Text(sku),
                      selected: inventory.skuFilter == sku,
                      onSelected: (selected) {
                        inventory.setSkuFilter(selected ? sku : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Inventory List
          Expanded(
            child: inventory.isLoading
                ? const Center(child: CircularProgressIndicator())
                : inventory.filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          "No inventory found.",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: inventory.filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = inventory.filteredItems[index];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: item.isLowStock
                                    ? Colors.red.shade300
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                item.sku,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "Size: ${item.size} • Color: ${item.color}",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () => inventory.quickAdjust(item.id!, -1),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => StockCounterDialog(
                                          item: item,
                                          onConfirm: (newQty, reason) =>
                                              inventory.updateStock(item.id!, newQty, reason),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: item.isLowStock
                                            ? Colors.red.shade50
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${item.quantity}",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: item.isLowStock
                                              ? Colors.red.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    onPressed: () => inventory.quickAdjust(item.id!, 1),
                                  ),
                                ],
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
}
