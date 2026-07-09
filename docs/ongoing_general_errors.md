# Ongoing General Errors & Engineering History

## Overview
This document tracks key engineering insights, regression-risk pitfalls, and historical system updates for Gaslight. Major architectural design layers are documented in dedicated system design files under `docs/`.

---

## 🧪 Resolved Issues & Implementation Refinements

1. **Race Condition in `evaluateReadyState` (Resolved - May 24)**:
   - **Problem**: Host evaluation of player readiness was susceptible to race conditions when multiple players marked ready concurrently, leading to duplicate phase advancements.
   - **Solution**: Implemented an in-memory set `_advancedStateKeys` tracking unique state hashes (`roomCode_phase_rotationIndex_readerId`) to ensure each state is only advanced once.
   - **Regression Warning**: Any changes to state evaluation must check `_advancedStateKeys` to prevent double-navigation bugs.

2. **Firestore Listener Leaks (Resolved - May 24)**:
   - **Problem**: Stream listeners for game state and player sub-documents were instantiated without keeping subscription handles, causing them to leak and duplicate on re-joins.
   - **Solution**: Added stream subscription fields `_roomSubscription` and `_playersSubscription` inside `GameService`, ensuring previous streams are cancelled before starting new ones and during `dispose()`.

3. **API Key Exposure & Transactional Integrity (Resolved - May 24/25)**:
   - **Problem**: API keys were previously passed in request URLs. Additionally, concurrent client writes could bypass similarity checks.
   - **Solution**: Moved the API key to the `x-goog-api-key` HTTP header. Applied Firestore transaction blocks around all card answer submissions.

4. **Host-Only Phase Advancement Failure (Resolved - May 24)**:
   - **Problem**: If a host disconnected, phase transitions were permanently frozen.
   - **Solution**: Added a 5-second periodic heartbeat updating player `lastSeen` in Firestore. The host prunes inactive players, and players automatically trigger host transfer if the host document is deleted.

5. **Mid-Game Join State Corruption & Spectator Mode (Resolved - May 25)**:
   - **Problem**: Players joining a game in progress corrupted active player card queues.
   - **Solution**: Late-joining players are assigned `PlayerRole.spectator` and shown passive spectator UIs, and are filtered out of all gameplay loops and readiness calculations.

6. **Mid-Game Disconnect Card Orphans & Recalculation (Resolved - May 25)**:
   - **Problem**: Inactive or disconnected players left orphan cards in the rotation plan.
   - **Solution**: Host bridges the card assignments (bypassing the departed player), dynamically regenerates rotations using `RotationEngine`, and auto-advances the reader.

7. **Redundant Phase Numbering Mismatches in UI and Routing (Resolved - May 25)**:
   - **Problem**: The system mixed conceptual phase numbers, screen headers, and filename numbering, causing confusion.
   - **Solution**: Standardized all screen titles and instructions to use descriptive titles only ("FORGERY", "TRUTH", "THE VOTE", "THE REVEAL") and completely eliminated phase numbers.

8. **Gemini Star Spark Floating Background Animation (Resolved - May 25)**:
   - **Problem**: The particle generator floated '✦' and '✧' sparks resembling the Gemini star logo, which clashed with the gothic deduction theme of the game.
   - **Solution**: Replaced the particle character generator with mystery glyphs ('?', '⚹', '¿') matching the Lora serif theme.

9. **"Return to lobby" Action Freezes/Stalls on Rebuild (Resolved - May 25)**:
   - **Problem**: The button and its BuildContext unmounted during the async database cleanup call `leaveRoom()` before the routing animation could finish, freezing the screen.
   - **Solution**: Captured the `NavigatorState` locally prior to the async call and executed navigation on the captured state.

10. **"Sabotage" Phase Name is Non-Descriptive (Resolved - May 25)**:
    - **Problem**: The enum value `GamePhase.sabotage` clashed with the conceptual goal of the game and was non-descriptive.
    - **Solution**: Renamed `GamePhase.sabotage` to `GamePhase.forgery` system-wide and updated the UI titles, texts, and instructions accordingly.

11. **Missing Simulator and Emulator Networking Instructions (Resolved - May 25)**:
    - **Problem**: Development setup lacked instructions on routing emulator network requests (e.g. `10.0.2.2` for Android emulator loopback).
    - **Solution**: Updated `README.md` with detailed networking setup guidelines for Android Emulators, iOS Simulators, and physical devices.

12. **No Option to Disable the Auto-Advance Timer (Resolved - May 25)**:
    - **Problem**: The writing and voting screens had hardcoded auto-advance timers that could not be turned off for casual play.
    - **Solution**: Added an `isTimerDisabled` field to `GameState`, a configuration toggle in the lobby creation UI, and bypassed timer writes and visibility in game screens when active.

13. **Missing Anonymous Firebase Authentication (Resolved - May 25)**:
    - **Problem**: Secure `firestore.rules` required authentication, but the client never performed sign-in, resulting in write permission errors.
    - **Solution**: Integrated the `firebase_auth` dependency and initiated anonymous sign-in (`signInAnonymously()`) on app startup in `main.dart`.

14. **Gemini API Key Exposure in Client-Side Binary (Resolved - May 25)**:
    - **Problem**: The Gemini API key was loaded in client code and sent in HTTP headers, exposing it to extraction from production binaries.
    - **Solution**: Documented this exposure in `README.md` as a prototyping risk, detailing the migration path to a secure proxy server for production release.

15. **Firestore Heartbeat Write Volume Optimization (Resolved - May 25)**:
    - **Problem**: Player heartbeats ran every 5 seconds, causing excessive write volume and Firestore quota consumption in larger rooms.
    - **Solution**: Optimized the heartbeat interval to 10 seconds and player pruning threshold to 30 seconds inside `GameService`.

16. **Cache Bypass on Missing API Key in SemanticFilter (Resolved - May 25)**:
    - **Problem**: `SemanticFilter._getEmbedding()` checked for `GEMINI_API_KEY` and threw an exception before looking at `_vectorCache`. This caused offline test runs or mock injections to fail open, bypassing similarity filtering.
    - **Solution**: Reordered the logic in `_getEmbedding()` to perform the `_vectorCache` lookup first, bypassing API key checks and network requests for cached terms.

17. **Firebase Anonymous Authentication Configuration Error (Resolved - May 25)**:
    - **Problem**: Running the unmocked E2E integration test `integration_test/real_e2e_test.dart` in Chrome failed on app launch because the cloud Firebase project `gaslight-46368` (configured in `DefaultFirebaseOptions.currentPlatform`) threw a `FirebaseAuthException: [firebase_auth/configuration-not-found]` during `signInAnonymously()`.
    - **Solution**: Enabled the Anonymous sign-in provider in the Firebase Authentication Console for the production project. Additionally, adjusted the test environment virtual viewport size to `1600x2000` to prevent layout warnings/errors on Chrome, and implemented robust waiting routines for `CONTINUE` and `RETURN TO LOBBY` buttons during transition animations.

18. **Animation Timing Collision in `real_e2e_test.dart` (Resolved - May 25)**:
    - **Problem**: When running the unmocked integration test in Chrome, route transition slide-in animations caused interactive buttons (like `CONTINUE`, `I'M READY`, and `RETURN TO LOBBY`) to render outside the virtual bounds of the test viewport (e.g., at X = 1673.4 on a 1600.0 wide viewport). Taps performed during this transition failed the hit-test, causing phase transitions to fail and tests to time out.
    - **Solution**: Added a 1000ms settling delay (`await tick(1000)`) after detecting each transition screen but before tapping the button inside `integration_test/real_e2e_test.dart`.

19. **Missing Target Identity on Reveal Screen Header (Resolved - May 25)**:
    - **Problem**: The reveal screen previously displayed a static `'RESOLVING CARD'` header, lacking a clear label indicating whose card target was being resolved. Additionally, the user requested that forgery author names (`"FORGERY by [Name]"`) remain hidden to preserve secret identities.
    - **Solution**: Updated `lib/screens/phase4_reveal.dart` to dynamically render `'RESOLVING [NAME]\'S CARD'` using the active reader's name. As per design intent, forgery author names were kept anonymous to prevent visual leakage.

20. **GridView Card Height Overflow on GameOverScreen (Resolved - May 25)**:
    - **Problem**: The superlatives cards on the game over screen had unconstrained heights inside a `GridView.count` with a default square aspect ratio. Narrow viewports caused cards to overflow vertically, rendering yellow/black layout warnings.
    - **Solution**: Configured `childAspectRatio: 0.85` inside `game_over_screen.dart`'s GridView to provide sufficient height headroom.

21. **Deterministic Card Resolution Sequence (Resolved - May 25)**:
    - **Problem**: Card resolution sequence was deterministic (based on joining order or ID sorting in Firestore), making the reveal phase predictable and diminishing game surprise.
    - **Solution**: Shuffled active player IDs to generate a `resolutionOrder` stored in Firestore `GameState` when transitioning to the vote phase, and updated `GameService` to resolve cards sequentially using this randomized order.

22. **Limited Thematic Prompt Decks (Resolved - May 25)**:
    - **Problem**: The lobby had a limited selection of prompt themes, and existing decks did not have enough prompts to comfortably support 10-player games without risk of duplication.
    - **Solution**: Added two new decks (`'rated_r_nsfw'` and `'cah_dark_humor'`) with 12 prompts each to `PromptDecks` to guarantee unique prompts for up to 10 players, and updated the lobby dropdown to dynamically support them.

---

23. **Game Lobby and Waiting Room Aesthetic Upgrade (Resolved - May 25)**:
    - **Problem**: The room creation forms, text fields, and avatar selectors utilized standard flat card layouts and lacked the visual depth required for a premium dark-mode card game.
    - **Solution**: Replaced containers with `CrimsonShadowCard` featuring flat dark backgrounds and bold crimson drop-shadows. Upgraded input decorators, dropdown selection styling, and avatar token selectors with crimson focused outlines. Wrapped row controls with `Expanded` components to prevent RenderFlex layout overflows on narrow viewports.

24. **Phase 2 (Crafting) Screen Redesign (Resolved - May 25)**:
    - **Problem**: The prompt card and text entry fields used plain parchment styling and standard font structures, clashing with the dark modern game board style.
    - **Solution**: Configured the screen to display prompts on a charcoal `CrimsonShadowCard` using clean modern sans-serif typography, and updated the typing text field to feature standard modern outline styling and dark black translucent fills.

25. **Phase 3 (Voting) Screen Layout & Grid Upgrades (Resolved - May 25)**:
    - **Problem**: The voting options were presented as a simple vertical scrollable list of rectangular cards, which lacked physical interactivity.
    - **Solution**: Created a custom `CardGrid` widget rendering voting answers in a structured responsive grid of gold-trimmed parchment cards. Implemented local state voting selection displaying a red wax seal monogram stamp overlay when selected, and added a dedicated "CONFIRM VOTE" action button to cast the vote.

---

## ⚠️ Unresolved Issues & Suggestions

> Discovered during a full docs + code-walkthrough of Journeys 1–5 (see `docs/e2e_testing_journeys.md`) on July 8. Each issue below was traced to specific source lines. **These are not yet fixed** — they are documented here for triage. Ordered by severity.

---

### Issue 1: Non-Host Players Are Blocked From All Gameplay Writes by `firestore.rules`
**Status**: ⚠️ Confirmed Unresolved — Verified as a direct contradiction between the client write paths and the deployed security rules.
- `firestore.rules` (line 34): `allow update, delete: if isRoomHost(roomCode);` — **only the host may write the room document.**
- All gameplay state (`cards`, `readyPlayers`, `votes`) lives *inside* the room document (`GameState`), and every player's client writes to it directly:
  - `GameService.submitCardAnswer()` → `transaction.update(roomRef, {'cards': ...})` (`game_service.dart:439`).
  - `GameService.castVote()` → `transaction.update(roomRef, {'cards': ...})` (`game_service.dart:468`).
  - `GameService.setPlayerReady()` → `transaction.update(roomRef, {'readyPlayers': ...})` (`game_service.dart:540`).
- Result: when a **non-host human** submits a forgery/truth, casts a vote, or marks ready, Firestore returns `PERMISSION_DENIED`. The game loop is broken for every player except the host. This is the single most critical blocker for real multiplayer.
- **Why it was never caught**: every automated test drives the game through the *host* `GameService` plus `debugSimulateBotResponses()` (host writes on behalf of `bot_*`), and `test/simulation_test.dart` uses a `FakeFirestore` that does not enforce `firestore.rules`. The non-host human write path is never exercised. See also the open clarification in `design_database_and_security.md` about which write architecture is canonical.

**Option A (recommended)**: **Host-Authoritative Relay via Per-Player "Submission" Docs** — Non-host clients write only to their *own* player document (which the rules already permit via `isOwner(playerId)`), e.g. a `pendingSubmission`/`pendingVote`/`isReady` field. The host listens to the players collection and merges these into the room document's `cards`/`readyPlayers`/`votes`.
  - *Pros*: Keeps the secure host-only room rule intact; aligns with the existing host-authoritative model (host already owns phase advancement, scoring, disconnect handling); the players listener already runs `evaluateReadyState()` (`game_service.dart:276`), so the merge hook has a natural home.
  - *Cons*: Requires refactoring `submitCardAnswer`/`castVote`/`setPlayerReady` into a two-step (player-doc write → host merge) flow; adds one Firestore round-trip of latency per submission; host must be online for any write to land (mitigated by existing host-transfer logic).

**Option B**: **Cloud Function / Callable Relay** — Route all room mutations through a trusted server function that validates the caller and writes the room document with admin privileges.
  - *Pros*: Strongest security posture; removes all trust from the client; centralizes anti-cheat (e.g. enforce self-vote guard, similarity checks server-side).
  - *Cons*: Introduces a backend (contradicts the current "serverless prototyping" stance in `README.md`); cold-start latency; more infra to run and secure the Gemini key (which the README already flags for a proxy migration).

**Option C**: **Loosen the Rule to Any Authenticated Room Member** — Change room `update` to allow any authenticated user who owns a player document in that room.
  - *Pros*: Smallest change; unblocks multiplayer immediately with no client refactor.
  - *Cons*: Any player can overwrite the *entire* room document (scores, phase, other players' answers, votes) — trivially cheatable; abandons the integrity guarantees the current rules were written to provide.

**Validation**:
- Add a widget/integration test that instantiates **two** `GameService` instances against a rules-enforcing emulator (`firebase emulators:exec`), one host + one non-host human, and asserts the non-host can submit a forgery and cast a vote without `PERMISSION_DENIED`.
- Manual: run two devices/emulators (host + joiner), reach FORGERY, and confirm the joiner's SUBMIT actually mutates `cards` in the Firestore console.

Your selection: Proceed with Option A.

---

### Issue 2: Host "PROCEED TO REVEAL" Override Skips Score Application
**Status**: ⚠️ Confirmed Unresolved — Verified in `phase3_vote.dart`. The host-only `SecondaryButton('PROCEED TO REVEAL (HOST)')` in both the waiting view (`phase3_vote.dart:168-170`) and the spectator view (`phase3_vote.dart:355-357`) advances the phase with a raw `gs.updateGameState(state.copyWith(currentPhase: GamePhase.reveal))`.
- The **only** place scores for a card are applied is `GameService._advanceRotationOrPhase()`'s vote→reveal branch (`game_service.dart:616-627`), which calls `ScoringLogic.calculateScores()` + `applyScoreDeltas()`. The reveal screen deliberately does **not** re-apply them (`phase4_reveal.dart:138-139` comment).
- Because the override bypasses `_advanceRotationOrPhase()`, a host who taps this button **permanently loses all points for that card**. It also fails to reset `readyPlayers` and never records the state in `_advancedStateKeys`, weakening the double-advance guard.

**Option A (recommended)**: **Route the Override Through `forceAdvance()`** — Replace both button `onPressed` bodies with `gs.forceAdvance()`, which already guards via `_advancedStateKeys` and funnels into `_advanceRotationOrPhase()` (applying scores, resetting readiness, clearing the timer).
  - *Pros*: One-line change per call site; reuses the exact, already-tested advancement path; keeps scoring, readiness reset, and the duplicate-advance guard consistent with the automatic/timer path.
  - *Cons*: `forceAdvance()` advances even if not everyone has voted (acceptable for an explicit host override, but the button label may warrant a confirmation dialog).

**Option B**: **Remove the Manual Override Entirely** — Delete the button and rely solely on all-ready evaluation + the auto-advance timer.
  - *Pros*: Eliminates the footgun; fewer code paths to keep in sync.
  - *Cons*: Removes the host's escape hatch when a player is stuck/AFK and timers are disabled (Casual Mode), risking a hang.

**Validation**: Unit-test that invoking the vote→reveal transition via the override path yields the same `totalScore` deltas as the all-ready path for an identical `votes` map. Manual: in a 4-player game, have the host tap PROCEED TO REVEAL before all votes are in and confirm the reveal chips and `totalScore` still reflect the applied points.

Your selection: Proceed with Option A.

---

### Issue 3: `forceAdvance()` Never Submits Placeholder Answers for Unready Players
**Status**: ⚠️ Confirmed Unresolved — The design promises auto-filled placeholders on timeout, but the code only advances the phase.
- `master_implementation_plan.md` (line 40): *"An Explicit Auto-Advance Timer will force submit empty/AI responses if players hang the lobby to prevent dead-air."*
- `design_scoring_and_ui.md` (line 54): *"If the timer expires, the host calls `forceAdvance()` to submit generic placeholders for unready players."*
- Actual behavior: `forceAdvance()` (`game_service.dart:567-573`) just calls `_advanceRotationOrPhase()`, whose forgery/truth branches (`game_service.dart:583-604`) reset `readyPlayers` and move on **without writing any answer** for players who never submitted.
- Impact: a card held by an unready forger ends the round with a missing forgery (fewer/zero vote options); a TARGET who never submits during TRUTH advances with an **empty `truthAnswer`**, so the vote screen shows a blank "THE TRUTH" option and the card is effectively unwinnable/confusing.

**Option A (recommended)**: **Fill Placeholders Inside `_advanceRotationOrPhase()` Before Advancing** — For the current forgery rotation and the truth phase, iterate the active players; for anyone missing an answer on their assigned card (`currentCardAssignments`), write a generic placeholder (e.g. `"(No answer submitted)"`) into `sabotageAnswers[playerId]` / `truthAnswer` in the same transaction that advances the phase.
  - *Pros*: Matches documented behavior; guarantees every card has a full option set; keeps the write atomic with the advance.
  - *Cons*: Placeholder answers are trivially identifiable during voting (skews scoring slightly); needs a rule for what counts as "missing" (empty string).

**Option B**: **Only Fill the Truth Placeholder; Allow Missing Forgeries** — Guarantee a non-empty `truthAnswer` on advance, but let short-handed cards keep fewer forgeries.
  - *Pros*: Fixes the worst symptom (blank/unwinnable truth) with minimal logic; fewer "obvious placeholder" tells.
  - *Cons*: Vote option counts become uneven across cards; the dynamic scoring denominator `S` no longer matches actual option counts (interacts with Issue 5).

**Validation**: Simulate a forgery and a truth phase where one active (non-bot) player never submits, fire the timer, and assert every resulting card has a non-empty `truthAnswer` and the expected number of `sabotageAnswers`. Manual: leave one player idle through a timed TRUTH phase and confirm the vote screen shows no blank option.

Your selection: Proceed with Option A.

---

### Issue 4: Readiness Evaluation Isn't Triggered by Room-Document Ready Writes (Advancement Latency)
**Status**: ⚠️ Confirmed Unresolved — `readyPlayers` lives in the **room** document, but the host only re-evaluates readiness from the **players-collection** listener.
- The room snapshot listener (`game_service.dart:241-246`) updates `_gameState` and calls `notifyListeners()` but **does not** call `evaluateReadyState()`.
- `evaluateReadyState()` is invoked only from the players listener (`game_service.dart:276`) and from the acting host's own submit (`phase2_craft.dart:72`).
- Consequently, when a non-host player marks ready (a *room*-doc write), the host does not immediately evaluate. It only advances on the next players-collection change — in practice the 10-second heartbeat (`game_service.dart:182`). This adds up to ~10s of dead time after the last player is ready and, if heartbeats are ever throttled/disabled, risks a stall. (Note: `debugSimulateBotResponses()` masks this in tests by also writing an unused `isReady` field to player docs at `game_service.dart:736`, which forces the players listener to fire.)

**Option A (recommended)**: **Call `evaluateReadyState()` From the Room Listener Too** — In the room snapshot handler, after updating `_gameState`, invoke `evaluateReadyState()` when the host and the phase is advanceable. The existing `_advancedStateKeys` guard already makes this idempotent.
  - *Pros*: Near-instant advancement the moment the last ready write lands; reuses the existing idempotency guard; one small addition.
  - *Cons*: Slightly more frequent evaluation calls (all cheap, all guarded); must ensure `currentPlayer` is resolved before evaluating on early snapshots.

**Option B**: **Remove the Unused `isReady` Player-Doc Field and Rely on Heartbeat Only** — Accept heartbeat-driven evaluation and drop the dead `isReady` write.
  - *Pros*: Simplest; removes misleading dead code.
  - *Cons*: Leaves the ~10s latency in place; poor feel, especially in Casual Mode.

**Validation**: With two `GameService` instances, mark all players ready and assert the phase advances within one event loop tick (no heartbeat wait). Manual: on two devices, confirm the phase flips immediately after the last submit rather than after a visible pause.

Your selection: Proceed with Option A.

---

### Issue 5: `sabotageAnswersCount` Is Overloaded as Both Config and the Scoring Denominator `S`, So Forgery-Phase Disconnects Corrupt Scoring
**Status**: ⚠️ Confirmed Unresolved — The same field feeds the rotation config *and* the scoring denominator `S`, and disconnect handling mutates it.
- `ScoringLogic.calculateScores()` computes `truthReward = ceil((P-1)/(S+1))` with `S = state.sabotageAnswersCount` (`scoring_logic.dart:19`).
- `handlePlayerDisconnect()` during FORGERY rewrites this field: it sets `sabotageAnswersCount: 0` when collapsing to TRUTH (`game_service.dart:358`) and `sabotageAnswersCount: remainingRotations` otherwise (`game_service.dart:371`).
- After a collapse-to-truth, `S = 0` makes `truthReward = ceil((P-1)/1) = P-1` (maximum reward), even though cards may still carry several real forgeries — the scoring EV is badly inflated and no longer matches the actual number of vote options.

**Option A (recommended)**: **Derive `S` Per-Card at Scoring Time** — Compute the denominator from the card's real option count: `S = currentCard.sabotageAnswers.length`, so the reward always matches what voters actually faced. Keep `sabotageAnswersCount` purely as a rotation-config value.
  - *Pros*: Scoring becomes robust to disconnects, uneven cards (Issue 3), and mid-game rotation changes; a single localized change in `ScoringLogic`.
  - *Cons*: Slightly changes documented EV semantics (needs a one-line note in `design_scoring_and_ui.md`); per-card rewards may vary across a game.

**Option B**: **Introduce a Separate Immutable `scoringForgeryCount` Field** — Store the original configured `S` at game start and never mutate it; disconnect logic only touches the rotation config.
  - *Pros*: Preserves a fixed EV across the whole game; clear separation of concerns.
  - *Cons*: Adds a `GameState` field + Firestore serialization; still mismatches reality when cards end up with fewer forgeries than the original `S`.

**Validation**: Unit-test `calculateScores` for a card with 2 forgeries after `state.sabotageAnswersCount` was forced to 0, asserting `truthReward == ceil((P-1)/3)`, not `P-1`. Simulate a forgery-phase disconnect that collapses to TRUTH and verify final scores are sane.

Your selection: Proceed with Option A.

---

### Issue 6: Waiting/Voting "Unready" Counters Include Spectators and the Local Player
**Status**: ⚠️ Confirmed Unresolved — The counters subtract from `gs.players.length`, which includes spectators (and the already-ready local player), inflating the "waiting for N" figure.
- FORGERY/TRUTH waiting view: `int unready = gs.players.length - readyCount;` (`phase2_craft.dart:232`).
- VOTE waiting view: `int unready = gs.players.length - readyCount;` (`phase3_vote.dart:154`).
- Spectators never appear in `readyPlayers` (their readiness is intentionally ignored), so each spectator inflates `unready` by one; the displayed "Waiting for N players…" can never reach 0 in a game with spectators, misleading players into thinking the game is stuck.

**Option A (recommended)**: **Count Against Active Non-Spectators** — Compute `activeCount = gs.players.where((p) => p.role != PlayerRole.spectator).length;` and `unready = activeCount - readyCount;` (clamped at ≥0). The spectator/vote-progress views already use this exact `totalActive` pattern (`phase2_craft.dart:167`, `phase3_vote.dart:278`) and can be reused.
  - *Pros*: Accurate counts; matches the readiness logic in `evaluateReadyState()` which also filters spectators; trivial change.
  - *Cons*: None material.

**Validation**: Widget test with 3 active + 1 spectator, 2 ready, asserting the label reads "Waiting for 1" (not "2"). Manual: join a spectator mid-game and confirm the waiting counter can reach zero.

Your selection: Proceed with Option A.

---

### Issue 7: Game Over Honors Include Spectators/Bots and Duplicate in Small Lobbies
**Status**: ⚠️ Confirmed Unresolved — Honors are derived from the raw `players` list with simplistic index math.
- `GameOverScreen` sorts *all* `players` by `totalScore` (`game_over_screen.dart:22`), including spectators (who never scored) and bots. "🤡 Most Gullible" = `leaderboard.last` (`game_over_screen.dart:104`), so a score-0 spectator is crowned Most Gullible despite never playing.
- "🃏 The Trickster" is just the 2nd-highest *total* scorer (`game_over_screen.dart:26`), not the best deceiver — and in a 2-player game `trickster` falls back to `mastermind`, showing the same player under two honors. See the related open clarification in `design_scoring_and_ui.md` about what each honor should semantically measure.

**Option A (recommended)**: **Filter to Active Non-Spectators + Guard Small Lobbies** — Exclude `PlayerRole.spectator` before ranking, and only render an honor card when a distinct eligible player exists (no duplicates, no empty-lobby crash).
  - *Pros*: Correct, non-duplicated honors; removes the score-0 spectator artifact; small, contained change.
  - *Cons*: Doesn't make "Trickster/Most Gullible" *semantically* accurate (still score-rank proxies) — that requires the clarification below to define real per-role metrics.

**Option B**: **Compute Honors From Real Per-Role Metrics** — Track cumulative saboteur deception count and times-fooled per player during reveals, and award Trickster/Most Gullible from those.
  - *Pros*: Honors become meaningful and fun; rewards the intended behaviors.
  - *Cons*: Requires accumulating per-player stats across cards (new `PlayerState`/aggregation fields); larger change; depends on resolving the design clarification first.

**Validation**: Unit-test honor selection for a 4-player + 1-spectator game asserting the spectator is never selected and no player holds two honors; render the screen for a 2-player game and confirm no duplicate honoree.

Your selection: Proceed with Option A.

