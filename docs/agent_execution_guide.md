# Agent Execution Guide — Active Build: W1 → W5 — August 16, 2026

**You are an engineering agent with no memory of this project.**

**What is done, and independently verified in source, against the live project, and by re-running the battery.** Issues 1–88 are delivered and deployed (§7).

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (222 issues) |
| `flutter test` | **141/141** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **53/53** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ |

**What this build does.** Both open issues are selected and the queue is fully determined.

| # | Item | Issue | Selection | Touches |
|---|---|---|---|---|
| **W1** | Downgrade A4's verdict to what its evidence supports | 89.1 | Option A | docs |
| **W2** | Perform and record the T1 falsification | 89.2 | Option A | tests |
| **W3** | Self-answer detection — the **A-half**: key the record by card | 90 | **Option D** | client |
| **W4** | Self-answer detection — the **B-half**: identify by option id | 90 | **Option D** | client + **server** |
| **W5** | Deploy W4 and verify | — | — | production |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.** W3 and W4 are two commits, deliberately — see §2.
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body.
- **A guard that has never failed has not been tested.** W2 is this rule applied to itself.
- **A verdict line must not name a verification method the block records no data for.**
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §7 or §8.**

---

## 1. Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way. **W4 must add a branch there or the widget tests cannot exercise the callable.**
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.**
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.** `./scripts/check_deploy_fresh.sh` is the fifth gate; **exit 2 means "could not verify" and must never be reported as a pass.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** Grep the guards before writing a setup.
17. **A cross-reference between assertions goes stale silently.**
18. **A verdict line and its observation section are two separate claims.**
19. **`ans.authorId` in `card_grid.dart` is an opaque *option* UUID, not a player id.** Comparing it to a player id is always false — that dead comparison at `card_grid.dart:45` is half of Issue 90, and **W4 is what finally makes it mean something.**
20. **Cards are keyed by their target player's id.** `card.targetPlayerId`, the `submitAnswer` `targetCardId` argument, and the `sealed/{cardId}` document id are all **the same value**. W3 and W4 both depend on this.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| **W1** | A4 verdict | Docs-only, independent, and it stops the record overstating today. Cheap to do first. |
| **W2** | T1 falsification | Independent of everything else; touches only test files and reverts its own probe. |
| **W3** | Issue 90 A-half | **Before W4.** It alone kills the reported bug with no deploy, and W4's fallback path *is* W3 — the authority cannot layer on a fallback that does not exist yet. |
| **W4** | Issue 90 B-half | After W3. Client + server. |
| **W5** | Deploy | One deploy for W4. Never deploy mid-build with the callable live and no client calling it, or vice versa. |

---

## 3. W1 — Downgrade A4's verdict *(Issue 89, Option A)*

**What this means for the user:** the evidence record says the deck-exhaustion path was verified in a live session, and contains nothing from a device.

### The gap

`docs/playthrough_findings_marionette.md` A4 reads **`PASS (Verified in Backend Emulator Suite + Client Widget Suite + Marionette Live Session)`** and describes *"consecutive re-rolls on P1 in room `REQH` and `WVFM`."* Its **"What I observed, verbatim"** section holds a backend source citation, a client source citation, and a test pass count — **0 ordered prompts, 0 `grep -cF` mentions, no arithmetic, no device output.**

### Implementation

1. Rewrite the verdict as:

```markdown
- **Verdict:** PASS (backend boundary + client widget mapping) · **NOT RUN on device**
```

2. **Delete the "Marionette Live Session" clause and step 3 of "What I did"** — the room codes and the claimed re-roll sequence. **Not silently:** add one line noting that a session may have run and its output was not captured, so a future reader does not re-derive the same claim from the same absence.
3. **Keep the backend and widget-test citations.** They are real and they are why the verdict is still PASS for what it covers.
4. State plainly that the end-to-end path from a deployed `resource-exhausted` to the rendered SnackBar **has not been observed, and that this is accepted rather than queued.**

### Validation

`grep -c "Marionette Live Session"` → **0**. `grep -c "REQH"` → **0**. A4's verdict names only methods with data behind them in the same block. **No other assertion's verdict changes.**

Commit: `docs(playthrough): downgrade A4 to the verification its evidence supports`.

---

## 4. W2 — Perform and record the T1 falsification *(Issue 89, Option A)*

**What this means for the user:** three tests assert the leave control survives timers being disabled. Nobody has shown those tests can fail, and the three tests that already existed passed throughout the entire defect.

### The gap

The spec required moving the leave `IconButton` from `leading` into `actions`, observing the new case fail and the old one pass, reverting, and recording both. `f0d878b` has a one-line message and no body; `ec3a976` lists changes only. **No commit records the observation.** The tests themselves are correct.

### Implementation

1. In `lib/screens/phase2_craft.dart`, temporarily move the leave `IconButton` out of the `AppBar`'s `leading:` and into `actions:`, **inside the existing `state.isTimerDisabled ? const SizedBox.shrink() : …` branch.** A bare move into `actions` does **not** reproduce the regression — the point is that the control vanishes exactly when timers are off.
2. `flutter test test/in_game_leave_test.dart`.
3. Record **both** outcomes:
   - `Phase2CraftScreen … isTimerDisabled is true` must **fail**;
   - `Phase2CraftScreen renders leave button and confirms leave on tap` must **still pass** — the half that explains why the pre-existing tests never caught this.
4. **Revert.** `git diff` must be empty for `lib/`.
5. **Put the real failure output where it leaves an artefact:** a comment at the top of the `isTimerDisabled` group in `test/in_game_leave_test.dart`, **and** in the commit body. A step whose only product is a commit-body sentence is exactly what got skipped last time.

**If the timer-disabled case passes with the button moved, STOP** — the fixture is not reaching the timer-disabled branch and the tests prove nothing.

### Validation

`flutter test` back at **141/141**. `git status --short` clean for `lib/`. The comment quotes the real failure text, not a paraphrase.

Commit: `test(game): record the falsification run for the timer-disabled leave guard`.

---

## 5. W3 — Issue 90, the A-half: key the record by card

**What this means for the user:** options written by other players are greyed out and **untappable**, so a player's vote can be forced. In the reported case two of three options were blocked, leaving exactly one.

### The gap

`_mySubmittedAnswers` (`game_service.dart:84`) is a flat `Set<String>` of trimmed **text**, populated on every submit (`:483`) and cleared only in the teardown path (`:300`) — **it accumulates across every card and every round.** `isMySubmittedAnswer` (`:86`) is pure text membership. `phase3_vote.dart:422` feeds it into `isSelfAnswer`, and `card_grid.dart:51` makes a flagged option untappable.

Cross-card duplicates are legitimate: `isTooSimilar` (`index.ts:478`) only compares against the **same card's** answers, so two prompts drawing the same short answer is ordinary play.

**The server bound is correct and must not be touched.** `castVote` resolves the option through `sealedData.answerAuthors` and rejects only genuine self-votes (`index.ts:572`).

### Implementation

**Do not "clear the set on transition."** A player writes their forgery for card X during the forgery rotation and votes on card X later; a periodic clear would drop the very entry that is needed. **Key the record by card.**

1. **`lib/services/game_service.dart:84`** — replace the flat set with a per-card map:

```dart
  final Map<String, Set<String>> _mySubmittedByCard = {};
```

2. **`:86`** — the accessor takes the card:

```dart
  bool isMySubmittedAnswer(String cardId, String text) =>
      _mySubmittedByCard[cardId]?.contains(text.trim()) ?? false;
```

3. **`:483`, inside `submitCardAnswer(targetCardId, authorId, text, isTruth)`** — record under the card key. The method **already receives `targetCardId`**; use it rather than adding a parameter.

4. **`:300`** — clear the map in the same teardown path, beside `_gameState = null`.

5. **`lib/screens/phase3_vote.dart:422`** — pass the card being voted on. `currentCard` is in scope where `gridAnswers` is built and is non-null inside the `.map`:

```dart
      final isSelf = gs.isMySubmittedAnswer(currentCard.targetPlayerId, opt.text);
```

**Cards are keyed by their target player's id** (trap 20), so `card.targetPlayerId` is the same value `submitCardAnswer` received as `targetCardId`. Re-grep both call sites and confirm they agree before committing — if they disagree, nothing is flagged and the bug inverts into "you can vote for your own answer".

### Validation

**The falsifying assertion.** A widget test where the player submitted `"asdf"` for a **previous** card, and the current card's options include `"asdf"` authored by someone else. Assert the option is **votable** (`onTap` non-null) and **not** labelled `(Your Forgery)`. **Run it against unmodified code and record that it fails.**

**The over-reach guard, in the same test.** An option the player genuinely wrote **for the current card** must still be blocked and labelled. **A fix that simply deletes the flagging would otherwise pass**, and that is the most likely wrong fix here.

Set `accessibleNavigation: true` (trap 7). Battery: `flutter test` **≥143**.

### Blast radius

`lib/services/game_service.dart`, `lib/screens/phase3_vote.dart`, plus tests. **Client-only — no deploy.** Grep for any other caller of `isMySubmittedAnswer`; the signature changes.

Commit: `fix(vote): scope self-answer detection to the card being voted on`.

---

## 6. W4 — Issue 90, the B-half: identify by option id

**What this means for the user:** after W3 the reported bug is gone, but the flagging still rests on text. Two players writing the same words on the *same* card would still misfire. This replaces the heuristic with the actual answer.

### Why this is allowed

**The invariant is *never send other players' authorship to the client*.** Telling a player which opaque option id is **their own** reveals nothing they do not already know — they wrote the text and can see it in the list. **A callable's response goes to exactly one authenticated caller and is a legitimate private channel.** The previous guide wrongly described this as blocked; it is not.

### Implementation

1. **New callable in `functions/src/index.ts`** — place it beside `castVote`, which it mirrors:

```ts
export const getMyOptionId = onCall(async (request) => { … });
```

- Require `request.auth`; throw `unauthenticated` otherwise.
- Take `{ roomCode, cardId, playerId }`. **Verify the caller owns that player document exactly as `castVote` does** (`index.ts:548`): read `rooms/{roomCode}/players/{playerId}`, compare its `authUid` to `request.auth.uid`, throw **`permission-denied`** on mismatch.
- Read `rooms/{roomCode}/sealed/{cardId}`. Find the entry in `answerAuthors` whose **value** equals `playerId`; return its **key** as `{ optionId }`.
- Return `{ optionId: null }` when the caller authored nothing on that card. **Absence is not an error** — the truth-teller's own card has no forgery of theirs.
- **Return at most one id, and only the caller's.** Never return the map. Never accept a "whose id do you want" argument.
- **No rules change.** The sealed document stays default-deny and is read server-side, exactly as `castVote` already reads it.

2. **`lib/services/game_service.dart`** — a method calling it, caching per `cardId`, invoked once on entering the vote phase for a card. Treat a failure as `null` and fall through to W3's per-card text — **do not block the grid on the network call.**

3. **`lib/widgets/card_grid.dart:45`** — the identity clause is currently dead (trap 19). Make it mean something:

```dart
        final isSelfAnswer = ans.isSelfAnswer || ans.authorId == myOptionIdForThisCard;
```

`ans.authorId` is the option UUID (`phase3_vote.dart:423` passes `opt.id`), so this is now **option id compared to option id**, which is what the clause was always trying to express. Plumb `myOptionIdForThisCard` in as a parameter rather than reaching for a provider inside the widget.

4. **`test/fake_functions.dart`** — add a `if (name == 'getMyOptionId')` branch alongside the existing `castVote` and `rerollPrompt` branches (trap 6), modelling both the success shape and the `permission-denied` error shape.

### Validation

**Server, in `functions/test/game_e2e.spec.ts` — three assertions, and the third is the security bound:**
1. A caller who authored a forgery on that card receives **their own** option id, and resolving it through `answerAuthors` yields the caller.
2. A caller who authored nothing on that card receives `null` **without throwing**.
3. **A caller cannot obtain another player's option id** — calling with a `playerId` they do not own throws **`permission-denied`**, matched on the **code**, never the message (trap 12).

**Client:** a widget test where two players wrote identical text on the **same** card, with the fetched option id belonging to one of them. Assert **only that option** is blocked and the other is votable — the case W3's text heuristic cannot get right, and therefore the falsifying assertion for W4 specifically.

**Over-reach guard:** with the id fetch returning `null` (simulating failure), the grid must still fall back to W3's per-card text and must **not** block everything or block nothing. Assert both halves.

Battery: `npm --prefix functions test` **≥54**; `flutter test` **≥145**.

### Blast radius

`functions/src/index.ts`, `lib/services/game_service.dart`, `lib/screens/phase3_vote.dart`, `lib/widgets/card_grid.dart`, `test/fake_functions.dart`, plus tests. **Server change — W5 must deploy it.**

Commit: `feat(vote): identify a player's own answer by option id, not by text`.

---

## 7. W5 — Deploy and verify

Deploy only after W4 is committed and green. `predeploy` runs the suite and needs Java.

```bash
npx firebase-tools deploy --only functions --project gaslight-46368
```

Rules are unchanged by this build — **verify that rather than assuming**, with the Rules API call in `design_database_and_security.md` §8.

**Validation:** `./scripts/check_deploy_fresh.sh` → **exit 0**, with **15** functions now expected rather than 14. **Update `EXPECTED_FUNCTION_COUNT` and `EXPECTED_FUNCTIONS` in `scripts/check_deploy_fresh.sh` in the W4 commit** — otherwise the gate exits 1 on a correct deploy and the next agent learns to ignore it. Paste the before and after tables into the findings doc.

**A partial deploy is a failure, not a partial success.**

---

## 8. Already delivered — do NOT rework

**Verified in source and against the live project, August 16, 2026, at `f0d878b`:**

- **Issue 88.2** — `test/in_game_leave_test.dart` covers all three phase screens with `isTimerDisabled: true`, asserting the leave button present and `AutoAdvanceTimer` absent. *(W2 supplies the missing falsification record, not new tests.)*
- **Issue 88.1 (partial)** — `test/phase2_craft_test.dart:213` stubs `FirebaseFunctionsException(code: 'resource-exhausted')` and asserts the SnackBar text. **Keep it** — it guards the branch that degrades silently.
- **Issue 84** — `DialogThemeData` at `main.dart:86`; contrast test asserts ≥4.5:1 content and ≥3.0:1 title.
- **Issue 83 (Option C)** — `game_e2e.spec.ts:1959`, parameterised over both deck sizes with the per-player isolation guard.
- **Issue 87** — host kick succeeds **and** a non-host kicking a third player is rejected.
- **Issue 86** — `index.ts:264` filters `!p.isHost && p.lobbyReady !== true`; the test asserts the host's own `lobbyReady` is not true before proving the start succeeds.
- **Issue 85** — `index.ts:909` applies the below-3 rule **after** the phase branches; three tests cover auto-end, the 4-player over-reach, and the lobby exemption.
- **Issues 77–82** — sentinel purge, unmask bounds, full deploy, and the freshness gate whose three exit codes were each exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 9. Invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.**
- **Never send *other players'* authorship to the client.** **This does not forbid telling a caller their own** (W4). Option ids stay opaque in the room document; `answerAuthors` stays in the default-deny sealed document, read server-side only.
- **`castVote` rejects only genuine self-votes**, resolved server-side. **Never loosen it to accommodate a client heuristic.**
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and wins over the phase-specific branches.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.**
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **The exhaustion message is matched on the `resource-exhausted` code**; every other error falls through to the generic string, and **that fall-through is the failure mode** (`design_prompt_system.md` §5).
- **Re-rolls are unlimited during `truth`, rejected elsewhere, and never repeat.** **`seenPrompts` is per-sealed-document, not global.**
- **Who may accuse and who may be accused are two separate bounds.**
- **The deploy gate's three exit codes are a contract**, and its expected-function list is part of that contract — **update it in the same commit that adds a callable.**
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, **90 A-alone / B-alone / C**, and the rejected options on 58–66.

---

## 10. Where the contracts live

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

**After W4 lands, record the `getMyOptionId` contract in `design_database_and_security.md` §2** — what it returns, why returning the caller's own id does not violate the authorship invariant, and the `permission-denied` bound. It is a new write-architecture surface and belongs with the others.

---

## 11. Do not invent work · escalation

Outside W1–W5 there is no queue. Legitimate triggers: a defect W3/W4 surfaces, a user-selected issue, or the TTL interval dropping below ~4 hours.

**Bounded deviation:** keep the intent, deviate minimally, note it in the commit body — and record any substitution of deck, device or fixture.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel, **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** loosen `castVote`'s self-vote rejection, and **do not** put another player's option id anywhere the client can read it.

---

## 12. Validation standard

**Write validation that fails against the broken state, and observe it fail.** W2 is this rule applied to itself.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.**

**A verdict line and its observation section are two separate claims.**

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.**

**A clamp is not a rejection. A client-only bound is not a bound — and its mirror image: a client bound *tighter* than the server's is also a defect.** Issue 90 is the first instance of that direction here, and W3/W4 are the fix.

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Every defect in the last four waves came from a human with three simulators, not from a gate.

---

## 13. Feedback loop — what past specs got wrong

- **"There is no private channel" was wrong, and it nearly closed off the right fix.** Issue 90 Option B was written off because authorship must never reach the client. **The invariant is about *other players'* authorship**; a callable returning the caller's own id leaks nothing. **When an invariant seems to forbid an obvious fix, check whether it forbids the specific thing or only the general shape.**
- **A dead comparison keeps a heuristic load-bearing.** `card_grid.dart:45`'s identity check has been false since Issue 63, so text matching quietly became the only mechanism — and nobody noticed until it misfired. **Grep for comparisons that can never be true.**
- **A verdict line can name a method the block has no data for.** Specificity — two room codes — reads as evidence and is not.
- **A Definition-of-Done step with no artefact gets skipped.** W2 now names the file its output goes in.
- **A cross-reference survives a renumber; the promise it made does not.**
- **This guide once told an agent to do something impossible.** A guide is not exempt from its own traps.
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
(4) VALIDATE per §12, including the over-reach guard.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading;
    playthrough observations go to docs/playthrough_findings_marionette.md.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **W1** — `grep -c "Marionette Live Session"` and `grep -c "REQH"` both return **0**; A4 reads `PASS (backend boundary + client widget mapping) · NOT RUN on device`; the lost-output note present; no other verdict changed.
- [ ] **W2** — timer-disabled case **observed failing** with the button moved *into the `isTimerDisabled` branch of* `actions`, timers-enabled case observed **still passing**, move reverted, real failure text recorded **both** in `test/in_game_leave_test.dart` and the commit body.
- [ ] **W3** — per-card map replaces the flat set; `isMySubmittedAnswer` takes a `cardId`; the falsifying test (previous-card text, other author) observed **failing** first; over-reach guard (same-card own answer still blocked) in the same test.
- [ ] **W4** — `getMyOptionId` returns the caller's own id, `null` when none, and **`permission-denied` when asked for another player's**. `card_grid.dart:45` compares option id to option id. `test/fake_functions.dart` models it.
- [ ] **W4** — fallback asserted in both directions: with the id `null`, the grid neither blocks everything nor blocks nothing, falling back to per-card text.
- [ ] **W4** — `scripts/check_deploy_fresh.sh` updated to expect **15** functions, in the same commit.
- [ ] **W5** — one deploy; all **15** functions later than the last `functions/src` commit; gate exit **0**; before/after tables recorded.
- [ ] **After W4** — the `getMyOptionId` contract recorded in `design_database_and_security.md` §2.
- [ ] Battery at or above the bar: **0 errors** · **≥145** · clean build · **≥54** · deploy gate exit **0**.
