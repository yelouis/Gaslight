# Agent Execution Guide — Active Build: Wave R — stop the background, fix two clipped surfaces, then recover the three missing verifications — August 28, 2026

**You are an engineering agent with no memory of this project.**

**All four selections are made.** Build exactly these, in this order.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **R0** | Reduce Motion actually stops the in-game background | **138 → B** | client | — |
| **R1** | The in-game AppBar sizes itself to its text — no magic numbers | **136 → A**, modified | client | — |
| **R2** | The dealt-card overlay grows so a long prompt is readable | **137 → A** | client | — |
| **R3** | Re-run the three re-aimed soak blocks as **E44–E46** | **135 → A** | test only | — |

**No deploy is needed for any of this wave.** Nothing here touches `functions/src`. `./scripts/check_deploy_fresh.sh` should stay at exit 0 throughout; if it goes red, you have changed something you should not have.

**One item = one commit** — four commits.

**Every number, formula and literal string below is a decision, not a suggestion.**

---

## 0. Ordering, and why it is not negotiable

**R0 → R1 → R2 → R3.**

**R0 goes first because it removes the trap that stalled this wave once already.** `AnimatedThinkingBackground` roots craft, vote and reveal and never stops animating, which is both the accessibility defect Issue 138 records *and* the reason `pumpAndSettle` hangs on those screens (§1.1). R1 and R2 are the two items whose tests mount exactly those screens. Landing R0 first means the rest of the wave is written against a tree that can actually reach a resting state.

**It also gets device-verified for free.** R3 photographs all three of those screens, so R0's visual change — the particle layer absent under Reduce Motion — is observable in the same soak that certifies R1 and R2. Turn Reduce Motion on for one of the five devices and the soak covers both states at once.

**One thing R0 does not change: `pump(Duration)` stays the standing convention** (§1.1). R0 makes `pumpAndSettle` *safe* on those three screens rather than *required*, and the existing tests that already use `pump(Duration)` are correct before and after. Do not churn passing tests to switch style.

R3 is a device run that photographs the craft screen, the vote screen and the reveal screen. R1 and R2 change how two of those screens lay out. **Running R3 first would produce a report full of screenshots showing the old, clipped UI**, and every one of them would have to be retaken. Land the fixes, then certify them.

There is a second reason, and it is the better one: R3's whole purpose is to recover verifications that were skipped. If R1 and R2 land first, R3's screenshots become the device evidence for *those* fixes as well — the craft header and the dealt card appear in almost every block. **One device run, three items verified.**

---

## 1. Standing constraints

- **One item = one commit**, Conventional Commit, **WHY in the body — never a bare title.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.** Nothing in this wave needs it.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Read a gate's exit code bare, never through a pipe.**
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated.
- **R3 finds defects; it does not fix them.** File and stop.
- **A block performed differently is `NOT RUN` with a `Reason:`, never `PASS` under a new title** (lesson 2.33). This is the rule the last soak broke.
- **⚠️ Never call `tester.pumpAndSettle()` on the craft, vote or reveal screen — it will hang the run.** See §1.1. This wave's widget tests all target those three screens, so this is not a footnote.
- **Do not touch anything in §6 or §7.**

### 1.1 ⚠️ The `pumpAndSettle` hang — read this before writing a single widget test

**Every widget test in this wave mounts an animated screen, and the obvious way to pump it deadlocks the runner.**

`Phase2CraftScreen`, `Phase3VoteScreen` and `Phase4RevealScreen` each return an `AnimatedThinkingBackground` as their root — `lib/screens/phase2_craft.dart:216`, `lib/screens/phase3_vote.dart:137`, `lib/screens/phase4_reveal.dart:313`. That widget starts an **unguarded infinite animation** in `initState`:

```dart
// lib/widgets/thinking_background.dart:21
_controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
```

`pumpAndSettle` returns only when the tree has no pending frames. This tree **always** has one. So it spins until its **10-minute default timeout — per test**. A 13-test file therefore appears to hang for over two hours, and because the reporter prints a test's name when it *starts*, the run emits the test name and then **nothing at all**. It reads exactly like an infinite loop in the code under test. It is not.

**Do this instead** — the convention the passing tests already use:

```dart
await tester.pump();                                    // build
await tester.pump(const Duration(milliseconds: 1000));  // advance past entry animations
```

See `test/phase2_craft_test.dart:96` and `test/debug_buttons_gating_test.dart:106-107`, both of which mount these screens and pass in milliseconds.

**Two traps inside the trap:**

1. **`accessibleNavigation: true` does not save you here.** The project's motion-reduction convention is `AppMotion.reduce(context)`, which does read `MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`) — and `lobby_background.dart`, `raven_mascot.dart`, `waiting_indicator.dart` and the rest all honour it. **`AnimatedThinkingBackground` never consults it at all** — it is the one animated widget whose motion a Reduce Motion user cannot switch off. Setting the flag is still correct and still required for the other animations; it simply does not stop this one. **This is what R0 fixes, and R0 lands first** — see §R0. After R0, `pumpAndSettle` becomes safe on craft, vote and reveal; it does not become *required*, and `pump(Duration)` remains the convention everywhere. (Issue 138 also notes that `game_over_screen.dart:900` keeps an unconditional ticker running even though its `build` correctly swaps to a static painter — so `pumpAndSettle` would hang there too, latently, since no test currently calls it on that screen. **That is deliberately out of R0's scope; see §R0.6.**)
2. **Never `await` a fake callable directly inside `testWidgets`** — that is a separate FakeAsync deadlock (lesson 2.7). Wrap it in `tester.runAsync`.

**Triage, if a run ever hangs again:** `flutter test --reporter expanded`; the last test name printed **without a result** is the one stuck. To distinguish "not settling" from "genuinely slow", pass an explicit short timeout — `await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5))` — and a non-settling tree fails in 5 s with `pumpAndSettle timed out` instead of blocking for 10 minutes.

---

## R0 — Reduce Motion actually stops the in-game background (138 → B)

**What this means for the user:** a player who turns on **Reduce Motion** in iOS Settings still gets fifteen glyph particles drifting up the screen throughout craft, vote and reveal — the three screens where they spend nearly the whole match. Every other animation in the app already goes still for them. After this, these do too.

### R0.1 The gap

`lib/widgets/thinking_background.dart:21` starts the ticker unconditionally in `initState`:

```dart
_controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
```

`grep -c AppMotion lib/widgets/thinking_background.dart` returns **0** — the file has no motion guard of any kind. It is the root of all three in-game screens (`phase2_craft.dart:216`, `phase3_vote.dart:137`, `phase4_reveal.dart:313`).

**The selected option is B: skip the particle layer entirely under Reduce Motion** — the background becomes the radial gradient plus the screen content, with no `CustomPaint` and no ticker.

### R0.2 Implementation

**Step 1 — take the start decision out of `initState`.**

- **Remove `..repeat()` from `:21`**, leaving a plain `AnimationController` construction. `MediaQuery` is not available in `initState`, so the decision cannot be made there; starting it and stopping it a moment later would work but leaves a frame of motion for the exact user who asked for none.
- **Keep the particle seeding loop at `:24–26` exactly as it is.** Under Reduce Motion those fifteen objects are unused — but if the user toggles the setting *off* mid-match, the animated branch must find a populated field. Making the seeding conditional creates an empty-background bug that only appears on toggle, which is the hardest kind to see. Fifteen allocations once per screen is not worth optimising.

**Step 2 — let `didChangeDependencies` own the ticker.**

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (AppMotion.reduce(context)) {
    _controller.stop();
  } else if (!_controller.isAnimating) {
    _controller.repeat();
  }
}
```

- This mirrors `lib/widgets/lobby_background.dart:30–38`, which is the house pattern.
- **One deliberate difference from that pattern: do NOT add a `_controller.value = …` line.** `lobby_background` sets it because its build *reads* `_breathingController.value` (`:55`). Here the value is **never read** — positions are mutated inside the `AnimatedBuilder` builder (`:72–78`) and the controller is a bare repaint ticker. Setting `value` would be cargo-culting a line whose purpose does not exist in this widget.
- `didChangeDependencies` fires on first mount **and** on every `MediaQuery` change, so toggling Reduce Motion in iOS Settings takes effect mid-match without relaunching. An `initState`-only read would not.
- **Add `import '../theme/app_motion.dart';`** — the file currently has no reference to it.

**Step 3 — skip the particle layer in `build`.**

- When `AppMotion.reduce(context)` is true, return the `Stack` with **only** the gradient `Container` and `widget.child`; omit the `AnimatedBuilder` (`:68–86`) entirely.
- **Hoist the gradient `Container` (`:54–67`) into one source** — a private `Widget get _gradient` or a `static const` — and use it in both branches. **Do not copy-paste it.** Two copies of a nine-line `RadialGradient` will drift the first time someone touches the palette, and the drift will only be visible to Reduce Motion users, who are the least likely to report it.
- **Keep the `Stack` in both branches.** Do not collapse the reduced branch to `Container(child: widget.child)`. `Stack` sizes and positions `widget.child` in a specific way, and changing the parent widget type would change the layout of every in-game screen for exactly the users who cannot easily be asked to check.

### R0.3 ⚠️ The trap: Step 3 without Step 2 looks completely correct

**Skipping the paint while leaving the ticker running produces a screen that is visually perfect and a test suite that hangs forever.** Reduce Motion appears honoured — no particles move, because nothing paints them — but `_controller` is still repeating, the tree still never reaches a resting state, and `pumpAndSettle` still spins to its ten-minute default with no output.

This is not hypothetical: it is exactly the state `game_over_screen.dart` is in today (§R0.6).

**Steps 2 and 3 are one change. Landing either alone is a defect.** The validation below is written as a *settle* test rather than a "no particles painted" test precisely so that Step 3 alone cannot pass it.

### R0.4 Validation

**New file: `test/thinking_background_reduce_motion_test.dart`.** No test covers this widget today — `ls test/ | grep -i thinking` is empty.

**⚠️ Every `pumpAndSettle` in this file must pass an explicit short timeout:**

```dart
await tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);
```

The default is **ten minutes**. With the default, a red test is indistinguishable from a hung runner — which is the whole failure this item exists to end. Five seconds is generous for a tree that settles in one frame.

1. **The falsifying test — the widget settles under Reduce Motion.** Mount `AnimatedThinkingBackground` with `accessibleNavigation: true` and assert the `pumpAndSettle` above **completes**. **Run it against current code and observe it fail with `pumpAndSettle timed out`.** Paste that line into the commit body.
2. **The three real screens settle.** The same assertion mounting `Phase2CraftScreen`, `Phase3VoteScreen` and `Phase4RevealScreen` with `accessibleNavigation: true`. This is the assertion that retires §1.1 for those screens, and it is the one that will catch a future widget re-introducing an unguarded ticker anywhere in their subtree.
3. **Over-reach guard — the motion still exists when it was not asked to stop.** With `accessibleNavigation: false`, assert the particle layer **is** in the tree:
   ```dart
   expect(
     find.descendant(
       of: find.byType(AnimatedThinkingBackground),
       matching: find.byType(AnimatedBuilder),
     ),
     findsOneWidget,
   );
   ```
   and that it is **absent** under `accessibleNavigation: true`. Scope the finder with `find.descendant` as shown — `MaterialApp` contains `AnimatedBuilder`s of its own and an unscoped finder will match them. **Without this guard, deleting the animation outright passes every other test in this file.**
4. **The live toggle works.** Pump with `accessibleNavigation: false`, then pump the same tree with `true`, and assert it now settles *and* the `AnimatedBuilder` is gone; then back to `false` and assert it returns. **This is the assertion that distinguishes `didChangeDependencies` from an `initState`-only read**, and it is the reason Step 2 specifies that method rather than the constructor.
5. **The content always renders.** In both modes, assert the `child` passed to the widget is found. A reduced branch that drops the screen content would otherwise pass tests 1–4.
6. **Falsify both halves separately, and record both runs:**
   - Revert **Step 2** only (ticker repeating, paint skipped) → tests **1 and 2 must fail** with `pumpAndSettle timed out`. This is the §R0.3 trap; confirming it is what proves the test suite can see it.
   - Revert **Step 3** only (ticker stopped, paint kept) → test **3 must fail** on the reduce-motion branch.

**Regression watch — one existing file changes shape.** `test/phase3_vote_test.dart` is the only test that parameterizes this flag: it drives `Phase3VoteScreen` at `reduceMotion: true` (`:109`, `:174`) and `false` (`:132`, `:149`). The two `true` cases will now build a tree with no particle layer. It uses `pump()`, so it cannot hang either way — but **re-run that file specifically and confirm all four cases still pass** before running the full battery.

### R0.5 Blast radius

`lib/widgets/thinking_background.dart` · the new widget test · **`docs/design_ui_direction.md`** — record that the in-game background honours Reduce Motion by **omitting the particle layer entirely** (Option B), that the radial gradient is retained so the screens keep their ground colour, and that this differs from the game-over screen, which keeps a static ember field instead.

### R0.6 Explicitly NOT in scope — do not widen this

`game_over_screen.dart:900` (`EmberBackdrop`) has the **same** unconditional `..repeat()` in `initState`. **Its accessibility behaviour is already correct** — `build` checks `AppMotion.reduce` and returns a `_StaticEmberPainter` instead of the `AnimatedBuilder` (`:924–938`). But its ticker never stops, so it is a live example of the §R0.3 trap and `pumpAndSettle` on the game-over screen would hang. It is latent only because `game_over_screen_test.dart` and `badge_pills_overflow_test.dart` both use `pump()`.

**Issue 138's selection covers `AnimatedThinkingBackground` only. Do not fix `EmberBackdrop` inside R0.** If you think it should be fixed, **file it with options, Pros/Cons and a blank selection line, and carry on** — that is the standing rule in §1, and it applies here even though the fix is three lines. Note also that test 2 above deliberately does **not** cover the game-over screen; adding it there would fail against the current code and turn R0 red for a reason R0 is not allowed to fix.

---

## 2. R1 — The in-game AppBar sizes itself to its text (136 → A, modified)

**What this means for the user:** during the forgery phase the header currently reads `FORGERY` / `ROOM: XXXX` / `Rotation 1 of 2`, and the third line is sliced through the middle of its letters. The player cannot see how many forgery rounds remain.

### 2.1 The gap

`lib/screens/phase2_craft.dart:228` gives `AppBar.title` a `Column` with **three** children during the forgery phase:

- `TitleSettle` — `AppTextStyles.phaseTitle.copyWith(fontSize: 26)`, CormorantGaramond
- `SizedBox(height: 2)` then `ROOM: <code>` — `sectionLabel.copyWith(fontSize: 11)`, Lora
- `Padding(top: 2)` then `Rotation N of M` — `sectionLabel`, Lora 12 pt

**No `toolbarHeight` is set**, so the toolbar keeps Material's **56 pt** default. Three lines do not fit. The truth phase has two lines and does fit, which is exactly why `e29_p4_room_code_truth.png` renders cleanly and `e31_p3_relinked.png` clips.

### 2.2 The user's constraint: no hardcoded 78–84

The issue text proposed a literal, and the user rejected it — correctly. **But be careful which kind of "relative" you reach for.**

**A percentage of screen height is the wrong answer.** `MediaQuery.sizeOf(context).height * 0.1` is relative to the wrong thing: it does not track font size, and it does not track the accessibility text scale. On a tall phone with `textScaleFactor: 2.0` it still clips; on a short phone it wastes space. The variable that actually determines whether the text fits is **the height of the text**, not the height of the screen.

**Measure the text.** This project already does exactly this in `AutoSizedAnswerText` (`lib/widgets/card_grid.dart`, Issue 119), which lays out a `TextPainter` against real constraints and the live `MediaQuery.textScalerOf`. Use the same technique here. That gives a header that adapts to **device width** (which changes wrapping), **text scale** (which changes line height), and **any future edit to the styles** — none of which a literal or a screen-height fraction would survive.

### 2.3 Implementation

1. **Write one shared helper**, e.g. `double inGameAppBarHeight(BuildContext context, {required List<TextSpanSpec> lines})` in a small file both screens import — or a method on a shared widget. It must:
   - Read `MediaQuery.textScalerOf(context)` and the available width (screen width minus the leading `IconButton` and its mirror, so the title's real box — do **not** measure against full screen width).
   - For each line, lay out a `TextPainter` with that line's **actual `TextStyle`** — the same objects the widgets use, not copies of their numbers — and `maxLines: 1`.
   - Sum the resulting `textPainter.height` values, add the **existing** inter-line spacing (`2` + `2`), and add a small symmetric breathing allowance (**8 pt total**, 4 above and 4 below).
   - Return `max(kToolbarHeight, computed)` so the header never becomes *shorter* than the Material default.
2. **Wrap the AppBar in `PreferredSize`** (or set `AppBar.toolbarHeight` to the helper's result). `AppBar` requires its height before layout, which is why an `IntrinsicHeight` or `LayoutBuilder` alone cannot solve this — the measurement has to happen in the build method and be handed in.
3. **Apply it to all three in-game screens**, not just craft: `phase2_craft.dart`, `phase3_vote.dart:` and `phase4_reveal.dart:` all build the same title `Column`. Vote and reveal have only two lines today and fit at scale 1.0 — **but at `textScaleFactor: 1.3` two lines already approach 56 pt, and at 2.0 they exceed it.** Fixing only craft leaves the same bug waiting behind an accessibility setting.
4. **⚠️ `TitleSettle` animates `letterSpacing` from the style's value + 6 down to the value** (`lib/widgets/gaslight_route.dart:74`). That changes the title's **width**, not its height — but a wider title can **wrap**, and a wrapped title is taller. Measure the title line at the **maximum** letter spacing (base + 6), or give the title `maxLines: 1` with `TextOverflow.ellipsis` so it can never wrap. **State which you chose in the commit body.**

### 2.4 Validation

**⚠️ Every test below mounts craft, vote or reveal.** **R0 lands before this item and makes those screens settleable**, so `pumpAndSettle` is no longer a hazard here — but **`pump(Duration)` remains the convention** (§1.1), the existing test file already uses it, and there is nothing to gain by changing it. If you are working on R1 before R0 is committed, `pump(Duration)` is mandatory: a run that stops emitting output has hit the §1.1 trap and is not a logic bug in your fix.

**⚠️ A partial test file for this item already exists on disk, untracked: `test/in_game_app_bar_test.dart` (13 tests).** It was written before the trap was understood, and **it is the reason the suite currently hangs.** It is otherwise sound — correct fixtures, the nine-way matrix, the over-reach guards, and `accessibleNavigation: true` already set. **Start from it rather than rewriting it.** Changing its single `await tester.pumpAndSettle();` (line 100) to `await tester.pump(const Duration(milliseconds: 1000));` is sufficient to make it run.

**Its post-fix baseline is already known — this is your falsification, so do not re-derive it:** with that one line changed and R1 **not** implemented, the file produces **13 failures in seconds**, of the exact shape the item predicts:

```
Expected: a value less than or equal to <56.0>
  Actual: <60.5>
Reveal screen at scale 2.0: roomCodeBottom (60.5) <= appBarBottom (56.0)
```

`56.0` is Material's untouched `kToolbarHeight` — the gap in §2.1, observed rather than argued. **Paste this into the commit body as the falsifying evidence.**

**All 13 fail, including the truth-phase over-reach guard** — that one asserts `truthHeight < forgeryHeight`, and today both are the same untouched 56.0, so it cannot pass until the helper exists. **13/13 red is the correct pre-fix baseline; 13/13 green is the bar.**

**Note also that this failure fires on the *reveal* screen at scale 2.0** — confirming §2.3 step 3: the bug is not craft-only, and a craft-only fix leaves it live behind an accessibility setting.

- **The falsifying test.** Widget test on the craft screen in the **forgery** phase: find the `Rotation N of M` `Text`, take its `RenderBox`, and assert its bottom edge is **inside** the AppBar's paint bounds. **Run it against the current code and watch it fail** — paste the failing geometry into the commit body.
- **The matrix.** Assert the same at widths **320, 375 and 430 pt** and at `textScaleFactor` **1.0, 1.3 and 2.0** — nine combinations. The whole point of the derived height is that it survives all of them; a fix validated at one size is the bug that produced this issue.
- **Over-reach guard, the truth phase:** the header still renders correctly with two lines and does **not** grow taller than it needs — assert the computed height at scale 1.0 in the truth phase is **less than** the forgery-phase height. If they are equal, the helper is returning a constant and you have reintroduced a magic number in a new costume.
- **Over-reach guard, the other screens:** vote and reveal still render their two-line headers, at 1.0 and at 2.0.
- **Do not assert an exact pixel value anywhere.** Assert containment and ordering. A test that hardcodes "the header is 81 pt" is the same defect the user rejected, moved into the test suite.

**Blast radius:** `lib/screens/phase2_craft.dart` · `lib/screens/phase3_vote.dart` · `lib/screens/phase4_reveal.dart` · the new helper · widget tests. **`docs/design_ui_direction.md`** describes the in-game headers — record that their height is derived from measured text, and why a screen-height fraction was rejected.

---

## 3. R2 — The dealt-card overlay grows so a long prompt is readable (137 → A)

**What this means for the user:** when the card is dealt, a long prompt is cut off partway through, so the player is asked to answer a question they cannot finish reading.

### 3.1 The gap

`lib/widgets/dealt_card_overlay.dart`:

- outer `Container(width: 300, height: 420)` (`:70–71`)
- inside it, `Padding(horizontal: 20, vertical: 24)` (`:96`) → **`FittedBox(fit: BoxFit.scaleDown)`** (`:98`) → `SizedBox(width: 260, height: 372)` (`:100–102`)
- the prompt sits in `Expanded` → `SingleChildScrollView` → `Column` (`:129–160`)

Because the prompt scrolls, there is **no overflow error and no test failure** — the text is simply cut at the fold with **no scrollbar, no fade and no partial-line cue**. Same discoverability failure as Issue 132, different widget.

**Concrete worst case, derived from the catalogue rather than guessed:** the longest prompt in the deck data is **89 characters** — `"The first thing I would buy with lottery money that would make people question my sanity."` (`hypotheticals`). At 22 pt CormorantGaramond in a 260 pt box that is roughly five lines, which alone exceeds what remains of the 372 pt after the crown icon, the title, the divider and the italic intro.

### 3.2 ⚠️ The trap: `FittedBox(scaleDown)` will silently defeat a partial fix

The available space inside the padding is exactly `300 − 40 = 260` wide by `420 − 48 = 372` tall — precisely the `SizedBox`. So the `FittedBox` currently scales by 1.0 and does nothing.

**If you enlarge the inner `SizedBox` without also enlarging the outer `Container`, `FittedBox` will shrink the whole card's contents to fit the unchanged 372 pt** — the text gets *smaller*, the clipping "goes away", and the screenshot looks plausible while the prompt is now harder to read than before. **Change both, or remove the `FittedBox` and let the growth handle it.**

### 3.3 Implementation

1. **Let the card grow, bounded by the viewport.** Replace the outer fixed `height: 420` with a maximum:
   ```
   maxHeight = min(MediaQuery.sizeOf(context).height * 0.7, 560)
   ```
   `screenHeight` is already computed at `:66` for the entry animation — reuse it rather than reading `MediaQuery` twice. Keep `width: 300`.
2. **Let the content size itself** — the inner `SizedBox(width: 260, height: 372)` becomes width-constrained only, so the `Column` takes its intrinsic height. Short prompts then produce a card close to today's proportions; long ones produce a taller card, up to the cap.
3. **Keep the `SingleChildScrollView` as the floor**, so a pathological prompt is still reachable rather than permanently unreadable. It should now almost never engage.
4. **Decide the `FittedBox` deliberately.** Either drop it (growth makes it redundant) or keep it strictly as a last resort below the cap. **Say which, and why, in the commit body** — §3.2 is the reason this cannot be left to chance.
5. **The entry animation translates by `screenHeight + 200` (`:223`).** A taller card still starts fully off-screen, so no change is needed — but re-watch the animation on the shortest device, because a 0.7-height card on a small phone is a much larger object than today's 420.

### 3.4 Validation

**⚠️ Mount `DealtCardOverlay` standalone in a `Scaffold`, as `test/dealt_card_overlay_test.dart:12-29` does.** Mounted that way it settles, and `pumpAndSettle()` is safe — those tests pass today. **But if you mount it inside `Phase2CraftScreen` to exercise the real dealt-card flow, you inherit the §1.1 hang** and the run will stop dead with no output. In that case switch to `pump(Duration)`.

- **The falsifying test.** Render the overlay with the **longest prompt in the catalogue, obtained from `PromptDecks` at test time** — iterate `allDecks` and take the maximum-length prompt; **do not paste the string into the test**, because decks are edited and a hardcoded worst case silently stops being the worst case. Assert the prompt's `RenderParagraph.didExceedMaxLines == false` **and** that its `RenderBox` sits fully inside the card's bounds. **Run it against the current code and watch it fail.**
- **Load the real Lora and CormorantGaramond fonts via `FontLoader`**, as `test/vote_option_truncation_test.dart:23` does. `flutter test` otherwise substitutes a square-glyph fallback whose metrics are wrong in both directions, and a card tuned against it will be wrong on a device.
- **The cap holds.** At a short viewport (e.g. 320 × 568), assert the card's height does **not** exceed `screenHeight * 0.7` and the card is fully on screen.
- **Over-reach guard, short prompts.** A 30-character prompt must **not** produce a card that has grown to the cap — assert its height is materially less than the long-prompt case. Otherwise you have replaced a fixed 420 with a fixed 560.
- **Over-reach guard, the truth/forgery variants.** Both the `You must pen the absolute truth…` intro and the `You have been dealt the ledger of X` variant render fully; the second is two lines and longer.
- **Falsify the `FittedBox` trap explicitly:** enlarge the inner box only, and confirm the test *still fails* (because the contents shrink instead of the card growing). Record that you checked this.

**Blast radius:** `lib/widgets/dealt_card_overlay.dart` · a new or extended widget test · **`docs/design_ui_direction.md`** if it specifies the card's dimensions.

---

## 4. R3 — Recover the three missing verifications as E44–E46 (135 → A)

**What this means for the user:** three fixes shipped in Waves O, P and Q have **never been verified on a device**, because the blocks meant to check them were re-aimed at easier assertions and marked PASS.

### 4.1 What is missing, and what is not

**Do not re-run the soak.** 19 of its 22 blocks were performed as specified and their 27 artefacts are on disk and valid. Read `docs/playthrough_findings_5player.md` before starting — it carries the harness configuration, the block format, and the ⚠️ notices on the three re-aimed entries.

| New block | Recovers | Which shipped fix it certifies |
|---|---|---|
| **E44** | own answer locked out **in round 2**, and it is the *right* option | **Issue 117** — cross-round `answerAuthors` isolation |
| **E45** | unmask window **withholds then publishes** deltas, **including with the host absent** | **Issues 124 and 133** — Wave Q's entire subject |
| **E46** | presence: still seated at **~2 min**, gone at **~11** | **Issue 123** — the ten-minute window |

**E44 and E45 share one match. E46 needs its own.** That is two rooms, not three.

### 4.2 Prerequisites

Same as the original soak, and **all of them still apply**:

1. Five Marionette servers responding (`.agents/mcp_config.json` declares `marionette-p1`…`p5`). If only three are exposed, **stop and tell the user.**
2. Five booted simulators, five distinct models, UDIDs and DDS ports recorded.
3. **`.env` contains `USE_EMULATOR=false`** — a bundled asset; changing it after the build has no effect.
4. **Uninstall on all five before installing.** `SharedPreferences` survives an install-over-the-top, so a device that played a previous room silently rejoins it.
5. Build once, install five times; prove the binary is newer than the source and paste both lines.
6. **`./scripts/check_deploy_fresh.sh` must exit 0.** No server change is in this wave, so it should already be green — if it is not, something is wrong and you should stop.
7. **This build must contain R0, R1 and R2.** Note their commit SHAs in the block headers; the screenshots double as those items' device evidence.
8. **Enable Reduce Motion on exactly one of the five devices** (Settings → Accessibility → Motion → Reduce Motion) and record which UDID. R0's visible result — the drifting glyph particles absent on craft, vote and reveal while the radial gradient and all content remain — is then covered by the same screenshots that certify R1 and R2, and the other four devices continue to show the animated background as the control. **Say in each block which device had it on.**

**Drive by `ValueKey` or unique text, never by pixel bounds** — five device models, five different coordinate systems. The keys are `player_name_field`, `room_code_field`, `deck_<id>`, `forgeries_<n>`, `rounds_<n>`, `timer_seconds_field`, `answer_field`, `peek_inside_<id>`, `peek_prompt_<idx>`, `deck_peek_shuffle`, `kick_<playerId>`, `game_over_bottom_bar`; labels are `CREATE ROOM`, `START GAME`, `SUBMIT DOSSIER`, `RE-ROLL PROMPT`, `CONFIRM VOTE`, `RETURN TO LOBBY`, `Leave game` → `LEAVE GAME` in game, and **`Leave room` → `CLOSE ROOM`/`LEAVE` in the lobby** (a different control).

### 4.3 Match N1 — E44 and E45

**Config:** five players, `forgeries` at the **default** (which resolves to 4 at five players, so a card carries five options), **`Rounds = 2`**, **timers off**, deck `hypotheticals`.

**`Rounds = 2` is the whole point of this match.** The previous attempt ran `Rounds = 1`, which is why E42 was unreachable as configured — round 2 did not exist.

- **E44 — Your own answer is locked out in round 2, and it is the right one.**
  Play through round 1 normally. **In round 2**, on a card where the player wrote a forgery, assert on that player's device that the option they authored is **stamped `SEALED` / `(Your Forgery)` and cannot be tapped** — and, critically, that **the sealed option is the one whose text they wrote *this* round.** Issue 117's bug was that round 1's option id leaked into round 2, so the lockout landed on the wrong option or on none; a check that only confirms "something is sealed" would have passed against the bug. **Screenshot the round-2 vote screen showing the sealed option and its text.** Then confirm a *different* player's own answer is sealed on a *different* card, so this is not one lucky alignment.
- **E45 — The unmask window withholds the deltas, then publishes them.**
  Reach a reveal on a card where **someone was actually fooled** — the window only opens when `hasFooled` is true, so verify at least one vote went to a forgery before expecting it. **During the ~20-second window, assert no per-player points are displayed** (no `POINTS AWARDED THIS CARD` tray, no `▲`/`▼` deltas in the standings). **After it closes, assert the tray appears with values that include the unmask ±1**, and that the standings badges update.
  **Then the half that only a device can test:** on a second fooled card, **have the host leave before the deadline expires**, and confirm the tray still fills on the remaining devices. Q1 opened `closeUnmaskWindow` to any room member precisely so an absent host cannot strand it, and **no unit test can observe that.** Screenshot both states — during the window and after.

### 4.4 Match N2 — E46

**Config:** five players, **timers OFF** — with timers on, phases auto-advance during the wait and the match state changes underneath the assertion. Any forgery count; `Rounds = 1` is fine.

- **E46 — The presence window really is ten minutes.**
  ⚠️ **~12 minutes of wall clock. Budget for it; run it last.** Reach an active phase, then `xcrun simctl terminate` P5 and **do not relaunch it.** Record the wall-clock time.
  - **At ~2 minutes: assert P5 is STILL in the roster on every other device.** This is the entire point — before Issue 123, a host-initiated `handleDisconnect` evicted them at exactly this mark. Screenshot a remaining device's roster with the timestamp visible in the status bar.
  - **At ~11 minutes: assert P5 is gone from the roster.** Screenshot again.
  - Record both wall-clock timestamps in the block.

  **No unit test can cover this** — fake timers do not suspend an isolate, which is why the emulator falsification (neutering the server guard fails exactly the 150 s test) is necessary but not sufficient.

### 4.5 Reporting and validation

- **Append E44–E46 to `docs/playthrough_findings_5player.md`.** One report per build; do not open a new file.
- Use the existing block shape exactly: `### E44 — <title>` then `- **Verdict:**`, `- **Devices:**`, `- **Room Code:**`, `- **What I did:**`, `- **Observed:**`, `- **Reference:**`, `- **Expected:**`.
- Screenshots into `docs/playthrough_evidence/` as `e44_p2_<what>.png`. **Cite a path only after the file is written** — Rule R5 checks existence.
- **`**Observed:**` must contain a real artefact** — a screenshot path, a `Type:`/`Text: "…"` widget entry, or a `flutter:` log line. **A `grep -` is a hard failure.**
- **Run the gate after each match**, not at the end:
  ```bash
  ./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md
  ```
  It must exit 0, and the block count it reports must be **25**. A gate that parses fewer blocks than exist has told you nothing.
- **Commit per match** — two commits — so a crash costs one match, not both.
- **If a block cannot be performed, mark it `NOT RUN` with a `Reason:`.** Do **not** rename it and assert something easier. That is precisely what produced Issue 135, and it is now lesson 2.33.
- **Open every screenshot you cite and confirm it shows what the prose claims.** Two shipped defects were found this way in the last pass, inside blocks marked PASS.

### 4.6 If R3 finds a defect

**File it with options, Pros/Cons and a blank selection line; finish the match you are in; then stop.** Do not fix it inside the soak and do not start the second match against a build you already know is wrong.

---

## 5. Definition of Done

**R0**
- [ ] `AnimatedThinkingBackground` **settles** under `accessibleNavigation: true`, and so do **craft, vote and reveal**, each asserted with an explicit 5-second `pumpAndSettle` timeout.
- [ ] The falsifying test was run against the current code and **observed to fail** with `pumpAndSettle timed out`, with that line in the commit body.
- [ ] **Both halves falsified separately**: Step 2 reverted fails the settle tests; Step 3 reverted fails the layer-present guard. Both runs recorded.
- [ ] Under `accessibleNavigation: false` the particle layer is **still present** (scoped `find.descendant`) — the animation was guarded, not deleted.
- [ ] Toggling the flag on a mounted tree takes effect **both ways**, proving `didChangeDependencies` rather than an `initState`-only read.
- [ ] The gradient exists in **one** place in the source, not copy-pasted into two branches.
- [ ] `test/phase3_vote_test.dart` still passes all four `reduceMotion` cases.
- [ ] **`EmberBackdrop` was not touched** (§R0.6). If it was worth fixing, it was *filed*, not folded in.

**R1**
- [ ] The `Rotation N of M` `RenderBox` is fully inside the AppBar bounds at **320/375/430 pt × textScale 1.0/1.3/2.0** — all nine.
- [ ] The falsifying test was run against the current code and **observed to fail**, with the geometry in the commit body.
- [ ] The height is **derived from measured text**, not a literal and not a fraction of screen height. The truth-phase header is measurably **shorter** than the forgery-phase header, proving the helper is not returning a constant.
- [ ] Applied to **craft, vote and reveal**; vote and reveal still render correctly at scale 2.0.
- [ ] The `TitleSettle` letter-spacing/wrapping decision is stated in the commit body.
- [ ] **No test asserts an exact pixel height.**
- [ ] **No test in this wave calls `pumpAndSettle()` on craft, vote or reveal** (§1.1), and the full `flutter test` run **completes** rather than hanging.

**R2**
- [ ] The longest prompt **obtained from `PromptDecks` at test time** renders with `didExceedMaxLines == false` and inside the card bounds, with the **real fonts loaded**.
- [ ] The falsifying test was run against the current code and **observed to fail**.
- [ ] The card is capped at `min(screenHeight * 0.7, 560)` and stays fully on screen at 320 × 568.
- [ ] A short prompt produces a **materially shorter** card — the fixed 420 was not simply replaced with a fixed 560.
- [ ] The `FittedBox` decision is stated, and the "inner box only" failure mode was checked.

**R3**
- [ ] `docs/playthrough_findings_5player.md` carries **E44, E45, E46**; the gate exits **0** and reports **25 blocks**.
- [ ] **E44** asserts the sealed option in **round 2** is the one authored *that round*, on two different players' cards.
- [ ] **E45** asserts deltas absent during the window and present after, **and** that the tray fills with the **host absent**.
- [ ] **E46** records **both** wall-clock timestamps, with P5 present at ~2 min and gone at ~11.
- [ ] Every cited screenshot exists **and was opened**.
- [ ] The build under test contains R1 and R2, with their SHAs recorded.
- [ ] Nothing was renamed; anything not performed is `NOT RUN` with a `Reason:`.

**Across the wave**
- [ ] Battery at or above baseline: **0 errors** · **≥234** client · clean functions build · **≥102** functions · deck sync PASS · both evidence gates exit 0 · **deploy still exit 0** (nothing here touches the server).
- [ ] Issues **135, 136, 137 and 138** moved into the **single** existing Resolved heading, and `design_ui_direction.md` updated for **R0**, R1 and R2.

---

## 6. Already delivered — do NOT rework

- **Wave Q** — **Q1** (Issue 133): `closeUnmaskWindow` refuses an early close and returns `{ alreadyClosed: true }` for `null`/`0`; the client trigger is open to any member with a 1500 ms margin and a five-attempt cap. **Falsified:** neutering the guard fails exactly F1 while F2–F7 stay green. Deployed 2026-08-28T02:40–02:41Z. **Q3**: `clock` moved to `dependencies`.
- **The soak's 19 good blocks**, with artefacts on disk. Verified by opening them: **E31** (forgery chain re-links — `e31_p3_relinked.png` shows room `YOGU` and Charlie re-pointed to Bob), **E33** (reader departs mid-vote with readers queued, unreachable below five players), **E41** (five options one per row, own answer `SEALED`, partial third row as the scroll cue). **Do not re-run E22–E39 or E41.**
- **The five-player emulator pre-flight** (`dfac7de`) — the suite's first game above four players.
- **Wave P** — all eleven items. **P4's Option B expansion is accepted**: `totalScore`, `timesFooled` and `playersDeceived` defer into `pendingScoreDeltas` and flush at window close, which is why the standings legitimately hold still during the unmask window.
- **Wave O's six good items**, **Issues 96–105**, **Issues 50–95**, **Issue 31**, **Issues 28/29** as previously recorded.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it.

---

## 7. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** This is why `pendingScoreDeltas` lives there.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **Never let a client bound exceed the server's.** `castVote` and `closeUnmaskWindow` are the models.
- **The presence window gates the ACTION, not the caller.**
- **`pendingScoreDeltas` is flushed at three sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`. Guarding the first two would strand the deltas.
- **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and **caps every match at three departures** — the third ends it.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130); turning them on is the deviation to record.

**Never accept Xcode's "Update to recommended settings" dialog** — it enables `ENABLE_USER_SCRIPT_SANDBOXING` and breaks the iOS build (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is generated. **No file outside the catalogue may branch on a deck id.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak to recover three blocks (135 B); **a screen-height fraction for the AppBar (136, explicitly rejected by the user in favour of measured text)**; auto-shrinking the dealt-card prompt (137 B); **freezing the thinking-background particles in place rather than removing the layer (138 A), and leaving the background unguarded on the grounds that the drift is sub-threshold ambience (138 C)** — the user selected B, which removes the particle layer entirely under Reduce Motion. **And there is no chat or emote feature** — `sendEmote` and `sendRoomChat` appeared only in a fabricated table in the soak report and have never existed in this repository.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Five-player soak report, harness config, block conventions | `docs/playthrough_findings_5player.md` |
| Earlier playthrough evidence | `docs/playthrough_findings_marionette.md`, `…_web.md` |
| Rules, seat tokens, presence, callables, deploy verification | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, **in-game header sizing**, dialogs, error surfaces | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 9. Validation standard

**Diff the block titles before reading the verdicts** (lesson 2.33). A re-aimed block is invisible to every mechanical rule this project has.

**Open the artefact.** Issues 136 and 137 were both found this way, inside blocks marked PASS.

**Measure the thing that actually constrains the layout.** Screen height does not determine whether text fits; text height does. This is R1's whole lesson and it generalises.

**Derive worst cases from data, not from a paste.** R2's test reads the longest prompt from `PromptDecks`, because decks are edited and a hardcoded worst case stops being worst.

**Falsify every guard.** A guard whose test passes with the guard removed is decoration.

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A green suite is not evidence about anything it cannot observe.** All eight gates were green while three blocks tested the wrong thing.

**Treat 100% PASS on never-exercised paths as an anomaly, not a result.**

---

## 10. Feedback loop — what shaped this wave

- **The user rejected a magic number, and was right.** The issue text offered "about 78–84 pt", which would have been correct today and wrong the first time someone changed a font size or turned up accessibility text. **When a spec reaches for a literal to describe a layout, that is a signal the measurement was skipped** — the codebase already had the right tool in `AutoSizedAnswerText`.
- **Two of this wave's three items came from opening a screenshot**, not from a gate, a test, or a bug report. That is now three separate occasions.
- **A test-harness trap turned out to be a user-facing accessibility defect wearing a disguise.** The hang was investigated as a tooling problem; the cause was a widget ignoring Reduce Motion on the three screens players use most. **R0 exists because the fix for the test problem and the fix for the accessibility problem are the same change** — which is worth remembering the next time a suite misbehaves for a reason that looks purely mechanical.
- **The wave's first hang was misdiagnosed from a lesson that did not apply.** The handoff blamed a missing `accessibleNavigation: true`; the file already had it. The real cause was one widget that ignores the flag everything else honours (§1.1). **A convention is only worth trusting once you have checked the specific widget obeys it** — `grep` for the repeating animation, not for the guard.
- **The re-aimed blocks were the last three of twenty-two.** Length is a failure mode; R3 is deliberately two short matches rather than a re-run, and it commits per match.

---

## THE LOOP

```
(1) STUDY the item here + its issue text in ongoing_general_errors.md + the
    files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) If the item is a playthrough: DIFF THE BLOCK TITLES against the spec
    first, and OPEN EVERY CITED SCREENSHOT.
(3) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body.
(4) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE --
    including a renamed block, a changed viewport, or a dropped assertion.
(5) VALIDATE, including every over-reach guard, then RE-RUN THE GUARD WITH
    THE FIX REMOVED and confirm it fails.
(6) RE-RUN THE FULL BATTERY -- exit codes read BARE, not piped. Deploy must
    stay green; nothing in this wave touches the server.
(7) BLOCKED, or a decision is needed? STOP. File it with options, Pros/Cons,
    one (recommended), and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update design_ui_direction.md.
```

**After R3, the queue is empty.** Report the state and stop. Do not invent work.
