# Prompt System Design

This document details the thematic prompt deck architecture, prompt drawing logic, and the initialization of game cards.

## 1. Prompt Deck Structure

To keep the game client lightweight and minimize Firestore reads, all prompt decks are stored as in-memory native Dart `const Map<String, List<String>>` constants within the codebase. 

### Location
* File: `lib/utils/prompt_decks.dart`

### Maturity Ratings & Themes
The system supports multiple distinct thematic decks grouped by player maturity/vibe:
1. **PG-13 / Relatable**: e.g., `"the_daily_grind"`, `"deep_fears_and_phobias"`, `"unhinged_quirks"`, `"romantic_disasters"`.
2. **Rated R / NSFW**: e.g., bedroom blunders, gross-out, Intoxicated confessions.
3. **CAH / Dark Humor**: e.g., offensive hot takes, vile fantasies.

Each deck contains highly subjective prompts that allow believable lies to be written on behalf of other players, avoiding objective questions (e.g., "What is my height?") and favoring experiential claims.

---

## 2. Drawing Engine Logic

The drawing engine shuffles the chosen deck and returns unique prompts equal to the number of active players:

### Method Signature
```dart
static List<String> drawPrompts(String deckId, int count)
```

### Verification & Constraints
* **Shuffle & Slice**: The list of prompts matching `deckId` is copied, shuffled using Dart's native `List.shuffle()`, and sliced to yield exactly `count` items.
* **Error Handling**: Throws an exception if the selected deck is missing or if the requested count of players exceeds the total number of prompts available in the deck.
* **Synchronous Availability**: Because decks are loaded as compilation-time constants rather than async JSON files, prompt drawing occurs synchronously, avoiding `FutureBuilder` latency during match initialization.
