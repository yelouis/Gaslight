# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

---

## 1. Open & in-flight

**0 open issues awaiting a decision.** One item is selected and being implemented:

---

### Issue 34: Each New Mascot Pose Is Hand-Copied Boilerplate — Contain It Before T5 Multiplies It
**Status**: 🔵 **Selected (Option A) — in flight as part of Task T5.** Implementation spec: `agent_execution_guide.md` §3, Steps 1–2. — Not a bug today. This is about the shape of Task T5, which adds up to **seven** new poses across four screens where there is currently **one pose per screen**.

**What the code does now.** Every time the crow reacts, the screen hand-writes the same block — see `phase3_vote.dart:296` and `phase4_reveal.dart:307`:

```dart
if (shouldFire && !AppMotion.reduce(context)) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _ravenTimer?.cancel();
    setState(() { _ravenState = RavenState.hop; });
    _ravenTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) { setState(() { _ravenState = RavenState.idle; }); }
    });
  });
}
```

**The current code is correct** — all four screens were checked and each has exactly one pose timer, cancelled in `dispose()`, 4 out of 4. The concern is not that something is broken; it is that this block has to be copied correctly seven more times, and it has three separate things to get right:

1. **The lifecycle** — check reduced-motion, wait for the frame to finish, cancel the previous timer, check the widget still exists before reverting, and cancel on dispose. Miss the cancel and two timers race: one reverts the pose early, so it flickers or sticks.
2. **The "only once" key** — the game state streams from Firestore and rebuilds constantly, so without a marker saying "already reacted to this card", the pose re-fires on every rebuild and the bird machine-guns. The reveal screen does this with `_playedRevealForTargetId`; the lobby uses `_knownPlayerIds`. **Every new trigger needs its own new key, and a missing one is invisible in code review** — it only shows up when you watch it.
3. **Collisions — new with T5.** Today each screen has one pose, so nothing can conflict. T5 puts **three** on the reveal screen (`preen` when you fooled someone, `startle` when you were fooled, `bow` when the Truth lands) and these can be true in the same moment. With the current pattern the last one to run silently wins, so the bird's reaction to a dramatic beat becomes a coin flip.

**Option A (recommended)**: **One shared helper that owns the whole lifecycle.** Add a small reusable piece each screen mixes in, so a reaction becomes a single line — roughly `raven.play(RavenState.peck, onceKey: cardId)`. It handles the reduced-motion check, frame timing, cancelling the previous pose, the existence check, disposal, and the "only once" de-duplication internally.
  - *Pros*: There is one copy to get right and one set of tests instead of eleven. **Making the "only once" key a required argument is the real win** — the subtlest of the three failures becomes impossible to forget, because the code will not compile without it. Each new pose costs one line, so adding reactions later stays cheap. Screens get noticeably shorter.
  - *Cons*: The four existing reaction sites have to be migrated, which is churn on code that currently works. One more small abstraction for a future reader to learn. On its own it does not decide who wins a collision.

**Option B**: **Move the whole lifecycle inside the mascot widget.** The screen just says "a peck happened" and the crow plays and un-plays it itself.
  - *Pros*: No timer code in any screen, ever again. Cleanup is automatic, because the widget already owns animation controllers and disposes them. Conceptually the animation lifecycle lives with the animation.
  - *Cons*: Changes `RavenMascot`'s constructor, which is currently frozen as an invariant — that needs your explicit sign-off. More importantly it **does not solve the "only once" problem**, because the widget cannot know that a card id changed; screens would still hand-write that part, leaving the subtlest failure exactly where it is. Also needs the API to carry both a resting pose and one-off reactions, which is fiddlier than it sounds.

**Option C**: **Option A, plus a priority order for reactions.** Same helper, but each pose carries a rank so a more important reaction beats a less important one — being fooled outranks fooling someone, which outranks the ceremonial bow.
  - *Pros*: The only option that actually settles the collision. On the reveal screen, the biggest emotional beat wins reliably instead of by accident. Deterministic, so it can be tested.
  - *Cons*: The most work of the three, and it adds a ranking table someone has to keep sensible as poses are added. If in practice the reveal poses never really overlap, this is machinery for a problem that does not occur.

**Option D**: **Change nothing structural; add tests that catch it.** Keep copying the block, and add tests that fire triggers rapidly and assert the crow always returns to its resting pose, plus a check that each screen cleans up its timers.
  - *Pros*: No refactor at all of code that is currently correct. Cheapest to land, and the tests are worth having regardless of which option you pick.
  - *Cons*: Catches the mistake instead of preventing it, and only for the cases someone remembered to test. The boilerplate still grows sevenfold, and a forgotten "only once" key is exactly the kind of thing a test suite tends not to cover until after it has shipped once.

*Effort:* Moderate (A) · Moderate (B) · Large (C) · Small (D). Your selection: Proceed with Option A.

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
