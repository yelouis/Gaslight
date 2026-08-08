#!/usr/bin/env python3
import os
import struct
import zlib

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

def generate_beak(scale=1):
    w = 256 * scale
    h = 256 * scale
    pixels = bytearray(w * h * 4)

    def set_pixel(x, y, r, g, b, a=255):
        if 0 <= x < w and 0 <= y < h:
            idx = (y * w + x) * 4
            pixels[idx] = r
            pixels[idx+1] = g
            pixels[idx+2] = b
            pixels[idx+3] = a

    # Colors
    brass = (201, 162, 75, 255)
    dark_fill = (46, 42, 38, 255)
    mouth_black = (20, 17, 14, 255)

    # Scale coordinates relative to 256x256
    # Upper beak fixed at y ~ 70-76, lower mandible drops down to y ~ 78-94 and extends right x ~ 144-165
    for y in range(int(70 * scale), int(96 * scale)):
        for x in range(int(140 * scale), int(168 * scale)):
            fx = x / scale
            fy = y / scale
            
            # Lower mandible beak arc breaking outside closed beak silhouette (y > 78)
            if 78 <= fy <= 93 and 144 <= fx <= 165:
                # Triangular beak tip pointing right-down
                rel_x = (fx - 144) / 21.0
                max_y_for_x = 78 + (1.0 - rel_x) * 14.0
                min_y_for_x = 78 + (1.0 - rel_x) * 4.0
                
                if min_y_for_x <= fy <= max_y_for_x:
                    # Rim outline along bottom edge of lower mandible
                    if fy >= max_y_for_x - 1.5 or fx >= 163:
                        set_pixel(x, y, *brass)
                    elif fy <= min_y_for_x + 1.2:
                        set_pixel(x, y, *mouth_black)
                    else:
                        set_pixel(x, y, *brass)

    return w, h, pixels

def main():
    base_dir = 'assets/images/raven'
    
    # 1x
    w1, h1, p1 = generate_beak(1)
    png1 = write_png(w1, h1, p1)
    with open(os.path.join(base_dir, 'beak_open.png'), 'wb') as f:
        f.write(png1)
        
    # 2x
    w2, h2, p2 = generate_beak(2)
    png2 = write_png(w2, h2, p2)
    os.makedirs(os.path.join(base_dir, '2.0x'), exist_ok=True)
    with open(os.path.join(base_dir, '2.0x', 'beak_open.png'), 'wb') as f:
        f.write(png2)

    # 3x
    w3, h3, p3 = generate_beak(3)
    png3 = write_png(w3, h3, p3)
    os.makedirs(os.path.join(base_dir, '3.0x'), exist_ok=True)
    with open(os.path.join(base_dir, '3.0x', 'beak_open.png'), 'wb') as f:
        f.write(png3)

    print("Updated beak_open.png at 1x, 2.0x, 3.0x densities.")

if __name__ == '__main__':
    main()
