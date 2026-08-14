# Agent Execution Guide — Active Build: E1 → E2 → E3 → E4 (Issues 78, 79, 77, then the playthrough) — August 13, 2026

**You are an engineering agent with no memory of this project.**

**What happened.** A manual three-player playthrough on August 13 found five defects. Root-causing them turned up something larger: **production has been running `6d9c178` since August 10**. Three commits touching `functions/src` — `4986cc7`, `3aa3148`, `1e12748` — were committed *after* the last deploy and never shipped. Issues 71, 72 and 76 are genuinely fixed in this repository and have never been true of the running game. Every verification pass that marked them Resolved read source and never asked production what it was running.

**One of the five is not a deploy gap.** Issue 78 is a live defect in HEAD: `3aa3148` redefined what `votes` holds and updated one of its nine readers. Deploying without fixing it ships a *different* wrong scoring rule.

**The user has selected. This queue is approved and ordered:**

| Item | Issue | Selection |
|---|---|---|
| **E1** | Issue 78 — `votes` sentinel purge | Option A |
| **E2** | Issue 79 — revenge tray offers the truth's author | Option A, *"leave comments to address the cons"* |
| **E3** | Issue 77 — deploy `4986cc7…HEAD` | Option A (E1+E2 first, one deploy) |
| **E4** | Issue 70 / Issue 80 — re-run the playthrough on the correct build | Option D, Marionette-driven |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.** Full issue text, options and rationale live in `docs/ongoing_general_errors.md`; this guide is the how.

---

## Standing constraints — these apply to every item

- **One item = one commit.** E1 and E2 are separate commits. Do not batch them: Issues 71–76 landed as one commit, five were real, one was untouched, and the batch read as complete.
- **Write validation that fails against the broken state, and observe it fail before you fix anything.** Record the failure output in the commit body. This is not optional here — all four gates were green while Issues 71, 76 and 78 were live.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not fix Issue 80.** The user selected: re-run the assertion after E1–E3 land. If it still fails, file the design question then.
- **Never fill in a `Your selection: _____` line.**
- **Do not touch anything in §10–§12.**

---

## 1. Verified baseline — the regression bar

Re-measured **August 13, 2026** at `1e12748`; unchanged at `0c5aef1` (docs-only since).

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (24 warnings, 197 infos — 221 issues total) |
| `flutter test` | **127/127** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **43/43** ✅ |
| **Deployed backend** | ❌ **STALE** — production runs `6d9c178`; three commits undeployed (E3) |
| **The playthrough** | ⚠️ Ran August 13 against the **stale** build; must be re-run (E4) |

**The battery had a hole, and this closes it.** A green suite says nothing about what is deployed. Run this in every future pass and compare against `git log -1 --format=%cI -- functions/src`:

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,updateTime)"
```

**`gcloud` is not on this shell's `PATH`** — it is at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`. **`~/.pub-cache/bin` is not on `PATH`** either.

### ⚠️ Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`** — it walks `build/{ios,macos}/SourcePackages` and reports ~678 phantom errors from vendored plugin source.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`. **E2's client test needs this.**
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`** — the two must be deployed as separate commands (E3). Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers in this guide will drift as you edit.** Re-grep for the *expression*, not the number, before every edit. E1 changes nine sites in four files; after the third edit every number below it is stale.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| **E1** | Issue 78 — purge the `'TRUTH'` sentinel | First, because E3 must not ship the current scoring rule and because E2's "who was fooled" logic reads the same broken predicate. Fixing E2 on top of E1 is clean; the reverse order means writing E2's test against a value that is about to change meaning. |
| **E2** | Issue 79 — exclude the truth's author from the revenge tray | After E1, before the deploy, so one deploy carries both. |
| **E3** | Issue 77 — deploy functions **and rules** | Only after E1 and E2 are green. This is the user's selected Option A: one deploy, one re-test. |
| **E4** | Re-run the playthrough (Marionette, M1–M5) | Last. Running it before E3 measures `6d9c178` — the exact mistake that produced this queue. |

---

## 3. E1 — Issue 78: purge the retired `'TRUTH'` sentinel

**What this means for the user:** today a player who correctly picks the truth scores **nothing**, the person who told the truth is paid as though they had fooled someone, and the game tells *every* player they were fooled — including the one who was right. This is the defect that made the reveal read `Unknown: +1` while standings stayed at `0`.

### The gap

`3aa3148` changed what `votes` holds. It used to map `voterId → optionId | 'TRUTH'`. It now maps `voterId → resolvedAuthorId` (`functions/src/index.ts:583`), so **a vote for the truth stores the card target's player id** and the string `'TRUTH'` is never written by `castVote` again.

Exactly one reader was updated (`index.ts:1367`). **Nine were not.** Two further consequences follow from the same root and must be fixed in this commit:

- Because `advancePhaseInternal` only applies deltas whose key is an active player id (`index.ts:1111–1124`), a delta keyed to anything else is **silently dropped** — which is why the reveal and the standings disagreed.
- `debugSimulateBotResponses` still *writes* the dead sentinel, so the debug path seeds data no reader can interpret.

### Implementation

**The rule, stated once:** a vote is a truth vote **iff `votedForId == card.targetPlayerId`**. There is no sentinel. Apply that substitution at every site below.

| # | File | Expression today | Change to |
|---|---|---|---|
| 1 | `functions/src/scoring_logic.ts:54` | `votedForId === 'TRUTH'` | `votedForId === currentCard.targetPlayerId` |
| 2 | `lib/utils/scoring_logic.dart:25` | `votedForId == 'TRUTH'` | `votedForId == currentCard.targetPlayerId` |
| 3 | `lib/screens/phase4_reveal.dart:105` | `votedFor != 'TRUTH'` | `votedFor != card.targetPlayerId` |
| 4 | `lib/screens/phase4_reveal.dart:250` | `currentCard.votes[me.id] != 'TRUTH'` | `… != currentCard.targetPlayerId` |
| 5 | `lib/screens/phase4_reveal.dart:265` | `currentCard.votes[me.id] != 'TRUTH'` | `… != currentCard.targetPlayerId` |
| 6 | `lib/screens/phase4_reveal.dart:359` | `_buildOptionRow('TRUTH', currentCard.truthAnswer, …, isTruth: true)` | `_buildOptionRow(currentCard.targetPlayerId, currentCard.truthAnswer, …, isTruth: true)` |
| 7 | `lib/screens/phase4_reveal.dart:554` | `card.votes[me.id] != 'TRUTH'` | `… != card.targetPlayerId` |
| 8 | `lib/screens/phase4_reveal.dart:757` | `card.votes[p.id] != 'TRUTH'` | `… != card.targetPlayerId` |
| 9 | `functions/src/index.ts:1544` | `votes[p.id] = "TRUTH";` | `votes[p.id] = currentTargetId;` |

**Site 6 deserves a second look before you change it.** `_buildOptionRow` is declared at `phase4_reveal.dart:804` and uses its `authorId` parameter at `:806` to find that option's voters: `gs.players.where((p) => card.votes[p.id] == authorId)`. With `'TRUTH'` passed in, that comparison is never true, so **the truth row currently shows no voters at all**. Passing the target id fixes it. The label and border are governed by the separate `isTruth: true` flag, not by `authorId` — **re-read `:804–830` and confirm that before editing**, because if any label branch keys off `authorId` the truth row would start rendering as "FORGERY BY <target>".

**Also in this commit:**

- **`functions/src/index.ts:1367`** — `if (votedForId === "TRUTH" || votedForId === currentCard.targetPlayerId)`. The first disjunct is now dead. Delete it, leaving the target-id check. This is the one reader that was already correct; make it unambiguous.
- **`lib/utils/scoring_logic.dart:13`** — the doc comment reads `// VoterID -> VotedForID (or "TRUTH")`. **Update it.** A stale comment describing a retired contract is how this bug propagated in the first place.
- **`lib/screens/phase3_vote.dart:52–64`** — `_generateShuffledAnswers` builds `_AnonymizedAnswer('TRUTH', card.truthAnswer)` from `card.truthAnswer` and `card.sabotageAnswers`. **This path is dead:** the live grid is built from `currentCard.options` at `phase3_vote.dart:412`, and `_shuffledAnswers` is assigned but never read. **Delete the method, its call at `:135`, and the `_shuffledAnswers` / `_shuffledCardId` fields at `:48–49`.** Leaving it is how the sentinel comes back.

After the edits, this must return nothing outside of display copy:

```bash
grep -rn "'TRUTH'\|\"TRUTH\"" lib functions/src | grep -v "THE TRUTH\|RECORD OF TRUTH\|YOUR TRUTH\|IS THE TRUTH"
```

### Validation

**Observe the failure first.** Write the tests, run them against unmodified code, record the output, then fix.

**Falsifying assertion (server, `functions/test/game_e2e.spec.ts`).** Today's code gives a correct truth-voter **0**. Assert the real reward, `ceil((P − 1) / (S + 1))`, **at two different inputs — one value cannot pass both**:

| Case | Players `P` | `forgeriesPerCard` `S` | Expected truth-voter delta |
|---|---|---|---|
| A | 4 | 1 | **2** |
| B | 5 | 3 | **1** |

Case A alone would also pass a "give the voter a flat 1" mis-fix; case B alone would also pass today's "give the voter 0 but the target 1" if you only checked the target. Both are required.

In each case have one player vote the truth option and one vote a forgery, then assert on the player documents after the phase advances:

- the truth-voter's `totalScore` increased by exactly the expected reward;
- the **card target's** `totalScore` increased by exactly `1` per truth-voter;
- the **forger's** `totalScore` increased by exactly `1`.

**Over-reach guard, in the same test:** the player who voted for a forgery must **not** receive the truth reward, and the card target must **not** be credited for the forgery vote. A fix that pays everyone would otherwise pass.

**Falsifying assertion (client, new `test/scoring_logic_test.dart`).** `ScoringLogic.calculateScores` is a pure function — call it directly with a hand-built `GameState` and `CardModel` for the same two cases and assert the same numbers. This is the cheap mirror of the server test and it is what the reveal actually renders.

**Regression guard for the "fooled" predicate.** A widget or unit test asserting that a player whose vote equals `card.targetPlayerId` is **not** treated as fooled. Today that predicate is true for everyone, so this assertion fails before the fix and passes after. Set `accessibleNavigation: true` if you drive the reveal screen (trap 7).

**Battery:** `flutter analyze lib test` 0 errors · `flutter test` **≥127** · functions build clean · `npm --prefix functions test` **≥43**. New tests raise these counts; they must never lower them.

### Blast radius

`functions/src/scoring_logic.ts`, `functions/src/index.ts`, `lib/utils/scoring_logic.dart`, `lib/screens/phase4_reveal.dart`, `lib/screens/phase3_vote.dart`, plus the new/updated tests. **`test/fake_functions.dart` models the server's error shape — check whether it stores votes, and if so keep it consistent with the new contract.**

Commit: `fix(scoring): resolve truth votes by target identity, not the retired 'TRUTH' sentinel`. Put the pre-fix failure output in the body.

---

## 4. E2 — Issue 79: exclude the truth's author from the revenge tray

**What this means for the user:** the revenge round currently offers you the chance to accuse the person who wrote the truth of having forged it. It is a wasted guess, and offering it tells the player the game is not tracking who did what.

### The gap

`lib/screens/phase4_reveal.dart:~688` builds the candidate list as:

```dart
final candidates = gs.players
    .where((p) => p.id != me.id && p.role != PlayerRole.spectator)
    .toList();
```

It excludes only the guesser. The **card's target** — who by definition wrote the truth for this card, not a forgery — is offered on every card. The server does not reject it either: `submitUnmaskGuess` (`functions/src/index.ts:1375`) rejects only self-accusation.

### Implementation

**Client** — add the target to the exclusion at `phase4_reveal.dart:~688`:

```dart
final candidates = gs.players
    .where((p) =>
        p.id != me.id &&
        p.id != card.targetPlayerId &&
        p.role != PlayerRole.spectator)
    .toList();
```

**Server** — in `submitUnmaskGuess`, immediately after the self-accusation guard at `index.ts:1375`, add:

```ts
    if (guessedAuthorId === currentCard.targetPlayerId) {
      throw new HttpsError(
        "invalid-argument",
        "The card's target wrote the truth and cannot be accused of forgery."
      );
    }
```

**The user asked for the cons of Option A to be addressed in comments.** Option A's stated cost is that the same exclusion is now expressed twice, in two languages, and can drift. Add a short comment at **both** sites naming the other one and saying why both exist — the client copy is UX, the server copy is the actual bound, because a client-only bound is not a bound. Something a future reader cannot misread as duplication to be cleaned up:

```
// Paired with the identical exclusion in <the other file:symbol>. The client
// copy keeps the impossible choice off screen; the server copy is the real
// guard — a stale or modified client must not be able to submit it. Change
// both or neither.
```

### Validation

**Falsifying assertion (server, `game_e2e.spec.ts`).** A player who fell for a forgery calls `submitUnmaskGuess` with `guessedAuthorId` set to the card's `targetPlayerId`. Expect a rejection with code **`invalid-argument`** — match on the **code**, never the message (trap 12). Today this call **succeeds**; observe that first.

**Over-reach guard, same test:** a guess naming a genuine forger on the same card must still succeed and must still apply `+1` to the guesser and `−1` to the forger (`index.ts:1395–1400`). A fix that rejects everything would otherwise pass.

**Falsifying assertion (client).** A widget test on the reveal at the unmask stage asserting the candidate chips contain the other forger and **do not** contain the card target. Set `accessibleNavigation: true` (trap 7).

**Battery** as in E1.

### Blast radius

`lib/screens/phase4_reveal.dart`, `functions/src/index.ts`, plus tests. Note that `index.ts:1367` already rejects guesses from players who voted the truth — E2 is the complementary bound on *who may be accused*, not on *who may accuse*. Do not merge the two guards.

Commit: `fix(reveal): reject accusing the card target, who wrote the truth`.

---

## 5. E3 — Issue 77: deploy functions and rules

**What this means for the user:** four fixed issues are sitting in the repository and have never reached anyone playing the game.

**This is a production change, and the user has authorised it** by selecting Option A on Issue 77 — which is explicitly "fix Issue 78 first, then deploy `4986cc7…HEAD` in one go". **Announce the deploy before running it. Do not run it before E1 and E2 are committed and green.**

### Implementation

1. Confirm the working tree is clean and the battery is at or above §1.
2. Record the pre-deploy state so the change is provable:

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,updateTime)"
```

3. Deploy functions. `firebase.json`'s `predeploy` runs the test suite on this path and needs Java:

```bash
npx firebase-tools deploy --only functions --project gaslight-46368
```

4. **Deploy rules separately.** `firestore.rules` was last changed in `3aa3148` — which is also undeployed — and `predeploy` does **not** gate `--only firestore:rules` (trap 8):

```bash
npx firebase-tools deploy --only firestore:rules --project gaslight-46368
```

### Validation

**The falsifying check:** re-run the `gcloud functions list` command. **All 14 functions** must report an `updateTime` later than `git log -1 --format=%cI -- functions/src`. Paste the before and after tables into the commit or the findings doc. A partial deploy — some functions updated, some not — is a failure, not a partial success: `castVote` and `advancePhase` disagreeing about what `votes` holds is worse than either version alone.

Expected function list: `advancePhase`, `advanceToNextResolution`, `castVote`, `createRoom`, `debugAddBots`, `debugSimulateBotResponses`, `handleDisconnect`, `joinRoom`, `rerollPrompt`, `setReady`, `startGame`, `submitAnswer`, `submitUnmaskGuess`, `updateLobbySettings`.

**If the deploy fails**, do not retry blindly and do not disable `predeploy` to get past it. Record the error and STOP per §9.

---

## 6. E4 — Re-run the playthrough against the correct build

Marionette MCP is **already installed** — `marionette_flutter: ^0.6.0` is in `pubspec.yaml`, the binding is in `lib/main.dart`, `.agents/mcp_config.json` registers three servers, and the six stable keys landed in `f3a5a1d`. A previous agent reached the M3 connect gate (`docs/playthrough_evidence/m3_gate_p1.png`) and stalled there without writing findings. **Verify the setup rather than redoing it.**

### Setup

- **`.env` must contain `USE_EMULATOR=false`.** It is a bundled asset — changing it requires a rebuild.
- **Debug build.** The server refuses debug callables when `debugEnabled` is false, and release builds expose no VM service.
- **Three real clients. Never `DEBUG: ADD 9 BOTS`** — bots are server-seeded documents that never traverse the client write path or the security rules, which is the exact blind spot this run exists to cover.
- **One Marionette server process holds one connection.** Three players means the three registered server entries, not one server reconnected. There is no session id on any other tool.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl uninstall "$U" com.whylabs.gaslight 2>/dev/null; done
```

Launch **one device at a time** — two concurrent builds against the same `build/` directory corrupt each other:

```bash
flutter run -d <UDID> --debug > /tmp/gaslight_p1.log 2>&1 &
```

Extract each VM service URI and convert it to the WebSocket form Marionette expects:

```bash
grep -oE 'http://127\.0\.0\.1:[0-9]+/[^ ]*' /tmp/gaslight_p1.log | tail -1 | sed -e 's|^http|ws|' -e 's|/$|/ws|'
```

`marionette-p1.connect` → P1's URI, and so on. Record which UDID sits behind each server; every observation must name its device.

**Gate before any assertion:** `take_screenshots` on all three must show **`THE GUEST LEDGER`**. Three devices, not two — the minimum player count is enforced server-side.

### Three hazards, all of which produce a false pass rather than a visible failure

1. **The Forgeries and Rounds choosers are both `ChoiceChip`s labelled with bare numerals** (`lobby_screen.dart:569` and `:600`). `get_interactive_elements` on P1 must show `forgeries_*` and `rounds_*` as **distinct keyed elements** before you touch House Rules. If it does not, **stop** — assertion 1 cannot be trusted and neither can any House Rule you set.
2. **`Family-Friendly Decks Only`** (`lobby_screen.dart:643`) hides `cah_dark_humor`, which assertion 4 needs. It defaults to `false` — **leave it off**.
3. **Phase auto-advance fires faster than an agent can read-then-tap.** Turn **`Disable Game Timers` on** (`lobby_screen.dart:623`) and record it as a deliberate deviation.

Two more that cost a cycle each: `get_interactive_elements` returns only **visible** elements, so `scroll_to` before concluding a control is absent; and this app renders labels as literal ALL-CAPS strings (`'THE GUEST LEDGER'`, `'CREATE ROOM'`, `'RE-ROLL PROMPT'`, `'SUBMIT DOSSIER'`, `'CONFIRM VOTE'`) — `tap(text: 'Create Room')` will not match.

### Player setup

P1 is host: `enter_text` into `player_name_field` → `Alpha`, `tap(text: 'CREATE ROOM')`, read the code under `ROOM CODE`. P2/P3: `player_name_field` → `Bravo`/`Charlie`, `room_code_field` → the code, `tap(text: 'JOIN ROOM')`.

**Prefix every answer per device — `AAA`, `BBB`, `CCC`.** Assertions 8, 12 and 13 are only checkable because you know who typed what.

### The assertions

Run in order. **Items 9 and 10 destroy the room.**

| # | Assertion | Verdict comes from |
|---|---|---|
| 1 | **Forgery chooser range** — offers only `1 … n − 1`, defaults sensibly, allows more than 5 when players allow | The `forgeries_*` key list; with 3 players expect exactly `forgeries_1`, `forgeries_2` |
| 2 | **Truth phase first** — everyone answers their own prompt before any lie is written | The prompt/answer copy on all three |
| 3 | **Re-roll variety** — a different prompt every time, never a repeat | The sequence of prompt strings, verbatim |
| 4 | **Deck exhaustion** on `cah_dark_humor` (12 prompts) via `tap(key: 'deck_cah_dark_humor')` | Must read exactly `No more prompts left in this deck.`, not the generic fallback |
| 5 | **Reveal is readable** — no red-and-yellow overflow stripe | The pixels. Attach the screenshot |
| 6 | **`THE SOUL IS SILENT` must not appear** when everyone answered | Search the reveal text on all three. **This was Issue 76 and it is the check that matters most** |
| 7 | **Points name real players**, not `Unknown` | `POINTS AWARDED THIS CARD`. `Unknown` here was Issue 71 |
| 8 | **Attribution is correct** — the named author actually wrote it | Your `AAA`/`BBB`/`CCC` ground truth |
| **11** | **Rounds are settable** — set `rounds_3`, start, and confirm the game actually plays three rounds | Finding 1 from August 13. Assert the round counter advances, not just that the chip highlights |
| **12** | **Scoring is correct** *(E1)* — the player who picks the truth gains `ceil((P − 1) / (S + 1))`, the truth-teller `+1` per finder, the forger `+1` | `STANDINGS` before and after, as numbers. **A reveal chip that says `+1` while standings stay `0` is the exact August 13 symptom — check both** |
| **13** | **Revenge tray excludes the truth's author** *(E2)*, and a correct accusation reports success *(Issue 80)* | The candidate chips, then `REVENGE UNMASKING RESULTS`. **This is Issue 80's re-verification — if a correct accusation still reads FAILED, file the design question with the observed `votes[guesserId]` and `guessedAuthorId` attached** |
| 9 | **A non-host leaves** → room survives, host sees them go | P1 and P2 still in the room |
| 10 | **The host leaves** → both others land on the entry screen | Must read exactly `The host has left. This room has closed.` |
| 14 | **TTL** — a fresh room and its host player document carry `expiresAt` ~8 h ahead | **Not Marionette-verifiable.** Record as **NOT RUN** and say why |

**If any assertion cannot be reached**, that is itself a finding. Record what you saw, mark every downstream assertion **NOT RUN**, and continue with whatever remains reachable. A blocked run reporting six honest NOT RUNs is worth more than one reporting six passes it did not observe.

### Record

Create **`docs/playthrough_findings_marionette.md`**. Header: date, commit SHA, **the post-deploy `gcloud functions list` output**, the three devices and UDIDs, build mode, `USE_EMULATOR`, Marionette versions, and the timers-disabled deviation.

Then **one block per assertion, all fourteen, in order** — passes included:

```markdown
### A1 — Forgery chooser range

**Verdict:** PASS | FAIL | NOT RUN
**Devices:** P1 `iPhone 17` (host, Alpha)
**What I did:** <the exact tool calls, in order>
**What I observed, verbatim:** <exact strings / exact key list — no paraphrase>
**Expected:** <what the assertion required>
**Evidence:** docs/playthrough_evidence/a1_p1.png
```

Save screenshots under `docs/playthrough_evidence/`; **commit images only for FAIL and NOT RUN blocks** — for passes the verbatim strings are the record. Close with a re-run battery compared against §1, and a **"what the harness could not see"** section.

**Do not write into `ongoing_general_errors.md`.** Findings go in the findings doc; converting a failure into a tracked issue with options is a separate step, because a fix applied inline destroys the evidence that the fix was needed.

---

## 7. Deferred — do not start

- **Issue 80** — a correct revenge accusation reported `FAILED`. The user selected: **do not fix; re-run after E1–E3.** It is assertion 13 in E4. It is probably downstream of Issues 77 and 78 — on the stale build `votes[guesserId]` holds an option UUID that cannot equal any player id, so every accusation fails by construction. **Trigger for further work: assertion 13 still failing after E3.** Only then file the design question — whether "correct" should mean *the author of the forgery you voted for* or *anyone who forged on this card*.

---

## 8. Do not invent work

Outside E1–E4 there is no queue. The only legitimate triggers for further work are: a defect E4 surfaces, a user-selected issue in `ongoing_general_errors.md`, Issue 80's trigger above, or a §11 trigger firing — the TTL interval dropping below ~4 hours, or a sibling glyph turning out wrong.

**One short check is worth doing during E1**, since you are already in `submitAnswer`: confirm `authorId` is bound to `request.auth.uid` before it is used as the write key. If it is not, a client could write into another player's slot. This was unverifiable in an earlier pass, **not found broken** — if it is broken, file it, do not fix it inside E1's commit.

---

## 9. Escalation

**Bounded deviation:** if an exact value or step here is impossible, keep the intent, deviate minimally, and note it in the commit body.

**If the design itself cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`, and do not improvise. Specifically: **do not** reintroduce the `'TRUTH'` sentinel to make a test pass (that is Issue 78 Option B, which the user declined), **do not** disable `predeploy` to get a deploy through, and **do not** fall back to `DEBUG: ADD 9 BOTS` for E4.

---

## 10. Already delivered — do NOT rework

Verified in source at `1e12748`. **All of it is in the repository; none of it was in production before E3** — that distinction is the whole of Issue 77.

- **Issue 76** — `submitAnswer` validates against `room.currentCardAssignments?.[authorId]` (`index.ts:~495`), so author and holder are provably the same identity and the timeout fill can no longer miss a real answer.
- **Issue 72** — default `Math.min(activePlayers.length - 1, 5)` (`index.ts:266`), derived from the live count; `updateLobbySettings` rejects out-of-range with `invalid-argument` against `maxAllowed = numPlayers - 1`; `isExplicitForgeriesUpdate` keeps "unset" distinct from an explicit choice; `totalRounds` bounded 1–5; the **3-player floor is its own guard** (`index.ts:260`); the chooser renders `1 … min(n − 1, 8)`.
- **Issue 71** — `castVote` resolves option ids via `sealedData.answerAuthors` (`index.ts:545–546`). **This is the change that created Issue 78** — it was correct, and its readers were not enumerated.
- **Issues 73–75** — `EVALUATE READY STATE (HOST)` removed, reactions removed, standings reworked.
- **Issues 50–70** as previously recorded.
- **Issue 31** — the server uses loose `!= null`; **never "simplify" to a falsy check**.
- **Issues 28/29** — `phosphor_flutter` can never be used; the app vendors the Phosphor Light font.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 11. Accepted equivalents & invariants — do NOT change

- **Issue 76 validates rather than re-derives.** The spec asked for the forgery write key to be re-derived server-side; the implementation keeps `[authorId]` and validates it against `currentCardAssignments`. **Same guarantee, different structure — leave it.**
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **The non-host carousel is interactive-but-inert, not dimmed.**
- **`pumpAndSettle()` and `pump()` + `pump(500ms)` are both acceptable** once `accessibleNavigation: true` is set.
- **The leave dialog uses `showGeneralDialog`, not `showDialog`.**
- **`lastReaction` / `lastReactionAt` remain on `PlayerState` and in the rules deliberately** (Issue 74) — dead fields kept to avoid a rules deploy and migration.
- **The `prompt_decks` TS/Dart pair is data-only**; error plumbing deliberately differs. **`text_similarity` must stay byte-identical.** After E1, **`scoring_logic` joins it as a pair that must stay semantically identical across both languages.**
- **Sealed documents are created lazily**, not at `startGame`.
- **`_ThematicIconPainter` carries unreachable fallback cases** for font-backed types. Do not delete or wire them up.
- **Server-authoritative**; room reads stay open; `/rooms/{code}/sealed/{cardId}` is default-deny and holds the answer key, `answerAuthors` and `seenPrompts`. **Never add an explicit `allow read: if false`.**
- **Option ids are opaque UUIDs**, resolved to authors server-side. **Never send authorship to the client.**
- **Phase order is truth → forgery → vote → reveal.**
- **Minimum 3 active players**, enforced as its own guard — never as a side effect of the forgery arithmetic.
- **Forgeries per card: hard ceiling `n − 1`; `5` is a default, not a cap.**
- **Re-rolls are unlimited during `truth`, rejected elsewhere, and never repeat a prompt.**
- **`ROOM_TTL_MS` is 8 hours**; below ~4 h a host-only `touchRoom` keepalive plus a client timer become mandatory.
- **`firebase.json`'s `predeploy` stays** and runs the tests.
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, Issue 34 C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, **Issue 78 B/C, Issue 79 B**, and the rejected options on 58–66.

---

## 12. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| **E4's findings** | `docs/playthrough_findings_marionette.md` (you create it) |
| Backend writes, rules, identity, TTL, **deploy & verification §8** | `design_database_and_security.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, icons, mascot | `design_ui_direction.md` |
| **Phase order, rounds, forgeries, the 3-player minimum** | `design_game_state_and_models.md` |
| Deck catalogue, re-roll exclusion, mirror status | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 13. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the failure output.

**A test that asserts the happy path of a bug is not a test for the bug.** `game_e2e.spec.ts:1384–1392` has all three players vote the truth and then asserts only that the phase became `reveal`. **No test anywhere asserts a score after a vote** — which is precisely why Issue 78 shipped and stayed green.

**A green suite is not evidence about anything it cannot observe.** Issues 71, 76 and 78 were all live with four green gates.

**A green suite is not evidence about what is deployed.** New, and the most expensive lesson in this file. See §1.

**Assert a derived default at two different inputs** — one value cannot pass both. E1 requires exactly this.

**A clamp is not a rejection.** **A client-only bound is not a bound** — E2 exists because of it.

**Measure; do not estimate.** **Do not weaken an assertion or delete a test to reach green.**

**Pair every fix assertion with an over-reach guard.**

**A driven playthrough is not a played one.** E4 can check every literal string and still miss pacing, confusion, and whether the game is fun. Say so in "what the harness could not see" rather than implying coverage you do not have.

---

## 14. Feedback loop — what past specs got wrong

- **"Verified in source" is not "shipped."** Issues 71, 72 and 76 were each read in source, confirmed correct, and marked Resolved — and all three were still broken for players, because nobody asked production what it was running. Three passes conflated a diff with a deploy. **The deploy check is now in §1's battery.**
- **When you redefine what a field holds, enumerate its readers.** Issue 71 changed `votes` from `optionId | 'TRUTH'` to a resolved author id and updated one of nine readers. This is the second time `votes` has done this — it previously broke scoring, the self-vote guard and the reveal. **A sentinel value is the thing that makes this failure mode invisible**, which is why Option B was declined.
- **A guide's title is not its contents.** This document was twice retitled "Queue Complete" while its body specified unfinished work — and once while production was three commits behind.
- **An item can be marked done because the *other* items in its commit were.** Issues 71–76 landed as one commit; five were real and Issue 76 was untouched. **One item = one commit** exists for exactly this.
- **The manual gate earns its keep every time it runs.** Two playthroughs, eleven defects, none of them visible to four green gates.
- **A blocker that costs a human's time gets deferred forever.** Issue 70 sat seven cycles because it needed a person. **When an item keeps slipping, the fix is usually tooling, not discipline.**
- **Doc structure rots silently.** Append inside the existing Resolved heading; never add a second.

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified.
(4) VALIDATE per §13, including the over-reach guard.
(5) BEFORE COMMITTING, re-run the full battery. One item = one commit.
(6) BLOCKED, or found something needing human judgement? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(7) RECORD: move the item to Resolved inside the SINGLE existing Resolved heading.
    E4's observations go to docs/playthrough_findings_marionette.md instead.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **E1** — nine sentinel sites changed, `index.ts:1367` simplified, the stale comment at `scoring_logic.dart:13` corrected, the dead `_generateShuffledAnswers` path deleted, and the `grep` for `'TRUTH'` returns only display copy.
- [ ] **E1 validation** — scoring asserted at **two** inputs (P=4/S=1 → 2 and P=5/S=3 → 1) on both server and client, each with an over-reach guard, each observed failing first.
- [ ] **E2** — client exclusion + server `invalid-argument` rejection, both carrying the paired-guard comment the user asked for, with a test that observed the guess **succeed** before the fix.
- [ ] **E3** — functions **and** `firestore.rules` deployed; all **14** functions report an `updateTime` later than the last `functions/src` commit; before/after tables recorded.
- [ ] **E4** — Marionette setup verified, three devices screenshotted on `THE GUEST LEDGER`, all **fourteen** assertions attempted, each with PASS / FAIL / NOT RUN and a reason.
- [ ] **E4 record** — `docs/playthrough_findings_marionette.md` exists with one block per assertion, verbatim observations, the post-deploy function table, the timers deviation, a re-run battery, and "what the harness could not see".
- [ ] Battery at or above §1: `flutter analyze lib test` **0 errors** · `flutter test` **≥127** · functions build clean · `npm --prefix functions test` **≥43**.
- [ ] **Nothing fixed inline during E4.** Failures are described, not repaired.
- [ ] **Issue 80 not touched** unless assertion 13 fails after E3.
