#!/usr/bin/env python3
import os
import math
import struct
import zlib

def read_png(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    offset = 8
    width, height = 0, 0
    color_type = 6
    palette = []
    trns = []
    idat = b''
    while offset < len(data):
        length, type_ = struct.unpack('>I4s', data[offset:offset+8])
        chunk = data[offset+8:offset+8+length]
        if type_ == b'IHDR':
            width, height, _, color_type, _, _, _ = struct.unpack('>IIBBBBB', chunk[:13])
        elif type_ == b'PLTE':
            for i in range(0, len(chunk), 3):
                palette.append((chunk[i], chunk[i+1], chunk[i+2]))
        elif type_ == b'tRNS':
            trns = list(chunk)
        elif type_ == b'IDAT':
            idat += chunk
        offset += 8 + length + 4

    raw = zlib.decompress(idat)

    if color_type == 6:
        bpp = 4
        stride = 1 + width * bpp
        pixels = bytearray(width * height * 4)
        prev_row = bytearray(width * 4)
        for y in range(height):
            filter_type = raw[y * stride]
            row_raw = raw[y * stride + 1 : (y + 1) * stride]
            row = bytearray(width * 4)
            for i in range(width * 4):
                filt = row_raw[i]
                a = row[i - 4] if i >= 4 else 0
                b = prev_row[i] if y > 0 else 0
                c = prev_row[i - 4] if (y > 0 and i >= 4) else 0
                if filter_type == 0: val = filt
                elif filter_type == 1: val = (filt + a) & 0xFF
                elif filter_type == 2: val = (filt + b) & 0xFF
                elif filter_type == 3: val = (filt + (a + b) // 2) & 0xFF
                elif filter_type == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    val = (filt + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 0xFF
                row[i] = val
            pixels[y * width * 4 : (y + 1) * width * 4] = row
            prev_row = row
        return width, height, pixels
    elif color_type == 3:
        bpp = 1
        stride = 1 + width * bpp
        pixels = bytearray(width * height * 4)
        prev_row = bytearray(width)
        for y in range(height):
            filter_type = raw[y * stride]
            row_raw = raw[y * stride + 1 : (y + 1) * stride]
            row = bytearray(width)
            for i in range(width):
                filt = row_raw[i]
                a = row[i - 1] if i >= 1 else 0
                b = prev_row[i] if y > 0 else 0
                c = prev_row[i - 1] if (y > 0 and i >= 1) else 0
                if filter_type == 0: val = filt
                elif filter_type == 1: val = (filt + a) & 0xFF
                elif filter_type == 2: val = (filt + b) & 0xFF
                elif filter_type == 3: val = (filt + (a + b) // 2) & 0xFF
                elif filter_type == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    val = (filt + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 0xFF
                row[i] = val
            for x in range(width):
                idx = row[x]
                r, g, b_col = palette[idx]
                alpha = trns[idx] if idx < len(trns) else 255
                dst = (y * width + x) * 4
                pixels[dst] = r
                pixels[dst+1] = g
                pixels[dst+2] = b_col
                pixels[dst+3] = alpha
            prev_row = row
        return width, height, pixels
    else:
        raise ValueError(f"Unsupported PNG color_type: {color_type}")

def write_png(width, height, pixels):
    bpp = 4
    stride = width * bpp
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])
    idat = zlib.compress(bytes(raw), level=9)
    def chunk(type_, data):
        crc = zlib.crc32(type_ + data) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + type_ + data + struct.pack('>I', crc)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', idat) + chunk(b'IEND', b'')

def get_pixel(pixels, w, h, x, y):
    if x < 0 or x >= w or y < 0 or y >= h:
        return (0, 0, 0, 0)
    idx = (y * w + x) * 4
    return (pixels[idx], pixels[idx+1], pixels[idx+2], pixels[idx+3])

def sample_bilinear(pixels, w, h, fx, fy):
    if fx < 0 or fx >= w - 1 or fy < 0 or fy >= h - 1:
        x0, y0 = int(math.floor(fx)), int(math.floor(fy))
        return get_pixel(pixels, w, h, x0, y0)
    x0 = int(math.floor(fx))
    y0 = int(math.floor(fy))
    x1 = x0 + 1
    y1 = y0 + 1
    dx = fx - x0
    dy = fy - y0
    
    p00 = get_pixel(pixels, w, h, x0, y0)
    p10 = get_pixel(pixels, w, h, x1, y0)
    p01 = get_pixel(pixels, w, h, x0, y1)
    p11 = get_pixel(pixels, w, h, x1, y1)
    
    res = []
    for c in range(4):
        v = (p00[c] * (1 - dx) * (1 - dy) +
             p10[c] * dx * (1 - dy) +
             p01[c] * (1 - dx) * dy +
             p11[c] * dx * dy)
        res.append(int(round(v)))
    return tuple(res)

def blend(dst, src):
    sr, sg, sb, sa = src
    if sa == 0:
        return dst
    if sa == 255 or dst[3] == 0:
        return src
    dr, dg, db, da = dst
    fa = sa / 255.0
    fda = (da / 255.0) * (1.0 - fa)
    out_a = fa + fda
    if out_a == 0:
        return (0, 0, 0, 0)
    out_r = int(round((sr * fa + dr * fda) / out_a))
    out_g = int(round((sg * fa + dg * fda) / out_a))
    out_b = int(round((sb * fa + db * fda) / out_a))
    out_a_int = int(round(out_a * 255.0))
    return (out_r, out_g, out_b, out_a_int)

def render_frame(layers,
                 scale_x=1.0, scale_y=1.0,
                 wing_rot=0.0, ruffle_wave=0.0,
                 rotate=0.0, translate_x=0.0, translate_y=0.0,
                 use_wing_up=False, use_beak_open=False, use_beak_semi_open=False,
                 use_eye_closed=False, eye='open'):
    """Render a single 256×256 frame by compositing layers in order:
       body_base → wing variant → beak variant → eye variant.

    Task T9: body_base has clean sockets where the beak and wing were; each
    animated part is supplied as its own layer so variants can genuinely swap.
    Beak has 3 states: closed (default), semi_open, open.
    """
    # Task T7's |wing_rot| <= 0.12 cap exists because wing_folded is a small
    # marking that detaches from the silhouette when swung far. wing_up is a
    # blade anchored at the shoulder and is *meant* to sweep, so the cap applies
    # only to the folded wing.
    if not use_wing_up:
        assert abs(wing_rot) <= 0.12001, f"wing_folded rot cap violated: {wing_rot} > 0.12 rad"

    w, h = 256, 256
    frame = [(0, 0, 0, 0)] * (w * h)
    cx, cy = 128.0, 128.0  # Center for scale & whole-body rotation

    # T9 layer selection: body_base is always the base; wing and beak variants swap.
    body = layers['body_base']
    wing = layers['wing_up'] if use_wing_up else layers['wing_folded']
    if use_beak_open:
        beak = layers['beak_open']
    elif use_beak_semi_open:
        beak = layers['beak_semi_open']
    else:
        beak = layers['beak_closed']
    # Emotional eye variants. use_eye_closed stays supported for the blink.
    eye_key = 'eye_closed' if use_eye_closed else f'eye_{eye}'
    eye = layers.get(eye_key, layers['eye_open'])

    # Whole-body rotation matrix (inverse)
    cos_rot = math.cos(-rotate)
    sin_rot = math.sin(-rotate)

    def map_coords(x, y):
        tx = x - translate_x
        ty = y - translate_y
        dx = tx - cx
        dy = ty - cy
        rx = dx * cos_rot - dy * sin_rot + cx
        ry = dx * sin_rot + dy * cos_rot + cy
        return rx, ry

    # 1. Body base layer with scale, whole-body rotation, translation & feather ruffle wave
    body_layer = [(0, 0, 0, 0)] * (w * h)
    for y in range(h):
        for x in range(w):
            rx, ry = map_coords(x, y)
            sx = (rx - cx) / scale_x + cx
            sy = (ry - cy) / scale_y + cy
            if ruffle_wave != 0.0:
                sx += ruffle_wave * math.sin((ry - 40) * 0.15)
            p = sample_bilinear(body[2], w, h, sx, sy)
            body_layer[y * w + x] = p

    # 2. Wing layer with corrected shoulder attachment pivot (100.0, 118.0)
    px, py = 100.0, 118.0
    cos_w = math.cos(-wing_rot)
    sin_w = math.sin(-wing_rot)
    wing_layer = [(0, 0, 0, 0)] * (w * h)
    for y in range(h):
        for x in range(w):
            rx, ry = map_coords(x, y)
            # Reverse wing rotation around shoulder pivot (px, py)
            dx = rx - px
            dy = ry - py
            wx = dx * cos_w - dy * sin_w + px
            wy = dx * sin_w + dy * cos_w + py
            sx = (wx - cx) / scale_x + cx
            sy = (wy - cy) / scale_y + cy
            p = sample_bilinear(wing[2], w, h, sx, sy)
            wing_layer[y * w + x] = p

    # 3. Beak layer with body scale, rotation & translation
    beak_layer = [(0, 0, 0, 0)] * (w * h)
    for y in range(h):
        for x in range(w):
            rx, ry = map_coords(x, y)
            sx = (rx - cx) / scale_x + cx
            sy = (ry - cy) / scale_y + cy
            p = sample_bilinear(beak[2], w, h, sx, sy)
            beak_layer[y * w + x] = p

    # 4. Eye layer with body scale, rotation & translation
    eye_layer = [(0, 0, 0, 0)] * (w * h)
    for y in range(h):
        for x in range(w):
            rx, ry = map_coords(x, y)
            sx = (rx - cx) / scale_x + cx
            sy = (ry - cy) / scale_y + cy
            p = sample_bilinear(eye[2], w, h, sx, sy)
            eye_layer[y * w + x] = p

    # Composite layers: body_base → wing variant → beak variant → eye variant
    for i in range(w * h):
        c = blend(frame[i], body_layer[i])
        c = blend(c, wing_layer[i])
        c = blend(c, beak_layer[i])
        c = blend(c, eye_layer[i])
        frame[i] = c
    return frame

POSE_REGISTRY = {
    # 6 ACCEPTED POSES — DO NOT TOUCH (ruffle, startle, hop, peck, bow, alert)
    'ruffle': {
        'cols': 4, 'rows': 2,
        'frames': [
            {'scale_x': 1.00, 'scale_y': 1.00, 'wing_rot': 0.00, 'ruffle_wave': 0.0},
            {'scale_x': 1.05, 'scale_y': 1.02, 'wing_rot': 0.05, 'ruffle_wave': 1.5},
            {'scale_x': 1.12, 'scale_y': 1.04, 'wing_rot': 0.10, 'ruffle_wave': 3.5},
            {'scale_x': 1.18, 'scale_y': 1.08, 'wing_rot': 0.12, 'ruffle_wave': 5.0},
            {'scale_x': 1.15, 'scale_y': 1.05, 'wing_rot': 0.10, 'ruffle_wave': 4.0},
            {'scale_x': 1.08, 'scale_y': 1.02, 'wing_rot': 0.06, 'ruffle_wave': 2.0},
            {'scale_x': 1.03, 'scale_y': 1.01, 'wing_rot': 0.02, 'ruffle_wave': 0.8},
            {'scale_x': 1.00, 'scale_y': 1.00, 'wing_rot': 0.00, 'ruffle_wave': 0.0},
        ]
    },
    'startle': {
        'cols': 3, 'rows': 2,
        'frames': [
            {'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0, 'wing_rot': 0.00},
            {'eye': 'wide', 'scale_x': 1.04, 'scale_y': 1.08, 'translate_y': -12.0, 'wing_rot': 0.08},
            {'eye': 'wide', 'scale_x': 1.08, 'scale_y': 1.12, 'translate_y': -18.0, 'wing_rot': 0.11},
            {'eye': 'wide', 'scale_x': 0.96, 'scale_y': 0.94, 'translate_y': -4.0, 'wing_rot': 0.04},
            {'eye': 'wide', 'scale_x': 1.02, 'scale_y': 1.02, 'translate_y': -1.0, 'wing_rot': 0.01},
            {'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0, 'wing_rot': 0.00},
        ]
    },
    'hop': {
        'cols': 4, 'rows': 2,
        'frames': [
            {'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0, 'wing_rot': 0.00},
            {'scale_x': 1.05, 'scale_y': 0.92, 'translate_y': 4.0, 'wing_rot': -0.04},
            {'scale_x': 0.95, 'scale_y': 1.10, 'translate_y': -14.0, 'wing_rot': 0.08},
            {'scale_x': 1.00, 'scale_y': 1.02, 'translate_y': -24.0, 'wing_rot': 0.11},
            {'scale_x': 0.96, 'scale_y': 1.08, 'translate_y': -12.0, 'wing_rot': 0.06},
            {'scale_x': 1.08, 'scale_y': 0.90, 'translate_y': 5.0, 'wing_rot': -0.05},
            {'scale_x': 1.02, 'scale_y': 1.03, 'translate_y': -1.0, 'wing_rot': 0.01},
            {'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0, 'wing_rot': 0.00},
        ]
    },
    'peck': {
        'cols': 3, 'rows': 2,
        'frames': [
            {'rotate': 0.00, 'translate_x': 0.0, 'translate_y': 0.0},
            {'eye': 'angry', 'rotate': -0.05, 'translate_x': -1.0, 'translate_y': -2.0},
            {'eye': 'angry', 'rotate': 0.32, 'translate_x': 8.0, 'translate_y': 10.0, 'scale_x': 1.04, 'scale_y': 0.96},
            {'eye': 'angry', 'rotate': 0.28, 'translate_x': 6.0, 'translate_y': 8.0},
            {'eye': 'angry', 'rotate': 0.08, 'translate_x': 2.0, 'translate_y': 2.0},
            {'rotate': 0.00, 'translate_x': 0.0, 'translate_y': 0.0},
        ]
    },
    'bow': {
        'cols': 4, 'rows': 2,
        'frames': [
            {'rotate': 0.00, 'translate_y': 0.0},
            {'rotate': 0.08, 'translate_y': 2.0},
            {'rotate': 0.22, 'translate_y': 5.0},
            {'rotate': 0.38, 'translate_y': 9.0, 'scale_x': 1.02},
            {'rotate': 0.38, 'translate_y': 9.0, 'scale_x': 1.02},
            {'rotate': 0.24, 'translate_y': 6.0},
            {'rotate': 0.10, 'translate_y': 2.0},
            {'rotate': 0.00, 'translate_y': 0.0},
        ]
    },
    'alert': {
        'cols': 3, 'rows': 2,
        'frames': [
            {'rotate': 0.00, 'scale_y': 1.00, 'translate_y': 0.0},
            {'eye': 'wide', 'rotate': -0.18, 'scale_y': 1.04, 'translate_y': -4.0},
            {'eye': 'wide', 'rotate': -0.25, 'scale_y': 1.06, 'translate_y': -6.0},
            {'eye': 'wide', 'rotate': -0.25, 'scale_y': 1.06, 'translate_y': -6.0},
            {'eye': 'wide', 'rotate': -0.08, 'scale_y': 1.02, 'translate_y': -2.0},
            {'rotate': 0.00, 'scale_y': 1.00, 'translate_y': 0.0},
        ]
    },

    # Task T8 RE-AUTHORED POSES (preen, fly, flap, caw)
    'preen': {
        'cols': 4, 'rows': 2,
        'frames': [
            {'rotate': 0.00, 'scale_x': 1.00, 'scale_y': 1.00, 'wing_rot': 0.00},
            {'eye': 'happy', 'rotate': -0.08, 'scale_x': 1.02, 'scale_y': 0.97, 'wing_rot': 0.04},
            {'eye': 'happy', 'rotate': -0.14, 'scale_x': 1.04, 'scale_y': 0.94, 'wing_rot': 0.08},
            {'eye': 'happy', 'rotate': -0.18, 'scale_x': 1.05, 'scale_y': 0.93, 'wing_rot': 0.10},
            {'eye': 'happy', 'rotate': -0.18, 'scale_x': 1.05, 'scale_y': 0.93, 'wing_rot': 0.10},
            {'eye': 'happy', 'rotate': -0.12, 'scale_x': 1.03, 'scale_y': 0.96, 'wing_rot': 0.06},
            {'eye': 'happy', 'rotate': -0.04, 'scale_x': 1.01, 'scale_y': 0.99, 'wing_rot': 0.02},
            {'rotate': 0.00, 'scale_x': 1.00, 'scale_y': 1.00, 'wing_rot': 0.00},
        ]
    },
    'fly': {
        'cols': 4, 'rows': 2,
        'frames': [
            {'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0, 'use_wing_up': False},
            {'scale_x': 1.05, 'scale_y': 0.90, 'translate_y': 3.0, 'use_wing_up': False},                       # anticipation crouch
            {'scale_x': 0.96, 'scale_y': 1.10, 'translate_y': -9.0, 'use_wing_up': True, 'wing_rot': -1.20},    # push off, wing still low
            {'scale_x': 0.97, 'scale_y': 1.08, 'translate_y': -17.0, 'use_wing_up': True, 'wing_rot': -0.60},   # sweeping up
            {'scale_x': 0.99, 'scale_y': 1.05, 'translate_y': -23.0, 'use_wing_up': True, 'wing_rot': 0.00},    # top of climb, wing high
            {'scale_x': 1.01, 'scale_y': 1.02, 'translate_y': -16.0, 'use_wing_up': True, 'wing_rot': -0.45},   # wing sweeping down
            {'scale_x': 1.02, 'scale_y': 0.99, 'translate_y': -5.0, 'use_wing_up': True, 'wing_rot': -1.15},    # descending, wing low
            {'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0, 'use_wing_up': False},
        ]
    },
    'flap': {
        'cols': 3, 'rows': 2,
        'frames': [
            {'scale_y': 1.00, 'scale_x': 1.00, 'translate_y': 0.0, 'use_wing_up': False},
            {'eye': 'happy', 'scale_y': 1.04, 'scale_x': 0.97, 'translate_y': -12.0, 'use_wing_up': True, 'wing_rot': -1.25},  # wing low -- reads as folded, so no pop
            {'eye': 'happy', 'scale_y': 0.97, 'scale_x': 1.03, 'translate_y': -22.0, 'use_wing_up': True, 'wing_rot': -0.15},  # beat 1 upstroke
            {'eye': 'happy', 'scale_y': 1.05, 'scale_x': 0.96, 'translate_y': -24.0, 'use_wing_up': True, 'wing_rot': -1.25},  # beat 1 downstroke
            {'eye': 'happy', 'scale_y': 0.97, 'scale_x': 1.03, 'translate_y': -11.0, 'use_wing_up': True, 'wing_rot': -0.20},  # beat 2 upstroke
            {'scale_y': 1.00, 'scale_x': 1.00, 'translate_y': 0.0, 'use_wing_up': False},
        ]
    },
    'caw': {
        'cols': 3, 'rows': 2,
        'frames': [
            {'rotate': 0.00, 'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0},  # closed
            {'eye': 'angry', 'rotate': -0.08, 'scale_x': 1.04, 'scale_y': 1.05, 'translate_y': -2.0, 'use_beak_semi_open': True},  # opening
            {'eye': 'angry', 'rotate': -0.14, 'scale_x': 1.08, 'scale_y': 1.10, 'translate_y': -5.0, 'use_beak_open': True},  # peak caw
            {'eye': 'angry', 'rotate': -0.14, 'scale_x': 1.08, 'scale_y': 1.10, 'translate_y': -5.0, 'use_beak_open': True},  # hold
            {'eye': 'angry', 'rotate': -0.05, 'scale_x': 1.02, 'scale_y': 1.03, 'translate_y': -1.0, 'use_beak_semi_open': True},  # closing
            {'rotate': 0.00, 'scale_x': 1.00, 'scale_y': 1.00, 'translate_y': 0.0},  # closed
        ]
    },
}

def main():
    base_dir = 'assets/images/raven'
    layers = {
        'body_base': read_png(os.path.join(base_dir, 'body_base.png')),
        'wing_folded': read_png(os.path.join(base_dir, 'wing_folded.png')),
        'wing_up': read_png(os.path.join(base_dir, 'wing_up.png')),
        'beak_closed': read_png(os.path.join(base_dir, 'beak_closed.png')),
        'beak_semi_open': read_png(os.path.join(base_dir, 'beak_semi_open.png')),
        'beak_open': read_png(os.path.join(base_dir, 'beak_open.png')),
        'eye_open': read_png(os.path.join(base_dir, 'eye_open.png')),
        'eye_closed': read_png(os.path.join(base_dir, 'eye_closed.png')),
        'eye_wide': read_png(os.path.join(base_dir, 'eye_wide.png')),
        'eye_happy': read_png(os.path.join(base_dir, 'eye_happy.png')),
        'eye_angry': read_png(os.path.join(base_dir, 'eye_angry.png')),
    }
    
    out_dir = os.path.join(base_dir, 'frames')
    os.makedirs(out_dir, exist_ok=True)

    for pose_name, spec in POSE_REGISTRY.items():
        frames = spec['frames']
        cols = spec['cols']
        rows = spec['rows']
        sheet_w = cols * 256
        sheet_h = rows * 256
        sheet_pixels = bytearray(sheet_w * sheet_h * 4)

        for idx, params in enumerate(frames):
            frame = render_frame(layers, **params)
            col = idx % cols
            row = idx // cols
            ox = col * 256
            oy = row * 256
            for y in range(256):
                for x in range(256):
                    p = frame[y * 256 + x]
                    dst_idx = ((oy + y) * sheet_w + (ox + x)) * 4
                    sheet_pixels[dst_idx] = p[0]
                    sheet_pixels[dst_idx+1] = p[1]
                    sheet_pixels[dst_idx+2] = p[2]
                    sheet_pixels[dst_idx+3] = p[3]

        out_path = os.path.join(out_dir, f'{pose_name}.png')
        png_bytes = write_png(sheet_w, sheet_h, sheet_pixels)
        with open(out_path, 'wb') as f:
            f.write(png_bytes)
        print(f"Generated {out_path}: {sheet_w}x{sheet_h} ({len(frames)} frames, {cols}x{rows} grid), {len(png_bytes)} bytes")

if __name__ == '__main__':
    main()
