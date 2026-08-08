# `bow.png` — edit prompt

**A slow, formal bow.  Fires when the Truth is revealed and when honours are read.**

Paste the block below into nano banana together with `bow.png`.

---

```text
This image is a sprite sheet for a 2D game mascot: a simple, bold, flat-vector crow
in a Victorian style. It contains 8 animation frames in a 4 × 2 grid, read left
to right and then top to bottom. Each cell is exactly 256 × 256 pixels and the whole
sheet is 1024 × 512 pixels.

Redraw the frames so the animation reads clearly as: a slow, formal bow.

Each frame should show:
  Frame 0 (row 0, column 0) - the bird at complete rest
  Frame 1 (row 0, column 1) - beginning to lean forward
  Frame 2 (row 0, column 2) - leaning further, head lowering
  Frame 3 (row 0, column 3) - a deep bow — head well down, body tipped forward
  Frame 4 (row 1, column 0) - held at the deepest point of the bow
  Frame 5 (row 1, column 1) - beginning to rise
  Frame 6 (row 1, column 2) - almost upright again
  Frame 7 (row 1, column 3) - back at complete rest

Make the motion ease rather than step evenly: build to the strongest frame, then
settle back more gradually than you built up.

Keep all of the following exactly as they are:

- Canvas 1024 × 512 pixels, cells exactly 256 × 256, 4 columns by 2 rows, no padding
  or gaps between cells.
- The character's design and proportions. This is the same bird in every frame -
  do not restyle it, do not change its shape language, do not redraw it as a
  different crow.
- The palette: body fill #2D2925, brass outline #C6A14B roughly 2-3 pixels thick,
  eye ivory #F5EEDB with a #14110E pupil, beak brass #C6A14B.
- Flat colour only. No gradients, no shading, no texture, no drop shadows, no glow.
- A fully transparent background with soft 8-bit alpha edges. Do not flatten onto
  a colour and do not use hard 1-bit transparency.
- The bird stays centred in its cell at the same scale throughout. Do not zoom,
  crop or reframe.

Also observe these limits:

- Frame 0 must show the bird at complete rest, and the final frame must return to
  that same resting pose. These two frames are what the animation blends out of
  and back into, so they must match.
- Nothing may touch or cross a cell edge. In this sheet the artwork currently has
  31 px of clearance at the top, 16 px at the bottom, 3 px on the left and 28 px on the
  right. Stay inside that.
- Keep the brass outline bright. It is what makes the bird visible against the very
  dark background it sits on, so do not darken or thin it.
- Movement should be carried by the whole silhouette - the body leaning, stretching,
  compressing or turning. The wing and beak are small details and cannot carry the
  motion on their own, though they should move along with it.

Output the complete sheet at 1024 × 512 pixels with the same 4 × 2 grid.
```

---

## Reference

| | |
|---|---|
| Sheet | **1024 × 512 px** · cells **256 × 256** · **4 × 2** grid · **8** frames |
| Reading order | left → right, then top → bottom |
| Clearance left before clipping | top **31px** · bottom **16px** · left **3px** · right **28px** |
| Palette | body `#2D2925` · outline `#C6A14B` · eye `#F5EEDB` / pupil `#14110E` |
| Background it sits on | `#14110E` |

**This sheet is especially tight on the left edge** — there is almost no room to make the bird larger or move it further that way.

**Each frame is a complete flat picture of the bird** — there are no layers here. If the beak should open or the wing should lift, simply draw it that way in the frame. The layering rules that apply elsewhere in the project do not apply to these sheets.
