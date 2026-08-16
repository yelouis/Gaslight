# Agent Execution Guide — Awaiting one selection (Issue 89); U0 is unblocked — August 16, 2026

**You are an engineering agent with no memory of this project.**

**What is done, and independently verified this session — in source, against the live project, and by re-running the battery, not from commit messages.** Issues 1–88 are delivered and deployed. **Do not rework any of it** (§5).

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (222 issues) |
| `flutter test` | **141/141** ✅ (was 137) |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **53/53** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ |

The last wave landed well: T0's stale reference is gone (`grep -c "Assertion A20"` → **0**), the `isTimerDisabled` cases carry **both** required assertions on all three phase screens, and the new `test/phase2_craft_test.dart` case guards the `resource-exhausted` → string mapping — **the branch that degrades silently**, since `phase2_craft.dart:543` otherwise falls through to `'Something went wrong. Try again.'`

**What is open.** Not code — evidence discipline. Two items, tracked as Issue 89.

| Item | Issue | Blocked? |
|---|---|---|
| **U0** — perform and record the T1 falsification | 89.2 | **No. Do this now.** It is a standing validation rule, not an option branch. |
| **U1** — reconcile A4's verdict with A4's evidence | 89.1 | **Yes** — the three options differ in what gets verified, not just how much work it is. |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **A guard that has never failed has not been tested.** U0 exists because this was skipped.
- **A verdict line must not name a verification method the block records no data for.** If a session ran and its output was lost, that is **NOT RUN**, not PASS with a citation.
- **Every quoted game string in any report must be findable in source with `grep -F`**; any count-dependent assertion must state the count, the deck, and the deck's size.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §5 or §6.**

---

## 1. Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`. **U0 touches these tests.**
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** Run `./scripts/check_deploy_fresh.sh` as the fifth gate; **exit 2 means "could not verify" and must never be reported as a pass.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** **Re-roll requires the truth phase, which requires 3 active players *and* every non-host ready** — there is no re-roll in the lobby, and a previous revision of this guide wrongly specced it as a one-device task. Grep the guards before writing a setup.
17. **A cross-reference between assertions goes stale silently.** Repoint inbound references whenever you renumber.
18. **A verdict line and its observation section are two separate claims.** Check them against each other — this is Issue 89.

---

## 2. U0 — Perform and record the T1 falsification *(unblocked)*

**What this means for the user:** three new tests assert the leave control survives timers being disabled. Nobody has confirmed those tests can actually fail, and the three tests that already existed passed throughout the entire defect.

### The gap

The T1 spec required moving the leave `IconButton` from `leading` into `actions`, observing the new timer-disabled case **fail** while the timers-enabled case still **passed**, reverting, and recording both outcomes in the commit body. `f0d878b` has a one-line message and no body; `ec3a976`'s body lists changes only. **No commit records the observation.**

The tests themselves are correct — `isTimerDisabled: true`, `find.byTooltip('Leave game')` present, `find.byType(AutoAdvanceTimer)` absent, `accessibleNavigation: true`. **This is missing proof-of-work, not a suspected defect.** It matters because the assertion that makes these tests meaningful is the `AutoAdvanceTimer`-absent one, and nothing has yet demonstrated that the pair fails when the control moves.

### Implementation

1. In `lib/screens/phase2_craft.dart`, temporarily move the leave `IconButton` out of the `AppBar`'s `leading:` and into `actions:`, **inside the existing `state.isTimerDisabled ? const SizedBox.shrink() : …` branch** — that is the regression being guarded against, not a bare move.
2. Run `flutter test test/in_game_leave_test.dart`.
3. Record **both** results:
   - the **`Phase2CraftScreen … isTimerDisabled is true`** case must **fail**;
   - the original **`Phase2CraftScreen renders leave button and confirms leave on tap`** case must **still pass** — this is the half that proves why the pre-existing tests never caught it.
4. **Revert the move** — `git diff` must be empty for `lib/` before you commit.
5. Put both outcomes, verbatim, in the commit body.

**Nothing in `lib/` changes permanently.** If the timer-disabled case passes with the button moved, **stop** — the fixture is not reaching the timer-disabled branch and the test proves nothing.

### Validation

`flutter test` back at **141/141**. `git status --short` clean for `lib/`. The commit body contains the observed failure text.

Commit: `test(game): record the falsification run for the timer-disabled leave guard`.

*(This commit changes no files under `lib/` or `test/` — it exists to carry the observation. If your workflow needs a file change, add the observed failure output as a comment at the top of the `isTimerDisabled` group in `test/in_game_leave_test.dart`.)*

---

## 3. U1 — Reconcile A4's verdict with A4's evidence *(blocked on Issue 89)*

**What this means for the user:** A4 currently says the deck-exhaustion path was verified in a live Marionette session, and records nothing from a device.

### The gap

The block reads **`PASS (Verified in Backend Emulator Suite + Client Widget Suite + Marionette Live Session)`** and describes *"consecutive re-rolls on P1 in room `REQH` and `WVFM`."* Its **"What I observed, verbatim"** section is three bullets: a backend source citation, a client source citation, and a test pass count.

| Required by the T2 spec | Present in the block |
|---|---|
| Ordered list of distinct prompts | **0 entries** |
| `grep -cF` traceability per prompt | **0 mentions** |
| Reconciling arithmetic (12 − 1 = 11 re-rolls; message on attempt 12) | absent |
| The string observed **on device** at a stated attempt index | absent |

Nothing is fabricated — the claim is simply larger than the evidence, and the named room codes make it read as verified.

### Option A — downgrade the verdict to what the evidence supports

Rewrite A4's verdict as:

```markdown
- **Verdict:** PASS (backend boundary + client widget mapping) · **NOT RUN on device**
```

Delete the "Marionette Live Session" clause from the verdict **and** step 3 of "What I did". Keep the backend and widget-test citations — they are real and they are good. Add one line stating plainly that **the end-to-end path from a deployed `resource-exhausted` to the rendered SnackBar has not been observed**, and that this is accepted, not queued.

**Do not delete the room codes silently** — if a session ran and its output was lost, say that.

**Validation:** `grep -c "Marionette Live Session" docs/playthrough_findings_marionette.md` → **0**. A4's verdict names only methods with data behind them in the same block.

### Option B — run the device session A4 claims

**Three devices, not one** (trap 16). Bots are permitted for the two filler seats **for this assertion only**, because every observation concerns the host's own device and the other seats exist solely to satisfy the player floor; bots carry `lobbyReady: true` (`index.ts:1481`) so they clear the readiness gate. **Record the bots deviation.**

- `.env` must contain `USE_EMULATOR=false`; rebuild the client (it is a bundled asset).
- Uninstall first so nothing restores a stale room; launch one device at a time.
- `Disable Game Timers` **on** (`lobby_screen.dart:623`); `Family-Friendly Decks Only` **off** (`lobby_screen.dart:643`).
- **`cah_dark_humor`, 12 prompts, the short path.** `tap(key: 'deck_cah_dark_humor')`. Count the deck first and put the number in the block:

```bash
awk "/'cah_dark_humor': \[/,/^    \],/" lib/utils/prompt_decks.dart | grep -cE '^\s+"'
```

**The arithmetic, written out in the block:** the deck holds 12; the host's card consumes 1 at deal; `seenPrompts` is per-sealed-document — so **re-rolls 1–11 each return a distinct prompt** and **attempt 12 shows the message**. `grep -cF` every prompt and paste the output. **PASS requires the exact string `No more prompts left in this deck.`** — not the generic `Something went wrong. Try again.` — at attempt 12, with the count reconciling at 11.

**If the message appears early, or the generic fallback appears: STOP and file it.** Shut the simulators down when finished (`xcrun simctl shutdown all`).

### Option C — retire the device assertion

Rewrite A4's verdict as Option A does, and additionally record that the device check is **retired, not deferred**: the backend proves the throw at two deck sizes, `test/phase2_craft_test.dart` proves the code→string mapping, and the only unexercised seam is Firebase's exception marshalling. Add the same note to `design_prompt_system.md` §5 so it does not resurface as an open gap.

**Do not leave it reading as "queued."** Issue 88.1 existed because a deferred item described as pending became invisible.

---

## 4. Do not invent work · escalation

Outside U0 and U1 there is no queue. Legitimate triggers: a defect U1 surfaces, a user-selected issue, or the TTL interval dropping below ~4 hours.

**Bounded deviation:** keep the intent, deviate minimally, note it in the commit body — **and record any substitution of deck, device or fixture.**

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel, **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** use bots outside U1 Option B's bounded exception, and **do not** reconstruct an observation you did not capture.

---

## 5. Already delivered — do NOT rework

**Verified in source and against the live project, August 16, 2026, at `f0d878b`:**

- **Issue 88.2** — `test/in_game_leave_test.dart` covers all three phase screens with `isTimerDisabled: true`, asserting the leave button **present** and `AutoAdvanceTimer` **absent**. *(U0 supplies the missing falsification record, not new tests.)*
- **Issue 88.1 (partial)** — `test/phase2_craft_test.dart:213` stubs `FirebaseFunctionsException(code: 'resource-exhausted')` and asserts the SnackBar text. **This is a better durable guard than the manual observation the spec asked for** — keep it whatever U1 decides.
- **Issue 84** — `DialogThemeData` at `main.dart:86`; contrast test asserts **≥4.5:1** content and **≥3.0:1** title.
- **Issue 83 (Option C)** — `game_e2e.spec.ts:1959`, parameterised over both deck sizes with the per-player isolation guard.
- **Issue 87** — host kick succeeds **and** a non-host kicking a third player is rejected. **That second half is the bound; never relax it.**
- **Issue 86** — `index.ts:264` filters `!p.isHost && p.lobbyReady !== true`; the test asserts the host's own `lobbyReady` is not true before proving the start succeeds.
- **Issue 85** — `index.ts:909` applies the below-3 rule **after** the phase branches; three tests cover auto-end, the 4-player over-reach, and the lobby exemption.
- **Issues 77–82** — sentinel purge, unmask bounds, full deploy, and the freshness gate whose three exit codes were each exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 6. Invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`.
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. **Separate guard from the 3-player floor.**
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and wins over the phase-specific branches.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.** Never add a separate kick or quit callable.
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **The exhaustion message is matched on the `resource-exhausted` code**, and every other error falls through to `'Something went wrong. Try again.'` — **that fall-through is the failure mode**, and `test/phase2_craft_test.dart` is what guards it (`design_prompt_system.md` §5).
- **Re-rolls are unlimited during `truth`, rejected in every other phase, and never repeat.** **`seenPrompts` is per-sealed-document, not global.**
- **Who may accuse and who may be accused are two separate bounds.**
- **The deploy gate's three exit codes are a contract.**
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.** **Option ids are opaque UUIDs.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, and the rejected options on 58–66.

---

## 7. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Phase order, 3-player floor, readiness gate, `votes` contract | `design_game_state_and_models.md` |
| Scoring formulas, reveal beats, unmask bounds | `design_scoring_and_ui.md` |
| Deploy & the freshness gate (§8); `handleDisconnect`'s callers (§4) | `design_database_and_security.md` |
| Dialog surface & contrast rule (§6) | `design_ui_direction.md` |
| **Deck catalogue, re-roll exclusion, exhaustion plumbing (§5)** | `design_prompt_system.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 8. Validation standard

**Write validation that fails against the broken state, and observe it fail.** U0 is this rule applied to itself.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every game string you quote.

**A verdict line and its observation section are two separate claims** — check them against each other.

**Traceable quotes do not make a report arithmetically sound.** State the count, the deck, and the deck's size.

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.** **A clamp is not a rejection. A client-only bound is not a bound.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Every defect in the last three waves came from a human with three simulators, not from a gate.

---

## 9. Feedback loop — what past specs got wrong

- **A verdict line can name a method the block has no data for.** A4 says "Marionette Live Session" and names two room codes; its observation section holds two source citations and a pass count. **Specificity reads as evidence and is not.**
- **A Definition-of-Done step with no artefact gets skipped.** The T1 falsification left nothing behind — no file, no output — so nothing recorded its absence. **Steps whose only product is a commit-body sentence need the artefact named explicitly**, which is why U0 says where to put it.
- **A cross-reference survives a renumber; the promise it made does not.**
- **This guide once told an agent to do something impossible** (a one-device re-roll session). A guide is not exempt from its own traps.
- **"The code is right" and "the coverage is complete" are separate claims.**
- **The backend keeps being ahead of the client.** Missing affordances and unenforced gates are invisible to server tests and source audits alike.
- **A computed value that feeds a `decoration` looks like a gate and is not.**
- **Fixing a class of defect promotes the next one.** Fabricated quotes → arithmetic that did not add up → missing controls → dropped assertions → stale cross-references → a verdict outrunning its evidence.
- **When a written step fails twice, replace it with a tool.**
- **One item = one commit.** **Doc structure rots silently** — append inside the single existing Resolved heading.

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §8, including the over-reach guard.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading;
    playthrough observations go to docs/playthrough_findings_marionette.md.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **U0** — the timer-disabled case **observed failing** with the leave button moved into the `isTimerDisabled` branch of `actions`, the timers-enabled case observed **still passing**, the move reverted, and both outcomes recorded where §2 says to put them.
- [ ] **U0** — `git status --short` clean for `lib/`; `flutter test` back at **141/141**.
- [ ] **Issue 89 selection recorded** before U1 begins.
- [ ] **U1** — per the selection. Under **A** or **C**, `grep -c "Marionette Live Session"` returns **0** and A4's verdict names only methods with data in the same block. Under **B**, A4 carries the deck, its size **12**, **11** ordered prompts, `grep -cF` output per prompt, the arithmetic, and the exact string at attempt **12**.
- [ ] **Under C only** — the retirement recorded in `design_prompt_system.md` §5, so it cannot resurface as an open gap.
- [ ] Battery at or above the bar: **0 errors** · **≥141** · clean build · **53/53** · deploy gate exit **0**.
- [ ] **Nothing fixed inline** during U1 Option B. If the exhaustion message misbehaves, it is filed, not repaired.
