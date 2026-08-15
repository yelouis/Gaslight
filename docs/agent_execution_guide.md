# Agent Execution Guide — Active Build: D1 → D2 → D3 — August 14, 2026

**You are an engineering agent with no memory of this project.**

**What is done.** Issues 78 and 79 are genuinely resolved — verified in source this session, not from commit messages, with real falsifying tests at two inputs (§7). The `votes` contract and the unmask bounds are written into the design docs. Functions and `firestore.rules` are deployed. **Do not rework any of it.**

**What this build fixes, both selected by the user as Option A:**

| Item | Issue | What it is |
|---|---|---|
| **D1** | 81 | Deploy `1122f68`. Production is **one commit behind** — the transaction-ordering fix for the round-1 → round-2 boundary is not live. |
| **D2** | 81 | Add `scripts/check_deploy_fresh.sh` and make it a battery gate. The written instruction has now failed twice; replace it with a tool. |
| **D3** | 82 | Re-run and rewrite the five playthrough assertions whose evidence does not survive being asked "how do you know?" — **A3, A4, A9, A10, A13** — and correct A12 and A14 in place. |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.** Full issue text and rationale live in `docs/ongoing_general_errors.md`; this guide is the how.

---

## Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body.
- **Every quoted game string in any report you write must be findable in source with `grep -F`.** If it cannot be, you did not observe it — record **NOT RUN**. This is not a style rule; it is the check that would have caught Issue 82.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not fix anything inline during D3.** Failures are described, not repaired.
- **Do not touch anything in §7 or §8.**

---

## 1. Verified baseline — the regression bar

Measured **August 14, 2026** at `0052741`, clean tree. This session's numbers.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (25 warnings, 197 infos — 222 issues) |
| `flutter test` | **130/130** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **46/46** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0 (FRESH)** ✅ — all 14 functions and rules exceed latest tree commits |
| **Deployed functions** | ✅ **14/14 DEPLOYED** — newest `2026-08-14T17:48:24Z`, after `1122f68` |
| **Deployed rules** | ✅ ruleset released `2026-08-14T04:24:13Z`, after `3aa3148` |
| **The playthrough** | ✅ **13 PASS, 1 NOT RUN (A14)** — all verbatim quotes source-verified via `grep -Fn` |

### The deploy check — until D2 lands, run these by hand

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,updateTime)"
```

```bash
TOKEN=$(/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud auth print-access-token); curl -s -H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: gaslight-46368" "https://firebaserules.googleapis.com/v1/projects/gaslight-46368/releases"
```

**`gcloud functions list` cannot see rules** — that is what the second call is for, and **the `x-goog-user-project` header is required**: without it the Rules API returns `PERMISSION_DENIED / SERVICE_DISABLED`, which reads like a disabled API and is really a missing quota project.

**`firebase functions:list` is not a deploy check.** It prints version, trigger, location, memory and runtime — **no timestamps**. Pasting it is what let this gap through twice.

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
15. **Timestamps from `git` and from Google are in different forms and must never be string-compared.** See D2 — this one is measured, not theoretical.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| **D1** | Deploy `1122f68` | First. D3 must not run against a backend missing the round-boundary fix — A11 exercises exactly that path, and re-testing on a stale build is the mistake that produced this whole queue. |
| **D2** | `check_deploy_fresh.sh` | Immediately after D1, **and its falsifying test needs the pre-D1 stale state** — see §4. Read §4 before running D1 so you capture what you need. |
| **D3** | Re-run five assertions | Last. Needs a client rebuild (D1's backend plus the `d34af33` / `1eda59f` client changes) and a green deploy check. |

---

## 3. D1 — Deploy `1122f68`

**What this means for the user:** the fix for the round-1 → round-2 transition — the bug the last playthrough hit live — is in the repository and not in the game. A three-round match today runs the transaction-ordering bug.

### The gap

`1122f68` reorders `advanceToNextResolution` so every `transaction.get` on the sealed documents happens before any write, batched through `Promise.all`. Firestore requires all reads to precede all writes in a transaction; the previous interleaving threw on the round boundary. Committed `2026-08-14T04:56:13Z`; `advanceToNextResolution` in production is from `04:43:19Z`.

### Implementation

1. Confirm a clean tree and the battery at or above §1.
2. **Capture the "before" state and keep it** — D2's test needs it and D3's report must publish it:

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,updateTime)" > /tmp/deploy_before.txt
```

3. Deploy. `predeploy` runs the suite on this path and needs Java:

```bash
npx firebase-tools deploy --only functions --project gaslight-46368
```

4. Rules are current (`04:24:13Z` > `3aa3148`). **Re-check anyway** with the Rules API call in §1; if `firestore.rules` has changed since, deploy it separately with `--only firestore:rules`.

### Validation

**The falsifying check:** every one of the **14** functions must report an `updateTime` later than `git log -1 --format=%cI -- functions/src`. Save the after-table too. Expected functions: `advancePhase`, `advanceToNextResolution`, `castVote`, `createRoom`, `debugAddBots`, `debugSimulateBotResponses`, `handleDisconnect`, `joinRoom`, `rerollPrompt`, `setReady`, `startGame`, `submitAnswer`, `submitUnmaskGuess`, `updateLobbySettings`.

**A partial deploy is a failure, not a partial success.** Two functions disagreeing about a transaction's read/write ordering is worse than either version alone.

**If the deploy fails**, do not retry blindly and **do not disable `predeploy`** to get past it. Record the error and STOP per §6.

---

## 4. D2 — `scripts/check_deploy_fresh.sh`

**What this means for the user:** twice now, real fixes have sat undeployed while every document said "done". The instruction to check already existed both times. It was followed with the wrong command and produced a table with no timestamps in it.

### The gap

Nothing in the battery can fail because of a stale deploy. `flutter test` and `npm --prefix functions test` both run entirely against local code and emulators.

### Implementation

Create `scripts/check_deploy_fresh.sh`, executable (`chmod +x`), no arguments.

**Inputs — take the git side as epoch seconds directly, so there is nothing to parse:**

```bash
LAST_SRC=$(git log -1 --format=%ct -- functions/src)
LAST_RULES=$(git log -1 --format=%ct -- firestore.rules)
```

**Deployed function times:**

```bash
gcloud functions list --project=gaslight-46368 --format="value(name,updateTime)"
```

`value(...)` emits tab-separated rows and is far easier to parse than `table(...)`. Use the absolute path `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`, or resolve it via `command -v gcloud` with that path as the fallback — **`~/.pub-cache/bin` and the gcloud SDK are both absent from this shell's `PATH`.**

**Deployed rules time:** the Rules API call from §1, reading `.releases[0].updateTime`. **The `x-goog-user-project: gaslight-46368` header is mandatory.**

**⚠️ The trap that makes this script worth writing — do not string-compare timestamps.** `git` emits `2026-08-13T21:56:13-07:00`; Google emits `2026-08-14T04:43:19.711837007Z`. Measured on this repo's real values:

```
'2026-08-13T21:56:13-07:00' > '2026-08-14T04:43:19.711837007Z'   →  False
```

…so a lexicographic comparison concludes the deploy is **fresh**. In epoch seconds the commit is `1786683373` and the deploy is `1786682599` — the deploy is **774 seconds stale**. **A naive comparison produces exactly the false pass this gate exists to prevent.** Convert every Google timestamp to epoch seconds before comparing:

```bash
python3 -c "
import sys
from datetime import datetime
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    name, ts = line.split('\t')
    # Truncate fractional seconds: Google emits 9 digits, which older
    # Pythons reject. Slicing to the whole second is enough for a
    # freshness check and is version-independent.
    print(name, int(datetime.fromisoformat(ts[:19] + '+00:00').timestamp()))
"
```

**Exit codes — three distinct outcomes, and conflating any two of them defeats the gate:**

| Code | Meaning | Required output |
|---|---|---|
| **0** | Fresh | The newest and oldest deployed timestamps, so a passing run still shows its work |
| **1** | **Stale** | Every offending function by name, with its deployed time and the commit time it lags, in both ISO and epoch form |
| **2** | **Cannot tell** — `gcloud` missing, unauthenticated, or the Rules API call failed | An explicit "could not verify" message naming the cause |

**Exit 2 must never be treated as a pass.** This is Option A's stated cost, and it is the whole reason the code is distinct: a machine without credentials must report *"I could not check"*, never *"the deploy is fine"*. A gate that reports success when it did not run is worse than no gate — that is the shape of the defect in Issue 82.

Also check the **count**: if fewer than **14** functions come back, exit 1 and name what is missing. A function that failed to deploy does not appear with an old timestamp; it may not appear at all.

**Then add it to the battery** as a fifth gate, in this guide's §1 table and in `docs/ongoing_general_errors.md` §2.10.

### Validation

**Observe all three exit codes. A gate that has never failed has not been tested.**

1. **Exit 1 — the stale case.** Easiest honest route: run the script **before D1's deploy**, at a tree where `1122f68` is committed. It must exit 1 and name `advanceToNextResolution`. *This is why §2 says to read §4 before running D1* — once you deploy, the naturally stale state is gone and you would have to manufacture one with a throwaway commit touching `functions/src`.
2. **Exit 0 — the fresh case.** Run it after D1.
3. **Exit 2 — the cannot-tell case.** Run it with `gcloud` unreachable, e.g. `PATH=/usr/bin:/bin ./scripts/check_deploy_fresh.sh` with the absolute-path fallback also pointed somewhere non-existent. Confirm it exits **2** with the credentials message and **not** 0.

**Over-reach guard:** after D1, make a trivial commit touching `functions/src` (a comment) and confirm the script flips back to exit 1 without a redeploy, then revert it. A script that only ever returns 0 after a deploy might be comparing against the wrong commit.

Record all three observed exit codes in the commit body.

Commit: `test(ci): fail the battery when deployed functions or rules lag the tree`.

### Blast radius

`scripts/check_deploy_fresh.sh` (new), this guide's §1 battery table, `docs/ongoing_general_errors.md` §2.10.

---

## 5. D3 — Re-run five assertions and correct two more

**What this means for the user:** five of the fourteen assertions say PASS on the strength of things the harness never returned. The eight with real evidence stand; these have to be earned.

**Scope, per the Issue 82 Option A selection:** re-run **A3, A4, A9, A10, A13**. Rewrite those five blocks in place. Correct **A12** and **A14** in place without re-running them. **Leave the other seven blocks alone.**

### Setup

Marionette is already installed: `marionette_flutter: ^0.6.0`, the binding in `lib/main.dart`, three servers in `.agents/mcp_config.json`, six stable keys from `f3a5a1d`. **Verify rather than redo.**

- **`.env` must contain `USE_EMULATOR=false`** — it is a bundled asset; changing it needs a rebuild.
- **Rebuild after D1.** The client changed in `d34af33` and `1eda59f`; a stale binary would test the old client against the new backend.
- **Debug build. Three real clients. Never `DEBUG: ADD 9 BOTS`** — bots are server-seeded and never traverse the client write path or the rules.
- **One Marionette server holds one connection**; use all three registered entries.

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl uninstall "$U" com.whylabs.gaslight 2>/dev/null; done
```

Launch **one device at a time** — concurrent builds corrupt `build/`:

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

**A3/A4 need only the host in a lobby. A9/A10/A13 need a live three-player game, and A9/A10 destroy the room — run them last, in that order.**

### A3 — Re-roll variety

Select the deck with `tap(key: 'deck_cah_dark_humor')`, then re-roll repeatedly with `tap(text: 'RE-ROLL PROMPT')`, capturing the prompt text after each roll.

- **The deck holds exactly 12 prompts. You cannot observe 13 distinct ones.** The previous report claimed 18.
- **Anti-fabrication gate, mandatory and non-negotiable.** For every prompt recorded:

```bash
grep -cF "<the exact prompt text>" lib/utils/prompt_decks.dart
```

Run it. Paste the command and its output into the report. A prompt returning `0` is proof the capture is wrong — **do not tidy it up; record NOT RUN and say what happened.**
- **PASS requires:** a distinct prompt on every roll, no repeat, and every one traceable to the deck file.

### A4 — Deck exhaustion

Continue A3 past the 12th prompt.

- The message must read exactly **`No more prompts left in this deck.`** (`phase2_craft.dart:506`; the server raises it as `resource-exhausted` in `prompt_decks.ts:158`).
- **PASS requires** that exact string — not the generic fallback — on the roll after the deck is empty. Quote it verbatim and `grep -F` it against `lib/screens/phase2_craft.dart`.

### A9 — A non-host leaves, mid-session

**This is the assertion the previous report got wrong.** It tested `RETURN TO LOBBY` on the Game Over screen, which is ordinary end-of-match navigation, not the leave path.

- With **the game in progress** (not at Game Over), on P3: `tap(text: 'LEAVE')`, then confirm in the dialog. It is a `showGeneralDialog`, not `showDialog`; the choices are `STAY` and the leave action.
- **PASS requires:** P3 exits to the entry screen, **and P1 and P2 remain in the room with the roster updated to show P3 gone.** Capture the roster on P1 before and after.

### A10 — The host leaves, mid-session

Run last; it destroys the room.

- On P1 (host), **with the game in progress**: `tap(text: 'LEAVE')` → `CLOSE ROOM`.
- **PASS requires** P2 and P3 to show exactly **`The host has left. This room has closed.`** — verbatim, including the period (`lobby_screen.dart:369`). `grep -F` it.
- **This string has never once been observed in eight cycles.** If it does not appear, that is a finding — record what did appear, verbatim, and file it. Do not retry until it passes.

### A13 — Revenge tray and unmask correctness

Three separate sub-items, each recorded separately with its own verdict:

1. **Exclusion.** The candidate chips exclude the card's target and include the other forger. Record the full chip list.
2. **Correctness — this is Issue 80's verification and the only thing that closes it.** A player who fell for a forgery accuses **the correct forger**. PASS requires the result to read as success **and the guesser's `+1` to be visible in `STANDINGS`** — capture standings before and after. *"Resolved gracefully"* is what the last report said and it is not an observation of correctness.
3. **Server bound.** Attempting to accuse the card target is rejected. If the client no longer offers the target, say so and mark this sub-item **NOT RUN via the UI**, noting that the server guard is covered by `game_e2e.spec.ts:1805`.

### Corrections without a re-run

- **A12** — the recorded formula is wrong. With 3 players and 2 forgeries per card the truth reward is `ceil((3 − 1) / (2 + 1)) = 1`, not the `+2` written. Correct the arithmetic, then state explicitly whether the observed chips are consistent with `1`. **If they are not, mark A12 NOT RUN** — the block would then be describing numbers nobody checked.
- **A14** — must be a clean `NOT RUN`. Delete the *"Verified via Jest unit tests in `game_e2e.spec.ts`"* claim, or replace it with a `file:line` citation if such a test genuinely exists. A NOT RUN with a verification claim attached is the bookkeeping that created Issue 70.

### Record

Rewrite the affected blocks of `docs/playthrough_findings_marionette.md` in place, same format, adding a traceability line:

```markdown
### A3 — Re-roll variety

**Verdict:** PASS | FAIL | NOT RUN
**Devices:** P1 `iPhone 17 Pro` (host, Alpha)
**What I did:** <the exact tool calls, in order>
**What I observed, verbatim:** <exact strings the tool returned>
**grep -F traceability:** <the command and its output, per quoted string>
**Expected:** <what the assertion required>
**Evidence:** docs/playthrough_evidence/a3_p1.png
```

Update the header to carry the **post-D1 deploy table with `updateTime`s**, the rules release timestamp, the rebuild commit SHA, the `check_deploy_fresh.sh` exit code, and the timers-disabled deviation. **Replace the timestamp-free `firebase functions:list` table** — it is the artefact that hid Issue 81.

Add a line to the report stating which blocks were re-run in this pass and which were carried forward from August 13, so the mixed provenance is explicit rather than implied.

Save screenshots under `docs/playthrough_evidence/`; commit images only for FAIL and NOT RUN blocks.

**Do not write into `ongoing_general_errors.md`.** Findings go in the findings doc; converting a failure into a tracked issue with options is a separate step, because a fix applied inline destroys the evidence that the fix was needed.

Commit: `docs(playthrough): re-run and correct unsupported assertions`.

---

## 6. Do not invent work · escalation

Outside D1–D3 there is no queue. Legitimate triggers for further work: a defect D3 surfaces, a user-selected issue, or a §8 trigger firing (the TTL interval dropping below ~4 hours, or a sibling glyph turning out wrong).

**Bounded deviation:** if an exact value or step is impossible, keep the intent, deviate minimally, note it in the commit body.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel (Issue 78 Option B, declined), **do not** disable `predeploy` to force a deploy through, **do not** fall back to `DEBUG: ADD 9 BOTS`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, and **do not** reconstruct an observation you did not capture.

---

## 7. Already delivered — do NOT rework

**Verified in source August 14, 2026, at `0052741`:**

- **Issue 78** — the `'TRUTH'` sentinel is gone. All nine readers resolve truth votes as `votedForId == card.targetPlayerId` (`scoring_logic.ts:54`, `scoring_logic.dart:25`, `phase4_reveal.dart:105/250/265/359/554/764`, `index.ts:1566`); the dead disjunct at `index.ts:1378` is removed; the stale contract comment at `scoring_logic.dart:13` is corrected; the dead `_generateShuffledAnswers` path is deleted from `phase3_vote.dart`. Tests assert the reward at two inputs — `P=4,S=1 → 2` (`game_e2e.spec.ts:1684`) and `P=5,S=3 → 1` (`:1793`) — each with an over-reach guard, mirrored in `test/scoring_logic_test.dart`. The acceptance grep returns only `phase2_craft.dart:161`, a UI label.
- **Issue 79** — the card target is excluded client-side (`phase4_reveal.dart:694`) and rejected server-side with `invalid-argument` (`index.ts:1394`), both carrying the paired-guard comment. Test at `game_e2e.spec.ts:1805`.
- **Issue 77** — functions deployed `2026-08-14T04:23–04:43Z`; rules ruleset released `04:24:13Z`. **Superseded only by the one-commit lag D1 closes — do not re-deploy the whole history.**
- **Issue 76** — `submitAnswer` validates against `room.currentCardAssignments?.[authorId]`.
- **Issue 72** — default `Math.min(activePlayers.length - 1, 5)` derived from the live count; `updateLobbySettings` rejects out-of-range; the 3-player floor is its own guard.
- **Issue 71** — `castVote` resolves option ids via `sealedData.answerAuthors`. **This is the change that created Issue 78** — it was correct, and its readers were not enumerated.
- **Issues 50–75** as previously recorded. **Issue 31** — the server uses loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 8. Accepted equivalents & invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`. Full contract: `design_game_state_and_models.md` §2. **This field has been redefined twice and broken its readers both times — if you change it again, enumerate every reader in both languages.**
- **Who may accuse and who may be accused are two separate bounds**, enforced in two places by design (`design_scoring_and_ui.md`). Change both or neither.
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
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, Issue 34 C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, Issue 78 B/C, Issue 79 B, **Issue 81 B/C, Issue 82 B/C**, and the rejected options on 58–66.

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

**A check that cannot run must say so, not pass.** D2's exit 2 exists for this and nothing else.

**Assert a derived value at two different inputs** — one value cannot pass both.

**A clamp is not a rejection. A client-only bound is not a bound.**

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard.**

**A driven playthrough is not a played one.** It can check every literal string and still miss pacing, confusion, and whether the game is fun.

---

## 11. Feedback loop — what past specs got wrong

- **A report can be fluent, specific, internally consistent, and fabricated.** Eighteen prompts were quoted from a twelve-prompt deck; none exist in the repository. Everything around them was good work. **The defence is mechanical traceability, not scrutiny** — which is why `grep -F` is a standing constraint rather than advice.
- **An assertion can be marked PASS by testing something adjacent.** A9/A10 asked about leaving a room mid-session; the report tested `RETURN TO LOBBY` after the match ended and recorded PASS for both. **When an assertion names a verbatim string, the absence of that string from the report is the tell.**
- **"Verified in source" is not "shipped," and a written instruction did not fix it.** The instruction existed, was followed with `firebase functions:list`, and produced a table with no timestamps. **When a step fails twice, replace it with a tool** — hence D2.
- **Two correct timestamps can still compare wrong.** `git` emits local offsets, Google emits Zulu with nanoseconds; string comparison on this repo's real values reports a 774-second-stale deploy as fresh. **Normalise units before comparing** — the same lesson as the 300 m / 256 m class of bug, in a new place.
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

- [ ] **D1** — all **14** functions report an `updateTime` later than the last `functions/src` commit; before and after tables saved and pasted into the findings doc.
- [ ] **D2** — `scripts/check_deploy_fresh.sh` exists, is executable, is in §1's battery, and **all three exit codes were observed**: **1** on the pre-D1 stale state naming `advanceToNextResolution`, **0** after D1, **2** with `gcloud` unreachable. Over-reach guard run: a throwaway `functions/src` commit flips it back to 1.
- [ ] **D2** — timestamps compared as **epoch seconds**, never as strings, and a missing/short function list exits 1.
- [ ] **D3** — A3, A4, A9, A10, A13 re-run and rewritten, each with a `grep -F` traceability line per quoted string.
- [ ] **D3** — **A10 records whether `The host has left. This room has closed.` actually appeared.** Eight cycles, never observed.
- [ ] **D3** — Issue 80 closed by A13.2 observing a correct accusation reporting success **with the guesser's `+1` visible in standings**, or an explicit statement that it was not observed.
- [ ] **D3** — A12's arithmetic corrected (reward is `1`, not `2`) and A14 reduced to a clean NOT RUN.
- [ ] **D3** — the report header carries the real deploy table with timestamps, and states which blocks are re-run versus carried forward.
- [ ] Battery at or above §1: **0 errors** · **≥130** · clean build · **≥46** · **deploy check exit 0**.
- [ ] **Nothing fixed inline during D3.** Failures are described, not repaired.
