import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/normalization_service.dart';

class SettingsRulesScreen extends StatefulWidget {
  const SettingsRulesScreen({super.key});

  @override
  State<SettingsRulesScreen> createState() => _SettingsRulesScreenState();
}

class _SettingsRulesScreenState extends State<SettingsRulesScreen> {
  late TextEditingController _brandController;
  late TextEditingController _primaryController;
  late TextEditingController _secondaryController;
  late double _percent;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _brandController = TextEditingController(text: settings.brandName);
    _primaryController = TextEditingController(text: settings.primaryKeyword);
    _secondaryController = TextEditingController(text: settings.secondaryKeyword);
    _percent = settings.secondaryCropPercent;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings & Rules"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: "Save Settings",
            onPressed: () async {
              await settings.updateBrandName(_brandController.text.trim());
              await settings.updateKeywords(
                primary: _primaryController.text.trim(),
                secondary: _secondaryController.text.trim(),
                percent: _percent,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Settings saved successfully!")),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Brand Information",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _brandController,
            decoration: const InputDecoration(
              labelText: "Brand / Business Name",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "PDF Cropping Parameters",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _primaryController,
            decoration: const InputDecoration(
              labelText: "Primary Crop Keyword (Trim below)",
              helperText: "Crops and keeps everything above this keyword line",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secondaryController,
            decoration: const InputDecoration(
              labelText: "Secondary Keyword (Exchange)",
              helperText: "Fallback when primary keyword is absent",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Secondary Crop Fraction:"),
              Text(
                "${(_percent * 100).toInt()}%",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _percent,
            min: 0.50,
            max: 0.95,
            divisions: 9,
            onChanged: (val) => setState(() => _percent = val),
          ),
          const SizedBox(height: 24),
          const Text(
            "Canonical SKU Sort Hierarchy",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Labels and pick lists are automatically sorted in this canonical sequence:",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...NormalizationService.canonicalSkuOrder.asMap().entries.map(
                (entry) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.indigo.shade100,
                    child: Text("${entry.key + 1}", style: TextStyle(fontSize: 11, color: Colors.indigo.shade900)),
                  ),
                  title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                ),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await settings.updateBrandName(_brandController.text.trim());
              await settings.updateKeywords(
                primary: _primaryController.text.trim(),
                secondary: _secondaryController.text.trim(),
                percent: _percent,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Settings saved successfully!")),
                );
              }
            },
            child: const Text("Save Configuration"),
          ),
        ),
      ),
    );
  }
}
