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

### Ruffle Frame Sequence Brief (8 frames, 4 cols × 2 rows grid sheet)
- **Frame 0**: Exact resting pose (`body.png` + `wing.png` + `eye_open.png`).
- **Frames 1–6**: Authored ruffle expansion and feather wave displacement sequence (body puffing up to 1.18x, wing rotation up to 0.20 rad, feather wave oscillation).
- **Frame 7**: Settled resting pose returning seamlessly to resting alignment.

### Sheet Assembly Command
```bash
python3 scripts/build_sprite_sheets.py
```
Outputs `assets/images/raven/frames/ruffle.png` (1024×512, 8 cells).

