# Agent Execution Guide — Awaiting Selection: Issues 27–28 (August 6, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**Current state:** the Issues 23–26 queue is **implemented and independently verified** (see §1 and §7). Two new items — **Issues 27 and 28** — were opened by that verification pass and are filed in `docs/ongoing_general_errors.md` with options.

**⛔ Do not start Issues 27 or 28.** Both have an empty `Your selection: _____` line. They are the user's decisions to make, not yours. Check those lines first: if they are still blank, there is **no approved work in this queue** — report that and stop. If one is filled in, implement only that option, exactly as written, following THE LOOP.

**What NOT to touch:** anything in §7 (delivered), §8 (accepted equivalents), or §9 (intentional decisions).

**Specs are decisions, not suggestions.** Every number, token name, and copy string is deliberate. If a value is impossible, keep the intent, deviate minimally, and say so in the commit body. If the design itself cannot work, **STOP** — file it in `ongoing_general_errors.md` with options and a `Your selection: _____` line. Do not improvise.

---

## Standing constraints — apply to every change

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge` in `lib/theme/`. No raw hex, no ad-hoc `Duration`, no one-off `TextStyle`.
3. **Every animation needs an `AppMotion.reduce(context)` path** — jump to the end state instead of animating.
4. **Text scale is clamped 1.0–1.3** app-wide (`main.dart:81–88`). Layouts must survive 1.3.
5. **Touch targets ≥ 48 dp** (M4).
6. **Neither open issue touches `functions/` or `firestore.rules`.** If you are editing either, you have left the spec — STOP.
7. **One item = one commit**, Conventional Commits per `.agents/skills/commit_message_guidelines/SKILL.md`, WHY in the body.

---

## 1. Verified baseline — measured August 6, 2026

**This is the regression bar.** Reproduce it before changing anything.

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors**, 24 warnings, 252 infos |
| Client tests | `flutter test` | **60/60 pass** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **28/28** (last run August 5; untouched since — no `functions/` change has landed) |
| iOS compile | `flutter build ios --simulator --debug` | succeeded August 5 |

### ⚠️ Analyzer trap — run `flutter analyze lib test`, never bare `flutter analyze`

Bare `flutter analyze` reports **~1053 issues including ~678 errors**. Every one lives in `build/ios/SourcePackages/` or `build/macos/SourcePackages/` — vendored plugin source that Swift Package Manager drops into `build/` during an iOS/macOS build. It is not project code, it is gitignored, and it is not yours to fix. Scoping to `lib test` gives the true **0 errors**. If you see 678 errors, you ran the wrong command.

### ⚠️ Working-directory trap
The Bash working directory persists between commands. A `cd functions && npm run build` leaves you in `functions/`, and the next `grep lib/...` fails with "No such file or directory". Use absolute paths or `npm --prefix functions run build`.

---

## 2. Open queue — BOTH BLOCKED ON USER SELECTION

| Issue | Title | Status |
|---|---|---|
| **27** | Two competing "HOUSE RULES" panels in the Parlor | ⛔ `Your selection: _____` — blank |
| **28** | Icon dependency substituted for a third-party repackaging | ⛔ `Your selection: _____` — blank |

Full statements, evidence and options are in `docs/ongoing_general_errors.md`. Summaries only, so you can recognise them:

**Issue 27** — the Parlor renders two host-only UIs both titled "HOUSE RULES": a pre-existing `CrimsonShadowCard` at `lobby_screen.dart:450–520` (Forgery Rounds chips **[1–4]**, Disable Game Timers, Family-Friendly Decks Only) and the new `HouseRulesDialog` from the AppBar at `:393` (Number of Rounds dropdown **[1–5]**, Disable Game Timers). They share backing fields so state cannot diverge, but the **ranges disagree** — pick 5 in the dialog and the chip row shows nothing selected. Options A/B/C decide which surface survives.

**Issue 28** — `pubspec.yaml:50` carries `phosphoricons_flutter: ^1.0.0`, a third-party repackaging, where the spec named `phosphor_flutter: ^2.1.0` from the phosphor-icons org. Verified functionally equivalent and identical in size (both ship the same six ~3.0 MB font weights). The question is provenance for a shipping app. Options A/B/C.

**If both selection lines are still blank: stop here.** Do not pick for the user. Do not start unrelated work.

---

## 3. When a selection lands — how to implement it

1. Re-read the chosen option **and the other options you did not choose**, so you know what was deliberately rejected.
2. Grep for every affected symbol before editing. Issue 27 especially: `grep -rn "HouseRulesDialog\|Forgery Rounds\|Disable Game Timers\|Family-Friendly" lib test`.
3. **Write the falsifying test first and watch it fail.** See §5 — this is not optional here; it is the one habit that caught a spec error last pass.
4. Run the full §1 battery.
5. Move the issue to Resolved in `ongoing_general_errors.md` using the `bug_documentation_guidelines` format (**Problem** / **Solution** / **Validation**).
6. Update `docs/design_ui_direction.md` if the change alters the shipped icon or lobby contract — that file carries a **SHIPPED STATE** block for §7 that must stay accurate.
7. One Conventional Commit.

### Blast radius, pre-computed

**Issue 27, Option A** (delete dialog, keep inline panel): remove `lib/widgets/house_rules_dialog.dart`, the import at `lobby_screen.dart:19`, the AppBar action at `:393`; widen the chip row at `:450–520` to `[1,2,3,4,5]`; add non-host read-only treatment. **`test/house_rules_dialog_test.dart` must be rewritten against the inline panel, not deleted** — its four cases (host edits, non-host gating, Firestore stream sync, creation default of 2) are all still requirements. Re-check the Parlor bottom padding `fromLTRB(24, 12, 24, 260)` at `:408` still clears the roster sheet.

**Issue 27, Option B** (delete inline panel, keep dialog): strip `:450–520`; move `Family-Friendly Decks Only` into `HouseRulesDialog` or the setting is silently lost — it writes `selectedDeckId`-adjacent state and has no other home. Existing dialog tests stay valid; add one for the migrated setting.

**Issue 28, Option A** (switch to upstream): two lines — `pubspec.yaml:50` and the import at `lib/theme/app_icons.dart:2`. The `PhosphorIconsLight.*` references need no edit; both packages expose that class with the same glyph names. Run `flutter pub get`, then the battery. `test/thematic_icon_test.dart` asserts `icon.icon == PhosphorIconsLight.feather` and will catch any drift.

---

## 4. Feedback loop — what the last pass got wrong

Read this before writing any new spec. Each entry is a spec failure, not an implementation failure.

- **A "no X exists" claim must be grepped across the whole feature, not just the obvious file.** Issue 25's Status line asserted no settings home existed, having checked `main.dart` routes and the entry form. A host-only "HOUSE RULES" panel had been sitting in the Parlor body the whole time. The implementing agent built exactly what was specified and produced a duplicate. **Before claiming something is absent, grep for its user-visible strings** — `grep -rn "Disable Game Timers" lib` would have caught this in one command.
- **Layout overflow must be measured, not estimated.** Issue 24 estimated ~275 dp of overflow by summing the widget tree by hand. The harness measured **593 dp** — low by more than 2×. Options were costed against the wrong number. Write the failing widget test *first* and read the real figure off it.
- **Name the exact package, and expect the name to be substituted anyway.** Issue 23 named `phosphor_flutter: ^2.1.0` and recorded that it resolved cleanly; `phosphoricons_flutter: ^1.0.0` was installed instead. When a dependency is load-bearing, state the package **and** add a validation step that asserts it — a test importing the expected package fails loudly on substitution.
- **What went right, keep doing:** every spec named its falsifying assertion, and all four held up. The Issue 26 test drags the *header text* rather than the grid — dragging the grid would have passed pre-fix and proven nothing.

---

## 5. Validation standard — non-negotiable

**Write validation that fails against the current broken state.** A test that passes before your change proves nothing. State which assertion is the falsifying one, and prove it:

```bash
# Stash the fix, run the new test, confirm it FAILS, restore.
cp lib/screens/lobby_screen.dart /tmp/CURRENT.dart
git show <pre-fix-sha>:lib/screens/lobby_screen.dart > lib/screens/lobby_screen.dart
flutter test test/<your_new_test>.dart      # must FAIL
cp /tmp/CURRENT.dart lib/screens/lobby_screen.dart
git status --short                          # must be clean
```

This is exactly how Issues 24 and 26 were confirmed real on August 6 (`Actual: <593.0>` and `Actual: <334.0>` respectively). Record the observed failure output in the Resolved entry — it is the evidence, and a later pass should not have to re-derive it.

Prefer assertions on **counts, ordering, geometry and state transitions** over "it looks right". Always pair a fix assertion with an **over-reach guard**: Issue 26 asserts the sheet moves on a header drag *and* that the grid still scrolls independently at 10 players.

---

## 6. `.gitignore` maintenance

**Decision rule.** (1) Is it a secret, or does it identify a developer's machine or account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.** Generated-and-reproducible (`build/`, `.dart_tool/`, `Pods/`, `functions/lib/`, `functions/node_modules/`) → ignore.

**Trap: `.swiftpm/` does not match `swiftpm/`.** The real paths Xcode created are `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` and `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` — no leading dot. Those are SPM lockfiles in `xcshareddata` (explicitly the shared, non-per-user part of the project) and should be **committed**, not ignored. Do not "fix" this by adding a `swiftpm/` rule.

**Rules that must never be removed** — each guards a credential or a machine-specific path:

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA as a Flutter asset (§7). |
| `**/google-services.json` | Android Firebase config. |
| `**/GoogleService-Info.plist` | iOS Firebase config — required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Also the source of the phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Adding a rule:** put it in the commented section it belongs to, then **verify it matches** — `git check-ignore -v <path>` must print `.gitignore:<line>:<rule>	<path>`. No output means the pattern is wrong; a silently-matching-nothing rule is the most common `.gitignore` bug. If the file is already tracked the rule does nothing until `git rm --cached <path>`; if it held a secret, rotate it, because it remains in history. Finish with `git status --porcelain | grep "^??"` — on a healthy tree this returns nothing.

---

## 7. Already delivered — do NOT rework

**Issues 23–26 (August 5–6, 2026), all independently verified:**
- **Issue 23** — hybrid icons: 11 functional glyphs route to Phosphor Light, 6 avatar sigils stay bespoke. Fork at `app_icons.dart:33`/`:42`; no call site changed. *(Dependency provenance is open as Issue 28.)*
- **Issue 24** — entry form fits 360×640. **Proven:** pre-fix overflow `593.0` dp → now `0.0`.
- **Issue 25** — house rules off the entry form; `createRoom` defaults to `sabotageAnswersCount: 2`; `HouseRulesDialog` with host gating. *(Duplicate-surface residual is open as Issue 27.)*
- **Issue 26** — roster sheet header drag/tap. **Proven:** pre-fix header drag moved the sheet `0` px (stuck at `334.0`) → now responds.

**Everything through the July 16 pass:** server-authoritative backend · gameplay P1–P6, P8, P10 · heuristic duplicate-answer check · E7 sound · UI/UX program U0–U8 + UF · mobile-first M1–M5 + MF1 · character pass V1–V5.

**App identity and release plumbing — do not revert:**
- Bundle ID **`com.whylabs.gaslight`** everywhere; Android `MainActivity.kt` lives in the matching Kotlin package (drift here crashes the app at launch).
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
- **The entry-form logo shrinks via `SizedBox(height: 60)` + `FittedBox`**, not the `Transform.scale(0.7)` the Issue 24 spec suggested. The spec's own note warned that `Transform.scale` does not change layout size; `FittedBox` solves that correctly. Same intent, better structure — keep it.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale**, slightly tighter than the spec's 12/16/20. It achieves the measured target (0 dp scroll extent at 360×640) — keep it.

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through Cloud Functions callables; `firestore.rules` denies client room writes. Transactions read-before-write always; `advancePhaseInternal` never reads.
- **Portrait-locked on phones**, iPad rotation intentionally retained.
- **Text scale clamped 1.0–1.3** — a recorded accessibility trade-off (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`. Pure synonyms passing is accepted (Decision 2).
- **The `_advancedStateKeys` / once-per-event guards** (reveal sounds, raven hops, seal stamps, ceremony sounds) exist to survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.** Call sites must not import the icon package directly.
- **The "Number of Rounds" label maps to `sabotageAnswersCount`** (forgeries per card), which the README calls "forgery rounds". Renaming user-visible copy is a product decision — do not do it unasked.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Engineering history, all issues & selections | `docs/ongoing_general_errors.md` |
| How to run / playtest (emulator + TestFlight) | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` — note `design_ui_direction.md` §7 carries a **SHIPPED STATE** block recording the hybrid icon system |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

This guide points at the design docs; it does not duplicate them.

---

## THE LOOP — once a selection exists

```
(1) STUDY the selected option + the rejected ones + the design_*.md contract it touches.
(2) IMPLEMENT exactly as specified.
(3) VALIDATE: write the falsifying test FIRST, prove it fails against pre-fix code (§5),
    then implement until green. Then the full §1 battery.
(4) BLOCKED or the spec is wrong? STOP. File in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Ask. Do not improvise.
(5) RECORD: move to Resolved (Problem / Solution / Validation), including the observed
    pre-fix failure output. Sync any design doc whose described behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] The selected option for Issue 27 (and/or 28) is implemented exactly as written.
- [ ] A falsifying test exists and was **observed to fail** against pre-fix code; the failure output is recorded in the Resolved entry.
- [ ] An over-reach guard accompanies each fix assertion.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 60** · `npm --prefix functions run build` clean · `npm --prefix functions test` **28/28** · `flutter build ios --simulator --debug` succeeds.
- [ ] Issue moved to Resolved in `ongoing_general_errors.md`; `design_ui_direction.md` SHIPPED STATE block updated if the icon or lobby contract changed.
- [ ] `git status --porcelain | grep "^??"` returns nothing (§6).
- [ ] One commit per item.
- [ ] This guide rewritten to reflect the new state.

**If both selection lines in §2 are still blank, the correct action is to report that and stop.** Do not invent work. The only legitimate triggers are (a) a filled-in `Your selection:` line, (b) a regression against the §1 baseline on a fresh checkout, or (c) an explicit user request. Store-readiness chores — app icons, store listing, privacy manifest, release signing — are user-driven; do not start them unsolicited.
