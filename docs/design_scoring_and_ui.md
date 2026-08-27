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

**Single-Card Reveal Scoping (Issue 99, August 2026)**: During each reveal transition in `advancePhaseInternal`, sealed data (`truthAnswer`, `sabotageAnswers`) and resolved votes are merged **only into the card currently being revealed (`card.targetPlayerId === room.currentReaderId`)**. Every other card in `room.cards` remains blank (`truthAnswer: ""`, `sabotageAnswers: {}`), ensuring remaining cards in the round are never exposed in public room snapshots prior to their own resolution.

**Unmask Forgery Authorship Withholding (Issue 100, August 2026)**: While `unmaskDeadline` is active (the 20-second revenge window), `currentCard.sabotageAnswers` remains empty (`{}`) and forgery votes in `currentCard.votes` remain opaque option UUIDs on the public room document. The server evaluates revenge guesses in `submitUnmaskGuess` authoritatively against the private `sealed` subcollection. Forgery authorship and resolved votes are published only when all fooled players submit guesses or when the unmask deadline expires.

**Who may accuse, and who may be accused** (two separate bounds — do not merge them):
* **May accuse:** only voters who fell for a forgery. Enforced server-side by `submitUnmaskGuess` rejecting `votes[voterId] === card.targetPlayerId`.
* **May be accused:** anyone except the guesser **and except `card.targetPlayerId`**, who authored the truth and by definition forged nothing (Issue 79). Enforced in two places by design — `phase4_reveal.dart`'s candidate list keeps the impossible choice off screen, and `submitUnmaskGuess` rejects it with `invalid-argument` because a client-only bound is not a bound. **Change both or neither**; each site carries a comment naming the other.
* Correctness of a guess is `guessedAuthorId == votes[guesserId]` — the author of *the specific forgery you voted for*, not merely someone who forged on this card.

---

## ❓ Resolved Clarifications

### Clarification 1: Undocumented Saboteur "Found the Truth" Bonus
* **Decision**: Keep the bonus and document it (Option A). Added to Formulas section and the lobby instructions.

### Clarification 2: What Should the Game-Over "Honors" Actually Measure?
* **Decision**: Define honors by dedicated metrics (Option A).
  * **The Mastermind**: highest total score.
  * **The Duplicitous** (labelled *The Trickster* in this decision's original wording): highest `playersDeceived`, ties broken by score.
  * **The Gullible**: highest `timesFooled`, ties broken by **fewest** points.
  * Enforced at scoring time and on the game over screen.

> **Each honor goes to a different player — the rule the metrics above do not state.** `game_over_screen.dart:156-190` carries an `assignedIds` set seeded with the Mastermind, and every later honor is chosen only from players not yet assigned. **So an honor does NOT always go to the global leader on its own metric.** In the W20 playthrough Alice deceived 2 players and Bob deceived 1, yet **Bob** received The Duplicitous — because Alice had already taken The Mastermind. That is correct and deliberate: the honors spread recognition across the table rather than handing one strong player every card. Verified in source August 24, 2026 after the screenshot made it look like a defect. **Read the exclusion before filing a bug about an "wrong" honor.**

### Match Highlights (Issue 111, August 2026)

Below the honors and the **FINAL STANDINGS** table, the game over screen renders **MATCH HIGHLIGHTS** from `GameState.matchSummary`: **Best Lie of the Night** (the forgery text, its author, and how many it fooled), **Cleanest Truth** (the truth fewest players found), **The Sting** (the card with the most wrong votes), and head-to-head lines.

The summary is **server-owned**. It is accumulated per resolved card inside the reveal transaction — the only moment `truthAnswer`, `sabotageAnswers` and the resolved votes all exist, since single-card reveal scoping blanks non-current cards and the round advance resets each `sealed/{playerId}` doc along with `votes` and `unmaskGuesses`. It lives in `sealed/_summary`, which is default-deny because it has no `match` block in `firestore.rules`, and reaches the world-readable room document **only at game over**. Publishing it earlier would expose forgery authorship while the unmask window is still open and reopen Issues 99 and 100.

> **Empty is a legitimate state, and it renders as nothing.** `computeMatchSummary` only collects forgeries with `fooled > 0`, so a match where every voter found the truth yields a null `bestLie`; when **all** awards are null, `_buildMatchHighlights` returns `SizedBox.shrink()`. A scripted playthrough in which nobody is fooled therefore shows an empty section that looks exactly like a broken feature. Any test or playthrough exercising this must ensure **at least one player votes for a forgery** and that the match runs **more than one round** — a single round cannot produce a best-lie contest.

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
* **Own-answer lockout — two layers, and the order matters** (Issue 90 & Issue 117, August 2026). An option the voter authored is greyed and made untappable (`card_grid.dart`, `onTap: isSelfAnswer ? null : …`). Identification is layered:
  1. **Authority — option id.** `getMyOptionId` returns the caller's own opaque option id for that card (`design_database_and_security.md` §2); the grid compares **option id to option id**. The server resets `answerAuthors` at round advance and writes `sealedData` on vote transition without `{ merge: true }` so option mappings never union across rounds (Issue 117).
  2. **Fallback — per-card text.** While the id is unresolved or if the call fails, the grid falls back to matching text the voter submitted **for that same card**, keyed by `card.targetPlayerId`.
  > ⚠️ **The fallback must stay scoped to the card.** It was originally a flat session-wide set of every answer the player had ever written, so an option authored by *someone else* whose text happened to match anything the voter had submitted on any earlier card was greyed out and **could not be voted for** — in the reported case two of three options were blocked and the vote was effectively forced. Cross-card duplicate text is legitimate: `isTooSimilar` only compares within a single card. **A client bound tighter than the server's is a defect**; `castVote` resolves the option server-side and rejects only genuine self-votes, and this UI must not exceed it.

* **Placeholder answers sealed and unvotable** (Issue 118, August 2026). If a player departs and leaves placeholder answers (`THE SOUL IS SILENT`), `castVote` rejects votes for placeholders with `invalid-argument`. The voting screen disables and stamps placeholder options with `SEALED` for all players, and `advancePhaseInternal`/`advanceToNextResolution` skips cards where all options are placeholders.
* **Raven Mascot on Sealed Ballot Waiting Screen** (Issue 116, August 2026). Once a player submits their vote, `_buildWaitingUI` renders the `RavenMascot` widget positioned above the candle flame indicator and `"YOUR BALLOT IS SEALED"` plaque, providing consistent mascot presence across all game waiting states.

### 3. Phase 4 (Reveal Phase)
* **Voter Chip Wrap**: Uses Flutter's `Wrap` widget to display player avatars who voted for each option, preventing UI overflow.
* **Points Delta**: Server publishes authoritative `scoreDeltas` on `card` during single-card reveal, updated when unmask revenge guesses resolve (Issue 113). Standings badges display positive (`▲+$delta`) and negative (`▼$delta`) adjustments without client-side recomputation. Unrevealed cards omit `scoreDeltas` to preserve answer and author secrecy.
* **Cleanup**: Returning to the lobby triggers `leaveRoom()`, deleting active player records and shutting down subscriptions.

### 4. Phase 5 (Game Over Screen) — Standings, Match Highlights & Case File Export (Wave K)
* **Full Ranked Standings (`_buildStandings`)**: Renders all active players ranked 1st through Nth, with podium trophies/ribbons, avatar, name, and stat lines (`Fooled X · Fooled by Y`), ensuring every player sees their final placement and stats.
* **Match Summary & Answer Quoting (`_buildMatchHighlights`)**: Displays server-computed awards quoting actual answers:
  * **Best Lie of the Night**: Forgery with the highest number of fooled voters, quoting the exact lie text, author name, and prompt.
  * **Cleanest Truth**: Truth answer that went unnoticed / had the fewest finder votes.
  * **The Sting**: The single card that caused the highest total wrong votes.
  * **Rivalries (Head to Head)**: Deceiver/victim pairs where player A fooled player B two or more times.
* **Accumulation & Security Invariant (`sealed/_summary`)**: Because answer text is wiped across single-card reveals and round advances, resolved card summaries and display names are accumulated into `room.collection("sealed").doc("_summary")` (default-deny to clients) during `advancePhaseInternal`. The summary is only computed and written to public `room.matchSummary` at game over (`advanceToNextResolution` and `handleDisconnect`), guaranteeing zero answer/author leakage mid-game. Display names are frozen into `matchSummary` awards (`authorName`, `targetPlayerName`, `deceiverName`, `victimName`) so match highlights remain self-contained even if players depart before or after game over (Issue 115).
* **Responsive Badge Pills (`_highlightCard`)**: Highlight card titles are wrapped in `Expanded` with text ellipsis alongside `Flexible` badge containers to preserve badge visibility without clipping or RenderFlex overflow on narrow devices (Issue 114).
* **Case File Delivery (`_shareCaseFile`)**:
  * **Web (`kIsWeb`)**: Converts the `RepaintBoundary` PNG bytes into a `Blob` via `package:web`, triggers a synthetic anchor download (`gaslight_case_file_<roomCode>.png`), and presents a confirmation snackbar.
  * **Mobile / Native**: Writes PNG bytes to a temporary file and opens the native OS share sheet via `Share.shareXFiles`.

---

## 4. Delivered gameplay programme (P1–P11) — consolidated record

Absorbed from `ongoing_general_errors.md`, August 7. All items below are **shipped and verified**; the per-proposal specs were retired once delivered. Retained because these define the game's shape.

| # | Feature | Notes that constrain future work |
|---|---|---|
| **P1** | Running leaderboard between cards | Scores stream from Firestore; never computed client-side. |
| **P2** | Reveal drama — sequential vote landing + "Best Lie" callout | The five-beat reveal contract; each beat is guarded by a once-per-event key so stream rebuilds cannot replay it. |
| **P3** | Emoji reactions during reveal | **Raw emoji strings** travel over the wire; the Victorian medallion is render-side only (V5). |
| **P4** | "I Can't Answer This" prompt re-roll | One re-roll per player per game, tracked by `hasRerolled` — a server-owned field clients cannot write. |
| **P5** | Lobby warmth — live roster, ready-check, house rules | House rules live in **one** inline Parlor panel; non-hosts see it read-only. |
| **P6** | Post-game shareable "Case File" card | Uses `share_plus`; rendered locally, nothing uploaded. |
| **P8** | Unmask the Forger — the revenge guess | Fall for a lie, then guess its author before forgers are revealed. |
| **P10** | Custom decks — players write prompts in the lobby | Server caps 3 custom prompts per player; you never receive your own prompt. See `design_prompt_system.md` §3. |

**Not built (deliberately deferred, not forgotten):** **P7** confidence wager, **P9** house cards / round modifiers, **P11** the final-gambit comeback round. These were proposed and consciously not selected — do not treat their absence as an oversight or re-propose them unprompted.

### Scoring invariants worth restating
- **All scoring runs server-side** in `functions/src/scoring_logic.ts`. `totalScore`, `timesFooled` and `playersDeceived` are locked to server writes by `firestore.rules`.
- **"Forgery Rounds" in the UI maps to `sabotageAnswersCount`** — the number of forgeries per card, not a round counter. Renaming that user-facing label is a product decision, not a cleanup.
