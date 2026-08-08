#!/usr/bin/env python3
"""
Build emotional eye variants from the two existing eye layers.

The mascot only had eye_open (ivory circle, dark pupil, highlight) and
eye_closed (a brass arc curving down). Every pose therefore wore the same
neutral expression, which is why the reactions read as motion rather than
feeling. These three variants are derived from the existing art so the shape
language and edge quality stay identical -- nothing is drawn from scratch.

  eye_wide    scale eye_open up about its own centre .......... surprise / alarm
  eye_happy   eye_closed mirrored vertically -> an arc curving up ... joy / smug
  eye_angry   eye_open plus a brass brow slanting down toward the beak . intent

Run:  python3 scripts/build_eye_variants.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sprite_sheets import read_png, write_png  # noqa: E402

BASE = 'assets/images/raven'
RIM = (0xC6, 0xA1, 0x4B)

EYE_CENTRE_1X = (130.5, 77.5)   # centre of eye_open's bounding box
WIDE_SCALE = 1.20
BROW_A_1X = (110.0, 57.0)       # outer end, high
BROW_B_1X = (149.0, 73.0)       # inner end (toward the beak), low -> a scowl
BROW_HALF_1X = 5.4

DENSITIES = [('', 1), ('2.0x/', 2), ('3.0x/', 3)]


def sample(px, w, h, fx, fy):
    """Bilinear sample with premultiplied alpha."""
    x0, y0 = math.floor(fx), math.floor(fy)
    tx, ty = fx - x0, fy - y0
    acc = [0.0, 0.0, 0.0, 0.0]
    for dy in (0, 1):
        for dx in (0, 1):
            x, y = x0 + dx, y0 + dy
            wt = (tx if dx else 1 - tx) * (ty if dy else 1 - ty)
            if wt <= 0 or not (0 <= x < w and 0 <= y < h):
                continue
            i = (y * w + x) * 4
            a = px[i + 3] / 255.0
            acc[0] += px[i] * a * wt
            acc[1] += px[i + 1] * a * wt
            acc[2] += px[i + 2] * a * wt
            acc[3] += a * wt
    if acc[3] <= 1e-6:
        return (0, 0, 0, 0)
    return (min(255, int(round(acc[0] / acc[3]))),
            min(255, int(round(acc[1] / acc[3]))),
            min(255, int(round(acc[2] / acc[3]))),
            min(255, int(round(acc[3] * 255))))


def make_wide(px, w, h, scale):
    cx, cy = EYE_CENTRE_1X[0] * scale, EYE_CENTRE_1X[1] * scale
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            sx = (x - cx) / WIDE_SCALE + cx
            sy = (y - cy) / WIDE_SCALE + cy
            r, g, b, a = sample(px, w, h, sx, sy)
            if a:
                i = (y * w + x) * 4
                out[i:i + 4] = bytes((r, g, b, a))
    return out


HAPPY_LID = 0.42        # fraction of the eye height hidden by the lid


def make_happy(px, w, h, scale):
    """A squinting, smiling eye.

    A bare brass arc (the eye_closed treatment) disappears here, because the
    socket behind it is dark and there is no eyeball to sit against -- it reads
    as a missing eye with a squiggle in it. Instead keep the LOWER crescent of
    the ivory eyeball and cut the top away along an upward-curving lid. The
    bright crescent reads as a happy squint at 48-96 dp, where a thin stroke
    does not.
    """
    pts = [(x, y) for y in range(h) for x in range(w) if px[(y * w + x) * 4 + 3] > 20]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    cx = (x0 + x1) / 2.0
    half_w = max(1.0, (x1 - x0) / 2.0)
    lid = y0 + (y1 - y0) * HAPPY_LID

    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            if px[i + 3] == 0:
                continue
            # Lid curves upward at the outer edges, so the opening is a smile.
            t = (x - cx) / half_w
            cutoff = lid + (y1 - y0) * 0.22 * (t * t)
            if y < cutoff - 1.0:
                continue
            a = px[i + 3]
            if y < cutoff:           # soften the cut edge
                a = int(a * (y - (cutoff - 1.0)))
            out[i:i + 4] = bytes((px[i], px[i + 1], px[i + 2], a))
    return out


def make_angry(px, w, h, scale):
    """eye_open plus a brow bar slanting down toward the beak."""
    out = bytearray(px)
    ax, ay = BROW_A_1X[0] * scale, BROW_A_1X[1] * scale
    bx, by = BROW_B_1X[0] * scale, BROW_B_1X[1] * scale
    half = BROW_HALF_1X * scale
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    ss = 2
    for y in range(max(0, int(min(ay, by) - half - 2)), min(h, int(max(ay, by) + half + 3))):
        for x in range(max(0, int(min(ax, bx) - half - 2)), min(w, int(max(ax, bx) + half + 3))):
            cov = 0
            for sy in range(ss):
                for sx in range(ss):
                    fx, fy = x + (sx + 0.5) / ss, y + (sy + 0.5) / ss
                    t = max(0.0, min(1.0, ((fx - ax) * dx + (fy - ay) * dy) / L2))
                    d = math.hypot(fx - (ax + t * dx), fy - (ay + t * dy))
                    # taper the outer end so it reads as a brow, not a bar
                    if d <= half * (0.55 + 0.45 * t):
                        cov += 1
            if not cov:
                continue
            a = int(round(255 * cov / (ss * ss)))
            i = (y * w + x) * 4
            af = a / 255.0
            for k in range(3):
                out[i + k] = int(round(RIM[k] * af + out[i + k] * (1 - af)))
            out[i + 3] = min(255, int(round(a + out[i + 3] * (1 - af))))
    return out


def main():
    for density_dir, scale in DENSITIES:
        d = os.path.join(BASE, density_dir)
        w, h, eo = read_png(os.path.join(d, 'eye_open.png'))
        _, _, ec = read_png(os.path.join(d, 'eye_closed.png'))

        for name, data in (('eye_wide', make_wide(eo, w, h, scale)),
                           ('eye_happy', make_happy(eo, w, h, scale)),
                           ('eye_angry', make_angry(eo, w, h, scale))):
            path = os.path.join(d, f'{name}.png')
            with open(path, 'wb') as f:
                f.write(write_png(w, h, bytes(data)))
            opaque = sum(1 for i in range(w * h) if data[i * 4 + 3] > 40)
            print(f'  {path}: {w}x{h}, {opaque} opaque px')


if __name__ == '__main__':
    main()
