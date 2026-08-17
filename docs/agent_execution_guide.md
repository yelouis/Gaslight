# Agent Execution Guide — Active Build: V0 (Issue 89, selected); V1 awaiting selection — August 16, 2026

**You are an engineering agent with no memory of this project.**

**What is done, and independently verified in source, against the live project, and by re-running the battery.** Issues 1–88 are delivered and deployed (§5).

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (222 issues) |
| `flutter test` | **141/141** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **53/53** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ |

**What is open:**

| Item | Issue | Selection | Blocked? |
|---|---|---|---|
| **V0.1** — downgrade A4's verdict to what its evidence supports | 89.1 | **Option A** | **No. Do now.** |
| **V0.2** — perform and record the T1 falsification | 89.2 | **Option A** | **No. Do now.** |
| **V1** — self-answer detection blocks legitimate votes | 90 | *awaiting* | **Yes** — four options, specced in §4 so the work is understood before it is chosen. |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **A guard that has never failed has not been tested.** V0.2 is this rule applied to itself.
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
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape. **V1's B-half must be modelled there too, or the widget tests cannot exercise it.**
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** Run `./scripts/check_deploy_fresh.sh` as the fifth gate; **exit 2 means "could not verify" and must never be reported as a pass.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** Re-roll requires the truth phase, which requires 3 active players *and* every non-host ready. Grep the guards before writing a setup.
17. **A cross-reference between assertions goes stale silently.** Repoint inbound references whenever you renumber.
18. **A verdict line and its observation section are two separate claims.**
19. **`ans.authorId` in `card_grid.dart` is an opaque *option* UUID, not a player id.** Comparing it to a player id is always false — that dead comparison at `card_grid.dart:45` is half of Issue 90.

---

## 2. V0.1 — Downgrade A4's verdict *(selected: Issue 89 Option A)*

**What this means for the user:** the evidence record says the deck-exhaustion path was verified in a live session, and contains nothing from a device.

### The gap

`docs/playthrough_findings_marionette.md` A4 reads **`PASS (Verified in Backend Emulator Suite + Client Widget Suite + Marionette Live Session)`** and describes *"consecutive re-rolls on P1 in room `REQH` and `WVFM`."* Its **"What I observed, verbatim"** section holds a backend source citation, a client source citation, and a test pass count — **0 ordered prompts, 0 `grep -cF` mentions, no arithmetic, no device output.**

### Implementation

1. Rewrite the verdict line as:

```markdown
- **Verdict:** PASS (backend boundary + client widget mapping) · **NOT RUN on device**
```

2. **Delete the "Marionette Live Session" clause from the verdict, and delete step 3 of "What I did"** — the room codes and the claimed re-roll sequence. **Do not delete them silently:** add one line stating that a session may have run and its output was not captured, so a future reader does not re-derive the same claim.

3. Keep the backend and widget-test citations. **They are real, they are good, and they are the reason the verdict is still PASS for what it covers.**

4. Add one line stating plainly that **the end-to-end path from a deployed `resource-exhausted` to the rendered SnackBar has not been observed, and that this is accepted rather than queued.**

### Validation

`grep -c "Marionette Live Session" docs/playthrough_findings_marionette.md` → **0**. `grep -c "REQH" docs/playthrough_findings_marionette.md` → **0**. A4's verdict names only methods with data behind them in the same block. **No other assertion's verdict changes.**

Commit: `docs(playthrough): downgrade A4 to the verification its evidence supports`.

---

## 3. V0.2 — Perform and record the T1 falsification *(selected: Issue 89 Option A)*

**What this means for the user:** three tests assert the leave control survives timers being disabled. Nobody has shown those tests can fail, and the three tests that already existed passed throughout the entire defect.

### The gap

The T1 spec required moving the leave `IconButton` from `leading` into `actions`, observing the new case fail and the old one pass, reverting, and recording both. `f0d878b` has a one-line message and no body; `ec3a976` lists changes only. **No commit records the observation.** The tests themselves are correct — `isTimerDisabled: true`, `find.byTooltip('Leave game')` present, `find.byType(AutoAdvanceTimer)` absent, `accessibleNavigation: true`.

### Implementation

1. In `lib/screens/phase2_craft.dart`, temporarily move the leave `IconButton` out of the `AppBar`'s `leading:` and into `actions:`, **inside the existing `state.isTimerDisabled ? const SizedBox.shrink() : …` branch.** A bare move into `actions` does **not** reproduce the regression being guarded against — the point is that the control disappears exactly when timers are off.
2. `flutter test test/in_game_leave_test.dart`.
3. Record **both** outcomes:
   - `Phase2CraftScreen … isTimerDisabled is true` must **fail**;
   - `Phase2CraftScreen renders leave button and confirms leave on tap` must **still pass** — the half that explains why the pre-existing tests never caught this.
4. **Revert.** `git diff` must be empty for `lib/`.
5. **Put the observed failure output where it leaves an artefact**: as a comment at the top of the `isTimerDisabled` group in `test/in_game_leave_test.dart`, *and* in the commit body. A step whose only product is a commit-body sentence is what got skipped last time.

**If the timer-disabled case passes with the button moved, STOP** — the fixture is not reaching the timer-disabled branch and the tests prove nothing.

### Validation

`flutter test` back at **141/141**. `git status --short` clean for `lib/`. The comment block quotes the real failure text, not a paraphrase.

Commit: `test(game): record the falsification run for the timer-disabled leave guard`.

---

## 4. V1 — Issue 90: self-answer detection *(blocked on selection)*

**What this means for the user:** options written by other players are being greyed out and made **untappable**, so a player's vote can be forced. In the reported case two of three options were blocked.

### The gap

`_mySubmittedAnswers` (`game_service.dart:84`) is a flat `Set<String>` of trimmed **text**, populated on every submit (`:483`) and cleared only in the teardown path (`:300`) — **it accumulates across every card and every round.** `isMySubmittedAnswer` (`:86`) is pure text membership. `phase3_vote.dart:422` feeds it into `isSelfAnswer`; `card_grid.dart:51` makes a flagged option untappable; and `card_grid.dart:45`'s identity clause `ans.authorId == currentPlayerId` is **dead**, because `authorId` is the opaque option UUID (trap 19). **The text heuristic is the only mechanism doing this job.**

Cross-card duplicates are legitimate: `isTooSimilar` (`index.ts:478`) only compares against the **same card's** answers.

**The server bound is correct and must not be touched.** `castVote` resolves the option through `sealedData.answerAuthors` and rejects only genuine self-votes (`index.ts:572`).

### The A-half — scope the record to the card *(in Options A and D)*

**Do not "clear the set on transition."** A player writes their forgery for card X during the forgery rotation and votes on card X later; a periodic clear would drop the very entry that is needed. **Key the record by card instead:**

1. Replace `final Set<String> _mySubmittedAnswers = {}` with a per-card map, e.g. `final Map<String, Set<String>> _mySubmittedByCard = {}`.
2. `submitCardAnswer` (`game_service.dart:480`) already receives `targetCardId` — record under that key rather than in a flat set.
3. Change the accessor to take the card: `bool isMySubmittedAnswer(String cardId, String text)`.
4. `phase3_vote.dart:422` passes the card being voted on — `currentTargetId`, already in scope on that screen.
5. Clear the map in the same teardown path at `:300`.

### The B-half — identify by option id *(in Options B and D)*

**This was wrongly described as blocked in the previous guide. It is not.** The invariant is *never send **other players'** authorship to the client*; telling a player which opaque id is **their own** reveals nothing they do not already know. A callable's response goes to exactly one authenticated caller and is a legitimate private channel.

1. **New callable `getMyOptionId(roomCode, cardId, playerId)` in `functions/src/index.ts`.** Verify the caller owns that player document **exactly as `castVote` does** (`index.ts:548` — read the player doc, compare `authUid` to `request.auth.uid`, throw `permission-denied` otherwise). Read `sealed/{cardId}`, find the entry in `answerAuthors` whose **value** equals `playerId`, and return its **key**. Return `null` when the caller authored nothing on that card. **No rules change** — the sealed document stays default-deny and is read server-side, exactly as `castVote` already reads it.
2. **It must return at most one id, and only the caller's.** Never return the map, never return another player's entry, never accept an arbitrary "whose id do you want" argument.
3. **Client:** a `GameService` method that calls it once per card on entering the vote phase, caching the result per `cardId`.
4. **`card_grid.dart:45`:** replace the dead `ans.authorId == currentPlayerId` with a comparison against the fetched option id for this card — **option id to option id**, which is what that clause was always trying to express.
5. **Model it in `test/fake_functions.dart`** (trap 6) or the widget tests cannot exercise it.

### Layering, if Option D is selected

**B is the authority; A is the fallback.** The grid renders before a network call resolves, and the call can fail. Grey out by option id when it is known; fall back to **current-card** text when it is not. **Ship them as two commits** — A first (client-only, no deploy), then B (callable plus deploy).

**Name the failure mode explicitly in the fallback:** with no id and no fallback, a player can tap their own answer and be rejected by the server — correct but confusing; or, if everything is blocked, they cannot vote at all.

### Validation *(required under every option)*

**The falsifying assertion.** A widget test in which the player submitted `"asdf"` for a **previous** card, and the current card's options include `"asdf"` authored by someone else. Assert the option is **votable** (`onTap` non-null) and **not** labelled `(Your Forgery)`. **Run it against today's code and observe it fail.**

**The over-reach guard, in the same test.** An option the player genuinely wrote **for the current card** must still be blocked and labelled. **A fix that simply deletes the flagging would otherwise pass**, and that is the most likely wrong fix here.

**Under B or D, add a server test:** the caller receives their own option id; a caller who authored nothing on that card receives `null`; and **a caller cannot obtain another player's option id** — matched on `permission-denied` by code, never message (trap 12). That third assertion is the security bound.

**Blast radius:** `lib/services/game_service.dart`, `lib/screens/phase3_vote.dart`, `lib/widgets/card_grid.dart`, plus tests; under B or D also `functions/src/index.ts`, `test/fake_functions.dart`, and a deploy. **Remove or repair the dead identity clause at `card_grid.dart:45` in whichever commit touches it** — it currently reads as though identity checking happens when nothing does.

---

## 5. Already delivered — do NOT rework

**Verified in source and against the live project, August 16, 2026, at `f0d878b`:**

- **Issue 88.2** — `test/in_game_leave_test.dart` covers all three phase screens with `isTimerDisabled: true`, asserting the leave button present and `AutoAdvanceTimer` absent. *(V0.2 supplies the missing falsification record, not new tests.)*
- **Issue 88.1 (partial)** — `test/phase2_craft_test.dart:213` stubs `FirebaseFunctionsException(code: 'resource-exhausted')` and asserts the SnackBar text. **Keep it** — it guards the branch that degrades silently, since `phase2_craft.dart:543` otherwise falls through to `'Something went wrong. Try again.'`
- **Issue 84** — `DialogThemeData` at `main.dart:86`; contrast test asserts ≥4.5:1 content and ≥3.0:1 title.
- **Issue 83 (Option C)** — `game_e2e.spec.ts:1959`, parameterised over both deck sizes with the per-player isolation guard.
- **Issue 87** — host kick succeeds **and** a non-host kicking a third player is rejected.
- **Issue 86** — `index.ts:264` filters `!p.isHost && p.lobbyReady !== true`; the test asserts the host's own `lobbyReady` is not true before proving the start succeeds.
- **Issue 85** — `index.ts:909` applies the below-3 rule **after** the phase branches; three tests cover auto-end, the 4-player over-reach, and the lobby exemption.
- **Issues 77–82** — sentinel purge, unmask bounds, full deploy, and the freshness gate whose three exit codes were each exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 6. Invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.**
- **Never send *other players'* authorship to the client.** **This does not forbid telling a caller their own** — see V1's B-half. Option ids stay opaque in the room document; `answerAuthors` stays in the default-deny sealed document and is read server-side only.
- **`castVote` rejects only genuine self-votes**, resolved server-side. Never loosen it to accommodate a client heuristic.
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and wins over the phase-specific branches.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.**
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **The exhaustion message is matched on the `resource-exhausted` code**; every other error falls through to the generic string, and **that fall-through is the failure mode** (`design_prompt_system.md` §5).
- **Re-rolls are unlimited during `truth`, rejected elsewhere, and never repeat.** **`seenPrompts` is per-sealed-document, not global.**
- **Who may accuse and who may be accused are two separate bounds.**
- **The deploy gate's three exit codes are a contract.**
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Leaving a room does not call `Navigator` explicitly.**
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, **89 B/C**, and the rejected options on 58–66.

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
| Deck catalogue, re-roll exclusion, exhaustion plumbing (§5) | `design_prompt_system.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 8. Do not invent work · escalation

Outside V0 and V1 there is no queue. Legitimate triggers: a defect V1 surfaces, a user-selected issue, or the TTL interval dropping below ~4 hours.

**Bounded deviation:** keep the intent, deviate minimally, note it in the commit body — **and record any substitution of deck, device or fixture.**

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel, **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** loosen `castVote`'s self-vote rejection to accommodate the client, and **do not** put another player's option id anywhere the client can read it.

---

## 9. Validation standard

**Write validation that fails against the broken state, and observe it fail.** V0.2 is this rule applied to itself.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.**

**A verdict line and its observation section are two separate claims.**

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.** **A clamp is not a rejection. A client-only bound is not a bound** — **and its mirror image: a client bound that is *tighter* than the server's is also a defect.** Issue 90 is the first instance of that direction in this project.

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Every defect in the last four waves came from a human with three simulators, not from a gate.

---

## 10. Feedback loop — what past specs got wrong

- **"There is no private channel" was wrong, and it nearly closed off the right fix.** Issue 90 Option B was written off as blocked because authorship must never reach the client. **The invariant is about *other players'* authorship**; a callable returning the caller's own option id leaks nothing. **When an invariant seems to forbid an obvious fix, check whether it forbids the specific thing or only the general shape.**
- **A verdict line can name a method the block has no data for.** Specificity — two room codes — reads as evidence and is not.
- **A Definition-of-Done step with no artefact gets skipped.** The T1 falsification left nothing behind, so nothing recorded its absence. V0.2 now names the file the output goes in.
- **A dead comparison keeps a heuristic load-bearing.** `card_grid.dart:45`'s identity check has been false since Issue 63, so text matching quietly became the only mechanism — and nobody noticed until it misfired.
- **A cross-reference survives a renumber; the promise it made does not.**
- **This guide once told an agent to do something impossible** (a one-device re-roll session). A guide is not exempt from its own traps.
- **"The code is right" and "the coverage is complete" are separate claims.**
- **The backend keeps being ahead of the client**, and **fixing a class of defect promotes the next one**: fabricated quotes → arithmetic → missing controls → dropped assertions → stale cross-references → a verdict outrunning its evidence.
- **One item = one commit.** **Doc structure rots silently.**

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

- [ ] **V0.1** — `grep -c "Marionette Live Session"` and `grep -c "REQH"` both return **0**; A4's verdict reads `PASS (backend boundary + client widget mapping) · NOT RUN on device`; the lost-output note is present; no other verdict changed.
- [ ] **V0.2** — the timer-disabled case **observed failing** with the leave button moved *into the `isTimerDisabled` branch of* `actions`, the timers-enabled case observed **still passing**, the move reverted, and the real failure text recorded **both** in `test/in_game_leave_test.dart` and in the commit body.
- [ ] **V0.2** — `git status --short` clean for `lib/`; `flutter test` back at **141/141**.
- [ ] **Issue 90 selection recorded** before V1 begins.
- [ ] **V1** — the falsifying widget test (previous-card text, other author) observed **failing** first; the over-reach guard (same-card own answer still blocked) present in the same test.
- [ ] **V1 under B or D** — server test covers own id returned, `null` when nothing authored, and **another player's id unobtainable** (`permission-denied` by code). `test/fake_functions.dart` models the callable.
- [ ] **V1** — the dead identity clause at `card_grid.dart:45` removed or repaired.
- [ ] Battery at or above the bar: **0 errors** · **≥141** · clean build · **53/53** (or higher under B/D) · deploy gate exit **0**.
