# Agent Execution Guide — Active Build: release 1.2.1 (10) for TestFlight (AP1) — October 20, 2026

**You are an engineering agent with no memory of this project.**

**Where things stand.** Wave AI came from a read-only audit on October 10 (Issues 178–191) plus two October 12 follow-ups (192, 193). All sixteen of its items, AI1–AI15 and AH1, are built, and AI11's server change is deployed. **The whole wave was verified on October 13** by re-running every gate and re-falsifying every item in scratch clones (§3).

**One item is approved: AP1 (§2), a TestFlight build of 1.2.1 (10).** The user asked for it in chat on October 20. It carries every fix since 1.2.0 (9): AL1, AM1, AM3, AN1 and the IDE auto-fix `f7e7a12` (kept, Issue 200 → A). AP1 builds and verifies the archive, and **uploading it is the user's step**. When AP1 is done the queue is empty. **Do not invent work.**

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
4. **New code adds zero analyzer infos.** Use `.withValues(alpha: x)`, never `.withOpacity(x)`, and no `print`. `flutter analyze lib test` must stay at **0 errors · 0 warnings · 17 infos**, as measured on `f7e7a12`.
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
  - **The web smoke is one command:** `./scripts/run_web_smoke.sh` (AK1). It builds an emulator-only web app into a temp directory (never `build/web`), runs `firebase emulators:exec`, and plays two full games with three Playwright browsers; exit 0 means both reached game over (about 5 minutes; needs Java and Playwright's Chromium).
    - **It starts its own emulators,** so it refuses to run while any of ports 8777, 8080, 9099, 5001, 4000, 4400, 4500 or 9150 is busy. It prints the owner and kills nothing: stop what *you* started, by PID.
    - **The scripts refuse a `WEB_E2E_SHOT_DIR` inside `docs/playthroughs/evidence/`.** A default run writes screenshots to a temp directory and the runner fails if that tracked folder changes.
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

## 1. Verified baseline — measured October 19, 2026 on `f7e7a12` (after Wave AN and the IDE auto-fix)

**This is the regression bar.** Every gate was run bare in the verification session.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 17 infos · exit 1** (13 `avoid_print` in tests, 4 `use_build_context_synchronously`). It was 169 until `f7e7a12` migrated the 137 `withOpacity` and applied other `dart fix` clean-ups; kept (Issue 200 → A). |
| `flutter test` | **569 passing** (AL1 +9, AM1 +12, AM3 +31, AN1 +51), exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **167 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five**: no-arg, `docs/playthroughs/findings_marionette.md`, `…/findings_web.md`, `…/findings_5player.md`, `…/findings_waveAA.md` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH, 19 functions.** It reads STALE after any later commit touching `functions/src` until the next deploy. |
| `./scripts/check_web_e2e_strings.sh` | **exit 0** |
| `flutter build ios --release --no-codesign` | **exit 0 — `✓ Built build/ios/iphoneos/Runner.app (50.1MB)`**; `UIDeviceFamily` = `1` (iPhone-only) |
| `./scripts/run_web_smoke.sh` — **a release-time check, not a per-item gate** | **exit 0** — both playthroughs reach game over, and the full one also sweeps the lobby, craft, vote, reveal and game-over screens at 375×812, 768×1024 and 1280×800 (AL2: a wrong phase or a missing or off-screen key control fails the run; 15 `w21_*` PNGs per run). Measured: AK1, 5 runs of 275–279 s; AL2, 2 runs of 302 s and 313 s; AM2 and AM3, runs of 315–323 s (October 15, verification: 323 s). Every one exit 0, 41 PNGs each, ports free after every run. The vote sweep also requires `Previous option` and `Next option` inside the viewport (AM3). Needs Java and Playwright's Chromium (§0.1). Run it before `flutter build web --release` (README → Releasing); do not add it to an item's nine-gate battery. |
| `flutter test --coverage` | **Not a gate.** *Coverage is not collectable on Flutter 3.44.6 (runner segfault; `game_service.dart` missing from LCOV) — see Issue 189 findings.* Not reported upstream (Issue 194 → A). |

**Production** (read October 13, read-only):
- 19 functions deployed (18 callables + `cleanupDaily`). The Firestore rules release is newer than the last `firestore.rules` commit (August 20), per `check_deploy_fresh.sh`.
- `cleanupdaily` serves `cleanupdaily-00020-7tq` at 100 % with `CLEANUP_DRY_RUN=false`.
- 0 function-log entries at WARNING or above since the October 13 deploy. The first nightly cleanup after it ran with `dryRun=false, errors=0`.

**⚠️ `flutter analyze lib test` exits 1 even when clean** — judge it by the counts. Never run bare `flutter analyze`.

---

## 2. AP1 — Build 1.2.1 (10) for TestFlight (requested by the user, October 20)

**What this means for the user.** TestFlight testers have, at best, 1.2.0 (9). Everything fixed since then is in the code only:
- AL1 and AM1: the count labels;
- AM3: the vote deck's navigation stays in view, and the deck opens on a card you can choose;
- AN1: the compact vote header on short phones;
- `f7e7a12`: the `withValues` migration.

AP1 builds and verifies **1.2.1 (10)** and leaves an iOS archive ready for **the user** to upload from Xcode's Organizer.

**⚠️ AP1 is a release, not a code change.** Exactly **one line** of the application changes: the version in `pubspec.yaml`. Everything else is procedure and verification. **If you find yourself editing a test, a screen, a script or a plist, stop — you have left the item.**

**The gap** (on `088a2e2`):
- `pubspec.yaml:19` reads `version: 1.2.0+9`.
- **The old archive:** `build/ios/archive/Runner.xcarchive` holds **1.2.0 (9)** (October 13, 20:11:30). It is the archive AJ1 left for the user. **Move it aside; do not delete it** (step 3).
- **Signing:** this Mac has **only an Apple Development identity**, so the `.ipa` export step will fail. That is expected (step 4).
- **Server:** the functions are unchanged since AI11's deploy (`check_deploy_fresh.sh` exit 0). **Do not deploy functions.** The web app stays at 1.2.0 (9) unless the user asks for a web deploy; **AP1 does not deploy the web.**

### 2.1 The only application change
`pubspec.yaml`: `version: 1.2.0+9` → **`version: 1.2.1+10`**.
- `CFBundleShortVersionString` and `CFBundleVersion` come from it (`$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`), and so does the title screen's label (`PackageInfo`).
- Build **10** is higher than any build App Store Connect can hold (8 is on TestFlight; 9 may or may not have been uploaded).

**⚠️ Do not touch `test/lobby_version_test.dart`.** It mocks `9.9.9` and `1.0.0` on purpose. `flutter test` must still report **569**.

### 2.2 Procedure
0. **Commit pending docs first.** If `git status --porcelain` shows the docs modified, commit them **unmodified**, on their own: `docs: commit the October 20 AP1 release spec, unmodified`. If anything outside `docs/` is modified, STOP and ask the user.
1. **Bump** `pubspec.yaml` as in §2.1.
2. **Preflight:** run all nine §1 gates bare, plus `./scripts/run_web_smoke.sh` once. A release is the moment the whole battery must be green, and the web smoke exercises the same client code end to end.
   - The numbers must equal §1 exactly: analyze **0 / 0 / 17**, `flutter test` **569**, functions **167**, the rest exit 0, and the smoke exit 0.
3. **Move the old archive aside.**
   - First `ls -la build/ios/archive build/ios/ipa 2>&1`.
   - Then `mv build/ios/archive build/ios/archive_1.2.0_9` — kept, in case the user still wants build 9 — and `rm -rf build/ios/ipa` if present.
   - From here on, `build/ios/archive/` holds only what your run produces.
4. **`flutter build ipa`.** Judge it by its output, not its exit code.
   - **Expected:** `✓ Built build/ios/archive/Runner.xcarchive`, then an export error (`No Accounts` / `No signing certificate "iOS Distribution" found`). At AJ1 the exit code was still 0. That outcome is a **pass**.
   - **If the archive step itself fails, STOP.** Record the error verbatim and file it with options. Never accept Xcode's settings dialog, and never reintroduce a `Podfile`.
5. **Verify the archive, never an `.ipa`** (`X=build/ios/archive/Runner.xcarchive`, `A=$X/Products/Applications/Runner.app`):

   | Check | Required |
   |---|---|
   | `stat -f "%Sm" $X` | a timestamp from this run |
   | `PlistBuddy :ApplicationProperties:CFBundleShortVersionString` on `$X/Info.plist` | `1.2.1` |
   | `PlistBuddy :ApplicationProperties:CFBundleVersion` | `10` |
   | `:UIDeviceFamily` on `$A/Info.plist` | only `1` |
   | `:MinimumOSVersion` · `:CFBundleDisplayName` · `:ITSAppUsesNonExemptEncryption` · `:CFBundleIdentifier` | `15.0` · `Gaslight` · `false` · `com.whylabs.gaslight` |
   | `test -f $A/PrivacyInfo.xcprivacy` | exit 0 |
   | `strings $A/Frameworks/App.framework/App \| grep -c marionette` | `0` |
   | the same `strings` with `grep -c 'Could not reach the parlour'` | `1` — the positive control that the search can see Dart strings |
   | the same `strings` with `grep -c 'Found by no one'` | `≥ 1` — AL1's string is in this build; build 9 had `0`, check it on `build/ios/archive_1.2.0_9` |

6. **Device check (REQUIRED).**
   - On the iPhone SE simulator, with a reset Keychain (§0.1), run `flutter run -d <udid> --dart-define=USE_EMULATOR=true` with the emulators up.
   - The title screen must show **`v1.2.1 (10)`** beneath READ MANUAL.
   - Take a screenshot with `xcrun simctl io <udid> screenshot`, then stop your `flutter run` and your emulator by PID.
7. **Do not upload to TestFlight, do not open Organizer's Distribute flow, and do not deploy anything.** The upload needs the user's Apple account; hand it over (step 9).
8. **One commit:** `chore(release): ship 1.2.1+10 (Wave AP / AP1)`.
   - **Files:** `pubspec.yaml` plus the docs:
     - a tracker §3 row: what shipped, the step-5 table as measured, the preflight;
     - this guide's §3 *Release plumbing*: 1.2.1 (10) archived and verified, upload pending; the 1.2.0 (9) archive moved to `build/ios/archive_1.2.0_9/`; the web still at 1.2.0 (9);
     - the guide returned to queue-complete mode (title, framing, §2 *"Queue — empty"*, THE LOOP step (1), close-out).
   - **Body:** the WHY, `Falsification:` (build 9's archive against build 10's — 1.2.0 / 9 against 1.2.1 / 10, and `Found by no one` 0 against ≥ 1), `Device check: DONE — v1.2.1 (10) …`, and `Web deploy: NOT RUN — not part of AP1`.
   - A commit cannot contain its own hash. Do not push.
9. **Hand-off to the user, in your final message:** the upload steps and the *What to Test* text below.

**What to Test (paste into App Store Connect):**

> 1.2.1 (10) — fixes since 1.2.0:
> • Counts read correctly: "1 SUSPECT JOINED", "Waiting for 1 player...", "1 Deception", "Found by no one".
> • On the vote screen, PREV / NEXT and the card dots always stay on screen, and the deck opens on a card you can pick — never your own forgery.
> • On smaller phones (iPhone SE size) and with large text, the vote screen shows the card without scrolling.
> Please try: (1) with large text on (Settings → Accessibility → Display & Text Size → Larger Text), check that the vote screen shows the card, PREV / NEXT and the vote button without scrolling; (2) turn on Airplane Mode and tap CREATE ROOM — it should say "Could not reach the parlour. Check your connection and try again."

### 2.3 Validation summary
- **Falsifying:** build 10's archive differs from build 9's in exactly the intended ways — version, build number, and the new strings present.
- **Over-reach guard:** the release commit's `git diff --stat` shows `pubspec.yaml` and docs only; `flutter test` 569 with `test/lobby_version_test.dart` untouched.
- **Load-bearing checks (REQUIRED):** the title screen's `v1.2.1 (10)`, the preflight including the web smoke, and the step-5 table. Each outcome goes in the commit body either way.

**Blast radius:** `pubspec.yaml`, `docs/ongoing_general_errors.md`, `docs/agent_execution_guide.md`. No design doc.

---

## 3. Already delivered — do NOT rework

### Wave AI — verified October 12 (AI1–AI9, AH1) and October 13 (AI10–AI15)

Each row's falsification was **re-run independently** in a scratch clone of `HEAD`, reset with `git reset --hard` between runs; every fault compiled. Controls: October 12, the nine guard files pass 69/69; October 13, the four new client test files pass 43/43.

| Item | Commit | What shipped | Falsification re-run |
|---|---|---|---|
| **`f7e7a12`** (200 → A) | `f7e7a12` | IDE auto-fix kept: `withOpacity` → `withValues` everywhere, plus `dart fix` clean-ups | October 19: every gate green; analyze 0 / 0 / 17 |
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
| **AJ1** (release) | `adb05fc` | `pubspec.yaml` → `1.2.0+9`; the iOS archive was built and verified for the user to upload. The web deploy did not run (Issue 195 → Wave AK). | Archive read October 13: 1.2.0 / 9 / `{ 1 }`, privacy manifest present, 0 `marionette` strings (control 1). The stale archive read 1.1.0 / 8 / `{ 1, 2 }`. |
| **AK1** (195 → A, extended) | `dd4d3ce` | Both web playthroughs repaired (author-aware W7, the deck walked with `Next option`, the host's PROCEED, a room-document oracle, no silent loop or vacuous pass), plus `scripts/run_web_smoke.sh`. | October 14: runner exit 0 (280 s, 41 PNGs); Bob never voting → `STALLED`, exit 1; a 3-tick cap → *did not reach game over*, exit 1. |
| **AK2** (release) | `28f8a06` | 1.2.0 (9) deployed to web hosting with the user's go-ahead. | Live `version.json` 1.2.0 / 9; `/` and `/assets/.env` 200; deploy fresh; iOS archive untouched. |
| **AL1** (196 → A) | `410f986` | `pluralize` helper; *1 SUSPECT JOINED*, *1 Deception*, *1 wrong vote*, *Found by no one*; the two correct siblings now share the path. | October 15: control 26 / 26; always-plural → +21 −5 (`1 Deception`, `1 SUSPECT JOINED` ×3, `'vote'`). |
| **AL2** (197 → A) | `3a8f7f1` | The responsive sweep runs on the real game at every phase and three sizes; W17–W19 corrected to NOT RUN; W21 cites 15 new images. | October 15: runner exit 0 (315 s, 15 / 15 `w21_*`); a wrong phase at W6 → exit 1 at the first in-game sweep; the evidence diff is 15 additions. |
| **AM1** (196 → A, completed) | `3d50704` | `Waiting for 1 player...` (craft and vote), the deck-too-small sentence as `deckTooSmallMessage`, the carousel's `prompt(s) from player(s)`, and the reveal banner, all through `pluralize`. | October 15: the single-quoted scan returns exactly the nine allowed lines; no `? 's' : ''` is left. |
| **AM2** (195 → A, completed) | `64f9d40` | The accusation settles (two reads 300 ms apart within 1 px) before its click, and is retried once while ≥ 3 s of the window remain. | Cause observed (a click mid-animation); 10 of 10 repeat runs; October 15 runner: 6 settle waits, 0 retries. |
| **AM3** (198 → A) | `7a28dc1` | `DeckController` and `DeckNavigationBar`: the vote deck's PREV · dots · NEXT sit in the pinned bar; the deck opens on the first card the voter can choose; a new controller per card. | October 15: fit and controller tests 31 / 31; `openOnFirstVotable: false` → +8 −9; W22 shows the row at three sizes; runner exit 0. |
| **AN1** (199 → A3) | `7602141` | A compact vote header when `height / textScale < 740`: a one-line avatar row, no `Prompt:` label, a 17-pt prompt, a one-line target header, and no guidance line. Tall screens are unchanged. | October 19: fit test 65 / 65 with the real fonts; never compact → 36 fail; runner exit 0; SE device check done at 1.0 and 1.3 (the commit's own device report named a non-existent button). |
| **192 → B** | `3a36e91` | AH1's device check closed by acceptance (simulator observation plus source trace). | Nothing to falsify. |

### Earlier waves
- **Wave AG** (AG1 error mapping, AG2 chip-header ivory, AG3 ledger on waiting screens) — verified October 3.
- **Wave AA** (sixteen items, Issues 153–169, 160, 162) — verified September 11.
- **Wave Z (152)** leave latch in a `finally` · **Y1 (151)** · **Y2 (149)** · **X1 (147)** · **X2 (148)** · **W1 (146)** · **W2 (145)** · **V1 (143, 144)** · **U1–U5**, **S1**, **R0–R2**, soak blocks **E22–E49**, Waves **Q/P/O**, Issues **96–105, 50–95, 31, 28/29**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · **iPhone-only** (`UIDeviceFamily` 1) · Node **22**. **TestFlight has build 1.1.0 (8)**, which predates Wave AI. **1.2.0 (9) is archived and verified** (`build/ios/archive/Runner.xcarchive`, October 13; the preflight on the 1.2.0+9 tree read the same numbers as §1), and **its upload is pending — the user's step in Xcode's Organizer**, because this Mac has no Apple Distribution certificate and `flutter build ipa` cannot export an `.ipa`. **The web app serves 1.2.0 (9):** AK2 deployed hosting on October 14 with the user's go-ahead, after AK1 repaired the web smoke (Issue 195); the live `version.json` reads 1.2.0 / 9.

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
- **AK1: the lobby's House Rules controls are clicked through the DOM (`domClick`), not with the pointer.** They sit behind the full-width suspects sheet, and pointer clicks there never registered. Each click is checked against the room document before and after.
- **AK1: W10 asserts at least one score chip, not one per player.** A reader whose score does not change gets no chip; the app is right.
- **AK1: the runner checks more than the spec asked:** `.env`, Playwright and Java up front (exit 2); at least 20 PNGs; free ports afterwards; a 570 s watchdog that explains itself before the 600 s kill. It also refuses a shot directory inside the tracked evidence folder.
- **AN1: six named cases are exempt from the at-least-20-px answer check in `test/vote_screen_fit_test.dart`,** each with its measured value. They are the 320×640 × 1.3 extremes, the SE × 1.3 target with an 89-character prompt, and 375×812 × 1.0 with an 89-character prompt on the unchanged full header. Every case still asserts the `OPTION` label on screen. Do not "fix" them by shrinking type beyond A3.
- **AN1: card visibility for the target is measured with a non-host target.** Under `flutter test` `kDebugMode` is true, so a host would see the debug-only `DEBUG: BOTS SUBMIT` in the pinned bar, which release builds never show.
- **AM1: the count-label scan is run with the pattern single-quoted.** In double quotes the shell turns `\$` into `$` and the scan silently finds nothing; my spec had that bug, and the design doc carries the corrected command.
- **AM1: the deck-too-small sentence's singular forms are unreachable today.** The smallest deck holds 25 prompts, and a room holds at most 8 players; they are asserted on `deckTooSmallMessage` itself.
- **AM3: `DeckNavigationBar` also takes `selectedIndex`,** so the chosen option's dot stays oxblood as before.
- **AM3: the analyzer count fell to 169.** The State's `dispose()` now disposes the deck controller, so its `unnecessary_overrides` info is gone; that is not a regression.
- **AM3: a comment in `test/tap_target_guidelines_test.dart`** (the vote harness) still describes the old layout. The file is a guard, so it was not edited; its assertions pass unchanged.
- **AL2: the reveal is swept after the unmask window, and once its score chips are up.** The window lasts 20 s and three resizes would spend it, and a reveal still mid-beat shows different content at each size. The room waits on the reveal for the host's `CONTINUE`, so the phase assertion holds. The spec said only "in W9".
- **AL2: the W17–W19 Reason line says the Lobby image shows the title screen.** The guide's draft said only the Lobby image shows what it names. Opening the three files showed the title screen (`THE GUEST LEDGER`): the old script saved it under `_lobby` before it created a room. No cited image at any of the three sizes shows the screen it names.
- **AL2: the sweep's evidence is a resized desktop page, built for the emulator.** No touch emulation and no mobile user agent (the old w17 context had both, but only ever showed the title screen and a lobby). The emulator-only build also paints Firebase's red *"Running in emulator mode"* banner over the bottom 20–37 px of every image, which can cover the lower edge of a bottom-pinned button; the release build has none.
- **AL2: a key control is asserted horizontally only, and the images show the top of each page.** Flutter keeps a scroll view's children in the semantics tree, so a control below the fold is found without scrolling (the wheel is the fallback, proved on the game over screen). What the images show vertically is recorded in W21, not asserted: at 375×812 and 1280×800 the vote screen's PREV / NEXT row sits under the bottom bar until the page is scrolled.
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

**Vote screen and copy (AL1, AM1, AM3, AN1)**
- **Short screens get the compact vote header** (`height / textScale < 740`). The full header is unchanged on tall screens. Layout pixels are measured with the **real app fonts** and real prompt lengths (29, 65 and 89 characters), never Flutter's test font (lesson §2.49).
- **Every count label goes through `pluralize`** (`lib/utils/pluralize.dart`); zero gets its own phrase where *only 0* would read wrongly. The exemptions and the single-quoted scan are in `design_ui_direction.md`.
- **The vote deck's navigation lives in the pinned bar** (`DeckNavigationBar`), never back inside the scroll view. **The deck opens on the first card the viewer can choose** (`openOnFirstVotable`); the target opens on card I. Each card gets a new `DeckController`.
- **`test/vote_screen_fit_test.dart` judges the whole screen, not `CardGrid` alone.** Its "on screen" means inside the window, inside every enclosing scroll view's viewport, and reachable by a tap at its centre.

**Code hygiene (`f7e7a12`, Issue 200 → A)**
- **`withOpacity` is gone. New code uses `.withValues(alpha: …)`; never reintroduce it. `grep -rn 'withOpacity(' lib/ test/` returns nothing.**

**The web smoke (AK1)**
- **Run `./scripts/run_web_smoke.sh` before every web deploy;** it must exit 0.
- **It never writes `docs/playthroughs/evidence/`.** Re-capturing cited evidence is a deliberate, separate act under the evidence gate's rules.
- **It also sweeps the web screens (AL2).** The full playthrough resizes P1's page through 375×812, 768×1024 and 1280×800 at the lobby, craft, vote, reveal and game over, and fails on a wrong phase or a missing or off-screen key control. It saves `w21_<w>x<h>_<phase>.png` to the scratch shot directory; the 15 cited copies in `docs/playthroughs/evidence/` were copied in by hand and are never overwritten. A skipped sweep does not fail the runner (26 PNGs still clear its minimum of 20): check the 15 `w21_*` names by name.
- **Its emulator-only build lives in a temp directory and is never deployed.** Only `flutter build web --release` with no `--dart-define`, into `build/web`, is deployable.
- **Never open the live web app in a browser to check a deploy:** `lib/main.dart:65` signs in anonymously at boot. Use `version.json` and HTTP status codes.
- **`build/ios/archive/` is the user's upload artefact:** never delete it. AP1 moves the 1.2.0 (9) archive to `build/ios/archive_1.2.0_9/` before building 1.2.1 (10); after that, leave both until the user says the upload is done.

**Assessed and rejected — do NOT re-propose:** everything listed in the September guides and the tracker §3, including **migrating `withOpacity` → `withValues` (139 C)** — superseded: the migration was applied by `f7e7a12` and kept (Issue 200 → A). October 10 rejections: 178 A and C; 179 B; 180 B and C; 181 B; 182 B; 183 B; 184 B; 185 B; 186 B; 187 B; 188 B and C; 189 A; 190 B. October 12 rejections: 192 A; 193 A and C. October 13 rejections: 194 B and C.

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
| Count labels (`pluralize`), its exemptions and the scan | `lib/utils/pluralize.dart`; `docs/design_ui_direction.md` (*Count labels agree with their numbers*) |
| The vote deck's navigation and opening card; the whole-screen fit | `lib/widgets/card_grid.dart` (`DeckController`, `DeckNavigationBar`); `test/vote_screen_fit_test.dart`; `docs/design_ui_direction.md` (stacked deck) |

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
(1) Take AP1 (§2). After it the queue is empty: STOP unless there is a new
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
(14) RE-RUN THE FULL BATTERY: all nine gates bare; analyze 0/0/17; flutter
     tests at least 569; functions tests at least 167.
(15) COMMIT: ONE ITEM, ONE Conventional Commit; WHY + Falsification + Device
     check in the body; tracker updated in the same commit. Ask before any
     deploy; never upload to TestFlight unless asked.
```

---

## Close-out

**When AP1 is done the queue is empty. Do not invent work.** The only legitimate triggers for further action are:
1. a new user selection or instruction (a new guide rewrite specs it first);
2. a §1 gate going red (investigate, then file with options);
3. a user or tester report — for example *Something went wrong. Try again.* while offline, which re-opens the 192 inference (§4).

Anything else, including tidying, upgrading dependencies or re-opening closed issues, is not approved.
