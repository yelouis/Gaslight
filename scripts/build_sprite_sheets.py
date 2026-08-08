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

def render_frame(body, wing, eye, scale_x=1.0, scale_y=1.0, wing_rot=0.0, ruffle_wave=0.0):
    w, h = 256, 256
    frame = [(0, 0, 0, 0)] * (w * h)
    cx, cy = 128.0, 128.0
    
    # 1. Body layer with scale & feather ruffle displacement
    body_layer = [(0, 0, 0, 0)] * (w * h)
    for y in range(h):
        for x in range(w):
            sx = (x - cx) / scale_x + cx
            sy = (y - cy) / scale_y + cy
            if ruffle_wave != 0.0:
                sx += ruffle_wave * math.sin((y - 40) * 0.15)
            p = sample_bilinear(body[2], w, h, sx, sy)
            body_layer[y * w + x] = p
            
    # 2. Wing layer with wing_rot around shoulder pivot (-0.25 * 256 + 128 = 64, 0.10 * 256 + 128 = 153.6)
    px, py = 64.0, 153.6
    rad = wing_rot
    cos_r = math.cos(-rad)
    sin_r = math.sin(-rad)
    wing_layer = [(0, 0, 0, 0)] * (w * h)
    for y in range(h):
        for x in range(w):
            dx = x - px
            dy = y - py
            rx = dx * cos_r - dy * sin_r + px
            ry = dx * sin_r + dy * cos_r + py
            sx = (rx - cx) / scale_x + cx
            sy = (ry - cy) / scale_y + cy
            p = sample_bilinear(wing[2], w, h, sx, sy)
            wing_layer[y * w + x] = p
            
    # 3. Eye layer with body scale
    eye_layer = [(0, 0, 0, 0)] * (w * h)
    for y in range(h):
        for x in range(w):
            sx = (x - cx) / scale_x + cx
            sy = (y - cy) / scale_y + cy
            p = sample_bilinear(eye[2], w, h, sx, sy)
            eye_layer[y * w + x] = p

    # Composite layers
    for i in range(w * h):
        b = blend(frame[i], body_layer[i])
        b = blend(b, wing_layer[i])
        b = blend(b, eye_layer[i])
        frame[i] = b
    return frame

def main():
    base_dir = 'assets/images/raven'
    body = read_png(os.path.join(base_dir, 'body.png'))
    wing = read_png(os.path.join(base_dir, 'wing.png'))
    eye = read_png(os.path.join(base_dir, 'eye_open.png'))
    
    # Ruffle sequence: 8 frames
    # Frame 0: Exact resting pose (scale=1.0, rot=0.0)
    # Frames 1-7: Authored ruffle sequence
    frames_params = [
        (1.00, 1.00, 0.00, 0.0),   # Frame 0: resting
        (1.05, 1.02, 0.05, 1.5),   # Frame 1: start expansion & ruffle wave
        (1.12, 1.04, 0.12, 3.5),   # Frame 2: puffing up
        (1.18, 1.08, 0.20, 5.0),   # Frame 3: peak ruffle fluff
        (1.15, 1.05, 0.15, 4.0),   # Frame 4: wave settling
        (1.08, 1.02, 0.08, 2.0),   # Frame 5: easing back
        (1.03, 1.01, 0.03, 0.8),   # Frame 6: subtle recovery
        (1.00, 1.00, 0.00, 0.0),   # Frame 7: settled resting pose
    ]
    
    cols = 4
    rows = 2
    sheet_w = cols * 256
    sheet_h = rows * 256
    sheet_pixels = bytearray(sheet_w * sheet_h * 4)
    
    for idx, (sx, sy, w_rot, r_wave) in enumerate(frames_params):
        frame = render_frame(body, wing, eye, scale_x=sx, scale_y=sy, wing_rot=w_rot, ruffle_wave=r_wave)
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
                
    out_path = os.path.join(base_dir, 'frames', 'ruffle.png')
    png_bytes = write_png(sheet_w, sheet_h, sheet_pixels)
    with open(out_path, 'wb') as f:
        f.write(png_bytes)
    print(f"Generated {out_path}: {sheet_w}x{sheet_h}, {len(png_bytes)} bytes")

if __name__ == '__main__':
    main()
