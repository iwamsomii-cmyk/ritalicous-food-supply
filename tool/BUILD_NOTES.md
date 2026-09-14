# Build notes

1. Use the supplied `assets/ritalicous_logo.png` as the source artwork for Android/iOS/Windows/Linux icons.
2. Add `flutter_launcher_icons` during the packaging phase if icon generation is desired from the source image.
3. Keep all business data in SQLite; never require a remote database.
4. For a true local LLM on capable devices, add a native inference bridge in a later phase. The current AI layer is deterministic/offline and therefore works on low-end devices too.
