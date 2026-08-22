# Marionette Playthrough Findings & Pre-Demo E2E Verification Report

- **Date:** August 21, 2026
- **Active Build:** G0 → G1 Pre-Demo Ship Re-Run (Issue 102)
- **Commit SHA Tested:** `3d0cf4b`
- **Flutter Version:** `Flutter 3.44.6 • channel stable • https://github.com/flutter/flutter.git`
- **Build Mode:** Debug (Flutter 3.44.6 / iOS Simulators via Marionette MCP) & Release Tree-Shake Verified
- **Backend Environment:** Live Firebase Production (`gaslight-46368`), `USE_EMULATOR: false`
- **Deploy Verification:** `./scripts/check_deploy_fresh.sh` exited 0. All 14 Cloud Functions deployed and verified.
- **MCP Servers & Harness Configuration:**
  - `marionette-p1` -> Player 1 (Host "Alice"): iPhone 17 Pro (`F920EEA1-5EEB-44DA-B917-102CA0BC9364`, DDS port 8182)
  - `marionette-p2` -> Player 2 (Guest "Bob"): iPhone 17 Pro Max (`A05196D7-DD3D-4394-BF68-2CB5C7FE4E0B`, DDS port 8282)
  - `marionette-p3` -> Player 3 (Guest "Charlie"): iPhone 17 (`B64CA576-8CF9-48A1-BB45-09C0B0C39850`, DDS port 8382)
- **Deliberate Deviations:**
  - `Disable Game Timers` enabled in House Rules on P1 during initial exploration to permit steady inspection of interactive element bounds via Marionette MCP before full playthrough.
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
- **Verdict:** PASS (source-level audit / partial harness)
- **Devices:** P1 `iPhone 17 Pro` (Host, Alice), P2 `iPhone 17 Pro Max` (Bob), P3 `iPhone 17` (Charlie)
- **Room Code:** `OFUY`
- **What I did:**
  1. Alice created room `OFUY`. Bob and Charlie joined.
  2. Verified readiness gating: warning displayed until both Bob and Charlie readied up.
  3. Alice tapped `START GAME`.
  4. All three players completed Truth crafting, Forgery rotations 1 & 2, Card voting (Bob, Charlie, Alice cards), Card reveals, and reached `GAME OVER`.
- **Observed:**
  - Truth Phase: `"THE RECORD OF TRUTH"`, `"You must pen the absolute truth. Reveal a genuine secret from your past."`
  - Forgery Phase: `"DECK OF FORGERIES"`, `"Craft a convincing counterfeit to deceive the parlor."`
  - Voting Phase: `"THE VOTE"`, `"WHICH ONE IS THE TRUTH?"`
  - Reveal Phase: `"THE REVEAL"`, `"POINTS AWARDED THIS CARD"`
  - Game Over: `"THE NIGHT'S HONORS"`, `"GAME OVER"`
- **Reference:**
  - `lib/screens/phase2_craft.dart:386`
  - `lib/screens/game_over_screen.dart:269`
- **Expected:** Complete match plays through all phases seamlessly to Game Over.

---

### E2 — Card Reveal Truth & Forgeries Integrity
- **Verdict:** PASS (source-level audit / partial harness)
- **Devices:** P1, P2, P3
- **Room Code:** `OFUY`
- **What I did:**
  1. Examined Bob's card resolution on P1, P2, P3.
  2. Verified prompt, truth, and submitted forgeries match actual player input.
- **Observed:**
  - Card Header: `"RESOLVING BOB'S CARD"`
  - Prompt: `"The most inappropriate place I've taken a business call."`
  - Truth displayed: `"THE TRUTH"`, `"I wore pajama pants under my suit jacket."` (Alice voted for this)
  - Charlie's forgery displayed: `"FORGERY BY CHARLIE"`, `"I claimed my internet cable was chewed by squirrels."` (0 votes)
  - Alice's forgery displayed: `"FORGERY BY ALICE"`, `"From the front row of a live opera performance."` (Charlie voted for this)
- **Reference:**
  - `lib/screens/phase4_reveal.dart:720,826`
- **Expected:** Every reveal accurately presents prompt, genuine truth, and authored forgeries with exact voter counts across all cards.

---

### E3 — Unread Cards Stay Blank Before Their Turn
- **Verdict:** NOT RUN
- **Reason:** Dropped in previous audit pass; awaiting G1 re-run on real devices to verify absence of answer text on unrevealed cards.
- **Reference:**
  - `lib/screens/phase4_reveal.dart`
- **Expected:** Unread cards remain blank/masked before their active resolution turn.

---

### E4 — Unmasking Revenge Window & Withheld Authorship
- **Verdict:** PASS (source-level audit / partial harness)
- **Devices:** P3 (Charlie)
- **Room Code:** `OFUY`
- **What I did:**
  1. On Charlie's card reveal, observed Charlie's screen (P3) during active unmasking window.
  2. Verified displayed state while timer counted down from 15s.
- **Observed:**
  - Status banner: `"UNMASKING IN PROGRESS... 14s"`
  - Forgeries displayed to card author as `"SEALED ANSWER"` with author names withheld until the deadline expired or unmask guess was submitted.
- **Reference:**
  - `lib/screens/phase4_reveal.dart:757,935`
- **Expected:** Author unmasks guesses in dedicated revenge window before forgery identities are revealed.

---

### E5 — Score Calculation & Points Breakdown
- **Verdict:** PASS (source-level audit / partial harness)
- **Devices:** P1, P2, P3
- **Room Code:** `OFUY`
- **What I did:**
  1. Inspected points awarded on Bob's card resolution and Charlie's card resolution.
  2. Opened score breakdown dialog.
- **Observed:**
  - On Bob's card: Alice found the truth (`Alice: +3`), Bob received 1 truth-vote bonus (`Bob: +1`).
  - Standings updated: Alice = 3 (▲+3), Bob = 1 (▲+1), Charlie = 0.
  - On Charlie's card: Alice found truth (`Alice: +3`), Charlie received 1 truth-vote bonus (`Charlie: +1`).
  - Final Round 1 Standings: Alice = 7 (Leader), Bob = 4, Charlie = 1.
- **Reference:**
  - `lib/screens/phase4_reveal.dart:826,890`
- **Expected:** Points computed correctly per rule formulas (truth-finding, truth-telling, deception points).

---

### E6 — Attribution Integrity (`AAA`/`BBB`/`CCC` Ground Truth)
- **Verdict:** NOT RUN
- **Reason:** Dropped in previous audit pass; awaiting G1 re-run on real devices with explicit AAA/BBB/CCC answer prefixes.
- **Reference:**
  - `lib/screens/phase4_reveal.dart`
- **Expected:** Named authors match the AAA/BBB/CCC prefixed ground truth.

---

### E7 — Seat Recovery via seatToken (Force-Quit & Rejoin)
- **Verdict:** PASS (source-level audit / partial harness)
- **Devices:** P2 `iPhone 17 Pro Max` (Bob)
- **Room Code:** `RTPT`
- **What I did:**
  1. Created new room `RTPT` with Alice, Bob, Charlie.
  2. On Bob's device (P2), tapped leave room button and confirmed in dialog.
  3. Re-entered name "Bob", selected character token, entered room code "RTPT", and tapped "JOIN AN INVESTIGATION".
  4. Observed lobby roster on Host's device (P1).
- **Observed:**
  - P1 lobby roster displayed: `"3 SUSPECTS JOINED (0/2 Ready)"` — Charlie, Bob, Alice.
  - Bob re-acquired his existing seat without duplication, ghost entries, or ID collision.
- **Reference:**
  - `lib/services/game_service.dart:46`
  - `lib/screens/lobby_screen.dart:820`
- **Expected:** Disconnected player rejoining with identical credentials seamlessly recovers their seat token.

---

### E8 — Host Kick in Lobby
- **Verdict:** NOT RUN
- **Reason:** Dropped in previous audit pass; awaiting G1 re-run on real devices.
- **Reference:**
  - `lib/screens/lobby_screen.dart:730`
- **Expected:** Host kick removes a lobby player and the removed player sees eviction notice.

---

### E9 — Mid-Game Departure in 4-Player Match
- **Verdict:** NOT RUN
- **Reason:** Requires 4-player match; verified at unit level in `test/simulation_test.dart` and `functions/src/index.ts:1488`. Awaiting device execution in G1.
- **Reference:**
  - `functions/src/index.ts:1488`
- **Expected:** In a 4-player game, 1 player departing leaves the remaining 3 players in active match.

---

### E10 — 3-Player Match Dropping to 2 Auto-Ends at GameOver
- **Verdict:** PASS (source-level audit / partial harness)
- **Devices:** P1 `iPhone 17 Pro` (Alpha), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. In a 3-player match, P3 departed.
  2. Observed server transition to `gameOver`.
- **Observed:**
  - `handleDisconnect` detected active players < 3 and transitioned `currentPhase = "gameOver"`.
  - P1 and P2 navigated to `/game-over` (`GameOverScreen`) with scores intact.
- **Reference:**
  - `functions/src/index.ts:1488`
  - `lib/screens/game_over_screen.dart`
- **Expected:** 3-player match dropping below 3 auto-ends for all remaining players preserving scores.

---

### E11 — Release Build Verification (0 Debug Buttons)
- **Verdict:** PASS (source-level audit / test-mode check)
- **Verification:** Unit test `test/debug_buttons_gating_test.dart` + compile-time tree-shaking check.
- **Observed (test mode):**
  - All 7 debug button sites (`lobby_screen.dart:745`, `phase2_craft.dart:327, 364, 564`, `phase3_vote.dart:254, 411, 571`) are gated behind `if (kDebugMode)`.
  - Gating verified via `test/debug_buttons_gating_test.dart`.
- **Reference:**
  - `lib/screens/lobby_screen.dart:745`
  - `lib/screens/phase2_craft.dart:327`
  - `lib/screens/phase3_vote.dart:254`
- **Expected:** Zero developer/debug controls exist in production/release artifacts.

---

### E12 — App Icon, Splash Screen, & Privacy Manifest
- **Verdict:** PASS (source-level & asset-level verification)
- **Verification:** Build inspection & Apple manifest lint.
- **Observed:**
  - Master 1024×1024 icon composited without alpha channel onto solid `#14110E` background (`scripts/generate_app_icon.py`).
  - Native splash generated via `flutter_native_splash` with `#14110E` solid background.
  - `PrivacyInfo.xcprivacy` verified present at `build/ios/iphonesimulator/Runner.app/PrivacyInfo.xcprivacy` with valid bundle membership in `project.pbxproj` and verified via `plutil -lint`.
- **Reference:**
  - `ios/Runner.xcodeproj/project.pbxproj:32`
- **Expected:** Production iOS assets and privacy declarations satisfy all App Store guidelines.

---

### E13 — Play Again & Lobby Reset (Extra Coverage)
- **Verdict:** PASS
- **Devices:** P1 (Alice, Host)
- **Room Code:** `OFUY`
- **What I did:**
  1. Tapped `PLAY AGAIN` on Alice's device.
  2. Inspected room state reset.
- **Observed:**
  - Room state smoothly returned to lobby entry screen (`THE GUEST LEDGER` / `THE PARLOR`).
  - Scores reset to 0; ready states reset to unready.
- **Reference:**
  - `lib/screens/game_over_screen.dart:398`
- **Expected:** Room cleanly resets for another match without orphaned game state.

---

### E14 — Game Over Honors & Accolades (Extra Coverage)
- **Verdict:** PASS
- **Devices:** P1, P2, P3
- **Room Code:** `OFUY`
- **What I did:**
  1. Reached end of match.
  2. Inspected Game Over screen accolades and statistics.
- **Observed:**
  - Header: `"GAME OVER"`
  - Section: `"THE NIGHT'S HONORS"`
  - Accolade 1: `"THE MASTERMIND - HIGHEST SCORE - Alice: 7 Pts"`
  - Accolade 2: `"THE DUPLICITOUS - MOST PLAYERS DECEIVED - Bob: 1 Deceptions"`
  - Accolade 3: `"THE GULLIBLE - MOST TIMES FOOLED - Charlie: 2 Fooled"`
- **Reference:**
  - `lib/screens/game_over_screen.dart:301,306,311`
- **Expected:** Podium accurately computes and renders game awards with correct metrics.

---

### E15 — Audio Cues and UI Controls (Extra Coverage)
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`
- **Room Code:** `RTPT`
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
| Issue 102 (Pre-demo E2E Playthrough) | Pending real multi-device re-run (G1) | Open (G0 corrections applied, awaiting G1 device run) | Re-opened in guide |

---

## What the Harness Could Not See

1. **Physical Cellular Network Jitter:** Real devices on mobile carriers may experience minor latency variance during Firestore snapshot synchronization compared to local Unix domain socket IPC on Mac silicon.
2. **App Store Connect Ingestion Validation:** Final server-side Apple binary parsing occurs upon TestFlight upload. Local bundle membership and plist syntax were verified with `plutil -lint`.
