# Agent Execution Guide — Active Build: T0 → T1 → T2 — August 16, 2026

**You are an engineering agent with no memory of this project.**

**What is done, and independently verified in source and against the live project — not from commit messages.** Issues 1–87 are delivered and deployed. Every over-reach guard the last wave specced is genuinely present, including the one that mattered most: the assertion that a start succeeds while the **host's own** `lobbyReady` is false (§5). **Do not rework any of it.**

**What this build does.** Issue 88 recorded two assertions that were specced and not delivered. The user selected **Option B — do both.**

| Item | Issue | What it is |
|---|---|---|
| **T0** | 88.1 | Repoint A4's stale forward reference. The record currently promises coverage and cites unrelated evidence. |
| **T1** | 88.2 | Add the timers-disabled regression guard — the state the `leading`-slot design exists for. |
| **T2** | 88.1 | Verify the deck-exhaustion SnackBar on device. Closes the last gap Option C left open. |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body.
- **Every quoted game string in any report must be findable in source with `grep -F`**; any count-dependent assertion must state the count, the deck, and the deck's size.
- **When you renumber an assertion list, grep for inbound references and repoint them in the same pass.** T0 exists because this was not done.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not fix anything inline during T2.** Failures are described, not repaired.
- **Do not touch anything in §5 or §6.**

---

## 1. Verified baseline — the regression bar

Measured **August 16, 2026** at `3eb9595`, clean tree.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (222 issues) |
| `flutter test` | **137/137** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **53/53** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ |

**Run the deploy gate as the fifth gate every pass.** Its contract — three exit codes, epoch-second comparison, function-count check, the Rules API's mandatory `x-goog-user-project` header — is in `design_database_and_security.md` §8. **Exit 2 means "could not verify" and must never be reported as a pass.** **This build changes no server code, so no deploy is required** — but the gate must still read 0 before you record a result.

### ⚠️ Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`. **T1 needs this.**
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**.
15. **`git` and Google timestamps must never be string-compared.**
16. **A spec can demand something the app cannot do.** **The previous version of this guide told the next agent that T2 needed "one device — do not stand up three." That was wrong** — see §4. Before asserting against a flow, grep the guards that gate reaching it.
17. **A cross-reference between assertions goes stale silently.** T0 is the live instance.

---

## 2. T0 — Repoint A4's dangling reference

**What this means for the user:** the evidence record promises that deck exhaustion was queued for UI verification, and points at a paragraph about players leaving mid-match. A reader concludes the gap is covered.

### The gap

`docs/playthrough_findings_marionette.md` records A4 as **NOT RUN via the UI**, states its gap honestly, and ends *"Queued for re-verification in S7 (Assertion A20)."* **A20 in that same document is "Mid-Game Departure & Auto-End Below 3 Players."** The list was renumbered mid-run and the pointer was never repointed. `grep -n "No more prompts left" docs/playthrough_findings_marionette.md` returns exactly **one** hit — A4's own *Expected* line.

### Implementation

Edit A4's **Gap** line only. Replace the `(Assertion A20)` pointer with a statement that survives renumbering:

```markdown
- **Gap:** Option C verifies the exhaustion boundary and per-player sealed-document isolation in the emulator suite (`cah_dark_humor` @ 12 prompts, `the_daily_grind` @ 20 prompts), but **the client SnackBar path at `phase2_craft.dart:507` is covered by no test at any level and has not been observed since August 13.** Tracked as Issue 88.1 — not queued to any assertion number in this document.
```

**Do not change A4's verdict, and do not renumber A20.** The record of what ran is correct; only the forward reference is wrong. **T2 will replace this block entirely** — T0 exists so that if T2 is interrupted, the document is still honest.

### Validation

`grep -c "Assertion A20" docs/playthrough_findings_marionette.md` → **0**. A4's Gap names Issue 88.1. No verdict changes anywhere.

Commit: `docs(playthrough): repoint A4's stale reference to Issue 88.1`.

---

## 3. T1 — The timers-disabled regression guard

**What this means for the user:** the leave control sits in the app bar's `leading` slot precisely because `actions` empties out when timers are disabled. Nothing tests the state that motivated the design.

### The gap

The S5 spec required widget tests asserting the leave control renders on all three phase screens **including when `isTimerDisabled` is true**. `test/in_game_leave_test.dart` has three `testWidgets` cases and **no reference to `isTimerDisabled` at all**. A18 in the findings report claims *"Visible across all players regardless of timer configuration"*, but its only recorded observation is a single bounds rectangle on `/craft` with the timer state unstated.

**The risk is low and the gap is still real.** `leading` and `actions` are independent slots, so the control cannot vanish with the timer today. It becomes a real risk the moment someone refactors an app bar — which is exactly what a regression guard is for.

### Implementation

Extend `test/in_game_leave_test.dart`. For each of `Phase2CraftScreen`, `Phase3VoteScreen`, `Phase4RevealScreen`, add a case that pumps the screen with a `GameState` whose **`isTimerDisabled` is `true`**, asserting **both**:

1. the leave `IconButton` with `tooltip: 'Leave game'` **is present**; and
2. **`AutoAdvanceTimer` is absent.**

**The second assertion is not decoration — without it the test passes against a fixture where timers are enabled and verifies nothing.** It is what proves the fixture actually reached the timer-disabled branch (`state.isTimerDisabled ? const SizedBox.shrink() : AutoAdvanceTimer(...)` in each screen's `actions`).

Reuse the existing fixture helper in that file — the three current cases already build a `GameState`, so this is a parameter flip plus two assertions. Set `accessibleNavigation: true` (trap 7).

### Validation

**The falsifying observation, and you must actually perform it.** Temporarily move the leave `IconButton` from `leading` into `actions` in `lib/screens/phase2_craft.dart`, run the suite, and confirm:

- the **new timer-disabled case fails** (the button is now inside the branch that renders `SizedBox.shrink()`), and
- the **existing timers-enabled case still passes** — which is precisely why the existing tests never caught this.

**Then revert the move.** Record both outcomes in the commit body. A guard that has never failed has not been tested.

Battery: `flutter test` **≥140**.

### Blast radius

`test/in_game_leave_test.dart` only. No production code changes.

Commit: `test(game): assert the leave control survives timers being disabled`.

---

## 4. T2 — Verify the exhaustion SnackBar on device

**What this means for the user:** when a deck runs dry the game should say so plainly rather than falling back to a generic error. The server behaviour is proven at two deck sizes; the sentence the player actually reads is proven nowhere.

### ⚠️ This needs three devices, not one

**The previous guide said "one device is enough — do not stand up three." That was wrong, and it is worth understanding why before you start.** `RE-ROLL PROMPT` renders only on `phase2_craft.dart:519`, and `rerollPrompt` rejects anything but the truth phase:

```ts
if (room.currentPhase !== "truth") {
  throw new HttpsError("failed-precondition", "Prompt re-rolls are only allowed during the truth phase.");
}
```

Reaching the truth phase means `startGame`, which enforces **3 active players** *and*, since Issue 86, **every non-host marked ready**. There is no re-roll in the lobby. **Grep the guards that gate a flow before asserting against it** — this is trap 16, and this guide was the one that tripped it.

**Bounded exception, for T2 only.** The standing rule is never to use `DEBUG: ADD 9 BOTS` in a playthrough, because bots are server-seeded and never traverse the client write path or the rules. **That rationale does not apply here**: every assertion in T2 concerns the host's own device — their re-roll calls, their prompt list, their SnackBar — and the other two seats exist only to satisfy the player floor. Bots also carry `lobbyReady: true` (`index.ts:1481`), so they satisfy Issue 86's gate. **You may use bots to reach the truth phase for T2, and you must record it as a deviation.** The ban stands everywhere else, and nothing about this exception generalises — if any future assertion depends on what another player writes, use real clients.

### Setup

- **`.env` must contain `USE_EMULATOR=false`** — it is a bundled asset, so a change requires a rebuild, not a hot reload.
- **Rebuild the client.** `lib/` changed across S1, S3, S4 and S5; a stale binary would test the old client.
- Debug build. Uninstall first so nothing restores a stale room:

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl uninstall "$U" com.whylabs.gaslight 2>/dev/null; done
```

- Launch **one device at a time** — concurrent builds corrupt `build/`.
- Turn **`Disable Game Timers` on** (`lobby_screen.dart:623`) and record it. Leave **`Family-Friendly Decks Only` off** (`lobby_screen.dart:643`) — it hides `cah_dark_humor`.
- **Select `cah_dark_humor` — 12 prompts, the short path.** `tap(key: 'deck_cah_dark_humor')`. **Count the deck first** and put the number in the report before rolling:

```bash
awk "/'cah_dark_humor': \[/,/^    \],/" lib/utils/prompt_decks.dart | grep -cE '^\s+"'
```

- **Shut the simulators down when finished:** `xcrun simctl shutdown all`.

### The assertion

Start the match, then on the host device re-roll continuously, recording every prompt in order.

**The arithmetic, stated explicitly in the report:** the deck holds **12**. The host's card consumes **1** at deal, and `seenPrompts` is per-sealed-document, so the host's exclusion set begins with only their own prompt. Therefore **re-rolls 1 through 11 must each return a new distinct prompt** (12 seen in total), and **re-roll attempt 12 must produce the exhaustion message**.

- `grep -cF` every recorded prompt against `lib/utils/prompt_decks.dart` and paste the commands and their output. A prompt returning `0` means the capture is wrong — **do not tidy it up; record NOT RUN and say what happened.**
- **PASS requires the exact string `No more prompts left in this deck.`** (`phase2_craft.dart:507`) — **not** the generic fallback `Something went wrong. Try again.` — on attempt 12, and the count reconciling at 11.

**If the message appears early, or the generic fallback appears instead: STOP and file it** with the deck, its size, the ordered prompt list and the attempt index. That is a real defect in the machinery Issue 67 rebuilt and the error plumbing Issue 68 fixed — **it is not fixed inline.**

### Record

**Replace A4 wholesale** with a real verdict in the standard block format: devices, the exact tool calls, the ordered prompt list, the `grep -cF` traceability output, the reconciling arithmetic, the verbatim message, and evidence. Update the header's `Provenance:` line to cover this run and note the bots deviation.

Commit: `docs(playthrough): verify the deck exhaustion SnackBar on device`.

---

## 5. Already delivered — do NOT rework

**Verified in source and against the live project, August 16, 2026, at `3eb9595`:**

- **Issue 84** — `DialogThemeData` at `main.dart:86` (Flutter 3.44 requires that type); copy at `phase3_vote.dart:204`. `test/dialog_theme_contrast_test.dart` asserts **≥4.5:1** content **and ≥3.0:1** title.
- **Issue 83 (Option C)** — `game_e2e.spec.ts:1959`, parameterised over **both** deck sizes with the per-player isolation guard.
- **Issue 87** — one test covers host kick succeeding **and** a non-host kicking a third player being rejected. **That second half is the bound; never relax it.**
- **Issue 86** — `index.ts:264` filters `!p.isHost && p.lobbyReady !== true`; the test reads the host document and **asserts `lobbyReady` is not true before proving the start succeeds.**
- **Issue 85** — `index.ts:909` applies `phase !== "lobby" && activePlayerCount < 3` **after** the phase-specific branches so it wins; three tests cover the auto-end, the 4-player over-reach and the lobby exemption. Leave control in `leading` on all three phase screens.
- **Issues 77–82** — sentinel purge, unmask bounds, deploy of all 14 functions and rules, and the freshness gate whose three exit codes were each exercised.
- **Issues 50–76** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 6. Invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId` (`design_game_state_and_models.md` §2).
- **The readiness gate exempts the host deliberately** — the host has no ready toggle, so requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`, never a falsy check. **Separate guard from the 3-player floor.**
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase-specific branches, and computes no scores.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player must stay rejected with `permission-denied`** (`design_database_and_security.md` §4). **Never add a separate kick or quit callable.**
- **Dialogs render on `groundRaised`, never on `colorScheme.surface`** (`design_ui_direction.md` §6). The regression guard asserts a **ratio**, not a string.
- **Re-rolls are unlimited during `truth`, rejected in every other phase, and never repeat a prompt.** **`seenPrompts` is per-sealed-document, not global** — T2's arithmetic depends on this.
- **Who may accuse and who may be accused are two separate bounds** (`design_scoring_and_ui.md`).
- **The deploy gate's three exit codes are a contract.** Collapsing exit 2 into 0 defeats the mechanism.
- **`scoring_logic.{ts,dart}` semantically identical; `text_similarity` byte-identical.**
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **Server-authoritative**; `/rooms/{code}/sealed/{cardId}` is default-deny; **never add an explicit `allow read: if false`.** **Option ids are opaque UUIDs**; never send authorship to the client.
- **Phase order is truth → forgery → vote → reveal.** **Forgeries per card: ceiling `n − 1`; 5 is a default, not a cap.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, 34 C, 57 B/C, 67 A/C, 68 B/C, 69 B/C, 70 A/C, 71 B/C, 76 B, 78 B/C, 79 B, 81 B/C, 82 B/C, 83 A/B, 84 B/C, 85 B/C, 86 B/C, 87 B/C, **88 A/C**, and the rejected options on 58–66.

---

## 7. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| **Phase order, 3-player floor (start *and* in play), readiness gate, `votes` contract** | `design_game_state_and_models.md` |
| Scoring formulas, reveal beats, unmask bounds | `design_scoring_and_ui.md` |
| **Deploy & the freshness gate (§8); `handleDisconnect`'s callers (§4)** | `design_database_and_security.md` |
| **Dialog surface & contrast rule (§6)** | `design_ui_direction.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| **Deck catalogue, re-roll exclusion** | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 8. Do not invent work · escalation

Outside T0–T2 there is no queue. Legitimate triggers: a defect T2 surfaces, a user-selected issue, or the TTL interval dropping below ~4 hours.

**Bounded deviation:** keep the intent, deviate minimally, note it in the commit body — **and record any substitution of deck, device or fixture.** An unrecorded deck substitution is what made Issue 83 unreadable.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel, **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** use bots outside T2's bounded exception, and **do not** reconstruct an observation you did not capture.

---

## 9. Validation standard

**Write validation that fails against the broken state, and observe it fail.** T1 says exactly how: move the button, watch the new case fail and the old one pass, move it back.

**A test that asserts the happy path of a bug is not a test for the bug.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every game string you quote.

**Traceable quotes do not make a report arithmetically sound.** State the count, the deck, and the deck's size.

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs.** **A clamp is not a rejection. A client-only bound is not a bound.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard — and make sure the guard can actually fail.** T1's `AutoAdvanceTimer`-absent assertion exists for exactly this reason.

**A driven playthrough is not a played one.** Every item in the last two waves came from a human with three simulators, not from a gate.

---

## 10. Feedback loop — what past specs got wrong

- **A cross-reference survives a renumber; the promise it made does not.** A4 was honestly marked NOT RUN and pointed at a future assertion; the list was renumbered mid-run and the pointer went stale. **Grep for inbound references whenever you renumber anything.**
- **This guide told the next agent to do something impossible.** The previous revision specced T2 as a one-device task; re-roll requires the truth phase, which requires three players and — since Issue 86 — every non-host ready. **A guide is not exempt from trap 16. Grep the guards before writing the setup.**
- **A specced assertion can be quietly dropped while the item it belongs to is genuinely finished.** Issues 83–87 all shipped correctly; two of their assertions did not. **"The code is right" and "the coverage is complete" are separate claims.**
- **The backend keeps being ahead of the client.** Mid-match departure, host removal and lobby readiness were all built server-side and either unreachable or never consulted.
- **A computed value that feeds a `decoration` looks like a gate and is not.** Grep where a guard value is *read*, not just where it is computed.
- **Fixing a class of defect promotes the next one.** Fabricated quotes → arithmetic that did not add up → missing controls → dropped assertions → stale cross-references.
- **When a written step fails twice, replace it with a tool.** `check_deploy_fresh.sh` ended a two-cycle deploy gap.
- **When you redefine what a field holds, enumerate its readers.**
- **One item = one commit.** **Doc structure rots silently** — append inside the single existing Resolved heading.

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

- [ ] **T0** — `grep -c "Assertion A20"` returns **0**; A4's Gap names Issue 88.1 and states the path is unverified; no verdict changed.
- [ ] **T1** — timer-disabled case on all three screens, asserting the leave button **present** *and* `AutoAdvanceTimer` **absent**.
- [ ] **T1 falsification** — the guard **observed failing** with the button temporarily moved to `actions`, the timers-enabled case observed still passing, and the move reverted. Both outcomes in the commit body.
- [ ] **T2** — A4 replaced with a real verdict: the deck named, its size **12** stated, **11** distinct prompts listed in order, `grep -cF` output per prompt, the reconciling arithmetic written out, and the exact string `No more prompts left in this deck.` on attempt **12**.
- [ ] **T2** — the bots deviation recorded in the header, and the `Provenance:` line updated to cover this run.
- [ ] **Simulators shut down** (`xcrun simctl shutdown all`) once T2 is recorded.
- [ ] Battery at or above §1: **0 errors** · **≥140** · clean build · **53/53** · deploy gate exit **0**.
- [ ] **Nothing fixed inline during T2.** If the exhaustion message misbehaves, it is filed, not repaired.
