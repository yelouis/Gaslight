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

**Release identity — shipped Issue 103, August 2026.** The app icon and launch screen are **generated from source art, never hand-placed.** `flutter_launcher_icons` and `flutter_native_splash` are configured in `pubspec.yaml`; the icon derives from a single 1024×1024 master of the raven mascot on `AppColors.ground` `#14110E` with a brass outline, and the launch screen is a solid `#14110E` field so a cold start reads as the game rather than a white flash.

> ⚠️ **Two constraints that fail an App Store upload rather than looking wrong.** The 1024 icon must have **no alpha channel** — `remove_alpha_ios: true` is set, and the check is `file` reporting `8-bit/color RGB`, not `RGBA`. And the source art must have **no pre-rounded corners**: iOS applies its own mask, so a pre-rounded icon renders with a doubled radius. Regenerate from the master rather than editing any of the 15 slots — hand-placing them is how icon sets drift out of sync. Before this shipped, all 15 slots were the stock Flutter chevron and the three `LaunchImage` files were 1×1 pixel stubs.

**Error surfaces — shipped Issue 93, August 2026.** **Never interpolate an exception object into user-facing text.** `FirebaseFunctionsException.toString()` carries its stack trace, so `Text('Error: $e')` rendered ~20 lines of `pigeon/messages.pigeon.dart` frames into the Guest Ledger when a player mistyped a room code — the single most likely error in the app.

> The pattern, established at `phase2_craft.dart:543` and now mirrored in `lobby_screen.dart`: **match on `e.code`, map each code the callable actually throws to one sentence, and fall through to `'Something went wrong. Try again.'` for everything else.** Enumerate the codes from the callable's source rather than from expectation — `joinRoom` throws exactly `unauthenticated`, `invalid-argument` and `not-found`, and an earlier draft of the fix guessed at two codes it does not throw. **The regression guard must assert the negative** — that the rendered text contains no `pigeon`, `#0`, or `firebase_functions` — because asserting only that the friendly sentence appears passes while the trace is still displayed beneath it.

**Busy states — shipped Issue 95, August 2026.** `PrimaryButton` carries `loading` and `showTextOnLoading`; pass a flag set before the callable and cleared in a **`finally`**, and disable `onPressed` while busy. **That disabling is a correctness guard, not only feedback: `createRoom` is not idempotent**, so an un-guarded second tap strands an orphan room.

**Dialogs (`ThemeData.dialogTheme`) — shipped Issue 84, August 2026.** Dialogs render on **`groundRaised`** with a **`brass`** title and **`ivory`** content, set once in `main.dart` so bare `AlertDialog`s inherit it.

> ⚠️ **Do not let dialogs fall back to `colorScheme.surface`.** `surface` is `parchment` — correct for cards and sheets, and fatal for dialogs, because the global `textTheme` paints body copy `ivory` and titles `brass`, both of which are chosen for the dark ground. Before the fix, `phase3_vote.dart`'s confirmation rendered **ivory on parchment at a measured 1.02:1** — the text was present, correct, and literally invisible, while its oxblood buttons sat at 9.67:1 and looked fine. The regression guard asserts a **contrast ratio**, not the presence of a string: a string test passed throughout the defect's life. Helpers: `relativeLuminance` / `contrastRatio` in `test/helpers/png_decoder.dart`; thresholds 4.5:1 content, 3.0:1 title.

**Single-line gameplay guidance — shipped Issue 129, August 2026.** An italic subtitle in `Lora` sits under the prompt on the Truth (`Write something true about you — the more surprising, the better. Others must be able to believe it.`), Forgery (`You are writing as <name>. Make it sound like something they would say, so people pick yours.`), and Vote (`Talk it out — discussion is part of the game.`) screens, providing clear objective framing without UI clutter.

**Buttons (`shared_ui.dart`).** `PrimaryButton` is solid burgundy — good for "commit" actions (SUBMIT, CONFIRM VOTE). Add a **pressed "stamp" feel**: on tap, a quick scale-down + a faint wax-ring flash, echoing the vote seal. `SecondaryButton` is emerald — retheme to verdigris and reserve it strictly for host/utility actions so color = meaning.

**Player tokens (`player_avatar.dart`).** Strong already. Two upgrades: (1) add a thin **engraved bevel** (inner highlight top-left, shadow bottom-right) so chips read as pressed metal/stone; (2) give the **active reader** a **brass halo / lamplight ring** so "whose card is this" is unmistakable at a glance.

**Timer (`auto_advance_timer.dart`).** Reframe from a digital countdown to a **guttering lamp / pocket-watch**: keep the number (tabular figures) but when `isLowTime`, make the lamp-pool background pulse and the ring flicker rather than just turning red. Period-correct urgency.

**Prompt / craft screen (`phase2_craft.dart`).** The prompt already sits on a `CrimsonShadowCard` labeled "CASE PROMPT" — very good. Style the text field as an **inkwell / telegram form** (thin brass underline instead of a full box, a quill/nib cursor accent). Show the target as *"A forgery on behalf of —"* with their token, reinforcing the impersonation fantasy.

**Vote grid (`card_grid.dart`).** Answers as **evidence cards** on the table. Selected = wax seal (keep). Add: the disabled "(Your Forgery)" card gets a subtle **"SEALED — your own hand" ribbon** so it reads as intentional, not broken.

**Reveal (`phase4_reveal.dart`).** This is the money screen — give it the most craft: staggered vote-chip landing, Truth revealed last in verdigris with a **stamped "THE TRUTH" seal**, forgery cards **flip to unmask** authors, and a **"Best Forgery of the Round"** banner. (Ties directly to the honor-stats work selected in `design_scoring_and_ui.md` Clarification 2.)

**In-game header sizing — shipped Wave R (Issue 136, Option A modified), August 2026.** In-game screen AppBars across Craft (`Phase2CraftScreen`), Vote (`Phase3VoteScreen`), and Reveal (`Phase4RevealScreen`) derive their `toolbarHeight` dynamically via `inGameAppBarHeight` from measured text (`TextPainter.layout`) scaled by live `MediaQuery.textScalerOf(context)` constrained to the title box, rather than using arbitrary literals or screen-height fractions. A minimum floor of `kToolbarHeight` (56.0) is enforced. Forgery phase multi-line headers (`FORGERY`, `ROOM: XXXX`, `Rotation N of M`) fit cleanly across all viewport widths and accessibility text scaling settings without clipping.

**Dealt-card overlay sizing — shipped Wave R (Issue 137, Option A), August 2026.** `DealtCardOverlay` scales responsively to accommodate long catalog prompts without silent truncation at the fold. Outer card height is bounded dynamically by `min(screenHeight * 0.7, 560)` with an inner width-constrained `Column` that takes intrinsic height for short prompts while expanding smoothly for long prompts. `SingleChildScrollView` is retained as a safety floor.

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
> - **Eleven functional affordances render from a vendored Phosphor Light font asset (`assets/fonts/phosphor/Phosphor-Light.ttf`)** — `writing`, `redraw`, `timer`, `secret`, `ledger`, `envelope`, `observe`, `confirm`, `sound`, `mute`, `host`. Light was chosen because its 1.5 px nominal stroke matches the painter's hairline `max(1.5, w/16)`, preserving "single-weight brass line icons for consistency."
> - **`depart` is the twelfth affordance and is a bespoke sigil**, drawn by `_ThematicIconPainter`, not sourced from the font (Issue 57, August 10, 2026). It is the only functional affordance not backed by Phosphor; that is deliberate, because its codepoint could not be verified by name and the first one chosen was wrong.
> - **All eleven font-backed codepoints were audited on August 10, 2026** by decoding their outlines from the TTF and comparing each rendering against the comment beside it in `app_icons.dart`. **All eleven match** — feather, arrows-clockwise, hourglass, key, open book, envelope, magnifying glass, seal-with-check, bell-ringing, bell-slash, lamp. Re-run with `scripts/inspect_glyph.py` if a codepoint is ever changed; a cmap presence check is not a substitute, because this font's cmap spans `0x0020–0xFFFD` and reports almost anything as present.
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
- **In-game background and Reduce Motion (Wave R / R0 / Issue 138; Wave U / U2 / Issue 141):** The in-game background (`AnimatedThinkingBackground`, rooting Craft, Vote, and Reveal) honours Reduce Motion (`AppMotion.reduce(context)`) by **omitting the particle layer entirely** and stopping its AnimationController ticker. The radial gradient is retained so the screens keep their warm soot ground colour.
  - *Platform Signal Contract (Issue 141):* `AppMotion.reduce(context)` checks `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion || MediaQuery.of(context).accessibleNavigation`. `accessibleNavigation` alone reflects only VoiceOver / Switch Control on iOS; real iOS **Settings → Accessibility → Motion → Reduce Motion** sets the `reduceMotion` bit on `accessibilityFeatures` (which is not exposed on `MediaQueryData` in Flutter stable). Stateful widgets like `AnimatedThinkingBackground` implement `WidgetsBindingObserver.didChangeAccessibilityFeatures` to rebuild live if the OS toggle changes mid-session. All motion gates across the app (including `AutoAdvanceTimer`) route through `AppMotion.reduce`.
- **Game-over background and Reduce Motion (Wave X / X1 / Issue 147):** The Game Over screen background (`EmberBackdrop`) honours Reduce Motion in **both** its visuals and its ticker lifecycle:
  - *Visuals:* Returns a static CustomPaint (`_StaticEmberPainter`) under `AppMotion.reduce(context)`.
  - *Ticker Lifecycle:* Implements `WidgetsBindingObserver` to pause the `AnimationController` (`_controller.stop()`) under Reduce Motion in both `didChangeDependencies` (covering initial mount and `MediaQuery` / `accessibleNavigation` changes) and `didChangeAccessibilityFeatures` (covering live OS `reduceMotion` toggle changes with `setState`). Unpauses when Reduce Motion is off.
  - *Disposal:* Removes the binding observer in `dispose` to prevent leaking observer registrations or firing `setState()` post-dispose.

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
> - **Artwork:** Flat vector mascot in a bold silhouette — brass rim-light outline, warm dark body, ivory eye, brass beak. **Measured from the shipped PNGs (August 7):** rim `#C6A14B` at **7.70:1** against `#14110E`; body fill `#2D2925` at 1.30:1. *(An earlier revision of this note claimed 18.59:1 for the rim — that figure is the ivory highlight in `eye_open.png`, a different layer. The rim still clears the 4.5:1 bar with headroom.)*
> - **Body fill (Issue 33):** the first generation shipped as a hollow outline — 84.5% of the silhouette was transparent, so backgrounds showed through the bird. The interior is now filled, raising opaque coverage inside the bounding box from 12.4% to **44.9%**. **A flood-fill cannot be used to repair this**: the brass rim is not a closed loop (7–582 enclosed pixels depending on alpha threshold, against the ~20,000 a filled body needs), so any fill escapes. Regenerate via image-to-image editing instead.
> - **Asset layers & sprite sheets:** Resting poses (`idle`, `sleep`) use layered PNGs (`assets/images/raven/{body,wing,eye_open,eye_closed}.png`). Transient poses (`ruffle`, etc.) use pre-rendered grid sprite sheets (`assets/images/raven/frames/*.png`, 256×256 px cells, 1x density). Prompts and assembly recorded in `assets/images/raven/PROMPTS.md`.
> - **Dual-renderer architecture (Task T6, August 8, 2026):** Two renderers coexist by design — layered `Stack` for resting states (to support stochastic eye blinking and idle head tilts without long frame loops), and `CustomPaint` `drawImageRect` frame sequence sprite sheets for transient poses (to support rich deformation, squash, stretch, and feather ruffling).
> - **Animation contract:** Preserves all 12 screen poses and reduced-motion static frame 0 fallback. `RavenMascot` public API (`state`, `size`) and `RavenPoseHost` `playRavenPose` remain unchanged.

---

## 10. Delivered UI programme — consolidated record

Absorbed from `ongoing_general_errors.md` during the August 7 doc consolidation. Every item below is **shipped and verified**; the detailed per-proposal specs were retired once delivered. Kept here because these are the design decisions a future change has to respect, not history for its own sake.

### Mobile-first pass (M1–M5, shipped July 16)
| # | Decision | Why it constrains future work |
|---|---|---|
| **M1** | **Portrait-locked on phones**; iPad rotation retained | Every screen is a portrait column design. Landscape was never laid out. |
| **M2** | Waiting room is a scrollable sheet, not a fixed column | The Parlor roster must survive any player count on a 360×640 viewport. |
| **M3** | **Text scale clamped 1.0–1.3** app-wide (`main.dart`) | A recorded accessibility trade-off: fixed-height widgets break above 1.3. Layouts must still survive 1.3. |
| **M4** | Touch targets **≥ 48 dp** | Do not shrink an interactive element below this to win vertical space. |
| **M5** | Safe-area and thumb-zone pass; bottom-anchored commit actions | Craft's SUBMIT is a deliberate in-flow exception for keyboard interplay. |

### Character & custom widgets (V1–V5, shipped July 16)
- **V1 — the Lamplighter's Raven**, now the app's single mascot (see the mascot block above, and §5's lamplight motif).
- **V2 — living avatar sigils**: six bespoke `CustomPainter` house sigils (`flame`, `moth`, `key`, `raven`, `moon`, `hourglass`), pulsed by `SigilTicker`. These are the reason the icon system is a **hybrid** — see §7.
- **V3 — deck selection as case files**; **V4 — "Lighting the Lamp" loading states**; **V5 — Victorian reaction medallions**. Reactions send **raw emoji strings** over the wire; the medallion is render-side only.

### UI/UX programme (U1–U8, shipped July 15–16)
Gaslight-flicker phase transitions · themed waiting moments instead of spinners · the card-dealt craft entrance · typography unification · the icon sweep and a real wax seal · game-over as a read-out ceremony · the room code as a tap-to-copy brass plaque · a live vote ticker during lockout.

**The invariant these left behind:** every one of these animations is guarded by a **once-per-event key** (the `_advancedStateKeys` pattern) so it survives Firestore-stream rebuilds, and every one has an `AppMotion.reduce` path. **Never remove those guards** — without them the animation re-fires on every stream tick.

### Sound (Decision 1, shipped)
Bundled `.wav` effects in `assets/audio/` — quill scratch on submit, wax thunk on vote, the bell on the Truth reveal — with a single mute control. Sound is bundled, never fetched, so it works offline.

### Motion tokens
All durations come from `AppMotion`: `fast` 180 ms (presses, stamps) · `standard` 300 ms (fades, state swaps) · `scene` 450 ms (route transitions) · `emphasis` 600 ms (title settles, flips). No ad-hoc `Duration` values.

### Lobby Leave Control & Motion Contract (Issue 50 & 57 — August 10, 2026)
- **`ThematicIconType.depart`**: occupies `LobbyScreen`'s `AppBar` `leading:` slot with tooltip `'Leave room'`. Drawn as a bespoke line-art sigil (`_bespokeSigils` in `lib/theme/app_icons.dart`) featuring a doorway frame and exit arrow pointing right in single-weight brass stroke matching the app's vector sigil aesthetic (Issue 57 Option A, August 10, 2026).
- **Dialog motion & accessibility**: `_confirmLeave` uses `showGeneralDialog` with `barrierDismissible: true` unconditionally, `barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel`, `barrierColor: Colors.black54`, and `transitionDuration: AppMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 150)`. Under `AppMotion.reduce(context)`, the static child widget is returned directly without wrapping in a `FadeTransition`. Double-tap prevention sets `_isLeaving = true` before `Navigator.pop()`.

### Lobby Deck Carousel (Issue 52, shipped August 2026)
- Non-hosts get the full 7-deck `PageView` carousel read-only, labeled with `THE CHOSEN FILE`. Selection affordances (`onDeckSelected` callable write, stamp pulse) are suppressed for non-hosts.
- Host's selected deck is badged with `CHOSEN` on non-host carousels.
- Non-host carousel does not snap back to host's selection when swiped within the last 3 seconds (`_lastSwipeTime`).

