# Ritalicous Food Supply — APK build

## Local build
Install Flutter stable and Android SDK, then run:

    flutter pub get
    flutter build apk --release

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

The installed app itself does not require internet access. Business records are stored locally in SQLite. Internet is used only to check for and download updates.

## GitHub Actions
Upload the project to a GitHub repository, then run **Build Android APK** under Actions. The workflow builds the release APK and uploads it as an artifact.

## Masasisho ya kiotomatiki (Auto-update)
- Ukifanya mabadiliko: pakia faili GitHub (`main`). Workflow inajenga toleo jipya lenye namba kubwa kuliko la awali na kuliweka kwenye **Releases → Latest** pamoja na `version.json`.
- Kila device inapofunguliwa na ina internet, inaangalia `version.json`; ikiona toleo jipya inalipakua na kulisakinisha yenyewe. Bila internet, programu inaendelea kufanya kazi kama kawaida.
- **Windows:** sasisho linasakinishwa kimya kimya na programu inajifungua tena (full screen). Hakuna hatua ya mkono.
- **Android:** mara ya kwanza washa "Ruhusu kusakinisha programu" kwa mfumo huu, na ukubali kisanduku cha kusakinisha. Android 12+ masasisho yanayofuata yanaenda kimya; Android za zamani zinaonyesha kisanduku cha uthibitisho (Android hairuhusu programu kujisakinisha bila uthibitisho).
- Repository lazima iwe **public** ili devices zipakue masasisho.
- Kumbuka: devices zilizosakinishwa **kabla** ya toleo hili la auto-update zinahitaji kusakinishwa mara moja kwa mkono; baada ya hapo zinajisasisha zenyewe.
