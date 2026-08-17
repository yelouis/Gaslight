# Agent Execution Guide — Queue Complete; one selection pending (Issue 91) — August 17, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved code queue. Do not invent work** (§3).

**Issues 1–90 are delivered, deployed, and independently verified this session** — in source, against the live project, and by re-running the battery. The W-wave (Issues 89 and 90) is **the first wave in this sequence with no correctness residue**: every over-reach guard the spec demanded is present, the security bound is genuinely asserted, the falsification artefact quotes real failure output, and the new callable is **wired into the running app**, not merely parameterised for tests.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (26 warnings, 197 infos — 223 issues) |
| `flutter test` | **144/144** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **54/54** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ — **15/15** functions, `getMyOptionId` deployed `2026-08-17T03:39:04Z` |

**One item is open and needs a `Your selection:` line before anything happens: Issue 91.** It is minor, bounded, and not user-visible — a missing in-flight guard on `fetchMyOptionId`. §2 specs all three branches.

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body **and in an artefact that survives** — a comment in the test file. A step whose only product is a commit-body sentence gets skipped.
- **Never fill in a `Your selection: _____` line.**
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §4 or §5.**

---

## 1. Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`** — it walks vendored plugin source and reports ~678 phantom errors.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way. It also **resolves callables without a realistic in-flight window**, which is why Issue 91 is invisible to the current tests.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** `./scripts/check_deploy_fresh.sh` is the fifth gate; **exit 2 means "could not verify" and must never be reported as a pass**. **Its expected-function list is part of its contract — update it in the same commit that adds or removes a callable**, or it fails on a correct deploy and the next agent learns to ignore it.
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** Re-roll requires the truth phase, which requires 3 active players *and* every non-host ready. Grep the guards before writing a setup.
17. **A cross-reference between assertions goes stale silently.** Repoint inbound references whenever you renumber.
18. **A verdict line and its observation section are two separate claims.**
19. **Grep for comparisons that can never be true.** `card_grid.dart`'s identity clause compared an opaque *option* UUID to a *player* id and was silently false from Issue 63 until Issue 90 — which is how a text heuristic quietly became the only mechanism.
20. **Cards are keyed by their target player's id.** `card.targetPlayerId`, `submitAnswer`'s `targetCardId`, and the `sealed/{cardId}` document id are all the same value.

---

## 2. Issue 91 — `fetchMyOptionId` has no in-flight guard *(blocked on selection)*

**What this means for the user:** nothing visible. It is redundant paid callable invocations, and the fix is three lines using a pattern already in the same file.

### The gap

`fetchMyOptionId` (`game_service.dart:509`) caches by **completion** — `_myOptionIdByCard` is written on success (`:522`) or in the `catch` (`:527`). Between issuing the call and its completion, `containsKey` is still false. The call site sits inside `build()` (`phase3_vote.dart:423`), and `context.watch<GameService>()` rebuilds on every `GameService` change; the vote phase is chatty as `readyPlayers` fills in. **Each rebuild inside the resolution window issues another invocation for the same card.**

The repository already contains the idiom: `final Set<String> _disconnectsInFlight = {}` at `game_service.dart:93`, used at `:405–406` and `:479` to prevent exactly this for `handleDisconnect`.

### Option A — add the in-flight guard

Add `final Set<String> _optionIdFetchesInFlight = {}` beside the cache. In `fetchMyOptionId`, after the `containsKey` early return, return early when the set already holds `cardId`; otherwise add it before the call and remove it in a **`finally`**, so a thrown call cannot wedge the card permanently. Mirror `_disconnectsInFlight` exactly, and clear the set in the teardown path at `:305` alongside `_myOptionIdByCard`.

### Option B — Option A, plus move the fetch out of `build()`

Trigger from `didChangeDependencies` or a post-frame callback when the card changes. `phase3_vote.dart` already tracks card changes via `_lastReaderId` — integrate there rather than adding a second change detector. **Keep the guard from Option A regardless**; moving the call reduces the trigger rate but does not make concurrency impossible.

### Option C — leave it, and record that

Add a comment at `fetchMyOptionId` stating the duplicate-invocation window is known and accepted, so it is not re-filed. **Do not leave it undocumented** — an accepted cost that looks like an oversight gets "fixed" by the next agent without a decision.

### Validation *(A and B)*

**The falsifying assertion:** issue two `fetchMyOptionId` calls for the same card **before the first resolves**, and assert the underlying callable was invoked **exactly once**. This requires a fake that does not resolve immediately (trap 6) — give the `getMyOptionId` branch in `test/fake_functions.dart` a completer the test controls, and count invocations. **Run it against unmodified code and record that it counts two.**

**Two over-reach guards, both required:**
- a fetch for a **different** card during the same window must still go through — a guard keyed too broadly would block it;
- a second fetch **after** the first completes must return the cached value and **not** refetch — proving the guard did not replace the cache.

Battery must stay at or above §0: **0 errors** · **≥144** · clean build · **54/54** · deploy gate exit **0**. **No deploy** — this is client-only.

Commit: `fix(vote): guard against duplicate in-flight option-id fetches`.

---

## 3. Do not invent work · escalation

**Outside Issue 91 there is no queue.** The only legitimate triggers for further work are:

- a defect surfaced by a human playing the game (four of the last five waves came from exactly this, and none from a gate);
- a user-selected issue in `docs/ongoing_general_errors.md`;
- **`ROOM_TTL_MS` dropping below ~4 hours**, which makes a host-only `touchRoom` keepalive plus a client timer mandatory;
- a sibling glyph in the Phosphor font turning out wrong.

**Do not** start a playthrough, refactor, or "improvement" that no one asked for. **Do not** re-verify what §4 records as delivered — it was checked in source this session, not taken from commit messages.

**Bounded deviation:** keep the intent, deviate minimally, note it in the commit body — and record any substitution of deck, device, or fixture.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel, **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** loosen `castVote`'s self-vote rejection to accommodate a client heuristic, and **do not** put another player's option id anywhere the client can read it.

---

## 4. Already delivered — do NOT rework

**Verified in source and against the live project, August 17, 2026, at `9e78c36`:**

- **Issue 90** — self-answer detection is layered. `_mySubmittedByCard` (`game_service.dart:84`) is keyed by card; `isMySubmittedAnswer(cardId, text)` (`:87`); `phase3_vote.dart:428` passes `currentCard.targetPlayerId`. The authority is `getMyOptionId`, wired end to end: `fetchMyOptionId` (`:509`) → `getMyOptionIdForCard` (`:90`) → `phase3_vote.dart:423/425` → `CardGrid.myOptionIdForThisCard` → the repaired identity clause at `card_grid.dart:47`. Tests: cross-card duplicate votable (`phase3_vote_test.dart:166`), same-card distinguished by id (`:265`), fallback on null fetch (`:356`), and server bounds including **`PERMISSION_DENIED` when querying another player's id**.
- **Issue 89** — A4 reads `PASS (backend boundary + client widget mapping) · NOT RUN on device`; `grep -c "Marionette Live Session"` and `grep -c "REQH"` both return **0**. The T1 falsification is recorded with real failure text at `test/in_game_leave_test.dart:212–214`.
- **Issue 88** — `isTimerDisabled` cases on all three phase screens assert the leave button present **and** `AutoAdvanceTimer` absent; `test/phase2_craft_test.dart:213` guards the `resource-exhausted` → SnackBar mapping.
- **Issues 84–87** — dialog contrast (`main.dart:86`, ≥4.5:1 content / ≥3.0:1 title); deck exhaustion at two deck sizes; host kick **with the non-host rejection bound**; readiness gate (`index.ts:264`) **with the host-exemption deadlock guard**; below-3 auto-end (`index.ts:909`) with the 4-player over-reach and lobby exemption.
- **Issues 77–83** — sentinel purge, unmask bounds, full deploy, and the freshness gate whose three exit codes were each exercised deliberately.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 5. Invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`.
- **Never send *other players'* authorship to the client** — **but this does not forbid telling a caller their own.** `getMyOptionId` returns at most one id, only the caller's, over a private callable channel (`design_database_and_security.md` §2). Never return the map; never accept a "whose id do you want" argument.
- **`castVote` rejects only genuine self-votes**, resolved server-side. **Never loosen it to accommodate a client heuristic — and never let the client bound exceed it** (`design_scoring_and_ui.md` §3.2).
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase-specific branches, and computes no scores.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.** No separate kick or quit callable.
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **The exhaustion message is matched on the `resource-exhausted` code**; every other error falls through to the generic string, and **that fall-through is the failure mode**.
- **Re-rolls are unlimited during `truth`, rejected elsewhere, never repeating.** **`seenPrompts` is per-sealed-document, not global.**
- **Who may accuse and who may be accused are two separate bounds.**
- **The deploy gate's three exit codes are a contract**, and so is its expected-function list.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`; 5 is a default, not a cap.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, 90 A-alone/B-alone/C, and the rejected options on 58–66.

---

## 6. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Phase order, 3-player floor, readiness gate, `votes` contract | `design_game_state_and_models.md` |
| **Scoring, reveal beats, unmask bounds, own-answer lockout (§3.2)** | `design_scoring_and_ui.md` |
| **Callable table incl. `getMyOptionId` (§2); deploy & freshness gate (§8); `handleDisconnect`'s callers (§4)** | `design_database_and_security.md` |
| Dialog surface & contrast rule (§6) | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing (§5) | `design_prompt_system.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 7. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the output where it survives.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every game string you quote.

**A verdict line and its observation section are two separate claims.**

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.**

**A clamp is not a rejection. A client-only bound is not a bound — and a client bound *tighter* than the server's is also a defect.**

**Structurally present is not actually wired.** Issue 90's callable was verified this session by tracing `GameService` → screen → widget → comparison, not by reading its tests.

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Four of the last five waves came from a human with three simulators; none came from a gate.

---

## 8. Feedback loop — what past specs got wrong

- **"There is no private channel" was wrong and nearly closed off the right fix.** The authorship invariant is about *other players'* authorship. **When an invariant seems to forbid an obvious fix, check whether it forbids the specific thing or only the general shape.**
- **A dead comparison keeps a heuristic load-bearing**, and nobody notices until it misfires.
- **A Definition-of-Done step with no artefact gets skipped.** The falsification record now lives in a test file, not only a commit body.
- **A verdict line can name a method the block has no data for.** Specificity reads as evidence and is not.
- **A cross-reference survives a renumber; the promise it made does not.**
- **This guide once told an agent to do something impossible.** A guide is not exempt from its own traps.
- **"The code is right" and "the coverage is complete" are separate claims.**
- **The backend keeps being ahead of the client** — missing affordances and unenforced gates are invisible to server tests and source audits alike.
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
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading;
    playthrough observations go to docs/playthrough_findings_marionette.md.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **Issue 91 selection recorded** before any work begins. **If the line is blank: stop and say so.**
- [ ] **Under A or B** — the duplicate-invocation test observed **counting two** before the fix and **one** after; both over-reach guards present (a different card still fetches; a completed card still uses the cache).
- [ ] **Under B** — the fetch fires from a card-change trigger, not from `build()`, **and the guard from A is still present.**
- [ ] **Under C** — the accepted window documented at `fetchMyOptionId`, so it is not re-filed.
- [ ] Battery at or above the bar: **0 errors** · **≥144** · clean build · **54/54** · deploy gate exit **0**. **No deploy required** — Issue 91 is client-only.
- [ ] **Queue empty afterwards. Do not invent work** (§3).
