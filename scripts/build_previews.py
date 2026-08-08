#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil

sys.path.append(os.path.join(os.path.dirname(__file__)))
import build_sprite_sheets as bss

def build_stills():
    base_dir = 'assets/images/raven'
    body = bss.read_png(os.path.join(base_dir, 'body.png'))
    wing_up = bss.read_png(os.path.join(base_dir, 'wing_up.png'))
    beak_open = bss.read_png(os.path.join(base_dir, 'beak_open.png'))
    eye_open = bss.read_png(os.path.join(base_dir, 'eye_open.png'))

    w, h = 256, 256
    bg_ground = (20, 17, 14, 255) # #14110E

    out_dir = '/tmp/pose'
    os.makedirs(out_dir, exist_ok=True)

    # Composite 1: body + wing_up + eye_open
    frame1 = [bg_ground] * (w * h)
    body_pixels = [(body[2][(y*w+x)*4], body[2][(y*w+x)*4+1], body[2][(y*w+x)*4+2], body[2][(y*w+x)*4+3]) for y in range(h) for x in range(w)]
    wing_up_pixels = [(wing_up[2][(y*w+x)*4], wing_up[2][(y*w+x)*4+1], wing_up[2][(y*w+x)*4+2], wing_up[2][(y*w+x)*4+3]) for y in range(h) for x in range(w)]
    eye_open_pixels = [(eye_open[2][(y*w+x)*4], eye_open[2][(y*w+x)*4+1], eye_open[2][(y*w+x)*4+2], eye_open[2][(y*w+x)*4+3]) for y in range(h) for x in range(w)]
    beak_open_pixels = [(beak_open[2][(y*w+x)*4], beak_open[2][(y*w+x)*4+1], beak_open[2][(y*w+x)*4+2], beak_open[2][(y*w+x)*4+3]) for y in range(h) for x in range(w)]

    for i in range(w * h):
        b = bss.blend(frame1[i], body_pixels[i])
        b = bss.blend(b, wing_up_pixels[i])
        b = bss.blend(b, eye_open_pixels[i])
        frame1[i] = b

    raw_frame1 = bytearray(w * h * 4)
    for i, p in enumerate(frame1):
        raw_frame1[i*4:i*4+4] = bytes(p)
    png1 = bss.write_png(w, h, raw_frame1)
    with open(os.path.join(out_dir, 'wing_up_still.png'), 'wb') as f:
        f.write(png1)

    # Composite 2: body + beak_open + eye_open
    frame2 = [bg_ground] * (w * h)
    for i in range(w * h):
        b = bss.blend(frame2[i], body_pixels[i])
        b = bss.blend(b, beak_open_pixels[i])
        b = bss.blend(b, eye_open_pixels[i])
        frame2[i] = b

    raw_frame2 = bytearray(w * h * 4)
    for i, p in enumerate(frame2):
        raw_frame2[i*4:i*4+4] = bytes(p)
    png2 = bss.write_png(w, h, raw_frame2)
    with open(os.path.join(out_dir, 'beak_open_still.png'), 'wb') as f:
        f.write(png2)

    print("Generated stills: /tmp/pose/wing_up_still.png and /tmp/pose/beak_open_still.png")

def render_preview_gif(pose_name, cols, rows, frames_cnt, fps=16):
    sheet_path = f'assets/images/raven/frames/{pose_name}.png'
    out_dir = '/tmp/pose'
    os.makedirs(out_dir, exist_ok=True)
    frames_tmp = os.path.join(out_dir, f'{pose_name}_f%02d.png')
    
    # Extract cells with ffmpeg untile
    cmd_untile = [
        'ffmpeg', '-y', '-loglevel', 'error',
        '-i', sheet_path,
        '-vf', f'untile={cols}x{rows}',
        '-frames:v', str(frames_cnt),
        frames_tmp
    ]
    subprocess.run(cmd_untile, check=True)

    gif_out = os.path.join(out_dir, f'{pose_name}_preview.gif')
    cmd_gif = [
        'ffmpeg', '-y', '-loglevel', 'error',
        '-framerate', str(fps),
        '-i', frames_tmp,
        '-f', 'lavfi', '-i', 'color=c=0x14110E:s=256x256',
        '-filter_complex', '[1][0]overlay=shortest=1,scale=320:320:flags=neighbor,split[a][b];[a]palettegen=reserve_transparent=0[p];[b][p]paletteuse',
        '-loop', '0',
        gif_out
    ]
    subprocess.run(cmd_gif, check=True)
    print(f"Generated GIF preview: {gif_out}")

def main():
    build_stills()
    previews = [
        ('flap', 3, 2, 6, 16),
        ('fly', 4, 2, 8, 16),
        ('preen', 4, 2, 8, 16),
        ('caw', 3, 2, 6, 16),
    ]
    for pose, cols, rows, n, fps in previews:
        render_preview_gif(pose, cols, rows, n, fps)

if __name__ == '__main__':
    main()
