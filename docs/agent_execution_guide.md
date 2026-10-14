# Agent Execution Guide — Active Build: Wave AK (web smoke repair, then the 1.2.0 (9) web release) — October 13, 2026

**You are an engineering agent with no memory of this project.**

**Where things stand.** Wave AI came from a read-only audit on October 10 (Issues 178–191) plus two October 12 follow-ups (192, 193). All sixteen of its items, AI1–AI15 and AH1, are built, and AI11's server change is deployed. **The whole wave was verified on October 13** by re-running every gate and re-falsifying every item in scratch clones (§3).

**Two items are approved: Wave AK (§2).** AJ1 (`adb05fc`) built and verified the 1.2.0 (9) iOS archive; uploading it is the user's step. Its web deploy was blocked because the web playthroughs fail on every client (Issue 195). On October 13 the user chose **Issue 195 → Option A** in chat, extended as the validation recommends. **AK1** repairs the web smoke and makes it one command; **AK2** then deploys 1.2.0 (9) to the web with the user's go-ahead. When AK2 is done the queue is empty. **Do not invent work.**

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

## 1. Verified baseline — measured October 13, 2026 on `27a6314`; AJ1's preflight on `1.2.0+9` (`adb05fc`) matched it exactly

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

## 2. Wave AK — repair the web smoke (Issue 195 → A, extended), then ship 1.2.0 (9) to the web

| Step | Item | Why this position |
|---|---|---|
| 1 | **AK1** Repair both web playthroughs and make the web smoke one command | The web deploy is blocked on a check that cannot tell the truth. |
| 2 | **AK2** Web release of 1.2.0 (9) | Only after AK1's smoke exits 0 on `HEAD`, and only with the user's go-ahead. |

**The user's own step runs in parallel:** uploading the archived 1.2.0 (9) to TestFlight from Xcode's Organizer. **Never delete or rebuild `build/ios/archive/`**; it is the artefact the user uploads.

### 2.1 AK1 — Repair the web playthroughs; one-command web smoke (Issue 195 → A, extended)

**What this means for the user.** The web app's only end-to-end check fails on every client, so the 1.2.0 (9) web release is blocked. Worse, one of the two scripts can report success without finishing a game. After AK1, one command builds an emulator-only web app, plays two full games with three browsers against the local emulators, and exits 0 only if both reach game over.

**Why "extended".** The user chose Option A, which this item keeps whole. The October 13 validation (tracker, Issue 195) found three things A as filed did not cover, so this item adds two parts:
- **What the validation found:**
  1. The match-summary "hang" is a silent loop that **ends in a false pass**.
  2. The vote failure is the stacked deck's one-card-at-a-time layout plus the host's `PROCEED TO REVEAL (HOST)` button.
  3. `firebase emulators:exec` hides failures unless the exit code is passed on.
- **What AK1 adds:**
  1. **no vacuous pass** — stall detection and loop exhaustion both throw;
  2. **a one-command runner.** AJ1 and the validation each spent about 30 minutes re-deriving the emulators, server and port setup by hand.

**The gap.** Issue 195's block in the tracker has the full evidence. In brief:
- **W7:** it types Alice's truth as P2's "duplicate", but who forges whose card is random per game. After a rejection it cannot find the field, because the field is matched by the word "quill" and a field holding text has an empty `aria-label`.
- **W5:** it toggles timers on.
- **The match-summary script:**
  - it votes only for a button containing `OPTION`, the deck's front card, and never presses `Next option`;
  - it never presses `PROCEED TO REVEAL (HOST)`;
  - it logs only when it acts;
  - it prints success when its 120 ticks run out.
- **Screenshots:** both scripts write into `docs/playthroughs/evidence/`, and all 20 file names they save are cited in `findings_web.md`.

#### Implementation
Change `test/web_e2e/*.js` and add `scripts/run_web_smoke.sh`. **No change to `lib/`, `functions/` or any app string.**

1. **Screenshots leave the tracked tree.**
   - In `playthrough_helpers.js`, `EVIDENCE_DIR` becomes `process.env.WEB_E2E_SHOT_DIR` when set, otherwise `fs.mkdtempSync(path.join(os.tmpdir(), 'gaslight-web-e2e-'))`. Print it once at start.
   - `saveScreenshot` returns the absolute path. Delete every log line that claims `Saved docs/playthroughs/evidence/…`.
   - A default run must never write `docs/playthroughs/evidence/`. Re-capturing the cited evidence is **not** part of AK1.
2. **An oracle for end states: the emulator's room document.** Add `readRoom(code)` to the helpers. It is a `GET` with `Authorization: Bearer owner`:
   - URL: `${WEB_E2E_FIRESTORE || 'http://127.0.0.1:8080'}/v1/projects/gaslight-46368/databases/(default)/documents/rooms/<code>`;
   - returns the room's fields, checked October 13 on an emulator room: `currentPhase`, `currentReaderId`, `currentRound`, `currentRotationIndex`, `isTimerDisabled`, `readyPlayers`, `rotationPlan`, and `cards[]`. Each card has `targetPlayerId` and a `votes` map keyed by voter.
   - Submitted answers are sealed and not on the room, but each submission marks its author in `readyPlayers`.

   The scripts are emulator-only by design (the runner builds with `USE_EMULATOR=true`), so this is safe. It is the only reliable way to assert a phase change.
3. **Craft field by tag, not by "quill".** Add `typeIntoCraftField(page, text)`.
   - It finds the visible `TEXTAREA` elements and throws with a dump unless there is **exactly one**.
   - Then it clicks it, selects all, deletes, and types.
   - Use it for every truth and forgery entry in both scripts. Keep `typeIntoInput` for labelled fields (`Your Name`, `Room Code`).
4. **W5 reads before it clicks.** Click `Disable Game Timers` only if `readRoom(code).isTimerDisabled !== true`, then assert it is `true`. Apply the same to the match-summary script's settings step.
5. **W7 becomes author-aware.**
   - Read P2's instruction with `/Write a convincing lie as (.+?)\./`.
   - Log `P2 is forging <Name>'s card`; the validation needs it.
   - Type **that** player's W6 truth and submit. Within 5 s, assert two things: P2 shows `Too similar to an existing answer! Be more creative.` (add `TOO_SIMILAR` to `UI` in `ui_strings.js`), and P2's craft field is still present.
   - Then type a valid forgery with `typeIntoCraftField`, submit, and assert P2's craft field is gone within 10 s.
6. **Voting on the stacked deck (both scripts).** Add `castVote(page, preferText)`:
   - N comes from the `Show option k of N` labels.
   - Look at up to N cards. A card is votable when a button's text starts with `OPTION ` and contains `Tap to choose this one` (add `TAP_TO_CHOOSE` to `UI`).
   - Click the preferred votable card if one is seen, otherwise the first votable one; then click `CONFIRM VOTE`. If the front card is not votable, press `Next option`.
   - Afterwards assert, within 10 s, that the page no longer shows `CONFIRM VOTE` or `TAP A CARD TO CHOOSE`.
   - If no card is votable after N presses, throw with a dump.
   - On the vote screen, a page showing `I'M READY` presses it (the target's toggle). **`NOT READY` means already ready: never press it.**
7. **Advance on observed state, not on timers.**
   - After every action, read `readRoom(code).currentPhase`.
   - The host presses `PROCEED TO REVEAL (HOST)` (add `PROCEED_TO_REVEAL` to `UI`) only when every voter's vote is in the `votes` of the card whose `targetPlayerId` is `currentReaderId`, and only if the phase has not left `vote` within 10 s by itself.
   - Log which of the two happened.
8. **No silent loops and no vacuous pass (both scripts).**
   - Every loop iteration logs one line: the tick, the room phase, and each page's screen marker.
   - **Stall:** if the room's `currentPhase`, `currentReaderId`, `currentRound`, `currentRotationIndex`, number of `readyPlayers` entries and total number of `votes` entries are all unchanged for **6** consecutive ticks, throw `STALLED`, with every page's buttons and one screenshot per page.
   - **Loop exhaustion throws**; it never falls through to the success path.
   - Every `page.evaluate` in the helpers is raced against a **15 s** timeout that throws `PAGE UNRESPONSIVE P<n>`. That separates an app freeze from a script stall.
   - Each `W` step in `run_full_playthrough.js` ends with **one positive end-state assertion** (a room phase or a screen marker). A `try*` helper may be used only where the action is genuinely optional, and the step still asserts its end state.
   - Each script must finish within **10 minutes**.
9. **`scripts/run_web_smoke.sh`, the one command.** Bash, `set -uo pipefail`.
   1. **Refuse to start** if any of the ports 8777, 8080, 9099, 5001, 4000, 4400, 4500 or 9150 is listening. Print the owning process and **kill nothing** (§0.1).
   2. `TMP=$(mktemp -d)`; `flutter build web --release --dart-define=USE_EMULATOR=true -o "$TMP/web"` (**never `build/web`**); `npm --prefix functions run build`.
   3. Run `PATH="/opt/homebrew/bin:/opt/homebrew/opt/openjdk/bin:$PATH" npx firebase-tools emulators:exec --only auth,functions,firestore --project gaslight-46368 "<this script> --inner $TMP"`.
   4. **Inner mode:**
      - serve `$TMP/web` with `python3 -m http.server 8777 --bind 127.0.0.1` in the background;
      - run each script from `test/web_e2e/` under a hard kill, `perl -e 'alarm 600; exec @ARGV' node <script>` (macOS has no `timeout`), with `WEB_E2E_SHOT_DIR=$TMP/shots`;
      - stop the server;
      - **`exit` with the combined status as the last command.** `emulators:exec` passes on the exit code of its command's last line.
   5. Print the shot directory, each script's exit code and the verdict. Then fail if `git status --porcelain docs/playthroughs/evidence` is non-empty.
   6. **Exit 0 only if both scripts exited 0.**
10. **Strings:** every new UI literal goes into `ui_strings.js`, so `check_web_e2e_strings.sh` stays at exit 0. Every literal must exist in `lib/`; `Tap to choose this one` is at `lib/widgets/card_grid.dart:650`.

#### Validation
1. **Falsify the repaired scripts.** These are test code: each fault must compile and run, and must make `./scripts/run_web_smoke.sh` exit non-zero **for the intended reason**. Run each in a scratch clone and reset with `git reset --hard` between runs.
   - (a) W7 types a fresh, non-duplicate string as the "duplicate" → it fails at the `TOO_SIMILAR` assertion.
   - (b) `castVote` skips P2 → the match-summary script fails with `STALLED` within its budget (not exit 0, not a 10-minute kill).
   - (c) the tick cap set to 3 → it fails with "did not reach game over", proving exhaustion no longer passes.
   - (d) one script calls `process.exit(1)` at its first line → the runner exits non-zero, proving the exit code is passed on.
   - (e) W5's condition inverted → the `isTimerDisabled === true` assertion fails.
2. **Acceptance:** run `./scripts/run_web_smoke.sh` repeatedly until **both** rotation cycles of W7 have been seen: `P2 is forging Alice's card` and `P2 is forging Charlie's card`, at least once each.
   - Stop after at most 8 runs. **Every run must exit 0.**
   - Record each run's room codes, cycle, duration and exit code.
   - If both cycles have not appeared within 8 runs, record that; it is not a failure.
3. **The tree stays clean.** `git status --porcelain docs/playthroughs/evidence` is empty after every run (the runner checks; check by hand once). **Positive control:** the run's shot directory holds at least 20 PNGs.
4. **Ports are free after every run** (`lsof` on the eight ports); `emulators:exec` stops what it started.
5. **The nine §1 gates, bare and unchanged:** 0 / 0 / 170; 466; 167; the rest exit 0, including `check_web_e2e_strings.sh` with the new strings.
6. **Any app defect the repaired scripts expose: STOP.** File it with options and do not change `lib/` in AK1. AK2 does not run.
7. **One commit:** `test(web): repair the web playthroughs and add a one-command web smoke (Wave AK / AK1, Issue 195 Option A)`. The body includes `Falsification:` (a–e) and `Device check: NOT RUN — no app change; the web smoke itself is the end-to-end check`. Do not push.

**Blast radius:**
- `test/web_e2e/playthrough_helpers.js`, `run_full_playthrough.js`, `run_match_summary_playthrough.js` and `ui_strings.js`; `scripts/run_web_smoke.sh` (new).
- `README.md` → Releasing → **1. Web app**: before `flutter build web --release`, run `./scripts/run_web_smoke.sh`, which must exit 0. Note its run time and its needs: Java, and Playwright's Chromium in `test/web_e2e/node_modules`.
- This guide: §1 gains a **release-time check** row for `run_web_smoke.sh` (not a per-item gate); §0.1 names the runner.
- The tracker: a §3 row, Issue 195's block deleted, and the Unresolved intro updated.
- No design doc: this is test tooling.

### 2.2 AK2 — Web release of 1.2.0 (9) (finishes AJ1's web half)

**What this means for the user.** Web players are still on 1.1.0 (8). After AK2 the live site serves 1.2.0 (9), the same client as the iOS archive.

**Preconditions:** AK1 is committed; `./scripts/run_web_smoke.sh` exits 0 on `HEAD`; `pubspec.yaml` still reads `1.2.0+9`; the nine §1 gates are green.

1. **Build.** Look at `build/web` before removing it — **only `build/web`, never `build/ios/archive`**. Then run `flutter build web --release` with **no** `--dart-define`.
   - `build/web/version.json` must read `"version":"1.2.0"` and `"build_number":"9"`, with a timestamp from this run.
   - `grep -c '^USE_EMULATOR=true' .env` must be `0`. **Never print `.env` values.**
   - `test -f build/web/assets/.env` must exit 0.
2. **Ask the user for the go-ahead** — a hosting deploy changes production. Then run `npx firebase-tools deploy --only hosting` bare; it must exit 0.
3. **Check the live site without opening the app.** `lib/main.dart:65` signs in anonymously at boot, so loading the page in a browser would create a production Auth user.
   - `curl -s "https://gaslight-46368.web.app/version.json?t=$(date +%s)"` must show 1.2.0 and 9;
   - `curl -s -o /dev/null -w '%{http_code}'` must return `200` for `/` and for `/assets/.env` (status only).
4. **If the user declines,** record `Web deploy: NOT RUN — <reason>`.
5. **Do not deploy functions** (they are unchanged and fresh), and **do not upload to TestFlight**.
6. **One docs commit:** `docs(release): record the 1.2.0 (9) web deploy (Wave AK / AK2)`.
   - A tracker §3 row with the live checks.
   - The guide's "Release plumbing" line names web 1.2.0 (9) as live.
   - The guide returns to queue-complete mode: title, framing, §2 "Queue — empty", THE LOOP step (1), close-out.

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
| **192 → B** | `3a36e91` | AH1's device check closed by acceptance (simulator observation plus source trace). | Nothing to falsify. |

### Earlier waves
- **Wave AG** (AG1 error mapping, AG2 chip-header ivory, AG3 ledger on waiting screens) — verified October 3.
- **Wave AA** (sixteen items, Issues 153–169, 160, 162) — verified September 11.
- **Wave Z (152)** leave latch in a `finally` · **Y1 (151)** · **Y2 (149)** · **X1 (147)** · **X2 (148)** · **W1 (146)** · **W2 (145)** · **V1 (143, 144)** · **U1–U5**, **S1**, **R0–R2**, soak blocks **E22–E49**, Waves **Q/P/O**, Issues **96–105, 50–95, 31, 28/29**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · **iPhone-only** (`UIDeviceFamily` 1) · Node **22**. **TestFlight has build 1.1.0 (8)**, which predates Wave AI. **1.2.0 (9) is archived and verified** (`build/ios/archive/Runner.xcarchive`, October 13; the preflight on the 1.2.0+9 tree read the same numbers as §1), and **its upload is pending — the user's step in Xcode's Organizer**, because this Mac has no Apple Distribution certificate and `flutter build ipa` cannot export an `.ipa`. **The web app still serves 1.1.0 (8):** the AJ1 web smoke failed on both clients (Issue 195) and the user chose not to deploy.

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
(1) Take Wave AK in order (§2): AK1, then AK2. After AK2 the queue is empty:
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

**When AK2 is done the queue is empty. Do not invent work.** The only legitimate triggers for further action are:
1. a new user selection or instruction;
2. a §1 gate going red (investigate, then file with options);
3. a user or tester report — for example *Something went wrong. Try again.* while offline, which re-opens the 192 inference (§4).

Anything else, including tidying, upgrading dependencies or migrating `withOpacity`, is not approved.
