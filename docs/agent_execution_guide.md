# Active Build Queue — Queue Complete (August 7, 2026)

All items in the active build queue (**Issues 31 and 32**) have been successfully implemented, verified with automated unit and widget tests, deployed to production Cloud Functions, and documented in `docs/ongoing_general_errors.md`.

---

## 🟢 Delivered Queue Summary

1. **Issue 31 — Lobby Settings Wipe & START GAME Crash (Option A)** (`d5e2e0d`):
   - **Client (`lib/services/game_service.dart`)**: Conditionally constructed `updateLobbySettings` payload so untouched fields are omitted instead of sending Dart `null` values.
   - **Server (`functions/src/index.ts`)**: Updated `updateLobbySettings` to use loose `!= null` guards so JSON `null` values do not overwrite existing stored settings in Firestore.
   - **Server (`functions/src/index.ts`)**: Added explicit `rounds` validation in `startGame`, throwing a readable `HttpsError("failed-precondition")` when `sabotageAnswersCount` is invalid.
   - **Engine (`functions/src/rotation_engine.ts`)**: Hardened `RotationEngine.generateRotations` to validate positive integer `sabotageRounds`.
   - **Tests & Deployment**: Added backend E2E tests in `functions/test/game_e2e.spec.ts` (31/31 passed) and client test in `test/house_rules_panel_test.dart`. Deployed updated Cloud Functions to Firebase production.

2. **Issue 32 — New Simple-Mascot Crow Artwork (Option D)** (`0a58dcb`):
   - **Asset System (`assets/images/raven/`)**: Generated 4 transparent PNG layers (`body.png`, `wing.png`, `eye_open.png`, `eye_closed.png`) on a shared 1024×1024 canvas with 1x, 2x, 3x resolution variants (total size: 38.09 KB across 12 files). Saved prompts to `assets/images/raven/PROMPTS.md`.
   - **Widget (`lib/widgets/raven_mascot.dart`)**: Replaced 485-line `_RavenPainter` with stacked `Image.asset` layers wrapped in `Transform` widgets. Preserved `RavenMascot` public API, `RavenState` enum, and all 5 screen call sites without modification.
   - **Validation & Contrast**: Measured rim-light contrast at 18.59:1 and body contrast at 1.32:1 against `#14110E` background (exceeding 4.5:1 and 1.2:1 thresholds). Added 8 automated test cases in `test/raven_mascot_test.dart` covering asset integrity, contrast, and all pose animation contracts.

---

## 🧪 Final Verification Battery

- `flutter analyze lib test`: **0 errors** (261 warnings/infos)
- `flutter test`: **74/74 pass** (100% green)
- `npm --prefix functions run build`: **TypeScript build clean**
- `npm --prefix functions test`: **31/31 pass on emulator**
- `npx firebase-tools deploy --only functions`: **Production deploy succeeded**
