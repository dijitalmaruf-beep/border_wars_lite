# Border Wars Lite

Border Wars Lite is a first playable Flutter MVP for a simplified territory conquest game. Players and bots fight over a real-world-style territory map with local single-player state, deterministic game rules, and an MVP Firestore-backed online room flow.

## MVP Scope

- Android and Web first.
- Local single-player game state.
- MVP online rooms: 2 human players plus selectable bot commanders.
- Local mode: 1 human player plus a selectable bot count.
- 48 clickable world-map territories with owners, armies, neighbors, polygon borders, and continent groups.
- Reinforcement, attack, bot, and victory rules implemented outside the UI.
- Firebase Core, Anonymous Firebase Auth, and Cloud Firestore dependencies included for online rooms.
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

## Firebase / Online Play

Online play uses Anonymous Firebase Auth plus Cloud Firestore documents in the `games` collection. The flow is:

- Host opens `Online Game`, creates a 6-character room code, and waits.
- Guest opens `Online Game`, enters the room code, and joins.
- The match starts with 2 human players and the host-selected bot count.
- The current `GameState` is synced through Firestore.

To enable real online play, configure Firebase for each target:

- Android: `android/app/google-services.json` plus the usual Google Services Gradle setup if your Firebase tooling requires it.
- Web: generated Firebase options, normally via FlutterFire CLI.
- Firebase Console: enable `Authentication > Sign-in method > Anonymous`.
- Firestore: deploy `firestore.rules` so only signed-in room participants can update active games.

The app handles missing Firebase config or missing Anonymous Auth setup gracefully and shows an online setup warning instead of crashing.

## Next Features

- Continue game with local persistence.
- Better map visuals and continent bonuses.
- Difficulty settings for bots.
- Firebase-backed save slots.
- Full account/profile system beyond Anonymous Auth.
- Codemagic iOS workflow with Apple signing.
