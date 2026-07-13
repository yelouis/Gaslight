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
  * *Note*: $S$ is the number of forgeries actually present on the card being scored, making the math robust to mid-game disconnects or missing answers.
* **Target Points**: The card's owner (Target) receives `1` point for each player who successfully identifies the Truth.
* **Saboteur Points**: Saboteurs receive `1` point for every voter they successfully deceive into voting for their fake answer.
* **Saboteur Insight Bonus**: A saboteur who also correctly votes for the Truth on a card they forged earns `+1` point in addition to the standard voter reward.
* **Self-Votes Guard**: Players cannot vote for their own sabotage submissions (the option is disabled).
* **Unmask the Forger (P8 — revenge guess)**: Each voter who fell for a forgery gets **one guess per card** at who authored the lie they voted for, submitted during the reveal's unmask window via the `submitUnmaskGuess` callable. Correct guess: `+1` to the guesser and `−1` to the forger (no floor — negative totals allowed). Wrong guess: no change. The server validates phase, the `unmaskDeadline`, fooled-voter eligibility, one-guess-per-card, and no self-guess; it deliberately does **not** return correctness, so results land with the author flip.

### The Unmask Window & Five-Beat Reveal (canonical presentation contract)
The reveal must run as five beats, gated on the **server-written** `GameState.unmaskDeadline` (set at the vote→reveal transition: `now + 20s` when at least one voter was fooled, `null` otherwise; cleared on next-card advance):
1. Vote chips land on the sealed options.
2. **The Truth flips** — forgery author cards stay sealed.
3. **Unmask window** (while `now < unmaskDeadline`): fooled voters see the guess tray; everyone else sees an "unmasking in progress" status. Skipped entirely when `unmaskDeadline == null`.
4. **Forgery authors flip** + REVENGE results — only after the deadline passes.
5. Points awarded + standings + host CONTINUE (which is locked until the window ends).
> **Regression guard:** forgery authorship must never be visible while guesses are still accepted — the deadline, not local animation timers, is the beat clock.

---

## ❓ Resolved Clarifications

### Clarification 1: Undocumented Saboteur "Found the Truth" Bonus
* **Decision**: Keep the bonus and document it (Option A). Added to Formulas section and the lobby instructions.

### Clarification 2: What Should the Game-Over "Honors" Actually Measure?
* **Decision**: Define honors by dedicated metrics (Option A).
  * **The Mastermind**: highest total score.
  * **The Trickster**: highest `playersDeceived` (voters deceived across all cards, ties broken by score).
  * **Most Gullible**: highest `timesFooled` (voted for forgeries, ties broken by fewest points).
  * Enforced at scoring time and game over screen.

---

## 2. Standardized Routing & Session Persistence

To allow seamless recovery from app restarts, device sleep, or connection losses:
* **Session Persistence**: Player IDs and Room Codes are cached on the device via `SharedPreferences`.
* **Rejoining**: On app boot, `GameService.tryRejoinSession()` runs automatically, loading cached parameters and restoring the room subscription.
* **Synchronized Phase Routing**: Instead of UI-driven navigation triggers, all screens listen to `GameService` and route themselves reactively based on a centralized schema:
  ```dart
  static String getRouteForPhase(GamePhase phase) {
    switch (phase) {
      case GamePhase.lobby:
        return '/';
      case GamePhase.forgery:
      case GamePhase.truth:
        return '/craft';
      case GamePhase.vote:
        return '/vote';
      case GamePhase.reveal:
        return '/reveal';
      case GamePhase.gameOver:
        return '/game-over';
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
