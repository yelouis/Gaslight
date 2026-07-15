# Agent Execution Guide — One Active Item: H1 (Heuristic Similarity) (July 14)

**You are an engineering agent picking up Gaslight (Flutter + Firebase party game).** Everything previously selected is implemented and verified green (§1) — **except one newly-approved change: replace the Gemini-based "too similar" answer check with a dependency-free heuristic, server-enforced and mirrored on-device for instant feedback (item `H1`, §4).** The user approved removing the Gemini path entirely. Read this before starting so you don't redo finished work or "fix" intentional decisions.

Context read (once): `docs/implementation_plan_gameplay_and_ui.md` **Section 0** (game, architecture, file map) and `docs/design_database_and_security.md` (server-authoritative architecture).

---

## 1. Verified state — trust this, re-run the battery before changing anything

**Full battery (July 14 verification pass):**
- `cd functions && npm run build` — clean.
- `flutter analyze` — **0 errors** (lint-only info/warnings remain).
- `flutter test` — **19/19 passing** (incl. `test/phase4_reveal_test.dart` reveal-ordering + `test/audio_service_test.dart` mute-contract tests).
- `npm --prefix functions test` — **16/16 passing** on the Firebase emulator: full two-client game loop, auth denials, seat re-bind, bot `lastSeen:null`, bot order-independent advance, timeout placeholders, **unmask revenge-guess scoring**, **custom-deck deal + top-up + reroll fallback + 3-prompt cap**, and `firestore.rules` tests.

**Everything shipped and confirmed:**
- **Issues 1–22 + Decision 1 (E7 sound): ALL resolved** — entries #38–49 in `ongoing_general_errors.md` are verified legitimate against the code and tests.
- **Server-authoritative backend (Issue 1):** all mutations are Cloud Functions callables; `firestore.rules` denies client room writes and scopes player-doc writes to non-protected fields; Gemini key is server-side.
- **P8 Unmask the Forger — fully playable.** Server scoring + the client five-beat reveal (authors stay sealed through the `unmaskDeadline` window, flip only after it passes). Contract: `design_scoring_and_ui.md` → "The Unmask Window & Five-Beat Reveal".
- **P10 Custom Decks — complete.** Lobby contribution form (own-doc field-scoped writes), host deck sync, server harvest/top-up/own-prompt-free assignment incl. terminal-fallback edge, reroll fallback, and the 3-per-player cap (Issue 22).
- **E7 Sound — complete.** Four CC0 (Kenney) SFX in `assets/audio/` wired via `lib/services/audio_service.dart` at submit/vote/reveal(once-per-card)/unmask, with a persisted mute toggle; mute contract tested. (`CREDITS.md` records CC0 provenance.)
- **Visual polish:** palette tokens, bundled Cormorant/Lora fonts, lamp-pool background, thematic icons, PrimaryButton wax-stamp press, pulsing active-reader halo, low-time timer flicker (reduce-motion aware), haptics on commit/reveal.
- **Declined forever — never implement:** proposals **P7** (confidence wager), **P9** (house-card modifiers), **P11** (final gambit).

There are **no unresolved issues or open decisions** in `ongoing_general_errors.md`.

---

## 2. What to do

1. **Primary: build item `H1` (§4)** — replace the Gemini similarity check with the heuristic. Execute via the loop in §3.
2. After H1 lands, the queue is empty — do **not** invent work. Only act again if a **new user selection** appears in `ongoing_general_errors.md` (a fresh `### Issue N` / `### Decision N` / proposal with a filled `Your selection:` line), or a **regression** appears (the §1 battery fails on a fresh checkout → triage, file with options, fix). Otherwise report complete and stop; don't refactor working, tested code for its own sake. The delivered `S1 · E7 sound` and `H1` specs are retained as records.

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

## 4. H1 · Replace Gemini "too similar" check with a heuristic (approved) — full build spec

**Decision:** remove the Gemini embedding path entirely; the duplicate-answer check becomes a **dependency-free lexical heuristic**, **enforced server-side** (in the `submitAnswer` callable) and **mirrored on-device** in `phase2_craft.dart` for instant "try again" feedback before the round-trip. No API key, no network, no cost, no "fail-open"; deterministic and unit-testable. This resolves **Decision 2** in `ongoing_general_errors.md`. Rationale/spectrum is recorded there; this is the build.

**What it must catch** (tiers): (1) exact/near-exact dupes ("Sleeping!" vs "sleeping"); (2) reworded overlap ("sleeping in my bed all day" vs "sleep all day in bed" — the Journey 5 case). **Acknowledged non-goal:** pure synonyms with no shared words ("a quick nap" vs "sleeping") are *allowed through* — that's the documented trade-off of dropping the model; do not try to hand-maintain a synonym list.

### A. The shared algorithm (MUST be byte-identical in Dart and TS)
Implement `isTooSimilar(candidate: String, existing: List<String>) -> bool` → returns true (reject) if `candidate` is too similar to **any** entry in `existing`. Put it in its own file each side so it's unit-testable and mirrorable (like `rotation_engine`/`scoring_logic`):
- **TS:** `functions/src/text_similarity.ts` → `export function isTooSimilar(...)`.
- **Dart:** `lib/utils/text_similarity.dart` → `class TextSimilarity { static bool isTooSimilar(...) }`.

**Constants (identical both sides):**
- `STOPWORDS = {a, an, the, my, your, our, his, her, their, this, that, in, on, of, to, and, or, for, with, at, is, am, are, was, were, be, been, it, i, me, we, you, all}`
- `JACCARD_THRESHOLD = 0.6`
- `LEV_RATIO_THRESHOLD = 0.85`
- `CONTAINMENT_MIN_TOKENS = 2`

**Helpers:**
- `normalize(s)`: lowercase → replace every char **not** in `[a-z0-9]` with a space → collapse runs of spaces → trim. (Non-ASCII becomes spaces; acceptable.)
- `stem(tok)` — apply the **first** matching rule only:
  - len>5 & endsWith `"ing"` → drop last 3
  - else len>4 & endsWith `"ed"` → drop last 2
  - else len>4 & endsWith `"es"` → drop last 2
  - else len>3 & endsWith `"s"` & **not** endsWith `"ss"` → drop last 1
  - else len>4 & endsWith `"ly"` → drop last 2
  - else return tok
- `contentTokensSet(s)` → normalize → split on space → drop empties & STOPWORDS → `stem` each → collect into a **Set**.
- `contentPhrase(s)` → same as above but keep **order** and join with single spaces (a String).

**Reject `candidate` C against an `existing` entry E if ANY of:**
1. **Exact:** `normalize(C) == normalize(E)`.
2. **Containment:** let `pc=contentPhrase(C)`, `pe=contentPhrase(E)`; the shorter (by char length) is a substring of the longer **and** the shorter has ≥ `CONTAINMENT_MIN_TOKENS` content tokens.
3. **Jaccard:** `tc=contentTokensSet(C)`, `te=contentTokensSet(E)`; if both non-empty, `|tc∩te| / |tc∪te| ≥ JACCARD_THRESHOLD`.
4. **Levenshtein:** on `na=normalize(C)`, `nb=normalize(E)`: `ratio = 1 - lev(na,nb)/max(na.length, nb.length)`; `ratio ≥ LEV_RATIO_THRESHOLD` (guard: if both empty, ratio=1). Standard DP Levenshtein; answers are ≤200 chars so O(n·m) is fine.

Iterate `existing`; return true on the first match; else false. Expose the constants at file top so thresholds are tunable during playtests.

**Worked cases (use as the test table, both sides — identical expected results):**
| candidate | existing entry | expect |
|---|---|---|
| `Sleeping!` | `sleeping` | REJECT (exact after normalize) |
| `sleeping in my bed all day` | `sleep all day in bed` | REJECT (Jaccard ≈1.0) |
| `the dog ate the homework` | `my dog ate my homework` | REJECT (Jaccard 1.0) |
| `pizza` | `pizza with pineapple` | ALLOW (shorter <2 tokens; Jaccard 0.5) |
| `a quick nap` | `sleeping` | ALLOW (synonym gap — intended) |
| `went to the club` | `clubbing downtown` | ALLOW (different enough) |
| `hello world` | `` (empty) | ALLOW |

### B. Server: enforce in `submitAnswer` (`functions/src/index.ts`)
1. **Delete** the Gemini block (the `const geminiApiKey = process.env.GEMINI_API_KEY; …` similarity section, ~lines 477–512) and the now-unused helpers `getEmbedding`, `getAnswerHash`, and `cosineSimilarity`. No code writes the `rooms/{code}/embeddings` cache anymore (it was ephemeral — nothing to migrate).
2. `import { isTooSimilar } from "./text_similarity";`
3. Before the write transaction (same place the old check ran), build the **existing-answers list** for the target card exactly as the old block did:
   - fetch the card (`room.cards.find(targetPlayerId === targetCardId)`),
   - `existing = [...Object.entries(card.sabotageAnswers).filter(([sabId]) => sabId !== authorId).map(([,v]) => v)]`, and **push `card.truthAnswer` only if it is non-empty AND `isTruth === false`** (a forgery must not match the truth; the truth must not match a forgery).
   - `if (isTooSimilar(text, existing)) throw new HttpsError("invalid-argument", "Answer is too similar to another player's answer!");` — keep the **same error code + message** the client already recognizes.
4. This now always runs (no key gate, no try/catch "fail open"). Keep it **outside** the transaction (matching current placement) so it doesn't enlarge the transaction read set.

### C. Client: instant pre-check (`lib/utils/text_similarity.dart` + `phase2_craft.dart`)
1. **Delete** `lib/utils/semantic_filter.dart` and create `lib/utils/text_similarity.dart` with the identical algorithm (pure Dart; **no** `http`, **no** `dotenv`, no network).
2. In `phase2_craft.dart` `_submitAnswer`, **before** `await gs.submitCardAnswer(...)`: derive the same `existing` list from `state.cards` for the target card (sabotage values excluding `me.id`, plus `truthAnswer` when non-empty and not the truth phase). If `TextSimilarity.isTooSimilar(text, existing)` → show the existing SnackBar *"Too similar to an existing answer! Be more creative."*, `setState(() => _isSubmitting = false)`, and **return without calling the server**. Otherwise proceed (the server still enforces — defense in depth).
3. Fix imports: `phase2_craft.dart` imports the new `text_similarity.dart`; **remove the now-unused `semantic_filter.dart` import in `game_service.dart`** (there are no `SemanticFilter.` calls left in `lib/`).

### D. Mirror in the test fake (`test/fake_functions.dart`)
The fake `submitAnswer` must apply the same `isTooSimilar` rejection (port the Dart `TextSimilarity`, or import it) with the same error, so existing widget/sim tests behave like production.

### E. Cleanup (remove Gemini remnants)
- `pubspec.yaml`: remove the `http` dependency (only `semantic_filter.dart` used it — confirm with grep after deleting the file). **Keep** `flutter_dotenv` (still used by `firebase_options.dart`, `main.dart`, `game_service.dart` for Firebase config + `USE_EMULATOR`).
- `README.md`: delete the **"Gemini API Key Prototyping Risk"** section (lines ~51–55); replace with one line: *duplicate-answer detection is a local heuristic — no external AI, no API key.*
- Remove `GEMINI_API_KEY` from any `functions/.env`, deploy notes, and `.env.example` if present.
- Tests `test/ui_e2e_test.dart` and `test/simulation_test.dart` currently call `SemanticFilter.clearCache()` / `debugSetEmbedding(...)` — delete those lines; where they relied on forcing a "too similar" rejection (e.g. `simulation_test.dart:501-502` sleeping-vs-sleep), keep the *pair of strings* but let the real heuristic reject them (assert the rejection), and ensure other simulated answers are mutually dissimilar so the sim still advances.

### F. Design doc
Rewrite `docs/design_semantic_integrity.md` to describe the heuristic: reframe it as **"Duplicate-Answer Filtering"** (it is lexical, not semantic — you may keep the filename to avoid breaking links, or rename and update references). Document the algorithm + the four triggers + thresholds, that it runs **server-authoritative in `submitAnswer` and mirrored on-device for instant feedback**, and the explicit synonym trade-off. Remove all Gemini/embedding/cosine/`x-goog-api-key` content.

### G. Validation
- **TS unit** `functions/test/text_similarity.spec.ts`: the worked-cases table (A) → expected reject/allow, plus normalization/stemming edge cases.
- **Dart unit** `test/text_similarity_test.dart`: the **same table**, asserting **parity** with the TS results (this is the guard that the two mirrors agree — the whole point).
- **Emulator E2E** — add an `it` to `functions/test/game_e2e.spec.ts`: player A submits a forgery; player B submits a near-duplicate on the same card → `submitAnswer` rejects with `invalid-argument` "too similar"; B then submits a distinct answer → succeeds. (This is the enforced test the Gemini path never had.)
- **Client widget test**: typing a near-duplicate and tapping SUBMIT shows the SnackBar and does **not** invoke the submit callable (inject a fake `GameService`/functions that fails the test if `submitCardAnswer` is called); a distinct answer does call it.
- **Full battery green:** `cd functions && npm run build` · `flutter analyze` 0 errors · `flutter test` · `npm --prefix functions test`.

### H. Record
Move **Decision 2** to delivered in `ongoing_general_errors.md` (Resolved-style entry: what was solved), and confirm `design_semantic_integrity.md` + README updated.

---

## 5. S1 · E7 Bundled Sound (Option B — approved) — full build spec  ·  ✅ DELIVERED (record)

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

## 6. Definition of Done
**H1 · Heuristic similarity (the active item):**
- [ ] `isTooSimilar` implemented identically in `functions/src/text_similarity.ts` and `lib/utils/text_similarity.dart`; worked-cases table passes on **both** (parity).
- [ ] Gemini fully removed: `getEmbedding`/`getAnswerHash`/`cosineSimilarity` + the env-key block gone from `functions/src/index.ts`; `lib/utils/semantic_filter.dart` deleted; `http` dropped from `pubspec.yaml`; README Gemini section removed; no `GEMINI_API_KEY` anywhere.
- [ ] Server enforces in `submitAnswer` (always runs, same error); client pre-checks in `phase2_craft.dart` (instant SnackBar, no server call on a dup); fake mirrors it.
- [ ] Emulator E2E rejects an enforced near-duplicate over the callable; client widget test proves the pre-check blocks before the server; obsolete `SemanticFilter` test hooks replaced.
- [ ] `design_semantic_integrity.md` rewritten to the heuristic; Decision 2 → Resolved.
- [ ] Full battery green (`functions` build · `flutter analyze` 0 · `flutter test` · emulator suite).

**Preserve (already met — regression bar):**
- [x] `flutter analyze` 0 errors · `flutter test` green · `npm --prefix functions test` green · `functions` builds.
- [x] Issues 1–22 + Decision 1 in the Resolved section; P8 + P10 delivered & verified; P7/P9/P11 not implemented.
- [x] Design docs synced (`design_scoring_and_ui.md`, `design_prompt_system.md`, `design_database_and_security.md`).

**S1 · E7 sound — ✅ DELIVERED (July 14):**
- [x] CC0 assets in `assets/audio/` (+ `CREDITS.md`) — Kenney CC0; `quill_scratch`/`wax_stamp`/`truth_reveal`/`unmask_success`.
- [x] `AudioService` + persisted `soundEnabled` mute toggle (handbell icon, lobby + reveal); every `play*` silent when muted.
- [x] Triggers wired at submit / vote+ready / Truth-reveal (once-per-card guard `_playedRevealForTargetId`) / correct-unmask; deferred via `addPostFrameCallback`; not gated on reduce-motion.
- [x] Mute-contract test (`test/audio_service_test.dart`: zero `play` when muted, one when on, correct asset paths) green; full battery green (19/19 + 16/16).
- [x] E7 note flipped to "shipped"; Decision 1 recorded as delivered (Resolved #49); lobby manual mentions the mute control.
