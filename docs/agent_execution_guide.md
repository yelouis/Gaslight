# Agent Execution Guide — Active Build: Issues 28 → 27 (August 6, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**What is approved:** exactly two items, both **Option A**, selected by the user in `docs/ongoing_general_errors.md`:

- **Issue 28** — replace the substituted icon package with the upstream one. Trivial, independent.
- **Issue 27** — delete `HouseRulesDialog`; keep and extend the pre-existing inline Parlor panel.

Nothing else is approved. Both specs are in §3 and §4 and are complete — implement those, not your own interpretation.

**Specs are decisions, not suggestions.** Every number, range, token, and copy string below is deliberate. If a value is impossible, keep the intent, deviate minimally, and say so in the commit body. If the design cannot work, **STOP** — file it in `ongoing_general_errors.md` with options and a `Your selection: _____` line. Do not improvise.

**Line numbers below are anchors measured August 6, 2026.** They shift as you edit. Each one is quoted with surrounding code so you can locate it after drift — re-grep rather than trusting the number.

---

## Standing constraints — apply to every change

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge` in `lib/theme/`. No raw hex, no ad-hoc `Duration`, no one-off `TextStyle`.
3. **Every animation needs an `AppMotion.reduce(context)` path.**
4. **Text scale is clamped 1.0–1.3** (`main.dart:81–88`). Layouts must survive 1.3.
5. **Touch targets ≥ 48 dp** (M4).
6. **Neither item touches `functions/` or `firestore.rules`.** If you are editing either, you have left the spec — STOP.
7. **One item = one commit**, Conventional Commits per `.agents/skills/commit_message_guidelines/SKILL.md`, WHY in the body.

---

## 1. Verified baseline — measured August 6, 2026

**This is the regression bar.** Reproduce it before changing anything.

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors**, 24 warnings, 252 infos |
| Client tests | `flutter test` | **60/60 pass** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **28/28** (last run Aug 5; no `functions/` change has landed since) |
| iOS compile | `flutter build ios --simulator --debug` | succeeded Aug 5 |

### ⚠️ Analyzer trap — run `flutter analyze lib test`, never bare `flutter analyze`
Bare `flutter analyze` reports **~1053 issues including ~678 errors**, every one inside `build/ios/SourcePackages/` or `build/macos/SourcePackages/` — vendored plugin source dropped there by Swift Package Manager during an iOS/macOS build. Not project code, gitignored, not yours to fix. If you see 678 errors, you ran the wrong command.

### ⚠️ Working-directory trap
The Bash working directory persists between commands. `cd functions && npm run build` leaves you in `functions/`, and the next `grep lib/...` fails with "No such file or directory". Use absolute paths or `npm --prefix functions run build`.

---

## 2. Execution order

| # | Item | Position rationale |
|---|---|---|
| 1 | **Issue 28** — upstream icon package | Two lines and independent. Settle the dependency *before* the larger refactor, so if a glyph name drifted between the two packages you find out against a 3-test file rather than midway through Issue 27. |
| 2 | **Issue 27** — consolidate House Rules | Larger: deletes a widget and a dialog test, restructures the Parlor panel, changes non-host visibility. Nothing in it depends on 28, but doing it second keeps the diffs separable. |

---

## 3. Issue 28 — Switch to the upstream Phosphor package (Option A)

**What this means for the user:** nothing visible. This is a supply-chain correction: the app currently depends on a one-maintainer `1.0.0` repackaging instead of the package published by the icon set's own organisation.

### The gap
`pubspec.yaml:50` declares `phosphoricons_flutter: ^1.0.0` (`github.com/lucaszafret/phosphoricons_flutter`, self-described as "Based on phosphor-icons/core v2.0.8"). The Issue 23 spec named `phosphor_flutter: ^2.1.0`, from the phosphor-icons organisation, and had verified it resolves cleanly against this lockfile.

Already verified, so do not re-investigate: both expose `PhosphorIconsLight.<name>` with all 11 required glyphs, and both ship the identical six `.ttf` weights (~3.0 MB). **There is no size or behaviour difference.** This is purely provenance.

### Implementation

**Step 1 — swap the dependency.**
```bash
flutter pub remove phosphoricons_flutter
flutter pub add phosphor_flutter
```
Expect `phosphor_flutter 2.1.0` in `pubspec.lock`. If it resolves to something other than 2.x, **STOP and report** — the spec was written against 2.1.0.

**Step 2 — two import lines. These are the only source edits.**

| File | Current (anchor) | Change to |
|---|---|---|
| `lib/theme/app_icons.dart:2` | `import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';` | `import 'package:phosphor_flutter/phosphor_flutter.dart';` |
| `test/thematic_icon_test.dart:4` | `import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';` | `import 'package:phosphor_flutter/phosphor_flutter.dart';` |

**Do not touch the `PhosphorIconsLight.*` references** in the `_phosphorGlyphs` map at `app_icons.dart:42–54`. Both packages expose that class with identical member names; the map is correct as written.

**Step 3 — confirm nothing else references the old package.**
```bash
grep -rn "phosphoricons_flutter" lib test pubspec.yaml
```
Must return nothing.

### Validation

**The test file is itself the package-identity assertion.** `test/thematic_icon_test.dart` imports the icon package *directly* rather than relying on it transitively through `app_icons.dart`. That is deliberate and must stay that way: if someone later substitutes the package again, this test fails to compile, loudly. Do not "simplify" that import away.

Existing assertions that now double as the migration check:
```dart
expect(icon.icon, PhosphorIconsLight.feather);   // catches a drifted glyph name
expect(icon.size, 20.0);
```

Run:
```bash
flutter analyze lib test && flutter test
```
Expect **0 errors** and **60/60** — the count must not change; this item adds no tests.

**Manual check:** run on the iPhone 17 simulator and confirm the entry-form quill, the rounds icon, and the AppBar bell render identically to before. Any glyph that silently changed shape means a name collision between the two packages — report it rather than picking a replacement yourself.

### Blast radius
`pubspec.yaml`, `pubspec.lock`, `lib/theme/app_icons.dart:2`, `test/thematic_icon_test.dart:4`. Nothing else.

---

## 4. Issue 27 — Consolidate House Rules into the inline Parlor panel (Option A)

**What this means for the user:** the Parlor currently has two panels both titled "HOUSE RULES" — one in the page body, one behind a ledger icon in the AppBar — controlling the same settings but offering different round ranges. Pick 5 in the dialog and the body's chip row shows nothing selected. After this change there is one panel, it offers the full range, and non-hosts can finally see the rules they are playing under.

### The gap
Two host-only surfaces control the same two fields:
1. **Inline panel** — `CrimsonShadowCard` inside `if (isHost) ...[` at `lobby_screen.dart:450–534`, titled `'HOUSE RULES'`, containing `Forgery Rounds:` `ChoiceChip`s over **[1, 2, 3, 4]** (`:475`), a `Disable Game Timers` `SwitchListTile` (`:499–513`), and a `Family-Friendly Decks Only` `SwitchListTile` (`:514–530`).
2. **`HouseRulesDialog`** — opened from an `IconButton` in the Parlor `AppBar` at `:391–395`, titled `'HOUSE RULES'`, with a `Number of Rounds` dropdown over **[1, 2, 3, 4, 5]**.

Both write `sabotageAnswersCount` / `isTimerDisabled` through `updateLobbySettings`, so state cannot diverge — but the ranges do.

### Implementation

#### Step 1 — Delete the dialog

- Delete the file `lib/widgets/house_rules_dialog.dart`.
- Remove the import at `lobby_screen.dart:19`: `import '../widgets/house_rules_dialog.dart';`
- Remove the ledger `IconButton` from the AppBar `actions:` list at `lobby_screen.dart:391–395` — the block whose `onPressed` is `() => HouseRulesDialog.show(context)`. **Leave the sound-toggle `IconButton` that follows it.** The AppBar must end with exactly one action.

#### Step 2 — Make the inline panel visible to everyone, editable by the host

Currently `if (isHost) ...[` at `:450` wraps **both** the `CrimsonShadowCard` **and** the `DEBUG: ADD 9 BOTS` button at `:535–542`. Restructure so the card renders unconditionally while the debug button stays host-only:

```dart
// House rules are visible to everyone so non-hosts can see the rules they are
// playing under; only the host may change them. The server enforces this too --
// updateLobbySettings rejects non-host callers -- so the disabled controls
// below are an affordance, not the security boundary.
CrimsonShadowCard(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ... 'HOUSE RULES' title unchanged ...
      // ... Forgery Rounds row, chips widened to 1..5, onSelected host-gated ...
      // ... Disable Game Timers, onChanged host-gated ...
      if (isHost) /* Family-Friendly Decks Only -- see ruling below */,
      if (!isHost) /* caption -- see copy below */,
    ],
  ),
),
if (isHost && players.length < 10) /* DEBUG: ADD 9 BOTS, unchanged */,
```

Keep the title `Text` exactly as it is (`CormorantGaramond`, 18, bold, `theme.colorScheme.secondary`, `letterSpacing: 2`) and the existing `SizedBox` rhythm (12 after the title, 8 between controls).

#### Step 3 — Widen the chip range to 1–5

At `lobby_screen.dart:475`, change `[1, 2, 3, 4].map((r) {` to `[1, 2, 3, 4, 5].map((r) {`.

This matches the range the deleted dialog exposed and is the reason the two surfaces disagreed. `rounds` is read at `:360` as `gs.gameState?.sabotageAnswersCount ?? 2` and needs no change.

**Watch the width.** Five chips plus the `'Forgery Rounds:'` label now share one `Row` with `MainAxisAlignment.spaceBetween` at 360 dp. If the fifth chip overflows, wrap the chip `Row` in `Flexible` + `Wrap` rather than shrinking the chips below the 48 dp minimum (standing constraint 5). The text-scale-1.3 test in §5 will catch it either way.

#### Step 4 — Gate the two shared controls

- **ChoiceChip** (`:487`): `onSelected: isHost ? (selected) { if (selected) gs.updateLobbySettings(sabotageAnswersCount: r); } : null`
- **Disable Game Timers `SwitchListTile`** (`:509`): `onChanged: isHost ? (val) => gs.updateLobbySettings(isTimerDisabled: val) : null`
- Wrap **each** of those two controls in `Opacity(opacity: isHost ? 1.0 : 0.5, child: ...)`, matching the visual treatment the deleted dialog established.

#### Step 5 — Non-host caption

Render only when `!isHost`, after the timer control, preceded by `const SizedBox(height: 8)`. Copy **verbatim**, including the full stop:

> `Only the host may set the house rules. Changes appear here as they are made.`

Style: `fontFamily: 'Lora'`, `fontStyle: FontStyle.italic`, `fontSize: 12`, `color: AppColors.ivory.withOpacity(0.6)`.

#### Step 6 — RULING: `Family-Friendly Decks Only` stays host-only

**Render it only when `isHost`.** This is a deliberate ruling, not an oversight — do not "fix" it by exposing it to non-hosts.

Rationale, verified in source: `_familyFriendlyOnly` is a **client-local `bool` field** (`lobby_screen.dart:43`) mutated with `setState` (`:525–527`). It is **never sent to the server** — it does not go through `updateLobbySettings` and has no `GameState` field. Its only effect is filtering the `availableDecks` list at `:345–353`, which feeds the host's `DeckCarousel`. Exposing it to a non-host would let them alter their own `selectedDeckId` *display* (via the `availableDecks.contains(...)` fallback at `:355–357`) without changing the actual game — a display-only desync for zero benefit, since non-hosts cannot select decks.

It sits inside a card titled "HOUSE RULES" while not actually being a shared house rule. That naming mismatch is real but **out of scope** — if it should become a synced lobby setting, that is a new issue with its own options, not a silent change here.

### Validation

Rename `test/house_rules_dialog_test.dart` → **`test/house_rules_panel_test.dart`** and rewrite it against the inline panel. **Do not delete it** — all four of its cases remain requirements.

Reuse its existing `setupRoom({required bool isHost, int sabotageAnswersCount, bool isTimerDisabled})` helper as-is (`house_rules_dialog_test.dart:25–64`) — it seats a host and a guest in `FakeFirestore`, wires `SharedPreferences`, and calls `tryRejoinSession()`. Only the pump target changes: pump `LobbyScreen` (which renders the Parlor once a room exists) instead of showing the dialog. Drop the `package:gaslight/widgets/house_rules_dialog.dart` import.

Required cases — the first two are the falsifying ones:

1. **Only one House Rules surface exists.** *Falsifies today:* the Parlor AppBar currently has **2** `IconButton`s.
   ```dart
   expect(
     find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton)),
     findsOneWidget,                       // sound toggle only
   );
   expect(find.text('HOUSE RULES'), findsOneWidget);
   ```
2. **The range reaches 5.** *Falsifies today:* the chip row stops at 4.
   ```dart
   expect(find.widgetWithText(ChoiceChip, '5'), findsOneWidget);
   ```
   Then tap it and assert `gameService.gameState?.sabotageAnswersCount == 5`.
3. **Non-hosts can see the panel but not edit it.** *Falsifies today:* non-hosts see no panel at all, so `find.text('HOUSE RULES')` currently returns nothing for them.
   ```dart
   await setupRoom(isHost: false);
   expect(find.text('HOUSE RULES'), findsOneWidget);
   expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
   expect(find.textContaining('Only the host may set the house rules'), findsOneWidget);
   ```
   Then tap the switch and assert `gameService.gameState?.isTimerDisabled` is **still `false`**. That "no write recorded" assertion is the one that proves gating — a test that only checks the caption renders would pass against a broken build.
4. **Family-Friendly stays host-only.** As a non-host, `expect(find.text('Family-Friendly Decks Only'), findsNothing);` As a host, `findsOneWidget`. This pins the Step 6 ruling so a later pass does not quietly reverse it.
5. **Values stream from Firestore, not local state.** `setupRoom(isHost: true, sabotageAnswersCount: 4)` then assert chip `'4'` is the selected one — falsifies an implementation that keeps its own `setState` copy.
6. **Over-reach guard — the Parlor still fits.** At 360×640 with a **non-host** (the newly-tallest case, since the panel is now visible to them):
   ```dart
   tester.view.physicalSize = const Size(360, 640);
   tester.view.devicePixelRatio = 1.0;
   addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
   // ... pump ...
   expect(tester.takeException(), isNull);   // catches RenderFlex overflow
   ```
   Repeat at `textScaler: TextScaler.linear(1.3)`. The Parlor body carries hand-tuned bottom padding `EdgeInsets.fromLTRB(24, 12, 24, 260)` at `lobby_screen.dart:408` to clear the roster sheet; making the panel visible to non-hosts makes their body taller, so this must be re-verified rather than assumed.

**Prove falsifiability before you claim success** — see §5. Cases 1, 2 and 3 must each be observed failing against the pre-change tree.

Then the full §1 battery. Expect **≥ 60** tests (the file is rewritten, not removed, and gains cases).

**Manual check (required, two devices):** run on the iPhone 17 simulator **and** macOS (`flutter run -d macos`). Create a room on one, join from the other. Confirm: the AppBar has only the sound icon; the host sees five chips and can change rules; the non-host sees the same panel greyed with the caption, updating live as the host changes it; the non-host does **not** see Family-Friendly Decks Only.

### Blast radius
- **Deleted:** `lib/widgets/house_rules_dialog.dart`.
- `lib/screens/lobby_screen.dart` — import `:19`; AppBar action `:391–395`; panel restructure `:450–544`; chip range `:475`; gating `:487`, `:509`.
- **Renamed and rewritten:** `test/house_rules_dialog_test.dart` → `test/house_rules_panel_test.dart`.
- Grep before starting: `grep -rn "HouseRulesDialog\|Forgery Rounds\|Disable Game Timers\|Family-Friendly" lib test`.
- `docs/design_ui_direction.md` — no change expected; its SHIPPED STATE block covers icons, not the lobby. Update it only if you alter icon behaviour.

---

## 5. Validation standard — non-negotiable

**Write validation that fails against the current broken state.** A test that passes before your change proves nothing. Name the falsifying assertion, then prove it:

```bash
cp lib/screens/lobby_screen.dart /tmp/CURRENT.dart
git show HEAD:lib/screens/lobby_screen.dart > lib/screens/lobby_screen.dart
flutter test test/house_rules_panel_test.dart      # must FAIL
cp /tmp/CURRENT.dart lib/screens/lobby_screen.dart
git status --short                                  # must be clean
```

This is exactly how Issues 24 and 26 were confirmed real on August 6 (`Actual: <593.0>` and `Actual: <334.0>`). **Record the observed failure output in the Resolved entry** — it is the evidence, and the next pass should not have to re-derive it.

Prefer assertions on **counts, ranges, geometry and state transitions** over "it looks right". Always pair a fix assertion with an **over-reach guard** — here, case 6 (the Parlor still fits for the now-taller non-host view).

---

## 6. `.gitignore` maintenance

**Decision rule.** (1) Is it a secret, or does it identify a developer's machine or account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.** Generated-and-reproducible (`build/`, `.dart_tool/`, `Pods/`, `functions/lib/`, `functions/node_modules/`) → ignore.

**Trap: `.swiftpm/` does not match `swiftpm/`.** The paths Xcode created are `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` and `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` — no leading dot. Those are SPM lockfiles in `xcshareddata` (the shared, non-per-user part of the project) and should be **committed**. Do not add a `swiftpm/` ignore rule.

**Rules that must never be removed:**

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA as a Flutter asset (§7). |
| `**/google-services.json` | Android Firebase config. |
| `**/GoogleService-Info.plist` | iOS Firebase config — required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Source of the phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Adding a rule:** put it in the commented section it belongs to, then verify it matches — `git check-ignore -v <path>` must print `.gitignore:<line>:<rule>	<path>`. No output means the pattern is wrong. If the file is already tracked the rule does nothing until `git rm --cached <path>`; if it held a secret, rotate it — it remains in history. Finish with `git status --porcelain | grep "^??"`, which should return nothing.

---

## 7. Already delivered — do NOT rework

**Issues 23–26 (August 5–6, 2026), independently verified:**
- **Issue 23** — hybrid icons: 11 functional glyphs route to Phosphor Light, 6 avatar sigils stay bespoke. Fork at `app_icons.dart:33`/`:42`; no call site changed. *(Package provenance is Issue 28, in flight.)*
- **Issue 24** — entry form fits 360×640. **Proven:** pre-fix overflow `593.0` dp → now `0.0`.
- **Issue 25** — house rules off the entry form; `createRoom` defaults to `sabotageAnswersCount: 2`. *(Duplicate surface is Issue 27, in flight.)* **The entry-form offload itself is correct and must survive Issue 27** — do not restore rules to the entry form; Issue 24's fit depends on their absence.
- **Issue 26** — roster sheet header drag/tap. **Proven:** pre-fix header drag moved the sheet `0` px (stuck at `334.0`) → now responds.

**Everything through the July 16 pass:** server-authoritative backend · gameplay P1–P6, P8, P10 · heuristic duplicate-answer check · E7 sound · UI/UX U0–U8 + UF · mobile-first M1–M5 + MF1 · character pass V1–V5.

**App identity and release plumbing — do not revert:**
- Bundle ID **`com.whylabs.gaslight`** everywhere; Android `MainActivity.kt` lives in the matching Kotlin package (drift crashes the app at launch).
- Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368`.
- iOS deployment target **15.0** in all three build configs and `ios/Podfile` — the Firebase SDK floor.
- `functions/package.json` engines: Node **22**. `ITSAppUsesNonExemptEncryption = false` in `ios/Runner/Info.plist`.
- `ios/Runner/GoogleService-Info.plist` is **required on disk** to build but **gitignored** — fresh clones must download it.
- `.env` ships inside the IPA, so **`USE_EMULATOR` must be `false`** in any tester build. Use `flutter run --dart-define=USE_EMULATOR=true` locally.

---

## 8. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field, not in a bottom bar — deliberate keyboard-interplay exception (M5).
- **Vote's CONFIRM is bottom-anchored via `Expanded`+`SafeArea`** rather than a literal bottom bar.
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **The entry-form logo shrinks via `SizedBox(height: 60)` + `FittedBox`**, not `Transform.scale` — `Transform.scale` does not change layout size, so `FittedBox` is the correct structure. Same intent, better mechanism.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale**, tighter than the original 12/16/20 spec. It hits the measured target (0 dp scroll extent at 360×640).

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through Cloud Functions callables; `firestore.rules` denies client room writes. Transactions read-before-write always; `advancePhaseInternal` never reads.
- **Portrait-locked on phones**, iPad rotation intentionally retained.
- **Text scale clamped 1.0–1.3** — recorded accessibility trade-off (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`. Pure synonyms passing is accepted (Decision 2).
- **The `_advancedStateKeys` / once-per-event guards** (reveal sounds, raven hops, seal stamps, ceremony sounds) survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.** Call sites must not import the icon package directly — the one exception is `test/thematic_icon_test.dart`, where the direct import is the package-identity assertion (§3).
- **The "Number of Rounds" / "Forgery Rounds" label maps to `sabotageAnswersCount`** (forgeries per card). Renaming user-visible copy is a product decision — do not do it unasked.
- **`_familyFriendlyOnly` is client-local and host-only** — see §4 Step 6.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Engineering history, all issues & selections | `docs/ongoing_general_errors.md` |
| How to run / playtest (emulator + TestFlight) | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` — `design_ui_direction.md` §7 carries a **SHIPPED STATE** block recording the hybrid icon system |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

This guide points at the design docs; it does not duplicate them.

---

## 11. Feedback loop — what earlier specs got wrong

Read before writing any new spec. Each is a spec failure, not an implementation failure.

- **A "no X exists" claim must be grepped across the whole feature.** Issue 25 asserted no settings home existed after checking `main.dart` routes and the entry form, but never grepped the Parlor body — where a "HOUSE RULES" panel had lived all along. The agent built exactly what was specified and produced the duplicate that is now Issue 27. `grep -rn "Disable Game Timers" lib` would have caught it in one command.
- **Layout overflow must be measured, not estimated.** Issue 24 estimated ~275 dp by summing the widget tree; the harness measured **593 dp**. Write the failing widget test first and read the real number off it.
- **Name the exact package and assert it in a test.** Issue 23 named `phosphor_flutter: ^2.1.0`; `phosphoricons_flutter: ^1.0.0` was installed instead, and nothing failed. The fix now in §3 is a direct import in the test file, so a future substitution breaks compilation.
- **State rulings on ambiguous sub-elements explicitly.** Issue 27's spec would have been ambiguous about `Family-Friendly Decks Only` had §4 Step 6 not ruled on it *and* pinned the ruling with test case 4. Anything left unstated gets invented.
- **What went right, keep doing:** every spec named its falsifying assertion, and all four held. Issue 26's test drags the *header text*, not the grid — dragging the grid would have passed pre-fix and proven nothing.

---

## THE LOOP — repeat per item, in the §2 order

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE: write the falsifying tests FIRST, observe them fail against the
    pre-change tree (§5), then implement until green. Then the full §1 battery.
(4) BLOCKED or the spec is wrong? STOP. File in ongoing_general_errors.md with
    options and a `Your selection: _____` line. Ask. Do not improvise.
(5) RECORD: move to Resolved (Problem / Solution / Validation), including the
    observed pre-fix failure output. Sync any design doc whose behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **Issue 28:** `phosphor_flutter ^2.1.0` in `pubspec.yaml`; both imports switched; `grep -rn "phosphoricons_flutter" lib test pubspec.yaml` returns nothing; test count still **60**.
- [ ] **Issue 27:** `house_rules_dialog.dart` deleted; AppBar has exactly one `IconButton`; chips run 1–5; non-hosts see the panel read-only with the caption; `Family-Friendly Decks Only` remains host-only.
- [ ] `test/house_rules_panel_test.dart` exists with all six cases; cases 1, 2 and 3 were **observed to fail** against the pre-change tree, and that output is recorded in the Resolved entry.
- [ ] The Parlor renders without overflow at 360×640 for a **non-host** at text scale 1.0 and 1.3.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 60** · `npm --prefix functions run build` clean · `npm --prefix functions test` **28/28** · `flutter build ios --simulator --debug` succeeds.
- [ ] Both issues moved to Resolved in `ongoing_general_errors.md`.
- [ ] `git status --porcelain | grep "^??"` returns nothing (§6).
- [ ] Two commits, one per item.
- [ ] This guide rewritten to **Queue Complete**, or to the next approved queue.

**When both items are done and this guide is rewritten: the queue is empty. Do not invent work.** The only legitimate triggers are (a) a filled-in `Your selection:` line in `ongoing_general_errors.md`, (b) a regression against the §1 baseline on a fresh checkout, or (c) an explicit user request. Store-readiness chores — app icons, store listing, privacy manifest, release signing — are user-driven; do not start them unsolicited.
