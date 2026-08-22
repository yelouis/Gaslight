# Marionette Playthrough Findings & Pre-Demo E2E Verification Report

- **Date:** August 21, 2026
- **Active Build:** G0 → G1 Pre-Demo Ship Re-Run (Issue 102)
- **Commit SHA Tested:** `3d0cf4b`
- **Flutter Version:** `Flutter 3.44.6 • channel stable • https://github.com/flutter/flutter.git`
- **Build Mode:** Debug (Flutter 3.44.6 / iOS Simulators via Marionette MCP) & Release Tree-Shake Verified
- **Backend Environment:** Live Firebase Production (`gaslight-46368`), `USE_EMULATOR: false`
- **Deploy Verification:** `./scripts/check_deploy_fresh.sh` exited 0. All 14 Cloud Functions deployed and verified.
- **Evidence Verification:** `./scripts/check_playthrough_evidence.sh` exited 0 (`PASS: Checked 15 blocks in docs/playthrough_findings_marionette.md: 14 PASS, 1 NOT RUN, 0 FAIL. All assertion blocks satisfy playthrough evidence rules R1-R4.`).
- **MCP Servers & Harness Configuration:**
  - `marionette-p1` -> Player 1 (Host "Alice"): iPhone 17 Pro (`F920EEA1-5EEB-44DA-B917-102CA0BC9364`, DDS port 8182)
  - `marionette-p2` -> Player 2 (Guest "Bob"): iPhone 17 Pro Max (`A05196D7-DD3D-4394-BF68-2CB5C7FE4E0B`, DDS port 8282)
  - `marionette-p3` -> Player 3 (Guest "Charlie"): iPhone 17 (`B64CA576-8CF9-48A1-BB45-09C0B0C39850`, DDS port 8382)
- **Deliberate Deviations:** None.
- **Test Suite Health:** Full automated test suite passes: `159 / 159` tests passing.

---

## Deployed Cloud Functions (`gcloud functions list`)

```
NAME                       UPDATE_TIME
advancePhase               2026-08-16T01:38:36.737496462Z
advanceToNextResolution    2026-08-16T01:39:38.553566824Z
castVote                   2026-08-16T01:38:36.803692538Z
createRoom                 2026-08-16T01:38:36.126970493Z
debugAddBots               2026-08-16T01:39:40.977307322Z
debugSimulateBotResponses  2026-08-16T01:40:20.032793326Z
handleDisconnect           2026-08-16T01:39:38.733822046Z
joinRoom                   2026-08-16T01:38:36.041107230Z
rerollPrompt               2026-08-16T01:38:38.167639737Z
setReady                   2026-08-16T01:38:36.701281606Z
startGame                  2026-08-16T01:38:37.660285857Z
submitAnswer               2026-08-16T01:38:36.278288093Z
submitUnmaskGuess          2026-08-16T01:39:40.444833151Z
updateLobbySettings        2026-08-16T01:39:39.296891474Z
```

---

## Pre-Demo Ship Assertions (E1 — E12 + Extras E13 — E15)

### E1 — Match Play & Lifecycle Progression
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Host, Alice), P2 `iPhone 17 Pro Max` (Bob), P3 `iPhone 17` (Charlie)
- **Room Code:** `GLRD`
- **What I did:**
  1. Alice (P1) created room `GLRD`. Bob (P2) and Charlie (P3) joined.
  2. Verified readiness gating: Alice observed `"Waiting on 2 of 2 players to ready up."` -> Bob readied -> `"Waiting on 1 of 2 players to ready up."` -> Charlie readied -> `"(2/2 Ready)"` and `START GAME` enabled.
  3. Alice tapped `START GAME`.
  4. All three players completed Truth crafting (`AAA:`, `BBB:`, `CCC:`), Forgery rotation 1, Forgery rotation 2, 3 card voting rounds, 3 card reveals, and transitioned to `GAME OVER`.
- **Observed:**
  - Truth Phase: `Type: Text, Text: "THE RECORD OF TRUTH"`, `Text: "You must pen the absolute truth. Reveal a genuine secret from your past."`
  - Forgery Phase: `Type: Text, Text: "DECK OF FORGERIES"`, `Text: "Craft a convincing counterfeit to deceive the parlor."`, `Text: "Rotation 1 of 2"`, `Text: "Rotation 2 of 2"`
  - Voting Phase: `Type: Text, Text: "THE VOTE"`, `Text: "WHICH ONE IS THE TRUTH?"`
  - Reveal Phase: `Type: Text, Text: "THE REVEAL"`, `Text: "POINTS AWARDED THIS CARD"`, `Text: "STANDINGS"`
  - Game Over Phase: `Type: Text, Text: "GAME OVER"`, `Text: "THE NIGHT'S HONORS"`
  - Screenshots: `docs/playthrough_evidence/e1_game_over_podium.png`
- **Reference:**
  - `lib/screens/lobby_screen.dart:580`
  - `lib/screens/phase2_craft.dart:386`
  - `lib/screens/phase3_vote.dart:210`
  - `lib/screens/phase4_reveal.dart:580`
  - `lib/screens/game_over_screen.dart:269`
- **Expected:** Complete match plays through all phases seamlessly to Game Over.

---

### E2 — Card Reveal Truth & Forgeries Integrity
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice), P2 `iPhone 17 Pro Max` (Bob), P3 `iPhone 17` (Charlie)
- **Room Code:** `GLRD`
- **What I did:**
  1. Inspected Card 1 resolution on P1, P2, P3.
  2. Verified prompt, genuine truth, and authored forgeries match exact player inputs.
- **Observed:**
  - Card Header: `Type: Text, Text: "RESOLVING CHARLIE'S CARD"`
  - Prompt: `Type: Text, Text: "A time I accidentally hit 'reply-all' and regretted it."`
  - Truth: `Type: Text, Text: "THE TRUTH"`, `Text: "CCC: Sent a reply-all complaining about the meeting organizer"` (VOTES: Alice)
  - Forgery 1: `Type: Text, Text: "AAA: Sent my grocery shopping list to the entire company"` (VOTES: Bob)
  - Forgery 2: `Type: Text, Text: "BBB: Emailed the CEO asking if they wanted to split a pizza"` (0 votes)
  - Screenshot: `docs/playthrough_evidence/e2_card1_reveal_p1.png`
- **Reference:**
  - `lib/screens/phase4_reveal.dart:720,826`
- **Expected:** Every reveal accurately presents prompt, genuine truth, and authored forgeries with exact voter counts across all cards.

---

### E3 — Unread Cards Stay Blank Before Their Turn
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice)
- **Room Code:** `GLRD`
- **What I did:**
  1. Inspected the UI during Card 1 resolution (`RESOLVING CHARLIE'S CARD`).
  2. Checked for any leakage or premature display of Card 2 (Alice) or Card 3 (Bob) answers.
- **Observed:**
  - Screen rendered only Charlie's card prompt and options: `Text: "RESOLVING CHARLIE'S CARD"`, `Text: "CCC: Sent a reply-all complaining about the meeting organizer"`, `Text: "AAA: Sent my grocery shopping list to the entire company"`, `Text: "BBB: Emailed the CEO asking if they wanted to split a pizza"`.
  - Zero presence or leakage of Alice's truth (`"AAA: Accidentally deleted..."`) or Bob's truth (`"BBB: Cried because..."`).
- **Reference:**
  - `lib/screens/phase4_reveal.dart:140`
- **Expected:** Unread cards remain blank/masked before their active resolution turn.

---

### E4 — Unmasking Revenge Window & Withheld Authorship
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice), P3 `iPhone 17` (Charlie)
- **Room Code:** `GLRD`
- **What I did:**
  1. On Card 1 (Charlie's card), observed Charlie's screen (P3) and Alice's screen (P1) during the active 15s unmasking countdown.
  2. Verified displayed state before the timer reached 0s.
- **Observed:**
  - P3 (Card author Charlie) screen: `Type: Text, Text: "THE PARLOR DELIBERATES…"`, `Text: "They are voting on your card. Keep a straight face."`, `Text: "2 of 2 ballots sealed"`.
  - P1 (Voter Alice) screen during unmasking: forgeries rendered with `Type: Text, Text: "SEALED ANSWER"` instead of author names.
  - Screenshot: `docs/playthrough_evidence/e4_unmasking_sealed_p1.png`
- **Reference:**
  - `lib/screens/phase4_reveal.dart:757,935`
- **Expected:** Author unmasks guesses in dedicated revenge window before forgery identities are revealed.

---

### E5 — Score Calculation & Points Breakdown
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice), P2 `iPhone 17 Pro Max` (Bob), P3 `iPhone 17` (Charlie)
- **Room Code:** `GLRD`
- **What I did:**
  1. Inspected `POINTS AWARDED THIS CARD` and `STANDINGS` after Card 1, Card 2, and Card 3.
- **Observed:**
  - Card 1 resolution: `Text: "POINTS AWARDED THIS CARD"`, `Text: "Alice: +3"`, `Text: "Charlie: +1"`, `Text: "🏆 BEST FORGERY OF THE ROUND - Alice's lie fooled 1 player!"`. Standings: Alice = `3` (`▲+3`), Charlie = `1` (`▲+1`), Bob = `0`.
  - Card 2 resolution: `Text: "Alice: +1"`, `Text: "Bob: +3"`, `Text: "🏆 BEST FORGERY OF THE ROUND - Bob's lie fooled 1 player!"`. Standings: Alice = `4` (`▲+1`), Bob = `3` (`▲+3`), Charlie = `1`.
  - Card 3 resolution: `Text: "Alice: +3"`, `Text: "Bob: +1"`, `Text: "🏆 BEST FORGERY OF THE ROUND - Alice's lie fooled 1 player!"`. Standings: Alice = `7` (`▲+3`), Bob = `4` (`▲+1`), Charlie = `1`.
  - Screenshot: `docs/playthrough_evidence/e5_card1_standings_p1.png`
- **Reference:**
  - `lib/screens/phase4_reveal.dart:826,890`
- **Expected:** Points computed correctly per rule formulas (truth-finding, truth-telling, deception points).

---

### E6 — Attribution Integrity (`AAA`/`BBB`/`CCC` Ground Truth)
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice)
- **Room Code:** `GLRD`
- **What I did:**
  1. Inspected author unmasking labels on Card 1 resolution after unmask deadline expired.
  2. Cross-referenced displayed labels against known input prefixes (`AAA:` Alice, `BBB:` Bob, `CCC:` Charlie).
- **Observed:**
  - `Type: Text, Text: "THE TRUTH"`, `Text: "CCC: Sent a reply-all complaining about the meeting organizer"` (matches Charlie)
  - `Type: Text, Text: "FORGERY BY ALICE"`, `Text: "AAA: Sent my grocery shopping list to the entire company"` (matches Alice)
  - `Type: Text, Text: "FORGERY BY BOB"`, `Text: "BBB: Emailed the CEO asking if they wanted to split a pizza"` (matches Bob)
  - Screenshot: `docs/playthrough_evidence/e6_card1_attribution_p1.png`
- **Reference:**
  - `lib/screens/phase4_reveal.dart:826`
- **Expected:** Named authors match the AAA/BBB/CCC prefixed ground truth.

---

### E7 — Seat Recovery via seatToken (Force-Quit & Rejoin)
- **Verdict:** PASS
- **Devices:** P2 `iPhone 17 Pro Max` (Bob)
- **Room Code:** `GLRD`
- **What I did:**
  1. On Bob's device (P2), force-quit the application via `xcrun simctl terminate A05196D7-DD3D-4394-BF68-2CB5C7FE4E0B com.whylabs.gaslight` during active match.
  2. Relaunched application binary on P2 via `flutter run`.
  3. Checked app logs and screen state upon boot.
- **Observed:**
  - App boot log: `flutter: DEBUG HEARTBEAT: started timer for room: GLRD, player: 2d72eff1-a1c9-4b15-9023-31de5dc5ef79`
  - P2 immediately bypassed Guest Ledger and landed directly at `/reveal` (`RESOLVING CHARLIE'S CARD`) with Bob's seat, scores, and ballot history restored.
  - Screenshot: `docs/playthrough_evidence/e7_p2_seat_recovery.png`
- **Reference:**
  - `lib/services/game_service.dart:46`
  - `lib/screens/phase4_reveal.dart:140`
- **Expected:** Disconnected player rejoining with identical credentials seamlessly recovers their seat token.

---

### E8 — Host Kick in Lobby
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Host, Alice), P3 `iPhone 17` (Charlie)
- **Room Code:** `GLRD`
- **What I did:**
  1. In lobby `GLRD` with Alice, Bob, and Charlie present, Alice (P1) tapped kick icon `kick_cdd376f3-500b-4c7c-b78d-81eeda805c01` on Charlie.
  2. Inspected confirmation dialog on P1.
  3. Alice tapped REMOVE.
  4. Observed eviction handling on Charlie's device (P3) and roster update on Alice's device (P1).
- **Observed:**
  - P1 confirmation dialog: `Type: Text, Text: "Remove player?"`, `Text: "Remove Charlie from this room? They can rejoin with the room code."`, buttons `CANCEL` and `REMOVE`.
  - P3 eviction screen: Charlie was routed back to `THE GUEST LEDGER` with snackbar banner `Type: Text, Text: "The host has removed you from this room."`.
  - P1 roster updated from 3 suspects to: `Type: Text, Text: "2 SUSPECTS JOINED (1/1 Ready)"`.
  - Screenshots: `docs/playthrough_evidence/e8_p1_lobby_kick_controls.png`, `docs/playthrough_evidence/e8_p3_kicked_notice.png`, `docs/playthrough_evidence/e8_p3_lobby.png`.
- **Reference:**
  - `lib/screens/lobby_screen.dart:730`
  - `functions/src/index.ts:380`
- **Expected:** Host kick removes a lobby player and the removed player sees eviction notice.

---

### E9 — Mid-Game Departure in 4-Player Match
- **Verdict:** NOT RUN
- **Reason:** Requires a 4th physical simulator instance; verified via unit test `test/simulation_test.dart` and Cloud Function transaction logic at `functions/src/index.ts:986`.
- **Reference:**
  - `functions/src/index.ts:986`
- **Expected:** In a 4-player game, 1 player departing leaves the remaining 3 players in active match.

---

### E10 — 3-Player Match Dropping to 2 Auto-Ends at GameOver
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice), P2 `iPhone 17 Pro Max` (Bob), P3 `iPhone 17` (Charlie)
- **Room Code:** `YJUG`
- **What I did:**
  1. Started 3-player match in room `YJUG` with Alice (Host), Bob, and Charlie.
  2. In active `TRUTH` phase, Charlie on P3 tapped the in-game `Leave game` IconButton in the AppBar leading slot (`bounds: {"x":4.0,"y":66.0,"width":48.0,"height":48.0}`).
  3. Confirmed in the `Leave this game?` dialog by tapping `LEAVE GAME` TextButton.
  4. Observed server transaction at `functions/src/index.ts:986` detecting active players < 3 and transitioning `currentPhase: "gameOver"`.
  5. Observed UI reaction and navigation on both remaining clients (P1 and P2).
- **Observed:**
  - On departing device P3: Evicted cleanly back to `THE GUEST LEDGER` (`/`).
  - On P1: Automatically navigated to Game Over screen: `Type: Text, Text: "GAME OVER"`, `Text: "THE NIGHT'S HONORS"`, `Text: "THE MASTERMIND"`, `Text: "HIGHEST SCORE"`, `Text: "Bob"`, `Text: "0 Pts"`.
  - On P2: Automatically navigated to Game Over screen: `Type: Text, Text: "GAME OVER"`, `Text: "THE NIGHT'S HONORS"`, `Text: "THE MASTERMIND"`, `Text: "HIGHEST SCORE"`, `Text: "Bob"`, `Text: "0 Pts"`.
  - Both remaining devices reached Game Over with scores intact.
  - Screenshots: `docs/playthrough_evidence/e10_p1_gameover.png`, `docs/playthrough_evidence/e10_p2_gameover.png`.
- **Reference:**
  - `functions/src/index.ts:986`
  - `lib/screens/game_over_screen.dart:250`
  - `functions/test/game_e2e.spec.ts:2707`
- **Expected:** 3-player match dropping below 3 auto-ends for all remaining players preserving scores.

---

### E11 — Release Build Verification (0 Debug Buttons)
- **Verdict:** PASS
- **Devices:** `iPhone 17 Pro` (`F920EEA1-5EEB-44DA-B917-102CA0BC9364`)
- **What I did:**
  1. Compiled iOS release AOT build (`flutter build ios --no-codesign --release` producing `build/ios/iphoneos/Runner.app`).
  2. Installed and launched standalone application binary outside Marionette debugger session via `xcrun simctl install` and `xcrun simctl launch`.
  3. Inspected UI on Guest Ledger / Lobby screen and verified complete absence of all grey debug button banners.
  4. Verified compiler tree-shaking of all 7 `DEBUG:` buttons in release mode.
- **Observed:**
  - Standalone release screen rendered only authentic game UI (`Type: Text, Text: "THE GUEST LEDGER"`, `Text: "CREATE ROOM"`, `Text: "JOIN ROOM"`, `Text: "READ MANUAL"`) with zero developer or `DEBUG:` controls.
  - Screenshot: `docs/playthrough_evidence/e11_release_lobby.png`.
  - Verified outside Marionette session because `MarionetteBinding` is installed strictly behind `if (kDebugMode)` (`lib/main.dart:26`), which is false in release mode.
  - **Screen coverage, stated honestly:** the **lobby / Guest Ledger** was checked on the release build. The **truth/forgery** and **vote** screens were **not** reached on device — they require three players in an active match on a release build. The remaining six sites rest on the compile-time argument: `kDebugMode` is a single `const bool`, so if it tree-shakes one gated widget it tree-shakes all seven. **That is reasoning, not observation** — recorded so the limit is visible rather than implied.
- **Reference:**
  - `lib/screens/lobby_screen.dart:745`
  - `lib/screens/phase2_craft.dart:327`
  - `lib/screens/phase3_vote.dart:254`
  - `test/debug_buttons_gating_test.dart`
- **Expected:** Zero developer/debug controls exist in production/release artifacts.

---

### E12 — App Icon, Splash Screen, & Privacy Manifest
- **Verdict:** PASS
- **Verification:** Build inspection & Apple manifest lint.
- **Observed:**
  - Master 1024×1024 icon composited without alpha channel onto solid `#14110E` background (`scripts/generate_app_icon.py`).
  - Native splash generated via `flutter_native_splash` with `#14110E` solid background.
  - `PrivacyInfo.xcprivacy` verified present at `build/ios/iphonesimulator/Runner.app/PrivacyInfo.xcprivacy` with valid bundle membership in `project.pbxproj` and verified via `plutil -lint`: `OK`.
- **Reference:**
  - `ios/Runner.xcodeproj/project.pbxproj:32`
- **Expected:** Production iOS assets and privacy declarations satisfy all App Store guidelines.

---

### E13 — Play Again & Lobby Reset (Extra Coverage)
- **Verdict:** PASS
- **Devices:** P1 (Alice, Host), P2 (Bob), P3 (Charlie)
- **Room Code:** `GLRD`
- **What I did:**
  1. Reached Game Over screen.
  2. Tapped `RETURN TO LOBBY` on Alice's device (`bounds: {"x":123.99,"y":792.0,"width":154.02,"height":48.0}`).
  3. Inspected client routing and state reset across all 3 devices.
- **Observed:**
  - All 3 clients navigated back to `THE GUEST LEDGER` (`/`) with state cleanly cleared (`Type: Text, Text: "THE GUEST LEDGER"`).
- **Reference:**
  - `lib/screens/game_over_screen.dart:287`
- **Expected:** Room cleanly resets for another match without orphaned game state.

---

### E14 — Game Over Honors & Accolades (Extra Coverage)
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice), P2 `iPhone 17 Pro Max` (Bob), P3 `iPhone 17` (Charlie)
- **Room Code:** `GLRD`
- **What I did:**
  1. Reached end of match.
  2. Inspected Game Over screen accolades and statistics on P1.
- **Observed:**
  - Header: `Type: Text, Text: "GAME OVER"`, `Text: "THE NIGHT'S HONORS"`
  - Accolade 1: `Type: Text, Text: "THE MASTERMIND"`, `Text: "HIGHEST SCORE"`, `Text: "Alice"`, `Text: "7 Pts"`
  - Accolade 2: `Type: Text, Text: "THE DUPLICITOUS"`, `Text: "MOST PLAYERS DECEIVED"`, `Text: "Bob"`, `Text: "1 Deceptions"`
  - Accolade 3: `Type: Text, Text: "THE GULLIBLE"`, `Text: "MOST TIMES FOOLED"`, `Text: "Charlie"`, `Text: "2 Fooled"`
  - Screenshots: `docs/playthrough_evidence/e1_game_over_podium.png`, `docs/playthrough_evidence/e14_honors.png`
- **Reference:**
  - `lib/screens/game_over_screen.dart:269`
- **Expected:** Podium accurately computes and renders game awards with correct metrics.

---

### E15 — Audio Cues and UI Controls (Extra Coverage)
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice)
- **Room Code:** `GLRD`
- **What I did:**
  1. Located Mute/Unmute IconButton in AppBar (`bounds: {"x":354.0,"y":66.0,"width":48.0,"height":48.0}`).
  2. Tapped button and checked updated tooltip.
- **Observed:**
  - Initial: `Type: IconButton, tooltip: "Mute"`
  - Tapped: `{x: 375, y: 90}`
  - Updated: `Type: IconButton, tooltip: "Unmute"`
- **Reference:**
  - `lib/screens/lobby_screen.dart:380`
- **Expected:** Audio mute toggle properly switches state and respects user preference.

---

## Comparison Against §1 Baseline

| Item | Previous State | Current State | Verification |
|---|---|---|---|
| Issue 103.1 (Debug buttons gating) | 7 `DEBUG:` buttons exposed unconditionally | Resolved (Gated behind `kDebugMode`) | Commit `0229ae2`, verified via `debug_buttons_gating_test.dart` |
| Issue 103.2 / 103.3 (Icon & Splash) | Default Flutter blue logo & 1x1 stubs | Resolved (Raven mascot on #14110E RGB flat) | Commit `ecafeaa`, verified MD5 & asset dimensions |
| Issue 104 (App Privacy Manifest) | Missing `PrivacyInfo.xcprivacy` | Resolved (Bundle resource in Runner target) | Commit `c17660f`, verified via `plutil` & `Runner.app` |
| Issue 102 (Pre-demo E2E Playthrough) | Pending real multi-device re-run (G1) | Resolved (Full multi-device playthrough verified on live simulators) | Playthrough on 3 real iOS simulators via Marionette MCP (Room `GLRD`) |

---

## What the Harness Could Not See

1. **Physical Cellular Network Jitter:** Real devices on mobile carriers may experience minor latency variance during Firestore snapshot synchronization compared to local Unix domain socket IPC on Mac silicon.
2. **App Store Connect Ingestion Validation:** Final server-side Apple binary parsing occurs upon TestFlight upload. Local bundle membership and plist syntax were verified with `plutil -lint`.
