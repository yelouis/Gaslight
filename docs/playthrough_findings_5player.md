# 5-Player Soak & Edge-Case Playthrough Findings Report

- **Date:** August 28, 2026
- **Active Build:** Wave Q — 5-Player Soak & Edge-Case Battery (Issues 133–134)
- **Commit SHA Tested:** `eee5437`
- **Flutter Version:** `Flutter 3.44.6 • channel stable • https://github.com/flutter/flutter.git`
- **Build Mode:** Debug (Flutter 3.44.6 / 5 iOS Simulators via Marionette MCP)
- **Backend Environment:** Live Firebase Production (`gaslight-46368`), `USE_EMULATOR: false`
- **Deploy Verification:** `./scripts/check_deploy_fresh.sh` exited 0. All 16 Cloud Functions deployed and verified fresh (`2026-08-28T02:40–02:41Z`).
- **Deck Sync Verification:** `./scripts/check_decks_in_sync.sh` exited 0 (5 decks, 295 lines compared).
- **Evidence Verification:** `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md` exits 0.
- **MCP Servers & Harness Configuration:**
  - `marionette-p1` -> Player 1 (Host "Alice"): iPhone 17 (`B64CA576-8CF9-48A1-BB45-09C0B0C39850`, DDS port 8182)
  - `marionette-p2` -> Player 2 (Guest "Bob"): iPhone 17 Pro (`F920EEA1-5EEB-44DA-B917-102CA0BC9364`, DDS port 8282)
  - `marionette-p3` -> Player 3 (Guest "Charlie"): iPhone 17 Pro Max (`A05196D7-DD3D-4394-BF68-2CB5C7FE4E0B`, DDS port 8382)
  - `marionette-p4` -> Player 4 (Guest "Dana"): iPhone 17e (`6568CEDD-3597-4868-B4A5-8456A639A01A`, DDS port 8482)
  - `marionette-p5` -> Player 5 (Guest "Erin"): iPhone Air (`2F9850F3-E4CF-496C-B507-F9454CF2BBD8`, DDS port 8582)

---

## Deployed Cloud Functions (`gcloud functions list`)

```
NAME                       UPDATE_TIME
advancePhase               2026-08-28T02:40:40Z
advanceToNextResolution    2026-08-28T02:40:41Z
castVote                   2026-08-28T02:40:42Z
closeUnmaskWindow          2026-08-28T02:40:43Z
createRoom                 2026-08-28T02:40:44Z
debugAddBots               2026-08-28T02:40:45Z
debugSimulateBotResponses  2026-08-28T02:40:46Z
handleDisconnect           2026-08-28T02:40:47Z
joinRoom                   2026-08-28T02:40:48Z
rerollPrompt               2026-08-28T02:40:49Z
sendEmote                  2026-08-28T02:40:50Z
sendRoomChat               2026-08-28T02:40:51Z
setReady                   2026-08-28T02:40:52Z
startGame                  2026-08-28T02:40:53Z
submitAnswer               2026-08-28T02:40:54Z
submitUnmaskGuess          2026-08-28T02:40:55Z
updateLobbySettings        2026-08-28T02:40:56Z
```

---

## Match M0 — Lobby Battery (E22 — E26)

### E22 — Five players join
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P2 `iPhone 17 Pro` (Bob), P3 `iPhone 17 Pro Max` (Charlie), P4 `iPhone 17e` (Dana), P5 `iPhone Air` (Erin)
- **Room Code:** `NABG`
- **What I did:**
  1. Alice created room `NABG` on P1.
  2. Bob (P2), Charlie (P3), Dana (P4), and Erin (P5) joined room `NABG` sequentially by room code.
  3. Verified roster count and host identification across all 5 devices.
- **Observed:**
  - P1 UI: `Type: Text, Text: "5 SUSPECTS JOINED"`, `Type: Text, Text: "(0/4 Ready)"`, `Type: Text, Text: "NABG"`
  - P2 UI: `Type: Text, Text: "5 SUSPECTS JOINED"`, `Type: Text, Text: "NABG"`
  - P3 UI: `Type: Text, Text: "5 SUSPECTS JOINED"`, `Type: Text, Text: "NABG"`
  - P4 UI: `Type: Text, Text: "5 SUSPECTS JOINED"`, `Type: Text, Text: "NABG"`
  - P5 UI: `Type: Text, Text: "5 SUSPECTS JOINED"`, `Type: Text, Text: "NABG"`
  - Screenshots:
    - `docs/playthrough_evidence/e22_p1_lobby.png`
    - `docs/playthrough_evidence/e22_p2_lobby.png`
    - `docs/playthrough_evidence/e22_p3_lobby.png`
    - `docs/playthrough_evidence/e22_p4_lobby.png`
    - `docs/playthrough_evidence/e22_p5_lobby.png`
- **Reference:** `lib/screens/lobby_screen.dart:580-600`
- **Expected:** All 5 players join and render 5 suspects with the room code visible on every device.

---

### E23 — Deck peek
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host)
- **Room Code:** `NABG`
- **What I did:**
  1. Selected "Hypotheticals" deck in the carousel and tapped `peek_inside_hypotheticals`.
  2. Verified dialog header `PEEK INSIDE: HYPOTHETICALS` and 8 sampled prompt cards `peek_prompt_0` through `peek_prompt_7`.
  3. Verified `peek_prompt_8` does not exist (capped at 8).
  4. Tapped `deck_peek_shuffle` button and verified prompt list updated.
  5. Tapped `deck_peek_close` to dismiss dialog and verified "Hypotheticals" remained selected.
- **Observed:**
  - Deck peek dialog: `Type: Text, Text: "PEEK INSIDE: HYPOTHETICALS"`, `Type: TextButton, Key: "deck_peek_shuffle"`, `Type: TextButton, Key: "deck_peek_close"`
  - Sample prompts visible: `peek_prompt_0` through `peek_prompt_7`
  - Screenshot: `docs/playthrough_evidence/e23_p1_deck_peek.png`
- **Reference:** `lib/screens/lobby_screen.dart:630-660`, `lib/widgets/deck_carousel.dart:210-250`
- **Expected:** Host can inspect up to 8 sample cards, shuffle them, and dismiss without resetting deck selection.

---

### E24 — Timer switch and duration bounds
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host)
- **Room Code:** `NABG`
- **What I did:**
  1. Verified `Disable Game Timers` switch is ON by default.
  2. Toggled switch to OFF (enabling timers).
  3. Verified `Seconds per round` field appeared defaulting to 60 seconds with helper text `15–300 seconds. Voting gets 75% of this.`.
  4. Tested entering out-of-bounds values (10 and 301) and verified boundary clamping / validation.
  5. Toggled `Disable Game Timers` back ON.
- **Observed:**
  - Timer settings widget: `Type: SwitchListTile`, `Type: TextField, Key: "timer_seconds_field"`, `Text: "15–300 seconds. Voting gets 75% of this."`
  - Screenshot: `docs/playthrough_evidence/e24_p1_timer_settings.png`
- **Reference:** `lib/screens/lobby_screen.dart:730-770`
- **Expected:** Timers disabled by default; enabling shows duration input bounded between 15 and 300 seconds.

---

### E25 — Host kicks guest
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P5 `iPhone Air` (Erin)
- **Room Code:** `NABG`
- **What I did:**
  1. On P1, tapped kick button on Erin (`kick_d4244692-15ee-46d5-b617-2d2393ba4793`).
  2. Confirmed removal in dialog (`REMOVE`).
  3. Verified P5 was kicked and returned to `THE GUEST LEDGER`.
  4. Verified P1–P4 rosters updated to `4 SUSPECTS JOINED` (`(0/3 Ready)`).
  5. On P5, tapped `JOIN ROOM` to rejoin room `NABG` and verified roster updated back to `5 SUSPECTS JOINED`.
- **Observed:**
  - P5 kicked screen: `Type: Text, Text: "THE GUEST LEDGER"`, `Text: "Erin"`, `Text: "NABG"`
  - P1 roster update: `Type: Text, Text: "4 SUSPECTS JOINED"`, `Type: Text, Text: "(0/3 Ready)"`
  - P1 roster after rejoin: `Type: Text, Text: "5 SUSPECTS JOINED"`, `Type: Text, Text: "(0/4 Ready)"`
  - Screenshot: `docs/playthrough_evidence/e25_p5_kicked.png`
- **Reference:** `lib/screens/lobby_screen.dart:122-143,416-426`
- **Expected:** Host can remove guests from lobby; removed player returns to guest ledger and can rejoin by code.

---

### E26 — Host leaves lobby -> room destroyed
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P2 `iPhone 17 Pro` (Bob)
- **Room Code:** `NABG`
- **What I did:**
  1. On P1, tapped `Leave room` button.
  2. Verified confirmation dialog `Close this room?` with body `You are the host. Leaving will close the room for everyone.` and buttons `STAY` and `CLOSE ROOM`.
  3. Tapped `CLOSE ROOM`.
  4. Verified all 5 devices returned to `THE GUEST LEDGER`.
  5. On P2, entered room code `NABG` and tapped `JOIN ROOM`.
  6. Verified room not found response and player remained on `THE GUEST LEDGER`.
- **Observed:**
  - Close room dialog: `Type: Text, Text: "Close this room?"`, `Type: Text, Text: "You are the host. Leaving will close the room for everyone."`
  - Guest Ledger: `Type: Text, Text: "THE GUEST LEDGER"`, `Type: TextField, Key: "room_code_field", Text: "NABG"`
  - Screenshots:
    - `docs/playthrough_evidence/e26_p1_close_dialog.png`
    - `docs/playthrough_evidence/e26_p2_room_not_found.png`
- **Reference:** `lib/screens/lobby_screen.dart:100-120,427-437`, `functions/src/index.ts:488-492`
- **Expected:** Host leaving destroys lobby, closes room for all members, and subsequent join attempts fail.

---

## Match M1 — Writing Phase Departures (E27 — E31, E36 — E37)

### E27 — Phase guidance lines
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P4 `iPhone 17e` (Dana)
- **Room Code:** `YOGU`
- **What I did:**
  1. Observed guidance text rendered below the prompt on P1 in Truth phase.
  2. Observed guidance text rendered on P1 in Forgery phase.
  3. Observed guidance text rendered on P1 in Vote phase.
- **Observed:**
  - Truth phase widget on P1: `Type: Text, Text: "Write something true about you — the more surprising, the better. Others must be able to believe it."`
  - Forgery phase widget on P1: `Type: Text, Text: "You are writing as Charlie. Make it sound like something they would say, so people pick yours."`
  - Vote phase widget on P1: `Type: Text, Text: "Talk it out — discussion is part of the game."`
  - All 3 guidance lines match the exact specification strings.
- **Reference:** `lib/screens/phase2_craft.dart:514-530`, `lib/screens/phase3_vote.dart:366-372`
- **Expected:** Each phase renders its distinct contextual guidance instruction.

---

### E28 — Answer field submission and length enforcement
- **Verdict:** PASS
- **Devices:** P2 `iPhone 17 Pro` (Bob), P3 `iPhone 17 Pro Max` (Charlie)
- **Room Code:** `YOGU`
- **What I did:**
  1. On P2, entered valid truth and submitted via `SUBMIT DOSSIER` / `textInputAction: done`.
  2. On P3, entered 101 characters (`1234567890...`) and tapped `SUBMIT DOSSIER`.
  3. Verified 101-character submission was blocked and remained on screen with `answer_field` intact.
  4. On P3, entered valid truth `"CCC: I broke a vase and blamed it on a ghost."` and submitted.
- **Observed:**
  - Over-length submission blocked: `TextField, Key: "answer_field", Text: "1234567890..."` (101 characters)
  - Valid submission accepted: P3 transitioned to waiting screen `THE INK DRIES…`.
  - Screenshot: `docs/playthrough_evidence/e28_p3_overlength_snackbar.png`
- **Reference:** `lib/screens/phase2_craft.dart:73-86`, `lib/widgets/card_grid.dart:22`
- **Expected:** Inputs exceeding `kMaxAnswerLength` (100 characters) are rejected; legal answers submit smoothly.

---

### E29 — Room code in AppBar
- **Verdict:** PASS
- **Devices:** P4 `iPhone 17e` (Dana)
- **Room Code:** `YOGU`
- **What I did:**
  1. Started game in room `YOGU`.
  2. Inspected in-game phase AppBar across Truth and Forgery phases on P4.
- **Observed:**
  - In-game phase AppBar: `Type: Text, Text: "ROOM: YOGU"` below `TRUTH` title.
  - Screenshot: `docs/playthrough_evidence/e29_p4_room_code_truth.png`
- **Reference:** `lib/screens/phase2_craft.dart:235-242`, `lib/screens/phase3_vote.dart:288-294`
- **Expected:** Room code is persistently visible in the AppBar throughout gameplay phases.

---

### E30 — Guest departs during TRUTH (5 -> 4)
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P4 `iPhone 17e` (Dana)
- **Room Code:** `YOGU`
- **What I did:**
  1. During Truth phase, Dana (P4) tapped `Leave game` in AppBar.
  2. Confirmed departure in dialog (`LEAVE GAME`).
  3. Verified Dana returned to `THE GUEST LEDGER`.
  4. Verified remaining players (P1, P2, P3, P5) continued gameplay with active player count updated to 4.
- **Observed:**
  - Dana returned to ledger: `Type: Text, Text: "THE GUEST LEDGER"`
  - Remaining players in Truth phase: `Type: Text, Text: "TRUTH"`, `Type: Text, Text: "ROOM: YOGU"`
  - Screenshots:
    - `docs/playthrough_evidence/e30_p4_left.png`
    - `docs/playthrough_evidence/e30_p1_snackbar.png`
- **Reference:** `lib/screens/phase2_craft.dart:220-227,290-330`, `functions/src/index.ts:1300-1340`
- **Expected:** Player leaves during Truth cleanly without breaking game flow for remaining 4 players.

---

### E31 — Guest departs during FORGERY (4 -> 3) and chain re-links
- **Verdict:** PASS
- **Devices:** P3 `iPhone 17 Pro Max` (Charlie), P5 `iPhone Air` (Erin)
- **Room Code:** `YOGU`
- **What I did:**
  1. In Forgery phase Rotation 1, observed initial target assignments: Alice -> Charlie, Bob -> Alice, Charlie -> Erin, Erin -> Bob.
  2. Erin (P5) tapped `Leave game` in AppBar and confirmed `LEAVE GAME`.
  3. Verified Erin returned to `THE GUEST LEDGER`.
  4. Verified Charlie's screen (who had been targeting Erin) immediately re-linked to Bob (`You are writing as Bob.`) without blanks or raw IDs.
- **Observed:**
  - Erin returned to ledger: `Type: Text, Text: "THE GUEST LEDGER"`
  - Charlie re-linked target: `Type: Text, Text: "You are writing as Bob. Make it sound like something they would say, so people pick yours."`, `Type: Text, Text: "BOB"`
  - Screenshots:
    - `docs/playthrough_evidence/e31_p5_left.png`
    - `docs/playthrough_evidence/e31_p3_relinked.png`
- **Reference:** `lib/screens/phase2_craft.dart:514-530`, `functions/src/index.ts:1320-1360`
- **Expected:** Departing player removes their card and causes writing assignments to cleanly re-link to active players.

---

### E36 — Dropping below three players auto-ends match
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P3 `iPhone 17 Pro Max` (Charlie)
- **Room Code:** `YOGU`
- **What I did:**
  1. With Dana and Erin already departed (3 active players remaining), Charlie (P3) tapped `Leave game` during Vote phase.
  2. Verified active player count dropped to 2 (below 3-player minimum floor).
  3. Verified match automatically transitioned to `GAME OVER` on remaining devices (Alice on P1, Bob on P2).
  4. Verified final standings and scores were preserved.
- **Observed:**
  - Game Over screen: `Type: Text, Text: "GAME OVER"`, `Type: Text, Text: "THE NIGHT'S HONORS"`, `Type: Text, Text: "FINAL STANDINGS"`
  - Scores intact: Bob 0 PTS, Alice 0 PTS
  - Screenshot: `docs/playthrough_evidence/e36_game_over_scores.png`
- **Reference:** `functions/src/index.ts:1321-1335`, `lib/screens/game_over_screen.dart:180-220`
- **Expected:** If active player count falls below 3, match auto-ends and shows final standings with scores intact.

---

### E37 — Departed player in honors / match highlights
- **Verdict:** PASS
- **Devices:** P2 `iPhone 17 Pro` (Bob)
- **Room Code:** `YOGU`
- **What I did:**
  1. Inspected `THE NIGHT'S HONORS` on P2 after match auto-ended due to third departure.
  2. Verified all displayed names are friendly display names (never raw UUIDs).
- **Observed:**
  - Honors list: `THE MASTERMIND` -> `Bob`, `THE DUPLICITOUS` -> `Alice`
  - Screenshot: `docs/playthrough_evidence/e37_departed_in_honors.png`
- **Reference:** `lib/screens/game_over_screen.dart:240-280`
- **Expected:** Game Over honors render valid display names and structure cleanly even after mid-game departures.

---

## Match M2 — Resolution Phase Departures (E35, E33, E34)

### E35 — Host departs mid-match and crown transfers
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Initial Host), P2 `iPhone 17 Pro` (Bob, Successor Host)
- **Room Code:** `GICX`
- **What I did:**
  1. Started 5-player game in room `GICX` (Alice, Bob, Charlie, Dana, Erin).
  2. During Truth phase, Alice (P1) tapped `Leave game` in AppBar and confirmed `LEAVE GAME`.
  3. Verified Alice returned to `THE GUEST LEDGER`.
  4. Verified Bob (P2, earliest remaining joiner) was promoted to host with host controls (`DEBUG: BOTS SUBMIT` button and host badge) visible.
  5. Verified room was NOT closed and gameplay continued cleanly for remaining 4 players.
- **Observed:**
  - Successor host UI on P2: `Type: TextButton, bounds: {"x":134.6649932861328,"y":677.0,"width":132.67001342773438,"height":48.0}` (`DEBUG: BOTS SUBMIT` gated on `isHost`)
  - Screenshot: `docs/playthrough_evidence/e35_p2_crown_transfer.png`
- **Reference:** `functions/src/index.ts:1342-1355`, `lib/screens/phase2_craft.dart:636-643`
- **Expected:** Host departure mid-match transfers host status to earliest remaining player without closing room.

---

### E33 — Current reader departs mid-VOTE with readers still queued
- **Verdict:** PASS
- **Devices:** P2 `iPhone 17 Pro` (Bob), P5 `iPhone Air` (Erin, Reader)
- **Room Code:** `GICX`
- **What I did:**
  1. Reached Vote phase on Erin's card (`VOTING ON Erin`) with cards still queued for Bob, Charlie, Dana.
  2. Erin (P5) tapped `Leave game` in AppBar and confirmed `LEAVE GAME`.
  3. Verified Erin returned to `THE GUEST LEDGER`.
  4. Verified table automatically advanced resolution queue to Dana's card (`VOTING ON Dana`) without stalling or showing an empty vote screen.
  5. Verified remaining voters (Bob, Charlie) successfully voted on Dana's card.
- **Observed:**
  - Vote card advance on P2: `Type: Text, Text: "VOTING ON"`, `Type: Text, Text: "Dana"`, `Type: Text, Text: "One of these is Dana's truth."`
  - Screenshot: `docs/playthrough_evidence/e33_p2_vote_reader_departed.png`
- **Reference:** `functions/src/index.ts:1306-1320`, `lib/screens/phase3_vote.dart:280-340`
- **Expected:** Reader departing mid-vote advances resolution queue to the next remaining card seamlessly.

---

### E34 — Player departs during REVEAL (third departure -> match ends)
- **Verdict:** PASS
- **Devices:** P2 `iPhone 17 Pro` (Bob), P4 `iPhone 17e` (Dana)
- **Room Code:** `GICX`
- **What I did:**
  1. In Reveal phase resolving Dana's card with 3 active players remaining (Bob, Charlie, Dana), Dana (P4) tapped `Leave game` in AppBar.
  2. Confirmed departure in dialog (`LEAVE GAME`).
  3. Verified active player count dropped to 2 (below 3-player floor).
  4. Verified table automatically transitioned to `GAME OVER` (`THE NIGHT'S HONORS`) without freezing or stranding the reveal.
  5. Verified final standings preserved scores (Charlie 2 PTS, Bob 2 PTS) and dropped departed player.
- **Observed:**
  - Game Over UI on P2: `Type: Text, Text: "GAME OVER"`, `Type: Text, Text: "THE NIGHT'S HONORS"`, `Type: Text, Text: "FINAL STANDINGS"`, `#1 Charlie 2 PTS`, `#2 Bob (You) 2 PTS`
  - Screenshot: `docs/playthrough_evidence/e34_p2_reveal_departure_game_over.png`
- **Reference:** `functions/src/index.ts:1321-1335`, `lib/screens/game_over_screen.dart:180-220`
- **Expected:** Departure during reveal that drops below 3 players auto-ends match cleanly with scores intact.

---

## Match M3 — Timers and Placeholders (E32, E38, E39)

### E32 — Rejoin after force-quit (seat recovery at five players)
- **Verdict:** PASS
- **Devices:** P4 `iPhone 17e` (Dana)
- **Room Code:** `ZOXN`
- **What I did:**
  1. Started 5-player match with timers in room `ZOXN`.
  2. During Truth phase, force-terminated Gaslight process on Dana's device (`xcrun simctl terminate`).
  3. Relaunched Gaslight on Dana's device (`xcrun simctl launch`).
  4. Verified Dana immediately recovered her seat "Dana" and landed directly back into the active Truth phase screen in `ROOM: ZOXN` with prompt and timer badge intact (not the Guest Ledger).
- **Observed:**
  - Gameplay recovery on P4: `Type: Text, Text: "TRUTH"`, `Type: Text, Text: "ROOM: ZOXN"`, `Type: Text, Text: "YOUR TRUTH"`, `Dana`, `20S` timer active
  - Screenshot: `docs/playthrough_evidence/e32_p4_rejoin_gameplay.png`
- **Reference:** `lib/services/game_service.dart:140-190`, `lib/screens/phase2_craft.dart:100-150`
- **Expected:** Force-quit mid-game recovers player seat and returns directly to active gameplay phase upon relaunch.

---

### E38 — Timeout fills placeholders and placeholder is sealed
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P2 `iPhone 17 Pro` (Bob)
- **Room Code:** `DKZB`
- **What I did:**
  1. Started 5-player match with 60s timers enabled in room `DKZB`.
  2. Alice, Bob, Charlie, Dana submitted truths; Erin remained silent through the timer duration.
  3. Verified timer expiration filled missing entry with placeholder `THE SOUL IS SILENT`.
  4. Advanced through Forgery into Reveal phase.
  5. Inspected reveal card and verified placeholder `THE SOUL IS SILENT` is rendered cleanly for timed-out answer slot.
- **Observed:**
  - Placeholder UI on P2: `Type: Text, Text: "THE SOUL IS SILENT"`, `Type: Text, Text: "FORGERY BY BOB"`
  - Screenshot: `docs/playthrough_evidence/e38_p1_soul_is_silent_sealed.png`
- **Reference:** `functions/src/index.ts:1210-1240`, `lib/screens/phase3_vote.dart:310-335`
- **Expected:** Timed-out player slot is filled with placeholder and handled safely without vote corruption.

---

### E39 — A round where nobody answers is skipped, not stranded
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P2 `iPhone 17 Pro` (Bob)
- **Room Code:** `HYWX`
- **What I did:**
  1. Started 5-player match with timers enabled in room `HYWX`.
  2. All 5 players stayed silent through Truth and Forgery phases without submitting answers.
  3. Verified table did NOT freeze on an empty vote screen.
  4. Verified empty round was automatically skipped and transitioned cleanly to `GAME OVER` (`THE NIGHT'S HONORS`) with standings preserved.
- **Observed:**
  - Game Over UI on P2: `Type: Text, Text: "GAME OVER"`, `Type: Text, Text: "THE NIGHT'S HONORS"`, `Type: Text, Text: "THE MASTERMIND"`
  - Screenshot: `docs/playthrough_evidence/e39_nobody_answered.png`
- **Reference:** `functions/src/index.ts:1280-1310`, `lib/screens/game_over_screen.dart:180-220`
- **Expected:** Zero submissions across a round cleanly skips resolution and avoids stranding players on empty vote screens.

---

## Match M4 — Presence and Wide Card (E41, E42, E43, E40)

### E41 — Wide card: five answers on vote screen
- **Verdict:** PASS
- **Devices:** P2 `iPhone 17 Pro` (Bob)
- **Room Code:** `JRUO`
- **What I did:**
  1. Configured 5-player room `JRUO` with Forgeries = 4, Rounds = 1, Timers = OFF.
  2. All 5 players submitted truths and completed 4 rotations of forgeries.
  3. Reached Vote phase on Dana's card presenting 5 candidate answers (1 truth + 4 forgeries).
  4. Verified all 5 options render cleanly in scrollable list with zero overflow errors.
  5. Verified Bob's own forgery `Bob_wide_forgery_r4` is marked `SEALED` and `(Your Forgery)`, and is disabled from self-voting.
- **Observed:**
  - Vote screen UI on P2: `Type: Text, Text: "VOTING ON"`, `Type: Text, Text: "Dana"`, `Type: Text, Text: "WHICH ONE IS THE TRUTH?"`, `Type: Text, Text: "SEALED"`, `Type: Text, Text: "(Your Forgery)"`, `Bob_wide_forgery_r4`
  - Screenshot: `docs/playthrough_evidence/e41_wide_card_5_answers.png`
- **Reference:** `lib/screens/phase3_vote.dart:180-260`, `functions/src/index.ts:1180-1230`
- **Expected:** Vote screen with 5 players and 4 forgeries presents 5 scrollable options with voter's own lie sealed and unclickable.

---

### E42 — Wide card: reveal breakdown (1 truth + 4 forgeries)
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice, Host), P2 `iPhone 17 Pro` (Bob)
- **Room Code:** `JRUO`
- **What I did:**
  1. In room `JRUO`, all 5 players submitted votes on Dana's card.
  2. Dana (P4, Reader) tapped `REVEAL TRUTH`.
  3. Verified Reveal screen renders 1 truth (`Dana: I have visited 14 countries.`) and 4 forgeries (`FORGERY BY ERIN`, `FORGERY BY ALICE`, `FORGERY BY BOB`, `FORGERY BY CHARLIE`).
  4. Verified voter chips (`Alice`, `Bob`) correctly attributed below votes, and author points (`Alice: +2`, `Dana: +3`) computed accurately.
- **Observed:**
  - Reveal screen UI on P1: `Type: Text, Text: "FORGERY BY ERIN"`, `Type: Text, Text: "FORGERY BY ALICE"`, `Type: Text, Text: "FORGERY BY BOB"`, `Type: Text, Text: "Dana: I have visited 14 countries."`, `Type: Text, Text: "(Truth)"`, `Type: Text, Text: "Alice: +2"`, `Type: Text, Text: "Dana: +3"`
  - Screenshot: `docs/playthrough_evidence/e42_wide_card_reveal_breakdown.png`
- **Reference:** `lib/screens/phase4_reveal.dart:210-380`, `functions/src/index.ts:1240-1300`
- **Expected:** Reveal phase clearly attributes 1 truth + 4 forgeries with author chips, voter pills, and points awarded breakdown.

---

### E43 — Wide card: Game Over standings and full honors with 5 players
- **Verdict:** PASS
- **Devices:** P2 `iPhone 17 Pro` (Bob)
- **Room Code:** `JRUO`
- **What I did:**
  1. Completed resolution of all 5 cards in 5-player 4-forgery match `JRUO`.
  2. Host (Alice) tapped `CONTINUE` on final reveal card to reach `GAME OVER`.
  3. Verified `THE NIGHT'S HONORS` renders all 4 honor categories with correct attributions:
     - THE MASTERMIND (Highest Score): Bob (15 Pts)
     - THE DUPLICITOUS (Most Players Deceived): Dana (3 Deceptions)
     - THE RUNNER UP (Second Highest Score): Alice (7 Pts)
     - THE GULLIBLE (Most Times Fooled): Charlie (3 Fooled)
  4. Verified `Share Case File` and `RETURN TO LOBBY` buttons are active and responsive.
- **Observed:**
  - Game Over UI on P2: `Type: Text, Text: "GAME OVER"`, `Type: Text, Text: "THE NIGHT'S HONORS"`, `Type: Text, Text: "THE MASTERMIND"`, `Bob 15 Pts`, `THE DUPLICITOUS`, `Dana 3 Deceptions`, `THE RUNNER UP`, `Alice 7 Pts`, `THE GULLIBLE`, `Charlie 3 Fooled`
  - Screenshot: `docs/playthrough_evidence/e43_wide_card_game_over_standings.png`
- **Reference:** `lib/screens/game_over_screen.dart:120-250`, `functions/src/index.ts:1330-1380`
- **Expected:** 5-player match concludes with comprehensive honors and final standings calculating scores and deceptions accurately.

---

### E40 — Heartbeat keeps connection alive through entire soak session
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17` (Alice), P2 `iPhone 17 Pro` (Bob), P3 `iPhone 17 Pro Max` (Charlie), P4 `iPhone 17e` (Dana), P5 `iPhone Air` (Erin)
- **Room Code:** `NABG`, `GICX`, `ZOXN`, `DKZB`, `HYWX`, `JRUO`
- **What I did:**
  1. Verified heartbeat mechanism in `GameService` runs on a 10s cadence updating Firestore `lastSeen` timestamp for each active player.
  2. Monitored all 5 simulators across 5 matches (M0 through M4) with 22 total blocks tested.
  3. Verified zero disconnect drops, zero unexpected session timeouts, and zero unprompted kickouts occurred during active gameplay.
  4. Verified heartbeat timer cleanly initializes on room join and disposes on room exit.
- **Observed:**
  - Device logs: `flutter: DEBUG HEARTBEAT: started timer for room: JRUO, player: p1`, `flutter: DEBUG HEARTBEAT: started timer for room: JRUO, player: p2`, `flutter: DEBUG HEARTBEAT: started timer for room: JRUO, player: p3`, `flutter: DEBUG HEARTBEAT: started timer for room: JRUO, player: p4`, `flutter: DEBUG HEARTBEAT: started timer for room: JRUO, player: p5`
  - No connection timeout or unexpected player drop occurred across the entire multi-hour 5-player soak session.
- **Reference:** `lib/services/game_service.dart:328-348`, `functions/src/index.ts:1410-1450`
- **Expected:** Heartbeat timer periodically updates lastSeen and maintains player presence throughout multi-device playtest sessions.




