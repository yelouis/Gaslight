# Agent Execution Guide — Awaiting one selection (Issue 88); T0 is unblocked — August 16, 2026

**You are an engineering agent with no memory of this project.**

**What is done, and independently verified this session in source and against the live project — not from commit messages.** Issues 1–87 are delivered and deployed. The August 15 wave (S0–S7) shipped all five selected items, and — unusually for this project — **every over-reach guard the spec demanded is genuinely present rather than merely titled** (§6).

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (222 issues) |
| `flutter test` | **137/137** ✅ (was 130) |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **53/53** ✅ (was 46) |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — oldest deployed `castVote` `2026-08-16T01:38:36Z`, after the last `functions/src` commit |

**What is open.** The code is right; **two assertions the S-build specced were not delivered**, and one of them left a dangling promise in the evidence record.

| Item | Issue | Blocked? |
|---|---|---|
| **T0** — repoint A4's stale forward reference | 88.1 | **No. Do this now** — every option requires the record to stop overstating. |
| **T1** — the timers-disabled regression guard | 88.2 | **Yes** — needed under Options A and B, skipped under C. |
| **T2** — verify the exhaustion SnackBar on a device | 88.1 | **Yes** — Option B only. |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body.
- **Every quoted game string in any report must be findable in source with `grep -F`**; any count-dependent assertion must state the count, the deck, and the deck's size.
- **When you renumber an assertion list, grep for inbound references and repoint them in the same pass.** T0 exists because this was not done.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §6 or §7.**

---

## 1. Verified baseline

The table above is the regression bar, measured **August 16, 2026** at `3eb9595`, clean tree. **Run `./scripts/check_deploy_fresh.sh` as the fifth gate every pass** — its contract (three exit codes, epoch-second comparison, function-count check, the Rules API's mandatory `x-goog-user-project` header) is in `design_database_and_security.md` §8. **Exit 2 means "could not verify" and must never be reported as a pass.**

### ⚠️ Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`. **T1 needs this.**
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.** See `design_database_and_security.md` §8.
16. **A spec can demand something the app cannot do**, and the agent will test the nearest reachable thing and report PASS. Before asserting against a control, grep that the control exists.
17. **A cross-reference between assertions goes stale silently.** T0 is the live instance.

---

## 2. T0 — Repoint A4's dangling reference *(unblocked — do this first)*

**What this means for the user:** the evidence record currently promises that the deck-exhaustion UI was queued for verification, and points at a paragraph about players leaving mid-match. Anyone reading it concludes the gap is covered.

### The gap

`docs/playthrough_findings_marionette.md` records A4 as **NOT RUN via the UI**, states its gap honestly, and ends:

> *Queued for re-verification in S7 (Assertion A20).*

**A20 in the same document is "Mid-Game Departure & Auto-End Below 3 Players."** The S7 list was renumbered during the run and A4's pointer was never repointed. `grep -n "No more prompts left" docs/playthrough_findings_marionette.md` returns exactly **one** hit — A4's own *Expected* line — so the client-side exhaustion path is unverified at every level while the document reads as though it is queued.

### Implementation

Edit A4's **Gap** line. Remove the `(Assertion A20)` pointer and replace it with a statement that survives renumbering:

```markdown
- **Gap:** Option C verifies the exhaustion boundary and per-player sealed-document isolation in the emulator suite (`cah_dark_humor` @ 12 prompts, `the_daily_grind` @ 20 prompts), but **the client SnackBar path at `phase2_craft.dart:507` is covered by no test at any level and has not been observed since August 13.** Tracked as Issue 88.1 — not queued to any assertion number in this document.
```

**Do not change A4's verdict**, and do not renumber A20. The record of what was run is correct; only the forward reference is wrong.

### Validation

`grep -n "Assertion A20" docs/playthrough_findings_marionette.md` returns **0** hits. A4's Gap line names Issue 88.1 and states plainly that the path is unverified. No verdict changes anywhere in the document.

Commit: `docs(playthrough): repoint A4's stale reference to Issue 88.1`.

---

## 3. T1 — The timers-disabled regression guard *(Options A and B)*

**What this means for the user:** the leave control was put in the app bar's `leading` slot precisely because `actions` empties out when timers are disabled. Nothing tests the state that motivated the design.

### The gap

The S5 spec required widget tests asserting the leave control renders on all three phase screens **including when `isTimerDisabled` is true**. `test/in_game_leave_test.dart` has three `testWidgets` cases and **no reference to `isTimerDisabled` at all**. A18 in the findings report claims *"Visible across all players regardless of timer configuration"* — its only recorded observation is a single bounds rectangle on `/craft`, with nothing showing the timer-disabled state.

**The risk is low and the gap is still real.** `leading` and `actions` are independent slots, so the control cannot vanish with the timer — which is why this is a missing regression guard, not a suspected bug. It becomes a real risk the moment someone refactors an app bar.

### Implementation

Extend `test/in_game_leave_test.dart`. For each of the three screens — `Phase2CraftScreen`, `Phase3VoteScreen`, `Phase4RevealScreen` — add a case that pumps the screen with a `GameState` whose **`isTimerDisabled` is `true`**, and asserts:

1. the leave `IconButton` with `tooltip: 'Leave game'` **is present**; and
2. `AutoAdvanceTimer` is **absent** — this is what proves the fixture actually reached the timer-disabled branch. **Without it the test could pass against a fixture where timers are enabled**, verifying nothing.

Reuse the existing fixture-building helper in that file rather than writing a second one; the three existing cases already construct a `GameState`, so this is a parameter flip plus the two assertions. Set `accessibleNavigation: true` (trap 7).

### Validation

**The falsifying observation:** temporarily move the leave `IconButton` from `leading` into `actions` on `phase2_craft.dart` and confirm the new timer-disabled case **fails** while the existing enabled case still passes. That is the exact regression this guards, and a guard that has never failed has not been tested. **Revert the move.** Record both outcomes in the commit body.

Battery: `flutter test` **≥140**.

Commit: `test(game): assert the leave control survives timers being disabled`.

---

## 4. T2 — Verify the exhaustion SnackBar on a device *(Option B only)*

**What this means for the user:** when a deck runs dry the game should say so plainly rather than falling back to a generic error. The server behaviour is proven at two deck sizes; the sentence the player actually reads is proven nowhere.

### Implementation

**One device is enough — do not stand up three.** A3/A4 need only a host in a lobby.

- `.env` must contain `USE_EMULATOR=false`; it is a bundled asset, so a change needs a rebuild.
- Rebuild the client — `lib/` changed across S1, S3, S4 and S5.
- Debug build: `flutter run -d <UDID> --debug`, then convert the printed VM service URI to `ws://…/ws` for Marionette.
- Leave **`Family-Friendly Decks Only` off** (`lobby_screen.dart:643`); turn **`Disable Game Timers` on** (`lobby_screen.dart:623`) and record it as a deviation.
- **Use `cah_dark_humor` — 12 prompts, the short path.** `tap(key: 'deck_cah_dark_humor')`. State the deck and its size in the block before you start.

Re-roll continuously, recording every prompt in order. **The count of distinct prompts before the message must equal 11** — the deck's 12 minus the one consumed at deal. State that arithmetic explicitly. `grep -cF` every prompt against `lib/utils/prompt_decks.dart` and paste the commands and outputs.

**PASS requires the exact string `No more prompts left in this deck.`** (`phase2_craft.dart:507`) on the roll immediately after the last distinct prompt — **not** the generic fallback — and the count reconciling.

**If the message appears early, or the generic fallback appears instead: STOP and file it.** That is a real defect in the machinery Issue 67 rebuilt, and it is not fixed inline.

### Record

Rewrite A4 in place with a real verdict, the deck and its size, the ordered prompt list, the `grep -cF` output, and the reconciling arithmetic. Update the header's `Provenance:` line to cover this run.

Commit: `docs(playthrough): verify the deck exhaustion SnackBar on device`.

---

## 5. If Option C is selected

**Run nothing.** Do T0, then edit two places to record both gaps as accepted rather than pending:

1. **A4's Gap line** — state that the client SnackBar path is **deliberately uncovered**, that the server boundary is proven at two deck sizes, and that the accepted risk is the generic fallback appearing in place of the specific string.
2. **`test/in_game_leave_test.dart`** — a comment at the top of the group recording that the timer-disabled case is deliberately untested, and why (`leading` and `actions` are independent slots).

**Do not leave either reading as "queued."** The whole of Issue 88.1 is that a deferred item described as pending becomes invisible.

---

## 6. Already delivered — do NOT rework

**Verified in source and against the live project, August 16, 2026, at `3eb9595`:**

- **Issue 84** — `DialogThemeData` at `main.dart:86` (Flutter 3.44 requires that type, not `DialogTheme`); copy at `phase3_vote.dart:204`. `test/dialog_theme_contrast_test.dart` asserts **≥4.5:1** content **and ≥3.0:1** title, so a fix darkening only the body still fails.
- **Issue 83 (Option C)** — `game_e2e.spec.ts:1959` is parameterised over **both** deck sizes with the per-player isolation guard.
- **Issue 87** — one test covers host kick succeeding **and** a non-host kicking a third player being rejected. **That second half is the bound; never relax it.**
- **Issue 86** — `index.ts:264` filters `!p.isHost && p.lobbyReady !== true`. The test reads the host document and **asserts `lobbyReady` is not true before proving the start succeeds** — the deadlock guard is real.
- **Issue 85** — `index.ts:909` applies `phase !== "lobby" && activePlayerCount < 3` **after** the phase-specific branches so it wins; three tests cover the auto-end, the 4-player over-reach, and the lobby exemption. Leave control in `leading` on all three phase screens.
- **Issues 77–82** — sentinel purge, unmask bounds, deploy of all 14 functions and rules, and the freshness gate whose three exit codes were each exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 7. Invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId` (`design_game_state_and_models.md` §2). **Redefined twice, broke its readers both times.**
- **The readiness gate exempts the host deliberately.** The host has no ready toggle; requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`, never a falsy check. **Separate guard from the 3-player floor — do not merge them.**
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase-specific branches, and computes no scores (`design_game_state_and_models.md` §1).
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player must stay rejected with `permission-denied`** (`design_database_and_security.md` §4). **No separate kick or quit callable should ever be added.**
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`** — `surface` is parchment, and the global `textTheme` paints body copy ivory (`design_ui_direction.md` §6). The regression guard asserts a **ratio**, not a string.
- **Who may accuse and who may be accused are two separate bounds** (`design_scoring_and_ui.md`).
- **The deploy gate's three exit codes are a contract.** Collapsing exit 2 into 0 defeats the mechanism.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **Sealed documents are created lazily. `seenPrompts` is per-sealed-document, not global.**
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.** **Option ids are opaque UUIDs**; never send authorship to the client.
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`; 5 is a default, not a cap.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, and the rejected options on 58–66.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| **Phase order, 3-player floor (start *and* in play), readiness gate, `votes` contract** | `design_game_state_and_models.md` |
| Scoring formulas, reveal beats, unmask bounds | `design_scoring_and_ui.md` |
| **Deploy & the freshness gate (§8); `handleDisconnect`'s callers (§4)** | `design_database_and_security.md` |
| **Dialog surface & contrast rule (§6)** | `design_ui_direction.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |
| **PNG decoding + WCAG contrast helper** | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 9. Validation standard

**Write validation that fails against the broken state, and observe it fail.** T1 says exactly how: move the button, watch the test fail, move it back.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every game string you quote.

**Traceable quotes do not make a report arithmetically sound.** Check counts separately.

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.** **A clamp is not a rejection. A client-only bound is not a bound.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard** — and make sure the guard can actually fail. T1's second assertion (`AutoAdvanceTimer` absent) exists because without it the test would pass against the wrong fixture.

**A driven playthrough is not a played one.** Every item in the last two waves came from a human with three simulators, not from a gate.

---

## 10. Feedback loop — what past specs got wrong

- **A cross-reference survives a renumber; the promise it made does not.** A4 was honestly marked NOT RUN and pointed at a future assertion. The list was renumbered mid-run and the pointer was never repointed, so the document now cites evidence about something else. **Grep for inbound references whenever you renumber anything.**
- **A specced assertion can be quietly dropped while the item it belongs to is genuinely finished.** Issues 83–87 all shipped correctly; two of their assertions did not. **"The code is right" and "the coverage is complete" are separate claims.**
- **The backend keeps being ahead of the client.** Mid-match departure, host removal and lobby readiness were all built server-side and either unreachable or never consulted. Missing affordances and unenforced gates are invisible to server tests and source audits alike.
- **A computed value that feeds a `decoration` looks like a gate and is not.** Grep where a guard value is *read*, not just where it is computed.
- **Fixing a class of defect promotes the next one.** Fabricated quotes → arithmetic that did not add up → missing controls → dropped assertions. Assume the next failure is one level up.
- **When a written step fails twice, replace it with a tool.** `check_deploy_fresh.sh` ended a two-cycle deploy gap, and works only because exit 2 is distinct from exit 0.
- **When you redefine what a field holds, enumerate its readers.**
- **One item = one commit.** **Doc structure rots silently** — append inside the single existing Resolved heading.

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

- [ ] **T0** — `grep -n "Assertion A20" docs/playthrough_findings_marionette.md` returns **0**; A4's Gap names Issue 88.1 and states the path is unverified; no verdict changed.
- [ ] **Issue 88 selection recorded** before T1 or T2 begins.
- [ ] **T1** *(A or B)* — timer-disabled case on all three screens, asserting the leave button **present** and `AutoAdvanceTimer` **absent**; the guard observed **failing** when the button is temporarily moved to `actions`, and the move reverted.
- [ ] **T2** *(B only)* — A4 rewritten with the deck, its size, **11** distinct prompts, `grep -cF` output per prompt, the reconciling arithmetic, and the exact string `No more prompts left in this deck.`
- [ ] **Option C instead** — both gaps recorded as *accepted*, in A4 and in `test/in_game_leave_test.dart`. Neither left reading as "queued."
- [ ] Battery at or above §1: **0 errors** · **≥137** · clean build · **≥53** · deploy gate exit **0**.
- [ ] **Nothing fixed inline** during T2. Failures are described, not repaired.
