# Agent Execution Guide — Queue Complete — August 21, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue. Do not invent work** (§2).

**Issues 1–101 are delivered, deployed, and independently verified.** The security remediation (SEC1–SEC7, Issues 96–101) closed six defects including one HIGH-severity account takeover. Every over-reach guard the spec named is present in the tests rather than merely titled, both deploys landed and were confirmed, and two design documents that still described the vulnerable model were corrected during verification.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (22 warnings, 194 infos — both *down* from 26/196) |
| `flutter test` | **156/156** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **61/61** (was 54; +7 security tests) |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions and the rules release, both after their commits |

---

## 1. Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail — and apply that to the test itself.** Remove the guard, watch the test go red, restore it, and record the failure text **in a comment on the test** as well as the commit body. A step whose only product is a commit-body sentence gets skipped (Issues 89.2, 92). The security wave did this correctly — `functions/test/rules.spec.ts:33-34` carries the recorded run.
- **Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.
- **Security fixes cannot be proved by Dart widget tests.** `test/fake_functions.dart` does not enforce `firestore.rules`. Rules → `functions/test/rules.spec.ts`; callable authorization → `functions/test/game_e2e.spec.ts`.
- **Match on the error `code`, never the message.** A raw `Error` from a callable flattens to `INTERNAL`.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Run `./scripts/check_deploy_fresh.sh` as the fifth gate. Exit 2 means "could not verify" and is never a pass.** Its expected-function list is part of its contract — update it in the same commit that adds or removes a callable. **`firebase.json`'s `predeploy` does not gate `--only firestore:rules`** — a rules change needs its own deploy and its own verification.

---

## 2. Do not invent work

**Nothing is queued.** The only legitimate triggers for further work are:

- **a defect surfaced by a human playing the game** — five of the last six functional waves came from exactly this, and none from a gate;
- a user-selected issue in `docs/ongoing_general_errors.md`;
- **`ROOM_TTL_MS` dropping below ~4 hours**, which makes a host-only `touchRoom` keepalive plus a client timer mandatory;
- a sibling glyph in the Phosphor font turning out wrong.

**Do not** start a playthrough, a refactor, or an "improvement" nobody asked for. **Do not** re-verify what §3 records as delivered — it was checked in source and against the live project, not taken from commit messages. **Do not** touch anything in §4; every entry there is a decision someone made deliberately, and several look like oversights precisely because they are load-bearing.

**If you find something worth doing, file it — do not do it.** `docs/ongoing_general_errors.md`, with options and a blank `Your selection: _____` line. That is how every item in §3 got built.

---

## 3. Already delivered — do NOT rework

**Security (Issues 96–101), verified in source and against the live project, August 21, 2026:**

- **Issue 96** — `firestore.rules` splits `allow get: if true` / `allow list: if false` on `/rooms`; the `players` rule is intact because the lobby roster lists it. Two tests, authenticated and unauthenticated, each with both over-reach guards.
- **Issue 97** — seat re-bind requires **ownership, a valid `seatToken`, or a seat stale >30 s**. The token's SHA-256 hash lives only in `sealed/seat_{playerId}`; **no `seatToken` appears in any player-document write.** Rejection precedes the `return { role }`. Four over-reach guards, plus `expect.fail` so a successful takeover cannot pass silently.
- **Issue 98** — `votes` stores the **opaque option UUID**; phase, `currentReaderId`, and already-voted guards all present; resolution to authors happens server-side at the reveal transition and in `submitUnmaskGuess`.
- **Issue 99** — sealed content merges only for `room.currentReaderId`'s card; all others blank.
- **Issue 100** — while `unmaskDeadline` is open, `sabotageAnswers` stays empty and votes stay opaque; published only when all fooled players have guessed or the deadline expires.
- **Issue 101** — debug callables carry **both** guards: `FUNCTIONS_EMULATOR` rejection in production **and** a room-member `isHost` check.

**Functional work, previously verified:** Issues 84–95 (dialog contrast ≥4.5:1 content / ≥3.0:1 title; deck exhaustion at two deck sizes; host kick with the non-host rejection bound; readiness gate with the host-exemption deadlock guard; below-3 auto-end with its two guards; `isTimerDisabled` leave controls; the ordered option-id/text layering; join-error mapping; busy states) and Issues 50–83 as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 4. Invariants & intentional decisions — do NOT change

**Security invariants — these are now tested; breaking one will go red, and that is the point:**

- **`playerId` is NOT a credential.** It is the player document's ID and that collection is world-readable. A re-bind needs ownership, a `seatToken`, or a stale seat. **Do not simplify to one condition** — staleness alone lets an attacker wait; token alone strands a reinstall (`design_database_and_security.md` §5).
- **The seat token's hash lives only in the default-deny `sealed` subcollection.** Writing it into the player document recreates the original vulnerability in a new field.
- **`allow get` and `allow list` are split deliberately on `/rooms`. Never collapse them back to `allow read`** — `read` grants both verbs and re-opens unauthenticated enumeration.
- **`sealed` and `embeddings` have no `match` block and are therefore default-deny.** **Never add an explicit `allow read: if false`**, and never add a `match` block that accidentally grants access.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved to authors server-side at the reveal transition. **Never store the resolved author pre-reveal** — that was the answer-key oracle. A truth vote is `votes[voterId] == card.targetPlayerId` *once resolved*; there is no `'TRUTH'` sentinel and one must never be reintroduced.
- **Never send *other players'* authorship to the client** — but this does not forbid telling a caller their own (`getMyOptionId`).
- **`castVote` rejects only genuine self-votes** — never loosen it, and never let a client bound exceed the server's.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.**
- **Debug callables are emulator-only *and* host-only.** Both guards, not either.

**Functional invariants:**

- **The option id is the authority; text is the fallback, consulted only when the id is null.** Never union the two.
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose. Do not "tidy" either.
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase branches, and computes no scores.
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`.** The guard asserts a **ratio**, not a string.
- **Never interpolate an exception object into user-facing text.** Map on `e.code` with a generic fallback.
- **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **The exhaustion message is matched on the `resource-exhausted` code**; the generic fall-through is the failure mode.
- **Re-rolls are unlimited during `truth`, rejected elsewhere, never repeating.** **`seenPrompts` is per-sealed-document.**
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()` (once `/rooms` is not listable, an attacker cannot enumerate codes, and the remaining narrative is brute force — no security delta from `crypto.randomInt`); `authUid` exposure in player documents (opaque anonymous identifier, confers no capability); prototype pollution via `selectedDeckId` (throws a `TypeError`); plus P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, 88 A/C, 89 B/C, 90 A-alone/B-alone/C, 91 B/C, 92 B/C, 93 B/C, 94 B/C, 95 B/C, and the rejected options on 58–66.

---

## 5. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps, lessons | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| **`votes` two-phase contract**, phase order, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, **single-card reveal scoping**, **unmask withholding**, own-answer lockout | `design_scoring_and_ui.md` |
| **Rules (§3), seat tokens (§5), callable table (§2), debug isolation (§7.1), deploy & freshness gate (§8)** | `design_database_and_security.md` |
| Dialog surface, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules tests | `functions/test/rules.spec.ts` |
| Callable / integration tests | `functions/test/game_e2e.spec.ts` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |

---

## 6. Validation standard

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.**

**Check that a test's subject is the thing the spec named.**

**Assert the negative as well as the positive.** The security wave's sharpest assertions are negatives: the token appears in **no** client-readable document; the stored vote is **not** a player id; the rendered error contains **no** stack frame.

**Use `expect.fail` when a test's failure mode is "the bad thing succeeded."** A `try/catch` that only asserts inside `catch` passes silently when nothing throws.

**A test harness that cannot express the bug will pass against it.** A Dart widget test can never prove a rules or authorization fix.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.** Rules and functions deploy separately; verify both.

**An observation you cannot trace to a tool result is not an observation.**

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.** One value cannot pass both.

**A clamp is not a rejection. A client-only bound is not a bound — and a client bound *tighter* than the server's is also a defect.**

**A layered fix must be ordered, not unioned** — the authority must be able to say *no*, not merely *also yes*.

**Structurally present is not actually wired.** Trace callable → service → screen → widget before believing it.

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

---

## 7. Feedback loop — what past specs got wrong

- **A fix can be correct while its design doc still describes the vulnerability.** Four of six security items updated a design doc; the two most important did not, leaving §3 documenting the retired `allow read: if true` as intended behaviour. **Closing a security issue means updating the document that made the old design sound deliberate. Grep the design docs for the code you just deleted.**
- **A documented invariant with no test behind it is a wish.** "Never send other players' authorship to the client" was written down, believed, and violated by the one function privileged to read the sealed document.
- **When a design doc calls something a secret, grep for where it is published.** `playerId` was the recovery credential *and* a world-readable document ID.
- **When you redefine what a field holds, enumerate its readers.** `votes` has now been redefined three times; the third time the 13 readers were walked and it held.
- **A guard's test must be run with the guard removed** — the skip is invisible in a green run.
- **A spec can be over-cautious as well as wrong.** The guide warned that `advanceToNextResolution` must merge the next card; it does not, because that branch returns to `vote` and the ordinary transition handles it. **Recorded so nobody "fixes" a non-problem** — a wrong warning costs a cycle just as a missing one does.
- **A layered fix must be ordered, not unioned.** **Check what a component already offers before specifying an addition.** **Enumerate error codes from source, never from expectation.**
- **"Verified in source" is not "shipped."** A written deploy instruction failed twice before it was replaced with a tool.
- **Fixing a class of defect promotes the next one.** Assume the next failure is one level up, and look there first.
- **One item = one commit.** **Doc structure rots silently** — append inside the single existing Resolved heading; never add a second.

---

## THE LOOP — for whenever the queue reopens

```
(1) STUDY the item + its full issue text in ongoing_general_errors.md + the
    exact files at the cited anchors. RE-GREP every anchor; line numbers drift.
(2) ENUMERATE the readers of anything you are about to change. `votes` has
    broken twice on exactly this.
(3) WRITE the falsifying validation FIRST, in the suite that can observe it:
    rules -> functions/test/rules.spec.ts
    callable authorization -> functions/test/game_e2e.spec.ts
    client behaviour -> test/*.dart
    Run it. OBSERVE IT FAIL. Record the exact output.
(4) IMPLEMENT exactly as specified. Record any substitution you make.
(5) VALIDATE per section 6, including every over-reach guard -- and remove the
    guard to prove the test can still fail.
(6) RECORD the observed failure text in a comment on the test AND in the
    commit body.
(7) RE-RUN THE FULL BATTERY before committing, including
    ./scripts/check_deploy_fresh.sh.
(8) BLOCKED, or a design decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(9) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output
    included. Move the issue into the SINGLE existing Resolved heading, and
    update the design doc that described the OLD behaviour -- not only the one
    describing the new.
```

---

## Definition of Done — for this state

- [x] Battery green and re-measured: **0 errors** · **156/156** · clean build · **61/61** · deploy gate **exit 0**.
- [x] Every issue through 101 resolved, with its guards verified in source rather than from commit messages.
- [x] Both deploys confirmed — functions **and** the separately-gated rules release.
- [x] No blank `Your selection:` line anywhere in `docs/ongoing_general_errors.md`.
- [x] Design docs carry the contracts the code now implements, including the two corrected during this verification (§5).
- [ ] **Nothing further. Do not invent work** (§2). The next change should come from someone playing the game.
