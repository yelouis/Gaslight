# Game State & Data Models

This document defines the Firestore collection hierarchies, schemas, role definitions, and phase routing tables.

## 1. Game Phases

The match progresses through the following sequential states:
```dart
enum GamePhase { lobby, truth, forgery, vote, reveal, gameOver }
```

### Phase order

`startGame` opens in `truth` — every player answers their own prompt before any forgery is written. The full progression is: **lobby → truth → forgery → vote → reveal → gameOver**. The `vote → reveal` cycle repeats once per card in `resolutionOrder`.

### Minimum player count

`startGame` enforces a strict floor of **3 active players** (`activePlayers.length < 3` → rejected with `failed-precondition`). This is a deliberate rule enforced as an independent guard, not a side-effect of forgery arithmetic.

## 2. Card Model (`CardModel`)

A card represents a prompt assigned to a player, holding their answers, vote choices, and unmask guesses.
* File: `lib/models/card_model.dart`

### Schema Details
* `targetPlayerId` (String): ID of the player this card belongs to (the Target).
* `promptText` (String): The drawn prompt assigned to this card.
* `truthAnswer` (String): The Target's own answer (populated on the public room document at `reveal` phase; stored in server-only `/rooms/{code}/sealed/{cardId}` subcollection prior to reveal).
* `sabotageAnswers` (Map<String, String>): A map of `saboteurPlayerId` to their written sabotage answers (populated on the public room document at `reveal` phase; stored in server-only `/rooms/{code}/sealed/{cardId}` subcollection prior to reveal). `submitAnswer` derives the author key server-side from `currentCardAssignments[authorId]`, ensuring key synchronization with `advancePhaseInternal` and preventing spurious `kMissingAnswerPlaceholder` (`THE SOUL IS SILENT`) entries.
* `options` (List<CardAnswerOption>?): Unlabelled, shuffled options list (`id`, `text`) supplied to public cards during the `vote` phase to conceal answer origin.
* `votes` (Map<String, String>): A map of `voterPlayerId` to the **resolved author id** of the option they chose, representing votes cast during the `vote` phase. The client sends an opaque option UUID; `castVote` resolves it through `sealed/{cardId}.answerAuthors` and stores the author, never the raw client value.
  * **There is no sentinel.** A vote is a truth vote **iff `votes[voterId] == card.targetPlayerId`**, because the target authored the truth for their own card. The retired `'TRUTH'` string must never be reintroduced.
  * **This contract has broken twice.** Issue 62/63 redefined the value once; Issue 71 redefined it again and left nine readers testing the dead sentinel (Issue 78), which silently zeroed the reward for finding the truth and marked every player as "fooled". **Both `ScoringLogic` implementations and every `phase4_reveal.dart` predicate read this field — when you change what it holds, enumerate its readers.**
* `unmaskGuesses` (Map<String, String>?): A map of `guesserPlayerId` to `accusedPlayerId` representing unmask guesses cast during the `reveal` phase.

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
* `forgeriesPerCard` (int?): Total number of forgery rotations configured per card (legacy alias `sabotageAnswersCount`).
  - **Unset default:** Resolves to `min(n - 1, 5)` at read time (`startGame` and lobby display) when `null`.
  - **Hard ceiling:** `n - 1` (where `n` is `activePlayers.length`). Values above `n - 1` are never offered in the chooser and are rejected by `updateLobbySettings`.
  - **5 is a default, not a cap:** A room with 9 players allows selecting 7 or 8 forgeries.
* `currentRotationIndex` (int): Incremental tracker for the current sabotage pass.
* `cards` (List<CardModel>): The master list of cards in active play.
* `currentCardAssignments` (Map<String, String>): Mappings of `holdingPlayerId` to `targetPlayerId`, determining who writes for whom.
* `rotationPlan` (Map<String, Map<String, String>>): Pre-calculated matrix specifying assignments for every sabotage rotation.
* `currentReaderId` (String?): ID of the player whose card is being resolved.
* `readyPlayers` (Map<String, bool>): Readiness map tracking which active players have submitted their input.
* `endTime` (int?): Epoch timestamp denoting when the phase will auto-advance.
* `resolutionOrder` (List<String>): Shuffled list of active player IDs determining the sequence in which cards are resolved during the `vote` and `reveal` phases.
