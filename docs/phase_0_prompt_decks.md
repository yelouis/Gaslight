# Phase 0: Thematic Prompt Decks

## Overview
Before the complex rotation and state logic kicks in, the foundational data of the game must be curated. A prompt is only good if it allows Saboteurs to tell a believable, subjective lie on behalf of the Target. The prompts must avoid objective facts (e.g., "What is my middle name?") and favor subjective experiential claims (e.g., "The worst way I've gotten a rash"). 

## Key Processing Logic
1. **Local Hardcoded Storage**: Create a Dart file (e.g., `lib/utils/prompt_decks.dart`) that stores multiple themes as constant Maps or Lists. This avoids continuous Firestore document reads and keeps the app lightweight.
2. **Theme Grouping**: Group prompts into categories so players can choose the "vibe" of their lobby before starting (e.g., "Late Night", "Mild", "Childhood", "Deep Fears").
3. **Random Selection Logic**: Create a helper function `drawPrompts(String deckId, int count)`. It will shuffle the array and return `P` unique prompts for the number of players.

## Pseudo Code

```dart
// lib/utils/prompt_decks.dart
class PromptDecks {
  static const Map<String, List<String>> decks = {
    'embarrassment': [
      "The most absurd lie I told to get out of an obligation...",
      "A situation where I confidently said the wrong thing and everyone just stared...",
      "The most childish thing I still do when nobody is looking...",
      "The worst way I've ever gotten a rash...",
      "The most embarrassing thing that happened to me on a date..."
    ],
    'fears': [
      "My biggest irrational fear that I still hold onto today...",
      "The movie scene that scarred me for absolutely no logical reason...",
      "A seemingly normal everyday object that creeps me out...",
      "The exact scenario I imagine happening when walking up the basement stairs in the dark..."
    ],
    'quirks': [
      "The incredibly specific way I need my bed or pillows arranged to fall asleep...",
      "A food combination I secretly eat but would be judged for...",
      "The weird hyper-fixation I had for exactly two weeks and then abandoned..."
    ]
  };

  /// Returns [count] number of randomly selected unique prompts from [deckId].
  static List<String> drawPrompts(String deckId, int count) {
    if (!decks.containsKey(deckId)) {
      throw Exception('Deck not found');
    }
    
    // Create a mutable copy of the deck
    List<String> deckCopy = List.from(decks[deckId]!);
    
    if (count > deckCopy.length) {
       // Handle edge cases where players > prompts by either 
       // repeating or throwing an error
       throw Exception('Not enough prompts in the deck for \$count players.');
    }
    
    // Shuffle and pick
    deckCopy.shuffle();
    return deckCopy.sublist(0, count);
  }
}
```
