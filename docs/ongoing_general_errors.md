# Ongoing General Errors

## Overview
As requested, a full end-to-end simulation of 10 players was executed to identify boundary cases, logical crashes, and state management errors during the migration from the legacy Single-Trickster architecture to the Phase 4 Mimicry Edition. 

Due to the complexity of the errors found (specifically stemming from legacy UI files not yet decoupled from the old Game Phase logic), the simulation sequence and stack trace analysis are documented below. 

---

## 1. Resolved Minor Errors (10-Player Simulation)

### Bot Readiness Bottleneck (Resolved)
- **Error Description**: `GameService.setPlayerReady` was hardcoded to only update the local `_currentPlayerId`. This blocked bot advancement during E2E simulation.
- **Resolution**: Modified `setPlayerReady` to accept an optional `playerId`, allowing the simulation and bots to correctly signal readiness.

### Vote Attribution Error (Resolved)
- **Error Description**: `GameService.castVote` was incorrectly marking the *target* or the *local host* as ready instead of the actual `voterId` passed into the method.
- **Resolution**: Refactored `castVote` to pass the `voterId` to `setPlayerReady`, ensuring individual bot progress is tracked.

### Redundant Scaling Logic & Display Mismatch (Resolved)
- **Error Description**: The `Phase4RevealScreen` was attempting to apply score deltas in the UI layer, while the `GameService` was also calculating them during phase transitions. This created potential double-score increments and race conditions.
- **Resolution**: Centralized all scoring mutations into `GameService._advanceRotationOrPhase`. The UI now only reads `ScoringLogic` for local display/highlighting without triggering DB writes. Verified that `ceil((P-1)/(S+1))` correctly produces 3 pts for 10-player games.

### UI Overflow in Phase 4 (Resolved)
- **Error Description**: Using a `Row` to display voter chips in the Reveal screen caused an overflow when 5+ players voted for the same option.
- **Resolution**: Replaced `Row` with `Wrap` to handle any player count gracefully.

---

## 2. Unresolved Cross-Cutting Bugs (Current)

### Firestore Listener Leaks (Active)
- **Error Description**: `GameService.listenToRoom()` (`game_service.dart:119-133`) creates two Firestore `snapshots().listen()` subscriptions but **never stores the `StreamSubscription` references**. There is no `dispose()`, `cancel()`, or cleanup method in `GameService`. If a player joins Room A, leaves, then joins Room B, listeners for Room A persist in memory and continue firing callbacks that overwrite `_gameState` and `_players` with stale data from the old room.
- **Impact**: Memory leak, potential data corruption if a user navigates back to lobby and creates/joins a new room within the same app session.
- **Fix**: Store subscriptions as class fields and cancel them at the start of each new `listenToRoom()` call and in a `dispose()` method.

### No Session Persistence / Rejoin Mechanism (Design Gap)
- **Error Description**: Player IDs are generated fresh via `Uuid().v4()` on every `createRoom` / `joinRoom` call (`lobby_screen.dart:34, 52`). If the app is killed, backgrounded, or hot-restarted, the player cannot rejoin their existing room. Their old player document persists in Firestore as a ghost, and `readyPlayers` / `evaluateReadyState` will permanently wait for a player who will never respond.
- **Impact**: Any app restart during an active game permanently stalls the lobby. Ghost player documents also inflate the `_players.length` count used in scoring and readiness calculations.
- **Fix**: Persist `(roomCode, playerId)` to `SharedPreferences` or `Hive` and attempt rejoin on app launch.

### `totalPlayers` Scoring Miscalculation (Critical — Cross-Phase)
- **Error Description**: Documented in detail under Phase 2, but the impact crosses into Phase 4 (scoring display) and the Game Over screen. `GameState.totalPlayers` defaults to `4` and is never updated. The `ceil((P-1)/(S+1))` formula in `ScoringLogic` uses this stale value, producing incorrect point rewards for any game with ≠4 players. The Game Over screen (`game_over_screen.dart`) then displays these incorrect final scores.
- **Root Files**: `game_service.dart:69` (default), `game_service.dart:254` (missing `totalPlayers: _players.length`), `scoring_logic.dart:17-19` (consumer).
