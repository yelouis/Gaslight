# Agent Execution Guide — Active Build: Task T3 → Issue 33 (August 7, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**Approved work — two items, in this order:**

| # | Item | Scope | Selected |
|---|---|---|---|
| 1 | **Task T3** — make the raven asset/contrast test actually test something | `test/` only | (approved task) |
| 2 | **Issue 33** — fill the crow's body so the background stops showing through | `assets/images/raven/` only | Option A |

Nothing else is approved. Both specs are complete in §2 and §3.

**T3 first — it builds the PNG decoder that Issue 33's acceptance test depends on.**

**Specs are decisions, not suggestions.** **A blocker is a filing event, not a licence to re-choose on the user's behalf.**

**Line numbers are anchors measured August 7, 2026** — re-grep rather than trusting them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge`. No raw hex in widget code.
3. **Every animation needs an `AppMotion.reduce(context)` path.**
4. **Text scale clamped 1.0–1.3** (`main.dart:81–88`). **Touch targets ≥ 48 dp** (M4).
5. **Neither item touches `lib/` or `functions/`.** T3 is `test/` only; Issue 33 is `assets/` only. If you are editing `lib/`, you have left the spec — STOP and file it.
6. **One item = one commit**, Conventional Commits, WHY in the body.

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
5. **`Image.asset` loads no bytes under `flutter test`.** Widget tests render `Image` widgets with no pixels, so `find.byType(Image)` counts them whether or not the art exists or is correct, and a golden render of the mascot comes out **blank**. That is a harness artifact, not a broken asset. **Anything about how the art looks must be verified by decoding the PNG, or on a simulator.**

---

## 2. Task T3 — Make the raven asset test actually test something

**What this means for the user:** nothing visible today. It stops the crow silently regressing to invisible, which is the bug that started all of this — and it is the acceptance gate for Issue 33.

### The gap

`test/raven_mascot_test.dart:11` is titled *"Layer 1 & Layer 2: Asset dimensions, alpha channels, and rim contrast >= 4.5:1"* and its entire body is:

```dart
for (final name in assets) {
  final file = File('assets/images/raven/$name');
  expect(file.existsSync(), isTrue, reason: '$name must exist');
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThan(0));
}
```

No dimensions, no alpha, no contrast. It would pass with a one-byte junk file, and **it would pass with the bird back at 1.02:1** — the precise regression it is named for.

The per-pose tests (`:23` onward) are thin the same way: `find.byType(Image), findsNWidgets(3)` plus `takeException() == null`. Three `Image` widgets exist in every state, so they cannot tell `eye_open` from `eye_closed`, and they would pass with no `Transform` applied at all.

### Implementation

**Do not change `lib/` or the assets.** The art is correct-as-far-as-it-goes today; this is about proving it stays that way.

**Step 1 — a PNG decoder, in `test/` only.** The assets are **8-bit palette-indexed PNGs (colour type 3)** with a `tRNS` alpha table — *not* RGBA. Naively assuming RGBA will throw. The decoder must:
- walk chunks for `IHDR`, `PLTE`, `tRNS`, `IDAT`;
- inflate the concatenated `IDAT` (`ZLibCodec` from `dart:io`);
- undo the five PNG scanline filters — None/Sub/Up/Average/Paeth — at **1 byte per pixel** (`bpp = 1` for colour type 3, which changes the Sub/Paeth neighbour offsets versus RGBA);
- map each palette index through `PLTE` for RGB and `tRNS` for alpha.

Put it in `test/png_decoder.dart` as a test helper. **Nothing in `lib/`.**

**Step 2 — verify your decoder before asserting anything.** These values were measured from the shipped assets on August 7. If your decoder disagrees, the decoder is wrong:

| Asset | Canvas | Opaque px (α>200) | Dominant colour | Contrast vs `#14110E` |
|---|---|---|---|---|
| `body.png` | 256×256 | 4871 | `#C6A14B` rim, 3194 px | **7.70:1** |
| | | | `#2D2925` fill, 1122 px | 1.30:1 |
| `wing.png` | 256×256 | 378 | `#C7A24C` | 7.79:1 |
| `eye_open.png` | 256×256 | 1110 | `#F3ECD4` | 15.91:1 |
| `eye_closed.png` | 256×256 | 79 | `#CFA64D` | 8.25:1 |

**Step 3 — replace the vacuous test with four real assertions.**

1. **Dimensions.** Each 1x asset decodes to exactly **256×256**; `2.0x` to 512×512; `3.0x` to 768×768.
2. **Alpha is real.** Each asset has at least one fully transparent pixel *and* at least one opaque pixel.
3. **Rim contrast — the regression guard.** Compute the WCAG contrast of the **brightest opaque pixel in `body.png`** against `AppColors.ground` `#14110E`; assert **≥ 4.5:1**. Formula: linearise each channel (`c/12.92` if `c ≤ 0.03928`, else `((c+0.055)/1.055)^2.4`), luminance `0.2126R + 0.7152G + 0.0722B`, ratio `(L_hi + 0.05)/(L_lo + 0.05)`.
4. **Shared-canvas alignment.** The alpha bounding box of `body.png` must **contain** that of `eye_open.png`. This catches the "layers cropped to their own bounding boxes" failure that would misalign the stack.

**Step 4 — make the per-pose tests assert the pose.** Read the asset path off the rendered `Image` widgets — `AssetImage.assetName` exposes it without touching `lib/`:
- `sleep` renders `eye_closed.png`; resting `idle` renders `eye_open.png`.
- `hop`, `ruffle`, `fly`: pump to mid-animation and assert the relevant `Transform`'s matrix is **not** identity, then pump to completion and assert it settles. `tester.widgetList<Transform>(...)` gives the matrices.
- Reduced motion: the tree is identical across two pumps 500 ms apart.

If any of that proves impossible without adding a `Key` or exposing state in `lib/`, **stop and file it** — a one-line `Key` is probably right, but it changes T3 from "test-only" and that is the user's call.

### Validation

**Prove the contrast assertion is not vacuous.** Paint a scratch 256×256 PNG filled `#171310` (the pre-Issue-32 invisible colour) on transparent, point the contrast assertion at it, and confirm it **fails**. Restore, confirm `git status --short` is clean, and **record the observed failure output in the commit body.** A contrast test never seen to fail is the same trap T3 exists to remove.

Then the full §1 battery. Expect **74/74** or more; the count must not drop.

### Blast radius
`test/raven_mascot_test.dart`, new `test/png_decoder.dart`. **Nothing in `lib/`, `assets/` or `functions/`.**

---

## 3. Issue 33 — Fill the crow's body (Option A)

**What this means for the user:** the crow currently reads as a hollow wire outline — in the lobby you can see the tavern wall, the hanging herbs and the brass room-code plaque straight through its chest and tail. Filling it makes it a solid bird that looks the same on every screen.

### The gap — measured
Decoding `assets/images/raven/body.png`: inside the bird's own bounding box (198×199 px), **84.5% of pixels are fully transparent** and only **12.4% are opaque** — and most of that is the outline (3194 px brass rim `#C6A14B` versus 1122 px dark fill `#2D2925`). The brief called for a filled dark body behind a brass rim; what shipped is essentially the rim alone.

### ⚠️ A programmatic flood fill will NOT work — already tested, do not retry

The obvious approach — flood-fill the interior from the outline — was tested and **fails**. The rim is not a closed loop. Enclosed interior pixels, measured across wall thresholds:

| Wall threshold | Enclosed interior px |
|---|---|
| α ≥ 1 | 582 |
| α ≥ 10 | 17 |
| α ≥ 30 / 60 / 100 / 160 | 7 |

A filled body needs on the order of **20,000 px**. At every threshold the fill escapes through gaps in the outline and floods the whole canvas. **Regenerate the art instead.**

### Implementation — regenerate `body.png` only

**The overriding constraint is alignment.** `wing.png`, `eye_open.png` and `eye_closed.png` are positioned to match the *current* body on a shared 256×256 canvas. If the regenerated body is redrawn, re-posed, re-scaled or re-centred, every other layer misaligns and you will be chasing it for hours. **Do not regenerate from the text prompt.**

**Step 1 — edit, do not redraw.** Use the existing `assets/images/raven/3.0x/body.png` (768×768, the highest-resolution copy) as the image-to-image reference:

> Using the supplied image as an exact reference, fill the interior of the bird shape with solid opaque `#2D2925`, behind the existing brass outline. Keep the outline, the silhouette, the pose, the scale and the position **pixel-identical** — change nothing except making the inside of the bird opaque instead of transparent. Preserve the transparent background outside the bird. Output the same 768×768 canvas with alpha.

**Step 2 — reuse the existing palette colour.** Fill with `#2D2925`, which is already in the file's palette. Introducing a new shade adds a palette entry and grows the file; the current 68 KB total is well inside the 150 KB budget and should stay there.

**Step 3 — regenerate the density variants.** Downscale the approved 768×768 result to 512×512 (`2.0x/body.png`) and 256×256 (`body.png`). Downscale from one master rather than generating three times — three generations will not match.

**Step 4 — if alignment cannot be preserved**, the fallback is to regenerate **all four layers together** from the master in `assets/images/raven/PROMPTS.md`, so they are mutually consistent, then re-verify alignment. This is the expensive path; exhaust Step 1 first. If you take it, say so explicitly in the commit body.

**No code changes.** `lib/widgets/raven_mascot.dart` and `pubspec.yaml` are untouched.

### Validation

**Falsifying test — add to `test/raven_mascot_test.dart` using T3's decoder.** Assert the opaque fraction inside `body.png`'s alpha bounding box is **≥ 40%**:

```
opaque(α>200) inside bbox  /  bbox area  >=  0.40
```

Current value is **12.4%**, so this **fails against today's asset** — that is the point. 40% is chosen to sit far above the hollow case while staying achievable: a crow silhouette does not fill its bounding rectangle, so expect roughly 45–65%.

**If a genuinely filled silhouette measures below 40%, report the real number — do not quietly lower the threshold to make it pass.** That would convert a real guard into the same decoration T3 exists to remove.

**Alignment regression guard — not optional.** After regenerating, assert:
- `body.png`'s alpha bounding box is within **±3 px on every edge** of the pre-change box `(26, 32)–(217, 224)`, proving the bird was not moved or re-scaled;
- `body.png`'s bounding box still **contains** `eye_open.png`'s.

This is what catches a "helpfully redrawn" bird before it ships misaligned.

**Contrast must not regress.** T3's rim assertion (≥ 4.5:1) must still pass — the rim is untouched, so it should stay at 7.70:1.

**Size:** total `assets/images/raven/` stays **≤ 150 KB** (currently 68 KB).

**Visual check on a simulator** — the harness cannot show you the art (§1 trap 5):
```bash
xcrun simctl boot "iPhone 17"; open -a Simulator
flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.whylabs.gaslight
xcrun simctl io booted screenshot /tmp/raven.png
```
The crow appears in the Parlor beside "ASSEMBLING THE SUSPECTS…". Confirm no tavern wall, herbs or brass plaque show through it.

### 🚦 Approval gate — this BLOCKS the commit

**Show the user the simulator screenshot and get explicit approval before committing.** Issue 32 shipped its artwork unseen because this step lived in a checklist instead of blocking, and the hollow bird is the direct result. Do not commit regenerated art the user has not looked at. Record the approval in the Resolved entry.

### Blast radius
`assets/images/raven/body.png`, `2.0x/body.png`, `3.0x/body.png`, and the new coverage + alignment assertions in `test/raven_mascot_test.dart`. **Nothing in `lib/`, `pubspec.yaml` or `functions/`.**

---

## 4. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.** Issue 31 is the model — rebuilt from pre-fix source, the suite reported `expected null to equal 3` and `expected 'INTERNAL' to equal 'FAILED_PRECONDITION'`, exactly the reported symptom pair. **Record the observed failure output in the Resolved entry.**

**A test's name is not a test.** Issue 32 shipped a test called *"…rim contrast >= 4.5:1"* that asserted only that a file was non-empty. Before trusting an existing test, read its body. Before writing one, ask what change would make it fail — if the answer is "almost nothing", it is decoration.

**Some correctness is invisible to the harness.** `Image.asset` loads nothing under `flutter test`; icon code points render as blank boxes that every assertion passes. Verify the artefact directly — decode the PNG, parse the font `cmap` — or check on a simulator.

**Do not tune a threshold to make a test pass.** Report the measured number and say the guard failed.

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

**Must stay tracked:** the vendored Phosphor font + `LICENSE`, the 12 raven PNGs + `PROMPTS.md`, `.firebaserc`, `ios/Podfile.lock`, both `xcshareddata/swiftpm/Package.resolved`. After regenerating art, confirm with `git status` that the new PNGs are staged — a silently-ignored asset is a blank bird on every other machine.

**Trap: `.swiftpm/` does not match `swiftpm/`** — the real Xcode paths have no leading dot.

---

## 7. Already delivered — do NOT rework

**Issues 1–32, Tasks T1–T2.** Points bearing on current work:
- **Issue 31** — settings no longer wipe each other; `startGame` throws a readable `failed-precondition`. **Verified live in production** (`DEPLOYMENT_ROLLOUT` 2026-08-07T05:20:40Z). The server uses loose `!= null` — **do not "simplify" that to a falsy check**: `isTimerDisabled: false` and `sabotageAnswersCount: 0` are legitimate values a falsy check would discard, re-creating the bug in a new shape. An over-reach test guards this.
- **Issue 32** — mascot is four layered PNGs on a shared 256×256 canvas (68 KB), `RavenMascot` API and all five call sites frozen, `_RavenPainter` deleted. Regeneration prompts in `assets/images/raven/PROMPTS.md`.
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

- **A test's name is not a test.** Issue 32 shipped `'…rim contrast >= 4.5:1'` asserting only that a file was non-empty — the exact guard for the bug being fixed, absent while reading as present. **When a spec names a threshold, review the assertion, not the title.**
- **Approval gates get skipped under momentum.** Issue 32's spec required user sign-off on a contact sheet before merge. It shipped unseen and the crow turned out hollow — Issue 33. **If a step needs a human, it has to block the commit, not sit in a checklist.** §3 now states this inline.
- **A cross-language `undefined` check is not a null check.** Issue 31's server guard was correct-looking TypeScript that failed because the Dart client sends explicit `null`; the TypeScript test suite structurally could not produce the failing payload.
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
    Then the full §1 battery.
(4) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including observed
    failure output and measured numbers.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **T3:** `test/png_decoder.dart` handles palette-indexed PNGs; the asset test asserts real dimensions (256/512/768), alpha presence, **rim contrast ≥ 4.5:1** vs `#14110E`, and body-contains-eye alignment.
- [ ] Per-pose tests assert the actual asset path and non-identity transforms, not three `Image` widgets and no exception.
- [ ] **The contrast assertion was observed to FAIL** against a deliberately-darkened body; output recorded in the commit body.
- [ ] No `lib/`, `assets/` or `functions/` changes in the T3 commit.
- [ ] **Issue 33:** `body.png` and its 2x/3x variants regenerated by *editing* the existing art, not redrawing it.
- [ ] Opaque coverage inside the bounding box **≥ 40%** (was 12.4%), and this assertion was observed to fail against the pre-change asset.
- [ ] Alignment guard passes: bounding box within **±3 px** of `(26, 32)–(217, 224)` on every edge, and still contains `eye_open.png`'s box.
- [ ] Rim contrast still ≥ 4.5:1; `assets/images/raven/` still **≤ 150 KB**; new PNGs staged in git.
- [ ] **🚦 The user has seen a simulator screenshot of the filled crow and approved it — before the commit.**
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 74** · functions build clean · `npm --prefix functions test` **31/31**.
- [ ] Both items moved to Resolved in `ongoing_general_errors.md`; two commits, one per item.
- [ ] This guide rewritten to **Queue Complete**, or to the next approved queue.
