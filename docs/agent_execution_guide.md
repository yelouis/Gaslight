# Agent Execution Guide — Active Build: Y1 → Y3; Issue 92 still awaiting selection — August 17, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–91 are delivered, deployed, and independently verified** (§5). Battery at `3ee34fe`:

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (26 warnings, 196 infos) |
| `flutter test` | **147/147** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **54/54** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — 15/15 functions |

**What this build does.** Three items from a manual three-simulator session, all selected as Option A. **All are client-only — no deploy.**

| # | Item | Issue | Why it matters |
|---|---|---|---|
| **Y1** | Make the option id a true authority, and stop accumulating superseded text | 94 | **Correctness.** Two tiles get sealed, the vote is forced, and `(Your Forgery)` is asserted about another player's answer. |
| **Y2** | Map join errors to sentences instead of dumping the exception | 93 | A failed join renders ~20 lines of stack trace into the Guest Ledger. |
| **Y3** | Busy state on `CREATE ROOM` and `JOIN ROOM` | 95 | The app looks inert at the first interaction, and `createRoom` is **not idempotent**. |

**⚠️ Issue 92 is still open and its `Your selection:` line is blank.** Do not start it, and do not fill the line. It is summarised in §4 so you know why the in-flight guard's test is not to be trusted.

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** — **and apply that to the test itself**: remove the guard, watch the test go red. Issue 92 is the cost of skipping it.
- Record the failure output in the commit body **and in an artefact that survives** — a comment in the test file.
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
6. **`test/fake_functions.dart` models the server's error shape** and carries a **controllable gate plus invocation counter** for `getMyOptionId` — the pattern Y3's over-reach guard reuses. Behaviour must stay unchanged when no gate is installed.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** All three items need it.
8. **`firebase.json`'s `predeploy` runs the test suite.** Gates `--only functions`, **not** `--only firestore:rules`. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** `./scripts/check_deploy_fresh.sh` is the fifth gate; **exit 2 is "could not verify", never a pass.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** Grep the guards first.
17. **A cross-reference between assertions goes stale silently.**
18. **A verdict line and its observation section are two separate claims.**
19. **Grep for comparisons that can never be true.**
20. **Cards are keyed by their target player's id.**
21. **A test can use the wrong fixture and still read as correct** — Issue 92.1 throws on `card_a` and asserts on `card_b`. Check that a test's subject is the thing the spec named.
22. **Check what a widget already offers before adding to it.** `PrimaryButton` already has `loading` and `showTextOnLoading`, already used twice — an earlier draft of Issue 95 claimed it had none and specced a shared-widget change that is not needed.

---

## 2. Y1 — Issue 94: the option id must override the heuristic, not merely add to it

**What this means for the user:** two of three options get greyed out and made untappable, so the vote is effectively chosen for them — and one of those tiles says `(Your Forgery)` about an answer somebody else wrote.

### The gap

**`getMyOptionId` returns at most one id**, so the id path can flag at most one tile. A second sealed tile can only come from the text path. Two defects combine:

**94.1 — the layers are unioned.** `card_grid.dart:47`:

```dart
final isSelfAnswer = ans.isSelfAnswer || (myOptionIdForThisCard != null && ans.authorId == myOptionIdForThisCard);
```

The design is *"the id is the authority, text is the fallback"* (`design_scoring_and_ui.md` §3.2 — **which already documents the ordered behaviour the code does not implement**). As written, the authority can **add** a tile to the blocked set but can never **remove** one the heuristic wrongly added.

**94.2 — the per-card record accumulates superseded text.** `game_service.dart:490`:

```dart
_mySubmittedByCard.putIfAbsent(targetCardId, () => {}).add(text.trim());
```

A `Set` that only grows, while the server keeps **only the latest** per author (`index.ts:521`: `{ ...existing, [authorId]: text }`). Resubmitting for the same card leaves the client believing both texts are its own; the superseded one is then free to match another player's answer.

### Implementation

1. **`lib/widgets/card_grid.dart:47`** — make it an ordered choice:

```dart
        final isSelfAnswer = myOptionIdForThisCard != null
            ? ans.authorId == myOptionIdForThisCard
            : ans.isSelfAnswer;
```

**The `||` must go.** When the authoritative id is known it is the *only* input; `ans.isSelfAnswer` is consulted **only** when the id is null.

2. **`lib/services/game_service.dart:490`** — keep only the latest submission for that card, mirroring the server's overwrite:

```dart
      _mySubmittedByCard[targetCardId] = {text.trim()};
```

The value stays a `Set` so the accessor at `:87` is untouched; it simply never holds more than the current answer for a card. **Do not change `isMySubmittedAnswer`'s signature** — Issue 90's per-card keying is correct and is not what failed.

**Do not touch `phase3_vote.dart`.** Its `isSelf` computation at `:428` stays as-is; the ordering now happens in `CardGrid`, which is where the id lives.

### Validation

**The falsifying assertion.** A widget test in which the player submits `"asdf"` and then `"asdfw4er"` **for the same card**, `getMyOptionId` resolves to the `"asdfw4er"` option, and a **different** player's option on that card carries `"asdf"`. Assert **only** the id-matched tile is blocked and labelled, and that the `"asdf"` tile's `onTap` is **non-null**. **Run it against today's code and record that two tiles are blocked.**

**Over-reach guard 1 — the load-bearing one.** With `myOptionIdForThisCard` **null**, the player's own *current* text must **still** be blocked. A fix that simply stopped consulting text passes the main assertion and fails this.

**Over-reach guard 2.** With the id resolved, the player's own answer must **still** be blocked — proving the ordered branch did not stop blocking altogether.

Battery: `flutter test` **≥150**.

### Blast radius

`lib/widgets/card_grid.dart`, `lib/services/game_service.dart`, plus tests. Client-only. **Re-read `design_scoring_and_ui.md` §3.2 afterwards and confirm the code now matches what it already claims** — no doc edit should be needed.

Commit: `fix(vote): let the option id override the text heuristic, not add to it`.

---

## 3. Y2 — Issue 93: map join errors to sentences

**What this means for the user:** mistyping a room code — the single most likely error in the app — produces twenty lines of `pigeon/messages.pigeon.dart` stack trace inside the Guest Ledger card.

### The gap

`lobby_screen.dart:206`:

```dart
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
```

`$e` on a `FirebaseFunctionsException` stringifies to message **plus** stack trace.

### Implementation

**`joinRoom` throws exactly three codes** (`index.ts:142–229`, enumerated from source — do not guess, and re-grep before writing the map):

| Code | Message |
|---|---|
| `not-found` | `No room with that code. Check the four letters and try again.` |
| `invalid-argument` | `Enter your name and a four-letter room code.` |
| `unauthenticated` | `Could not sign in. Check your connection and try again.` |
| anything else | `Something went wrong. Try again.` |

Follow the established shape at `phase2_craft.dart:543` — test `e is FirebaseFunctionsException && e.code == …`, and **never interpolate `e` into user-facing text.**

### Validation

**The falsifying assertion, and the negative half is the one that pins it.** A widget test where `joinRoom` throws `FirebaseFunctionsException(code: 'not-found')`, asserting:

1. the SnackBar shows the mapped sentence; **and**
2. the rendered text **does not contain** `pigeon` **or** `#0`.

**Assertion 1 alone would pass while the trace is still displayed beneath it.** Run against today's code and record that assertion 2 fails.

**Over-reach guard:** an unmapped code (e.g. `internal`) must produce the generic string, not an empty SnackBar and not the raw exception.

### Blast radius

`lib/screens/lobby_screen.dart`, plus a test. **Grep for other `Text('Error: $e')` sites while you are here** — if any exist, note them in the commit body; **do not fix them in this commit** (that was Option C, not selected).

Commit: `fix(lobby): show a readable message when a room cannot be joined`.

---

## 4. Y3 — Issue 95: busy state on CREATE ROOM and JOIN ROOM

**What this means for the user:** the first thing they ever tap gives no feedback, and a second tap can create a second room — `createRoom` is **not idempotent**.

### The gap

`lobby_screen.dart` has one busy flag, `_isStartingGame` (`:46`), used only by START GAME (`:950–965`). Neither `CREATE ROOM` nor `JOIN ROOM` has one.

**`PrimaryButton` already supports this.** `shared_ui.dart:90` declares `final bool loading` and `final bool showTextOnLoading`, and its state class drives `_loadingController` from them. **Two call sites already use it** — `phase2_craft.dart:500` (`loading: _isSubmitting`) and `game_over_screen.dart:281` (`loading: _isSharing`). **Copy that; do not modify the widget** (trap 22).

### Implementation

1. Add `bool _isCreatingRoom = false;` and `bool _isJoiningRoom = false;` beside `_isStartingGame` (`:46`).
2. In `_createRoom` and `_joinRoom`, set the flag before the callable and clear it in a **`finally`** — a thrown call must not leave the button permanently disabled. `_isStartingGame`'s existing shape at `:950–965` is the model.
3. Pass `loading: _isCreatingRoom` / `loading: _isJoiningRoom` to the respective buttons, and **disable `onPressed` while busy** — pass `null`, matching how `_isStartingGame` gates START GAME. That disabling *is* the double-tap guard.
4. Y2 lands first, so `_joinRoom`'s `catch` already exists; put the flag clearing in a `finally` **beside** it, not inside it.

### Validation

**The falsifying assertion.** A widget test that taps `CREATE ROOM` against a callable held open by a completer (the gate pattern already in `test/fake_functions.dart`), asserting the button reports `loading == true` and its `onPressed` is `null` while in flight, and both are restored after the completer resolves.

**Over-reach guard — the one that matters, because `createRoom` is not idempotent.** A **second tap during the in-flight window must not issue a second `createRoom` call.** Assert an invocation count of exactly **1**, using the counter pattern `fake_functions.dart` already has for `getMyOptionId`.

**Second over-reach guard:** after a **failed** call, the button must be re-enabled — this is what proves the `finally`. Remove the `finally` and confirm this assertion fails.

Battery: `flutter test` **≥153**.

### Blast radius

`lib/screens/lobby_screen.dart`, `test/fake_functions.dart` (a counter for `createRoom`), plus tests. **`shared_ui.dart` is not modified.**

Commit: `feat(lobby): show a busy state while creating or joining a room`.

---

## 5. Issue 92 — blocked, and why you should not trust the in-flight guard's test

**Do not start this. The selection line is blank.**

Issue 91's guard (`_optionIdFetchesInFlight`) is correct and correctly placed. **Its regression test is not:** `test/fetch_my_option_id_test.dart:148` throws on `card_a` and then fetches `card_b`, which was never in the in-flight set — so the assertion holds with or without the `finally`. **Demonstrated: deleting the `finally` outright leaves all three tests passing.**

X1 also removed `_myOptionIdByCard[cardId] = null` from the `catch`, so a failed fetch is no longer cached and retries once per rebuild — raising invocations above the pre-X1 code in the persistent-failure path.

**The coupling is the decision:** if failures are cached, the `finally` is unobservable through the public API and no test can reach it; if they are not, it is load-bearing and testable. Options A/B/C are filed. **If you touch `fetchMyOptionId` for any other reason, do not "tidy" either behaviour — they are the subject of an open decision.**

---

## 6. Already delivered — do NOT rework

**Verified in source and against the live project, August 17, 2026:**

- **Issue 91** — `_optionIdFetchesInFlight` (`game_service.dart:86`), marked at `:517`, cleared in a `finally` at `:532–534` and in teardown at `:307`. **The guard is correct; only its test and retry semantics are open (§5).**
- **Issue 90** — per-card keying (`_mySubmittedByCard`) and `getMyOptionId` wired end to end. **The keying is correct; the *layering* is Y1's subject.**
- **Issue 89** — A4 downgraded to `PASS (backend boundary + client widget mapping) · NOT RUN on device`; T1 falsification recorded with real failure text.
- **Issue 88** — `isTimerDisabled` cases assert leave button present **and** `AutoAdvanceTimer` absent; `phase2_craft_test.dart:213` guards the `resource-exhausted` → SnackBar mapping.
- **Issues 84–87** — dialog contrast (≥4.5:1 / ≥3.0:1); deck exhaustion at two deck sizes; host kick **with the non-host rejection bound**; readiness gate **with the host-exemption deadlock guard**; below-3 auto-end with its two guards.
- **Issues 77–83** — sentinel purge, unmask bounds, full deploy, freshness gate with all three exit codes exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 7. Invariants & intentional decisions — do NOT change

- **`fetchMyOptionId` is called from `build()` on purpose.** Issue 91 Option B was declined. **Do not relocate the call.**
- **`votes` maps `voterId` → resolved author id. There is no sentinel.**
- **Never send *other players'* authorship to the client** — but this does not forbid telling a caller their own (`design_database_and_security.md` §2).
- **`castVote` rejects only genuine self-votes.** **Never loosen it — and never let the client bound exceed it.** Y1 exists because the client bound was wider than the server's.
- **The readiness gate exempts the host deliberately.** Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase branches, computes no scores.
- **`handleDisconnect` has exactly three legitimate callers.** **A non-host acting on a third player stays rejected with `permission-denied`.**
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**.
- **The exhaustion message is matched on the `resource-exhausted` code**; the generic fall-through is the failure mode.
- **Re-rolls are unlimited during `truth`, rejected elsewhere, never repeating.** **`seenPrompts` is per-sealed-document.**
- **The deploy gate's three exit codes are a contract**, and so is its expected-function list.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, 90 A-alone/B-alone/C, 91 B/C, **93 B/C, 94 B/C, 95 B/C**, and the rejected options on 58–66.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Phase order, 3-player floor, readiness gate, `votes` contract | `design_game_state_and_models.md` |
| **Scoring, reveal beats, unmask bounds, own-answer lockout (§3.2)** | `design_scoring_and_ui.md` |
| Callable table incl. `getMyOptionId` (§2); deploy & freshness gate (§8); `handleDisconnect`'s callers (§4) | `design_database_and_security.md` |
| Dialog surface & contrast rule (§6) | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing (§5) | `design_prompt_system.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 9. Validation standard

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.**

**Assert the negative as well as the positive.** Y2's "the text does not contain `pigeon`" is the assertion that pins the defect; the friendly sentence alone would pass with the trace still on screen.

**A test harness that cannot express the bug will pass against it.**

**Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.**

**A check that cannot run must say so, not pass.**

**A clamp is not a rejection. A client-only bound is not a bound — and a client bound *tighter* than the server's is also a defect.**

**Structurally present is not actually wired.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Every defect in the last five waves came from a human with three simulators; none came from a gate.

---

## 10. Feedback loop — what past specs got wrong

- **A layered fix must be ordered, not unioned.** Y1's whole defect is `||` where the design said "authority, then fallback". **When a spec says one input supersedes another, the code must be able to say *no* — not merely *also yes*.**
- **Check what a component already offers before specifying an addition.** Issue 95 was filed claiming `PrimaryButton` had no loading state; it has one, used twice. The spec shrank by most of its size once that was checked.
- **Enumerate error codes from source, never from expectation.** Issue 93 originally speculated about `failed-precondition` and `permission-denied` on the join path; `joinRoom` throws neither.
- **A test can satisfy a spec's words while testing nothing** (Issue 92.1).
- **A fix can change behaviour it was not asked to change** (Issue 92.2). **Diff the whole method, not only the lines you meant to add.**
- **A guard and a cache are different things.**
- **"There is no private channel" was wrong and nearly closed off the right fix.**
- **A dead comparison keeps a heuristic load-bearing.**
- **A Definition-of-Done step with no artefact gets skipped.**
- **"The code is right" and "the coverage is complete" are separate claims.**
- **Fixing a class of defect promotes the next one:** fabricated quotes → arithmetic → missing controls → dropped assertions → stale cross-references → a verdict outrunning its evidence → a missing concurrency guard → a guard whose test cannot fail → **a fix wired so it cannot win.**
- **One item = one commit.** **Doc structure rots silently.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §9 — including removing the guard to prove the test can fail.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **Y1** — `card_grid.dart:47` is an ordered choice with **no `||`**; `_mySubmittedByCard[cardId]` holds only the latest submission. Falsifying test observed blocking **two** tiles before the fix and **one** after.
- [ ] **Y1 guards** — with the id `null`, the player's own current text is **still blocked**; with the id resolved, the player's own answer is **still blocked**.
- [ ] **Y2** — three codes mapped; the test asserts the mapped sentence **and** that the output contains neither `pigeon` nor `#0`, with the negative observed failing first. Unmapped codes give the generic string.
- [ ] **Y3** — `_isCreatingRoom` / `_isJoiningRoom` cleared in a **`finally`**; `loading:` passed to both buttons; **`shared_ui.dart` unmodified.**
- [ ] **Y3 guards** — a second tap in flight issues **exactly one** `createRoom`; a failed call leaves the button re-enabled, observed failing with the `finally` removed.
- [ ] **`phase3_vote.dart` untouched** by Y1.
- [ ] **Issue 92 untouched**, its selection line still blank.
- [ ] Battery at or above the bar: **0 errors** · **≥153** · clean build · **54/54** · deploy gate exit **0**. **No deploy** — all three are client-only.
