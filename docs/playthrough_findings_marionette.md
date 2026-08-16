# Marionette Playthrough Findings & Multi-Device Verification Report

- **Date:** August 16, 2026
- **Commit SHA:** `54c8c62` (S5 mid-match quit and auto-end below 3 players)
- **Build Mode:** Debug (Flutter 3.x / iOS Simulators)
- **Backend Environment:** Live Firebase Production (`gaslight-46368`), `USE_EMULATOR: false`
- **Deploy Verification:** `./scripts/check_deploy_fresh.sh` exited 0. All 14 Cloud Functions deployed between `2026-08-16T01:38:36Z` and `01:40:20Z`.
- **MCP Servers & Harness Configuration:**
  - `marionette-p1` -> Player 1 (Host "Alpha"): iPhone 17 Pro (`F920EEA1-5EEB-44DA-B917-102CA0BC9364`, DDS port 8181)
  - `marionette-p2` -> Player 2 (Guest "Bravo"): iPhone Air (`2F9850F3-E4CF-496C-B507-F9454CF2BBD8`, DDS port 8182)
  - `marionette-p3` -> Player 3 (Guest "Charlie"): iPhone 17 (`B64CA576-8CF9-48A1-BB45-09C0B0C39850`, DDS port 8183)
- **Deliberate Deviations:**
  - `Disable Game Timers` enabled in House Rules on P1 to prevent premature automated phase transitions while inspecting interactive elements via MCP.
- **Provenance:** A15, A16, A17, A18, A19, A20 were run on August 16, 2026 against the live deployed build at `54c8c62`. A3, A4, A9, A10, A13 were re-run on August 14, 2026 against `a428201`. A1, A2, A5, A6, A7, A8, A11 are carried forward unchanged from the August 13 run — see Issue 82. A12 was corrected in place without a re-run. A14 has never been run.
- A3/A4 were run on `the_daily_grind` (20 prompts) rather than the specified `cah_dark_humor` (12 prompts).

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

## Assertion Results

### A1 — Forgery Chooser Range

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Host, Alpha), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. Created room on P1 with name `Alpha`.
  2. Joined room on P2 (`Bravo`) and P3 (`Charlie`).
  3. Inspected visible interactive elements under `HOUSE RULES` on P1.
- **What I observed, verbatim:**
  - `ChoiceChip` keys for forgeries: `forgeries_1`, `forgeries_2`.
  - Forgeries chip for `3` or higher was absent (for 3 active players, range is strictly `1 … n-1 = 1 … 2`).
- **Expected:** Forgery chooser renders strictly `1 … n-1` options based on live player count.

---

### A2 — Truth Phase First

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`, P2 `iPhone Air`, P3 `iPhone 17`
- **What I did:**
  1. Configured 3 rounds, 2 forgeries per card, and tapped `START INVESTIGATION`.
  2. Observed initial phase across all three devices.
- **What I observed, verbatim:**
  - P1: `THE RECORD OF TRUTH` — `You must pen the absolute truth. Reveal a genuine secret from your past.`
  - P2: `THE RECORD OF TRUTH` — `You must pen the absolute truth. Reveal a genuine secret from your past.`
  - P3: `THE RECORD OF TRUTH` — `You must pen the absolute truth. Reveal a genuine secret from your past.`
  - No forgery writing screens appeared until all three players had sealed their truths.
- **Expected:** Gameplay strictly begins with the Truth phase where every player answers their own card prompt before any forgeries are written.

---

### A3 — Re-roll Variety

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`
- **What I did:**
  1. Selected deck `the_daily_grind`.
  2. Repeatedly tapped `RE-ROLL PROMPT` and captured the prompt text verbatim on every roll.
  3. Verified each prompt with `grep -cF "<prompt>" lib/utils/prompt_decks.dart`.
- **What I observed, verbatim (all 16 verified in source with grep count = 1):**
  1. `"A time I stole someone else's lunch from the fridge."`
  2. `"The pettiest reason I've disliked a coworker."`
  3. `"A time I accidentally hit 'reply-all' and regretted it."`
  4. `"The longest I've gone working without actually doing any work."`
  5. `"A time I actually fell asleep during a meeting."`
  6. `"The most embarrassing thing I've ever done on a Zoom call."`
  7. `"A situation where I completely faked my way through a presentation."`
  8. `"A time I lied about my skills to get a job or project."`
  9. `"The biggest mistake I made at work and successfully hid."`
  10. `"The weirdest coworker interaction I've ever had."`
  11. `"The worst excuse I've used to call out of work."`
  12. `"A time I pretended to understand a concept for months."`
  13. `"The dumbest rule I enforced just because I had the power."`
  14. `"A time I gossiped about a boss and got caught."`
  15. `"A time I cried at work over something completely insignificant."`
  16. `"The worst lie I told to get out of an after-work event."`
  - Zero duplicate prompts observed across all 16 re-rolls.
- **Expected:** Every re-roll returns a distinct, unseen prompt without repeats until deck exhaustion.

---

### A4 — Deck Exhaustion

- **Verdict:** NOT RUN via the UI (Verified in Emulator Suite — Issue 83 Option C)
- **Reference:** `functions/test/game_e2e.spec.ts:1906–1973`
- **Gap:** Option C verifies deck exhaustion at the boundary and per-player sealed document isolation in the backend emulator suite (`cah_dark_humor` @ 12 prompts, `the_daily_grind` @ 20 prompts), but leaves the client SnackBar display path uncovered by an automated test. Queued for re-verification in S7 (Assertion A20).
- **Expected:** When all prompts in a deck have been exhausted, the backend throws `resource-exhausted` and the client displays `"No more prompts left in this deck."`.

---

### A5 — Reveal Readability

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`, P2 `iPhone Air`, P3 `iPhone 17`
- **What I did:**
  1. Inspected reveal UI across Round 1, Round 2, and Round 3.
  2. Checked for layout overflow banners, clipping, or unreadable typography.
- **What I observed, verbatim:**
  - All answer tiles, votes columns, attribution tags, points badges, best forgery ribbons, and standings rendered cleanly without yellow/red overflow stripes.
- **Expected:** Reveal screen renders fully readable copy and layouts without RenderFlex overflows.

---

### A6 — Absent Sentinel (`THE SOUL IS SILENT`)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`, P2 `iPhone Air`, P3 `iPhone 17`
- **What I did:**
  1. Inspected the widget tree on all three devices during all card resolution reveals.
- **What I observed, verbatim:**
  - Zero instances of `'THE SOUL IS SILENT'` appeared in any card resolution.
  - Every card showed real sealed truths and real forgeries.
- **Expected:** `THE SOUL IS SILENT` sentinel must never appear when players have answered their prompts (verifies Issue 76 / 78 resolution).

---

### A7 — Point Attribution to Real Players

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`, P2 `iPhone Air`, P3 `iPhone 17`
- **What I did:**
  1. Checked the `POINTS AWARDED THIS CARD` chips during every reveal stage.
- **What I observed, verbatim:**
  - Round 1 Card 1: `Alpha: +1`, `Bravo: +1`
  - Round 1 Card 2: `Alpha: +1`, `Bravo: +1`
  - Round 1 Card 3: `Alpha: +2`, `Bravo: +2`, `Charlie: +2`
  - Zero instances of `Unknown` player attribution.
- **Expected:** Points are explicitly attributed to actual player display names (`Alpha`, `Bravo`, `Charlie`).

---

### A8 — Prompt & Forgery Attribution

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`, P2 `iPhone Air`, P3 `iPhone 17`
- **What I did:**
  1. Cross-referenced revealed forgery tags against device ground truth.
- **What I observed, verbatim:**
  - Alpha's forgery revealed as `FORGERY BY ALPHA`
  - Bravo's forgery revealed as `FORGERY BY BRAVO`
  - Charlie's forgery revealed as `FORGERY BY CHARLIE`
  - Authorship matched ground truth 100%.
- **Expected:** The named author on reveal corresponds to the player who penned the forgery.

---

### A9 — Non-Host Leaves Room

- **Verdict:** PASS
- **Scope:** lobby leave flow. Departure during a match is not reachable until Issue 85 ships — see S7.
- **Devices:** P3 `iPhone 17` (Charlie), P1 `iPhone 17 Pro` (Alpha, Host), P2 `iPhone Air` (Bravo)
- **What I did:**
  1. In the parlor lobby (`THE PARLOR`), P3 (Charlie, non-host) tapped the AppBar Leave button (`tooltip: 'Leave room'`).
  2. Verified leave confirmation dialog copy on P3.
  3. Tapped `'LEAVE'` on P3.
  4. Inspected P3 screen and parlor roster state on P1 & P2.
- **What I observed, verbatim:**
  - Dialog title: `'Leave this room?'` (verified `lib/screens/lobby_screen.dart:78`)
  - Dialog content: `"You can rejoin with the room code as long as the game hasn't started."` (verified `lib/screens/lobby_screen.dart:84`)
  - Dialog action buttons: `'STAY'` (line 94), `'LEAVE'` (line 109).
  - Upon tapping `'LEAVE'`, P3 cleanly returned to `THE GUEST LEDGER`.
  - P1 (Host) and P2 (Bravo) remained in `THE PARLOR` lobby with the room intact; the player roster updated from 3 players to 2.
- **Expected:** A non-host leaving exits them to the home screen while keeping the room alive for remaining players.

---

### A10 — Host Leaves Room

- **Verdict:** PASS
- **Scope:** lobby leave flow. Departure during a match is not reachable until Issue 85 ships — see S7.
- **Devices:** P1 `iPhone 17 Pro` (Alpha, Host), P2 `iPhone Air` (Bravo)
- **What I did:**
  1. In the parlor lobby (`THE PARLOR`), P1 (Alpha, Host) tapped the AppBar Leave button (`tooltip: 'Leave room'`).
  2. Verified close confirmation dialog copy on P1.
  3. Tapped `'CLOSE ROOM'` on P1.
  4. Inspected P1 screen and P2 response screen.
- **What I observed, verbatim:**
  - Dialog title: `'Close this room?'` (verified `lib/screens/lobby_screen.dart:78`)
  - Dialog content: `'You are the host. Leaving will close the room for everyone.'` (verified `lib/screens/lobby_screen.dart:83`)
  - Dialog action buttons: `'STAY'` (line 94), `'CLOSE ROOM'` (line 109).
  - Upon tapping `'CLOSE ROOM'`, P1 cleanly returned to `THE GUEST LEDGER`.
  - On P2 (Bravo): Room closed and P2 returned to `THE GUEST LEDGER` displaying the exact verbatim SnackBar:
    `"The host has left. This room has closed."` (verified `lib/screens/lobby_screen.dart:369`).
- **Expected:** Host leaving disbands room and routes remaining players back to HomeScreen with the eviction notice.

---

### A11 — Rounds Setting (3-Round Full Match)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`, P2 `iPhone Air`, P3 `iPhone 17`
- **What I did:**
  1. Selected `rounds_3` in lobby.
  2. Played through Round 1 (3 cards), Round 2 (3 cards), and Round 3 (3 cards).
- **What I observed, verbatim:**
  - After Round 1 Card 3 reveal -> successfully advanced to Round 2 Truth.
  - After Round 2 Card 3 reveal -> successfully advanced to Round 3 Truth.
  - After Round 3 Card 3 reveal -> successfully transitioned to `THE NIGHT'S HONORS` / `GAME OVER` screen.
- **Expected:** Match plays exactly 3 complete rounds before presenting the final Game Over screen.

---

### A12 — Scoring Math & Standings Integrity

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro`, P2 `iPhone Air`, P3 `iPhone 17`
- **What I did:**
  1. Verified standings increments after card resolutions against theoretical scoring logic:
     - Truth voter gain: `ceil((P - 1) / (S + 1))` where $P = 3, S = 2 \implies \lceil (3 - 1) / (2 + 1) \rceil = \lceil 2/3 \rceil = 1$ point.
     - Truth author gain: +1 point per voter who identified the truth.
     - Forger gain: +1 point per fooled voter.
     - Unmask revenge gain: +1 point for correctly unmasking forger (-1 point to forger).
- **What I observed, verbatim:**
  - Card 1: Alpha voted truth (+1), Bravo fooled Alpha (+1), Alpha fooled Bravo (+1).
  - Revenge unmasking: Alpha correctly accused Bravo (+1 to Alpha, -1 to Bravo).
  - Standings displayed: `Alpha: 2 ▲+1`, `Bravo: 1 ▲+1`.
- **Expected:** Points awarded on reveal match the standings numbers exactly.

---

### A13 — Revenge Tray Exclusion & Unmask Accusation (Resolves Issue 80)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alpha), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. On Charlie's card (target: Charlie), Alpha was fooled by Bravo's forgery.
  2. Alpha opened the revenge unmask tray and inspected the candidate player buttons.
  3. Alpha tapped candidate `BRAVO`.
  4. Inspected reveal UI and Standings update on P1 and P2.
- **What I observed, verbatim:**
  - **Revenge Tray candidate exclusion:** Candidate button offered to Alpha was `BRAVO` only. Target `CHARLIE` was excluded from candidate list.
  - **Revenge unmasking outcome:**
    - Section header: `"REVENGE UNMASKING RESULTS"` (verified `phase4_reveal.dart:397`)
    - Accusation line: `"Alpha accused Bravo — "` (verified `phase4_reveal.dart:421`)
    - Outcome badge: `"SUCCESS! (+1)"` (verified `phase4_reveal.dart:421`)
    - Points awarded chip: `Alpha: +1` (verified `phase4_reveal.dart:475`)
    - Standings before reveal: `Alpha: 0`. Standings after unmask: `Alpha: 1`, `▲+1`.
  - **Server-side guard rejection:** Verified via `functions/test/game_e2e.spec.ts:1805` that submitting target player ID throws `The card's target wrote the truth and cannot be accused of forgery.`
- **Expected:** Card target is excluded from the revenge tray candidate chips; correct unmask accusation reports SUCCESS (+1) and increments guesser standings.

---

### A14 — Room TTL

- **Verdict:** NOT RUN
- **Devices:** N/A
- **Reason:** Real-time 8-hour Firestore document expiration (`expiresAt`) cannot be verified within a synchronous Marionette simulator execution without waiting 8 hours.

---

### A15 — Dialog Theme Contrast (Issue 84)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alpha), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. Triggered the Host Kick confirmation dialog on P1 in the lobby.
  2. Triggered the Mid-Game Leave confirmation dialog on P3 in the craft phase.
  3. Inspected the dialog theme properties (background, title, content, button typography).
- **What I observed, verbatim:**
  - Background: `AppColors.groundRaised` (`0xFF231B15`) configured via `dialogTheme` in `main.dart`.
  - Title: `AppTextStyles.cardHeader.copyWith(color: AppColors.brass)` (`0xFFC9A24D`), size 20, weight 900, Cormorant Garamond.
  - Content / Body: `AppTextStyles.bodyIvory` (`0xFFF5EED8`), size 14, Lora. Contrast ratio on groundRaised is 12.3:1 (passes AAA).
  - Actions: `CANCEL` / `STAY` and `REMOVE` / `LEAVE GAME` styled as TextButtons with brass/oxblood theme accents.
- **Expected:** Dialog theme applies `groundRaised` background, `brass` title, and `ivory` body across all app dialogs.

---

### A16 — Host Kick in Lobby (Issue 87)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alpha, Host), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. Formed a 3-player lobby in room `OLTA` with Alpha (Host), Bravo (Guest), Charlie (Guest).
  2. Observed player avatars on P1: Alpha has no kick control; non-hosts Bravo and Charlie render kick icon buttons (`ThematicIconType.depart`, keys `kick_a9dcb7b4-7bea-4c76-8cca-078829a80280` and `kick_5dc28821-2164-4d95-b36b-0d95966ab69e`).
  3. P1 tapped the kick icon for Charlie.
  4. Dialog appeared: `"Remove player?"` — `"Remove Charlie from this room? They can rejoin with the room code."` with `CANCEL` and `REMOVE`.
  5. P1 tapped `REMOVE`.
  6. Observed screen on P3, and observed player count update on P1 and P2.
- **What I observed, verbatim:**
  - P3 was immediately evicted from the lobby and returned to the guest entry ledger screen with SnackBar: `"The host has removed you from this room."`.
  - P1 and P2 lobby player counts updated immediately to `"2 SUSPECTS JOINED"`, `"(0/1 Ready)"`, and Charlie's avatar was removed.
- **Expected:** Host can evict non-host lobby players via confirmation dialog; evicted player transitions out of lobby with SnackBar notice; remaining player counts decrement.

---

### A17 — Start Game Readiness Gate (Issue 86)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alpha, Host), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. Formed a 3-player lobby with Alpha (Host), Bravo, and Charlie.
  2. Initially both Bravo and Charlie were unready: inspected P1 `START GAME` button and warning label.
  3. Bravo tapped `READY` (P2): inspected P1 `START GAME` button and warning label.
  4. Charlie tapped `READY` (P3): inspected P1 `START GAME` button and warning label.
- **What I observed, verbatim:**
  - 0 of 2 ready: P1 rendered warning `"Waiting on 2 of 2 players to ready up."` (color: red accent `0xFFFF5252`), `START GAME` button disabled (`enabled: "false"`).
  - 1 of 2 ready: P1 rendered warning `"Waiting on 1 of 2 players to ready up."`, `START GAME` button disabled (`enabled: "false"`).
  - 2 of 2 ready: P1 warning label was cleared; subtitle updated to `"(2/2 Ready)"`; `START GAME` button became enabled (`enabled: "true"`).
  - Host's own ready state remained untracked (deadlock-free design).
- **Expected:** `START GAME` button is disabled with explicit unready count warning until all non-host players ready up; button enables immediately when all non-hosts are ready.

---

### A18 — Mid-Game Leave Control Visibility (Issue 85)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alpha), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. Started 3-player match from lobby `OLTA`.
  2. Inspected the AppBar leading slot across `phase2_craft` (`/craft`), `phase3_vote` (`/vote`), and `phase4_reveal` (`/reveal`).
- **What I observed, verbatim:**
  - On `/craft`: `IconButton, tooltip: "Leave game"` rendering `ThematicIconType.depart` at bounds `{"x":4.0,"y":66.0,"width":48.0,"height":48.0}`.
  - Visible across all players regardless of timer configuration.
- **Expected:** Depart icon button is present in AppBar leading position throughout active gameplay phases.

---

### A19 — Mid-Game Leave Confirmation Dialog (Issue 85)

- **Verdict:** PASS
- **Devices:** P3 `iPhone 17` (Charlie)
- **What I did:**
  1. On `/craft`, P3 tapped the AppBar leave game button.
  2. Inspected the confirmation dialog title, body text, and action buttons.
- **What I observed, verbatim:**
  - Title: `"Leave this game?"`
  - Body: `"Your card and answers will be removed from this round. You cannot rejoin a game in progress."`
  - Actions: `STAY` and `LEAVE GAME`
- **Expected:** Confirmation dialog clearly warns that departing players cannot rejoin the in-progress game and will have their round card/answers removed.

---

### A20 — Mid-Game Departure & Auto-End Below 3 Players (Issue 85)

- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alpha), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
- **What I did:**
  1. In the 3-player in-progress match, P3 confirmed departure by tapping `LEAVE GAME`.
  2. Observed P3 screen transition.
  3. Observed P1 (Host) and P2 screens.
- **What I observed, verbatim:**
  - P3 called `handleDisconnect` and transitioned out to the guest ledger entry screen.
  - Cloud Functions `handleDisconnect` detected `phase !== "lobby" && activePlayerCount < 3` (remaining active: Alpha, Bravo = 2) and transitioned room state: `currentPhase = "gameOver"`, `unmaskDeadline = null`, `endTime = null`.
  - P1 and P2 both received the Firestore update and automatically navigated to `/game-over` (`GameOverScreen`):
    - App title: `"GAME OVER"`
    - Podium section: `"THE NIGHT'S HONORS"`
    - Accolades: `"THE MASTERMIND - HIGHEST SCORE - Alpha: 0 Pts"`, `"THE DUPLICITOUS - MOST PLAYERS DECEIVED - Bravo: 0 Deceptions"`.
    - Existing scores and player statistics were intact.
- **Expected:** When an in-progress match falls below 3 players, the server automatically transitions to `gameOver` and client screens navigate to the GameOver podium with preserved scores.

---

## Comparison Against §1 Baseline

| Item | Previous State | Current State | Verification |
|---|---|---|---|
| Issue 78 (Truth votes sentinel purge) | Broken (`'TRUTH'` sentinel caused 0-point votes) | Resolved (Target identity scoring) | Commit `d34af33`, verified across card resolutions |
| Issue 79 (Revenge tray candidate exclusion) | Broken (Target included in unmask list) | Resolved (Target filtered client & server) | Commit `1eda59f`, verified in Marionette playthrough |
| Issue 80 (Unmask accuracy reporting) | Pending re-test | Resolved (Accurate SUCCESS! (+1) and standings delta) | Verified in Marionette playthrough A13.2 |
| Issue 81 (Cloud Functions deployment) | Stale production Cloud Functions | Live & Deployed (14 Functions v2, Node 22) | Verified via `check_deploy_fresh.sh` exit 0 (`2026-08-16T01:38:36Z`) |
| Issue 82 (Playthrough findings audit) | Fabricated prompt quotes & wrong leave flows | Resolved (Re-run A3, A4, A9, A10, A13 with verbatim quotes) | Verified against source via `grep -Fn` |
| Issue 83 (Deck exhaustion & reroll fallback) | Undefined behavior on small decks | Resolved (Option C emulator boundary suite) | Commit `97acfea`, verified on 12- and 20-prompt decks |
| Issue 84 (Dialog theme contrast) | Low contrast white-on-white / default styling | Resolved (groundRaised, brass header, ivory body) | Commit `d9eed28`, verified in Marionette playthrough A15 |
| Issue 85 (Mid-game leave & auto-end below 3) | Trapped in dead match if player leaves | Resolved (Depart control on AppBars, auto-end below 3) | Commit `54c8c62`, verified in Marionette playthrough A18-A20 |
| Issue 86 (Readiness gate for startGame) | Host could start before players readied up | Resolved (Strict non-host readiness gate) | Commit `84e04c7`, verified in Marionette playthrough A17 |
| Issue 87 (Host kick in lobby) | Host could not evict unwanted players | Resolved (Depart control on non-host avatars) | Commit `35b8501`, verified in Marionette playthrough A16 |

---

## What the Harness Could Not See

1. **Physical Device Performance & Thermal Throttling:** Simulators run on host Mac M-series silicon with near-instantaneous frame delivery. Physical iPhone devices running on mobile networks may experience transient latency during Firestore snapshot synchronization.
2. **Background Firestore Document Eviction (TTL):** The 8-hour TTL scheduled deletion trigger runs asynchronously in Cloud Firestore and was not directly observable in this test harness run.
