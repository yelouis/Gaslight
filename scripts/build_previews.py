#!/usr/bin/env python3
"""Task T9 preview generator:
  1. Still of body_base alone (on #14110E ground)
  2. Stills of beak_closed, beak_open, wing_folded, wing_up each composited over body_base + eye_open
  3. GIF previews for all 10 poses (re-rendered from new layer set)
"""
import os
import sys
import subprocess

sys.path.append(os.path.join(os.path.dirname(__file__)))
import build_sprite_sheets as bss

ARTIFACT_DIR = os.environ.get('ARTIFACT_DIR', '/tmp/pose')


def composite_still(layers_pixels, w, h, bg=(20, 17, 14, 255)):
    """Composite a list of pixel arrays (bytearray) over a solid background."""
    frame = [bg] * (w * h)
    for pix in layers_pixels:
        for i in range(w * h):
            p = bss.get_pixel(pix, w, h, i % w, i // w)
            frame[i] = bss.blend(frame[i], p)
    raw = bytearray(w * h * 4)
    for i, p in enumerate(frame):
        raw[i * 4:i * 4 + 4] = bytes(p)
    return raw


def build_stills():
    base_dir = 'assets/images/raven'
    w, h = 256, 256

    body_base = bss.read_png(os.path.join(base_dir, 'body_base.png'))
    beak_closed = bss.read_png(os.path.join(base_dir, 'beak_closed.png'))
    beak_open = bss.read_png(os.path.join(base_dir, 'beak_open.png'))
    wing_folded = bss.read_png(os.path.join(base_dir, 'wing_folded.png'))
    wing_up = bss.read_png(os.path.join(base_dir, 'wing_up.png'))
    eye_open = bss.read_png(os.path.join(base_dir, 'eye_open.png'))

    os.makedirs(ARTIFACT_DIR, exist_ok=True)

    stills = {
        # 1. body_base alone
        'body_base_still.png': [body_base[2]],
        # 2. body_base + wing_folded + beak_closed + eye_open (resting composite)
        'resting_composite.png': [body_base[2], wing_folded[2], beak_closed[2], eye_open[2]],
        # 3. body_base + beak_closed + eye_open
        'beak_closed_still.png': [body_base[2], beak_closed[2], eye_open[2]],
        # 4. body_base + beak_open + eye_open
        'beak_open_still.png': [body_base[2], beak_open[2], eye_open[2]],
        # 5. body_base + wing_folded + eye_open
        'wing_folded_still.png': [body_base[2], wing_folded[2], eye_open[2]],
        # 6. body_base + wing_up + eye_open
        'wing_up_still.png': [body_base[2], wing_up[2], eye_open[2]],
    }

    for name, layer_list in stills.items():
        raw = composite_still(layer_list, w, h)
        png = bss.write_png(w, h, raw)
        path = os.path.join(ARTIFACT_DIR, name)
        with open(path, 'wb') as f:
            f.write(png)
        print(f"Generated still: {path}")


def render_preview_gif(pose_name, cols, rows, frames_cnt, fps=16):
    sheet_path = f'assets/images/raven/frames/{pose_name}.png'
    os.makedirs(ARTIFACT_DIR, exist_ok=True)
    frames_tmp = os.path.join(ARTIFACT_DIR, f'{pose_name}_f%02d.png')

    cmd_untile = [
        'ffmpeg', '-y', '-loglevel', 'error',
        '-i', sheet_path,
        '-vf', f'untile={cols}x{rows}',
        '-frames:v', str(frames_cnt),
        frames_tmp,
    ]
    subprocess.run(cmd_untile, check=True)

    gif_out = os.path.join(ARTIFACT_DIR, f'{pose_name}_preview.gif')
    cmd_gif = [
        'ffmpeg', '-y', '-loglevel', 'error',
        '-framerate', str(fps),
        '-i', frames_tmp,
        '-f', 'lavfi', '-i', 'color=c=0x14110E:s=256x256',
        '-filter_complex',
        '[1][0]overlay=shortest=1,scale=320:320:flags=neighbor,split[a][b];'
        '[a]palettegen=reserve_transparent=0[p];[b][p]paletteuse',
        '-loop', '0',
        gif_out,
    ]
    subprocess.run(cmd_gif, check=True)
    print(f"Generated GIF: {gif_out}")


def main():
    build_stills()

    # All 10 poses
    previews = [
        ('ruffle', 4, 2, 8, 16),
        ('startle', 3, 2, 6, 16),
        ('hop', 4, 2, 8, 16),
        ('peck', 3, 2, 6, 16),
        ('bow', 4, 2, 8, 16),
        ('alert', 3, 2, 6, 16),
        ('preen', 4, 2, 8, 16),
        ('fly', 4, 2, 8, 16),
        ('flap', 3, 2, 6, 16),
        ('caw', 3, 2, 6, 16),
    ]
    for pose, cols, rows, n, fps in previews:
        render_preview_gif(pose, cols, rows, n, fps)


if __name__ == '__main__':
    main()
