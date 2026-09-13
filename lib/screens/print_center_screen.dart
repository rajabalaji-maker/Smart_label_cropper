import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/label_batch_provider.dart';

class PrintCenterScreen extends StatelessWidget {
  const PrintCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final batch = context.watch<LabelBatchProvider>();
    final hasBatch = batch.activeOrderItems.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print & Export Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info
          Card(
            elevation: 0,
            color: Colors.indigo.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.indigo.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.print, color: Colors.indigo.shade700, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Batch Documents',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            hasBatch
                                ? '${batch.activeOrderItems.length} labels • ${batch.totalOrderUnits} total units'
                                : 'No active batch. Process PDFs in Cropper tab.',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Shipping Labels (Thermal & A4)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          _PdfActionTile(
            title: 'Full Sorted Shipping Labels',
            subtitle: 'Cropped 4x6 / thermal labels sorted by SKU, size & partner',
            icon: Icons.picture_as_pdf,
            color: Colors.indigo,
            isEnabled: hasBatch && batch.activeCroppedPdfPath != null,
            onShare: () => batch.shareCroppedPdf(),
            onPrint: batch.activeCroppedPdfPath != null
                ? () async {
                    final file = File(batch.activeCroppedPdfPath!);
                    final bytes = await file.readAsBytes();
                    await Printing.layoutPdf(onLayout: (_) => bytes);
                  }
                : null,
          ),

          if (batch.activeWithoutXpressPdfPath != null)
            _PdfActionTile(
              title: 'Labels Without XpressBees',
              subtitle: 'Batch excluding XpressBees labels for separate handover',
              icon: Icons.local_shipping,
              color: Colors.blue,
              isEnabled: true,
              onShare: () => batch.shareWithoutXpressPdf(),
              onPrint: () async {
                final file = File(batch.activeWithoutXpressPdfPath!);
                final bytes = await file.readAsBytes();
                await Printing.layoutPdf(onLayout: (_) => bytes);
              },
            ),

          if (batch.activeXpressPdfPath != null)
            _PdfActionTile(
              title: 'XpressBees Labels Only',
              subtitle: 'Standalone batch for XpressBees courier pickup',
              icon: Icons.bolt,
              color: Colors.amber.shade800,
              isEnabled: true,
              onShare: () => batch.shareXpressPdf(),
              onPrint: () async {
                final file = File(batch.activeXpressPdfPath!);
                final bytes = await file.readAsBytes();
                await Printing.layoutPdf(onLayout: (_) => bytes);
              },
            ),

          const SizedBox(height: 16),
          const Text(
            'Warehouse Reports & Manifests',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          _PdfActionTile(
            title: 'Aggregated Order Summary',
            subtitle: 'SKU | Size tabular summary with Grand Total and SKU breakdown',
            icon: Icons.table_chart,
            color: Colors.teal,
            isEnabled: hasBatch && batch.activeSummaryPdfPath != null,
            onShare: () => batch.shareSummaryPdf(),
            onPrint: batch.activeSummaryPdfPath != null
                ? () async {
                    final file = File(batch.activeSummaryPdfPath!);
                    final bytes = await file.readAsBytes();
                    await Printing.layoutPdf(onLayout: (_) => bytes);
                  }
                : null,
          ),

          _PdfActionTile(
            title: 'Warehouse Pick List',
            subtitle: 'Item checklist with check boxes for order packaging',
            icon: Icons.checklist,
            color: Colors.purple,
            isEnabled: hasBatch && batch.activePickListPdfPath != null,
            onShare: () => batch.sharePickListPdf(),
            onPrint: batch.activePickListPdfPath != null
                ? () async {
                    final file = File(batch.activePickListPdfPath!);
                    final bytes = await file.readAsBytes();
                    await Printing.layoutPdf(onLayout: (_) => bytes);
                  }
                : null,
          ),

          _PdfActionTile(
            title: 'Courier Partner Manifest',
            subtitle: 'Courier handover signoff sheet with packet counts',
            icon: Icons.assignment_turned_in,
            color: Colors.green,
            isEnabled: hasBatch && batch.activeManifestPdfPath != null,
            onShare: () => batch.shareManifestPdf(),
            onPrint: batch.activeManifestPdfPath != null
                ? () async {
                    final file = File(batch.activeManifestPdfPath!);
                    final bytes = await file.readAsBytes();
                    await Printing.layoutPdf(onLayout: (_) => bytes);
                  }
                : null,
          ),

          // Per SKU PDFs
          if (batch.activePerSkuPdfPaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Per-SKU PDF Downloads',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...batch.activePerSkuPdfPaths.entries.map((entry) {
              final sku = entry.key;
              final path = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListTile(
                  leading: const Icon(Icons.style, color: Colors.indigo),
                  title: Text(sku, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Filtered labels for this product only'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        tooltip: 'Share',
                        onPressed: () => batch.sharePerSkuPdf(sku),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print, size: 20),
                        tooltip: 'Print',
                        onPressed: () async {
                          final file = File(path);
                          final bytes = await file.readAsBytes();
                          await Printing.layoutPdf(onLayout: (_) => bytes);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _PdfActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;

  const _PdfActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isEnabled,
    this.onShare,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEnabled ? color.withOpacity(0.12) : Colors.grey.shade100,
          child: Icon(icon, color: isEnabled ? color : Colors.grey.shade400),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isEnabled ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: isEnabled ? Colors.grey.shade700 : Colors.grey.shade400),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onPrint != null)
              IconButton(
                icon: const Icon(Icons.print, size: 20),
                tooltip: 'Print',
                onPressed: isEnabled ? onPrint : null,
              ),
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              tooltip: 'Share',
              onPressed: isEnabled ? onShare : null,
            ),
          ],
        ),
      ),
    );
  }
}
