import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/order_item.dart';
import '../services/report_generator_service.dart';

class PickListScreen extends StatefulWidget {
  final List<OrderItem> items;

  const PickListScreen({super.key, required this.items});

  @override
  State<PickListScreen> createState() => _PickListScreenState();
}

class _PickListScreenState extends State<PickListScreen> {
  final Set<String> _checkedKeys = {};

  @override
  Widget build(BuildContext context) {
    // Group items
    final Map<String, int> grouped = {};
    for (final item in widget.items) {
      final key = "${item.sku} | Size: ${item.size} | Color: ${item.color}";
      grouped[key] = (grouped[key] ?? 0) + item.qty;
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final totalUnits = widget.items.fold<int>(0, (sum, item) => sum + item.qty);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Warehouse Pick List"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: "Print / Share Pick List PDF",
            onPressed: () async {
              final pdfBytes = await ReportGeneratorService.generatePickListPdf(
                items: widget.items,
              );
              await Printing.layoutPdf(
                onLayout: (format) async => pdfBytes,
                name: 'Pick_List_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Items to Pick: ${entries.length} variations",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      "Checked: ${_checkedKeys.length} of ${entries.length}",
                      style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$totalUnits Units Total",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isChecked = _checkedKeys.contains(entry.key);

                return CheckboxListTile(
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _checkedKeys.add(entry.key);
                      } else {
                        _checkedKeys.remove(entry.key);
                      }
                    });
                  },
                  title: Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked ? Colors.grey : Colors.black87,
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isChecked ? Colors.grey.shade200 : Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "${entry.value}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isChecked ? Colors.grey : Colors.indigo.shade900,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              final pdfBytes = await ReportGeneratorService.generatePickListPdf(
                items: widget.items,
              );
              await Printing.layoutPdf(
                onLayout: (format) async => pdfBytes,
                name: 'Pick_List_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Print / Export Pick List PDF"),
          ),
        ),
      ),
    );
  }
}
