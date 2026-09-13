import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../models/import_batch.dart';
import '../models/order_item.dart';
import '../services/database_helper.dart';
import '../services/pdf_cropper_service.dart';
import '../services/report_generator_service.dart';

class LabelBatchProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<OrderItem> _activeOrderItems = [];
  Uint8List? _activeCroppedPdfBytes;
  String? _activeCroppedPdfPath;
  String? _activeWithoutXpressPdfPath;
  String? _activeXpressPdfPath;
  String? _activeSummaryPdfPath;
  String? _activePickListPdfPath;
  String? _activeManifestPdfPath;
  Map<String, String> _activePerSkuPdfPaths = {};
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _statusMessage = 'Ready';
  List<ImportBatch> _pastBatches = [];

  List<OrderItem> get activeOrderItems => _activeOrderItems;
  Uint8List? get activeCroppedPdfBytes => _activeCroppedPdfBytes;
  String? get activeCroppedPdfPath => _activeCroppedPdfPath;
  String? get activeWithoutXpressPdfPath => _activeWithoutXpressPdfPath;
  String? get activeXpressPdfPath => _activeXpressPdfPath;
  String? get activeSummaryPdfPath => _activeSummaryPdfPath;
  String? get activePickListPdfPath => _activePickListPdfPath;
  String? get activeManifestPdfPath => _activeManifestPdfPath;
  Map<String, String> get activePerSkuPdfPaths => _activePerSkuPdfPaths;
  bool get isProcessing => _isProcessing;
  double get processingProgress => _processingProgress;
  String get statusMessage => _statusMessage;
  List<ImportBatch> get pastBatches => _pastBatches;

  int get totalOrderUnits => _activeOrderItems.fold(0, (sum, item) => sum + item.qty);

  Future<void> loadPastBatches() async {
    _pastBatches = await _db.getAllImports();
    notifyListeners();
  }

  /// Process selected PDF files
  Future<bool> processPdfs(List<File> files) async {
    if (files.isEmpty) return false;

    _isProcessing = true;
    _processingProgress = 0.1;
    _statusMessage = "Reading PDF files...";
    notifyListeners();

    try {
      final List<Uint8List> pdfBytesList = [];
      for (int i = 0; i < files.length; i++) {
        pdfBytesList.add(await files[i].readAsBytes());
        _processingProgress = 0.1 + (0.2 * (i + 1) / files.length);
        notifyListeners();
      }

      _statusMessage = "Detecting keywords, cropping & sorting labels...";
      _processingProgress = 0.5;
      notifyListeners();

      final result = await PdfCropperService.processPdfs(
        pdfFilesBytes: pdfBytesList,
      );

      _activeCroppedPdfBytes = result.sortedCroppedPdfBytes;
      _activeCroppedPdfPath = result.savedPdfPath;
      _activeOrderItems = result.parsedItems;

      _statusMessage = "Generating pick list and manifests...";
      _processingProgress = 0.8;
      notifyListeners();

      // Pre-generate reports
      final pickBytes = await ReportGeneratorService.generatePickListPdf(items: _activeOrderItems);
      _activePickListPdfPath = await ReportGeneratorService.saveReportToFile(pickBytes, "pick_list");

      if (result.manifestPdfBytes != null) {
        _activeManifestPdfPath = await ReportGeneratorService.saveReportToFile(result.manifestPdfBytes!, "manifest");
      } else {
        final manifestBytes = await ReportGeneratorService.generateManifestPdf(items: _activeOrderItems);
        _activeManifestPdfPath = await ReportGeneratorService.saveReportToFile(manifestBytes, "manifest");
      }

      if (result.summaryPdfBytes != null) {
        _activeSummaryPdfPath = await ReportGeneratorService.saveReportToFile(
          result.summaryPdfBytes!,
          "order_summary",
        );
      }

      if (result.withoutXpressBeesBytes != null) {
        _activeWithoutXpressPdfPath = await ReportGeneratorService.saveReportToFile(
          result.withoutXpressBeesBytes!,
          "without_xpressbees",
        );
      } else {
        _activeWithoutXpressPdfPath = null;
      }

      if (result.xpressBeesBytes != null) {
        _activeXpressPdfPath = await ReportGeneratorService.saveReportToFile(
          result.xpressBeesBytes!,
          "xpressbees_only",
        );
      } else {
        _activeXpressPdfPath = null;
      }

      _activePerSkuPdfPaths = {};
      for (final entry in result.perSkuPdfs.entries) {
        final clean = entry.key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final path = await ReportGeneratorService.saveReportToFile(entry.value, "sku_$clean");
        _activePerSkuPdfPaths[entry.key] = path;
      }

      _processingProgress = 1.0;
      _statusMessage = "Completed! ${_activeOrderItems.length} labels processed.";
      return true;
    } catch (e) {
      debugPrint("Error processing PDFs: $e");
      _statusMessage = "Failed: $e";
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Allow user to modify detected SKU / Size / Color in preview before saving
  void updateItemDetails(int index, {String? sku, String? size, String? color, int? qty}) {
    if (index >= 0 && index < _activeOrderItems.length) {
      final current = _activeOrderItems[index];
      _activeOrderItems[index] = current.copyWith(
        sku: sku ?? current.sku,
        size: size ?? current.size,
        color: color ?? current.color,
        qty: qty ?? current.qty,
      );
      notifyListeners();
    }
  }

  /// Confirm and save batch to database, deducting inventory
  Future<int> confirmAndSaveBatch({bool deductStock = true}) async {
    if (_activeOrderItems.isEmpty) return 0;

    final now = DateTime.now().toIso8601String();
    final batch = ImportBatch(
      platform: _activeOrderItems.first.platform,
      filePath: _activeCroppedPdfPath ?? '',
      importedAt: now,
      totalItems: _activeOrderItems.length,
      sortedLabelPdf: _activeCroppedPdfPath,
      pickListPdf: _activePickListPdfPath,
      courierManifestPdf: _activeManifestPdfPath,
    );

    final importId = await _db.saveImportBatch(
      batch: batch,
      items: _activeOrderItems,
      deductStock: deductStock,
    );

    await loadPastBatches();
    return importId;
  }

  /// Undo a past batch import
  Future<bool> undoBatch(int importId) async {
    final success = await _db.undoImport(importId);
    if (success) {
      await loadPastBatches();
    }
    return success;
  }

  /// Mobile sharing helpers
  Future<void> shareCroppedPdf() async {
    if (_activeCroppedPdfPath != null) {
      await Share.shareXFiles(
        [XFile(_activeCroppedPdfPath!)],
        text: 'Meesho Cropped & Sorted Labels',
      );
    }
  }

  Future<void> shareWithoutXpressPdf() async {
    if (_activeWithoutXpressPdfPath != null) {
      await Share.shareXFiles(
        [XFile(_activeWithoutXpressPdfPath!)],
        text: 'Labels Without XpressBees',
      );
    }
  }

  Future<void> shareXpressPdf() async {
    if (_activeXpressPdfPath != null) {
      await Share.shareXFiles(
        [XFile(_activeXpressPdfPath!)],
        text: 'XpressBees Labels Only',
      );
    }
  }

  Future<void> shareSummaryPdf() async {
    if (_activeSummaryPdfPath != null) {
      await Share.shareXFiles(
        [XFile(_activeSummaryPdfPath!)],
        text: 'Aggregated Order Summary',
      );
    }
  }

  Future<void> sharePickListPdf() async {
    if (_activePickListPdfPath != null) {
      await Share.shareXFiles(
        [XFile(_activePickListPdfPath!)],
        text: 'Warehouse Pick List',
      );
    }
  }

  Future<void> shareManifestPdf() async {
    if (_activeManifestPdfPath != null) {
      await Share.shareXFiles(
        [XFile(_activeManifestPdfPath!)],
        text: 'Courier Handover Manifest',
      );
    }
  }

  Future<void> sharePerSkuPdf(String sku) async {
    final path = _activePerSkuPdfPaths[sku];
    if (path != null) {
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Labels for SKU: $sku',
      );
    }
  }

  void clearActiveBatch() {
    _activeOrderItems = [];
    _activeCroppedPdfBytes = null;
    _activeCroppedPdfPath = null;
    _activeWithoutXpressPdfPath = null;
    _activeXpressPdfPath = null;
    _activeSummaryPdfPath = null;
    _activePickListPdfPath = null;
    _activeManifestPdfPath = null;
    _activePerSkuPdfPaths = {};
    _statusMessage = 'Ready';
    notifyListeners();
  }
}

