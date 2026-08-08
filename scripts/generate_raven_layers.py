#!/usr/bin/env python3
"""Task T9 layer generation: extract body_base, beak_closed, wing_folded from body.png,
and generate beak_open and wing_up as vector art. All at 1x/2.0x/3.0x densities.

The base layer contains only what never moves. Anything that animates is cut out of it
and supplied as its own layer.
"""
import os
import sys
import math
import struct
import zlib

sys.path.append(os.path.join(os.path.dirname(__file__)))
import build_sprite_sheets as bss


def cubic_bezier(p0, p1, p2, p3, num_pts=30):
    pts = []
    for i in range(num_pts + 1):
        t = i / float(num_pts)
        inv = 1.0 - t
        x = inv**3 * p0[0] + 3 * inv**2 * t * p1[0] + 3 * inv * t**2 * p2[0] + t**3 * p3[0]
        y = inv**3 * p0[1] + 3 * inv**2 * t * p1[1] + 3 * inv * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def rasterize_layer(pts, width, height, ss=4, fill_color=(46, 42, 38, 255),
                    rim_color=None, rim_pts_range=None, rim_thickness=2.5):
    W, H = width * ss, height * ss
    poly = [(p[0] * ss, p[1] * ss) for p in pts]

    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    min_x, max_x = max(0, int(math.floor(min(xs)))), min(W - 1, int(math.ceil(max(xs))))
    min_y, max_y = max(0, int(math.floor(min(ys)))), min(H - 1, int(math.ceil(max(ys))))

    grid = [None] * (W * H)
    n = len(poly)
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            inside = False
            p1x, p1y = poly[0]
            for i in range(n + 1):
                p2x, p2y = poly[i % n]
                if y > min(p1y, p2y):
                    if y <= max(p1y, p2y):
                        if x <= max(p1x, p2x):
                            if p1y != p2y:
                                xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                            if p1x == p2x or x <= xinters:
                                inside = not inside
                p1x, p1y = p2x, p2y
            if inside:
                grid[y * W + x] = fill_color

    if rim_color and rim_pts_range:
        rim_poly = [(pts[i][0] * ss, pts[i][1] * ss) for i in rim_pts_range]
        r_thick_ss = rim_thickness * ss
        for i in range(len(rim_poly) - 1):
            x1, y1 = rim_poly[i]
            x2, y2 = rim_poly[i + 1]
            rmin_x = max(0, int(math.floor(min(x1, x2) - r_thick_ss)))
            rmax_x = min(W - 1, int(math.ceil(max(x1, x2) + r_thick_ss)))
            rmin_y = max(0, int(math.floor(min(y1, y2) - r_thick_ss)))
            rmax_y = min(H - 1, int(math.ceil(max(y1, y2) + r_thick_ss)))

            dx, dy = x2 - x1, y2 - y1
            len_sq = dx * dx + dy * dy
            if len_sq == 0:
                continue

            for y in range(rmin_y, rmax_y + 1):
                for x in range(rmin_x, rmax_x + 1):
                    if grid[y * W + x] is not None:
                        t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / len_sq))
                        px = x1 + t * dx
                        py = y1 + t * dy
                        dist = math.hypot(x - px, y - py)
                        if dist <= r_thick_ss:
                            grid[y * W + x] = rim_color

    pixels = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            r_acc, g_acc, b_acc, a_acc = 0, 0, 0, 0
            cnt = 0
            for sy in range(ss):
                for sx in range(ss):
                    gx = x * ss + sx
                    gy = y * ss + sy
                    p = grid[gy * W + gx]
                    if p is not None:
                        r_acc += p[0]
                        g_acc += p[1]
                        b_acc += p[2]
                        a_acc += p[3]
                        cnt += 1
            if cnt > 0:
                dst = (y * width + x) * 4
                pixels[dst] = int(round(r_acc / (ss * ss)))
                pixels[dst + 1] = int(round(g_acc / (ss * ss)))
                pixels[dst + 2] = int(round(b_acc / (ss * ss)))
                pixels[dst + 3] = int(round(a_acc / (ss * ss)))
    return pixels


# ─── T9 Layer Extraction ─────────────────────────────────────────────

def extract_layers_from_body(base_dir, scale, size, out_dir):
    """Extract body_base, beak_closed, and wing_folded from body.png at a given scale.

    Coordinate zones are defined at 1x (256×256) and scaled proportionally.
    Brass threshold: r > 150, g > 120, b < 110, a > 100.
    Dark socket fill: #2D2925 (45, 41, 37, 255).
    """
    body_path = os.path.join(base_dir, 'body.png')
    wing_path = os.path.join(base_dir, 'wing.png')

    # Read source at the target density
    if scale == 1.0:
        w, h, pix_body = bss.read_png(body_path)
        w_w, h_w, pix_wing = bss.read_png(wing_path)
    else:
        density_dir = os.path.join(base_dir, f'{scale}x')
        w, h, pix_body = bss.read_png(os.path.join(density_dir, 'body.png'))
        w_w, h_w, pix_wing = bss.read_png(os.path.join(density_dir, 'wing.png'))

    body_base = bytearray(pix_body)
    beak_closed = bytearray(w * h * 4)
    wing_folded = bytearray(w * h * 4)

    # Scale zone coordinates
    s = scale
    beak_x0, beak_x1 = int(160 * s), int(221 * s)
    beak_y0, beak_y1 = int(55 * s), int(106 * s)
    flank_x0, flank_x1 = int(50 * s), int(111 * s)
    flank_y0, flank_y1 = int(100 * s), int(176 * s)

    def is_brass(p):
        return p[0] > 150 and p[1] > 120 and p[2] < 110 and p[3] > 100

    # Phase 1: Extract beak — all brass pixels in beak zone
    beak_coords = set()
    for y in range(beak_y0, beak_y1):
        for x in range(beak_x0, beak_x1):
            p = bss.get_pixel(pix_body, w, h, x, y)
            if is_brass(p):
                beak_coords.add((x, y))

    for (x, y) in beak_coords:
        idx = (y * w + x) * 4
        p = bss.get_pixel(pix_body, w, h, x, y)
        beak_closed[idx:idx + 4] = bytes(p)
        # Fill socket with dark body color
        body_base[idx] = 45
        body_base[idx + 1] = 41
        body_base[idx + 2] = 37
        body_base[idx + 3] = 255

    # Phase 2: Extract wing folded — brass + wing.png opaque in flank zone
    wing_coords = set()
    for y in range(flank_y0, flank_y1):
        for x in range(flank_x0, flank_x1):
            p_body = bss.get_pixel(pix_body, w, h, x, y)
            p_wing = bss.get_pixel(pix_wing, w, h, x, y)
            if is_brass(p_body) or p_wing[3] > 0:
                wing_coords.add((x, y))

    for (x, y) in wing_coords:
        if (x, y) not in beak_coords:
            idx = (y * w + x) * 4
            p = bss.get_pixel(pix_body, w, h, x, y)
            wing_folded[idx:idx + 4] = bytes(p)
            body_base[idx] = 45
            body_base[idx + 1] = 41
            body_base[idx + 2] = 37
            body_base[idx + 3] = 255

    # Write outputs
    os.makedirs(out_dir, exist_ok=True)

    png_bb = bss.write_png(w, h, body_base)
    with open(os.path.join(out_dir, 'body_base.png'), 'wb') as f:
        f.write(png_bb)

    png_bc = bss.write_png(w, h, beak_closed)
    with open(os.path.join(out_dir, 'beak_closed.png'), 'wb') as f:
        f.write(png_bc)

    png_wf = bss.write_png(w, h, wing_folded)
    with open(os.path.join(out_dir, 'wing_folded.png'), 'wb') as f:
        f.write(png_wf)

    # Print stats
    beak_opaque = sum(1 for i in range(w * h) if beak_closed[i * 4 + 3] > 0)
    wing_opaque = sum(1 for i in range(w * h) if wing_folded[i * 4 + 3] > 0)
    beak_zone_brass = sum(
        1 for y in range(beak_y0, beak_y1)
        for x in range(beak_x0, beak_x1)
        if is_brass(bss.get_pixel(body_base, w, h, x, y))
    )
    flank_zone_brass = sum(
        1 for y in range(flank_y0, flank_y1)
        for x in range(flank_x0, flank_x1)
        if is_brass(bss.get_pixel(body_base, w, h, x, y))
    )

    print(f"  body_base.png: {w}x{h}, beak_zone_brass_remaining={beak_zone_brass} (<50), "
          f"flank_zone_brass_remaining={flank_zone_brass} (<50)")
    print(f"  beak_closed.png: {beak_opaque} opaque px")
    print(f"  wing_folded.png: {wing_opaque} opaque px")

    return body_base, beak_closed, wing_folded


# ─── T8 Vector Art Generation (wing_up and beak_open) ────────────────

def generate_vector_layers(scale, size, out_dir):
    """Generate wing_up.png and beak_open.png as vector art at the given scale."""
    # wing_up: Shoulder at (100, 118), sweeping up-left to (56, 46)
    outer_wing = cubic_bezier((100, 118), (88, 75), (72, 52), (56, 46), 40)
    tip_wing = cubic_bezier((56, 46), (48, 56), (44, 72), (48, 85), 20)
    inner_wing = cubic_bezier((48, 85), (60, 105), (76, 122), (98, 126), 40)
    base_wing = cubic_bezier((98, 126), (102, 124), (102, 120), (100, 118), 10)
    wing_pts = outer_wing + tip_wing[1:] + inner_wing[1:] + base_wing[1:]
    wing_rim_range = range(0, len(outer_wing) + len(tip_wing) - 1)

    # beak_open: Hinge at (172, 80), curve up-right to tip (214, 42)
    top_beak = cubic_bezier((172, 80), (178, 58), (192, 44), (214, 42), 30)
    tip_beak = cubic_bezier((214, 42), (212, 48), (206, 56), (198, 62), 15)
    bottom_beak = cubic_bezier((198, 62), (190, 68), (182, 74), (172, 80), 30)
    beak_pts = top_beak + tip_beak[1:] + bottom_beak[1:]

    os.makedirs(out_dir, exist_ok=True)

    w_pts = [(p[0] * scale, p[1] * scale) for p in wing_pts]
    b_pts = [(p[0] * scale, p[1] * scale) for p in beak_pts]

    pix_wu = rasterize_layer(
        w_pts, size, size, ss=4,
        fill_color=(46, 42, 38, 255),
        rim_color=(199, 162, 76, 255),
        rim_pts_range=wing_rim_range,
        rim_thickness=2.6 * scale,
    )
    png_wu = bss.write_png(size, size, pix_wu)
    with open(os.path.join(out_dir, 'wing_up.png'), 'wb') as f:
        f.write(png_wu)

    pix_bo = rasterize_layer(
        b_pts, size, size, ss=4,
        fill_color=(199, 162, 76, 255),
        rim_color=None,
        rim_pts_range=None,
    )
    png_bo = bss.write_png(size, size, pix_bo)
    with open(os.path.join(out_dir, 'beak_open.png'), 'wb') as f:
        f.write(png_bo)

    wu_opaque = sum(1 for i in range(size * size) if pix_wu[i * 4 + 3] > 0)
    bo_opaque = sum(1 for i in range(size * size) if pix_bo[i * 4 + 3] > 0)
    print(f"  wing_up.png: {size}x{size}, {wu_opaque} opaque px")
    print(f"  beak_open.png: {size}x{size}, {bo_opaque} opaque px")


def verify_reconstruction(base_dir, out_dir, scale, size):
    """Verify T9 assertion 1: body_base + wing_folded + beak_closed + eye_open ≈ body.png (≤ 2%)."""
    if scale == 1.0:
        w, h, pix_orig = bss.read_png(os.path.join(base_dir, 'body.png'))
    else:
        density_dir = os.path.join(base_dir, f'{scale}x')
        w, h, pix_orig = bss.read_png(os.path.join(density_dir, 'body.png'))

    w_bb, h_bb, pix_bb = bss.read_png(os.path.join(out_dir, 'body_base.png'))
    w_bc, h_bc, pix_bc = bss.read_png(os.path.join(out_dir, 'beak_closed.png'))
    w_wf, h_wf, pix_wf = bss.read_png(os.path.join(out_dir, 'wing_folded.png'))

    diff_count = 0
    total_opaque = 0
    for y in range(h):
        for x in range(w):
            orig = bss.get_pixel(pix_orig, w, h, x, y)
            if orig[3] > 0:
                total_opaque += 1

            bb = bss.get_pixel(pix_bb, w, h, x, y)
            wf = bss.get_pixel(pix_wf, w, h, x, y)
            bc = bss.get_pixel(pix_bc, w, h, x, y)

            rec = bss.blend(bb, wf)
            rec = bss.blend(rec, bc)

            if orig != rec:
                diff_count += 1

    pct = diff_count / total_opaque * 100 if total_opaque > 0 else 0
    status = "PASS" if pct <= 2.0 else "FAIL"
    print(f"  Reconstruction: {diff_count}/{total_opaque} differ ({pct:.2f}%) [{status}]")
    return pct <= 2.0


def generate():
    base_dir = 'assets/images/raven'

    densities = [
        (1.0, 256, base_dir),
        (2.0, 512, os.path.join(base_dir, '2.0x')),
        (3.0, 768, os.path.join(base_dir, '3.0x')),
    ]

    for scale, size, out_dir in densities:
        print(f"\n=== {scale}x ({size}x{size}) → {out_dir} ===")

        # Step 1: Extract body_base, beak_closed, wing_folded from body.png
        print("Extracting layers from body.png:")
        extract_layers_from_body(base_dir, scale, size, out_dir)

        # Step 2: Generate wing_up and beak_open vector art
        print("Generating vector art:")
        generate_vector_layers(scale, size, out_dir)

        # Step 3: Verify reconstruction
        print("Verifying reconstruction:")
        verify_reconstruction(base_dir, out_dir, scale, size)


if __name__ == '__main__':
    generate()
