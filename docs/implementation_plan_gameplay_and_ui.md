# Implementation & Validation Plan — Gameplay Features & Visual Identity

Companion to `docs/implementation_plan_selected_fixes.md`. That doc covers the selected **bug fixes** (Issues 1–11, Clarifications 1–2, Waves A–C). **This** doc covers the selected **new features** (gameplay Proposals P1–P6, all Option A — **Wave D**) and the selected **visual redesign** (the "Turn Down the Lamps" direction in `docs/design_ui_direction.md`, all sections approved — **Wave E**).

> Written so a fresh agent can execute it without prior context. **Section 0 is required reading** — it explains the app, where everything lives, and one constraint (the write-path) that decides what can be built now vs. after the server migration.

---

# 0. Context an executing agent needs (READ FIRST)

## 0.1 What the game is
Gaslight is a real-time multiplayer social-bluffing party game (think Fibbage × Cards Against Humanity) with a Victorian "gaslight mystery" theme. Each player gets a secret prompt card; players write fake answers ("forgeries") on each other's cards across S rotations, then write the truth on their own; everyone votes to find the truth; a reveal tallies points. Full rules: `docs/e2e_testing_journeys.md`, `docs/master_implementation_plan.md`, `docs/design_scoring_and_ui.md`.

## 0.2 Tech stack & architecture
- **Flutter** (Dart, `>=3.0.6 <4.0.0`), **Provider** for state, **Firebase** (Firestore + anonymous Auth) backend, **Cloud Firestore** streams for realtime.
- **`GameService extends ChangeNotifier`** (`lib/services/game_service.dart`) is the single source of truth. It holds `_gameState`, `_players`, `_currentPlayerId`; exposes getters (`gameState`, `players`, `currentPlayer`); subscribes to the room doc and players sub-collection; and drives all game logic. Screens do `context.watch<GameService>()` and rebuild reactively.
- **Firestore shape:** `/rooms/{roomCode}` = one `GameState` document; `/rooms/{roomCode}/players/{playerId}` = one `PlayerState` document each.
- **Routing is phase-driven, not push-driven:** every screen reads `state.currentPhase`, maps it via `GameState.getRouteForPhase`, and calls `Navigator.pushReplacementNamed` when its route no longer matches. Phases: `lobby → forgery → truth → vote → reveal → gameOver`. Vote+reveal repeat **once per card** (sequential resolution via `resolutionOrder`).

## 0.3 File map (what to touch)
| File | Role |
|------|------|
| `lib/services/game_service.dart` | All game logic, Firestore reads/writes, phase advancement, scoring hook |
| `lib/models/game_state.dart` | Room doc model (`GameState`, `GamePhase`, routing table) |
| `lib/models/player_state.dart` | Player doc model (`PlayerState`, `PlayerRole`) |
| `lib/models/card_model.dart` | `CardModel` (prompt, truth, `sabotageAnswers`, `votes`) |
| `lib/screens/lobby_screen.dart` | Entry form + waiting room (Proposal P5) |
| `lib/screens/phase2_craft.dart` | Forgery + Truth writing (Proposal P4 re-roll) |
| `lib/screens/phase3_vote.dart` | Voting grid + lockout |
| `lib/screens/phase4_reveal.dart` | Reveal (Proposals P1, P2, P3; UI motif E4) |
| `lib/screens/game_over_screen.dart` | Honors (Proposal P6; UI E5) |
| `lib/widgets/shared_ui.dart` | `CrimsonShadowCard`, `ParchmentCard`, `PrimaryButton`, `SecondaryButton` |
| `lib/widgets/player_avatar.dart` | Gem-chip tokens (`PlayerAvatar`, `buildChip`) |
| `lib/widgets/card_grid.dart` | Vote option cards + wax-seal select |
| `lib/widgets/auto_advance_timer.dart` | Countdown timer |
| `lib/widgets/lobby_background.dart`, `thinking_background.dart` | Animated backgrounds |
| `lib/main.dart` | `ThemeData` (colors, fonts), routes, Firebase/Auth init |
| `pubspec.yaml` | Dependencies + asset/font declarations |

## 0.4 Current design system (the base we're refining, not replacing)
- **Colors** (today, in `main.dart` `ColorScheme`): scaffold `#141A17`; primary crimson `#8B0000`; secondary gold `#D4AF37`; tertiary emerald `#1B5E20`; surface parchment `#F4EBD8`; onSurface ink `#2C1E16`; ivory text `#F5EEDB`. Many widgets **hardcode** these hexes inline (e.g. `Color(0xFF1A1F1C)` in `shared_ui.dart`, `card_grid.dart`, `game_over_screen.dart`).
- **Type:** Lora serif via `google_fonts` (`GoogleFonts.loraTextTheme` in `main.dart`) — fetched at runtime.
- **Components:** `CrimsonShadowCard` (dark coal + crimson glow = "the room"), `ParchmentCard` (parchment + gold = "the document"), gem-chip avatars, a red wax-seal stamp on vote selection.

## 0.5 THE WRITE-PATH CONSTRAINT (decides build-now vs build-after-server)
Per **Issue 1** (bug plan Wave C): today Firestore rules let **only the host** write the **room** document, but each player may write **their own player document**. This is being fixed by moving all room writes to Cloud Functions (Wave C). Until then:
- ✅ **Buildable now:** anything that only **reads** shared state, or writes to the acting player's **own** player doc.
- ⛔ **Blocked for non-host until Wave C:** anything that writes the **room** doc (`cards`, `votes`, `readyPlayers`, phase) from a non-host client.

Each feature below has a **Write-path** line saying which bucket it's in and how to build it so it survives the Wave C migration. **Rule of thumb:** implement any new mutation as a `GameService` method that mirrors the existing `submitCardAnswer`/`castVote` pattern, so Wave C can re-home it into a callable in one place.

## 0.6 Dependencies on the bug/correctness plan
- **A6 (metric honors)** in the bug plan adds `timesFooled` and `playersDeceived` to `PlayerState` and accumulates them at the vote→reveal scoring step. **P2's "Best Forgery" game-level honor and P6's share card read these fields — do A6 before D2/D6.** (P2's *per-round* banner can be derived from the current card's `votes` without A6; the persistent "Master Forger" honor needs A6.)
- **E1 (palette tokens)** should land before the reveal-heavy visual work (E4) and before D2, so new screens use tokens, not fresh hardcoded hexes.
- Everything that adds a room mutation (D4 re-roll; D5 house rules are host-only so fine) must be **mirrored into Wave C** callables — noted per item.

## 0.7 Recommended execution order
1. **Bug plan Wave A** (correctness + A6 honor stats) — prerequisite for D2/D6.
2. **E1 → E2 → E3** (palette tokens, fonts, lamp-pool background): the visual foundation; cheap, unblocks everything else looking right.
3. **D1, D5, D6** (leaderboard, lobby, share): high value, buildable now, mostly read/own-doc.
4. **D2 + E4 together** (reveal drama + card-flip/concealment): they rewrite the same screen — do as one effort.
5. **D3** (reactions): own-doc writes, buildable now.
6. **E5, E6, E7, E8** (components, icons, motion/sound, a11y polish).
7. **D4** (re-roll): needs the room-write path; land with or right after Wave C.
8. **Bug plan Wave C** (server migration); **mirror** D3/D4/D5 mutations and A6 scoring into callables.

---

# WAVE D — Gameplay Features (all Option A)

## D1 · Proposal P1 — Running leaderboard strip on the Reveal
**Player value:** standings every round create rivalry ("I just passed Bob!") instead of one surprise at the end.
**Write-path:** ✅ read-only. Buildable now.

**Build (`lib/screens/phase4_reveal.dart`):**
1. Add a slim horizontal ranked strip below the points-awarded chips: for each **non-spectator** player sorted by `totalScore` desc — token · name · score. Use `PlayerAvatar` (small, `showName:false`) + name + score.
2. Show **movement this card** using the already-computed `_latestDeltas` (the per-card points this screen calculates): render `▲ +N` in verdigris for a positive delta. (Optional rank-change arrow: snapshot the pre-card ranking by sorting `totalScore - delta`.)
3. Use `font-variant`/`FontFeature.tabularFigures()` on the score numbers so they don't jitter.
4. Keep it one row with horizontal scroll (`SingleChildScrollView`, `scrollDirection: Axis.horizontal`) so 10 players don't overflow.

**Validation:** Widget test — given 4 players with known scores + deltas, assert order is by score and the mover shows the correct `+N`. Manual — play 2 cards; confirm the strip updates and highlights who gained.

---

## D2 · Proposal P2 — Reveal drama: staggered votes → truth last → "Best Forgery" banner
**Player value:** the table-erupts moment. Votes land one by one, the truth is unmasked last, and the round's most convincing liar gets crowned.
**Write-path:** ✅ read-only rendering. **Depends on A6** for the persistent honor stats; per-round banner is standalone.
**Coordinate with E4** (card-flip/concealment) — same screen; build together.

**Build (`lib/screens/phase4_reveal.dart`):**
1. **Sequence the reveal** with a small state machine / staggered `AnimationController`: reveal forgery option rows first (each with its voter chips animating in), then the **Truth row last** with emphasis (verdigris, stamped seal — see E4).
2. **Voter chips land staggered:** instead of rendering all `voters` at once per row, animate them in with a per-chip delay (`TweenAnimationBuilder` + index-based delay, or an `AnimatedList`).
3. **"Best Forgery of the Round" banner:** compute, for the current card, which saboteur's answer received the most votes (`card.votes` values grouped by author, excluding `'TRUTH'`). Show `"{name}'s lie fooled {n} of you!"` with their token. Ties → show joint or pick highest.
4. Gate the whole sequence behind `prefers-reduced-motion`/the app's reduce-motion setting (E7): if reduced, skip straight to the final state.
5. The **game-level** "Master Forger" title on Game Over uses A6's cumulative `playersDeceived` (not this per-round banner).

**Validation:** Widget test — a card where Bob's forgery got 3 votes, Cara's got 1 → banner names Bob with "fooled 3". Golden/manual — watch the sequence: forgeries → truth last → banner; and with reduce-motion on, the final state renders instantly and correctly.

---

## D3 · Proposal P3 — Emoji reactions during the Reveal
**Player value:** 😂🐍👏 floating over the reveal — the social, shareable, replay-driving spark.
**Write-path:** ✅ **each player writes only their OWN player doc** → allowed by current rules. Buildable now. Mirror into a callable in Wave C only if you want server validation.

**Build:**
1. **Model (`lib/models/player_state.dart`):** add `String? lastReaction` and `int? lastReactionAt` (epoch ms); include in `toMap`/`fromMap`/`copyWith`.
2. **Service (`game_service.dart`):** add `Future<void> sendReaction(String emoji)` that writes `{lastReaction, lastReactionAt}` to `rooms/{code}/players/{currentPlayerId}` (own doc — permitted).
3. **UI (`phase4_reveal.dart`):** a fixed reaction tray (fixed emoji set, e.g. `😂 🤨 🐍 👏 🔥`). On tap → `sendReaction`.
4. **Broadcast render:** the players stream already updates `gs.players`. Track the last-seen `lastReactionAt` per player in screen state; when a player's `lastReactionAt` increases and is newer than screen mount, spawn a floating-emoji animation (rise + fade via `AnimatedPositioned`/an `OverlayEntry`). Ignore stale reactions from before this reveal.
5. Throttle client-side (e.g. one reaction / 500 ms) to bound writes.

**Validation:** Widget test — simulate a player doc gaining a newer `lastReactionAt`; assert a floating emoji spawns once and isn't replayed on unrelated rebuilds. Manual — two devices; a reaction on one animates on both.

---

## D4 · Proposal P4 — "I can't answer this" prompt re-roll (Truth phase)
**Player value:** if your own prompt doesn't apply to you, swap it once so your truth stays juicy and no card is dead.
**Write-path:** ⛔ writes the room doc (`cards[].promptText`) → **non-host blocked until Wave C.** Build the UI + a `GameService` method now (mirroring `submitCardAnswer`); it becomes fully functional for everyone when Wave C lands. Interim: works for the host only, or feature-flag off until Wave C.

**Build:**
1. **Model (`player_state.dart`):** add `bool hasRerolled` (default false) to enforce once-per-game; serialize it.
2. **Deck (`lib/utils/prompt_decks.dart`):** add a helper `String drawOneExcluding(String deckId, Set<String> used)` returning a random prompt from the deck not already on any card. (The game must remember the chosen `deckId`; if it isn't stored on `GameState`, add a `deckId` field in `startGame`.)
3. **Service (`game_service.dart`):** `Future<void> rerollMyPrompt()` — only in `truth` phase, only if `!currentPlayer.hasRerolled`; in a transaction, replace `card(currentPlayerId).promptText` with a new unused prompt and set the player's `hasRerolled = true`. (This is a room write → Wave C callable later.)
4. **UI (`phase2_craft.dart`):** during the Truth round only, show a subtle "This isn't me — draw another" text button; disable after use.
5. `startGame` must reset `hasRerolled=false` for all players.

**Validation:** Unit — `rerollMyPrompt` swaps to a prompt not present on any card and flips `hasRerolled`; a second call is a no-op. Manual — re-roll your truth card once; confirm the prompt changes and the button disables.

---

## D5 · Proposal P5 — Lobby warmth: live roster, ready-check, house rules
**Player value:** setup feels social and intentional; the host knows everyone's actually here before starting.
**Write-path:** live roster = ✅ read-only; ready-check = ✅ **own player-doc** field; house rules = ✅ host writes room doc (host is allowed). All buildable now.

**Build (`lib/screens/lobby_screen.dart` + models):**
1. **Live roster:** the waiting room already renders `gs.players` in a grid. Add entrance animation for newly-arrived players (animate the grid item in) and a small "Alice joined" toast when `players` grows.
2. **Ready-check (own-doc):** add `bool lobbyReady` to `PlayerState` (serialize). Non-host players get a "I'M READY" toggle in the lobby writing their own doc. The host sees "3/4 ready" and START is emphasized once all non-host players are ready (does not block; just guidance).
3. **House rules (host, room doc):** add lobby toggles that map to existing/near-existing `GameState` config: e.g. "family-friendly decks only" (filters the deck dropdown to PG-13 decks), round-count preset chips (writes `sabotageAnswersCount`), and reuse the existing "Disable Game Timers". Keep them host-only.
4. Pair with **Issue 8** (bug plan B2): the START button should already be gated/annotated for min players and rounds; the ready-check builds on that.

**Validation:** Widget — toggling a non-host's `lobbyReady` updates the host's "X/Y ready" count; a house-rule toggle changes the deck list / config. Manual — two devices; watch join animations, ready counts, and a house-rule change propagate.

---

## D6 · Proposal P6 — Shareable "Case File" summary card
**Player value:** a themed, image-shareable recap (winner, honors, funniest lie) — the organic-marketing moment at App Store launch.
**Write-path:** ✅ read-only + client render + OS share. Buildable now. **Depends on A6** honors for content. Adds a dependency (`share_plus`).

**Build (`lib/screens/game_over_screen.dart`):**
1. Add `share_plus` (and `path_provider`) to `pubspec.yaml`.
2. Build an off-screen themed summary widget (winner + the three metric honors from A6 + optionally the round's best-voted forgery text) wrapped in a `RepaintBoundary`.
3. On "Share": capture the boundary via `RenderRepaintBoundary.toImage()` → PNG bytes → temp file → `Share.shareXFiles([...])`. Replace the current stub `SnackBar('Sharing coming soon!')`.
4. Style it per E5 (framed-portrait / dossier look) so the shared image is on-brand.
5. Handle web (where file share differs) gracefully — fall back to a downloadable image or copyable recap.

**Validation:** Manual — finish a game, tap Share, confirm a correctly-composed PNG reaches the OS share sheet on iOS/Android; verify names/scores/honors match the final state. Widget — render the summary widget and assert it contains the winner and honor names.

---

# WAVE E — Visual Identity: "Turn Down the Lamps"

Full rationale: `docs/design_ui_direction.md`. North star: **a gas-lit Victorian parlor where every player is a suspect.** Do E1→E3 first (foundation), then the rest.

## E1 · Palette tokens & warm-neutral shift (§3 — approved)
**Do this first; it's the foundation.** Centralize colors, then apply the warm shift.

1. **Create `lib/theme/app_colors.dart`** with named constants (single source of truth):
   - `ground = Color(0xFF14110E)` (warm soot; replaces `#141A17`)
   - `groundRaised = Color(0xFF1C1712)` (replaces `#1A1F1C`)
   - `oxblood = Color(0xFF8B0000)` (primary; `#7B1E1E` acceptable for large fills)
   - `brass = Color(0xFFC9A24B)` (secondary; replaces bright gold `#D4AF37`)
   - `verdigris = Color(0xFF2E6E5B)` (tertiary/truth; replaces `#1B5E20`)
   - `parchment = Color(0xFFF4EBD8)`, `ink = Color(0xFF2C1E16)`, `ivory = Color(0xFFF5EEDB)`
2. **Rewire `main.dart` `ColorScheme`** to reference these constants (scaffold=ground, primary=oxblood, secondary=brass, tertiary=verdigris, surface=parchment, onSurface=ink).
3. **Replace hardcoded hexes** across `shared_ui.dart`, `card_grid.dart`, `game_over_screen.dart`, `phase4_reveal.dart`, `player_avatar.dart` (gold ring), backgrounds — swap literals for the tokens. Grep for `0xFF141A17`, `0xFF1A1F1C`, `0xFFD4AF37`, `0xFF1B5E20`, `0xFF8B0000`.
4. Keep **verdigris = truth/correct**, **oxblood = forgery/wrong** as *semantic* colors in the Reveal, distinct from **brass = brand accent** (don't let all three compete).

**Validation:** Visual regression / manual — every screen still renders, now on warm soot with aged brass; no leftover cool-green background or bright-gold accents. Grep confirms no stray old hexes.

## E2 · Typography — display face + bundled fonts (§4 — approved: Cormorant + blackletter wordmark)
1. **Bundle fonts as assets** (offline/App Store safe): add **Cormorant** (or Cormorant Garamond) for display and bundle **Lora** for body; declare both under `pubspec.yaml` `flutter: fonts:`. Stop relying on runtime `google_fonts` fetches (a silent fallback would break the identity).
2. **Phase titles & wordmark** (`GASLIGHT`, `FORGERY`, `TRUTH`, `THE VOTE`, `THE REVEAL`, honor titles): Cormorant display, ~28–32px, `letterSpacing: 3`, brass, soft dark drop-shadow ("spotlight"). Reserve a restrained **blackletter/engraved** treatment for the `GASLIGHT` wordmark **only** (logo, not body) — keep legibility.
3. **Section labels** ("CASE PROMPT", "VOTES", "POINTS AWARDED"): Lora small-caps, ~12px, `letterSpacing: 2`, brass @ 70%.
4. **Body/answers:** Lora; ensure parchment answers use full-strength `ink`.
5. **Numbers** (timer, scores, "ready X/Y"): `TextStyle(fontFeatures: [FontFeature.tabularFigures()])`.

**Validation:** Manual on device (fonts load offline — turn off network) — titles render in Cormorant, wordmark in the display face, no Lora fallback; numbers don't shift width as they tick.

## E3 · Lamp-pool background + vignette (§5a — approved)
1. Create a shared `AtmosphereBackground` wrapper: a warm **radial gradient** light pooled top-center over `ground`, falling to a darker **vignette** at the edges (`RadialGradient` in a `BoxDecoration`, or a `CustomPaint`).
2. Layer it **under** the existing `AnimatedThinkingBackground`/`AnimatedLobbyBackground`; dim their glyph particles so they read as dust motes in lamplight, not sparkles.
3. Apply on every screen scaffold so the whole app feels like one lit room.

**Validation:** Manual — every screen shows the same warm light pool + vignette; particles are subtle; text contrast still passes (E8).

## E4 · Concealment → reveal motif (§5b — approved Option A) — build with D2
1. **Wax-seal watermark** on anonymous voting cards' back styling (`card_grid.dart`), reinforcing "sealed identity".
2. **Redaction bars** (brushed-ink rectangles) wherever authorship is hidden, instead of blank space.
3. **Card-flip unmasking on Reveal** (`phase4_reveal.dart`): each forgery row/card flips (3D `Transform` rotationY via `AnimationController`; swap front/back at π/2) from a **wax-sealed back** to the **author's token + name** — the seal "cracks". Truth flips last to a **stamped "THE TRUTH" seal** in verdigris.
4. Respect reduce-motion (E7): render final unmasked state without the flip.

**Validation:** Manual — reveal plays as a sequence of unmaskings; with reduce-motion, authors show immediately. Widget — assert author names are present in the final state regardless of animation.

## E5 · Component upgrades (§6 — approved)
- **Buttons (`shared_ui.dart`):** `PrimaryButton` gets a pressed "stamp" feel (quick scale-down + faint wax-ring flash on tap) for commits (SUBMIT, CONFIRM VOTE). Retheme `SecondaryButton` to **verdigris**, reserved for host/utility actions (color = meaning).
- **Avatars (`player_avatar.dart`):** add a thin **engraved bevel** (inner top-left highlight, bottom-right shadow); give the **active reader** a **brass lamplight halo** so "whose card" is obvious.
- **Timer (`auto_advance_timer.dart`):** on `isLowTime`, make the lamp-pool pulse and the ring flicker (guttering lamp) rather than only turning red; keep tabular digits.
- **Craft (`phase2_craft.dart`):** style the text field as an inkwell/telegram form (thin brass underline vs. full box); show "A forgery on behalf of —" with the target's token.
- **Vote grid (`card_grid.dart`):** keep the wax-seal select; give the disabled self card a "SEALED — your own hand" ribbon so it reads intentional, not broken (pairs with a11y in E8).
- **Game Over (`game_over_screen.dart`):** present honors as **framed portraits/plaques** (brass frames) rather than flat cards.

**Validation:** Manual per component — commit buttons stamp; reader has a halo; low-timer flickers; self vote-card shows the ribbon; honors look like framed portraits. Widget — `SecondaryButton` uses verdigris; reader halo appears only for `currentReaderId`.

## E6 · Iconography overhaul (§7 — approved: now)
1. Replace stock **Material icons** (`remove_red_eye`, `timer`, `casino`, `vpn_key`, `lightbulb_outline`, etc.) with a **thin-line Victorian set**: monocle/magnifier (observe/spectator), pocket-watch (timer), quill & nib (writing), wax seal (submit/confirm), skeleton key (secret), candelabra/gas-lamp (host/light). Bundle as an icon font or SVGs (single-weight, brass).
2. Swap the six **avatar glyphs** (`PlayerAvatar.thematicIcons`) for six **engraved house sigils** (moth, moon, key, raven, hourglass, flame) so each player reads as a crest. Keep the index-based API so existing `avatarIndex` values still map.

**Validation:** Manual — no stock Material icons remain on primary screens; avatar picker shows six sigils; existing players keep a stable icon per `avatarIndex`.

## E7 · Motion, sound & feel (§8 — approved) — restraint
1. Concentrate motion into **orchestrated moments**: wax-stamp on commit; card-flip on reveal (E4); lamp-flicker on low timer and phase transitions.
2. Optional high-impact: a few **bundled sounds** (quill scratch on submit, wax *thunk* on vote, low swell on Truth reveal) + **haptics** on commit/reveal, behind a **mute toggle**.
   > [!NOTE]
   > **Sound Assets Note (updated July 14)**: Decision 1 = **Option B (add sound)**. The **CC0 audio assets are now sourced and committed** to `assets/audio/` (`quill_scratch.wav`, `wax_stamp.wav`, `truth_reveal.wav`, `unmask_success.wav`; Kenney Interface/Impact packs, CC0, see `assets/audio/CREDITS.md`). The remaining work — `audioplayers` dependency, `AudioService`, persisted mute toggle, and trigger wiring — is fully specced in `docs/agent_execution_guide.md` → item **S1**. Ambient lobby loop remains optional/unsourced.
   > **Haptics**: `HapticFeedback.mediumImpact()` is triggered on commit/reveal events.
3. Add a **"reduce motion" setting** and honor the OS accessibility flag; every animation (E4/D2/D3) checks it and degrades to the final state.

**Validation:** Manual — animations feel intentional, not scattered; reduce-motion toggles/OS settings work; no motion when reduce-motion is on.

## E8 · Accessibility & polish (§9 — approved)
1. Parchment answer text at full-strength `ink`; don't carry meaning by dim opacity alone — the disabled self vote-card uses the **ribbon** (E5) + dimming together.
2. Verify **brass-on-soot** and **ivory-on-soot** meet WCAG AA at body sizes (the warmer brass helps).
3. Keep the app **single-theme (dark)** by design; document that so no one adds a reflexive light mode. If a light mode is ever wanted, make it a "daylight / evidence room" (parchment ground) variant, not an inversion.
4. Tabular figures on all live numbers (timer, scores, "ready X/Y").

**Validation:** Run a contrast checker on brass/ivory over soot; manual VoiceOver/TalkBack pass on the main flow; confirm no meaning is conveyed by color/opacity alone.

---

# Cross-cutting: what Wave C (server migration) must re-home
When the bug plan's **Wave C** moves room writes to Cloud Functions, mirror these new mutations too so they don't regress:
- **D3 `sendReaction`** — either keep as an own-player-doc write (still allowed) or move to a `react` callable for validation.
- **D4 `rerollMyPrompt`** — becomes a `rerollPrompt` callable (it writes `cards`); enforce once-per-game (`hasRerolled`) server-side.
- **D5 house-rule / ready-check** — host config writes move server-side; `lobbyReady` can stay an own-doc write.
- **A6 honor-stat accumulation** and **D2 scoring-derived banner** — the stat increments happen inside the same server scoring step that applies deltas.

# Definition of Done (Waves D–E)
- [ ] Bug plan Wave A + A6 merged first (prereq for D2/D6).
- [ ] `flutter analyze` clean; new unit/widget tests per item green; `flutter test` passes.
- [ ] Palette centralized in `app_colors.dart`; no stray legacy hexes (grep clean).
- [ ] Fonts bundled; app renders correctly with the network off.
- [ ] New deps (`share_plus`, any audio) added to `pubspec.yaml` and `flutter pub get` run.
- [ ] Reduce-motion honored by every new animation.
- [ ] New room-writing features (D4, D5 host config) flagged for Wave C mirroring; own-doc features (D3, D5 ready-check) verified against current rules.
- [ ] `docs/ongoing_general_errors.md` proposals + `docs/design_ui_direction.md` sections marked delivered; design docs updated where behavior/looks changed.
