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
- **Evidence Verification:** `./scripts/check_playthrough_evidence.sh docs/playthroughs/findings_web.md` exited 0.
- **Deliberate Deviations:** Game Timers disabled (`Disable Game Timers` switched ON) in lobby to control progression deterministically across automated browsers.

---

## Web Playthrough Assertions (W1 — W21)

### W1 — Context Isolation & Session Restoral Falsification
- **Verdict:** PASS
- **Clients:** Browser Context 1 (Alice), Browser Context 2 (Bob), Browser Context 3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Falsification step: Alice created room `SMYG` in Context 1. Opened a second tab within Context 1 (same browser storage/cookies) and navigated to `http://127.0.0.1:8777`. Verified that Context 1 tab 2 automatically restored the session into room `SMYG` with a roster count of 1.
  2. Isolated step: Launched distinct Chromium contexts (Context 2 and Context 3). Joined room `SMYG` as Bob and Charlie.
  3. Verified that Context 1, Context 2, and Context 3 maintain separate player identities and sync all 3 distinct players in the lobby roster.
- **Observed:**
  - Falsification Screenshot: `docs/playthroughs/evidence/w1_falsify_same_tab.png`
  - 3-Player Roster Screenshot: `docs/playthroughs/evidence/w1_contexts_roster.png`
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
  - Screenshot: `docs/playthroughs/evidence/w2_cold_boot.png`
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
  - Screenshot: `docs/playthroughs/evidence/w3_semantics_dom.png`
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
  - P1 Screenshot: `docs/playthroughs/evidence/w4_p1_lobby.png`
  - P2 Screenshot: `docs/playthroughs/evidence/w4_p2_lobby.png`
  - P3 Screenshot: `docs/playthroughs/evidence/w4_p3_lobby.png`
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
  - Screenshot: `docs/playthroughs/evidence/w5_readiness_gate.png`
  - Quoted Semantics: `"Waiting on 2 of 2 players to ready up."`, `"Disable Game Timers"`, `"START GAME"`
- **Reference:** `lib/screens/lobby_screen.dart:623`
- **Expected:** Host cannot start match until all non-host players are marked ready.

---

### W6 — Truth Crafting Phase & Quill Submission
> **Superseded note (Wave AA / Wave AB):** The "THE RECORD OF TRUTH" modal dialog observed here was deleted in Wave AA (AA1, Issue 155); superseded by block E50 in `docs/playthroughs/findings_waveAA.md`.
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. Host clicked `START GAME`.
  2. All three players transitioned to Truth crafting phase.
  3. Typed genuine secrets into quill textarea and clicked `SUBMIT DOSSIER`.
- **Observed:**
  - Screenshot: `docs/playthroughs/evidence/w6_truth_craft.png`
  - Quoted Semantics: `"THE RECORD OF TRUTH"`, `"SUBMIT DOSSIER"`, `"Dip the quill…"`
- **Reference:** `lib/screens/phase2_craft.dart:210`
- **Expected:** Truth dossiers submit cleanly and advance all players to Forgery phase.

---

### W7 — Forgery Crafting & Semantic Duplicate Rejection
> **Superseded note (Wave AA / Wave AB):** The "DECK OF FORGERIES" modal dialog observed here was deleted in Wave AA (AA1, Issue 155); superseded by block E50 in `docs/playthroughs/findings_waveAA.md`.
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie)
- **Room Code:** `SMYG`
- **What I did:**
  1. In Forgery phase, Bob attempted to submit an exact duplicate of Alice's genuine truth: `"AAA Paris Story about getting lost near Eiffel Tower"`.
  2. Verified duplicate rejection error feedback in UI.
  3. Bob and Charlie submitted valid original forgeries.
- **Observed:**
  - Duplicate Rejection Screenshot: `docs/playthroughs/evidence/w7_duplicate_reject.png`
  - Forgery Crafting Screenshot: `docs/playthroughs/evidence/w7_forgery_craft.png`
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
  - Screenshot: `docs/playthroughs/evidence/w8_vote_lockout.png`
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
  - Card Reveal Screenshot: `docs/playthroughs/evidence/w9_reveal_card.png`
  - Unmask Window Screenshot: `docs/playthroughs/evidence/w9_unmask_window.png`
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
  - Screenshot: `docs/playthroughs/evidence/w10_standings.png`
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
  - Screenshot: `docs/playthroughs/evidence/w11_gameover.png`
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
  - Screenshot: `docs/playthroughs/evidence/w12_session_restored.png`
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
  - Screenshot: `docs/playthroughs/evidence/w13_same_origin_tab.png`
  - Quoted Semantics: `"ROOM CODE SMYG"`, `"THE PARLOR"`, `"Alice (Host)"`
- **Reference:** `lib/services/game_service.dart:210`
- **Expected:** Opening a second tab under the same origin automatically syncs the active room session.

---

### W14 — Case File Share Action on Web
- **Verdict:** PASS
- **Clients:** P1 (Alice)
- **Room Code:** `XHPD`
- **What I did:**
  1. On GameOverScreen, waited for engraving ceremony to complete and clicked `Share Case File` button.
  2. Observed browser download event and confirmation snackbar on web.
  3. Verified downloaded image file integrity and byte size on disk.
- **Observed:**
  - Screenshot: `docs/playthroughs/evidence/w14_case_file_download.png`
  - Downloaded Image: `docs/playthroughs/evidence/gaslight_case_file_xhpd.png`
  - Quoted Semantics / UI: `"Share Case File"`, `"Case File saved to Downloads!"`
  - Download Verification: File `gaslight_case_file_xhpd.png` downloaded via Blob URL + synthetic anchor click; `file` verification reports `PNG image data, 2464 x 1510, 8-bit/color RGBA, non-interlaced` with size `629585` bytes (not 0 bytes, not HTML error page).
  - *Historical record*: W14 previously cited `w14_case_file_share.png` showing `Sharing is only supported on mobile devices.` prior to Issue 110; re-shot in Wave L (L3) with full runtime confirmation of the web Blob download pipeline.
- **Reference:**
  - `lib/screens/game_over_screen.dart:104`
  - `lib/utils/case_file_saver_web.dart`
- **Expected:** Clicking Share Case File on web initiates browser download of `gaslight_case_file_<roomCode>.png` and displays confirmation snackbar.

---

### W15 — Production Web Console Hygiene & Error Audit
- **Verdict:** PASS
- **Clients:** P1, P2, P3
- **What I did:**
  1. Monitored console error and warning events across all 3 player contexts during full match.
  2. Verified zero unhandled exceptions or rendering crashes.
- **Observed:**
  - Screenshot: `docs/playthroughs/evidence/w15_console_hygiene.png`
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
  - P1 Screenshot: `docs/playthroughs/evidence/w16_p1_gameover.png`
  - P2 Screenshot: `docs/playthroughs/evidence/w16_p2_gameover.png`
  - Quoted Semantics: `"GAME OVER"`, `"FINAL STANDINGS"`
- **Reference:** `lib/services/game_service.dart:710`
- **Expected:** When player count drops below 3 during active play, the match auto-terminates to GameOver.

---

### W17 — Responsive Sweep: Mobile Viewport (375x812)
- **Verdict:** NOT RUN — the in-game screens were never captured (recorded PASS on August 30; corrected October 14, 2026, Issue 197; superseded by W21)
- **Reason:** the cited Crafting, Voting, Reveal and GameOver images show a one-player lobby (October 14: w17 craft = vote and reveal = gameover by checksum; w18 vote = reveal); the cited Lobby image at each size shows the title screen (THE GUEST LEDGER), not the lobby, so no cited image shows the screen it names. All fifteen files were checked on October 14: twelve opened, three byte-identical to one that was.
- **Viewport:** 375 x 812 (Mobile device profile)
- **What I did:**
  1. Loaded web application at 375x812 mobile viewport with touch emulation.
  2. Captured all key match flow screens: Lobby, Crafting, Voting, Reveal, GameOver.
- **Observed:**
  - Lobby: `docs/playthroughs/evidence/w17_lobby.png`
  - Crafting: `docs/playthroughs/evidence/w17_craft.png`
  - Voting: `docs/playthroughs/evidence/w17_vote.png`
  - Reveal: `docs/playthroughs/evidence/w17_reveal.png`
  - GameOver: `docs/playthroughs/evidence/w17_gameover.png`
- **Reference:** `lib/screens/lobby_screen.dart:180`
- **Expected:** Layout adapts responsively to mobile viewport without clipping or overflow.

---

### W18 — Responsive Sweep: Tablet Viewport (768x1024)
- **Verdict:** NOT RUN — the in-game screens were never captured (recorded PASS on August 30; corrected October 14, 2026, Issue 197; superseded by W21)
- **Reason:** the cited Crafting, Voting, Reveal and GameOver images show a one-player lobby (October 14: w17 craft = vote and reveal = gameover by checksum; w18 vote = reveal); the cited Lobby image at each size shows the title screen (THE GUEST LEDGER), not the lobby, so no cited image shows the screen it names. All fifteen files were checked on October 14: twelve opened, three byte-identical to one that was.
- **Viewport:** 768 x 1024 (Tablet portrait)
- **What I did:**
  1. Loaded web application at 768x1024 tablet viewport.
  2. Captured all key match flow screens: Lobby, Crafting, Voting, Reveal, GameOver.
- **Observed:**
  - Lobby: `docs/playthroughs/evidence/w18_lobby.png`
  - Crafting: `docs/playthroughs/evidence/w18_craft.png`
  - Voting: `docs/playthroughs/evidence/w18_vote.png`
  - Reveal: `docs/playthroughs/evidence/w18_reveal.png`
  - GameOver: `docs/playthroughs/evidence/w18_gameover.png`
- **Reference:** `lib/screens/lobby_screen.dart:180`
- **Expected:** Layout adapts responsively to tablet viewport without clipping or overflow.

---

### W19 — Responsive Sweep: Desktop Viewport (1280x800)
- **Verdict:** NOT RUN — the in-game screens were never captured (recorded PASS on August 30; corrected October 14, 2026, Issue 197; superseded by W21)
- **Reason:** the cited Crafting, Voting, Reveal and GameOver images show a one-player lobby (October 14: w17 craft = vote and reveal = gameover by checksum; w18 vote = reveal); the cited Lobby image at each size shows the title screen (THE GUEST LEDGER), not the lobby, so no cited image shows the screen it names. All fifteen files were checked on October 14: twelve opened, three byte-identical to one that was.
- **Viewport:** 1280 x 800 (Desktop landscape)
- **What I did:**
  1. Loaded web application at 1280x800 desktop viewport.
  2. Captured all key match flow screens: Lobby, Crafting, Voting, Reveal, GameOver.
- **Observed:**
  - Lobby: `docs/playthroughs/evidence/w19_lobby.png`
  - Crafting: `docs/playthroughs/evidence/w19_craft.png`
  - Voting: `docs/playthroughs/evidence/w19_vote.png`
  - Reveal: `docs/playthroughs/evidence/w19_reveal.png`
  - GameOver: `docs/playthroughs/evidence/w19_gameover.png`
- **Reference:** `lib/screens/lobby_screen.dart:180`
- **Expected:** Layout adapts responsively to desktop viewport without clipping or overflow.

---

### W20 — Multi-Round Match Highlights: Best Lie of the Night, Cleanest Truth, and The Sting
- **Verdict:** PASS
- **Clients:** P1 (Alice), P2 (Bob), P3 (Charlie) in 3 isolated browser contexts
- **Room Code:** `QZER`
- **What I did:**
  1. Hosted a 3-player, 2-round (`totalRounds = 2`) match from Context 1 with game timers disabled.
  2. Joined P2 (Bob) from Context 2 and P3 (Charlie) from Context 3.
  3. Advanced through Round 1 (Truth, Forgery Rotation 1, Forgery Rotation 2, Voting on 3 cards, Reveal on 3 cards).
  4. Advanced through Round 2 (Truth, Forgery Rotation 1, Forgery Rotation 2, Voting on 3 cards, Reveal on 3 cards) to GameOverScreen.
  5. In voting phase, players deliberately voted for authored forgeries ensuring `fooled > 0` on candidate forgeries (Charlie voting for Alice's `"Sapphire"` forgery, Alice voting for Bob's `"Panther"` forgery, Bob voting for Alice's `"Diamond"` forgery).
  6. Verified that `computeMatchSummary` computed non-null highlights:
     - **BEST LIE OF THE NIGHT:** Quoting `"Sapphire"` by Alice for prompt `"The most embarrassing thing I've ever done on a Zoom call."` with `Fooled 1 player` badge.
     - **CLEANEST TRUTH:** Quoting `"Archimedes"` Charlie's Truth for prompt `"A time I took credit for someone else's idea."` with `Found by only 0 players` badge.
     - **THE STING:** Quoting `"A time I took credit for someone else's idea."` as Deadliest prompt on the table with `2 wrong votes` badge.
  7. Verified verbatim that the quoted string in Best Lie (`"Sapphire"`) was a real player-authored forgery from this match (authored by Alice in Round 1), and NOT a placeholder (`THE SOUL IS SILENT`) or truth.
- **Observed:**
  - Standings & Podium: `docs/playthroughs/evidence/w20_gameover_standings.png`
  - Match Highlights (honors, standings and all three awards in one frame): `docs/playthroughs/evidence/w20_match_summary.png`
  - *(Correction, August 24, 2026: this block originally also cited `w20_best_lie_detail.png` as a separate "Detail" observation. That file was **byte-identical** to `w20_match_summary.png` — the same sha — so it evidenced nothing further. It has been removed with `git rm` and the claim reduced to the two distinct frames that actually exist.)*
  - Verbatim Quoted Semantics:
    - `"MATCH HIGHLIGHTS"`
    - `"BEST LIE OF THE NIGHT"`
    - `"Fooled 1 player"`
    - `""Sapphire""`
    - `"By Alice for prompt \"The most embarrassing thing I've ever done on a Zoom call.\""`
    - `"CLEANEST TRUTH"`
    - `"Found by only 0 players"`
    - `""Archimedes""`
    - `"Charlie's Truth for prompt \"A time I took credit for someone else's idea.\""`
    - `"THE STING"`
    - `"2 wrong votes"`
    - `"\"A time I took credit for someone else's idea.\""`
    - `"Deadliest prompt on the table"`
- **Reference:** `lib/screens/game_over_screen.dart:670`
- **Expected:** In multi-round matches with fooled players, `computeMatchSummary` populates `bestLie`, `cleanestTruth`, and `theSting` referencing actual player submissions, rendering the complete `MATCH HIGHLIGHTS` card.

---

### W21 — Responsive Sweep: lobby and in-game screens at three web sizes
- **Verdict:** PASS
- **Viewports:** 375 x 812 (phone), 768 x 1024 (tablet portrait) and 1280 x 800 (desktop landscape): one page, resized in place with `page.setViewportSize`
- **Clients:** P1 (Alice, the host) in a 3-player match against the local emulators; P2 (Bob) and P3 (Charlie) played the other seats at 1280 x 800
- **Room Code:** `NJMH`
- **What I did:**
  1. Ran `./scripts/run_web_smoke.sh` on October 14, 2026 (exit 0 in 302 s; both playthroughs reached game over; 41 PNGs): an emulator-only web build of the tree at `410f986`, driven by this item's scripts. A second run the same evening (exit 0 in 313 s, room `ALDR`) passed the same sweep with P1 as the reader instead of a voter; its images were not kept.
  2. At five points of the main game, resized P1's page through the three sizes with `sweepViewports` (`test/web_e2e/playthrough_helpers.js`): the lobby with all three players ready (W5), the craft screen before P1 typed (W6, phase `truth`), the vote screen before P1 voted (W8; P1 was a voter, on Bob's card), the reveal once its score chips were up (W9), and the game over screen after the engraving ceremony (W11).
  3. At each size the sweep waited 1.5 s for Flutter to lay out again and re-enabled semantics; asserted the room document's `currentPhase` (`lobby`, `truth`, `vote`, `reveal`, `gameOver`); asserted that every key control was present (scrolling with the mouse wheel if need be) and inside the viewport horizontally (`x >= -1` and `x + width <= viewport width + 1`); saved the image scrolled to the top; and logged, for information only, any node whose right edge passed the viewport. It restored 1280 x 800 afterwards.
  4. Opened all fifteen images and checked that each shows the named screen at the named size.
- **Observed:**
  - Lobby, 375 x 812: `docs/playthroughs/evidence/w21_375x812_lobby.png`
  - Lobby, 768 x 1024: `docs/playthroughs/evidence/w21_768x1024_lobby.png`
  - Lobby, 1280 x 800: `docs/playthroughs/evidence/w21_1280x800_lobby.png`
  - Crafting (phase `truth`), 375 x 812: `docs/playthroughs/evidence/w21_375x812_truth.png`
  - Crafting (phase `truth`), 768 x 1024: `docs/playthroughs/evidence/w21_768x1024_truth.png`
  - Crafting (phase `truth`), 1280 x 800: `docs/playthroughs/evidence/w21_1280x800_truth.png`
  - Voting, 375 x 812: `docs/playthroughs/evidence/w21_375x812_vote.png`
  - Voting, 768 x 1024: `docs/playthroughs/evidence/w21_768x1024_vote.png`
  - Voting, 1280 x 800: `docs/playthroughs/evidence/w21_1280x800_vote.png`
  - Reveal, 375 x 812: `docs/playthroughs/evidence/w21_375x812_reveal.png`
  - Reveal, 768 x 1024: `docs/playthroughs/evidence/w21_768x1024_reveal.png`
  - Reveal, 1280 x 800: `docs/playthroughs/evidence/w21_1280x800_reveal.png`
  - GameOver, 375 x 812: `docs/playthroughs/evidence/w21_375x812_gameOver.png`
  - GameOver, 768 x 1024: `docs/playthroughs/evidence/w21_768x1024_gameOver.png`
  - GameOver, 1280 x 800: `docs/playthroughs/evidence/w21_1280x800_gameOver.png`
  - Measured (the run's `[SWEEP]` lines, left to right edge in px): at 375, ROOM CODE 29.0 to 346.0, START GAME 16.0 to 359.0, answer field 49.5 to 331.5, SUBMIT DOSSIER 24.0 to 351.0, TAP A CARD TO CHOOSE 24.0 to 351.0, THE REVEAL 0.0 to 375.0, Share Case File 24.0 to 351.0; at 768, START GAME 16.0 to 752.0 and Share Case File 24.0 to 744.0; at 1280, START GAME 16.0 to 1264.0 and Share Case File 24.0 to 1256.0. Every key control lay inside its viewport at every size.
  - Information only: on the reveal at 375, two nodes of the Standings strip (Bob's chip: "Bob", "0") had right edges of 487.6 and 509.5. The strip is a horizontal scroll view by design (`lib/screens/phase4_reveal.dart`, `STANDINGS`), so a third chip runs past a phone's edge. No other node passed a right edge at any size.
  - Seen in the images, not asserted: at 375 x 812 and 1280 x 800 the vote screen's PREV / NEXT row sits under the bottom bar until the page is scrolled (it is fully visible at 768 x 1024), and in this run the deck opens on P1's own forgery, stamped SEALED and "(Your Forgery)". At 375 x 812 the reveal shows only its top (the prompt, the truth and the forgery cards); the points, standings and CONTINUE are below the fold.
- **Reference:** `test/web_e2e/playthrough_helpers.js` (`sweepViewports`); `test/web_e2e/run_full_playthrough.js` (the calls in W5, W6, W8, W9 and W11)
- **Expected:** each screen's key controls inside the viewport at each size. Lobby: ROOM CODE and START GAME. Craft: the answer field and SUBMIT DOSSIER. Vote: TAP A CARD TO CHOOSE for a voter, I'M READY or NOT READY for the reader. Reveal: THE REVEAL. Game over: Share Case File.
- **Limit:** a resized desktop page, with no touch emulation and no mobile user agent (the old w17 context had both, but only ever showed the title screen and a one-player lobby). The build is the emulator-only one, which paints Firebase's red "Running in emulator mode" banner over the bottom 20 to 37 px of every image; at 375 x 812 it covers the lower edge of the bottom-pinned buttons, and the release build has none. Only each key control's horizontal bounds are asserted: nothing here checks vertical fit, text clipping or the parts of a page below the fold, and each image shows the top of its page.
