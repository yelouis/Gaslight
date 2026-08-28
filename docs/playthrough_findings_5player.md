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
