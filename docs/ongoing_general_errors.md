# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

---

## 1. Open & in-flight

**4 open issues — the Lobby Lifecycle wave.** All four were filed and selected on **August 9, 2026** after a live three-simulator playtest against production. Implementation specs live in `agent_execution_guide.md` §3–§6.

They are causally linked: Issue 51 is the root defect, it produced the state that made Issue 50 inescapable and Issue 52 look like a bug. Fix 51 first.

---

## ⚠️ Unresolved Issues & Suggestions

### Issue 50: No way to leave a lobby

**Status**: ⚠️ Confirmed Unresolved — verified August 9, 2026. `GameService.leaveRoom()` exists and is correct (`lib/services/game_service.dart:258–290`: cancels the room and player subscriptions, cancels the heartbeat timer, calls the `handleDisconnect` callable, clears the `room_code` and `player_id` keys from `SharedPreferences`, and notifies listeners). The lobby simply never calls it. `lib/screens/lobby_screen.dart:377–386` declares exactly one `AppBar` action — the sound toggle — and supplies no `leading:` widget. A grep across `lobby_screen.dart`, `gaslight_route.dart` and `main.dart` for `PopScope|WillPopScope|Navigator.pop|maybePop|leading:|BackButton|Leave|Exit|Quit` returns **zero matches**. The sole caller of `leaveRoom()` in the entire client is `lib/screens/game_over_screen.dart:289`. Consequence: once a player joins a room, the only exit is reaching game-over or force-quitting the app — and force-quitting leaves the seat behind for 30 s until a peer's staleness sweep prunes it.

**Option A (recommended): `AppBar` exit icon with a confirmation dialog**
- Pros: Matches the existing `AppBar` idiom already used for the sound toggle; discoverable in the standard back-button position; the confirm step prevents a mis-tap from dumping a player out of a room mid-setup; reuses `leaveRoom()` with no service changes; allows distinct host copy warning that leaving ends the room.
- Cons: Consumes the `leading:` slot, so any future navigation affordance must share it; requires two copy strings (host vs non-host); the dialog needs an `AppMotion.reduce(context)` path like every other animated surface.

**Option B: A `LEAVE` button inside the bottom sheet, beside `READY`**
- Pros: Sits where the player's attention already is; leaves the `AppBar` untouched.
- Cons: Crowds the primary action at 360×640 dp, where the sheet already carries the ready state, the ready counter and the "Waiting for Host…" line; places a destructive action adjacent to the most-tapped control in the screen, inviting mis-taps; hard to keep both targets ≥ 48 dp.

**Option C: `AppBar` icon plus a `PopScope` handler for system back and edge-swipe**
- Pros: Most complete coverage — the iOS edge-swipe and the Android hardware back both leave cleanly instead of silently doing nothing.
- Cons: `PopScope` must be suppressed during the join transition and any route push, or it fires against a half-built room; interacts with the custom transitions in `gaslight_route.dart`; materially more surface to test than Option A.

Your selection: **Option A** — selected August 9, 2026.

**Implementation note — the icon codepoint cannot be verified in this repo.** Option A needs a new `ThematicIconType.depart`. The vendored `Phosphor-Light.ttf` carries a `post` table at version 3.0, which stores no glyph names, so no script in this repository can map a name to a codepoint. A cmap presence check is **not** a substitute: the font's cmap spans `0x0020–0xFFFD` and three unrelated candidate codepoints all tested present on August 9, 2026. `0xe674` is the user's proposed value and is present, but presence is not identity. **The only real gate is seeing the glyph render on a simulator** — a wrong codepoint produces a tofu box that passes every automated test in this project.

---

### Issue 52: Non-hosts cannot see which decks exist

**Status**: ⚠️ Working as designed — a UX change, not a defect. Verified August 9, 2026. `lib/widgets/deck_carousel.dart:102–121` returns early whenever `widget.isHost` is false, rendering a single centred `_FolderCard` under the label "THE CHOSEN FILE"; the seven-item `PageView` at lines 123–141 is host-only. Both deck registries are complete and in agreement — six decks in `functions/src/prompt_decks.ts` (`the_daily_grind`, `deep_fears_and_phobias`, `unhinged_quirks`, `romantic_disasters`, `rated_r_nsfw`, `cah_dark_humor`) mirrored in `lib/utils/prompt_decks.dart:7–126`, plus a synthetic `'custom'` entry appended at `lobby_screen.dart:339`. `_familyFriendlyOnly` defaults to `false` (`lobby_screen.dart:43`) and its filter (lines 332–340) drops only the two mature decks, and only while the toggle is on. Nothing is missing or mis-filtered. This was reported as "there is only one deck" because Issue 51 had stranded the reporter as a non-host in a hostless room, where no host was ever going to change the selection.

**Option A: Keep the single card, add an explanatory caption**
- Pros: Near-zero cost and no layout risk at 360×640; removes the confusion directly; preserves the deliberate information hierarchy where a non-host sees exactly the one fact that affects them.
- Cons: Players still cannot see what the game offers, which matters most to a first-time player deciding whether to keep playing.

**Option B (selected): Give non-hosts the full carousel, read-only**
- Pros: Everyone can see the deck catalogue, which is a selling point of the game rather than a setting; makes the lobby feel less inert for non-hosts; the host's active choice can be badged so the actual state stays unambiguous.
- Cons: A swipeable carousel implies agency the player does not have — the selection affordances must be actively suppressed (`onPageChanged` must not call `updateLobbySettings`, and the `_pulseController` stamp animation must not fire on swipe); a non-host swiping away from the host's pick must not lose track of it, so the badge and a snap-back or explicit indicator are load-bearing; more widget-test surface.

**Option C: Change nothing**
- Pros: No work, no risk; once Issue 51 is fixed a non-host always has a live host actively choosing, so the stranded state that caused the confusion cannot recur.
- Cons: Leaves a genuinely opaque moment for anyone who is not the host.

Your selection: **Option B** — selected August 9, 2026.

---

### Issue 53: Nothing reaps rooms that every client has abandoned

**Status**: ⚠️ Confirmed Unresolved — verified August 9, 2026. `functions/src/index.ts` exports fourteen callables and **no** scheduled or triggered function; a grep for `onSchedule|pubsub|scheduler|onDocument|TTL` across `functions/src/` returns zero matches. Room cleanup is therefore entirely client-driven: the staleness sweep at `lib/services/game_service.dart:310–328` only runs inside a client that is currently subscribed to the room, and it can only prune players *other* than itself (line 317). When the last client closes the app, nothing remains to call `handleDisconnect`, and the room document plus its `players` subcollection persist in production Firestore indefinitely. Fixing Issue 51 removes the common path to an abandoned room but not this one.

**Option A: A scheduled cleanup function**
- Pros: Can delete the room document *and* recursively delete its `players` subcollection, which is the only way to fully remove a room; the deletion criterion is expressible in code (all players stale past a threshold) and testable in the emulator suite; runs on a predictable cadence.
- Cons: A recurring scheduled invocation to pay for and monitor; needs a Cloud Scheduler job on the Blaze plan; adds a new class of test to `functions/test/`.

**Option B (selected): A native Firestore TTL policy**
- Pros: No function to write, run, pay for or monitor — the platform performs the deletion; the only application-side change is writing an `expiresAt` timestamp; cannot fail at runtime the way a scheduled function can.
- Cons: **TTL does not cascade to subcollections** — a policy on `rooms` deletes the room document and orphans every document under `rooms/{code}/players`, which then becomes unreachable through the parent but still stored and still billable. A second TTL policy on the `players` collection group is mandatory, not optional. Deletion timing is best-effort and may lag the expiry by up to 24 hours, so a stale room can still be joinable well past its nominal expiry. TTL policies are configured out-of-band via `gcloud`/console, so they are not captured in the repo and will not exist in the emulator or in a fresh project unless someone re-runs the command.

**Option C: Defer**
- Pros: Fixing Issue 51 removes the common case; storage cost of a few orphaned rooms is negligible at current scale.
- Cons: Leaves production Firestore accumulating dead rooms; a 4-letter room code space is small enough that collisions with dead rooms eventually matter.

Your selection: **Option B, at an 8-hour interval** — Option B selected August 9, 2026. The interval was revised twice the same day: +24 h → +1 h → **+8 h**, which is the value in force. TTL is also the more scalable of the two: its work is absorbed by Firestore rather than by a function that must query, batch under a 500-operation limit, and finish inside a wall-clock timeout. What it trades away is semantic precision — it cannot express *"no client is watching"*, only *"this timestamp passed."*

Two consequences are accepted knowingly and are specified in `agent_execution_guide.md` §6:

1. **The second TTL policy on the `players` collection group is mandatory**, because TTL never cascades to subcollections. Skip it and every player document behind a deleted room is orphaned permanently.
2. **Deletion is best-effort** and may lag expiry by up to 24 hours, so an expired room can still be joinable. The emulator does not enforce TTL, so only the writing and refreshing of `expiresAt` is testable.

**Why the interval matters more than it looks — the record of the 1-hour detour.** Nothing in this system tracks presence. A player document's `expiresAt` is written once at join and never refreshed, because the 10-second heartbeat writes `lastSeen` and only `lastSeen`. Room documents are refreshed by writes that already happen, but an idle lobby produces none. The whole design therefore rests on one bet: **every realistic session ends before the timer expires.**

At **+1 h** that bet loses routinely. An idle lobby — players waiting for friends, generating no room writes — would be deleted with people sitting in it, and because Issue 51 turns deletion into a client eviction they would all be thrown to the entry screen. Worse, any game running past sixty minutes would have its **active players' documents deleted mid-play**. That interval consequently required a host-only `touchRoom` callable on a 5-minute client timer, refreshing the room and every player document; it was correct precisely because Issue 51 guarantees a live room always has exactly one host, and it cost roughly 12 invocations per room-hour.

At **+8 h** both failure modes are unreachable — phones sleep and apps background long before an eight-hour idle lobby, and a party game does not run for eight hours — so the keepalive was removed as dead weight, along with all client-side work for this issue.

**The keepalive design is recorded here rather than deleted, because it becomes necessary again the moment the interval drops below roughly 4 hours.** `agent_execution_guide.md` §7 carries that trigger.

---

## 🧪 Resolved Issues & Implementation Refinements

1. **Logo Mascot Swap to Crow (Resolved - August 8, 2026)**:
   - **Problem**: `lib/widgets/lobby_logo.dart` rendered `Image.asset('assets/images/gaslight_mascot.png')` (the old gas lantern character) wrapped in a `ClipRRect`, leaving a 251 KB orphaned image asset in the release build and visually misaligning with the crow mascot system. Furthermore, `body.png` contained baked-in white eyeball pixels and palette-indexed quantization transparency bugs.
   - **Solution**: Replaced `gaslight_mascot.png` with `RavenMascot(state: RavenState.idle, size: 80)` inside an 80×80 container in `lib/widgets/lobby_logo.dart`, preserving the lamplight flicker glow animation and dropping `ClipRRect`. Deleted `assets/images/gaslight_mascot.png` (-251 KB savings). Re-exported `body.png` and `eye_closed.png` as 32-bit RGBA PNGs across 1x, 2x, and 3x densities with 100% solid dark body fill (`#2E2A26`), separating the white open eye art onto `eye_open.png` and the closed brass eyelid arc onto `eye_closed.png`. Added `test/lobby_logo_test.dart` asserting `RavenMascot` presence.

2. **Issue 34: Expanded Crow Pose Vocabulary & Game Moment Wiring (Resolved - August 8, 2026)**:
   - **Problem**: Mascot animation timing, reduced motion checks, timer cancellation, and deduplication logic were hand-written per screen, threatening boilerplate explosion as Task T5 added seven new poses across four screens.
   - **Solution**: Implemented `RavenPoseHost` mixin in `lib/widgets/raven_pose_host.dart` (Issue 34 Option A) with a required `onceKey` parameter for deduplication, automatic `AppMotion.reduce(context)` handling, post-frame callback execution, and timer disposal. Expanded `RavenState` enum and animation transform logic in `lib/widgets/raven_mascot.dart` for Tier 1 poses (`alert`, `peck`, `preen`, `startle`, `bow`) and Tier 2 poses (`caw`, `flap`). Generated Tier 2 assets (`beak_open.png`, `wing_up.png`) at 1x (256x256), 2.0x (512x512), and 3.0x (768x768). Migrated `lobby_screen.dart`, `phase3_vote.dart`, `phase4_reveal.dart`, and `game_over_screen.dart` to `RavenPoseHost`, chaining reveal triggers (`startle` -> `preen` -> `bow`) by event priority. Verified with unit/contract test suites in `test/raven_mascot_test.dart` and `test/raven_pose_host_test.dart`.

3. **Issue 35 / Task T6: Pre-rendered Frame Sequences for Transient Crow Poses (Resolved - August 8, 2026)**:
   - **Problem**: Transform-based layer motion (`Transform.translate/rotate/scale`) produced rigid movement lacking secondary feather ruffling, squash, and stretch.
   - **Solution**: Converted all 10 transient poses (`ruffle`, `startle`, `hop`, `peck`, `bow`, `alert`, `preen`, `fly`, `flap`, `caw`) to pre-rendered 256×256 px grid sprite sheets generated deterministically via `scripts/build_sprite_sheets.py`. Implemented dual-renderer architecture in `lib/widgets/raven_mascot.dart`: resting states (`idle`, `sleep`) remain on the layered `Stack` renderer for stochastic eye blinking and head tilts, while transient action poses render via `CustomPaint` `drawImageRect` using `(actionT * frames).floor().clamp(0, frames - 1)` frame indexing math with precached `ui.Image` handles and proper `.dispose()` teardown. Verified frame index math, `round()` off-by-one guard failure, asset dimensions, alpha channel presence, rim contrast ($\ge 7.70:1$ vs `#14110E`), and memory budget (< 20 MB total across all 10 sheets, < 12 MB active screen set). Total iOS app size measured at **46.0 MB**.

5. **Issue 51: Host Lobby Exit Room Closure (Resolved - August 9, 2026)**:
   - **Problem**: When a host left a lobby, `handleDisconnect` (`functions/src/index.ts`) checked `hasCard = room.cards.some(...)` and returned early before reaching host transfer, leaving player documents intact without a host. Furthermore, `GameService.dart` lacked an `else` branch in its room snapshot listener, stranding remaining clients in an unstartable, inescapable lobby without notice.
   - **Solution**: Implemented Option A phase-gating in `handleDisconnect`: if `disconnectedPlayer?.isHost === true` and `currentPhase === "lobby"`, all player documents and the room document are deleted in transaction, returning `{ success: true, roomClosed: true }`. In `GameService.dart`, extracted `_clearLocalRoomState()`, updated room listener to set `_roomClosed = true` on room deletion (`else if (_gameState != null)`), and added post-frame SnackBar eviction notice in `LobbyScreen` (`"The host has left. This room has closed."`).
   - **Observed Falsifying Output**:
     ```text
     1) closes the room when the host disconnects in the lobby:
        AssertionError: expected undefined to be true
        + expected - actual
        -undefined
        +true
     ```
   - **Over-reach Guard**: Verified in-game host transfer (`currentPhase !== "lobby"`) still transfers host to earliest-joined active player without closing room in both TS E2E and Dart unit suites (`test/room_closed_test.dart`).


---


## 2. Lessons that still bite

These are kept because each one describes a trap that is **still live in the codebase** — not because it is interesting history. Each points at the contract that now owns the detail.

### 2.1 `null` is not "absent" across the Dart ↔ TypeScript boundary
Dart sends an omitted optional as `null`; TypeScript's `!== undefined` guard treats that as a real value and writes it. This erased lobby settings and made the game unstartable (Issue 31). **Clients must omit keys rather than send null; callables must guard with loose `!= null`, never a falsy check** — `false` and `0` are legitimate values. Full contract: **`design_database_and_security.md` §7**.

### 2.2 The test harness has four structural blind spots
Each has hidden a real bug. None is a flaw to fix — they are limits to design around:
- **The emulator suite is written in TypeScript**, so an omitted key genuinely *is* `undefined` there. It cannot produce the payload the Dart client actually sends. Issue 31 lived behind this.
- **Client tests use a fake Firestore that does not enforce `firestore.rules`**, so non-host writes and `authUid` checks are never really exercised. Use real simulator clients for anything that must be correct — bots are server-seeded documents and do not exercise the client path at all.
- **`Image.asset` loads no bytes under `flutter test`.** `find.byType(Image)` counts widgets whether or not art exists, and a golden render of the mascot comes out blank. Verify art by decoding the PNG (`test/helpers/png_decoder.dart`) or on a simulator.
- **Bare `flutter analyze` reports ~678 errors** from vendored plugin source under gitignored `build/`. Always scope it: `flutter analyze lib test`.

### 2.3 Stream-rebuild guards are load-bearing
Firestore streams rebuild constantly. Every animation, sound and mascot pose is gated behind a **once-per-event key** (the `_advancedStateKeys` pattern; `_playedRevealForTargetId`; `_knownPlayerIds`). Remove one and the effect re-fires on every tick. A missing key is invisible in code review and only shows up on device — which is why Issue 34 makes the key a required argument.

### 2.4 Validate type and range before comparing
`3 <= null` is `false`, so a range check silently passes and the function returns an empty result far from the cause. Reject nonsense input outright and throw a readable `HttpsError`, not a raw `Error` — raw errors flatten to `INTERNAL` and tell the player nothing. Detail: **`design_rotation_engine.md` §5**.

### 2.5 Measure; do not estimate, and do not trust a test's name
- A layout overflow estimated at ~275 dp measured **593 dp**.
- A mascot shipped at **1.02:1** contrast — invisible — with a fully green suite.
- A test titled *"…rim contrast >= 4.5:1"* asserted only that a file was non-empty. **Read the assertion, not the title.**

### 2.6 `IconData` is a `final class`
`phosphor_flutter` extends it and therefore **cannot compile** on this SDK. Proven twice. The app vendors the Phosphor Light font directly instead. Detail: **`design_ui_direction.md` §7**.

### 2.7 Everything mutating goes through a Cloud Function
Clients read Firestore streams and write nothing to rooms; `firestore.rules` denies it. Transactions read before write. Detail: **`design_database_and_security.md`**.

---

## 3. Deliberately not built — do not re-propose

These were designed, costed and consciously **not** selected. Their absence is a decision, not an oversight:

- **P7 — Confidence Wager** ("seal it in blood"): stake points on your own forgery.
- **P9 — House Cards**: per-round modifiers.
- **P11 — The Final Gambit**: a comeback round for trailing players.
- **Issue 30 Option C**: making `_familyFriendlyOnly` a synced house rule. It stays client-local.
- **Issue 34 Option C**: priority arbitration between mascot poses. Available as an upgrade if reveal-screen collisions prove annoying in practice.

---

## 4. Resolved — index only

64 items resolved between May 24 and August 7, 2026. Full text is in `git log`; the durable consequences are in the design docs. Grouped by what they touched:

| Area | Items | Where the surviving contract lives |
|---|---|---|
| **Write architecture & multiplayer** — non-host writes blocked by rules, read-after-write transaction order, unhandled server errors, direct client writes in debug tools, full-object writes | Issues 1, 13, 14, 17, 18 + the May race/leak/transaction fixes | `design_database_and_security.md` |
| **Identity & reconnection** — device-stable `playerId`, seat re-binding, anonymous-auth loss, heartbeat volume, disconnect cleanup, host handoff | Issues 16, 36, 42, 15, 34, 35 | `design_database_and_security.md` §4–§5 |
| **Game-loop correctness** — score application on host override, timeout blank cards, inflated scores after disconnect, spectator miscounts, deterministic card resolution, reader re-indexing | Issues 26–35, 21 | `design_rotation_engine.md`, `design_scoring_and_ui.md` |
| **Scoring & honors** — saboteur "found the truth" bonus, metric-based end-game honors | Issues 30, 31 | `design_scoring_and_ui.md` |
| **Prompts & decks** — thematic decks, custom decks, the 3-prompt server cap, re-roll | Issues 22, 48, P4, P10 | `design_prompt_system.md` |
| **Duplicate answers** — Gemini replaced by a local lexical heuristic mirrored byte-identically on both sides | Decision 2 | `design_semantic_integrity.md` |
| **Secrets** — Gemini/Firebase key exposure in the client binary; keys moved to `.env`, Gemini removed entirely | Issues 3, 14 | §2.7 above; `.env` is gitignored and ships inside the IPA |
| **UI programme** — M1–M5 mobile-first, V1–V5 character work, U1–U8 UX, E7 sound | 49 + the M/V/U proposal sets | `design_ui_direction.md` §10 |
| **Icons & mascot** — hybrid icon system, the `final class IconData` blocker, vendored font, mascot redraw, hollow-body fill | Issues 23, 28, 29, 32, 33 | `design_ui_direction.md` §7 and the mascot block |
| **Lobby & house rules** — entry-form fit at 360×640, House Rules consolidation, non-host read-only, settings-wipe crash | Issues 24, 25, 27, 30, 31 | `design_ui_direction.md` §10; `design_database_and_security.md` §7 |
| **Test infrastructure** — emulator + rules unit suite, coverage gaps, real PNG decoding and contrast assertions | Issue 41, Tasks T1–T3 | §2.2 above |
| **Dependencies** — unused `cupertino_icons` removed; Phosphor font vendored | Tasks T2, Issue 29 | `design_ui_direction.md` §7 |

---

## 5. Where the detail lives now

| Looking for | Go to |
|---|---|
| What to work on next, and how to validate it | `agent_execution_guide.md` |
| Backend write contract, security rules, identity | `design_database_and_security.md` |
| Card passing, disconnect recalculation, input validation | `design_rotation_engine.md` |
| Scoring, routing, screen architecture, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, motif, icons, mascot, UI programme | `design_ui_direction.md` |
| Prompt decks and custom decks | `design_prompt_system.md` |
| Duplicate-answer heuristic | `design_semantic_integrity.md` |
| Game phases and data models | `design_game_state_and_models.md` |
| Manual playtest journeys | `e2e_testing_journeys.md` |
| Full history of any resolved item | `git log` |
