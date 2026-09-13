import 'package:flutter/material.dart';
import '../models/inventory_item.dart';

class StockCounterDialog extends StatefulWidget {
  final InventoryItem item;
  final Function(int newQty, String reason) onConfirm;

  const StockCounterDialog({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  @override
  State<StockCounterDialog> createState() => _StockCounterDialogState();
}

class _StockCounterDialogState extends State<StockCounterDialog> {
  late int _quantity;
  String _reason = 'MANUAL_RESTOCK';

  final List<String> _reasons = [
    'MANUAL_RESTOCK',
    'PHYSICAL_AUDIT_ADJUSTMENT',
    'DAMAGED_ITEMS',
    'RETURN_RESTOCK',
    'OTHER_CORRECTION',
  ];

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Adjust Stock: ${widget.item.sku}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Size: ${widget.item.size} | Color: ${widget.item.color}",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (_quantity > 0) {
                    setState(() => _quantity--);
                  }
                },
                icon: const Icon(Icons.remove_circle_outline, size: 32, color: Colors.red),
              ),
              const SizedBox(width: 16),
              Text(
                "$_quantity",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline, size: 32, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Reason for update:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _reason,
            items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _reason = val);
            },
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_quantity, _reason);
            Navigator.of(context).pop();
          },
          child: const Text("Save Stock"),
        ),
      ],
    );
  }
}
