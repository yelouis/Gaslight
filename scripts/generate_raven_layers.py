#!/usr/bin/env python3
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

def rasterize_layer(pts, width, height, ss=4, fill_color=(46, 42, 38, 255), rim_color=None, rim_pts_range=None, rim_thickness=2.5):
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
            x2, y2 = rim_poly[i+1]
            rmin_x = max(0, int(math.floor(min(x1, x2) - r_thick_ss)))
            rmax_x = min(W - 1, int(math.ceil(max(x1, x2) + r_thick_ss)))
            rmin_y = max(0, int(math.floor(min(y1, y2) - r_thick_ss)))
            rmax_y = min(H - 1, int(math.ceil(max(y1, y2) + r_thick_ss)))
            
            dx, dy = x2 - x1, y2 - y1
            len_sq = dx*dx + dy*dy
            if len_sq == 0: continue
            
            for y in range(rmin_y, rmax_y + 1):
                for x in range(rmin_x, rmax_x + 1):
                    if grid[y * W + x] is not None:
                        t = max(0.0, min(1.0, ((x - x1)*dx + (y - y1)*dy) / len_sq))
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
                pixels[dst+1] = int(round(g_acc / (ss * ss)))
                pixels[dst+2] = int(round(b_acc / (ss * ss)))
                pixels[dst+3] = int(round(a_acc / (ss * ss)))
    return pixels

def generate():
    # 1x coordinate definitions
    # wing_up: Shoulder at (100, 118), sweeping up-left to (56, 46), tip at (48, 85), back to shoulder (98, 126)
    outer_wing = cubic_bezier((100, 118), (88, 75), (72, 52), (56, 46), 40)
    tip_wing = cubic_bezier((56, 46), (48, 56), (44, 72), (48, 85), 20)
    inner_wing = cubic_bezier((48, 85), (60, 105), (76, 122), (98, 126), 40)
    base_wing = cubic_bezier((98, 126), (102, 124), (102, 120), (100, 118), 10)
    wing_pts = outer_wing + tip_wing[1:] + inner_wing[1:] + base_wing[1:]
    wing_rim_range = range(0, len(outer_wing) + len(tip_wing) - 1)

    # beak_open: Hinge at (172, 80), curve up-right to tip (214, 42), curve back to (172, 80)
    top_beak = cubic_bezier((172, 80), (178, 58), (192, 44), (214, 42), 30)
    tip_beak = cubic_bezier((214, 42), (212, 48), (206, 56), (198, 62), 15)
    bottom_beak = cubic_bezier((198, 62), (190, 68), (182, 74), (172, 80), 30)
    beak_pts = top_beak + tip_beak[1:] + bottom_beak[1:]

    densities = [
        (1.0, 256, 'assets/images/raven'),
        (2.0, 512, 'assets/images/raven/2.0x'),
        (3.0, 768, 'assets/images/raven/3.0x'),
    ]

    for scale, size, out_dir in densities:
        os.makedirs(out_dir, exist_ok=True)

        w_pts = [(p[0] * scale, p[1] * scale) for p in wing_pts]
        b_pts = [(p[0] * scale, p[1] * scale) for p in beak_pts]

        pix_wu = rasterize_layer(
            w_pts, size, size, ss=4,
            fill_color=(46, 42, 38, 255),
            rim_color=(199, 162, 76, 255),
            rim_pts_range=wing_rim_range,
            rim_thickness=2.6 * scale
        )
        png_wu = bss.write_png(size, size, pix_wu)
        with open(os.path.join(out_dir, 'wing_up.png'), 'wb') as f:
            f.write(png_wu)

        pix_bo = rasterize_layer(
            b_pts, size, size, ss=4,
            fill_color=(199, 162, 76, 255),
            rim_color=None,
            rim_pts_range=None
        )
        png_bo = bss.write_png(size, size, pix_bo)
        with open(os.path.join(out_dir, 'beak_open.png'), 'wb') as f:
            f.write(png_bo)

        print(f"Generated {out_dir}/wing_up.png ({size}x{size}) and {out_dir}/beak_open.png ({size}x{size})")

if __name__ == '__main__':
    generate()
