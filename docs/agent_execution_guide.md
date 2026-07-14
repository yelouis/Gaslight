# Agent Execution Guide — One Active Item: E7 Sound (verified July 13)

**You are an engineering agent picking up Gaslight (Flutter + Firebase party game).** As of the July 13 verification pass, every previously-selected issue and feature is implemented and verified green — **except one now-approved build item: E7 bundled sound (item `S1` in §4).** The user chose **Option B** (add sound + mute toggle) and asked you to source or generate the audio assets yourself per the plan below. Read this whole guide before starting, so you don't redo finished work or "fix" intentional decisions.

Context read (once): `docs/implementation_plan_gameplay_and_ui.md` **Section 0** (game, architecture, file map) and `docs/design_database_and_security.md` (server-authoritative architecture).

---

## 1. Verified state — trust this, re-run the battery before changing anything

**Full battery (July 13 verification pass):**
- `cd functions && npm run build` — clean.
- `flutter analyze` — **0 errors** (lint-only info/warnings remain).
- `flutter test` — **16/16 passing** (incl. `test/phase4_reveal_test.dart` reveal-ordering tests).
- `npm --prefix functions test` — **16/16 passing** on the Firebase emulator: full two-client game loop, auth denials, seat re-bind, bot `lastSeen:null`, bot order-independent advance, timeout placeholders, **unmask revenge-guess scoring**, **custom-deck deal + top-up + reroll fallback + 3-prompt cap**, and 8 `firestore.rules` tests.

**Everything shipped and confirmed:**
- **Issues 1–22: ALL resolved** — entries #38–48 in `ongoing_general_errors.md` are verified legitimate against the code and tests.
- **Server-authoritative backend (Issue 1):** all mutations are Cloud Functions callables; `firestore.rules` denies client room writes and scopes player-doc writes to non-protected fields; Gemini key is server-side.
- **P8 Unmask the Forger — fully playable.** Server scoring + the client five-beat reveal (authors stay sealed through the `unmaskDeadline` window, flip only after it passes). Contract: `design_scoring_and_ui.md` → "The Unmask Window & Five-Beat Reveal".
- **P10 Custom Decks — complete.** Lobby contribution form (own-doc field-scoped writes), host deck sync, server harvest/top-up/own-prompt-free assignment incl. terminal-fallback edge, reroll fallback, and the 3-per-player cap (Issue 22).
- **Visual polish:** palette tokens, bundled Cormorant/Lora fonts, lamp-pool background, thematic icons, PrimaryButton wax-stamp press, pulsing active-reader halo, low-time timer flicker (reduce-motion aware), haptics on commit/reveal.
- **Declined forever — never implement:** proposals **P7** (confidence wager), **P9** (house-card modifiers), **P11** (final gambit).

There are **no unresolved issues** in `ongoing_general_errors.md`.

---

## 2. What to do

1. **Primary: build item `S1` (E7 sound) — §4.** This is the one approved, unbuilt item. Execute it via the loop in §3.
2. After S1 lands, the queue is empty — do **not** invent work. Only act again if: a **new user selection** appears in `ongoing_general_errors.md` (a fresh `### Issue N` / `### Decision N` / proposal with a filled `Your selection:` line), or a **regression** appears (the §1 battery no longer passes on a fresh checkout → triage, file with options, fix). Otherwise report complete and stop; don't refactor working, tested code for its own sake.

---

## 3. THE LOOP (only when there is a selected item to build)

```
 ORIENT: read the item's block · flutter pub get · run the full §1 battery to confirm a green baseline.
      │
      ▼
 (1) STUDY the item spec + the exact files + the design_*.md that defines its contract.
 (2) IMPLEMENT. Invariants (do not violate):
       • Cloud Functions transactions: ALL reads before ANY writes; advancePhaseInternal never reads.
       • Never weaken firestore.rules to make something pass.
       • test/fake_functions.dart must mirror functions/src/index.ts behavior.
       • Forgery authorship is never visible while unmask guesses are accepted (the deadline is the beat clock).
 (3) VALIDATE per the item's block, then the full §1 battery. For anything touching functions/ or rules,
     the emulator suite (npm --prefix functions test) is mandatory — a fake-only pass does not count.
 (4) BLOCKED or spec wrong? STOP; file it in ongoing_general_errors.md with options; ask the user.
 (5) RECORD: move the issue to Resolved with a what-was-solved note; sync the design_*.md if behavior/looks changed.
 (6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## 4. S1 · E7 Bundled Sound (Option B — approved) — full build spec

**Decision:** `ongoing_general_errors.md` → "Decision 1" = **Option B**. Add themed SFX at the commit / vote / Truth-reveal moments, behind a **mute toggle**, silent when muted. Haptics (`HapticFeedback.mediumImpact()`) and reduce-motion are already done — **do not** gate audio on reduce-motion (that suppresses *animation*, not sound). This is a client-only change (no Firestore/functions impact).

Build in four parts (B–E), validate (F), document (G). **Part A (assets) is already DONE** — see below.

### A. Audio assets — ✅ ALREADY SOURCED & IN REPO (Route 2 / CC0, July 14)
The CC0 assets are already produced and committed to `assets/audio/`. **Do not re-source them.** They are mono, 44.1 kHz, 16-bit PCM WAV (universal iOS/Android/web support, low latency), peak-normalized to −3 dBFS. Provenance + licenses are in `assets/audio/CREDITS.md`.

| File | Moment (trigger) | Length | Source (all **CC0**, Kenney) |
|---|---|---|---|
| `quill_scratch.wav` | submit forgery/truth | 325 ms | Interface Sounds — `scratch_004` |
| `wax_stamp.wav` | vote lock / "I'M READY" | 300 ms | Impact Sounds — `impactPunch_medium_000` (trimmed) |
| `truth_reveal.wav` | Truth flips in reveal | 1.74 s | Impact Sounds — `impactBell_heavy_001` (a **bell toll**, not a rising swell — chosen for gothic gravitas) |
| `unmask_success.wav` *(optional)* | your correct revenge guess | 290 ms | Interface Sounds — `confirmation_001` |

Notes: (1) the reveal cue is a **bell toll** (sharp strike + long decay), so the method is best named `playReveal()`/the file `truth_reveal.wav` — don't rename it "swell". (2) `lobby_ambience` was **not** sourced (Kenney has no ambient bed); it's optional — leave it out, or add a CC0 dark-ambient loop later and append a `CREDITS.md` row. (3) These four are drop-in; if any sounds wrong on audition, swap for a sibling from the same CC0 packs (still in the Kenney zips) and update `CREDITS.md`.

> **Second-opinion audition (do this before wiring):** the repo has an `audio_review/` folder with **3 CC0 candidates per slot** (the `_CURRENT` files are the shipped picks) and `audio_review/README.md` — a full listening procedure + selection criteria for an independent model/human to confirm or override each pick by ear. Run/consult it, copy each winner into `assets/audio/` under its canonical name, update `CREDITS.md` if a source changed, then **delete `audio_review/`** (it must not ship in the bundle).

### B. Dependency + `AudioService`
1. `pubspec.yaml`: add `audioplayers: ^6.x`; declare `assets/audio/` under `flutter: assets:`.
2. Create `lib/services/audio_service.dart` — a singleton wrapping `audioplayers`. Preload the clips (hold `AudioPlayer` instances or use `AudioCache`; set low-latency `AudioContext`/`PlayerMode.lowLatency` where supported). Expose `playSubmit()`, `playVote()`, `playReveal()`, `playUnmaskSuccess()`, and `startLobbyAmbience()`/`stopLobbyAmbience()`. Every `play*` **early-returns when muted** (reads the flag from part C). One-shots use `ReleaseMode.stop`; ambience uses `ReleaseMode.loop`. Dispose players on teardown.

### C. Mute toggle (persisted)
1. Persist `soundEnabled` (default `true`) in `SharedPreferences`; expose it (small `SettingsService`/provider, or fold into `GameService` with a getter + `toggleSound()` + `notifyListeners()`). `AudioService` checks this before every play; turning it off also calls `stopLobbyAmbience()`.
2. UI: a speaker / speaker-off **`ThematicIcon`** button (use the existing `lib/theme/app_icons.dart` set) in the lobby app bar (and optionally the reveal app bar).

### D. Trigger points (fire alongside the existing haptics — same call sites)
- **Submit** forgery/truth — `phase2_craft.dart` `_submitAnswer` on success → `playSubmit()`.
- **Vote confirm** — `phase3_vote.dart` `_castVote`; and the reader **"I'M READY"** lock → `playVote()`.
- **Truth reveal** — `phase4_reveal.dart` when the Truth flips (the moment `revealStage` reaches 2 / the truth `FlippingRevealCard` opens) → `playReveal()`. **Guard against re-fire:** play once per card (track e.g. `_playedRevealForReaderId == currentReaderId`), because the widget rebuilds on the 200 ms countdown timer.
- **Optional** correct unmask (beat ≥ 4, local player's `unmaskGuesses[me] == votes[me]`) → `playUnmaskSuccess()` once.
- **Optional** `startLobbyAmbience()` on entering the lobby; `stopLobbyAmbience()` on game start / leave.

### E. Platform notes
- **Web autoplay:** browsers block audio before a user gesture. The first SFX is triggered by a tap (submit/vote), which satisfies the policy — but do **not** auto-start lobby ambience before the first interaction on web; start it on the first user tap or gate it behind a play control.
- Keep the bundle lean; lazy-load; avoid overlapping the same player instance (give reveal/ambience their own players).

### F. Validation
- **Unit/widget (mute contract):** inject a fake/mock audio backend into `AudioService`; assert that with `soundEnabled=false` `playVote()`/`playSubmit()`/`playReveal()` produce **zero** `play` calls, and with `true` exactly one each.
- **Reveal once-per-card guard:** pump the reveal so it rebuilds several times for one reader; assert `playReveal` fires exactly once, and again (once) after advancing to the next reader.
- **Regression:** the full §1 battery still green (`flutter analyze` 0 errors, `flutter test`, `npm --prefix functions test` — audio shouldn't touch functions, so the emulator suite must be unchanged/green); existing commit/reveal **haptics still fire**; reduce-motion still suppresses animation but audio still plays.
- **Manual:** iOS + Android — each moment plays its clip at acceptable latency; toggling mute mid-game silences immediately (incl. ambience); web shows no autoplay-blocked console spam.

### G. Docs
- Flip the E7 "Sound Assets Deferral Note" in `implementation_plan_gameplay_and_ui.md` from *deferred* to *shipped* (list the files + trigger sites + mute toggle).
- Add `assets/audio/CREDITS.md` (source/license per file).
- Add one line to the lobby "HOW TO PLAY" manual mentioning the mute control.
- Move **Decision 1** to a Resolved-style note once shipped (it's a decision, not a bug — record it as delivered in the doc).

---

## 5. Definition of Done
**Preserve (already met — regression bar):**
- [x] `flutter analyze` 0 errors · `flutter test` green · `npm --prefix functions test` green · `functions` builds.
- [x] Issues 1–22 in the Resolved section; P8 + P10 delivered & verified; P7/P9/P11 not implemented.
- [x] Design docs synced (`design_scoring_and_ui.md`, `design_prompt_system.md`, `design_database_and_security.md`).

**S1 · E7 sound (the active item):**
- [x] CC0 assets in `assets/audio/` (+ `CREDITS.md`) — done (Kenney CC0; `quill_scratch`/`wax_stamp`/`truth_reveal`/`unmask_success`). Remaining sub-items below are the wiring.
- [ ] `AudioService` + persisted `soundEnabled` mute toggle (lobby speaker icon); every `play*` silent when muted.
- [ ] Triggers wired at submit / vote+ready / Truth-reveal (once-per-card guard), alongside existing haptics; audio NOT gated on reduce-motion.
- [ ] Mute-contract test (zero `play` calls when muted; exactly one when on) + once-per-card reveal test green; full §1 battery still green; web has no autoplay-blocked spam.
- [ ] E7 note flipped to "shipped"; Decision 1 recorded as delivered; lobby manual mentions the mute control.
