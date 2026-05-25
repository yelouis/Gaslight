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

7. **Redundant Phase Numbering Mismatches in UI and Routing (Resolved - May 25)**:
   - **Problem**: The system mixed conceptual phase numbers, screen headers, and filename numbering, causing confusion.
   - **Solution**: Standardized all screen titles and instructions to use descriptive titles only ("FORGERY", "TRUTH", "THE VOTE", "THE REVEAL") and completely eliminated phase numbers.

8. **Gemini Star Spark Floating Background Animation (Resolved - May 25)**:
   - **Problem**: The particle generator floated '✦' and '✧' sparks resembling the Gemini star logo, which clashed with the gothic deduction theme of the game.
   - **Solution**: Replaced the particle character generator with mystery glyphs ('?', '⚹', '¿') matching the Lora serif theme.

9. **"Return to lobby" Action Freezes/Stalls on Rebuild (Resolved - May 25)**:
   - **Problem**: The button and its BuildContext unmounted during the async database cleanup call `leaveRoom()` before the routing animation could finish, freezing the screen.
   - **Solution**: Captured the `NavigatorState` locally prior to the async call and executed navigation on the captured state.

10. **"Sabotage" Phase Name is Non-Descriptive (Resolved - May 25)**:
    - **Problem**: The enum value `GamePhase.sabotage` clashed with the conceptual goal of the game and was non-descriptive.
    - **Solution**: Renamed `GamePhase.sabotage` to `GamePhase.forgery` system-wide and updated the UI titles, texts, and instructions accordingly.

11. **Missing Simulator and Emulator Networking Instructions (Resolved - May 25)**:
    - **Problem**: Development setup lacked instructions on routing emulator network requests (e.g. `10.0.2.2` for Android emulator loopback).
    - **Solution**: Updated `README.md` with detailed networking setup guidelines for Android Emulators, iOS Simulators, and physical devices.

12. **No Option to Disable the Auto-Advance Timer (Resolved - May 25)**:
    - **Problem**: The writing and voting screens had hardcoded auto-advance timers that could not be turned off for casual play.
    - **Solution**: Added an `isTimerDisabled` field to `GameState`, a configuration toggle in the lobby creation UI, and bypassed timer writes and visibility in game screens when active.

13. **Missing Anonymous Firebase Authentication (Resolved - May 25)**:
    - **Problem**: Secure `firestore.rules` required authentication, but the client never performed sign-in, resulting in write permission errors.
    - **Solution**: Integrated the `firebase_auth` dependency and initiated anonymous sign-in (`signInAnonymously()`) on app startup in `main.dart`.

14. **Gemini API Key Exposure in Client-Side Binary (Resolved - May 25)**:
    - **Problem**: The Gemini API key was loaded in client code and sent in HTTP headers, exposing it to extraction from production binaries.
    - **Solution**: Documented this exposure in `README.md` as a prototyping risk, detailing the migration path to a secure proxy server for production release.

15. **Firestore Heartbeat Write Volume Optimization (Resolved - May 25)**:
    - **Problem**: Player heartbeats ran every 5 seconds, causing excessive write volume and Firestore quota consumption in larger rooms.
    - **Solution**: Optimized the heartbeat interval to 10 seconds and player pruning threshold to 30 seconds inside `GameService`.

16. **Cache Bypass on Missing API Key in SemanticFilter (Resolved - May 25)**:
    - **Problem**: `SemanticFilter._getEmbedding()` checked for `GEMINI_API_KEY` and threw an exception before looking at `_vectorCache`. This caused offline test runs or mock injections to fail open, bypassing similarity filtering.
    - **Solution**: Reordered the logic in `_getEmbedding()` to perform the `_vectorCache` lookup first, bypassing API key checks and network requests for cached terms.
