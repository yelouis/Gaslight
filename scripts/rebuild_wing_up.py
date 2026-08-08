#!/usr/bin/env python3
"""
Rebuild wing_up.png -- the raised wing used by flap/fly.

The previous version read as a leaf or a single feather: too narrow, close to
vertical, and appearing to sprout from the top of the back rather than hinging
at the shoulder. It cleared the numeric targets (mass, share outside the body)
while still not looking like a wing, which is why those numbers were necessary
but not sufficient.

This builds a broad wing blade as a filled shape with the same brass rim weight
as the rest of the bird:

  * anchored at the shoulder, where wing_folded attaches, so it visibly belongs
    to the body rather than floating above it;
  * swept up and back rather than straight up, which is what a wing at the top
    of a beat actually does;
  * a convex leading edge and a concave trailing edge -- the asymmetry is what
    separates "wing" from "leaf";
  * widest near the base and tapering to a rounded tip.

The interior is body-dark on a dark background, exactly like the bird itself, so
the brass rim is what carries the silhouette. That is consistent with the rest
of the character.

Run:  python3 scripts/rebuild_wing_up.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sprite_sheets import read_png, write_png  # noqa: E402

BASE = 'assets/images/raven'
FILL = (0x2D, 0x29, 0x25)
RIM = (0xC6, 0xA1, 0x4B)

# All geometry in 1x (256 px) space; scaled per density.
SHOULDER = (102.0, 132.0)  # tucked behind the shoulder where wing_folded meets the body
TIP = (38.0, 72.0)         # up and swept back, not vertical
BASE_HALF_WIDTH = 30.0     # broad enough to read as a wing, not a horn
BELLY = 28.0               # leading-edge bow; the asymmetry is what says 'wing'
RIM_PX = 3.0

DENSITIES = [('', 1), ('2.0x/', 2), ('3.0x/', 3)]


def bezier(p0, p1, p2, t):
    u = 1 - t
    return (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


def blade_polygon(scale, steps=160):
    """Leading edge bows out, trailing edge cuts back in -- a wing, not a leaf."""
    sh = (SHOULDER[0] * scale, SHOULDER[1] * scale)
    tip = (TIP[0] * scale, TIP[1] * scale)
    hw = BASE_HALF_WIDTH * scale
    belly = BELLY * scale

    ax, ay = tip[0] - sh[0], tip[1] - sh[1]
    length = math.hypot(ax, ay)
    ux, uy = ax / length, ay / length          # along the wing
    px, py = -uy, ux                           # perpendicular

    base_out = (sh[0] + px * hw, sh[1] + py * hw)
    base_in = (sh[0] - px * hw, sh[1] - py * hw)

    # Leading edge: bulge outward around the midpoint.
    lead_ctrl = (sh[0] + ux * length * 0.55 + px * (hw + belly),
                 sh[1] + uy * length * 0.55 + py * (hw + belly))
    # Trailing edge: pull inward, so the blade narrows behind.
    trail_ctrl = (sh[0] + ux * length * 0.45 - px * (hw * 0.15),
                  sh[1] + uy * length * 0.45 - py * (hw * 0.15))

    pts = [bezier(base_out, lead_ctrl, tip, i / steps) for i in range(steps + 1)]
    pts += [bezier(tip, trail_ctrl, base_in, i / steps) for i in range(1, steps + 1)]
    return pts


def inside(poly, x, y):
    n = len(poly)
    hit = False
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            hit = not hit
        j = i
    return hit


def dist_to_edge(poly, x, y):
    best = 1e9
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        L2 = dx * dx + dy * dy
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / L2))
        best = min(best, math.hypot(x - (x1 + t * dx), y - (y1 + t * dy)))
    return best


def build(density_dir, scale):
    size = 256 * scale
    poly = blade_polygon(scale)
    rim = RIM_PX * scale
    ss = 2  # 2x2 supersample for clean edges

    out = bytearray(size * size * 4)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    x0, x1 = max(0, int(min(xs)) - 4), min(size, int(max(xs)) + 5)
    y0, y1 = max(0, int(min(ys)) - 4), min(size, int(max(ys)) + 5)

    for y in range(y0, y1):
        for x in range(x0, x1):
            cov_fill = 0
            cov_rim = 0
            for sy in range(ss):
                for sx in range(ss):
                    fx = x + (sx + 0.5) / ss
                    fy = y + (sy + 0.5) / ss
                    if not inside(poly, fx, fy):
                        continue
                    if dist_to_edge(poly, fx, fy) <= rim:
                        cov_rim += 1
                    else:
                        cov_fill += 1
            total = cov_fill + cov_rim
            if total == 0:
                continue
            a = int(round(255 * total / (ss * ss)))
            col = RIM if cov_rim >= cov_fill else FILL
            i = (y * size + x) * 4
            out[i:i + 4] = bytes((col[0], col[1], col[2], a))

    path = os.path.join(BASE, density_dir, 'wing_up.png')
    with open(path, 'wb') as f:
        f.write(write_png(size, size, bytes(out)))

    opaque = sum(1 for i in range(size * size) if out[i * 4 + 3] > 40)
    print(f'  {path}: {size}x{size}, {opaque} opaque px')
    return path


def report():
    w, h, base = read_png(os.path.join(BASE, 'body_base.png'))
    bset = {(x, y) for y in range(h) for x in range(w) if base[(y * w + x) * 4 + 3] > 40}
    _, _, wu = read_png(os.path.join(BASE, 'wing_up.png'))
    pts = {(x, y) for y in range(h) for x in range(w) if wu[(y * w + x) * 4 + 3] > 40}
    outside = len(pts - bset)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    print(f'\n1x: {len(pts)} px, bbox=({min(xs)},{min(ys)})-({max(xs)},{max(ys)}), '
          f'outside body_base: {outside} ({100 * outside / len(pts):.0f}%)')


def main():
    print('wing_up (blade anchored at the shoulder, swept up and back):')
    for d, s in DENSITIES:
        build(d, s)
    report()


if __name__ == '__main__':
    main()
