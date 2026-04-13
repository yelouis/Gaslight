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
      "My biggest irrational fear that I still hold onto today..."
  ]
};
```
