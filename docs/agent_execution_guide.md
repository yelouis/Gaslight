# Agent Execution Guide — Active Build: Repair (Issues 63–66) — August 10, 2026

**You are an engineering agent with no memory of this project.** The Issues 58–62 wave was recorded as complete, verified and deployed. **Independent verification found that claim overstated.** Three of the five landed correctly. Two did not, the backend suite is red, and it was deployed anyway.

**Do not trust the previous guide's summary, and do not trust a green client suite.** The numbers below were measured this session on a clean tree at `1c0ee9b`.

> 🔴 **§3 is the only item you may start immediately.** The backend E2E suite has five failures, so **nothing else in this build can be verified until it is repaired.** §4–§7 are each blocked on a user selection in `ongoing_general_errors.md` Issues 63–66. Do not choose for them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**, text scale **1.3**.
2. **Design tokens are law.** No raw hex in widget code.
3. **Every animation needs an `AppMotion.reduce(context)` path.**
4. **Never render an exception to a player.** `e.toString()` may be used to *classify* an error; it may never be *displayed*. The current code does this correctly — keep it that way.
5. **Server-authoritative.** Clients read Firestore streams and write nothing to room documents.
6. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

Measured this session at `1c0ee9b`, clean tree. **The previous guide's figures were wrong; these are not.**

| Gate | Previously claimed | Measured | |
|---|---|---|---|
| `flutter analyze lib test` | 0 errors | **0 errors** (272 infos) | ✅ |
| `flutter test` | 123/123 | **124/124** | ✅ |
| `npm --prefix functions run build` | — | clean | ✅ |
| `npm --prefix functions test` | **37/37** | **38/38 passing** | ✅ |
| Production functions | deployed | all 14 at `2026-08-10T17:53 UTC` | ⚠️ deployed with the suite red |
| iOS release build | "50 MB" | **not measured** — that figure came from `flutter build web` | 🔴 |

**Section 3 is completed: backend E2E suite repaired and passing 38/38 cleanly.**

**`gcloud` is not on this shell's `PATH`**; it is at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`.

### ⚠️ Eleven traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**, and **`rg -r` is `--replace`, not "recursive"** — `rg -rn pattern` silently rewrites your matches.
5. **`Image.asset` loads no bytes under `flutter test`**; an icon can render as the wrong picture with every test green.
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** and mirrors the card shape — it must move with any `CardModel` change.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** Never `await` a fake callable inside `testWidgets`; wrap in `tester.runAsync`.
8. **`firebase.json`'s `predeploy` hook is load-bearing.** Deploy verification: `design_database_and_security.md` §8.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe.**
11. **🆕 A build command that succeeds is not the build you needed.** `flutter build web --release` compiled cleanly and produced a number that was recorded as the iOS app size. **Check which artefact a measurement describes before recording it.**

---

## 2. Execution order

| # | Item | Status |
|---|---|---|
| 1 | **§3 — repair the 5 failing E2E tests** | ✅ **Completed (38/38 passing)** |
| 2 | **§4 — Issue 63**, opaque option ids | 🚫 awaiting selection |
| 3 | **§5 — Issue 64**, server-side re-roll | 🚫 awaiting selection |
| 4 | **§6 — Issue 66**, guards and the size measurement | 🚫 awaiting selection |
| 5 | **§7 — Issue 65**, deploy gate | 🚫 awaiting selection |
| 6 | **§8 — redeploy, verify, play** | after all of the above |

---

## 3. Repair the backend E2E suite

**What this means for the user:** nothing directly. It restores the only check that can tell whether the game's phase flow actually works.

### The gap

`npm --prefix functions test` reports **32 passing, 5 failing**. All five are in `functions/test/game_e2e.spec.ts`:

```text
1) should run a full 2-player game loop successfully
     AssertionError: expected 'truth' to equal 'forgery'
2) should advance phase when host submits first then bots simulate
3) should handle timeout and fill missing slots with placeholder
4) should handle submitUnmaskGuess E2E revenge guesses and scoring
5) should enforce duplicate-answer rejection in submitAnswer
     AssertionError: expected undefined to be a string
```

Failures 1–3 assert the **pre-Issue-61 phase order** — they expect `startGame` to yield `forgery`, and it now correctly yields `truth`. Failure 5 reads a field that Issue 62 deliberately blanked on the room card.

### Implementation

**Treat each failure as a question, not a chore.** For every one, decide explicitly which is wrong — the test or the code — and write the answer in the commit body. The whole reason a red suite is dangerous is that it hides the difference.

1. **Failures 1–3:** update the expected phase to `truth`, and update the transition sequence to **truth → forgery → vote → reveal**. Where a test drives a game forward, it must now write the truth *before* the forgery rounds; a test that submits forgeries first is asserting a flow that no longer exists.
2. **Failure 5:** `expected undefined to be a string` — the assertion reads an answer field from the room card. Since Issue 62, the truth and the forgery map live in `/rooms/{code}/sealed/{cardId}`, and the room card carries only `options`. Read the sealed document for author/truth assertions; read `options` for what a player can see. **Do not "fix" this by putting the answer back on the card** — that is the defect Issue 62 exists to prevent.
3. **Failure 4:** `submitUnmaskGuess` E2E. Diagnose before editing; it may be a knock-on of the reordering or of the option-id shape, and it is the one most likely to indicate a real defect rather than a stale expectation.

**Do not weaken an assertion to make it pass.** If a test cannot be made green without asserting less than it did, stop and file it — that is a signal about the code, not the test.

### Validation

- `npm --prefix functions test` returns **37/37** — the count the previous guide claimed. Any test you delete rather than repair must be justified in the commit body by name.
- **Over-reach guard:** the two suites that were already green stay green — `rules.spec.ts` (7) and `text_similarity.spec.ts`. If your edits changed shared fixtures, this is where it shows.
- **Add one assertion that would have caught this class:** a test asserting the full phase sequence from `startGame` through `gameOver` in order. Failures 1–3 were three separate tests each incidentally observing the phase; one explicit sequence test makes a future reorder fail loudly and once.

### Blast radius

`functions/test/game_e2e.spec.ts` only. **If you find yourself editing `functions/src/`, stop** — that means a test caught a real defect, and it should be filed, not silently fixed under a test-repair commit.

---

## 4. 🚫 Issue 63 — opaque answer-option ids (awaiting selection)

**What this means for the user:** anyone reading the stream the app already subscribes to can still see which answer is true and who wrote each forgery. Issue 62 was supposed to close this.

### The gap

Issue 62's structure is right — the sealed subcollection exists, the room card's `truthAnswer` and `sabotageAnswers` are blanked at the vote transition (`index.ts:990–991`), and the answers are genuinely shuffled (971–974). The ids give it away:

```ts
allAnswers.push({ id: `opt_truth_${card.targetPlayerId}`, … });  // index.ts:957
allAnswers.push({ id: `opt_${forgerId}`, … });                   // index.ts:964
```

Those ids go into the room document's `options` array at line 979. The `opt_truth_` prefix names the truth; `opt_<forgerId>` names each forger. The shuffle is cosmetic.

### If Option A is selected — opaque random ids

Generate each option's id server-side as a random opaque token at the moment `options` is built, with no relationship to `targetPlayerId`, `forgerId`, or position. The mapping already has a home: `sealedData.answerAuthors` (id → authorId) and `sealedData.truthAnswerId` are written at `index.ts:983–984`, so the reveal and scoring paths read the sealed document and need no structural change.

**Two things to check while you are in there:** the id must be unique *within a card* only, and it must be generated once and persisted — regenerating on a later write would invalidate votes already cast against it.

### Validation (whichever option is selected)

- **The falsifying assertion:** in `game_e2e.spec.ts`, play to the vote phase, read the room document as a client would, and assert that **no option id contains any player's id and none matches `/truth/i`**. Assert it over every option on every card, not just the first. **Falsifying today:** ids literally contain both.
- **Over-reach guard:** the reveal still attributes every forgery to the right author and scores the game correctly. The id is the join key between the readable list and the sealed mapping; if it broke, scoring silently misattributes.
- **A vote cast before the reveal still resolves to the right author** — this is the assertion that catches an id regenerated between phases.

### Blast radius

`functions/src/index.ts` · `functions/test/game_e2e.spec.ts` · `lib/models/card_model.dart` and the vote/reveal screens **only if** they assume the id format — grep for `opt_` before assuming they do not.

---

## 5. 🚫 Issue 64 — finish the server-side re-roll (awaiting selection)

**What this means for the user:** the re-roll button stays enabled after the first use, the second tap is rejected by the server, and they are shown *"Something went wrong. Try again."* — the generic fallback firing for a state the UI itself invited.

### The gap

Issue 61's amendment was implemented on the client only.

- **Client** (`phase2_craft.dart:483`) — `canReroll = isTruthPhase && !isTimerLast5Sec && !_isSubmitting`. Correct: unlimited, truth-phase-gated.
- **Server** (`index.ts:675`) — still throws `"Prompt already re-rolled once this game."`; line 694 still writes `hasRerolled: true`; and there is still **no phase guard**, so `rerollPrompt` remains callable during forgery.
- `hasRerolled` still exists on `PlayerState` (`lib/models/player_state.dart:28`).

### If Option A is selected — finish the server side

1. Remove the `hasRerolled` check (`index.ts:675`) and its write (694).
2. Add a phase guard: reject unless `room.currentPhase === "truth"`, with a `failed-precondition` and a message a developer can act on.
3. Remove `hasRerolled` from `PlayerState` and from every write in `functions/src/index.ts` — it appears at five sites; a partial removal will resurrect the field.
4. **Leave `'hasRerolled'` in the `firestore.rules` denylist.** Denying writes to a field that no longer exists is a harmless no-op, and removing it is a rules change with no upside.

### Validation

- **Unlimited:** call `rerollPrompt` three times in the truth phase; all three succeed and the prompt changes each time. **Falsifying today:** the second call throws.
- **Phase-gated:** calling it during forgery is rejected. **Falsifying today:** it succeeds.
- **Deck exhaustion is now reachable** — two decks ship only 12 prompts. Re-roll past the end on `cah_dark_humor` and assert the client shows exactly `No more prompts left in this deck.` (already implemented at `phase2_craft.dart:514`) and **not** the generic fallback. This path exists but has never been executed.
- **Over-reach guard:** a single re-roll still works, and the re-roll control is absent during forgery.

### Blast radius

`functions/src/index.ts` · `lib/models/player_state.dart` · `functions/test/game_e2e.spec.ts` · `docs/design_database_and_security.md` §2 already reads *"unlimited re-rolls allowed during the `truth` phase"* — it will be true once this lands.

---

## 6. 🚫 Issue 66 — guards that cannot fail, and the size measurement (awaiting selection)

Three findings sharing one cause: a check that reads as evidence and is not.

1. **The release size came from the wrong artefact.** Recorded as *"Re-measured via `flutter build web --release` (50 MB)"*. The gate is `flutter build ios --release --no-codesign`, measuring `Runner.app`. A web bundle and an iOS app share no packaging. **The iOS figure is still the inherited 49.5 MB from `56c183a` and remains unverified.**
2. **The contrast guard cannot fail for its target regression.** `test/contrast_tokens_test.dart` asserts correct ratios for correct token pairs, which pass because the palette is fine. Nothing asserts the screens *use* those tokens, so reverting `phase4_reveal.dart` to `theme.colorScheme.onSurface` leaves it green. **This is the spec's fault, not the implementer's** — the previous guide asked for exactly that table.
3. **The `depart` ink floor is 30 px**, where the spec asked for half the measured value. Weak, not wrong: it still catches an empty painter.

### If Option A is selected

Re-run `flutter build ios --release --no-codesign`, record `Runner.app`'s real size, and replace every inherited figure. Then make both guards assert what they claim: render the widget under test to a bitmap (the machinery already exists in `test/thematic_icon_test.dart`), sample the text pixels against the background pixels, and assert the measured ratio — which catches a token regression *and* a colour hardcoded in a widget. Raise the ink floor to half its measured value and put the measurement in a comment beside the constant.

### Validation

- **Observe each guard fail.** Temporarily revert `phase4_reveal.dart` to `colorScheme.onSurface`, confirm the contrast guard goes red, restore. Do the same for the ink floor with an emptied painter. **Record both failing outputs** — that is the entire point of this item.
- The iOS size is a measured number with its delta against 49.5 MB recorded, not an estimate.

### Blast radius

`test/contrast_tokens_test.dart` · `test/thematic_icon_test.dart` · this guide's §1 · `ongoing_general_errors.md`.

---

## 7. 🚫 Issue 65 — stop a red suite from deploying (awaiting selection)

The suite was red and production shipped anyway: functions updated `2026-08-10T17:53 UTC`, commit `b57e5c1` timestamped `17:51 UTC`. Two minutes.

Repairing the tests is §3 and needs no decision. **What needs a decision is whether anything should prevent a recurrence** — a `predeploy` hook, a documented checklist, or CI. The options and their costs are in `ongoing_general_errors.md` Issue 65. If Option A is selected, the mechanism already exists: `firebase.json` carries a `predeploy` array, added under Issue 55 for this exact class of problem.

---

## 8. Redeploy, verify, and play

§4 and §5 change Cloud Functions. **Nothing reaches a player until deployed**, and no gate in the battery can see a deployment.

Deploy and verify per **`design_database_and_security.md` §8** — all 14 timestamps move, the deployed bundle contains a token unique to your change, and the deployed ruleset is read back. **Do not skip the artefact check.**

Then re-run the three-simulator playthrough. The last one found five defects in a single sitting; this one has more surface to cover, because the phase order changed. Assertions still unconfirmed on a real device:

1. **The truth phase comes first** — every player answers their own prompt before any lie is written, and the re-roll is available and repeatable there.
2. Host leaves a lobby → both non-hosts see exactly **"The host has left. This room has closed."**
3. A non-host leaves → the room survives.
4. A non-host swipes the deck carousel through all 7 cards → the host's selection does not change.
5. A newly created production room carries `expiresAt` ~8 h ahead on **both** the room and host player document.
6. The reveal is readable — prompt and answers — at 360×640 dp.
7. No overflow stripe anywhere, including the `REVENGE UNMASKING!` header.
8. A full game completes end to end with three human clients.

**Anything that fails is a new issue filed with options**, not an inline fix.

---

## 9. Already delivered — do NOT rework

Verified in source this session:

- **Issue 58's colour fix** — 12 `AppColors.ivory` usages in the reveal; the dark-surface text is correct. (Its *guard* is Issue 66.)
- **Issue 59** — the unmask tray is stream-driven, and `e.toString()` is used only to classify errors, never displayed. `phase2_craft.dart:98` and `:514` and `phase4_reveal.dart:829` are all correct implementations of this pattern; **do not "clean them up"**.
- **Issue 60** — both `Expanded` wrappers present in the reveal header.
- **Issue 61's phase reorder** — `startGame` opens in `truth` (`index.ts:395`); the client re-roll gate is truth-phase and unlimited. (Its server half is Issue 64.)
- **Issue 62's structure** — sealed subcollection, blanked card fields, shuffled answers. (Its ids are Issue 63.)
- **Issues 50–57** — leave control, lobby close, read-only carousel, TTL, deploy, backfill, `depart` sigil. `depart` is a bespoke sigil; all 11 font-backed glyphs audited and correct.
- **Issue 31** — the server uses loose `!= null`; **never "simplify" to a falsy check**.
- **Issues 28/29** — `phosphor_flutter` can never be used; the app vendors the Phosphor Light font.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` · Firebase project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 10. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the output.

**A check that cannot fail is not a check.** Seven instances now: the cmap presence script, `find.byType(IconButton).last`, a bare `find.byType(FadeTransition)`, a "file is non-empty" contrast test, `find.byType(CustomPaint)` as proof something was drawn, the token-pair contrast table (§6), and a 30-pixel ink floor. **Before trusting a check, ask what input would turn it red.**

**Check which artefact a measurement describes.** `flutter build web` succeeded and produced a number that was recorded as the iOS app size.

**A red suite is not a chore, it is a blindfold.** Five failing E2E tests meant nobody could distinguish a stale assertion from a real defect in a phase flow that had just been rewritten — and it shipped in that state.

**"Resolved" is not "deployed", and "deployed" is not "verified".**

**Measure; do not estimate**, and **do not tune a threshold or weaken an assertion to make a test pass** — report the number and say the guard failed.

**Pair every fix assertion with an over-reach guard.**

---

## 11. Accepted equivalents — do NOT "fix" back

- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **The non-host carousel is interactive-but-inert, not dimmed.**
- **`pumpAndSettle()` and `pump()` + `pump(500ms)` are both acceptable** once `accessibleNavigation: true` is set.
- **The leave dialog uses `showGeneralDialog`, not `showDialog`.**
- **`e.toString()` used to classify an error and select fixed copy is correct**, and is the intended pattern — the ban is on displaying it.
- **`_ThematicIconPainter` carries unreachable fallback cases for font-backed types.** Do not delete or wire them up.
- **`isSmallHeight` uses a `< 700` dp breakpoint** with a 6/8/12/16/20 spacing scale.

---

## 12. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; `firestore.rules` denies client room writes. **Room reads stay open** — Issue 62/63 fix what is written, not who may read.
- **The answer key lives in `/rooms/{code}/sealed/{cardId}` with no client rule.** Default-deny is what protects it; **do not add an explicit `allow read: if false`**, which invites someone to "fix" it later.
- **Phase order is truth → forgery → vote → reveal.**
- **Portrait-locked**; **text scale clamped 1.0–1.3**.
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically across `text_similarity.ts` ↔ `text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive stream rebuilds — **never remove them.**
- **`ROOM_TTL_MS` is 8 hours.** Below ~4 hours a `touchRoom` keepalive becomes mandatory (`ongoing_general_errors.md` Issue 53).
- **`firebase.json`'s `predeploy` hook stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C, Issue 57 Options B/C, and the rejected options on Issues 58–62.

---

## 13. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Backend writes, rules, identity, TTL, **deploy & verification §8** | `design_database_and_security.md` |
| Card passing, disconnect recalculation, assignment timing | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, `onSurface` semantics, icons, mascot | `design_ui_direction.md` |
| Phase order and data models | `design_game_state_and_models.md` |
| PNG decoding + WCAG contrast helper (reuse, do not rewrite) | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 14. Feedback loop — what past specs got wrong

- **A spec can manufacture a useless guard.** The previous guide asked for a contrast test over *token pairs*. It was implemented exactly as written and cannot fail for the regression it exists to prevent. **When specifying a guard, state the regression it must catch and require the author to observe it catching that regression.**
- **A summary is not a verification.** The previous guide opened with "Queue Complete — All Tasks Delivered, Tested & Deployed" and "37/37" while the backend suite was red with five failures. **Re-run the battery before writing a completion claim; paste the output.**
- **A build that succeeds is not the build you needed.** `flutter build web --release` compiled cleanly and its number was recorded as the iOS app size.
- **Implementing half a contract is worse than none.** Issue 64's client now offers unlimited re-rolls the server rejects, so the UI invites an action that produces an error. **When a change spans client and server, land both or neither.**
- **Redaction defeated by naming.** Issue 62 blanked the fields and left `opt_truth_…` and `opt_<forgerId>` in the ids. **When hiding data, enumerate every channel it can travel — field names, ids, ordering, array length, timing.**
- **One playthrough found five defects that 157 automated tests could not.** The manual pass is a gate, not a nicety.
- **"Resolved" is not "deployed."** And a deploy two minutes after a commit, over a red suite, is not a deploy anyone verified.
- **Doc structure rots silently.** The Resolved section has been split by duplicate headings three times. **Append inside the existing heading; never add a second.**

---

## THE LOOP

```
(1) STUDY the item here + the options in ongoing_general_errors.md + the exact files
    at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Copy strings verbatim; paste, do not retype.
(3) VALIDATE per §10. Observe the falsifying assertion fail first, and record it.
    Run the over-reach guard. Decode the artefact rather than assuming you cannot.
    Then the full §1 battery — including the BACKEND suite.
(4) BEFORE COMMITTING, re-read this guide's open list for the item you are finishing,
    and re-run the battery. Do not write a completion claim from memory.
(5) BLOCKED, or found something needing human judgement? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
(6) RECORD: move the item to Resolved inside the SINGLE existing Resolved heading,
    with its observed falsifying output. Sync any design doc whose behaviour changed.
(7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **§3** — `npm --prefix functions test` returns **37/37**; each of the five failures resolved with an explicit written judgement of whether the test or the code was wrong; no assertion weakened; a phase-sequence test added; `rules.spec.ts` and `text_similarity.spec.ts` still green.
- [ ] 🚫 **§4 (Issue 63)** — not started, or done per the selected option, with the falsifying assertion (no option id contains a player id or matches `/truth/i`) **observed failing first**.
- [ ] 🚫 **§5 (Issue 64)** — not started, or done per the selected option; three consecutive re-rolls succeed in `truth`; a re-roll during `forgery` is rejected; deck exhaustion shows the specific copy, not the fallback.
- [ ] 🚫 **§6 (Issue 66)** — not started, or done per the selected option; **both guards observed failing** against a deliberately reverted state; iOS `Runner.app` measured with `flutter build ios --release --no-codesign` and the delta against 49.5 MB recorded.
- [ ] 🚫 **§7 (Issue 65)** — not started, or done per the selected option.
- [ ] **§8** — deployed and verified by artefact inspection; playthrough re-run with all eight assertions recorded per device; anything surfaced filed as a **new issue with options**.
- [ ] Full battery, all four gates, **pasted into the commit body** rather than summarised: `flutter analyze lib test` 0 errors · `flutter test` ≥ 124 · functions build clean · `npm --prefix functions test` **37/37 or better**.
- [ ] Issues 63–66 moved to Resolved **inside the single existing Resolved heading**, each with its observed falsifying output.
- [ ] **Guide rewritten** — body and title together — to `Queue Complete` or the next queue. **A completion claim must quote measured output.** The previous one did not, and was wrong.
