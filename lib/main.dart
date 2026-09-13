import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/inventory_provider.dart';
import 'providers/label_batch_provider.dart';
import 'providers/settings_provider.dart';

import 'screens/home_dashboard_screen.dart';
import 'screens/label_cropper_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_history_screen.dart';
import 'screens/settings_rules_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TonyMaxMobileApp());
}

class TonyMaxMobileApp extends StatelessWidget {
  const TonyMaxMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()..loadInventory()),
        ChangeNotifierProvider(create: (_) => LabelBatchProvider()..loadPastBatches()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: settings.brandName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4338CA), // Modern Indigo
                brightness: Brightness.light,
              ),
              textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
              scaffoldBackgroundColor: const Color(0xFFF9FAFB),
              cardTheme: CardThemeData(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            home: const MainNavigationHolder(),
          );
        },
      ),
    );
  }
}

class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _currentIndex = 0;

  void _onSelectTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeDashboardScreen(onNavigateTab: _onSelectTab),
      const LabelCropperScreen(),
      const InventoryScreen(),
      const ReportsHistoryScreen(),
      const SettingsRulesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onSelectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.crop_outlined),
            selectedIcon: Icon(Icons.crop),
            label: 'Cropper',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Rules',
          ),
        ],
      ),
    );
  }
}
