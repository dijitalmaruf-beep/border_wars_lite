# Chroma Conquest

Chroma Conquest is a first playable Flutter MVP for a premium territory conquest strategy game. Players and bots fight over a real-world-style territory map with local single-player state, deterministic game rules, and an MVP Firestore-backed online room flow.

Primary slogan:

```text
One Color. One World.
Until the last color stands.
```

Turkish slogan:

```text
Tek Renk. Tüm Dünya.
Son renk kalana kadar.
```

## MVP Scope

- Android and Web first.
- Local single-player game state.
- MVP online rooms with selectable human player count and bot commanders.
- Local mode: 1 human player plus a selectable bot count.
- 47 clickable world-map territories with owners, armies, neighbors, polygon borders, and continent groups.
- Reinforcement, attack, transfer, bot, and victory rules implemented outside the UI.
- Firebase Core, Anonymous Firebase Auth, and Cloud Firestore dependencies included for online rooms.
- Codemagic workflows for Android debug APK, Web release, and tests.

## Local Setup

Install Flutter, then from the repo root run:

```sh
flutter create . --platforms=android,web
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

Android app label:

```text
Chroma Conquest
```

Android package id:

```text
com.marleklabs.chromaconquest
```

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

## Firebase / Online Play

Online play uses Anonymous Firebase Auth plus Cloud Firestore documents in the `games` collection. The flow is:

- Host opens `Online Game`, creates a 6-character room code, and waits.
- Guest opens `Online Game`, enters the room code, and joins.
- The match starts with the selected human player count and bot count.
- The current `GameState` is synced through Firestore.

To enable real online play, configure Firebase for each target:

- Android: `android/app/google-services.json` should include package id `com.marleklabs.chromaconquest`.
- Web: generated Firebase options, normally via FlutterFire CLI.
- Firebase Console: enable `Authentication > Sign-in method > Anonymous`.
- Firestore: deploy `firestore.rules` so only signed-in room participants can update active games.

The app handles missing Firebase config or missing Anonymous Auth setup gracefully and shows an online setup warning instead of crashing.

## iOS Preparation

iOS App Name:

```text
Chroma Conquest
```

Bundle ID planned:

```text
com.marleklabs.chromaconquest
```

Notes:

- iOS workflow/signing will be added later in Codemagic.
- App Store display name should be `Chroma Conquest`.
- Subtitle/marketing slogan: `One Color. One World. Until the last color stands.`

## Next Features

- Codemagic iOS workflow with Apple signing.
- Better map assets after visual approval.
- Difficulty settings for bots.
- Firebase-backed save slots.
- Full account/profile system beyond Anonymous Auth.
