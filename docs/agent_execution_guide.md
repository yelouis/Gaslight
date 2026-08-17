# Agent Execution Guide — Awaiting one selection (Issue 92) — August 17, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved code queue. Do not invent work** (§3).

**Issues 1–91 are delivered, deployed, and independently verified this session** — in source, against the live project, and by re-running the battery (§4).

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (26 warnings, 196 infos) |
| `flutter test` | **147/147** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **54/54** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — **15/15** functions |

**One item is open and needs a `Your selection:` line before anything happens: Issue 92.** The X1 in-flight guard is correct; **its regression test cannot fail**, and X1 quietly changed retry-on-failure semantics. §2 specs all three branches.

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail.** **Apply this to the test as well as to the code** — remove the guard, watch the test go red. Issue 92 exists because that step was skipped.
- Record the failure output in the commit body **and in an artefact that survives** — a comment in the test file.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §4 or §5.**

---

## 1. Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`** — it walks vendored plugin source and reports ~678 phantom errors.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape. It now also carries a **controllable gate and an invocation counter** for `getMyOptionId` — behaviour is unchanged when no gate is installed, and it must stay that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** `./scripts/check_deploy_fresh.sh` is the fifth gate; **exit 2 means "could not verify" and must never be reported as a pass.** Its expected-function list is part of its contract.
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** Grep the guards before writing a setup.
17. **A cross-reference between assertions goes stale silently.**
18. **A verdict line and its observation section are two separate claims.**
19. **Grep for comparisons that can never be true.**
20. **Cards are keyed by their target player's id.**
21. **A test can use the wrong fixture and still read as correct.** Issue 92.1 throws on `card_a` and asserts on `card_b`. **Check that a test's subject is the thing the spec named**, not merely the right shape.

---

## 2. Issue 92 — the wedge check, and retry-on-failure *(blocked on selection)*

**What this means for the user:** nothing visible today. It means the guard protecting against duplicate paid callable invocations has no working regression test, and a failed fetch now behaves differently than before in a way nobody decided.

### The gap — 92.1, demonstrated

`test/fetch_my_option_id_test.dart:148` throws on **`card_a`** and then fetches **`card_b`**. `card_b` was never in the in-flight set, so **the assertion holds whether or not the `finally` exists** — it is a duplicate of the "different card" over-reach guard one test above it.

**Verified by removing the guard:** deleting the `finally` block outright and running `flutter test test/fetch_my_option_id_test.dart` yields `+3: All tests passed!`.

### The gap — 92.2, a behaviour change nobody recorded

X1 deleted `_myOptionIdByCard[cardId] = null;` from the `catch`.

| Path | Before X1 | After X1 |
|---|---|---|
| Fetch succeeds | cached; **1 call ever** | cached; **1 call ever** |
| Fetch **fails** | cached as `null`; **1 call ever** | **nothing cached; one call per rebuild**, serialised by the guard |

For a card whose fetch persistently fails, **X1 raised total invocations above the code it was fixing.**

**The two are coupled, and this is the decision to make.** *Should a failed option-id fetch ever be retried?* **If failures are cached, the `finally` is unobservable through the public API** — the completion cache short-circuits before the guard is consulted — so it becomes defence-in-depth no test can reach. If failures are not cached, the `finally` is load-bearing and testable. The current code chose "not cached" and then did not test it.

### Option A — keep retry-on-failure, fix the test

Change the wedge check's second call to **`fetchMyOptionId('card_a')`** — the same card that threw. Assert it **reaches the callable**: `fakeFunctions.getMyOptionIdCallCount` increments to **2**, and the recovered value is returned.

**Falsification, mandatory:** delete the `finally` block, run `flutter test test/fetch_my_option_id_test.dart`, and confirm the wedge check now **fails**. Restore it. Record the failure text in the commit body **and** in a comment on that test.

**No production change.** One test edit.

### Option B — restore failure-caching, drop the misleading test

Put `_myOptionIdByCard[cardId] = null;` back in the `catch`, before the `finally`. Keep the `finally` as defence-in-depth. **Delete the wedge check** and replace it with a comment on the test group explaining that an in-flight leak is unobservable because the completion cache short-circuits first — **so the absence of a wedge test is a consequence of the design, not missing coverage.**

**Falsification for the restored behaviour:** a test where the fake throws for `card_a`, then a second `fetchMyOptionId('card_a')` asserts `getMyOptionIdCallCount` is **still 1** — proving the failure is cached and never retried. Observe it fail against today's code, where the count reaches 2.

### Option C — bounded retry

Cache the failure **and** allow a fixed number of re-attempts (one). Track an attempt count per card; clear it in the teardown path at `game_service.dart:307` alongside the other state.

**Two assertions required, and neither alone is sufficient:** the first failure **is** retried (count reaches 2), and the second failure **is not** (count stays at 2). A fix that only allowed retries, or only capped them, would pass one and fail the other.

### Validation common to all three

Battery at or above §0: **0 errors** · **≥147** · clean build · **54/54** · deploy gate exit **0**. **No deploy** — client-only.

**Do not touch `phase3_vote.dart`.** The `build()` call site is an intentional decision (§5).

Commit: `test(vote): make the in-flight guard's regression test able to fail` — or, under B/C, a `fix(vote):` subject naming the retry semantics chosen.

---

## 3. Do not invent work · escalation

**Outside Issue 92 there is no queue.** The only legitimate triggers for further work are:

- a defect surfaced by a human playing the game (four of the last five waves came from exactly this, and none from a gate);
- a user-selected issue in `docs/ongoing_general_errors.md`;
- **`ROOM_TTL_MS` dropping below ~4 hours**, which makes a host-only `touchRoom` keepalive plus a client timer mandatory;
- a sibling glyph in the Phosphor font turning out wrong.

**Do not** start a playthrough, refactor, or "improvement" nobody asked for. **Do not** re-verify what §4 records as delivered.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel, **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** loosen `castVote`'s self-vote rejection, **do not** put another player's option id anywhere the client can read it, and **do not** move the `fetchMyOptionId` call out of `build()`.

---

## 4. Already delivered — do NOT rework

**Verified in source and against the live project, August 17, 2026, at `557bea0`:**

- **Issue 91** — `_optionIdFetchesInFlight` (`game_service.dart:86`), marked at `:517`, cleared in a real `finally` at `:532–534`, cleared in teardown at `:307`. `phase3_vote.dart` untouched as specified. The fake gained a gate and counter with unchanged default behaviour. **The guard is correct; only its test and the retry semantics are in question (§2).**
- **Issue 90** — self-answer detection is layered: `_mySubmittedByCard` keyed by card, with `getMyOptionId` as the authority, **wired end to end** (`:509` → `:90` → `phase3_vote.dart:423/425` → `CardGrid.myOptionIdForThisCard` → `card_grid.dart:47`). Server bounds include **`PERMISSION_DENIED` when querying another player's id**.
- **Issue 89** — A4 reads `PASS (backend boundary + client widget mapping) · NOT RUN on device`; the T1 falsification is recorded with real failure text at `test/in_game_leave_test.dart:212–214`.
- **Issue 88** — `isTimerDisabled` cases on all three phase screens assert the leave button present **and** `AutoAdvanceTimer` absent; `test/phase2_craft_test.dart:213` guards the `resource-exhausted` → SnackBar mapping.
- **Issues 84–87** — dialog contrast (≥4.5:1 content / ≥3.0:1 title); deck exhaustion at two deck sizes; host kick **with the non-host rejection bound**; readiness gate **with the host-exemption deadlock guard**; below-3 auto-end with the 4-player over-reach and lobby exemption.
- **Issues 77–83** — sentinel purge, unmask bounds, full deploy, and the freshness gate whose three exit codes were each exercised deliberately.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 5. Invariants & intentional decisions — do NOT change

- **`fetchMyOptionId` is called from `build()` on purpose.** Issue 91 Option B (relocating it) was **declined**; the in-flight guard makes repeated invocation harmless. **Do not relocate the call.**
- **`votes` maps `voterId` → resolved author id. There is no sentinel.**
- **Never send *other players'* authorship to the client** — **but this does not forbid telling a caller their own.** `getMyOptionId` returns at most one id, only the caller's (`design_database_and_security.md` §2).
- **`castVote` rejects only genuine self-votes**, resolved server-side. **Never loosen it — and never let the client bound exceed it** (`design_scoring_and_ui.md` §3.2).
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase branches, and computes no scores.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.**
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **The exhaustion message is matched on the `resource-exhausted` code**; every other error falls through to the generic string, and **that fall-through is the failure mode**.
- **Re-rolls are unlimited during `truth`, rejected elsewhere, never repeating.** **`seenPrompts` is per-sealed-document, not global.**
- **Who may accuse and who may be accused are two separate bounds.**
- **The deploy gate's three exit codes are a contract**, and so is its expected-function list.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, 90 A-alone/B-alone/C, 91 B/C, and the rejected options on 58–66.

---

## 6. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Phase order, 3-player floor, readiness gate, `votes` contract | `design_game_state_and_models.md` |
| Scoring, reveal beats, unmask bounds, own-answer lockout (§3.2) | `design_scoring_and_ui.md` |
| Callable table incl. `getMyOptionId` (§2); deploy & freshness gate (§8); `handleDisconnect`'s callers (§4) | `design_database_and_security.md` |
| Dialog surface & contrast rule (§6) | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing (§5) | `design_prompt_system.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 7. Validation standard

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.** Issue 92.1 is the cost of skipping it: the guard's own regression test passes with the guard deleted.

**A test harness that cannot express the bug will pass against it.** When a test seems impossible to write, suspect the harness before the claim.

**Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.**

**A verdict line and its observation section are two separate claims.**

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.**

**A clamp is not a rejection. A client-only bound is not a bound — and a client bound *tighter* than the server's is also a defect.**

**Structurally present is not actually wired.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Four of the last five waves came from a human with three simulators; none came from a gate.

---

## 8. Feedback loop — what past specs got wrong

- **A test can satisfy a spec's words while testing nothing.** The spec said "that same card"; the implementation used a different one. Same shape, same assertion, zero coverage — and **a passing run looks identical either way**. The only defence is removing the guard and watching the test fail.
- **A fix can change behaviour it was not asked to change.** X1 removed failure-caching in passing, raising invocation counts in the failure path above the code it was fixing. **Diff the whole method, not only the lines you meant to add.**
- **A guard and a cache are different things, and one does not imply the other.** Ask what is true *during* the window, not only after it.
- **The idiom was already in the file.** Grep the file you are editing for an existing solution before writing a new one.
- **"There is no private channel" was wrong and nearly closed off the right fix.** When an invariant seems to forbid an obvious fix, check whether it forbids the specific thing or only the general shape.
- **A dead comparison keeps a heuristic load-bearing.**
- **A Definition-of-Done step with no artefact gets skipped.**
- **A verdict line can name a method the block has no data for.**
- **This guide once told an agent to do something impossible.** A guide is not exempt from its own traps.
- **"The code is right" and "the coverage is complete" are separate claims** — and Issue 92 is the sharpest instance yet: the code *is* right.
- **Fixing a class of defect promotes the next one:** fabricated quotes → arithmetic → missing controls → dropped assertions → stale cross-references → a verdict outrunning its evidence → a missing concurrency guard → **a guard whose test cannot fail.**
- **One item = one commit.** **Doc structure rots silently.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §7 — including removing the guard to prove the test can fail.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **Issue 92 selection recorded** before any work begins. **If the line is blank: stop and say so.**
- [ ] **Under A** — the wedge check's second call targets **`card_a`** and asserts `getMyOptionIdCallCount == 2`; **the `finally` deleted, the test observed failing, the `finally` restored**, with the failure text in the commit body and a comment on the test.
- [ ] **Under B** — `_myOptionIdByCard[cardId] = null` restored in the `catch`; the wedge check replaced by a comment explaining why it cannot exist; a new test asserts the count **stays 1** after a failure, observed failing against today's code first.
- [ ] **Under C** — both assertions present: the first failure **is** retried, the second **is not**; the attempt-count state cleared in teardown at `game_service.dart:307`.
- [ ] **`phase3_vote.dart` untouched** (§5).
- [ ] Battery at or above the bar: **0 errors** · **≥147** · clean build · **54/54** · deploy gate exit **0**. **No deploy.**
- [ ] **Queue empty afterwards. Do not invent work** (§3).
