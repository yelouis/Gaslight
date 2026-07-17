# Agent Execution Guide — Queue Complete (verified July 16)

**You are an engineering agent picking up Gaslight (Flutter phone game, Android + iOS).** As of the July 16 verification pass, **every item ever selected is implemented and independently verified** — the server-authoritative backend, all gameplay features (P1–P6, P8, P10), the heuristic duplicate-answer check, E7 sound, the full UI/UX program (U0–U8 + UF punch list), the mobile-first pass (M1–M5 + MF1), and the character pass (V1–V5). **There is no outstanding engineering work.** Read this before starting anything so you don't redo finished work or "fix" intentional decisions.

## 1. Verified baseline (July 16 — re-run before changing anything)
- `flutter analyze` — **0 errors** (lint-only infos remain).
- `flutter test` — **49/49** (includes 360×640 phone-layout tests, audio mute contracts, reveal-ordering, ceremony stagger/sounds, MF1 bar).
- `cd functions && npm run build` — clean.
- `npm --prefix functions test` — **28/28** on the Firebase emulator (full game loops, rules, bots, custom decks, unmask scoring, dup-check).

## 2. The world as built — intentional decisions (do NOT "fix" these)
- **Server-authoritative:** clients read Firestore streams; ALL mutations go through Cloud Functions callables; `firestore.rules` denies client room writes. Transactions read-before-write always; `advancePhaseInternal` never reads.
- **Craft SUBMIT is in-flow** under the text field (not a bottom bar) — deliberate keyboard-interplay exception (M5). Vote's CONFIRM is bottom-anchored via `Expanded`+`SafeArea` — accepted equivalent of the bar.
- **Portrait-locked on phones**, iPad rotation intentionally kept.
- **Text scale clamped 1.0–1.3** app-wide (accessibility trade-off, recorded in M3).
- **Reactions send raw emoji strings** over the wire; medallions are render-side only (V5).
- **Duplicate-answer check is a lexical heuristic** mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`; pure synonyms passing is the accepted trade-off (Decision 2).
- **The `_advancedStateKeys` / once-per-event guard patterns** (reveal sounds, raven hops, seal stamps, ceremony sounds) exist to survive Firestore-stream rebuilds — never remove them.
- Design tokens are law: `AppColors` / `AppTextStyles` / `AppMotion` / `ThematicIcon` / `WaxSealBadge`. Every animation has an `AppMotion.reduce` path. Every layout is validated at **360×640 dp portrait**.

## 3. If you were spawned to "continue the work"
1. **A new user selection landed** — check `ongoing_general_errors.md` for a fresh `### Issue N` / `### Decision N` / proposal block with a filled `Your selection:` line. If it's UI/animation work, write a detailed design spec (durations/curves/dimensions/tokens/guards/validation) into this guide FIRST, then implement via §4.
2. **A battery regression** — if §1 no longer passes on a fresh checkout: triage, file it in `ongoing_general_errors.md` (bug_documentation_guidelines format, with options), fix per §4.
3. **Store-readiness chores** (only if the user asks): app icons/splash, store listing assets, privacy manifest, release signing. These are user-driven — do not start them unsolicited.
4. **Nothing changed** — report the queue is complete and stop. Do not refactor working, tested code for its own sake.

## 4. THE LOOP (only when §3 gives you a real item)
```
(1) STUDY the item + the design_*.md contract it touches + the exact files.
(2) IMPLEMENT exactly as specified (specs are decisions, not suggestions).
(3) VALIDATE per the item, then the full §1 battery. Anything touching functions/ or
    rules REQUIRES the emulator suite — fakes never validate backend behavior.
(4) BLOCKED or spec wrong? STOP; file with options; ask the user.
(5) RECORD: move resolved items to Resolved with what-was-solved; sync design docs.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

## 5. Where everything lives
| What | Where |
|---|---|
| Engineering history + all delivery records | `docs/ongoing_general_errors.md` |
| How to run/playtest (local emulator + TestFlight) | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` (scoring/UI incl. five-beat reveal contract · prompt system incl. custom decks · database/security incl. callables table · duplicate-answer filtering · UI direction, stamped SHIPPED) |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc/commit conventions | `.agents/skills/` |
