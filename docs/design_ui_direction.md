# UI Design Direction — "Turn Down the Lamps"

A brainstorm for tightening Gaslight's visual identity so every screen feels like it belongs to the *same* world. Written to be reviewed the same way as the issues doc: where a direction is a genuine fork, it ends with **Options** and a `Your selection: _____` line.

> **Deliverable note:** this is a written direction, not code. Nothing here is required to fix a bug — it's about making the game *feel* like its name. If you want, I can also produce a clickable visual mockup of one screen (e.g. the Reveal) so you can see a direction before committing.

---

## 1. The North Star (one sentence)

**Gaslight is a gas-lit Victorian parlor after dark, where every player is a suspect and nothing on the table is quite what it seems.**

That is more specific than the current "dark fantasy tavern / gothic" read, and it's true to the name (the 1944 film *Gaslight* = manipulation, doubt, lamplight, Victorian London). Every design decision below is derived from that one image: **lamplight and shadow, brass and oxblood, ink and evidence, concealment and reveal.**

---

## 2. What's already working (keep it)

The foundation is genuinely good and should be preserved, not thrown out:
- **Crimson + gold + parchment** palette and the **Lora** serif establish period and mood immediately.
- **`CrimsonShadowCard`** (coal + crimson glow) and **`ParchmentCard`** (parchment + gold border) are a strong two-surface system: "the room" (dark) vs. "the document" (parchment).
- The **red wax-seal stamp** on vote selection (`card_grid.dart`) is the single most on-theme micro-interaction in the app. It should become a recurring motif, not a one-off.
- The **gem-chip player tokens** (`player_avatar.dart`) already read as poker chips / signet stones.

The problem isn't quality — it's **consistency and specificity**. Three things dilute the theme: (a) the neutral ground is a cool green-black while lamplight is warm; (b) Material icons (`remove_red_eye`, `timer`, `casino`) break the period spell; (c) titles are set in the same body serif, so nothing feels "billed" like a theater act.

---

## 3. Palette refinement — bias the neutrals toward lamplight

Small shifts, big cohesion. The accents mostly stay; the **neutral gets a deliberate warm bias** (a picked neutral, not an inherited one), and each color gets a *job*.

| Token | Now | Proposed | Job |
|-------|-----|----------|-----|
| `ground` (scaffold) | `#141A17` cool green-black | **`#14110E` warm soot** | The dark room; everything sits in shadow |
| `ground-raised` (cards) | `#1A1F1C` | **`#1C1712`** | Raised surfaces catching lamplight |
| `primary` oxblood | `#8B0000` | keep (maybe `#7B1E1E` for large fills) | Danger, blood, wax, forgery |
| `secondary` brass | `#D4AF37` bright gold | **`#C9A24B` aged brass** | Lamplight, framing, "the house" |
| `truth` green | `#1B5E20` deep emerald | **`#2E6E5B` verdigris** | The Truth — oxidized copper reads better on dark |
| `parchment` | `#F4EBD8` | keep | Evidence/documents only — never a screen background |
| `ink` | `#2C1E16` | keep | Text on parchment |

**Why aged brass over bright gold:** #D4AF37 is a jewelry gold that pops toward "fantasy." #C9A24B reads as a **brass lamp fitting under warm light** — quieter, more period, and it stops the gold from competing with the crimson for attention. Spend the boldness on the crimson; keep the brass supporting.

**Semantic vs. accent:** keep verdigris (truth/correct) and crimson (forgery/wrong) as *semantic* colors in the Reveal, distinct from brass as the *brand* accent. Don't let all three shout at once.

Your selection (warm-neutral shift): _____

---

## 4. Typography — bill the acts like a theater

Right now headers and body are both Lora, so "THE VOTE" carries no more weight than a paragraph. Introduce **one characterful display face** for the wordmark and phase titles, keep **Lora** for body, and add a **small-caps utility** for labels/timers.

Because the app targets the App Store and should work offline, **bundle the fonts as bundled assets** (`pubspec.yaml` `fonts:`) rather than fetching via `google_fonts` at runtime — a silent network fallback would break the identity.

**Display face options** (for `GASLIGHT`, `THE VOTE`, `THE REVEAL`, honor titles):

- **Option A (recommended) — Cormorant / Cormorant Garamond.** High-contrast, elegant, distinctly period without tipping into costume. Reads beautifully at large sizes with letter-spacing; pairs naturally with Lora. Less overused than Playfair.
- **Option B — Playfair Display.** Safe, dramatic Didone; very "Victorian." Downside: it's become an AI-default display serif, so it's the least distinctive choice.
- **Option C — A blackletter *only* for the `GASLIGHT` wordmark** (e.g. UnifrakturCook/Cinzel-adjacent) with Cormorant for phase titles. Highest drama, but blackletter is illegible for anything but the logo — use sparingly.

*Recommendation:* Option A for phase titles + a restrained blackletter/engraved treatment reserved for the wordmark only.

Your selection (display face): _____

**Type scale & treatment:**
- Phase titles: display face, ~28–32px, `letterSpacing: 3`, brass, with a soft dark drop-shadow (a "spotlight" feel).
- Section labels ("CASE PROMPT", "VOTES", "POINTS AWARDED"): Lora small-caps, ~12px, `letterSpacing: 2`, brass at 70%.
- Body/answers: Lora, keep. Ensure parchment answers use `ink` (#2C1E16) at full strength for contrast.
- Numbers (timer, scores): add `fontFeatures: [FontFeature.tabularFigures()]` so digits don't jitter as they tick.

---

## 5. The unifying motif — the case file & the gas lamp

Two devices, applied everywhere, make the app feel authored:

**(a) The lamp-pool background.** Replace the flat scaffold with a subtle warm **radial light** (top-center) falling off into a **vignette** at the edges — as if a single gas lamp lights the table. This one change makes every screen feel like the same room. It can layer *under* the existing `AnimatedThinkingBackground` glyphs (dim them so they read as dust motes in lamplight, not sparkles).

**(b) Concealment → reveal.** The whole game is hidden identity. Lean into it:
- Forgeries during voting are **anonymous cards** — good already. Add a faint **wax-seal watermark** on the back-face styling.
- On the **Reveal**, flip each forgery card (a quick 3D `RotationY` flip) from a **wax-sealed back** to the **author's name + token** — the seal "cracks" open. This turns scoring into a series of little unmaskings.
- Hidden authorship elsewhere uses a **redaction bar** (a brushed-ink black rectangle) rather than blank space.

**Motif intensity options:**
- **Option A (recommended)** — Lamp-pool background everywhere + wax-seal/redaction concealment + card-flip reveal. Cohesive, still performant.
- **Option B** — Lamp-pool background only (cheapest cohesion win), defer the flip/redaction work.

Your selection (motif intensity): _____

---

## 6. Component-by-component upgrades

**Buttons (`shared_ui.dart`).** `PrimaryButton` is solid burgundy — good for "commit" actions (SUBMIT, CONFIRM VOTE). Add a **pressed "stamp" feel**: on tap, a quick scale-down + a faint wax-ring flash, echoing the vote seal. `SecondaryButton` is emerald — retheme to verdigris and reserve it strictly for host/utility actions so color = meaning.

**Player tokens (`player_avatar.dart`).** Strong already. Two upgrades: (1) add a thin **engraved bevel** (inner highlight top-left, shadow bottom-right) so chips read as pressed metal/stone; (2) give the **active reader** a **brass halo / lamplight ring** so "whose card is this" is unmistakable at a glance.

**Timer (`auto_advance_timer.dart`).** Reframe from a digital countdown to a **guttering lamp / pocket-watch**: keep the number (tabular figures) but when `isLowTime`, make the lamp-pool background pulse and the ring flicker rather than just turning red. Period-correct urgency.

**Prompt / craft screen (`phase2_craft.dart`).** The prompt already sits on a `CrimsonShadowCard` labeled "CASE PROMPT" — very good. Style the text field as an **inkwell / telegram form** (thin brass underline instead of a full box, a quill/nib cursor accent). Show the target as *"A forgery on behalf of —"* with their token, reinforcing the impersonation fantasy.

**Vote grid (`card_grid.dart`).** Answers as **evidence cards** on the table. Selected = wax seal (keep). Add: the disabled "(Your Forgery)" card gets a subtle **"SEALED — your own hand" ribbon** so it reads as intentional, not broken.

**Reveal (`phase4_reveal.dart`).** This is the money screen — give it the most craft: staggered vote-chip landing, Truth revealed last in verdigris with a **stamped "THE TRUTH" seal**, forgery cards **flip to unmask** authors, and a **"Best Forgery of the Round"** banner. (Ties directly to the honor-stats work selected in `design_scoring_and_ui.md` Clarification 2.)

**Game Over (`game_over_screen.dart`).** Present honors as **framed portraits on a parlor wall** (brass frames, engraved plaques) rather than flat cards. The stubbed "Share to Instagram" becomes an exportable **"Case Closed" dossier card** (see Proposal P6).

---

## 7. Iconography — retire the Material icons

`remove_red_eye`, `timer`, `casino`, `vpn_key`, `lightbulb_outline` are instantly recognizable as stock Material and quietly break the period. Move to a **thin-line Victorian icon set**: a **monocle/magnifier** (spectator/observe), **pocket-watch** (timer), **quill & nib** (writing), **wax seal** (submit/confirm), **skeleton key** (secret), **candelabra/gas lamp** (host/light). Keep them single-weight brass line icons for consistency. Bundle as an icon font or SVGs.

For the **avatar tokens**, swap the six Material glyphs for six **engraved "house sigils"** (moth, moon, key, raven, hourglass, flame) so each player is a little crest rather than a UI icon.

Your selection (icon overhaul now / later): _____

---

## 8. Motion, sound & feel (restraint required)

The current app has nice entrance tweens; the risk is *scattered* motion reading as generic. Concentrate it into a few **orchestrated moments**:
- **Wax stamp** on any commit (vote, submit, ready).
- **Card flip / seal-crack** on reveal.
- **Lamp flicker** on low timer and on phase transitions (a brief dim-then-brighten as the "scene changes").
- Optional, high-impact: a few **bundled sounds** — quill scratch on submit, a wax *thunk* on vote, a low string swell on the Truth reveal — plus **haptics** on commit/reveal. Sound is the cheapest way to make a party game feel expensive. (Needs asset licensing; gate behind a mute toggle.)
- Respect reduced-motion / provide a "reduce motion" setting for App Store accessibility.

---

## 9. Accessibility & polish checklist
- Ensure parchment answer text uses full-strength `ink`; the current 0.4-opacity "(Your Forgery)" is borderline — pair the dimming with the ribbon so meaning isn't carried by contrast alone.
- Verify brass-on-soot and ivory-on-soot meet WCAG AA at body sizes (the warmer brass helps here).
- The game is single-theme (always dark, by design) — that's a legitimate committed choice given "Gaslight"; document it so no one "adds light mode" by reflex. If a light mode is ever wanted, it should be a **"daylight / evidence room"** variant (parchment ground), not an inversion.
- Tabular figures on all live numbers (timer, scores, "ready X/Y").

---

## 10. Suggested roadmap (quick wins → bigger bets)

| Tier | Change | Effort | Payoff |
|------|--------|--------|--------|
| **Quick wins** | Warm-neutral palette shift (§3); aged brass; tabular figures; verdigris for truth | Low | Instant cohesion |
| | Lamp-pool background + vignette (§5a) | Low–Med | Every screen feels like one room |
| | Display font for titles + bundled fonts (§4) | Low–Med | Screens feel "billed" / period |
| **Mid** | Retire Material icons for a line set (§7); active-reader lamp halo | Med | Removes the biggest "stock UI" tell |
| | Reveal drama: staggered votes, truth seal, Best-Forgery banner (§6) | Med | The screen people remember |
| **Bigger bets** | Card-flip "unmasking" reveal + redaction motif (§5b) | Med–High | Signature interaction |
| | Sound design + haptics + mute toggle (§8) | Med–High | "Expensive" feel; shareable clips |
| | "Case Closed" shareable dossier export (§6, Proposal P6) | Med | Organic marketing at launch |

---

### Open directional selections (summary)
- Warm-neutral shift (§3): _____
- Display face (§4): _____
- Motif intensity (§5): _____
- Icon overhaul now/later (§7): _____

Pick any subset and I'll turn the chosen items into a concrete `ThemeData` + widget implementation plan (like `implementation_plan_selected_fixes.md`), or mock one screen visually first.
