# UI Design Direction — "Turn Down the Lamps"

A brainstorm for tightening Gaslight's visual identity so every screen feels like it belongs to the *same* world. Written to be reviewed the same way as the issues doc: where a direction is a genuine fork, it ends with **Options** and a `Your selection: _____` line.

> **Deliverable note:** this is a written direction, not code. Nothing here is required to fix a bug — it's about making the game *feel* like its name. If you want, I can also produce a clickable visual mockup of one screen (e.g. the Reveal) so you can see a direction before committing.
>
> ✅ **Approved.** The selected directions (§3 warm-neutral, §4 Cormorant + bundled fonts, §5 Option A motif, §7 icon overhaul, plus §6/§8/§9) are turned into a concrete `ThemeData` + widget execution plan in **`docs/implementation_plan_gameplay_and_ui.md` → Wave E**.

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

Your selection (warm-neutral shift): Sounds good. Proceed

---

## 4. Typography — bill the acts like a theater

Right now headers and body are both Lora, so "THE VOTE" carries no more weight than a paragraph. Introduce **one characterful display face** for the wordmark and phase titles, keep **Lora** for body, and add a **small-caps utility** for labels/timers.

Because the app targets the App Store and should work offline, **bundle the fonts as bundled assets** (`pubspec.yaml` `fonts:`) rather than fetching via `google_fonts` at runtime — a silent network fallback would break the identity.

**Display face options** (for `GASLIGHT`, `THE VOTE`, `THE REVEAL`, honor titles):

- **Option A (recommended) — Cormorant / Cormorant Garamond.** High-contrast, elegant, distinctly period without tipping into costume. Reads beautifully at large sizes with letter-spacing; pairs naturally with Lora. Less overused than Playfair.
- **Option B — Playfair Display.** Safe, dramatic Didone; very "Victorian." Downside: it's become an AI-default display serif, so it's the least distinctive choice.
- **Option C — A blackletter *only* for the `GASLIGHT` wordmark** (e.g. UnifrakturCook/Cinzel-adjacent) with Cormorant for phase titles. Highest drama, but blackletter is illegible for anything but the logo — use sparingly.

*Recommendation:* Option A for phase titles + a restrained blackletter/engraved treatment reserved for the wordmark only.

Your selection (display face): Sounds good. Proceed

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

Your selection (motif intensity): Option A

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

Your selection (icon overhaul now / later): Sounds good. Proceed

> ### ⚙️ SHIPPED STATE (revised August 6, 2026 — Issue 23, Option B & Issue 29, Option B)
>
> §7 as written above was delivered in Wave E as a fully bespoke `CustomPainter` set (`lib/theme/app_icons.dart`), and **that approach has since been partially reversed.** The hand-drawn set never normalised optical size: because each of the 19 glyphs was hand-tuned in fractional coordinates with no shared bounds pass, an identical `size:` produced ink from `0.38 w` (`key`) to `0.90 w` (`redraw`) — a ~2.4× spread, visible as a mismatched icon row on the entry form.
>
> **The icon system is now a hybrid using a vendored font asset**, and this is the current contract:
>
> - **The six avatar house sigils remain bespoke and hand-painted** — `flame`, `moth`, `key`, `raven`, `moon`, `hourglass`. The paragraph above about engraved crests still holds in full, including the `SigilTicker` / `AnimatedThematicIcon` animation work from V1/V2.
> - **The eleven functional affordances render from a vendored Phosphor Light font asset (`assets/fonts/phosphor/Phosphor-Light.ttf`)** — `writing`, `redraw`, `timer`, `secret`, `ledger`, `envelope`, `observe`, `confirm`, `sound`, `mute`, `host`. Light was chosen because its 1.5 px nominal stroke matches the painter's hairline `max(1.5, w/16)`, preserving "single-weight brass line icons for consistency."
> - **No third-party icon package dependency is used.** The code points are mapped via local `const IconData` constants in `lib/theme/app_icons.dart` using `fontFamily: 'PhosphorLight'` without `fontPackage`. This removed ~2.43 MB of unused font weight assets (`Thin`, `Duotone`, `Bold`, `Regular`, `Fill`) from the shipped app bundle.
> - `ThematicIcon` remains the **single public entry point**; the fork is internal (`app_icons.dart:33` `_bespokeSigils`, `:42` `_phosphorGlyphs`).
>
> **The trade-off, stated plainly:** Phosphor is a modern geometric set, not a Victorian one. This concedes some of the period specificity §7 was written to win, in exchange for metric consistency that the bespoke set could not deliver without a normalisation pass. That trade was offered as Issue 23 Option B and explicitly selected. The alternative — Option A, an optical-bounds table applied to all 19 bespoke glyphs — remains available if the geometric style reads as a "stock UI tell" in practice.
>
> **Known residual:** sigil-to-sigil optical sizing is still uneven, since normalisation was not applied to the six retained glyphs. It reads acceptably because the character tokens sit inside medallions that impose their own frame. Fix path if review disagrees: Issue 23 Option A, scoped to those six.
>
> ### 🔒 Historical SDK constraint — why `phosphor_flutter` was unviable
>
> **The upstream `phosphor_flutter` package cannot compile under modern Flutter SDKs.** This was empirically proven on August 6, 2026:
>
> ```
> phosphor_flutter-2.1.0/lib/src/phosphor_icon_data.dart:5:32: Error: The class 'IconData'
> can't be extended outside of its library because it's a final class.
> ```
>
> Flutter declares `final class IconData` (`flutter/lib/src/widgets/icon_data.dart:23`, SDK 3.44.6). A `final` class cannot be extended outside its own library, and `phosphor_flutter` is built on `class PhosphorIconData extends IconData`. No version of that package can build against a modern SDK until upstream stops subclassing. Vendoring the single `Phosphor-Light.ttf` font asset with local `IconData` constants completely decouples the app from external icon wrapper packages.

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

> **STATUS (July 16, 2026): this direction has SHIPPED — every row below is ✅ delivered**, via the U-pass (U0–U8 + UF punch list), the mobile-first pass (M1–M5), and the character pass (V1–V5). The world now also contains what this doc only dreamed of: a procedural wax seal, the gaslight-flicker scene change, the dealt-card handoff, the honors ceremony, the Lamplighter's Raven mascot, living sigils, reaction medallions, the deck dossier carousel, and lamp-lighting loading states. Delivery records: `ongoing_general_errors.md` (U/M/V sections); implementation specs preserved in `agent_execution_guide.md` history. This table is retained as the original plan of record.

| Tier | Change | Effort | Payoff |
|------|--------|--------|--------|
| **Quick wins** | Warm-neutral palette shift (§3); aged brass; tabular figures; verdigris for truth | Low | Instant cohesion |
| | Lamp-pool background + vignette (§5a) | Low–Med | Every screen feels like one room |
| | Display font for titles + bundled fonts (§4) | Low–Med | Screens feel "billed" / period |
| **Mid** | Retire Material icons for a line set (§7); active-reader lamp halo | Med | Removes the biggest "stock UI" tell |
| | Reveal drama: staggered votes, truth seal, Best-Forgery banner (§6) | Med | The screen people remember |
> ### 🐦 MASCOT SYSTEM (revised August 7, 2026 — Issue 32, Option D)
>
> The Lamplighter's Raven mascot (`lib/widgets/raven_mascot.dart`) was converted from a hand-drawn `CustomPainter` to a **layered raster asset system** on a shared 1024×1024 canvas.
>
> - **Artwork:** Flat vector mascot styled in clean, bold silhouette (brass rim-light `#C9A24B` outline, warm body `#2E2A26`, ivory eye `#F5EEDB`, brass beak). Tested contrast: **18.59:1** rim-light contrast against `#14110E` ground.
> - **Asset layers:** `assets/images/raven/{body,wing,eye_open,eye_closed}.png` with density variants (`2.0x/`, `3.0x/`). Prompts recorded in `assets/images/raven/PROMPTS.md`.
> - **Animation contract:** Preserves all 5 screen poses (`sleep`, `idle`, `hop`, `ruffle`, `fly`) and reduced-motion static frame fallback. `RavenMascot` public API and call sites remain unchanged.
