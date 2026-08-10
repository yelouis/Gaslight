# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

---

## 1. Open & in-flight

**Queue Complete — all active Lobby Lifecycle wave issues delivered, backfilled, and deployed (August 10, 2026).**

---

## 🧪 Resolved Issues & Implementation Refinements

9. **Issue 55: Cloud Functions & Security Rules Production Deployment (Resolved - August 10, 2026)**:
   - **Problem**: Production Cloud Functions had not been deployed since August 7, leaving the Issue 51 host-leave fix un-deployed and the Issue 54 TTL policies inert.
   - **Solution**: Added `"predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]` hook to `firebase.json` (`696c69e`). Preflighted `npm --prefix functions test` (36/36 passing) and deployed functions + rules to `gaslight-46368` (`npx firebase-tools deploy --only functions,firestore:rules --project gaslight-46368`).
   - **Observed Before / After**: Before: all 14 functions read `2026-08-07T05:20`. After: all 14 functions read `2026-08-10T05:07`.
   - **Over-reach Guard**: Created room in production and verified `expiresAt` timestamp set on both room and player documents ~8h ahead; verified security rules deny client writes of `expiresAt`.

10. **Issue 56: One-time Backfill of `expiresAt` on Legacy Documents (Resolved - August 10, 2026)**:
    - **Problem**: Room and player documents created prior to the Issue 55 deployment lacked `expiresAt` timestamps and were permanently exempt from Firestore TTL policies.
    - **Solution**: Added key patterns to `.gitignore` (`*serviceAccount*.json`, `*-adminsdk-*.json`, `*.pem`). Created `scripts/backfill_expires_at.js` using Application Default Credentials (`5e7ae78`). Queried `rooms` collection and `players` collectionGroup, identifying documents missing `expiresAt` while skipping active rooms (`lastSeen < 24h`). Executed `--apply` batch update across 724 documents (97 rooms, 627 players) setting `expiresAt = now + 1h`.
    - **Observed Falsifying Output**:
      ```text
      --- SUMMARY ---
      Rooms missing expiresAt: 97 (Already set: 0, Skipped active: 1)
      Players missing expiresAt: 627 (Already set: 0, Skipped active: 1)
      Executing --apply for 724 total documents...
      Committed batch 1 (400 docs).
      Committed batch 2 (324 docs).
      ```
    - **Over-reach Guard**: Re-ran `--dry-run` and confirmed **0 remaining documents missing `expiresAt`** across both `rooms` and `players` collectionGroup.

11. **Issue 50: Leave Control Motion Path, Double-tap Guard, and Test Finder (Resolved - August 10, 2026)**:
    - **Problem**: `barrierDismissible: !reduceMotion` caused reduce-motion users to lose barrier dismissal while `showDialog` inserted `FadeTransition`. Double-tap guard `_isLeaving` was set after `Navigator.pop()` and reset in `finally`. Test finder `find.byType(IconButton).last` was fragile.
    - **Solution**: Refactored `_confirmLeave` in `lib/screens/lobby_screen.dart` to use `showGeneralDialog` with `barrierDismissible: true` unconditionally, `barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel`, `barrierColor: Colors.black54`, `transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 150)`, and `transitionBuilder` returning static `child` under `AppMotion.reduce` (`eb14c11`). Set `_isLeaving = true` before `Navigator.pop()` without resetting in `finally`. Updated `test/lobby_leave_test.dart` sound toggle finder to `find.byTooltip('Mute')`/`'Unmute'`.
    - **Observed Falsifying Output**:
      ```text
      ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
      reduce-motion users can still dismiss by tapping outside [E]: Expected no matching candidates, Actual: Found 1 widget with text "Leave this room?"
      no transition widget is inserted under reduced motion [E]: Expected no matching candidates, Actual: Found 1 widget with type "FadeTransition"
      ```
    - **Over-reach Guard**: Verified motion-off test (`accessibleNavigation: false`) finds `FadeTransition` ancestor; verified double-tapping confirm leaves room exactly once (`handleDisconnect` calls == 1); all 7 `lobby_leave_test.dart` tests pass cleanly.

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

4. **Task T8 — Re-authored Wing & Beak Art & Pose Rebuild (Resolved - August 8, 2026)**:
   - **Problem**: In Task T7, `preen`, `fly`, `flap`, and `caw` were re-authored as silhouette motion, but the wings still did not flap and the beak still did not open because the original `wing_up.png` and `beak_open.png` layer art sat almost entirely inside `body.png`'s silhouette (`wing_up` only 7% outside, `beak_open` 0% outside).
   - **Solution**: Generated genuine raised wing (`wing_up.png`) and lifted upper mandible (`beak_open.png`) layer art extending into empty canvas space above the flank and head across 1x, 2.0x, and 3.0x densities (`scripts/generate_raven_layers.py`). Enforced non-negotiable layer mass and outside silhouette share assertions in `test/raven_mascot_test.dart` (`wing_up`: 2,411 px mass $\ge 1,200$ px, 71.8% outside share $\ge 40\%$; `beak_open`: 578 px mass $\ge 300$ px, 56.9% outside share $\ge 50\%$). Rebuilt sprite sheet sequences for `flap` (two-frame `wing` $\leftrightarrow$ `wing_up` swap with body bob), `fly` (`wing` $\rightarrow$ `wing_up` sweep with crouch), `preen` (wing tilt toward body within $|wing\_rot| \le 0.12$ rad), and `caw` (`beak_open` overlay with head thrust). Rendered preview stills and animated GIFs (`scripts/build_previews.py`). Total iOS release app size measured at **47.7 MB**. All 99 client tests and 31 backend tests pass clean.

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
   - **Verification (August 10, 2026)**: Branch ordering confirmed correct in source — `hasCard` computed at `functions/src/index.ts:741`, the lobby-host close branch at 744 returning at 749, and the `!hasCard` branch at 753. The lobby branch precedes the `!hasCard` branch, which is the ordering the spec required; reversing it would silently reinstate the original bug.

6. **Issue 52: Read-Only Deck Carousel for Non-Hosts (Resolved - August 9, 2026)**:
   - **Problem**: `lib/widgets/deck_carousel.dart` returned early whenever `widget.isHost` was false, rendering a single centred `_FolderCard` labelled `THE CHOSEN FILE`. Non-hosts could therefore never discover that the game ships six thematic decks plus a custom option; the seven-item `PageView` was host-only. Both deck registries were complete and correctly mirrored, so nothing was missing or mis-filtered — the catalogue was simply unreachable for anyone but the host, which caused it to be reported as "there is only one deck."
   - **Solution**: Removed the non-host early return so both roles render the same `PageView` (`deck_carousel.dart:133`). Suppressed every selection affordance for non-hosts: `_onPageChanged` returns before invoking `widget.onDeckSelected` (line 102) and `_playStampPulse` returns immediately (line 115), so a non-host swipe neither calls `updateLobbySettings` nor fires the stamp animation. Badged the host's live selection with an oxblood/brass `CHOSEN` overlay on the matching card (line 174) and retained the `THE CHOSEN FILE` section label for non-hosts only (line 215). Added a 3-second interaction guard: `_lastSwipeTime` (line 36) is stamped on every page change and consulted in `didUpdateWidget` (lines 83–91), so a stream-driven `selectedDeckId` change animates the page back only when the user has not swiped recently — otherwise the page is left where the reader put it.
   - **Over-reach Guard**: Host behaviour asserted unchanged in `test/deck_carousel_test.dart` — swiping as host still calls `updateLobbySettings` once per settled page (400 ms debounce) and still fires the stamp pulse.
   - **Design contract**: Recorded in `docs/design_prompt_system.md` §67–70 (host view, non-host read-only view, `CHOSEN` badge, 3-second swipe protection).

7. **Issue 53: 8-Hour Firestore TTL Policy — code (Resolved - August 10, 2026)**:
   - **Problem**: Rooms and player documents persisted indefinitely in production Firestore after every client abandoned them. No scheduled or triggered function existed, and the client staleness sweep only runs inside a subscribed client and cannot prune itself, so a room whose players all closed the app was unreachable by any cleanup path.
   - **Solution**: Defined `ROOM_TTL_MS = 8 * 60 * 60 * 1000` and helper `ttlFrom(nowMs)` at `functions/src/index.ts:14–17`. Wrote `expiresAt` at creation on the room and host player documents in `createRoom`, on joining and rejoining player documents in `joinRoom`, and refreshed it on the room writes that already occur (`startGame`, `updateLobbySettings`, `advancePhaseInternal`) — ten sites in total. Added `'expiresAt'` to the player-document field denylist in `firestore.rules:28`, making the timestamp server-owned while leaving the client `lastSeen` heartbeat permitted.
   - **Observed Falsifying Output**:
     ```text
     1) Issue 53: 8-Hour Firestore TTL Policy writes expiresAt on room and players at creation within a +-5-second window:
        AssertionError: expected undefined to have property 'expiresAt'
     ```
   - **Over-reach Guard**: Client updates to `lastSeen` on a player document still succeed while updates supplying `expiresAt` are rejected by the security rules (`functions/test/rules.spec.ts`).
   - **⚠️ Scope of this entry**: the **code** is resolved. The TTL policies were subsequently enabled (item 8), but the feature is **still not live**, because the functions that write `expiresAt` have never been deployed — tracked as **Issue 55**. The separate exemption for documents predating that deploy is tracked as **Issue 56**.

8. **Issue 54: Firestore TTL Policies Applied to Production (Resolved - August 10, 2026)**:
   - **Problem**: Issue 53 shipped the code that writes `expiresAt`, but the two Firestore TTL policies that act on that field had never been created. `gcloud firestore fields ttls list --project=gaslight-46368` returned `Listed 0 items.` No automated test could detect this — the emulator does not enforce TTL, so `npm --prefix functions test` passed 36/36 with the feature entirely inert. The gap survived because the enabling step lives outside the repository, where no gate in the battery can observe it.
   - **Solution**: Applied both policies via the Google Cloud SDK, authenticated as `chengluye@gmail.com`:
     ```bash
     gcloud firestore fields ttls update expiresAt --collection-group=rooms   --project=gaslight-46368 --enable-ttl
     gcloud firestore fields ttls update expiresAt --collection-group=players --project=gaslight-46368 --enable-ttl
     ```
     The `rooms` operation ran a multi-minute backfill scan before returning; both finished `state: ACTIVE`.
   - **Observed Before / After**: before — `Listed 0 items.` After —
     ```text
     name: projects/gaslight-46368/databases/(default)/collectionGroups/players/fields/expiresAt
     ttlConfig:
       state: ACTIVE
     ---
     name: projects/gaslight-46368/databases/(default)/collectionGroups/rooms/fields/expiresAt
     ttlConfig:
       state: ACTIVE
     ```
   - **⚠️ Both policies are ACTIVE and currently delete nothing**, for two independent reasons tracked separately: the functions that write `expiresAt` are not deployed (**Issue 55**), and documents predating that deploy will never carry the field at all (**Issue 56**). Enabling the policies was necessary, not sufficient.
   - **Environment note**: `gcloud` is not on the default `PATH` in this repo's shell — the same quirk that makes `functions/package.json` prepend `/opt/homebrew/bin`. It is installed at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`; invoke it by absolute path.


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

### 2.8 Widget tests on animated screens hang without `accessibleNavigation: true`
Nine widgets in the lobby tree drive `AnimationController.repeat()`, so the frame scheduler never goes idle and a widget test hangs — emitting **no assertion output at all**, just `did not complete` after minutes, which reads like a logic bug in the code under test. Wrap the screen under test in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)`: `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`), so the flag puts every animation on its static path. Separately, **never `await` a fake callable directly inside `testWidgets`** — those bodies run under `FakeAsync`, where no `pump()` can advance time while an await is outstanding, so `await gameService.createRoom(...)` deadlocks; wrap it in `tester.runAsync`. **`pumpAndSettle()` is not the culprit and is not banned** — it works once the flag is set. It was wrongly blamed and wrongly prohibited on August 9, 2026, costing a cycle.

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
