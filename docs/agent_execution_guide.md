# Agent Execution Guide — Active Build: Wave AI, 6 remaining items (AI15, AI10–AI14) — October 12, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.** Implement as written. If a value turns out to be impossible, keep the intent, deviate minimally, measure the deviation, and say so in the commit body. If the design itself cannot work, **STOP** and file it in `docs/ongoing_general_errors.md` with options and a `Your selection: _____` line — do not improvise.

**Where things stand.** Wave AI came from a read-only audit on October 10 (Issues 178–191); the user selected an option for every issue. **Steps 1–10 (AI1, AH1, AI2–AI9) are built and were verified on October 12** by re-running the battery and re-falsifying every item in a scratch copy (§9). **Six items remain: AI15, then AI10–AI14** (§2). Their specs below were refreshed against the current code — line numbers moved when earlier items edited the same files.

**Two follow-ups were selected in chat on October 12.** Issue 192 → **B**: AH1's physical-iPhone check is closed by acceptance (simulator observation plus source trace) — nothing to do; see §9's accepted equivalents. Issue 193 → **B**: the user grants **one-time Accessibility Inspector access** so the AI8 readings can be taken as specced — that is **AI15** (§8), and it runs **first**, while the user is at the keyboard to approve the access dialog.

---

## 0. Standing constraints — apply to every item

1. **One item = one local Conventional Commit**, WHY in the body, plus the tracker update (§0.9) in the same commit. Do not push.
2. **Falsify every new test.** Inject the fault, run the test, watch it fail, restore. The fault must **compile** — a test that fails to load proves nothing (THE LOOP rule 7). When reverting a whole commit would delete a symbol the test imports, inject a targeted fault instead. Paste the failing output under `Falsification:`.
3. **Read exit codes bare** — never through `| tail`, never through `timeout` (macOS has none). An empty result means nothing until the same query has returned something (lesson §2.44).
4. **New code adds zero analyzer infos.** Use `.withValues(alpha: x)`, never `.withOpacity(x)`; no `print`. After every item `flutter analyze lib test` must show **0 errors · 0 warnings · 170 infos** (AI12 lowered it from 186 by migrating the 16 `deprecated_member_use` that are not `withOpacity`).
5. **Strings are verbatim** — copy, keys, labels, punctuation, the em dash.
6. **The only server change left is AI11.** Deploy functions **once**, after AI11's commit (§0.8). Server changes are **additive only** — build **1.1.0 (8)** is on testers' phones.
7. **Rendered contrast is measured from pixels** with `test/helpers/rendered_contrast.dart` (`measureRenderedContrast`), never with the widget-tree walk in `test/contrast_tokens_test.dart`.
8. **Deploy procedure (AI11 only):** `firebase deploy --only functions` → `gcloud run services update cleanupdaily --update-env-vars CLEANUP_DRY_RUN=false` → read the flag back from the new revision → `./scripts/check_deploy_fresh.sh` bare, exit 0. **Deploying changes production: ask the user for the go-ahead before running `firebase deploy`.** Never deploy uncommitted code. **Do not upload to TestFlight** in this wave.
9. **Tracker update per item:** add one row at the top of `docs/ongoing_general_errors.md` §3's Wave AI table (what shipped, deviations, where the contract lives), update the design doc the item's blast radius names, and delete the issue block from "Unresolved". Never fill in or edit a `Your selection:` line.
10. **Never accept Xcode's "Update to recommended settings" dialog** (lesson §2.29). Edit `project.pbxproj` as text.
11. **A load-bearing manual check is REQUIRED and its outcome goes in the commit body either way:** `Device check: DONE — <what you saw>` or `Device check: NOT RUN — <reason>` (lesson §2.45).
12. **SnackBar assertions name the exact text and start from a known-empty screen** (lesson §2.47): a parlour reached through `tryRejoinSession` already shows *"Rejoined active game session!"*. Pump ~6 s and assert `find.byType(SnackBar)` `findsNothing` before the action under test, and assert `tester.takeException()` is `null` explicitly.

### 0.1 Environment — each of these cost a cycle

- **iOS builds work** since AI1 removed CocoaPods. There is **no `Podfile`** — never reintroduce one. `flutter build ios --release --no-codesign` is the ninth gate.
- **Emulators by hand:** `PATH="/opt/homebrew/bin:/opt/homebrew/opt/openjdk/bin:$PATH" npx firebase-tools emulators:start --only auth,functions,firestore`. App: `flutter run -d <udid> --dart-define=USE_EMULATOR=true`. `npm --prefix functions test` starts its own emulators on the same ports — stop hand-started ones first.
- **Stop only the processes you started.** This Mac runs many Claude sessions, each with its own `npm exec firebase-tools@latest mcp`. Never `pkill` by a `firebase` or `emulator` pattern; `kill -INT <the PID of the emulators:start you launched>`.
- **Stale Keychain trap:** a simulator that ran the app against an *earlier* emulator session fails every callable with `[firebase_functions/unknown] An internal error has occurred` — the anonymous user survives in the simulator Keychain, but the emulator's data (and its refresh token) was wiped. Before any device check, use a fresh simulator or `xcrun simctl keychain <udid> reset`. Leave the user's pre-existing "iPhone 17" simulator alone; use an "iPhone SE (3rd generation)" simulator on iOS 26.5 (create one with `xcrun simctl create "iPhone SE (3rd generation)" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-26-5` if none exists).
- **App access:** the user has granted **one-time computer-use access to Accessibility Inspector for AI15 only** (Issue 193 → B). Everything else stays declined — DeviceHub (declined October 10), the simulator panel's per-device grant, and any other app. Ask only for what AI15 needs, once; everywhere else work headless — `xcrun simctl io <udid> screenshot f.png`, marionette, and the VM service. This Xcode has no Simulator.app; **DeviceHub.app** (`/Applications/Xcode.app/Contents/Applications/`) shows simulators instead.
- **A native iOS sheet (the share sheet) cannot be dismissed from marionette** and `simctl` has no tap. End it with `xcrun simctl terminate <udid> com.whylabs.gaslight`; relaunching auto-rejoins the saved room. Plan native-sheet checks last in a session.
- **Marionette:** text taps and `scroll_to` fail on off-screen widgets — swipe first. In the parlour the House Rules and `DEBUG:` buttons sit on the page behind the `DraggableScrollableSheet`: drag the sheet handle down (y≈230→640), then swipe the page (y≈300→70, ×3). Failed marionette calls show up in `get_runtime_errors` as `ext.flutter.marionette.*` — not app errors.
- **No Simulator.app on this Xcode; `simctl` cannot rotate.** Text size: `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large` (the app clamps to 1.3; restore with `large`).
- **`flutter test --coverage` is broken on Flutter 3.44.6** (AI14 investigates). Never use it for validation.
- **`~/.local/bin/git` cannot clone over https** — prefix `PATH="/usr/bin:$PATH"`.
- **zsh:** a word starting with `=` is expanded (`echo =====x` fails) and an unmatched glob aborts the command. Use bash for scripts.

---

## 1. Verified baseline — measured October 12, 2026 on `da73408`

**This is the regression bar.** Every gate was run bare in that session.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 170 infos · exit 1** (137 `deprecated_member_use`, all of them `withOpacity` — the rejected 139 C migration; was 186 until AI12) |
| `flutter test` | **423 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **164 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five**: no-arg, `docs/playthroughs/findings_marionette.md`, `…/findings_web.md`, `…/findings_5player.md`, `…/findings_waveAA.md` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH, 19 functions** |
| `./scripts/check_web_e2e_strings.sh` | **exit 0** |
| `flutter build ios --release --no-codesign` | **exit 0 — `✓ Built build/ios/iphoneos/Runner.app (50.1MB)`**; `UIDeviceFamily` = `1, 2` (AI13 changes it) |
| `flutter test --coverage` | **Not a gate** — segfaults the runner (AI14) |

**Production:** 19 functions deployed; Firestore rules identical to `firestore.rules`. `CLEANUP_DRY_RUN=false` was last read back on `cleanupdaily-00020-7tq` (October 12, after AI11's deploy; it also survived the deploy itself, on `cleanupdaily-00019-pud`).

**⚠️ `flutter analyze lib test` exits 1 even when clean** — judge it by the counts. Never run bare `flutter analyze`.

---

## 2. Execution order

| Step | Item | Issue → option | Why this position |
|---|---|---|---|
| 1 | **AI15** Accessibility Inspector readings of AI8's controls (§8) | 193 → B | **First**: it needs the user at the keyboard to approve one access dialog, and they are most likely there when your session starts. Docs-only; reads the controls exactly as AI8 shipped them, before AI10 edits `lobby_screen.dart`. If access is not granted, record NOT RUN and go on — nothing else depends on it. |
| 2 | **AI10** Auto-rejoin keeps the seat on a transient failure | 183 → A | Client-only; reuses AH1's connection sentence (landed). Before AI11 so both new error surfaces exist before the one deploy. |
| 3 | **AI11** Error reasons from the server; one client mapper | 185 → A | The only server change; one deploy (§0.8) after its commit. |
| 4 | **AI12** Migrate deprecated APIs | 190 → A | Lowers the analyzer bar once, after the last code item that could add infos. Its share-sheet check is a native-sheet check — run it last in its session (§0.1). |
| 5 | **AI13** iPhone-only device family | 188 → A | Nothing depends on it; must land before the next App Store release. |
| 6 | **AI14** Investigate the coverage collector | 189 → B | Independent and touches no code; may run any time, in parallel. |

AI15 is numbered after AI14 only because it was selected after the others were numbered; §2's order governs.

---

## 3. AI10 — Auto-rejoin keeps the seat on a transient failure (Issue 183 → A)

**What this means for the user.** Reopen the app on a flaky connection and today you're told *"Your session expired — please rejoin."* and the saved seat is deleted. After this you're told the truth and offered RETRY, and the seat survives.

**The gap.** `lib/services/game_service.dart:319–366` `tryRejoinSession()`: when the room and player documents exist, it calls `joinRoom`; **any** exception lands in the inner `catch` (`debugPrint('Error re-binding session during rejoin: $e')` at `:355`), which removes `seat_token_<room>`, `room_code` and `player_id`. The outer `catch` (`:362–364`, `'Error rejoining session: $e'`) returns `false` without wiping. `lib/screens/lobby_screen.dart:186–200` (the `addPostFrameCallback` in `initState`) then shows `Rejoined active game session!` on `true`, or `Your session expired — please rejoin.` when a saved session existed. On iOS a dropped connection arrives as `unknown` (AH1). No test covers the failure branches.

### 3.1 Implementation
1. **Keep `Future<bool> tryRejoinSession()`** — `test/simulation_test.dart:570–581` asserts `isFalse` and must pass unedited. Add to `game_service.dart`: `enum RejoinFailure { none, expired, connection }`, a private field, and `RejoinFailure get lastRejoinFailure`.
2. Inside `tryRejoinSession()`, set `none` first, then:
   - no saved `room_code` or `player_id` → return `false`, `none`;
   - saved, but the room **or** player document does not exist → remove the three keys, return `false`, `expired`;
   - `joinRoom` throws a `FirebaseFunctionsException` whose `code` is `not-found`, `permission-denied` or `invalid-argument` → remove the three keys (as today), return `false`, `expired`;
   - any other exception from `joinRoom` — including `unknown`, `unavailable`, `deadline-exceeded`, `unauthenticated`, `internal`, and any non-`FirebaseFunctionsException` → **keep** the keys, return `false`, `connection`;
   - the outer `catch` → keep the keys, return `false`, `connection`.
   This is bounded: a dead session is retried at most until the room's 8-hour TTL deletes the document, after which the "document missing" branch clears it.
3. `lobby_screen.dart`: move the callback body (`:186–200`) into `Future<void> _attemptRejoin()`, called from `initState`'s post-frame callback and from RETRY. On `false`:
   - `connection` → `clearSnackBars()`, then `SnackBar(content: const Text('Could not reach the parlour. Check your connection and try again.'), duration: const Duration(seconds: 10), action: SnackBarAction(label: 'RETRY', onPressed: _attemptRejoin))`;
   - `expired`, when a saved session existed → the existing `Your session expired — please rejoin.`;
   - on `true` → the existing `Rejoined active game session!`.
   Guard every `ScaffoldMessenger` use with `if (!mounted) return;`.

### 3.2 Validation
1. New **`test/rejoin_failure_test.dart`**. Set-up: `SharedPreferences.setMockInitialValues({'room_code': 'ABCD', 'player_id': 'p1', 'seat_token_ABCD': 'tok'})`; a `FakeFirestore` holding room `ABCD` and player `p1`; `functions.overrideCallable('joinRoom', …)`. Service-level cases — each asserts the return value, `lastRejoinFailure`, and **each of the three keys** by name:
   1. throws `FirebaseFunctionsException(code: 'unknown', message: 'x')` → `false`, `connection`, **all three keys still present** — the falsifying case;
   2. `unavailable` → as 1; 3. `unauthenticated` → as 1; 4. a plain `Exception('x')` → as 1;
   5. `not-found` → `false`, `expired`, all three keys removed; 6. `permission-denied` → as 5;
   7. no override (success) → `true`, `none`, `seat_token_ABCD` holds the returned token;
   8. room document absent → `false`, `expired`, keys removed.
2. **Widget cases on `LobbyScreen`** (§0.12 — exact text; `tester.runAsync` around awaited fakes, lesson §2.7):
   - `unknown` → the connection sentence is shown with a `RETRY` action; remove the override, tap `RETRY` → `Rejoined active game session!` and `gameService.gameState` is non-null;
   - `not-found` → `Your session expired — please rejoin.`;
   - `tester.takeException()` is `null` in both.
3. **Falsifying:** on the parent commit, case 1 fails (the keys are gone) and the `unknown` widget case fails (it shows the expired sentence). Record both.
4. Over-reach guards, unedited: `test/simulation_test.dart` (all, especially `:570–581`), every test that calls `tryRejoinSession()` as set-up (`grep -rln tryRejoinSession test/`), and all 15 tests in `test/lobby_settings_error_test.dart`.
5. **Device check (REQUIRED):** iPhone SE simulator **with a reset Keychain** (§0.1), emulators running. Create a room as host, then `xcrun simctl terminate <udid> com.whylabs.gaslight`. Stop **your** emulator process (`kill -INT <pid>`). Relaunch → the connection SnackBar with `RETRY` appears (the seat is kept). Start the emulators again (they come back empty), run `xcrun simctl keychain <udid> reset` (the old anonymous user went with the emulator data), relaunch → `Your session expired — please rejoin.` (room document missing). That exercises both branches. Screenshots via `xcrun simctl io <udid> screenshot`.

**Blast radius:** `lib/services/game_service.dart`, `lib/screens/lobby_screen.dart`, `test/rejoin_failure_test.dart` (new), `docs/design_database_and_security.md` §5 (seat recovery: transient failures keep the saved seat; only `not-found`, `permission-denied`, `invalid-argument` or a missing document clear it).

---

## 4. AI11 — Error reasons from the server; one client mapper (Issue 185 → A)

**What this means for the user.** A guess that lands as the unmask countdown ends is told *"That guess is already locked in."* After this it says the window closed — and craft and reveal errors are mapped on codes, never on message text.

**The gap.** `lib/screens/phase4_reveal.dart:1098–1112`: after `debugPrint('submitUnmaskGuess error: $e')` (`:1100`), the sentence is chosen at `:1102` with `e.toString().contains('already submitted') || e.toString().contains('failed-precondition')` — but `submitUnmaskGuess` throws `failed-precondition` for six reasons, including `"Unmask guess deadline has passed or is inactive."` (`functions/src/index.ts:2514`). `lib/screens/phase2_craft.dart:177–193`: `errStr.contains('similar') || errStr.contains('Similarity')` (`:182`); the server's similarity rejection is `invalid-argument` (`index.ts:975`), the same code as its other `invalid-argument`s.

### 4.1 Implementation
1. **Server, additive** (`functions/src/index.ts`; message strings byte-identical — 1.1.0 (8) still matches on them):
   - `:2514` → `throw new HttpsError("failed-precondition", "Unmask guess deadline has passed or is inactive.", { reason: "deadline_passed" });`
   - `:2557` → `throw new HttpsError("failed-precondition", "Player has already submitted an unmask guess.", { reason: "already_submitted" });`
   - `:975` → `throw new HttpsError("invalid-argument", "Answer is too similar to another player's answer!", { reason: "too_similar" });`
2. **Emulator test helper, additive:** `callFn` in `functions/test/game_e2e.spec.ts` copies only `message` and `status` (`:68`). Add `(err as any).details = json.error.details;` on the line after `:68`. Without it no test can see `details`.
3. **Client:** new `lib/utils/callable_error_message.dart`:
   ```dart
   enum GameAction { unmaskGuess, submitAnswer }
   String gameCallableErrorMessage(Object error, {required GameAction action})
   ```
   `reason` = `error.details['reason']` when `error is FirebaseFunctionsException && error.details is Map`, else `null`.
   - `unmaskGuess` + `failed-precondition` + `deadline_passed` → **`The guessing window has closed.`**
   - `unmaskGuess` + `failed-precondition` + `already_submitted` → **`That guess is already locked in.`**
   - `submitAnswer` + `invalid-argument` + `too_similar` → **`Too similar to an existing answer! Be more creative.`**
   - everything else, including a non-`FirebaseFunctionsException`, missing `details`, or an unknown reason → **`Something went wrong. Try again.`**
4. `phase4_reveal.dart:1102–1104` → `final String msg = gameCallableErrorMessage(e, action: GameAction.unmaskGuess);`. `phase2_craft.dart:181–184` → `final String msg = gameCallableErrorMessage(e, action: GameAction.submitAnswer);`. Keep the craft screen's local similarity pre-check unchanged.
5. Afterwards `grep -rn "toString().contains" lib/` returns only `lib/theme/app_icons.dart:627` (the test-binding check, unrelated).
6. Deploy per §0.8 **after** the commit, with the user's go-ahead.

### 4.2 Validation
1. **Emulator suite**, three new cases in `functions/test/game_e2e.spec.ts`: (a) `submitUnmaskGuess` after the deadline → `err.status === 'FAILED_PRECONDITION'`, `err.details.reason === 'deadline_passed'`, `err.message === 'Unmask guess deadline has passed or is inactive.'`; (b) a second guess → `'already_submitted'`, message unchanged; (c) a too-similar `submitAnswer` → `'INVALID_ARGUMENT'`, `'too_similar'`, message unchanged. The unchanged-message assertions are the 1.1.0 (8) compatibility guard. Count **164 → 167**.
2. **Dart unit test** `test/callable_error_message_test.dart`: a table of (action, code, details, expected) covering the three mapped cases, each mapped code with `details: null`, `details` that is not a `Map`, an unknown reason, and a plain `Exception`.
3. **Widget tests** (§0.12): reveal — `overrideCallable('submitUnmaskGuess')` throws `FirebaseFunctionsException(code: 'failed-precondition', message: 'Unmask guess deadline has passed or is inactive.', details: {'reason': 'deadline_passed'})` → SnackBar `The guessing window has closed.`; craft — `submitAnswer` throws `invalid-argument` with `details: {'reason': 'too_similar'}` for text that passes the local pre-check → `Too similar to an existing answer! Be more creative.`; the raw message text never appears on screen.
4. **Falsifying (compiling faults):** (a) restore the old `toString()` expression at the reveal site → the deadline widget test shows `That guess is already locked in.` and fails; (b) delete the `details` line from `callFn` → emulator cases (a)–(c) fail; (c) drop `{ reason: "deadline_passed" }` from `:2514` → case (a) fails. Record all three.
5. Over-reach guards, unedited: every existing unmask and submit test in both suites; `test/phase2_craft_test.dart` and `test/ui_e2e_test.dart` (similarity paths).
6. **Deploy check (REQUIRED):** after deploying, `check_deploy_fresh.sh` exit 0 and `CLEANUP_DRY_RUN=false` read back from the new `cleanupdaily` revision — both in the commit body or a follow-up docs commit. If the user declines the deploy, record `Deploy: NOT RUN — <reason>` and mark the Issue 185 row "not deployed".
7. **Device check (REQUIRED):** iPhone SE simulator, reset Keychain, emulators: as a fooled voter, let the unmask countdown run out and tap an accusation as it expires → `The guessing window has closed.` If the buttons disable before the deadline, record `Device check: NOT RUN — buttons disabled before the deadline`, which is not a failure.

**Blast radius:** `functions/src/index.ts`, `functions/test/game_e2e.spec.ts`, `lib/utils/callable_error_message.dart` (new), `lib/screens/phase4_reveal.dart`, `lib/screens/phase2_craft.dart`, `test/callable_error_message_test.dart` (new), the two widget-test files, `docs/design_ui_direction.md` (error surfaces: craft and reveal map `code` + `details.reason`), `docs/design_database_and_security.md` (callable table: the three `details.reason` values).

---

## 5. AI12 — Migrate the deprecated APIs (Issue 190 → A)

**What this means for the user.** Nothing visible. It removes compile errors-in-waiting before an upgrade forces them at a bad moment.

**The gap.** 16 `deprecated_member_use` infos besides the 137 `withOpacity` (that migration was rejected as 139 C — leave those): `lib/screens/game_over_screen.dart:125` (`Share`, `shareXFiles`), `lib/widgets/room_code_plaque.dart:22` (`Share`, `share`), `lib/screens/lobby_screen.dart:608` and `:682` (`activeColor`), `lib/screens/game_over_screen.dart:1174` and `lib/screens/lobby_screen.dart:1128` (`Matrix4.scale`), `lib/screens/lobby_screen.dart:1142` (`Color.value` × 2), `test/raven_mascot_test.dart:47` and `:195` (`Color.red/green/blue` × 3 each). If lines shift, find them with `flutter analyze lib test | grep deprecated_member_use | grep -v withOpacity`.

### 5.1 Implementation
1. `game_over_screen.dart`: `await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: 'Just finished a match of Gaslight! Check out the night\'s honors.'));`
2. `room_code_plaque.dart`: `SharePlus.instance.share(ShareParams(text: 'Join my Gaslight game! Room code: ${widget.code}'));` — same text as today.
3. Both `activeColor: AppColors.brass` → `activeThumbColor: AppColors.brass`.
4. `Matrix4.identity()..scale(x)` → `Matrix4.identity()..scaleByDouble(x, x, x, 1.0)` at both sites (vector_math 2.2.0 `matrix4.dart:938`; one-argument `scale(x)` scales x, y and z by `x` and leaves w).
5. `crimsonColor.value` → `crimsonColor.toARGB32()`; `Colors.grey.shade700.value` → `Colors.grey.shade700.toARGB32()`.
6. `test/raven_mascot_test.dart:47`, `:195`: `AppColors.ground.red` → `(AppColors.ground.r * 255.0).round().clamp(0, 255)`, and likewise `.green` → `.g`, `.blue` → `.b` (the formula the deprecation message gives).
7. Update §1 of this guide to **170 infos** in the same commit (README points here).

### 5.2 Validation
1. `flutter analyze lib test` → **0 errors · 0 warnings · 170 infos**, exit 1; `flutter analyze lib test | grep deprecated_member_use | grep -vc withOpacity` → `0`; `… | grep -c withOpacity` → `137`.
2. `flutter test` → all passing, at least **423** (`test/raven_mascot_test.dart` T3.3 still asserts ≥ 4.5 : 1 with the same number).
3. **Falsifying (analyzer):** record the count before (186) and after (170).
4. **Device check (REQUIRED — the share paths changed API):** iPhone SE simulator, reset Keychain, emulators. First check the switches (the Family-Friendly and timers switches show a brass thumb when on) and the avatar tokens (the selected token still scales up). **Then, last** (§0.1 — a share sheet ends the session): tap the room-code envelope → the share sheet opens with `Join my Gaslight game! Room code: XXXX`; screenshot; `xcrun simctl terminate`; relaunch (auto-rejoins), finish a game, tap `Share Case File` → share sheet with the PNG and text; screenshot.

**Blast radius:** `lib/screens/game_over_screen.dart`, `lib/widgets/room_code_plaque.dart`, `lib/screens/lobby_screen.dart`, `test/raven_mascot_test.dart`, this guide's §1.

---

## 6. AI13 — iPhone-only for the first App Store release (Issue 188 → A)

**What this means for the user.** Gaslight ships as the iPhone game it was designed and tested as; iPad users get the iPhone app in compatibility mode. Adding iPad later is allowed; removing it after an iPad-capable App Store release is not.

**The gap.** `ios/Runner.xcodeproj/project.pbxproj:376`, `:501`, `:552` set `TARGETED_DEVICE_FAMILY = "1,2";` (the three Runner build configurations; the lines moved when AI1 removed CocoaPods). The built `Info.plist`'s `UIDeviceFamily` is `1, 2` (read October 12).

### 6.1 Implementation
1. Change all three to `TARGETED_DEVICE_FAMILY = 1;`, editing the file as text (§0.10).
2. Leave `UISupportedInterfaceOrientations~ipad` in `ios/Runner/Info.plist` — an iPhone-only binary ignores it. Do not touch `lib/main.dart`'s orientation lock.

### 6.2 Validation
1. `grep -c 'TARGETED_DEVICE_FAMILY = "1,2"' ios/Runner.xcodeproj/project.pbxproj` → `0`; `grep -c 'TARGETED_DEVICE_FAMILY = 1;'` → `3`.
2. **Falsifying (built artefact):** `flutter build ios --release --no-codesign`, then `/usr/libexec/PlistBuddy -c "Print :UIDeviceFamily" build/ios/iphoneos/Runner.app/Info.plist` → only `1` (before: `1` and `2`). Record both.
3. **Device check (REQUIRED):** run on the iPad Pro 13" (iOS 26.5) simulator → the app opens in iPhone compatibility mode and the title screen is intact. Screenshot via `xcrun simctl io`.
4. Full battery including the ninth gate; `git status --porcelain` shows only `project.pbxproj` and docs.

**Blast radius:** `ios/Runner.xcodeproj/project.pbxproj`, `README.md` → Releasing (no iPad screenshots are needed), `docs/design_ui_direction.md` (record the iPhone-only decision and why).

---

## 7. AI14 — Investigate the coverage collector (Issue 189 → B)

**What this means for the user.** Nothing visible. It tries to restore a trustworthy way to see which code no test runs.

**The gap.** On Flutter 3.44.6 (measured October 10, when the suite had 357 tests): the full-suite `flutter test --coverage` segfaults the runner (24× in one run, also with `--concurrency=1`) and never exits; file by file, 13 of 73 files still segfault (`ember_backdrop_reduce_motion`, `gaslight_route`, `phase4_header_overflow`, `phase4_reveal`, `raven_mascot`, `reduce_motion`, `room_code_plaque`, `scoring_logic`, `stacked_deck_navigation`, `text_similarity`, `vote_option_truncation`, `waiting_indicator`, `wax_seal_badge`); in those that finish, `lib/services/game_service.dart` appears in one LCOV file with 0 hits although nearly every widget test drives it. Already falsified: switching `test/simulation_test.dart`'s relative `../lib/` imports to `package:` did not bring it back.

### 7.1 Implementation — time-boxed to 2 hours of active work; no change to `lib/`, `test/`, `pubspec.yaml` or `pubspec.lock`
1. **Work in a scratch export** (`git archive HEAD | tar -x -C <scratch>`, plus `cp .env <scratch>/`), never in the repo — a different Flutter SDK rewrites `.dart_tool` and possibly `pubspec.lock`. If you track the scratch copy with git, reset with `git reset --hard HEAD` between runs: `git checkout -- .` restores from the index and lets changes accumulate.
2. **Reproduce the crash** on the smallest crasher: `flutter test --coverage --coverage-path=<scratch>/x.info test/wax_seal_badge_test.dart`, 5 runs, each in the background with a 120 s kill (macOS has no `timeout`; poll a file rather than a foreground `sleep`). Record the crash rate. Control: the same file without `--coverage`, 5 runs → expect 5/5 pass.
3. **Reproduce the missing library:** `flutter test --coverage test/lobby_create_error_test.dart`; `grep -c "SF:.*lib/services/game_service.dart"` on the LCOV → expect `0`. **Positive control:** the same LCOV contains `SF:lib/screens/lobby_screen.dart` (it did on October 10). An absence means nothing without it (lesson §2.44).
4. **Collector flags**, one at a time, on both reproductions: `--coverage-package=gaslight`, `--branch-coverage`, `--concurrency=1`, `--no-pub`. Record the effect of each.
5. **Next Flutter stable, side by side:** `PATH="/usr/bin:$PATH" git clone --depth 1 --branch <latest stable tag> https://github.com/flutter/flutter.git <scratch>/flutter-next`, then run steps 2–3 with `<scratch>/flutter-next/bin/flutter`.
6. **Minimal repro:** if it reproduces in a fresh `flutter create` sample with one widget test, it is a Flutter bug. Draft an upstream issue in the tracker, but **do not post it** — ask the user.

### 7.2 Validation and deliverable
1. A findings entry in `docs/ongoing_general_errors.md` §1. For every claim: the exact command, the number of runs, the outcome — and a positive control for every "absent" claim.
2. **Outcomes, exactly one:**
   - (a) a command that works on 3.44.6 → add it to §1 of this guide as **informational, never a gate** (lesson §2.30), with per-file numbers for `lib/services` and `lib/screens`;
   - (b) it works only on a newer Flutter → **STOP and file** a new issue with options (a project-wide SDK upgrade is the user's decision);
   - (c) nothing works → add one line to §1: *"Coverage is not collectable on Flutter 3.44.6 (runner segfault; `game_service.dart` missing from LCOV) — see Issue 189 findings."*
3. `git status --porcelain` in the repo shows only docs changed.

**Blast radius:** `docs/ongoing_general_errors.md`, this guide's §1. Nothing in `lib/`, `test/`, `functions/` or `pubspec.*`.

---

## 8. AI15 — Accessibility Inspector readings of AI8's controls (Issue 193 → B) — run FIRST

**What this means for the user.** A blind player finds each icon control by its name. AI8 proved the names exist in Flutter's semantics tree; this reads them where iOS exposes them, in Apple's Accessibility Inspector — the check AI8's spec required and could not run.

**The gap.** AI8's spec required: *"Open the Accessibility Inspector app, target the simulator, and hover each of the five controls: each reports the label above."* `19a2713`'s body records `Device check: NOT RUN for the Accessibility Inspector hover readings … (user_denied)`. A VM-service semantics-tree dump stood in (Issue 193's status lists it). On October 12 the user chose **Issue 193 → B: one-time computer-use access to Accessibility Inspector** for this check. AI8's kick-badge tap checks (corner and centre-right) were DONE in AI8 — do not repeat them. **No code changes in this item.**

### 8.1 Procedure
1. **Set up headless first — no access needed yet.**
   - Simulator: the "iPhone SE (3rd generation)" on iOS 26.5 (`xcrun simctl list devices available`; create one per §0.1 if absent). **Two simulators are usually booted: the user's "iPhone 17" is not yours** — note your SE's UDID.
   - Reset its Keychain (`xcrun simctl keychain <udid> reset`); text size `large`.
   - Start the emulators by hand (§0.1), then `flutter run -d <udid> --dart-define=USE_EMULATOR=true`.
   - Through marionette, create a room as host and tap `DEBUG: ADD 9 BOTS` (§0.1: drag the sheet down and swipe first).
   - Take a `simctl io` screenshot. It is your positive control for step 3.
2. **Access — exactly once.**
   - Load the computer-use tools (`ToolSearch`, query `computer-use`, `max_results` 30).
   - Call `request_access` for **Accessibility Inspector** only (`/Applications/Xcode.app/Contents/Applications/Accessibility Inspector.app`), then `open_application`.
   - If the request is denied or times out: record `Device check: NOT RUN — Inspector access not granted`, commit nothing, and go on to AI10. Do not re-ask unless the user says so in chat.
3. **Target the SE simulator.**
   - (a) **If the Inspector's target menu (top-left of its window) lists the SE simulator, choose it.** Step through the elements with the Inspector's next/previous-element navigation; no other app is needed.
   - (b) **If it does not**, the Inspector can only read a simulator through its on-screen window, which on this Xcode is **DeviceHub**. The user declined DeviceHub on October 10, and Issue 193 → B did not grant it. **Ask the user once in chat**: *"AI15: Accessibility Inspector can't target the simulator directly on this Xcode; it needs DeviceHub on screen. May I request access to DeviceHub too?"* On a no, record `Device check: NOT RUN — the Inspector needs DeviceHub, which was not granted`. Then STOP and file a new issue saying Option B cannot run as granted, with these options:
     - grant DeviceHub too;
     - accept the semantics-tree substitute (193's old Option A);
     - the user listens with VoiceOver on their iPhone (193's old Option C).
     
     Leave Issue 193 open and add to its status: *"Option B attempted <date>; blocked — see Issue <n>."*
   - **Positive control (lesson §2.44):** before taking any reading, inspect one plain element that is visible in your step-1 screenshot, e.g. the `THE GUEST LEDGER` heading. Its label must be that text; this proves you are reading **this app on your SE**. If it isn't, you are on the wrong target.
4. **Readings.** Take one Inspector screenshot per row, through the computer-use screenshot tool.
   - Record the **Label** and **Traits** exactly as shown, plus the frame size if the Inspector shows one. Sizes are already pinned by `test/tap_target_guidelines_test.dart`, so a size is recorded, not judged.
   - Expected values are what the semantics tree hands iOS:

   | Where | Control | Expected label | Expected traits |
   |---|---|---|---|
   | Parlour, host | each kick badge | `Remove <bot name>` — **its own element**, separate from the tile's `<bot name>` | Button |
   | Parlour | room-code envelope | `Share room code` | Button |
   | Parlour | each avatar token | `Token n of 6` | Button; Selected on the chosen token only (tap another, read again) |
   | Parlour, House Rules deck carousel (behind the sheet, §0.1) | the deck card's link | `PEEK INSIDE` | Button |
   | Vote, on a card where you vote | PREV / NEXT | `Previous option` / `Next option` | Button; Not Enabled on the first / last option |
   | Vote | each jump dot | `Show option n of N` (N = that card's options) | Button; Selected on the current option |

   Reach the vote screen with the `DEBUG:` buttons, as AI8's device check did (room created → truth → forgery → vote; `DEBUG: BOTS SUBMIT` on each waiting screen, §0.1).
5. **Release and tidy up.**
   - Quit the Inspector and end the computer-use session; the grant was one-time.
   - Restore the text size, `kill -INT` **your** emulator process, and leave the user's iPhone 17 alone.
6. **A reading that differs from the table is a finding, not something to fix here.** That includes a missing or different label, the kick label merged into the tile (the bug `container: true` fixed), or a missing Button trait.
   - Resolve Issue 193 with the readings, since the check ran.
   - File the difference as a **new issue with options** (*Pros*/*Cons*, one `(recommended)`, `Your selection: _____`), quoting the reading and the matching node from Issue 193's tree dump.
   - Do not change `lib/` in this item.

### 8.2 Validation and deliverable
1. **One docs-only commit:** `docs(a11y): record Accessibility Inspector readings of AI8's controls (Wave AI / AI15, Issue 193 Option B)`.
   - The body holds the observed table (control → label, traits, size if shown), the positive-control reading, which target path (a or b) was used, and `Device check: DONE — …` (or `NOT RUN — <reason>`).
2. **Screenshots are not committed.** `docs/playthroughs/evidence/` is gated by `check_playthrough_evidence.sh`'s manifest. Keep them in your scratchpad, name them in the commit body, and send them to the user if you have a file-sending tool.
3. **Tracker (on DONE):**
   - Add a §3 Wave AI row for Issue 193.
   - Delete Issue 193's Unresolved block.
   - In this guide's §9 table, replace the AI8 row's `Inspector reading → AI15` with the result.
   - In `docs/design_ui_direction.md` §9 (accessibility), add one sentence: *the named controls were read in Accessibility Inspector on <date>, matching the semantics tree*.
4. `git status --porcelain` shows only docs. The doc gates (all five evidence invocations, web strings, decks) exit 0.

**Blast radius:** `docs/ongoing_general_errors.md`, `docs/design_ui_direction.md`. Nothing else.

---

## 9. Already delivered — do NOT rework

### Wave AI steps 1–10 — verified October 12, 2026

Each row's falsification was **re-run independently** in a scratch copy of `HEAD` (reset between runs; every fault compiled). Control: the nine test files pass 69/69 on unmodified `HEAD`.

| Item | What shipped | Falsification re-run October 12 |
|---|---|---|
| **AI1** (178 → B) | CocoaPods removed; Swift Package Manager only; iOS release build is the ninth gate. | Build gate exit 0 on `da73408`; `grep -c Pods` = 0; no `Podfile`. Commit records parent exit 1 → exit 0. |
| **AH1** | `unknown` → *"Could not reach the parlour. Check your connection and try again."* for create and join. | Revert → exactly its 2 tests fail. Physical-iPhone check closed by acceptance (**Issue 192 → B**, see accepted equivalents). |
| **AI2** (191 → A) | README runs `flutter analyze lib test` and points here for the info count; duplicate blockquote gone. | `grep -c 188 README.md` = 0. |
| **AI3** (179 → A) | House Rules chip labels ink; `test/helpers/rendered_contrast.dart` pixel helper. | Revert → chips fail at **1.02 : 1** at both text scales. |
| **AI4** (181 → A) | `GaslightConfirmDialog` for all six confirmations; lobby headings brass. | Confirm label → oxblood fails the contrast test; a stray `AlertDialog` fails the routing source scan. |
| **AI5** (182 → A) | Vote subtitles ivory @ 0.75; card cue and `OPTION` label ink @ 0.7. | Revert → subtitles at **1.23 : 1** fail. |
| **AI6** (180 → A) | Voters column `ConstrainedBox(maxWidth: 92)`. | Revert → overflow plus starved answer; 5 fail. |
| **AI7** (184 → A) | `PrimaryButton` labels `FittedBox(scaleDown)`; unmask heading and game-over stat wrap. | Revert → 11 truncation cells fail. |
| **AI8** (187 → A) | 44-pt hit boxes and spoken names for kick, share, tokens, PREV/NEXT, dots, `PEEK INSIDE`. | Revert → 10 guideline/semantics tests fail. **Read in Accessibility Inspector on October 12 (AI15, Issue 193 → B):** every named control reports its label with the Button trait — Selected on the chosen token and the current option's dot, Not Enabled on PREV at the first option and NEXT at the last, each kick badge its own element beside the tile's `<name>`. What VoiceOver speaks on a device is still unheard. |
| **AI9** (186 → A) | All six settings writes go through `_applySetting`; `LobbyAction.settings` sentences. | One site made fire-and-forget again → its tests fail. |

### Earlier waves
- **Wave AG** (AG1 error mapping, AG2 chip-header ivory, AG3 ledger on waiting screens) — verified October 3.
- **Wave AA** (sixteen items, Issues 153–169, 160, 162) — verified September 11.
- **Wave Z (152)** leave latch in a `finally` · **Y1 (151)** · **Y2 (149)** · **X1 (147)** · **X2 (148)** · **W1 (146)** · **W2 (145)** · **V1 (143, 144)** · **U1–U5**, **S1**, **R0–R2**, soak blocks **E22–E49**, Waves **Q/P/O**, Issues **96–105, 50–95, 31, 28/29**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22** · build **1.1.0 (8)** on TestFlight.

### Accepted equivalents — do NOT "fix" these back

- **AH1's required device check is the simulator observation plus the source trace, not a physical iPhone** (Issue 192 → B, chosen by the user October 12).
  - On the SE simulator, −1004 (`Could not connect to the server.`) was observed arriving as `unknown` and showing the connection sentence.
  - −1009 (no network on a phone) is **inferred** from the vendored source (firebase-ios-sdk 12.15.0 → cloud_functions 6.3.5 → platform interface 6.0.5), not observed.
  - Do not re-open this or ask for a device for it. **The trigger that would re-open it:** a tester reports *Something went wrong. Try again.* while offline. That is a new issue, not a widening of the mapping.
- **AI7: the unmask heading and the game-over stat line use `maxLines: 3`, not the specified 2.** Measured with the real Lora and Cormorant Garamond fonts: two lines cannot hold either string at 320 pt × 1.3. `PrimaryButton`'s scale at 320 pt × 1.3 measured **0.653** (the STOP threshold was 0.6).
- **AI8: the named-control recipe is `Semantics(container: true, button: true, label: …, onTap: <the same callback>, excludeSemantics: true, child: …)`.** `excludeSemantics` alone drops the gesture's tap action; without `container: true` the kick label merged into the player tile (lesson §2.46).
- **AI8 also fixed `PEEK INSIDE`** (an 8.5-pt link, 99 × 12) with an invisible 44-pt-tall box — the guideline run found it.
- **The stacked deck's jump-dot slots are 44 pt wide only while they fit** (AI8, `card_grid.dart`). With 5 or more options on a 375-pt phone, or 3 or more on a 320-pt one, the `Flexible` slots shrink below 44 pt wide and PREV / NEXT (44 pt tall) are the accessible path. Do not "fix" it by letting the row overflow (without the `Flexible`, nine 44-pt slots overflow a 320-pt row by 300 px).
- **The vote screen's deck row cannot be judged by `meetsGuideline(iOSTapTargetGuideline)`**: it is flush with its scroll view's edges, which the guideline skips by design. `test/tap_target_guidelines_test.dart` asserts those sizes directly — do not "simplify" that back to the guideline.
- **AI5 lowered the analyzer count to 186** by replacing two `withOpacity` calls with `withValues` — not a regression of the 188 bar. **AI12 lowered it to 170** by migrating the 16 other `deprecated_member_use`.
- **The target's attribution UI is a separate chip row, not an interactive option grid** (AA16b) · **AA16b enforces one-player-per-option on the client** · **AA5 ships one stem list per prompt** · **AA8's phase guard on `setReady`** · **`GameService.kMissingAnswerPlaceholder` stays** · **Waves Y1, Z1, AA bumped `pubspec.yaml` in their own commits** · **`EmberBackdrop` and `AnimatedThinkingBackground` keep `..repeat()`** · **E48 / E49 / P4 records**.
- **`use_build_context_synchronously` × 4** guard `State.context` with `context.mounted` — equivalent to `mounted`.
- **`marionette_flutter` is in `dependencies`** — tree-shaken from release (0 strings in the 1.1.0 (8) binary), no native code.

---

## 10. Invariants & intentional decisions — do NOT change

- **There is no CocoaPods.** Do not reintroduce a `Podfile` (AI1).
- **Every confirmation dialog goes through `GaslightConfirmDialog`** (AI4) — `AlertDialog(` appears only in `lib/widgets/confirm_dialog.dart`; `test/confirm_dialog_routing_test.dart` scans for it.
- **Every host settings write goes through `_applySetting`** (AI9).
- **Rendered contrast is measured from pixels** (`test/helpers/rendered_contrast.dart`).
- **Named icon controls follow the AI8 `Semantics` recipe** (§9 accepted equivalents).
- **The seven `DEBUG:` buttons stay in the source, gated.** **`PrivacyInfo.xcprivacy` stays in the Runner target.** **The 1024 icon has no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** **`allow get` and `allow list` are split on `/rooms`.** **`sealed` and `embeddings` are default-deny.**
- **`votes` stores opaque option UUIDs during the vote phase.** **Never send other players' authorship before the unmask window closes.** **Never let a client bound exceed the server's.** **The presence window gates the ACTION, not the caller.**
- **`pendingScoreDeltas` is flushed at three sites.** **The option id is the authority; text is the fallback.** **The readiness gate exempts the host deliberately** (`!== true`). **The 3-player floor applies in play as well as at start.**
- **Error surfaces match on `e.code` (and, after AI11, `e.details['reason']`), never on the message.** **On iOS a dropped connection is `unknown`** — it belongs to the connection sentence (AH1).
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.** **Timers default OFF.** **Heartbeat 30 s** against a 10-minute server window. **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and must exceed `ROOM_TTL_MS`. **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`.** **The nightly orphan sweep is retained.** **`CLEANUP_DRY_RUN=false` is revision-scoped** — re-apply after every functions deploy.
- **`AppMotion.reduce` keeps the `accessibleNavigation` OR term.** **The title-screen version is read from the bundle at runtime.** **`main.dart`'s bootstrap is load-bearing.** **`LobbyScreen`'s `State` outlives every room** — any flag on it needs a reset in a `finally`.
- **`lastReaction` / `lastReactionAt` are deliberately retained dead fields.** **`lib/utils/prompt_decks.dart` is generated.**
- **Colour tokens name a SURFACE, not a role.** Ivory on the dark ground; ink on parchment; brass is an accent for the dark ground only (2.02 : 1 on parchment); `colorScheme.primary` is oxblood (1.78 : 1 on `groundRaised`) and `onSurface` is ink — never text on the dark ground.
- **Never render an exception object to a player.** **The web E2E string contract (Wave AE)**, **Wave AB** and **Wave AA** invariants stand as recorded in the design docs.
- **Never accept Xcode's "Update to recommended settings" dialog.**

**Assessed and rejected — do NOT re-propose:** everything listed in the September guides and the tracker §3, including **migrating `withOpacity` → `withValues` (139 C)**. **October 10 rejections:** 178 A and C; 179 B; 180 B and C; 181 B; 182 B; 183 B; 184 B; 185 B; 186 B; 187 B; 188 B and C; 189 A; 190 B. **October 12 rejections:** 192 A; 193 A and C — unless AI15's step 3(b) files a new issue that offers them again.

**There is no chat or emote feature.**

---

## 11. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Release runbook | `README.md` → Releasing |
| Playthrough material | `docs/playthroughs/` |
| Rules, seat tokens, seat recovery, presence, retention, cleanup, callable table | `docs/design_database_and_security.md` |
| `votes` contract, phases, 3-player floor | `docs/design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding, unmask close | `docs/design_scoring_and_ui.md` |
| Palette, dialogs, error surfaces, House Rules chips, buttons, tap targets, stacked deck, reveal voters | `docs/design_ui_direction.md` |
| Decks, re-roll exclusion, stems | `docs/design_prompt_system.md` |
| Pixel-measured contrast | `test/helpers/rendered_contrast.dart` |

---

## 12. Validation standard

**A falsification must compile.** A whole-commit revert that deletes a symbol the test imports fails to *load* — that is not the test failing. Use a targeted fault (October 12: AI4 and AI9 needed this).

**Reset to the commit, not the index.** `git checkout -- .` restores from the index; after `git apply --3way` the reversal is staged and survives. Use `git reset --hard HEAD` between runs (October 12: an earlier verification run's reversals accumulated and made a clean control fail).

**A tap-target guideline pass is evidence only about the nodes it evaluated** — it skips hidden nodes, nodes with no tap action, and nodes flush with a scrollable's edge (lesson §2.46). Assert the controls you care about directly.

**A SnackBar count means nothing unless the screen starts with none** (lesson §2.47).

**Measure rendered contrast from pixels.** **Prove a platform behaviour on the real toolchain before relying on it.** **An "already fixed" twin can be half-fixed.** **A guard flag lives as long as the object holding it.** **Write the test for the journey, not the defence.** **A test that reconstructs the world hides state bugs.** **A prediction followed by a matching outcome beats either alone.** **Re-run every gate yourself before trusting a table.** **Open the artefact and ask what it shows.** **Read exit codes bare.**

---

## THE LOOP

```
(1) Take the next step in §2 order (AI15 first). Never fill in or edit a
    `Your selection:` line. Ask for app access only where AI15 says, once.
(2) "Implemented to spec" and "fixed the problem" are different claims. Check
    the second against the ORIGINAL REPORT in the tracker, not the spec.
(3) If a fix depends on how a platform or library behaves, read the vendored
    source or prove it on the real toolchain first.
(4) A load-bearing check is REQUIRED, and its outcome goes in the commit body
    either way: DONE with the result, or NOT RUN with the reason.
(5) An EMPTY result is not evidence until the same query has been seen to
    return something. Never use `timeout` on macOS.
(6) zsh: no word-splitting of unquoted variables; an unmatched glob aborts the
    command; a word starting with `=` is expanded. Use bash for scripts.
(7) A falsification that fails to COMPILE proves nothing. Inject a fault that
    builds; reset with `git reset --hard`, not `git checkout -- .`.
(8) A fix applied to one of two twins is half a fix. Fix siblings through ONE
    shared path (AI11: craft and reveal share one mapper).
(9) A test is only as wide as what it walks; assert you inspected the parts
    that matter (non-vacuity counts; known-empty SnackBar start).
(10) COLOUR: tokens name a SURFACE. Measure from pixels.
(11) Never show an exception object to a player. Map e.code (+ details.reason).
(12) A rename broke a test? UPDATE THE ASSERTION, never the production code.
(13) Server changes the shipped client reads must be ADDITIVE (1.1.0 (8)).
(14) Read exit codes BARE.
(15) RE-RUN THE FULL BATTERY — all nine gates bare; analyze bar 0/0/170;
     functions tests 167.
(16) COMMIT: ONE ITEM, ONE Conventional Commit, WHY + Falsification + Device
     check in the body; tracker updated in the same commit. Ask before any
     deploy; never upload to TestFlight.
```

## Definition of Done for this wave

- [ ] AI15's readings committed (or `Device check: NOT RUN` with the reason, plus the step 3(b) issue if that path was blocked).
- [ ] AI10–AI13 each committed separately in §2 order; AI14's findings recorded (it may run in parallel).
- [ ] Each code commit body has `Falsification:` (compiling faults); every commit body has a `Device check:` line (DONE or NOT RUN with reason).
- [ ] All nine §1 gates green bare; analyze **0 / 0 / 170**; flutter tests at least **423** passing; functions tests **167**; after AI11's deploy `check_deploy_fresh.sh` FRESH and `CLEANUP_DRY_RUN=false` read back (or `Deploy: NOT RUN` recorded if the user declined).
- [ ] Issues 183, 185, 188, 189, 190 and 193 moved to the tracker's §3 index; design docs updated per each blast radius.
- [ ] §1 of this guide re-measured and rewritten as the new baseline.

**When AI14 is done the queue is empty. Do not invent work.** The only legitimate triggers for further action are: a new user selection (including on any issue AI15 files), a §1 gate going red (investigate and file), or a user report.
