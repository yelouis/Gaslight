# Agent Execution Guide — Active Build: Queue Complete (Issues 58–62) — August 10, 2026

**Queue Status**: **Queue Complete — All Tasks Delivered, Tested & Deployed**. Issues 58–62 are 100% delivered, verified across unit, widget, and E2E simulation test suites, and deployed to production `gaslight-46368`.

**Summary of Accomplishments (August 10, 2026)**:
- **Issue 58 (Contrast)**: All dark-surface text elements styled with `AppColors.ivory` (WCAG AA contrast $\ge 15.36:1$). Contrast guard unit test added in `test/contrast_guard_test.dart`.
- **Issue 59 (Unmask Tray & Errors)**: Unmask tray buttons disabled post-submission driven by `GameState` stream. Exception strings sanitized into friendly user copy.
- **Issue 60 (Layout Overflow)**: Wrapped reveal title in `Expanded` with `TextOverflow.ellipsis` at 360×640 dp.
- **Issue 62 (Sealed Subcollection)**: Answer keys moved to `/rooms/{roomCode}/sealed/{cardId}` subcollection with default-deny rules. Shuffled `options` supplied to voting cards.
- **Issue 61 (Truth-First Ordering & Unlimited Re-rolls)**: Game phase reordered to `truth → forgery → vote → reveal`. Rotation plan generated at `truth → forgery` transition. Unlimited re-rolls enabled during `truth` phase.
- **Carried Regression Guards**: Added bitmap ink-pixel count guard ($\ge 30$ pixels) for `depart` sigil in `test/thematic_icon_test.dart`.
- **Backend Deployment**: All 14 Cloud Functions and Firestore security rules deployed to `gaslight-46368` and verified ACTIVE via `gcloud`.
- **Release Bundle Size**: Re-measured via `flutter build web --release` (50 MB).

Full Battery: `flutter analyze lib test` **0 errors** · `flutter test` **123/123** · `npm --prefix functions test` **37/37**.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**, at text scale **1.3** — the clamped maximum, and the case §4 was never checked against.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`. No raw hex in widget code.
3. **Every animation needs an `AppMotion.reduce(context)` path.**
4. **Text scale clamped 1.0–1.3.** **Touch targets ≥ 48 dp.**
5. **Never render an exception to a player.** `e.toString()` in user-facing copy is a defect, not a fallback (§5).
6. **Server-authoritative.** Clients read Firestore streams and write nothing to room documents; `expiresAt` is server-owned.
7. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

Measured at commit `ca21748`, clean tree.

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** (270 infos/warnings, pre-existing) |
| Client tests | `flutter test` | **121/121** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **36/36** |
| Production functions | `gcloud functions list` | all 14 at `2026-08-10T05:07` |
| Firestore TTL policies | `gcloud firestore fields ttls list` | 2 × ACTIVE |
| Font glyph audit | `scripts/inspect_glyph.py` | 11/11 match their comments |
| iOS release build | `flutter build ios --release --no-codesign` | ⚠️ not re-run since `56c183a` (49.5 MB). §10. |

**Every gate above was green while all five defects in this queue were live.** That is the defining fact of this build: the suite cannot see contrast, layout overflow, double submission, phase ordering, or what a client can read. Do not treat a green battery as evidence for any of them.

**`gcloud` is not on this shell's `PATH`**; it is at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`.

### ⚠️ Ten traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`** — ~678 phantom errors from gitignored vendored plugin source.
2. **Analyze ≠ compile.** Only `flutter test` or `flutter build` surfaces a broken dependency.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions`.
4. **BSD `sed` does not support `\b`.** And **`rg -r` is `--replace`, not "recursive"** — `rg -rn pattern` silently rewrites your matches and returns convincing nonsense.
5. **`Image.asset` loads no bytes under `flutter test`**, and an icon can render as the wrong picture with every test green.
6. **`test/fake_functions.dart` does not enforce `firestore.rules`**, and it models the current `CardModel` shape — §8 changes that shape and the fake must move with it.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation`.** Wrap the screen under test in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)`. Never `await` a fake callable directly inside `testWidgets` (FakeAsync deadlock); wrap in `tester.runAsync`.
8. **`firebase.json`'s `predeploy` hook is load-bearing.** Deploy verification: `design_database_and_security.md` §8.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **🆕 A green suite is not evidence about anything it cannot observe.** See the note under the baseline table.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| 1 | **§3 — Issue 60**, header overflow | Two lines, self-contained, zero interaction. Clears a visible defect immediately. |
| 2 | **§4 — Issue 58**, contrast | Client-only. Its contrast guard is reusable and should exist before more UI work lands. |
| 3 | **§5 — Issue 59**, double submission | Client-only, touches several screens. Independent of the backend work below. |
| 4 | **§7 — Issue 62**, hide the answer key | **Must precede §8.** Backend + model + client reads. |
| 5 | **§8 — Issue 61**, truth phase first | Depends on §7 for safety, and reshapes the same phase machinery §7 touches. |
| 6 | **§6 — the `depart` regression guard** | Carried from the last build; test-only; slot it wherever convenient. |
| 7 | **§9/§10 — re-run the playthrough, re-measure the release build** | Last. Both need everything above to have landed. |

---

## 3. Issue 60 — the unmasking header overflows

**What this means for the user:** a debug overflow stripe across the reveal screen mid-game.

### The gap

`lib/screens/phase4_reveal.dart:701` builds a `Row` with `mainAxisAlignment: spaceBetween` holding an inner `Row` (icon + title, lines 704–722) and the countdown chip (723+). The title `Text` at line 711 has **no `Flexible` or `Expanded`**, so it claims full intrinsic width. With `'REVENGE UNMASKING!'` plus the chip it overflows — **26 px measured** at the reporting device's width, and worse at 360 dp or text scale 1.3.

### Implementation

Wrap the **inner `Row`** in `Expanded` inside the outer `Row`, and the title `Text` in `Expanded` inside the inner one, with `maxLines: 1` and `overflow: TextOverflow.ellipsis`. Both wrappers are needed: constraining only the `Text` still lets the inner `Row` demand its intrinsic width from a `spaceBetween` parent.

Change nothing about the copy, the icon, the chip, or the colours.

### Validation

Flutter reports a `RenderFlex` overflow as an exception during a widget test, which makes this cleanly falsifiable:

- Pump the reveal at **360 dp width** with `textScaler: TextScaler.linear(1.3)` and the `isFooled: true` branch, so the title is the longer `'REVENGE UNMASKING!'`. Assert `tester.takeException()` is `null`. **Falsifying:** today it returns a `FlutterError` naming the overflow.
- **Over-reach guard:** the same assertion with `isFooled: false` (the `'UNMASKING IN PROGRESS...'` branch) and at a wide width — both must also be clean, proving you did not fix one branch by breaking another.
- Assert the title is still findable by text so the ellipsis has not swallowed the whole string at 360 dp.

### Blast radius

`lib/screens/phase4_reveal.dart` · a reveal widget test.

---

## 4. Issue 58 — reveal text is invisible; add a contrast guard

**What this means for the user:** the prompt and every answer on the reveal screen are barely readable — measured at **1.10:1**, where WCAG AA wants 4.5:1.

### The gap

`lib/main.dart:72–78` sets `ColorScheme.dark(surface: AppColors.parchment, onSurface: AppColors.ink)`. That pair is correct: ink `#2C1E16` on parchment `#F4EBD8` is **13.59:1**. But `phase4_reveal.dart` reads `theme.colorScheme.onSurface` for text drawn on **dark** surfaces — the resolving prompt (line ~399, on `ground` `#14110E`) and every answer body (line ~1035, on `groundRaised` `#1C1712`).

| Text | On | Measured | Needs |
|---|---|---|---|
| Prompt, 22 px | `ground` | **1.17:1** | 3.0:1 |
| Answer body, 18 px | `groundRaised` | **1.10:1** | 4.5:1 |
| `ivory` `#F5EEDB` | `ground` | 16.25:1 | — |
| `ivory` `#F5EEDB` | `groundRaised` | 15.36:1 | — |

`colorScheme.onSurface` is read in **11 places across 4 files**: `phase4_reveal.dart`, `phase3_vote.dart`, `lobby_screen.dart`, `card_grid.dart`. **Some are correct** — anything drawn on a `ParchmentCard` genuinely wants ink. A blanket replacement breaks those.

### Implementation

1. **Classify all 11 usages** by the background they actually render on. Do not guess from the file name — `card_grid.dart` draws parchment cards, `phase4_reveal.dart` draws both.
2. For each usage on a **dark** background, replace `theme.colorScheme.onSurface` with `AppColors.ivory`. Leave parchment usages untouched.
3. **Add the guard.** Create a pure unit test — no widget pumping — holding a table of `(foreground, background, minimumRatio)` token pairs and asserting each meets its threshold. Cover at minimum: prompt/`ground` at 3.0, answer/`groundRaised` at 4.5, ink/parchment at 4.5, brass/`ground`, verdigris and oxblood label colours against their card backgrounds.
4. **Reuse the existing WCAG helper in `test/helpers/png_decoder.dart`** — it already computes contrast for the mascot tests. Do not write a second implementation; two contrast functions will diverge.

The guard tests **token pairs**, not rendered pixels. That keeps it deterministic and fast, and it is what makes it cheap enough to keep.

### Validation

- **Observe the guard fail first.** Add it before changing any colour, run it, and record the failing output — it must report the measured 1.17 and 1.10 against their thresholds. A guard that has only ever been green is not known to be a guard.
- **Over-reach guard:** ink-on-parchment must still pass at 13.59:1. If your edit made that fail, you replaced a correct usage.
- **Manual:** the reveal screen at 360×640 dp — the prompt and answers must be plainly readable. Contrast maths is necessary, not sufficient.

### Blast radius

`lib/screens/phase4_reveal.dart` · the other three files if their usages are on dark backgrounds · a new contrast test · `docs/design_ui_direction.md` §3 — record that `onSurface` means *ink on parchment* and must never be used for text on `ground`/`groundRaised`.

---

## 5. Issue 59 — nothing may be submitted twice, and no exception may reach a player

**What this means for the user:** tapping a trickster guess a second time threw a full-screen error with six frames of Dart stack trace across the reveal.

> **User amendment, August 10, 2026:** *"Make sure to guard against anything that shouldn't be submitted twice or clicked twice."* This item is therefore **an audit of every mutating action**, not a fix to one tray.

### The gap

Two defects at the reported site, both patterns rather than one-offs:

1. **No guard.** `phase4_reveal.dart:813` renders an `OutlinedButton` per candidate with an unconditional `onPressed` calling `gs.submitUnmaskGuess(cand.id)`. `GameService.submitUnmaskGuess` (`game_service.dart:399–410`) has no in-flight or already-submitted check. The server correctly rejects the duplicate with `failed-precondition`.
2. **The raw exception is rendered.** `phase4_reveal.dart:815` does `SnackBar(content: Text(e.toString()))`.

### Implementation

**Step 1 — fix the reported site.** Drive the tray's disabled state from **stream state, not a local flag**: the guess already lives in the card's `unmaskGuesses` map, so a player who has guessed can be detected from the room document. A local `bool` resets on rebuild and on reconnect, which reproduces the bug in a new costume.

**Step 2 — audit every mutating action.** For each of these, establish whether a second tap is possible and what happens:

| Action | Screen |
|---|---|
| `createRoom`, `joinRoom` | entry form |
| `startGame` | lobby |
| `setReady` | lobby |
| `updateLobbySettings` | lobby (deck carousel, house rules) |
| `submitAnswer` | craft |
| `rerollPrompt` | craft — see §8, its semantics change |
| `castVote` | vote |
| `submitUnmaskGuess` | reveal |
| `advanceToNextResolution`, `advancePhase` | reveal / host controls |
| `leaveRoom` | lobby, game over — **already guarded**, use it as the model |

For each: prefer a **stream-derived disabled state**; fall back to an in-flight flag only where no server state reflects the action yet. `leaveRoom`'s guard (`_isLeaving` set before `Navigator.pop()`, never reset — Issue 50) is the existing precedent for the in-flight case.

**Step 3 — no `e.toString()` in user-facing copy, anywhere.** Grep the client for it. Replace each with fixed, human copy. For the reported case use exactly: **`That guess is already locked in.`** Where a generic fallback is needed, use exactly: **`Something went wrong. Try again.`** Keep the technical detail — log it with `debugPrint`, do not show it.

### Validation

- **Per guarded surface**, a widget test that taps twice **with no pump between taps**, then pumps, and asserts `fakeFunctions.callableInvocations['<callable>'] == 1`. The Issue 50 double-tap test is the working precedent. **Falsifying:** today the unmask case records 2.
- **A test asserting the error copy**, not the exception: force the callable to throw and assert `find.text('That guess is already locked in.')` is present and that no text containing `'#0 '` or `'package:'` appears anywhere on screen. **Falsifying:** today the stack trace is rendered.
- **Over-reach guard:** a single tap still performs the action exactly once on every audited surface. A guard that blocks the first tap is worse than the bug.

### Blast radius

`lib/screens/phase4_reveal.dart` · `lib/services/game_service.dart` · every screen listed in step 2 that needs a guard · their tests.

---

## 6. Carried: give the `depart` sigil a regression guard

Unchanged from the previous build and still not done. `test/thematic_icon_test.dart` asserts `depart` dispatches to a `CustomPaint`, but `CustomPaint` is present whether or not the painter draws anything — **reverting `case ThematicIconType.depart:` (`app_icons.dart:478–495`) to a bare `break;` would keep the suite green.**

Render `ThematicIcon(type: ThematicIconType.depart, size: 24)` into a `RepaintBoundary`, `toImage(pixelRatio: 4.0)`, decode with **`test/helpers/png_decoder.dart`**, and assert an ink-pixel floor set at roughly **half** the measured value, with the measurement in a comment beside the constant.

**Observe it return 0** with the painter body temporarily reverted, record that output, then restore. **Do not add an identity assertion** — an ink count cannot tell a door from a scribble, and a test named as though it could would be another check that cannot fail.

**Blast radius:** `test/thematic_icon_test.dart` only. No `lib/` changes.

---

## 7. Issue 62 — withhold the answer key until the reveal

**What this means for the user:** today anyone reading the stream the app already subscribes to can see which answer is true before voting, and who wrote each forgery before guessing. Those two facts are the whole game.

### The gap

`CardModel` (`lib/models/card_model.dart:3–18`) puts on the room document:

- `truthAnswer` — the correct answer, in a field named for what it is;
- `sabotageAnswers` — a `Map<authorId, answer>`, labelling every forgery with its author.

`firestore.rules:11` is `allow read: if true`, and it must stay that way — the entire client is built on live room streams. **The fix is what the server writes, not who may read.**

Precedent already in the codebase: `design_database_and_security.md` §1 documents `/rooms/{roomCode}/embeddings/{answerHash}` as having **no client rule and therefore default-deny**, server-only. Use the same shape.

### Implementation

**Step 1 — a sealed, server-only subcollection.** Write the answer key to `/rooms/{roomCode}/sealed/{cardId}`, holding the truth text and the author→answer mapping. **Add no rule for it** — the default-deny in `firestore.rules` is what protects it, exactly as with `embeddings`. Do not add an `allow read: if false`; an explicit rule invites someone to "fix" it later.

**Step 2 — the room document carries an unlabelled, shuffled list.** During forgery and vote, each card exposes only the answer texts with **opaque, stable ids** — no author, no truth flag, no ordering that correlates with authorship. **Shuffle server-side, once, and persist the order**, so the vote UI does not reshuffle on every stream tick.

**Step 3 — votes must reference an answer, not an author.** This is the ripple that is easy to miss. `castVote(targetCardId, voterId, votedForId)` (`game_service.dart:468`) currently sends the **author's id**, which a redacted client cannot know. Change the payload to the opaque answer id and have the server resolve id → author from the sealed document. Scoring already runs server-side and is otherwise unaffected.

**Step 4 — merge at the reveal transition.** The server already performs the vote → reveal transition; that is where the sealed data is folded into the room document so the reveal screen can show `THE TRUTH` and `FORGERY BY X`. After that point the current client reads work unchanged.

**Step 5 — the fake must move with the model.** `test/fake_functions.dart` mirrors the callables and the card shape (§1 trap 6). If it is not updated in the same commit, every client test that touches a card breaks or — worse — keeps passing against a shape production no longer has.

### Validation

- **`functions/test/game_e2e.spec.ts`, the falsifying assertion:** play to the vote phase, read the room document as a client would, and assert the card object has **no `truthAnswer` property** and that its answers carry **no author attribution**. **Falsifying:** today `truthAnswer` is right there in plain text.
- **A second assertion at the reveal transition:** after the phase advances, the truth and authorship **are** present — proving you redacted rather than deleted.
- **Rules test:** a client read of `/rooms/{code}/sealed/{cardId}` is **denied**. Pair it with the existing proof that `/rooms/{code}` itself is still readable, so the over-reach is visible.
- **Over-reach guard:** a full game still completes end to end with correct scores, in both the emulator suite and the Dart simulation. Scoring depends on the author mapping; if it moved and scoring was not updated, this is where it shows.

### Blast radius

`functions/src/index.ts` (`startGame`, `submitAnswer`, `castVote`, `advancePhaseInternal`) · `lib/models/card_model.dart` · `lib/services/game_service.dart` · `lib/screens/phase3_vote.dart`, `phase4_reveal.dart` · **`test/fake_functions.dart`** · `functions/test/game_e2e.spec.ts`, `rules.spec.ts` · `docs/design_database_and_security.md` §1 and §3 · `docs/design_scoring_and_ui.md`.

---

## 8. Issue 61 — the truth phase comes first, with unlimited re-rolls

**What this means for the user:** today everyone writes lies first and the card's owner answers last — and can then re-roll the prompt, leaving every lie answering a question nobody can see.

> **User amendment, August 10, 2026:** *"Change the design contract to reflect this new ordering. Also allow the prompt to be re-rolled as many times as needed during the truth phase since it comes first."* The once-per-game limit is **removed**.

### The gap

`startGame` sets `currentPhase: "forgery"` (`functions/src/index.ts:401`); `advancePhaseInternal` moves forgery → truth (931) → vote (958). And the re-roll has **no phase guard at all** — not on the client (`phase2_craft.dart:473` gates only on `!me.hasRerolled && !isTimerLast5Sec && !_isSubmitting`) and not on the server (`index.ts:673+` checks auth, ownership, `hasRerolled`, card existence). `design_database_and_security.md` §2 documents it as *"truth phase only"*; **that guard was never written.**

### Implementation

**Step 1 — reorder the phases.** `startGame` opens in `currentPhase: "truth"`. `advancePhaseInternal`'s transition table becomes **truth → forgery → vote → reveal → gameOver**.

**Step 2 — move assignment generation.** The rotation engine currently builds forgery assignments at game start, which assumed forgery ran first. Generate them when the **truth phase closes**, so they are built against prompts that are now final.

**Step 3 — the re-roll becomes unlimited, and truth-phase-only.**
- **Server (`rerollPrompt`)**: **remove** the `hasRerolled` check; **add** a phase guard rejecting any call when `currentPhase !== "truth"` with a `failed-precondition`.
- **Client (`phase2_craft.dart:473`)**: drop `!me.hasRerolled`; keep `!isTimerLast5Sec && !_isSubmitting`; add a truth-phase condition so the control does not appear during forgery.
- **`hasRerolled` becomes dead.** Remove it from `PlayerState` and from the writes. **Leave `'hasRerolled'` in the `firestore.rules` denylist** — denying writes to a field that no longer exists is a harmless no-op, and removing it is a rules change with no upside.

**Step 4 — handle deck exhaustion, which unlimited re-rolls make reachable.** `PromptDecks.drawOneExcluding` **throws** when no unused prompt remains. Two decks ship only 12 prompts (`rated_r_nsfw`, `cah_dark_humor`), so a determined player will hit this. Catch it and surface fixed copy — **`No more prompts left in this deck.`** — and leave the current prompt in place. **Do not let this reach the player as an exception** (§5).

**Step 5 — the enum order.** `game_state.dart:3` reads `{ lobby, forgery, truth, vote, reveal, gameOver }`. Reordering to put `truth` before `forgery` is **safe**: `GameState.fromMap` resolves the phase by **name** via `GamePhase.values.firstWhere` (line 137), not by index. Verify that is still true before you touch it — if any serialization by index has appeared, leave the enum alone; it is cosmetic.

**Step 6 — update the design contract**, as the user explicitly asked:
- `design_database_and_security.md` §2 — the `rerollPrompt` row currently says *"once per game (`hasRerolled`), truth phase only"*. It becomes **unlimited, truth phase only**, and this time the guard exists.
- `design_rotation_engine.md` — assignment generation now happens at the truth→forgery transition.
- `design_game_state_and_models.md` — the phase order.

### Validation

- **`functions/test/game_e2e.spec.ts`:** assert `startGame` leaves the room in `truth`, and that the transition sequence is truth → forgery → vote → reveal. **Falsifying:** today `startGame` yields `forgery`.
- **Re-roll phase guard:** calling `rerollPrompt` during forgery is **rejected** with `failed-precondition`. **Falsifying:** today it succeeds, which is the whole defect.
- **Unlimited re-roll:** call `rerollPrompt` three times in the truth phase and assert all three succeed and the prompt changes each time. **Falsifying:** today the second call throws `Prompt already re-rolled once this game.`
- **Deck exhaustion:** on a 12-prompt deck, re-roll past the end and assert the callable fails cleanly and the client shows the fixed copy — not a stack trace.
- **Over-reach guard — the lies must still be written against the final prompt.** Play a full game: re-roll during truth, then assert every forgery on that card was authored **after** the final prompt was set, and that the reveal displays that same prompt. This is the assertion that proves the reported bug is gone, rather than merely moved.
- **Disconnect handling still works.** `handleDisconnect` has forgery-specific assignment bridging (`index.ts:754+`) that assumed the old order. Disconnect a player during **truth** and during **forgery** and assert the game continues correctly in both.

### Blast radius

`functions/src/index.ts` (`startGame`, `advancePhaseInternal`, `rerollPrompt`, `handleDisconnect`) · `functions/src/rotation_engine.ts` · `lib/models/game_state.dart`, `player_state.dart` · `lib/screens/phase2_craft.dart` · `test/fake_functions.dart` · `functions/test/game_e2e.spec.ts` · the Dart simulation suite · **three design docs** per step 6.

---

## 9. Deploy, then re-run the playthrough

§7 and §8 change Cloud Functions and `firestore.rules`. **Neither reaches a player until deployed**, and no gate in the battery can see a deployment — that is how the wave before this one sat "Resolved" for a day while production ran older code.

Deploy and verify per **`design_database_and_security.md` §8**: all 14 function timestamps move, the deployed bundle contains a token unique to your change, and the deployed ruleset is read back and checked. **Do not skip the artefact check** — a successful-looking deploy is not evidence.

Then re-run the three-simulator playthrough (`ongoing_general_errors.md` records the command sequence, and §1's trap list applies). The last one found five defects in a single sitting; assume this one will too, and treat anything it surfaces as **a new issue filed with options**, not an inline fix.

Assertions the previous playthrough never reached, which still need confirming:

1. Host leaves a lobby → both non-hosts land on the entry screen showing exactly **"The host has left. This room has closed."**
2. A non-host leaves → the room survives and the host sees them go.
3. A non-host swipes the deck carousel through all 7 cards → the host's selection does not change.
4. A newly created production room carries `expiresAt` ~8 h ahead on **both** the room and host player document.
5. The leave icon reads as a door with an arrow.
6. A full game completes end to end with three human clients — now with the truth written first.

---

## 10. Re-measure the release build

`flutter build ios --release --no-codesign`; record `Runner.app`. The **49.5 MB** figure is inherited from `56c183a` and predates everything since. **Measure; do not estimate** — the last size guess here was out by more than a factor of two.

---

## 11. Already delivered — do NOT rework

- **Issue 50** — leave control, `showGeneralDialog`, reduce-motion path, double-tap guard, tooltip finders. **Its `_isLeaving` guard is the model for §5's in-flight cases.**
- **Issue 51** — lobby-host close branch precedes the `!hasCard` branch (`index.ts:741/744/753`) and is live. **Reversing that order silently reinstates the original bug.**
- **Issue 52** — one `PageView` for both roles; suppression for non-hosts; `CHOSEN` badge; 3-second snap-back.
- **Issue 53** — `ROOM_TTL_MS` 8 h, `expiresAt` at ten sites, rules denylist. Live.
- **Issue 54** — both TTL policies `ACTIVE`. **Do not re-run the enable commands.**
- **Issue 55** — functions and rules deployed; `predeploy` hook in `firebase.json`.
- **Issue 56** — legacy backfill complete; `--dry-run` reports 0 missing.
- **Issue 57** — `depart` is a bespoke sigil; identity confirmed by rasterising the geometry; all 11 font-backed glyphs audited and correct.
- **Issues 1–49, Tasks T1–T11** — the mascot programme is finished; `POSE_REGISTRY` is the single source of truth for frame geometry.
- **Issue 31** — the server uses loose `!= null`; **never "simplify" to a falsy check**.
- **Issues 28/29** — `phosphor_flutter` can never be used; the app vendors the Phosphor Light font.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` · Firebase project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 12. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Every item in §3–§8 names its falsifying assertion. Record the failing output.

**A check that cannot fail is not a check.** Five instances so far: the cmap presence script, `find.byType(IconButton).last`, a bare `find.byType(FadeTransition)`, a "file is non-empty" contrast test, and `find.byType(CustomPaint)` as proof that something was drawn.

**Name what a check covers, or it will be read as covering more.** A dispatch assertion proves which branch runs; an ink count proves something was drawn; only looking proves it is the right picture.

**A green suite is not evidence about anything it cannot observe** — contrast, overflow, double submission, phase ordering, or what a client can read. All five defects in this queue were live at 121/121 and 36/36.

**"Resolved" is not "live."** Nothing in §7 or §8 reaches a player until §9.

**Measure; do not estimate**, and **do not tune a threshold to make a test pass** — report the number and say the guard failed.

**Pair every fix assertion with an over-reach guard.**

---

## 13. Accepted equivalents — do NOT "fix" back

- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null. **Do not add a redundant `pushReplacement`.**
- **The non-host carousel is interactive-but-inert, not dimmed.**
- **`pumpAndSettle()` and `pump()` + `pump(500ms)` are both acceptable** once `accessibleNavigation: true` is set.
- **The leave dialog uses `showGeneralDialog`, not `showDialog`.**
- **`_ThematicIconPainter` carries fallback cases for font-backed types.** Unreachable while `_phosphorGlyphs` has an entry. Do not delete or wire them up.
- **The `depart` sigil's committed proportions** differ slightly from spec and are accepted.
- **`isSmallHeight` uses a `< 700` dp breakpoint** with a 6/8/12/16/20 spacing scale.

---

## 14. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; `firestore.rules` denies client room writes. **Room reads stay open** — §7 fixes what is written, not who may read.
- **Portrait-locked on phones**; **text scale clamped 1.0–1.3**.
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically across `text_similarity.ts` ↔ `text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`_familyFriendlyOnly` is client-local and never synced.**
- **`playRavenPose`'s `onceKey` stays required.**
- **`ROOM_TTL_MS` is 8 hours.** If ever shortened below ~4 hours, a host-only `touchRoom` keepalive plus a client timer become mandatory (`ongoing_general_errors.md` Issue 53).
- **`firebase.json`'s `predeploy` hook stays.**
- **`depart` is a bespoke sigil, not a font glyph.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C, Issue 57 Options B/C, and the rejected options on Issues 58–62.

---

## 15. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Full history of any resolved item | `git log` |
| Backend writes, rules, identity, TTL §6, **deploy & verification §8** | `design_database_and_security.md` — §7 is the `null` ≠ absent contract |
| Card passing, disconnect recalculation, **assignment timing** | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, **`onSurface` semantics**, icons, mascot | `design_ui_direction.md` |
| Phase order and data models | `design_game_state_and_models.md` |
| Deck catalogue and non-host carousel contract | `design_prompt_system.md` §67–70 |
| PNG decoding + WCAG contrast helper (reuse, do not rewrite) | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 16. Feedback loop — what past specs got wrong

- **One playthrough found five defects that 157 automated tests could not.** Contrast, layout overflow, double submission, phase ordering and data exposure are all structurally outside what this battery observes. **Schedule the manual pass as a gate, not as a nicety** — it is the highest-yield check available and it had never once been run.
- **A guard nobody has seen fail is not known to be a guard.** `find.byType(CustomPaint)` was accepted as proof the sigil drew something; it passes against an empty painter.
- **A doc can document a guard that was never written.** `design_database_and_security.md` claimed `rerollPrompt` was "truth phase only" for weeks; no such check existed. **When a contract states a guard, grep for it.**
- **Fixing an ordering can widen a security window.** Issue 61 is right and Issue 62 must land first anyway. **Ask what a reordering exposes for longer, not just what it fixes.**
- **"Invisible to the harness" is a hypothesis.** The glyph gate was declared device-only, skipped twice, and shipped wrong — while its outlines were decodable in ~60 lines of Python.
- **"Resolved" is not "deployed."** Issues 51 and 53 were green and Resolved while production ran a two-day-old build.
- **A convenience the tooling normally provides may be absent.** `firebase.json` had no `predeploy` hook, so a deploy could ship stale code and report success.
- **An accommodation implemented against the wrong axis is a regression.** `barrierDismissible: !reduceMotion` removed a capability from the users it named.
- **A guide's title is not its contents.** This guide was once retitled "Queue Complete" while its body still specified finished work.
- **Doc structure rots silently.** The Resolved section has been split into duplicate headings by three separate edits. **Append inside the existing heading; never add a second one.**

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Copy strings verbatim; paste, do not retype.
(3) VALIDATE per §12. Observe the falsifying assertion fail first, and record it.
    Run the over-reach guard. For anything the harness cannot see, decode the
    artefact or look at a device — do not assume you cannot.
    Then the full §1 battery.
(4) BEFORE COMMITTING, re-read this guide's open list for the item you are finishing.
    Green tests are not evidence that a filed gap was closed.
(5) BLOCKED, or found something needing human judgement? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
(6) RECORD: move the item to Resolved (Problem / Solution / Observed Falsifying
    Output / Over-reach Guard) inside the SINGLE existing Resolved heading.
    Sync every design doc whose behaviour changed — §8 changes three.
(7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **§3** — inner `Row` and title both flexible; `tester.takeException()` null at 360 dp × 1.3 scale on the `REVENGE UNMASKING!` branch, **observed throwing first**; both branches and a wide width also clean.
- [ ] **§4** — all 11 `onSurface` usages classified and the dark ones switched to `ivory`; contrast guard added reusing `png_decoder.dart`, **observed failing at 1.17 and 1.10 first**; ink-on-parchment still passes; reveal readable at 360×640 dp.
- [ ] **§5** — unmask tray disabled from **stream state**; every action in the step-2 table audited; double-tap tests assert exactly one invocation each; **no `e.toString()` anywhere in user-facing copy**; error copy verbatim.
- [ ] **§6** — `depart` ink-count guard, **observed returning 0** with the painter reverted.
- [ ] **§7** — sealed subcollection with **no rule** (default-deny); room document carries no `truthAnswer` and no authorship during vote; votes reference opaque answer ids; truth and authorship appear at the reveal transition; rules test proves `sealed` is denied while the room stays readable; `fake_functions.dart` updated in the same commit; full game still scores correctly.
- [ ] **§8** — `startGame` opens in `truth`; transitions truth → forgery → vote → reveal; re-roll **unlimited** but **truth-phase-only on client and server**; `hasRerolled` removed while its denylist entry stays; deck exhaustion shows fixed copy, not an exception; lies provably written against the final prompt; disconnect verified in both truth and forgery; **three design docs updated**.
- [ ] **§9** — deployed, and verified by artefact inspection per `design_database_and_security.md` §8; playthrough re-run with all six assertions recorded per device; anything it surfaces filed as a **new issue with options**.
- [ ] **§10** — `Runner.app` re-measured and §1's inherited 49.5 MB replaced.
- [ ] Full battery at or above the §1 bar: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 121 + new** · functions build clean · `npm --prefix functions test` **≥ 36 + new**.
- [ ] Issues 58–62 moved to Resolved **inside the single existing Resolved heading**, each with its observed falsifying output.
- [ ] **Guide rewritten** — body and title together — to `Queue Complete` or the next queue. If the queue is empty: **do not invent work.**
