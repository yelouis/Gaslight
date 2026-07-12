# Agent Execution Guide — Remaining Work (post-verification, July 12)

**You are an engineering agent picking up Gaslight (Flutter + Firebase party game) after the second verification pass.** The server-authoritative backend (Wave C) has been *built* but has a **fatal bug that makes the game unplayable on it**, and it has never been executed by a test. Your job is to make the backend actually work, prove it with real emulator tests, and finish the remaining polish. Do **not** re-do finished work.

---

## 1. Current state (verified July 12)

**DONE and verified correct** (do not redo):
- Bug fixes **Issues 2–12** + Clarifications 1–2 → Resolved entries #26–37 in `docs/ongoing_general_errors.md`.
- Gameplay **Proposals P1–P6** (leaderboard, reveal drama + card-flip, reactions, re-roll, lobby warmth, share).
- UI foundation: palette tokens (`lib/theme/app_colors.dart`), bundled Cormorant/Lora fonts, lamp-pool background, concealment/card-flip reveal motif.
- **Wave C structure**: `functions/` (TypeScript, compiles clean via `npm run build`), locked-down `firestore.rules`, client `GameService` fully refactored onto callables, game rules faithfully mirrored in TS (per-card scoring + Sharp Eye bonus, placeholders, honor stats, idempotent disconnect + join-order host transfer), Gemini key server-side with a Firestore embeddings cache, `USE_EMULATOR` wiring.

**BROKEN / MISSING (your job), in priority order:**

| # | Work item | Spec lives in | Size |
|---|---|---|---|
| **R1** | **Issue 13 (CRITICAL)** — backend transactions read after writing; every submit/vote/ready throws | `ongoing_general_errors.md` → Issue 13 | Small fix, big impact |
| **R2** | **Issue 15 (HIGH)** — build the mandated emulator + rules test suite (none exists; fakes only) | Issue 15 + `implementation_plan_selected_fixes.md` Wave C4 | ~1 day |
| **R3** | **Issue 14 (HIGH)** — callable failures leave players stuck on spinners with no message | Issue 14 | Small |
| **R4** | **Issue 16 (MEDIUM)** — finish stable identity: client still uses auth-uid as playerId and clears sessions instead of using the server's re-bind | Issue 16 + Wave C5 | Small–Medium |
| **R5** | **Issue 17 (MEDIUM)** — debug/bot tools still write Firestore directly → dead under the new rules; also stale `integration_test/fake_firestore.dart` no longer compiles (2 analyzer errors) and dead `_resetAllPlayersReady`/`updateGameState` remnants | Issue 17 | Medium |
| **R6** | **Issue 18 (LOW)** — `sendReaction`/`toggleLobbyReady` send full player objects; stale protected fields can get writes rejected | Issue 18 | Tiny |
| **R7** | **UI polish Wave E leftovers** — E6 icon overhaul (stock Material icons remain in `phase2_craft`, `phase3_vote`, `lobby_screen`, `auto_advance_timer`, `player_avatar`); audit/finish E5 (stamp press, avatar bevel, reader halo, timer flicker), E7 (sound/haptics + mute), E8 (contrast audit) | `implementation_plan_gameplay_and_ui.md` Wave E | Medium |

⚠️ **Issues 13–18 carry `Your selection: _____` lines — check `ongoing_general_errors.md` first.** If the user has filled them in, follow the selection; if blank, implement the recommended Option A for R1–R3 (they are correctness/validation items with clear right answers) but **wait for the user on Issue 16 and 17** if their selections are still blank, since those change behavior/scope.

**Why R1+R2 outrank everything:** Issue 1 (the original multiplayer blocker) is *implemented but not resolved* — the game cannot actually be played on the new backend until Issue 13 is fixed, and no one can honestly claim it works until the Issue 15 suite passes. R1 without R2 just reopens the same blind spot that let R1 happen.

---

## 2. Where the docs are

| Purpose | Doc |
|---|---|
| **Required context** (game, architecture, file map) | `docs/implementation_plan_gameplay_and_ui.md` → **Section 0** — read first |
| Open issues with options + selections (Issues 1, 13–18) | `docs/ongoing_general_errors.md` (Unresolved section) |
| The server architecture as shipped (callables table, rules, identity model) | `docs/design_database_and_security.md` (rewritten July 12 — current) |
| Server-side semantic filter design | `docs/design_semantic_integrity.md` |
| Original Wave C plan (C0–C5) | `docs/implementation_plan_selected_fixes.md` |
| UI polish plan (E5–E8) | `docs/implementation_plan_gameplay_and_ui.md` |
| Manual test flows | `docs/e2e_testing_journeys.md` (Journey 2's bot buttons are broken until R5) |
| Doc/commit conventions | `.agents/skills/` (`bug_documentation_guidelines`, `issue_resolution`, `resolved_issue_cleanup`, `commit_message_guidelines`, `fixing_ui_issues`) |

---

## 3. Execution notes per item

### R1 — Issue 13: reorder transaction reads (fix first)
In `functions/src/index.ts`, `submitAnswer`, `castVote`, and `setReady` each do: read room → **write** room → **read** players. Firestore transactions require all reads before any writes, so the Admin SDK throws on the late players read — on every call. Fix per the selected option (recommended A): move `transaction.get(roomRef.collection("players"))` up next to the room read in all three callables, compute the merged `readyPlayers`, then write and conditionally call `advancePhaseInternal`. Rebuild (`cd functions && npm run build`). Do **not** validate this with `test/fake_functions.dart` — that fake is why the bug shipped; validation is R2.

### R2 — Issue 15: real emulator + rules tests
- Add an `emulators` block (auth 9099, firestore 8080, functions 5001) to `firebase.json`.
- Write a functions-side integration test (Node, or a Dart integration test run under `firebase emulators:exec`) that drives **two authenticated clients** through a full 4-player loop via the real callables: create → join → start → 2 forgery rotations → truth → per-card vote/reveal (assert scores, placeholder fill on a force-advance, honor stats) → game over. This test must fail before R1's fix and pass after.
- Add `@firebase/rules-unit-testing` tests: client cannot write the room doc; cannot create/delete player docs; cannot change `totalScore`/`isHost`/`authUid` on its own doc; **can** change `lastSeen`/`lastReaction`/`lobbyReady` on its own doc; cannot touch another player's doc.
- Wire into one command (e.g. `npm test` in `functions/` using `firebase emulators:exec`) and document it in the README.
- While here: delete or fix the stale `integration_test/fake_firestore.dart` (2 `invalid_override` analyzer errors after the SDK bump). Keep `test/fake_functions.dart` only for fast widget tests; the emulator suite is the source of truth for backend behavior.

### R3 — Issue 14: surface callable errors
Wrap the callable awaits in `phase2_craft.dart` (`_submitAnswer`), `phase3_vote.dart` (`_castVote`, reader ready) in try/catch on `FirebaseFunctionsException`; SnackBar the message; reset `_isSubmitting`/`_submitted` for retry. Remove the dead client `SemanticFilter` pre-check and the redundant `setPlayerReady` after `submitCardAnswer` (server already marks ready).

### R4 — Issue 16: finish stable identity (respect the user's selection)
If Option A selected: generate + persist a UUID `playerId` (never the auth uid) in `_getPlayerId()`; on rejoin mismatch, call the `joinRoom` callable to re-bind `authUid` instead of clearing the session; keep a one-time migration for old uid-keyed sessions. Update `design_database_and_security.md` §5 to remove the "current gap" note when done.

### R5 — Issue 17: debug tools (respect the user's selection)
If Option A selected: add gated `debugAddBots`/`debugSimulateBots` callables (refuse without a `debug: true` room flag or emulator detection); point the existing buttons at them; delete the dead `_resetAllPlayersReady`/`updateGameState` client remnants. The R2 emulator loop test can reuse the bot driver.

### R6 — Issue 18: targeted own-doc writes
Replace the `copyWith` + full-map `updatePlayerState` in `sendReaction`/`toggleLobbyReady` with field-scoped updates (`{'lastReaction': …, 'lastReactionAt': …}`, `{'lobbyReady': …}`).

### R7 — Wave E polish
Start with E6 (replace stock Material icons with the thematic line set; swap avatar glyphs to house sigils keeping the `avatarIndex` mapping). Then audit E5/E7/E8 against the plan and implement or explicitly defer each with a note. Honor reduce-motion on any new animation (the card flip already shows the pattern).

---

## 4. THE LOOP (repeat per work item)

```
   ORIENT once: read gameplay_and_ui.md §0 · check Issues 13–18 selections in
   ongoing_general_errors.md · flutter pub get · flutter analyze · cd functions && npm run build
        │
        ▼
  (1) SELECT the next item: R1 → R2 → R3 → R4 → R5 → R6 → R7.
  (2) STUDY its Issue entry + the files it names + the relevant design_*.md.
      If its "Your selection" is blank and the item changes behavior/scope (16, 17),
      ask the user instead of guessing.
  (3) IMPLEMENT exactly as specified. The TS functions are the authoritative game
      rules — keep the Dart mirrors (fake_functions, ScoringLogic) in sync or
      clearly subordinate. Never weaken firestore.rules to make something pass.
  (4) VALIDATE: item-specific test → `flutter analyze` (0 errors) → `flutter test`
      → for backend items, the R2 emulator suite (`firebase emulators:exec`) green.
      A FakeFirestore/fake_functions pass does NOT validate backend behavior.
  (5) BLOCKED / spec wrong? STOP; document in ongoing_general_errors.md
      (bug_documentation_guidelines format, with options) and ask the user.
  (6) RECORD: move the fixed issue to Resolved with what-was-solved; update
      design_database_and_security.md / other design docs if behavior changed;
      when R1+R2 are both green, ALSO move Issue 1 to Resolved (it is waiting
      only on them).
  (7) COMMIT (Conventional Commits, WHY in the body). One item = one commit.
        │
        ▼
   More items? → (1).  All done? → run §5 checklist, report to the user.
```

---

## 5. Definition of Done
- [ ] **R1**: the three callables read-before-write; `npm run build` clean; the emulator loop test passes end-to-end (proves both R1 and R2).
- [ ] **R2**: `firebase emulators:exec` suite green — two-client full game + rules tests (deny room writes/protected fields, allow cosmetic self-writes); stale `integration_test/fake_firestore.dart` removed/fixed (analyzer back to 0 errors).
- [ ] **Issue 1 moved to Resolved** once R1+R2 are green (with the emulator test named as its proof), and `design_database_and_security.md`'s status note updated.
- [ ] **R3**: failed submits/votes show a message and allow retry; dead pre-check + redundant ready call removed.
- [ ] **R4–R6**: per the user's selections; docs updated (esp. §5 of the database design doc).
- [ ] **R7**: E6 done; E5/E7/E8 each done or explicitly deferred with a note in the plan doc.
- [ ] `flutter analyze` 0 errors · `flutter test` green · emulator suite green · issues moved to Resolved · one-item Conventional Commits.

---

## 6. Quick-start (TL;DR)
1. Read `docs/implementation_plan_gameplay_and_ui.md` **§0**, then Issues 13–18 in `docs/ongoing_general_errors.md` (note which selections are filled).
2. **R1**: fix the read-after-write ordering in `submitAnswer`/`castVote`/`setReady`.
3. **R2**: build the emulator + rules test suite; prove the full two-client game loop.
4. Move **Issue 1** (and 13, 15) to Resolved once that loop is green.
5. **R3–R7** in order, honoring the user's selections; loop per §4; when blocked, ask.
