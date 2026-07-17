# Gaslight

A Victorian-parlor social bluffing game for phones (Android + iOS), built with Flutter. Players write forged answers on each other's prompt cards, vote to find the truth, and unmask the forgers. The game is **server-authoritative**: all game rules run in Firebase Cloud Functions, so a live (or emulated) backend is required for any play session.

## Getting Started

This project is a Flutter application that uses Firebase for its backend and `flutter_dotenv` for environment variable management.

### Prerequisites

- Flutter SDK (>=3.0.6 <4.0.0)
- Dart SDK
- A Firebase project with Firestore enabled

### Setting up API Keys

This project uses `flutter_dotenv` to manage Firebase API keys. The keys must not be exposed in source control.

1. Navigate to the project root directory.
2. Locate the `.env.example` file, and create a copy of it named `.env`:
   ```bash
   cp .env.example .env
   ```
3. Open the newly created `.env` file and replace the placeholder values with your actual Firebase API keys found in your Firebase console:
   ```env
   FIREBASE_API_KEY_WEB=your_actual_web_api_key
   FIREBASE_API_KEY_ANDROID=your_actual_android_api_key
   FIREBASE_API_KEY_IOS=your_actual_ios_api_key
   ```
   *Note: The `.env` file is excluded from git via `.gitignore` to prevent secret leaks.*

### Installation & Launch

1. Fetch the project dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application on your connected device or emulator:
   ```bash
   flutter run
   ```

### Emulator & Simulator Networking Setup

When testing the application locally with a local Firebase emulator suite or calling local servers, configuring networking is required:

*   **iOS Simulator**: Connects directly to `localhost` or `127.0.0.1`.
*   **Android Emulator**: Cannot resolve `127.0.0.1` as the host machine. Instead, use the special loopback IP address **`10.0.2.2`** which redirects to your host machine's loopback (`127.0.0.1`).
*   **Physical Android Device**: Ensure both your host machine and mobile device are connected to the same Wi-Fi network, and target the host machine's IP address (e.g. `192.168.x.x`). Alternatively, perform port forwarding using `adb reverse tcp:8080 tcp:8080` (or appropriate Firestore/auth ports).

### Duplicate-Answer Filtering

*   **Lexical Heuristic**: Duplicate-answer detection is implemented as a local, offline lexical heuristic (normalized Jaccard / containment / Levenshtein metrics) to prevent duplicate or near-duplicate forgeries. No external AI APIs or keys are required.

## Testing & Running the Game

There are three layers of testing: **automated suites** (run these first, always), **Option A: local playtesting** against the Firebase Emulator (free, no accounts, works offline), and **Option B: Apple developer testing via TestFlight** (the real pre-release path for playing with friends on their own iPhones).

### Automated test suites (run before any playtest)

```bash
flutter analyze                 # static analysis — must report 0 errors
flutter test                    # client widget/unit tests (incl. 360×640 phone-layout tests)
npm --prefix functions test     # backend E2E on the Firebase emulator: full game loops,
                                # security rules, bots, custom decks, unmasking/revenge scoring
```
The backend suite needs `firebase-tools` (invoked via `npx`) and Java (for the Firestore emulator). It boots the emulators itself via `emulators:exec`.

---

### Option A — Local testing (Firebase Emulator, no cloud account needed)

Everything (Auth, Firestore, Cloud Functions) runs on your machine. Best for solo smoke tests with bots, and for multi-simulator play at your desk.

1. **Build the functions and start the emulators** (ports are preconfigured in `firebase.json`: Auth 9099, Functions 5001, Firestore 8080):
   ```bash
   cd functions && npm install && npm run build && cd ..
   npx firebase-tools emulators:start --only auth,functions,firestore
   ```
2. **Point the app at the emulator** — either add `USE_EMULATOR=true` to your `.env`, or pass it at launch:
   ```bash
   flutter run --dart-define=USE_EMULATOR=true
   ```
3. **Networking per device** (the client targets `localhost`):
   - **iOS Simulator**: works as-is.
   - **Android Emulator**: forward the ports first: `adb reverse tcp:8080 tcp:8080 && adb reverse tcp:5001 tcp:5001 && adb reverse tcp:9099 tcp:9099`.
   - **Physical device on your Wi-Fi**: use `adb reverse` (Android) or point the hosts at your machine's LAN IP (see the networking section above).
4. **Solo play with bots**: debug builds create rooms with debug tooling enabled — in the lobby tap **DEBUG: ADD BOTS** (9 bots join), start the game, and use **DEBUG: BOTS SUBMIT** on each phase to drive them. This exercises the full loop end-to-end alone.
5. **Local multiplayer**: launch the app on two or more simulators/devices (step 3 applies to each), create a room on one, and join with the room code from the others. Same-room-code play works entirely against the local emulator.

> Note: the emulator wipes all data on shutdown — rooms don't persist between sessions. That's a feature for testing.

### Option B — Apple developer testing (TestFlight, for real playtests with friends)

This is the path that matches what you'll submit to the App Store: a real build, the real cloud backend, friends installing on their own iPhones.

**One-time backend deployment** (the game cannot run multiplayer without it):
1. You need a Firebase project on the **Blaze (pay-as-you-go) plan** — Cloud Functions do not deploy on the free Spark plan. Playtest usage costs cents.
2. Link the project and deploy the backend:
   ```bash
   npx firebase-tools login
   npx firebase-tools use --add        # select your Firebase project
   cd functions && npm run build && cd ..
   npx firebase-tools deploy --only functions,firestore:rules
   ```
3. In the Firebase console, enable **Authentication → Sign-in method → Anonymous**.
4. Make sure your `.env` contains the real `FIREBASE_API_KEY_IOS` (and Android key if building there), and that `USE_EMULATOR` is **not** set.

**One-time Apple setup:**
1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year) and create an app record in [App Store Connect](https://appstoreconnect.apple.com) (bundle ID must match `ios/Runner`).
2. In Xcode (`open ios/Runner.xcworkspace`), set your Team under Signing & Capabilities.

**Each test build:**
```bash
flutter build ipa
```
Upload `build/ios/ipa/*.ipa` to App Store Connect via Xcode's Organizer or the **Transporter** app. Then in App Store Connect → **TestFlight**:
- Add friends as **Internal Testers** (up to 100, by email — builds are available to them within minutes, no review wait), or create a public TestFlight link for external testers (first external build requires a brief Beta App Review).
- Friends install the **TestFlight** app on their iPhone, accept the invite, and install Gaslight.

**Playtest flow:** one player creates a room and shares the 4-letter code (tap the brass room-code plaque to copy/share it); everyone else joins with the code. Minimum 2 players; the game needs more players than forgery rounds (default 2), so 3+ is the practical minimum and 4–6 is the sweet spot.

> **Android testers:** the equivalent path is `flutter build apk --release` and sideloading `build/app/outputs/flutter-apk/app-release.apk`, or Play Console → Internal testing. The same deployed Firebase backend serves both platforms — iOS and Android friends can play in the same room.

### What to verify in a playtest
- A **non-host** player can submit forgeries, vote, and ready up (the server-authoritative path).
- The **Unmask the Forger** window: fall for a lie, then guess its author before the forgers are revealed.
- **Custom Decks**: everyone writes prompts in the lobby; confirm you never receive your own prompt.
- **Drop-out/rejoin**: force-quit mid-game and reopen — you should recover your seat.
- **Sound**: quill scratch on submit, wax thunk on vote, the bell on the Truth reveal; the handbell icon mutes everything.

## Version Control

When contributing to this repository, please adhere to the following guidelines regarding file commits.

### What to Commit
- Source code directories (`lib/`, `test/`)
- Project configuration files (`pubspec.yaml`, `pubspec.lock`)
- Platform-specific project files (`android/`, `ios/`, `web/`) excluding build artifacts
- Asset files (`assets/`)
- Documentation updates (e.g., this `README.md`)

### What NOT to Commit
- **Local environment files** (e.g., `.env`) that contain sensitive information like API keys or secrets.
- **Build directories and generated files** (e.g., `build/`, `.dart_tool/`).
- **IDE configuration files** specific to your local setup (e.g., macOS `.DS_Store`, local workspace settings).
- **Crash logs** or locally generated temporary files.

When in doubt, consult the `.gitignore` file to see the patterns of files that should be excluded from version control.
