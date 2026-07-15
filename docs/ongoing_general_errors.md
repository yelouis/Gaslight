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
    - **Solution**: Implemented Issue 12 Option B — the screen now registers a `GameService` listener in `initState` (`_onGameServiceUpdate`), removes it in `dispose`, and performs reaction detection in the listener callback (outside the build phase). Verified by the dedicated regression test `test/reaction_cr
38. **Issue 1: Non-Host Players Blocked from Writing by firestore.rules (Resolved - July 12)**:
    - **Problem**: Security rules blocked non-host clients from writing room documents directly, breaking gameplay for all non-host players.
    - **Solution**: Migrated all gameplay mutations to server-authoritative Cloud Functions callables and locked down client room writes in `firestore.rules` (Option D).
    - **Regression Warning**: Never allow clients to write directly to shared room states.

39. **Issue 13: Read-After-Write Transaction Order in Callables (Resolved - July 12)**:
    - **Problem**: Transaction logic in Cloud Functions callables performed writes before reads, causing runtime failures on every submission, vote, or readiness update.
    - **Solution**: Restructured the transaction phase order in `submitAnswer`, `castVote`, and `setReady` to ensure all reads (room and players) complete before any updates are written.
    - **Regression Warning**: Callables must never execute database reads after database writes inside a transaction block.

40. **Issue 14: Unhandled Server Errors & Spinner Lockups (Resolved - July 12)**:
    - **Problem**: Submissions and votes on the client lacked error handling, stranding players on infinite spinners if a network error or similarity check rejection occurred.
    - **Solution**: Wrapped all callable invocations in try/catch/finally blocks to catch exceptions, display Snackbars, and reset the spinner and submission state. Removed dead pre-check filters.

41. **Issue 15: Emulator Integration & Rules Unit Test Suite (Resolved - July 12)**:
    - **Problem**: The game backend and rules were never executed in integration or rules tests, hiding critical transaction and permission regressions.
    - **Solution**: Configured the Firebase Emulator environment and wrote a mocha E2E integration test suite in `functions/test` covering a full 2-client game loop, negative checks, and rules validations.

42. **Issue 16: Device-Stable Identity & Seat Re-Binding (Resolved - July 12)**:
    - **Problem**: Rejoin flow cleared local sessions on UID change, and the client derived playerId from auth uid, causing players to lose seats.
    - **Solution**: Persisted player ID via SharedPreferences and implemented re-bind seating updates.

43. **Issue 17: Direct Client Firestore Writes in Debug Bot Tools (Resolved - July 12)**:
    - **Problem**: Bot simulation directly wrote to Firestore, violating security rules.
    - **Solution**: Ported bot simulation tools to gated development-only callables (`debugAddBots` and `debugSimulateBots`).

44. **Issue 18: Full-Object Client Writes for Reactions & Lobby-Ready (Resolved - July 12)**:
    - **Problem**: Full-map merges could transmit stale values of protected fields.
    - **Solution**: Replaced client writes with targeted, field-scoped updates.

45. **Issue 19: Debug Bots Pruned as "Disconnected" After 30 Seconds (Resolved - July 12)**:
    - **Problem**: `debugAddBots` created bot documents with a real `lastSeen` timestamp, but bots never heartbeat; the client's dead-player detector treated them as stale after 30 seconds and called `handleDisconnect` for each, collapsing debug games mid-flow.
    - **Solution**: Bot documents are now created with `lastSeen: null` in `functions/src/index.ts`, which the client dead-player filter explicitly skips. Verified by the emulator test "should add bots with lastSeen set to null" and a 2-minute idle debug game.

46. **Issue 20: "BOTS SUBMIT" Order-Dependence — No Phase Advance if Host Submitted First (Resolved - July 12)**:
    - **Problem**: `debugSimulateBotResponses` merged bot answers/votes and marked bots ready but never ran the all-ready → advance check, so a readiness state completed via the debug path stalled the game until a manual force-advance.
    - **Solution**: Both branches (forgery/truth and vote) of `debugSimulateBotResponses` now compute `allReady` over active players and call `advancePhaseInternal` with the merged cards, mirroring the gameplay callables while preserving the reads-before-writes transaction invariant. Verified by the emulator test "should advance phase when host submits first then bots simulate".

47. **Issue 21: Forgery Authors Flipped Before Guess Tray Appears (Resolved - July 13)**:
    - **Problem**: Reveal sequence advanced on a fixed 1.8-second cadence, flipping authors at stage 4 before the guess tray rendered at stage 5, rendering the guess trivial.
    - **Solution**: Rewired reveal beats to functionally derive current stage from server `unmaskDeadline` and clock time. The unmask guess tray renders in stage 3 (the unmask window), and forgery authors only flip at stage 4 (after the deadline has passed). Verified via widget tests A–D in `test/phase4_reveal_test.dart`.

48. **Issue 22: Server Never Enforces the 3-Prompts-Per-Player Cap for Custom Decks (Resolved - July 13)**:
    - **Problem**: Custom prompt harvesting compiled all custom prompts submitted by players without limiting counts per player, leaving custom decks susceptible to prompt-flooding attacks.
    - **Solution**: Sliced player-submitted custom prompts to a maximum of 3 valid entries per player during harvest in the custom deck branch of `startGame` (and mirrored in `test/fake_functions.dart`). Verified by the backend E2E integration test "should enforce the server-side cap of at most 3 custom prompts per player".

49. **E7 Bundled Sound Effects — Decision 1, Option B (Resolved - July 14)**:
    - **Problem**: The game was silent except for haptics; bundled sound (the highest-impact, lowest-effort "juice" for a party game) was deferred because no licensed audio existed in the repo. Product decision "Decision 1" resolved to **Option B — add sound + mute toggle** with a hard CC0/no-attribution licensing constraint.
    - **Solution**: Sourced four **CC0 (public-domain)** effects from Kenney's Interface/Impact packs — `quill_scratch` (submit), `wax_stamp` (vote/ready), `truth_reveal` (a bell toll for the Truth flip), `unmask_success` (correct revenge guess) — converted to mono 44.1 kHz 16-bit WAV, peak-normalized to −3 dBFS, in `assets/audio/` with `CREDITS.md`. Added the `audioplayers` dependency and `lib/services/audio_service.dart` (singleton, low-latency, every `play*` gated on `soundEnabled`, injectable for tests). Wired triggers at submit (`phase2_craft.dart`), vote + "I'M READY" (`phase3_vote.dart`), and the reveal (`phase4_reveal.dart`) with a **once-per-card guard** (`_playedRevealForTargetId`) and a correct-guess-only unmask sting, both deferred via `addPostFrameCallback`. Added a persisted `soundEnabled` mute toggle (`GameService.toggleSound` + `SharedPreferences`) surfaced as a handbell `ThematicIcon` in the lobby/reveal app bars, documented in the in-app manual. A second CC0 candidate per slot was auditioned via a temporary `audio_review/` kit (since removed); all original picks were kept.
    - **Validation**: `test/audio_service_test.dart` proves the mute contract (exactly one `play` per method with the correct asset path when enabled; zero when muted). Full battery green — `flutter analyze` 0 errors, `flutter test` 19/19, emulator suite 16/16 (backend unaffected).
    - **Note**: Optional `lobby_ambience` loop was intentionally not sourced (Kenney has no ambient bed); revisit only if wanted.

---

## ⚠️ Unresolved Issues & Suggestions

> **No unresolved issues or in-flight decisions remain.** Everything is delivered and verified (July 15 — `flutter analyze` 0 · `flutter test` 30/30 · emulator suite 28/28).

---

### Decision 2: Duplicate-Answer Check — Replace Gemini with a Local Heuristic
**Status**: ✅ DECIDED & DELIVERED (July 15) — replaced Gemini with local lexical similarity heuristic check. See **Resolved #50** for the full solution. Kept below for the decision record.
- **What it means for the player:** When you write a forgery, the game blocks answers that are basically identical to one already on the card (so the round stays a real guessing game). Today that check calls Google's Gemini AI — which needs an API key, costs money per call, adds network lag, and silently does nothing if the key is missing. The player experience is the same or better with a built-in check, minus all that baggage.
- **Decision:** Remove the Gemini path **entirely**. Replace it with a dependency-free **lexical heuristic** (normalize + word-overlap/Jaccard + fuzzy string match), **enforced on the server** (in the `submitAnswer` Cloud Function) and **mirrored on-device** for instant "too similar, try again" feedback before the round-trip. Deterministic, free, offline, and finally unit-testable.
- **Trade-off accepted:** the heuristic catches exact/near-exact and reworded duplicates (incl. the Journey-5 "sleep all day in bed" case) but **not** pure synonyms with no shared words ("a quick nap" vs "sleeping"). For a party game that's fine; if playtests show otherwise, the cheap upgrade is a bundled shallow word-embedding (a few MB, still no API) — noted for later, not building now.
- **Why not keep Gemini as an optional layer:** the user chose full removal for simplicity (no key, no cost, no fail-open ambiguity). 

**Validation**: parity unit tests (identical Dart + TS results), an emulator E2E that rejects an enforced near-duplicate over the callable, and a client widget test proving the on-device pre-check blocks before the server call. See H1 for the full table and cleanup checklist (removing `http`, the README Gemini section, and the dead `SemanticFilter`).

---

### Decision 1: E7 Bundled Sound Effects — Ship Silent or Source Audio?
**Status**: ✅ DECIDED & DELIVERED (July 14) — chose **Option B**; implemented and verified. See **Resolved #49** for the full solution. Kept below for the decision record.
- **What it means for the player:** Sound is the cheapest way to make a party game feel "expensive" — a quill scratch as you write a forgery, a wax *thunk* as you lock a vote, a low string swell as the Truth is revealed. Right now the game is silent except for haptic buzzes. Adding audio would noticeably lift the theatrical, gaslit-parlor mood — but only if it's done with real, licensed assets (bad or unlicensed audio is worse than none).
- **Scope note:** This is the *only* item not marked complete across the whole backlog. Everything else (Issues 1–22, Proposals P1–P6, P8, P10, the visual redesign) is delivered and verified green.

**Option A (recommended for now — no work): Ship Silent.**
Leave E7 audio deferred; haptics + motion carry the feel. Revisit post-launch if playtests ask for sound.
  - *Pros*: Zero effort; no new dependency, bundle-size, or licensing exposure; nothing blocks a store submission; avoids shipping cheap-sounding placeholder audio.
  - *Cons*: The app feels quieter/less premium than competitors; you lose the highest-impact, lowest-effort "juice" a party game can have.

**Option B: Source Licensed Audio + Implement Sound.**
You provide (or approve a budget/source for) royalty-free/licensed clips — quill scratch (submit), wax thunk (vote), low swell (Truth reveal), optionally a soft lobby ambience — placed in `assets/audio/`. An agent then adds an audio dependency (e.g. `audioplayers`), a **mute toggle** in settings, and triggers playback at the commit/vote/reveal moments, silent when muted.
  - *Pros*: Big perceived-quality jump for modest engineering effort; reinforces the theme; better demo/marketing footage and App Store preview video.
  - *Cons*: Requires *you* to supply properly licensed assets (the blocker); adds a dependency + bundle size; needs the mute toggle + a "no playback when muted" test; a little per-platform audio-latency tuning.

**Option C: Procedural/Haptic-Only "Sound Design" (no audio files).**
Skip audio entirely and instead deepen the *haptic* vocabulary — distinct patterns per action (light tap on select, medium on commit, a double-pulse on a correct unmask) — plus stronger visual "sound-like" cues (the wax-stamp flash, screen-shake on a big reveal).
  - *Pros*: No licensing, no audio assets, no bundle cost; still adds tactile feedback variety; fully within an agent's power to build now.
  - *Cons*: Silent players (sound off / desktop web with no haptics) gain little; not a substitute for real audio's emotional lift.

**Validation (if Option B or C chosen)**: For B — widget test asserting no `AudioPlayer.play` fires when muted, and a manual pass that each moment plays its clip at reasonable latency on iOS + Android. For C — manual pass confirming distinct haptic patterns per action and no regression to the existing commit/reveal haptics.

Your selection: Proceed with Option B. However, can you find the audio files or provide instruction to the implementing LLM to find royalty free audio files. Optionally, create a new audio files from scratch using an open sourced model or do it yourself.

**Decision recorded (July 13): Option B — add bundled sound + mute toggle.** Full implementation & validation spec (dependency, `AudioService`, trigger points, mute toggle, tests) plus a complete **asset-sourcing plan** — Route 1: a deterministic, license-free procedural-synthesis recipe (`tool/generate_audio.py`, recommended); Route 2: curated **CC0-only** downloads (Freesound CC0 / Pixabay / Mixkit) with exact search terms; Route 3: open-source generative model as a fallback — is in `docs/agent_execution_guide.md` → item **S1 (E7 Sound)**. The implementing model must supply/generate the assets itself following that plan; only CC0 / public-domain / no-attribution audio may be used.

---

## 💡 New Gameplay & Fun Proposals (July 13) — Delivery Status

> **Verification (July 13 — final, after fixes `fd43ad7` + `d2423e8`; re-verified in the July 13 review pass):**
> - **P10 Custom Decks — ✅ delivered & verified complete.** Lobby contribution form (own-doc, field-scoped writes), host deck sync via `updateLobbySettings`, server harvest/top-up/own-prompt-free assignment (incl. the terminal-fallback edge), and reroll fallback — all proven by the emulator suite and rules tests. The former residual (3-per-player cap, Issue 22) is now **fixed** (Resolved #48) and covered by its own emulator test.
> - **P8 Unmask the Forger — ✅ delivered & verified complete.** Server (`submitUnmaskGuess`, deadline, ±1 scoring) was already correct; the reveal-ordering defect (Issue 21) that made guesses trivial is now **fixed** (Resolved #47) — forgery authors stay sealed through the guess window and flip only after the server `unmaskDeadline` passes, proven by widget tests A–D in `test/phase4_reveal_test.dart`. Fully playable as designed.
> - **P7, P9, P11 declined** — never implement. Original proposals retained below for reference.
>
> **Full battery re-run (July 13 verification pass):** `functions` build clean · `flutter analyze` 0 errors · `flutter test` 16/16 · emulator suite `npm --prefix functions test` **16/16** (incl. revenge-guess scoring, custom-deck assignment, and the 3-prompt cap). No unresolved issues remain.

---

### Proposal P7: Confidence Wager — "Seal It in Blood"
**What it adds:** When voting, you can optionally **double-or-nothing** your vote: seal it in blood-red wax instead of plain wax. Right = double points; wrong = you *lose* the base reward you'd have earned. Every card becomes a personal risk decision, and the reveal gets a second layer of drama ("Bob went ALL IN on a forgery!"). This is the single cheapest way to add tension to every round.

**Options:**
- **Option A (recommended)**: A "Seal in Blood" toggle on the vote confirmation. Wager doubles your gain if correct; if wrong you score `-truthReward` (floor at 0 total for the card). Wagered votes get a distinct blood-seal marker in the reveal.
- **Option B**: Fixed side-bet of exactly 1 point (win +1 / lose −1) — gentler math, less dramatic.

*Effort:* Low–Medium (one boolean per vote, one scoring branch, seal art). Your selection: Don't do this.

---

### Proposal P8: Unmask the Forger — the Revenge Guess
**What it adds:** If you got fooled, the reveal isn't over for you: you get **one guess at WHO wrote the lie you fell for**. Guess right and you steal a point back from the forger. Suddenly being fooled isn't just a loss — it starts a grudge match, and forgers must write lies that don't *sound like them*. This deepens exactly the skill the game is about: knowing your friends.

**Options:**
- **Option A (recommended)**: Fooled voters get a 15-second "Unmask" prompt during the reveal (avatar grid of eligible authors). Correct = +1 to you, −1 to the forger; wrong = nothing. Results shown as a mini second reveal.
- **Option B**: Same guess, but purely for bragging rights (a "🔍 Sharp Instincts" tally, no points) — zero scoring disruption.

*Effort:* Medium (new reveal sub-step, one callable, scoring tweak). Your selection: Yes, proceed with Option A. I like this idea.

---

### Proposal P9: House Cards — Round Modifiers
**What it adds:** Some cards come up "marked by the house": a modifier revealed when voting starts. Examples: **Double Stakes** (all points ×2 this card), **Blackout** (answers visible for 12 seconds, then vote from memory), **Crowded Table** (an extra AI-written decoy answer appears). Modifiers break routine in longer games and create "oh no, THIS card" moments.

**Options:**
- **Option A (recommended)**: Host toggle in the lobby ("House Rules: ON"); ~25% of cards get a random modifier from the three above. Modifier announced with a card-flip flourish at vote start.
- **Option B**: Ship only **Double Stakes** (pure scoring, no UI mechanics) as a first taste.

*Effort:* Medium–High for the full set; Low for Option B. Your selection: No, this doesn't add much. Don't do this.

---

### Proposal P10: Custom Decks — Write Your Own Prompts
**What it adds:** The host (or everyone in the lobby) writes their own prompts before the game — inside jokes, workplace themes, family-safe versions. Custom prompts are what make a party game *yours*; it's the #1 replayability feature this genre has.

**Options:**
- **Option A (recommended)**: Lobby "Custom Deck" builder — every player secretly contributes 2–3 prompts while waiting (great use of lobby dead time); the game shuffles them with a fallback deck if too few. Prompts written by you are never assigned to your own card.
- **Option B**: Host-only paste-a-list editor (simpler, one writer).

*Effort:* Medium (lobby UI + prompts stored on the room doc + draw logic server-side). Your selection: Yes, proceed with Option A.

---

### Proposal P11: The Final Gambit — Comeback Round
**What it adds:** The last card of the game is announced as **The Final Gambit**: all points doubled, and every player more than 5 points behind the leader gets their forgery bonus tripled on that card. Trailing players stay engaged to the very end ("I can still win this"), and the finale actually feels like one.

**Options:**
- **Option A (recommended)**: Double points on the final card + underdog forgery bonus, with a dramatic "FINAL GAMBIT" banner before it starts.
- **Option B**: Double points only (no underdog rule) — simpler to explain.

*Effort:* Low–Medium (scoring branch keyed on last `resolutionOrder` entry + banner). Your selection: Don't do this.

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

