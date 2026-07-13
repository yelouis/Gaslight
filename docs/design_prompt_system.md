# Prompt System Design

This document details the thematic prompt deck architecture, prompt drawing logic, and the initialization of game cards.

## 1. Prompt Deck Structure

To keep the game client lightweight and minimize Firestore reads, all prompt decks are stored as in-memory native Dart `const Map<String, List<String>>` constants within the codebase. 

### Location
* File: `lib/utils/prompt_decks.dart`

### Maturity Ratings & Themes
The system supports multiple distinct thematic decks grouped by player maturity/vibe:
1. **PG-13 / Relatable**: 
   - `"the_daily_grind"`: Professional and workplace blunders.
   - `"deep_fears_and_phobias"`: Irrational anxieties and worries.
   - `"unhinged_quirks"`: Weird solo routines and food combinations.
   - `"romantic_disasters"`: Failed dates, cringe texts, and awkward encounters.
2. **Rated R / NSFW**: 
   - `"rated_r_nsfw"`: Bedroom mishaps, wild nights out, and private confessions.
3. **CAH / Dark Humor**: 
   - `"cah_dark_humor"`: Offensive hot takes, cards against humanity style prompts, and dark scenarios.

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

> **Server-authoritative note (July 2026):** deck drawing for live games now happens in Cloud Functions (`functions/src/prompt_decks.ts`, a TypeScript port of this utility); the Dart copy remains for client display and test fakes.

---

## 3. Custom Decks (P10 — shipped July 2026)

Players can play on their **own prompts** instead of a built-in deck.

### Contribution flow
* While in the **lobby**, every player may write up to **3 prompts** (200-char cap each) in the waiting-room contribution form. Contributions are stored on the player's **own** document (`PlayerState.customPrompts: List<String>`) via field-scoped updates — the one gameplay field clients may write directly (verified by a dedicated rules test). Contributions are secret *in-app* (only aggregate counts are displayed), though technically world-readable like all player docs.
* The host selects the sentinel deck id **`'custom'`** in the deck dropdown; the choice syncs to the room document through the `updateLobbySettings` callable so all clients see the "add your prompts" banner and live contribution counts.

### Server-side deal (`startGame`, custom branch)
1. **Harvest**: each active non-spectator's `customPrompts` are trimmed, length-capped (≤200 chars), deduplicated case-insensitively, capped at a maximum of 3 valid entries per player, and pooled with author tracking.
2. **Top-up**: if the pool is smaller than the player count, prompts are drawn from the fallback deck `'the_daily_grind'` (author `"fallback"`), skipping duplicates.
3. **Own-prompt-free assignment**: the pool is shuffled and greedily assigned so **no player ever receives a prompt they authored**. If a player would be stuck with their own prompt, a swap with a compatible earlier assignment is attempted; if no valid swap exists (provable in tiny lobbies where one player authored the entire pool), the stuck slot is filled by a **fresh fallback draw**. The algorithm is total — it cannot fail to deal.
4. **Re-rolls**: `rerollPrompt` on a custom game draws from the fallback deck (there is no static `'custom'` deck), excluding all prompts already in play.

### Why it's designed this way
Contributions ride the player's own document to avoid a new write path (rules already permit owner writes to non-protected fields); the assignment constraint preserves the core deduction (writing a "truth" for your own prompt would be trivial); the terminal fallback guarantees `startGame` never throws for custom decks regardless of contribution patterns.
