# Agent Execution Guide — Active Build: UI & UX Polish U1–U8 (specs locked July 15)

**You are an engineering agent implementing an approved UI/animation design pass on Gaslight (Flutter + Firebase party game).** All eight proposals in `ongoing_general_errors.md` → "🎨 UI & UX Design Review" were selected **Option A**. This document is the **design specification** — durations, curves, dimensions, and colors are exact values chosen by the designer. **Implement them as written; do not substitute your own timings, colors, or layouts.** Where a value is genuinely impossible (e.g., overflow on a small screen), keep the intent, adjust minimally, and note the deviation in your commit body.

Everything else in the project is delivered and verified — do not touch game logic, the backend, scoring, or audio assets. These items are **client-side presentation only**. Prior delivered records: Resolved #38–50 in `ongoing_general_errors.md` (backend migration, P8/P10, E7 sound = #49, heuristic dup-check = #50).

---

## 1. Baseline (verified July 15 — re-run before you start, and after every item)
- `cd functions && npm run build` — clean · `flutter analyze` — **0 errors** · `flutter test` — **30/30** · `npm --prefix functions test` — **28/28**.
- The emulator suite must remain **byte-identical in result** (28/28) — nothing here touches `functions/`.

**Design system you MUST source from (never hardcode new values):**
- Colors: `lib/theme/app_colors.dart` — `ground #14110E`, `groundRaised #1C1712`, `oxblood #8B0000`, `brass #C9A24B`, `verdigris #2E6E5B`, `parchment #F4EBD8`, `ink #2C1E16`, `ivory #F5EEDB`.
- Text: `lib/theme/app_text_styles.dart` — `gaslightLogo`, `phaseTitle` (Cormorant 32/bold/brass/ls3), `cardHeader` (Cormorant 22), `sectionLabel` (Lora 12/w600/brass@0.7/ls2), `bodyInk`, `bodyIvory`.
- Icons: `lib/theme/app_icons.dart` — `ThematicIcon` + `ThematicIconType {flame, moth, key, raven, moon, hourglass, observe, timer, writing, confirm, secret, host, sound, mute}` (procedural CustomPaint; add new types the same way).
- Sound: `AudioService.instance` — `playSubmit/playVote/playReveal/playUnmaskSuccess`, all mute-gated.
- Reduce-motion signal used app-wide: `MediaQuery.of(context).accessibleNavigation` (pattern already in `FlippingRevealCard`).

## 2. Execution order (dependencies encoded — follow exactly)

| # | Item | Why this position |
|---|---|---|
| 1 | **U0** Motion tokens + shared flip widget (prep) | Everything below imports it |
| 2 | **U4** Typography & voice unification | Later items reference the new strings/styles |
| 3 | **U5** Wax-seal painter + icon sweep | U2/U7/U8/U6 all use `WaxSealBadge` |
| 4 | **U1** Gaslight-flicker route transition | Global; test suite settles before screen work |
| 5 | **U7** Room-code brass plaque | Small, standalone |
| 6 | **U2** Themed waiting moments | Uses seal + motion tokens |
| 7 | **U8** Reader's ballot ticker | Uses seal + flip + waiting patterns |
| 8 | **U3** "Card is dealt" handoff | Uses flip widget + U4 field restyle |
| 9 | **U6** Game-over ceremony | Uses seal, sounds, embers — biggest, last |

One item = one Conventional Commit (`feat(ui): …`, WHY in body). Run `flutter analyze` + `flutter test` after each; the full battery after U1, U3, and U6.

---

## U0 · Prep: motion tokens + shared flip widget (do first, ~30 min)

1. **Create `lib/theme/app_motion.dart`:**
   ```dart
   class AppMotion {
     static const fast     = Duration(milliseconds: 180); // presses, stamps
     static const standard = Duration(milliseconds: 300); // fades, state swaps
     static const scene    = Duration(milliseconds: 450); // route transition
     static const emphasis = Duration(milliseconds: 600); // title settle, flips
     static const deal     = Duration(milliseconds: 1250); // U3 interstitial total
     static const ceremonyStep = Duration(milliseconds: 900); // U6 per-honor cadence
     static bool reduce(BuildContext c) => MediaQuery.of(c).accessibleNavigation;
   }
   ```
   Every duration in U1–U8 MUST reference these constants (no inline `Duration(...)` for the values above).
2. **Extract the flip widget:** move `FlippingRevealCard` out of `phase4_reveal.dart` into `lib/widgets/flipping_card.dart` unchanged (same class name), import it back into the reveal. U3 and U8 reuse it. No behavior change — reveal widget tests must still pass untouched.
3. **Delete dead code:** `lib/widgets/atmosphere_background.dart` and `lib/widgets/swipeable_card.dart` (confirmed unreferenced). If `lib/widgets/prompt_deck.dart` has no imports either (verify with grep), delete it too.

**Validate:** `flutter analyze` 0 · `flutter test` 30/30 (reveal tests prove the extraction was clean).

---

## U4 · Typography & voice unification

### A. Phase titles — one style everywhere
In every phase AppBar, replace the ad-hoc `TextStyle` with `AppTextStyles.phaseTitle.copyWith(fontSize: 26)` (32 overflows a standard AppBar; 26 is the AppBar variant):
- `phase2_craft.dart` `'FORGERY'` / `'TRUTH'` title (currently plain 18px) — keep the "Rotation X of Y" subtitle below it in `sectionLabel` style.
- `phase3_vote.dart` `'THE VOTE'` (currently plain 18px).
- `phase4_reveal.dart` `'THE REVEAL'` (already Cormorant — normalize to the same `copyWith(fontSize: 26)` call).
- `game_over_screen.dart` `'GAME OVER'`.
- Lobby waiting-room AppBar: see U7 (code moves out of the AppBar; new AppBar title = `'THE PARLOR'` in `phaseTitle.copyWith(fontSize: 22)`).

### B. Kill generic `serif` (9 sites)
`grep -rn "fontFamily: 'serif'" lib/` and remap **every** hit:
- Answer/body text on parchment (`card_grid.dart` answer text, reveal option rows): `fontFamily: 'Lora'` (keep existing size/weight).
- Display-ish names (`game_over_screen.dart` player name): `fontFamily: 'CormorantGaramond'`, size 20.
- Lobby labels using `'serif'` (e.g. dropdown text): `'Lora'`.
After the pass, `grep -rn "fontFamily: 'serif'" lib/` MUST return 0.

### C. Copy sweep — exact strings (old → new), and the rule
**Rule: interactive controls keep literal labels** (CREATE ROOM, JOIN ROOM, SUBMIT, CONFIRM VOTE, I'M READY, START GAME stay). **Ambient/status text carries the Victorian voice.** Apply exactly:

| Location | Old | New |
|---|---|---|
| `lobby_screen.dart` entry card header | `CREW STATION` | `THE GUEST LEDGER` |
| `lobby_screen.dart` waiting header | `WAITING FOR CREW...` | `ASSEMBLING THE SUSPECTS…` |
| `phase2_craft.dart` waiting title | `HOLDING TIGHT...` | `THE INK DRIES…` |
| `phase3_vote.dart` waiting title | `YOUR VOTE IS LOCKED IN` | `YOUR BALLOT IS SEALED` |
| `phase3_vote.dart` waiting sub | `Waiting for N other voters...` | `Awaiting N more ballots…` |
| `phase3_vote.dart` reader title | `THEY ARE VOTING ON YOUR CARD...` | `THE PARLOR DELIBERATES…` |
| `phase3_vote.dart` reader sub | `Keep a straight face.` | `They are voting on your card. Keep a straight face.` |
| `phase2_craft.dart` spectator title | `SPECTATOR MODE` | `THE GALLERY` |
| `game_over_screen.dart` header | `THE CREW'S HONORS` | `THE NIGHT'S HONORS` |

Use the exact ellipsis character `…` (U+2026) as written. After the sweep, `grep -rin "crew" lib/` MUST return 0.

### D. Blast radius (update in the SAME commit)
- `test/ui_e2e_test.dart:72` expects `'WAITING FOR CREW...'` → new string; `:102` expects `'HOLDING TIGHT...'` → new string. Grep all of `test/` for every old string in the table.
- `docs/e2e_testing_journeys.md` quotes `"HOLDING TIGHT..."`, `"THEY ARE VOTING ON YOUR CARD... Keep a straight face."`, `"SPECTATOR MODE: ..."` — update the quoted strings.
- Lobby manual (`_showInstructions`): if it quotes any old string, update it.

**Validate:** `flutter test` green with new matchers; both greps return 0; manual screenshot pass of all five screens confirming titles render in Cormorant without overflow (smallest target: 375×812 viewport).

---

## U5 · The real wax seal + finish the icon sweep

### A. `WaxSealBadge` (new widget in `lib/theme/app_icons.dart`)
`class WaxSealBadge extends StatelessWidget { final double size; final Color color; const WaxSealBadge({this.size = 24, this.color = AppColors.oxblood}); }` — a `CustomPaint` drawing, **deterministic (no Random)**, in paint order:
1. **Wax blob:** closed path around center at polar radius `R(θ) = 0.42·size · (1 + 0.06·sin(5θ + 1.3) + 0.04·cos(3θ))`, sampled every 10°, filled with `color`.
2. **Pressed ring:** stroked circle, radius `0.26·size`, strokeWidth `0.05·size`, color `Color.lerp(color, Colors.black, 0.35)`.
3. **Emboss starburst:** 6 spokes from center, length `0.14·size`, at 0°/60°/…/300°, strokeWidth `0.04·size`, color `AppColors.brass`; plus center dot radius `0.05·size`, brass.
4. **Highlight:** arc from 200° to 250° at radius `0.36·size`, strokeWidth `0.05·size`, color `AppColors.ivory` at opacity 0.25.

### B. Deploy the seal (replacing `Icons.verified` everywhere)
- `card_grid.dart` **selected stamp**: replace the 30dp circle+`Icons.verified` container with `WaxSealBadge(size: 34)` (keep the existing `easeOutBack` scale-in, but change its duration to `AppMotion.fast` and add a start scale of 1.6→1.0 so it reads as *pressed down onto* the card).
- `card_grid.dart` **watermark**: replace `Icons.verified` size 80 @0.04 with `Opacity(opacity: 0.05, child: WaxSealBadge(size: 80))`.
- `phase4_reveal.dart` **THE TRUTH badge**: replace `Icon(Icons.verified, verdigris, 14)` with `WaxSealBadge(size: 16, color: AppColors.verdigris)`.

### C. Sweep the remaining stock icons (exact mapping)
| Current | Where | Replacement |
|---|---|---|
| `Icons.lock` | reveal "SEALED ANSWER" chip | `WaxSealBadge(size: 12)` |
| `Icons.gavel` | reveal revenge tray header | `ThematicIcon(type: confirm)` |
| `Icons.hourglass_empty` | reveal tray (non-fooled) | `ThematicIcon(type: hourglass)` |
| `Icons.person` | lobby name field prefix | `ThematicIcon(type: writing, size: 20)` (you *sign* the ledger) |
| `Icons.menu_book` | lobby READ MANUAL | new type `ledger` (painter: two mirrored rounded-rect page panels meeting at a center spine line, 3 strokes total, brass) |
| `Icons.share` | game-over share button | new type `envelope` (painter: stroked rect `0.9×0.62·size` + two flap lines from top corners to center-mid, brass) |
| `Icons.refresh` / `Icons.loop` | reroll affordances | new type `redraw` (painter: arc start −90°, sweep 300°, strokeWidth `0.08·size`, + 2-line arrowhead at arc end, each line `0.18·size` at ±45° to the tangent) |
| `Icons.add_circle` | add custom prompt | 24dp `Container` circle, 1.5dp brass border, centered `Text('+', ivory, bold, 16)` — no painter |
| `Icons.delete` | remove custom prompt | same circle treatment, oxblood border, `'×'` |
| `Icons.check` | prompt-saved indicator | `WaxSealBadge(size: 16)` |
| `Icons.star` | (locate with grep — 1 use) | `ThematicIcon(type: flame)` |

**Validate:** `grep -rn "Icons\." lib/screens lib/widgets` returns **0 matches**. Widget test: pump `WaxSealBadge` at sizes 12, 34, 80 inside a 100×100 box — renders without exceptions. Manual: vote screen — the selected seal reads as red wax with a brass emboss at arm's length.

---

## U1 · The "Gaslight Flicker" scene change

### A. The route (`lib/widgets/gaslight_route.dart`)
`class GaslightPageRoute<T> extends PageRouteBuilder<T>` with:
- `transitionDuration: AppMotion.scene` (450 ms), `reverseTransitionDuration: AppMotion.standard`, `opaque: true`.
- `transitionsBuilder`: a `Stack`: `Positioned.fill(ColoredBox(color: Color(0xFF090807)))` (the vignette black — screen reads near-dark mid-transition) under the incoming page wrapped in **both**:
  - `FadeTransition` whose opacity is the flicker curve: `TweenSequence<double>` on the route animation —
    | segment | weight | from → to |
    |---|---|---|
    | rise | 35 | 0.00 → 0.55 |
    | gutter | 10 | 0.55 → 0.30 |
    | recover | 15 | 0.30 → 0.75 |
    | stutter | 10 | 0.75 → 0.55 |
    | bloom | 30 | 0.55 → 1.00 |
  - `ScaleTransition` 0.985 → 1.0 across the full duration, `Curves.easeOutCubic` (a settle breath — subtle; if it's visible as "zoom", it's too much).
- **Reduce-motion:** if `AppMotion.reduce(context)` → plain `FadeTransition` (linear 0→1), duration 250 ms, no dips, no scale.

### B. Wiring
`main.dart` currently uses a `routes:` map. Replace it with `onGenerateRoute:` — a `switch (settings.name)` over the **identical** five names (`'/'`, `'/craft'`, `'/vote'`, `'/reveal'`, `'/game-over'`) each returning `GaslightPageRoute(pageBuilder: … the same screen widgets …, settings: settings)`. No screen navigation code changes (`pushReplacementNamed` calls stay).

### C. Title settle (per phase screen)
Wrap each AppBar title `Text` in a new `TitleSettle` stateless helper (put it in `lib/widgets/gaslight_route.dart`): a `TweenAnimationBuilder<double>` from 0→1, duration `AppMotion.emphasis`, `Curves.easeOutCubic`, building the text with `letterSpacing: 9 − 6t` (settles at the style's 3) and `opacity: t`. Runs once on mount (TweenAnimationBuilder's natural behavior). Reduce-motion → return the text directly.

**Validate:**
- Widget test: push a `GaslightPageRoute`; `tester.pump(Duration(ms:180))` — opacity of the `FadeTransition` is **below 0.55** (the gutter dip proves the flicker exists); `pumpAndSettle()` → child fully visible, opacity 1.0. Reduce-motion (`tester.platformDispatcher.accessibilityFeaturesTestValue`… or wrap in `MediaQuery(data: …accessibleNavigation: true)`) → no `TweenSequence` (plain fade), settles in ≤300 ms.
- Full suite: `flutter test` — the sim/UI tests use `pumpAndSettle` and must still pass (all animations are finite).
- Manual: play through all five phases; the flicker reads as *lamplight*, not a glitch — if testers describe it as "flashing", halve the two dip depths (0.30→0.42, 0.55→0.65) and note it.

---

## U7 · Room-code brass plaque

### A. Placement
Remove `'ROOM: ABCD'` from the waiting-room AppBar (new AppBar title: `'THE PARLOR'`, per U4). Insert `RoomCodePlaque(code: gs.gameState!.roomCode)` directly **below** the `'ASSEMBLING THE SUSPECTS…'` header and **above** the joined-count line.

### B. `RoomCodePlaque` (new file `lib/widgets/room_code_plaque.dart`)
- Container: height 84, `maxWidth 320`, centered; `borderRadius 10`; gradient `LinearGradient(topLeft→bottomRight, [Color(0xFFD8B460), AppColors.brass, Color(0xFF8A6D2F)])` (polished brass); border 1.5dp `Color(0xFF6E571F)`; shadow black@0.5, blur 10, offset (0,4).
- Content column (centered): label `'ROOM CODE'` — Lora 11, w600, `ink` @0.65, letterSpacing 3; then the code — **CormorantGaramond, w900, 40px, letterSpacing 12, color `ink`**, engraved via two shadows: `ivory@0.35 offset(0,1)` + `black@0.4 offset(0,−1)`.
- Top-right corner (8dp inset): a 22dp `ThematicIcon(type: envelope, color: ink @0.7)` inside its own `InkWell` → **share**.
- Whole plaque wrapped in `InkWell` → **copy**.

### C. Behavior
- **Tap (copy):** `Clipboard.setData(roomCode)`; press animation scale 1.0→0.96→1.0 over `AppMotion.fast` (mirror the PrimaryButton stamp feel); `HapticFeedback.selectionClick()`; `AudioService.instance.playVote()` (it *is* a stamp); SnackBar: `'Code ABCD copied — summon your suspects.'`
- **Share icon:** `Share.share('Join my Gaslight game! Room code: ABCD')` (`share_plus` already a dependency). Do not block on the share result.

**Validate:** widget test — mock the clipboard channel (`TestDefaultBinaryMessengerBinding`), tap plaque → clipboard holds the code and the SnackBar appears; envelope icon present; code text style is Cormorant w900. Manual: iOS + Android share sheet opens; plaque is legible in sunlight-sim (max brightness) — the ink-on-brass contrast must hold.

---

## U2 · Themed waiting moments (craft + vote waiting views)

### A. `CandleFlameIndicator` (new file `lib/widgets/waiting_indicator.dart`)
A 48×64dp `CustomPaint` + one `AnimationController` (1200 ms, `repeat(reverse: true)`):
- **Wick:** 2×8dp rounded rect, bottom-center, color `ink`.
- **Glow:** radial circle behind the flame, radius 26dp, `brass @0.15`.
- **Flame (outer):** teardrop path — from wick top, two mirrored quadratic béziers meeting at the tip; base width 14dp; height animates 28→34dp with the controller (`Curves.easeInOut`); fill `brass @0.85`.
- **Flame (core):** same shape at 55% scale, anchored to the wick, fill `ivory @0.9`.
- **Sway:** translate the tip x by `sin(controllerValue·2π)·2.5`dp.
- **Gutter:** a `Timer.periodic(3600 ms)` triggers a 120 ms dip — flame height scale ×0.85 then back (`easeOut` down, `easeIn` up) — the candle "catches".
- **Reduce-motion:** no controller, no timer; draw the static 31dp flame.

### B. `WaitingOnRow` (same file)
Input: `List<PlayerState> players` (pass ONLY active non-spectators), `Map<String,bool> readyMap`.
- `Wrap(spacing: 12, runSpacing: 12, alignment: center)` of per-player columns: `PlayerAvatar(size: 44, showName: true)`.
- **Ready:** avatar wrapped in a circular `Container` ring — 1.5dp `verdigris` border — with a `WaxSealBadge(size: 16)` overlaid bottom-right (Stack, `Positioned(right: −2, bottom: −2)`).
- **Not ready:** `Opacity(0.45)` + gentle pulse — scale 1.0→1.05→1.0 over 1600 ms, one shared `AnimationController` for all unready entries (single ticker). Name text at `ivory @0.5`.
- **Reduce-motion:** no pulse; opacity states only.

### C. Wire into both waiting views
In `phase2_craft.dart` `_buildWaitingUI` and `phase3_vote.dart` `_buildWaitingUI`, replace the `CircularProgressIndicator` with, top-to-bottom: `CandleFlameIndicator` → 24dp gap → existing title (new U4 strings) → count line → 16dp gap → `WaitingOnRow` (players = active non-spectators; for vote, exclude no one — the reader shows sealed once they tap ready). After this, `grep -rn "CircularProgressIndicator" lib/screens/` may only match the app-boot loading states (`state == null` guards) — the two waiting views must be clean.

**Validate:** widget test — 3 active (2 ready) + 1 spectator: `WaitingOnRow` renders exactly 3 avatars (spectator absent), exactly 2 `WaxSealBadge`s, the unready entry sits inside an `Opacity(0.45)`; reduce-motion → `pumpAndSettle` completes (no infinite tickers — the candle controller must be absent). Manual: leave a 3-player game idle on the craft waiting screen — the candle gutters ~every 3.6 s and the unready player visibly pulses.

---

## U8 · The reader's ballot ticker (vote lockout view)

### A. `BallotTicker` (new file `lib/widgets/ballot_ticker.dart`)
Input: `List<PlayerState> expectedVoters` (active non-spectators **minus the reader**), `Map<String,bool> readyMap`.
- A centered `Wrap(spacing: 10)` of ballot cards, one per expected voter, each 34×48dp:
  - **Unsealed:** `groundRaised`, borderRadius 6, border 1dp `brass @0.35`; two face-down "text lines": 16×2dp rounded rects, `ivory @0.15`, stacked center.
  - **Sealed:** same card + centered `WaxSealBadge(size: 18)`, border brightens to `brass @0.7`.
  - **Transition:** when a voter's `readyMap[id]` flips true, the card flips unsealed→sealed via `FlippingRevealCard` (height 48), duration `AppMotion.emphasis`; at flip completion play the stamp **quietly**: extend `AudioService.playVote({double volume = 1.0})` to call `votePlayer.setVolume(volume)` before `play`, and pass `0.4` here (full 1.0 remains the default everywhere else). **Once-per-voter guard:** a `Set<String> _sealedPlayed` in the ticker's state (same pattern as the reveal SFX guard).
- Caption below, 12dp gap: `'N of M ballots sealed'` — Lora 14, `ivory`, `FontFeature.tabularFigures()`. N = expected voters with ready true.

### B. `BlinkingEye` (same file)
56×32dp `CustomPaint` above the title: almond outline (two mirrored quadratic arcs), stroke 1.5dp `brass`; iris = 6dp brass-filled circle, pupil = 2.5dp `ink`. Blink = `Transform.scale(scaleY: 1.0→0.08→1.0)` over 220 ms, scheduled by a timer at a random interval 2.8–4.2 s. Reduce-motion: static open eye, no timer.

### C. Wire into the reader branch
In `phase3_vote.dart` `_buildVotingUI`'s reader/target branch, the new column order: `BlinkingEye` → 16 → `'THE PARLOR DELIBERATES…'` (U4, `cardHeader` style) → 8 → sub line (U4) → 24 → `BallotTicker` → caption → 32 → existing `I'M READY` button → debug button. Remove the old `Icons.remove_red_eye` (already swept in the earlier icon pass — verify).

**Validate:** widget test — 4 active (1 reader + 3 voters), `readyPlayers: {}` → 3 unsealed cards, caption `'0 of 3 ballots sealed'`; push a state with 2 ready → exactly 2 `WaxSealBadge`s, caption `'2 of 3 ballots sealed'`; pump the **same** state again → the injected fake audio player's `play` count did **not** increase (guard works). Reduce-motion → sealed states render instantly, no flip, no sound. Manual: on two devices, watch a ballot seal itself the moment the other player votes — the quiet thunk must be noticeably softer than your own vote stamp.

---

## U3 · "The card is dealt" — craft handoff interstitial

### A. Trigger + guard
In `phase2_craft.dart` state: `String? _lastHandoffKey`. Compute `key = '${state.currentPhase.name}_${state.currentRotationIndex}'` in `build`. Show the interstitial when ALL of: key ≠ `_lastHandoffKey`; player is an active non-spectator; player has a target (`currentCardAssignments[me.id] != null`); player not already ready. Set `_lastHandoffKey = key` **when the interstitial starts** (never replays on rebuild). Reduce-motion: set the key and skip straight to the write UI.

### B. The overlay (in-screen `Stack` layer, not a route) — total `AppMotion.deal` (1250 ms), tap-anywhere to skip
Timeline (ms):
- **0–250:** scrim fades in over the write UI — black @0 → @0.6, `easeOut`.
- **100–600:** a face-down card enters — 280×180dp, borderRadius 16, `groundRaised`, border 1.5dp `brass @0.4`, centered `Opacity(0.15, WaxSealBadge(size: 64))` watermark — `SlideTransition` from `Offset(1.2, 0)` → `Offset.zero`, `Curves.easeOutCubic`, plus rotation −4° → 0° (`RotationTransition`, 0.011 turns).
- **600–1000:** the card flips (`FlippingRevealCard`) to its **parchment face**: background `parchment`, borderRadius 16; content column — `'FORGING FOR'` in `sectionLabel` recolored `ink @0.7` → target name in CormorantGaramond 28 bold `ink` → 12dp gap → `PlayerAvatar(target, size: 56, showName: false)`.
- **1000–1250:** whole overlay fades out (`easeIn`); at 1000 ms call `_answerFocusNode.requestFocus()` so the keyboard is rising as the table clears. **No sound** (submission owns the quill sound; the deal stays silent).
- **Truth phase variant** (key `truth_0`): face reads `'YOUR OWN CARD RETURNS'` over the player's own avatar; otherwise identical.
- **Tap-to-skip:** jump all controllers to complete → overlay gone, focus requested.

### C. Pinned target header (persistent, replaces the current header row in `_buildWriteUI`)
`Row(mainAxisSize: min, center)`: `PlayerAvatar(target, size: 40, showName: false)` → 10dp gap → `Column(crossAxisStart)`: `'FORGING FOR'` in `sectionLabel` + target name in CormorantGaramond 22 `brass`. Truth: own avatar, label `'YOUR TRUTH'`. This stays visible the entire time the player types — whose card this is must never be ambiguous again.

### D. The inkwell field (completes E5)
Restyle the answer `TextField`: remove the filled box + `OutlineInputBorder`s. New: `UnderlineInputBorder` — enabled 1dp `brass @0.5`, focused 2dp `brass`; `filled: false`; text style Lora 18 `ivory`; `cursorColor: AppColors.brass`; hint `'Dip the quill…'` in Lora italic `ivory @0.35`; 4dp left content padding.

**Validate:** widget test — enter forgery rotation 1: interstitial appears exactly once showing the correct target name; advance the fake state to rotation 2 (new assignment) → appears once more with the **new** name; rebuild same state → absent; tap during it → write UI visible immediately; reduce-motion → never appears, write UI + pinned header immediate; already-ready player → no interstitial. Manual: the 1.25 s deal must feel like *receiving* a card, and typing must be possible the instant it clears.

---

## U6 · Game over as a ceremony — "The honors are read"

### A. Reveal order & cadence
Honors reveal **one at a time**, least→most prestigious: **Most Gullible → Runner Up → Trickster → Mastermind**. Plaque *i* (0-based, skipping absent honors) enters at `t = 400 + i·AppMotion.ceremonyStep` ms after screen mount. A `bool _ceremonyStarted` guard runs it once per mount; `bool _ceremonyComplete` set when the last plaque lands + 400 ms.

### B. Plaque design (replaces `_honorCard`; grid stays `crossAxisCount: 2`, `childAspectRatio: 0.85`)
- **Frame:** outer `Container` — 3dp `brass` border, borderRadius 6 (frames are rectilinear; the current 16 is too soft), 6dp padding → inner panel `groundRaised` with a 1dp `brass @0.4` inset border.
- **Cap:** a 24×6dp brass rounded rect centered on the frame's top edge (the mounting plate).
- **Content column (centered):** honor **sigil** (see mapping) as `ThematicIcon(size: 28, brass)` → `PlayerAvatar(size: 48, showName: false)` → name in CormorantGaramond 20 `ivory` → title in `sectionLabel` (letterSpacing 2) → score `'N pts'` Lora 14 `brass` + `tabularFigures`.
- **NO emoji anywhere** — delete 🏆 🃏 🥈 🤡 from the title strings. Sigils: Mastermind → `key` · Trickster → `moth` · Runner Up → `hourglass` · Most Gullible → `observe` (the monocle that saw nothing).
- **Entrance (500 ms per plaque):** opacity 0→1 (`easeOut`) + scale 1.15→1.0 (`easeOutBack`) + rotationZ −0.03→0 rad. At each entrance's END: honors 1–3 → `AudioService.playUnmaskSuccess()`; **Mastermind → `playReveal()`** (the bell tolls for the winner). Existing mute gating applies automatically.

### C. Ember fall (backdrop)
`EmberFallPainter` in a Stack layer **behind and outside the `RepaintBoundary`** (the share capture must never contain mid-fall particles): 24 particles, each `{x: rand 0–1, y: starts −0.05, fall speed 0.03–0.08 screen-heights/s, size 2–4dp, drift: x += sin(t·ω)·0.004, color: Color.lerp(brass, oxblood, rand) @ opacity 0.25–0.5, twinkle: opacity × (0.75 + 0.25·sin(t·ω₂))}`; recycle at bottom; one 12 s repeating controller. Reduce-motion: no embers.

### D. Interactions during the ceremony
- Share button disabled until `_ceremonyComplete` (label meanwhile: `'Engraving…'`); existing `_isSharing` logic untouched.
- `RETURN TO LOBBY` restyled: label in CormorantGaramond 16 `brass`, letterSpacing 2 (still a `TextButton`).
- Reduce-motion: all plaques visible immediately, `_ceremonyComplete = true` on first frame, **no** staggered sounds (play nothing — the screen appearing silently is the accessible path).

**Validate:** widget test with fakes — after first frame, 0 plaques visible; pump +400 ms → 1 (Most Gullible); +900 → 2; +900 → 3; +900 → 4 (Mastermind); injected fake audio players: `unmaskPlayer.play` fired exactly 3×, `revealPlayer.play` exactly 1×; share button disabled until complete, enabled after; `find.textContaining('🏆')` (and the other three emoji) → nothing; reduce-motion → all four visible on first settle, zero audio calls, share enabled. Manual: full game to the end — the ceremony should make someone say "ooh"; verify the Case File share image (post-ceremony) contains crisp plaques and no embers.

---

## THE LOOP (per item)
```
(1) IMPLEMENT the item exactly as specced (values are design decisions, not suggestions).
(2) VALIDATE per the item's block, then: flutter analyze (0 errors) · flutter test.
    After U1, U3, U6 additionally: cd functions && npm run build · npm --prefix functions test (must stay 28/28).
(3) BLOCKED or a spec value is impossible on-device? Keep the intent, minimal deviation,
    note it in the commit body. If the *design* itself can't work, STOP and file it in
    ongoing_general_errors.md with options.
(4) RECORD: after U8… nothing remains — mark the U-section delivered in ongoing_general_errors.md
    (summary of what shipped per item), and update design_ui_direction.md §10 roadmap ticks.
(5) COMMIT: one item = one feat(ui) commit, WHY in the body.
```

## Definition of Done (U-pass)
- [ ] U0: `AppMotion` exists; `FlippingRevealCard` extracted; dead widgets deleted; suite green.
- [ ] U4: all phase titles = `phaseTitle.copyWith(fontSize: 26)`; `grep 'serif'` = 0; copy table applied verbatim; `grep -i crew` = 0; test matchers + journey doc updated.
- [ ] U5: `WaxSealBadge` per spec; `grep "Icons\." lib/screens lib/widgets` = 0; new `ledger`/`envelope`/`redraw` icon types drawn.
- [ ] U1: flicker route on all five names via `onGenerateRoute`; dip proven by widget test; reduce-motion = plain 250 ms fade; full suite green.
- [ ] U7: plaque with engraved Cormorant code; tap-copies (tested via clipboard mock) + stamp press + thunk; envelope shares.
- [ ] U2: candle + waiting-on avatars in both waiting views; no spinner in waiting states; spectator excluded; reduce-motion settles.
- [ ] U8: ballot flips with quiet stamp (volume 0.4 via new `playVote(volume:)` param, default 1.0 preserved — `audio_service_test` still green); once-per-voter guard tested.
- [ ] U3: handoff interstitial (once per rotation key, tap-skip, focus handoff); pinned target header; inkwell field; all guard cases widget-tested.
- [ ] U6: staggered plaque ceremony with sigils (no emoji), bell on Mastermind, embers outside the share boundary; audio counts asserted; reduce-motion instant.
- [ ] Final: full battery green (`analyze` 0 · `flutter test` · functions build · emulator 28/28) · U-section marked delivered · `design_ui_direction.md` updated.
