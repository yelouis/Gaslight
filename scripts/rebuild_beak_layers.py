#!/usr/bin/env python3
"""
Rebuild beak_open.png and beak_semi_open.png from beak_closed.png.

Why derive rather than draw: the previous open/semi-open beaks were authored
independently of the closed one and came out fragmented -- ragged mandible
edges plus stray slivers where the mouth line should be, and ~18% partial-alpha
pixels against the closed beak's 4%. Deriving them from the closed art
guarantees identical edge quality and shape language, and makes the result
reproducible.

Method: beak_closed.png decomposes into exactly three connected components --
the upper mandible (with its nostril), the lower mandible, and a small brow
stroke above. To open the beak, rotate ONLY the upper mandible about the hinge
where the two mandibles meet at the back of the beak. The lower mandible and
the brow stay put, which is how a real beak opens.

Run:  python3 scripts/rebuild_beak_layers.py
"""

import math
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sprite_sheets import read_png, write_png  # noqa: E402

BASE = 'assets/images/raven'

# Hinge in 1x (256 px) coordinates: where the upper and lower mandibles meet at
# the back of the beak. Scaled per density below.
HINGE_1X = (165.0, 95.0)

# Opening angles, degrees. Negative rotates the tip upward on screen (y grows
# downward), which is the direction a beak opens.
ANGLES = {'beak_open': -20.0, 'beak_semi_open': -10.0}

DENSITIES = [('', 1), ('2.0x/', 2), ('3.0x/', 3)]


def components(px, w, h, alpha_min=90):
    """Connected components of sufficiently-opaque pixels, largest first."""
    seen = bytearray(w * h)
    out = []
    for sy in range(h):
        for sx in range(w):
            i = sy * w + sx
            if seen[i] or px[i * 4 + 3] <= alpha_min:
                continue
            q = deque([(sx, sy)])
            seen[i] = 1
            blob = []
            while q:
                x, y = q.popleft()
                blob.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            j = ny * w + nx
                            if not seen[j] and px[j * 4 + 3] > alpha_min:
                                seen[j] = 1
                                q.append((nx, ny))
            out.append(blob)
    out.sort(key=len, reverse=True)
    return out


def sample(px, w, h, fx, fy):
    """Bilinear sample with premultiplied alpha, so edges stay clean."""
    x0, y0 = math.floor(fx), math.floor(fy)
    tx, ty = fx - x0, fy - y0
    acc = [0.0, 0.0, 0.0, 0.0]
    for dy in (0, 1):
        for dx in (0, 1):
            x, y = x0 + dx, y0 + dy
            wgt = (tx if dx else 1 - tx) * (ty if dy else 1 - ty)
            if wgt <= 0 or not (0 <= x < w and 0 <= y < h):
                continue
            i = (y * w + x) * 4
            a = px[i + 3] / 255.0
            acc[0] += px[i] * a * wgt
            acc[1] += px[i + 1] * a * wgt
            acc[2] += px[i + 2] * a * wgt
            acc[3] += a * wgt
    if acc[3] <= 1e-6:
        return (0, 0, 0, 0)
    r = min(255, int(round(acc[0] / acc[3])))
    g = min(255, int(round(acc[1] / acc[3])))
    b = min(255, int(round(acc[2] / acc[3])))
    return (r, g, b, min(255, int(round(acc[3] * 255))))


def build(density_dir, scale, name, angle_deg):
    src = os.path.join(BASE, density_dir, 'beak_closed.png')
    w, h, px = read_png(src)

    comps = components(px, w, h)
    if len(comps) < 2:
        raise SystemExit(f'{src}: expected >=2 components, found {len(comps)}')

    # Largest = upper mandible. Everything else (lower mandible, brow) stays put.
    upper = set(comps[0])

    # Layer holding only the upper mandible, and one holding the rest.
    up = bytearray(w * h * 4)
    rest = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            if px[i + 3] == 0:
                continue
            dst = up if (x, y) in upper else rest
            dst[i:i + 4] = px[i:i + 4]

    hx, hy = HINGE_1X[0] * scale, HINGE_1X[1] * scale
    # Inverse rotation: for each destination pixel, find where it came from.
    ca, sa = math.cos(-math.radians(angle_deg)), math.sin(-math.radians(angle_deg))

    out = bytearray(rest)  # start from the fixed parts
    for y in range(h):
        for x in range(w):
            dx, dy = x - hx, y - hy
            sx = dx * ca - dy * sa + hx
            sy = dx * sa + dy * ca + hy
            r, g, b, a = sample(up, w, h, sx, sy)
            if a == 0:
                continue
            i = (y * w + x) * 4
            da = out[i + 3]
            if da == 0:
                out[i:i + 4] = bytes((r, g, b, a))
            else:  # source-over onto whatever fixed part is already there
                af = a / 255.0
                out[i] = int(round(r * af + out[i] * (1 - af)))
                out[i + 1] = int(round(g * af + out[i + 1] * (1 - af)))
                out[i + 2] = int(round(b * af + out[i + 2] * (1 - af)))
                out[i + 3] = min(255, int(round(a + da * (1 - af))))

    dst_path = os.path.join(BASE, density_dir, f'{name}.png')
    with open(dst_path, 'wb') as f:
        f.write(write_png(w, h, bytes(out)))

    opaque = sum(1 for i in range(w * h) if out[i * 4 + 3] > 40)
    partial = sum(1 for i in range(w * h) if 20 < out[i * 4 + 3] < 235)
    print(f'  {dst_path}: {w}x{h}, {opaque} opaque, '
          f'{partial} partial-alpha ({100 * partial / max(opaque, 1):.0f}%)')


def main():
    for name, angle in ANGLES.items():
        print(f'{name} (upper mandible rotated {angle:+.0f}deg about the hinge):')
        for density_dir, scale in DENSITIES:
            build(density_dir, scale, name, angle)


if __name__ == '__main__':
    main()
