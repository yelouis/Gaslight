---
name: Creating a Raven Mascot Pose
description: The end-to-end pipeline for adding an animated pose to the crow mascot — composing frames from the existing layer art, building the sprite sheet, rendering an animated preview for the user to approve, wiring it into the widget, and validating it. Use this whenever a new mascot pose is requested or an existing one is converted from Transform-based motion to frames.
---

# Creating a Raven Mascot Pose

The crow (`lib/widgets/raven_mascot.dart`) animates in two different ways, deliberately:

- **Resting poses — `idle` and `sleep` — stay on the layered `Transform` renderer.** They need *stochastic* behaviour: `idle` blinks and tilts at randomised intervals, which a fixed frame loop cannot do without a visible cycle. Do not convert these.
- **Transient poses — everything else — are pre-rendered sprite sheets.** They need *authored* behaviour: squash, stretch, ruffle, deformation that geometry cannot express.

This skill is about the second kind. Two renderers coexist on purpose; do not "unify" them.

---

## 1. The core principle: composite, never generate

**Frames are produced by warping the existing layer art, not by drawing new pictures.**

`scripts/build_sprite_sheets.py` reads `body.png`, `wing.png` and `eye_open.png` and composites them per frame with numeric deformation parameters. There is **no AI image generation in this pipeline**, and that is the point:

- The layers *are* the character. Warping them cannot drift.
- Generating each frame — with nano banana, Veo, or anything else — reintroduces **character drift across the sequence**, which already bit this project once during layer generation. A bird that subtly morphs frame to frame looks worse than no animation.
- It is deterministic. Re-running the script reproduces the sheet byte for byte, so a sheet can always be rebuilt from source.

**Veo has exactly one legitimate role: a motion reference.** Generate a clip to decide *what the motion should look like*, then express it as deformation numbers. Never key frames out of the video — video carries no alpha, and keying the one-pixel anti-aliased brass rim fringes badly. That is why Issue 35 rejected the GIF route.

---

## 2. Anatomy of a pose

A pose is three things:

| Piece | Where |
|---|---|
| Frame parameters — one tuple per frame | `scripts/build_sprite_sheets.py` |
| The sprite sheet PNG | `assets/images/raven/frames/<pose>.png` |
| Registration + timing | `_poseSheets` in `raven_mascot.dart`; `_defaultHold` in `raven_pose_host.dart` |

**Fixed conventions — do not vary them per pose:**
- **Cell size 256×256.** The mascot renders at 48–96 dp; at 3× that is 288 physical px worst case. Larger is wasted bytes.
- **One density only.** No `2.0x`/`3.0x` for sheets. A single 256 px source scaled by Flutter is ample, and three densities would triple the asset count. This deliberately differs from the layer system.
- **Frames laid left-to-right, top-to-bottom, no padding**, so index → cell is plain arithmetic.
- **6–10 frames.** At `AppMotion.fast` (180 ms) six frames is 30 ms each; at `emphasis` (600 ms) ten is 60 ms each. Beyond ten the file grows without reading better at this size.

**Frame 0 must be the exact resting pose** — all deformation parameters at their neutral values. This is not cosmetic:
- reduced motion draws frame 0 and never advances, so it must look like a bird at rest, not a mid-motion extreme;
- the pose has to blend cleanly out of and back into `idle`, and a frame 0 that does not match resting produces a visible jump at both ends.

The last frame should also return to (or very near) resting, for the same reason.

---

## 3. The layering rule — read this before anything else

> **The base layer contains only what never moves. Anything that animates is cut *out* of it and supplied as its own layer.**

A part layer **replaces** — it does not **add**. If the thing it is meant to replace is still painted into the base, you get two of them: overlay an open beak on a bird that already has a closed one and it grows a second beak.

**The eye is the reference implementation.** Under `eye_open.png`'s footprint, the base contains 0 light pixels and 1,444 dark ones — a clean socket. That is why blinking works, and it is the only part that ever animated correctly. (It took surgery to get there: T4 had to strip baked-in white eyeball pixels out of `body.png`.)

**This rule was discovered the expensive way.** The beak and the folded wing were painted into `body.png` — 1,149 and 522 brass pixels respectively — so every attempt to animate them was additive. Four review rounds were spent on new art and new motion parameters before anyone checked whether the parts were separable at all. **Before authoring a pose that moves a part, verify the part is not welded to the base:** sample the base layer under the part's footprint and confirm it is an empty socket, not a copy of the part.

**When splitting a part out of the base, prove the split was lossless** — composite all the layers back together and diff against the original; ≤2% of pixels differing. Without that check a refactor of the base silently degrades every pose that was already accepted.

---

## 4. What actually reads at 48–96 dp — the rule that governs every pose

**Carry the pose in the silhouette. Treat the wing and beak as garnish.**

Measured masses of the layers:

| Layer | Opaque px | Share of body |
|---|---|---|
| `body.png` | 23,705 | 100% |
| `wing.png` | 476 | **2.0%** |
| `wing_up.png` | 496 | **2.1%** |
| `beak_open.png` | 47 | **0.2%** |

The wing and beak are **line details, not limbs.** At the size the mascot renders, only whole-silhouette change reads: overall scale, rotation, translation, and deformation of the outline. Four poses were rejected in review for exactly this — `preen` and `fly` swung the wing so far it detached and read as a stray scratch; `flap` swapped `wing`↔`wing_up`, a 20 px difference nobody can see; `caw` overlaid a 47 px `beak_open` that sits **entirely inside** the body outline and therefore changes nothing.

**The test before you author anything: would this pose still read if the wing layer were deleted?** If not, the pose is resting on a detail that cannot hold it — re-express it as body motion.

**Hard limits, derived from the geometry:**
- The wing attaches to the body along its **right** edge near **(100, 118)** — the body centroid is at x=129. Pivot there. *(A previous version pivoted at (64, 153.6), the wing's free tip, which swings the attached end away from the body. Backwards.)*
- With a correct pivot the farthest wing pixel is ~72 px out, and the body outline leaves ~10 px of margin, so **`|wing_rot| ≤ 0.12 rad (≈7°)`**. Anything more detaches.
- Any new part intended to *break* the silhouette — an opening beak, a raised crest — must be drawn to extend **outside** the body outline. **A part drawn inside the outline is invisible when overlaid, no matter how large its motion parameter is.** This cost two full review rounds: `beak_open` was enlarged from 47 px to 115 px and still could not be seen, because 100% of it remained inside the body. Mass is not the metric — **share of pixels outside the silhouette** is.

**When commissioning a new part layer, state a measurable target and assert it.** For reference, the values set in T8:

| Layer | Minimum mass | Minimum share outside `body.png` |
|---|---|---|
| `wing_up.png` | ≥ 1,200 px (≈5% of body) | **≥ 40%** |
| `beak_open.png` | ≥ 300 px | **≥ 50%** |

**The body is a single solid blob, which constrains where a part can go.** Before briefing new art, measure the free space — the chest sits directly below the beak, so a beak must open *upward*; the flank has ~120 px of clearance above it, so a raised wing goes *up*. Compute the body's per-column top edge rather than assuming.

---

## 5. Deformation primitives

`render_frame()` accepts the parameters below. Keep every new one a pure numeric value so a frame stays fully described by its tuple.

| Primitive | What it does | Poses that need it |
|---|---|---|
| `scale_x`, `scale_y` | squash and stretch about the body centre | `ruffle`, `startle`, `caw` |
| `wing_rot` | rotate the wing about its shoulder — **cap `|wing_rot| ≤ 0.12` rad, see §4** | `ruffle`, `hop`, `preen`, `startle`, `fly` |
| `ruffle_wave` | horizontal displacement wave down the silhouette | `ruffle` |
| `rotate` | rotate the whole composite about the body base | `alert`, `peck`, `preen`, `bow`, `caw` |
| `translate_x`, `translate_y` | move the whole composite within the cell | `hop`, `fly`, `startle`, `flap` |
| layer selection | choose `wing` vs `wing_up`; `eye_open` vs `eye_closed`; overlay `beak_open` | `flap`, `caw`, and any blink beat |

**Rotation and translation must not clip.** The bird's bounding box inside a 256 px cell already sits close to the edges. Before authoring a pose that rotates more than ~20° or translates more than ~15% of the cell, check the composited frame still fits — the validation in §8 asserts this, but it is cheaper to catch while choosing numbers.

---

## 6. Authoring the frames

1. **Decide the motion arc in words first.** For `ruffle` it was: rest → expand → peak fluff → settle → recover → rest. Writing the arc before the numbers keeps the sequence from becoming a random walk.
2. **Write the parameter tuples**, one per frame, in a list. Follow the existing `ruffle` block as the model — it is commented per frame, and that comment is what makes the sequence editable six months later.
3. **Ease, do not step linearly.** Real motion accelerates and decelerates. `ruffle` peaks at frame 3 of 8 and eases back over five frames rather than four, which is what stops it looking mechanical.
4. **Add the pose to the registry in `scripts/build_sprite_sheets.py`** — keyed by pose name, holding its frame list and grid shape. Adding a pose is a data change, not a code change; if you find yourself editing `render_frame` for anything but a genuinely new primitive, stop and reconsider.
5. **Author keyframes, not every frame.** Set `target` (final frame count) and `out_cols` on the pose and the builder resamples your keys up to it with a cosine ease. Six hand-written keys is the right amount of authoring; twenty is not. Aim `target` at **~30 fps against the pose's hold** — below about 20 fps the motion visibly steps.
   - Flags in `DISCRETE` (`use_wing_up`, the beak variants, `eye`) snap at the midpoint instead of blending — you cannot half-swap a layer. Everything else glides.
   - A key that omits a parameter takes its **rest** value, and rest is `1.0` for the scales, not `0.0`.

```bash
python3 scripts/build_sprite_sheets.py
python3 scripts/build_frame_prompts.py   # geometry in the .md prompts is derived, not typed
```

Anything that restates a sheet's grid — the Dart `_poseSheets` entry, the preview table, the `.md` prompt, the T6.2 expectations — is a copy that will rot the next time the pose is re-timed. Derive it from `POSE_REGISTRY` instead of writing the numbers twice.

---

## 7. 🚦 Render a preview and show the user — this BLOCKS the commit

**Never commit a pose the user has not seen animate.** Artwork has shipped unseen on this project before and was wrong; the guard is that the preview happens before the commit, not after.

A widget test cannot do this — `Image.asset` loads no bytes under `flutter test`, so a golden render of the mascot comes out **blank**. Render from the sheet file instead.

**Verified recipe.** Split the sheet, then composite onto the real app background and loop:

```bash
POSE=ruffle; COLS=4; ROWS=2; N=8; FPS=16
mkdir -p /tmp/pose && rm -f /tmp/pose/f*.png
ffmpeg -y -loglevel error -i assets/images/raven/frames/$POSE.png \
  -vf "untile=${COLS}x${ROWS}" -frames:v $N /tmp/pose/f%02d.png
ffmpeg -y -loglevel error -framerate $FPS -i /tmp/pose/f%02d.png \
  -f lavfi -i color=c=0x14110E:s=256x256 \
  -filter_complex "[1][0]overlay=shortest=1,scale=320:320:flags=neighbor,split[a][b];[a]palettegen=reserve_transparent=0[p];[b][p]paletteuse" \
  -loop 0 /tmp/pose/${POSE}_preview.gif
```

Then send `/tmp/pose/<pose>_preview.gif` to the user with `display: "render"` so it plays inline.

- **`FPS` = frames ÷ hold-duration-in-seconds**, using the pose's `_defaultHold`. An 8-frame pose held 500 ms previews at 16 fps. Previewing at the wrong rate is the most common way to misjudge a pose.
- **`color=c=0x14110E`** is `AppColors.ground`. Judging a pose on a white or transparent background is misleading — the whole mascot programme started with a bird that was invisible against exactly this colour.
- **`flags=neighbor`** keeps the upscale crisp instead of blurring flat art.
- **GIF is correct *here* precisely because the preview never ships.** No alpha is needed over a solid background, and file size is irrelevant in `/tmp`. Do not read this as a reversal of Issue 35 — shipping GIFs was rejected for alpha and size reasons that do not apply to a throwaway review artifact.

**When replacing an existing Transform-based pose, show both side by side.** A dark HTML page looping old and new next to each other works well — if you build one worth reusing, keep it in `scripts/`, not `scratch/` (which is gitignored and disposable). A pose that is merely *different* is not an improvement; the user needs the comparison to judge.

Wait for explicit approval. If a pose is rejected, change the parameter tuples and re-render — do not touch the widget code.

---

## 8. Wire it up and validate

**Register** the pose in `_poseSheets` (asset path, frame count, columns). A pose absent from that map falls through to the layered renderer, which is how poses can be converted one at a time.

**Required assertions** — reuse `test/helpers/png_decoder.dart`:

1. **Declared geometry matches the file.** Width `== cols * 256`, height `== ceil(frames / cols) * 256`. A mismatch renders garbage cells and nothing else catches it.
2. **Frame index maths.** `t = 0.0` → frame `0`; `t = 1.0` → frame `frames - 1`; never out of range for any `t` in `[0, 1]`. **Use `floor().clamp()`, not `round()`** — `round()` yields `frames` at `t = 1.0`, one past the end. Write the test so a `round()` implementation fails it.
3. **Frame 0 is the resting pose** — its opaque bounding box should match `body.png`'s within a few pixels. This is what enforces §2's blend requirement.
4. **Rim contrast on frame 0 ≥ 4.5:1** against `#14110E`. The mascot programme began with a bird at 1.02:1; do not let a regenerated sheet regress it.
5. **No clipping.** No opaque pixel touches the cell border in any frame.
6. **Reduced motion** renders frame 0 and never advances.
7. **`idle` and `sleep` still render the layered stack** with the blink swap — the over-reach guard. The likeliest collateral damage is breaking the resting states while wiring a new sheet.
8. **Memory budget.** Total decoded sheet area × 4 bytes stays under **12 MB**.
9. **Silhouette containment.** Every opaque pixel of every frame falls inside a ~6 px dilation of `body.png`'s outline. **This is the assertion that catches a detached wing** — the failure mode that got four poses rejected — and nothing else in the suite covers it. A layer deliberately designed to break the outline (an opened beak) must be asserted to *fail* this check, not exempted from it.
10. **Wing-rotation cap.** No frame in the registry exceeds `|wing_rot| = 0.12` rad.

Then the full battery: `flutter analyze lib test` (0 errors) · `flutter test` · and measure `Runner.app` against the recorded baseline. A sheet of flat four-colour art should be tens of KB; hundreds of KB means gradients or noise crept in — re-export rather than accept it.

---

## 9. What not to do

- **Do not touch `raven_pose_host.dart`.** This skill changes how a pose is *drawn*, never how it is *chosen*. If you are editing the host, the split between orchestration and rendering is being broken.
- **Do not convert `idle` or `sleep`.**
- **Do not add density variants** for sheets.
- **Do not generate frames with an image model.** See §1.
- **Do not overlay a part onto a base that already contains it.** See §3 — this is what produced a two-beaked bird.
- **Do not skip the preview.** See §7.
- **Do not lower a validation threshold to make a sheet pass** — report the measured number and say the guard failed.
