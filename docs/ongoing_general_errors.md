# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

---

## 1. Open & in-flight

**0 open issues awaiting a decision.** One item is selected and in flight:

---

### Issue 35: How Should the Mascot Actually Be Animated?
**Status**: 🔵 **Selected (Option B) — in flight as Task T6.** Implementation spec: `agent_execution_guide.md` §2. Raised after a proposal to generate the crow's animations as GIFs (via Veo) rather than animating it in code. **Task T5 has already shipped code-driven motion**, so this is not blocking anything — it is the question of whether to *change renderer* now that you can watch the current one on a device. That is the right order: judge the real thing, then decide.

**Everything below was measured on August 7, not estimated.**

| Fact | Measured |
|---|---|
| `Runner.app` today | **44.0 MB** |
| Adding the `rive` package — runtime only, no artwork | **48.5 MB, i.e. +4.5 MB** |
| `lobby_background.gif`, one animated loop already shipping here | **3.75 MB** |
| The same background as a static PNG | 757 KB — the GIF costs **5× its still frame** |
| The whole current raven asset system | ~300 KB |

**Two hard technical facts about the GIF route specifically**, since that is what prompted this:
- **Veo outputs video, and video carries no alpha channel.** The crow sits over the tavern wall *and* over the cream parchment sheet. With no transparency it must be chroma-keyed — and what you would be keying is a one-pixel anti-aliased brass rim. That fringes, and the fringe looks wrong against one of the two backgrounds.
- **GIF transparency is 1-bit.** A pixel is fully opaque or fully gone; there is no partial alpha. Even a flawless key yields a jagged rim, degrading exactly the artwork Issue 33 was opened to fix.

**One thing no option escapes:** something must still decide *which* pose, *when*, *once per event*, and *revert to resting*. The Issue 34 pose helper stays either way. Changing the renderer changes the drawing, not the orchestration.

**Option A (recommended)**: **Keep what just shipped — code-driven `Transform` motion.**
  - *Pros*: Zero new bytes and zero new dependencies. Full playback control — play once, hold, reverse, interrupt — because the app owns the `AnimationController`. Real 8-bit alpha, so the rim stays clean on both backgrounds. Reduced motion is a one-line early return. It is built, tested and live, so it is the only option with no unknowns left.
  - *Cons*: Motion is limited to what transforms of flat layers can express — no secondary motion, no squash-and-stretch, no feather ruffle. If it reads mechanical on device, this option cannot fix that.

**Option B**: **Pre-rendered PNG frame sequences.** Numbered frames, with the frame index driven off the controller you already have.
  - *Pros*: Keeps full alpha and full playback control, and composes with everything already built — the pose helper is unchanged. Flat four-colour art compresses hard, so a ten-frame pose is likely tens of KB, not megabytes. **Veo still earns a place here as a motion reference to trace frames from**, which captures most of the appeal of your original idea without the format problems.
  - *Cons*: Every pose becomes N drawings instead of one, and keeping the character consistent across frames is a real risk — the layer generation already showed that drift. Asset count grows quickly.

**Option C**: **Animated WebP, one file per pose.** Strictly the better version of the GIF idea; Flutter plays it natively.
  - *Pros*: Full 8-bit alpha and far better compression than GIF, so none of the format objections above apply. One file per pose is easy to reason about.
  - *Cons*: Playback control is poor — `Image.asset` loops from first build, and "play once then hold" is precisely what a pose needs and precisely what is awkward. You would still ship a static frame per pose for reduced motion, so you maintain both.

**Option D**: **Rive.** Detail below — read it before choosing, because one constraint is decisive.
  - *Pros*: Purpose-built for this exact problem: a rigged character with a named state machine you trigger at runtime, blending between states. Resolution-independent vector, so one file serves every size. `.riv` files are typically kilobytes. By far the richest motion ceiling.
  - *Cons*: **+4.5 MB measured** before any artwork, against an app that just spent two tasks recovering 2.7 MB — and **an agent cannot produce the artwork.**

*Effort:* None (A) · Moderate (B) · Moderate (C) · Large (D). Your selection: Proceed with Option B.

#### Detail on Option D — Rive, since you asked

**Is it like a GIF? Nearly the opposite.** A GIF is a flipbook — pre-rendered raster frames at a fixed resolution, played start to finish. A `.riv` file holds **vector shapes, a rig, and a state machine**; nothing is pre-rendered. The runtime draws it live at any size, and you drive it by firing named inputs ("peck", "startle") rather than playing a clip. It can blend one state into another mid-motion, which no frame-based format can do. That is why the files are kilobytes.

**Can another agent implement it? The answer splits, and the split is the point.**

- ✅ **The code: yes, comfortably.** Add the dependency, load the `.riv`, get a controller, fire a trigger on a game moment. Ordinary Flutter work, and it maps cleanly onto the existing pose helper — `playRavenPose` would fire a Rive trigger instead of setting a `Transform`.
- ❌ **The artwork: no, and there is no workaround.** A `.riv` is authored in the **Rive editor**, a GUI design tool: you draw or import the crow, build a bone rig, define the state machine, name each input, export. **There is no generation API, and neither nano banana nor Veo can output Rive.** You or a designer must rig the bird by hand. Every other option here can be driven end-to-end by an agent; this one cannot. That is the decisive practical difference.
- ⚠️ **A trap if you do pick it.** The Flutter package was rewritten. In `rive 0.14.11` the widely-known API — `RiveAnimation`, `StateMachineController`, `SMITrigger` — **no longer exists**; verified, it fails to compile. The current names are `RiveWidget`, `RiveWidgetController`, `StateMachineNamed`. An agent working from training memory will write the old API first; these verified names are recorded so that costs minutes instead of an afternoon.

---

## 🧪 Resolved Issues & Implementation Refinements

1. **Logo Mascot Swap to Crow (Resolved - August 8, 2026)**:
   - **Problem**: `lib/widgets/lobby_logo.dart` rendered `Image.asset('assets/images/gaslight_mascot.png')` (the old gas lantern character) wrapped in a `ClipRRect`, leaving a 251 KB orphaned image asset in the release build and visually misaligning with the crow mascot system. Furthermore, `body.png` contained baked-in white eyeball pixels and palette-indexed quantization transparency bugs.
   - **Solution**: Replaced `gaslight_mascot.png` with `RavenMascot(state: RavenState.idle, size: 80)` inside an 80×80 container in `lib/widgets/lobby_logo.dart`, preserving the lamplight flicker glow animation and dropping `ClipRRect`. Deleted `assets/images/gaslight_mascot.png` (-251 KB savings). Re-exported `body.png` and `eye_closed.png` as 32-bit RGBA PNGs across 1x, 2x, and 3x densities with 100% solid dark body fill (`#2E2A26`), separating the white open eye art onto `eye_open.png` and the closed brass eyelid arc onto `eye_closed.png`. Added `test/lobby_logo_test.dart` asserting `RavenMascot` presence.

2. **Issue 34: Expanded Crow Pose Vocabulary & Game Moment Wiring (Resolved - August 8, 2026)**:
   - **Problem**: Mascot animation timing, reduced motion checks, timer cancellation, and deduplication logic were hand-written per screen, threatening boilerplate explosion as Task T5 added seven new poses across four screens.
   - **Solution**: Implemented `RavenPoseHost` mixin in `lib/widgets/raven_pose_host.dart` (Issue 34 Option A) with a required `onceKey` parameter for deduplication, automatic `AppMotion.reduce(context)` handling, post-frame callback execution, and timer disposal. Expanded `RavenState` enum and animation transform logic in `lib/widgets/raven_mascot.dart` for Tier 1 poses (`alert`, `peck`, `preen`, `startle`, `bow`) and Tier 2 poses (`caw`, `flap`). Generated Tier 2 assets (`beak_open.png`, `wing_up.png`) at 1x (256x256), 2.0x (512x512), and 3.0x (768x768). Migrated `lobby_screen.dart`, `phase3_vote.dart`, `phase4_reveal.dart`, and `game_over_screen.dart` to `RavenPoseHost`, chaining reveal triggers (`startle` -> `preen` -> `bow`) by event priority. Verified with unit/contract test suites in `test/raven_mascot_test.dart` and `test/raven_pose_host_test.dart`.

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
