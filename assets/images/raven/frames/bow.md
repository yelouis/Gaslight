# `bow.png` — frame grid constraints

**Pose:** `RavenState.bow` · ****The Truth is revealed**, and again when honours are read.**
`phase4_reveal.dart:320` and `game_over_screen.dart:69`. The ceremony pose — deliberately unhurried.

Edit this sheet directly in any image editor. The game reads it as-is at runtime — there is no build step between this file and what players see.

---

## Grid geometry — must not change

| Property | Value |
|---|---|
| Sheet size | **1024 × 512 px** |
| Cell size | **256 × 256 px** |
| Layout | **4 columns × 2 rows** |
| Frame count | **8** |
| Frame order | left → right, then top → bottom |
| Padding between cells | **none** |

**Changing any of these breaks the pose** unless `_poseSheets` in `lib/widgets/raven_mascot.dart` is updated to match:

```dart
RavenState.bow: _PoseSheet('assets/images/raven/frames/bow.png', 8, 4),
//                                                              frames ^   ^ columns
```

The 256 px cell size is hardcoded in `_PosePainter` and is **not** configurable per pose. Keep every cell exactly 256 × 256.

---

## Timing

| Property | Value |
|---|---|
| Hold duration in game | **600 ms** (`_defaultHold` in `raven_pose_host.dart`) |
| Time per frame | **75 ms** |
| Effective frame rate | **13.3 fps** |

Preview at this rate or you will misjudge the motion:

```bash
POSE=bow; COLS=4; ROWS=2; N=8; FPS=13
mkdir -p /tmp/pose && rm -f /tmp/pose/f*.png
ffmpeg -y -loglevel error -i assets/images/raven/frames/$POSE.png -vf "untile=${COLS}x${ROWS}" -frames:v $N /tmp/pose/f%02d.png
ffmpeg -y -loglevel error -framerate $FPS -i /tmp/pose/f%02d.png -f lavfi -i color=c=0x14110E:s=256x256 \
  -filter_complex "[1][0]overlay=shortest=1,scale=320:320:flags=neighbor,split[a][b];[a]palettegen=reserve_transparent=0[p];[b][p]paletteuse" \
  -loop 0 /tmp/pose/${POSE}_preview.gif
```

---

## Current artwork bounds

Measured across all 8 frames. Coordinates are **within a cell** (0–255), not the whole sheet.

| Frame | Position in grid | Art bounds in cell | Note |
|---|---|---|---|
| 0 | row 0, col 0 | (25,31)–(218,225) | **resting — must match frame 0 of every other pose** |
| 1 | row 0, col 1 | (19,35)–(221,228) |  |
| 2 | row 0, col 2 | (12,40)–(224,234) |  |
| 3 | row 0, col 3 | (3,48)–(227,239) |  |
| 4 | row 1, col 0 | (3,48)–(227,239) |  |
| 5 | row 1, col 1 | (11,41)–(224,235) |  |
| 6 | row 1, col 2 | (18,35)–(221,228) |  |
| 7 | row 1, col 3 | (25,31)–(218,225) | returns to rest |

**Union across all frames:** (3,31)–(227,239)

**Headroom before clipping:** left **3 px** · top **31 px** · right **28 px** · bottom **16 px**

> ⚠️ **This sheet is already tight on the left edge** (left 3px). There is almost no room to make the bird bigger or move it further that way — it will clip.

---

## Hard constraints — breaking these breaks the pose

1. **Frame 0 must be the bird at rest.** Reduced-motion users see *only* frame 0, and the pose blends out of and back into `idle` from it. If frame 0 is a mid-motion extreme, the bird visibly jumps at both ends and accessibility users get a permanently distorted bird.
2. **The last frame must return to rest** (or very near it), for the same blending reason.
3. **Nothing may touch a cell border.** Any opaque pixel at x=0, x=255, y=0 or y=255 will be visibly cut off. Watch the tight edges listed above.
4. **Stay inside the silhouette.** Every opaque pixel should sit within roughly 6 px of the bird's outline. A part that floats free of the body reads as a stray mark, not a limb — this is what got four poses rejected in review.
5. **Keep the brass rim contrast.** The rim must stay at least **4.5:1** against the app background `#14110E`. The shipped rim is `#C6A14B` at 7.70:1. Darkening it is how the mascot became invisible the first time.
6. **Transparent background, 8-bit alpha.** Save as PNG with alpha. Do not flatten onto a colour and do not use 1-bit transparency.
7. **Do not resize the canvas.** See the grid table above.

---

## Soft guidance

- **Ease, do not step linearly.** Real motion accelerates and decelerates. Peak the action around 40% of the sequence and spend the remainder easing back.
- **Carry the motion in the silhouette.** The wing and beak are small line details — at the size this renders (48–96 dp) they cannot carry a pose on their own. Scale, rotation and outline change are what read.
- **Check it small.** Preview at 320 px, but also glance at it at 64 px, which is roughly what players see.

---

## ⚠️ Regeneration will overwrite this file

`scripts/build_sprite_sheets.py` rebuilds sheets from the layer art and **silently destroys hand edits**. All poses are opted out of regeneration; confirm `bow` is still listed under the script's skip set before running it, and keep a copy of your edited sheet regardless.

---

## Validation

```bash
flutter test test/raven_mascot_test.dart   # geometry, contrast, containment, frame-0 rest
flutter test                                # full suite
```

Then hot-restart (not hot reload — asset changes need a restart) or rebuild:

```bash
flutter run -d "iPhone 17"
```
