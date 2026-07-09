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

## ❓ Open Clarifications (Needs Product Decision)

> These were surfaced during the July 8 docs/code walkthrough. The code implements behavior the design doc does not describe. Resolve before "fixing", because the fix depends on intent.

### Clarification 1: Undocumented Saboteur "Found the Truth" Bonus
**Question**: `ScoringLogic.calculateScores()` (`scoring_logic.dart:29-32`) grants a saboteur an **extra `+1`** (on top of the standard `truthReward`) whenever that saboteur *also* votes for `TRUTH` on the card they sabotaged. This bonus appears nowhere in the design or the in-app "HOW TO PLAY" manual. Is it intended?

**Impact**: It changes competitive balance. Saboteurs get a strictly higher expected value than pure voters on cards they sabotaged, which may or may not be the desired incentive. Whichever way we go, the code and the docs/manual currently disagree, so one of them is wrong.

**Solutions**:
- **Option A (recommended)**: Keep the bonus and **document it** — add it to this file and to the lobby manual (`lobby_screen.dart` "SCORING" section). Rationale: rewarding a saboteur who can still identify the truth is a fun, defensible mechanic, and it's already shipped/tested.
- **Option B**: Remove the bonus (`scoring_logic.dart:29-32`) so scoring matches the documented three rules exactly. Rationale: simplest mental model for players; EV parity between voters.

**Recommended**: Option A — document the shipped behavior unless product wants strict EV parity.

Your selection: Proceed with Option A.

---

### Clarification 2: What Should the Game-Over "Honors" Actually Measure?
**Question**: The design lists honors like "The Mastermind" and "The Trickster" but never defines their metrics. The implementation (`game_over_screen.dart:22-26,101-105`) currently derives all of them from **total score rank** — Mastermind = 1st, Trickster = 2nd, Runner Up = 2nd again, Most Gullible = last. Should Trickster/Most Gullible reflect *actual behavior* (best deceiver / most-often-fooled) instead of raw score position?

**Impact**: Determines whether honors need new per-player stat tracking across reveals (deception count, times-fooled) or can stay as score-rank proxies. Also gates the fix for Issue 7 in `ongoing_general_errors.md` (whether Option A cosmetic filtering suffices, or Option B metric-based honors is required).

**Solutions**:
- **Option A (recommended)**: Define honors by **dedicated metrics** — Mastermind = highest total score; Trickster = most voters deceived across all cards; Most Gullible = voted for the most forgeries. Requires accumulating counters during each reveal.
- **Option B**: Keep honors as **score-rank proxies** and simply relabel them to be honest (e.g. "2nd Place" instead of "The Trickster") and filter spectators.
- **Option C**: Keep names but explicitly document them as score-rank proxies (lowest effort, least meaningful).

**Recommended**: Option A for a satisfying payoff screen; fall back to Option B if scope is tight.

Your selection: Proceed with Option A.

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
