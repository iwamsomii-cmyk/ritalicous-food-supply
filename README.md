# RITALICIOUS FOOD SUPPLY — Offline AI Sales Calculator

This is the first production-oriented Flutter foundation for the Ritalicous Food Supply application. It is designed around the supplied Excel template and keeps the four sheet titles:

- Executive Dashboard
- Sales Log
- Expenses Log
- Inventory Log

## How stock and sales are calculated (v2 logic)

- **Inventory Log**: the user types only *product name*, *opening stock* and *closing stock*. (Leaving closing empty = nothing counted yet = nothing sold.)
- **Sales Log**: the user types only *product name*, *price* and whether the price is per **unit** or per **pack**.
- The app matches the two logs by product name (capital letters and extra spaces are ignored) and works out: **sold = opening - closing**, **value = sold x price**. Results are shown on every card in both logs.
- Opening / closing stock *value* on the dashboard uses the selling price from the Sales Log (the Inventory Log no longer has a cost price).
- Every revenue and profit view shows the product name: dashboard table "Mapato na Faida kwa Kila Bidhaa", pie "Revenue kwa Bidhaa", the PDF table and saved records. "Mgao wa faida" is Net Profit split by each product's revenue share (expenses are not recorded per product).
- Old records: products that have no inventory count keep the quantity they were saved with. Database version is now 4 (adds `sales.sale_unit`); existing data upgrades automatically.

## Offline design

- SQLite stores all business data locally.
- Calculations are deterministic and run on-device.
- Dashboard charts are generated from the local database.
- Business advice is generated locally by the analysis engine.
- PDF reports are generated locally.
- No network/API is required at runtime or when installing the final APK.
- JSON import/export is deliberately not exposed in the normal UI.

## Build

Install Flutter SDK on the developer/build machine, then:

```bash
flutter pub get
flutter run -d windows
flutter build apk --release
flutter build windows --release
flutter build linux --release
flutter build ios --release
```

The end user does not need internet to install or run the resulting APK/binaries. Build-time dependency fetching is a developer concern.

## Important

The Excel workbook is encrypted, so the source workbook itself is not embedded into the app. Its visible structure/formulas were used as the application specification. The supplied logo was extracted into `assets/ritalicous_logo.png`.
