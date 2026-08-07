# Agent Execution Guide — Task T3 approved · Issue 33 awaiting selection (August 7, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

| Item | What it is | Status |
|---|---|---|
| **Task T3** | Make the raven asset/contrast test actually test something | ✅ **APPROVED — start here.** Test-only. |
| **Issue 33** | The new crow is an outline; the background shows through it | ⛔ `Your selection: _____` blank |

**Do T3. Do not start Issue 33** — it is a look-and-feel decision only the user can make. If its selection line is still blank after T3, report that and stop.

Issues 1–32 and Tasks T1–T2 are implemented and independently verified. **Issue 31 is verified live in production** (`DEPLOYMENT_ROLLOUT` 2026-08-07T05:20:40Z).

**Specs are decisions, not suggestions.** **A blocker is a filing event, not a licence to re-choose on the user's behalf.**

**Line numbers are anchors measured August 7, 2026** — re-grep rather than trusting them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge`. No raw hex in widget code.
3. **Every animation needs an `AppMotion.reduce(context)` path.**
4. **Text scale clamped 1.0–1.3** (`main.dart:81–88`).
5. **Touch targets ≥ 48 dp** (M4).
6. **T3 touches only `test/`.** If you are editing `lib/`, `functions/`, or `assets/`, you have left the spec — STOP.
7. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** |
| Client tests | `flutter test` | **74/74 pass** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **31/31** |
| iOS release | `flutter build ios --release --no-codesign` | succeeds |

### ⚠️ Five traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, **never bare `flutter analyze`** — the bare form reports ~678 errors from vendored plugin source under gitignored `build/`.
2. **Analyze ≠ compile.** `flutter analyze` does not analyse dependency source. Only `flutter test` or `flutter build` surfaces a broken dependency.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions run build`.
4. **BSD `sed` does not support `\b`** — it silently matches nothing and exits 0. Use `python3`.
5. **`Image.asset` does not load real bytes under `flutter test`.** Widget tests render `Image` widgets with no pixels, so `find.byType(Image)` counts them whether or not the art exists or is correct. A golden-file render of the mascot comes out **blank** for this reason — that is a harness artifact, not a broken asset. **Anything about how the art actually looks must be verified by decoding the PNG file, or on a simulator.**

---

## 2. Task T3 — Make the raven asset test actually test something ✅ APPROVED

**What this means for the user:** nothing visible today. It stops the crow silently regressing to invisible in future, which is the exact bug that started all of this.

### The gap

`test/raven_mascot_test.dart:11` is titled:

> `'Layer 1 & Layer 2: Asset dimensions, alpha channels, and rim contrast >= 4.5:1'`

and its entire body is:

```dart
for (final name in assets) {
  final file = File('assets/images/raven/$name');
  expect(file.existsSync(), isTrue, reason: '$name must exist');
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThan(0));
}
```

It measures **no dimensions, no alpha, and no contrast**. It would pass with a one-byte junk file, and — the point — **it would pass with the bird back at 1.02:1 contrast**. The name promises the regression guard for Issue 32; the body delivers a file-existence check. This is worse than having no test, because the name tells the next reader they are covered.

The per-pose tests (`:23` onward) are thin in the same way: they assert `find.byType(Image), findsNWidgets(3)` and `takeException() == null`. Three `Image` widgets are present in every state, so these cannot distinguish `eye_open` from `eye_closed`, and they would pass even if no `Transform` were applied at all.

### Implementation

**Do not change `lib/` or the assets.** The art is correct as shipped; this is about proving it stays correct.

**Step 1 — a minimal PNG decoder in the test.** The assets are **8-bit palette-indexed PNGs** (colour type 3) with a `tRNS` alpha table — *not* RGBA. A decoder must handle `IHDR`, `PLTE`, `tRNS` and `IDAT`, `zlib.decode` the pixel data, and undo the five PNG scanline filters (None/Sub/Up/Average/Paeth) at **1 byte per pixel**. Dart's `dart:io` plus `package:archive` or the built-in `ZLibCodec` (`dart:io`) covers the inflate. Put the decoder in a test helper, not in `lib/`.

Reference values, measured from the shipped assets on August 7 — use these to confirm your decoder is correct before asserting anything:

| Asset | Canvas | Opaque px | Dominant colour | Contrast vs `#14110E` |
|---|---|---|---|---|
| `body.png` | 256×256 | 4871 | `#C6A14B` (rim, 3194 px) | **7.70:1** |
| | | | `#2D2925` (fill, 1122 px) | 1.30:1 |
| `wing.png` | 256×256 | 378 | `#C7A24C` | 7.79:1 |
| `eye_open.png` | 256×256 | 1110 | `#F3ECD4` | 15.91:1 |
| `eye_closed.png` | 256×256 | 79 | `#CFA64D` | 8.25:1 |

**Step 2 — replace the vacuous test with four real assertions.**

1. **Dimensions.** Each 1x asset decodes to exactly **256×256**. Also assert the `2.0x` variants are 512×512 and `3.0x` are 768×768.
2. **Alpha present.** Each asset has at least one fully transparent pixel and at least one opaque pixel — proving a real alpha channel rather than an opaque rectangle.
3. **Rim contrast — the regression guard.** Compute the WCAG relative-luminance contrast of the **brightest opaque pixel in `body.png`** against `AppColors.ground` `#14110E`, and assert **≥ 4.5:1**. Current value 7.70:1, so there is comfortable headroom. Use the standard formula: linearise each channel (`c/12.92` if `c ≤ 0.03928`, else `((c+0.055)/1.055)^2.4`), luminance `0.2126R + 0.7152G + 0.0722B`, ratio `(L_hi + 0.05) / (L_lo + 0.05)`.
4. **Shared-canvas alignment.** The alpha bounding box of `body.png` must **contain** that of `eye_open.png`. This is what catches the "layers cropped to their own bounding boxes" failure that would misalign the stack.

**Step 3 — make the per-pose tests assert the pose.** Give each layer a `Key` in `raven_mascot.dart`… **no — that would edit `lib/`, which is out of scope for T3.** Instead assert on what is already observable from the widget tree:

- `sleep` and a blinking `idle` must render the `eye_closed.png` asset; resting `idle` must render `eye_open.png`. Read this from the `Image` widgets' `image` property — `AssetImage.assetName` (or `ExactAssetImage`) exposes the path without touching `lib/`.
- `hop`, `ruffle`, `fly`: pump to mid-animation and assert the relevant `Transform`'s `transform` matrix is **not** the identity, then pump to completion and assert it returns. `tester.widgetList<Transform>(...)` gives you the matrices.
- Reduced motion: assert the widget tree is identical across two pumps 500 ms apart — a static frame.

If any of that turns out to be impossible without adding a `Key` or exposing state in `lib/`, **stop and file it** rather than quietly editing the widget: a one-line `Key` addition is very likely the right answer, but it changes the scope from "test-only" and the user should say so.

### Validation

**Prove the new contrast assertion is not vacuous** — this is the whole point of T3, so it must be demonstrated, not assumed:

```bash
# Temporarily swap in the OLD invisible colour and confirm the test FAILS.
python3 - <<'PY'
# regenerate body.png with fill+rim at 0xFF171310 (the pre-Issue-32 colour), or
# simply point the test at a scratch PNG painted #171310 on transparent.
PY
flutter test test/raven_mascot_test.dart     # must FAIL on the contrast assertion
```
Restore afterwards and confirm `git status --short` is clean. **Record the observed failure output in the commit body.** A contrast test that has never been seen to fail is the same trap this task exists to remove.

Then the full §1 battery. Expect **74/74** still (T3 rewrites assertions inside existing tests; add cases if you prefer, but the count must not drop).

### Blast radius
`test/raven_mascot_test.dart` and a new test-only PNG-decoding helper under `test/`. **Nothing in `lib/`, `assets/` or `functions/`.**

---

## 3. Issue 33 — BLOCKED, do not start

The crow is **84.5% fully transparent inside its own bounding box** — an outline rather than a filled silhouette, so the lobby's tavern wall and the brass room-code plaque show through it. Options are: fill the body in, keep the hollow look deliberately, or fill it partially. Full statement and trade-offs are in `ongoing_general_errors.md`.

**This is a look-and-feel judgement and the user's call.** If a selection lands: Options A and C mean regenerating `assets/images/raven/body.png` (and its 2x/3x variants) from the prompts in `assets/images/raven/PROMPTS.md` — **no code change**, and T3's alignment and contrast assertions become the acceptance gate. Option B means recording it in §7 as an accepted equivalent and doing nothing else.

Whichever way it goes, **the artwork approval gate that was skipped on Issue 32 must actually happen this time**: render the mascot on a booted simulator and have the user confirm before it merges. A widget-test golden will come out blank (§1 trap 5) and proves nothing.

---

## 4. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.** Issue 31 is the model — rebuilt from pre-fix source, the suite reported `expected null to equal 3` and `expected 'INTERNAL' to equal 'FAILED_PRECONDITION'`, which is exactly the reported symptom pair. **Record the observed failure output in the Resolved entry.**

**A test's name is not a test.** Issue 32 shipped a test called *"…rim contrast >= 4.5:1"* that asserted only that a file was non-empty. Before trusting any existing test, read its body. Before writing one, ask what change would make it fail — if the answer is "almost nothing", it is decoration.

**Some correctness is invisible to the test harness.** `Image.asset` loads no bytes under `flutter test`; icon code points render as blank boxes that every assertion passes. Verify the artefact directly — decode the PNG, parse the font `cmap` — or verify on a simulator.

Prefer assertions on **counts, ranges, geometry and measured values**. Pair every fix assertion with an **over-reach guard**.

---

## 5. Running 3 simulators for multiplayer testing

Bots are server-seeded documents and never exercise the non-host **client** path — use real simulator clients for anything that must be correct.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```
```bash
flutter build ios --simulator --debug
```
```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app; xcrun simctl launch "$U" com.whylabs.gaslight; done
```

Must be `--debug`: `lobby_screen.dart:87` passes `debugEnabled: kDebugMode`, and the server refuses debug calls when false. **DEBUG: ADD 9 BOTS** is host-only and adds 9 unconditionally.

---

## 6. `.gitignore` — rules that must never be removed

**Decision rule.** (1) Secret, or identifies a developer's machine/account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.**

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA. |
| `**/google-services.json` · `**/GoogleService-Info.plist` | Firebase config. The plist is required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Source of the phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Must stay tracked:** the vendored Phosphor font + `LICENSE`, the 12 raven PNGs + `PROMPTS.md`, `.firebaserc`, `ios/Podfile.lock`, both `xcshareddata/swiftpm/Package.resolved`.

**Trap: `.swiftpm/` does not match `swiftpm/`** — the real Xcode paths have no leading dot.

---

## 7. Already delivered — do NOT rework

**Issues 1–32, Tasks T1–T2.** Points that bear on current work:
- **Issue 31** — settings no longer wipe each other; `startGame` throws a readable `failed-precondition`. **Live in production.** The client omits null keys, the server uses loose `!= null` — **do not "simplify" that to a falsy check**: `isTimerDisabled: false` and `sabotageAnswersCount: 0` are legitimate values a falsy check would discard, re-creating the bug in a new shape. An over-reach test guards this.
- **Issue 32** — mascot is four layered PNGs on a shared 256×256 canvas (68 KB total), `RavenMascot` API and all five call sites frozen, `_RavenPainter` deleted. Regenerate art from `assets/images/raven/PROMPTS.md`.
- **Issue 23/29** — 11 functional glyphs from a **vendored** Phosphor Light font; 6 bespoke `CustomPainter` avatar sigils. `phosphor_flutter` **can never be used** — `IconData` is a `final class`; proven twice.
- **Issue 24** — entry form fits 360×640 (was 593 dp over). **Issue 26** — roster sheet header drag works (was 0 px). **Issue 27/30** — one House Rules panel; `Family-Friendly Decks Only` is host-only. **T2** — `cupertino_icons` deliberately absent.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` everywhere · Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `ITSAppUsesNonExemptEncryption = false` · `GoogleService-Info.plist` required on disk but gitignored · `.env` ships in the IPA so **`USE_EMULATOR` must be `false`** for testers.

---

## 8. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field (M5); **Vote's CONFIRM** is bottom-anchored via `Expanded`+`SafeArea`.
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **Entry-form logo uses `SizedBox(height: 60)` + `FittedBox`**, not `Transform.scale`.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale.**
- **House Rules non-host gating uses `IgnorePointer` + `Opacity(0.5)`.** The server rejects non-host writes regardless.
- **Forgery Rounds uses `Wrap(spacing: 6)`.** The caption reads `Only the host can modify house rules.`
- **The mascot's head tilt is whole-body, and `lowerBeakOpen` was dropped** — deliberate simplifications for a single-silhouette design (Issue 32).

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through callables; `firestore.rules` denies client room writes.
- **Portrait-locked on phones**; **text scale clamped 1.0–1.3** (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.**
- **`_familyFriendlyOnly` is client-local and never synced.**
- **`RavenMascot`'s public API and `RavenState` enum are frozen**; the five call sites must not change.
- **"Forgery Rounds" maps to `sabotageAnswersCount`.**

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Engineering history, every issue and selection | `docs/ongoing_general_errors.md` |
| How to run / playtest | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` — `design_ui_direction.md` §7 carries the icon **SHIPPED STATE** block |
| Mascot regeneration prompts | `assets/images/raven/PROMPTS.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 11. Feedback loop — what past specs got wrong

- **A test's name is not a test.** Issue 32 shipped `'…rim contrast >= 4.5:1'` asserting only that a file was non-empty — the exact guard for the bug being fixed, absent, while reading as present. **When a spec names a threshold, the review must read the assertion, not the test title.**
- **A cross-language `undefined` check is not a null check.** Issue 31's server guard was correct-looking TypeScript that failed because the Dart client sends explicit `null`; the TypeScript test suite structurally could not produce the failing payload. When a boundary is crossed by two languages, at least one test must send the payload the way the real client sends it.
- **Approval gates get skipped under momentum.** Issue 32's spec required user sign-off on a contact sheet before merge. It shipped unseen, and the crow turned out hollow — Issue 33. **If a step needs a human, it cannot live only in a checklist; it has to block the commit.**
- **Resolution is not compilation.** A package that resolves may still fail to build.
- **A "no X exists" claim must be grepped across the whole feature.**
- **Layout overflow must be measured, not estimated** — estimated ~275 dp, measured **593 dp**.
- **A ruling is only as durable as the test that pins it.**
- **Some correctness is invisible to the harness.** Wrong icon code points render as blank boxes; `Image.asset` loads nothing under `flutter test`; a bird can ship at 1.02:1 with a green suite. Verify the artefact directly.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §4. Observe the falsifying test fail against the broken state.
    For anything the harness cannot see, decode the artefact or check a simulator.
    Then the full §1 battery. Anything touching functions/ or rules REQUIRES the
    emulator suite.
(4) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including observed
    failure output and measured numbers.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **T3:** the asset test decodes the palette-indexed PNGs and asserts real dimensions, alpha presence, **rim contrast ≥ 4.5:1** against `#14110E`, and body-contains-eye bounding-box alignment.
- [ ] Per-pose tests assert the actual asset path and non-identity transforms, not just three `Image` widgets and no exception.
- [ ] **The contrast assertion was observed to FAIL** against a deliberately-darkened body, and the observed output is recorded in the commit body.
- [ ] No changes to `lib/`, `assets/` or `functions/` in the T3 commit.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 74** · functions build clean · `npm --prefix functions test` **31/31**.
- [ ] `git status --porcelain | grep "^??"` returns nothing.
- [ ] **Issue 33 — awaiting the user's selection. Do not start it.**
- [ ] This guide rewritten to reflect the new state.
