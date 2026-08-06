# Agent Execution Guide — Active Build: Issue 30 → T1 → Issue 29 → T2 (August 6, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**Approved work — four items, in this order:**

| # | Item | Scope | Selected |
|---|---|---|---|
| 1 | **Issue 30** — hide `Family-Friendly Decks Only` from non-hosts | `lib/` + 1 test | Option A |
| 2 | **T1** — close the Issue 27 test-coverage gap | `test/` only | (approved task) |
| 3 | **Issue 29** — vendor the 11 Phosphor glyphs, drop the dependency | `lib/` + `pubspec` + assets | Option B |
| 4 | **T2** — drop the unused `cupertino_icons` dependency | `pubspec` only | (approved task) |

Nothing else is approved. All four specs are complete in §3–§6.

**Specs are decisions, not suggestions.** Every code point, family name, and path below is deliberate.

**If something turns out to be impossible, STOP and file it** in `ongoing_general_errors.md` with options and a `Your selection: _____` line. **A blocker is a filing event, not a licence to re-choose.** Last pass an agent hit a genuine blocker, diagnosed it correctly, then silently substituted a different option — right call technically, but a decision that was the user's got made without them. Issue 29 exists only because that happened.

**Line numbers are anchors measured August 6, 2026** and drift as you edit — re-grep rather than trusting them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge`. No raw hex, no ad-hoc `Duration`, no one-off `TextStyle`.
3. **Every animation needs an `AppMotion.reduce(context)` path.**
4. **Text scale clamped 1.0–1.3** (`main.dart:81–88`). Layouts must survive 1.3.
5. **Touch targets ≥ 48 dp** (M4).
6. **None of these four items touches `functions/` or `firestore.rules`.** If you are editing either, you have left the spec — STOP.
7. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — measured August 6, 2026

**This is the regression bar.** Reproduce before changing anything.

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** |
| Client tests | `flutter test` | **60/60 pass** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **28/28** (last run Aug 5; no `functions/` change since) |
| iOS compile | `flutter build ios --simulator --debug` | succeeded Aug 5 |

### ⚠️ Three traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, never bare `flutter analyze`. The bare form reports ~678 errors, all inside `build/{ios,macos}/SourcePackages/` — vendored plugin source dropped by Swift Package Manager. Not project code, gitignored, not yours to fix.
2. **Analyze ≠ compile.** `flutter analyze` does **not** analyse dependency source. It reported **0 errors** with a package installed that could not build. Only `flutter test` or `flutter build` surfaces that. `dart pub add --dry-run` resolving proves nothing either. **Issue 29 changes a dependency — your acceptance check must be a command that compiles and renders, not one that resolves.**
3. **Working directory persists** between Bash calls. `cd functions && npm run build` leaves you in `functions/`; the next `grep lib/...` then fails with "No such file or directory". Use absolute paths or `npm --prefix functions run build`.

---

## 2. Execution order

| # | Item | Position rationale |
|---|---|---|
| 1 | **Issue 30** | Changes behaviour that T1 must then assert. Doing it first means T1's Family-Friendly case is written **once**, against final behaviour, instead of being written to today's behaviour and immediately flipped. Its pinning test ships in this commit. |
| 2 | **T1** | Test-only. Closes the remaining coverage gap on already-correct behaviour. |
| 3 | **Issue 29** | Largest and most error-prone: touches the dependency, the asset bundle, and the icon table. Doing it after T1 means the House Rules panel is fully test-covered before the icon system is rebuilt under it. |
| 4 | **T2** | Same asset-size territory as Issue 29 and verified by the same release-build inspection, so that workflow is already in hand. Kept as its own commit so each font removal has an attributable size delta. |

---

## 3. Issue 30 — Hide `Family-Friendly Decks Only` from non-hosts (Option A)

**What this means for the user:** a non-host currently sees a greyed "Family-Friendly Decks Only" toggle inside the "HOUSE RULES" card, which implies the host has set a content filter for the whole table. That is untrue — it is a per-device filter and each player's copy is independent. Non-hosts should see only settings that genuinely describe the shared game.

### The gap
`_familyFriendlyOnly` is a client-local `bool` at `lobby_screen.dart:43`, mutated with `setState`, **never sent to the server** — no `updateLobbySettings` call, no `GameState` field. Its only effect is filtering `availableDecks` at `:345–353`, which feeds the host's `DeckCarousel`.

It is currently rendered **inside** the `IgnorePointer(ignoring: !isHost)` block that wraps the two genuine house rules, so non-hosts see it at 0.5 opacity. No functional harm — they cannot toggle it, so the `selectedDeckId` display desync that originally motivated this ruling cannot occur — but it misrepresents a device preference as a table rule.

### Implementation

Move the `Family-Friendly Decks Only` `Material` → `SwitchListTile` block **out of** the `IgnorePointer` subtree and render it only for the host.

Locate it by content, not line number: the `Material(color: Colors.transparent, child: SwitchListTile(title: const Text('Family-Friendly Decks Only'), …))` currently sitting as the last child inside the `IgnorePointer` → `Opacity` → `Column`.

- Remove it from that `Column`.
- Re-insert it **after** the `IgnorePointer` block closes, wrapped as `if (isHost) …`.
- It keeps `value: _familyFriendlyOnly` and its existing `onChanged` with `setState` — **do not** route it through `updateLobbySettings`. It is deliberately client-local; making it a synced rule was Issue 30 Option C and was **not** selected.
- Leave the two genuine house rules (`Forgery Rounds`, `Disable Game Timers`) inside the `IgnorePointer` exactly as they are.
- The `if (!isHost)` caption block stays where it is, after everything.

Resulting order inside the card: title → `IgnorePointer`(rounds, timers) → `if (isHost)` Family-Friendly → `if (!isHost)` caption.

### Validation

Add this case to the House Rules test file (in T1 it gets renamed; if you do Issue 30 first, add it to the current `test/house_rules_dialog_test.dart` and let T1 carry it through the rename).

```dart
testWidgets('Family-Friendly Decks Only is host-only', (tester) async {
  await setupRoomAndPump(tester, isHost: false);
  expect(find.text('Family-Friendly Decks Only'), findsNothing);
});

testWidgets('Family-Friendly Decks Only is present for the host', (tester) async {
  await setupRoomAndPump(tester, isHost: true);
  expect(find.text('Family-Friendly Decks Only'), findsOneWidget);
  // The two genuine house rules must still render for BOTH roles -- this is the
  // over-reach guard. A fix that hid the whole card from non-hosts would pass
  // the assertion above while destroying Issue 27.
});

testWidgets('genuine house rules remain visible to non-hosts', (tester) async {
  await setupRoomAndPump(tester, isHost: false);
  expect(find.text('HOUSE RULES'), findsOneWidget);
  expect(find.text('Forgery Rounds:'), findsOneWidget);
  expect(find.text('Disable Game Timers'), findsOneWidget);
});
```

**The falsifying assertion is `findsNothing` for the non-host** — it fails against current code, where the control renders greyed. **The third test is the over-reach guard and is not optional:** the naive way to make the first test pass is to hide the whole card from non-hosts, which would silently undo Issue 27's entire point.

`setupRoomAndPump(WidgetTester tester, {required bool isHost, int sabotageAnswersCount, bool isTimerDisabled})` is at `test/house_rules_dialog_test.dart:25`. Note it takes `tester` **positionally** and performs the pump itself — do not write your own.

Prove falsifiability per §7, then run the full §1 battery. Expect **63/63**.

### Blast radius
`lib/screens/lobby_screen.dart` (the panel only) and the House Rules test file. Nothing else. `_familyFriendlyOnly`'s declaration at `:43` and its use at `:345–353` are unchanged.

---

## 4. Task T1 — Close the Issue 27 test-coverage gap (test-only)

**What this means for the user:** nothing visible. Issue 27's behaviour is correct and verified; two of its specified regression tests were never written, so parts of it are protected by nothing.

### The gap
Two cases from the Issue 27 spec are still missing after Issue 30 lands:
- **AppBar `IconButton`-count assertion** — nothing prevents a future change reintroducing a second House Rules entry point, which *was* the entire defect.
- **360×640 non-host overflow guard** — the explicitly-flagged over-reach check. **Verified manually on August 6 and it passes** (`exception=NONE`), so this is a coverage gap, not a bug. Making the panel visible to non-hosts made their Parlor the tallest layout case, and nothing in CI protects it.

**Test-only. Do not change `lib/`.**

### Implementation

**Step 1 — rename the file.** `test/house_rules_dialog_test.dart` → **`test/house_rules_panel_test.dart`** via `git mv` so history follows. There is no dialog any more; the name misleads.

**Step 2 — add two cases.**

**Case A — exactly one House Rules surface.**
```dart
await setupRoomAndPump(tester, isHost: true);
expect(
  find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton)),
  findsOneWidget,                       // sound toggle only
);
expect(find.text('HOUSE RULES'), findsOneWidget);
```

**Case B — non-host Parlor fits 360×640.** The tallest layout case.
```dart
tester.view.physicalSize = const Size(360, 640);
tester.view.devicePixelRatio = 1.0;
addTearDown(() {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
});
await setupRoomAndPump(tester, isHost: false);
expect(tester.takeException(), isNull);   // catches RenderFlex overflow
```
Add a second variant at `TextScaler.linear(1.3)`. `setupRoomAndPump` hardcodes `MediaQueryData(accessibleNavigation: true)` with no `textScaler`, so extend it with an optional `double textScale = 1.0` parameter — preferred, since it keeps one pump path — and default it to `1.0` so existing cases are unaffected.

### Validation

These guard already-correct behaviour, so the §7 "observe it fail" procedure does not apply — **there is nothing broken to fail against.** Prove they are not vacuous the other way: temporarily break what each one guards, confirm failure, revert.

| Case | Temporary break that must make it fail |
|---|---|
| A | Add a second dummy `IconButton` to the Parlor `AppBar` `actions:` |
| B | Add `const SizedBox(height: 400)` inside the House Rules card |

Revert each immediately; finish with `git status --short` clean. **Record in the commit body that you did this and what each broken run reported** — otherwise nobody can tell a real guard from a vacuous one.

Then the full §1 battery. Expect **≥ 65/65**.

### Blast radius
`test/house_rules_dialog_test.dart` → `test/house_rules_panel_test.dart`, contents only. Nothing in `lib/`.

---

## 5. Issue 29 — Vendor the 11 Phosphor glyphs, drop the dependency (Option B)

**What this means for the user:** a smaller download, and one less third-party package in a shipping app. The icons look exactly the same — if any icon changes appearance, something is wrong.

### The gap
`pubspec.yaml:50` carries `phosphoricons_flutter: ^1.0.0`, a single-maintainer package. Only **11 glyphs** at **one weight** are used, but the package declares **all six** weights in its `flutter: fonts:` block (`Phosphor-Light.ttf` 524K, plus Bold 484K, Duotone 555K, Fill 439K, Thin 523K, Regular 477K ≈ **3.0 MB** of declared font assets).

Do **not** attempt the upstream `phosphor_flutter` package — it cannot compile here (`final class IconData`); see §9 and `design_ui_direction.md` §8.

**Do not substitute a different icon library either.** Four alternatives were surveyed on August 6 and all were rejected on evidence:

| Package | Compiles? | Font files | Verdict |
|---|---|---|---|
| `lucide_icons_flutter` 3.1.15 | ✅ safe | 13 | Worse — more unused weights than Phosphor, same failure mode |
| `material_symbols_icons` 4.2960.0 | ✅ safe | 6 | Same failure mode, and Material is precisely the "stock UI tell" `design_ui_direction.md` §8 was written to escape |
| `hugeicons` 1.1.7 | ✅ safe | 0 | Different rendering model; no metric advantage |
| `iconsax_flutter` 1.0.1 | ✅ safe | 1 | Only one that avoids the multi-weight problem, but a rounded modern set — would mean re-choosing and re-verifying all 11 glyphs against the Victorian aesthetic |

None subclasses `IconData`, so none hits the `phosphor_flutter` wall — but **the size problem is not a Phosphor problem.** It is "a package declares N weights, the app uses 1, Flutter ships all N." Switching libraries either reproduces it or trades it for an aesthetic re-decision. Vendoring solves it exactly, keeps the glyphs already chosen and shipped, and removes the dependency entirely. That is why Option B was selected over Option A.

### Implementation

**Step 1 — vendor the font and its licence.**

Copy from the pub cache into the repo:
```
~/.pub-cache/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Light.ttf
   →  assets/fonts/phosphor/Phosphor-Light.ttf
```
Copy **only** `Phosphor-Light.ttf`. The other five weights are unused.

**Licence — a required deliverable, but a two-minute one.** The font is MIT, © Phosphor Icons (`github.com/phosphor-icons/core`). Copy the MIT text with that attribution to `assets/fonts/phosphor/LICENSE`. That is the entire obligation: MIT requires only that the notice travel with the file. The pub package was carrying it for us; vendoring moves it here. One ~1 KB text file, no ongoing cost, no restriction on how the app is licensed or shipped. (The wrapper package's own MIT © Lucas Zafret stops applying once its Dart code is gone — only the font travels.)

**Step 2 — declare the font family in `pubspec.yaml`.** Append to the existing `flutter: fonts:` list, alongside `CormorantGaramond` and `Lora`:
```yaml
    - family: PhosphorLight
      fonts:
        - asset: assets/fonts/phosphor/Phosphor-Light.ttf
```
The family name **must be exactly `PhosphorLight`** — it must match the `fontFamily` in the `IconData` constants below.

**Step 3 — replace the glyph table in `lib/theme/app_icons.dart`.** Replace the `_phosphorGlyphs` map (currently at `:42–54`, whose values are `PhosphorIconsLight.*`) with locally-declared `IconData`. These code points were read directly out of `phosphoricons_flutter 1.0.0`:

```dart
/// Vendored from Phosphor Icons (MIT) -- see assets/fonts/phosphor/LICENSE.
/// `fontPackage` is deliberately omitted: the font is a first-party asset now,
/// so Flutter must resolve the family from this app's own bundle.
const String _kPhosphorLight = 'PhosphorLight';

const Map<ThematicIconType, IconData> _phosphorGlyphs = {
  ThematicIconType.writing:  IconData(0xe9c0, fontFamily: _kPhosphorLight), // feather
  ThematicIconType.redraw:   IconData(0xe094, fontFamily: _kPhosphorLight), // arrowsClockwise
  ThematicIconType.timer:    IconData(0xe2b2, fontFamily: _kPhosphorLight), // hourglass
  ThematicIconType.secret:   IconData(0xe2d6, fontFamily: _kPhosphorLight), // key
  ThematicIconType.ledger:   IconData(0xe0e6, fontFamily: _kPhosphorLight), // bookOpen
  ThematicIconType.envelope: IconData(0xe214, fontFamily: _kPhosphorLight), // envelope
  ThematicIconType.observe:  IconData(0xe30c, fontFamily: _kPhosphorLight), // magnifyingGlass
  ThematicIconType.confirm:  IconData(0xe606, fontFamily: _kPhosphorLight), // sealCheck
  ThematicIconType.sound:    IconData(0xe5e8, fontFamily: _kPhosphorLight), // bellRinging
  ThematicIconType.mute:     IconData(0xe0d4, fontFamily: _kPhosphorLight), // bellSlash
  ThematicIconType.host:     IconData(0xe638, fontFamily: _kPhosphorLight), // lamp
};
```

**Three things that will silently break this if you change them:**
- **Drop `fontPackage`.** The originals carry `fontPackage: 'phosphoricons_flutter'`. Keeping it makes Flutter look for the font inside a package that no longer exists → every icon renders as a blank box.
- **Keep the map `const`.** Flutter's `--tree-shake-icons` (on by default for release builds) only subsets fonts when `IconData` is const and statically analysable. A non-const map silently disables tree-shaking and can fail the release build outright.
- **Keep the trailing comments.** The code points are opaque; `// feather` is the only thing telling the next reader what `0xe9c0` is.

**Step 4 — remove the dependency and its imports.**
```bash
flutter pub remove phosphoricons_flutter
```
Then delete the import at `lib/theme/app_icons.dart:2` and at `test/thematic_icon_test.dart:4`. Confirm:
```bash
grep -rn "phosphoricons_flutter\|PhosphorIconsLight" lib test pubspec.yaml
```
Must return nothing.

**Step 5 — update `test/thematic_icon_test.dart`.** It currently asserts `expect(icon.icon, PhosphorIconsLight.feather)`, a symbol that no longer exists. Replace with assertions on the vendored identity:
```dart
expect(icon.icon!.codePoint, 0xe9c0);
expect(icon.icon!.fontFamily, 'PhosphorLight');
expect(icon.icon!.fontPackage, isNull);   // proves it is first-party now
```
`fontPackage, isNull` is the falsifying assertion for this whole item — today it is `'phosphoricons_flutter'`.

### Validation

**⚠️ A wrong code point renders a blank box and NO automated test catches it.** `codePoint` assertions prove the table matches this spec; they cannot prove the glyph is the intended picture. Both layers are required.

**Layer 1 — automated.**
```bash
flutter analyze lib test && flutter test
```
Expect **0 errors** and the same count as after T1 (**≥ 65**); this item adds no tests, it rewrites assertions.

**Layer 2 — visual, mandatory.** Build and run on the iPhone 17 simulator, then confirm **each of the 11** renders as a real glyph and not a tofu box (`􀀀`/hollow rectangle). They appear in these places:

| Glyph | Where to look |
|---|---|
| `writing` (quill) | Entry form, name field prefix |
| `redraw` (circular arrows) | Parlor House Rules — *only if still used after Issue 27* |
| `timer` (hourglass) | Parlor House Rules, Disable Game Timers row |
| `secret` (key) | Entry form, room-code field prefix |
| `ledger` (open book) | Entry form, JOIN ROOM row |
| `sound` / `mute` (bell / bell-slash) | Parlor AppBar — toggle it to see both |
| `observe`, `confirm`, `envelope`, `host` | Grep their call sites: `grep -rn "ThematicIconType.observe\|confirm\|envelope\|host" lib` |

Any glyph that renders as a box means its code point is wrong — **report it, do not guess a replacement.**

**Layer 3 — confirm the size change against a measured baseline.**

The baseline was **measured on August 6, 2026**, not estimated — a release build was run and the shipped bundle inspected:

| Shipped font | Size in bundle | Note |
|---|---|---|
| `Phosphor-Light.ttf` | **8 KB** | tree-shaken down from 524 KB — only the 11 used glyphs survive |
| `Phosphor-Thin.ttf` | 524 KB | **full size, zero glyphs used** |
| `Phosphor-Duotone.ttf` | 556 KB | full size, unused |
| `Phosphor-Bold.ttf` | 484 KB | full size, unused |
| `Phosphor.ttf` (Regular) | 480 KB | full size, unused |
| `Phosphor-Fill.ttf` | 440 KB | full size, unused |

**`Runner.app` total: 46.7 MB. Dead font weight: 2.43 MB.**

This is the mechanism, and it is the whole justification for this item: **`--tree-shake-icons` subsets fonts that have used code points, but it does not remove font families with none.** Light shrank 524 KB → 8 KB, proving tree-shaking works; the other five shipped whole because nothing references them. Vendoring only `Phosphor-Light.ttf` drops those five entirely and the vendored copy still tree-shakes to ~8 KB, because the replacement table in Step 3 is `const`.

**Expected outcome: `Runner.app` ≈ 44.3 MB, a ~2.43 MB / ~5% reduction.** Verify:
```bash
flutter build ios --release --no-codesign
du -sh build/ios/iphoneos/Runner.app
find build/ios/iphoneos/Runner.app -iname "Phosphor*.ttf"   # must list exactly ONE file
```
The `find` is the real check — a single subsetted `Phosphor-Light.ttf` and nothing else. Record the before (46.7 MB) and after numbers in the commit body and the Resolved entry. **If the reduction is materially different from 2.43 MB, say so rather than restating this figure** — that is the Issue 24 lesson (estimated 275 dp, actual 593).

### Blast radius
- **New:** `assets/fonts/phosphor/Phosphor-Light.ttf`, `assets/fonts/phosphor/LICENSE`.
- `pubspec.yaml` — dependency removed, font family added. `pubspec.lock`.
- `lib/theme/app_icons.dart` — import `:2`, glyph map `:42–54`.
- `test/thematic_icon_test.dart` — import `:4` and the glyph assertions.
- `docs/design_ui_direction.md` §8 — the SHIPPED STATE block documents the dependency and the `final class IconData` constraint. **Update it**: the constraint stays true and still explains why upstream was never viable, but the app no longer depends on either package. Say what it depends on now.
- **`.gitignore` check:** confirm `assets/` is not ignored and the `.ttf` is actually tracked — `git check-ignore -v assets/fonts/phosphor/Phosphor-Light.ttf` must print nothing, and the file must appear in `git status`. A silently-ignored font is a blank-box crash on every other machine.

---

## 6. Task T2 — Drop the unused `cupertino_icons` dependency

**What this means for the user:** a slightly smaller download. Nothing visible changes — if any icon changes or turns into a blank box, stop and revert.

### The gap
`pubspec.yaml:37` declares `cupertino_icons: ^1.0.2`, a leftover from the Flutter project template. It is **unused**: the August 6 survey found zero references to `CupertinoIcons`, zero imports of `package:flutter/cupertino.dart`, and zero `Cupertino*` widgets anywhere in `lib/` or `test/`.

It nevertheless ships. Confirmed by inspecting the release bundle:
```
252 KB  Frameworks/App.framework/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf
```
Full size, not subsetted — the same mechanism described in §5: `--tree-shake-icons` subsets font families that have used code points and ships families with none intact. **252 KB of a 46.7 MB `Runner.app`.**

Note this is separate from `MaterialIcons-Regular.otf`, which ships at **4 KB** — tree-shaken, because Material icons *are* used (Flutter's own widgets reference them). Do not touch that one.

### Implementation

**Step 1 — re-verify before removing. Do not take the survey above on trust.** A "no X exists" claim that was never re-grepped is exactly what produced Issue 27:
```bash
grep -rn "CupertinoIcons\|package:flutter/cupertino.dart" lib test
grep -rnoE "Cupertino[A-Za-z]+" lib test | sort -u
```
Both must return nothing. **If either returns a hit, STOP** — the dependency is live and this task is void. File that finding rather than proceeding.

**Step 2 — remove it.**
```bash
flutter pub remove cupertino_icons
```
Also delete the two orphaned template comment lines immediately above it in `pubspec.yaml` ("The following adds the Cupertino Icons font…" / "Use with the CupertinoIcons class…"), which describe a dependency that no longer exists.

### Validation

**Layer 1 — automated.**
```bash
flutter analyze lib test && flutter test
```
Expect **0 errors** and no change in test count.

**Layer 2 — the font is actually gone.** This is the falsifying check:
```bash
flutter build ios --release --no-codesign
find build/ios/iphoneos/Runner.app -iname "CupertinoIcons.ttf"   # must return NOTHING
du -sh build/ios/iphoneos/Runner.app
```
Record the size before and after. Expect roughly **−252 KB**. If Issue 29 has already landed, the baseline for this step is *its* post-change number, not 46.7 MB — measure, do not subtract on paper.

**Layer 3 — visual smoke test.** Run on the iPhone 17 simulator and walk one full game loop (create room → DEBUG bots → craft → vote → reveal → game over). You are looking for a blank box anywhere an icon should be. Flutter falls back silently on a missing font, so a live Cupertino glyph that the greps missed would appear as tofu rather than an error. If you see one, revert and file it.

### Ongoing constraint
If a future change introduces any Cupertino widget or `CupertinoIcons` glyph, **this dependency must come back** — the SDK's `CupertinoIcons` class ships in `package:flutter/cupertino.dart`, but the *font that backs it* comes from this package. Recorded in §11.

### Blast radius
`pubspec.yaml`, `pubspec.lock`. Nothing in `lib/` or `test/`.

---

## 7. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.**
```bash
cp lib/screens/lobby_screen.dart /tmp/CURRENT.dart
git show HEAD:lib/screens/lobby_screen.dart > lib/screens/lobby_screen.dart
flutter test test/<file>.dart      # must FAIL
cp /tmp/CURRENT.dart lib/screens/lobby_screen.dart
git status --short                 # must be clean
```
This is how Issues 24 and 26 were confirmed real (`Actual: <593.0>`, `Actual: <334.0>`). **Record the observed failure output in the Resolved entry.**

**For a regression test over already-correct behaviour** (T1): nothing exists to fail against, so temporarily break what the test guards and confirm it fails.

**For anything a test cannot see** (Issue 29 glyph identity): a mandatory manual pass, itemised — see §5 Layer 2.

Prefer assertions on **counts, ranges, geometry and state transitions** over "it looks right". Pair every fix assertion with an **over-reach guard** — the first thing dropped under time pressure, and the thing dropped last pass.

---

## 8. `.gitignore` maintenance

**Decision rule.** (1) Secret, or identifies a developer's machine/account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.** Generated-and-reproducible (`build/`, `.dart_tool/`, `Pods/`, `functions/lib/`, `functions/node_modules/`) → ignore.

**Relevant to Issue 29:** the vendored `.ttf` and its `LICENSE` must be **committed**. Verify with `git check-ignore -v assets/fonts/phosphor/Phosphor-Light.ttf` (must print nothing) and confirm the file appears in `git status`.

**Trap: `.swiftpm/` does not match `swiftpm/`.** The real paths are `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` and `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` — no leading dot. Those are SPM lockfiles in `xcshareddata` and should be **committed**. Do not add a `swiftpm/` ignore rule.

**Rules that must never be removed:**

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA as a Flutter asset. |
| `**/google-services.json` | Android Firebase config. |
| `**/GoogleService-Info.plist` | iOS Firebase config — required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Source of the phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Adding a rule:** place it in the commented section it belongs to, then verify — `git check-ignore -v <path>` must print `.gitignore:<line>:<rule>	<path>`. No output means the pattern is wrong. If already tracked, the rule does nothing until `git rm --cached <path>`; if it held a secret, rotate it. Finish with `git status --porcelain | grep "^??"` returning nothing.

---

## 9. Already delivered — do NOT rework

**Issues 23–28, independently verified August 5–6, 2026:**
- **Issue 23** — hybrid icons: 11 functional glyphs render from a Phosphor font, 6 avatar sigils stay bespoke `CustomPainter`s. Fork at `app_icons.dart:33`/`:42`; no call site changed. *(Issue 29 changes where the font comes from, not the architecture.)*
- **Issue 24** — entry form fits 360×640. **Proven:** pre-fix overflow `593.0` dp → now `0.0`.
- **Issue 25** — house rules off the entry form; `createRoom` defaults to `sabotageAnswersCount: 2`. **The entry-form offload must survive** — Issue 24's fit depends on those controls being absent.
- **Issue 26** — roster sheet header drag/tap. **Proven:** pre-fix header drag moved the sheet `0` px (stuck at `334.0`) → now responds.
- **Issue 27** — House Rules consolidated into one inline Parlor panel; dialog deleted; AppBar down to one action; chips 1–5 in a `Wrap`; non-hosts see it read-only. Verified: no `HouseRulesDialog` references remain, and a non-host tap records **no** write.
- **Issue 28** — the upstream `phosphor_flutter` package **cannot compile here**: `flutter/lib/src/widgets/icon_data.dart:23` declares `final class IconData` (SDK 3.44.6) and the package does `class PhosphorIconData extends IconData`. Proven empirically. **Do not attempt it again**, including after Issue 29.

**Everything through July 16:** server-authoritative backend · gameplay P1–P6, P8, P10 · heuristic duplicate-answer check · E7 sound · UI/UX U0–U8 + UF · mobile-first M1–M5 + MF1 · character pass V1–V5.

**App identity and release plumbing — do not revert:**
- Bundle ID **`com.whylabs.gaslight`** everywhere; Android `MainActivity.kt` in the matching Kotlin package (drift crashes at launch).
- Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368`.
- iOS deployment target **15.0** in all three configs and `ios/Podfile` — the Firebase SDK floor.
- `functions/package.json` engines: Node **22**. `ITSAppUsesNonExemptEncryption = false` in `ios/Runner/Info.plist`.
- `ios/Runner/GoogleService-Info.plist` **required on disk** to build but **gitignored** — fresh clones must download it.
- `.env` ships inside the IPA, so **`USE_EMULATOR` must be `false`** in any tester build. Use `flutter run --dart-define=USE_EMULATOR=true` locally.

---

## 10. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field, not a bottom bar — deliberate keyboard exception (M5).
- **Vote's CONFIRM is bottom-anchored via `Expanded`+`SafeArea`.**
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **Entry-form logo shrinks via `SizedBox(height: 60)` + `FittedBox`**, not `Transform.scale` — the latter does not change layout size.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale.** Hits the measured 0 dp scroll extent at 360×640.
- **House Rules non-host gating uses `IgnorePointer(ignoring: !isHost)` + `Opacity(0.5)`**, not per-control `onChanged: null`. Equivalent for blocking input; the server rejects non-host writes regardless. Consequence: `SwitchListTile.onChanged` stays non-null, so the switch renders enabled-but-dimmed rather than greyed.
- **The Forgery Rounds chip row uses `Wrap(spacing: 6)`** to fit five chips at 360 dp.
- **House Rules caption reads `Only the host can modify house rules.`** — shorter than the originally specified two-sentence copy. Settled; do not re-expand.

---

## 11. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through Cloud Functions callables; `firestore.rules` denies client room writes. Transactions read-before-write always; `advancePhaseInternal` never reads.
- **Portrait-locked on phones**, iPad rotation retained.
- **Text scale clamped 1.0–1.3** (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart` (Decision 2).
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.** Call sites must not reference the glyph table or font family directly.
- **"Forgery Rounds" maps to `sabotageAnswersCount`** (forgeries per card). Renaming user-visible copy is a product decision.
- **`_familyFriendlyOnly` is client-local and never synced.** Issue 30 Option C would have changed this and was **not** selected — do not route it through `updateLobbySettings`.
- **`cupertino_icons` is deliberately absent after T2.** The SDK's `CupertinoIcons` class lives in `package:flutter/cupertino.dart`, but the font backing it comes from that package. If any Cupertino widget or glyph is ever introduced, **the dependency must be restored** or the glyph renders as a blank box with no error. Do not re-add it speculatively.

---

## 12. Where the contracts live

| What | Where |
|---|---|
| Engineering history, all issues & selections | `docs/ongoing_general_errors.md` |
| How to run / playtest (emulator + TestFlight) | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` — `design_ui_direction.md` §8 carries the **SHIPPED STATE** block for the hybrid icon system and the `final class IconData` constraint. **Issue 29 must update it.** |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 13. Feedback loop — what earlier specs got wrong

Each is a spec failure, not an implementation failure. Read before writing any new spec.

- **Resolution is not compilation.** Issue 28's spec verified `phosphor_flutter` resolved via `dart pub add --dry-run` and concluded it would work. It cannot compile — `IconData` is `final`. `flutter analyze` also reported 0 errors with the broken package installed. **Name a compiling command as the acceptance check for any dependency change.**
- **A blocker is a filing event, not a licence to re-choose.** Facing the above, the implementer switched options and self-recorded it. Right technically; wrong process — THE LOOP step (4) exists for exactly this.
- **A "no X exists" claim must be grepped across the whole feature.** Issue 25 asserted no settings home existed after checking `main.dart` and the entry form, but never the Parlor body — where one already lived. That produced Issue 27.
- **Layout overflow must be measured, not estimated.** Issue 24 estimated ~275 dp; the harness measured **593 dp**. Issue 29 §5 Layer 3 applies this directly: measure the app-size change, do not claim it.
- **A ruling is only as durable as the test that pins it.** The Issue 27 spec ruled Family-Friendly host-only and named a test for it. The ruling was not followed *and* the test was not written, so nothing caught it — hence Issue 30. **State a ruling and pin it in the same breath.**
- **Over-reach guards are the first thing dropped.** The 360×640 non-host check was flagged as most likely to be skipped, and was skipped. It passed on manual check — luck, not process. T1 closes it, and §3 adds one specifically against the naive "hide the whole card" fix.
- **Some correctness is invisible to tests.** A wrong icon code point renders a blank box that every assertion passes. Where that is true, say so and require an itemised manual pass — §5 Layer 2.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §7. For a fix, observe the test fail against the broken state.
    For a regression test, break the guarded thing and observe the failure.
    For anything tests cannot see, do the itemised manual pass.
    Then the full §1 battery.
(4) BLOCKED, or the spec turns out to be impossible? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
    Do NOT substitute a different option on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including observed
    failure output and measured numbers. Sync any design doc whose behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **Issue 30:** Family-Friendly moved out of the `IgnorePointer` block and wrapped in `if (isHost)`; still client-local (no `updateLobbySettings`); three tests added including the over-reach guard that genuine house rules still render for non-hosts; the `findsNothing` assertion was **observed to fail** against pre-change code.
- [ ] **T1:** file renamed via `git mv` to `test/house_rules_panel_test.dart`; AppBar-count and 360×640 non-host cases added at scale 1.0 and 1.3; each proven non-vacuous by temporarily breaking what it guards, with the observed failures recorded in the commit body.
- [ ] **Issue 29:** `Phosphor-Light.ttf` + `LICENSE` vendored under `assets/fonts/phosphor/` and **tracked by git**; `PhosphorLight` family declared in `pubspec.yaml`; glyph map rewritten as `const IconData` with `fontPackage` omitted; `grep -rn "phosphoricons_flutter\|PhosphorIconsLight" lib test pubspec.yaml` returns nothing; `fontPackage, isNull` assertion added.
- [ ] **T2:** the two greps in §6 Step 1 were **re-run** and returned nothing before removing anything; `cupertino_icons` removed from `pubspec.yaml` along with its orphaned template comments; `find build/ios/iphoneos/Runner.app -iname "CupertinoIcons.ttf"` returns nothing; `MaterialIcons-Regular.otf` still present at ~4 KB.
- [ ] **All 11 glyphs visually confirmed on the simulator** — none renders as a blank box. A full game loop (create → bots → craft → vote → reveal → game over) was walked after T2 with no tofu anywhere.
- [ ] **App-size delta measured** before and after Issue 29 (`du -sh build/ios/iphoneos/Runner.app`), both numbers recorded in the commit body and the Resolved entry.
- [ ] `docs/design_ui_direction.md` §8 SHIPPED STATE updated: the `final class IconData` constraint stays, but the app now vendors the font rather than depending on either package.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 65** · `npm --prefix functions run build` clean · `npm --prefix functions test` **28/28** · `flutter build ios --simulator --debug` succeeds.
- [ ] Both issues (29, 30) moved to Resolved in `ongoing_general_errors.md`; T1 and T2 recorded there as completed tasks.
- [ ] `git status --porcelain | grep "^??"` returns nothing (§8).
- [ ] Four commits, one per item.
- [ ] This guide rewritten to **Queue Complete**, or to the next approved queue.

**When all four are done and this guide is rewritten: the queue is empty. Do not invent work, and do not choose for the user.** The only legitimate triggers are (a) a filled-in `Your selection:` line in `ongoing_general_errors.md`, (b) a regression against the §1 baseline on a fresh checkout, or (c) an explicit user request. Store-readiness chores — app icons, store listing, privacy manifest, release signing — are user-driven.
