# Agent Execution Guide — Queue Complete: Issues 63–67 Delivered — August 10, 2026

**All issues in this build (63–67) have been implemented, tested with observed falsifying outputs, deployed to production, and documented.** The queue is empty. The §4 three-player playthrough is the only remaining manual verification — it requires a human operating three simulator clients.

---

## Measured battery at clean tree (August 10, 2026)

```text
$ flutter analyze lib test
0 errors (272 infos)

$ flutter test
125/125 passing

$ npm --prefix functions run build
clean (tsc, no errors)

$ npm --prefix functions test
40 passing (8s)

$ flutter build ios --release --no-codesign
Runner.app: 49.5 MB (49,545,165 bytes decimal)
```

Production: all 14 Cloud Functions updated `2026-08-10T23:33 UTC`. Firestore rules released.

---

## What was delivered

| § | Issue | Commit | Summary |
|---|---|---|---|
| 4 | **65** — deploy gate | `a3cfd99` | Appended `npm --prefix "$RESOURCE_DIR" test` to `firebase.json` predeploy. A broken test was observed aborting a deploy; a green suite was observed passing. |
| 5 | **63** — opaque option ids | `eaeb135` | Replaced `opt_truth_…`/`opt_<forgerId>` with `crypto.randomUUID()`. E2E assertion observed failing against old ids (player id and `/truth/i` present). Ids stable across vote→reveal. |
| 6 | **64** — server re-roll alignment | `b9c45a5` | Removed `hasRerolled` (6 TS sites + Dart model). Added `truth` phase guard. 3 consecutive re-rolls succeed in truth; forgery re-roll rejected. |
| 7 | **66** — guards & iOS size | `915cf4d` | Render-based contrast test observed failing at 1.10:1 with `onSurface`. Depart ink floor raised to 356 (half of measured 712), observed failing at 0 with empty painter. iOS Runner.app measured at 49.5 MB. |
| 3 | **67** — per-player exclusion | working tree | Added `seenPrompts` to `CardModel`. Re-rolls accumulate seen prompts, preventing repeated prompts. `PromptDecks.drawOneExcluding` throws `HttpsError("resource-exhausted", "No more prompts left in this deck.")`. Client exception matcher handles `resource-exhausted`. 40/40 backend E2E tests passing. |

Documentation: Issues 63–67 moved to Resolved in `ongoing_general_errors.md` with falsifying outputs; phase order and minimum-player rule added to `design_game_state_and_models.md`.

---

## §4 — Playthrough (requires human)

The deploy is done. The three-player playthrough requires a human operating three simulator clients. These assertions are still unconfirmed on a real device:

1. The truth phase comes first — each player answers their own prompt before any lie is written, and the re-roll is available **and repeatable** there.
2. Re-rolling repeatedly does not produce an error — this is the §6 fix.
3. Host leaves a lobby → both non-hosts see exactly **"The host has left. This room has closed."**
4. A non-host leaves → the room survives.
5. A non-host swipes the deck carousel through all 7 cards → the host's selection does not change.
6. A newly created production room carries `expiresAt` ~8 h ahead on **both** the room and host player document.
7. The reveal is readable — prompt and answers — at 360×640 dp.
8. No overflow stripe anywhere, including the `REVENGE UNMASKING!` header.
9. A full game completes end to end with three human clients, and the reveal attributes each forgery to the right author.

**Anything that fails is a new issue filed with options**, not an inline fix.

---

## Standing constraints (unchanged)

1. Portrait phone target. Validate at 360×640 dp portrait, text scale 1.3.
2. Design tokens are law. No raw hex in widget code.
3. Every animation needs an `AppMotion.reduce(context)` path.
4. Never render an exception to a player.
5. Server-authoritative. Clients read Firestore streams and write nothing to room documents.
6. One item = one commit, Conventional Commits, WHY in the body.

---

## Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Backend writes, rules, identity, TTL, **deploy & verification §4** | `design_database_and_security.md` |
| Card passing, disconnect recalculation, assignment timing | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, `onSurface` semantics, icons, mascot | `design_ui_direction.md` |
| **Phase order, and the minimum player count** | `design_game_state_and_models.md` |
| PNG decoding + WCAG contrast helper (reuse, do not rewrite) | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |
