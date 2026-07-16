# Agent Execution Guide — Active Build: UF + M + V (design specs locked July 16)

**You are an engineering agent implementing the approved UI/UX build-out on Gaslight (a Flutter phone game, Android + iOS).** Three approved batches: **UF1–UF3** (finishing punch list from the U-pass), **M1–M5** (mobile-first audit — all Option A), **V1–V5** (characters & custom widgets — all Option A). This document is the **design specification**: durations, curves, dimensions, colors, and copy are the designer's decisions — **implement as written, do not substitute your own values.** If a value is physically impossible on-device, keep the intent, deviate minimally, and note it in the commit body. If the *design* can't work, STOP and file it in `ongoing_general_errors.md` with options.

Do **not** touch: game logic, `functions/`, scoring, audio assets, or U-items verified faithful (U0/U1/U2/U4/U5/U7).

**MOBILE-FIRST GROUND RULE (applies to every item):** validate every layout at a **360×640 dp portrait** viewport in widget tests (`tester.view.physicalSize = const Size(360, 640); tester.view.devicePixelRatio = 1.0;` + reset in teardown). Nothing may overflow (`tester.takeException() == null`) or hide the screen's primary action at that size.

## 1. Baseline (verified July 16 — re-run before starting and after each item)
`cd functions && npm run build` clean · `flutter analyze` 0 errors · `flutter test` 42/42 · `npm --prefix functions test` 28/28 (must stay 28/28 — nothing here touches the backend).

**Design system (sole sources — never hardcode equivalents):** `AppColors` (`ground #14110E`, `groundRaised #1C1712`, `oxblood #8B0000`, `brass #C9A24B`, `verdigris #2E6E5B`, `parchment #F4EBD8`, `ink #2C1E16`, `ivory #F5EEDB`) · `AppTextStyles` (`phaseTitle`, `cardHeader`, `sectionLabel`, `bodyInk`, `bodyIvory`) · `AppMotion` (fast 180 / standard 300 / scene 450 / emphasis 600 / deal 1250 / ceremonyStep 900 / `reduce(context)`) · `ThematicIcon` + `WaxSealBadge` · `AudioService.instance` (mute-gated).

## 2. Execution order (dependencies encoded — follow exactly)

| # | Item | Rationale |
|---|---|---|
| 1–3 | **UF1 → UF2 → UF3** | Close the approved U-pass first |
| 4 | **M1** portrait lock | Changes the layout contract for everything after |
| 5 | **M3** text-scale clamp + elasticity | Foundation; later widgets audited at 1.3× |
| 6 | **M4** touch targets | Small, standalone |
| 7 | **M2** waiting-room scrollable sheet + action bar | Big lobby restructure; V3 lands inside it |
| 8 | **M5** safe-area & thumb-zone pass | Extends M2's bar pattern to other screens |
| 9 | **V4** lamp boot + ink-dot buttons | Kills the last stock spinners |
| 10 | **V5** reaction medallions | Self-contained painters |
| 11 | **V2** living avatar sigils | Touches shared icon painters |
| 12 | **V3** deck dossier carousel | Lands in the M2-restructured lobby |
| 13 | **V1** the Raven mascot | Biggest; hooks events across five screens |

One item = one Conventional Commit (`fix(ui):` for UF/M, `feat(ui):` for V; WHY in body). `flutter analyze` + `flutter test` after each; full battery after M2, M5, V3, V1.

---

# PART A — UF finishing punch list (authorized under the U-pass)

## UF1 · Game-over ceremony: order, cadence, sounds, share gating (`lib/screens/game_over_screen.dart`)
Keep the delivered extras (metric subtitles like "MOST PLAYERS DECEIVED", "N Fooled"). Four corrections:
1. **Reveal order (currently inverted).** Animation order must be **Most Gullible → Runner Up → Trickster → Mastermind LAST**. Grid *positions* stay as-built; only the per-plaque animation `index` changes (assign from reveal order, skipping absent honors with consecutive indices).
2. **Cadence.** Plaque *i* starts at `Duration(milliseconds: 400) + AppMotion.ceremonyStep * i` (400 + 900·i ms) — replaces the shipped `200 * index`. The 500 ms fade/scale/rotate entrance itself is faithful; keep it.
3. **Sounds.** At each entrance **completion**: plaques 1–3 → `AudioService.instance.playUnmaskSuccess()`; final plaque (Mastermind) → `playReveal()` (the bell). Guard with a per-mount `Set<int> _soundedIndices`. **Reduce-motion: instant plaques, zero sounds.**
4. **Share gating.** `bool _ceremonyComplete` = true 400 ms after the last plaque starts (immediately under reduce-motion). Until then share is disabled, label `'Engraving…'`; after, existing behavior resumes.

**Validate** (extend `test/game_over_screen_test.dart`): stepwise pumps prove the order (only Gullible at +400 ms; +900 each adds one; Mastermind last); fake audio: `unmaskPlayer.play` ×3, `revealPlayer.play` ×1, counts stable on extra pumps; share disabled/`'Engraving…'` until complete; reduce-motion → all visible instantly, 0 audio, share enabled.

## UF2 · Ballot ticker: caption + quiet per-seal stamp (`lib/screens/phase3_vote.dart`, `lib/services/audio_service.dart`)
1. **Caption** 12 dp below the ballot row: `'N of M ballots sealed'` — Lora 14, `ivory`, `fontFeatures: [FontFeature.tabularFigures()]`. N = expected voters (active non-spectators minus reader) with `readyPlayers[id] == true`; M = total expected.
2. **Quiet stamp.** Extend to `playVote({double volume = 1.0})` — `await votePlayer.setVolume(volume)` before `play` (default preserves all existing call sites; add `setVolume` to the fake player so `audio_service_test` stays green). On each unsealed→sealed transition play `playVote(volume: 0.4)` once per voter — guard `Set<String> _sealedSoundPlayed`, cleared when `currentReaderId` changes. Reduce-motion: sealed renders directly, guard pre-filled, no sounds.

**Validate:** new audio test (`setVolume(0.4)` then one `play`; default sets 1.0); widget test — 3 voters, 0 ready → `'0 of 3 ballots sealed'`, 0 sounds; 2 ready → caption updates, `play` count exactly 2; same state re-pumped → still 2; new `currentReaderId` + 1 ready → count 3.

## UF3 · Craft: inkwell field + pinned target avatar (`lib/screens/phase2_craft.dart`)
`DealtCardOverlay` + its `_lastPhase`/`_lastRotation` guard are correct — leave them.
1. **Inkwell field.** Remove box outline/fill. `filled: false`; enabled border `UnderlineInputBorder(BorderSide(brass @0.5, width 1))`; focused `UnderlineInputBorder(BorderSide(brass, width 2))`; text Lora 18 `ivory`; `cursorColor: brass`; hint exactly `'Dip the quill…'` (U+2026), Lora italic `ivory @0.35`; `contentPadding: EdgeInsets.only(left 4, top 12, bottom 12)`. **If the field sits on a parchment panel** (the U3 commit restyled it), use the ink variant instead: borders `ink @0.6` / `ink`, hint `ink @0.4` — the *underline* treatment is the requirement.
2. **Pinned target header** replacing the text-only `"FORGERY FOR X"`: `Row(min, center)`: `PlayerAvatar(target, size: 40, showName: false)` → 10 dp → `Column(start)`: `'FORGING FOR'` in `sectionLabel` over the target name in CormorantGaramond 22 `brass`. Truth round: own avatar, label `'YOUR TRUTH'`, no name line. Visible the entire time the player types.

**Validate:** widget test — forgery shows target avatar + `'FORGING FOR'`; truth shows own avatar + `'YOUR TRUTH'`; decoration uses `UnderlineInputBorder`, `filled != true`, hint exact; update tests matching `'Pen your response here...'`/old header.

---

# PART B — Mobile-first fixes (M1–M5, all Option A)

## M1 · Lock portrait on phones
1. `main.dart`, in `main()` after `WidgetsFlutterBinding.ensureInitialized()` and before `runApp`: `await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);` (`import 'package:flutter/services.dart'`).
2. `ios/Runner/Info.plist`: in the **iPhone** `UISupportedInterfaceOrientations` array delete both `LandscapeLeft`/`LandscapeRight` entries (Portrait only). **Do not touch** the `~ipad` array.
3. `android/app/src/main/AndroidManifest.xml`: add `android:screenOrientation="portrait"` to the main `<activity>`.

**Validate:** `flutter analyze`/`flutter test` unaffected; manual — rotate a phone/emulator on every screen: UI never rotates; iPad (if simulated) still rotates.

## M3 · Text-scale clamp + elasticity audit
1. **Clamp** in `main.dart` `MaterialApp(builder: ...)`: wrap `child` in `MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3)))`. (If the installed Flutter's `TextScaler` lacks `.clamp`, implement the equivalent: read `mq.textScaler.scale(1.0)`, clamp to [1.0, 1.3], set `TextScaler.linear(clamped)` — same effect, note it.)
2. **Elasticity audit at 1.3×** (fix exactly these four):
   - `RoomCodePlaque`: replace `height: 84` with `constraints: BoxConstraints(minHeight: 84)` + vertical padding 12; inner column `mainAxisSize: min`.
   - Honor plaques (game over): wrap the name/title/metric text column in `FittedBox(fit: BoxFit.scaleDown)`; each text `maxLines: 1`.
   - `DealtCardOverlay` card face: wrap the face content column in `FittedBox(fit: BoxFit.scaleDown)`.
   - Ballot cards (34×48): text-free — exempt; confirm the caption below them is in normal flow (it is).

**Validate:** widget test — pump the app shell with a parent `MediaQuery` textScaler 2.0, read the effective scaler inside via a `Builder`: `.scale(10) == 13.0`. Pump plaque, game-over grid, and dealt overlay at 1.3× in 360×640 → `takeException() == null`, no clipped text (golden or overflow assertion).

## M4 · Touch targets ≥ 44 dp
1. **Plaque envelope (share)**: wrap in a 48×48 `SizedBox` + centered 22 dp icon; the share `InkWell` covers the full 48×48 and absorbs its taps (a share tap must never trigger the plaque's copy).
2. **Custom-prompt `+` / `×` circle buttons**: keep the 24 dp visuals; wrap each in a 48×48 `SizedBox(child: InkWell(child: Center(visual)))`.
3. **Sweep**: audit every `InkWell`/`GestureDetector`/`IconButton` in `lib/` (IconButtons default to 48 — fine unless `constraints`/`padding` shrank them). Produce a table in the commit body: widget · file:line · effective hit size · fix applied/none needed. Named suspects: reroll button, avatar picker chips (entry form), sound toggle, emoji tray (52 ✓), deck dropdown items (Material 48 ✓).

**Validate:** widget test — tap at `center + Offset(20, 20)` of the envelope icon still fires share (proves ≥44 zone); same for `+`/`×`; plaque copy *not* fired by an edge-of-envelope tap.

## M2 · Waiting room → scrollable sheet + pinned action bar (`lib/screens/lobby_screen.dart`)
**The fix for the confirmed roster-collapse bug.** Restructure the waiting-room `Scaffold`:
1. **Bottom action bar** — `bottomNavigationBar: SafeArea(minimum: EdgeInsets.fromLTRB(24, 12, 24, 12), child: <bar>)`. Bar container: color `AppColors.ground`, top border 1 dp `brass @0.25`, `BoxShadow(black @0.4, blur 8, offset (0, −2))` (the "table edge").
   - **Host bar**: `Column(min)`: [if `startWarning != null` → warning text (existing style), 8 dp] + `PrimaryButton('START GAME')` (existing enable/glow logic moves here intact).
   - **Non-host bar**: `PrimaryButton("I'M READY"/'NOT READY')` + 8 dp + `'Waiting for Host to start…'` centered, Lora 13 italic `brass`.
2. **Body becomes a single `ListView`** (padding LTRB 24/16/24/24), children in order: header (`'ASSEMBLING THE SUSPECTS…'`, unchanged) → 12 → `RoomCodePlaque` → 12 → count line → 24 → **roster `GridView.builder` with `shrinkWrap: true, physics: NeverScrollableScrollPhysics()`** (crossAxisCount 3, existing entrance tween — the roster can never collapse again) → 16 → custom-prompts section (when custom deck) → 16 → HOUSE RULES card (host) — buttons removed from the list (they live in the bar).

**Validate (the M2 regression test):** at 360×640, host + custom deck selected + 10 players: `takeException() == null`; all 10 roster cells exist (scroll to verify); START visible **without scrolling** (`find` in `bottomNavigationBar`); non-host variant shows READY in the bar. At 800 dp tall: no dead space anomalies. Manual: smallest available device/emulator.

## M5 · Safe-area & thumb-zone pass
Extend M2's bar grammar so every phase's primary action lives at the thumb. Exact placements:
1. **Vote screen (voter view):** move `CONFIRM VOTE` into a `bottomNavigationBar` bar (same visual recipe as M2); disabled until a card is selected (existing logic). **Reader view:** the bar shows `I'M READY` instead. **Waiting view:** no bar.
2. **Reveal screen:** `bottomNavigationBar` becomes `SafeArea(Column(min))`: [host-only `CONTINUE` bar (existing unmask-deadline gating intact — only relocated), then the existing reaction tray row]. Non-hosts see just the tray.
3. **Game over:** `Share Case File` + `RETURN TO LOBBY` move to a pinned bottom bar (`Column(min)`, share first); the ceremony scrolls in the body behind it. UF1's `'Engraving…'` gating applies in the bar.
4. **Craft screen — deliberate exception:** SUBMIT **stays in-flow** directly under the text field (with the keyboard open, a `bottomNavigationBar` is covered by the keyboard; under-field placement is the correct mobile pattern here). Instead: body's scroll view gets `SafeArea(bottom: true)` and the TextField gets `scrollPadding: EdgeInsets.only(bottom: 120)` so focusing it scrolls the field+button above the keyboard.
5. **Every screen:** bottom edge of scrollable bodies wrapped in `SafeArea` (or bar `SafeArea(minimum: …)`) — nothing may sit under the gesture bar/home indicator.

**Validate:** at 360×640 per screen: primary action's `getBottomLeft().dy ≥ 640 − 180` (thumb zone) except craft; craft with `viewInsets.bottom = 300` simulated → field and SUBMIT both visible; no overflow anywhere; emulator suite still 28/28 (navigation flows unchanged).

---

# PART C — Characters & custom widgets (V1–V5, all Option A)

## V4 · Custom loading states — "Lighting the Lamp"
### A. `LampLightingIndicator` (`lib/widgets/lamp_loading.dart`, default size 96)
Two controllers — **intro** (1500 ms, forward once) then **sustain** (2000 ms, repeat reverse). Drawing (CustomPaint):
- Static fixture: brass vertical stem 3 dp wide from bottom to 40% height; glass bulb = circle r `0.22·size`, stroke 2 dp `brass @0.7`, centered at `0.38·size` from top.
- **Intro t 0–0.25 "strike":** a 6 dp `ivory` spark travels a quadratic path from bottom-right corner to bulb center, trailing a 1 dp fading tail (opacity 0.4→0).
- **Intro t 0.25–0.5 "catch":** teardrop flame inside the bulb scales 0→1 with `easeOutBack` — **extract the flame-path builder from `waiting_indicator.dart` into a shared static** (`CandlePaths.flamePath(...)`) and reuse it; outer `brass @0.85`, core `ivory @0.9`.
- **Intro t 0.5–1.0 "bloom":** radial glow behind the bulb, `brass` opacity 0→0.35, radius 0→`0.55·size`, `easeOut`.
- **Sustain loop:** glow opacity 0.25↔0.40; flame sway ±2 dp. (The strike plays ONCE — never re-strikes on loop.)
- Caption 12 dp below, inside the widget: `'LIGHTING THE LAMPS…'` in `sectionLabel`. Reduce-motion: static lit lamp (flame + glow @0.3), caption shown.
### B. Deploy
Replace **every** `state == null` boot guard (`Scaffold(body: Center(child: CircularProgressIndicator()))` in phase2/3/4 + any lobby equivalent) with `Scaffold(backgroundColor: AppColors.ground, body: Center(child: LampLightingIndicator()))`.
### C. Ink-dot button progress
`PrimaryButton` gains `final bool loading;` (default false). When true: `onPressed` forced null; child = `Row(min)` of three 6 dp `ivory` dots, 6 dp gaps; one 1200 ms repeating controller; dot *i* opacity `0.25 + 0.75·max(0, sin(2π·t − i·2π/3))`, scale `0.8 + 0.2·(same phase)`. Reduce-motion: three static dots @0.6. Wire: craft submit (`loading: _isSubmitting` — delete the in-body brass spinner) and the game-over share button's mini-spinner (16 dp dot row, keep the `'Generating dossier...'` label).
**Validate:** after this item `grep -rn "CircularProgressIndicator" lib/` returns **0**; widget tests — boot state shows `LampLightingIndicator`; `PrimaryButton(loading: true)` → null `onPressed` + 3 dots; reduce-motion settles (`pumpAndSettle` on the static path).

## V5 · Victorian reaction medallions (`lib/theme/reaction_medallions.dart`)
**Wire format unchanged:** `sendReaction(emoji)` still sends the emoji string; render-side map `{'😂': laugh, '🤨': monocle, '🐍': serpent, '👏': applause, '🔥': flame}`; unknown emoji → fallback (raw emoji inside the ring frame).
`ReactionMedallion({required ReactionType type, double size = 44})`, layered:
1. Disc: circle fill `parchment`, r `0.5·size`. 2. Rim: brass strokes at r `0.49·size` (width `0.08·size`) and r `0.39·size` (width `0.02·size`). 3. Motif engraved in `ink`, stroke width `0.05·size`, contained in r `0.35·size`:
   - **laugh:** theater-mask outline (inverted-U face), two downturned-arc eyes, wide smile arc.
   - **monocle:** circle r `0.16·size` offset up-left, handle line down-right `0.15·size`, raised-eyebrow arc above.
   - **serpent:** S-curve (two joined cubics), head dot `0.06·size`, two-line forked tongue.
   - **applause:** two mitten-glove outlines tilted ±15° facing each other + three small motion arcs between (width `0.04·size`).
   - **flame:** shared `CandlePaths.flamePath` stroked in ink + small `oxblood` core fill.
Deploy: reveal tray → `ReactionMedallion(size: 30)` inside the existing 52 dp circles (unchanged tap targets/throttle); `FloatingEmojiWidget` → `ReactionMedallion(size: 44)` + existing name tag.
**Validate:** widget test — tray renders 5 medallions; tapping still sends the **same emoji strings** (assert fake payload unchanged); an incoming `'😂'` floats a laugh medallion; unknown `'🎉'` renders the fallback ring+emoji. Manual: each motif distinguishable at 30 dp at arm's length — if muddy, thicken strokes to `0.06·size` (note deviation).

## V2 · Living avatar sigils (`lib/theme/app_icons.dart` + `lib/widgets/player_avatar.dart`)
1. **`SigilTicker`** singleton: one timer; every `6 + Random().nextInt(5)` seconds it pulses **exactly one** random registered subscriber (never two in sync — this is the design). Subscribers register in `initState`, unregister in `dispose`; timer stops with zero subscribers. `AppMotion.reduce` → never pulses.
2. **`AnimatedThematicIcon(type, size, color)`**: renders identically to `ThematicIcon` at rest; on pulse runs its 2000 ms micro-animation once (`easeInOut`):
   - **flame:** gutter — flame scaleY 1.0→1.12→0.94→1.0 (keys at t 0/0.35/0.6/1.0). · **moth:** wings rotate ±18° about the body axis, two flutters (t 0.2, 0.5), settle. · **key:** an `ivory @0.35` highlight band (width `0.15·size`) sweeps along the shaft (clip to the key path). · **raven:** eye dot scaleY 1→0.1→1 at t 0.4. · **moon:** crescent terminator drifts — cutout-circle center x offset `+0.08·size·sin(πt)`. · **hourglass:** one 1.5 dp grain falls top-chamber→bottom over t 0.2–0.8; bottom pile arc grows 1 dp.
3. **Deploy:** only inside `PlayerAvatar.buildChip` — swap its sigil `ThematicIcon` for `AnimatedThematicIcon`. Every avatar everywhere gains idle life; standalone UI icons stay static.
**Validate:** widget test with an injectable ticker — pulse one subscriber: only that sigil's controller runs; reduce-motion → zero pulses; all existing avatar/roster tests unchanged (rest state identical). Perf note in PR: exactly one 2 s animation at a time, ticker idle otherwise.

## V3 · Deck selection as case files (`lib/widgets/deck_carousel.dart`)
Replaces the host's deck dropdown in the (M2-restructured) waiting room — the carousel is its own `ListView` item between the roster and the custom-prompts section. Non-hosts see a single centered chosen folder labeled `'THE CHOSEN FILE'` in `sectionLabel` (no interaction).
1. **Folder card (150×110 dp):** `parchment` rounded-rect 8 dp with a 30×10 dp tab top-left; string-tie: two crossing 1 dp `ink @0.5` lines to an 8 dp button circle at right-center; deck name Lora 13 bold `ink` top-left under the tab (maxLines 2); sample-prompt peek strip along the bottom — first prompt of the deck, Lora italic 10 `ink @0.6`, 2 lines ellipsized; **wax rating seal** bottom-right: `WaxSealBadge(size: 26)` with a new optional `String? label` param (1–2 chars, CormorantGaramond bold `0.3·size`, brass, replacing the starburst): relatable decks → wax `Color(0xFF7A6A3A)` label `'PG'`; `rated_r_nsfw` → `oxblood` label `'R'`; `cah_dark_humor` → `Color(0xFF2A2226)` label `'X'`. **Custom deck folder:** blank face + centered `ThematicIcon(writing, 30)` + `'CUSTOM DECK'` + live `'N prompts from M players'`.
2. **Carousel:** `PageView(controller: PageController(viewportFraction: 0.48))`, height 130; center page scale 1.0, neighbors 0.9 + opacity 0.6 (controller-listener transform); **snap = selection**: `onPageChanged` → `gs.updateLobbySettings(selectedDeckId: ...)` **debounced 400 ms** (never spam the callable mid-swipe); tapping a folder animates to it and selects. Selection commit plays the stamp-press pulse (scale 0.96→1.0, `AppMotion.fast`). The family-friendly toggle keeps filtering the deck list (existing logic).
**Validate:** widget test — one folder per available deck + custom; swipe to page 2, pump 400 ms → exactly **one** `updateLobbySettings` fake call with the right id; NSFW folder contains an oxblood `WaxSealBadge`; non-host build has no `PageView` gesture response; at 360 dp width the center folder + two peeking edges render without overflow. Manual: swipe feel + seal legibility.

## V1 · The Lamplighter's Raven (`lib/widgets/raven_mascot.dart`)
`enum RavenState { sleep, idle, hop, ruffle, fly }` · `RavenMascot({required RavenState state, double size = 64})`.
### A. Anatomy (one CustomPainter — side profile facing LEFT; all proportions of `size`)
Body: bézier teardrop, fill `Color(0xFF171310)`, back-edge rim-light stroke 1.5 dp `brass @0.12`. Head: circle `0.28` overlapping top-front. Beak: two-triangle wedge protruding `0.18`, fill `Color(0xFF3E3428)`. Eye: `0.05` brass dot + `0.02` ink pupil. Folded wing: layered path over the body with 3 feather notch lines `ivory @0.12`. Tail: 3-notch fan `0.30` behind. Legs: two 1.5 dp lines down to a **perch bar** the widget draws itself (2 dp brass rail, `0.9·size` wide) so the bird "sits on" any container edge.
### B. States
- **sleep:** head rotated down 25°, eye a closed arc; body scaleY breathes 1.0↔1.03 (3 s repeat-reverse).
- **idle:** every 5–8 s (random) head tilts 12° for 600 ms and back; 1-in-3 chance of a 150 ms blink instead.
- **hop:** translateY 0→`−0.12·size`→0 (300 ms; ease-out up, ease-in down) + wing flares 8°.
- **ruffle:** 500 ms — body scaleX 1→1.15→0.95→1, feather lines jitter ±1 dp, lower beak opens 15° for 200 ms.
- **fly (entrance):** enters from off-screen left along a shallow arc to its perch over 900 ms; spread-wing variant flaps 3× at 150 ms each; folds + 2 dp settle bounce on landing.
- **Reduce-motion:** static idle pose everywhere; fly-in replaced by appearing perched; no hops/ruffles/blinks.
### C. Placement & event wiring (exact — and nowhere else)
| Screen | Perch | State + trigger |
|---|---|---|
| Lobby waiting | atop the `RoomCodePlaque`, right-aligned (`Stack`, offset y `−0.78·size`) | `sleep`; wakes to `idle` for 3 s when `_knownPlayerIds` grows (existing join detection) |
| Craft waiting view | above the candle indicator | `idle` |
| Vote reader view | right end, atop the ballot row | `idle`; **hop once per new seal** — guard `Set<String> _hoppedFor`, parallel to UF2's sound guard |
| Reveal | top-right above the option list | `idle`; **ruffle once at the Truth flip** — piggyback the exact `_playedRevealForTargetId` trigger |
| Game over | centered above `'THE NIGHT'S HONORS'`, size 72 | `fly` at ceremony start, then `idle` |
NOT on: entry form, spectator views, the voter's card grid (never distract a choice).
### D. Validation
Widget tests: each state pumps without exceptions; `hop`/`ruffle`/`fly` complete (`pumpAndSettle`); repeating states (`sleep`/`idle`) tested with fixed pumps. Expose `@visibleForTesting int actionCount` on the state; assert vote-screen seal → exactly one hop per voter (guard re-pump stable), reveal truth flip → exactly one ruffle. Reduce-motion: static, `actionCount == 0`. **Manual gate (the only subjective check in this doc): at 64 dp the silhouette must read as a raven at arm's length — if ambiguous, iterate beak wedge and tail fan proportions FIRST, before any state work.**

---

## THE LOOP
```
(1) IMPLEMENT in the §2 order, one commit per item.
(2) VALIDATE per item + flutter analyze (0) + flutter test; full battery after M2, M5, V3, V1
    (functions build + emulator 28/28 — must never change).
(3) Impossible value → minimal deviation + commit note. Broken design → STOP, file with options.
(4) RECORD when all land: mark UF/M/V delivered in ongoing_general_errors.md (what shipped per item),
    tick design_ui_direction.md §10, and note the new widgets in design docs if behavior-relevant.
(5) Then STOP — do not invent work. Act only on new filled "Your selection:" lines or a battery regression.
```

## Definition of Done
- [ ] UF1–UF3 per spec (order/cadence/sounds/gating · caption/quiet-stamp/volume param · inkwell/pinned avatar).
- [ ] M1 portrait-locked (phones only); M3 scale clamped 1.0–1.3 + four widgets elastic at 1.3×; M4 all hit areas ≥44 dp (audit table in commit); M2 waiting room scrolls + pinned bar (10-player/custom-deck 360×640 test green); M5 thumb-zone bars on vote/reveal/game-over + craft keyboard exception + SafeArea everywhere.
- [ ] V4 zero `CircularProgressIndicator` in `lib/`; V5 five medallions, wire format unchanged; V2 one-at-a-time sigil pulses, rest-state identical; V3 carousel with debounced selection + rating seals; V1 raven with five states, evented on all five perches, silhouette gate passed.
- [ ] Every item validated at 360×640 portrait; reduce-motion path for every animation; full battery green at the end.
