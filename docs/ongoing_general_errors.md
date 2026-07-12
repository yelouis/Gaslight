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

32. **Readiness Evaluation Latency / Heartbeat Dead-Air (Resolved - July 10)**:
    - **Problem**: Hosts only evaluated readiness in response to player collection updates or the 10-second heartbeat, leading to up to 10s of dead air after all players submitted ready room-doc writes.
    - **Solution**: Triggered `evaluateReadyState()` on the room snapshot listener inside `GameService.listenToRoom()` for hosts, resulting in near-instant phase advancement.

33. **Lobby "Start Game" Silent Failure (Resolved - July 10)**:
    - **Problem**: When a host tapped "START GAME" with an invalid setup (fewer than 2 players, deck too small, or rounds exceeding players), the service failed silently or threw unhandled exceptions, leaving the host in a confused state.
    - **Solution**: Refactored `startGame()` in `GameService` to validate setup and throw typed, descriptive exceptions. Updated `LobbyScreen` to catch these errors and show SnackBar messages, and added pre-check warning text with conditional disabling of the start button.

34. **Overlap/Multiple Disconnect Cleanup Calls (Resolved - July 10)**:
    - **Problem**: Asynchronous and unguarded host-only disconnect cleanups fired multiple times for the same player across overlapping snapshots, corrupting card counts and round rotation math.
    - **Solution**: Added a `_disconnectsInFlight` set inside `GameService` to filter duplicate disconnect signals, wrapped `handlePlayerDisconnect` in try-finally, and added an early-return check to ensure idempotency.

35. **Random Host Handoff Promoting Spectators (Resolved - July 10)**:
    - **Problem**: Host handoff promoted `_players.first`, which was based on random Firestore document ID ordering and could promote inactive spectator accounts, halting game progress.
    - **Solution**: Added a `joinedAt` timestamp to `PlayerState` during room creation and joining, and rewrote the host promotion code to sort candidate non-spectator players by earliest `joinedAt` (with ID fallback).

36. **Losing Anonymous Identity Locks Rejoining Player (Resolved - July 10)**:
    - **Problem**: If a player's anonymous Firebase UID changed (e.g. storage cleared), tryRejoinSession restored a cached session under the old UID that the rules prevented the new UID from writing to, leaving them locked out.
    - **Solution**: Implemented an interim mismatch check in `tryRejoinSession` comparing authenticated `uid` to saved `player_id`. If a mismatch is detected, it clears the cached keys, returns `false`, and alerts the player in the lobby via SnackBar to rejoin cleanly.
    - **Regression Warning**: This is the *interim* fix only. The durable stable-identity model (Wave C5) is still incomplete on the client — see **Issue 16** below.

37. **Emoji Reactions Called `setState` During `build` (Resolved - July 11)**:
    - **Problem**: `Phase4RevealScreen.build()` invoked `_checkForNewReactions()` synchronously; when another player's reaction arrived (via the players stream, which triggers a rebuild), it called `setState` during the build phase, throwing "setState() called during build" exactly when a reaction landed.
    - **Solution**: Implemented Issue 12 Option B — the screen now registers a `GameService` listener in `initState` (`_onGameServiceUpdate`), removes it in `dispose`, and performs reaction detection in the listener callback (outside the build phase). Verified by the dedicated regression test `test/reaction_crash_test.dart`.

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
**Status**: 🟡 Implemented, NOT yet resolved (July 12) — The Option D migration is built (Cloud Functions + locked-down rules + client callables, with the shipped game rules faithfully mirrored in TypeScript), but it **cannot be verified working**: a fatal transaction-ordering bug (**Issue 13**) makes every submit/vote/ready fail on the real backend, and the mandated emulator validation (**Issue 15**) was never built. Resolve 13 → 15 (and ideally 14, 16–18), run the two-client emulator loop green, then move this issue to Resolved. Original triage below for reference.
*(Original status)*: ⚠️ Verified as a direct contradiction between the client write paths and the deployed security rules.
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

**Verification (July 12):** A second full verification pass reviewed the two new commits (`fix(reveal): defer emoji reaction checks` and `feat(backend): migrate game mutations to Cloud Functions`).
- **Issue 12 is fixed** and moved to Resolved (#37). *Note: you selected Option A (post-frame callback); the implementation used the listed Option B (a `GameService` listener) — functionally equivalent and covered by the regression test `test/reaction_crash_test.dart`.*
- **Issue 1's migration is substantially implemented and faithful:** Cloud Functions exist and compile, `firestore.rules` is locked down (client room writes denied, player docs restricted to cosmetic self-fields), the client routes every mutation through callables, and the shipped game rules are correctly mirrored in TypeScript — per-card `S` scoring + Sharp Eye bonus (`scoring_logic.ts`), timeout placeholders, honor-stat accumulation, atomic+idempotent disconnect handling with join-order host transfer, and the Gemini key server-side with a per-room embeddings cache (removed from `.env.example`).
- **However, Issue 1 CANNOT be marked resolved:** inspection found a **fatal transaction-ordering bug** in the three most-used callables (new **Issue 13**) that makes every submit, vote, and ready-up fail at runtime — and the emulator validation mandated by Wave C4, which would have caught it, was never built (new **Issue 15**). New Issues 13–18 below, ordered by severity. Updated next steps for the implementing model: `docs/agent_execution_guide.md`.

---

### Issue 13: Backend Transactions Read After Writing — Every Submit/Vote/Ready Fails 🔴 CRITICAL
**Status**: ⚠️ Confirmed Unresolved — Verified by code inspection of `functions/src/index.ts`: `submitAnswer` (~415–456), `castVote` (~483–518), and `setReady` (~541–561) all follow the pattern read room → **write** room → **read** the players collection.
- **What it means for the player:** on the new server backend, **nobody can submit an answer, cast a vote, or ready up** — every attempt returns an internal error, for the host too. The game is unplayable end-to-end until this is fixed, which blocks calling Issue 1 done.
- **Root cause:** Firestore transactions require **all reads before any writes**. The late `transaction.get(players)` (used for the "is everyone ready → auto-advance" check) comes after `transaction.update(room)`, so the Admin SDK throws `Firestore transactions require all reads to be executed before all writes.` on **every** invocation — not an edge case.
- **Why tests missed it:** the Flutter suite stubs the backend with `test/fake_functions.dart`, a Dart re-implementation that never executes the real TypeScript (see Issue 15).

**Option A (recommended)**: **Reorder — read the players collection before any write** — In all three callables, fetch players alongside the room read, compute the merged `readyPlayers`, then perform the write and (conditionally) `advancePhaseInternal`, keeping everything in one transaction.
  - *Pros*: Minimal mechanical fix; preserves the atomic "write + auto-advance" design that makes advancement instant and race-free.
  - *Cons*: Reads players on every submit even when not everyone is ready (negligible).

**Option B**: **Split the auto-advance into a second transaction** — Commit the answer/vote/ready first, then run a follow-up transaction that re-reads and advances if all are ready.
  - *Pros*: Slightly cheaper common case.
  - *Cons*: Two transactions to keep consistent; re-opens the duplicate-advance race window the single-transaction design closed.

**Validation**: A single emulator test calling the deployed `submitAnswer` would fail today; after the fix, the Issue 15 two-client emulator loop (submit → vote → ready → advance, zero internal errors) is the acceptance gate.

Your selection: Proceed with Option A.

---

### Issue 14: Server Errors Leave Players Stuck on a Spinner With No Message 🔴 HIGH
**Status**: ⚠️ Confirmed Unresolved — Verified in `lib/screens/phase2_craft.dart` (`_submitAnswer`, lines 27–81) and `lib/screens/phase3_vote.dart` (`_castVote`).
- **What it means for the player:** submits and votes now go to a server, so they can legitimately fail — e.g. the server rejects an answer as "too similar", or the network blips. The screens `await` those calls with **no error handling**: the UI flips to a spinner (`_isSubmitting`/`_submitted = true`) and if the call throws, the player is **stuck on that spinner forever**, with no message, and their answer/vote never landed.
- **Related cleanups in the same paths:** the client still runs a dead `SemanticFilter` pre-check before calling the server (`phase2_craft.dart:50` — no client key, always passes), and `_submitAnswer` calls `setPlayerReady` even though the server's `submitAnswer` already marks the author ready in the same transaction (a redundant extra round-trip).

**Option A (recommended)**: **Try/catch every callable, surface the message, reset the UI** — Catch `FirebaseFunctionsException` in `_submitAnswer`, `_castVote`, and the reader "I'M READY" path; show the server's message in a SnackBar; reset `_isSubmitting`/`_submitted` so the player can retry. Remove the dead pre-check and the redundant `setPlayerReady` call.
  - *Pros*: Players always learn why an action failed and can retry; trims two wasteful round-trips; small contained change.
  - *Cons*: None material.

**Option B**: **Global error channel in `GameService`** — Catch in the service and expose a `lastError` the screens render.
  - *Pros*: One interception point for all future callables.
  - *Cons*: Bigger refactor; screens still need per-action retry-state resets anyway.

**Validation**: Widget test with a stubbed callable that throws → SnackBar appears and the button becomes tappable again. Manual (after Issue 13, on the emulator): submit a near-duplicate answer → "too similar" message shows, field stays editable.

Your selection: Proceed with Option A.

---

### Issue 15: The Mandated Server Validation Was Never Built (No Emulator Tests, No Rules Tests) 🔴 HIGH
**Status**: ⚠️ Confirmed Unresolved — `firebase.json` has no `emulators` block; `functions/` contains zero tests; the Flutter suite substitutes `test/fake_functions.dart`, a Dart re-implementation of the server logic.
- **What it means for the game:** the backend that now runs the entire game has **never been executed by any test** — the suite validates the fake, not the server. That is exactly how the fatal Issue 13 slipped through, and how any future drift between the Dart fake and the TypeScript truth will slip through. It reproduces, one layer up, the same blind spot (host + bots + fake store) that originally hid Issue 1.
- **Wave C4 explicitly required:** a two-client integration test against the Functions + Firestore **emulator**, plus `@firebase/rules-unit-testing` tests proving a client cannot write the room doc, another player's doc, or protected fields.

**Option A (recommended)**: **Build the C4 suite as specified** — Add an `emulators` block to `firebase.json`; write a test that drives **two authenticated clients** through a full 4-player game via the real callables under `firebase emulators:exec`; add rules unit tests for the lockdown; wire both into one documented command.
  - *Pros*: Actually executes the shipped TS + rules; would catch Issue 13 today and all future drift; the only path to honestly resolving Issue 1.
  - *Cons*: Test-infra work (~a day); needs `firebase-tools` locally/CI.

**Option B**: **Rules tests only; manual two-device testing for the loop**.
  - *Pros*: Cheaper; still guards the security posture.
  - *Cons*: Leaves the Issue-13 class of game-loop regressions untested.

**Validation**: The suite is the validation. Acceptance: `firebase emulators:exec` green including the two-client full-game test; a rules test proves `PERMISSION_DENIED` for a client writing `totalScore` or the room doc.

Your selection: Proceed with Option A.

---

### Issue 16: Durable Stable Identity Is Half-Built — the Server Supports It, the Client Never Uses It 🟠 MEDIUM
**Status**: ⚠️ Confirmed Unresolved — Server side is done: `createRoom`/`joinRoom` accept a caller-chosen `playerId`, store `authUid` separately, `joinRoom` **re-binds** `authUid` when a known `playerId` returns (`functions/src/index.ts:211–221`), callables validate `authUid`, and the rules lock `authUid` against client edits. Client side is not: `_getPlayerId()` still uses the **auth uid** as the playerId (`lobby_screen.dart:58`), and `tryRejoinSession` still **clears the session** on an auth/playerId mismatch (the interim guard from Resolved #36).
- **What it means for the player:** Wave C5's promise was "reinstall the app or lose browser storage and **keep your seat and score**." The server can now deliver that — but the client still ties identity to the throwaway anonymous account and self-destructs the session on mismatch, so players **still lose their seat**, and the interim guard actively prevents the server's re-bind path from ever running.

**Option A (recommended)**: **Finish C5 as designed** — Generate a device-stable UUID `playerId` once, persist it in `SharedPreferences`, always use it (never the auth uid). On rejoin mismatch, call `joinRoom` (which re-binds the new `authUid` to the existing player doc) instead of clearing the session.
  - *Pros*: Delivers the promised seat/score recovery; the server work already exists; removes the now-counterproductive guard.
  - *Cons*: One migration wrinkle for sessions saved under uid-as-playerId (they rejoin fresh once).

**Option B**: **Accept the interim behavior permanently** — Keep uid-as-playerId + clear-on-mismatch; document that identity loss = seat loss.
  - *Pros*: Zero work.
  - *Cons*: Wastes the finished server support; reinstalls lose seats/scores — poor for an App Store game.

**Validation**: Emulator test — create a room, simulate a new auth uid with the same stored `playerId`, rejoin → assert the player doc's `authUid` updated and seat/score retained. Manual (web): clear only auth storage mid-lobby, reload, seat survives.

Your selection: Proceed with Option A.

---

### Issue 17: Debug/Bot Tools Still Write Firestore Directly — Dead Under the New Rules 🟠 MEDIUM
**Status**: ⚠️ Confirmed Unresolved — `debugAddBots` and `debugSimulateBotResponses` (`game_service.dart` ~456–575) still batch-create player docs and `transaction.update` the room doc from the client. The new `firestore.rules` denies all client room writes and player creates.
- **What it means for development:** every "DEBUG: ADD 9 BOTS" / "DEBUG: BOTS SUBMIT" button now fails with `PERMISSION_DENIED` in any rules-enforcing environment (production **and** emulator). Journey 2 in `e2e_testing_journeys.md` and the whole one-device dev workflow are broken; they only "work" inside the rules-ignoring FakeFirestore harness.
- **Also:** the now-unreachable `_resetAllPlayersReady`/`updateGameState` remnants in `GameService` are dead code that would be rules-blocked anyway — remove them.

**Option A (recommended)**: **Port the bot tools to dev-only callables** — Add `debugAddBots`/`debugSimulateBots` functions (admin SDK bypasses rules) gated on a `debug: true` room flag or emulator detection; point the existing buttons at them.
  - *Pros*: Restores dev/QA on the real stack; the Issue 15 emulator tests can reuse the bot driver; production stays abuse-safe via the gate.
  - *Cons*: Two more functions to maintain; the gate must be airtight.

**Option B**: **Emulator-only client writes** — Show the buttons only under `USE_EMULATOR` and relax the emulator rules file.
  - *Pros*: No new server code.
  - *Cons*: Emulator rules then diverge from production rules, undermining Issue 15's guarantees.

**Validation**: With rules enforced (emulator): ADD 9 BOTS populates the lobby, BOTS SUBMIT advances the phase, and the same calls are rejected for a room without the debug flag.

Your selection: Proceed with Option A.

---

### Issue 18: Own-Doc Writes Send the Whole Player Object — Stale Fields Can Trip the Rules 🟡 LOW
**Status**: ⚠️ Confirmed Unresolved — `sendReaction` and `toggleLobbyReady` build updates via `p.copyWith(...)` + `updatePlayerState`, which writes the **entire** player map with `merge: true` (`game_service.dart:333`).
- **What it means for the player:** the rules allow changing only cosmetic fields on your own doc; any *changed* value on a protected field denies the whole write. Because the client sends its full local copy, a stale local value — e.g. reacting during the Reveal in the instant before the just-incremented score arrives on the listener — puts `totalScore` in the diff and the write is **rejected**: the emoji (or lobby-ready toggle) silently never happens.

**Option A (recommended)**: **Write only the intended fields** — Replace the full-map merge with targeted updates: `{'lastReaction': …, 'lastReactionAt': …}` and `{'lobbyReady': …}` (the heartbeat already does this correctly for `lastSeen`).
  - *Pros*: Eliminates the race; smaller writes; matches exactly what the rules permit.
  - *Cons*: None.

**Validation**: Unit test asserting `sendReaction` issues an update containing only the two reaction keys. Manual (emulator): react immediately after a reveal begins and confirm the emoji still broadcasts.

Your selection: Proceed with Option A.

---

## 💡 Gameplay & Fun Proposals — ✅ Delivered (July 10)

All six selected proposals (all Option A) were implemented and compile. Detailed specs remain in `docs/implementation_plan_gameplay_and_ui.md` (Wave D); the original brainstorm entries are retained below for reference.
- **P1 Running leaderboard** — standings strip on the Reveal (`phase4_reveal.dart`): non-spectators ranked by score, per-card `▲ +N` delta, tabular figures.
- **P2 Reveal drama** — staggered `_revealStage` sequence, card-flip unmasking (`FlippingRevealCard`), Truth revealed last, "Best Forgery of the Round" banner.
- **P3 Emoji reactions** — reaction tray + floating overlay + `GameService.sendReaction` (own-doc write). Its build-phase crash (Issue 12) is fixed (Resolved #37); a remaining stale-field write race is tracked as Issue 18.
- **P4 Prompt re-roll** — `GameService.rerollMyPrompt` + Truth-phase button, once-per-game via `hasRerolled`. Note: writes the room doc, so for **non-host** players it only lands once **Issue 1 / Wave C** is complete.
- **P5 Lobby warmth** — live roster, `toggleLobbyReady` ready-check, `updateLobbySettings` house rules.
- **P6 Case File share** — `RepaintBoundary` → PNG → `share_plus`, with a web fallback.

---



## 💡 Gameplay & Fun Proposal Specs (reference — all delivered, see summary above)

> Original brainstorm entries retained for reference. All were selected Option A and are now implemented (P3's follow-up defect Issue 12 is resolved; see Issue 18 for a minor remaining hardening item).

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

