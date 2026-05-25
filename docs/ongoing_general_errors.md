# Ongoing General Errors & Engineering History

## Overview
This document tracks key engineering insights, regression-risk pitfalls, and historical system updates for Gaslight. Major architectural design layers are documented in dedicated system design files under `docs/`.

---

## 🧪 Resolved Issues & Implementation Refinements

1. **Race Condition in `evaluateReadyState` (Resolved - May 24)**:
   - **Problem**: Host evaluation of player readiness was susceptible to race conditions when multiple players marked ready concurrently, leading to duplicate phase advancements.
   - **Solution**: Implemented an in-memory set `_advancedStateKeys` tracking unique state hashes (`roomCode_phase_rotationIndex_readerId`) to ensure each state is only advanced once.
   - **Regression Warning**: Any changes to state evaluation must check `_advancedStateKeys` to prevent double-navigation bugs.

2. **Firestore Listener Leaks (Resolved - May 24)**:
   - **Problem**: Stream listeners for game state and player sub-documents were instantiated without keeping subscription handles, causing them to leak and duplicate on re-joins.
   - **Solution**: Added stream subscription fields `_roomSubscription` and `_playersSubscription` inside `GameService`, ensuring previous streams are cancelled before starting new ones and during `dispose()`.

3. **API Key Exposure & Transactional Integrity (Resolved - May 24/25)**:
   - **Problem**: API keys were previously passed in request URLs. Additionally, concurrent client writes could bypass similarity checks.
   - **Solution**: Moved the API key to the `x-goog-api-key` HTTP header. Applied Firestore transaction blocks around all card answer submissions.

4. **Host-Only Phase Advancement Failure (Resolved - May 24)**:
   - **Problem**: If a host disconnected, phase transitions were permanently frozen.
   - **Solution**: Added a 5-second periodic heartbeat updating player `lastSeen` in Firestore. The host prunes inactive players, and players automatically trigger host transfer if the host document is deleted.

5. **Mid-Game Join State Corruption & Spectator Mode (Resolved - May 25)**:
   - **Problem**: Players joining a game in progress corrupted active player card queues.
   - **Solution**: Late-joining players are assigned `PlayerRole.spectator` and shown passive spectator UIs, and are filtered out of all gameplay loops and readiness calculations.

6. **Mid-Game Disconnect Card Orphans & Recalculation (Resolved - May 25)**:
   - **Problem**: Inactive or disconnected players left orphan cards in the rotation plan.
   - **Solution**: Host bridges the card assignments (bypassing the departed player), dynamically regenerates rotations using `RotationEngine`, and auto-advances the reader.

---

## ⚠️ Unresolved Issues & Suggestions

### Issue 1: Redundant Phase Numbering Mismatches in UI and Routing
**Status**: ⚠️ Confirmed Unresolved — Verified in `lobby_screen.dart` (lines 123-125), `phase3_vote.dart` (line 109), and `phase4_reveal.dart` (line 95). The system currently mixes filename numbering (e.g. `phase2_craft.dart`), conceptual phase numbering in instructions (e.g. "Phase 1 (Sabotage)"), and screen headers (e.g. "PHASE 3: THE VOTE").

**Option A (recommended)**: **Remove Phase Numbers and Standardize Titles** — Standardize all screen titles and instructions to use descriptive titles only ("SABOTAGE", "TRUTH", "THE VOTE", "THE REVEAL") and completely eliminate numbers.
  - *Pros*: Avoids confusing numbering mismatches and keeps the UI clean and premium.
  - *Cons*: Requires minor edits in screens and instructions.

**Option B**: **Align Numbering System-Wide** — Rewrite all screens, routes, and instructions to follow a single consecutive sequence (e.g., Phase 1: Sabotage, Phase 2: Truth, Phase 3: Vote, Phase 4: Reveal).
  - *Pros*: Preserves step-by-step numbering which some players might find helpful.
  - *Cons*: Numbers can become redundant as the screen titles are already descriptive.

Your selection: _____

---

### Issue 2: Gemini Star Spark Floating Background Animation
**Status**: ⚠️ Confirmed Unresolved — Verified in `thinking_background.dart` (lines 28-38): The particle generator is hardcoded to float '✦' and '✧' sparks (resembling the Gemini star logo symbols) up the screen, which doesn't fit the deduction/gaslight theme.

**Option A (recommended)**: **Transition to Mystery Glyphs** — Replace the floating star sparks with question marks, asterisks, or ancient glyphs ('?', '⚹', '¿') matching the Lora serif mystery theme of the game.
  - *Pros*: Reinforces the theme of deduction, secrets, and gaslighting.
  - *Cons*: Simple character change; does not add complex dynamic lighting effects.

**Option B**: **Implement Drifting Mist Shader Animation** — Replace the particle painter with overlapping animated radial gradients or low-opacity curves simulating floating "gaslight" vapor/smoke.
  - *Pros*: Extremely premium visual experience that directly fits the game title "Gaslight".
  - *Cons*: Higher rendering computational cost and implementation complexity.

Your selection: _____

---

### Issue 3: "Return to lobby" Action Freezes/Stalls on Rebuild
**Status**: ⚠️ Confirmed Unresolved — Verified in `game_over_screen.dart` (lines 74-82): When the host or a player clicks "RETURN TO LOBBY", the asynchronous method `gs.leaveRoom()` is invoked. During this call, the players list is cleared and the parent `watch<GameService>()` triggers a synchronous widget rebuild. Because the rebuild returns a `CircularProgressIndicator` instead of the original `Column`, the `TextButton` and its BuildContext are unmounted, preventing the subsequent routing code (`Navigator.pushNamedAndRemoveUntil`) from executing.

**Option A (recommended)**: **Capture Navigator State Before Async Call** — Capture the `NavigatorState` locally prior to the async call (`final nav = Navigator.of(context)`), then navigate using the captured reference.
  - *Pros*: Simple, safe, and completely avoids dependency on context remaining mounted.
  - *Cons*: None.

**Option B**: **Remove Rebuild Guard on Player Count** — Remove the early return `if (players.isEmpty)` that swaps the layout with a loading screen.
  - *Pros*: Prevents unmounting the button context during state changes.
  - *Cons*: Could lead to null or index errors on other widgets if the widget tree references empty lists during disposal.

Your selection: _____

---

### Issue 4: "Sabotage" Phase Name is Non-Descriptive
**Status**: ⚠️ Confirmed Unresolved — Verified in `game_state.dart` (line 3) and `game_service.dart` (line 568): The first writing phase is named `GamePhase.sabotage`, which is non-descriptive as the whole game is about sabotage, and it clashes conceptually with write actions in subsequent phases.

**Option A (recommended)**: **Rename to `mimicry` or `writeSabotage`** — Rename `GamePhase.sabotage` to `GamePhase.mimicry` system-wide to reflect the active writing task of copying others' styles.
  - *Pros*: Standardizes terminology and makes codebase logic much cleaner for new developers.
  - *Cons*: Requires extensive search-and-replace across multiple model, service, and screen files.

**Option B**: **Keep Database Schema and Update User Strings Only** — Retain the Firestore enum key as `sabotage` but change the user-facing text and headers to "THE DECEPTION" or "MIMICRY".
  - *Pros*: Avoids database key migrations or code search-replace.
  - *Cons*: Leaves conceptual clutter in the code and database document snapshots.

Your selection: _____

---

### Issue 5: Missing Simulator and Emulator Networking Instructions
**Status**: ⚠️ Confirmed Unresolved — Verified in `README.md` (lines 32-41): The documentation lacks setup guides for targeting emulators, troubleshooting connection configurations, and explaining host machine loopbacks (e.g. `10.0.2.2` for Android emulator networking).

**Option A (recommended)**: **Update README.md with Emulator & Network Setup Guide** — Add detailed instructions to `README.md` covering Android Studio Emulator/iOS Simulator execution, port forwarding, and local emulator loops.
  - *Pros*: Improves developer onboarding and reduces setup troubleshooting time.
  - *Cons*: None.

Your selection: _____

---

### Issue 6: No Option to Disable the Auto-Advance Timer
**Status**: ⚠️ Confirmed Unresolved — Verified in `lobby_screen.dart` and `game_service.dart`: The game loop enforces an auto-advance timer on the writing and voting screens. There is no setting to disable it for casual/relaxed game play.

**Option A (recommended)**: **Add a "Disable Timer" Option to Lobby** — Add a boolean `isTimerDisabled` to `GameState` and a checkbox in the lobby room options. If set, skip writing `endTime` and hide the timer widgets in game screens.
  - *Pros*: Fully configurable; supports both fast competitive play and casual play styles.
  - *Cons*: Requires database and lobby UI schema updates.

**Option B**: **Simply Increase Default Timers** — Set the default timer length to a high duration (e.g. 5 minutes) rather than adding option toggles.
  - *Pros*: Extremely low implementation complexity.
  - *Cons*: Does not actually disable the timer; visual countdown still remains on screen.

Your selection: _____
