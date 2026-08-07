# Agent Execution Guide — Awaiting Selection: Issues 31–32 (August 7, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**Two open issues, both BLOCKED on the user's decision.** Issues 1–30 and Tasks T1–T2 are all implemented and independently verified. A live 3-simulator playtest on August 7 surfaced two new defects, filed with options in `ongoing_general_errors.md`:

| Issue | What the user sees | Status |
|---|---|---|
| **31** | Changing any lobby setting silently wipes the others; START GAME then fails with `[firebase_functions/internal] INTERNAL` | ⛔ `Your selection: _____` blank |
| **32** | The raven mascot is invisible — drawn at **1.02:1** contrast against the background, where 1.00 is identical | ⛔ `Your selection: _____` blank |

**⛔ Do not start either one.** Both selection lines are blank; these are the user's decisions. Check them first — if still blank, report that and stop. **Issue 31 is a live production defect that makes the game unstartable after any settings change**, so if the user has not responded, say so plainly rather than quietly waiting.

The root causes are already fully diagnosed — see §1a. Do not re-investigate; go straight to implementing the selected option when one lands.

**A blocker is a filing event, not a licence to re-choose.** If a selected option turns out to be impossible, STOP and file that with fresh options. Do not substitute a different option on the user's behalf.

Do not invent other work. Do not refactor working, tested code for its own sake. Do not "fix" anything in §5, §6 or §7 — those lists exist because earlier passes kept undoing deliberate decisions.

---

## 1. What was delivered August 5–6, 2026

| Item | Outcome | Independently verified by |
|---|---|---|
| **Issue 30** — `Family-Friendly Decks Only` hidden from non-hosts | Moved outside `IgnorePointer`, wrapped in `if (isHost)`; still client-local | Test failed against the pre-change tree: `Expected: no matching candidates / Actual: Found 1 widget` |
| **T1** — Issue 27 test-coverage gap | Renamed to `house_rules_panel_test.dart`; AppBar-count and 360×640 non-host cases added at scale 1.0 and 1.3 | 9 cases present; suite 60 → 65 |
| **Issue 29** — Phosphor glyphs vendored | `Phosphor-Light.ttf` + MIT `LICENSE` in `assets/fonts/phosphor/`; dependency removed | Font `cmap` parsed directly — **11/11 code points map to real glyphs** in both the source and the shipped font |
| **T2** — `cupertino_icons` removed | Unused template leftover dropped | `CupertinoIcons.ttf` absent from the release bundle; `MaterialIcons-Regular.otf` still present at 4 KB |

**Measured size result: `Runner.app` 46.7 MB → 44.0 MB, i.e. 2.7 MB (5.8%) smaller.** Exactly one Phosphor font ships, subsetted 536 KB → **8 KB** — proving `--tree-shake-icons` still works on the vendored asset because the glyph map stayed `const`.

---

## 1a. Diagnosis already completed for Issues 31–32 — do not re-investigate

Both were traced to root cause on August 7. Options and full evidence are in `ongoing_general_errors.md`; this is the technical summary so whoever implements does not repeat the dig.

### Issue 31 — one defect, two symptoms

`lib/services/game_service.dart:361–368` sends **all three** lobby settings on every call, filling untouched ones with Dart `null`. `functions/src/index.ts:1006–1008` skips fields that are `undefined` — but a Dart `null` arrives as JSON `null`, and **`null !== undefined` is true**, so the nulls get written.

Two consequences, and the second is the reported crash:
1. `isTimerDisabled` → `null` → falsy → the toggle reads as off. Symmetric: changing rounds wipes the timer, changing the timer wipes the rounds.
2. `sabotageAnswersCount` → `null` → in `functions/src/rotation_engine.ts`, the guard at `:7` (`playerIds.length <= sabotageRounds`) evaluates `3 <= null` → false, so it does **not** throw; the loop at `:15` (`r <= null`) then runs zero times and returns `{}`. `startGame` reads `stringRotations["1"]` → `undefined` → Firestore rejects it. Production log:
   ```
   Cannot use "undefined" as a Firestore value (found in field "currentCardAssignments")
   ```
   The client surfaces only `[firebase_functions/internal] INTERNAL`.

**Whichever option is selected, the validation must include a test that sends an explicit `null`** — the existing 28/28 emulator suite calls the callable from TypeScript (`functions/test/game_e2e.spec.ts:643`) where omitted keys really are `undefined`, so it structurally cannot reproduce this. That gap is the point. A test asserting `updateLobbySettings` with a null field leaves the stored value unchanged is the falsifying assertion; it fails against today's backend.

If Option A or C is selected, the change touches `functions/` and **the emulator suite becomes a required gate**, plus a redeploy:
```bash
npm --prefix functions run build && npm --prefix functions test
npx firebase-tools deploy --only functions
```
No data migration is needed — rooms are created fresh per game.

### Issue 32 — a contrast problem, not a drawing problem

`lib/widgets/raven_mascot.dart` fills the body with `Color(0xFF171310)` at lines **293, 307, 323, 406**, on `AppColors.ground` `#14110E`. Measured contrast **1.02:1** (1.00 = identical). Only the brass beak and eye have real contrast, which is why the bird reads as two floating gold specks.

Measured reference values against the background: warm charcoal `#3E3428` **1.55:1** · brass `#C9A24B` **7.84:1** · ivory `#F5EEDB` **16.25:1**.

**Before touching this, know what it is:** a 485-line hand-animated widget with three animation controllers and five poses (`sleep`, `idle`, `hop`, `ruffle`, `fly`), used on five screens each passing a different pose — `lobby_screen.dart:424`, `phase2_craft.dart:304`, `phase3_vote.dart:382`, `phase4_reveal.dart:417`, `game_over_screen.dart:231`. Option A recolours it; Option B replaces it with the `bird` glyph already present in the vendored Phosphor font (no new dependency) and retires the animation. Option B therefore changes five call sites and deletes character work — it is not a like-for-like swap.

Validation for either option must assert **measured contrast**, not "looks better": compute the ratio of the body fill against `AppColors.ground` and assert it exceeds a chosen threshold. A screenshot cannot regress-test this, which is exactly how it shipped invisible.

---

## 2. Verified baseline — the regression bar

Measured on this tree, August 6, 2026. If a fresh checkout does not reproduce these, **triage that first** — do not build on a broken baseline.

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** (24 warnings, 252 infos) |
| Client tests | `flutter test` | **65/65 pass** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **28/28** (last run Aug 5; no `functions/` change has landed since) |
| iOS debug compile | `flutter build ios --simulator --debug` | succeeds |
| iOS release | `flutter build ios --release --no-codesign` | succeeds, `Runner.app` **44.0 MB** |

### ⚠️ Four traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, **never bare `flutter analyze`**. The bare form reports ~678 errors, every one inside `build/{ios,macos}/SourcePackages/` — vendored plugin source dropped there by Swift Package Manager during an iOS build. Not project code, gitignored, not yours to fix.
2. **Analyze ≠ compile.** `flutter analyze` does **not** analyse dependency source. It once reported 0 errors with a package installed that could not build at all. `dart pub add --dry-run` resolving proves nothing either. **Any dependency change must be accepted by a command that compiles — `flutter test` or `flutter build`.**
3. **Working directory persists** between Bash calls. `cd functions && npm run build` leaves you in `functions/`; the next `grep lib/...` then fails with "No such file or directory". Use absolute paths or `npm --prefix functions run build`.
4. **BSD `sed` does not support `\b`.** On macOS, `sed "s|§6\b|§7|"` silently matches nothing and still exits 0. Use `python3` for anything involving word boundaries, and verify the result rather than trusting the exit code.

---

## 3. If you were spawned to "continue the work"

**First check the `Your selection:` lines on Issues 31 and 32.** If both are still blank, there is no approved work — report that, and note that Issue 31 is a live defect blocking gameplay. These are the **only** legitimate triggers for action:

1. **A new user selection landed** — check `ongoing_general_errors.md` for a fresh `### Issue N` block with a filled-in `Your selection:` line. For Issues 31–32 the diagnosis is already done (§1a) — go straight to implementation. If it is UI or animation work, write a detailed design spec (exact dimensions, durations, curves, tokens, guards, validation) into this guide **first**, then implement via THE LOOP in §8.
2. **A baseline regression** — if §2 no longer passes on a fresh checkout, triage it, file it in `ongoing_general_errors.md` in `bug_documentation_guidelines` format with options, then fix per §8.
3. **Store-readiness chores**, and only if the user asks: app icons, splash, store listing assets, privacy manifest, release signing. User-driven — do not start them unsolicited.
4. **Nothing changed** — report the queue is complete and stop.

---

## 4. Release plumbing — current state, do not revert

- Bundle ID **`com.whylabs.gaslight`** on every platform. Android's `MainActivity.kt` lives in the matching Kotlin package — if that drifts, the manifest's `.MainActivity` fails to resolve and the app crashes at launch.
- Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368`. Anonymous auth enabled, Blaze plan, functions and rules deployed.
- iOS deployment target **15.0** in all three build configs and `ios/Podfile` — the Firebase SDK floor. Lowering it fails the build.
- `functions/package.json` engines: Node **22**. `ITSAppUsesNonExemptEncryption = false` in `ios/Runner/Info.plist`.
- `ios/Runner/GoogleService-Info.plist` is **required on disk** to build (it is wired into the Runner target's Resources phase) but is **gitignored** — a fresh clone must download it from the Firebase console, or the link step fails with `Build input file cannot be found`.
- `.env` ships **inside the IPA** as a Flutter asset, so **`USE_EMULATOR` must be `false`** in any build handed to a tester. Use `flutter run --dart-define=USE_EMULATOR=true` for local emulator work instead.

---

## 5. Accepted equivalents — do NOT "fix" back

Each differs from how a spec originally worded it, reaches the same outcome, and has been reviewed and kept.

- **Craft SUBMIT is in-flow** under the text field rather than in a bottom bar — a deliberate keyboard-interplay exception (M5).
- **Vote's CONFIRM is bottom-anchored via `Expanded`+`SafeArea`** rather than a literal bottom bar.
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **The entry-form logo shrinks via `SizedBox(height: 60)` + `FittedBox`**, not `Transform.scale` — the latter does not change layout size, so `FittedBox` is the correct mechanism.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale**, tighter than the originally specified 12/16/20. It hits the measured target of 0 dp scroll extent at 360×640.
- **House Rules non-host gating uses `IgnorePointer(ignoring: !isHost)` + `Opacity(0.5)`**, not per-control `onChanged: null`. Equivalent for blocking input, and the server rejects non-host writes regardless. Consequence: `SwitchListTile.onChanged` stays non-null, so the switch renders enabled-but-dimmed rather than Flutter's greyed disabled state.
- **The Forgery Rounds chip row uses `Wrap(spacing: 6)`** to fit five chips at 360 dp.
- **The House Rules caption reads `Only the host can modify house rules.`** — shorter than the two-sentence copy originally specified. Settled; do not re-expand.

---

## 6. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through Cloud Functions callables; `firestore.rules` denies client room writes. Transactions read-before-write always; `advancePhaseInternal` never reads.
- **Portrait-locked on phones**, iPad rotation intentionally retained.
- **Text scale clamped 1.0–1.3** app-wide — a recorded accessibility trade-off (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`. Pure synonyms passing is the accepted trade-off (Decision 2).
- **The `_advancedStateKeys` / once-per-event guard patterns** (reveal sounds, raven hops, seal stamps, ceremony sounds) exist to survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.** Call sites must never reference the glyph table or the font family directly. The sole exception is `test/thematic_icon_test.dart`, whose direct import is the package-identity assertion.
- **The icon system is a hybrid:** 6 bespoke `CustomPainter` avatar sigils (`flame`, `moth`, `key`, `raven`, `moon`, `hourglass`) plus 11 functional glyphs from the vendored Phosphor Light font. Full contract in `design_ui_direction.md` §7.
- **`phosphor_flutter` can never be used here.** `flutter/lib/src/widgets/icon_data.dart:23` declares `final class IconData`; that package does `class PhosphorIconData extends IconData`. Proven twice, empirically. The app now vendors the font and depends on neither package.
- **`cupertino_icons` is deliberately absent.** The `CupertinoIcons` class ships in the SDK but the font backing it does not. If any Cupertino widget or glyph is ever introduced, **the dependency must be restored** or it renders as a blank box with no error.
- **`_familyFriendlyOnly` is client-local and never synced.** Making it a shared rule was Issue 30 Option C and was explicitly **not** selected — do not route it through `updateLobbySettings`.
- **"Forgery Rounds" / "Number of Rounds" maps to `sabotageAnswersCount`** (forgeries per card). Renaming user-visible copy is a product decision, not a cleanup.
- Design tokens are law: `AppColors` / `AppTextStyles` / `AppMotion` / `ThematicIcon` / `WaxSealBadge`. Every animation has an `AppMotion.reduce` path. Every layout is validated at **360×640 dp portrait**.

---

## 7. `.gitignore` — rules that must never be removed

**Decision rule.** (1) Secret, or identifies a developer's machine/account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.**

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA (§4). |
| `**/google-services.json` | Android Firebase config. |
| `**/GoogleService-Info.plist` | iOS Firebase config — required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Source of the phantom analyzer errors in §2. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Must stay tracked:** `assets/fonts/phosphor/Phosphor-Light.ttf` and its `LICENSE` (a silently-ignored font is a blank-box crash on every other machine), `.firebaserc`, `ios/Podfile.lock`, and both `xcshareddata/swiftpm/Package.resolved` files.

**Trap: `.swiftpm/` does not match `swiftpm/`** — the real Xcode paths have no leading dot. Do not add a `swiftpm/` rule.

**Adding a rule:** put it in the commented section it belongs to, then verify — `git check-ignore -v <path>` must print `.gitignore:<line>:<rule>	<path>`. No output means the pattern is wrong. If the file is already tracked the rule does nothing until `git rm --cached <path>`; if it held a secret, rotate it — it remains in history.

---

## 8. THE LOOP — only when §3 gives you a real item

```
(1) STUDY the item + the rejected options in ongoing_general_errors.md + the
    design_*.md contract it touches + the exact files (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Specs are decisions, not suggestions.
(3) VALIDATE. Write the falsifying test FIRST and observe it fail against the
    broken state. For a regression test over already-correct behaviour, break the
    guarded thing instead and observe that. For anything tests cannot see, do an
    itemised manual pass -- or better, verify the artefact directly. Then the full
    §2 battery. Anything touching functions/ or rules REQUIRES the emulator suite;
    fakes never validate backend behaviour.
(4) BLOCKED, or the spec turns out to be impossible? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
    A blocker is a filing event, NOT a licence to re-choose on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including the
    observed failure output and any measured numbers. Sync any design doc whose
    described behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## 9. Where everything lives

| What | Where |
|---|---|
| Engineering history, every issue and selection | `docs/ongoing_general_errors.md` |
| How to run / playtest (emulator + TestFlight) | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` — `design_ui_direction.md` §7 carries the **SHIPPED STATE** block for the hybrid icon system and the `final class IconData` constraint |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 10. Feedback loop — what past specs got wrong

Read before writing any new spec. Each entry is a **spec** failure, not an implementation failure, and each cost a cycle.

- **Resolution is not compilation.** A spec named `phosphor_flutter: ^2.1.0` after confirming it resolved via `dart pub add --dry-run`. It cannot compile — `IconData` is `final`. Name a *compiling* command as the acceptance check.
- **A blocker is a filing event, not a licence to re-choose.** Facing that, an implementer switched options and self-recorded it. Technically right, procedurally wrong — the user never got the choice. THE LOOP step (4) exists for this.
- **A "no X exists" claim must be grepped across the whole feature.** A spec asserted no settings home existed after checking `main.dart` routes and the entry form, but never the Parlor body — where one already lived. `grep -rn "Disable Game Timers" lib` would have caught it in one command.
- **Layout overflow must be measured, not estimated.** A spec estimated ~275 dp; the harness measured **593 dp**.
- **A ruling is only as durable as the test that pins it.** A spec ruled `Family-Friendly Decks Only` host-only and named a test for it. The ruling was not followed *and* the test was not written, so nothing caught it. State a ruling and pin it in the same breath.
- **Over-reach guards are the first thing dropped.** The 360×640 non-host check was flagged as most likely to be skipped — and was skipped. It passed on manual check, which was luck, not process.
- **Some correctness is invisible to tests.** A wrong icon code point renders a blank box that every assertion happily passes. Where that is true, say so — or better, verify the artefact itself: parsing the font's `cmap` proved 11/11 glyphs resolve, which no widget test could have shown.
- **What went right, keep doing:** every falsifying assertion a spec named has held up under adversarial re-testing. The Issue 26 test drags the *header text*, not the grid — dragging the grid would have passed before the fix and proven nothing.

---

## Definition of Done — for this state

- [x] Issues 1–30 and Tasks T1–T2 implemented and independently verified.
- [x] Issues 31–32 diagnosed to root cause with evidence, filed with options (§1a).
- [x] Baseline in §2 measured on this tree and reproducible.
- [x] `design_ui_direction.md` §7 reflects the shipped hybrid icon system and the vendored font.
- [ ] **Issue 31 — awaiting the user's selection.**
- [ ] **Issue 32 — awaiting the user's selection.**

**Both open issues are blocked on the user. Do not choose for them, and do not invent other work.** When a selection lands, implement only that option, validate per §1a and §8, and rewrite this guide.

### Feedback-loop entry from the August 7 playtest

**A cross-language `undefined` check is not a null check.** Issue 31's server guard (`x !== undefined ? x : existing`) was correct-looking TypeScript that silently failed because the Dart client sends explicit `null`. The 28/28 emulator suite could not catch it — those tests are written in TypeScript, where an omitted key genuinely *is* `undefined`, so the failing shape was unreachable from the test harness. **When a boundary is crossed by two languages, at least one test must send the payload the way the real client sends it.** This is the same real-client blind spot that produced the non-host write gap; it has now cost two separate bugs.
