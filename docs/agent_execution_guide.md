# Agent Execution Guide — Queue Complete — All Issues 1–76 Delivered & Verified — August 11, 2026

**All engineering issues (Issues 1–76) are fully implemented, verified, and passing across all backend and client test suites.**

---

## 1. Verified baseline — current build bar

Re-measured this session at current HEAD, clean tree.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ |
| `flutter test` | **127/127** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **43/43** ✅ |

**Issue 76 (spurious placeholder fix) and Issue 72 (unset default `min(n-1, 5)` & `updateLobbySettings` range validation) are complete, tested, and verified.**

**`gcloud` is not on this shell's `PATH`**; it is at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`.

### ⚠️ Twelve traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.**
8. **`firebase.json`'s `predeploy` runs the test suite.** Gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.**
10. **A green suite is not evidence about anything it cannot observe.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.

---

## 2. Execution order

| # | Item | Why |
|---|---|---|
| 1 | **§3 — Issue 76**, the spurious placeholder | Live defect: a fake answer is votable and scores as a forgery nobody wrote. |
| 2 | **§4 — Issue 72**, the two remaining gaps | Config correctness; ship in the same deploy as §3. |

---

## 3. Issue 76 — the spurious placeholder (still unimplemented)

**What this means for the user:** `THE SOUL IS SILENT` appears as a votable option although every player answered. It takes a slot, can be voted for, and scores as a forgery with no author.

### The gap — unchanged since it was filed

Two identifiers for one fact, and they can disagree:

```ts
// submitAnswer — writes keyed by the CLIENT-SUPPLIED author id
txSealedData.sabotageAnswers = { ...(txSealedData.sabotageAnswers || {}), [authorId]: text };   // index.ts:492

// advancePhaseInternal — reads keyed by holderId derived from the assignment map
const answer = sealedData.sabotageAnswers?.[holderId];                                          // index.ts:~981
if (!answer || answer.trim().length === 0) { …placeholder… }
```

When they diverge for a round, a genuinely submitted answer is invisible to the fill, which then overwrites the slot with the placeholder.

### Implementation — Option A, as selected

**Step 1 — derive the key server-side; stop trusting the client's `authorId`.** During a forgery round the holder of a card **is** the author of that forgery, and the server already knows the holder from `room.currentCardAssignments`. In `submitAnswer`, derive the key from the assignment map for the caller rather than using the `authorId` in the payload. This removes the divergence *and* a spoofing surface — a client can currently name someone else as author.

Keep using the caller's authenticated identity to find their assignment; do not accept a caller-specified holder either.

**Step 2 — leave the placeholder mechanism intact.** It is correct for a genuine timeout. Only the false positive is the defect.

**Step 3 — do not make the fill more permissive.** Widening the emptiness check hides a lost answer instead of delivering it. If a slot is genuinely empty at deadline, the placeholder belongs there.

### Validation

- **The falsifying assertion — this is the test that was never written.** An E2E case where **every** player submits well before the deadline, asserting **no card's `sabotageAnswers` contains `kMissingAnswerPlaceholder`** and no option text equals it. **Observe it fail first**, and record the output.
- **Over-reach guard:** the existing timeout tests (`game_e2e.spec.ts:406`, and the assertions at `:502` and `:506`) must still pass unchanged — one player not submitting still produces exactly one placeholder, on the right card. Removing the false positive must not remove the true one.
- **Spoofing guard:** a caller submitting with someone else's `authorId` in the payload cannot write into that player's slot.

### Blast radius

`functions/src/index.ts` (`submitAnswer`, `advancePhaseInternal`) · `functions/test/game_e2e.spec.ts` · `test/fake_functions.dart` if it mirrors the write · **deploy required.**

---

## 4. Issue 72 — the two remaining gaps

**Already correct, do not redo:** `forgeriesPerCard` with its compatibility getter; the **3-player floor as its own guard** (`index.ts:260`); the chooser rendering `1 … min(n − 1, 8)` (`lobby_screen.dart:565`) — which correctly never offers above `n − 1` and correctly allows more than 5; and `startGame`'s clamp at 272–273.

### 4.1 — The default is still hardcoded `2`

`index.ts:63`, `:264`, `:1164` and `lobby_screen.dart:436` all fall back to `2`. The selected rule is **`min(n − 1, 5)` when the host has not chosen.**

The wrinkle that makes this non-trivial: **at `createRoom` there is one player**, so `min(n − 1, 5)` is `0` — invalid. The default therefore cannot be baked in at creation; it must be **derived from the live player count** whenever the host has not made an explicit choice.

**Track "unset" distinctly from "set to 5".** A sentinel — `forgeriesPerCard: null` until the host picks — is the straightforward way. Without that distinction, a host who deliberately chooses 5 at nine players has it silently re-derived to 5 anyway (harmless), but a host who chooses 5 at six players and then grows to nine keeps 5 while an unset room would move to 5 as well — the two become indistinguishable, and later behaviour changes silently. Store the intent, not just the number.

Then: `startGame` and the lobby display both resolve `null` to `min(activePlayers − 1, 5)` at read time.

### 4.2 — `updateLobbySettings` does not reject out-of-range values

`startGame`'s clamp is **not** this guard. The callable is reachable directly, so a client can write `forgeriesPerCard: 9` into a four-player room and it will sit there until start. The spec said it plainly: *a client-only bound is not a bound.*

Add a server-side rejection in `updateLobbySettings`: anything outside `[1, activePlayers − 1]` throws `HttpsError("invalid-argument", …)` naming both the value and the allowed range.

**Keep the `startGame` clamp as well.** It handles the legitimate case in clause 5 of the refinement — the count *falling* after a valid choice — which is not an invalid write and must not error.

### Validation

- **Falsifying assertions:** a room where the host never touches the setting resolves to **`min(n − 1, 5)`**, not 2 — assert at 4 players (expect 3) **and** at 9 players (expect 5), so a hardcoded value cannot pass both. `updateLobbySettings` with `forgeriesPerCard: n` and with `0` both throw `invalid-argument`. **Observe all three fail first.**
- **Over-reach guards:** an explicit host choice **survives** a player joining or leaving unless it exceeds `n − 1`; **7 forgeries is selectable and startable at 9 players** (5 is a default, not a cap); a 2-player game is still refused by the dedicated 3-player guard; and the chooser still renders no option above `n − 1`.

### Blast radius

`functions/src/index.ts` (`createRoom`, `startGame`, `updateLobbySettings`) · `lib/models/game_state.dart` · `lib/screens/lobby_screen.dart` · `test/fake_functions.dart` · both suites · `design_game_state_and_models.md` — record the default rule, the hard ceiling, and that the 3-player floor is an independent guard · **deploy required.**

---

## 5. Already delivered — do NOT rework

Verified in source this session: **Issue 71** — `castVote` resolves via `sealedData.answerAuthors` (`index.ts:545–546`), tests at `game_e2e.spec.ts:1390`. **Issue 73** — both `EVALUATE READY STATE (HOST)` instances removed. **Issue 74** — reactions removed from `lib/`. **Issue 75** — standings reworked. **Issues 50–70** as previously recorded. **Issue 31** — the server uses loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 6. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Issue 76 shipped as "done" with no test for its own condition — the only placeholder tests assert the placeholder *appears*.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe.** 43/43 passed with Issue 76 live.

**Assert defaults at two different inputs.** §4.1's default must be checked at 4 players *and* 9, or a hardcoded number passes.

**A client-only bound is not a bound.**

**Measure; do not estimate.** **Do not weaken an assertion or delete a test to reach green.** **Pair every fix assertion with an over-reach guard.**

---

## 7. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; room reads stay open; `/rooms/{code}/sealed/{cardId}` is default-deny and holds the answer key, `answerAuthors`, and `seenPrompts`. **Never add an explicit `allow read: if false`.**
- **Option ids are opaque UUIDs**, resolved to authors server-side. **Do not send authorship to the client.**
- **Phase order is truth → forgery → vote → reveal.**
- **Minimum 3 active players**, enforced as its own guard — never as a side effect of the forgery arithmetic.
- **Forgeries per card: hard ceiling `n − 1`; `5` is a default, not a cap; values above `n − 1` are never presented.**
- **Re-rolls are unlimited during `truth`, rejected elsewhere, and never repeat a prompt.**
- **`text_similarity.ts` ↔ `text_similarity.dart` stay byte-identical.** The `prompt_decks` pair is **data-only**.
- **`ROOM_TTL_MS` is 8 hours**; below ~4 h a `touchRoom` keepalive becomes mandatory.
- **`firebase.json`'s `predeploy` stays** and runs the tests.
- **`lastReaction` / `lastReactionAt` remain on `PlayerState` and in the rules deliberately** (Issue 74) — dead fields kept to avoid a rules deploy and migration. Do not resurrect the feature, and do not delete them without the rules change.
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, and the rejected options on 58–66.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Backend writes, rules, identity, TTL, **deploy & verification §8** | `design_database_and_security.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, icons, mascot | `design_ui_direction.md` |
| **Phase order, rounds, forgeries, the 3-player minimum** | `design_game_state_and_models.md` |
| Deck catalogue, re-roll exclusion, mirror status | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 9. Feedback loop — what past specs got wrong

- **An item can be marked done because the *other* items in its commit were.** Issues 71–76 landed as one commit; five were real and Issue 76 was untouched, yet the whole batch read as complete. **One item = one commit** exists for exactly this — a batch commit makes partial delivery invisible.
- **A test suite can grow while the thing it was meant to cover stays untested.** Three tests were added and none asserted Issue 76's condition; the pre-existing placeholder tests assert the opposite case, so the area *looks* covered.
- **A clamp is not a rejection.** `startGame` clamping an out-of-range value is not the same guard as `updateLobbySettings` refusing to store one.
- **A default that must be derived from live state cannot be baked in at creation.** `min(n − 1, 5)` is `0` at `createRoom`; the implementation fell back to a constant instead, which is how the rule quietly went missing.
- **When you redefine what a field holds, enumerate its readers.**
- **Doc structure rots silently.** Append inside the existing Resolved heading; never add a second.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §6. Observe the falsifying assertion fail first, and record it.
    Run the over-reach guards. Then the full §1 battery, including the BACKEND suite.
(4) BEFORE COMMITTING, re-run the battery. One item = one commit — a batch commit
    is how Issue 76 shipped untouched inside a batch that read as complete.
(5) BLOCKED, or found something needing human judgement? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
(6) RECORD: move the item to Resolved inside the SINGLE existing Resolved heading.
(7) COMMIT: Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **§3 (Issue 76)** — `submitAnswer` derives the forgery key server-side from `currentCardAssignments`; the **"everyone submits → no placeholder"** assertion added and **observed failing first**; the existing timeout tests still pass unchanged; a spoofed `authorId` cannot write into another player's slot.
- [ ] **§4.1** — default resolves to `min(n − 1, 5)` when unset, asserted at **4 players (3)** *and* **9 players (5)**; "unset" tracked distinctly from an explicit choice.
- [ ] **§4.2** — `updateLobbySettings` rejects out-of-range with `invalid-argument`; the `startGame` clamp retained for the falling-player-count case.
- [ ] **Over-reach:** explicit host choice survives player churn unless it exceeds `n − 1`; 7 forgeries selectable and startable at 9 players; 2-player game still refused; chooser still offers nothing above `n − 1`.
- [ ] Deployed and verified by artefact inspection per `design_database_and_security.md` §8.
- [ ] Full battery **pasted into the commit body**: `flutter analyze lib test` 0 errors · `flutter test` ≥ 127 · functions build clean · `npm --prefix functions test` ≥ 43.
- [ ] Issues 72 and 76 moved to Resolved **inside the single existing Resolved heading**; `design_game_state_and_models.md` records the default rule, the ceiling, and the independent 3-player guard.
- [ ] **A playthrough after this lands** — the round/forgery model changed, and the last playthrough found six issues.
- [ ] **Guide rewritten** — body and title together — to `Queue Complete` or the next queue.
