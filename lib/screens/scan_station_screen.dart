import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../providers/label_batch_provider.dart';

enum ScanMode { lookup, dispatch, restock }

class ScanStationScreen extends StatefulWidget {
  const ScanStationScreen({super.key});

  @override
  State<ScanStationScreen> createState() => _ScanStationScreenState();
}

class _ScanStationScreenState extends State<ScanStationScreen> {
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ScanMode _currentMode = ScanMode.lookup;
  String? _statusMessage;
  bool _isSuccess = true;
  final List<Map<String, dynamic>> _scanHistory = [];

  @override
  void dispose() {
    _scanController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _processScan(String query) {
    final q = query.trim();
    if (q.isEmpty) return;

    final inventory = context.read<InventoryProvider>();
    final batch = context.read<LabelBatchProvider>();

    // 1. Try finding in active batch orders by AWB or Order No
    String? foundSku;
    String? foundSize;
    for (final order in batch.activeOrderItems) {
      if (order.orderNo.toLowerCase() == q.toLowerCase() ||
          order.rawSku.toLowerCase().contains(q.toLowerCase()) ||
          order.sku.toLowerCase().contains(q.toLowerCase())) {
        foundSku = order.sku;
        foundSize = order.size;
        break;
      }
    }

    // 2. Try finding in inventory
    InventoryItem? item;
    if (foundSku != null && foundSize != null) {
      item = inventory.findItem(foundSku, foundSize);
    }

    if (item == null) {
      // Direct search in inventory items
      for (final inv in inventory.items) {
        if (inv.sku.toLowerCase() == q.toLowerCase() ||
            '${inv.sku} ${inv.size}'.toLowerCase() == q.toLowerCase() ||
            '${inv.sku}-${inv.size}'.toLowerCase() == q.toLowerCase()) {
          item = inv;
          break;
        }
      }
    }

    if (item == null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSuccess = false;
        _statusMessage = 'No matching SKU or Order found for: "$q"';
      });
      _scanController.clear();
      _focusNode.requestFocus();
      return;
    }

    final validItem = item;

    // Process according to mode
    if (_currentMode == ScanMode.lookup) {
      HapticFeedback.lightImpact();
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Found: ${validItem.sku} (${validItem.size}) • ${validItem.quantity} in stock';
        _scanHistory.insert(0, {
          'time': DateTime.now(),
          'sku': validItem.sku,
          'size': validItem.size,
          'action': 'Lookup',
          'stock': validItem.quantity,
          'query': q,
        });
      });
    } else if (_currentMode == ScanMode.dispatch) {
      HapticFeedback.mediumImpact();
      final newQty = validItem.quantity > 0 ? validItem.quantity - 1 : 0;
      if (validItem.id != null) {
        inventory.updateStock(validItem.id!, newQty, 'Scan Dispatch: $q');
      }
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Dispatched 1 pc of ${validItem.sku} (${validItem.size}). Remaining: $newQty';
        _scanHistory.insert(0, {
          'time': DateTime.now(),
          'sku': validItem.sku,
          'size': validItem.size,
          'action': 'Dispatched (-1)',
          'stock': newQty,
          'query': q,
        });
      });
    } else if (_currentMode == ScanMode.restock) {
      HapticFeedback.mediumImpact();
      final newQty = validItem.quantity + 1;
      if (validItem.id != null) {
        inventory.updateStock(validItem.id!, newQty, 'Scan Restock: $q');
      }
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Restocked 1 pc of ${validItem.sku} (${validItem.size}). New Stock: $newQty';
        _scanHistory.insert(0, {
          'time': DateTime.now(),
          'sku': validItem.sku,
          'size': validItem.size,
          'action': 'Restocked (+1)',
          'stock': newQty,
          'query': q,
        });
      });
    }

    _scanController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Station Terminal'),
      ),
      body: Column(
        children: [
          // Mode Selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ChoiceChip(
                  label: const Text('🔍 Lookup'),
                  selected: _currentMode == ScanMode.lookup,
                  onSelected: (val) {
                    if (val) setState(() => _currentMode = ScanMode.lookup);
                  },
                ),
                ChoiceChip(
                  label: const Text('📉 Dispatch (-1)'),
                  selected: _currentMode == ScanMode.dispatch,
                  selectedColor: Colors.red.shade100,
                  onSelected: (val) {
                    if (val) setState(() => _currentMode = ScanMode.dispatch);
                  },
                ),
                ChoiceChip(
                  label: const Text('📦 Restock (+1)'),
                  selected: _currentMode == ScanMode.restock,
                  selectedColor: Colors.green.shade100,
                  onSelected: (val) {
                    if (val) setState(() => _currentMode = ScanMode.restock);
                  },
                ),
              ],
            ),
          ),

          // Input field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scanController,
                    focusNode: _focusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Scan Barcode / Enter AWB / SKU',
                      hintText: 'Type or scan barcode...',
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      suffixIcon: _scanController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _scanController.clear(),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: _processScan,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                  onPressed: () => _processScan(_scanController.text),
                  child: const Text('Scan'),
                ),
              ],
            ),
          ),

          // Status Feedback Banner
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 24),

          // Scan History List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Activity History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (_scanHistory.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _scanHistory.clear()),
                    child: const Text('Clear History'),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _scanHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.barcode_reader, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Ready to scan barcodes or order IDs',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _scanHistory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _scanHistory[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item['action'].toString().contains('Dispatch')
                              ? Colors.red.shade100
                              : item['action'].toString().contains('Restock')
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                          child: Icon(
                            item['action'].toString().contains('Dispatch')
                                ? Icons.arrow_downward
                                : item['action'].toString().contains('Restock')
                                    ? Icons.arrow_upward
                                    : Icons.search,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          '${item["sku"]} (${item["size"]})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Query: ${item["query"]} • Stock: ${item["stock"]}'),
                        trailing: Text(
                          item['action'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item['action'].toString().contains('Dispatch')
                                ? Colors.red.shade700
                                : item['action'].toString().contains('Restock')
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
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
