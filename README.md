# Tony Max Mobile - Meesho Label Cropper & Inventory Sorter App

A **100% offline, standalone Flutter mobile application** for Android and iOS that automates shipping label cropping, order sorting, inventory management, warehouse pick lists, and courier manifests.

---

## Features

- ✂️ **On-Device Shipping Label Cropping**:
  - Automatically searches for keywords like `Original For Recipient` (keeping everything above) and `Exchange` (keeping top 80% or 60%).
  - Auto-rotates horizontal pages to vertical portrait orientation.
  - Generates visual high-contrast **"QTY: X"** badges on labels with quantity > 1.
  - Automatically merges and sorts pages by canonical SKU hierarchy and size sequences.
- 📦 **Offline SQLite Inventory Management**:
  - Embedded local database (`tony_max_inventory.db`) with zero internet required.
  - Instant stock updates (+ / - buttons).
  - Low stock warning alerts with custom threshold settings.
  - Complete stock audit trail (`inventory_movements`) tracking every order deduction, restock, or return.
- 📋 **Warehouse Pick Lists**:
  - Automatically groups items by SKU, Size, and Color.
  - Interactive on-screen checklist so packing workers can check off items on the warehouse floor.
  - 1-Click PDF export and direct thermal/A4 printing via mobile.
- 🚚 **Courier Handover Manifests**:
  - Groups parcels by logistics partner: **Delhivery, Shadowfax, Xpressbees, Ekart, Ecom Express, Valmo, etc.**
  - Ready-to-sign handover sheets for delivery pickup riders.
- 🔄 **History & Undo System**:
  - Full history of previous PDF batches.
  - **Undo Import** feature that restores deducted inventory if a file was processed by mistake.
  - Export full inventory to CSV for Excel backup.

---

## How to Run & Build

### Prerequisites
1. Install Flutter SDK ([flutter.dev](https://flutter.dev/docs/get-started/install)).
2. Make sure Android Studio or VS Code with Flutter extension is installed.

### Setup & Run
```bash
# 1. Navigate to mobile app directory
cd mobile_app

# 2. Get dependencies
flutter pub get

# 3. Connect your Android or iOS device (enable USB debugging on Android)
flutter devices

# 4. Run the app in debug mode
flutter run
```

### Build Release APK (For Android Phone Install)
```bash
flutter build apk --release
```
The installable APK will be generated at:
`mobile_app/build/app/outputs/flutter-apk/app-release.apk`

Transfer this `.apk` file to any Android phone via WhatsApp, Bluetooth, or USB and tap to install!

---

## Project Structure

```
mobile_app/
├── lib/
│   ├── main.dart                       # App entry point, MultiProvider, Material 3 Theme
│   ├── models/
│   │   ├── inventory_item.dart         # SKU, size, color, quantity model
│   │   ├── order_item.dart             # Parsed shipping label model
│   │   ├── import_batch.dart           # Batch history record
│   │   └── stock_movement.dart         # Audit movement log
│   ├── services/
│   │   ├── database_helper.dart        # SQLite tables, transactions, migrations
│   │   ├── pdf_cropper_service.dart    # Pure on-device PDF cropper & QTY stamper
│   │   ├── label_parser_service.dart   # Meesho, Amazon, Flipkart regex parser
│   │   ├── normalization_service.dart  # SKU variants & canonical hierarchy
│   │   └── report_generator_service.dart # Pick list & manifest PDF generator
│   ├── providers/
│   │   ├── inventory_provider.dart     # Reactive stock state
│   │   ├── label_batch_provider.dart   # Batch workflow & processing
│   │   └── settings_provider.dart      # Crop keywords & brand name
│   ├── screens/
│   │   ├── home_dashboard_screen.dart  # Metric tiles, low stock alert
│   │   ├── label_cropper_screen.dart   # PDF file picker, preview, export
│   │   ├── inventory_screen.dart       # Searchable stock list, quick +/-
│   │   ├── pick_list_screen.dart       # Warehouse checklist & print
│   │   ├── manifest_screen.dart        # Courier handover sheet
│   │   ├── reports_history_screen.dart # Batch history, undo import, CSV export
│   │   └── settings_rules_screen.dart  # Crop settings & SKU hierarchy
│   └── widgets/
│       ├── order_item_card.dart        # Label preview card
│       ├── stock_counter_dialog.dart   # Stock adjustment modal
│       └── stat_card.dart              # Metric summary card
├── test/
│   └── normalization_test.dart         # Unit tests for SKU & size rules
└── pubspec.yaml                        # Dependencies
```
