# Phase 1: Data Models & State Refactoring

## Overview
The "Mimicry Edition" moves from a single target (Trickster) to a multi-card rotation system. Everyone gets a card, and that card rotates among the players. To support this, we must overhaul `GameState` and `PlayerState`, allowing custom configuration for player counts and sabotage variables.

## Key Processing Logic
1. **Remove Old Paradigms:** Strip out `currentTricksterId`, `secretTarget`, etc. from `GameState`.
2. **Configurations:** Track `totalPlayers` and `sabotageAnswersCount` in `GameState`.
3. **Local Decks:** Prompts are driven by local hardcoded JSON arrays, not remote fetches.
4. **Cards Model:** A `Card` represents the prompt assigned to a Target. It holds the Target's ID, the prompt text, and the dynamically sized map of submitted sabotage answers.
5. **Phase & Player Tracking**: Track phase routing via enum, rotation index state, and per-player readiness for the auto-advance sync.

## Pseudo Code

```dart
// 1. Updated Phases
enum GamePhase { lobby, sabotage, truth, vote, reveal, gameOver }

// 2. The Card Model
class Card {
  final String targetPlayerId;
  final String promptId;    // Looked up against local hardcoded decks
  final String truthAnswer; // Written in Phase: Truth
  final Map<String, String> sabotageAnswers; // Key = SaboteurPlayerId, Value = Answer
  
  Card({this.targetPlayerId, this.promptId, this.truthAnswer, this.sabotageAnswers});
  
  // toMap and fromMap methods...
}

// 3. GameState Additions
class GameState {
  final String roomCode;
  final GamePhase currentPhase;
  
  // Custom Configurability
  final int totalPlayers; 
  final int sabotageAnswersCount; 
  
  // Rotation Tracking
  final int currentRotationIndex; 
  
  // The master list of cards in the current round
  final List<Card> cards; 
  
  // Who is holding whose card mapped by holdingPlayerId -> targetPlayerId
  final Map<String, String> currentCardAssignments; 
  
  // Track who is reading the card during Phase 3 & 4
  final String? currentReaderId; 
  
  ...
}

// 4. PlayerState Additions
class PlayerState {
  final String id;
  final String name;
  final int totalScore; 
  final bool isReadyForNextRotation; // true when they submit their answer
  
  ...
}

// 5. Local Hardcoded Decks Array Simulation
const Map<String, List<String>> _localDecks = {
  "embarrassing": [
      "The worst way I've gotten a rash...",
      "The most absurd lie I told to get out of an obligation...",
  ],
  "fears": [
  ]
};
```

## Implementation Status (Phase 1 Completed)

### What has been accomplished:
- **CardModel Implementation**: Created `lib/models/card_model.dart` which acts as the cornerstone of the Mimicry Edition. It tracks the target player, the local prompt, the singular truth answer, and maps Saboteur IDs to their deceptive submissions.
- **GameState Restructuring**: Fully obliterated the old single-trickster state logic. Implemented `GamePhase` routing (`lobby`, `sabotage`, `truth`, `vote`, `reveal`), configured `totalPlayers` & `sabotageAnswersCount`, and added tracking for the newly designed `cards` sub-collection and rotation metrics.
- **PlayerState Refactoring**: Cleaned up legacy fields from the original drafting game (e.g., `draftedTemplates`) and replaced them with `isReadyForNextRotation`, ensuring we can implement smooth auto-advancing ready-checks natively synced with Firebase.
- **UI Decoupling Stub**: To prevent the entire application from failing to compile upon removing the legacy properties from `GameService`, `Phase1DraftScreen` was correctly stubbed out into a non-breaking `Phase1SabotageScreen` skeleton, paving the way for Phase 4 (User Interface Overhaul).

### Things to review:
- **Card Answer Map Validation**: Currently, `CardModel.sabotageAnswers` is fundamentally a `Map<String, String>` where `String` is `playerId`. During Phase 2 Game Logic implementation, we must heavily ensure this Map handles concurrent writes cleanly in Firestore, because multiple Saboteurs will be writing to the same card simultaneously.
- **Score Accumulation Strategy**: The new `PlayerState` has a simplified `totalScore` rather than an explicit per-round tracking array (as Firestore handles arrays somewhat clunkily). For a per-round breakdown on the UI, we might need a separate sub-collection if simple point aggregation isn't enough for the Reveal Screen graph logic later down the line. I'd like your thoughts here.

### Places where there could be errors:
- **`promptId` Stores Text, Not an ID (Active):** `CardModel.promptId` is named as if it holds a lookup key, but `GameService.startGame()` stores the **full prompt string** directly from `PromptDecks.drawPrompts()` (line 246: `promptId: prompts[i]`). The UI then renders `targetCard.promptId` as display text (e.g., `phase2_craft.dart:198`, `phase3_vote.dart:203`). This naming mismatch means any future code that treats `promptId` as a real ID for deck lookup will silently fail. Should be renamed to `promptText` or switched to a proper ID+lookup pattern.
- **`totalPlayers` Not Updated at Game Start (Critical — see Phase 2):** The `GameState.totalPlayers` field defaults to `4` at room creation and is **never updated** when players join or when the game starts. Since `ScoringLogic.calculateScores` uses `state.totalPlayers` for the `ceil((P-1)/(S+1))` formula, all non-4-player games will calculate the wrong point values. `startGame()` must set `totalPlayers = _players.length`.
