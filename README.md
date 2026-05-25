# Gaslight

A Flutter application.

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

### Gemini API Key Prototyping Risk

*   **Current Architecture**: The application loads the Gemini API key via `.env` on the client and passes it directly in HTTP headers (`x-goog-api-key`) to facilitate rapid, serverless prototyping.
*   **Production Risk**: In compiled production binaries, client-side API keys can be reverse-engineered and extracted.
*   **Production Migration Path**: For production releases, client-side Gemini requests must be migrated to a secure backend proxy (such as Firebase Cloud Functions or a dedicated Node.js/Go middleware server) to keep the API key fully hidden.

## Development

- The app has screens in `lib/screens/` and reusable UI components in `lib/widgets/`.
- When adding new dependencies, run `flutter pub get`.
- The `firebase_options.dart` configuration relies on the environment variables defined in your `.env` file.

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
