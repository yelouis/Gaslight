# Audio Asset Credits & Licenses

All sound effects in this directory are **CC0 1.0 (Creative Commons Zero / Public Domain)**.
No attribution is legally required; Kenney is credited voluntarily as a courtesy.
Free for personal, educational, and commercial use.

| File | Source pack | Original file | License | URL |
|------|-------------|---------------|---------|-----|
| `quill_scratch.wav` | Kenney — Interface Sounds (1.0) | `scratch_004.ogg` | CC0 1.0 | https://kenney.nl/assets/interface-sounds |
| `wax_stamp.wav` | Kenney — Impact Sounds (1.0) | `impactPunch_medium_000.ogg` (trimmed to 300 ms) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `truth_reveal.wav` | Kenney — Impact Sounds (1.0) | `impactBell_heavy_001.ogg` | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `unmask_success.wav` | Kenney — Interface Sounds (1.0) | `confirmation_001.ogg` | CC0 1.0 | https://kenney.nl/assets/interface-sounds |

## Processing applied
Each file was converted to **mono, 44.1 kHz, 16-bit PCM WAV** (chosen for universal
iOS + Android + web support and low latency) and **peak-normalized to −3 dBFS** via ffmpeg.
`wax_stamp.wav` was additionally trimmed to 300 ms with a 50 ms fade-out tail.
Source: `tool/`-free; reproducible from the Kenney CC0 packs above.

## Not yet sourced
- `lobby_ambience` (optional looping drone) — Kenney's interface/impact packs contain no
  ambient bed. If desired, source a CC0 dark-ambient loop (e.g. Freesound CC0 filter, or
  Kenney has no match) and add it here with its license row.

## License text
CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
Kenney packs ship a `License.txt` confirming CC0; retained in the source zips.
