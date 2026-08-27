# Agent Execution Guide — Active Build: Wave Q — Close the `closeUnmaskWindow` hole (Issue 133) — August 27, 2026

**You are an engineering agent with no memory of this project.**

**One item. One commit. The selection is made: Issue 133 → Option A.**

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **Q1** | `closeUnmaskWindow` must refuse an early close, and any room member must be able to call it | **133 → A** | server + client | ✅ |

**Do not run `firebase deploy` yourself** — that call is the user's, and it is what makes the server half of Q1 real.

**Every number and literal string below is a decision, not a suggestion.** Implement as written. If a value is impossible, keep the intent, deviate minimally, and say so in the commit body.

---

## 0. What this item is, in one paragraph

Wave P's Issue 124 fix correctly stopped publishing `scoreDeltas` while the unmask window is open, and added a `closeUnmaskWindow` callable to close the window on the timeout path. **The callable shipped without the deadline check that made it safe.** Any player can call it the instant the reveal begins, which ends the guessing window for the whole table and publishes the map that names every fooling forger. Separately, the client only calls it when the caller is the host, so a table whose host has left never closes the window at all. **Q1 fixes both halves in one commit**, because fixing only the guard leaves the empty-tray path and fixing only the trigger widens who can exploit the missing guard.

---

## 1. Standing constraints

- **One item = one commit**, Conventional Commit, **WHY in the body — never a bare title.** Wave P's Issue 124 commit was a title with no body, and that is part of why this defect took a verification pass to find.
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Read a gate's exit code bare, never through a pipe.** `./scripts/check_deploy_fresh.sh | tail -6` reports `$?` from `tail`, which is always `0`.
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated.
- **When a change adds or alters a callable, enumerate what it now permits** before enumerating what it fixes (lesson 2.32). That is the lesson this whole wave exists to apply.
- **Do not touch anything in §7 or §8.**

---

## 2. Q1 — the server guard (133 → A, part 1 of 2)

**What this means for the user:** during the twenty seconds when players are guessing who fooled them, nobody can skip to the answer — or end the round early for everyone else.

### 2.1 The gap, with reproducible evidence

`closeUnmaskWindow` (`functions/src/index.ts:2241`) validates the phase, the current card, room membership and the sealed document. **It never reads `room.unmaskDeadline`.** Proven against a running emulator, with the fooled player — the one who is supposed to be guessing — making the call:

```
PROBE unmaskDeadline       = 1787846904973
PROBE window open?         = true
PROBE scoreDeltas at reveal= undefined          <- Issue 124's core fix works
PROBE early close returned = {"success":true}   <- should have been failed-precondition
PROBE unmaskDeadline after = 0                  <- window ended for the WHOLE table
PROBE scoreDeltas after    = {"p_host":3,"p_g1":1}
PROBE actual forgerId      = p_host  target = p_g1
PROBE forger identified?   = true  via ["p_host"]
```

### 2.2 The four states `unmaskDeadline` can hold — handle all of them

This is the part that is easy to get half-right. The field is not a boolean.

| Value | Meaning | Required behaviour |
|---|---|---|
| `null` | No window ever opened for this card — nobody was fooled, and `scoreDeltas` was already published at reveal | Early return `{ success: true, alreadyClosed: true }`. **Do not write anything.** |
| `0` | The window has already been closed | Early return `{ success: true, alreadyClosed: true }`. **Do not write anything.** |
| A **future** timestamp | The window is open | **Throw `failed-precondition`.** This is the fix. |
| A **past** timestamp | The window expired and nobody has closed it | Proceed with the existing flush-and-publish logic, unchanged. |

### 2.3 Implementation

1. **Add the early return for `null` and `0`** immediately after `const room = roomSnap.data() as GameState;` and the existing `currentPhase !== "reveal"` check:
   ```ts
   if (room.unmaskDeadline === null || room.unmaskDeadline === undefined || room.unmaskDeadline === 0) {
     return { success: true, alreadyClosed: true };
   }
   ```
   **Use an explicit comparison, not a falsy check** (lesson 2.1). This also turns the N−1 redundant transactions from concurrent callers into cheap no-ops instead of repeated writes.
2. **Add the deadline guard**, placed **after** the caller-membership check (`if (!callerPlayer)`) so an outsider always receives `permission-denied` regardless of window state — authorize first, then validate state:
   ```ts
   if (Date.now() <= room.unmaskDeadline) {
     throw new HttpsError("failed-precondition", "The unmask window has not expired yet.");
   }
   ```
   **Throw here, unlike `handleDisconnect`'s `still-present` return.** The client needs to distinguish "not yet" from "done" so it can retry (§3.3); a silent success would latch the client and the window would never close.
3. **Change nothing else in this function.** The flush block, the `resolvedVotes` construction, the `updatedCards` write and `unmaskDeadline: 0` are all correct as written.
4. **Do not add this guard to the other two flush sites.** `pendingScoreDeltas` is flushed in three places — `advancePhaseInternal` (`index.ts:~1836`), `advanceToNextResolution` (`~2013`) and `closeUnmaskWindow` (`~2282`). The first two run when the game legitimately moves past the card, at which point nobody is guessing any more. Guarding those would strand the pending deltas. **This is also the reason a failed close is not a disaster:** if `closeUnmaskWindow` never succeeds for a card, the tray stays empty for that card but the scores are still applied when the host advances. No score is ever lost or double-applied.

### 2.4 Validation — the falsifying test comes first

**Write this one before anything else, run it against the current code, and watch it fail.** Paste the failing output into the commit body.

- **F1 — the fix.** Advance to reveal on a card where someone was fooled. Assert `unmaskDeadline > Date.now()` (proving the window is genuinely open — *asserting the rejection without proving the window was open proves nothing*), then call `closeUnmaskWindow` as the fooled voter and assert it throws `failed-precondition`. Then assert, in a fresh read: `card.scoreDeltas` is still `undefined`, and `unmaskDeadline` is **unchanged** — not `0`.
- **F2 — the happy path still works.** With the deadline forced into the past (write `unmaskDeadline: Date.now() - 1000` directly onto the room), call it and assert `scoreDeltas` is the full correct map and `unmaskDeadline === 0`.
- **F3 — idempotency, asserted on scores and not on absence of error.** Call it **twice** after expiry and assert each player's `totalScore` equals the value implied by the votes the test cast — computed in the test, **not** read back from the summary. Because Issue 124's implementation defers `totalScore`, `timesFooled` and `playersDeceived` into `pendingScoreDeltas`, a double flush would corrupt scores, and "it returned success twice" would not catch it.
- **F4 — concurrency.** Two different members call in the same tick (`await Promise.all([...])`). Assert scores are applied exactly once, by the same computed-in-test arithmetic as F3.
- **F5 — over-reach guard, non-member.** A user who is authenticated but not in the room gets `permission-denied`, both while the window is open and after it has expired. The guard must not have changed who may call.
- **F6 — over-reach guard, nobody fooled.** On a card where `unmaskDeadline` is `null`, calling it returns success and **leaves `card.scoreDeltas` exactly as reveal published it** — it must not be overwritten with `{}`.
- **F7 — over-reach guard, the other flush paths.** `advanceToNextResolution` still flushes pending deltas when the host advances **during** an open window. This must still work; it is not the leak, and guarding it would strand the deltas.

**Then re-run F1 with the guard removed and confirm it fails.** A guard whose test passes with the guard removed is decoration.

---

## 3. Q1 — the client trigger (133 → A, part 2 of 2)

**What this means for the user:** the points tray fills in even when the host has already left the game.

### 3.1 The gap

`lib/screens/phase4_reveal.dart:89` reads:

```dart
if (gs.currentPlayer?.isHost == true && !_hasClosedUnmaskWindow) {
```

If the host has left or backgrounded the app, nobody calls, `scoreDeltas` is never published, and the points tray and standings deltas stay empty for the rest of that card.

### 3.2 ⚠️ The trap: this timer ticks every 200 ms

`_countdownTimer` is `Timer.periodic(const Duration(milliseconds: 200), ...)` (`phase4_reveal.dart:83`). Two consequences that must both be handled, or the fix is worse than the bug:

- **Never clear the latch unconditionally on failure.** A client whose clock runs 5 seconds fast would fire **25 rejected calls per card**, times every player at the table.
- **But never latch permanently on failure either.** `unmaskDeadline` is a server-generated absolute timestamp compared against each client's own clock. If every client's clock is ahead of the server's, every client calls early, every call is rejected, and — if they all latched — **the window would never close for that card.** That is the empty-tray regression this item exists to remove, reintroduced by the fix for it.

### 3.3 Implementation

1. **Delete the `isHost` condition.** Any room member triggers the call. Keep the existing per-card `_hasClosedUnmaskWindow` latch, which is already reset when the card changes (`phase4_reveal.dart:264`) — that reset is correct; do not touch it.
2. **Add a safety margin.** Fire only when `now >= state.unmaskDeadline! + 1500`, not at the deadline itself. 1500 ms absorbs ordinary clock skew so the common case never produces a rejected call.
3. **Make the service wrapper report the outcome.** Change `GameService.closeUnmaskWindow()` (`lib/services/game_service.dart:704`) from `Future<void>` to **`Future<bool>`**:
   - `true` — the server closed it, or it was already closed.
   - `false` — the server threw `failed-precondition` (not yet expired). Match on `e.code == 'failed-precondition'`, **on the code and never on the message** — that rule already burned this project once (Issue 93).
   - Any other exception: log via `debugPrint` and return `true`, so an unrelated failure does not spin the retry loop.
4. **Retry, but bounded.** In the timer callback:
   ```dart
   if (!_hasClosedUnmaskWindow && now >= state.unmaskDeadline! + 1500) {
     _hasClosedUnmaskWindow = true;              // latch immediately: stops the 200ms storm
     gs.closeUnmaskWindow().then((closed) {
       if (!closed && mounted && _closeAttempts < 5) {
         _closeAttempts++;
         _hasClosedUnmaskWindow = false;         // allow exactly one more attempt
       }
     });
   }
   ```
   Add `int _closeAttempts = 0;` beside `_hasClosedUnmaskWindow`, and **reset it to 0 in the same place the latch is reset** (`:264`, when `currentTargetId != _previousTargetId`). Five attempts across a card is ample for any plausible skew and bounded enough that a badly-set clock cannot spam.
5. **A rejected call must never surface to the user.** No snackbar, no dialog. It is an expected outcome of clock skew, not an error.
6. **Give up quietly after five attempts.** Per §2.3 step 4, the pending deltas are still flushed when the host advances, so the worst case is one card whose tray stayed empty — not a lost or wrong score. Say this in the commit body so nobody later "fixes" it with an unbounded retry.

### 3.4 Validation

- **W1 — the falsifying widget test.** A **non-host** player on the reveal screen, past `unmaskDeadline + 1500`, causes exactly one `closeUnmaskWindow` call. **Run it against the current code and watch it fail** — today only the host calls.
- **W2 — the host still calls.** Over-reach guard: removing the `isHost` condition must not have removed the host's own trigger.
- **W3 — no storm.** Hold the clock at `unmaskDeadline + 1500` and pump **20 ticks (4 seconds)** with the fake returning `true`. Assert the call count is exactly **1**. This is the assertion that proves the latch works at 200 ms.
- **W4 — bounded retry.** With the fake returning `false` every time, pump 60 ticks and assert the call count is exactly **6** (the initial call plus five retries) and no more. Falsify by removing the `_closeAttempts` cap and confirm the count runs away.
- **W5 — the margin.** At `unmaskDeadline + 500` (inside the margin), assert **zero** calls. At `+1500`, assert one.
- **W6 — per-card reset.** Advance to a second card and assert a fresh call is made — the latch and the attempt counter both reset.
- **W7 — silence.** After a `false` response, assert no `SnackBar` is in the tree.

### 3.5 Blast radius

`functions/src/index.ts` (`closeUnmaskWindow` only) · `lib/services/game_service.dart:704` (return type; **check for other callers before changing the signature** — there is currently one) · `lib/screens/phase4_reveal.dart` (`:41` field, `:89` trigger, `:264` reset) · `functions/test/game_e2e.spec.ts` · `test/phase4_reveal_test.dart` or a new `test/unmask_close_test.dart` · **`docs/design_scoring_and_ui.md` §3.3** currently describes the close path without the deadline bound — update it to state that the server refuses an early close and that any member may trigger it.

---

## 4. Definition of Done

- [ ] **F1 written first, run against the current code, and observed to fail.** Failing output pasted into the commit body.
- [ ] The guard **throws `failed-precondition`** while the window is open, and `scoreDeltas` and `unmaskDeadline` are both left untouched by the rejected call.
- [ ] `null` and `0` return early with **no write**, using explicit comparisons rather than a falsy check.
- [ ] **F3 and F4 assert `totalScore` arithmetic**, not merely the absence of an error — deferred increments make double-flush a scoring bug, not a cosmetic one.
- [ ] F5, F6 and F7 pass: non-members still refused; a nobody-fooled card keeps the deltas reveal published; `advanceToNextResolution` still flushes during an open window.
- [ ] **F1 re-run with the guard removed and observed to fail.**
- [ ] W1 written first and observed to fail; a non-host now triggers the close.
- [ ] **W3 asserts exactly 1 call across 20 ticks**, and **W4 asserts exactly 6 across 60** with the cap falsified.
- [ ] A rejected close is invisible to the user.
- [ ] Battery at or above baseline: **0 errors** · **≥227** client · clean functions build · **≥94** functions · deck sync PASS · evidence exit 0.
- [ ] `check_deploy_fresh.sh` goes **red** the moment this lands and stays red until the user deploys — **say so in the commit body** rather than leaving it looking like a regression.
- [ ] Issue 133 moved into the **single** existing Resolved heading, and `design_scoring_and_ui.md` §3.3 updated.

---

## 5. Carry forward — no selection needed, not part of Q1

Do these only if a future item already touches the file. They are not work on their own.

- **P7's departure diff is implemented twice.** `processPlayersSnapshotForTesting` (`lib/services/game_service.dart:80`) is a `@visibleForTesting` mirror of the logic in the real players listener (`:476`). The unit test therefore exercises **the copy, not the shipped path**, and the two can drift silently. Fix by extracting one private method both call — then prove it by breaking the shared method and confirming the test fails.
- **`'THE SOUL IS SILENT'` is a hardcoded Dart literal** in `lib/widgets/card_grid.dart`, duplicating `kMissingAnswerPlaceholder` (`index.ts:176`). A sentinel with two owners (lesson 2.31).
- **`kMaxAnswerLength` is duplicated** across the client cap and the server bound. Consistent today; a change to either needs the other in the same commit.

---

## 6. Verified baseline — measured in-session, August 27, 2026

This is the regression bar. Every number came from running the command.

| Gate | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze lib test` | **0 errors**, 0 warnings, 221 infos |
| Client tests | `flutter test` | **227 passing** |
| Functions build | `npm --prefix functions run build` | clean |
| Functions tests | `npm --prefix functions test` | **94 passing** |
| Deck sync | `./scripts/check_decks_in_sync.sh` | **exit 0** — 5 decks, 295 lines |
| Deploy freshness | `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH** (16 functions, deployed 2026-08-27T16:02–16:03Z). **Q1 will turn this red.** |
| Playthrough evidence | `./scripts/check_playthrough_evidence.sh` | **exit 0** — 21 blocks: 20 PASS, 1 NOT RUN, 0 FAIL |

---

## 7. Already delivered — do NOT rework

- **All of Wave P except the Issue 133 defect.** Verified in source and against a running emulator, August 27, 2026:
  - **P1**/122 — the timeout test picks a non-placeholder, non-self option; all three original assertions survive.
  - **P2**/125 — `concludeResolutionRound` (`index.ts:1352`) was **moved, not copied**: one definition, two callers (`:1639`, `:2068`). The empty-order path passes the already-read `sealedDataMap`, so the helper performs no reads after a write.
  - **P3**/123 — the presence window gates **the action, not the caller**. `handleDisconnect` takes a `"leave" | "kick" | "presence" | "reconcile"` reason and **returns** `{ success: false, reason: "still-present" }` rather than throwing, because the client swallows errors. **Falsified:** disabling that return fails exactly the 150 s test and leaves the other five green.
  - **P5**/130 — timers off by default at all four sites with `!== undefined` guards; all six hardcoded durations replaced by `getPhaseDurations` (`index.ts:215`), clamped 15–300, vote at 75%.
  - **P6**/127 · **P7**/128 · **P8**/126 · **P9**/132 (`ListView.separated` with `ConstrainedBox(minHeight: 72, maxHeight: 132)` — the unbounded-height trap avoided; tests at 320/375/430 pt with the real Lora font) · **P10**/131 · **P11**/129.
- **Wave O's six good items:** **O1**/117 — the `{ merge: true }` writes to `sealed/{playerId}` became full-document sets: `startGame` (`index.ts:712`), the round advance inside `concludeResolutionRound` (`:1411`), and the `transaction.set(sealedRef, sealedData)` calls in `advancePhaseInternal` (`:1502`–`:1607`). This is safe because `sealedDataMap` is a complete in-transaction read and the seat token lives in a **different** document (`sealed/seat_{playerId}`). **The `_summary` doc still uses `{ merge: true }` (`:1771`) and must keep it** — that one is supposed to accumulate. **O3**/115 · **O6**/114 · **O7**/116 · **O8**/119 · **O9**/121 (the target's vote is refused independently at `index.ts:924`).
- **Issue 102** — the pre-demo playthrough in room `GLRD`: **20 PASS, 1 NOT RUN, 0 FAIL**. E7 seat recovery and E8 host kick both device-verified.
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R5 mechanically.
- **Issue 103** — seven `DEBUG:` sites gated; **all seven buttons still exist** — gated, not deleted.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken`, or a stale seat; `votes` stores opaque option UUIDs; the reveal merges only the current card; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

**Build numbers:** App Store Connect has consumed **build 4**. `pubspec.yaml` must exceed it — `1.0.0+5` or higher. A reused number is rejected at upload.

---

## 8. Accepted equivalents & intentional decisions — do NOT change

**Accepted equivalents** — different structure, same guarantee. Do not "fix" these back:

- **P10's submit button is not pinned with `viewInsets`.** It was moved out of the inner scroll view and relies on `Scaffold.resizeToAvoidBottomInset`. The test proves the guarantee at 320×640 with `FakeViewPadding(bottom: 300)`.
- **P11's guidance line sits in a bordered parchment container** rather than the plain italic text the spec named. Validated at 320 pt.
- **P1 adds a `setReady` fallback** when a voter has no non-self votable option.
- **P3 defaults a missing `reason` to `"leave"` when the caller is the subject**, rather than a blanket `"presence"`. Better for old clients.
- **Issue 124's implementation went beyond Option A into Option B**, deferring `totalScore`, `timesFooled` and `playersDeceived` through `pendingScoreDeltas` / `pendingTimesFooled` / `pendingPlayersDeceived`. **Accepted.** It closes the inference channel Option A left open, and the three flush sites each guard on the field's presence and `FieldValue.delete()` inside a transaction. **The standings strip legitimately holds still during the unmask window — that is Option B's stated cost, not a bug.** Q1's F3 and F4 exist because these deferred increments make a double flush a scoring bug.

**Invariants** — do not change:

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** This is why `pendingScoreDeltas` lives there.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **Never let a client bound exceed the server's.** This is the invariant Q1 restores; `castVote` is the model.
- **The presence window gates the ACTION, not the caller.** `isDead` inside an authorization condition is what made Issue 120 inert for a full wave. Do not move it back.
- **The option id is the authority; text is the fallback**, consulted only when the id is null.
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **Error surfaces match on `e.code`, never on the message**, and never interpolate an exception into user-facing text.
- **Dialogs render on `groundRaised`.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which **breaks the iOS build**. Proven August 25, 2026: `Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter`. The answer stays no (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is **generated**. **No file outside the catalogue may branch on a deck id.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; a scheduled-task close for the unmask window (Issue 133 Option C); a host-only trigger with a server-side sweep (Issue 133 Option B); distinguishing *why* a player left (Issue 128 Option B); per-phase timer durations (Issue 130 Option B); plus the declined options in `ongoing_general_errors.md` §4.

---

## 9. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens, presence & the disconnect reason union, callables, deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 10. Validation standard

**Ask what the change permits, not only what it fixes** (lesson 2.32). The probe that caught Issue 133 called the new callable; a probe that re-read the room document reported the leak closed.

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A constant's value is not behaviour** (lesson 2.30). Drive the assertion through the entry point a client uses.

**Falsify every guard.** A guard whose test passes with the guard removed is decoration.

**Assert the arithmetic, not the absence of an error.** F3 and F4 exist because "it returned success twice" cannot detect a double-applied score.

**A test that exercises a mirror of the shipped logic tests nothing about the shipped logic** (§5, first bullet).

**Record every substitution.** An omitted assertion reads as though it passed.

**A green suite is not evidence about anything it cannot observe.** All seven gates were green while `closeUnmaskWindow` was unguarded and deployed.

**A driven playthrough is not a played one.**

---

## 11. Feedback loop — why this defect escaped a detailed spec

The Wave P spec named this guard **twice** — once in the implementation steps, once in the Definition of Done — and it still fell out. Three corrections, all applied in this document:

- **A guard on a new entry point needs its own numbered sub-item, not a clause.** In Wave P it was one bullet inside a large item whose hard part was the `pendingScoreDeltas` plumbing, and a validation line reading "refuses an early close" is easy to skim as already satisfied by the surrounding checks. Here it is §2 with its own state table and its own F1.
- **The adversarial test must attack what the change added.** Verifying Issue 124 by re-reading the room document reports success. Only calling the new callable finds the hole.
- **State every value a field can hold when the guard reads it.** `unmaskDeadline` is `null`, `0`, future or past, and a naive truthy check gets two of those wrong. §2.2 is a table for that reason.

---

## THE LOOP

```
(1) STUDY §2 and §3 here + Issue 133 in ongoing_general_errors.md + the files
    at the cited anchors. RE-GREP every anchor; numbers drift -- three did
    between Wave P and this document.
(2) ENUMERATE WHAT THE CHANGE PERMITS, not only what it fixes.
(3) GREP THE EXISTING SUITE for tests asserting the rule you are changing.
    Update them in the SAME commit.
(4) WRITE F1 and W1 FIRST. Run them. OBSERVE THEM FAIL. Record the exact
    output.
(5) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(6) VALIDATE F1-F7 and W1-W7, then RE-RUN F1 WITH THE GUARD REMOVED and
    confirm it fails.
(7) RE-RUN THE FULL BATTERY -- all seven, exit codes read BARE, not piped.
    check_deploy_fresh WILL be red; that is expected and must be explained.
(8) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options, Pros/Cons, one (recommended),
    and a blank `Your selection: _____`.
(9) COMMIT: Conventional Commit, WHY in the body -- never a bare title. Move
    Issue 133 into the SINGLE existing Resolved heading and update
    design_scoring_and_ui.md §3.3.
```

**After Q1 lands, the queue is empty.** Report the state, tell the user the deploy is theirs to run, and stop. Do not invent work.
