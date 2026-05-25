# Rotation Engine & Disconnect Recalculation

This document outlines the circular derangement algorithm for prompt distribution, card rotation logic, and dynamic mid-game disconnect handling.

## 1. Derangement Algorithm (`RotationEngine`)

To ensure that no player receives their own card or holds the same player's card twice during the sabotage phase, a mathematical derangement algorithm is implemented.
* File: `lib/utils/rotation_engine.dart`

### Generation Logic
For $P$ players and $S$ sabotage rounds, the engine constructs a mapping where:
* The assignment for player at index `i` in rotation round `r` is `(i + r) % P`.
* **Constraint**: Since `1 <= r <= S` and `S < P`, no player is ever assigned their own card (`targetIndex != i`).
* **Output**: A map of rotation index to assignment maps: `Map<int, Map<String, String>>`.

---

## 2. Dynamic Disconnect Recalculation

When a player leaves the match during active gameplay, the host detects the departure by comparing active Firestore players against `GameState.cards`. To prevent deadlocks or state corruption, the system recalculates game parameters on the fly:

### 1. Card Removal
The disconnected player's card is purged from the `cards` list in the room document to prevent a voting round on a non-existent player.

### 2. Assignment Bridging (Sabotage Phase)
If the disconnect occurs during the Sabotage writing phase:
* **Bridging**: The card passing queue is bridged. If player `A` was writing for the disconnected player `B`, and `B` was writing for target `C`, the assignment map is updated so `A` writes directly for `C` (`currentCardAssignments[A] = C`).
* **Rotation Re-generation**: The remaining rotation plans (`rotationPlan`) are recalculated for the remaining active players using the `RotationEngine`.
* **Rounds Adjustments**: If the number of active players falls below or equal to the sabotage count, the remaining sabotage rounds count (`sabotageAnswersCount`) is capped or decremented. If active players drop to $\le 2$, the engine terminates the sabotage phase and advances directly to the **Truth** phase.

### 3. Reader Re-indexing (Vote/Reveal Phases)
If a player departs during voting or reveal, and they were the active card reader (`currentReaderId`), the host advances the reader index to the next active player. If no active players remain, the phase terminates to `gameOver`.

### 4. Readiness Pruning
The disconnected player's ID is removed from `readyPlayers` to ensure the host can evaluate readiness correctly.
