# Scoring System & UI Architecture

This document outlines the dynamic scoring formulas, standardized phase navigation, and game screen architectures.

## 1. Dynamic Scoring System (`ScoringLogic`)

Because player count ($P$) and sabotage counts ($S$) are configurable, Gaslight scales points dynamically to maintain balanced Expected Value (EV).
* File: `lib/utils/scoring_logic.dart`

### Formulas
* **Correct Voters (Voter Points)**: Guessing the target's truth answer rewards points scaled dynamically:
  $$\text{Voter Points} = \left\lceil \frac{P - 1}{S + 1} \right\rceil$$
  * *Example (4 players, 2 sabotages)*: $\lceil 3 / 3 \rceil = 1$ point.
  * *Example (10 players, 2 sabotages)*: $\lceil 9 / 3 \rceil = 3$ points. (Deduction is harder, so reward is higher).
* **Target Points**: The card's owner (Target) receives `1` point for each player who successfully identifies the Truth.
* **Saboteur Points**: Saboteurs receive `1` point for every voter they successfully deceive into voting for their fake answer.
* **Self-Votes Guard**: Players cannot vote for their own sabotage submissions (the option is disabled).

---

## 2. Standardized Routing & Session Persistence

To allow seamless recovery from app restarts, device sleep, or connection losses:
* **Session Persistence**: Player IDs and Room Codes are cached on the device via `SharedPreferences`.
* **Rejoining**: On app boot, `GameService.tryRejoinSession()` runs automatically, loading cached parameters and restoring the room subscription.
* **Synchronized Phase Routing**: Instead of UI-driven navigation triggers, all screens listen to `GameService` and route themselves reactively based on a centralized schema:
  ```dart
  static String getRouteForPhase(GamePhase phase) {
    switch (phase) {
      case GamePhase.lobby: return '/lobby';
      case GamePhase.sabotage: return '/craft';
      case GamePhase.truth: return '/craft';
      case GamePhase.vote: return '/vote';
      case GamePhase.reveal: return '/reveal';
      case GamePhase.gameOver: return '/reveal';
    }
  }
  ```
  Each screen compares its route to this mapping. If a phase change occurs, it calls `Navigator.pushReplacementNamed` to sync instantly.

---

## 3. Screen Architectures

### 1. Phase 2 (Craft Phase)
* **Active Player View**: Displays prompt text and allows input. Submitting marks them ready and starts the waiting view.
* **Spectator View**: Displays game progress and active players' readiness: `Players ready: X / Y`.
* **Timers**: Embeds `AutoAdvanceTimer` in the AppBar. If the timer expires, the host calls `forceAdvance()` to submit generic placeholders for unready players.

### 2. Phase 3 (Voting Phase)
* **Reader & Target Lockout**: The active reader and target see a locked status screen: `"THEY ARE VOTING ON YOUR CARD..."`.
* **Voter View**: Shuffles options using `_shuffledCardId` to ensure the placement of answers remains static for the duration of that card's vote.
* **Spectator View**: Displays the active prompt and vote status (`Votes Locked In: X / Y`) without revealing the voting cards or options.

### 3. Phase 4 (Reveal Phase)
* **Voter Chip Wrap**: Uses Flutter's `Wrap` widget to display player avatars who voted for each option, preventing UI overflow.
* **Points Delta**: Computes and overlays points awarded specifically during the current resolution using a localized scoring lookup.
* **Cleanup**: Returning to the lobby triggers `leaveRoom()`, deleting active player records and shutting down subscriptions.
