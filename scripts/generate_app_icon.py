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

def write_rgb_png(width, height, rgb_pixels):
    bpp = 3
    stride = width * bpp
    raw = bytearray()
    for y in range(height):
        raw.append(0) # filter type 0
        raw.extend(rgb_pixels[y * stride : (y + 1) * stride])
    idat = zlib.compress(bytes(raw), level=9)
    def chunk(type_, data):
        crc = zlib.crc32(type_ + data) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + type_ + data + struct.pack('>I', crc)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', idat) + chunk(b'IEND', b'')

def composite_layers():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    raven_dir = os.path.join(project_root, 'assets', 'images', 'raven', '3.0x')

    # Load 3.0x layers (768x768)
    w_body, h_body, body_pix = read_png(os.path.join(raven_dir, 'body_base.png'))
    w_beak, h_beak, beak_pix = read_png(os.path.join(raven_dir, 'beak_closed.png'))
    w_eye, h_eye, eye_pix = read_png(os.path.join(raven_dir, 'eye_open.png'))
    w_wing, h_wing, wing_pix = read_png(os.path.join(raven_dir, 'wing.png'))

    # Composite layers onto a 768x768 RGBA buffer
    composite_768 = bytearray(w_body * h_body * 4)
    for layer in [body_pix, beak_pix, eye_pix, wing_pix]:
        for i in range(0, len(composite_768), 4):
            src_a = layer[i+3] / 255.0
            if src_a > 0:
                dst_a = composite_768[i+3] / 255.0
                out_a = src_a + dst_a * (1.0 - src_a)
                if out_a > 0:
                    r = int((layer[i] * src_a + composite_768[i] * dst_a * (1.0 - src_a)) / out_a)
                    g = int((layer[i+1] * src_a + composite_768[i+1] * dst_a * (1.0 - src_a)) / out_a)
                    b = int((layer[i+2] * src_a + composite_768[i+2] * dst_a * (1.0 - src_a)) / out_a)
                    composite_768[i] = r
                    composite_768[i+1] = g
                    composite_768[i+2] = b
                    composite_768[i+3] = int(out_a * 255)

    # Find bounding box of raven in 768x768
    min_x, max_x, min_y, max_y = 768, 0, 768, 0
    for y in range(768):
        for x in range(768):
            a = composite_768[(y * 768 + x) * 4 + 3]
            if a > 10:
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y

    raven_w = max_x - min_x + 1
    raven_h = max_y - min_y + 1
    print(f"Raven bbox in 768x768: ({min_x}, {min_y}) to ({max_x}, {max_y}), size: {raven_w}x{raven_h}")

    # We want the raven to occupy ~680 px within 1024x1024 canvas
    target_raven_size = 680
    scale = target_raven_size / max(raven_w, raven_h)
    
    # Target center in 1024x1024 canvas
    canvas_w = 1024
    canvas_h = 1024
    bg_r, bg_g, bg_b = 0x14, 0x11, 0x0E # AppColors.ground #14110E

    # Initialize 1024x1024 RGB buffer with solid ground color
    out_rgb = bytearray(canvas_w * canvas_h * 3)
    for i in range(0, len(out_rgb), 3):
        out_rgb[i] = bg_r
        out_rgb[i+1] = bg_g
        out_rgb[i+2] = bg_b

    # Source raven center
    src_cx = (min_x + max_x) / 2.0
    src_cy = (min_y + max_y) / 2.0

    # Destination center (slightly adjusted for visual optical balance)
    dst_cx = canvas_w / 2.0
    dst_cy = canvas_h / 2.0 + 10.0 # slight optical adjustment

    # Render with bilinear filtering
    for dy in range(canvas_h):
        for dx in range(canvas_w):
            # Map (dx, dy) back to source (sx, sy)
            sx = src_cx + (dx - dst_cx) / scale
            sy = src_cy + (dy - dst_cy) / scale

            if 0 <= sx < 767 and 0 <= sy < 767:
                x0 = int(math.floor(sx))
                y0 = int(math.floor(sy))
                x1 = x0 + 1
                y1 = y0 + 1
                fx = sx - x0
                fy = sy - y0

                idx00 = (y0 * 768 + x0) * 4
                idx10 = (y0 * 768 + x1) * 4
                idx01 = (y1 * 768 + x0) * 4
                idx11 = (y1 * 768 + x1) * 4

                # Interpolate RGBA
                r = (composite_768[idx00] * (1-fx)*(1-fy) +
                     composite_768[idx10] * fx*(1-fy) +
                     composite_768[idx01] * (1-fx)*fy +
                     composite_768[idx11] * fx*fy)
                g = (composite_768[idx00+1] * (1-fx)*(1-fy) +
                     composite_768[idx10+1] * fx*(1-fy) +
                     composite_768[idx01+1] * (1-fx)*fy +
                     composite_768[idx11+1] * fx*fy)
                b = (composite_768[idx00+2] * (1-fx)*(1-fy) +
                     composite_768[idx10+2] * fx*(1-fy) +
                     composite_768[idx01+2] * (1-fx)*fy +
                     composite_768[idx11+2] * fx*fy)
                a = (composite_768[idx00+3] * (1-fx)*(1-fy) +
                     composite_768[idx10+3] * fx*(1-fy) +
                     composite_768[idx01+3] * (1-fx)*fy +
                     composite_768[idx11+3] * fx*fy) / 255.0

                if a > 0:
                    dst_idx = (dy * canvas_w + dx) * 3
                    out_rgb[dst_idx] = int(r * a + bg_r * (1.0 - a))
                    out_rgb[dst_idx+1] = int(g * a + bg_g * (1.0 - a))
                    out_rgb[dst_idx+2] = int(b * a + bg_b * (1.0 - a))

    # Write output to assets/icon/app_icon_1024.png
    out_dir = os.path.join(project_root, 'assets', 'icon')
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'app_icon_1024.png')
    png_data = write_rgb_png(canvas_w, canvas_h, out_rgb)
    with open(out_path, 'wb') as f:
        f.write(png_data)
    print(f"Wrote master app icon to {out_path} ({len(png_data)} bytes)")

if __name__ == '__main__':
    composite_layers()
