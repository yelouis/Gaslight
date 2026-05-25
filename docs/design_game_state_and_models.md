# Game State & Data Models

This document defines the Firestore collection hierarchies, schemas, role definitions, and phase routing tables.

## 1. Game Phases

The match progresses through the following sequential states:
```dart
enum GamePhase { lobby, forgery, truth, vote, reveal, gameOver }
```

---

## 2. Card Model (`CardModel`)

A card represents a prompt assigned to a player, holding their answers and voting records.
* File: `lib/models/card_model.dart`

### Schema Details
* `targetPlayerId` (String): ID of the player this card belongs to (the Target).
* `promptText` (String): The drawn prompt assigned to this card.
* `truthAnswer` (String): The Target's own answer (written during the `truth` phase).
* `sabotageAnswers` (Map<String, String>): A map of `saboteurPlayerId` to their written sabotage answers.
* `votes` (Map<String, String>): A map of `voterPlayerId` to `votedForPlayerId` (or `'TRUTH'`), representing votes cast during the `vote` phase.

---

## 3. Player State (`PlayerState`)

Tracks individual player presence, roles, scores, and readiness.
* File: `lib/models/player_state.dart`

### Player Roles
```dart
enum PlayerRole { saboteur, target, voter, spectator, unassigned }
```
* **Spectator**: Assigned to players joining mid-game. Spectators have no card assignments and their readiness/votes are ignored in phase transitions.

### Schema Details
* `id` (String): Unique identifier (persistent in local device storage).
* `name` (String): Player displayName.
* `isHost` (bool): Identifies if the player is the host (responsible for triggering phase advancements).
* `colorValue` (int): Selected HSL/RGB avatar color value.
* `avatarIndex` (int): Profile avatar sprite index.
* `totalScore` (int): Running score accumulation.
* `lastSeen` (int): Millisecond epoch timestamp updated periodically via heartbeat.
* `role` (PlayerRole): The active gameplay role.

---

## 4. Game State (`GameState`)

The root room document storing global match settings and rotation assignments.
* File: `lib/models/game_state.dart`

### Schema Details
* `roomCode` (String): 4-character room access key.
* `currentPhase` (GamePhase): Active phase of the game loop.
* `totalPlayers` (int): Number of active players participating in gameplay (excluding spectators).
* `sabotageAnswersCount` (int): Total number of sabotage rotations configured (normally 2).
* `currentRotationIndex` (int): Incremental tracker for the current sabotage pass.
* `cards` (List<CardModel>): The master list of cards in active play.
* `currentCardAssignments` (Map<String, String>): Mappings of `holdingPlayerId` to `targetPlayerId`, determining who writes for whom.
* `rotationPlan` (Map<String, Map<String, String>>): Pre-calculated matrix specifying assignments for every sabotage rotation.
* `currentReaderId` (String?): ID of the player whose card is being resolved.
* `readyPlayers` (Map<String, bool>): Readiness map tracking which active players have submitted their input.
* `endTime` (int?): Epoch timestamp denoting when the phase will auto-advance.
