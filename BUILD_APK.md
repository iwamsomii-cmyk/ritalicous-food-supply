# Ritalicous Food Supply — APK build

## Local build
Install Flutter stable and Android SDK, then run:

    flutter pub get
    flutter build apk --release

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

The installed app itself does not require internet access. Business records are stored locally in SQLite. No INTERNET permission is declared by the app.

## GitHub Actions
Upload the project to a GitHub repository, then run **Build Android APK** under Actions. The workflow builds the release APK and uploads it as an artifact.
