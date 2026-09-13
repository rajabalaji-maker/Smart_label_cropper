import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/label_batch_provider.dart';
import '../widgets/order_item_card.dart';
import 'pick_list_screen.dart';
import 'manifest_screen.dart';
import 'print_center_screen.dart';
import 'order_form_screen.dart';

class LabelCropperScreen extends StatefulWidget {
  const LabelCropperScreen({super.key});

  @override
  State<LabelCropperScreen> createState() => _LabelCropperScreenState();
}

class _LabelCropperScreenState extends State<LabelCropperScreen> {
  bool _deductStock = true;
  List<PlatformFile> _selectedFiles = [];

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting files: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = context.watch<LabelBatchProvider>();
    final inventory = context.read<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Label Cropper & Sorter"),
        actions: [
          if (batch.activeOrderItems.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Print & Export Hub",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrintCenterScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.content_cut),
              tooltip: "Cutting Plan",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OrderFormScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Clear Batch",
              onPressed: () {
                setState(() => _selectedFiles = []);
                batch.clearActiveBatch();
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // File Picker / Status Area
          if (batch.activeOrderItems.isEmpty) ...[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 72,
                        color: Colors.indigo.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Crop & Sort Shipping Labels",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Select one or multiple Meesho / Ecommerce PDF shipping labels.\n"
                        "The app will automatically crop above 'Original For Recipient',\n"
                        "stamp quantity alerts, sort by SKU & size, and update stock.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      if (_selectedFiles.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            "${_selectedFiles.length} PDF file(s) selected",
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.folder_open),
                            label: Text(_selectedFiles.isEmpty ? "Select PDF Files" : "Change Files"),
                          ),
                          if (_selectedFiles.isNotEmpty && !batch.isProcessing) ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final success = await batch.processPlatformFiles(_selectedFiles);
                                if (!mounted) return;
                                if (!success) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text("Processing Failed"),
                                        ],
                                      ),
                                      content: SelectableText(
                                        batch.lastError ?? batch.statusMessage,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text("OK"),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text("Process Labels"),
                            ),
                          ],
                        ],
                      ),
                      if (batch.isProcessing) ...[
                        const SizedBox(height: 24),
                        LinearProgressIndicator(value: batch.processingProgress),
                        const SizedBox(height: 12),
                        Text(
                          batch.statusMessage,
                          style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
                        ),
                      ] else if (batch.lastError != null && batch.lastError!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Processing Error",
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      batch.lastError!,
                                      style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Batch Preview & Action Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.indigo.shade50,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Batch Summary: ${batch.activeOrderItems.length} Labels",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            "Total Units: ${batch.totalOrderUnits} pcs",
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text("Deduct Stock", style: TextStyle(fontSize: 12)),
                          Switch(
                            value: _deductStock,
                            onChanged: (val) => setState(() => _deductStock = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quick Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PrintCenterScreen()),
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text("Print / Export Hub"),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const OrderFormScreen()),
                          );
                        },
                        icon: const Icon(Icons.content_cut, size: 16),
                        label: const Text("Cutting Plan"),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PickListScreen(items: batch.activeOrderItems),
                            ),
                          );
                        },
                        icon: const Icon(Icons.checklist, size: 16),
                        label: const Text("Pick List"),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ManifestScreen(items: batch.activeOrderItems),
                            ),
                          );
                        },
                        icon: const Icon(Icons.local_shipping, size: 16),
                        label: const Text("Manifest"),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final id = await batch.confirmAndSaveBatch(deductStock: _deductStock);
                          if (id > 0) {
                            await inventory.loadInventory();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Batch #$id successfully saved${_deductStock ? ' and inventory deducted' : ''}!"),
                                  backgroundColor: Colors.green.shade800,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text("Confirm & Save"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Items List
            Expanded(
              child: ListView.builder(
                itemCount: batch.activeOrderItems.length,
                itemBuilder: (context, index) {
                  return OrderItemCard(
                    item: batch.activeOrderItems[index],
                    index: index,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
