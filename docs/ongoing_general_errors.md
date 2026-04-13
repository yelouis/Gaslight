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

## 2. Unresolved E2E Errors (Current)

- **ALL ERRORS RESOLVED.** The 10-player E2E simulation passed with 0 crashes. Final scores were mathematically verified against expected values (Host: 9, Bots: 19) for a 10-player/2-Sabotage configuration.

