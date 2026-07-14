# Audio Selection Review — Second Opinion Needed

**You are a reviewing model/agent giving an independent second opinion on Gaslight's sound effects.** A first pass already chose one sound per game moment (the files marked `_CURRENT`). Your job: **listen to all candidates and pick the best one per slot** — agreeing or overriding the current pick — using the criteria below. There are **3 candidates for each of the 4 sounds**.

This is for a Victorian **"gaslight mystery"** party game (social bluffing; write fake answers, vote, a dramatic reveal). Theme = a gaslit parlor after dark: ink, wax seals, brass, bells, candlelight. All 12 candidates are **CC0 (public domain)** from Kenney's Interface/Impact packs, converted to mono 44.1 kHz 16-bit WAV and peak-normalized to −3 dBFS, so **loudness is already matched — judge on character, not level.**

---

## How to "listen"

Pick whichever applies to you:

1. **If you can ingest audio directly** — load each `.wav` in the slot folders (`1_submit/`, `2_vote/`, `3_reveal/`, `4_unmask/`) and compare them by ear. This is the preferred path.
2. **If you drive a shell with speakers (macOS)** — play each file and listen:
   ```bash
   afplay audio_review/1_submit/submit_A_scratch004_CURRENT.wav      # macOS built-in
   # or, cross-platform:
   ffplay -autoexit -nodisp audio_review/1_submit/submit_B_scratch002.wav
   ```
   Play the three files in a slot back-to-back before deciding.
3. **If you genuinely cannot hear audio** — use the **Objective fallback data** in each slot below (duration, spectral centroid = "brightness" in Hz, and an ASCII amplitude envelope where `@`=loud … ` `=silent, left→right = time). Match those numbers against the slot's criteria. State clearly in your output that you judged by data, not by ear — a real audition should still follow.

**Always compare candidates within a slot against each other, and the four winners against each other (criterion G5).**

---

## Selection criteria

### Global (apply to every sound)
- **G1 · Thematic fit.** Favor organic/physical/analog materials (ink, paper, wax, wood, brass, bells, cloth). Reject anything that reads digital, 8-bit, sci-fi, cartoonish, or like a phone notification.
- **G2 · Envelope matches the gesture.** The amplitude shape should fit the action: a *commit/lock* wants a firm immediate transient (fast attack); a *reveal* wants a weighty bloom/toll that sustains under the animation; a *write* wants a textured, softer sound with **no** hard click.
- **G3 · Duration fits pacing.** Frequent cues must be short so they never delay the UI; the once-per-card reveal can be long enough to carry drama but not stall. (Target ranges are given per slot.)
- **G4 · Repeat tolerance.** These fire many times per game. Avoid anything that grates on repetition: piercing highs, long ringing tails on *frequent* cues, or melodic phrases that fatigue. Frequent cues should be understated; rare cues may be more expressive.
- **G5 · Mutual distinctiveness.** The four chosen cues must be easy to tell apart — contrast their frequency register and timbre (ideally: submit = mid/noisy, vote = low thud, reveal = low resonant toll, unmask = brighter tonal). If two winners sound too alike, reconsider one.
- **G6 · Clean & unclipped.** No clipping; no click at start/end; a clean decay tail.
- **G7 · Emotional tone.** Reveal = ominous/theatrical (**not** celebratory). Unmask = rewarding/positive (a small "gotcha"). Submit/vote = neutral-satisfying, never alarming (must not read as an "error" buzzer).

### How to weigh them
When criteria conflict, priority is roughly **G1 (theme) ≥ G2 (envelope) > G7 (tone) > G4 (repeat) > G3 (duration) > G5 (distinctiveness) > G6 (hygiene, since all are already clean)**. Theme and gesture-fit win; duration is a guardrail, not a target to hit exactly.

---

## Slot 1 — SUBMIT (the "quill scratch")
**Moment:** a player taps SUBMIT to lock in a forged/true answer. Fires on **every** submission (frequent). **Canonical output name:** `quill_scratch.wav` → `AudioService.playSubmit()`.
**Slot criteria:** should read as *ink/pen on paper* — textured, a little scratchy, **soft attack** (no hard click), understated (G4 — heard constantly). Target **120–350 ms**. Mid brightness reads as "paper"; very bright can feel harsh on repeat.

| Candidate | Dur | Brightness | Envelope | Note |
|---|---|---|---|---|
| **A** `submit_A_scratch004_CURRENT.wav` | 325 ms | ~1490 Hz | two soft strokes, mellow | current pick — gentlest |
| **B** `submit_B_scratch002.wav` | 139 ms | ~4375 Hz | sustained scratchy | brightest/"scratchiest," snappier |
| **C** `submit_C_scratch003.wav` | 123 ms | ~5225 Hz | two quick bursts | brightest & shortest |

## Slot 2 — VOTE / STAMP (the "wax seal")
**Moment:** a player confirms a vote, and the reader taps "I'M READY." A decisive lock-in (frequent). **Canonical name:** `wax_stamp.wav` → `AudioService.playVote()`.
**Slot criteria:** a **firm, satisfying "thunk/press"** like a wax seal or stamp pressed onto paper/desk — fast attack, quick decay, weight in the **low/low-mid** register (G2, G5 wants this to be the "low" cue). Target **150–350 ms**. Not a violent "punch," not a long metallic ring.

| Candidate | Dur | Brightness | Envelope | Note |
|---|---|---|---|---|
| **A** `vote_A_punchMed000_CURRENT.wav` | 300 ms | ~516 Hz | punchy thump, short tail | current pick — weighty |
| **B** `vote_B_wood000.wav` | 271 ms | ~90 Hz | very low, sharp knock | most "stamp on wood," deepest |
| **C** `vote_C_plateLight000.wav` | 542 ms | ~458 Hz | hard hit, longer tail | more metallic/resonant, longest |

## Slot 3 — TRUTH REVEAL (the toll)
**Moment:** the Truth card flips during the reveal — the dramatic beat, **once per card** (rare). **Canonical name:** `truth_reveal.wav` → `AudioService.playReveal()`.
**Slot criteria:** **gravitas.** A resonant **bell toll** (or swell) that blooms and decays under the flip animation — ominous/theatrical (G7), low-mid resonant tone. Target **~1–2 s** (long enough to underscore the moment; not so long it stalls pacing). *Note: a rising synth "swell" was not available in CC0 packs; all three options are bells — pick the most fitting toll, or flag if none work.*

| Candidate | Dur | Brightness | Envelope | Note |
|---|---|---|---|---|
| **A** `reveal_A_bell001_CURRENT.wav` | 1740 ms | ~315 Hz | strike + long decay | current pick — deep, longest |
| **B** `reveal_B_bell000.wav` | 1480 ms | ~505 Hz | strike + decay | brighter bell, slightly shorter |
| **C** `reveal_C_bell004.wav` | 299 ms | ~270 Hz | short toll | much shorter — likely too brief for the beat |

## Slot 4 — UNMASK SUCCESS (the reward)
**Moment:** you correctly guess who wrote the lie that fooled you. A positive payoff (occasional). **Canonical name:** `unmask_success.wav` → `AudioService.playUnmaskSuccess()`.
**Slot criteria:** a **positive, rewarding sting** — brighter/tonal, a small triumphant "gotcha," but still classy (a chime/confirmation, not a game-show fanfare). Target **200–500 ms**. Must feel clearly *positive* and be **distinct from the ominous reveal** (G5/G7).

| Candidate | Dur | Brightness | Envelope | Note |
|---|---|---|---|---|
| **A** `unmask_A_confirm001_CURRENT.wav` | 290 ms | ~700 Hz | warm chime, stepped decay | current pick — warm, rounded |
| **B** `unmask_B_confirm003.wav` | 322 ms | ~2550 Hz | bright chime | brighter, more "success-y" |
| **C** `unmask_C_pluck002.wav` | 162 ms | ~2675 Hz | short bright pluck | terse, plucky, least "chime" |

---

## Your output — fill this in

For each slot give: the chosen filename, whether you agree with the `_CURRENT` pick (Y/N), and a one-line reason grounded in the criteria (cite the G# / slot rule that drove it). End with a distinctiveness check across your four winners, and how you judged (by ear vs. objective data).

```
Slot 1 SUBMIT  → chosen: ______________________  agree with current? [Y/N]  reason: ____________________
Slot 2 VOTE    → chosen: ______________________  agree with current? [Y/N]  reason: ____________________
Slot 3 REVEAL  → chosen: ______________________  agree with current? [Y/N]  reason: ____________________
Slot 4 UNMASK  → chosen: ______________________  agree with current? [Y/N]  reason: ____________________

Distinctiveness check (G5): are the 4 winners easily distinguishable? ________________________________
Judged by:  [ ] ear   [ ] objective data only
Any slot where NONE are acceptable (needs re-sourcing)? __________________________________________
```

## After selection
For each slot, copy the winner to `assets/audio/` under its **canonical name** (above), overwriting if needed, and update `assets/audio/CREDITS.md` if the source file changed. Then delete this `audio_review/` folder (it must not ship in the app bundle). The wiring spec is in `docs/agent_execution_guide.md` → item **S1**.
