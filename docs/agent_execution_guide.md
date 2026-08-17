# Agent Execution Guide — Active Build: X1 (Issue 91, Option A) — August 17, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–90 are delivered, deployed, and independently verified** — in source, against the live project, and by re-running the battery (§4). The last wave was the first in this sequence with no correctness residue. **Do not rework any of it.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (26 warnings, 197 infos — 223 issues) |
| `flutter test` | **144/144** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **54/54** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — **15/15** functions |

**This build is one item.** Issue 91, selected as **Option A**: add an in-flight guard to `fetchMyOptionId`. Client-only, no deploy.

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body **and in an artefact that survives** — a comment in the test file. A step whose only product is a commit-body sentence gets skipped.
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
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way. **It also resolves callables with no in-flight window, which is exactly why Issue 91 is invisible today. X1 has to change that.**
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** `./scripts/check_deploy_fresh.sh` is the fifth gate; **exit 2 means "could not verify" and must never be reported as a pass.** Its expected-function list is part of its contract — update it in the same commit that adds or removes a callable.
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** Grep the guards before writing a setup.
17. **A cross-reference between assertions goes stale silently.**
18. **A verdict line and its observation section are two separate claims.**
19. **Grep for comparisons that can never be true.**
20. **Cards are keyed by their target player's id.** `card.targetPlayerId`, `submitAnswer`'s `targetCardId`, and the `sealed/{cardId}` document id are all the same value.

---

## 2. X1 — Guard `fetchMyOptionId` against duplicate in-flight calls

**What this means for the user:** nothing visible. It is redundant paid callable invocations during the vote phase, and the fix is a few lines using a pattern already in the same file.

### The gap

`fetchMyOptionId` (`game_service.dart:509`) caches by **completion**:

```dart
    if (_myOptionIdByCard.containsKey(cardId)) {
      return _myOptionIdByCard[cardId];
    }
```

`_myOptionIdByCard` is written on success (`:522`) and in the `catch` (`:527`). **Between issuing the call and its completion, `containsKey` is still false.** The call site is inside `build()` (`phase3_vote.dart:423`), and `context.watch<GameService>()` rebuilds on every `GameService` change — the vote phase is chatty as `readyPlayers` fills in. Each rebuild inside the resolution window issues **another** invocation for the same card.

### Implementation

**Mirror `_disconnectsInFlight`** (`game_service.dart:93`), which exists for exactly this purpose and **already uses `finally`** (`:478–480`) — that is the shape to copy.

1. **`game_service.dart`, beside `_myOptionIdByCard` (`:85`)** — add the guard set:

```dart
  final Set<String> _optionIdFetchesInFlight = {};
```

2. **In `fetchMyOptionId`, after the existing `containsKey` early return**, add a second early return, then mark and clear around the call:

```dart
    if (_optionIdFetchesInFlight.contains(cardId)) return null;
    _optionIdFetchesInFlight.add(cardId);
    try {
      … existing call, cache write, notifyListeners …
    } catch (e) {
      … existing catch …
    } finally {
      _optionIdFetchesInFlight.remove(cardId);
    }
```

**The `finally` is not optional.** Without it a thrown call wedges that card permanently: the completion cache is never written on some failure paths, so `containsKey` stays false while the in-flight set stays true, and the card can never be fetched again for the life of the session.

**Return `null` from the second early return, not the cached value.** There is no cached value yet — that is the whole point of the window — and the caller already falls back to per-card text when it gets `null`.

**Note one difference from the existing idiom, deliberately:** `_disconnectsInFlight` is *added to* at its call site (`:405–406`) and *removed* inside the method. For `fetchMyOptionId`, do **both inside the method**. The call site is a `build()` and must stay side-effect-simple.

3. **`game_service.dart:305`, the teardown path** — clear the new set alongside `_myOptionIdByCard`, so a rejoin does not inherit a stale in-flight marker.

### What X1 deliberately does **not** do

**The call to `fetchMyOptionId` stays inside `build()`.** Option B — moving it to a card-change trigger — was **declined by the user** on Issue 91. This is now an intentional decision, recorded in §5: **do not "fix" it in a later pass.** The guard makes the repeated invocation harmless, which was the whole complaint.

### Validation

**The falsifying assertion, and the fake has to change before it can exist.** `test/fake_functions.dart`'s `getMyOptionId` branch (`:396`) resolves against the fake database with no delay, so today two sequential calls never overlap and any test would pass against the bug.

1. **Give the fake a controllable gate and a counter.** On the fake, add a `Completer<void>?` the test can install and an `int getMyOptionIdCallCount`. In the `getMyOptionId` branch, increment the counter on entry and `await` the completer's future when one is installed, before returning. **Leave the existing behaviour identical when no completer is installed** — every other test depends on it.
2. **The test:** install the gate; call `fetchMyOptionId('card_a')` twice **without awaiting**; assert `getMyOptionIdCallCount == 1`; complete the gate; await both; assert both return the same value.
3. **Observe it fail first.** Against unmodified `game_service.dart` the count is **2**. Record that number in the commit body and in a comment at the top of the new test group — the artefact rule (§ Standing constraints).

**Two over-reach guards, both required, both in the same test file:**
- **A different card must still fetch during the window.** With `card_a` in flight, `fetchMyOptionId('card_b')` must issue its own call — count reaches **2**, one per card. A guard keyed too broadly (a single boolean instead of a per-card set) would block it, and would otherwise pass the main assertion.
- **A completed card must still use the cache, not refetch.** After the gate completes and both calls resolve, a third `fetchMyOptionId('card_a')` must **not** increase the count — proving the guard did not accidentally replace the completion cache.

**Third assertion — the wedge check.** Install a gate, have the fake **throw** for a card, then call `fetchMyOptionId` for that same card again and assert it is **not** permanently blocked. This is what proves the `finally` is present and is the assertion most likely to be skipped.

Battery must stay at or above §0: **0 errors** · **≥144** (this adds tests, so expect more) · clean build · **54/54** · deploy gate exit **0**. **No deploy** — client-only.

### Blast radius

`lib/services/game_service.dart`, `test/fake_functions.dart`, plus the new test group. **Do not touch `phase3_vote.dart`** — the call site is intentionally unchanged. Grep for other callers of `fetchMyOptionId` before committing; there should be exactly one.

Commit: `fix(vote): guard against duplicate in-flight option-id fetches`.

---

## 3. Do not invent work · escalation

**After X1 the queue is empty.** The only legitimate triggers for further work are:

- a defect surfaced by a human playing the game (four of the last five waves came from exactly this, and none from a gate);
- a user-selected issue in `docs/ongoing_general_errors.md`;
- **`ROOM_TTL_MS` dropping below ~4 hours**, which makes a host-only `touchRoom` keepalive plus a client timer mandatory;
- a sibling glyph in the Phosphor font turning out wrong.

**Do not** start a playthrough, refactor, or "improvement" nobody asked for. **Do not** re-verify what §4 records as delivered — it was checked in source, not taken from commit messages.

**Bounded deviation:** keep the intent, deviate minimally, note it in the commit body.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel, **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** loosen `castVote`'s self-vote rejection, **do not** put another player's option id anywhere the client can read it, and **do not** move the `fetchMyOptionId` call out of `build()` (§5).

---

## 4. Already delivered — do NOT rework

**Verified in source and against the live project, August 17, 2026, at `9e78c36`:**

- **Issue 90** — self-answer detection is layered. `_mySubmittedByCard` (`game_service.dart:84`) keyed by card; `isMySubmittedAnswer(cardId, text)` (`:87`); `phase3_vote.dart:428` passes `currentCard.targetPlayerId`. Authority is `getMyOptionId`, **wired end to end** (`:509` → `:90` → `phase3_vote.dart:423/425` → `CardGrid.myOptionIdForThisCard` → `card_grid.dart:47`). Tests: cross-card duplicate votable (`phase3_vote_test.dart:166`), same-card distinguished by id (`:265`), fallback on null fetch (`:356`), and server bounds including **`PERMISSION_DENIED` when querying another player's id**.
- **Issue 89** — A4 reads `PASS (backend boundary + client widget mapping) · NOT RUN on device`; the T1 falsification is recorded with real failure text at `test/in_game_leave_test.dart:212–214`.
- **Issue 88** — `isTimerDisabled` cases on all three phase screens assert the leave button present **and** `AutoAdvanceTimer` absent; `test/phase2_craft_test.dart:213` guards the `resource-exhausted` → SnackBar mapping.
- **Issues 84–87** — dialog contrast (`main.dart:86`, ≥4.5:1 content / ≥3.0:1 title); deck exhaustion at two deck sizes; host kick **with the non-host rejection bound**; readiness gate (`index.ts:264`) **with the host-exemption deadlock guard**; below-3 auto-end (`index.ts:909`) with the 4-player over-reach and lobby exemption.
- **Issues 77–83** — sentinel purge, unmask bounds, full deploy, and the freshness gate whose three exit codes were each exercised deliberately.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 5. Invariants & intentional decisions — do NOT change

- **`fetchMyOptionId` is called from `build()` on purpose.** Issue 91 Option B (moving it to a card-change trigger) was **declined**; the in-flight guard makes repeated invocation harmless. **Do not relocate the call.**
- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`.
- **Never send *other players'* authorship to the client** — **but this does not forbid telling a caller their own.** `getMyOptionId` returns at most one id, only the caller's, over a private callable channel (`design_database_and_security.md` §2).
- **`castVote` rejects only genuine self-votes**, resolved server-side. **Never loosen it — and never let the client bound exceed it** (`design_scoring_and_ui.md` §3.2).
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase-specific branches, and computes no scores.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.** No separate kick or quit callable.
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **The exhaustion message is matched on the `resource-exhausted` code**; every other error falls through to the generic string, and **that fall-through is the failure mode**.
- **Re-rolls are unlimited during `truth`, rejected elsewhere, never repeating.** **`seenPrompts` is per-sealed-document, not global.**
- **Who may accuse and who may be accused are two separate bounds.**
- **The deploy gate's three exit codes are a contract**, and so is its expected-function list.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Leaving a room does not call `Navigator` explicitly.**
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, 90 A-alone/B-alone/C, **91 B/C**, and the rejected options on 58–66.

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

**Write validation that fails against the broken state, and observe it fail.** Record the output where it survives.

**A test harness that cannot express the bug will pass against it.** X1's whole difficulty is that `fake_functions.dart` resolves instantly; the fake must gain a gate before the assertion means anything. **When a test seems impossible to write, suspect the harness before the claim.**

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

- **A guard and a cache are different things, and one does not imply the other.** `fetchMyOptionId` had a completion cache and no concurrency guard; the cache looked like it covered both. **Ask what is true during the window, not only after it.**
- **The idiom was already in the file.** `_disconnectsInFlight` sits ten lines from the code that omitted it. **Grep the file you are editing for an existing solution to the problem you are about to solve.**
- **"There is no private channel" was wrong and nearly closed off the right fix.** The authorship invariant is about *other players'* authorship. **When an invariant seems to forbid an obvious fix, check whether it forbids the specific thing or only the general shape.**
- **A dead comparison keeps a heuristic load-bearing**, and nobody notices until it misfires.
- **A Definition-of-Done step with no artefact gets skipped.**
- **A verdict line can name a method the block has no data for.** Specificity reads as evidence and is not.
- **A cross-reference survives a renumber; the promise it made does not.**
- **This guide once told an agent to do something impossible.** A guide is not exempt from its own traps.
- **"The code is right" and "the coverage is complete" are separate claims.**
- **Fixing a class of defect promotes the next one:** fabricated quotes → arithmetic → missing controls → dropped assertions → stale cross-references → a verdict outrunning its evidence → a missing concurrency guard. **Assume the next failure is one level up, and look there first.**
- **One item = one commit.** **Doc structure rots silently** — append inside the single existing Resolved heading.

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §7, including the over-reach guard.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **`_optionIdFetchesInFlight` added**, marked before the call and cleared in a **`finally`**, and cleared in the teardown path at `game_service.dart:305`.
- [ ] **The fake gained a controllable gate and an invocation counter**, with behaviour **unchanged** when no gate is installed.
- [ ] **The falsifying test observed counting 2 before the fix and 1 after**, with that number recorded in the commit body **and** in a comment on the new test group.
- [ ] **Over-reach guard 1** — a *different* card still fetches during the window (count reaches 2, one per card).
- [ ] **Over-reach guard 2** — a *completed* card still uses the cache and does not refetch.
- [ ] **Wedge check** — a card whose fetch **threw** can be fetched again; this is what proves the `finally`.
- [ ] **`phase3_vote.dart` untouched.** The `build()` call site is an intentional decision (§5).
- [ ] Battery at or above the bar: **0 errors** · **≥144** · clean build · **54/54** · deploy gate exit **0**. **No deploy.**
- [ ] **Queue empty afterwards. Do not invent work** (§3).
