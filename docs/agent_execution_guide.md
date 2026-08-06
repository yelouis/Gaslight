# Agent Execution Guide — One Approved Task + Two Awaiting Selection (August 6, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**Current state:** Issues 23–28 are implemented and independently verified (§7). The August 6 verification pass produced exactly three follow-ups:

| What | Status | Where |
|---|---|---|
| **Task T1** — close the Issue 27 test-coverage gap | ✅ **APPROVED — start here** | §3 |
| **Issue 29** — icon dependency: your Option A was impossible | ⛔ `Your selection: _____` blank | `ongoing_general_errors.md` |
| **Issue 30** — `Family-Friendly Decks Only` shown to non-hosts | ⛔ `Your selection: _____` blank | `ongoing_general_errors.md` |

**Do T1. Do not start Issues 29 or 30** — both have empty selection lines and are the user's decisions. Check those lines first: if still blank after T1, report and stop.

**Specs are decisions, not suggestions.** If a value is impossible, keep the intent, deviate minimally, and say so in the commit body. **If the design cannot work, STOP and file it** in `ongoing_general_errors.md` with options and a `Your selection: _____` line. This matters — last pass an agent hit a genuine blocker on Issue 28, correctly diagnosed it, then silently substituted a different option instead of filing it. The technical call was right; the process left the user out of a decision that was theirs. **A blocker is a filing event, not a licence to re-choose.**

**Line numbers are anchors measured August 6, 2026.** They drift as you edit — re-grep rather than trusting them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge`. No raw hex, no ad-hoc `Duration`, no one-off `TextStyle`.
3. **Every animation needs an `AppMotion.reduce(context)` path.**
4. **Text scale clamped 1.0–1.3** (`main.dart:81–88`). Layouts must survive 1.3.
5. **Touch targets ≥ 48 dp** (M4).
6. **T1 touches only `test/`.** If you are editing `lib/`, `functions/`, or `firestore.rules` for T1, you have left the spec — STOP.
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
2. **Analyze ≠ compile.** `flutter analyze` does **not** analyse dependency source. It reported **0 errors** with a package installed that could not build. Only `flutter test` or `flutter build` surfaces a broken dependency. Likewise `dart pub add --dry-run` resolving proves nothing about compilation. **When a task involves a dependency, the acceptance check must be a command that compiles it.**
3. **Working directory persists** between Bash calls. `cd functions && npm run build` leaves you in `functions/`, and the next `grep lib/...` fails with "No such file or directory". Use absolute paths or `npm --prefix functions run build`.

---

## 2. Execution order

**T1 only.** Issues 29 and 30 are blocked on selection. If a selection lands, implement that option and nothing else.

---

## 3. TASK T1 — Close the Issue 27 test-coverage gap ✅ APPROVED

**What this means for the user:** nothing visible. Issue 27's behaviour is correct and verified; three of the six specified regression tests were never written, so parts of it are protected by nothing.

### The gap
`test/house_rules_dialog_test.dart` covers four of the six cases the Issue 27 spec required. Missing:

- **AppBar `IconButton`-count assertion** — nothing prevents a future change from reintroducing a second House Rules entry point, which was the entire defect.
- **`Family-Friendly Decks Only` role visibility** — currently unpinned in either direction. See the ordering note below.
- **360×640 non-host overflow guard** — the explicitly-flagged over-reach check. **Verified manually on August 6 and it passes** (`exception=NONE`), so this is a coverage gap, not a bug. Making the panel visible to non-hosts made their Parlor the tallest layout case, and nothing in CI protects it.

**This is test-only work. Do not change `lib/`.** The behaviour is correct as shipped.

### Implementation

**Step 1 — rename the file.** `test/house_rules_dialog_test.dart` → **`test/house_rules_panel_test.dart`**. There is no dialog any more; the name misleads. Use `git mv` so history follows.

**Step 2 — add three cases** to the existing group, reusing the helper `setupRoomAndPump(WidgetTester tester, {required bool isHost, int sabotageAnswersCount, bool isTimerDisabled})` at `:25`. Note its exact name and that it takes `tester` **positionally** — it both seats the room in `FakeFirestore` and pumps `LobbyScreen`; do not write your own pump.

**Case A — exactly one House Rules surface.**
```dart
await setupRoomAndPump(tester, isHost: true);
expect(
  find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton)),
  findsOneWidget,                       // sound toggle only
);
expect(find.text('HOUSE RULES'), findsOneWidget);
```

**Case B — `Family-Friendly Decks Only` role visibility.** ⚠️ **Ordering — read before writing this one.** Issue 30 asks the user whether this control should be visible to non-hosts at all. **Assert only current behaviour** (visible to both roles, non-interactive for non-hosts) so the suite is honest today, and add a comment naming Issue 30 as the reason it may flip:
```dart
// Pins CURRENT behaviour. Issue 30 may change this to host-only -- if that
// option is selected, this expectation flips to findsNothing for non-hosts.
await setupRoomAndPump(tester, isHost: false);
expect(find.text('Family-Friendly Decks Only'), findsOneWidget);
```
Do **not** assert the host-only behaviour the Issue 27 spec originally ruled — that ruling is what Issue 30 is re-opening. Writing it now would make the suite fail against shipped code.

**Case C — non-host Parlor fits 360×640.** The tallest layout case.
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
Add a second variant at `TextScaler.linear(1.3)`. `setupRoomAndPump` hardcodes `MediaQueryData(accessibleNavigation: true)` with no `textScaler`, so for the 1.3 case either extend the helper with an optional `double textScale = 1.0` parameter (preferred — keeps one pump path) or pump inline. If you extend it, keep the default at `1.0` so the existing four cases are unaffected.

### Validation

These are regression tests for already-correct behaviour, so the §5 "prove it fails first" procedure does **not** apply — there is nothing broken to fail against. Prove they are not vacuous a different way: **temporarily break the thing each one guards, confirm the test fails, then revert.**

| Case | Temporary break that must make it fail |
|---|---|
| A | Add a second dummy `IconButton` to the Parlor `AppBar` `actions:` |
| B | Wrap `Family-Friendly Decks Only` in `if (isHost)` |
| C | Add `const SizedBox(height: 400)` inside the House Rules card |

Revert each break immediately; finish with `git status --short` clean. Record in the commit body that you did this and what each broken run reported.

Then the full §1 battery. Expect **63/63** (60 + 3; more if you split the 1.3 variant).

### Blast radius
`test/house_rules_dialog_test.dart` → `test/house_rules_panel_test.dart`, contents only. Nothing in `lib/`.

---

## 4. Blocked items — do not start

**Issue 29 — icon dependency.** You selected Option A on Issue 28 (switch to `phosphor_flutter: ^2.1.0`). It is **impossible**: `IconData` is a `final class` in Flutter 3.44.6 (`flutter/lib/src/widgets/icon_data.dart:23`) and `phosphor_flutter` extends it, so it cannot compile. Proven empirically August 6 by performing the swap; the tree was restored. The current `phosphoricons_flutter: ^1.0.0` is a principled workaround, not an accident — see the SDK-constraint block in `design_ui_direction.md` §7. Issue 29 asks whether to ratify it or vendor the glyphs instead. **Do not attempt `phosphor_flutter` again.**

**Issue 30 — `Family-Friendly Decks Only` visibility.** It is a client-local `bool` (`lobby_screen.dart:43`) that never reaches the server and only filters the host's `DeckCarousel`, yet non-hosts now see it greyed inside a card titled "HOUSE RULES". Options: hide from non-hosts / move to a "Your Device" section / promote to a real synced rule. **Option C would touch `functions/` and require the emulator suite** — check the constraint list before starting if it is selected.

---

## 5. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.**
```bash
cp lib/screens/lobby_screen.dart /tmp/CURRENT.dart
git show HEAD:lib/screens/lobby_screen.dart > lib/screens/lobby_screen.dart
flutter test test/<file>.dart      # must FAIL
cp /tmp/CURRENT.dart lib/screens/lobby_screen.dart
git status --short                 # must be clean
```
This is how Issues 24 and 26 were confirmed real (`Actual: <593.0>`, `Actual: <334.0>`). **Record the observed failure output in the Resolved entry.**

**For a regression test over already-correct behaviour** (T1): there is nothing to fail against, so instead temporarily break what the test guards and confirm it fails — see §3.

Prefer assertions on **counts, ranges, geometry and state transitions** over "it looks right". Pair every fix assertion with an **over-reach guard** — the thing most likely to be skipped, and the thing that was skipped last pass.

---

## 6. `.gitignore` maintenance

**Decision rule.** (1) Secret, or identifies a developer's machine/account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.** Generated-and-reproducible (`build/`, `.dart_tool/`, `Pods/`, `functions/lib/`, `functions/node_modules/`) → ignore.

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

## 7. Already delivered — do NOT rework

**Issues 23–28, independently verified August 5–6, 2026:**
- **Issue 23** — hybrid icons: 11 functional glyphs route to Phosphor Light, 6 avatar sigils stay bespoke. Fork at `app_icons.dart:33`/`:42`; no call site changed.
- **Issue 24** — entry form fits 360×640. **Proven:** pre-fix overflow `593.0` dp → now `0.0`.
- **Issue 25** — house rules off the entry form; `createRoom` defaults to `sabotageAnswersCount: 2`. **The entry-form offload must survive any future change** — Issue 24's fit depends on those controls being absent.
- **Issue 26** — roster sheet header drag/tap. **Proven:** pre-fix header drag moved the sheet `0` px (stuck at `334.0`) → now responds.
- **Issue 27** — House Rules consolidated into one inline Parlor panel; dialog deleted; AppBar down to one action; chips 1–5 in a `Wrap`; non-hosts see it read-only. Verified: no `HouseRulesDialog` references remain, and a non-host tap records **no** write.
- **Issue 28** — icon dependency retained as `phosphoricons_flutter: ^1.0.0` for a proven SDK reason. See §4 and `design_ui_direction.md` §7.

**Everything through July 16:** server-authoritative backend · gameplay P1–P6, P8, P10 · heuristic duplicate-answer check · E7 sound · UI/UX U0–U8 + UF · mobile-first M1–M5 + MF1 · character pass V1–V5.

**App identity and release plumbing — do not revert:**
- Bundle ID **`com.whylabs.gaslight`** everywhere; Android `MainActivity.kt` in the matching Kotlin package (drift crashes at launch).
- Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368`.
- iOS deployment target **15.0** in all three configs and `ios/Podfile` — the Firebase SDK floor.
- `functions/package.json` engines: Node **22**. `ITSAppUsesNonExemptEncryption = false` in `ios/Runner/Info.plist`.
- `ios/Runner/GoogleService-Info.plist` **required on disk** to build but **gitignored** — fresh clones must download it.
- `.env` ships inside the IPA, so **`USE_EMULATOR` must be `false`** in any tester build. Use `flutter run --dart-define=USE_EMULATOR=true` locally.

---

## 8. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field, not a bottom bar — deliberate keyboard exception (M5).
- **Vote's CONFIRM is bottom-anchored via `Expanded`+`SafeArea`.**
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **Entry-form logo shrinks via `SizedBox(height: 60)` + `FittedBox`**, not `Transform.scale` — the latter does not change layout size.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale.** Hits the measured target of 0 dp scroll extent at 360×640.
- **House Rules non-host gating uses `IgnorePointer(ignoring: !isHost)` + `Opacity(0.5)`**, not per-control `onChanged: null`. Equivalent for blocking input; the server rejects non-host writes regardless. Consequence: `SwitchListTile.onChanged` stays non-null, so the switch renders enabled-but-dimmed rather than Flutter's greyed disabled state.
- **The Forgery Rounds chip row uses `Wrap(spacing: 6)`** to fit five chips at 360 dp.
- **`phosphoricons_flutter: ^1.0.0` over `phosphor_flutter`** — forced by `final class IconData`. See §4.

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through Cloud Functions callables; `firestore.rules` denies client room writes. Transactions read-before-write always; `advancePhaseInternal` never reads.
- **Portrait-locked on phones**, iPad rotation retained.
- **Text scale clamped 1.0–1.3** (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart` (Decision 2).
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.** Call sites must not import the icon package directly — the sole exception is `test/thematic_icon_test.dart`, where the direct import is the package-identity assertion.
- **"Forgery Rounds" / "Number of Rounds" maps to `sabotageAnswersCount`** (forgeries per card). Renaming user-visible copy is a product decision.
- **`_familyFriendlyOnly` is client-local**, never synced — until and unless Issue 30 Option C is selected.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Engineering history, all issues & selections | `docs/ongoing_general_errors.md` |
| How to run / playtest (emulator + TestFlight) | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` — `design_ui_direction.md` §7 carries the **SHIPPED STATE** block for the hybrid icon system *and* the `final class IconData` SDK constraint |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 11. Feedback loop — what earlier specs got wrong

Each is a spec failure, not an implementation failure. Read before writing any new spec.

- **Resolution is not compilation.** Issue 28's spec verified `phosphor_flutter` resolved via `dart pub add --dry-run` and concluded it would work. It cannot compile — `IconData` is `final`. `flutter analyze` also reported 0 errors with the broken package installed, because it does not analyse dependency source. **Name a compiling command as the acceptance check for any dependency change.**
- **A blocker is a filing event, not a licence to re-choose.** Facing the above, the implementer switched to a different option and self-recorded it. Right call technically; wrong process — the user never got to choose between the remaining options. THE LOOP step (4) exists for exactly this.
- **A "no X exists" claim must be grepped across the whole feature.** Issue 25 asserted no settings home existed after checking `main.dart` and the entry form, but never the Parlor body — where one already lived. That produced Issue 27. `grep -rn "Disable Game Timers" lib` would have caught it.
- **Layout overflow must be measured, not estimated.** Issue 24 estimated ~275 dp; the harness measured **593 dp**.
- **A ruling is only as durable as the test that pins it.** The Issue 27 spec ruled `Family-Friendly Decks Only` host-only and named a test case for it. The ruling was not followed *and* the test was not written, so nothing caught it — now Issue 30. **State a ruling and pin it in the same breath; an unpinned ruling is a comment.**
- **Over-reach guards are the first thing dropped.** The 360×640 non-host layout check was flagged as most likely to be skipped, and was skipped. It passes on manual check — but that was luck, not process. T1 closes it.
- **What went right, keep doing:** every falsifying assertion named in a spec has held up under adversarial re-testing. Issue 26's test drags the *header text*, not the grid.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §5. For a fix, observe the test fail against the broken state.
    For a regression test, break the guarded thing and observe the failure.
    Then the full §1 battery.
(4) BLOCKED, or the spec turns out to be impossible? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
    Do NOT substitute a different option on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including observed
    failure output. Sync any design doc whose described behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **T1:** file renamed to `test/house_rules_panel_test.dart` via `git mv`; three cases added (AppBar count, Family-Friendly current-behaviour with the Issue 30 comment, 360×640 non-host at scale 1.0 and 1.3).
- [ ] Each new case was proven non-vacuous by temporarily breaking what it guards; the observed failures are recorded in the commit body; the tree is clean afterwards.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 63** · `npm --prefix functions run build` clean · `npm --prefix functions test` **28/28** · `flutter build ios --simulator --debug` succeeds.
- [ ] No `lib/` changes in the T1 commit.
- [ ] `git status --porcelain | grep "^??"` returns nothing (§6).
- [ ] This guide rewritten to reflect the new state.

**After T1, if Issues 29 and 30 still have blank selection lines: report that and stop. Do not invent work, and do not choose for the user.** The only legitimate triggers are (a) a filled-in `Your selection:` line, (b) a regression against the §1 baseline on a fresh checkout, or (c) an explicit user request. Store-readiness chores — app icons, store listing, privacy manifest, release signing — are user-driven.
