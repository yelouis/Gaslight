# Agent Execution Guide — Active Build: release 1.2.0 (9) (AJ1) — October 13, 2026

**You are an engineering agent with no memory of this project.**

**Where things stand.** Wave AI came from a read-only audit on October 10 (Issues 178–191) plus two October 12 follow-ups (192, 193). All sixteen of its items, AI1–AI15 and AH1, are built, and AI11's server change is deployed. **The whole wave was verified on October 13** by re-running every gate and re-falsifying every item in scratch clones (§3).

**One item is approved: AJ1 (§2), the release of 1.2.0 (9).** The user confirmed the version in chat on October 13. Wave AI's last item, AI16 (`75abb36`), recorded Issue 194 → A. AJ1 changes one line of the app plus docs; when it is done the queue is empty. **Do not invent work.**

**If work arrives** (a selection, a red gate, a user report), these rules apply:
- **Every number and literal string in a spec is a decision, not a suggestion.** Implement it as written.
- **If a value turns out to be impossible:** keep the intent, deviate minimally, measure the deviation, and say so in the commit body.
- **If the design itself cannot work:** STOP and file it in `docs/ongoing_general_errors.md` with options, *Pros*/*Cons*, one `(recommended)` and a `Your selection: _____` line. Do not improvise.

---

## 0. Standing constraints — for any future item

1. **One item = one local Conventional Commit**, with the WHY in the body and the tracker update (§0.9) in the same commit. Do not push.
2. **Falsify every new test.** Inject the fault, run the test, watch it fail, restore.
   - The fault must **compile**: a test that fails to *load* proves nothing.
   - When reverting a whole commit would delete a symbol the test imports, inject a targeted fault instead.
   - Paste the failing output under `Falsification:`.
3. **Read exit codes bare:** never through `| tail`, never through `timeout` (macOS has none). An empty result means nothing until the same query has been seen to return something (lesson §2.44).
4. **New code adds zero analyzer infos.** Use `.withValues(alpha: x)`, never `.withOpacity(x)`, and no `print`. `flutter analyze lib test` must stay at **0 errors · 0 warnings · 170 infos**.
5. **Strings are verbatim:** copy, keys, labels, punctuation, the em dash.
6. **Server changes are additive only.** Build **1.1.0 (8)** is on testers' phones and still matches on `HttpsError` message text, so a message string never changes; a new `details` field is fine.
7. **Rendered contrast is measured from pixels** with `test/helpers/rendered_contrast.dart` (`measureRenderedContrast`), never with the widget-tree walk in `test/contrast_tokens_test.dart`.
8. **Deploy procedure** (only when an item changes `functions/src` or `firestore.rules`):
   1. **Ask the user for the go-ahead first** — a deploy changes production. Never deploy uncommitted code.
   2. `firebase deploy --only functions`.
   3. `gcloud run services update cleanupdaily --region us-central1 --project gaslight-46368 --update-env-vars CLEANUP_DRY_RUN=false`.
   4. Read the flag back from the new revision.
   5. Run `./scripts/check_deploy_fresh.sh` bare; it must exit 0.

   **Never upload to TestFlight** unless the user asks.
9. **Tracker update per item:**
   - Add one row at the top of `docs/ongoing_general_errors.md` §3 (what shipped, deviations, where the contract lives).
   - Update the design doc the item's blast radius names.
   - Delete the issue block from "Unresolved".
   - **Never fill in or edit a `Your selection:` line.**
10. **Never accept Xcode's "Update to recommended settings" dialog** (lesson §2.29). Edit `project.pbxproj` as text.
11. **A load-bearing manual check is REQUIRED, and its outcome goes in the commit body either way:** `Device check: DONE — <what you saw>` or `Device check: NOT RUN — <reason>` (lesson §2.45).
12. **SnackBar assertions name the exact text and start from a known-empty screen** (lesson §2.47).
    - A parlour reached through `tryRejoinSession` already shows *"Rejoined active game session!"*.
    - Pump ~6 s and assert `find.byType(SnackBar)` `findsNothing` before the action under test.
    - Assert `tester.takeException()` is `null` explicitly.
13. **A `catch` is tested only if a test throws from outside the `try` it sits on** (lesson §2.48). AI10's outer catch was reachable only through a test whose *first read* throws.

### 0.1 Environment — each of these cost a cycle

- **Builds and tools**
  - **iOS builds work** through Swift Package Manager only (AI1 removed CocoaPods). There is **no `Podfile`**; never reintroduce one.
  - **`~/.local/bin/git` cannot clone over https** — prefix `PATH="/usr/bin:$PATH"`.
  - **zsh:** a word starting with `=` is expanded (`echo =====x` fails) and an unmatched glob aborts the command. Use bash for scripts.
- **Emulators**
  - **Start them by hand with** `PATH="/opt/homebrew/bin:/opt/homebrew/opt/openjdk/bin:$PATH" npx firebase-tools emulators:start --only auth,functions,firestore`. Run the app with `flutter run -d <udid> --dart-define=USE_EMULATOR=true`.
  - `npm --prefix functions test` starts its own emulators on the same ports, so stop hand-started ones first.
  - **Stop only the processes you started.** This Mac runs many Claude sessions, each with its own `npm exec firebase-tools@latest mcp`. Never `pkill` by a `firebase` or `emulator` pattern; use `kill -INT <the PID of the emulators:start you launched>`.
  - **To land a callable after a server deadline** (AI11), `kill -STOP` the Functions/Auth emulator process you started, tap while the button is still up, then `kill -CONT` after the deadline. A hand tap cannot beat a UI that disables itself at the deadline.
  - **To play a short game with the debug bots** (AI12), delete surplus bots from your emulator over its REST API before starting.
- **Simulators**
  - **Stale Keychain trap:** a simulator that ran the app against an *earlier* emulator session fails every callable with `[firebase_functions/unknown] An internal error has occurred`. Before any device check, use a fresh simulator or run `xcrun simctl keychain <udid> reset`.
  - Leave the user's pre-existing "iPhone 17" simulator alone. Use the "iPhone SE (3rd generation)" on iOS 26.5; if none exists, create one with `xcrun simctl create "iPhone SE (3rd generation)" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-26-5`.
  - **No Simulator.app on this Xcode** (DeviceHub.app shows simulators instead), and **`simctl` cannot rotate.** Set text size with `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large` (the app clamps to 1.3); restore it with `large`.
  - **A native iOS sheet (the share sheet) cannot be dismissed from marionette,** and `simctl` has no tap. End it with `xcrun simctl terminate <udid> com.whylabs.gaslight`; relaunching auto-rejoins the saved room. Plan native-sheet checks last in a session.
  - **Marionette:**
    - Text taps and `scroll_to` fail on off-screen widgets; swipe first.
    - In the parlour, the House Rules and `DEBUG:` buttons sit on the page behind the `DraggableScrollableSheet`. Drag the sheet handle down (y≈230→640), then swipe the page (y≈300→70, ×3).
    - Failed marionette calls show up in `get_runtime_errors` as `ext.flutter.marionette.*`; they are not app errors.
- **App access:** none is granted now. AI15's one-time Accessibility Inspector grant is used up.
  - DeviceHub and the simulator panel's per-device grant stay declined.
  - Work headless: `xcrun simctl io <udid> screenshot f.png`, marionette, and the VM service. A semantics-tree dump over the VM service (`ext.flutter.debugDumpSemanticsTreeInTraversalOrder`) reads accessibility labels without any grant.
  - If a check truly needs an app, ask the user in chat once.
  - The Inspector's target picker is a pop-up menu that computer-use tools cannot open; on October 12 the user picked the target by hand.
- **Coverage:** `flutter test --coverage` is broken on Flutter 3.44.6 and 3.47.7 (a Dart VM crash in `getSourceReport`, and `lib/services` and `lib/models` missing from the LCOV; tracker §1 has AI14's findings). **Never use it for validation.** Re-try only when the Flutter SDK is upgraded for another reason: one `--coverage` run of `test/lobby_create_error_test.dart`; the full suite only if that LCOV contains `game_service.dart` (Issue 194 → A).

---

## 1. Verified baseline — measured October 13, 2026 on `27a6314` (code unchanged through `75abb36`: only docs changed since)

**This is the regression bar.** Every gate was run bare in the verification session.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 170 infos · exit 1** (137 `deprecated_member_use`, all of them `withOpacity` — the rejected 139 C migration) |
| `flutter test` | **466 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **167 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five**: no-arg, `docs/playthroughs/findings_marionette.md`, `…/findings_web.md`, `…/findings_5player.md`, `…/findings_waveAA.md` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH, 19 functions.** It reads STALE after any later commit touching `functions/src` until the next deploy. |
| `./scripts/check_web_e2e_strings.sh` | **exit 0** |
| `flutter build ios --release --no-codesign` | **exit 0 — `✓ Built build/ios/iphoneos/Runner.app (50.1MB)`**; `UIDeviceFamily` = `1` (iPhone-only) |
| `flutter test --coverage` | **Not a gate.** *Coverage is not collectable on Flutter 3.44.6 (runner segfault; `game_service.dart` missing from LCOV) — see Issue 189 findings.* Not reported upstream (Issue 194 → A). |

**Production** (read October 13, read-only):
- 19 functions deployed (18 callables + `cleanupDaily`). The Firestore rules release is newer than the last `firestore.rules` commit (August 20), per `check_deploy_fresh.sh`.
- `cleanupdaily` serves `cleanupdaily-00020-7tq` at 100 % with `CLEANUP_DRY_RUN=false`.
- 0 function-log entries at WARNING or above since the October 13 deploy. The first nightly cleanup after it ran with `dryRun=false, errors=0`.

**⚠️ `flutter analyze lib test` exits 1 even when clean** — judge it by the counts. Never run bare `flutter analyze`.

---

## 2. AJ1 — Ship 1.2.0 (9) (approved by the user in chat, October 13)

**What this means for the user.** Testers are still playing 1.1.0 (8), which predates every Wave AI fix. Until a new build ships, none of the sixteen fixes reach a phone, and the web app still runs the old client code too. This item builds and verifies 1.2.0 (9) on both surfaces. It deploys the web app with your go-ahead, and leaves an iOS archive ready for **you** to upload from Xcode's Organizer.

**⚠️ AJ1 is a release, not a code change.** Exactly **one line** of the application changes: the version in `pubspec.yaml`. Everything else is procedure and verification. **If you find yourself editing a test, a screen, a script or a plist, stop — you have left the item.**

**The gap, measured October 13:**
- `pubspec.yaml:19` reads `version: 1.1.0+8`.
- **Stale artefacts that would mislead verification:**
  - `build/ios/archive/Runner.xcarchive` is dated October 11, 00:07 and reads 1.1.0 (8) with `UIDeviceFamily` `{ 1, 2 }`. It predates AI13.
  - `build/ios/ipa/` holds August 25 leftovers (`DistributionSummary.plist`, `ExportOptions.plist`, `Packaging.log`).
  - `build/web/` holds the 1.1.0 (8) web build.
- **Signing:** this Mac has **only an Apple Development identity**, so the `.ipa` export step will fail — expected, see step 4.
- **Server:** the functions are unchanged since AI11's deploy (`check_deploy_fresh.sh` exit 0). **Do not deploy functions.**

### 2.1 The only application change
`pubspec.yaml`: `version: 1.1.0+8` → **`version: 1.2.0+9`**. That is sufficient:
- `ios/Runner/Info.plist` takes `CFBundleShortVersionString` from `$(FLUTTER_BUILD_NAME)` and `CFBundleVersion` from `$(FLUTTER_BUILD_NUMBER)`.
- The title-screen label reads the running bundle through `PackageInfo.fromPlatform()`.
- The web build writes `build/web/version.json` from the same line.

**⚠️ Do not touch `test/lobby_version_test.dart`.** It mocks `9.9.9` and `1.0.0` on purpose, to test the label's *format* independently of the shipped version. `flutter test` must still report **466** after the bump.

### 2.2 Procedure
0. **If `git status --porcelain` shows the two docs modified,** commit them **unmodified** first, on their own: `docs: commit the October 13 AJ1 spec and verification notes, unmodified`. If anything outside `docs/` is modified, STOP and ask the user.
1. **Bump** `pubspec.yaml` as in §2.1.
2. **Preflight:** run all nine §1 gates bare. The numbers must equal §1 exactly: 0 / 0 / 170, 466, 167, and the rest exit 0. A release is the one moment the whole battery must be green at once.
3. **Delete the stale artefacts:**
   - `ls -la build/ios/archive build/ios/ipa build/web` first, to confirm they are the ones named above.
   - Then `rm -rf build/ios/archive build/ios/ipa build/web` (`/build/` is git-ignored).
   - From here on, anything under `build/` was produced by your run.
4. **`flutter build ipa`** — read its output, not just the exit code.
   - **Expected:** `✓ Built build/ios/archive/Runner.xcarchive`, followed by an export error (`No Accounts` / `No signing certificate "iOS Distribution" found`) and a non-zero exit. That outcome is a **pass**.
   - **If the ARCHIVE step itself fails, STOP.** This is the first signed archive since AI1 removed CocoaPods. Record the error verbatim and file it in the tracker with options. Never "fix" it by accepting Xcode's settings dialog or by reintroducing a `Podfile`.
5. **Verify the archive, never an `.ipa`.**
   - The paths: `X=build/ios/archive/Runner.xcarchive`, `A=$X/Products/Applications/Runner.app`.
   - **Required values:**

     | Check | Required |
     |---|---|
     | `stat -f "%Sm" $X` | a timestamp from this run |
     | `PlistBuddy :ApplicationProperties:CFBundleShortVersionString` on `$X/Info.plist` | `1.2.0` |
     | `PlistBuddy :ApplicationProperties:CFBundleVersion` on `$X/Info.plist` | `9` |
     | `PlistBuddy :UIDeviceFamily` on `$A/Info.plist` | only `1` (the stale archive read `{ 1, 2 }` — your before/after) |
     | `:MinimumOSVersion` | `15.0` |
     | `:CFBundleDisplayName` | `Gaslight` |
     | `:ITSAppUsesNonExemptEncryption` | `false` |
     | `test -f $A/PrivacyInfo.xcprivacy` | exit 0 |
     | `strings $A/Frameworks/App.framework/App \| grep -c marionette` | `0` |

   - **Positive control for the `0`:** on the same binary, `strings $A/Frameworks/App.framework/App | grep -c 'Could not reach the parlour'` must be `1`. A release AOT binary carries the app's UI strings, so the search can see Dart text; without this, the `0` proves nothing (lesson §2.44). (Do not use a debug build as the control: its Dart code lives in `kernel_blob.bin`, not `App.framework`. Checked October 13 on the release `build/ios/iphoneos` app: marionette `0`, control `1`.)
6. **Title-screen version (Device check, REQUIRED):**
   - Use the iPhone SE simulator with a reset Keychain (§0.1).
   - Run `flutter run -d <udid> --dart-define=USE_EMULATOR=true` with the emulators up.
   - The title screen must show **`v1.2.0 (9)`** beneath READ MANUAL. Swipe up if it sits below the fold.
   - Take a screenshot via `xcrun simctl io <udid> screenshot`.
7. **Web smoke on emulators — the first web run since Wave AI:**
   - Run `flutter build web --release --dart-define=USE_EMULATOR=true -o <scratch>/web_smoke`. It goes to **scratch, never `build/web`**: this build talks to the emulators and must never be deployed.
   - With **your** emulators running (§0.1), serve it: `python3 -m http.server 8777 --bind 127.0.0.1 --directory <scratch>/web_smoke` in the background.
   - From `test/web_e2e/`, run `node run_full_playthrough.js` and `node run_match_summary_playthrough.js`. Read each exit code bare; Playwright's Chromium is already installed.
   - Stop the server and **your** emulator process afterwards.
   - **If a script fails,** read its screenshots.
     - An app defect, or a script that no longer matches a correct screen, is filed in the tracker with options. **Do not edit the scripts or the app in this item.**
     - **The web deploy (steps 8–9) does not happen.** The iOS part continues; the two surfaces are independent.
8. **Web release build:**
   - Run `flutter build web --release` with **no** `--dart-define`, into the default `build/web`.
   - `build/web/version.json` must read `"version":"1.2.0"` and `"build_number":"9"`, with a timestamp from this run.
   - `grep -c '^USE_EMULATOR=true' .env` must be `0`. **Never print `.env` values.**
   - `test -f build/web/assets/.env` must exit 0: the app dies before painting without it (README → Releasing).
9. **Web deploy — ask the user for the go-ahead first; it changes production.**
   - Run `npx firebase-tools deploy --only hosting` bare; it must exit 0.
   - Then check the live site:
     - `curl -s "https://gaslight-46368.web.app/version.json?t=$(date +%s)"` must show 1.2.0 and 9;
     - `curl -s -o /dev/null -w '%{http_code}' https://gaslight-46368.web.app/assets/.env` must return `200`. Status only — never print the body.
   - If the user declines, record `Web deploy: NOT RUN — <reason>`.
10. **Do not upload to TestFlight, do not open Organizer's Distribute flow, and do not deploy functions.** The upload needs the user's Apple account. Hand over instead (step 12).
11. **One commit:** `chore(release): ship 1.2.0+9 (Wave AJ / AJ1)`.
    - **Files:** `pubspec.yaml`, plus the docs:
      - a tracker §3 row: what shipped, the archive values, the smoke and deploy results;
      - this guide: §1's "Release plumbing" names 1.2.0 (9) as archived, upload pending; the guide returns to queue-complete mode (title, framing, §2 "Queue — empty", THE LOOP step (1), close-out).
    - Don't try to write the commit's own hash into it; a commit cannot contain its own hash.
    - **Body:** the WHY, the step-5 table as measured, `Falsification:` (the stale archive's 1.1.0 / 8 / `{ 1, 2 }` against the new 1.2.0 / 9 / `{ 1 }`, and the `marionette` count with its `Could not reach the parlour` control), `Device check: DONE — v1.2.0 (9) …`, the web smoke exit codes, and `Web deploy: DONE …` or `NOT RUN …`. Do not push.
12. **Hand-off to the user, in your final message:**
    - **Upload:** `open build/ios/archive/Runner.xcarchive` → Organizer → **Distribute App** → **App Store Connect** → **Upload**, letting Xcode manage signing.
    - **In App Store Connect → TestFlight:** add the build to internal testers, **expire build 8**, and paste the *What to Test* text below.
    - **iPad testers,** if any, now get the iPhone app in compatibility mode (AI13).

**What to Test (paste verbatim into App Store Connect):**

> 1.2.0 (9) — fixes from the October audit:
> • Reopen the app on a bad connection and you keep your seat, with a RETRY button, instead of being told your session expired.
> • An accusation that lands just as the unmask countdown ends now says the guessing window has closed.
> • Easier-to-read House Rules chips, vote screen text and confirmation buttons; no cut-off labels on small phones.
> • Bigger tap targets and spoken names for icon buttons (VoiceOver).
> • iPhone-only build.
> Please try: (1) turn on Airplane Mode, then tap CREATE ROOM — it should say "Could not reach the parlour. Check your connection and try again." (2) If you use VoiceOver, swipe through the lobby and the vote screen and tell us anything that isn't read clearly.

### 2.3 Validation summary
- **Falsifying:** the archive's values differ from the deleted stale archive in exactly the intended ways — version 1.2.0, build 9, `UIDeviceFamily` `{ 1 }`.
- **Over-reach guard:** `git diff --stat` for the release commit shows `pubspec.yaml` and docs only; `flutter test` still 466 with `test/lobby_version_test.dart` untouched.
- **Load-bearing checks (REQUIRED):** the title screen's `v1.2.0 (9)`, both web playthroughs, and the live `version.json` (if deployed). Each outcome goes in the commit body either way.

**Blast radius:** `pubspec.yaml`, `docs/ongoing_general_errors.md`, `docs/agent_execution_guide.md`. No design doc: a version number is not a design contract.

---

## 3. Already delivered — do NOT rework

### Wave AI — verified October 12 (AI1–AI9, AH1) and October 13 (AI10–AI15)

Each row's falsification was **re-run independently** in a scratch clone of `HEAD`, reset with `git reset --hard` between runs; every fault compiled. Controls: October 12, the nine guard files pass 69/69; October 13, the four new client test files pass 43/43.

| Item | Commit | What shipped | Falsification re-run |
|---|---|---|---|
| **AI1** (178 → B) | `356c5c3` | CocoaPods removed; Swift Package Manager only; the iOS release build is the ninth gate. | Build exit 0; no `Podfile`; parent build exit 1. |
| **AH1** | `0e7b377` | `unknown` → *"Could not reach the parlour. Check your connection and try again."* for create and join. | Revert → exactly its 2 tests fail. The physical-iPhone check was closed by acceptance (192 → B). |
| **AI2** (191 → A) | `4addbdb` | README runs `flutter analyze lib test` and points here for the info count. | `grep -c 188 README.md` = 0. |
| **AI3** (179 → A) | `1500804` | House Rules chip labels ink; the pixel-contrast helper. | Revert → chips at **1.02 : 1**. |
| **AI4** (181 → A) | `2bd7ebd` | `GaslightConfirmDialog` for all six confirmations; lobby headings brass. | Oxblood confirm fails the contrast test; a stray `AlertDialog` fails the source scan. |
| **AI5** (182 → A) | `d372cc1` | Vote subtitles ivory @ 0.75; card cue and `OPTION` label ink @ 0.7. | Revert → **1.23 : 1**. |
| **AI6** (180 → A) | `3c7e7a1` | Voters column `ConstrainedBox(maxWidth: 92)`. | Revert → 5 fail. |
| **AI7** (184 → A) | `40b6c64` | `PrimaryButton` labels `FittedBox(scaleDown)`; unmask heading and game-over stat wrap. | Revert → 11 fail. |
| **AI8** (187 → A) | `19a2713` | 44-pt hit boxes and spoken names for kick, share, tokens, PREV/NEXT, dots, `PEEK INSIDE`. | Revert → 10 fail. Read in Accessibility Inspector by AI15. |
| **AI9** (186 → A) | `da73408` | Six settings writes through `_applySetting`; `LobbyAction.settings` sentences. | One site fire-and-forget again → its tests fail. |
| **AI15** (193 → B) | `5bef8d7` | Inspector readings: every named control has its label and the Button trait; Selected and Not Enabled follow state; each kick badge is its own element. | Docs only. The readings match the semantics tree. |
| **AI10** (183 → A) | `d06fe1d` | Auto-rejoin keeps the seat unless the server rejects it definitively; the connection SnackBar offers RETRY (10 s). | Wipe on any error → **14** fail; outer catch → `expired` → **1** fails; lobby connection branch off → **4** fail. |
| **AI11** (185 → A) | `4d2d686`, deploy `d445ade` | `details.reason` on three `HttpsError`s; `gameCallableErrorMessage` for craft and reveal; deployed with the user's go-ahead October 12. | Old reveal `toString()` → **2** fail; mapper drops `deadline_passed` → **3**; craft message match → **2**; server reason dropped → exactly its emulator case (166 / 1); `callFn` without `details` → exactly the 3 new cases (164 / 3). |
| **AI12** (190 → A) | `bfa9b18` | The 16 non-`withOpacity` deprecations migrated, with identical output. | Revert → **186** infos, 16 non-`withOpacity` deprecations; `HEAD` 170 and 0. |
| **AI13** (188 → A) | `6011202` | `TARGETED_DEVICE_FAMILY = 1` in all three Runner configurations: iPhone-only. | Built `UIDeviceFamily` `{ 1 }`; it was `{ 1, 2 }` on October 12. |
| **AI14** (189 → B) | `3bccfb3` | Coverage investigated: outcome (c), nothing works; the crash is in the Dart VM; 3.47.7 has it too. | Spot check: `game_service.dart` 0, control `lobby_screen.dart` 1. **Correction:** the other absent files vary between runs (36 source files on October 13, 20 for AI14). |
| **AI16** (194 → A) | `75abb36` | Decision recorded; no code. | Docs only; §2.2's checks re-run with positive controls, doc gates exit 0. |
| **192 → B** | `3a36e91` | AH1's device check closed by acceptance (simulator observation plus source trace). | Nothing to falsify. |

### Earlier waves
- **Wave AG** (AG1 error mapping, AG2 chip-header ivory, AG3 ledger on waiting screens) — verified October 3.
- **Wave AA** (sixteen items, Issues 153–169, 160, 162) — verified September 11.
- **Wave Z (152)** leave latch in a `finally` · **Y1 (151)** · **Y2 (149)** · **X1 (147)** · **X2 (148)** · **W1 (146)** · **W2 (145)** · **V1 (143, 144)** · **U1–U5**, **S1**, **R0–R2**, soak blocks **E22–E49**, Waves **Q/P/O**, Issues **96–105, 50–95, 31, 28/29**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · **iPhone-only** (`UIDeviceFamily` 1) · Node **22** · build **1.1.0 (8)** on TestFlight. That build predates Wave AI; a new build is the user's call.

---

## 4. Accepted equivalents — do NOT "fix" these back

**Wave AI**
- **AH1's required device check is the simulator observation plus the source trace, not a physical iPhone** (Issue 192 → B).
  - −1004 was observed arriving as `unknown`.
  - −1009 (no network on a phone) is **inferred** from the vendored source.
  - **The trigger that re-opens it:** a tester reports *Something went wrong. Try again.* while offline. That is a new issue, not a widening of the mapping.
- **AI10: RETRY is `textColor: AppColors.brass`.** An unstyled `SnackBarAction` rendered black on the ink SnackBar at **1.30 : 1**; brass measures **6.71 : 1**. `test/rejoin_failure_test.dart` measures both.
- **AI10: a missing room or player document now clears the saved keys.** Before AI10 it left them behind.
- **AI11: `test/fake_functions.dart` carries `details: {'reason': 'too_similar'}`.** It is the in-memory twin of the server; without it the unedited `test/ui_e2e_test.dart` fails for the right reason. Its `submitUnmaskGuess` throws stay plain `Exception`s and read as the generic sentence.
- **AI11: the `already_submitted` emulator case uses a 4-player room with two fooled voters.** With one, the window closes on the first guess and a second guess meets `deadline_passed`.
- **AI12: the two `Matrix4` sites hoist the scale into a local** (`tokenScale`, `scale`) before `scaleByDouble(x, x, x, 1.0)`; the numbers are the same.
- **AI15: the avatar tokens live on the entry screen, not the parlour.** Kick badges were read in the Inspector for Bots 1–3 of 9; the tree dump shows all nine identical.
- **AI7: the unmask heading and the game-over stat line use `maxLines: 3`, not 2.** Measured with the real fonts, two lines cannot hold either string at 320 pt × 1.3. `PrimaryButton`'s scale there is **0.653**.
- **AI8: the named-control recipe is `Semantics(container: true, button: true, label: …, onTap: <the same callback>, excludeSemantics: true, child: …)`** (lesson §2.46).
  - AI8 also fixed `PEEK INSIDE` with an invisible 44-pt-tall box.
  - The jump-dot slots are 44 pt wide only while they fit: with 5+ options on a 375-pt phone, or 3+ on a 320-pt one, PREV / NEXT are the accessible path.
  - The vote deck row cannot be judged by `meetsGuideline(iOSTapTargetGuideline)` (it is flush with its scroll view's edges), so `test/tap_target_guidelines_test.dart` asserts sizes directly.
- **The analyzer bar went 188 → 186 (AI5) → 170 (AI12).** Neither drop is a regression.

**Earlier waves:** the target's attribution UI is a separate chip row (AA16b) · AA16b enforces one-player-per-option on the client · AA5 ships one stem list per prompt · AA8's phase guard on `setReady` · `GameService.kMissingAnswerPlaceholder` stays · Waves Y1, Z1 and AA bumped `pubspec.yaml` in their own commits · `EmberBackdrop` and `AnimatedThinkingBackground` keep `..repeat()` · E48 / E49 / P4 records · `use_build_context_synchronously` × 4 guard with `context.mounted` · `marionette_flutter` is in `dependencies` (tree-shaken from release).

---

## 5. Invariants & intentional decisions — do NOT change

**Platform and build**
- **There is no CocoaPods** (AI1). **The app is iPhone-only** (AI13): adding iPad back is a design project (Issue 188 Option B), never a project-setting flip.
- **Never accept Xcode's "Update to recommended settings" dialog.**
- **The seven `DEBUG:` buttons stay in the source, gated.** **`PrivacyInfo.xcprivacy` stays in the Runner target.** **The 1024 icon has no alpha and no pre-rounded corners.**

**UI and accessibility**
- **Every confirmation dialog goes through `GaslightConfirmDialog`** (AI4); `AlertDialog(` appears only in `lib/widgets/confirm_dialog.dart`.
- **Every host settings write goes through `_applySetting`** (AI9).
- **Rendered contrast is measured from pixels.** **Named icon controls follow the AI8 recipe.**
- **Any `SnackBarAction` sets `textColor: AppColors.brass`.** The theme has no `snackBarTheme`, so an unstyled action renders black on the ink SnackBar (AI10).
- **Colour tokens name a SURFACE, not a role.** Ivory on the dark ground; ink on parchment. Brass is an accent for the dark ground only (2.02 : 1 on parchment). `colorScheme.primary` is oxblood (1.78 : 1 on `groundRaised`), and `onSurface` is ink — never text on the dark ground.
- **`AppMotion.reduce` keeps the `accessibleNavigation` OR term.** **The title-screen version is read from the bundle at runtime.** **`main.dart`'s bootstrap is load-bearing.** **`LobbyScreen`'s `State` outlives every room**: any flag on it needs a reset in a `finally`.

**Errors and seat recovery**
- **Error surfaces match on `e.code` and `e.details['reason']`, never on the message.**
  - Create, join and settings go through `lobbyCallableErrorMessage`; craft and reveal through `gameCallableErrorMessage` (AI11).
  - `toString().contains` appears in `lib/` only at `lib/theme/app_icons.dart:627`.
  - **On iOS a dropped connection is `unknown`**, and it belongs to the connection sentence.
- **The three `details.reason` values** (`deadline_passed`, `already_submitted`, `too_similar`) **are a client contract.** Their `HttpsError` messages stay byte-identical for 1.1.0 (8).
- **Auto-rejoin clears the saved seat only on** `not-found`, `permission-denied`, `invalid-argument` **or a missing room or player document.** Every other failure keeps it (AI10). `tryRejoinSession` returns `Future<bool>`; the reason is in `lastRejoinFailure`.
- **Never render an exception object to a player.**

**Data and server**
- **`playerId` is NOT a credential.** **`allow get` and `allow list` are split on `/rooms`.** **`sealed` and `embeddings` are default-deny.**
- **`votes` stores opaque option UUIDs during the vote phase.** **Never send other players' authorship before the unmask window closes.** **Never let a client bound exceed the server's.** **The presence window gates the ACTION, not the caller.**
- **`pendingScoreDeltas` is flushed at three sites.** **The option id is the authority; text is the fallback.** **The readiness gate exempts the host deliberately** (`!== true`). **The 3-player floor applies in play as well as at start.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.** **Timers default OFF.** **Heartbeat 30 s** against a 10-minute server window.
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and must exceed `ROOM_TTL_MS`. **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`.** **The nightly orphan sweep is retained.** **`CLEANUP_DRY_RUN=false` is revision-scoped**: re-apply it after every functions deploy.
- **`lastReaction` / `lastReactionAt` are deliberately retained dead fields.** **`lib/utils/prompt_decks.dart` is generated.**
- **The web E2E string contract (Wave AE)** and the **Wave AB** and **Wave AA** invariants stand as recorded in the design docs.

**Assessed and rejected — do NOT re-propose:** everything listed in the September guides and the tracker §3, including **migrating `withOpacity` → `withValues` (139 C)**. October 10 rejections: 178 A and C; 179 B; 180 B and C; 181 B; 182 B; 183 B; 184 B; 185 B; 186 B; 187 B; 188 B and C; 189 A; 190 B. October 12 rejections: 192 A; 193 A and C. October 13 rejections: 194 B and C.

**There is no chat or emote feature.**

---

## 6. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index, AI14's coverage findings | `docs/ongoing_general_errors.md` |
| Release runbook, iPhone-only | `README.md` → Releasing |
| Playthrough material | `docs/playthroughs/` |
| Rules, seat tokens, seat recovery (what clears a saved seat), presence, retention, cleanup, callable table with `details.reason` | `docs/design_database_and_security.md` |
| `votes` contract, phases, 3-player floor | `docs/design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding, unmask close, case-file share | `docs/design_scoring_and_ui.md` |
| Palette, dialogs, error surfaces (lobby and game mappers, rejoin SnackBar), House Rules chips, buttons, tap targets and Inspector readings, stacked deck, reveal voters, iPhone-only decision | `docs/design_ui_direction.md` |
| Decks, re-roll exclusion, stems | `docs/design_prompt_system.md` |
| Pixel-measured contrast | `test/helpers/rendered_contrast.dart` |
| Craft and reveal error mapping | `lib/utils/callable_error_message.dart` |

---

## 7. Validation standard

- **A falsification must compile.** A whole-commit revert that deletes a symbol the test imports fails to *load*; use a targeted fault.
- **Reset to the commit, not the index.** `git checkout -- .` restores from the index, and after `git apply --3way` a reversal is staged and survives. Use `git reset --hard HEAD` between runs.
- **A `catch` is tested only if a test can throw from outside its `try`** (lesson §2.48).
- **A tap-target guideline pass is evidence only about the nodes it evaluated** (lesson §2.46).
- **A SnackBar count means nothing unless the screen starts with none** (lesson §2.47).
- **One run is a sample.** A count that varies between runs (AI14's LCOV file list) is reported with its run count, and only the part that held every time is a finding.
- **Measure rendered contrast from pixels.** **Prove a platform behaviour on the real toolchain before relying on it.** **An "already fixed" twin can be half-fixed.** **Write the test for the journey, not the defence.** **A prediction followed by a matching outcome beats either alone.** **Re-run every gate yourself before trusting a table.** **Open the artefact and ask what it shows.** **Read exit codes bare.**

---

## THE LOOP — for any future item

```
(1) Take AJ1 (§2). After it the queue is empty: STOP unless there is a new
    user selection or instruction, a red gate, or a user report. Never fill
    in or edit a `Your selection:` line.
(2) "Implemented to spec" and "fixed the problem" are different claims. Check
    the second against the ORIGINAL REPORT in the tracker, not the spec.
(3) If a fix depends on how a platform or library behaves, read the vendored
    source or prove it on the real toolchain first.
(4) A load-bearing check is REQUIRED; its outcome goes in the commit body
    either way: DONE with the result, or NOT RUN with the reason.
(5) An EMPTY result is not evidence until the same query has been seen to
    return something. Never use `timeout` on macOS.
(6) zsh: an unmatched glob aborts the command; a word starting with `=` is
    expanded. Use bash for scripts.
(7) A falsification that fails to COMPILE proves nothing. Reset with
    `git reset --hard`, not `git checkout -- .`.
(8) A fix applied to one of two twins is half a fix. Fix siblings through ONE
    shared path.
(9) A test is only as wide as what it walks; assert you inspected the parts
    that matter (non-vacuity counts; a known-empty SnackBar start; a throw
    from outside the `try`).
(10) COLOUR: tokens name a SURFACE. Measure from pixels.
(11) Never show an exception object to a player. Map e.code + details.reason.
(12) A rename broke a test? UPDATE THE ASSERTION, never the production code.
(13) Server changes the shipped client reads must be ADDITIVE (1.1.0 (8)).
(14) RE-RUN THE FULL BATTERY: all nine gates bare; analyze 0/0/170; flutter
     tests at least 466; functions tests at least 167.
(15) COMMIT: ONE ITEM, ONE Conventional Commit; WHY + Falsification + Device
     check in the body; tracker updated in the same commit. Ask before any
     deploy; never upload to TestFlight unless asked.
```

---

## Close-out

**When AJ1 is done the queue is empty. Do not invent work.** The only legitimate triggers for further action are:
1. a new user selection or instruction;
2. a §1 gate going red (investigate, then file with options);
3. a user or tester report — for example *Something went wrong. Try again.* while offline, which re-opens the 192 inference (§4).

Anything else, including tidying, upgrading dependencies or migrating `withOpacity`, is not approved.
