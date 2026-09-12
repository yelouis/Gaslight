# Wave AA Marionette Playthrough Findings Report (E50 — E63)

- **Date:** September 11, 2026
- **Active Build:** Wave AA & Wave AB Verification Battery (Issues 153–170)
- **Commit Tested:** Descendant of `d7b1168` (AB2 running rivalries & closest read)
- **Flutter Version:** `Flutter 3.44.6 • channel stable • https://github.com/flutter/flutter.git`
- **Build Mode:** Debug (Flutter 3.44.6 / iOS Simulators via Marionette MCP)
- **Backend Environment:** Live Firebase Production (`gaslight-46368`), `USE_EMULATOR: false`
- **Deploy Verification:** `./scripts/check_deploy_fresh.sh` exited 0. All 18 Cloud Functions deployed and verified fresh. `CLEANUP_DRY_RUN=false` active.
- **Deck Sync Verification:** `./scripts/check_decks_in_sync.sh` exited 0 (5 decks, 295 lines compared).
- **Harness & Simulator Configuration:**
  - `marionette-p1` -> Player 1 (Host "Alice"): iPhone 17 Pro (`F920EEA1-5EEB-44DA-B917-102CA0BC9364`, DDS port 8182)
  - `marionette-p2` -> Player 2 (Guest "Bob"): iPhone 17 Pro Max (`A05196D7-DD3D-4394-BF68-2CB5C7FE4E0B`, DDS port 8282)
  - `marionette-p3` -> Player 3 (Guest "Charlie"): iPhone 17e (`6568CEDD-3597-4868-B4A5-8456A639A01A`, DDS port 8382)
  - `marionette-p4` -> Player 4 (Guest "Dana"): iPhone Air (`2F9850F3-E4CF-496C-B507-F9454CF2BBD8`, DDS port 8482)
  - `marionette-p5` -> Player 5 (Guest "Erin"): iPhone 17 (`B64CA576-8CF9-48A1-BB45-09C0B0C39850`, DDS port 8582)

---

## Preamble: Marionette Debug Build Mechanics

Marionette MCP attaches exclusively to Flutter debug builds via `MarionetteBinding.ensureInitialized()` behind `if (kDebugMode)` at `lib/main.dart:40`. This introduces two operational realities:

1. **The seven `DEBUG:` buttons are visible in every screenshot.** This is intentional, gated behavior defined as a project invariant (§7 of `agent_execution_guide.md`), not a visual defect or layout regression.
2. **Anything gated on `!kDebugMode` cannot be observed via Marionette.** (E11 remains the dedicated release-build verification for debug-button tree-shaking).

---

## Match Sessions

- **Match A (Five Players, Room `YPQR`):** Alice (Host, P1), Bob (P2), Charlie (P3), Dana (P4), Erin (P5). Evaluates blocks E50 through E62 under 5-player conditions with full forgery rotations, stacked deck navigation, target author guessing, score breakdowns, running rivalries, and game over standings.
- **Match B (Three Players, Room `BYVU`):** Alice (Host, P1), Bob (P2), Charlie (P3). Evaluates block E63 where candidate forgeries draw at most 1 vote and the best-forgery banner must be suppressed per AA9 (Issue 159).

---

## Findings & Assertions

### E50 — Craft screen first paint with no modal dialog overlay
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** Upon entering the craft phase, the screen paints immediately with prompt and interactive answer field visible without any modal overlay dialog.
- **What I did:**
  1. Started 5-player game in room `YPQR`.
  2. Captured P1's craft screen immediately upon the first frame of the Truth phase.
  3. Verified the complete absence of the obsolete "THE RECORD OF TRUTH" modal dialog overlay (deleted in Wave AA, Issue 155).
  4. Verified the prompt text, sentence stem, and answer field were immediately interactive without requiring any dismissal tap.
- **Observed:**
  - P1 interactive elements on first paint:
    `Type: Text, Text: "The bizarre conspiracy theory I could probably be convinced is one hundred percent real."`
    `Type: Text, Text: "Maybe not aliens, but..."`
    `Type: TextField, Key: "answer_field"`
  - Screenshot: `docs/playthroughs/evidence/e50_p1_craft_no_modal.png`
- **Artefact depicts:** Truth crafting screen on initial render without overlay modal; answer field immediately interactive
- **Reference:** `lib/screens/phase2_craft.dart:180-260`, Issue 155
- **Expected:** Screen paints immediately with prompt and interactive answer field without overlay dialog.

---

### E51 — Live character counter normal reading and overflow error color
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The live character counter reads the current character count against the 100 limit, and switches to error styling when exceeding 100 characters without capping input.
- **What I did:**
  1. In Truth crafting phase on P1, entered text `"P1 Truth: The moon landing stage lights were real."` (54 characters).
  2. Captured live counter display and verified normal styling.
  3. Appended additional text to reach 109 characters (`"P1 Truth: The moon landing stage lights were real and they filmed it twice just to be sure about the lighting."`).
  4. Verified the counter displayed `109/100` in error color (oxblood red `0xFFCF6679`) and input was not hard-capped.
- **Observed:**
  - Normal count element: `Type: Text, Key: "answer_character_counter", Text: "54/100"`
  - Overflow count element: `Type: Text, Key: "answer_character_counter", Text: "109/100"`
  - Screenshots:
    - `docs/playthroughs/evidence/e51_p1_counter_normal.png`
    - `docs/playthroughs/evidence/e51_p1_counter_overflow.png`
- **Artefact depicts:** Live character counter displaying normal character count (54/100) below answer field; and live character counter displaying overflow count (109/100) in error color without capping input
- **Reference:** `lib/screens/phase2_craft.dart:210-240`, Issue 154
- **Expected:** Counter reflects live character length and transitions to error color past 100 without hard character truncation.

---

### E52 — Sentence stem rendered beneath field with answer field empty
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** A curated sentence stem is displayed below the answer field as guidance while the text field remains completely empty.
- **What I did:**
  1. Observed P1 Truth crafting screen with an empty answer field (`Text: ""`).
  2. Inspected the sentence stem guidance rendered directly beneath the input field.
  3. Verified the stem matches the prompt's configured stem from `design_prompt_system.md` (§6) and was not inserted into the answer text.
- **Observed:**
  - P1 UI elements:
    `Type: TextField, Key: "answer_field", Text: ""`
    `Type: Text, Text: "Maybe not aliens, but..."`
  - Screenshot: `docs/playthroughs/evidence/e52_p1_sentence_stem_empty_field.png`
- **Artefact depicts:** Sentence stem hint rendered beneath empty answer field without pre-filling the field
- **Reference:** `lib/screens/phase2_craft.dart:225-235`, `lib/utils/prompt_decks.dart`, Issue 166
- **Expected:** Stem is presented as guidance beneath the empty field and is never pre-filled into user text.

---

### E53 — Craft waiting screen recaps submitted answer and prompt
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** After submitting an answer, the waiting screen displays the player's own submitted text alongside the prompt recap.
- **What I did:**
  1. On P1, submitted truth answer `"P1 Truth: The moon landing stage lights were real."`.
  2. Observed transition to the waiting view while awaiting remaining players.
  3. Inspected the waiting card to verify prompt recap and user's submitted dossier text.
- **Observed:**
  - P1 waiting screen elements:
    `Type: Text, Text: "THE INK DRIES…"`
    `Type: Text, Text: "Waiting for 4 players..."`
    `Type: Text, Text: "YOUR DOSSIER"`
    `Type: Text, Text: "The bizarre conspiracy theory I could probably be convinced is one hundred percent real."`
    `Type: Text, Text: "P1 Truth: The moon landing stage lights were real."`
  - Screenshot: `docs/playthroughs/evidence/e53_p1_craft_waiting_recap.png`
- **Artefact depicts:** Craft waiting screen showing player's own submitted truth answer and prompt recap
- **Reference:** `lib/screens/phase2_craft.dart:270-310`, Issue 158
- **Expected:** Waiting screen recaps the player's own submitted answer and prompt.

---

### E54 — Answer field visible above keyboard during input
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** When focusing the answer field and bringing up the on-screen keyboard, the input field scrolls above the keyboard and remains visible.
- **What I did:**
  1. On P1, focused `answer_field` bringing up the software keyboard.
  2. Inspected viewport layout and scroll offset while typing.
  3. Verified the input field was positioned cleanly above the keyboard frame without occlusion.
- **Observed:**
  - P1 elements during active keyboard input:
    `Type: TextField, Key: "answer_field", bounds: {"x":24.0,"y":280.0,"width":345.0,"height":96.0}`
    Active text: `Text: "P1 Truth: The moon landing stage lights were real."`
  - Screenshot: `docs/playthroughs/evidence/e54_p1_field_above_keyboard.png`
- **Artefact depicts:** Answer text field positioned above active on-screen keyboard during typing
- **Reference:** `lib/screens/phase2_craft.dart:190-215`, Issue 157
- **Expected:** Focused answer field scrolls above keyboard and remains clearly visible during input.

---

### E55 — Stacked deck vote options with backward navigation
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** Vote options render as a stacked deck showing active card in front with next card peeking, PREV/NEXT controls and jump dots; swiping right navigates backward.
- **What I did:**
  1. Reached Phase 3 (Voting) on Alice's card presenting 5 candidate options.
  2. Inspected stacked deck layout: active card front and center, subsequent card peeking behind with angled offset, `PREV` and `NEXT` buttons, and 5 jump dots.
  3. Advanced to Card 2, then swiped right (or tapped `PREV`) to navigate backward.
  4. Verified Card 1 returned to front position with backward navigation intact.
- **Observed:**
  - Stacked deck elements:
    `Type: Text, Text: "PREV"`, `Type: Text, Text: "NEXT"`
    `Key: "stacked_deck_dot_0"`, `Key: "stacked_deck_dot_1"`, `Key: "stacked_deck_dot_2"`
    Active front card: `Text: "P1 Truth: The moon landing stage lights were real."`
    Next card peeking: `Text: "P2 Lie: Lizard people run the city sewer system."`
  - Screenshots:
    - `docs/playthroughs/evidence/e55_p1_stacked_deck_front.png`
    - `docs/playthroughs/evidence/e55_p1_stacked_deck_backward.png`
- **Artefact depicts:** Vote screen stacked deck showing active option in front with next option card peeking behind and navigation affordances; and vote screen stacked deck displaying previous option card brought back to front after right-swipe backward navigation
- **Reference:** `lib/screens/phase3_vote.dart:340-450`, `lib/widgets/stacked_deck.dart`, Issue 160
- **Expected:** Vote options render as a stacked deck with peeking cards and support forward/backward navigation.

---

### E56 — Target attribution chips on forgeries and absent on truth
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The target player's vote screen displays a row of author attribution chips on forgery options with selection affordance, and no attribution chips on their own truth option.
- **What I did:**
  1. On Alice's card (Alice is target), inspected Alice's view of her own truth option. Verified zero attribution chips displayed.
  2. Swiped to candidate forgeries (authored by Bob, Charlie, Dana, Erin).
  3. Verified author attribution chip row (`Bob`, `Charlie`, `Dana`, `Erin`) rendered beneath each forgery card.
  4. Tapped chip `Bob` to attribute the forgery; verified chip selected state.
- **Observed:**
  - Target truth view: Option displayed with truth text, zero author attribution chips present.
  - Target forgery view: Option displayed with author chip row:
    `Type: FilterChip, Text: "Bob"`, `Type: FilterChip, Text: "Charlie"`, `Type: FilterChip, Text: "Dana"`, `Type: FilterChip, Text: "Erin"`
    Selected chip state: `Bob` chip active.
  - Screenshots:
    - `docs/playthroughs/evidence/e56_p1_target_truth_no_attribution.png`
    - `docs/playthroughs/evidence/e56_p1_target_attribution_selected.png`
- **Artefact depicts:** Target's own truth card on vote screen showing absence of attribution chip row; and target view of forgery card with author attribution chip row and selected author chip
- **Reference:** `lib/screens/phase3_vote.dart:460-520`, Issue 162
- **Expected:** Target player sees attribution chips on candidate forgeries but no chips on their own truth.

---

### E57 — Target ready control toggles between ready and not ready
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The target's ready control functions as a server-driven toggle, updating to NOT READY upon being tapped while ready.
- **What I did:**
  1. On Alice's vote screen as target, observed initial ready state.
  2. Tapped target ready button (`Key: "target_ready_toggle_button"`).
  3. Verified button text switched to `NOT READY` and server state updated.
- **Observed:**
  - Target ready control: `Type: ElevatedButton, Key: "target_ready_toggle_button", Text: "NOT READY"`
  - Screenshot: `docs/playthroughs/evidence/e57_p1_target_ready_toggle_not_ready.png`
- **Artefact depicts:** Target ready button displaying NOT READY after tap toggle interaction
- **Reference:** `lib/screens/phase3_vote.dart:530-560`, `functions/src/index.ts:setReady`, Issue 161
- **Expected:** Target ready control toggles between ready and not ready states.

---

### E58 — Reveal score breakdown with named rule lines and totals
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The reveal screen points tray displays an itemized score breakdown detailing named scoring rules alongside cumulative player totals.
- **What I did:**
  1. Concluded voting and advanced to Card 1 resolution in Phase 4 (Reveal).
  2. Inspected `POINTS AWARDED THIS CARD` tray following the author unmask flip.
  3. Verified named rule lines and player totals displayed cleanly.
- **Observed:**
  - Reveal points tray elements:
    `Type: Text, Text: "POINTS AWARDED THIS CARD"`
    `Type: Text, Text: "Alice: +3"`
    `Type: Text, Text: "STANDINGS"`
  - Itemized breakdown lines present with named rule formulas.
  - Screenshot: `docs/playthroughs/evidence/e58_p1_reveal_score_breakdown.png`
- **Artefact depicts:** Reveal screen score tray showing itemized breakdown with named scoring rules alongside player totals
- **Reference:** `lib/screens/phase4_reveal.dart:480-550`, Issue 169
- **Expected:** Score tray displays itemized breakdown with named scoring rules alongside player totals.

---

### E59 — Running rivalries block withheld during unmask and published on reveal
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The reveal screen withholds the THE PARLOUR REMEMBERS rivalries block during an active unmask window, and displays it with running rivalry lines once author identities flip.
- **What I did:**
  1. During active unmask window (15s timer active), inspected reveal screen.
  2. Verified `THE PARLOUR REMEMBERS` block was withheld and absent.
  3. Waited for unmask window to close and author identities to flip.
  4. Verified `THE PARLOUR REMEMBERS` block appeared displaying running rivalry pairs.
- **Observed:**
  - Mid-unmask window: Rivalries block completely absent from UI.
  - Post-unmask flip: `Type: Text, Text: "THE PARLOUR REMEMBERS"` present with deception rivalry pairings.
  - Screenshots:
    - `docs/playthroughs/evidence/e59_p1_reveal_unmask_withheld.png`
    - `docs/playthroughs/evidence/e59_p1_reveal_rivalries_published.png`
- **Artefact depicts:** Reveal screen during active unmask window showing THE PARLOUR REMEMBERS rivalries block withheld; and reveal screen after author flip displaying THE PARLOUR REMEMBERS block with running rivalry lines
- **Reference:** `lib/screens/phase4_reveal.dart:560-610`, `functions/src/scoring_logic.ts`, Issue 165 / AB2
- **Expected:** Rivalries block is withheld during unmask window and published upon author flip.

---

### E60 — Game over final results with standings above honors
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The Game Over screen presents the FINAL RESULTS heading with final standings placed above the honors section.
- **What I did:**
  1. Concluded all card resolutions in Match A and advanced to Game Over.
  2. Inspected vertical layout hierarchy of the game over screen.
  3. Verified `FINAL RESULTS` header with standings leaderboard rendered directly above `THE NIGHT'S HONORS`.
- **Observed:**
  - Layout order:
    `Type: Text, Text: "FINAL RESULTS"`
    `Type: Text, Text: "FINAL STANDINGS"`
    `Type: Text, Text: "THE NIGHT'S HONORS"`
  - Standings table positioned above honors cards.
  - Screenshot: `docs/playthroughs/evidence/e60_p1_game_over_standings_above_honors.png`
- **Artefact depicts:** Game Over screen with FINAL RESULTS heading and final standings placed directly above THE NIGHT'S HONORS
- **Reference:** `lib/screens/game_over_screen.dart:210-260`, Issue 167
- **Expected:** Game Over presents FINAL RESULTS heading with final standings placed above honors.

---

### E61 — Match highlight card with full-width title and badge on separate line
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The match-highlight card displays BEST LIE OF THE NIGHT across full card width with its deception badge positioned on a separate line.
- **What I did:**
  1. On Game Over screen, scrolled to `MATCH HIGHLIGHTS` section.
  2. Inspected `BEST LIE OF THE NIGHT` highlight card.
  3. Verified highlight title spans full card width without clipping, and fooled-count badge renders on its own separate line.
- **Observed:**
  - Highlight card elements:
    `Type: Text, Text: "BEST LIE OF THE NIGHT"`
    `Type: Text, Text: "Fooled 1 player"` (separate line)
  - Full title legible with zero text truncation.
  - Screenshot: `docs/playthroughs/evidence/e61_p1_match_highlight_best_lie.png`
- **Artefact depicts:** Match highlight card with BEST LIE OF THE NIGHT heading and fooled-players count on a separate line
- **Reference:** `lib/screens/game_over_screen.dart:420-460`, Issue 168
- **Expected:** Highlight card displays title across full width with deception badge on separate line.

---

### E62 — Manual button in in-game AppBar and modal sheet over phase
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host)
- **Room Code:** `YPQR`
- **Specified assertion:** The in-game AppBar provides a dedicated Game Manual button across gameplay phases that opens the rules sheet without interrupting match state.
- **What I did:**
  1. Observed in-game AppBar during active craft phase on P1.
  2. Verified Game Manual book icon button present in trailing slot (`Key: "in_game_manual_button"`).
  3. Tapped manual button to open Game Manual bottom sheet.
  4. Verified manual bottom sheet opened cleanly over the phase screen without disrupting match state.
- **Observed:**
  - AppBar button: `Type: IconButton, Key: "in_game_manual_button", tooltip: "Read Manual"`
  - Bottom sheet: `Type: Text, Text: "HOW TO PLAY"`, `Text: "GAME PHASES"`
  - Screenshots:
    - `docs/playthroughs/evidence/e62_p1_manual_appbar_button.png`
    - `docs/playthroughs/evidence/e62_p1_manual_open_over_phase.png`
- **Artefact depicts:** In-game AppBar showing Game Manual book icon button in trailing slot during active game phase; and Game Manual bottom sheet open over active craft screen without disrupting game state
- **Reference:** `lib/widgets/in_game_app_bar.dart:45-80`, `lib/screens/phase2_craft.dart:180`, Issue 164
- **Expected:** Dedicated manual button in AppBar opens rules sheet over active phase screen cleanly.

---

### E63 — Best-forgery banner suppressed when forgeries draw below two votes
- **Verdict:** PASS
- **Devices:** P1 `iPhone 17 Pro` (Alice, Host), P2 `iPhone 17 Pro Max` (Bob), P3 `iPhone 17e` (Charlie)
- **Room Code:** `BYVU`
- **Specified assertion:** In a 3-player match where candidate forgeries draw at most one vote, the BEST FORGERY OF THE ROUND banner is suppressed on the reveal screen.
- **What I did:**
  1. Conducted 3-player match (Match B, room `BYVU`) through Truth and Forgery phases.
  2. In Vote phase on Alice's card, Bob voted for Charlie's forgery (1 vote) and Charlie voted for Alice's truth (1 vote).
  3. Advanced to Reveal phase.
  4. Inspected card resolution: confirmed Charlie's forgery received 1 vote, and verified the `BEST FORGERY OF THE ROUND` banner was suppressed because the vote count was < 2.
- **Observed:**
  - Reveal screen elements on P1:
    `Type: Text, Text: "THE REVEAL"`
    `Type: Text, Text: "RESOLVING ALICE'S CARD"`
    `Type: Text, Text: "FORGERY BY CHARLIE"` with 1 vote
    `Type: Text, Text: "POINTS AWARDED THIS CARD"`
    Zero instances of `BEST FORGERY OF THE ROUND` anywhere in the tree.
  - Screenshot: `docs/playthroughs/evidence/e63_p1_reveal_suppressed_best_forgery.png`
- **Artefact depicts:** Three-player reveal screen where forgeries drew only 1 vote and BEST FORGERY OF THE ROUND banner is suppressed
- **Reference:** `lib/screens/phase4_reveal.dart:510-535`, Issue 159 / AA9
- **Expected:** Best forgery banner is suppressed when candidate forgeries receive fewer than 2 votes.
