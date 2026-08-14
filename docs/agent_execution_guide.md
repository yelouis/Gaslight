# Agent Execution Guide — Blocked on two selections; then D1 → D2 → D3 — August 14, 2026

**You are an engineering agent with no memory of this project.**

**What is done.** Issues 78 and 79 are genuinely resolved — verified in source this session, not from commit messages, with real falsifying tests at two inputs (§7). The `votes` contract and the unmask bounds are now written into the design docs. Functions and `firestore.rules` are deployed. **Do not rework any of it.**

**What is not done, and why this guide exists:**

1. **The deploy gap recurred inside the cycle that was meant to close it.** `1122f68` — a Firestore transaction-ordering fix for the round-1 → round-2 transition — was committed at `04:56Z`; the newest deployed function is `04:43Z`. **Production is one commit behind again** (Issue 81).
2. **The playthrough report cannot be trusted as written.** It records 13 PASS / 1 NOT RUN. Four of those verdicts are unsupported: A3/A4 quote **18 prompts from a 12-prompt deck**, none of which exist anywhere in the repository; A9/A10 tested end-of-match navigation instead of the leave/eviction flow and never observed the required string; A12's stated arithmetic is wrong; A13/A14 overclaim (Issue 82).

**Two issues need a `Your selection:` line before the work is fully determined — Issues 81 and 82 in `docs/ongoing_general_errors.md`.** §2 says exactly what is blocked and what is not.

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body.
- **Every quoted game string in any report you write must be findable in source with `grep -F`.** If it cannot be, you did not observe it — record **NOT RUN**. This is not a style rule; it is the check that would have caught Issue 82.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §7 or §8.**

---

## 1. Verified baseline — the regression bar

Measured **August 14, 2026** at `0052741`, clean tree. These are this session's numbers.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (25 warnings, 197 infos — 222 issues) |
| `flutter test` | **130/130** ✅ (was 127; E1/E2 added 3) |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **46/46** ✅ (was 43; E1/E2 added 3) |
| **Deployed functions** | ❌ **ONE COMMIT BEHIND** — newest `04:43Z`, last `functions/src` commit `04:56Z` (Issue 81) |
| **Deployed rules** | ✅ ruleset released `2026-08-14T04:24:13Z`, after `3aa3148` |
| **The playthrough** | ⚠️ 8 of 14 assertions have usable evidence; 5 do not; 1 NOT RUN (Issue 82) |

### The deploy check — run this every pass

`gcloud functions list` shows functions only. **Rules need a different call, and the last two cycles had no way to see them at all:**

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,updateTime)"
```

```bash
TOKEN=$(/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud auth print-access-token); curl -s -H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: gaslight-46368" "https://firebaserules.googleapis.com/v1/projects/gaslight-46368/releases"
```

Compare both against `git log -1 --format=%cI -- functions/src` and `git log -1 --format=%cI -- firestore.rules`. **The `x-goog-user-project` header is required** — without it the Rules API returns `PERMISSION_DENIED / SERVICE_DISABLED`, which reads like a missing API and is really a missing quota project.

**`firebase functions:list` is not a deploy check.** It prints version, trigger, location, memory and runtime — **no timestamps**. Pasting it is what let Issue 81 through.

### ⚠️ Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`** — separate commands. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **`cah_dark_humor` has exactly 12 prompts** (`lib/utils/prompt_decks.dart`, mirrored in `functions/src/prompt_decks.ts`). Any run reporting more re-rolls than that on this deck is reporting something that did not happen.

---

## 2. What is blocked, and what is not

| Item | Depends on | Status |
|---|---|---|
| **D1** — deploy `1122f68` | Issue 81 selection | **All three options begin with deploying.** Only what happens *after* differs. Do not run it until a selection is recorded — the selection line is what authorises a production change. |
| **D2** — deploy-freshness gate | Issue 81 = **A** | Specced in full at §4. Skip entirely if B or C is chosen. |
| **D3** — re-run the unsupported assertions | Issue 82 selection | Scope branches three ways (§5). **A = five assertions, B = all fourteen, C = relabel now and defer.** |
| **Issue 80** | folded into D3 | Verified as part of A13 under options A and B; stays open under C. |

**If both selection lines are still blank: stop and say so.** Do not pick for the user, and do not start D1 "since every option includes it" — a production deploy is not a safe default.

---

## 3. D1 — Deploy `1122f68`

**What this means for the user:** the fix for the round-1 → round-2 transition — the bug the last playthrough hit live — is sitting in the repository and is not in the game. A three-round match today runs the transaction-ordering bug.

### The gap

`1122f68` reorders `advanceToNextResolution` so every `transaction.get` on the sealed documents happens before any write, via `Promise.all`. Firestore requires this; the previous interleaving throws inside the transaction on the round boundary. Committed `2026-08-14T04:56:13Z`; `advanceToNextResolution` in production is from `04:43:19Z`.

### Implementation

1. Confirm a clean tree and the battery at or above §1.
2. Capture the **before** table using the §1 commands — the real one, with `updateTime`.
3. Deploy. `predeploy` runs the suite on this path and needs Java:

```bash
npx firebase-tools deploy --only functions --project gaslight-46368
```

4. Rules are already current (`04:24:13Z` > `3aa3148`). **Re-check anyway** with the Rules API call in §1 — if `firestore.rules` has changed since, deploy it separately.

### Validation

**The falsifying check:** every one of the **14** functions must report an `updateTime` later than `git log -1 --format=%cI -- functions/src`. Paste the before and after tables. Expected functions: `advancePhase`, `advanceToNextResolution`, `castVote`, `createRoom`, `debugAddBots`, `debugSimulateBotResponses`, `handleDisconnect`, `joinRoom`, `rerollPrompt`, `setReady`, `startGame`, `submitAnswer`, `submitUnmaskGuess`, `updateLobbySettings`.

**A partial deploy is a failure, not a partial success.** Two functions disagreeing about a transaction's read/write ordering is worse than either version alone.

Commit only if something changed in the tree; the deploy itself is recorded in D3's report.

---

## 4. D2 — Deploy-freshness gate *(only if Issue 81 = Option A)*

**What this means for the user:** twice now, four fixed issues and then a transaction fix have sat undeployed while every document said "done". A written instruction did not prevent the second occurrence.

### Implementation

Create `scripts/check_deploy_fresh.sh`, executable, no arguments:

1. `LAST_SRC=$(git log -1 --format=%cI -- functions/src)` and `LAST_RULES=$(git log -1 --format=%cI -- firestore.rules)`.
2. Fetch function `updateTime`s with the `gcloud` command in §1 (`--format="value(name,updateTime)"` parses more easily than `table`).
3. Fetch the rules release `updateTime` with the Rules API call in §1, including the `x-goog-user-project` header.
4. **Exit 1** if any function's `updateTime` is earlier than `LAST_SRC`, or the rules release is earlier than `LAST_RULES`. Print the offending names and both timestamps.
5. **Exit 2, with a distinct message, if `gcloud` is absent or unauthenticated.** Option A's stated con is exactly this case — it must be distinguishable from "the deploy is stale", never silently treated as a pass.
6. **Exit 0** otherwise, printing the newest and oldest deployed timestamps so a passing run still shows its work.

Add it to the battery in this guide's §1 as a fifth gate.

### Validation

**The falsifying check, and you must observe both halves:**
- Run it at `HEAD` **before** D1's deploy — or against a temporary commit touching `functions/src` — and watch it **exit 1** and name `advanceToNextResolution`. A gate that has never failed has not been tested.
- Run it after D1 and watch it **exit 0**.
- Run it with `PATH` stripped of `gcloud` and confirm **exit 2** with the credentials message, not a false pass.

Commit: `test(ci): fail the battery when deployed functions or rules lag the tree`.

---

## 5. D3 — Re-run the unsupported assertions

**What this means for the user:** five of the fourteen assertions in the current report say PASS on the strength of things the harness never returned. The eight with real evidence stand; these five have to be earned.

**Scope branches on the Issue 82 selection:**

- **Option A** — re-run **A3, A4, A9, A10, A13** and rewrite those five blocks in place. Leave the other nine.
- **Option B** — discard `docs/playthrough_findings_marionette.md` and re-run **all fourteen**.
- **Option C** — **do not run anything.** Edit the five blocks to `NOT RUN`, stating for each what was recorded and why it is not evidence, and stop. The work stays queued.

### Setup (options A and B)

Marionette is already installed: `marionette_flutter: ^0.6.0`, the binding in `lib/main.dart`, three servers in `.agents/mcp_config.json`, six stable keys from `f3a5a1d`. **Verify rather than redo.**

- **`.env` must contain `USE_EMULATOR=false`** — it is a bundled asset; changing it needs a rebuild.
- **Rebuild after D1.** The client changed in `d34af33` and `1eda59f`; a stale app binary would re-test the old client against the new backend.
- **Debug build. Three real clients. Never `DEBUG: ADD 9 BOTS`** — bots are server-seeded and never traverse the client write path or the rules.
- **One Marionette server holds one connection**; use all three registered entries.
- Boot, uninstall, then launch **one device at a time** (concurrent builds corrupt `build/`):

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl uninstall "$U" com.whylabs.gaslight 2>/dev/null; done
```

```bash
flutter run -d <UDID> --debug > /tmp/gaslight_p1.log 2>&1 &
```

```bash
grep -oE 'http://127\.0\.0\.1:[0-9]+/[^ ]*' /tmp/gaslight_p1.log | tail -1 | sed -e 's|^http|ws|' -e 's|/$|/ws|'
```

**Gate:** `take_screenshots` on all three must show `THE GUEST LEDGER` before any assertion.

**Three hazards, each of which produces a false pass rather than a visible failure:**
1. `get_interactive_elements` on P1 must show `forgeries_*` and `rounds_*` as **distinct keyed elements** before you touch House Rules — both rows are `ChoiceChip`s labelled with bare numerals (`lobby_screen.dart:569`, `:600`).
2. Leave **`Family-Friendly Decks Only` off** (`lobby_screen.dart:643`, defaults `false`) — it hides `cah_dark_humor`.
3. Turn **`Disable Game Timers` on** (`lobby_screen.dart:623`) and record it as a deviation.

Also: `get_interactive_elements` returns only **visible** elements — `scroll_to` first. And labels are literal ALL-CAPS strings; `tap(text: 'Create Room')` will not match `'CREATE ROOM'`.

### The five assertions, and exactly what each needs

**A3 — Re-roll variety.** Select `cah_dark_humor` via `tap(key: 'deck_cah_dark_humor')`, then re-roll repeatedly, capturing the prompt text after each roll.
- **The deck holds 12 prompts. You cannot observe 13 distinct ones.**
- **Anti-fabrication gate, mandatory:** every prompt you record must pass `grep -F "<prompt>" lib/utils/prompt_decks.dart`. Run it. Paste the result. A prompt that does not match is proof the capture is wrong — do not "clean it up", record NOT RUN and say why.
- PASS requires: distinct prompts on every roll, no repeat, all traceable to the deck.

**A4 — Deck exhaustion.** Continue A3 past the 12th prompt.
- The message must read exactly `No more prompts left in this deck.` (`phase2_craft.dart:506`; the server raises it as `resource-exhausted` in `prompt_decks.ts:158`).
- PASS requires that exact string, not the generic fallback, on the roll after the deck is empty.

**A9 — A non-host leaves, mid-session.** **Not `RETURN TO LOBBY` on the Game Over screen** — that is end-of-match navigation and is what the last report mistakenly tested.
- With the game in progress, on P3: `tap(text: 'LEAVE')`, then confirm in the dialog (it uses `showGeneralDialog`; buttons are `STAY` and the leave/close action).
- PASS requires: P3 exits, **and P1 and P2 remain in the room with the roster updated**.

**A10 — The host leaves, mid-session.** Run last; it destroys the room.
- On P1 (host): `tap(text: 'LEAVE')` → `CLOSE ROOM`.
- PASS requires P2 and P3 to show exactly **`The host has left. This room has closed.`** — verbatim, including the period (`lobby_screen.dart:369`). **This string has never once been observed in eight cycles.** If it does not appear, that is a finding, not a retry.

**A13 — Revenge tray and unmask correctness.** Three separate things, each recorded separately:
1. The candidate chips **exclude the card's target** and include the other forger.
2. A player who fell for a forgery accuses **the correct forger** → the result reads success, **and the guesser's `+1` is visible in `STANDINGS`**, not merely "resolved gracefully". **This is Issue 80's verification and the only thing that closes it.**
3. Attempting to accuse the card target is rejected. If the client no longer offers it, say so and mark this sub-item **NOT RUN via the UI** — the server guard is covered by `game_e2e.spec.ts:1805`.

### Record

Rewrite the affected blocks of `docs/playthrough_findings_marionette.md` in place (option A) or the whole file (option B), same format:

```markdown
### A3 — Re-roll variety

**Verdict:** PASS | FAIL | NOT RUN
**Devices:** P1 `iPhone 17 Pro` (host, Alpha)
**What I did:** <the exact tool calls, in order>
**What I observed, verbatim:** <exact strings the tool returned>
**grep -F traceability:** <the command and its result>
**Expected:** <what the assertion required>
**Evidence:** docs/playthrough_evidence/a3_p1.png
```

Also in the header: the **post-D1 deploy table with `updateTime`s**, the rules release timestamp, the rebuild commit, and the timers deviation.

**Fix the two blocks you are not re-running but that are wrong:** A12's stated formula. With 3 players and 2 forgeries per card the truth reward is `ceil((3 − 1) / (2 + 1)) = 1`, not the `+2` recorded. Correct the arithmetic and state whether the observed chips match it. A14 must be a clean `NOT RUN` — delete the "verified via Jest unit tests" claim, or cite the test by `file:line` if one genuinely exists.

**Do not write into `ongoing_general_errors.md`.** Findings go in the findings doc; converting a failure into a tracked issue with options is a separate step.

Commit: `docs(playthrough): re-run and correct unsupported assertions`.

---

## 6. Do not invent work · escalation

Outside D1–D3 there is no queue. Legitimate triggers for further work: a defect D3 surfaces, a user-selected issue, or a §8 trigger firing (the TTL interval dropping below ~4 hours, or a sibling glyph turning out wrong).

**Bounded deviation:** if an exact value or step is impossible, keep the intent, deviate minimally, note it in the commit body.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel (Issue 78 Option B, declined), **do not** disable `predeploy` to force a deploy through, **do not** fall back to `DEBUG: ADD 9 BOTS`, and **do not** reconstruct an observation you did not capture.

---

## 7. Already delivered — do NOT rework

**Verified in source August 14, 2026, at `0052741`:**

- **Issue 78** — the `'TRUTH'` sentinel is gone. All nine readers resolve truth votes as `votedForId == card.targetPlayerId` (`scoring_logic.ts:54`, `scoring_logic.dart:25`, `phase4_reveal.dart:105/250/265/359/554/764`, `index.ts:1566`); the dead disjunct at `index.ts:1378` is removed; the stale contract comment at `scoring_logic.dart:13` is corrected; the dead `_generateShuffledAnswers` path is deleted from `phase3_vote.dart`. Tests assert the reward at two inputs — `P=4,S=1 → 2` (`game_e2e.spec.ts:1684`) and `P=5,S=3 → 1` (`:1793`) — each with an over-reach guard, mirrored in `test/scoring_logic_test.dart`. **The acceptance grep now returns only `phase2_craft.dart:161`, which is a UI label.**
- **Issue 79** — the card target is excluded client-side (`phase4_reveal.dart:694`) and rejected server-side with `invalid-argument` (`index.ts:1394`), both carrying the paired-guard comment. Test at `game_e2e.spec.ts:1805`.
- **Issue 77** — functions deployed `2026-08-14T04:23–04:43Z`; rules ruleset released `04:24:13Z`. **Superseded only by the one-commit lag in Issue 81 — do not re-deploy the whole history.**
- **Issue 76** — `submitAnswer` validates against `room.currentCardAssignments?.[authorId]`.
- **Issue 72** — default `Math.min(activePlayers.length - 1, 5)` derived from the live count; `updateLobbySettings` rejects out-of-range; the 3-player floor is its own guard.
- **Issue 71** — `castVote` resolves option ids via `sealedData.answerAuthors`. **This is the change that created Issue 78** — it was correct, and its readers were not enumerated.
- **Issues 50–75** as previously recorded. **Issue 31** — the server uses loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 8. Accepted equivalents & invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`. Full contract: `design_game_state_and_models.md` §2. **This field has been redefined twice and broken its readers both times — if you change it again, enumerate every reader in both languages.**
- **Who may accuse and who may be accused are two separate bounds** and are enforced in two places by design (`design_scoring_and_ui.md`). Change both or neither.
- **`scoring_logic.{ts,dart}` must stay semantically identical**, as `text_similarity` must stay byte-identical.
- **Issue 76 validates rather than re-derives** — same guarantee, different structure. Leave it.
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **The non-host carousel is interactive-but-inert, not dimmed.** **The leave dialog uses `showGeneralDialog`.**
- **`lastReaction` / `lastReactionAt` stay on `PlayerState` and in the rules deliberately** (Issue 74).
- **Sealed documents are created lazily**, not at `startGame`. **`_ThematicIconPainter` carries unreachable fallback cases** — do not wire them up.
- **Server-authoritative**; room reads stay open; `/rooms/{code}/sealed/{cardId}` is default-deny. **Never add an explicit `allow read: if false`.**
- **Option ids are opaque UUIDs**, resolved server-side. **Never send authorship to the client.**
- **Phase order is truth → forgery → vote → reveal.** **Minimum 3 active players**, its own guard.
- **Forgeries per card: hard ceiling `n − 1`; `5` is a default, not a cap.** **Re-rolls unlimited during `truth`, rejected elsewhere, never repeating.**
- **`ROOM_TTL_MS` is 8 hours**; below ~4 h a host-only `touchRoom` keepalive plus a client timer become mandatory.
- **`firebase.json`'s `predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, Issue 34 C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, Issue 78 B/C, Issue 79 B, and the rejected options on 58–66.

---

## 9. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| **`votes` contract, card/player/game schemas, phase order** | `design_game_state_and_models.md` |
| **Scoring formulas, reveal beats, unmask bounds** | `design_scoring_and_ui.md` |
| Backend writes, rules, identity, TTL, deploy & verification §8 | `design_database_and_security.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| Palette, typography, icons, mascot | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 10. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the output.

**A test that asserts the happy path of a bug is not a test for the bug.** `game_e2e.spec.ts` had all three players vote the truth and asserted only that the phase became `reveal` — which is why Issue 78 shipped green.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** Quote what the tool returned, or record NOT RUN. `grep -F` every game string you quote.

**Assert a derived value at two different inputs** — one value cannot pass both.

**A clamp is not a rejection. A client-only bound is not a bound.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard.**

**A driven playthrough is not a played one.** It can check every literal string and still miss pacing, confusion, and whether the game is fun.

---

## 11. Feedback loop — what past specs got wrong

- **A report can be fluent, specific, internally consistent, and fabricated.** Eighteen prompts were quoted from a twelve-prompt deck; none exist in the repository. Everything around them was good work. **The defence is mechanical traceability, not scrutiny** — which is why `grep -F` is now a standing constraint rather than advice.
- **An assertion can be marked PASS by testing something adjacent.** A9/A10 asked about leaving a room mid-session; the report tested `RETURN TO LOBBY` after the match ended and recorded PASS for both. **When an assertion names a verbatim string, the absence of that string in the report is the tell.**
- **"Verified in source" is not "shipped," and a written instruction did not fix it.** The instruction existed, was followed with `firebase functions:list`, and produced a table with no timestamps. **When a step fails twice, replace it with a tool** (D2).
- **When you redefine what a field holds, enumerate its readers.** `votes` has now done this twice. A sentinel value is what makes the failure invisible.
- **One item = one commit** — Issues 71–76 landed as one commit; five were real, one untouched, and the batch read as complete.
- **The manual gate earns its keep every time it runs.** Two playthroughs, eleven defects, none visible to four green gates. **And a fabricated gate costs more than no gate**, because it retires the suspicion that would have found them.
- **Doc structure rots silently.** Append inside the existing Resolved heading; never add a second.

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified.
(4) VALIDATE per §10, including the over-reach guard.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING the deploy check.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading;
    playthrough observations go to docs/playthrough_findings_marionette.md.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **Selections recorded** on Issues 81 and 82 before any of D1–D3 begins.
- [ ] **D1** — all **14** functions report an `updateTime` later than the last `functions/src` commit; before/after tables with timestamps pasted into the findings doc.
- [ ] **D2** *(if Issue 81 = A)* — `scripts/check_deploy_fresh.sh` observed **exiting 1** on a stale deploy, **0** after D1, and **2** without `gcloud` credentials; added to §1's battery.
- [ ] **D3** — per the Issue 82 selection. Under A or B, every re-run assertion carries a `grep -F` traceability line, and **A10 records whether `The host has left. This room has closed.` actually appeared**.
- [ ] **Issue 80 closed or restated** — an accusation observed reporting success with the guesser's `+1` visible in standings, or an explicit statement that it was not observed.
- [ ] **A12 corrected** and **A14 reduced to a clean NOT RUN**, whichever option is chosen.
- [ ] Battery at or above §1: **0 errors** · **≥130** · clean build · **≥46** · deploy check green.
- [ ] **Nothing fixed inline during D3.** Failures are described, not repaired.
