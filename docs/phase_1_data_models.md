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
- **CardModel Implementation**: Created `lib/models/card_model.dart` which acts as the cornerstone of the Mimicry Edition.
- **Prompt Refinement**: Renamed `CardModel.promptId` to `CardModel.promptText` to accurately reflect that it stores the full prompt string, preventing silent lookup failures in future development.
- **Architectural Synchronization**: Updated `GameService.startGame()` to correctly set `GameState.totalPlayers` to the actual length of the player list, ensuring the `ceil((P-1)/(S+1))` scoring formula works for any player count.
- **GameState Restructuring**: Fully obliterated the old single-trickster state logic. Implemented `GamePhase` routing, configured `totalPlayers` & `sabotageAnswersCount`, and added tracking for the newly designed `cards` sub-collection and rotation metrics.
- **PlayerState Refactoring**: Cleaned up legacy fields and replaced them with `isReadyForNextRotation`, ensuring smooth auto-advancing ready-checks.
- **UI Decoupling Stub**: Correctly stubbed out the legacy properties from `GameService` to prevent compilation errors.

### Things to review:
- **Card Answer Map Validation**: Currently, `CardModel.sabotageAnswers` is fundamentally a `Map<String, String>` where `String` is `playerId`. During Phase 2 Game Logic implementation, we must heavily ensure this Map handles concurrent writes cleanly in Firestore.
- **Score Accumulation Strategy**: The new `PlayerState` has a simplified `totalScore` rather than an explicit per-round tracking array.

### Places where there could be errors:
- **None currently identified.** (All previous architectural misalignments in Phase 1 have been resolved).
