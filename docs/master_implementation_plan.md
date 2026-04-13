# Gaslight v2.0 - Master Implementation Plan

The objective is to implement the "Mimicry Edition" of Gaslight as outlined in the PRD. This involves generating thematic decks of subjective prompts, establishing a new assignment and rotation engine for writing sabotaged and real answers, integrating semantic similarity checks to maintain game integrity, and updating the scoring model.

## Core Configurations
- **Adjustable Lobby Sizes**: Total people per game acts as a configurable variable `totalPlayers`.
- **Adjustable Sabotages**: The amount of sabotage rounds acts as a configurable variable `sabotageAnswersCount`.
- **Data Locality**: Prompt decks (e.g. "The worst way I've gotten a rash") are hardcoded directly into the app natively, not hosted remotely.
- **Client-Side Embeddings**: For fast prototyping, semantic API calls rely on direct local HTTPS queries using `.env` keys.
- **Dynamic Scoring Function**: The point reward for Voter Success is calculated dynamically based on player count and options: `points = ceil((totalPlayers - 1) / (sabotageAnswersCount + 1))`.

## Phase 0: Thematic Prompt Decks
**Goal:** Create engaging, subjective decks of prompts that fuel the rest of the game logic.
- **Decks Generation**
  - Establish a native Dart utility containing multiple themes (e.g., "Embarrassment", "Fears", "Quirks").
  - Populate each theme with highly subjective prompts to allow believable impersonation.
- **Access Patterns**
  - Create a service method to randomly select $P$ unique prompts from a chosen deck for each new game.

## Phase 1: Data Models & State Refactoring
**Goal:** Restructure the game's state so it can handle a multi-card rotation model rather than the old single-trickster model.
- **`GameState` Updates**
  - Add `totalPlayers` and `sabotageAnswersCount`.
  - Remove single-target fields (`currentTricksterId`, `secretTarget`, etc.).
  - Add fields for global phases: `lobby`, `sabotage`, `truth`, `vote`, `reveal`.
  - Add a sub-collection or array for "Cards" (Target ID, Prompt, Saboteur Answers array, Truth Answer).
  - Track Sabotage Rotations (`currentRotationIndex`).
- **`PlayerState` Updates**
  - Overhaul score tracking to maintain a breakdown per round.
  - Track "ready" status for each phase (e.g., `isReadyForNextRotation`).

## Phase 2: Game Logic & The Rotation Engine
**Goal:** Implement the complex circular logic for assigning and shifting cards between players.
- **Card Assignment (Derangement Algorithm)**
  - For $P$ players and $S$ sabotage rounds, assign each card to $S$ unique saboteurs.
  - Ensure nobody sabotages the same card twice.
  - Ensure nobody receives their own card during the sabotage phase.
- **State Management & Transitions**
  - Enforce "Ready Checks". The rotation index only advances when all $P$ players submit their answers.
  - An Explicit Auto-Advance Timer will force submit empty/AI responses if players hang the lobby to prevent dead-air.

## Phase 3: AI-Assisted Semantic Integrity
**Goal:** Prevent identical answers and ensure high-quality gameplay.
- **Client-Side HTTPS Embeddings**
  - Send the newly submitted answer and existing answers to a lightweight embedding endpoint (e.g., `text-embedding-004`) directly through a Dart HTTP client wrapper using a `.env` stored key.
- **Anti-Dupe Logic**
  - If a submitted answer has $>85\%$ cosine similarity with existing answers on that card, reject the submission and prompt the user in the UI to rewrite.

## Phase 4: User Interface Overhaul
**Goal:** Rebuild the views to map to the new states and create an exciting "Theater" reveal.
- **Sabotage & Truth Views**
  - Create the Sabotage View: Shows the prompt, the Target's name, and a text field. Includes a progress indicator ("Rotation 1 of 3").
  - Create the Truth View: Target sees their card and writes their honest answer.
  - Add a dynamic "Players Ready: 7/10" UI combined with a countdown timer to auto-advance if necessary.
- **Vote View**
  - Target (Reader) reads aloud and is locked from UI interactions.
  - Voters see dynamically sized options ($1 \text{ truth} + S \text{ sabotages}$) in a randomized list. 
- **Reveal View (The "Theater")**
  - Build animations displaying votes landing on each option sequentially.
  - Reveal authors of the sabotages and the actual Truth.
  - Tally and update the score on screen in real-time according to the configurable dynamic scoring function.
