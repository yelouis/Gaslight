# Raven Mascot Art Generation Prompts

Generated on August 7, 2026 for Issue 32 Option D.

## Master Generation Prompt (Gemini / nano banana)

```text
A simple flat vector mascot of a crow, front-facing three-quarter view, for a Victorian gaslight-themed party game.

Style: extremely simple and bold, like the characters in Among Us — one clean rounded silhouette, no gradients, no texture, no feather detail, no shading. Flat fills only, at most four colours. Chunky and friendly, slightly plump body, short tail, small visible wing, one large expressive eye. Readable at 48 pixels tall.

Colours, exactly: body #2E2A26; a 3-pixel rim-light outline along the top and left of the silhouette in brass #C9A24B; beak brass #C9A24B; eye ivory #F5EEDB with a #14110E pupil.

The character sits on a very dark background (#14110E), so the brass rim-light is what makes it visible — keep the outline unbroken and clearly separated from the body fill.

Square canvas 1024×1024, transparent background (PNG with alpha), subject centred with roughly 10% padding. No text, no drop shadow, no scenery, no ground line.
```

## Layer Separation Brief

Every layer exported on shared 1024×1024 canvas for pixel-perfect Stack alignment:
- `body.png`: Main crow body silhouette + brass rim-light + beak + tail. Solid body fill under eye.
- `wing.png`: Near wing with brass stroke.
- `eye_open.png`: Ivory eye circle with pupil.
- `eye_closed.png`: Downward curved brass arc for sleeping pose.

## Task T6 Frame Briefs & Sheet Assembly (August 8, 2026)

For transient poses (`ruffle`, `hop`, `fly`, `alert`, `peck`, `preen`, `startle`, `bow`, `caw`, `flap`), frame sequences are composite grid sheets (256×256 px cells, single 1x density, left-to-right top-to-bottom layout).

### Transient Pose Frame Briefs (10 grid sheets)
- **`ruffle`** (8 frames, 1024×512): Frame 0 resting -> frames 1–6 body expansion (scale 1.18x), wing rotation (0.20 rad) & feather wave -> frame 7 resting.
- **`startle`** (6 frames, 768×512): Frame 0 resting -> frames 1–3 flinch pop (scale 1.08x, translate_y -18px, wing flare) -> frame 4 settle -> frame 5 resting.
- **`hop`** (8 frames, 1024×512): Frame 0 resting -> frame 1 crouch -> frames 2–4 arc jump (translate_y -24px, wing flare) -> frames 5–6 land impact & rebound -> frame 7 resting.
- **`peck`** (6 frames, 768×512): Frame 0 resting -> frame 1 wind-up -> frames 2–3 sharp peck down (rotate 0.32 rad, translate_x 8px, translate_y 10px) -> frame 4 snap-back -> frame 5 resting.
- **`bow`** (8 frames, 1024×512): Frame 0 resting -> frames 1–2 forward tilt -> frames 3–4 deep ceremony bow (rotate 0.38 rad, translate_y 9px) -> frames 5–6 return -> frame 7 resting.
- **`alert`** (6 frames, 768×512): Frame 0 resting -> frames 1–3 head/body snap (rotate -0.25 rad, translate_y -6px) -> frame 4 ease back -> frame 5 resting.
- **`preen`** (8 frames, 1024×512): Frame 0 resting -> frames 1–4 wing raise & body tilt (rotate -0.18 rad, wing_rot -0.44 rad) -> frames 5–6 release -> frame 7 resting.
- **`fly`** (8 frames, 1024×512): Frame 0 resting -> frames 1–4 rising wing sweep (translate_y -40px, wing_rot 0.35 rad) -> frames 5–6 glide down -> frame 7 resting.
- **`flap`** (6 frames, 768×512): Frame 0 resting -> frames 1–4 alternating `wing` / `wing_up` flaps with vertical lift -> frame 5 resting.
- **`caw`** (6 frames, 768×512): Frame 0 resting -> frames 1–3 body scale & tilt back with `beak_open` overlay -> frames 4–5 beak close & return -> frame 5 resting.

### Sheet Assembly Command
```bash
python3 scripts/build_sprite_sheets.py
```
Outputs `assets/images/raven/frames/{ruffle,startle,hop,peck,bow,alert,preen,fly,flap,caw}.png`.

