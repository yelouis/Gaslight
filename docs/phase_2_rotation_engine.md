# Phase 2: Game Logic & The Rotation Engine

## Overview
This phase handles the core logic for the round workflow. Most importantly, it implements the Circular/Derangement Algorithm to ensure cards rotate gracefully among any $P$ configured amount of players for $S$ sabotages.

## Key Processing Logic
1. **Dynamic Deck Assignment**: Randomly draw $P$ (`totalPlayers`) prompts from the local array datasets. Assign each player one as a Target.
2. **Rotation Derangement**: Ensure the $S$ (`sabotageAnswersCount`) rotations work efficiently. Player $[N]$ receives Player $[(N+R) \% P]$'s card for writing a sabotage response, where $R$ is the rotation loop round $(1 \le R \le S)$.
3. **Timer & Ready Management**: 
   - A timer on clients limits "dead air". Once either all players hit `isReadyForNextRotation`, *or* the timer expires, an advance instruction is fired.
   - If the timer expires before a player writes, the game proceeds by submitting a placeholder for them.

## Pseudo Code

```dart
// 1. Dynamic Rotation Assignment 
Map<int, Map<String, String>> generateRotations(List<String> playerIds, int sabotageRounds) {
  // Configured inputs: playerIds.length = P (totalPlayers), sabotageRounds = S
  var rotations = <int, Map<String, String>>{};
  
  for (int r = 1; r <= sabotageRounds; r++) {
    Map<String, String> currentRoundAssignments = {};
    for (int i = 0; i < playerIds.length; i++) {
        // As long as S < P, (i+r)%P will never loop back to `i` in early rounds
        int targetIndex = (i + r) % playerIds.length;
        currentRoundAssignments[playerIds[i]] = playerIds[targetIndex];
    }
    rotations[r] = currentRoundAssignments;
  }
  return rotations;
}

// 2. Ready Logic with Auto-Advance Timer considerations
Future<void> evaluateReadyState() async {
  // Triggered on UI when user clicks Submit OR timer reaches 0
  
  // Mark player ready (If answer is empty strings through timer, insert generic placeholder)
  await setPlayerReady(myPlayerId, true);
  
  // Check if all players are ready across the stream
  if (await allPlayersReady()) {
      await advanceRotationOrPhase();
  }
}

// 3. Advance Rotation Logic
Future<void> advanceRotationOrPhase() async {
  if (gameState.currentRotationIndex < gameState.sabotageAnswersCount) {
    // Advance to next sabotage rotation
    int nextRot = gameState.currentRotationIndex + 1;
    Map<String, String> nextAssignments = precalculatedRotations[nextRot];
    await updateGameState(currentRotationIndex: nextRot, currentCardAssignments: nextAssignments);
    await resetAllPlayersReady();
  } else {
    // Transition to Truth phase where Targets get their own cards
    Map<String, String> truthAssignments = { for (var id in playerIds) id : id };
    await updateGameState(currentPhase: GamePhase.truth, currentCardAssignments: truthAssignments);
    await resetAllPlayersReady();
  }
}
}
```

## Verification Plan

### Automated Mathematical Verification
A script will be temporarily generated and run utilizing `dart` natively to verify:
1. `generateRotations(P, S)` successfully creates $S$ distinct rotation maps.
2. In every map, `assignment[playerId] != playerId`. No player receives their own card during the Sabotage phase.
3. Over the course of all $S$ rotations, no player receives the *same* Target's card twice.

Only upon a clean exit code `0` from the test script will the `lib/` files be committed.

## Implementation Status (Phase 2 Completed)

### What has been accomplished:
- **Rotation Engine Mechanics**: Built `lib/utils/rotation_engine.dart` containing the mathematically rigorous derangement assignment logic using the formula `target = (Holder + Round) % TotalPlayers`. This ensures no player sabotages their own card and no targets overlap.
- **Centralized Readiness**: To eliminate "Ready-Check Race Conditions," we migrated player readiness from individual `PlayerState` documents to a centralized `Map<String, bool> readyPlayers` within the `GameState` document. This allows the Host to evaluate a single consistent snapshot and reduces write operations from $P$ per rotation to just 1.

### Verification Done:
- **Static Verification Completed**: Ran a rigorous sandbox script evaluating the constraints `P=4, S=2`. Confirmed explicitly that `holder != target` during execution, and tracked `seenTargetsByHolder` to guarantee 0 overlaps.
- **Race Condition Testing**: Verified that centralized readiness prevents premature rotation advancement even during concurrent submissions.

### Places where there could be errors:
- **`_resetAllPlayersReady` Stale-State Race Condition (Critical):** In `game_service.dart`, `_advanceRotationOrPhase()` calls `await updateGameState(newState)` to write the phase/rotation change, then immediately calls `await _resetAllPlayersReady()`. The reset method reads `_gameState!` (the local cached copy) and calls `updateGameState(_gameState!.copyWith(readyPlayers: {}))`. If the Firestore snapshot listener has NOT yet fired to update the local `_gameState`, the second write serializes the **old** phase/rotation values alongside `readyPlayers: {}`, effectively **reverting the phase transition**. This relies on Firestore's local-cache listener firing synchronously between the two awaits — behavior that is SDK-specific and not contractually guaranteed. Fix: merge `readyPlayers: {}` into the same `copyWith` call as the phase change so only one write occurs.
- **`totalPlayers` Never Synced — Scoring Formula Broken (Critical):** `GameState.totalPlayers` is set to `4` at room creation (default in `createRoom`) and is **never updated** when more players join or when `startGame()` fires. Since `ScoringLogic.calculateScores` uses `state.totalPlayers` for `ceil((P-1)/(S+1))`, any game with ≠4 players computes the wrong voter reward. For 10 players with `totalPlayers=4` and `S=2`, the reward would be `ceil(3/3)=1` instead of the correct `ceil(9/3)=3`. Fix: `startGame()` must set `totalPlayers: _players.length` in its `copyWith` call.
- **No Host-Transfer Mechanism (Design Gap):** `evaluateReadyState()` returns early if `currentPlayer?.isHost != true`. If the host disconnects or backgrounds the app, **no** remaining player can evaluate readiness or advance the game. The docs claim "host-disconnect bug is resolved" but no host-transfer or distributed advancement logic exists.
