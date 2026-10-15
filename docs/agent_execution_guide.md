# Agent Execution Guide — Active Build: Wave AL (count labels, then a real responsive sweep) — October 14, 2026

**You are an engineering agent with no memory of this project.**

**Where things stand.** Wave AI came from a read-only audit on October 10 (Issues 178–191) plus two October 12 follow-ups (192, 193). All sixteen of its items, AI1–AI15 and AH1, are built, and AI11's server change is deployed. **The whole wave was verified on October 13** by re-running every gate and re-falsifying every item in scratch clones (§3).

**Two items are approved: Wave AL (§2).** On October 14 the user chose **Option A for Issue 196** (count labels) and **Option A for Issue 197** (the responsive sweep) in chat. Wave AK was verified on October 14 (§3): AK1 (`dd4d3ce`) repaired the web smoke, and AK2 (`28f8a06`) deployed **1.2.0 (9)** to the web. The iOS archive of 1.2.0 (9) is built and verified, and **uploading it to TestFlight is still the user's step**. When AL2 is done the queue is empty. **Do not invent work.**

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

## 1. Verified baseline — measured October 13, 2026 on `27a6314`; AJ1 (`adb05fc`) and AK1 (`dd4d3ce`) re-ran all nine gates and matched it exactly (no app code has changed since)

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
| `./scripts/run_web_smoke.sh` — **a release-time check, not a per-item gate** | **exit 0** — both playthroughs reach game over (AK1, measured October 14: 5 runs of 275–279 s, every one exit 0, 41 PNGs each, ports free after every run). Needs Java and Playwright's Chromium (§0.1). Run it before `flutter build web --release` (README → Releasing); do not add it to an item's nine-gate battery. |
| `flutter test --coverage` | **Not a gate.** *Coverage is not collectable on Flutter 3.44.6 (runner segfault; `game_service.dart` missing from LCOV) — see Issue 189 findings.* Not reported upstream (Issue 194 → A). |

**Production** (read October 13, read-only):
- 19 functions deployed (18 callables + `cleanupDaily`). The Firestore rules release is newer than the last `firestore.rules` commit (August 20), per `check_deploy_fresh.sh`.
- `cleanupdaily` serves `cleanupdaily-00020-7tq` at 100 % with `CLEANUP_DRY_RUN=false`.
- 0 function-log entries at WARNING or above since the October 13 deploy. The first nightly cleanup after it ran with `dryRun=false, errors=0`.

**⚠️ `flutter analyze lib test` exits 1 even when clean** — judge it by the counts. Never run bare `flutter analyze`.

---

## 2. Wave AL — count labels (Issue 196 → A), then a real responsive sweep (Issue 197 → A)

| Step | Item | Why this position |
|---|---|---|
| 1 | **AL1** One pluralize helper for every count label | It changes app strings, so AL2's fresh evidence then shows the corrected wording. |
| 2 | **AL2** Responsive sweep at every phase; correct the W17–W19 record | It is test code and evidence only, and runs on AL1's tree. |

**No release in this wave.** AL1's wording reaches players only in a new build (1.2.1 (10) or later), which is the user's call. Do not bump `pubspec.yaml`. **`build/ios/archive/` stays untouched** (§5).

### 2.1 AL1 — Count labels agree with their numbers (Issue 196 → A)

**What this means for the user.** Every host currently sees *"1 SUSPECTS JOINED"* in the lobby, and the final screen can say *"1 Deceptions"*, *"1 wrong votes"* or *"Found by only 0 players"*. After AL1 each count reads correctly at 0, 1 and many.

**The gap** (confirmed October 14; line numbers on `28f8a06`):

| Site | Today | Reads wrongly at |
|---|---|---|
| `lib/screens/lobby_screen.dart:841` | `'${players.length} SUSPECTS JOINED'` | 1 |
| `lib/screens/game_over_screen.dart:386` | `'${trickster.playersDeceived} Deceptions'` | 1 |
| `lib/screens/game_over_screen.dart:746` | `'Found by only ${foundCount} ${foundCount == 1 ? 'player' : 'players'}'` | 0 (the server can send 0, `functions/src/index.ts:99`) |
| `lib/screens/game_over_screen.dart:756` | `'${wrongVoteCount} wrong votes'` | 1 |
| `lib/screens/game_over_screen.dart:736` | `'Fooled ${fooled} ${fooled == 1 ? 'player' : 'players'}'` | correct today — a sibling (THE LOOP rule 8) |
| `lib/screens/game_over_screen.dart:792` | `'… fooled … ${count} times'` | never: the server sends only counts ≥ 2 (`countFoolsPairs(…, 2)`). A sibling. |

**Left alone, deliberately:**
- `'${…} Pts'` / `'${…} PTS'` — an abbreviation that reads the same at 1;
- `'${deck.prompts.length} PROMPTS'` — every deck holds many;
- `'… behind'` — no noun;
- `'×$count'` — no noun.

#### Implementation
1. **New `lib/utils/pluralize.dart`:**
   ```dart
   /// The noun for [count]: [singular] when [count] is exactly 1, otherwise [plural].
   String pluralize(int count, String singular, String plural) => count == 1 ? singular : plural;
   ```
2. **Exact strings.** Convert summary-map counts with `(value as num?)?.toInt() ?? 0` before using them.
   - Lobby: `'$n ${pluralize(n, 'SUSPECT', 'SUSPECTS')} JOINED'`
   - Deceptions: `'$n ${pluralize(n, 'Deception', 'Deceptions')}'`
   - Found by: at **0**, `'Found by no one'`; otherwise `'Found by only $n ${pluralize(n, 'player', 'players')}'`
   - Wrong votes: `'$n wrong ${pluralize(n, 'vote', 'votes')}'`
   - Fooled: `'Fooled $n ${pluralize(n, 'player', 'players')}'` (unchanged output)
   - Head-to-head: `'… fooled … $n ${pluralize(n, 'time', 'times')}'` (unchanged output)
3. **Afterwards,** `grep -nE "== 1\) \? '" lib/` returns nothing: every count-noun choice goes through `pluralize`.

#### Validation
1. **`test/pluralize_test.dart`:** `pluralize` at 0, 1, 2 and 10.
2. **Widget cases for every changed label at 0, 1 and 2,** on the real screens: `GameOverScreen` with a match summary, and `LobbyScreen` with 1 and 2 players. Reuse the harnesses in `test/game_over_screen_test.dart` and `test/lobby_parlor_sheet_test.dart`. The falsifying cases are the 1-cases and *Found by no one*.
3. **Update the four pinned assertions** (THE LOOP rule 12 — the assertion changes, not the production code):
   - `test/game_over_screen_test.dart:377` and `test/badge_pills_overflow_test.dart:92`: `'Found by only 0 players'` → `'Found by no one'`;
   - `test/lobby_parlor_sheet_test.dart:81` and `:103`: `'1 SUSPECTS JOINED'` → `'1 SUSPECT JOINED'`, plus the comment at `:86`.
   - **Leave** `'10 SUSPECTS JOINED'` (`:130`), `'3 wrong votes'` and `'4 wrong votes'` as they are.
4. **Falsify (compiling faults):**
   - (a) `pluralize` always returns `plural` → every 1-case fails;
   - (b) the *Found by no one* branch removed → the 0-case fails;
   - (c) the lobby site restored to its old literal → its 1-case fails.
   Paste the failures under `Falsification:`.
5. **Device check (REQUIRED):**
   - On the iPhone SE simulator with a reset Keychain (§0.1), create a room as host: the lobby reads **`1 SUSPECT JOINED`**.
   - Tap `DEBUG: ADD 9 BOTS`: it reads **`10 SUSPECTS JOINED`**.
   - Take screenshots with `xcrun simctl io`. The game-over labels are covered by the widget tests; AL2's screenshots show them on the web.
6. **The nine §1 gates, bare:** analyze **0 / 0 / 170**; `flutter test` = 466 + the new cases; functions 167; the rest exit 0.
7. **`./scripts/run_web_smoke.sh` exits 0** (the lobby is recognised by its room code, not its header).

**Blast radius:**
- `lib/utils/pluralize.dart` (new), `lib/screens/lobby_screen.dart`, `lib/screens/game_over_screen.dart`;
- the tests above;
- `docs/design_ui_direction.md` (a copy rule: *"a count and its noun always agree, through `pluralize`; zero gets its own phrase where 'only 0' would read wrongly"*);
- the tracker (a §3 row; delete Issue 196's block).

### 2.2 AL2 — A real responsive sweep; correct the W17–W19 record (Issue 197 → A)

**What this means for the user.** The web app is played in phone browsers too, but nothing has ever shown its craft, vote, reveal or game-over screens at phone or tablet sizes. The record claims it has. After AL2 the smoke checks all four screens at three sizes in a real game, and the record says what was and wasn't checked.

**The gap.** Issue 197 has the evidence. In brief:
- `test/web_e2e/run_full_playthrough.js` section I3 (about `:439–470`) saves a one-player lobby under the `<size>_craft/vote/reveal/gameover.png` names.
- `docs/playthroughs/findings_web.md` W17–W19 (about `:280–330`) record PASS on those images.

#### Implementation
Change `test/web_e2e/*.js` and docs; copy new PNGs into the evidence folder by hand. No `lib/` change.
1. **Delete I3's lobby-only loop.** Keep a lobby capture: during the main game's lobby, sweep the three sizes as in step 2, with phase `lobby`.
2. **Add `sweepViewports(page, { code, phase, keyControls })` to `playthrough_helpers.js`.**
   - **For each size** — `{375, 812}`, `{768, 1024}`, `{1280, 800}`:
     1. `page.setViewportSize`, wait 1.5 s for Flutter to lay out again, then `enableSemantics`.
     2. Assert `readRoom(code).currentPhase === phase`, using the room's phase names: `lobby`, `truth`, `vote`, `reveal`, `gameOver` (checked in `functions/src/index.ts`).
     3. Assert every listed key control is present, scrolling vertically with the mouse wheel to find it if needed. Its rect must sit **inside the viewport horizontally** (`x >= -1` and `x + width <= width + 1`).
     4. Save `w21_<w>x<h>_<phase>.png` to the shot directory.
     5. Log every semantics node whose right edge passes the viewport width, as information only: the deck carousel peeks past the edge on purpose.
   - **Restore 1280×800 at the end,** in a `finally`.
3. **Call it on P1 (the host) during the main game:**
   - **truth:** in W6, before P1 types — the key controls are the craft `TEXTAREA` and `SUBMIT DOSSIER`;
   - **vote:** in W8, before P1 votes. If P1 is the reader, use `I'M READY` / `NOT READY`, otherwise `TAP A CARD TO CHOOSE`; read the room to tell which.
   - **reveal:** in W9 — `THE REVEAL`;
   - **gameOver:** after W10 — `Share Case File`.

   Add any new literal to `ui_strings.js`. A key control that is missing or runs past the viewport edge **fails the run**. If it is a real layout defect, STOP and file it with options; do not change `lib/` in AL2.
4. **Run `./scripts/run_web_smoke.sh`;** it must exit 0. Then copy that run's 15 `w21_*.png` (5 phases × 3 sizes) from its shot directory into `docs/playthroughs/evidence/`. **Open each one** and check it shows the named screen at the named size (lesson: open the artefact). Never overwrite an existing file.
5. **`findings_web.md`:**
   - **Correct W17, W18 and W19 in place:**
     - Change each `- **Verdict:** PASS` to `- **Verdict:** NOT RUN — the in-game screens were never captured (recorded PASS on August 30; corrected <date>, Issue 197; superseded by W21)`.
     - Add `- **Reason:** the cited Crafting, Voting, Reveal and GameOver images show a one-player lobby (October 14: w17 craft = vote and reveal = gameover by checksum; w18 vote = reveal); only the Lobby image at each size shows what it names.`
     - **Keep** the Observed lists and the old files.
   - **Add W21 — Responsive Sweep: lobby and in-game screens at three web sizes,** in the W17 format:
     - **Verdict:** PASS
     - **What I did:** the run's date, the main-game room code and the three sizes
     - **Observed:** the 15 `docs/playthroughs/evidence/w21_*.png` paths
     - **Expected:** each screen's key controls inside the viewport at each size
     - **Limit, stated:** a resized desktop page, with no touch emulation and no mobile user agent

#### Validation
1. **Falsify (test code; each fault runs through the real runner from a scratch clone, reset with `git reset --hard`):**
   - (a) a key control's horizontal bound tightened to `width - 400` → the run fails at the first sweep, naming the control and the size;
   - (b) the sweep asserts phase `vote` during W6 → it fails on the phase;
   - (c) the sweep skipped → the run passes, but `w21_*` is missing, which the PNG check in step 3 catches by name.
2. **Acceptance:** the runner exits 0 twice. Every run's shot directory holds all 15 `w21_*` names; the runner's PNG check stays ≥ 20.
3. **Evidence:**
   - `./scripts/check_playthrough_evidence.sh docs/playthroughs/findings_web.md` exits 0, and so do the no-argument run and the other three files.
   - Counted with `grep -c '^- \*\*Verdict:\*\* NOT RUN'`, W17–W19 are NOT RUN blocks with a Reason line.
   - W21 cites 15 files that exist.
   - `git diff --stat docs/playthroughs/evidence` shows **only additions**.
4. **The nine §1 gates, bare** (no `lib/` change); `check_web_e2e_strings.sh` exits 0.
5. **One commit:** `test(web): sweep every phase at three sizes and correct the W17–W19 record (Wave AL / AL2, Issue 197 Option A)`. Include `Falsification:` (a–c) and `Device check: NOT RUN — no app change; the sweep is the check`. Do not push.

**Blast radius:**
- `test/web_e2e/playthrough_helpers.js`, `run_full_playthrough.js`, `ui_strings.js`;
- `docs/playthroughs/findings_web.md`, `docs/playthroughs/evidence/w21_*.png` (new);
- this guide (remove AK1's I3 accepted-equivalent bullet; §1's smoke row notes the sweep);
- the tracker (a §3 row; delete Issue 197's block).
- No design doc.

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
- **AK1: the responsive sweep (I3) still saves the lobby under the craft, vote, reveal and game-over names.** AL2 replaces it (Issue 197 → A); remove this bullet then.
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

**The web smoke (AK1)**
- **Run `./scripts/run_web_smoke.sh` before every web deploy;** it must exit 0.
- **It never writes `docs/playthroughs/evidence/`.** Re-capturing cited evidence is a deliberate, separate act under the evidence gate's rules.
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
(1) Take Wave AL in order (§2): AL1, then AL2. After AL2 the queue is empty:
    STOP unless there is a new user selection or instruction, a red gate, or a
    user report. Never fill in or edit a `Your selection:` line.
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

**When AL2 is done the queue is empty. Do not invent work.** The only legitimate triggers for further action are:
1. a new user selection or instruction (a new guide rewrite specs it first);
2. a §1 gate going red (investigate, then file with options);
3. a user or tester report — for example *Something went wrong. Try again.* while offline, which re-opens the 192 inference (§4).

Anything else, including tidying, upgrading dependencies or migrating `withOpacity`, is not approved.
