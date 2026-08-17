# Agent Execution Guide — Active Build: Z1 (Issue 92, Option A) — August 17, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–91 and 93–95 are delivered, deployed, and independently verified** (§4). Battery at `0106840`:

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (26 warnings, 196 infos) |
| `flutter test` | **156/156** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **54/54** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — 15/15 functions |

**This build is one item.** Issue 92, selected as **Option A**: keep retry-on-failure, and make the in-flight guard's regression test able to fail. **One test file changes. No production code. No deploy.**

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail — and apply that to the test itself.** Z1 *is* that rule being applied retroactively.
- Record the failure output in the commit body **and in a comment on the test**.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §4 or §5.**

---

## 1. Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` models the server's error shape** and carries `overrideCallable`, a controllable gate, and `getMyOptionIdCallCount`. **Z1 depends on all three.** Behaviour must stay unchanged when no override or gate is installed.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.**
8. **`firebase.json`'s `predeploy` runs the test suite.** Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** `./scripts/check_deploy_fresh.sh` is the fifth gate; **exit 2 is "could not verify", never a pass.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** Grep the guards first.
17. **A cross-reference between assertions goes stale silently.**
18. **A verdict line and its observation section are two separate claims.**
19. **Grep for comparisons that can never be true.**
20. **Cards are keyed by their target player's id.**
21. **A test can use the wrong fixture and still read as correct.** **This is Z1's entire subject.**
22. **Check what a widget already offers before adding to it.** `PrimaryButton` already had `loading`; an earlier spec claimed otherwise and over-scoped the fix.

---

## 2. Z1 — Make the in-flight guard's regression test able to fail

**What this means for the user:** nothing directly. It means the guard that stops duplicate paid callable invocations can be deleted without any test noticing — so the next refactor can silently remove it.

### The gap

`test/fetch_my_option_id_test.dart:148` throws on **`card_a`** and then fetches **`card_b`**:

```dart
      final res1 = await gameService.fetchMyOptionId('card_a');   // throws
      …
      final res2 = await gameService.fetchMyOptionId('card_b');   // ← different card
      expect(res2, isNotNull);
```

`card_b` was never in the in-flight set, so **the assertion holds whether or not the `finally` exists.** It duplicates the "different card" over-reach guard one test above it.

**Demonstrated:** deleting the `finally` block in `game_service.dart` and running `flutter test test/fetch_my_option_id_test.dart` gives `+3: All tests passed!`.

### Implementation — one test, three edits

**File: `test/fetch_my_option_id_test.dart`, the `wedge check` test (~`:148`). No production file changes.**

1. **Change the second call's subject to the card that threw:**

```dart
      final res2 = await gameService.fetchMyOptionId('card_a');
```

2. **Assert it reached the callable.** The existing assertion (`isNotNull`) is not enough — add:

```dart
      expect(fakeFunctions.getMyOptionIdCallCount, 2,
          reason: 'The finally must clear the in-flight marker so the same card can be fetched again');
      expect(res2, 'opt_recovered');
```

The counter is reset to `0` at the top of that test already, and the recovery override already returns `{'optionId': 'opt_recovered'}` — **re-read both rather than assuming; do not renumber or reorder the surrounding tests.**

3. **Rename the test** so its subject is unambiguous, e.g. `wedge check: a card whose fetch threw can be fetched again (proves the finally)`.

**Why these assertions work, and why the old one did not.** With the `finally` present, the throw leaves the in-flight set empty **and** — because X1 removed the failure-cache — leaves `_myOptionIdByCard` without an entry, so the second call reaches the callable: count **2**, value `opt_recovered`. Without the `finally`, `card_a` is still marked in flight, so `fetchMyOptionId` returns at `if (_optionIdFetchesInFlight.contains(cardId)) return null;` — count stays **1** and `res2` is `null`. **Both new assertions fail, and the old one would have failed too once the card matched.**

### Validation

**The falsification, and it is mandatory — this item exists because it was skipped:**

1. Delete the `finally` block from `fetchMyOptionId` in `lib/services/game_service.dart` (leave the `try`/`catch`).
2. `flutter test test/fetch_my_option_id_test.dart`.
3. **Confirm the wedge check now FAILS**, and record the exact failure text.
4. **Confirm the other tests in that file still pass** — the falsification must be specific to the guard, not a blanket breakage.
5. **Restore the `finally`.** `git diff` must be empty for `lib/`.
6. Put the recorded failure text **in the commit body and in a comment on the wedge test**, matching the artefact already at `test/in_game_leave_test.dart:212–214`.

**If the wedge check still passes with the `finally` removed, stop** — the edit did not take, and you have reproduced the original defect.

Battery: `flutter test` stays at **156/156** (this changes assertions, not test count) · **0 errors** · clean build · **54/54** · deploy gate exit **0**. **No deploy.**

### Blast radius

`test/fetch_my_option_id_test.dart` only. **Do not touch `lib/` except for the temporary falsification probe, which must be reverted.**

Commit: `test(vote): make the in-flight guard's regression test able to fail`.

---

## 3. What Option A deliberately accepts

**Retry-on-failure stays.** X1 removed `_myOptionIdByCard[cardId] = null` from the `catch`, so a failed fetch is not cached and is re-attempted on the next rebuild, serialised by the in-flight guard. **Option A keeps this**, which is why the wedge test can exist at all: if failures were cached, the completion cache would short-circuit before the guard was consulted and the `finally` would be unobservable through the public API.

**The accepted cost:** a card whose fetch fails *persistently* is retried once per rebuild for the rest of the vote phase. Bounded in concurrency by the guard, unbounded in total. **This is a decision, not an oversight** — it buys recovery from a transient failure, which the cached version could not do. §5 records it so a later pass does not "restore" the cache without a decision.

*(If it is ever restored, the wedge test will fail loudly rather than silently — the second call would return the cached `null` without reaching the callable. That is the correct behaviour for a guard test and is a reason to leave it as written.)*

---

## 4. Already delivered — do NOT rework

**Verified in source and against the live project, August 17, 2026, at `0106840`:**

- **Issue 94** — `card_grid.dart:47–49` is an ordered ternary with **no `||`**; `game_service.dart:490` writes `{text.trim()}`. The load-bearing guard is covered: with the id null, `test/phase3_vote_test.dart:356` asserts `disabledCount == 1` and `enabledCount == 2`. **The code now matches what `design_scoring_and_ui.md` §3.2 already documented.**
- **Issue 93** — join errors mapped to sentences; the regression test rejects `pigeon`, `#0` **and** `firebase_functions`.
- **Issue 95** — `_isCreatingRoom` / `_isJoiningRoom` cleared in `finally`; `loading:` passed to both buttons; **`shared_ui.dart` unmodified**; four tests including the idempotency guard.
- **Issue 91** — `_optionIdFetchesInFlight` (`game_service.dart:86`), marked at `:517`, cleared in a `finally` at `:532–534` and in teardown at `:307`. **The guard is correct — only its test is Z1's subject.**
- **Issue 90** — per-card keying and `getMyOptionId` wired end to end, with `PERMISSION_DENIED` asserted for third-party queries.
- **Issue 89** — A4 downgraded to `PASS (backend boundary + client widget mapping) · NOT RUN on device`; T1 falsification recorded with real failure text.
- **Issues 84–88** — dialog contrast (≥4.5:1 / ≥3.0:1); deck exhaustion at two deck sizes; host kick **with the non-host rejection bound**; readiness gate **with the host-exemption deadlock guard**; below-3 auto-end with its two guards; `isTimerDisabled` leave-control cases.
- **Issues 77–83** — sentinel purge, unmask bounds, full deploy, freshness gate with all three exit codes exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 5. Invariants & intentional decisions — do NOT change

- **A failed `getMyOptionId` is not cached and will be retried** (Issue 92, Option A). **Do not restore `_myOptionIdByCard[cardId] = null` to the `catch` without a decision** — it would make the `finally` untestable.
- **`fetchMyOptionId` is called from `build()` on purpose.** Issue 91 Option B was declined. **Do not relocate the call.**
- **The option id is the authority; text is the fallback, consulted only when the id is null** (`design_scoring_and_ui.md` §3.2). **Never union the two** — that was Issue 94.
- **Never interpolate an exception object into user-facing text.** Map on `e.code`, generic fallback (`design_ui_direction.md` §6).
- **Busy-state disabling is a correctness guard**, not only feedback — `createRoom` is not idempotent.
- **`votes` maps `voterId` → resolved author id. There is no sentinel.**
- **Never send *other players'* authorship to the client** — but this does not forbid telling a caller their own.
- **`castVote` rejects only genuine self-votes.** **Never loosen it — and never let the client bound exceed it.**
- **The readiness gate exempts the host deliberately.** Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase branches.
- **`handleDisconnect` has exactly three legitimate callers.** **A non-host acting on a third player stays rejected with `permission-denied`.**
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**.
- **The exhaustion message is matched on the `resource-exhausted` code**; the generic fall-through is the failure mode.
- **Re-rolls are unlimited during `truth`, rejected elsewhere, never repeating.** **`seenPrompts` is per-sealed-document.**
- **The deploy gate's three exit codes are a contract**, and so is its expected-function list.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, 90 A-alone/B-alone/C, 91 B/C, **92 B/C**, 93 B/C, 94 B/C, 95 B/C, and the rejected options on 58–66.

---

## 6. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Phase order, 3-player floor, readiness gate, `votes` contract | `design_game_state_and_models.md` |
| Scoring, reveal beats, unmask bounds, **own-answer lockout (§3.2)** | `design_scoring_and_ui.md` |
| Callable table incl. `getMyOptionId` (§2); deploy & freshness gate (§8); `handleDisconnect`'s callers (§4) | `design_database_and_security.md` |
| **Dialog surface, error surfaces, busy states (§6)** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing (§5) | `design_prompt_system.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 7. Do not invent work · escalation

**After Z1 the queue is empty.** The only legitimate triggers for further work are:

- a defect surfaced by a human playing the game — **five of the last six waves came from exactly this, and none from a gate**;
- a user-selected issue in `docs/ongoing_general_errors.md`;
- **`ROOM_TTL_MS` dropping below ~4 hours**, which makes a host-only `touchRoom` keepalive plus a client timer mandatory;
- a sibling glyph in the Phosphor font turning out wrong.

**Do not** start a playthrough, refactor, or "improvement" nobody asked for. **Do not** re-verify what §4 records as delivered.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`.

---

## 8. Validation standard

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.** Z1 is that rule applied retroactively to a guard that shipped without it.

**Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.

**Assert the negative as well as the positive.** Issue 93's guard rejects `pigeon`/`#0`/`firebase_functions`; the friendly sentence alone would pass with the trace still on screen.

**A test harness that cannot express the bug will pass against it.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.**

**A check that cannot run must say so, not pass.**

**A clamp is not a rejection. A client-only bound is not a bound — and a client bound *tighter* than the server's is also a defect.**

**A layered fix must be ordered, not unioned** — the authority has to be able to say *no*, not merely *also yes*.

**Structurally present is not actually wired.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

---

## 9. Feedback loop — what past specs got wrong

- **A guard's test must be run with the guard removed.** Two waves apart, the same standing rule was honoured for the leave-control guard and skipped for the in-flight guard. **The skip is invisible in a green run** — which is why the artefact (recorded failure text in the test file) now exists.
- **A layered fix must be ordered, not unioned** (Issue 94).
- **Check what a component already offers before specifying an addition** (Issue 95's `loading`).
- **Enumerate error codes from source, never from expectation** (Issue 93).
- **A fix can change behaviour it was not asked to change** (Issue 92.2). **Diff the whole method, not only the lines you meant to add.**
- **A guard and a cache are different things.**
- **"There is no private channel" was wrong and nearly closed off the right fix.**
- **A dead comparison keeps a heuristic load-bearing.**
- **"The code is right" and "the coverage is complete" are separate claims.**
- **Fixing a class of defect promotes the next one:** fabricated quotes → arithmetic → missing controls → dropped assertions → stale cross-references → a verdict outrunning its evidence → a missing concurrency guard → a guard whose test cannot fail → a fix wired so it cannot win → **a test whose subject is the wrong fixture.**
- **One item = one commit.** **Doc structure rots silently.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §8 — including removing the guard to prove the test can fail.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **Z1** — the wedge check's second call targets **`card_a`**, and asserts **`getMyOptionIdCallCount == 2`** and `res2 == 'opt_recovered'`.
- [ ] **Z1 falsification** — the `finally` deleted, the wedge check **observed failing**, **the other tests in that file observed still passing**, the `finally` restored, and `git diff` empty for `lib/`.
- [ ] **Z1 artefact** — the recorded failure text in the commit body **and** in a comment on the wedge test.
- [ ] **The test is renamed** so its subject is unambiguous.
- [ ] **No production code changed.** No deploy.
- [ ] Battery at or above the bar: **0 errors** · **156/156** · clean build · **54/54** · deploy gate exit **0**.
- [ ] **Queue empty afterwards. Do not invent work** (§7).
