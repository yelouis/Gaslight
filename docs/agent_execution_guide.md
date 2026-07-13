# Agent Execution Guide — Remaining Work (post-verification, July 13 evening)

**You are an engineering agent picking up Gaslight (Flutter + Firebase party game).** The July 13 verification of commit `8e8c2dd` found the delivery largely solid — but the marquee new feature (Unmask the Forger) has a **client presentation defect that inverts the mechanic**, and a few smaller tails remain. This guide is the complete remaining queue.

Context read (once): `docs/implementation_plan_gameplay_and_ui.md` **Section 0** (game, architecture, file map), `docs/design_database_and_security.md` (server-authoritative architecture), and `docs/design_scoring_and_ui.md` **"The Unmask Window & Five-Beat Reveal"** (the canonical contract F1 must implement).

---

## 1. Verified state (July 13 — trust this, don't re-verify)

**All proven by:** `npm --prefix functions test` **15/15** (full game loop, auth denials, seat re-bind, bot lastSeen, bot order-independence, timeout placeholders, unmask server scoring, custom-deck deal + reroll fallback, 7 rules tests) · `flutter test` **12/12** · `flutter analyze` **0 errors** · `functions` TypeScript builds clean.

- **Issues 1–20: ALL resolved** (entries #38–46 in `ongoing_general_errors.md` are verified legitimate).
- **P10 Custom Decks: delivered & verified** (server deal incl. terminal-fallback edge, lobby form, deck sync, reroll fallback). Residual: Issue 22 (cap) below.
- **P8 Unmask the Forger: server half delivered & verified** — `submitUnmaskGuess` validates everything and scores ±1 correctly; `unmaskDeadline` is set/cleared properly. **The client reveal sequencing is broken** — Issue 21 below. The feature must not be considered shipped until F1 lands.
- **N4 polish partials done:** PrimaryButton wax-stamp press, pulsing active-reader halo, low-time timer flicker. Still missing: E7 (sound/haptics/mute), E8 (a11y audit).
- **Declined forever:** proposals P7, P9, P11.

## 2. Work queue

| # | Item | Gate | Size |
|---|---|---|---|
| **F1** | Issue 21 — unmask reveal shows authors before the guess | ✅ **Option A selected — build** | Medium (client-only) |
| **F2** | Issue 22 — server cap: ≤3 custom prompts per player | ✅ **Option A selected — build** | 1 line + test |
| **F3** | Docs & manual tail for shipped features | none — proceed | Small |
| **F4** | E7 sound/haptics/mute + E8 a11y audit | none — proceed | Medium |

**All selections locked (July 13): Issues 21 and 22 are both Option A** — nothing is awaiting user input. Execute in order: **F1 → F2 → F3 → F4** (F3's journey docs must describe F1's *fixed* behavior, so land F1 first).

---

## F1 · Issue 21 — Re-gate the reveal beats on `unmaskDeadline` (Option A spec)

**The defect:** `_advanceRevealSequence()` in `lib/screens/phase4_reveal.dart` advances `_revealStage` 1→5 on fixed 1.8s timers. Forgery author cards flip at `_revealStage >= 4` (~7.2s); the guess tray renders at `_revealStage == 5` (~9s); the server accepts guesses until `unmaskDeadline` (~20s). Fooled players read the author off the screen, then "guess" — a guaranteed +1/−1 every card.

**Target behavior** is codified in `design_scoring_and_ui.md` → "The Unmask Window & Five-Beat Reveal". Implementation:

1. **Rewire stage semantics** so the beat clock is the server deadline, not local delays:
   - Keep short local timers only for beats 1→2 (vote chips) and 2→3 (truth flip) — e.g. 1.8s each, as now.
   - **Stage 3 (window)**: entered after the truth flip. While `state.unmaskDeadline != null && now < unmaskDeadline`, stay in stage 3. The existing 200ms `_countdownTimer` already rebuilds the widget — derive the current beat *functionally* from (`local intro timers elapsed`, `unmaskDeadline`, `now`) rather than mutating `_revealStage` in nested `Future.delayed` chains. A helper like `int _computeStage(int nowMs)` makes rejoin-mid-reveal land correctly for free (server timestamps, not local state).
   - **Stage 4 (author flips + REVENGE results)**: entered when `unmaskDeadline == null` (nobody fooled → skip stage 3 entirely) or `now >= unmaskDeadline`. Keep a ~1.8s beat before stage 5 (points/standings) as now.
2. **Move the tray before the flips:** render `_buildRevengeGuessTray` during **stage 3** (currently `_revealStage == 5`); it already handles fooled vs. non-fooled display and the countdown. Remove the stage-5 rendering.
3. **Keep these already-correct pieces:** forgery rows flip on `_revealStage >= 4`; truth row flips at stage ≥2; host CONTINUE already locks while the window is active (line ~480) — verify it uses the same deadline check as the new stage logic.
4. **Guard:** when the player has already guessed (`card.unmaskGuesses[me.id] != null`), the tray shows a "Guess sealed" state for the remainder of the window (verify this exists; add if not).
5. **Reduce-motion:** unchanged — flips render final state, but the stage-3 *window* must still gate author visibility (it's gameplay, not decoration).
6. **Mirror check:** `test/fake_functions.dart` already sets `unmaskDeadline` — confirm the fake's value is far enough out for widget tests to observe stage 3 (make it injectable if needed).

**Validation (write these BEFORE fixing, watch them fail, then fix):**
- Widget test A: pump the reveal with a fooled local player and `unmaskDeadline = now + 15000`. After the intro beats settle, assert: guess tray visible, every forgery row still shows `SEALED ANSWER`, no author name text anywhere.
- Widget test B: advance mocked time past the deadline (or set a near-past deadline and pump) → assert authors flipped, REVENGE row present, tray gone.
- Widget test C: `unmaskDeadline == null` → no tray ever, authors flip after the intro beats promptly.
- Widget test D: local player NOT fooled → status line instead of tray during the window.
- Manual (emulator, 2 humans): fall for a lie — confirm you must guess blind, the countdown runs, authors flip only at zero, and your ±1 lands in the REVENGE row. Confirm an all-TRUTH card skips the wait. Confirm host CONTINUE unlocks exactly when the window ends.
- On completion: move Issue 21 → Resolved; delete the "(Violation … Issue 21)" parenthetical from the design doc's regression guard; mark P8 fully delivered in the proposals status note.

## F2 · Issue 22 — Harvest cap (Option A spec)

**Option A only was selected — do NOT add a `firestore.rules` size gate.** In `functions/src/index.ts` `startGame` custom branch: after the hygiene filter (trim, non-empty, ≤200 chars), take at most 3 **valid** prompts per player before pooling — i.e., collect each player's filtered prompts into a list and `.slice(0, 3)` it (cap valid prompts, not raw entries, so `["", "a", "b", "c", "d"]` still yields `a, b, c`). Everything downstream (dedupe against `seen`, top-up, assignment) is unchanged. Rebuild (`npm run build`).

**Validation:** emulator test — Admin-seed a player doc with 10 marker prompts (`FLOOD_01`…`FLOOD_10`), start a 2-player custom game, and assert at most 3 `FLOOD_` prompts entered play (the other player's card must hold a `FLOOD_` or fallback prompt; count `FLOOD_` texts across all dealt cards ≤ the cap minus dedupe effects) and the deal still succeeds. Move Issue 22 → Resolved; remove the "(Per-player cap … see open Issue 22)" parenthetical from `design_prompt_system.md` §3 step 1, restating it as shipped behavior.

## F3 · Docs & manual tail (proceed now; finish after F1)

Verified missing on July 13:
1. **Lobby "HOW TO PLAY" manual** (`lobby_screen.dart` `_showInstructions`): add one player-friendly line each for the Unmask revenge guess (+1/−1, one guess, during the reveal window) and Custom Decks (write up to 3 prompts in the lobby; never dealt your own).
2. **`docs/e2e_testing_journeys.md`**: add Journey 6 (Unmask: fall for a forgery → guess blind during the window → verify ±1 and the REVENGE row — describe the **post-F1** behavior) and Journey 7 (Custom Deck: two devices contribute, host picks Custom, verify no one receives their own prompt, try a re-roll).
3. Confirm `README.md` still documents `npm --prefix functions test`; add a line that the suite now covers unmask + custom decks.

## F4 · E7 + E8 (unchanged from previous guide)

1. **E7 — sound + haptics behind a mute toggle:** bundled effects (quill scratch on submit, wax thunk on vote, low swell on the truth flip — and now a seal-crack sting when authors flip at F1's stage 4), `HapticFeedback` on commit/reveal, an audio dep (`audioplayers` or `just_audio`), a settings mute toggle, silent-when-muted verified.
2. **E8 — a11y audit:** contrast-check brass/ivory on soot at body sizes; no meaning via dim opacity alone; tabular figures on all live numbers (including the unmask countdown); the `MediaQuery.accessibleNavigation` reduce-motion guard on every animation added since (halo pulse, stamp, flicker, tray pop).

**Validation:** `flutter analyze` 0 errors; mute ⇒ fully silent; reduce-motion ⇒ no pulsing/flip animation but correct final states; manual screen pass. Mark done or explicitly deferred in the Wave E section of `implementation_plan_gameplay_and_ui.md`.

---

## THE LOOP (per item)

```
 ORIENT once: read this guide + the design contract in design_scoring_and_ui.md ·
 flutter pub get · flutter analyze · cd functions && npm run build
      │
      ▼
 (1) SELECT next item: F1 → F2 → F3 → F4 (all approved; nothing pending).
 (2) STUDY the spec + the exact files named.
 (3) IMPLEMENT. Invariants: transaction reads before writes; advancePhaseInternal
     never reads; never weaken firestore.rules; authorship never visible while
     guesses are accepted (the F1 contract); keep test/fake_functions.dart mirrored.
 (4) VALIDATE per the item block, then flutter analyze (0 errors) · flutter test ·
     and for anything touching functions/ or rules: npm --prefix functions test.
     For F1, write the failing widget tests FIRST.
 (5) BLOCKED or spec wrong? STOP — file it in ongoing_general_errors.md
     (bug_documentation_guidelines format, with options) and ask the user.
 (6) RECORD: move resolved issues to Resolved with what-was-solved; sync the
     design docs (the Issue-21/22 pointers in design_scoring_and_ui.md and
     design_prompt_system.md must be cleaned up when fixed).
 (7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

## Definition of Done
- [ ] F1: five beats gated on `unmaskDeadline`; authors provably sealed during the window (widget tests A–D green); Issue 21 → Resolved; P8 marked fully delivered.
- [ ] F2: per-player cap enforced server-side (no rules change — Option A only); flood emulator test green; Issue 22 → Resolved; design-doc pointer cleaned.
- [ ] F3: manual + Journeys 6/7 + README note updated to post-F1 behavior.
- [ ] F4: E7/E8 done or explicitly deferred with notes.
- [ ] Final: `flutter analyze` 0 errors · `flutter test` green · `npm --prefix functions test` green · docs synced · one-item commits · P7/P9/P11 still untouched.
