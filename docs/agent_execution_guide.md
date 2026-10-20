# Agent Execution Guide — Active Build: Wave AN (a compact vote header on short screens, Issue 199 → A3) — October 19, 2026

**You are an engineering agent with no memory of this project.**

**Where things stand.** Wave AI came from a read-only audit on October 10 (Issues 178–191) plus two October 12 follow-ups (192, 193). All sixteen of its items, AI1–AI15 and AH1, are built, and AI11's server change is deployed. **The whole wave was verified on October 13** by re-running every gate and re-falsifying every item in scratch clones (§3).

**One item is approved: AN1 (§2).** On October 19 the user chose **Issue 199 → Option A3** in chat. The first AN1 spec (A) was stopped on a test-font measurement (`25a155c`); A3 is the re-measured version. Wave AM was verified on October 15 (§3): AM1 `3d50704`, AM2 `64f9d40`, AM3 `7a28dc1`. Uploading 1.2.0 (9) to TestFlight is still the user's step, and the fixes since then reach players only in a new build, which is the user's call. When AN1 is done the queue is empty. **Do not invent work.**

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
4. **New code adds zero analyzer infos.** Use `.withValues(alpha: x)`, never `.withOpacity(x)`, and no `print`. `flutter analyze lib test` must stay at **0 errors · 0 warnings · 169 infos**.
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

## 1. Verified baseline — measured October 15, 2026 on `7a28dc1` (after Wave AM)

**This is the regression bar.** Every gate was run bare in the verification session.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 169 infos · exit 1** (AM3 removed one `unnecessary_overrides`; 137 `deprecated_member_use`, all of them `withOpacity` — the rejected 139 C migration) |
| `flutter test` | **518 passing** (AL1 +9, AM1 +12, AM3 +31), exit 0 |
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

## 2. Wave AN — one item: a compact vote header on short screens (Issue 199 → A3)

**No release in this wave** (no `pubspec.yaml` bump). The fix reaches players only in a new build, which is the user's call. **`build/ios/archive/` stays untouched** (§5).

**History, so you don't repeat it.** The first AN1 spec (Issue 199 → A) was stopped at its STOP condition (`25a155c`). The cause was a measurement artefact: `test/vote_screen_fit_test.dart` renders Flutter's test font, which is about twice as wide as Lora, with the decks' shortest prompt, and its target is the host, who sees a debug-only button. The case was re-measured on October 19 with the real fonts and real prompt lengths, and the user chose **A3** in chat. The figures below are from that measurement, made in a scratch clone with this exact layout.

### 2.1 AN1 — The vote card is visible at first paint on short screens (Issue 199 → A3)

**What this means for the user.** On an iPhone SE (375×667), a voter's first view of each card shows the header, the prompt, the navigation and the button, but **none of the card they must judge**; even at normal text the answer starts about 100 pt below the fold for a typical prompt. After AN1, short screens use a compact header, so the prompt, the front card's label and its answer show without scrolling, at normal and large text. Tall screens look exactly as they do today.

**The gap** (re-checked on `25a155c`; find lines by their text if they moved):
- **The header today.** In `lib/screens/phase3_vote.dart` (about `:410–520`) the scroll view's column holds:
  - **for a voter:** `VOTING ON` · `PlayerAvatar(size: 50)` · *"One of these is X's truth."* · `WHICH ONE IS THE TRUTH?`;
  - **for the target:** `PlayerAvatar(me, size: 50)` · `THEY ARE VOTING ON YOUR TRUTH` (18 pt) · *"Keep a straight face while the parlor deliberates."*;
  - **then, for both:** a 16-pt gap · the prompt `ParchmentCard` (padding `vertical: 12`, a `Prompt:` label, a 6-pt gap, the prompt at **20 pt** bold Lora) · 12 · *"Find the real truth among the forgeries. Talk it out — discussion is part of the game."* · 12 · `CardGrid`.
- **The test cannot see it.** `test/vote_screen_fit_test.dart` checks the navigation and the button, but not the card. It also renders the **test font** and uses a 29-character prompt — the shortest of the decks' 150 prompts, which run 29–89 characters with a median of 65.

#### Implementation
1. **When the header is compact,** in the vote screen's build:
   ```dart
   final double effectiveHeight = MediaQuery.sizeOf(context).height / MediaQuery.textScalerOf(context).scale(1.0);
   final bool compactHeader = effectiveHeight < 740;
   ```
   - **Compact:** 320×640 and 375×667 at both text scales; 375×812 and 1280×800 at 1.3.
   - **Full:** 375×812, 1280×800 and 768×1024 at 1.0; 768×1024 at 1.3.
2. **The compact voter header,** replacing everything above the prompt card:
   - one centred `Row`: `PlayerAvatar(player: targetPlayer, size: 28)`, `SizedBox(width: 8)`, `Flexible(Text("One of these is ${targetPlayer.name}'s truth.", …))`;
   - the text keeps the same string and style, with `maxLines: 2`;
   - `VOTING ON` and `WHICH ONE IS THE TRUTH?` are not shown.
3. **The compact target header:**
   - one centred `Row`: `PlayerAvatar(player: me, size: 28)`, `SizedBox(width: 8)`, `Flexible(Text('THEY ARE VOTING ON YOUR TRUTH', …))` at **16 pt**, with the same weight and letter-spacing;
   - **no subtitle:** *"Keep a straight face…"* is not shown when compact.
4. **Compact, for both views:**
   - the gap before the prompt card is **10**;
   - the prompt card's padding is `horizontal: 16, vertical: 8`;
   - **no `Prompt:` label and no 6-pt gap after it;**
   - the prompt text is **17 pt** (20 pt when full), with the same weight, colour and font;
   - the *"Find the real truth…"* line and its spacing are not shown;
   - the gap before `CardGrid` is **10**.
5. **Unchanged:**
   - the full header, byte for byte;
   - the spectator branch;
   - `CardGrid`, AM3's pinned bar, the copy, and the colours.
   New code uses `.withValues(alpha: …)`, never `.withOpacity`.

#### Validation
1. **`test/vote_screen_fit_test.dart` measures real text.** Load the app fonts in `setUpAll`, exactly as `test/small_phone_truncation_test.dart` does: **Lora**, **CormorantGaramond** and **PhosphorLight** from `assets/fonts/`. AM3's existing cases must still pass unedited.
2. **Add a group:** *"the front card is visible at first paint (Issue 199 / AN1)"*.
   - **Setup:**
     - the real `GaslightApp` on the vote screen;
     - a card whose options put the voter's own forgery first;
     - prompts of **29**, **65** and **89** characters: the existing fixture, then *"The trick I use to avoid making small talk with people in public."* and *"The first thing I would buy with lottery money that would make people question my sanity."*;
     - sizes 320×640, 375×667, 375×812 and 1280×800; text scales 1.0 and 1.3;
     - as the voter (`p2`) and as a **non-host target**: make `p3` the host in this group. Under `flutter test` `kDebugMode` is true, so a host target would see `DEBUG: BOTS SUBMIT` in the pinned bar, which release builds never show.
   - **That is 48 cases.** In every one:
     - **(a)** the front card's `OPTION <roman>` label passes the file's existing "on screen" check: inside the window, inside every enclosing scroll viewport, and reachable by a tap at its centre;
     - **(b)** the front card's answer `Text` has **at least 20 px** inside the scroll viewport, measured from its top edge.
   - **The only exceptions to (b),** listed by name in the test with a comment giving the measured value:
     - 320×640 × 1.3: voter with the 89-character prompt (−10.5 px); target with 65 and 89 (−26.5, −58.5);
     - 375×667 × 1.3: target with 89 (0.5);
     - 375×812 × 1.0: the **full** header, unchanged, with 89 (voter 16.5, target −6.5).

     These cases still assert (a).
   - **Also assert** the header mode from step 1: `VOTING ON` (voter) and the guidance line present only when full; `Prompt:` absent when compact.
   - **This is the falsifying test:** on the parent commit (b) fails in most short-screen cases. The scratch measurement showed −41.5 to −445 px.
3. **Three guards pin the full header at sizes that are now compact.** In each, the test states the size it means; **the assertion text is unchanged.** This is THE LOOP rule 12's spirit: the test states its size, and the production code is not bent to the test.
   - `test/phase3_vote_test.dart`, *'the vote header names whose card is being voted on'* (`VOTING ON`, at the default 800×600);
   - `test/guidance_strings_test.dart`, the vote phase's guidance line (default 800×600);
   - `test/vote_screen_contrast_test.dart`'s **target** case, *"'Keep a straight face…' >= 4.5 : 1"* (375×667), which A3 drops when compact.

   **How:**
   - For the first two, set `tester.view.physicalSize = const Size(430, 932); tester.view.devicePixelRatio = 1.0;` with a tear-down reset.
   - For the contrast test, give its `pumpVoteScreen` an optional `size` (default 375×667, unchanged for the voter case) and pass `Size(430, 932)` for the target case.
   - Next to each, add a compact counterpart at 375×667 asserting that the dropped element is absent and the kept one present. For the contrast test, the voter case stays at 375×667 and still measures the voter subtitle, which is kept.
4. **Falsify (compiling faults):**
   - (a) threshold 0, so the header is never compact → (b) fails at 375×667;
   - (b) the prompt at 20 pt when compact → (b) fails for the voter with 89 characters at 375×667 × 1.3 (measured −8.5 without the 17-pt change);
   - (c) the threshold ignores text scale (raw height) → (b) fails at 375×812 × 1.3. If (c) does not fail, record that, and keep the term anyway.
5. **Over-reach guards, unedited:**
   - `blinking_eye_test.dart` and `ui_e2e_test.dart` (`THEY ARE VOTING ON YOUR TRUTH` stays in the compact row);
   - `stacked_deck_navigation_test.dart`, `vote_option_truncation_test.dart`, `vote_tap_cue_test.dart`, `tap_target_guidelines_test.dart`, `small_phone_truncation_test.dart`, `deck_controller_test.dart`;
   - AM3's fit cases, and every other vote-screen test.
6. **STOP condition (narrowed).** If any of the 42 non-exception cases fails (b), or any of the 48 fails (a), STOP before committing, and file it with the measured values. Do not tune sizes beyond this spec.
7. **Web:** `./scripts/run_web_smoke.sh` exits 0. Its sweep runs at text scale 1.0, where every size is full-header, so the sweep is unchanged.
8. **Device check (REQUIRED):** iPhone SE simulator (375×667), reset Keychain, emulators.
   - As a **voter**, at first paint and **without scrolling**, you see the one-line *"One of these is X's truth."* row, the prompt without its label, the front card's `OPTION` label and answer, PREV · dots · NEXT and `TAP A CARD TO CHOOSE`.
   - Repeat with `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large` (the app clamps to 1.3).
   - As the **target**, the one-line row shows without the subtitle. A debug build shows the host `DEBUG:` button in the pinned bar, so judge the card's visibility for the target from the widget test, not the device.
   - Take screenshots with `xcrun simctl io`, and restore the text size with `large`.
9. **The nine §1 gates, bare:** analyze **0 / 0 / 169**; `flutter test` = 518 + the new cases; the rest unchanged.
10. **One commit:** `fix(ui): a compact vote header on short screens so the card shows at first paint (Wave AN / AN1, Issue 199 Option A3)`, with `Falsification:` (a–c) and `Device check:`. Do not push.

**Blast radius:**
- `lib/screens/phase3_vote.dart`;
- `test/vote_screen_fit_test.dart`, `test/phase3_vote_test.dart`, `test/guidance_strings_test.dart`, `test/vote_screen_contrast_test.dart` (the target case's size only);
- `docs/design_ui_direction.md` → the stacked deck / vote screen section, adding **"Short screens"**:
  - the threshold, `height / textScale < 740`;
  - what folds into one line, and what is dropped: the `VOTING ON` label, the heading, the target subtitle, the `Prompt:` label and the guidance line;
  - the 17-pt prompt;
  - the guarantee — the front card's label at every tested size, and its first answer line except the listed extremes — tested by `test/vote_screen_fit_test.dart` with the real fonts;
- the tracker: a §3 row, and Issue 199's block deleted;
- **lesson §2:** a layout measurement taken under the test font says nothing about real text. Load the app fonts, and use real lengths, before trusting a pixel.

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
| **AJ1** (release) | `adb05fc` | `pubspec.yaml` → `1.2.0+9`; the iOS archive was built and verified for the user to upload. The web deploy did not run (Issue 195 → Wave AK). | Archive read October 13: 1.2.0 / 9 / `{ 1 }`, privacy manifest present, 0 `marionette` strings (control 1). The stale archive read 1.1.0 / 8 / `{ 1, 2 }`. |
| **AK1** (195 → A, extended) | `dd4d3ce` | Both web playthroughs repaired (author-aware W7, the deck walked with `Next option`, the host's PROCEED, a room-document oracle, no silent loop or vacuous pass), plus `scripts/run_web_smoke.sh`. | October 14: runner exit 0 (280 s, 41 PNGs); Bob never voting → `STALLED`, exit 1; a 3-tick cap → *did not reach game over*, exit 1. |
| **AK2** (release) | `28f8a06` | 1.2.0 (9) deployed to web hosting with the user's go-ahead. | Live `version.json` 1.2.0 / 9; `/` and `/assets/.env` 200; deploy fresh; iOS archive untouched. |
| **AL1** (196 → A) | `410f986` | `pluralize` helper; *1 SUSPECT JOINED*, *1 Deception*, *1 wrong vote*, *Found by no one*; the two correct siblings now share the path. | October 15: control 26 / 26; always-plural → +21 −5 (`1 Deception`, `1 SUSPECT JOINED` ×3, `'vote'`). |
| **AL2** (197 → A) | `3a8f7f1` | The responsive sweep runs on the real game at every phase and three sizes; W17–W19 corrected to NOT RUN; W21 cites 15 new images. | October 15: runner exit 0 (315 s, 15 / 15 `w21_*`); a wrong phase at W6 → exit 1 at the first in-game sweep; the evidence diff is 15 additions. |
| **AM1** (196 → A, completed) | `3d50704` | `Waiting for 1 player...` (craft and vote), the deck-too-small sentence as `deckTooSmallMessage`, the carousel's `prompt(s) from player(s)`, and the reveal banner, all through `pluralize`. | October 15: the single-quoted scan returns exactly the nine allowed lines; no `? 's' : ''` is left. |
| **AM2** (195 → A, completed) | `64f9d40` | The accusation settles (two reads 300 ms apart within 1 px) before its click, and is retried once while ≥ 3 s of the window remain. | Cause observed (a click mid-animation); 10 of 10 repeat runs; October 15 runner: 6 settle waits, 0 retries. |
| **AM3** (198 → A) | `7a28dc1` | `DeckController` and `DeckNavigationBar`: the vote deck's PREV · dots · NEXT sit in the pinned bar; the deck opens on the first card the voter can choose; a new controller per card. | October 15: fit and controller tests 31 / 31; `openOnFirstVotable: false` → +8 −9; W22 shows the row at three sizes; runner exit 0. |
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

**Vote screen and copy (AL1, AM1, AM3)**
- **Every count label goes through `pluralize`** (`lib/utils/pluralize.dart`); zero gets its own phrase where *only 0* would read wrongly. The exemptions and the single-quoted scan are in `design_ui_direction.md`.
- **The vote deck's navigation lives in the pinned bar** (`DeckNavigationBar`), never back inside the scroll view. **The deck opens on the first card the viewer can choose** (`openOnFirstVotable`); the target opens on card I. Each card gets a new `DeckController`.
- **`test/vote_screen_fit_test.dart` judges the whole screen, not `CardGrid` alone.** Its "on screen" means inside the window, inside every enclosing scroll view's viewport, and reachable by a tap at its centre.

**The web smoke (AK1)**
- **Run `./scripts/run_web_smoke.sh` before every web deploy;** it must exit 0.
- **It never writes `docs/playthroughs/evidence/`.** Re-capturing cited evidence is a deliberate, separate act under the evidence gate's rules.
- **It also sweeps the web screens (AL2).** The full playthrough resizes P1's page through 375×812, 768×1024 and 1280×800 at the lobby, craft, vote, reveal and game over, and fails on a wrong phase or a missing or off-screen key control. It saves `w21_<w>x<h>_<phase>.png` to the scratch shot directory; the 15 cited copies in `docs/playthroughs/evidence/` were copied in by hand and are never overwritten. A skipped sweep does not fail the runner (26 PNGs still clear its minimum of 20): check the 15 `w21_*` names by name.
- **Its emulator-only build lives in a temp directory and is never deployed.** Only `flutter build web --release` with no `--dart-define`, into `build/web`, is deployable.
- **Never open the live web app in a browser to check a deploy:** `lib/main.dart:65` signs in anonymously at boot. Use `version.json` and HTTP status codes.
- **`build/ios/archive/` is the user's upload artefact:** never delete or rebuild it until the user says the upload is done.

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
(1) Take AN1 (§2). After it the queue is empty: STOP unless there is a new
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
(14) RE-RUN THE FULL BATTERY: all nine gates bare; analyze 0/0/169; flutter
     tests at least 518; functions tests at least 167.
(15) COMMIT: ONE ITEM, ONE Conventional Commit; WHY + Falsification + Device
     check in the body; tracker updated in the same commit. Ask before any
     deploy; never upload to TestFlight unless asked.
```

---

## Close-out

**When AN1 is done the queue is empty. Do not invent work.** The only legitimate triggers for further action are:
1. a new user selection or instruction (a new guide rewrite specs it first);
2. a §1 gate going red (investigate, then file with options);
3. a user or tester report — for example *Something went wrong. Try again.* while offline, which re-opens the 192 inference (§4).

Anything else, including tidying, upgrading dependencies or migrating `withOpacity`, is not approved.
