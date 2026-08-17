# Agent Execution Guide — Queue Complete — August 17, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue. Do not invent work** (§2).

**Issues 1–95 are delivered, deployed, and independently verified this session** — in source, against the live project, and by re-running the battery. This is the first pass in the sequence with **nothing outstanding and no residue**: no open issue, no blank `Your selection:` line, no specced assertion left undelivered.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (26 warnings, 196 infos) |
| `flutter test` | **156/156** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **54/54** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — 15/15 functions, rules current |

**The last item (Issue 92) is also the first guard here whose efficacy was reproduced rather than reported.** Removing the `finally` from `fetchMyOptionId` makes the wedge check fail with `Expected: <2> / Actual: <1>` while the other two tests in that file still pass — verified independently, not taken from the commit message.

---

## 1. Standing constraints — read before touching anything

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail — and apply that to the test itself.** Remove the guard, watch the test go red, restore it, and record the failure text **in a comment on the test** as well as the commit body. Issues 89.2 and 92 were both the cost of skipping this.
- **Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run (Issue 92).
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Run `./scripts/check_deploy_fresh.sh` as the fifth gate.** **Exit 2 means "could not verify" and is never a pass.** Its expected-function list is part of its contract — update it in the same commit that adds or removes a callable.

---

## 2. Do not invent work

**There is nothing queued.** The only legitimate triggers for further work are:

- **a defect surfaced by a human playing the game** — five of the last six waves came from exactly this, and none from a gate;
- a user-selected issue in `docs/ongoing_general_errors.md`;
- **`ROOM_TTL_MS` dropping below ~4 hours**, which makes a host-only `touchRoom` keepalive plus a client timer mandatory;
- a sibling glyph in the Phosphor font turning out wrong.

**Do not** start a playthrough, a refactor, or an "improvement" nobody asked for. **Do not** re-verify what §4 records as delivered — it was checked in source this session, not taken from commit messages. **Do not** tidy anything in §5; every entry there is a decision someone made on purpose.

**If you find something worth doing, file it — do not do it.** `docs/ongoing_general_errors.md`, with options and a blank `Your selection: _____` line. That is how every item in §4 got built.

---

## 3. Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`** — it walks vendored plugin source and reports ~678 phantom errors.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way. It carries `overrideCallable`, a controllable gate, and `getMyOptionIdCallCount`; **behaviour must stay unchanged when no override or gate is installed.**
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`** — separate commands. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared** — normalise to epoch seconds (`design_database_and_security.md` §8).
16. **A spec can demand something the app cannot do.** Re-roll needs the truth phase, which needs 3 players *and* every non-host ready. Grep the guards before writing a setup.
17. **A cross-reference between assertions goes stale silently.** Repoint inbound references whenever you renumber.
18. **A verdict line and its observation section are two separate claims.**
19. **Grep for comparisons that can never be true.** A dead identity check let a text heuristic become load-bearing for three waves.
20. **Cards are keyed by their target player's id.** `card.targetPlayerId`, `submitAnswer`'s `targetCardId`, and `sealed/{cardId}` are the same value.
21. **A test can use the wrong fixture and still read as correct.**
22. **Check what a component already offers before adding to it.** `PrimaryButton` already had `loading`.
23. **Instrumentation has control flow too.** A counter placed after an early return counts only some paths — `getMyOptionIdCallCount` sat below an `overrideHandler` return and silently ignored every overridden call.

---

## 4. Already delivered — do NOT rework

**Verified in source and against the live project, August 17, 2026, at `0b76788`:**

- **Issue 92** — the wedge check targets `card_a` and asserts `getMyOptionIdCallCount == 2`; **falsification reproduced independently.** `test/fake_functions.dart` increments the counter at the entry point so overridden calls are counted.
- **Issue 91** — `_optionIdFetchesInFlight` (`game_service.dart:86`), marked at `:517`, cleared in a `finally` at `:532–534` and in teardown at `:307`.
- **Issue 90 / 94** — `card_grid.dart:47–49` is an **ordered ternary, no `||`**; `game_service.dart:490` writes `{text.trim()}`. With the id null, `phase3_vote_test.dart:356` asserts `disabledCount == 1` and `enabledCount == 2`.
- **Issue 93** — join errors mapped to sentences; the guard rejects `pigeon`, `#0` **and** `firebase_functions`.
- **Issue 95** — `_isCreatingRoom` / `_isJoiningRoom` cleared in `finally`; `loading:` passed to both buttons; **`shared_ui.dart` unmodified**; four tests including the idempotency guard.
- **Issue 89** — A4 reads `PASS (backend boundary + client widget mapping) · NOT RUN on device`; the T1 falsification is recorded with real failure text at `test/in_game_leave_test.dart:212–214`.
- **Issues 84–88** — dialog contrast (≥4.5:1 content / ≥3.0:1 title); deck exhaustion at two deck sizes; host kick **with the non-host rejection bound**; readiness gate **with the host-exemption deadlock guard**; below-3 auto-end with the 4-player over-reach and lobby exemption; `isTimerDisabled` leave-control cases.
- **Issues 77–83** — sentinel purge, unmask bounds, full deploy of 15 functions and rules, and the freshness gate whose three exit codes were each exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 5. Invariants & intentional decisions — do NOT change

- **A failed `getMyOptionId` is not cached and will be retried** (Issue 92, Option A). **Do not restore `_myOptionIdByCard[cardId] = null` to the `catch`** — caching failures makes the `finally` unobservable through the public API and the wedge test impossible.
- **`fetchMyOptionId` is called from `build()` on purpose.** Issue 91 Option B was declined; the in-flight guard makes repeat invocation harmless. **Do not relocate the call.**
- **The option id is the authority; text is the fallback, consulted only when the id is null.** **Never union the two** — that was Issue 94 (`design_scoring_and_ui.md` §3.2).
- **Never send *other players'* authorship to the client** — but this does not forbid telling a caller their own (`design_database_and_security.md` §2).
- **`castVote` rejects only genuine self-votes.** **Never loosen it — and never let the client bound exceed it.**
- **Never interpolate an exception object into user-facing text.** Map on `e.code`, generic fallback (`design_ui_direction.md` §6).
- **Busy-state disabling is a correctness guard**, not only feedback — `createRoom` is not idempotent.
- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`.
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase-specific branches, and computes no scores.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.** No separate kick or quit callable.
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **The exhaustion message is matched on the `resource-exhausted` code**; the generic fall-through is the failure mode.
- **Re-rolls are unlimited during `truth`, rejected elsewhere, never repeating.** **`seenPrompts` is per-sealed-document, not global.**
- **Who may accuse and who may be accused are two separate bounds.**
- **The deploy gate's three exit codes are a contract**, and so is its expected-function list.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`; 5 is a default, not a cap.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, 90 A-alone/B-alone/C, 91 B/C, 92 B/C, 93 B/C, 94 B/C, 95 B/C, and the rejected options on 58–66.

---

## 6. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps, lessons | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Phase order, 3-player floor, readiness gate, `votes` contract | `design_game_state_and_models.md` |
| Scoring, reveal beats, unmask bounds, own-answer lockout (§3.2) | `design_scoring_and_ui.md` |
| Callable table incl. `getMyOptionId` (§2); deploy & freshness gate (§8); `handleDisconnect`'s callers (§4) | `design_database_and_security.md` |
| Dialog surface, error surfaces, busy states (§6) | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing (§5) | `design_prompt_system.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 7. Validation standard

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.**

**Check that a test's subject is the thing the spec named.**

**Assert the negative as well as the positive.** "The friendly sentence appears" passes with the stack trace still on screen.

**A test harness that cannot express the bug will pass against it.** When a test seems impossible to write, suspect the harness before the claim.

**Instrumentation has control flow too.** A counter after an early return measures a subset.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every game string you quote.

**A verdict line and its observation section are two separate claims.**

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.**

**A clamp is not a rejection. A client-only bound is not a bound — and a client bound *tighter* than the server's is also a defect.**

**A layered fix must be ordered, not unioned** — the authority has to be able to say *no*, not merely *also yes*.

**Structurally present is not actually wired.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Every defect in the last six waves came from a human with three simulators; none came from a gate.

---

## 8. Feedback loop — what past specs got wrong

- **A guard's test must be run with the guard removed.** The skip is invisible in a green run, which is why the recorded failure text now lives in the test file rather than only a commit body.
- **A layered fix must be ordered, not unioned** (Issue 94).
- **Check what a component already offers before specifying an addition** (Issue 95).
- **Enumerate error codes from source, never from expectation** (Issue 93).
- **A fix can change behaviour it was not asked to change** (Issue 92.2). **Diff the whole method, not only the lines you meant to add.**
- **A guard and a cache are different things** — ask what is true *during* the window, not only after it.
- **"There is no private channel" was wrong and nearly closed off the right fix.** When an invariant seems to forbid an obvious fix, check whether it forbids the specific thing or only the general shape.
- **A dead comparison keeps a heuristic load-bearing.**
- **"Verified in source" is not "shipped."** A written deploy instruction failed twice before it was replaced with a tool.
- **"The code is right" and "the coverage is complete" are separate claims.**
- **Fixing a class of defect promotes the next one:** fabricated quotes → arithmetic → missing controls → dropped assertions → stale cross-references → a verdict outrunning its evidence → a missing concurrency guard → a guard whose test cannot fail → a fix wired so it cannot win → a test whose subject was the wrong fixture. **Assume the next failure is one level up, and look there first.**
- **One item = one commit.** **Doc structure rots silently** — append inside the single existing Resolved heading; never add a second.

---

## THE LOOP — for whenever the queue reopens

```
(1) STUDY the item + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §7 — including removing the guard to prove the test can fail.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading;
    playthrough observations go to docs/playthrough_findings_marionette.md.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done — for this state

- [x] Battery green and re-measured this session: **0 errors** · **156/156** · clean build · **54/54** · deploy gate **exit 0**.
- [x] Every issue through 95 resolved, with its guards verified in source rather than from commit messages.
- [x] No blank `Your selection:` line anywhere in `docs/ongoing_general_errors.md`.
- [x] Design docs carry the contracts the code now implements (§6).
- [ ] **Nothing further. Do not invent work** (§2). The next change should come from someone playing the game.
