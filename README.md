# RITALICIOUS FOOD SUPPLY — Offline AI Sales Calculator

This is the first production-oriented Flutter foundation for the Ritalicous Food Supply application. It is designed around the supplied Excel template and keeps the four sheet titles:

- Executive Dashboard
- Sales Log
- Expenses Log
- Inventory Log

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
