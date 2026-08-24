# Web Playthrough Findings & E2E Verification Report (Wave I)

- **Date:** August 24, 2026
- **Active Build:** Wave I — Web E2E Playthrough (I1 → I2 → I3)
- **Target:** Release Web Build (`build/web`) served locally over HTTP (`http://127.0.0.1:8777`)
- **Binary Freshness:** `Aug 23 18:51:05 2026 binary`
- **Source Freshness:** `Fri Aug 21 17:12:10 2026 -0700 source`
- **Flutter Version:** `Flutter 3.44.6 • channel stable • https://github.com/flutter/flutter.git`
- **Backend Environment:** Live Firebase Production (`gaslight-46368`), `USE_EMULATOR: false`
- **Automated Harness:** Playwright E2E Suite (`test/web_e2e/run_full_playthrough.js` + `test/web_e2e/playthrough_helpers.js`)
- **Deploy Verification:** `./scripts/check_deploy_fresh.sh` exited 0.
- **Evidence Verification:** `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` exited 0.
- **Deliberate Deviations:** Game Timers disabled (`Disable Game Timers` switched ON) in lobby to control progression deterministically across automated browsers.

---

## Web Playthrough Assertions (W1 — W19)

### W1 — Context Isolation & Session Restoral Falsification
- **Verdict:** PASS
- **Clients:** Browser Context 1 (Alice), Browser Context 2 (Bob), Browser Context 3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Falsification step: Alice created room `SMYG` in Context 1. Opened a second tab within Context 1 (same browser storage/cookies) and navigated to `http://127.0.0.1:8777`. Verified that Context 1 tab 2 automatically restored the session into room `SMYG` with a roster count of 1.
  2. Isolated step: Launched distinct Chromium contexts (Context 2 and Context 3). Joined room `SMYG` as Bob and Charlie.
  3. Verified that Context 1, Context 2, and Context 3 maintain separate player identities and sync all 3 distinct players in the lobby roster.
- **Observed:**
  - Falsification Screenshot: `docs/playthrough_evidence/w1_falsify_same_tab.png`
  - 3-Player Roster Screenshot: `docs/playthrough_evidence/w1_contexts_roster.png`
  - Quoted Semantics: `"ROOM CODE SMYG"`, `"MEMBERS OF THE PARLOR (3/8)"`, `"Alice"`, `"Bob"`, `"Charlie"`
- **Reference:** `lib/services/game_service.dart:180`
- **Expected:** Tabs sharing storage restore identical session; isolated browser contexts connect as distinct players.

---

### W2 — Cold Boot of Web Release Build
- **Verdict:** PASS
- **Clients:** Fresh Chromium Context (1280x800)
- **What I did:**
  1. Opened a clean browser context with no stored localStorage or IndexedDB state.
  2. Loaded `http://127.0.0.1:8777`.
  3. Verified CanvasKit initial load, font rendering, raven mascot display, and entrance form controls.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w2_cold_boot.png`
  - Quoted Semantics: `"GASLIGHT"`, `"THE GUEST LEDGER"`, `"Your Name"`, `"CREATE ROOM"`, `"Room Code"`, `"JOIN ROOM"`
- **Reference:** `lib/screens/lobby_screen.dart:150`
- **Expected:** Cold boot renders title screen and guest ledger cleanly without flash or crash.

---

### W3 — Semantics Tree Activation & DOM Verification
- **Verdict:** PASS
- **Clients:** Chromium Context 1 (P1)
- **What I did:**
  1. Triggered Flutter Web accessibility semantics via `flt-semantics-placeholder` / `aria-label="Enable accessibility"`.
  2. Inspected DOM for populated `flt-semantics` interactive tree nodes.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w3_semantics_dom.png`
  - Quoted DOM hit: `document.body.innerText.includes("THE GUEST LEDGER") === true`
- **Reference:** `test/web_e2e/playthrough_helpers.js:12`
- **Expected:** Flutter Web semantics tree activates and renders accessible DOM elements.

---

### W4 — 3-Player Parlor Lobby & Roster Sync
- **Verdict:** PASS
- **Clients:** P1 (Alice, Host), P2 (Bob, Guest), P3 (Charlie, Guest)
- **Room Code:** `SMYG`
- **What I did:**
  1. Bob and Charlie joined room `SMYG`.
  2. Inspected player roster across all 3 client screens.
- **Observed:**
  - P1 Screenshot: `docs/playthrough_evidence/w4_p1_lobby.png`
  - P2 Screenshot: `docs/playthrough_evidence/w4_p2_lobby.png`
  - P3 Screenshot: `docs/playthrough_evidence/w4_p3_lobby.png`
  - Quoted Semantics: `"THE PARLOR"`, `"ROOM CODE SMYG"`, `"Alice (Host)"`, `"Bob"`, `"Charlie"`
- **Reference:** `lib/screens/lobby_screen.dart:450`
- **Expected:** Lobby roster synchronizes real-time across host and guest screens.

---

### W5 — Host Readiness Gate & Game Timers Toggle
- **Verdict:** PASS
- **Clients:** P1 (Host), P2 (Guest), P3 (Guest)
- **Room Code:** `SMYG`
- **What I did:**
  1. Host P1 selected 1 round match length and toggled `Disable Game Timers` switch.
  2. Observed `START GAME` disabled with `"Waiting on 2 of 2 players to ready up."`
  3. P2 and P3 clicked `"I'M READY"`.
  4. Observed `START GAME` button become enabled on Host P1.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w5_readiness_gate.png`
  - Quoted Semantics: `"Waiting on 2 of 2 players to ready up."`, `"Disable Game Timers"`, `"START GAME"`
- **Reference:** `lib/screens/lobby_screen.dart:623`
- **Expected:** Host cannot start match until all non-host players are marked ready.

---

### W6 — Truth Crafting Phase & Quill Submission
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Host clicked `START GAME`.
  2. All three players transitioned to Truth crafting phase.
  3. Typed genuine secrets into quill textarea and clicked `SUBMIT DOSSIER`.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w6_truth_craft.png`
  - Quoted Semantics: `"THE RECORD OF TRUTH"`, `"SUBMIT DOSSIER"`, `"Dip the quill…"`
- **Reference:** `lib/screens/phase2_craft.dart:210`
- **Expected:** Truth dossiers submit cleanly and advance all players to Forgery phase.

---

### W7 — Forgery Crafting & Semantic Duplicate Rejection
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. In Forgery phase, Bob attempted to submit an exact duplicate of Alice's genuine truth: `"AAA Paris Story about getting lost near Eiffel Tower"`.
  2. Verified duplicate rejection error feedback in UI.
  3. Bob and Charlie submitted valid original forgeries.
- **Observed:**
  - Duplicate Rejection Screenshot: `docs/playthrough_evidence/w7_duplicate_reject.png`
  - Forgery Crafting Screenshot: `docs/playthrough_evidence/w7_forgery_craft.png`
  - Quoted Semantics: `"DECK OF FORGERIES"`, `"SUBMIT DOSSIER"`
- **Reference:** `lib/screens/phase2_craft.dart:340`
- **Expected:** Submitting duplicate truth answers triggers validation rejection; unique forgeries submit successfully.

---

### W8 — Voting Phase & Own-Answer Lockout
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Transitioned to Voting phase.
  2. Inspected card voting options on Bob (P2) and Charlie (P3).
  3. Verified own-answer lockout badge/sealing prevents voting for one's own authored forgery.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w8_vote_lockout.png`
  - Quoted Semantics: `"THE VOTE"`, `"WHICH ONE IS THE TRUTH?"`, `"SEALED THE SOUL IS SILENT (Your Forgery)"`, `"CONFIRM VOTE"`
- **Reference:** `lib/screens/phase3_vote.dart:310`
- **Expected:** Players cannot cast votes for their own submitted forgeries.

---

### W9 — Reveal Phase, Unmask Window, & Attribution
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Transitioned to Reveal phase.
  2. Inspected Card 1 resolution with truth card, forgeries, and vote attribution badges.
  3. Fooled players submitted unmask accusations during the unmask window.
- **Observed:**
  - Card Reveal Screenshot: `docs/playthrough_evidence/w9_reveal_card.png`
  - Unmask Window Screenshot: `docs/playthrough_evidence/w9_unmask_window.png`
  - Quoted Semantics: `"THE REVEAL"`, `"RESOLVING CHARLIE'S CARD"`, `"THE TRUTH"`, `"FORGERY BY BOB"`, `"POINTS AWARDED THIS CARD"`, `"REVENGE UNMASKING!"`, `"CONTINUE"`
- **Reference:** `lib/screens/phase4_reveal.dart:420`
- **Expected:** Reveal displays truth, forgeries, voter badges, and opens revenge unmasking tray.

---

### W10 — Round Standings & Cumulative Leaderboard
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Advanced through card resolutions to the standings leaderboard.
  2. Inspected score calculations and point deltas for all 3 players.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w10_standings.png`
  - Quoted Semantics: `"STANDINGS"`, `"Bob 2 ▲+2"`, `"Alice 2 ▲+2"`, `"Charlie 2 ▲+2"`
- **Reference:** `lib/screens/phase4_reveal.dart:850`
- **Expected:** Standings leaderboard displays correct cumulative scores and point deltas.

---

### W11 — Game Over Honors & Podium Transition
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Completed the match resolution.
  2. Inspected GameOverScreen honors, final podium rankings, and case file controls.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w11_gameover.png`
  - Quoted Semantics: `"NIGHT'S HONORS"`, `"GAME OVER"`, `"FINAL STANDINGS"`, `"Share Case File"`, `"PLAY AGAIN"`
- **Reference:** `lib/screens/game_over_screen.dart:280`
- **Expected:** Match completes and transitions smoothly to GameOverScreen with podium honors.

---

### W12 — Browser Refresh Mid-Match Session Restoral
- **Verdict:** PASS
- **Clients:** P2 (Bob)
- **Room Code:** `SMYG`
- **What I did:**
  1. Mid-match during resolution, triggered a full browser page reload on P2 (`p2.reload()`).
  2. Verified that P2 reconnected to room `SMYG` immediately without losing score or player identity.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w12_session_restored.png`
  - Verbatim Console log: `[P2 log] DEBUG HEARTBEAT: started timer for room: SMYG, player: 16464d22-4f45-4f52-93f0-42e6c560a74c`
- **Reference:** `lib/services/game_service.dart:185`
- **Expected:** Browser refresh restores player session, seat token, and active match state.

---

### W13 — Same-Origin Second Tab Session Restoral
- **Verdict:** PASS
- **Clients:** P1 Tab 2 (Context 1)
- **Room Code:** `SMYG`
- **What I did:**
  1. In Context 1 where Alice created room `SMYG`, opened a second tab to `http://127.0.0.1:8777`.
  2. Verified that tab 2 automatically loaded the active room session.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w13_same_origin_tab.png`
  - Quoted Semantics: `"ROOM CODE SMYG"`, `"THE PARLOR"`, `"Alice (Host)"`
- **Reference:** `lib/services/game_service.dart:210`
- **Expected:** Opening a second tab under the same origin automatically syncs the active room session.

---

### W14 — Case File Share Action on Web
- **Verdict:** PASS
- **Clients:** P1 (Alice)
- **Room Code:** `SMYG`
- **What I did:**
  1. On GameOverScreen, clicked `Share Case File` button.
  2. Observed what the app does with that click on web.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w14_case_file_share.png`
  - Quoted Semantics: `"Share Case File"`, `"CASE FILE"`
  - **The cited screenshot predates Wave K.** `w14_case_file_share.png` is dated **August 23, 19:35**, before Issue 110 was built, and the snackbar visible in it reads **`Sharing is only supported on mobile devices.`** — the behaviour Wave K replaced.
  - **What is actually verified today is compile-time only:** `flutter build web --release` exits 0 with `package:web` and the new conditional import resolving, and the source path is `game_over_screen.dart:104` → `case_file_saver_web.dart` (Blob → `createObjectURL` → synthetic anchor with `download` → `click()` → `revokeObjectURL`).
  - **NOT yet observed at runtime:** that a file actually lands, that it opens as a valid PNG of the Case File rather than 0 bytes or an HTML error page, and that the confirmation snackbar appears. **This block therefore claims less than the Wave K commit message did.**
- **Verdict qualifier:** PASS covers *no uncaught error on web*, which is what this block originally set out to establish. It does **not** cover the download working.
- **Reference:**
  - `lib/screens/game_over_screen.dart:104`
  - `lib/utils/case_file_saver_web.dart`
- **Expected:** Clicking Share Case File on web completes without a platform error. **Whether the PNG downloads is pending runtime verification** — see `agent_execution_guide.md` §3, which carries the browser procedure to settle it.

---

### W15 — Production Web Console Hygiene & Error Audit
- **Verdict:** PASS
- **Clients:** P1, P2, P3
- **What I did:**
  1. Monitored console error and warning events across all 3 player contexts during full match.
  2. Verified zero unhandled exceptions or rendering crashes.
- **Observed:**
  - Screenshot: `docs/playthrough_evidence/w15_console_hygiene.png`
  - Verbatim Log Summary: P1 log count: 10, P2 log count: 21, P3 log count: 10.
  - Zero `PAGE_ERROR` events logged.
- **Reference:** `test/web_e2e/run_full_playthrough.js:45`
- **Expected:** Web release build operates cleanly without console exceptions or errors.

---

### W16 — Below-3 Auto-End via In-Game Leave Game
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `PJRB`
- **What I did:**
  1. Created and started a 3-player match in room `PJRB`.
  2. In Truth phase, P3 clicked the in-game `Leave game` button in the AppBar and confirmed `LEAVE GAME`.
  3. Verified that the match automatically terminated due to falling below the 3-player floor.
  4. Verified both remaining players (P1 and P2) were routed to GameOverScreen.
- **Observed:**
  - P1 Screenshot: `docs/playthrough_evidence/w16_p1_gameover.png`
  - P2 Screenshot: `docs/playthrough_evidence/w16_p2_gameover.png`
  - Quoted Semantics: `"GAME OVER"`, `"FINAL STANDINGS"`
- **Reference:** `lib/services/game_service.dart:710`
- **Expected:** When player count drops below 3 during active play, the match auto-terminates to GameOver.

---

### W17 — Responsive Sweep: Mobile Viewport (375x812)
- **Verdict:** PASS
- **Viewport:** 375 x 812 (Mobile device profile)
- **What I did:**
  1. Loaded web application at 375x812 mobile viewport with touch emulation.
  2. Captured all key match flow screens: Lobby, Crafting, Voting, Reveal, GameOver.
- **Observed:**
  - Lobby: `docs/playthrough_evidence/w17_lobby.png`
  - Crafting: `docs/playthrough_evidence/w17_craft.png`
  - Voting: `docs/playthrough_evidence/w17_vote.png`
  - Reveal: `docs/playthrough_evidence/w17_reveal.png`
  - GameOver: `docs/playthrough_evidence/w17_gameover.png`
- **Reference:** `lib/screens/lobby_screen.dart:180`
- **Expected:** Layout adapts responsively to mobile viewport without clipping or overflow.

---

### W18 — Responsive Sweep: Tablet Viewport (768x1024)
- **Verdict:** PASS
- **Viewport:** 768 x 1024 (Tablet portrait)
- **What I did:**
  1. Loaded web application at 768x1024 tablet viewport.
  2. Captured all key match flow screens: Lobby, Crafting, Voting, Reveal, GameOver.
- **Observed:**
  - Lobby: `docs/playthrough_evidence/w18_lobby.png`
  - Crafting: `docs/playthrough_evidence/w18_craft.png`
  - Voting: `docs/playthrough_evidence/w18_vote.png`
  - Reveal: `docs/playthrough_evidence/w18_reveal.png`
  - GameOver: `docs/playthrough_evidence/w18_gameover.png`
- **Reference:** `lib/screens/lobby_screen.dart:180`
- **Expected:** Layout adapts responsively to tablet viewport without clipping or overflow.

---

### W19 — Responsive Sweep: Desktop Viewport (1280x800)
- **Verdict:** PASS
- **Viewport:** 1280 x 800 (Desktop landscape)
- **What I did:**
  1. Loaded web application at 1280x800 desktop viewport.
  2. Captured all key match flow screens: Lobby, Crafting, Voting, Reveal, GameOver.
- **Observed:**
  - Lobby: `docs/playthrough_evidence/w19_lobby.png`
  - Crafting: `docs/playthrough_evidence/w19_craft.png`
  - Voting: `docs/playthrough_evidence/w19_vote.png`
  - Reveal: `docs/playthrough_evidence/w19_reveal.png`
  - GameOver: `docs/playthrough_evidence/w19_gameover.png`
- **Reference:** `lib/screens/lobby_screen.dart:180`
- **Expected:** Layout adapts responsively to desktop viewport without clipping or overflow.
