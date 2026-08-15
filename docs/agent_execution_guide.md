# Agent Execution Guide — Awaiting one selection (Issue 83); H1 is unblocked — August 15, 2026

**You are an engineering agent with no memory of this project.**

**What is done, and independently verified this session in source and against the live project — not from commit messages:**

- **Issues 78 and 79** — the `'TRUTH'` sentinel is gone from all nine readers; the card target cannot be accused of forgery. Falsifying tests at two inputs, mirrored client and server.
- **Issues 77 and 81** — all **14** functions deployed `2026-08-14T17:47:40Z`–`17:48:24Z`, rules ruleset `04:24:13Z`. `scripts/check_deploy_fresh.sh` exists and works: **all three exit codes were exercised**, not assumed (§1).
- **Issue 80** — a correct revenge accusation now reports `SUCCESS! (+1)` with the guesser's `+1` visible in standings.
- **Issue 82** — the fabrication is genuinely gone. All **16** prompt quotes in A3 check out mechanically against source (0 missing, against 18/18 missing on August 13), and **`The host has left. This room has closed.` was observed for the first time in nine cycles.**

**Do not rework any of it** (§6).

**What is open:**

| Item | Issue | Blocked? |
|---|---|---|
| **H1** — two objective corrections to the findings report | 83 | **No. Do this now.** |
| **R1** — reconcile A4's exhaustion count and A12's worked example | 83 | **Yes — needs a `Your selection:` line.** Three options, three different amounts of work. |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body.
- **Every quoted game string in any report must be findable in source with `grep -F`.** If it cannot be, you did not observe it — record **NOT RUN**.
- **Any count-dependent assertion must state the count, the deck, and the deck's size.** This is new, and it is the whole of Issue 83.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §6 or §7.**

---

## 1. Verified baseline — the regression bar

Measured **August 15, 2026** at `6cc6d69`, clean tree. This session's numbers.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (222 issues) |
| `flutter test` | **130/130** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **46/46** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — 14/14 functions and rules exceed the tree |
| **The playthrough** | 🟡 12 sound · 2 unreconciled (A4, A12) · 1 NOT RUN (A14) |

**The deploy check is now a tool, not an instruction.** Run it as the fifth gate every pass:

```bash
./scripts/check_deploy_fresh.sh
```

Its contract — three exit codes, epoch-second comparison, function-count check, and the Rules API's mandatory `x-goog-user-project` header — is recorded in `design_database_and_security.md` §8. **Exit 2 means "could not verify" and must never be reported as a pass.** Verified this session: exit **0** at `6cc6d69`; exit **1** on a throwaway `functions/src` commit, naming all 14 functions with per-function lag; exit **2** via `GCLOUD_BIN_OVERRIDE=/nonexistent/gcloud`.

### ⚠️ Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`** — separate commands. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts, not guesses.** `cah_dark_humor` holds **12**; `the_daily_grind` holds **20**. Count them before quoting a re-roll total:

```bash
awk "/'the_daily_grind': \[/,/^    \],/" lib/utils/prompt_decks.dart | grep -cE '^\s+"'
```

15. **`git` and Google timestamps must never be string-compared** — `git` emits local offsets, Google emits Zulu with nanoseconds, and lexicographic order disagrees with chronological order. This is measured on real values, not hypothetical. See `design_database_and_security.md` §8.

---

## 2. What is blocked, and what is not

**H1 needs no selection.** Both items are objective corrections with a single right answer. Do them now, as one commit.

**R1 is blocked on Issue 83.** The three options differ by more than effort — Option C changes *where* the assertion lives, from a manual playthrough to the emulator suite. **Do not pick for the user, and do not start the Marionette setup on the assumption of A or B.**

If the selection line is still blank after H1: stop, say so, and leave the run there.

---

## 3. H1 — Two corrections to the findings report *(unblocked)*

**What this means for the user:** the report is what the next agent reads as proof. One of its artefacts is the exact thing that hid a production gap for two cycles, and nothing in it says which half of it is fresh.

### H1.1 — Delete the timestamp-free function table

`docs/playthrough_findings_marionette.md` lines ~17–38 carry a `firebase functions:list` box drawing showing **Function · Version · Trigger · Location · Memory · Runtime**. **There is not a timestamp in it.** This is the artefact that let Issue 77 and then Issue 81 through — it looks like deploy evidence and cannot answer the question.

Replace the whole block with real output:

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,updateTime)"
```

Keep the existing header line that already records the script's exit 0 and the deploy window — it is correct; it is just sitting above a table that contradicts its usefulness.

### H1.2 — State the report's provenance

The report mixes blocks re-run on August 14 with blocks carried forward from August 13, and nothing says which is which. Add to the header, immediately after **Deliberate Deviations**:

```markdown
- **Provenance:** A3, A4, A9, A10, A13 were re-run on August 14, 2026 against the deployed build at `a428201`. A1, A2, A5, A6, A7, A8, A11 are carried forward unchanged from the August 13 run — see Issue 82 for why the August 13 pass was audited. A12 was corrected in place without a re-run. A14 has never been run.
```

**Also record the deck substitution as a deviation.** The spec named `cah_dark_humor`; A3 was run on `the_daily_grind`. That may be entirely reasonable, but an unrecorded substitution is what makes A4 unreadable (Issue 83):

```markdown
- A3/A4 were run on `the_daily_grind` (20 prompts) rather than the specified `cah_dark_humor` (12 prompts).
```

### Validation

`grep -c "firebase functions:list" docs/playthrough_findings_marionette.md` returns **0**. The header contains a `Provenance:` line naming all fourteen assertions across its categories. No assertion block's verdict changes — **H1 corrects the record about the run, not the run.**

Commit: `docs(playthrough): replace non-evidential deploy table and record provenance`.

---

## 4. R1 — Reconcile A4 and A12 *(blocked on Issue 83)*

**What this means for the user:** A4 is the assertion that says "the game tells you when a deck runs out instead of silently misbehaving." Right now nobody can tell whether it passed, because the numbers do not add up.

### The gap

A3 records **16** re-rolls on `the_daily_grind`, which holds **20** prompts. A player's own card consumes one at deal, leaving **19** possible re-rolls. A4 then reports reaching `No more prompts left in this deck.` — three short. Three readings fit, and the report distinguishes none of them: more rolls happened than were listed; exhaustion fired early (**a real defect in `drawOneExcluding` / `seenPrompts`, the machinery Issue 67 rebuilt**); or A4 ran on a different deck than A3.

Separately, A12 states *"Alpha voted truth (+1), Bravo fooled Alpha (+1)"* — **the same choice, described two ways.** A13 independently says Alpha was fooled by Bravo, so the "voted truth" clause is the wrong half. The published standings do not follow from the listed deltas under any reading.

### Implementation — Option A: re-run A3+A4 as one sequence, re-derive A12

Marionette is installed and working (`marionette_flutter: ^0.6.0`, binding in `lib/main.dart`, three servers in `.agents/mcp_config.json`, keys from `f3a5a1d`). **A3/A4 need one device only** — the host in a lobby. Do not stand up three unless you are also redoing A13.

- `.env` must contain `USE_EMULATOR=false`; it is a bundled asset, so changing it needs a rebuild.
- Debug build. `flutter run -d <UDID> --debug`, then convert the printed VM service URI to `ws://…/ws`.
- Leave **`Family-Friendly Decks Only` off** (`lobby_screen.dart:643`). Turn **`Disable Game Timers` on** (`lobby_screen.dart:623`) and record it.
- **Pick one deck and name it.** If you use `cah_dark_humor`, `tap(key: 'deck_cah_dark_humor')` — 12 prompts, the shortest run.
- **Count the deck first**, with trap 14's command, and put the number in the report before you start rolling.
- Re-roll **without stopping** until the exhaustion message appears, recording every prompt in order. **The number of distinct prompts before the message must equal the deck size minus the one consumed at deal.** State that arithmetic explicitly in the block.
- `grep -cF` every prompt against `lib/utils/prompt_decks.dart`, and paste the commands and outputs.

**PASS for A4** requires the exact string `No more prompts left in this deck.` (`phase2_craft.dart:507`) **on the roll immediately after the last distinct prompt** — and the count reconciling. **If the message appears early, that is a defect: stop, do not retry, and file it** with the deck, its size, the ordered prompt list, and the roll index where the message appeared.

**A12 needs no new session.** Re-read A13's recorded card — Alpha fooled by Bravo's forgery on Charlie's card — and write the deltas that actually follow from `ScoringLogic`: the truth reward `ceil((P − 1) / (S + 1))` to whoever found the truth, `+1` to the card target per truth-finder, `+1` to the forger per fooled voter, `+1`/`−1` on a correct unmask. **If the published standings still do not follow, mark A12 NOT RUN** rather than reverse-engineering an explanation.

### Implementation — Option B: correct the record, re-verify later

Rewrite A4 and A12 as **NOT RUN**, each stating exactly what was recorded and why it is not evidence — A4: the count does not reconcile with any deck the report names; A12: the two clauses describe the same choice. Add both to the next playthrough's assertion list. No simulator run. **Do not soften them to PASS with a caveat** — a caveat is not a verdict.

### Implementation — Option C: close A4 in the emulator suite instead

Add a test to `functions/test/game_e2e.spec.ts` that, for a named deck of known size `n`:
- calls `rerollPrompt` exactly `n − 1` times, asserting each returns a prompt **not previously seen** and that the set of returned prompts has size `n − 1`;
- asserts call `n` throws **`resource-exhausted`** — match on the **code**, never the message (trap 12);
- asserts a *different* player on the same room is unaffected, since `seenPrompts` is per-sealed-document, not global. **This is the over-reach guard**: a fix that exhausted the deck globally would otherwise pass.

**The falsifying observation:** run the boundary case at two different deck sizes — `cah_dark_humor` (12) and `the_daily_grind` (20). A test hard-coded to one size cannot distinguish "exhausts at `n`" from "exhausts at 12".

**Option C does not cover the client SnackBar**, which is half of what A4 exists to check. Record that limitation in the report and leave the UI half queued.

### Validation (all options)

Battery at or above §1, **including `./scripts/check_deploy_fresh.sh` exit 0**. Under Option C, `npm --prefix functions test` rises above **46**.

Commit: `docs(playthrough): reconcile deck exhaustion count and scoring example` — or, under Option C, `test(functions): assert deck exhaustion at the boundary for two deck sizes`.

---

## 5. Do not invent work · escalation

Outside H1 and R1 there is no queue. Legitimate triggers: a defect R1 surfaces, a user-selected issue, or a §7 trigger firing (the TTL interval dropping below ~4 hours, or a sibling glyph turning out wrong).

**Bounded deviation:** if an exact value or step is impossible, keep the intent, deviate minimally, note it in the commit body — **and if you substitute a deck, a device, or a fixture, record the substitution.** An unrecorded substitution is the direct cause of Issue 83.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel (Issue 78 Option B, declined), **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** fall back to `DEBUG: ADD 9 BOTS`, and **do not** reconstruct an observation you did not capture.

---

## 6. Already delivered — do NOT rework

**Verified in source and against the live project, August 15, 2026, at `6cc6d69`:**

- **Issue 78** — nine readers resolve truth votes as `votedForId == card.targetPlayerId` (`scoring_logic.ts:54`, `scoring_logic.dart:25`, `phase4_reveal.dart:105/250/265/359/554/764`, `index.ts:1566`); dead disjunct at `index.ts:1378` removed; dead `_generateShuffledAnswers` path deleted. Tests at two inputs — `P=4,S=1 → 2` (`game_e2e.spec.ts:1684`) and `P=5,S=3 → 1` (`:1793`) — each with an over-reach guard, mirrored in `test/scoring_logic_test.dart`. The acceptance grep returns only `phase2_craft.dart:161`, a UI label.
- **Issue 79** — target excluded client-side (`phase4_reveal.dart:694`), rejected server-side with `invalid-argument` (`index.ts:1394`, message at `:1397`), both carrying the paired-guard comment. Test at `game_e2e.spec.ts:1805`.
- **Issues 77 / 81** — 14/14 functions deployed; rules released `04:24:13Z`; `scripts/check_deploy_fresh.sh` in the battery with all three exit codes exercised. **Do not re-deploy history; run the script.**
- **Issue 80** — `'SUCCESS! (+1)'` (`phase4_reveal.dart:421`) observed with standings `0 → 1`.
- **Issue 82** — A3's 16 quotes all verified in source; A9/A10 exercise the real mid-session leave flow with every citation resolving (`lobby_screen.dart:78/83/84/94/109/369`).
- **Issue 76** — `submitAnswer` validates against `room.currentCardAssignments?.[authorId]`.
- **Issue 72** — default `Math.min(activePlayers.length - 1, 5)` from the live count; `updateLobbySettings` rejects out-of-range; the 3-player floor is its own guard.
- **Issue 71** — `castVote` resolves option ids via `sealedData.answerAuthors`. **This is the change that created Issue 78** — correct, but its readers were not enumerated.
- **Issues 50–75** as previously recorded. **Issue 31** — the server uses loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 7. Accepted equivalents & invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`. Contract: `design_game_state_and_models.md` §2. **Redefined twice, broke its readers both times — if you change it again, enumerate every reader in both languages.**
- **Who may accuse and who may be accused are two separate bounds**, enforced in two places by design (`design_scoring_and_ui.md`). Change both or neither.
- **The deploy gate's three exit codes are a contract** (`design_database_and_security.md` §8). Collapsing exit 2 into 0 defeats the entire mechanism.
- **`scoring_logic.{ts,dart}` must stay semantically identical**, as `text_similarity` must stay byte-identical.
- **Issue 76 validates rather than re-derives** — same guarantee, different structure. Leave it.
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null. **The leave dialog uses `showGeneralDialog`.**
- **The non-host carousel is interactive-but-inert, not dimmed.**
- **`lastReaction` / `lastReactionAt` stay on `PlayerState` and in the rules deliberately** (Issue 74).
- **Sealed documents are created lazily**, not at `startGame`. **`seenPrompts` is per-sealed-document, not global** — R1 Option C's over-reach guard depends on this.
- **`_ThematicIconPainter` carries unreachable fallback cases** — do not wire them up.
- **Server-authoritative**; room reads stay open; `/rooms/{code}/sealed/{cardId}` is default-deny. **Never add an explicit `allow read: if false`.**
- **Option ids are opaque UUIDs**, resolved server-side. **Never send authorship to the client.**
- **Phase order is truth → forgery → vote → reveal.** **Minimum 3 active players**, its own guard.
- **Forgeries per card: hard ceiling `n − 1`; `5` is a default, not a cap.** **Re-rolls unlimited during `truth`, rejected elsewhere, never repeating.**
- **`ROOM_TTL_MS` is 8 hours**; below ~4 h a host-only `touchRoom` keepalive plus a client timer become mandatory.
- **`firebase.json`'s `predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, Issue 34 C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, Issue 78 B/C, Issue 79 B, Issue 81 B/C, Issue 82 B/C, and the rejected options on 58–66.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| **`votes` contract, card/player/game schemas, phase order** | `design_game_state_and_models.md` |
| **Scoring formulas, reveal beats, unmask bounds** | `design_scoring_and_ui.md` |
| **Deploy, and the freshness gate's contract (§8)** | `design_database_and_security.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| Palette, typography, icons, mascot | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 9. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the output.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every game string you quote.

**Traceable quotes do not make a report arithmetically sound.** Check the counts separately — that is Issue 83, and it is what survived fixing the fabrication.

**A check that cannot run must say so, not pass.** The gate's exit 2 exists for this and nothing else.

**Assert a derived value at two different inputs** — one value cannot pass both.

**A clamp is not a rejection. A client-only bound is not a bound.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard.**

**A driven playthrough is not a played one.** It can check every literal string and still miss pacing, confusion, and whether the game is fun.

---

## 10. Feedback loop — what past specs got wrong

- **Fixing a class of defect promotes the next one.** August 13's report invented quotes; August 14's quotes are all genuine and the *arithmetic between them* is what fails. Traceability catches invention and cannot catch a count that does not add up. **Each fix should assume the next failure is one level up.**
- **An unrecorded substitution destroys an assertion downstream.** The spec named a 12-prompt deck; the run used a 20-prompt deck and said nothing. A3 survives that (its quotes are real); **A4 does not, because A4's whole content is a count.**
- **When a written step fails twice, replace it with a tool.** `firebase functions:list` was pasted as deploy evidence in two consecutive cycles. `check_deploy_fresh.sh` ended it — and it only works because exit 2 is distinct from exit 0.
- **A gate that has never failed has not been tested.** All three exit codes were exercised deliberately, including on a throwaway commit engineered to be stale. Do the same for any gate you add.
- **Two correct timestamps can still compare wrong.** Normalise units before comparing — a 774-second-stale deploy read as fresh under string comparison.
- **When you redefine what a field holds, enumerate its readers.** `votes` has done this twice.
- **One item = one commit.** Issues 71–76 landed as one; five were real, one untouched, and the batch read as complete.
- **The manual gate earns its keep every time it runs** — two playthroughs, eleven defects, none visible to four green gates. **And a fabricated gate costs more than no gate**, because it retires the suspicion that would have found them.
- **Doc structure rots silently.** Append inside the existing Resolved heading; never add a second.

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §9, including the over-reach guard.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading;
    playthrough observations go to docs/playthrough_findings_marionette.md.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **H1.1** — the `firebase functions:list` table is gone from the findings report; `grep -c "firebase functions:list"` returns **0**; real `updateTime` output is in its place.
- [ ] **H1.2** — the header carries a `Provenance:` line covering all fourteen assertions, and the `the_daily_grind` / `cah_dark_humor` substitution is recorded as a deviation.
- [ ] **Issue 83 selection recorded** before R1 begins.
- [ ] **R1** — per the selection. Under **A**, A4 states the deck, its size, the ordered prompt list, and the reconciling arithmetic, with `grep -cF` output per prompt; under **B**, A4 and A12 read NOT RUN with reasons and are queued; under **C**, the exhaustion boundary is asserted at **two** deck sizes with the per-player over-reach guard, and the client SnackBar gap is recorded.
- [ ] **A12 either re-derived from A13's card or marked NOT RUN** — not softened to PASS with a caveat.
- [ ] Battery at or above §1: **0 errors** · **≥130** · clean build · **≥46** · **deploy gate exit 0**.
- [ ] **If the exhaustion message fires early under Option A: STOP and file it.** That is a real defect in machinery Issue 67 rebuilt, and it is not fixed inline.
