# Prompt System Design

This document details the thematic prompt deck architecture, prompt drawing logic, and the initialization of game cards.

## 1. Prompt Deck Structure

To keep the game client lightweight and minimize Firestore reads, all prompt decks are stored as in-memory native Dart `const Map<String, List<String>>` constants within the codebase. 

### Location
* **Source of truth: `functions/src/prompt_decks.ts`.** The Flutter client reads a
  **generated** copy at `lib/utils/prompt_decks.dart`.

### The deck catalogue is data, not code (August 2026)

Each deck is a `DeckDefinition` declaring its `id`, `displayName`, `rating`,
optional `isFallback`, and `prompts`. **No file outside the catalogue may branch on
a deck id.** Adding, renaming or re-rating a deck means editing one file and
regenerating — nothing else.

This replaced hardcoded deck-name branching that had spread to six places: the
carousel's rating seal, the family-friendly filter (twice), the display name, the
model's default deck, and the fallback deck id at **eight** call sites in
`index.ts`. Renaming a deck used to be a cross-cutting change that broke the game
silently; the deck set was in fact renamed while those branches still named the old
decks, which is what prompted this.

**Deck ids are not listed here on purpose.** A doc that enumerates decks goes stale
the first time one is added. Read `functions/src/prompt_decks.ts`.

- **Rating** is declared per deck (`PG` / `R` / `X`) and drives the carousel seal
  and the `Family-Friendly Decks Only` filter, which keeps PG decks only. The seal
  **colour** is presentation and lives in `app_colors.dart`, keyed by rating — so a
  new deck needs no UI change, and a new rating *tier* needs exactly one colour and
  will not compile until it is added.
- **`isFallback`** marks the one deck used when no chosen deck applies: the default
  for a new room, the custom-deck top-up pool, and the source for re-rolls in a
  custom game. `getFallbackDeckId()` **throws unless exactly one deck sets it**, so
  a missing or duplicated flag fails immediately rather than at draw time. Prefer
  the largest deck, since custom top-up draws from it.

### Generation and the sync gate

`./scripts/generate_prompt_decks_dart.sh` writes `lib/utils/prompt_decks.dart` from
the compiled TypeScript catalogue, so the emitted data is exactly what the server
draws from. The Dart file carries a **DO-NOT-EDIT** header and must never be
hand-edited.

`./scripts/check_decks_in_sync.sh` regenerates into a temp copy and diffs, failing
the battery when the two drift. It refuses to report success if it compared an empty
or truncated file.

**Why TypeScript is the source and Dart the artefact:** the server is authoritative
for the draw, so it should be the file a human edits. A skipped regeneration then
leaves the *client* stale — visible immediately in the lobby, and caught by the
Issue 106 mismatch guard before a game starts. The reverse direction would leave the
*server* stale after deploy, which surfaces as players getting the wrong prompts
mid-game with nothing on screen to explain it. That exact failure has already
happened here once, from a stale deploy.

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

**Deck authority (Issue 106, August 2026).** `room.selectedDeckId`, maintained by `updateLobbySettings`, is the **single source of truth** for which deck a match plays. `startGame` resolves the deck from the room (`functions/src/index.ts:293`) and never from the caller; a caller whose `selectedDeckId` disagrees is rejected with `invalid-argument` rather than silently obeyed, so a stale client fails loudly instead of starting a deck the lobby is not showing. Two consequences bind future work: **any UI that filters the deck list must write its choice through to the room** — `Family-Friendly Decks Only` previously filtered only local state, which would leave the lobby showing one deck while the room held another — and **`test/fake_functions.dart` must keep the same resolution and the same mismatch rejection**, because a fake that resolves from the room while production resolves from the caller hides the defect completely (§2.24 in `ongoing_general_errors.md`).

> **Server-authoritative note (July 2026):** deck drawing for live games now happens in Cloud Functions (`functions/src/prompt_decks.ts`, a TypeScript port of this utility); the Dart copy remains for client display and test fakes.

---

## 3. Custom Decks (P10 — shipped July 2026)

Players can play on their **own prompts** instead of a built-in deck.

### Contribution flow
* While in the **lobby**, every player may write up to **3 prompts** (200-char cap each) in the waiting-room contribution form. Contributions are stored on the player's **own** document (`PlayerState.customPrompts: List<String>`) via field-scoped updates — the one gameplay field clients may write directly (verified by a dedicated rules test). Contributions are secret *in-app* (only aggregate counts are displayed), though technically world-readable like all player docs.
* The host selects the sentinel deck id **`'custom'`** in the deck dropdown; the choice syncs to the room document through the `updateLobbySettings` callable so all clients see the "add your prompts" banner and live contribution counts.

### Server-side deal (`startGame`, custom branch)
1. **Harvest**: each active non-spectator's `customPrompts` are trimmed, length-capped (≤200 chars), deduplicated case-insensitively, capped at a maximum of 3 valid entries per player, and pooled with author tracking via `buildCustomPromptPool()`.
2. **Top-up**: if the pool is smaller than the player count, prompts are drawn from the fallback deck — whichever deck declares `isFallback`, resolved via `PromptDecks.getFallbackDeckId()` (author `"fallback"`), skipping duplicates.
3. **Own-prompt-free assignment**: the pool is shuffled and greedily assigned via `assignPromptsFromCustomPool()` so **no player ever receives a prompt they authored**. If a player would be stuck with their own prompt, a swap with a compatible earlier assignment is attempted; if no valid swap exists (provable in tiny lobbies where one player authored the entire pool), the stuck slot is filled by a **fresh fallback draw**. The algorithm is total — it cannot fail to deal.
4. **Effective deck resolution (Issue 109 / J1)**: `startGame` stores `effectiveDeckId: deckId === "custom" ? PromptDecks.getFallbackDeckId() : deckId` on `GameState` as the single authoritative prompt source, eliminating the `"custom"` sentinel at all subsequent draw sites.
5. **Re-rolls (Issue 108 / J2)**: `rerollPrompt` on a custom game draws from the players' contributed pool (`promptSource.pool`), strictly avoiding the caller's own authored prompts (`authorId !== callerId`) and prompts live on any card, falling back to the `isFallback` deck only when the pool is exhausted.
6. **Multi-round custom games (Issue 108 / J2 & 109 / J1)**: `advanceToNextResolution` draws subsequent round prompts from the custom pool, respecting player seen history and never assigning a player their own prompt.

### Why it's designed this way
Contributions ride the player's own document to avoid a new write path (rules already permit owner writes to non-protected fields); the assignment constraint preserves the core deduction (writing a "truth" for your own prompt would be trivial); the terminal fallback guarantees `startGame` never throws for custom decks regardless of contribution patterns; the `effectiveDeckId` field guarantees multi-round custom games never attempt to look up `"custom"` in the static catalog.

---

## 4. Deck Carousel Presentation (Issue 52 — shipped August 2026)

- **Host View**: The host sees the interactive 7-deck `PageView` carousel without a section label. Swiping pages updates the room's `selectedDeckId` via `updateLobbySettings` (debounced 400 ms) and triggers the scale pulse animation.
- **Non-Host Read-Only View**: Non-hosts see the exact same 7-deck `PageView` carousel labeled with `THE CHOSEN FILE`. Page swipes allow non-hosts to browse the full catalog read-only without calling `updateLobbySettings` or triggering the stamp pulse.
- **`CHOSEN` Badge**: On non-host carousels, the host's currently selected deck card is badged with an oxblood/brass `CHOSEN` label.
- **3-Second Swipe Protection**: When the host updates `selectedDeckId` via Firestore stream, a non-host's carousel page position does not snap back to the chosen deck if the non-host swiped within the last 3 seconds (`_lastSwipeTime`).

---

## 5. Re-roll Prompt Exclusion & Mirror Invariant Status (Issue 67, 69 & 107 — August 2026)

- **Sealed Storage (`/rooms/{roomCode}/sealed/{cardId}`)**: The list of prompts a player has seen and rejected during re-rolls (`seenPrompts: string[]`) is stored in the server-only `/sealed/{cardId}` subcollection (keyed by target player ID), preserving player privacy by keeping declined prompts off the public, client-readable room document.
- **Lazy Seeding & Accumulation**: `rerollPrompt` reads the player's sealed document inside the transaction prior to any writes, seeding `seenPrompts` lazily from `targetCard.promptText` if not yet created.
- **Uniform Re-roll Sampling (Issue 107 / J3 Option B)**: `rerollPrompt` samples uniformly from the selected deck or contributed custom pool, excluding only prompts currently live on any card on the table (`inPlay`). Re-rolls always visibly change the player's current prompt and prevent table collisions, while allowing past-seen prompts to reappear in uniform rotation.
- **Round Advance History Awareness**: While in-round re-rolls sample uniformly minus in-play cards, `advanceToNextResolution` continues to exclude each player's accumulated `seenPrompts` history across rounds to ensure fresh prompts across round boundaries.
- **Re-rolls are unlimited (August 2026).** `PromptDecks.drawOneExcluding(deckId, excluded, mustAvoid)` **never refuses**. It prefers a prompt outside `excluded` (everything this player has already seen, plus everything live on a card); once that set is empty it relaxes to anything outside `mustAvoid`, and only if *that* is empty does it return any prompt at all. **`mustAvoid` is the bound that survives exhaustion** — pass the prompts currently on cards, including the caller's own, so a re-roll always visibly changes something and two players never share a prompt. Only a missing deck throws (`not-found`).
- **The client's `resource-exhausted` branch is kept as a defensive guard**, not because the server still emits it for exhaustion. `phase2_craft.dart` matches explicitly on `e is FirebaseFunctionsException && e.code == 'resource-exhausted'`, falling through to `'Something went wrong. Try again.'` for every other error, and `test/phase2_craft_test.dart` stubs that throw and asserts the sentence. **Match on the code, never on the message** (a raw `Error` from a callable flattens to `INTERNAL`), and keep the widget test whenever this branch is touched (Issue 88.1).
- **TypeScript → Dart is GENERATED, not mirrored by hand.** `lib/utils/prompt_decks.dart` is a build artefact of `functions/src/prompt_decks.ts`; see "Generation and the sync gate" above. The old byte-for-byte hand-mirror rule is retired — it failed twice, once in each direction. The error plumbing is intentionally decoupled: the TypeScript backend throws typed `HttpsError` exceptions, whereas the Dart module throws standard `Exception` instances (used solely by `test/fake_functions.dart`).


