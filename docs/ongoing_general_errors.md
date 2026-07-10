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

26. **Host "PROCEED TO REVEAL" Override Skips Score Application (Resolved - July 10)**:
    - **Problem**: The "PROCEED TO REVEAL (HOST)" buttons in `phase3_vote.dart` directly updated the phase via `gs.updateGameState`, bypassing `_advanceRotationOrPhase`'s vote→reveal branch. This resulted in the permanent loss of all points earned on the current card.
    - **Solution**: Replaced the direct state updates with a unified `gs.forceAdvance()` call, ensuring scoring calculations and state resets are consistently applied. Wrapped the action in a user-facing confirmation dialog.

27. **Timeouts Leave Blank/Broken Cards (Resolved - July 10)**:
    - **Problem**: `forceAdvance()` advanced the phase on timeouts but never submitted placeholder answers for unready players, causing blank "THE TRUTH" options or cards with missing forgery options.
    - **Solution**: Defined `kMissingAnswerPlaceholder` in `GameService` and updated `_advanceRotationOrPhase` to atomically insert placeholders for any missing forgery answers (during Forgery phase) or missing truth answers (during Truth phase) before executing the phase transition.

28. **Scoring Inflated to Max Reward After Disconnect (Resolved - July 10)**:
    - **Problem**: Scoring logic used the game-wide `state.sabotageAnswersCount` for the EV denominator `S`. Disconnect handling mutated this configuration field to 0 when collapsing to TRUTH, inflating the truth reward to maximum regardless of actual forgeries present.
    - **Solution**: Updated `ScoringLogic.calculateScores` to dynamically derive `S` from the specific card's `currentCard.sabotageAnswers.length`, making scoring robust to configuration changes and disconnects.

29. **Waiting/Voting "Unready" Counters Include Spectators (Resolved - July 10)**:
    - **Problem**: Waiting and voting counters subtracted ready players from total player count, which incorrectly included spectators. Since spectators cannot mark ready, the counters could never hit zero, misleading players.
    - **Solution**: Filtered the player lists to only count active non-spectators (`p.role != PlayerRole.spectator`) before calculating the remaining unready players count.

30. **Undocumented Saboteur "Found the Truth" Bonus (Resolved - July 10)**:
    - **Problem**: The game awarded a `+1` bonus to saboteurs who also correctly identified the truth on cards they faked, but this was never documented in the design files or in-app instructions.
    - **Solution**: Documented the bonus in `design_scoring_and_ui.md` and added a description for the "Sharp Eye" bonus point to the in-app instructions modal in `lobby_screen.dart`.

31. **Meaningful Metric-Based End-Game Honors (Resolved - July 10)**:
    - **Problem**: End-game honors were based solely on overall score rank, creating duplicate titles in small lobbies and potentially awarding honors (like "Most Gullible") to spectators with 0 points.
    - **Solution**: Added `timesFooled` and `playersDeceived` tracking to `PlayerState` and aggregated them at reveal scoring time inside `GameService`. Rewrote the honors generation on the game over screen to filter spectators, use actual metrics for Trickster and Most Gullible, and select distinct recipients.

---

## ⚠️ Unresolved Issues & Suggestions

> Discovered during a full docs + code-walkthrough of Journeys 1–5 (see `docs/e2e_testing_journeys.md`) on July 8. Each issue below was traced to specific source lines. **These are not yet fixed** — they are documented here for triage. Ordered by severity.
>
> ✅ **All selections made.** Executable, player-language implementation & validation plans now exist:
> - **Bug fixes** (Issues 1–11 + Clarifications 1–2): `docs/implementation_plan_selected_fixes.md` (Waves A→C).
> - **Gameplay features** (Proposals P1–P6, all Option A) **and the visual redesign** (`design_ui_direction.md`): `docs/implementation_plan_gameplay_and_ui.md` (Waves D–E).
>
> Issues 8–11 were selected **Option A**; Proposals P1–P6 selected **Option A**. Their plans are folded into the two docs above (Issues 8–10 → Wave B2–B4, Issue 11 → Wave B5, Proposals → Wave D).

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

**Option D (SELECTED — the Firebase industry standard for a scalable App Store game)**: **Server-Authoritative via Cloud Functions** — A small trusted server (Firebase Cloud Functions) becomes the *only* writer of the shared game. Players **read** the game live for instant UI, but every action (submit, vote, ready, advance, score) goes through a callable function that verifies it's really that player and enforces the rules. Security rules deny all direct client writes to the room. This also lets the Gemini API key live on the server, closing the key-exposure risk the README already flags.
  - *Pros*: Cheat-resistant (no player's phone can rewrite scores/answers); auto-scales with Cloud Functions; the correct posture for a public App Store release; centralizes anti-cheat and the AI similarity check; secures the API key.
  - *Cons*: Largest lift — introduces a backend and requires porting the pure game logic (`rotation_engine.dart`, `scoring_logic.dart`) to TypeScript; adds ~100–300 ms of call latency (fine for a turn-based party game); modest per-invocation cost.

**Validation**:
- Add an integration test with **two** authenticated clients (host + joiner) against the Functions+Firestore **emulator**; assert the joiner can submit/vote/ready and the game advances — the exact path that is impossible today.
- Rules unit tests (`@firebase/rules-unit-testing`) proving a client cannot write `totalScore`, another player's doc, or the room doc.
- Manual: two physical devices on a store build complete a full 4-player loop with no `PERMISSION_DENIED`.

Your selection: Proceed with Option A → **overridden to Option D** per your note ("industry standard for security using Firebase; scalable App Store game").
**Decision (July 9):** Implement **Option D (server-authoritative Cloud Functions)** as the production target — see `docs/implementation_plan_selected_fixes.md` **Wave C**. Optional interim: the Option A host-authoritative shim if a friend playtest is needed before the backend exists (Wave C5).

---

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

---

## 🆕 Newly Discovered Issues (July 9) — Awaiting Selection

> Found in a second, deeper pass over the game loop, lobby, and disconnect/host-transfer logic. Same format as above. Each describes what it means for the player first.

---

### Issue 8: Tapping "Start Game" Can Silently Do Nothing
**Status**: ⚠️ Confirmed Unresolved — Verified in `game_service.dart` `startGame` (line 478) and `lobby_screen.dart` (line 340).
- **What it means for the player:** The host taps **START GAME** and… nothing happens. No message, no game, no explanation. This occurs when there are too few players, when the host chose more forgery rounds than there are players, or when the chosen deck doesn't have enough prompts for the player count.
- **Root cause:** `startGame` bails silently on `_players.length < 2` (`return;` with no feedback) and `throw`s for `players <= rounds` / deck-too-small — but the lobby calls it fire-and-forget (`gs.startGame(_selectedDeck)` at `lobby_screen.dart:341`, not awaited, no `try/catch`), so the exception is swallowed and the host sees nothing. The button is enabled whenever `players.isNotEmpty` (even with 1 player).

**Option A (recommended)**: **Surface Every Failure + Gate the Button** — Make `startGame` throw a descriptive error for all failure modes; in the lobby, `await` it in a `try/catch` and show a `SnackBar`. Additionally disable/annotate START until `players.length >= 2` and `players.length > selectedRounds`, and warn when the deck is too small for the player count.
  - *Pros*: Host always understands why they can't start; prevents dead-button confusion; cheap.
  - *Cons*: Requires threading the deck-capacity check into the lobby (small).

**Option B**: **Auto-Correct Instead of Erroring** — Clamp rounds to `players - 1` and auto-swap to a large-enough deck silently.
  - *Pros*: "Just works," never blocks the host.
  - *Cons*: Hidden behavior changes the host's chosen settings without consent; can surprise players.

**Validation**: Unit — `startGame` throws for 1 player, for `rounds >= players`, and for deck-too-small. Widget — lobby shows a SnackBar on each. Manual — try starting with 1 player and with 5 rounds/3 players; confirm a clear message.

Your selection: Option A.

---

### Issue 9: A Player Who Leaves Can Be "Cleaned Up" Several Times at Once
**Status**: ⚠️ Confirmed Unresolved — Verified in `game_service.dart` `listenToRoom` disconnect loop (lines 284–286) and `handlePlayerDisconnect` (line 302). No in-flight/idempotency guard.
- **What it means for the player:** When someone drops out mid-game, the recovery routine can fire **multiple times for the same person before the first finishes**. That can double-remove cards, shrink the number of rounds more than once, or scramble who-writes-for-whom — occasionally corrupting the game right after a disconnect.
- **Root cause:** The players listener recomputes `disconnected = cardIds.difference(activeIds)` and calls `handlePlayerDisconnect(dpId)` on *every* snapshot until the room write lands. Because that write is async and unguarded, overlapping snapshots (e.g. a heartbeat tick) start a second, third handler for the same id, each reading the same stale state and re-applying mutations.

**Option A (recommended)**: **In-Flight Guard + Idempotency** — Track ids currently being processed in a `Set` and skip duplicates; also early-return if the player's card is already gone, so a late duplicate is a harmless no-op. (Fully resolved later when disconnect handling becomes an atomic server transaction under Issue 1 / Wave C.)
  - *Pros*: Stops double-application; minimal change; composes with the eventual server migration.
  - *Cons*: In-memory guard only protects a single client (acceptable — only the host runs this today).

**Validation**: Fire disconnect detection twice synchronously for one player; assert `cards` shrinks by exactly one and `sabotageAnswersCount` decrements at most once. Manual — kill a bot mid-forgery; confirm exactly one card removed and rotations sane.

Your selection: Option A.

---

### Issue 10: Host Handoff Picks a Semi-Random Player — Possibly a Spectator
**Status**: ⚠️ Confirmed Unresolved — Verified in `game_service.dart` host-transfer block (`_players.first`, line 268). Contradicts `design_database_and_security.md` "longest-in-room" rule.
- **What it means for the player:** If the host leaves, the game is supposed to promote the longest-standing player to run things. Instead it promotes an essentially **random** player — and it can even hand the host role to a **spectator who isn't playing**, which can stall the match because that person has no reason (or ability) to drive it forward.
- **Root cause:** Firestore returns the players collection ordered by document ID (the random auth-uid/uuid), not by join time, so `_players.first` is not the oldest joiner. There is also no `role != spectator` filter before promotion.

**Option A (recommended)**: **Promote Earliest-Joined Active Player** — Add a `joinedAt` timestamp to `PlayerState` on create; on host loss, promote the non-spectator with the smallest `joinedAt` (fallback to smallest id for legacy docs).
  - *Pros*: Matches documented intent; never hands control to a spectator; deterministic.
  - *Cons*: Adds one field + serialization.

**Option B**: **Any Active Player, First to Detect Wins** — Skip join-order; simply promote the first *non-spectator* in the list.
  - *Pros*: Smaller change (no new field).
  - *Cons*: Still non-deterministic ordering; two clients could momentarily both claim host.

**Validation**: Room with host + 2 players + 1 spectator; delete host; assert earliest-joined non-spectator becomes host. Manual — host leaves mid-game; a playing player takes over and the game continues.

Your selection: Option A.

---

### Issue 11: Rejoining After the App Loses Its Anonymous Identity Locks the Player Out
**Status**: ⚠️ Confirmed Unresolved — Verified against `main.dart` `signInAnonymously()`, `lobby_screen.dart` `_getPlayerId()` (uses `currentUser.uid`), and `firestore.rules` `isOwner(playerId)`.
- **What it means for the player:** A player's identity is their anonymous Firebase account. If that account is lost — cleared browser storage on web, reinstall, or a failed silent sign-in — the app makes a **brand-new** identity on next launch. The saved "rejoin" info still points at the old identity, so the returning player can't edit their own record and effectively shows up as a stranger locked out of their seat.
- **Root cause:** `player_id` is cached as the auth `uid`, but the rules require `request.auth.uid == playerId` for a player to write their own doc. After an identity change, cached `playerId != new uid`, so `tryRejoinSession` restores a session the player can no longer write to.

**Option A (recommended)**: **Stable Local Player ID Decoupled from Auth** — Generate and persist a UUID `playerId` once per device (SharedPreferences) and keep it stable across auth changes; treat the anonymous `uid` purely as the auth credential. Adjust rules to map ownership via a server/function check rather than `uid == playerId` (naturally handled when Issue 1 / Wave C moves writes server-side and validates `uid` against the player's recorded `authUid`).
  - *Pros*: Rejoin survives storage/identity loss; cleaner identity model; composes with the server-authoritative migration.
  - *Cons*: Requires storing an `authUid` alongside `playerId` and validating server-side; interim rules can't express this without a function.

**Option B**: **Detect Mismatch and Restart Cleanly** — On rejoin, if cached `playerId != currentUser.uid`, clear the session and send the player to the entry screen with a friendly "please rejoin" message instead of a broken restored state.
  - *Pros*: Small; avoids the silent locked-out state.
  - *Cons*: Player loses their seat/score on identity loss (mid-game they'd rejoin as a spectator).

**Validation**: Simulate `currentUser.uid` changing between sessions; assert rejoin either keeps a stable id (Option A) or cleanly resets (Option B) rather than restoring an unwritable session. Manual (web) — clear site data mid-lobby, reload, confirm graceful behavior.

Your selection: Option A.

---

## 💡 Gameplay & Fun Improvement Proposals (July 9) — Awaiting Selection

> Not bugs — ideas to make Gaslight more fun, sticky, and satisfying. Same option/selection format so you can pick what to build. Ordered roughly by impact-to-effort.

---

### Proposal P1: Running Leaderboard Between Cards
**What it adds:** Right now players only see standings at the very end. A compact leaderboard on the reveal screen (and a quick "standings" flash between cards) creates suspense and rivalry every single round — the "oh I just passed Bob!" moment that keeps party games tense.

**Options:**
- **Option A (recommended)**: A slim ranked strip on the reveal screen (avatar · name · score · ▲/▼ movement since last card).
- **Option B**: A full standings screen that briefly appears between reveal and the next vote.
- **Option C**: Both — strip always, full screen only at the halfway point and end.

*Effort:* Low–Medium (data already exists in `PlayerState.totalScore`). Your selection: Option A.

---

### Proposal P2: Reveal Drama — Sequential Vote Landing + "Best Lie" Callout
**What it adds:** The reveal is where the payoff lives. Instead of showing all votes at once, animate them landing one-by-one, save the Truth for last, then crown the round's **Master Forger** ("Bob's lie fooled 3 of you!"). This is the single biggest "table erupts" moment in games like this.

**Options:**
- **Option A (recommended)**: Staggered vote-chip animation → truth revealed last → "Best Forgery of the Round" banner (ties into the honor stats from Clarification 2 Option A).
- **Option B**: Just the staggered animation, no banner.
- **Option C**: Add suspense audio/haptic stings on each landing (needs bundled sound assets).

*Effort:* Medium. Your selection: Option A.

---

### Proposal P3: Emoji Reactions During Reveal
**What it adds:** Let players fire quick reactions (😂 🤨 🐍 👏) that float over the reveal. Cheap to build, huge for the social, laugh-out-loud feel that makes people want to replay — and great for shareable clips.

**Options:**
- **Option A (recommended)**: A fixed reaction tray; reactions broadcast via the players/room doc and animate for everyone.
- **Option B**: Reactions only (no counts), ephemeral and local-broadcast to reduce writes.

*Effort:* Medium (needs a small realtime channel; trivial once Issue 1's server exists). Your selection: Option A.

---

### Proposal P4: "I Can't Answer This" Prompt Re-Roll (Truth Phase)
**What it adds:** Sometimes your own prompt genuinely doesn't apply to you ("worst breakup" for someone never in a relationship), which produces flat truths. A once-per-game re-roll on your **own** card keeps truths juicy and reduces dead cards.

**Options:**
- **Option A (recommended)**: One re-roll per player per game, only on your own Truth card, drawing an unused prompt.
- **Option B**: Host-configurable number of re-rolls in the lobby (0–2).

*Effort:* Low–Medium (deck already supports unique draws). Your selection: Option A.

---

### Proposal P5: Lobby Warmth — Live Roster, Ready-Check, and House Rules
**What it adds:** The lobby is the first impression. Add live "player joined" flourishes, an optional non-host **ready-check** before start, and a couple of house-rule toggles (e.g., "family-friendly decks only", round count presets). Makes setup feel intentional and social rather than a form.

**Options:**
- **Option A (recommended)**: Live roster animations + ready-check + 2–3 house-rule toggles.
- **Option B**: Just the ready-check (smallest step toward "everyone's actually here").

*Effort:* Medium. Your selection: Option A.

---

### Proposal P6: Post-Game Shareable "Case File" Card
**What it adds:** The Game Over screen already teases "Share to Instagram" (currently a stub). Generate a themed, image-exportable summary — winner, honors, funniest lie of the night — perfect for organic marketing on an App Store launch.

**Options:**
- **Option A (recommended)**: Render an in-theme summary card to an image and hook up native share sheet.
- **Option B**: Copy a text recap to clipboard (fastest, less shareable).

*Effort:* Medium. Your selection: Option A.

