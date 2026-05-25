# Ongoing General Errors & Engineering History

## Overview
This document tracks the technical engineering history, resolved issues, and unresolved limitations for the Phase 4 Mimicry Edition of Gaslight.

---

## 🧪 Resolved Issues & Implementation Refinements

1. **Bot Readiness Bottleneck (Resolved - May 24)**:
   - **Problem**: `GameService.setPlayerReady` was hardcoded to only update the local `_currentPlayerId`, which blocked bot advancement during E2E simulation.
   - **Solution**: Modified `setPlayerReady` to accept an optional `playerId`, allowing the simulation and bots to correctly signal readiness.

2. **Vote Attribution Error (Resolved - May 24)**:
   - **Problem**: `GameService.castVote` was incorrectly marking the *target* or the *local host* as ready instead of the actual `voterId` passed into the method.
   - **Solution**: Refactored `castVote` to pass the `voterId` to `setPlayerReady`, ensuring individual bot progress is tracked.

3. **Redundant Scaling Logic & Display Mismatch (Resolved - May 24)**:
   - **Problem**: The `Phase4RevealScreen` was attempting to apply score deltas in the UI layer, while the `GameService` was also calculating them during phase transitions. This created potential double-score increments and race conditions.
   - **Solution**: Centralized all scoring mutations into `GameService._advanceRotationOrPhase`. The UI now only reads `ScoringLogic` for local display/highlighting without triggering DB writes.

4. **UI Overflow in Phase 4 (Resolved - May 24)**:
   - **Problem**: Using a `Row` to display voter chips in the Reveal screen caused an overflow when 5+ players voted for the same option.
   - **Solution**: Replaced `Row` with `Wrap` to handle any player count gracefully.

5. **Firestore Listener Leaks (Resolved - May 24)**:
   - **Problem**: `GameService.listenToRoom()` established stream listeners for game state and player sub-documents without keeping references to the subscriptions, causing subscriptions to leak and conflict when room changes occurred.
   - **Solution**: Added stream subscription fields `_roomSubscription` and `_playersSubscription` inside `GameService`, ensuring previous streams are cancelled before starting new ones and during `dispose()`.

6. **No Session Persistence / Rejoin Mechanism (Resolved - May 24)**:
   - **Problem**: Player IDs were generated fresh on every screen load, making rejoining impossible if the app restarted, which left ghost players stuck in Firestore.
   - **Solution**: Integrated `SharedPreferences` to save `roomCode` and `playerId`. Added `tryRejoinSession()` to check and restore sessions upon app start.

7. **`totalPlayers` Scoring Miscalculation (Resolved - May 24)**:
   - **Problem**: `GameState.totalPlayers` was not correctly synced when games started, leading to incorrect calculations using the default value of 4.
   - **Solution**: Ensured `totalPlayers: _players.length` is synchronized in the `startGame` update payload.

8. **Double Score Application (Resolved - May 24)**:
   - **Problem**: Points were calculated separately on both the transition from Vote to Reveal and on the Reveal screen itself, introducing a risk of double-applying scores if the UI triggered DB writes.
   - **Solution**: Restructured the UI in `Phase4RevealScreen` to render points locally from `_latestDeltas` calculated during reveal init, and added warning comments to prevent UI-driven DB scoring writes.

9. **Stale Shuffled Answers on Reader Change (Resolved - May 24)**:
   - **Problem**: `Phase3VoteScreen` cached shuffled answers in a local variable without checking if the active reader changed, causing players to see and vote on answers from the previous card.
   - **Solution**: Tracked `_shuffledCardId` inside the state and forced a regeneration/reshuffle of answers whenever the `currentReaderId` changes.

10. **No `_isNavigating` Reset After Navigation (Resolved - May 24)**:
    - **Problem**: Game screens set `_isNavigating` to prevent double-navigation but never reset it, permanently disabling navigation if players went back.
    - **Solution**: Standardized the build logic to set `_isNavigating = false` whenever the screen's target phase matches the game state's active phase.

11. **Race Condition in `evaluateReadyState` (Resolved - May 24)**:
    - **Problem**: Host evaluation of player readiness was susceptible to race conditions when multiple players marked ready concurrently, leading to double phase advancement.
    - **Solution**: Implemented an in-memory set `_advancedStateKeys` tracking unique state hashes (`roomCode_phase_rotationIndex_readerId`) to ensure each state is only advanced once.

12. **Gemini API Key Exposed in Client-Side HTTP Requests (Resolved - May 24)**:
    - **Problem**: The Gemini API key was passed as a query parameter in the GET request URL, making it visible in browser network inspectors and proxies.
    - **Solution**: Removed the API key query parameter from the request URL and sent it securely in the HTTP POST headers via the `x-goog-api-key` header.

13. **No Firestore Room/Player Cleanup (Resolved - May 24)**:
    - **Problem**: Exiting the game did not delete player or room records from Firestore, accumulating orphaned records.
    - **Solution**: Implemented `leaveRoom()` in `GameService` to delete the player's document, delete the room if empty, cancel subscriptions, and clear stored session keys.

14. **`AutoAdvanceTimer` Widget Defined But Never Used (Resolved - May 24)**:
    - **Problem**: The `AutoAdvanceTimer` countdown widget was implemented but never instantiated on any active gameplay screens.
    - **Solution**: Rendered `AutoAdvanceTimer` inside the AppBar action slot of `Phase2CraftScreen` and `Phase3VoteScreen`, and added a `forceAdvance` host method.

15. **Host-Only Phase Advancement Creates Single Point of Failure (Resolved - May 24)**:
    - **Problem**: Phase transitions were strictly host-gated, meaning if a host disconnected, the game was permanently stuck.
    - **Solution**: Added a 5-second periodic heartbeat updating player `lastSeen` in Firestore, and auto-cleaned players inactive for 15+ seconds, which triggers host transfer if the host leaves.

16. **Mid-Game Join State Corruption (Resolved - May 25)**:
    - **Problem**: Players joining a game in progress corrupted the state because they were treated as active players but lacked cards/prompts.
    - **Solution**: Implemented Spectator Mode (Option B). Late-joining players are assigned `PlayerRole.spectator`. Screen UIs (`Phase2CraftScreen` and `Phase3VoteScreen`) show beautiful spectator views, and their readiness/voting is ignored in gameplay calculations.

17. **Mid-Game Disconnect Card Orphans (Resolved - May 25)**:
    - **Problem**: When players disconnected mid-game, their cards and rotations remained, causing dead voting rounds or crashes.
    - **Solution**: Implemented Dynamic Rotation Recalculation (Option B). The host detects player deletion, bridges card assignments (bypassing the departed player), recalculates future sabotage rotation plans dynamically, and auto-advances the card reader.

18. **Direct Client-Side Firestore Mutation Security Risks (Resolved - May 25)**:
    - **Problem**: Client applications wrote directly to Firestore without server-side validation or checks.
    - **Solution**: Defined `firestore.rules` (Option A) enforcing write validations based on user authentication, restricting room changes to the host, and restricting player document changes to the owner (except for host cleanup).

---

## ⚠️ Unresolved Issues & Suggestions

None. All previously identified issues have been resolved.
