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
