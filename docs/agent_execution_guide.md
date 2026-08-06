# Agent Execution Guide — Active Build: Issues 23–26 (August 5, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**What is approved:** exactly four client UI/UX items — Issues 23, 25, 24, 26 — found during the first playtest on real hardware (iPhone 17 / iOS 26.5) against the **deployed** Firebase backend. The user has already chosen the remediation option for each. Those choices are recorded in `docs/ongoing_general_errors.md` on the `Your selection:` line of each issue, and are restated here in §3–§6.

**Nothing is implemented.** The working tree is clean of these four items as of August 5, 2026. Do not go looking for partial work.

**What NOT to touch:** anything in §7 (already delivered), §8 (accepted equivalents), or §9 (intentional decisions). Those lists exist because previous passes kept "fixing" deliberate choices.

**Specs are decisions, not suggestions.** Every number, duration, curve, token name, icon name, and copy string in §3–§6 is deliberate. Implement as written. Do not substitute your own values because they seem better. If a value turns out to be impossible, keep the *intent*, deviate minimally, and say so in the commit body. If the design itself cannot work, **STOP** — file it in `ongoing_general_errors.md` with options and a `Your selection: _____` line, and ask. Do not improvise a redesign.

---

## Standing constraints — apply to every item

1. **Portrait phone is the target.** Every layout must be validated at **360×640 dp portrait**, the worst case the repo tests against. The app is portrait-locked on phones (M1); iPad rotation is intentionally retained.
2. **Design tokens are law.** Use `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge` from `lib/theme/`. Never introduce a raw hex colour, an ad-hoc `Duration`, or a one-off `TextStyle`. If you need a value that does not exist as a token, add it to the token file — do not inline it.
3. **Every animation needs an `AppMotion.reduce(context)` path.** When it returns true, jump to the end state instead of animating. `AppMotion.reduce` reads `MediaQuery.accessibleNavigation`.
4. **Text scale is clamped 1.0–1.3 app-wide** (`main.dart:81–88`). Layouts must survive 1.3.
5. **Touch targets are ≥ 48 dp** (M4). Do not shrink an interactive element below this to win vertical space.
6. **None of these four items touches `functions/` or `firestore.rules`.** If you find yourself editing either, you have left the spec — STOP and re-read. The emulator suite is therefore not a gate for this queue, but run it anyway before your final commit to prove you did not drift.
7. **One item = one commit**, Conventional Commits format per `.agents/skills/commit_message_guidelines/SKILL.md`, with the WHY in the body.

---

## 1. Verified baseline — run this before you change anything

These numbers were measured in the August 5, 2026 session on the current tree. **This is the regression bar.** If a fresh checkout does not reproduce them, triage that first — do not build on a broken baseline.

| Gate | Command | Current result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors**, 24 warnings, 251 infos (275 issues) |
| Client tests | `flutter test` | **49/49 pass** |
| Functions build | `npm --prefix functions run build` | clean (`tsc`, no output) |
| Backend E2E | `npm --prefix functions test` | **28/28 pass** on the Firebase emulator |
| iOS compile | `flutter build ios --simulator --debug` | `✓ Built build/ios/iphonesimulator/Runner.app` |

### ⚠️ Analyzer trap — read this before you panic

**Run `flutter analyze lib test`, not bare `flutter analyze`.**

Bare `flutter analyze` reports **1053 issues including 678 errors**. Every one of those 678 errors lives in `build/ios/SourcePackages/` and `build/macos/SourcePackages/` — vendored Flutter plugin source that Swift Package Manager drops into `build/` during an iOS/macOS build. It is not project code, it is gitignored, and it is not yours to fix. The analyzer walks it anyway because `build/` is inside the package root.

If you see 678 errors, you ran the wrong command. Scoping to `lib test` gives the true project figure of **0 errors**. A previous run of this baseline recorded "0 errors" from bare `flutter analyze` only because it happened to run *before* any iOS build had populated `build/`.

### Notes on the gates
- The backend suite boots its own emulators via `emulators:exec` and needs `firebase-tools` (via `npx`) plus Java. If Java is missing the suite does not run — say so explicitly rather than reporting a pass.
- `flutter build ios` requires `ios/Runner/GoogleService-Info.plist` on disk. It is **gitignored**; on a fresh clone download it from the Firebase console (project `gaslight-46368`, iOS app `com.whylabs.gaslight`) or the link step fails with `Build input file cannot be found`.

---

## 2. Execution order

| # | Item | Position rationale |
|---|---|---|
| 1 | **Issue 23** — hybrid icon system | Independent, and it introduces the `ThematicIconType.timer` / `.secret` routing that §4 and §5 both consume. Doing it first means the settings panel and the slimmed entry form are built against final icons instead of being retrofitted. |
| 2 | **Issue 25** — House Rules in the Parlor | Must precede Issue 24. It is what *removes* the rounds dropdown and timer toggle from the entry form; Issue 24's fit target is unreachable while those controls are still there. |
| 3 | **Issue 24** — entry form fits the viewport | Depends on 25 having freed ≈140 dp. Spacing changes alone cannot close the gap. |
| 4 | **Issue 26** — draggable roster sheet | Independent of the other three; last because it is the only one with hand-rolled gesture maths and is the most likely to need iteration. |

---

## 3. Issue 23 — Hybrid icon system (user selected **Option B**)

**What this means for the user:** icons that are supposed to look like a matched set currently look like they were drawn by three different people at three different sizes. The quill towers over the hourglass; the round-arrow dwarfs both.

### The gap
`lib/theme/app_icons.dart` hand-paints all 19 glyphs in `_ThematicIconPainter` (lines 56–442) using per-glyph fractional coordinates with **no optical normalisation pass**. The `size:` parameter sets the `SizedBox`, not the ink.

This is **not** a call-site bug. All three icons in the reported screenshot already pass `size: 20`:
- `lobby_screen.dart:778` — `ThematicIconType.writing` (quill, name field)
- `lobby_screen.dart:802` — `ThematicIconType.redraw` (round arrow, rounds dropdown)
- `lobby_screen.dart:833` — `ThematicIconType.hourglass` (timer toggle)

Measured ink extents inside that identical 20×20 box:

| Glyph | Painter lines | Ink extent | At `size: 20` |
|---|---|---|---|
| `redraw` | 400–436 | ≈ 0.90 w (arc `r = 0.38 w` line 401 + `0.18 w` arrowhead line 424) | ≈ 18.0 dp |
| `writing` | 237–255 | ≈ 0.65 w × 0.75 h | ≈ 13.0 dp |
| `hourglass`/`timer` | 184–221 | ≈ 0.50 w × 0.70 h | ≈ 10.0 dp |
| `key`/`secret` | 134–154 | ≈ 0.38 w | ≈ 7.6 dp |

Stroke weight diverges too: the shared paint is `math.max(1.5, size.width / 16)` = 1.5 dp at size 20 (line 67), while `redraw` overrides to `0.08 * w` = 1.6 dp (line 409). Net: the round-arrow's ink is **~2.4× the key's** at an identical `size:`.

### Implementation

**Step 1 — add the dependency.**
```bash
flutter pub add phosphor_flutter
```
Verified to resolve as **`phosphor_flutter: ^2.1.0`** with zero constraint conflicts against the current lockfile. `PhosphorIconData extends IconData` (`lib/src/phosphor_icon_data.dart:5`), so a plain `Icon()` renders it — no custom widget needed.

**Step 2 — use weight `PhosphorIconsLight`.** Its 1.5 px nominal stroke matches the painter's hairline. Do **not** use `Thin` (1 px — disappears against `AppColors.ground` at 20 dp) or `Regular` (too heavy beside the remaining sigils). The class is `PhosphorIconsLight` from `package:phosphor_flutter/phosphor_flutter.dart`.

**Step 3 — fork inside `ThematicIcon.build` (`app_icons.dart:32–54`).** `ThematicIcon` stays the single public entry point and **every existing call site keeps working unchanged** — this is what preserves the design-token contract in §9.

Add two top-level constants above the class:

```dart
/// The six avatar sigils stay hand-painted: they carry the V1/V2 character
/// work and are driven by [SigilTicker] via [AnimatedThematicIcon].
const Set<ThematicIconType> _bespokeSigils = {
  ThematicIconType.flame,
  ThematicIconType.moth,
  ThematicIconType.key,
  ThematicIconType.raven,
  ThematicIconType.moon,
  ThematicIconType.hourglass,
};

const Map<ThematicIconType, IconData> _phosphorGlyphs = {
  ThematicIconType.writing:  PhosphorIconsLight.feather,
  ThematicIconType.redraw:   PhosphorIconsLight.arrowsClockwise,
  ThematicIconType.timer:    PhosphorIconsLight.hourglass,
  ThematicIconType.secret:   PhosphorIconsLight.key,
  ThematicIconType.ledger:   PhosphorIconsLight.bookOpen,
  ThematicIconType.envelope: PhosphorIconsLight.envelope,
  ThematicIconType.observe:  PhosphorIconsLight.magnifyingGlass,
  ThematicIconType.confirm:  PhosphorIconsLight.sealCheck,
  ThematicIconType.sound:    PhosphorIconsLight.bellRinging,
  ThematicIconType.mute:     PhosphorIconsLight.bellSlash,
  ThematicIconType.host:     PhosphorIconsLight.lamp,
};
```

All eleven names were verified present in `PhosphorIconsLight` in `phosphor_flutter 2.1.0`. Then in `build`:

```dart
@override
Widget build(BuildContext context) {
  if (!_bespokeSigils.contains(type)) {
    final glyph = _phosphorGlyphs[type];
    if (glyph != null) {
      // SizedBox keeps the layout footprint identical to the painted path,
      // so no call site needs to change.
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: Icon(glyph, size: size, color: color)),
      );
    }
  }
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _ThematicIconPainter(type, color)),
  );
}
```

**Step 4 — mind the shared painter cases.** `hourglass` (sigil, stays bespoke) and `timer` (functional, routes to Phosphor) are distinct enum values that currently share one `case` at lines 184–185. Same for `key` (sigil) vs `secret` (functional) at lines 134–135. **Splitting their rendering is the point:** functional UI must use `timer` and `secret`; avatars use `hourglass` and `key`. Note that `lobby_screen.dart:833` currently uses `hourglass` for a *functional* timer row — that row moves to the House Rules panel in §4 and must use `timer` there.

**Step 5 — leave the painter cases for routed types in place.** They are still reachable through `_AnimatedThematicIconPainter`'s `default:` fallback (line 934–936). Deleting them is a separate cleanup, not this commit.

### Validation

Create **`test/thematic_icon_test.dart`**:

```dart
testWidgets('routes functional glyphs to Phosphor and keeps sigils painted', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [
    ThematicIcon(type: ThematicIconType.writing, size: 20),
    ThematicIcon(type: ThematicIconType.flame,   size: 20),
  ]))));

  final writing = find.byWidgetPredicate(
    (w) => w is ThematicIcon && w.type == ThematicIconType.writing);
  final flame = find.byWidgetPredicate(
    (w) => w is ThematicIcon && w.type == ThematicIconType.flame);

  // FALSIFYING ASSERTION — fails against today's code, passes only after the fork.
  expect(find.descendant(of: writing, matching: find.byType(CustomPaint)), findsNothing);
  expect(find.descendant(of: writing, matching: find.byType(Icon)), findsOneWidget);

  // Guard against over-reach: sigils must still be painted.
  expect(find.descendant(of: flame, matching: find.byType(CustomPaint)), findsOneWidget);
});
```

**The falsifying assertion is `findsNothing` for `CustomPaint` under `writing`.** Today that finds a widget, so the test fails — which is what proves the routing actually happened rather than the test being vacuous. Note `Icon` renders an internal `RichText`, not a `CustomPaint`, so the two matchers are genuinely exclusive.

Add a second test asserting the glyph identity, so a wrong mapping is caught:
```dart
final icon = tester.widget<Icon>(find.descendant(of: writing, matching: find.byType(Icon)));
expect(icon.icon, PhosphorIconsLight.feather);
expect(icon.size, 20.0);
```

Then run:
```bash
flutter analyze lib test && flutter test
```
Expect **0 errors** and **51/51** (49 existing + 2 new).

**Manual check (required):** run on the iPhone 17 simulator, open the entry form, and confirm the quill in the name field and the round-arrow in the rounds dropdown now read at the same visual weight. Compare against the "before" screenshots in the Issue 23 block of `ongoing_general_errors.md`.

**Known residual — accepted, do NOT fix unasked.** Sigil-to-sigil optical sizing stays uneven (`key` ≈ 0.38 w vs `flame` ≈ 0.80 h). It reads acceptably because the six character tokens sit inside medallions that impose their own visual frame. If review finds the token row uneven, the remedy is the Issue 23 **Option A** bounds table applied to those six glyphs only — file it, do not do it on your own initiative.

### Blast radius
- `pubspec.yaml` / `pubspec.lock` — new dependency.
- `lib/theme/app_icons.dart` — the fork.
- No call sites change. Confirm with `grep -rn "ThematicIcon(" lib | wc -l` before and after; the count must be identical.

---

## 4. Issue 25 — House Rules in the Parlor (user selected **Option C**)

**What this means for the user:** game rules currently have to be chosen before the room exists, on a screen that is already too tall, while the sound toggle lives somewhere else entirely. Rules move to where they actually matter — inside the Parlor, editable by the host while people are still joining.

### The gap
- "Disable Game Timers" is inlined into the entry form as a bespoke `Container`+`Row`+`Switch` at `lobby_screen.dart:820–860`, holding local `_isTimerDisabled` state.
- "Number of Rounds" is a `DropdownButtonFormField` at `lobby_screen.dart:785–818`, bound to `_selectedRounds` (initialised to `1` at `lobby_screen.dart:36`).
- The sound toggle is unrelated and lives in the Parlor `AppBar` at `lobby_screen.dart:391–398`.
- No settings route exists: `main.dart:90–105` registers only `/`, `/craft`, `/vote`, `/reveal`, `/game-over`.

### Backend is already sufficient — do NOT modify `functions/`
This was verified, not assumed:
- `updateLobbySettings` (`functions/src/index.ts:979`) destructures `{ roomCode, sabotageAnswersCount, isTimerDisabled, selectedDeckId }` at line 984 and enforces host-only via `hostPlayer.isHost`.
- `GameService.updateLobbySettings({int? sabotageAnswersCount, bool? isTimerDisabled, String? selectedDeckId})` already wraps it at `game_service.dart:361`.
- **The "Number of Rounds" dropdown writes `sabotageAnswersCount`** — see `lobby_screen.dart:85`. It is the forgery count, which the README calls "forgery rounds". Both settings the entry form collects are therefore already live-editable post-creation.

### Implementation

**Step 1 — new widget `lib/widgets/house_rules_dialog.dart`.** A `Dialog`, not a bottom sheet: the Parlor already hosts a `DraggableScrollableSheet` (§6) and a second sheet would fight it for gestures.

- Surface `AppColors.groundRaised`, `RoundedRectangleBorder(borderRadius: 12, side: BorderSide(color: AppColors.brass, width: 1.5))`.
- Padding `EdgeInsets.fromLTRB(20, 20, 20, 12)`.
- Header row: `ThematicIcon(type: ThematicIconType.ledger, size: 22)` + 10 dp gap + `Text('HOUSE RULES', style: AppTextStyles.sectionLabel)`.
- 16 dp gap, then the rounds control, 12 dp gap, then the timer control.
- Expose `static Future<void> show(BuildContext)` wrapping `showDialog`.

**Step 2 — the two controls.** Reuse the exact decoration currently on the entry-form widgets so the visual language carries over verbatim — copy from `lobby_screen.dart:785–818` (dropdown) and `820–860` (toggle), with two changes:
- The timer row's icon becomes `ThematicIconType.timer` (was `hourglass` — see §3 Step 4).
- Values come from `context.watch<GameService>().gameState`, not local state: `room?.sabotageAnswersCount ?? 2` and `room?.isTimerDisabled ?? false`.
- `onChanged` calls `gs.updateLobbySettings(sabotageAnswersCount: v)` / `(isTimerDisabled: v)`.

**Step 3 — host gating.** `final isHost = gs.currentPlayer?.isHost ?? false;` (the Parlor already does this at `lobby_screen.dart:312`). When `!isHost`: wrap each control in `Opacity(opacity: 0.5)` and pass `onChanged: null`. Add the caption, copy verbatim:

> `Only the host may set the house rules. Changes appear here as they are made.`

styled `fontFamily: 'Lora', fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.ivory.withOpacity(0.6)`.

The disabled controls are an **affordance, not the security boundary** — the server rejects non-host writes regardless.

**Step 4 — wire into the Parlor `AppBar`.** Add a second `IconButton` to `actions:` at `lobby_screen.dart:390–399`, placed **before** the existing sound button so sound stays rightmost:
```dart
IconButton(
  icon: ThematicIcon(type: ThematicIconType.ledger, color: theme.colorScheme.secondary),
  onPressed: () => HouseRulesDialog.show(context),
  tooltip: 'House Rules',
),
```

**Step 5 — strip the entry form and change the creation default.** Delete `lobby_screen.dart:785–818` (dropdown) and `820–860` (toggle) along with their trailing `SizedBox`es at `784` and `819`. Delete the now-unused `_selectedRounds` (line 36) and `_isTimerDisabled` fields.

At `lobby_screen.dart:85`, replace `sabotageAnswersCount: _selectedRounds` with the literal **`sabotageAnswersCount: 2`**.

**Behaviour change, stated explicitly:** rooms now start at 2 forgeries instead of the old `_selectedRounds` initial of 1. Two is the documented default in `lib/models/game_state.dart:49` and in the README, and the host can change it in the Parlor before START. This is deliberate — do not "restore" 1.

**Naming caveat — leave alone.** The label says "Number of Rounds" while the field is `sabotageAnswersCount`. Renaming user-visible copy is a product decision, not this task.

### Validation

Create **`test/house_rules_dialog_test.dart`**. Follow the `GameService` + `test/fake_functions.dart` setup idiom used by `test/phase2_craft_test.dart`.

1. **Host can edit.** Seat the current player as host, pump the dialog, assert the `Switch` has a non-null `onChanged` and the `DropdownButtonFormField<int>` is enabled. Tap the switch; assert `fake_functions` recorded an `updateLobbySettings` call carrying `isTimerDisabled: true`.
2. **Non-host cannot — the falsifying assertion.** Seat the current player as a non-host. Assert:
   ```dart
   expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
   expect(find.textContaining('Only the host may set the house rules'), findsOneWidget);
   ```
   Then tap the switch and assert **no** `updateLobbySettings` call was recorded. A test that only checks the caption renders would pass against a broken build — the "no call recorded" assertion is the one that actually proves gating.
3. **Values stream from Firestore, not local state.** Pump with `sabotageAnswersCount: 4` in the fake game state and assert `find.text('4 Rounds')` is present. This falsifies a naive implementation that keeps its own `setState` copy.
4. **Creation default.** In the entry-form test, tap CREATE ROOM and assert the recorded `createRoom` payload contains `sabotageAnswersCount: 2`.

```bash
flutter analyze lib test && flutter test
```

**Manual check (required, two devices):** run the app on the iPhone 17 simulator *and* macOS (`flutter run -d macos`). Create a room on one, join from the other. Change rounds on the host; confirm the non-host's dialog updates without a reload, and that the non-host's controls are visibly disabled.

### Blast radius
- `lib/widgets/house_rules_dialog.dart` — new.
- `lib/screens/lobby_screen.dart` — AppBar action; deletion of lines 36, 784–860; literal at line 85.
- Any existing test that types into or asserts on the entry form's rounds dropdown or timer switch will break. Grep before you start: `grep -rn "Disable Game Timers\|Number of Rounds" test/`.

---

## 5. Issue 24 — Entry form fits the viewport (user selected **Option A**)

**What this means for the user:** on a phone, the room-code field and the JOIN ROOM button sit below the fold. A player handed a room code cannot see where to type it without scrolling a page that does not look scrollable.

### The gap
`_buildEntryForm` (`lobby_screen.dart:722`) wraps content in a `SingleChildScrollView` (line 729) inside `ConstrainedBox(minHeight: constraints.maxHeight)` (730–734), so the page is *designed* to scroll. Summing the tree at iPhone-17 portrait:

| Element | Line | Height |
|---|---|---|
| Page padding (32 × 2) | 736 | 64 |
| `AnimatedLobbyLogo` | 741 | ≈ 250 |
| gap | 742 | 40 |
| Card title + gap | 749–758 | ≈ 46 |
| Name field | 759–783 | ≈ 56 |
| gap | 784 | 18 |
| Rounds dropdown | 785–818 | ≈ 56 |
| gap | 819 | 18 |
| Timer toggle | 820–860 | ≈ 48 |
| gap | 860 | 24 |
| "Select Character Token" + gap | 862–865 | ≈ 32 |
| Token `Wrap` (2 rows of 3) | 866 | ≈ 140 |
| gap | 899 | 30 |
| CREATE ROOM | 901 | ≈ 56 |
| OR divider | 912 | ≈ 40 |
| Room-code field + gaps | 940–947 | ≈ 74 |
| JOIN ROOM + trailing | 960–962 | ≈ 74 |

≈ **1066 dp** against an ~790 dp usable viewport — roughly **275 dp over**, matching the screenshot where the page ends at "OR". (Heights are read off the widget tree, not measured at runtime; the test below pins the real number.)

### Implementation

**Target: zero scroll extent at 360×640 dp at default text scale.** Keep the `SingleChildScrollView` — it remains the overflow safety net at text scale 1.3 and on smaller devices. The requirement is that it does not *need* to scroll, not that it is removed.

1. **Removals (from §4):** rounds dropdown + gap, timer toggle + gap. Reclaims **≈ 140 dp**.
2. **Vertical rhythm — replace the ad-hoc 18/24/30/40 ladder with a 12/16/20 scale:**
   - `742` logo→card: `40` → **`24`**
   - `758` card title→first field: `24` → **`16`**
   - between remaining fields: `18` → **`12`**
   - `899` before CREATE ROOM: `30` → **`20`**
   - around the OR divider: `18` → **`12`**

   Reclaims **≈ 60 dp**.
3. **Page padding** at line 736: `EdgeInsets.all(32)` → **`EdgeInsets.symmetric(horizontal: 20, vertical: 16)`**. Reclaims **≈ 32 dp**.
4. **Logo breakpoint:** inside the existing `LayoutBuilder` (line 727), when `constraints.maxHeight < 700`, wrap `AnimatedLobbyLogo` in `Transform.scale(scale: 0.7, alignment: Alignment.center)` **and** shrink its reserved height accordingly — a bare `Transform.scale` does not change layout size, so wrap in a `SizedBox` with the reduced height or the saving is purely visual. Reclaims **≈ 75 dp** at 640 dp tall.

   Total reclaimed ≈ **307 dp** against a ~275 dp deficit.

**Do not touch:** the character-token `Wrap` at line 866 (two rows is the V2 design), the `ConstrainedBox(maxWidth: 420)` at 743–744, or any 48 dp minimum hit area (M4).

### Validation

Create **`test/lobby_entry_test.dart`**, using the surface-size idiom from `test/game_over_screen_test.dart:196–202`:

```dart
testWidgets('entry form fits 360x640 portrait without scrolling', (tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await setupAndPumpEntryForm(tester: tester, reduceMotion: true);

  // FALSIFYING ASSERTION — currently ~275 dp > 0, so this fails today.
  final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
  expect(scrollable.controller?.position.maxScrollExtent ?? 0.0, 0.0);

  // Prove the point of the exercise: the below-the-fold controls are on screen.
  expect(find.text('JOIN ROOM'), findsOneWidget);
  expect(tester.getBottomRight(find.text('JOIN ROOM')).dy, lessThanOrEqualTo(640.0));

  expect(tester.takeException(), isNull);  // catches RenderFlex overflow
});
```

**The falsifying assertion is `maxScrollExtent == 0.0`.** Asserting only that JOIN ROOM "exists" is vacuous — `find.text` matches widgets that are laid out below the fold. The `getBottomRight().dy <= 640` check is what proves visibility.

Add a second test at **text scale 1.3** asserting `tester.takeException()` is null — proving the tightened spacing did not break the accessibility clamp (standing constraint 4). Scrolling *is* permitted at 1.3.

```bash
flutter analyze lib test && flutter test
```

**Manual check (required):** iPhone 17 simulator — the entire entry form from logo to JOIN ROOM visible with no scrolling. Then Settings → Accessibility → Larger Text at maximum, and confirm the form scrolls gracefully rather than overflowing.

### Blast radius
- `lib/screens/lobby_screen.dart` — `_buildEntryForm` only.
- Any test asserting entry-form geometry or the removed controls. Grep first: `grep -rn "GUEST LEDGER\|CREATE ROOM" test/`.

---

## 6. Issue 26 — Draggable roster sheet (user selected **Option C**)

**What this means for the user:** in the Parlor, once the suspect list is pulled up it cannot be pulled back down. The brass handle — the one thing on screen that looks draggable — does nothing at all.

### The gap
`DraggableScrollableSheet` at `lobby_screen.dart:542–656` derives its extent **solely** from the `ScrollController` it passes into `builder`. That controller is attached to exactly one widget: the `GridView.builder` at lines 606–607.

Everything in the sheet header is a plain `Column` child with **no gesture recognizer of any kind**:
- drag handle — lines 570–580
- "N SUSPECTS JOINED" — lines 581–593
- ready counter — lines 595–603

So a drag starting anywhere in the header is swallowed. Collapsing only works by dragging *on the grid*, and only while it sits at offset 0. With a short roster (the reported case was 1 player) the grid does not fill its viewport, has no scroll extent to hand the sheet under default physics, and the gesture is dropped entirely.

### Implementation

1. **Controller.** Add `final DraggableScrollableController _sheetController = DraggableScrollableController();` to the Parlor `State`. Pass `controller: _sheetController` to the sheet. **Dispose it** in `dispose()` — a leaked controller here survives Firestore stream rebuilds.
2. **Snapping.** Add `snap: true, snapSizes: const [0.25, 0.4, 0.7]`. Keep `initialChildSize: 0.4, minChildSize: 0.25, maxChildSize: 0.7` (lines 543–545) exactly as they are.
3. **Header gestures.** Wrap the whole header block (lines 570–603 — handle, title, and counter together) in a single `GestureDetector` with **`behavior: HitTestBehavior.opaque`** so the entire header strip is grabbable, not just the 40×4 dp handle.

   - `onVerticalDragUpdate`:
     ```dart
     final h = MediaQuery.of(context).size.height;
     final next = (_sheetController.size - details.primaryDelta! / h).clamp(0.25, 0.7);
     _sheetController.jumpTo(next);
     ```
     Note the **minus**: dragging down gives a positive `primaryDelta`, which must *shrink* the extent. Getting this sign wrong is the single most likely bug here and produces a sheet that fights the finger.
   - `onVerticalDragEnd`: choose from velocity —
     `details.primaryVelocity! > 300` → `0.25`; `< -300` → `0.7`; otherwise the nearest of `[0.25, 0.4, 0.7]` to the current size. Then
     `_sheetController.animateTo(target, duration: AppMotion.standard, curve: Curves.easeOutCubic)`.
     `AppMotion.standard` is 300 ms (`lib/theme/app_motion.dart`). Do not invent a different duration.
   - `onTap`: `_sheetController.size > 0.5 ? 0.25 : 0.7`, same duration and curve.
4. **Guards.**
   - `if (!_sheetController.isAttached) return;` before **every** controller access. The sheet builds before the controller attaches, and Firestore stream rebuilds re-run `build` — an unguarded `.size` throws.
   - Under `AppMotion.reduce(context)`, replace `animateTo` with `jumpTo` (standing constraint 3).
5. **Grid physics.** Add `physics: const AlwaysScrollableScrollPhysics()` to the `GridView.builder` at line 606 so a 1–3 player roster still hands drags to the sheet.

### Validation

Create **`test/lobby_parlor_sheet_test.dart`**:

1. **Header drag moves the sheet — the falsifying assertion.**
   ```dart
   final startSize = /* read extent via the controller or the sheet's height */;
   await tester.drag(find.text('1 SUSPECTS JOINED'), const Offset(0, 200)); // downward
   await tester.pumpAndSettle();
   expect(currentSize, lessThan(startSize));
   ```
   Drag the **title text**, not the grid — that is precisely the surface that does nothing today, so this fails against current code. A test that drags the grid would pass before the fix and prove nothing.
2. **Direction is correct.** The assertion above must be `lessThan`. If an implementation has the sign inverted, dragging down *expands* and this fails — which is the whole reason it is written as an inequality rather than "extent changed".
3. **Tap toggles.** Tap the header at the 0.4 initial extent; assert the extent settles at `0.7`. Tap again; assert `0.25`.
4. **Short roster.** Seat exactly **1** player. Repeat assertion 1. This is the reported repro and the case default physics drops.
5. **Grid still scrolls independently.** Seat **10** players (`debugAddBots` seats 9 + host). Expand to 0.7, then drag *upward on the grid* and assert the grid's scroll offset increased while the sheet extent stayed at 0.7. This guards against over-reach — a fix that routes every gesture to the sheet would break roster scrolling.
6. **No leak.** After `tester.pumpWidget(Container())`, assert no exception — proving `dispose()` runs.

```bash
flutter analyze lib test && flutter test
```

**Manual check (required):** iPhone 17 simulator. Create a room solo (1 player), drag the handle down — it must collapse. Tap it — it must toggle. Then `DEBUG: ADD 9 BOTS`, expand, and confirm the grid scrolls inside the sheet without collapsing it.

### Blast radius
- `lib/screens/lobby_screen.dart` — sheet block 542–656 plus the `State` fields and `dispose()`.
- The Parlor body's bottom padding (`lobby_screen.dart:404`, `fromLTRB(24, 12, 24, 260)`) is hand-tuned to clear the sheet. If snapping changes the resting extent, re-check that this padding still clears it at 360×640.

---

## 7. Already delivered — do NOT rework

Server-authoritative backend · all gameplay features (P1–P6, P8, P10) · heuristic duplicate-answer check · E7 sound · full UI/UX program (U0–U8 + UF punch list) · mobile-first pass (M1–M5 + MF1) · character pass (V1–V5). All were independently verified in the July 16, 2026 pass. Records are in `ongoing_general_errors.md`.

**App identity and release plumbing (August 4–5, 2026) — do not revert:**
- Bundle ID is **`com.whylabs.gaslight`** on every platform (iOS, macOS, Android `namespace` + `applicationId`, Linux `APPLICATION_ID`). The Android `MainActivity.kt` was moved to the matching Kotlin package — if it drifts back, the manifest's `.MainActivity` fails to resolve and the app crashes on launch.
- Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449` in project `gaslight-46368`.
- iOS deployment target **15.0** in all three build configs plus `ios/Podfile` — the Firebase SDK floor. Lowering it breaks the build with `requires minimum platform version 15.0`.
- `functions/package.json` engines: Node **22**.
- `ITSAppUsesNonExemptEncryption = false` in `ios/Runner/Info.plist`.
- `ios/Runner/GoogleService-Info.plist` is **required on disk** for the Xcode build (it is wired into the Runner target's Resources phase) but is **gitignored**. Fresh clones must download it.
- `.env` ships inside the IPA as a Flutter asset, so **`USE_EMULATOR` must be `false`** in any build handed to a tester. Use `flutter run --dart-define=USE_EMULATOR=true` for local emulator work instead.

---

## 8. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field rather than in a bottom bar — a deliberate keyboard-interplay exception (M5).
- **Vote's CONFIRM is bottom-anchored via `Expanded`+`SafeArea`** rather than a literal bottom bar — accepted as equivalent.
- **Reactions send raw emoji strings** over the wire; medallions are render-side only (V5).

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through Cloud Functions callables; `firestore.rules` denies client room writes. Transactions read-before-write always; `advancePhaseInternal` never reads.
- **Portrait-locked on phones**, iPad rotation intentionally retained.
- **Text scale clamped 1.0–1.3** app-wide — a recorded accessibility trade-off (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`. Pure synonyms passing is the accepted trade-off (Decision 2).
- **The `_advancedStateKeys` / once-per-event guard patterns** (reveal sounds, raven hops, seal stamps, ceremony sounds) exist to survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` remains the single public icon entry point** even after §3 — call sites must not import `phosphor_flutter` directly.
- Design tokens are law: `AppColors` / `AppTextStyles` / `AppMotion` / `ThematicIcon` / `WaxSealBadge`.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Engineering history, all issues & selections | `docs/ongoing_general_errors.md` |
| How to run / playtest (emulator + TestFlight) | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` (scoring/UI incl. five-beat reveal · prompt system incl. custom decks · database/security incl. callables table · duplicate-answer filtering · UI direction, stamped SHIPPED) |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

Detailed system behaviour belongs in the design docs. This guide points at them; it does not duplicate them.

---

## 11. Maintaining `.gitignore`

The iOS/TestFlight work in August 2026 generated several new build artefacts and config files. Some belong in the repo and some must never enter it. Getting this backwards is expensive in both directions: a committed secret is hard to retract, and an ignored lockfile silently breaks reproducible builds for everyone else.

### The decision rule

Ask two questions, in this order:

1. **Is it a secret, or does it identify a specific developer's machine or account?** → **ignore it, always.** No exceptions, no "it's only an API key".
2. **Would a fresh clone fail, or build differently, without it?** → **commit it.** Lockfiles, project aliases, and resolved dependency versions all fall here.

Anything generated *and* reproducible from committed sources (`build/`, `.dart_tool/`, `Pods/`, `functions/lib/`, `functions/node_modules/`) is ignored — it is derivable, and it is large.

### Current uncommitted state

`.gitignore` already carries an **uncommitted** addition of two rules from the Swift Package Manager migration:
```
.build/
.swiftpm/
```
Keep both. They correctly cover SPM's local scratch directories.

### ⚠️ Trap: `.swiftpm/` does not match `swiftpm/`

The rule `.swiftpm/` (leading dot) matches nothing Xcode actually created here. The real paths are:
```
ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
```
— directory `swiftpm`, no dot. Verify with `git check-ignore -v <path>`: it prints the matching rule, or exits non-zero when nothing matches. **Do not "fix" this by adding a `swiftpm/` rule** — those two `Package.resolved` files should be **committed** (see below).

### Disposition of the four currently-untracked paths

| Path | Action | Why |
|---|---|---|
| `.firebaserc` | **commit** | Maps the `default` alias to project `gaslight-46368`. Without it every `firebase deploy` needs a manual `firebase use`, and someone will eventually deploy to the wrong project. Contains no secrets — a project ID is not sensitive. |
| `ios/Podfile.lock` | **commit** | Pins native pod versions. Uncommitted, two machines silently resolve different native dependencies. Standard Flutter/iOS practice. |
| `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | **commit** | Pins resolved Swift Package versions — the SPM equivalent of a lockfile. This is `xcshareddata`, i.e. explicitly the *shared* (non-per-user) part of the Xcode project. |
| `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` | **commit** | Same, for the workspace. |

Stage them explicitly, never with `git add .`:
```bash
git add .firebaserc ios/Podfile.lock \
  ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

### Rules that must never be removed

These are load-bearing. Deleting any of them leaks a credential or a machine-specific file:

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys for web/Android/iOS **and** the `USE_EMULATOR` flag. This file is bundled into the IPA as a Flutter asset — see §7. |
| `**/google-services.json` | Android Firebase config. |
| `**/GoogleService-Info.plist` | iOS Firebase config. Required on disk to build (§1) but never committed. |
| `/build/`, `.dart_tool/` | Generated. Also the source of the 678 phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Contain absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

### Adding a new rule — the procedure

1. Add the pattern to `.gitignore`, in the existing commented section it belongs to (`# Dotenv`, `# Firebase config`, `# Cloud Functions build and dependencies`, …). Do not append loose rules to the bottom; the file is organised by origin.
2. **Verify it matches** — a rule that silently matches nothing is the most common `.gitignore` bug:
   ```bash
   git check-ignore -v <the-path-you-meant-to-ignore>
   ```
   It must print `.gitignore:<line>:<rule>	<path>`. No output means your pattern is wrong.
3. **If the file is already tracked, the new rule does nothing** — `.gitignore` only affects untracked files. Untrack it without deleting it:
   ```bash
   git rm --cached <path>
   ```
   Then commit. If the file held a secret, rotate the secret: it remains in history.
4. Confirm nothing you intended to keep got swept up:
   ```bash
   git status --short
   ```

### Verifying the whole thing

```bash
git status --porcelain | grep "^??"
```
On a healthy tree after the four commits above, this returns **nothing**. Any new untracked path is either something to commit or something to ignore — decide with the rule at the top of this section rather than leaving it dangling.

Commit `.gitignore` changes as `chore(gitignore): <what>` with the reason in the body — future readers need to know why a rule exists before they delete it.

---

## THE LOOP — repeat per item, in the §2 order

```
(1) STUDY the item here + the design_*.md contract it touches + the exact files at the cited lines.
(2) IMPLEMENT exactly as specified. Specs are decisions, not suggestions.
(3) VALIDATE: write the item's tests FIRST and watch them fail against current code
    (a test that passes before your change proves nothing), then implement until green.
    Then run the full §1 battery.
(4) BLOCKED, or the spec is wrong? STOP. File it in ongoing_general_errors.md with
    options and a `Your selection: _____` line. Ask. Do not improvise.
(5) RECORD: move the issue to the Resolved section of ongoing_general_errors.md using the
    bug_documentation_guidelines format (**Problem** / **Solution** / **Validation**).
    Sync any design doc whose described behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] Issue 23 implemented; `test/thematic_icon_test.dart` green; no call site changed.
- [ ] Issue 25 implemented; `test/house_rules_dialog_test.dart` green; non-host gating proven by a "no call recorded" assertion; two-device manual check done.
- [ ] Issue 24 implemented; `test/lobby_entry_test.dart` green with `maxScrollExtent == 0.0` at 360×640; text-scale-1.3 test green.
- [ ] Issue 26 implemented; `test/lobby_parlor_sheet_test.dart` green including the 1-player repro and the 10-player grid-scroll guard.
- [ ] Full battery green: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 49 + new** · `npm --prefix functions run build` clean · `npm --prefix functions test` **28/28** · `flutter build ios --simulator --debug` succeeds.
- [ ] All four issues moved to the Resolved section of `ongoing_general_errors.md`.
- [ ] `.gitignore` hygiene per §11: the four untracked paths committed, `git status --porcelain | grep "^??"` returns nothing, and no secret-guarding rule was removed.
- [ ] Four commits, one per item.
- [ ] This guide rewritten to **Queue Complete** — or to the next approved queue.

**When the four items are done and this guide has been rewritten: the queue is empty. Do not invent work.** The only legitimate triggers for further action are (a) a new `Your selection:` line filled in by the user in `ongoing_general_errors.md`, (b) a regression against the §1 baseline on a fresh checkout, or (c) an explicit user request. Store-readiness chores — app icons, store listing assets, privacy manifest, release signing — are user-driven; do not start them unsolicited.
