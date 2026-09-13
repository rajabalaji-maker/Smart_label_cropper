import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/order_item.dart';
import '../services/report_generator_service.dart';

class ManifestScreen extends StatelessWidget {
  final List<OrderItem> items;

  const ManifestScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // Group by courier
    final Map<String, List<OrderItem>> courierGroups = {};
    for (final item in items) {
      courierGroups.putIfAbsent(item.courierPartner, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Courier Handover Manifest"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: "Print / Share Manifest PDF",
            onPressed: () async {
              final pdfBytes = await ReportGeneratorService.generateManifestPdf(
                items: items,
              );
              await Printing.layoutPdf(
                onLayout: (format) async => pdfBytes,
                name: 'Courier_Manifest_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepOrange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Couriers Breakdown",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      "${courierGroups.length} logistics partners",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  "${items.length} Packages Total",
                  style: TextStyle(
                    color: Colors.deepOrange.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...courierGroups.entries.map((entry) {
            final courier = entry.key;
            final courierItems = entry.value;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepOrange.shade100,
                  child: Icon(Icons.local_shipping, color: Colors.deepOrange.shade800, size: 20),
                ),
                title: Text(
                  courier,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${courierItems.length} parcels to handover"),
                children: [
                  const Divider(height: 1),
                  ...courierItems.map(
                    (ci) => ListTile(
                      dense: true,
                      title: Text(ci.orderNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text("${ci.sku} (${ci.size})"),
                      trailing: Text("Qty: ${ci.qty}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              final pdfBytes = await ReportGeneratorService.generateManifestPdf(
                items: items,
              );
              await Printing.layoutPdf(
                onLayout: (format) async => pdfBytes,
                name: 'Courier_Manifest_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Print / Export Handover Sheet PDF"),
          ),
        ),
      ),
    );
  }
}
