# Agent Execution Guide — Active Build: Task T8 (August 8, 2026)

> ## 🔴 T8 — generate real `wing_up` and `beak_open` art, then rebuild `flap`, `fly`, `preen`, `caw`
>
> T7 re-authored the four poses as body motion (`ef6fc70`) and the user reviewed again: **the wings still do not flap and the beak still does not open.** T7 was the right fix for *how the poses move*, but it could not fix the underlying problem — **there is no art to show a raised wing or an open beak.** This task generates that art.
>
> ### Why T7 could not have worked — measured
>
> | Layer | Opaque px | % of body | Pixels **outside** the body silhouette |
> |---|---|---|---|
> | `wing.png` | 476 | 2.0% | **0 (0%)** |
> | `wing_up.png` | 496 | 2.1% | **37 (7%)** |
> | `beak_open.png` | 115 | 0.5% | **0 (0%)** |
>
> **A part drawn entirely inside the body outline cannot be seen, no matter what you do with it.** `wing.png` has literally zero pixels outside the silhouette — rotating it can never produce a visible wing. T7 grew `beak_open` from 47 px to 115 px, but every one of those pixels is still *inside* the body, so the beak still cannot appear to open. That is the whole bug, and no parameter change reaches it.
>
> ### The geometric constraint that dictates the art
>
> The body is a single solid blob, which rules out the obvious designs:
>
> - **The beak must open UPWARD, not downward.** The chest sits directly below the beak, so a dropped lower mandible stays inside the silhouette and stays invisible. Above the beak there is open space: at x=185 the body starts at y=53, at x=205 it starts at y=78. **Lift the upper mandible into that gap.**
> - **The raised wing must go UP over the flank.** At x=65 the body starts at y=126 and at x=75 at y=116, so there is 115–125 px of clear space directly above the wing's current position.
>
> ### Nano banana brief — two new reference layers
>
> Edit the **existing** art. Do not generate a new bird: the layers are the character, and a fresh generation reintroduces the drift that has already cost this project once. Copy these into `assets/images/raven/PROMPTS.md` when used.
>
> **`wing_up.png` — a genuinely raised wing**
>
> > Using the supplied `body.png` and `wing.png` as exact references, draw the crow's near wing **raised and extended upward**, as at the top of a wingbeat. The wing should sweep up and back from its shoulder at roughly (100, 118), with the tip reaching into the empty space above the bird's flank — around x 55–95, y 45–100 on the 256×256 canvas. **A substantial part of the wing must sit outside the body's outline**, clearly silhouetted against the background rather than lying flat on the body. Keep the same canvas, scale, position of the shoulder, palette (`#2D2925` fill, `#C6A14B` rim) and rim weight. Draw only the wing; everything else fully transparent.
>
> **`beak_open.png` — the beak open, hinging upward**
>
> > Using the supplied `body.png` as an exact reference, draw **only the crow's upper mandible, lifted open** as if calling — rotated up and back from the beak hinge at roughly (168, 84), with the tip rising into the empty space above the beak, around x 175–215, y 35–70 on the 256×256 canvas. **Most of this shape must fall outside the body's existing outline** so the open gap is clearly visible against the background. Match the beak's brass `#C6A14B` fill and rim weight. Draw only the lifted upper mandible; everything else fully transparent.
>
> ### Acceptance criteria — measurable, and non-negotiable
>
> Both new layers must pass, asserted in `test/raven_mascot_test.dart` using `test/helpers/png_decoder.dart`:
>
> | Layer | Minimum mass | Minimum share **outside** `body.png`'s silhouette |
> |---|---|---|
> | `wing_up.png` | **≥ 1,200 px** (≈5% of body; currently 496) | **≥ 40%** (currently 7%) |
> | `beak_open.png` | **≥ 300 px** (currently 115) | **≥ 50%** (currently 0%) |
>
> **The "outside" figure is the one that matters** — mass alone is what T7 increased, and it changed nothing. If a regenerated layer misses these, regenerate it; **do not lower the threshold to make it pass.** These numbers are what "visible" means here, expressed so a test can check it.
>
> ### Then rebuild the four poses
>
> With art that can actually be seen, the poses can use it:
> - **`flap`** — now genuinely alternate `wing` ↔ `wing_up` on a two-frame cadence. Keep the body bob T7 added; the two together read as a wingbeat. This is the pose the swap was always meant to serve.
> - **`fly`** — sweep through `wing` → `wing_up` across the climb, keeping T7's anticipation crouch.
> - **`preen`** — the wing can now be seen moving toward the body; keep it within **`|wing_rot| ≤ 0.12` rad** (§T7) since `wing.png` itself is unchanged and still sits inside the outline.
> - **`caw`** — overlay the new `beak_open` on the frames where the bird calls, with T7's head-thrust motion beneath it.
>
> **Leave `ruffle`, `startle`, `hop`, `peck`, `bow`, `alert` alone.** They were accepted.
>
> ### 🚦 Preview and approval — still blocking
> Re-render the four per `.agents/skills/mascot_pose_creation/SKILL.md` §6 and send them together for approval **before committing**. Since the last two rounds were both rejected on "can't see it", also send a **still of each new layer composited over `body.png`** so the raised wing and open beak can be judged directly, independently of the motion.
>
> ---

# Task T7 — re-author four poses as silhouette motion (delivered `ef6fc70`, superseded by T8)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

> ## 🔴 T7 — four poses do not read. Re-author them.
>
> All ten sheets shipped in `690d109`. On review the user **rejected `preen`, `fly`, `flap` and `caw`**. The other six — `ruffle`, `startle`, `hop`, `peck`, `bow`, `alert` — were accepted.
>
> **Do not touch the six that passed.** Re-authoring them is the easiest way to lose ground that is already won.
>
> **📖 `.agents/skills/mascot_pose_creation/SKILL.md` is still the method.** This section is the diagnosis and the per-pose brief.
>
> ### Root cause — one problem wearing four costumes
>
> Measured from the source layers, not inferred:
>
> | Layer | Opaque px | Share of body |
> |---|---|---|
> | `body.png` | 23,705 | 100% |
> | `wing.png` | **476** | **2.0%** |
> | `wing_up.png` | **496** | **2.1%** |
> | `beak_open.png` | **47** | **0.2%** |
>
> **The moving parts are decorative slivers, not structural shapes.** At the size the mascot renders — 48–96 dp — only whole-silhouette change reads: scale, rotation, translation, and deformation of the outline itself. A 2%-mass detail cannot carry a pose; a 0.2% one carries nothing. All four rejected poses were authored as if the wing or beak were a limb. They are line details.
>
> This is the general lesson, and it should govern every future pose: **carry the pose in the silhouette; treat the wing as garnish.** A useful test — *would the pose still read if the wing layer were deleted entirely?* For the six that passed, yes. For these four, no.
>
> Per pose:
> - **`preen`** — `wing_rot: -0.44` rad (−25°) swings the 476 px sliver clear of the body. It reads as a stray scratch beside the bird. Worse, the body rotates the *same* direction as the wing, so the two move **apart** — a preen is head-toward-flank, they should converge.
> - **`fly`** — alternating `wing_rot` of ±0.35–0.40 makes the sliver flicker in and out of the silhouette rather than sweep, while the body merely slides up and down. No launch.
> - **`flap`** — built as a `wing` ↔ `wing_up` swap, but the two differ by **20 px of mass**. The swap is invisible at render size. This pose cannot work as a layer swap at all.
> - **`caw`** — `beak_open.png` is 47 px and **100% of it lies inside the body silhouette**. Overlaying it changes nothing. There is no visible opening.
>
> ### A second, independent bug: the wing pivot is on the wrong corner
>
> `render_frame` rotates the wing about **(64.0, 153.6)**, commented "shoulder pivot". It is not the shoulder. The wing's bbox is (52,104)–(104,171) and the body centroid is x=129, so the wing **attaches along its right edge, near (100, 118)**. (64, 153.6) is the lower-**left** — the free tip. Rotating about the free tip swings the *attached* end away from the body, which is backwards and is why even modest angles detach.
>
> **Move the pivot to ≈ (100, 118).** The farthest wing pixel is then ~72 px away, and the body outline leaves ~10 px of margin, giving a hard cap:
>
> **`|wing_rot| ≤ 0.12 rad (≈7°)`.** `preen` and `fly` currently run 3× over it.
>
> ### Per-pose re-authoring brief
>
> - **`preen`** — carry it in the body: whole-body `rotate` toward the flank with `scale_y ≈ 0.94` / `scale_x ≈ 1.04` so the bird visibly hunches. Rotate the wing **opposite** to the body rotation so they converge, within the 0.12 cap. Verify the pose still reads with the wing deleted.
> - **`fly`** — a launch needs **anticipation**: one frame of crouch (`scale_y ≈ 0.90`, `translate_y ≈ +3`) *before* the climb, then stretch (`scale_y ≈ 1.12`) with a strong `translate_y`, then settle. Sliding upward without the crouch reads as being lifted, not leaping.
> - **`flap`** — abandon the layer swap. Express wingbeats as a **rhythmic body bob**: alternate `scale_y` 1.06 / 0.96 with matching `translate_y` on a two-frame cadence while climbing. A pulsing silhouette reads as beating; a 20 px shape change never will.
> - **`caw`** — the only one needing **new art as well as new numbers**.
>   - *Art:* regenerate `beak_open.png` so the dropped lower mandible extends **outside** the closed beak's outline — it must break the silhouette, not sit inside it. Same canvas, palette and rim weight; edit the existing art per the skill, never generate a fresh bird.
>   - *Motion:* head-thrust — `rotate` back and up, `scale ≈ 1.08`, slight `translate_y`, peaking on the frames where the beak is open.
>
> ### Validation — three new assertions on top of §2's
>
> 1. **Wing-rotation cap.** Over the whole pose registry, assert no frame exceeds `|wing_rot| = 0.12`. This is the guard that stops the detachment bug returning.
> 2. **Silhouette containment.** For every frame of every pose, all opaque pixels must fall inside a ~6 px dilation of `body.png`'s silhouette. **This is the assertion that would have caught all four rejections**, and nothing in the current suite covers it.
> 3. **`beak_open` must break the silhouette.** Assert containment **fails** for that layer specifically — do not exempt it from check 2, invert it. It is the only way to prove the new art actually opens the beak.
>
> ### 🚦 Preview and approval — still blocking
> Re-render each fixed pose per skill §5 and get approval **before committing**. Send all four together: they are being judged as a set against the six that passed.

---

**All approved queue items delivered and verified:**

| # | Item | Scope | Status |
|---|---|---|---|
| 1 | **Task T6 rollout** — pre-rendered frame sequences for all 10 transient crow poses | `assets/images/raven/frames/*.png` + `scripts/build_sprite_sheets.py` + `lib/widgets/raven_mascot.dart` + tests | ✅ **Delivered & Verified** |

> ### 🎉 Queue Complete
>
> All 10 transient raven poses (`ruffle`, `startle`, `hop`, `peck`, `bow`, `alert`, `preen`, `fly`, `flap`, `caw`) have been converted to pre-rendered grid sprite sheets and verified. `idle` and `sleep` remain on the layered `Stack` renderer. All client tests (94/94) and backend tests (31/31) pass clean.

**Specs are decisions, not suggestions.** **A blocker is a filing event, not a licence to re-choose on the user's behalf.**

**Line numbers are anchors measured August 8, 2026** — re-grep rather than trusting them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`. No raw hex in widget code, no ad-hoc `Duration`.
3. **Every animation needs an `AppMotion.reduce(context)` path** — a static frame, never a faster animation.
4. **Text scale clamped 1.0–1.3.** **Touch targets ≥ 48 dp** (M4).
5. **T6 touches no backend.** `functions/` and `firestore.rules` are out of scope; if you are editing them you have left the spec — STOP.
6. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** |
| Client tests | `flutter test` | **91/91 committed** — 94/94 with the uncommitted pilot in the tree |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **31/31** |
| iOS release | `flutter build ios --release --no-codesign` | succeeds, `Runner.app` **44.0 MB** |

### ⚠️ Five traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, **never bare `flutter analyze`** — the bare form reports ~678 errors from vendored plugin source under gitignored `build/`.
2. **Analyze ≠ compile.** Only `flutter test` or `flutter build` surfaces a broken dependency. A package resolving proves nothing.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions run build`.
4. **BSD `sed` does not support `\b`** — silently matches nothing and exits 0. Use `python3`.
5. **`Image.asset` loads no bytes under `flutter test`.** `find.byType(Image)` counts widgets whether or not art exists, and a golden render of the mascot comes out **blank**. Verify art by decoding the PNG (`test/helpers/png_decoder.dart`) or on a simulator. **This applies to sprite sheets too** — a widget test can prove the frame *index* is right, never that the frame *looks* right.

---

## 2. Task T6 — Pre-rendered frame sequences for transient poses

**What this means for the user:** the crow's reactions currently move by rotating and sliding flat layers. That can slide and tilt, but it cannot squash, stretch or ruffle — so the motion reads a bit mechanical. Pre-drawn frames let the animation do things geometry cannot.

### What exists today
`lib/widgets/raven_mascot.dart` renders a `Stack` of `Image.asset` layers — `body`, `wing`, `wing_up`, `eye_open`, `eye_closed`, `beak_open` — wrapped in `Transform.translate/rotate/scale`, driven by three `AnimationController`s. Twelve poses: `sleep`, `idle`, `hop`, `ruffle`, `fly`, `alert`, `peck`, `preen`, `startle`, `bow`, `caw`, `flap`. Assets total **304 KB** across three densities. `lib/widgets/raven_pose_host.dart` owns pose orchestration via `playRavenPose(pose, {required onceKey, hold})`.

### ⚠️ Do not convert all twelve poses — the split is deliberate

**Keep `idle` and `sleep` on the existing layered renderer. Convert only the ten transient poses.**

This is not a shortcut, it is the correct division:
- **Resting poses need *stochastic* behaviour.** `idle` blinks and tilts at randomised intervals, driven by its own controller. A fixed frame loop cannot do "blink at an unpredictable moment" without either a very long sheet or a visible cycle. Layers do it for free by swapping `eye_open`/`eye_closed`.
- **Transient poses need *authored* behaviour.** `peck`, `ruffle`, `preen`, `startle`, `flap` are exactly where deformation matters and where transforms fall short. They play once, on demand, with a fixed shape.

Two renderers, each doing what it is good at. Say so in a comment so a later pass does not "unify" them.

### Architecture — sprite sheets, not loose frames

**One PNG per pose containing all its frames in a grid**, not N separate files.

| Decision | Value | Why |
|---|---|---|
| Cell size | **256×256** | The mascot renders at 48–96 dp; at 3× that is 288 physical px worst case. 256 is the right ceiling — larger is wasted. |
| Densities | **One only** — no `2.0x`/`3.0x` | A single 256 px source scaled by Flutter is ample at these sizes, and three densities would triple an already large asset count. This deliberately differs from the layer system. |
| Layout | Left-to-right, top-to-bottom, no padding | Index → cell is then plain arithmetic. |
| Frames per pose | **6–10** | At `AppMotion.fast` (180 ms) 6 frames is 33 ms each; at `emphasis` (600 ms) 10 frames is 60 ms each. Beyond ~10 the file grows without reading better at this size. |

**Why a sheet rather than loose frames:** a 256×256 frame decodes to 256 KB in memory. Ten poses × 8 loose frames, all cached, is ~20 MB of decoded images and ten times the file handles and decode calls. A sheet is one decode, one cache entry, one handle per pose — and lets you precache exactly the poses a screen can play.

### Implementation

**Step 1 — declare the frame data in one place.** A `const` map in `raven_mascot.dart`, keyed by `RavenState`, giving sheet path, frame count, and columns:

```dart
class _PoseSheet {
  final String asset; final int frames; final int cols;
  const _PoseSheet(this.asset, this.frames, this.cols);
}
const Map<RavenState, _PoseSheet> _poseSheets = {
  RavenState.peck: _PoseSheet('assets/images/raven/frames/peck.png', 6, 3),
  // ... one per transient pose
};
```
A pose absent from this map falls through to the existing layered renderer — that is how `idle` and `sleep` keep working, and how you can convert poses one at a time.

**Step 2 — render a cell with `drawImageRect`.** A small `CustomPainter` — nothing like the 485-line path painter that was deleted:

```dart
canvas.drawImageRect(sheet, srcRect /* the current cell */, dstRect /* the widget box */, Paint());
```
`srcRect` = `Rect.fromLTWH((i % cols) * 256, (i ~/ cols) * 256, 256, 256)`. Use `FilterQuality.medium` so downscaling stays clean.

**Step 3 — drive the index from the controller that already exists.**
```dart
final i = (t * frames).floor().clamp(0, frames - 1);
```
`t` is the existing `_actionController.value` (0→1). **Use `floor()` with a `clamp`, not `round()`** — `round()` at `t = 1.0` yields `frames`, one past the end, and every frame gets uneven screen time except the first and last. This off-by-one is the single most likely defect in this task; the unit test in Validation exists specifically to catch it.

**Step 4 — load the sheet as a `dart:ui.Image`.** `Image.asset` will not do; you need the raw image for `drawImageRect`. Resolve via `AssetImage(...).resolve(ImageConfiguration.empty)` and keep the `ui.Image` in state. **Precache in `didChangeDependencies`**, not `build`. Precache only the poses that screen can play — the pose host knows which those are.

**Step 5 — reduced motion.** When `AppMotion.reduce(context)` is true, draw **frame 0** and never advance. Frame 0 must therefore be a sensible resting-adjacent pose, not a mid-motion extreme — state that requirement in the art brief.

**Step 6 — dispose.** `ui.Image` is not garbage-collected like a widget; call `dispose()` on every loaded sheet in the state's `dispose()`. Leaking these is a real memory leak, unlike a leaked `Image.asset`.

### Art generation

Append to `assets/images/raven/PROMPTS.md`. The existing layer art is the reference — **do not generate a new bird.**

1. **Use Veo as a motion reference, not as a source of assets.** Generate a short clip of the motion you want to see so there is a concrete target. Do **not** try to key frames out of the video: video carries no alpha, and keying a one-pixel anti-aliased brass rim fringes badly (this is exactly why Issue 35 rejected the GIF route).
2. **Produce each frame by editing the existing art**, the same image-to-image approach that Issue 33 used, on the same canvas:
   > Using the supplied `body.png` as an exact reference, redraw the crow at frame *N* of *M* of a *[peck / ruffle / …]* motion — *[describe the deformation for that frame]*. Keep the same canvas, scale, position, palette and outline weight. Change only the shape of the bird.
3. **Assemble the frames into a grid sheet** with any deterministic tool; record the exact command in `PROMPTS.md` so the sheet can be rebuilt.

**Character drift across frames is the known risk here** — it already bit the layer generation. Always edit from the same master, never from the previous frame, or the bird will visibly morph across the sequence.

### The rollout queue — nine poses, easiest deformation first

`ruffle` is done. Convert the rest **in this order**, because each group adds one new primitive to `render_frame()` and building them in dependency order means never writing two unproven primitives at once.

| Order | Pose | Motion brief | New primitive needed |
|---|---|---|---|
| 1 | **`startle`** | Sharp scale to ~1.08 with a lift, wing flares, then an overshoot settle. Reads as a flinch. | none — reuses `scale_x/y` + `wing_rot` + `translate_y` |
| 2 | **`hop`** | A vertical arc: up, brief hang, down, with the wing flaring on the rise and folding on descent. | `translate_y` |
| 3 | **`peck`** | Fast forward-and-down rotation of the whole bird, snapping back. Sharp in, soft out. | `rotate` |
| 4 | **`bow`** | Slow forward rotation to ~22°, a held beat, slow return. The ceremony pose — deliberately unhurried. | `rotate` |
| 5 | **`alert`** | Quick rotational snap toward the roster, hold ~2 frames, ease back. Eye stays open throughout. | `rotate` |
| 6 | **`preen`** | Wing rotates up to meet the body while the body tilts toward it; holds, then both return. Smug and slow. | `rotate` + `wing_rot` |
| 7 | **`fly`** | Rise with the wing sweeping through its full arc; the bird leaves frame-bottom slightly. | `translate_y` + `wing_rot` |
| 8 | **`flap`** | Alternate `wing` and `wing_up` every frame or two while rising — a real two-frame flap rather than a rotation. | **layer selection** |
| 9 | **`caw`** | Body scales up and tilts back while `beak_open` overlays the closed beak; a call. | **layer selection** + `rotate` + `scale` |

**Do `startle` first even though it needs no new primitive** — it proves the generalised pose registry in `build_sprite_sheets.py` works before any new deformation maths is layered on top. Getting the registry right on a pose with known-good primitives isolates the two risks.

**`flap` and `caw` are last for a reason:** they are the only two needing layer *selection* rather than layer *deformation*, which means `render_frame()` gains a different kind of parameter. If that turns out to be awkward, seven poses are already shipped and the finding can be filed without blocking them.

### 🚦 Preview and approval — per pose, blocking

**Every pose gets an animated preview shown to the user before its commit**, per the skill's §5 recipe. Do not batch nine poses and show them at the end: a wrong motion arc caught at pose two is a five-minute fix, and caught at pose nine it is eight more.

Group commits sensibly — one per pose, or one per primitive group — but **never commit a pose the user has not watched.**

### Validation

**Unit — the frame index, no rendering needed.** This is the falsifying test and it is pure arithmetic, so there is no excuse for skipping it:
- `t = 0.0` → frame `0`; `t = 1.0` → frame `frames - 1`; never `< 0` or `>= frames` for any `t` in `[0, 1]`.
- Sweep `t` in 0.01 steps across the whole range and assert the index stays in range and never decreases.
- **Assert `round()` semantics fail this test** — i.e. write it so a `round()` implementation would produce `frames` at `t = 1.0` and be caught.

**Asset integrity — reuse `test/helpers/png_decoder.dart`.** For every sheet in `_poseSheets`:
- width `== cols * 256` and height `== ceil(frames / cols) * 256`, so the declared geometry and the file agree. A mismatch here renders garbage cells, and nothing else would catch it.
- a real alpha channel is present;
- **rim contrast on frame 0 is still ≥ 4.5:1** against `#14110E`, reusing the T3 assertion. The whole mascot programme started with a bird at 1.02:1 — do not let regenerated art regress it.

**Memory budget.** Assert the sum of all sheet pixel areas × 4 bytes stays under **12 MB**. At 256 px cells and ≤10 frames per pose that is comfortable; the assertion exists so a later "let's use 512 px cells" is caught by CI rather than by a crash on an old phone.

**Widget contract.** Per converted pose: mid-animation renders a non-zero frame index; completion settles; `AppMotion.reduce` renders frame 0 and never advances; disposal throws nothing. Drive these off `RavenState.values` so a future pose cannot skip coverage.

**Unconverted poses still work.** `idle` and `sleep` must still render the layered `Stack` with the blink swap. This is the over-reach guard — the most likely collateral damage is breaking the resting states while wiring the new renderer.

**Size.** Measure `Runner.app` against the **44.0 MB** baseline and record the real number. Flat four-colour art should make each sheet tens of KB; if a sheet lands in the hundreds of KB, something is emitting gradients or noise and should be re-exported, not accepted.

**Simulator pass.** Play a full loop across three simulators (§4) and confirm each converted pose fires at its moment, plays once, and returns to resting.

### Blast radius
New `assets/images/raven/frames/*.png`; `lib/widgets/raven_mascot.dart` (frame map, painter, sheet loading, dispose); `assets/images/raven/PROMPTS.md`; `test/raven_mascot_test.dart`. **`raven_pose_host.dart` should not need to change** — T6 changes how a pose is drawn, not how it is chosen. If you find yourself editing the host, stop and re-read: that is a sign the split between orchestration and rendering is being broken.

---

## 3. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.** Issue 31 is the model — rebuilt from pre-fix source, the suite reported `expected null to equal 3` and `expected 'INTERNAL' to equal 'FAILED_PRECONDITION'`. **Record the observed failure output in the Resolved entry.**

**A test's name is not a test.** Issue 32 shipped a test called *"…rim contrast >= 4.5:1"* that asserted only that a file was non-empty. Read the assertion, not the title.

**Some correctness is invisible to the harness.** `Image.asset` loads nothing under `flutter test`. Verify artefacts directly — decode the PNG — or on a simulator.

**Do not tune a threshold to make a test pass.** Report the measured number and say the guard failed.

Pair every fix assertion with an **over-reach guard**.

---

## 4. Running 3 simulators for multiplayer testing

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

Must be `--debug`: `lobby_screen.dart` passes `debugEnabled: kDebugMode`, and the server refuses debug calls when false. **DEBUG: ADD 9 BOTS** is host-only and adds 9 unconditionally.

---

## 5. `.gitignore` — rules that must never be removed

**Decision rule.** (1) Secret, or identifies a developer's machine/account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.**

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA. |
| `**/google-services.json` · `**/GoogleService-Info.plist` | Firebase config. The plist is required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Source of the phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Must stay tracked:** the vendored Phosphor font + `LICENSE`, all raven PNGs + `PROMPTS.md`, `.firebaserc`, `ios/Podfile.lock`, both `xcshareddata/swiftpm/Package.resolved`. **After adding sprite sheets, confirm with `git status` that they are staged** — a silently-ignored asset is a blank bird on every other machine.

**New with T6, and currently undecided in the repo:**
- **`scripts/` must be committed.** `build_sprite_sheets.py` is the only way to rebuild a sheet from source art; losing it makes every sheet an unreproducible binary. Commit it with the pilot.
- **`scratch/` should be gitignored.** It holds throwaway preview artifacts. Add `scratch/` to `.gitignore` and verify with `git check-ignore -v scratch`. If a preview page is worth keeping as a reusable template, move it to `scripts/` rather than leaving it in a directory whose name promises it is disposable.

**Trap: `.swiftpm/` does not match `swiftpm/`** — the real Xcode paths have no leading dot.

---

## 6. Already delivered — do NOT rework

**Issues 1–35, Tasks T1–T5.** Points bearing on current work:
- **T4/T5** — the crow is the app's logo mascot, and has 12 poses wired to game moments through `raven_pose_host.dart`. The helper takes a **required `onceKey`**, because Firestore streams rebuild constantly and a bare `if (condition)` re-fires a pose on every tick. **T6 must not touch this.**
- **Issue 32/33** — the mascot is layered PNGs on a shared canvas, body filled behind a brass rim at 7.70:1 contrast. Regeneration prompts in `assets/images/raven/PROMPTS.md`.
- **Issue 35** — GIF/Veo was evaluated and rejected as a *delivery* format: video has no alpha and GIF alpha is 1-bit, so the rim fringes or jags. Veo remains useful as a **motion reference only**. Rive was rejected at **+4.5 MB measured** and because a `.riv` file can only be authored in a GUI editor — no agent can produce one.
- **Task T3** — `test/helpers/png_decoder.dart` decodes palette-indexed PNGs and computes WCAG contrast. **Reuse it for sheet validation.**
- **Issue 31** — settings no longer wipe each other; live in production. The server uses loose `!= null` — **never "simplify" to a falsy check**: `false` and `0` are legitimate values.
- **Issue 28/29** — `phosphor_flutter` can never be used (`IconData` is a `final class`); the app vendors the Phosphor Light font. **T2** — `cupertino_icons` deliberately absent.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` · Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `ITSAppUsesNonExemptEncryption = false` · `GoogleService-Info.plist` required on disk but gitignored · `.env` ships in the IPA so **`USE_EMULATOR` must be `false`** for testers.

---

## 7. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field (M5); **Vote's CONFIRM** is bottom-anchored via `Expanded`+`SafeArea`.
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **Entry-form logo uses `SizedBox` + `FittedBox`**, not `Transform.scale` — the latter does not change layout size.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale.**
- **House Rules non-host gating uses `IgnorePointer` + `Opacity(0.5)`.** The server rejects non-host writes regardless.
- **The mascot's head tilt is whole-body**, a deliberate simplification for a single-silhouette design.
- **After T6, two renderers coexist by design** — layered for resting poses, sprite sheets for transient ones. Do not unify them.

---

## 8. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through callables; `firestore.rules` denies client room writes.
- **Portrait-locked on phones**; **text scale clamped 1.0–1.3** (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.**
- **`_familyFriendlyOnly` is client-local and never synced.**
- **`RavenMascot`'s constructor signature (`state`, `size`) is fixed**, and `playRavenPose`'s `onceKey` stays required.
- **"Forgery Rounds" maps to `sabotageAnswersCount`.**

---

## 9. Where the contracts live

`ongoing_general_errors.md` was consolidated on August 7 from 903 lines to ~140. It is the live queue plus the traps that still bite — **not** a history. Do not re-expand it with delivered work; record outcomes in the design doc that owns the behaviour.

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Full history of any resolved item | `git log` |
| Backend write contract, rules, identity | `design_database_and_security.md` — **§7 is the `null` ≠ absent contract** |
| Card passing, disconnect recalc, input validation | `design_rotation_engine.md` §5 |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` §4 |
| Palette, typography, motif, icons, mascot, UI programme | `design_ui_direction.md` — **T6 must update the mascot block** |
| Prompt decks · duplicate answers | `design_prompt_system.md` · `design_semantic_integrity.md` |
| Mascot art prompts | `assets/images/raven/PROMPTS.md` — **T6 appends the frame briefs** |
| PNG decoding / contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 10. Feedback loop — what past specs got wrong

- **A test's name is not a test.** A contrast test once asserted only that a file was non-empty — the exact guard for the bug being fixed, absent while reading as present.
- **Approval gates get skipped under momentum.** Artwork shipped unseen because sign-off lived in a checklist. State gates inline, in the implementation section, marked blocking.
- **A cross-language `undefined` check is not a null check.** The TypeScript emulator suite structurally could not produce the payload the Dart client sends.
- **Resolution is not compilation.** A package that resolves may still fail to build — and a package's *documented* API may not be the one it ships.
- **Layout overflow must be measured, not estimated** — estimated ~275 dp, measured **593 dp**.
- **A ruling is only as durable as the test that pins it.**
- **Some correctness is invisible to the harness.** Verify the artefact directly.
- **Pilot the risky part before committing to the whole.** T6 converts one pose and compares before doing ten — the cost of being wrong about frames-versus-transforms is nine poses of wasted art.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §3. Observe the falsifying test fail against the broken state.
    For anything the harness cannot see, decode the artefact or check a simulator.
    Then the full §1 battery.
(4) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including observed
    failure output and measured numbers. Sync any design doc whose behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **Pilot committed on its own** before the rollout begins.
- [ ] `scripts/build_sprite_sheets.py` generalised to a pose registry — adding a pose is a data change, not a code change.
- [ ] All nine remaining transient poses converted in the §2 order; `idle` and `sleep` untouched.
- [ ] **🚦 Every pose previewed as an animated GIF and approved by the user before its commit** (skill §5).
- [ ] `.agents/skills/mascot_pose_creation/SKILL.md` followed and kept accurate if the pipeline changes.
- [ ] Frame-index unit test passes and is written so a `round()` implementation would fail it.
- [ ] Per pose: frame 0 matches the resting bounding box; no opaque pixel touches a cell border in any frame.
- [ ] Sheet integrity asserted for every entry in `_poseSheets`: declared geometry matches file dimensions, alpha present, frame-0 rim contrast ≥ 4.5:1.
- [ ] Total decoded sheet memory asserted under **12 MB**.
- [ ] `idle` and `sleep` still render the layered stack with the blink swap — the over-reach guard.
- [ ] `AppMotion.reduce` renders frame 0 and never advances, for every converted pose.
- [ ] Every loaded `ui.Image` is disposed; pumping the widget away throws nothing.
- [ ] `raven_pose_host.dart` unchanged.
- [ ] App-size delta measured against the **44.0 MB** baseline and recorded — not estimated.
- [ ] Three-simulator playthrough: every converted pose fires, plays once, returns to resting.
- [ ] `PROMPTS.md` gains the frame briefs and the sheet-assembly command; `design_ui_direction.md`'s mascot block records the two-renderer split.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 91 + new** · functions build clean · `npm --prefix functions test` **31/31**.
- [ ] Issue 35 moved to Resolved; one commit per pose batch. Guide rewritten to **Queue Complete** or the next queue.
