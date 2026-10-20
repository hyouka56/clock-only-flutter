# Clock — Flutter

A minimalist Android clock and alarm app with a pure-black interface and a white clock glyph centered on a black launcher icon.

## Features

- Only two screens: **Clock** and **Alarm**.
- Live digital time and date.
- One-time alarms and repeating alarms for selected weekdays.
- Optional alarm labels, editing, enable/disable, and swipe-to-delete.
- Saved alarm list using local preferences.
- Android scheduled notifications with alarm audio attributes and vibration.
- Android boot receiver to restore scheduled notifications.

## Build

Install Flutter stable, Android SDK, and Java 17. Then run:

\`\`\`sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
\`\`\`

The APK output path is \`build/app/outputs/flutter-apk/app-release.apk\`.

The GitHub Actions workflow builds the APK and uploads it as an artifact. It creates Gradle wrapper scripts in a temporary Flutter project because binary wrapper files are not part of this initial commit.

## Android alarm access

Allow notifications and **Alarms & reminders** access for the most reliable timing. If exact-alarm access is denied, the app falls back to inexact scheduling and Android may deliver the alert late. Some device vendors impose additional background limits.

Before store publication, configure a private release signing key. Do not publish using the debug signing configuration.
