#!/usr/bin/env python3
import sys
import os
import struct

def parse_ttf(ttf_path, codepoints):
    with open(ttf_path, 'rb') as f:
        data = f.read()

    # Offset table
    num_tables, = struct.unpack('>H', data[4:6])
    tables = {}
    for i in range(num_tables):
        offset = 12 + i * 16
        tag = data[offset:offset+4].decode('latin1')
        tab_offset, length = struct.unpack('>II', data[offset+8:offset+16])
        tables[tag] = (tab_offset, length)

    # cmap format 4
    cmap_offset, _ = tables['cmap']
    num_subtables, = struct.unpack('>H', data[cmap_offset+2:cmap_offset+4])
    subtable_offset = None
    for i in range(num_subtables):
        platform_id, encoding_id, offset = struct.unpack('>HHI', data[cmap_offset+4+i*8:cmap_offset+12+i*8])
        if (platform_id == 3 and encoding_id in (1, 10)) or platform_id == 0:
            subtable_offset = cmap_offset + offset
            break

    if not subtable_offset:
        subtable_offset = cmap_offset + struct.unpack('>I', data[cmap_offset+8:cmap_offset+12])[0]

    fmt, length, language, seg_count_x2 = struct.unpack('>HHHH', data[subtable_offset:subtable_offset+8])
    seg_count = seg_count_x2 // 2

    end_codes = [struct.unpack('>H', data[subtable_offset+14+i*2:subtable_offset+16+i*2])[0] for i in range(seg_count)]
    start_codes = [struct.unpack('>H', data[subtable_offset+16+seg_count*2+i*2:subtable_offset+18+seg_count*2+i*2])[0] for i in range(seg_count)]
    id_deltas = [struct.unpack('>h', data[subtable_offset+18+seg_count*4+i*2:subtable_offset+20+seg_count*4+i*2])[0] for i in range(seg_count)]
    id_range_offsets = [struct.unpack('>H', data[subtable_offset+20+seg_count*6+i*2:subtable_offset+22+seg_count*6+i*2])[0] for i in range(seg_count)]

    def get_glyph_id(cp):
        for i in range(seg_count):
            if end_codes[i] >= cp:
                if start_codes[i] <= cp:
                    if id_range_offsets[i] == 0:
                        return (cp + id_deltas[i]) & 0xFFFF
                    else:
                        offset_loc = subtable_offset + 20 + seg_count*6 + i*2 + id_range_offsets[i] + (cp - start_codes[i])*2
                        gid = struct.unpack('>H', data[offset_loc:offset_loc+2])[0]
                        if gid != 0:
                            return (gid + id_deltas[i]) & 0xFFFF
                        return 0
                else:
                    break
        return 0

    head_offset, _ = tables['head']
    index_to_loc_format = struct.unpack('>h', data[head_offset+50:head_offset+52])[0]
    loca_offset, _ = tables['loca']
    glyf_offset, _ = tables['glyf']

    def get_glyph_offset(gid):
        if index_to_loc_format == 0:
            off1, off2 = struct.unpack('>HH', data[loca_offset+gid*2:loca_offset+gid*2+4])
            return glyf_offset + off1 * 2, (off2 - off1) * 2
        else:
            off1, off2 = struct.unpack('>II', data[loca_offset+gid*4:loca_offset+gid*4+8])
            return glyf_offset + off1, off2 - off1

    for cp_val in codepoints:
        gid = get_glyph_id(cp_val)
        hex_cp = f"0x{cp_val:04X}"
        print(f"\n========================================")
        print(f"Codepoint {hex_cp} -> Glyph ID {gid}")
        print(f"========================================")

        if gid == 0:
            print("GLYPH ID 0 (.notdef / tofu)")
            continue

        g_off, g_len = get_glyph_offset(gid)
        if g_len == 0:
            print("EMPTY GLYPH (0 bytes)")
            continue

        num_contours, x_min, y_min, x_max, y_max = struct.unpack('>h hhhh', data[g_off:g_off+10])
        print(f"Contours: {num_contours}, Bounding Box: ({x_min}, {y_min}) -> ({x_max}, {y_max})")

        if num_contours < 0:
            print("COMPOSITE GLYPH (references other glyphs)")
            continue

        end_pts = [struct.unpack('>H', data[g_off+10+i*2:g_off+12+i*2])[0] for i in range(num_contours)]
        instruction_len = struct.unpack('>H', data[g_off+10+num_contours*2:g_off+12+num_contours*2])[0]
        offset = g_off + 12 + num_contours * 2 + instruction_len

        total_points = end_pts[-1] + 1 if num_contours > 0 else 0
        flags = []
        i = 0
        while i < total_points:
            flag = data[offset]
            offset += 1
            flags.append(flag)
            if flag & 0x08: # Repeat flag
                repeat_count = data[offset]
                offset += 1
                for _ in range(repeat_count):
                    flags.append(flag)
                    i += 1
            i += 1

        x_coords = []
        last_x = 0
        for flag in flags:
            if flag & 0x02: # X short
                dx = data[offset]
                offset += 1
                if not (flag & 0x10):
                    dx = -dx
            elif flag & 0x10: # X same/positive
                dx = 0
            else:
                dx = struct.unpack('>h', data[offset:offset+2])[0]
                offset += 2
            last_x += dx
            x_coords.append(last_x)

        y_coords = []
        last_y = 0
        for flag in flags:
            if flag & 0x04: # Y short
                dy = data[offset]
                offset += 1
                if not (flag & 0x20):
                    dy = -dy
            elif flag & 0x20: # Y same/positive
                dy = 0
            else:
                dy = struct.unpack('>h', data[offset:offset+2])[0]
                offset += 2
            last_y += dy
            y_coords.append(last_y)

        # Plot to ASCII grid
        grid_w, grid_h = 60, 30
        grid = [[' ' for _ in range(grid_w)] for _ in range(grid_h)]

        min_x, max_x = min(x_coords), max(x_coords)
        min_y, max_y = min(y_coords), max(y_coords)

        dx_range = max_x - min_x if max_x != min_x else 1
        dy_range = max_y - min_y if max_y != min_y else 1

        def draw_line(x0, y0, x1, y1):
            steps = max(abs(x1 - x0), abs(y1 - y0), 1)
            for s in range(steps + 1):
                t = s / steps
                x = int(round(x0 + t * (x1 - x0)))
                y = int(round(y0 + t * (y1 - y0)))
                gx = int((x - min_x) / dx_range * (grid_w - 1))
                gy = int((max_y - y) / dy_range * (grid_h - 1))
                if 0 <= gx < grid_w and 0 <= gy < grid_h:
                    grid[gy][gx] = '#'

        start_idx = 0
        for c_end in end_pts:
            pts_c = list(zip(x_coords[start_idx:c_end+1], y_coords[start_idx:c_end+1]))
            for k in range(len(pts_c)):
                p1 = pts_c[k]
                p2 = pts_c[(k + 1) % len(pts_c)]
                draw_line(p1[0], p1[1], p2[0], p2[1])
            start_idx = c_end + 1

        print("\nASCII Render:")
        print("+" + "-" * grid_w + "+")
        for row in grid:
            print("|" + "".join(row) + "|")
        print("+" + "-" * grid_w + "+")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/inspect_glyph.py <hex_codepoint1> [hex_codepoint2 ...]")
        sys.exit(1)

    cp_args = [int(arg, 16) for arg in sys.argv[1:]]
    ttf_file = os.path.join(os.path.dirname(__file__), '../assets/fonts/phosphor/Phosphor-Light.ttf')
    parse_ttf(ttf_file, cp_args)
