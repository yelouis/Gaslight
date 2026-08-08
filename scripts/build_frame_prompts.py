#!/usr/bin/env python3
"""
Regenerate assets/images/raven/frames/<pose>.md -- the nano banana edit prompts.

These prompts have to state the sheet's exact geometry: canvas size, cell grid,
frame count, reading order, and how much clearance the artwork has before it
would clip a cell edge. All of that changes whenever a pose is re-timed, and a
prompt carrying stale numbers is worse than no prompt -- it asks for a sheet the
game cannot slice. So the numbers are derived here rather than written by hand:

  * geometry and frame count come from POSE_REGISTRY, the same source the sheet
    builder and the Dart widget agree on;
  * clearance is measured off the generated PNG.

Only the creative intent is authored: one goal sentence per pose and the ordered
beats of the motion. Those beats are the registry's keyframes, so this file maps
each one onto the output frame it actually lands on after interpolation, and
tells the model the frames between them are in-betweens. That matters now that
sheets run to 20 frames -- enumerating every frame would be noise, and would
imply twenty distinct poses rather than a smooth arc.

Run:  python3 scripts/build_frame_prompts.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sprite_sheets import read_png, POSE_REGISTRY  # noqa: E402

FRAMES_DIR = 'assets/images/raven/frames'
CELL = 256

# When each pose fires in game, for the human reading the file.
TRIGGERS = {
    'ruffle': 'Fires on a correct guess.',
    'startle': 'Fires when the bird is caught out.',
    'hop': 'Fires when a player joins the room.',
    'peck': 'Fires when a vote is cast.',
    'bow': 'Fires at the end of a round.',
    'alert': 'Fires when the phase changes.',
    'preen': 'Fires when a player takes the lead.',
    'fly': 'Fires on the transition out of the lobby.',
    'flap': 'Fires on a win.',
    'caw': 'Fires when the game starts.',
}

GOALS = {
    'ruffle': 'a feather shake — the bird fluffs up and settles',
    'startle': 'a flinch — the bird is startled by something',
    'hop': 'a small hop in place',
    'peck': 'a quick downward peck',
    'bow': 'a slow, formal bow',
    'alert': 'the bird perks up sharply, noticing something',
    'preen': 'the bird grooms its flank, pleased with itself',
    'fly': 'a launch into flight',
    'flap': 'wingbeats in place — a celebration',
    'caw': 'a call — the bird opens its beak and caws',
}

# One beat per keyframe in POSE_REGISTRY, in order.
BEATS = {
    'ruffle': [
        'the bird at complete rest',
        'feathers just beginning to lift, body widening slightly',
        'puffing up further, feathers clearly raised',
        'peak fluff — widest and roundest, feathers fully raised',
        'the shake starting to subside',
        'feathers settling back down',
        'almost settled, a trace of residual fluff',
        'back at complete rest',
    ],
    'startle': [
        'the bird at complete rest',
        'a sharp recoil — the body snaps upward and back',
        'the peak of the flinch — most tense and extended, eyes wide',
        'beginning to relax',
        'a small overshoot as it settles',
        'back at complete rest',
    ],
    'hop': [
        'the bird at complete rest',
        'a crouch — the body compresses downward, gathering',
        'push-off — the body stretches upward as it leaves the ground',
        'rising, body extended, feet clear of the ground',
        'the apex — highest point, body at full stretch',
        'descending',
        'landing — a small compression as it touches down',
        'back at complete rest',
    ],
    'peck': [
        'the bird at complete rest',
        'the head and body thrust forward and down, eyes narrowing',
        'the full peck — lowest point, beak driven forward',
        'snapping back upward',
        'a slight overshoot past upright',
        'back at complete rest',
    ],
    'bow': [
        'the bird at complete rest',
        'beginning to lean forward',
        'leaning further, head lowering',
        'a deep bow — head well down, body tipped forward',
        'held at the deepest point of the bow',
        'beginning to rise',
        'almost upright again',
        'back at complete rest',
    ],
    'alert': [
        'the bird at complete rest',
        'a sharp perk — the body straightens and the head snaps around',
        'the peak of alertness — most upright and tense, eyes wide',
        'held, watching',
        'easing back down',
        'back at complete rest',
    ],
    'preen': [
        'the bird at complete rest',
        'the head begins to turn toward its own flank',
        'turning further, the body hunching around',
        'head tucked right into the flank, grooming, eyes contentedly squinted',
        'held there, a small nuzzling motion',
        'the head lifting away from the flank',
        'almost upright again',
        'back at complete rest',
    ],
    'fly': [
        'the bird at complete rest',
        'a crouch — the body compresses, gathering to jump',
        'push-off, the wing beginning to sweep upward',
        'climbing, the wing raised',
        'the top of the climb — highest point, wing fully raised',
        'the wing sweeping back down, still elevated',
        'dropping back toward the ground',
        'back at complete rest',
    ],
    'flap': [
        'the bird at complete rest, wing lowered',
        'the wing sweeping upward, the body lifting slightly',
        'the wing fully raised above the back, the body at its highest',
        'the wing sweeping back down, the body dropping',
        'the wing lowered, the body settling',
        'back at complete rest',
    ],
    'caw': [
        'the bird at complete rest, beak closed',
        'the head starting to thrust back and up, the beak just parting',
        'the beak wide open and the head thrown back — mid-call',
        'held at the peak of the call, beak still wide',
        'the beak closing, the head coming back down',
        'back at complete rest',
    ],
}


def measure_clearance(path, cols, rows):
    """Smallest gap between the artwork and its cell edge, over every cell."""
    w, h, px = read_png(path)
    best = {'top': CELL, 'bottom': CELL, 'left': CELL, 'right': CELL}
    for r in range(rows):
        for c in range(cols):
            ox, oy = c * CELL, r * CELL
            pts = [(x, y)
                   for y in range(oy, oy + CELL)
                   for x in range(ox, ox + CELL)
                   if px[(y * w + x) * 4 + 3] > 100]
            if not pts:
                continue
            xs = [p[0] - ox for p in pts]
            ys = [p[1] - oy for p in pts]
            best['top'] = min(best['top'], min(ys))
            best['bottom'] = min(best['bottom'], CELL - 1 - max(ys))
            best['left'] = min(best['left'], min(xs))
            best['right'] = min(best['right'], CELL - 1 - max(xs))
    return best


def anchor_indices(n_keys, n_frames):
    """Output frame each authored keyframe lands on after interpolation."""
    if n_frames <= n_keys:
        return list(range(n_keys))
    last = n_keys - 1
    return [round(k * (n_frames - 1) / last) for k in range(n_keys)]


def build(pose, spec):
    frames = spec.get('target') or len(spec['frames'])
    cols = spec['out_cols'] if spec.get('target') else spec['cols']
    rows = -(-frames // cols)
    w, h = cols * CELL, rows * CELL

    path = os.path.join(FRAMES_DIR, f'{pose}.png')
    clear = measure_clearance(path, cols, rows)

    beats = BEATS[pose]
    idx = anchor_indices(len(spec['frames']), frames)
    lines = []
    for k, beat in enumerate(beats):
        i = idx[k]
        lines.append(f'  Frame {i:>2} (row {i // cols}, column {i % cols}) - {beat}')
    anchors = '\n'.join(lines)

    goal = GOALS[pose]
    trigger = TRIGGERS[pose]
    title = goal[0].upper() + goal[1:]

    tween_note = (
        f'The {len(beats)} frames listed above are the key poses. The remaining\n'
        f'frames are in-betweens: interpolate smoothly from each key pose to the next so\n'
        f'the whole {frames}-frame sequence plays as one continuous motion, not as '
        f'{len(beats)} poses\nwith gaps.'
    ) if frames > len(beats) else (
        'Every frame is a key pose; there are no in-betweens.'
    )

    return f"""# `{pose}.png` — edit prompt

**{title}.  {trigger}**

Paste the block below into nano banana together with `{pose}.png`.

---

```text
This image is a sprite sheet for a 2D game mascot: a simple, bold, flat-vector crow
in a Victorian style. It contains {frames} animation frames in a {cols} × {rows} grid, read left
to right and then top to bottom. Each cell is exactly {CELL} × {CELL} pixels and the whole
sheet is {w} × {h} pixels.

Redraw the frames so the animation reads clearly as: {goal}.

The key poses are:
{anchors}

{tween_note}

Make the motion ease rather than step evenly: build to the strongest frame, then
settle back more gradually than you built up.

Keep all of the following exactly as they are:

- Canvas {w} × {h} pixels, cells exactly {CELL} × {CELL}, {cols} columns by {rows} rows, no padding
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
  {clear['top']} px of clearance at the top, {clear['bottom']} px at the bottom, {clear['left']} px on the left and {clear['right']} px on the
  right. Stay inside that.
- Keep the brass outline bright. It is what makes the bird visible against the very
  dark background it sits on, so do not darken or thin it.
- Movement should be carried by the whole silhouette - the body leaning, stretching,
  compressing or turning. The wing and beak are small details and cannot carry the
  motion on their own, though they should move along with it.

Output the complete sheet at {w} × {h} pixels with the same {cols} × {rows} grid.
```

---

## Reference

| | |
|---|---|
| Sheet | **{w} × {h} px** · cells **{CELL} × {CELL}** · **{cols} × {rows}** grid · **{frames}** frames |
| Reading order | left → right, then top → bottom |
| Clearance left before clipping | top **{clear['top']}px** · bottom **{clear['bottom']}px** · left **{clear['left']}px** · right **{clear['right']}px** |
| Palette | body `#2D2925` · outline `#C6A14B` · eye `#F5EEDB` / pupil `#14110E` |
| Background it sits on | `#14110E` |

**Each frame is a complete flat picture of the bird** — there are no layers here. If the beak should open or the wing should lift, simply draw it that way in the frame. The layering rules that apply elsewhere in the project do not apply to these sheets.

<!-- Generated by scripts/build_frame_prompts.py -- do not hand-edit the numbers;
     they are derived from POSE_REGISTRY and from the generated PNG. Edit the
     GOALS/BEATS tables in that script and re-run instead. -->
"""


def main():
    for pose, spec in POSE_REGISTRY.items():
        n_keys = len(spec['frames'])
        if len(BEATS[pose]) != n_keys:
            raise SystemExit(
                f'{pose}: {len(BEATS[pose])} beats authored but the registry has '
                f'{n_keys} keyframes -- they must correspond one to one.')
        out = os.path.join(FRAMES_DIR, f'{pose}.md')
        with open(out, 'w') as f:
            f.write(build(pose, spec))
        print(f'  {out}')


if __name__ == '__main__':
    main()
