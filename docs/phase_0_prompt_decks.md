# Phase 0: Thematic Prompt Decks

## Overview
Before the complex rotation and state logic kicks in, the foundational data of the game must be curated. A prompt is only good if it allows Saboteurs to tell a believable, subjective lie on behalf of the Target. The prompts must avoid objective facts (e.g., "What is my middle name?") and favor subjective experiential claims (e.g., "The worst way I've gotten a rash"). 
Each deck should have at least 50 prompts.

## Key Processing Logic
1. **Local Hardcoded Storage**: Create a Dart file (e.g., `lib/utils/prompt_decks.dart`) that stores multiple themes as constant Maps or Lists. This avoids continuous Firestore document reads and keeps the app lightweight.
2. **Theme Grouping**: Group prompts into categories so players can choose the "vibe" of their lobby before starting (e.g., "Late Night", "Mild", "Childhood", "Deep Fears").
3. **Random Selection Logic**: Create a helper function `drawPrompts(String deckId, int count)`. It will shuffle the array and return `P` unique prompts for the number of players.

## Proposed Deck Themes (50+ cards each)
To ensure diverse and highly replayable lobbies, we will establish 20 distinct decks split across three maturity/vibe ratings:

### PG-13 / Relatable Lobbies
1. **"The Daily Grind"**: Workplace anecdotes, petty office annoyances, and the biggest professional lies you've sold.
2. **"Deep Fears & Phobias"**: Irrational thoughts, weird inanimate objects that creep you out.
3. **"Childhood Delusions"**: Dumbest things you believed as a child, traumatic playground moments.
4. **"Family Dysfunction"**: Relative chaos, holiday disasters, and weird family traditions you thought were normal.
5. **"Petty Grievances"**: Insignificant things that cause internal rage; immediate platonic dealbreakers.
6. **"Romantic Disasters"**: Terrible first dates, cringe-worthy text messages, and weird rejections.
7. **"Unhinged Quirks"**: Weird daily habits, bizarre food combinations, 2AM hyper-fixations.

### Rated R / NSFW Lobbies
8. **"Bedroom Blunders" (Rated R)**: Awkward physical encounters, post-coital regrets, and questionable kinks.
9. **"Down Bad & Desperate" (Rated R)**: The lowest, most pathetic actions taken purely out of desperation.
10. **"Intoxicated Confessions" (Rated R)**: The most destructive or ridiculous things done under the influence.
11. **"Moral Depravity" (Rated R)**: Scenarios where you were legitimately the villain of the story and didn't care.
12. **"Statute of Limitations" (Rated R)**: Minor illegal or highly unethical acts you got away with.
13. **"Fired For Cause" (Rated R)**: Insanely inappropriate things done on the company dime.
14. **"Gross Out" (Rated R)**: Disgusting bodily habits, hygiene nightmares, things you wouldn't tell a doctor.

### Cards Against Humanity Style / Dark Humor Lobbies
15. **"Humanity's Worst" (CAH Style)**: Irreverent, pitch-black humor scenarios testing the limits of your friendships.
16. **"Offensive Hot Takes" (CAH Style)**: Highly cancellable opinions and terrible hills you are willing to die on.
17. **"Vile Fantasies" (CAH Style)**: Intrusive thoughts gone horribly wrong.
18. **"Cruel Intentions" (CAH Style)**: The most spiteful, premeditated, and petty actions taken against a known enemy.
19. **"Hellward Bound" (CAH Style)**: Things you've laughed at that guaranteed your spot in hell.
20. **"Trauma Bonding" (CAH Style)**: Finding the absolute worst, most inappropriate silver lining in a terrible tragedy.

## Pseudo Code

```dart
// lib/utils/prompt_decks.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class PromptDecks {
  // Acts as our in-memory cache so we only load a deck once.
  static final Map<String, List<String>> _loadedDecks = {};

  /// Pulls [count] number of randomly selected unique prompts from [deckId].
  /// [deckId] should match the filename in assets (e.g., "embarrassment").
  static Future<List<String>> drawPrompts(String deckId, int count) async {
    
    // Lazy load the JSON asset if it hasn't been cached yet
    if (!_loadedDecks.containsKey(deckId)) {
        try {
            final String jsonString = await rootBundle.loadString('assets/decks/\$deckId.json');
            final List<dynamic> jsonList = jsonDecode(jsonString);
            _loadedDecks[deckId] = List<String>.from(jsonList);
        } catch (e) {
            throw Exception('Failed to load deck: \$deckId. Ensure it exists in assets/decks/');
        }
    }
    
    // Create a mutable copy of the loaded deck
    List<String> deckCopy = List.from(_loadedDecks[deckId]!);
    
    if (count > deckCopy.length) {
       throw Exception('Not enough prompts in the deck for \$count players.');
    }
    
    deckCopy.shuffle();
    return deckCopy.sublist(0, count);
  }
}
```
