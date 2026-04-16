# Ongoing General Errors

## Overview
As requested, a full end-to-end simulation of 10 players was executed to identify boundary cases, logical crashes, and state management errors during the migration from the legacy Single-Trickster architecture to the Phase 4 Mimicry Edition. 

Due to the complexity of the errors found (specifically stemming from legacy UI files not yet decoupled from the old Game Phase logic), the simulation sequence and stack trace analysis are documented below. 

---

## 1. Resolved Minor Errors (10-Player Simulation)

### Bot Readiness Bottleneck (Resolved)
- **Error Description**: `GameService.setPlayerReady` was hardcoded to only update the local `_currentPlayerId`. This blocked bot advancement during E2E simulation.
- **Resolution**: Modified `setPlayerReady` to accept an optional `playerId`, allowing the simulation and bots to correctly signal readiness.

### Vote Attribution Error (Resolved)
- **Error Description**: `GameService.castVote` was incorrectly marking the *target* or the *local host* as ready instead of the actual `voterId` passed into the method.
- **Resolution**: Refactored `castVote` to pass the `voterId` to `setPlayerReady`, ensuring individual bot progress is tracked.

### Redundant Scaling Logic & Display Mismatch (Resolved)
- **Error Description**: The `Phase4RevealScreen` was attempting to apply score deltas in the UI layer, while the `GameService` was also calculating them during phase transitions. This created potential double-score increments and race conditions.
- **Resolution**: Centralized all scoring mutations into `GameService._advanceRotationOrPhase`. The UI now only reads `ScoringLogic` for local display/highlighting without triggering DB writes. Verified that `ceil((P-1)/(S+1))` correctly produces 3 pts for 10-player games.

### UI Overflow in Phase 4 (Resolved)
- **Error Description**: Using a `Row` to display voter chips in the Reveal screen caused an overflow when 5+ players voted for the same option.
- **Resolution**: Replaced `Row` with `Wrap` to handle any player count gracefully.

---

## 2. Unresolved Cross-Cutting Bugs (Current)

### Firestore Listener Leaks (Active)
- **Error Description**: `GameService.listenToRoom()` (`game_service.dart:119-133`) creates two Firestore `snapshots().listen()` subscriptions but **never stores the `StreamSubscription` references**. There is no `dispose()`, `cancel()`, or cleanup method in `GameService`. If a player joins Room A, leaves, then joins Room B, listeners for Room A persist in memory and continue firing callbacks that overwrite `_gameState` and `_players` with stale data from the old room.
- **Impact**: Memory leak, potential data corruption if a user navigates back to lobby and creates/joins a new room within the same app session.
- **Fix**: Store subscriptions as class fields and cancel them at the start of each new `listenToRoom()` call and in a `dispose()` method.

### No Session Persistence / Rejoin Mechanism (Design Gap)
- **Error Description**: Player IDs are generated fresh via `Uuid().v4()` on every `createRoom` / `joinRoom` call (`lobby_screen.dart:34, 52`). If the app is killed, backgrounded, or hot-restarted, the player cannot rejoin their existing room. Their old player document persists in Firestore as a ghost, and `readyPlayers` / `evaluateReadyState` will permanently wait for a player who will never respond.
- **Impact**: Any app restart during an active game permanently stalls the lobby. Ghost player documents also inflate the `_players.length` count used in scoring and readiness calculations.
- **Fix**: Persist `(roomCode, playerId)` to `SharedPreferences` or `Hive` and attempt rejoin on app launch.

### `totalPlayers` Scoring Miscalculation (Critical — Cross-Phase)
- **Error Description**: Documented in detail under Phase 2, but the impact crosses into Phase 4 (scoring display) and the Game Over screen. `GameState.totalPlayers` defaults to `4` and is never updated. The `ceil((P-1)/(S+1))` formula in `ScoringLogic` uses this stale value, producing incorrect point rewards for any game with ≠4 players. The Game Over screen (`game_over_screen.dart`) then displays these incorrect final scores.
- **Root Files**: `game_service.dart:69` (default), `game_service.dart:254` (missing `totalPlayers: _players.length`), `scoring_logic.dart:17-19` (consumer).

---

## 3. New Bugs Found — Full Code Review (April 2026)

### Double Score Application (Critical — Vote→Reveal)
- **Error Description**: In `GameService._advanceRotationOrPhase()` (line 355–366), when transitioning from Vote→Reveal, `applyScoreDeltas()` is called to write score deltas to Firestore. Then separately on the Reveal screen (`phase4_reveal.dart:49`), `ScoringLogic.calculateScores()` is called again in `_calculateAndShowResults()`. While the Reveal screen currently only uses the result for local display (`_latestDeltas`), the `_latestDeltas` map is **never actually rendered anywhere in the UI** — no widget reads it. This means the score calculation on the Reveal screen is wasted work. More critically, if any future change calls `applyScoreDeltas` from the Reveal screen (as was done in the past per resolved errors), scores will be doubled.
- **Impact**: Wasted computation now; high-risk for accidental double-scoring if Reveal screen is modified.
- **Root Files**: `game_service.dart:357-360`, `phase4_reveal.dart:35-57`.

### Stale Shuffled Answers on Reader Change (Critical — Phase 3)
- **Error Description**: `Phase3VoteScreen` caches shuffled answers in `_shuffledAnswers` (line 28) and only generates them once (`if (_shuffledAnswers != null) return;` on line 31). When the host calls `advanceToNextResolution()`, the phase transitions Vote→Reveal→Vote for the next card. But because `pushReplacementNamed('/vote')` creates a **new** `Phase3VoteScreen` instance each time (from the Reveal screen), this is partially mitigated. However, if the state changes from Vote→Vote directly (e.g., a host manually updates `currentReaderId` without going through Reveal), the same widget instance retains stale shuffled answers for the **previous** card.
- **Impact**: Players could see and vote on the wrong card's answers if the widget is reused without navigation.
- **Root Files**: `phase3_vote.dart:28-43`.

### No `_isNavigating` Reset After Navigation (Active — All Screens)
- **Error Description**: Every game screen (`phase2_craft.dart:22`, `phase3_vote.dart:27`, `phase4_reveal.dart:21`, `lobby_screen.dart:25`) uses a boolean `_isNavigating` flag to prevent duplicate navigation. Once set to `true`, it is **never reset**. If a player navigates forward and then `Navigator.pushNamedAndRemoveUntil(context, '/')` is called on Game Over (line 75), the user arrives at a fresh `LobbyScreen` (new instance, so this is fine). But if `Navigator.pop()` or the system back button is used at any point during gameplay, the existing screen instance with `_isNavigating = true` will **never navigate again** even if the game state changes.
- **Impact**: Player gets permanently stuck on a screen if they somehow navigate backward (via Android back button or programmatic pop).
- **Root Files**: All screen files (`_isNavigating` field).

### Race Condition in `evaluateReadyState` (Active)
- **Error Description**: `evaluateReadyState()` is called from two places: (1) automatically from the Firestore players listener (`game_service.dart:144`) whenever any player document changes, and (2) manually by the host from UI buttons. The method checks `allReady` against the `_gameState.readyPlayers` map and then calls `_advanceRotationOrPhase()`. But `_gameState` is updated asynchronously by a Firestore listener, meaning the readyPlayers map may be stale at the moment `evaluateReadyState` runs. Additionally, there is **no guard** to prevent `_advanceRotationOrPhase()` from being called multiple times in quick succession (e.g., two player-ready events arrive nearly simultaneously, both see `allReady = true`, both trigger advance).
- **Impact**: Could advance the phase twice in rapid succession, corrupting the game state (e.g., skipping from Sabotage rotation 1 to rotation 3, or from Truth directly to Reveal, skipping Vote).
- **Root Files**: `game_service.dart:306-317`.

### Gemini API Key Exposed in Client-Side HTTP Requests (Security)
- **Error Description**: `SemanticFilter._getEmbedding()` (`semantic_filter.dart:62-94`) reads the `GEMINI_API_KEY` from `.env` and sends it directly in a client-side HTTP GET URL parameter (`?key=$apiKey`). On web builds, this key is fully visible in browser DevTools Network tab. On mobile builds, it can be extracted via proxy or APK decompilation.
- **Impact**: API key theft, quota abuse, and potential billing attacks. Anyone who intercepts the key can make unlimited Gemini API calls at the project owner's expense.
- **Root Files**: `semantic_filter.dart:63, 72`.

### No Firestore Room/Player Cleanup (Active)
- **Error Description**: When a game ends and a player taps "RETURN TO LOBBY" (`game_over_screen.dart:75`), the app navigates to `/` via `pushNamedAndRemoveUntil`. A new `GameService` is **not** created (it's a singleton via `ChangeNotifierProvider` in `main.dart:25-28`). The old `_gameState`, `_players`, and `_currentPlayerId` fields persist in memory. Additionally, the Firestore room document and all player sub-documents are **never deleted**. Over time, this creates orphaned rooms in Firestore that persist indefinitely.
- **Impact**: Firestore storage/cost bloat. The stale in-memory `_gameState` may also cause the lobby screen to immediately think the user is in a room (line 223 check `gs.gameState != null`) and try to navigate to `/craft`.
- **Root Files**: `game_over_screen.dart:75`, `game_service.dart` (no cleanup/reset method).

### `AutoAdvanceTimer` Widget Defined But Never Used (Dead Code / Missing Feature)
- **Error Description**: The `AutoAdvanceTimer` widget (`auto_advance_timer.dart`) is fully implemented with `endTime` and `onTimerExpired` callback support. `GameService` dutifully writes `endTime` timestamps to Firestore during phase transitions (e.g., `game_service.dart:272, 334, 344, 353, 384`). However, **no screen in the entire app instantiates `AutoAdvanceTimer`**. The timer is never displayed, and the `onTimerExpired` callback is never wired to auto-advance logic.
- **Impact**: Players have no visible countdown during timed phases (Sabotage, Truth, Vote). The `endTime` field is written to Firestore but has zero effect — phases only advance via explicit readiness, making the time limits meaningless.
- **Root Files**: `auto_advance_timer.dart`, all screen files (missing usage), `game_service.dart:272, 334, 344, 353`.

### Host-Only Phase Advancement Creates Single Point of Failure (Design)
- **Error Description**: All phase transitions (`evaluateReadyState`, `advanceToNextResolution`, the "PROCEED TO REVEAL" button in `phase3_vote.dart:140`) are gated behind `currentPlayer?.isHost == true`. If the host closes the app, loses connection, or their device sleeps, **no other player can advance the game**. The host-transfer logic (`game_service.dart:135-138`) only fires when the players snapshot updates and no player has `isHost: true` — but the departed host's Firestore player document **still has `isHost: true`** because it's never deleted.
- **Impact**: If the host disconnects, the game is permanently stuck. The automatic host-transfer logic will never trigger because the ghost host document retains `isHost: true`.
- **Root Files**: `game_service.dart:135-138, 306-310, 373`.
