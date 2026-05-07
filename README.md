# Border Wars Lite

Border Wars Lite is a first playable Flutter MVP for a simplified territory conquest game. One human player and three bots fight over a 30-territory abstract world map with local single-player state, deterministic game rules, and placeholder Firebase/Firestore services for later online features.

## MVP Scope

- Android and Web first.
- Local single-player game state.
- 1 human player and 3 bots: Atlas Bot, Nova Bot, Terra Bot.
- 48 clickable world-map territories with owners, armies, neighbors, polygon borders, and continent groups.
- Reinforcement, attack, bot, and victory rules implemented outside the UI.
- Firebase Core and Cloud Firestore dependencies included, with multiplayer methods stubbed.
- Codemagic workflows for Android debug APK, Web release, and tests.

## Local Setup

Install Flutter, then from the repo root run:

```sh
flutter create . --platforms=android,web --project-name border_wars_lite
flutter pub get
```

The `flutter create` command generates Android/Web platform wrappers on machines or CI runners that have Flutter installed. It is safe to run over this source scaffold.

## Run Locally

```sh
flutter run -d chrome
```

For Android device testing:

```sh
flutter devices
flutter run -d <device-id>
```

## Tests and Analysis

```sh
flutter analyze
flutter test
```

## Build Android APK

```sh
flutter build apk --debug
```

The debug APK will be written under `build/app/outputs/flutter-apk/`.

## Build Web

```sh
flutter build web --release
```

The web build will be written under `build/web/`.

## Codemagic

Connect the GitHub repository in Codemagic and choose one of the workflows in `codemagic.yaml`:

- `android-debug-apk`
- `web-release`
- `tests`

iOS release builds are intentionally not configured yet because they require Apple Developer credentials, signing certificates, and provisioning profiles. The Flutter structure is ready for Codemagic iOS work later.

## Firebase

Firebase is not initialized during app startup for this MVP. Add generated Firebase options and call `FirebaseService.initialize()` when save/load or multiplayer features are ready.

## Next Features

- Continue game with local persistence.
- Better map visuals and continent bonuses.
- Difficulty settings for bots.
- Firebase-backed save slots.
- Online lobby and turn synchronization.
- Codemagic iOS workflow with Apple signing.
