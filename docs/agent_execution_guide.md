# Agent Execution Guide — Active Build: Wave S — make the soak contract enforceable, then recover the three verifications — August 28, 2026

**Status as of August 29, 2026: S1 and S2 are done and committed. S3 is partial — E47 and E48 landed as Match N1 and are committed; E49 (Match N2) is stopped, not started, pending a decision on newly-filed Issue 141 (found while gathering S3's own R0 device-evidence prerequisite — see `docs/ongoing_general_errors.md`).** The queue is not empty; do not start Match N2 until Issue 141 has a selection.

**You are an engineering agent with no memory of this project.**

**All three selections are made.** Build exactly these, in this order.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **S1** | Clear the 13 analyze warnings; delete the dead code rather than silencing it | **139 → A**, modified | client | — |
| **S2** | Make a re-aimed block impossible to land silently: manifest + rule R6 + an artefact hand-off format | **140 → A**, modified | tooling | — |
| **S3** | Recover the three device verifications as **E47–E49**, under S2's contract | **135 → A** | test only | — |

**No deploy is needed for any of this wave.** Nothing here touches `functions/src`. `./scripts/check_deploy_fresh.sh` must stay at exit 0 throughout; if it goes red, you changed something you should not have.

**One item = one commit** — S1 and S2 are one commit each; S3 is **one commit per match** (two).

**Every number, formula and literal string below is a decision, not a suggestion.** Implement as written; do not substitute your own values.

---

## 0. Ordering, and why it is not negotiable

**S1 → S2 → S3.**

**S2 must precede S3.** S2 defines the contract a soak report has to satisfy. Running the recovery blocks before that contract exists means running them under precisely the conditions that produced **two consecutive re-aims of the same three verifications** (§2). The tooling is the point; doing S3 first would be the third attempt under the second attempt's rules.

**S1 goes first because it is cheap and it makes every later gate reading unambiguous.** Right now `flutter analyze lib test` exits 1 on a clean tree, so "the analyze gate is red" carries no information. After S1 the warning count is a real signal, and S2's and S3's own validation can rely on it.

**S3 is two matches, and the second one costs ~12 minutes of wall clock.** Budget for it and run it last.

---

## 1. Verified baseline — measured this session on `aef9edb`

This is the regression bar. Every number was produced by running the command in this session.

| Gate | Result | After Wave S it must be |
|---|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **258 passing**, exit 0 | ≥ 258 |
| `npm --prefix functions run build` | clean, exit 0 | clean |
| `npm --prefix functions test` | **102 passing**, exit 0 | ≥ 102 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** | exit 0 |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 16 functions @ 2026-08-28T02:40–02:41Z | exit 0 |
| `./scripts/check_playthrough_evidence.sh` (Wave N report) | **exit 0** — 21 blocks | exit 0 |
| `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md` | **exit 0** — 25 blocks | **exit 0 — 28 blocks**, R6 checked ≥ 3 manifest entries |

**⚠️ `flutter analyze lib test` exits 1 even when clean**, because it exits non-zero on *infos* and there are 206 (mostly `deprecated_member_use` for `withOpacity`, plus `avoid_print` in `test/`). **The bar is `0 errors` and `0 warnings`. It is not `exit 0`.** Do not chase the exit code on this gate; read the counts. The 206 infos are **accepted and tracked**: they must not grow.

**Read every other gate's exit code bare, never through a pipe** — `... | tail -6` reports `tail`'s status, always 0.

**Gates that could not run this session:** none. All eight ran.

---

## 2. Why S2 exists — read this before writing any part of S3

**The same three device verifications have now been re-aimed twice.**

- **First attempt** (E40, E42, E43): the ten-minute presence window became *"the heartbeat keeps connected players connected"*; the round-2 lockout became *"the reveal breaks down 1 truth + 4 forgeries"* in a match configured for **one** round; the unmask window became *"Game Over honors render"*. Filed as Issue 135.
- **Second attempt** — the blocks written to recover the first (E44, E45, E46): **E46** replaced a ~12-minute presence timeout with a *voluntary departure through the `Leave game` dialog* — a different mechanism, seconds instead of minutes, no timestamps, and incapable of failing the way Issue 123 failed. **E45** kept the withhold-then-publish half and dropped *"with the host absent"*, which was the only device-observable proof of Q1/Issue 133; its screenshot is **the app's launch screen with an empty name field**. **E44** performed its assertion but cited the **GAME OVER** screen for a claim about a round-2 vote option.

**Every gate passed both times.** Rules R1–R5 ask whether a block has a verdict, an `Observed:` field, a real artefact on disk, no `grep -`, and a screenshot path that resolves. **None asks whether the block still asserts what it was told to assert, and none opens the image.** Adding ⚠️ notices to all three blocks changed nothing: the gate still reports **25 PASS, 0 FAIL**.

**A fourth gap, separate from the re-aims:** no block in E44–E46 records a commit or build SHA, and the report header still reads `**Commit SHA Tested:** eee5437` — a commit predating all four Wave R commits. So **R0, R1 and R2 have no device evidence either**, despite a prerequisite that required it.

**The lesson that shaped this wave: specificity was not the problem.** The R3 spec named the mechanism (`xcrun simctl terminate`), both checkpoints (~2 min, ~11 min), the requirement to record both wall-clock timestamps, and for E44 it said *"Screenshot the round-2 vote screen showing the sealed option and its text."* All specific; none followed. **Writing more detailed prose is a lever that has already been pulled and did not move.** S2 builds the check instead.

---

## 3. S1 — Clear the 13 analyze warnings, deleting dead code rather than silencing it (139 → A, modified)

**What this means for the user:** nothing visible. This is hygiene that makes a broken gate meaningful again — and it removes two pieces of dead code that embody designs this project has explicitly rejected.

### 3.1 The gap

`flutter analyze lib test` reports **13 warnings** on `aef9edb`. Every doc recorded this gate as *"0 errors, 0 warnings"*, which has never been true — re-measured at `a143f41` in a clean worktree, the same 220 issues appear, so this predates Wave R.

**The user's modification to Option A: do not blanket-delete. Determine per symbol whether it is genuinely dead or whether its absence indicates something missing. That check has been performed; its results are below and are decisions, not suggestions.**

### 3.2 The eight unused imports — delete

| File | Import |
|---|---|
| `lib/screens/lobby_screen.dart:2` | `dart:async` |
| `lib/screens/phase4_reveal.dart:9` | `../utils/scoring_logic.dart` |
| `lib/services/game_service.dart:11` | `../utils/prompt_decks.dart` |
| `lib/services/game_service.dart:12` | `../utils/rotation_engine.dart` |
| `lib/services/game_service.dart:13` | `../models/card_model.dart` |
| `lib/services/game_service.dart:14` | `../utils/scoring_logic.dart` |
| `lib/widgets/blinking_eye.dart:2` | `dart:math` |
| `lib/widgets/deck_carousel.dart:2` | `dart:math` |

**Eight imports + five declarations = the 13 warnings.** `scoring_logic.dart` appears twice because it is unused in two different files. Removing an unused import cannot change behaviour.

### 3.3 The five unused declarations — verdicts, with reasons

**1. `_generateRoomCode` — `lib/services/game_service.dart:168` — DELETE. This is the highest-value deletion in S1.**

```dart
String _generateRoomCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  var rng = Random();
  return String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
}
```

It is unreferenced, and it **implements a design this project explicitly rejected** — see §8, *"room codes from `Math.random()`"*. Room codes are minted server-side by `createRoom`. Leaving a client-side generator in `GameService` is an invitation for someone to wire it up and silently reintroduce the rejected behaviour. **`dart:math` stays** — `Random()` has five other uses in this file, including `_getRandomColor` immediately below.

**2. `_getPlayerId` — `lib/screens/lobby_screen.dart:165` — DELETE, and delete two imports with it.**

```dart
String _getPlayerId() {
  try {
    return FirebaseAuth.instance.currentUser?.uid ?? const Uuid().v4();
  } catch (_) {
    return const Uuid().v4();
  }
}
```

Unreferenced, and it mints an identity client-side, which sits badly against the invariant that **`playerId` is not a credential** and that a seat re-bind needs ownership, a `seatToken`, or a stale seat (§8). Server callables own identity.

**⚠️ Cascade — this is the one edit in S1 that can *increase* the warning count if done carelessly.** Both `Uuid()` uses in this file (`:167`, `:169`) and the **only** `FirebaseAuth` use (`:167`) are inside this method. Deleting the method therefore orphans two imports that are *not* in the current 13:

- `import 'package:uuid/uuid.dart';` (`lobby_screen.dart:6`) — **delete**
- `import 'package:firebase_auth/firebase_auth.dart';` (`lobby_screen.dart:7`) — **delete**

**So S1 is 13 warnings + 2 cascade = 15 removals to reach zero.** Verify with a re-run, not by counting.

**3. `_lastReactionSentTime` — `lib/screens/phase4_reveal.dart:36` — DELETE, but read the warning below first.**

`int _lastReactionSentTime = 0;` is a client-side rate-limit timestamp left over from the **reaction feature removed in Issue 74 (August 2026)**.

**⚠️ Do NOT also delete `lastReaction` and `lastReactionAt` from `lib/models/player_state.dart:24-25`.** Those are **deliberately retained**, and the file says so at `:23`: *"intentionally retained dead fields from the removed reaction feature (Issue 74, August 2026), kept to avoid a rules deploy and data migration. Safe to drop when firestore.rules is next revised."* They are not flagged by the analyzer because they are public fields, so nothing will stop you — the only thing stopping you is this paragraph. **Removing them requires a rules deploy and a data migration, and this wave deploys nothing.**

Note also: the reaction feature is **real and was removed**. This is unrelated to `sendEmote`/`sendRoomChat`, which never existed in this repository at all and appeared only in a fabricated table in a soak report (§8). Do not conflate them.

**4. `_currentStateKey` — `lib/services/game_service.dart:143` — DELETE.**

```dart
String _currentStateKey() {
  final state = _gameState;
  if (state == null) return '';
  return '${state.roomCode}_${state.currentPhase.name}_${state.currentRotationIndex}_${state.currentReaderId}';
}
```

Unreferenced. It has the shape of a **stream de-duplication key**, and lesson 2.3 records that *stream-rebuild guards are load-bearing here* — so it was checked specifically. **There is no other de-dup guard in `game_service.dart` that this one supersedes**; the only related symbol is `didChangeAppLifecycleState` (`:358`), which is unrelated. **Delete it anyway** — an unreferenced private method cannot be guarding anything.

**But record this explicitly in the commit body:** its deletion is *not* evidence that a de-dup guard is unnecessary. **If, while working in this file, you observe a snapshot handler re-running side effects for an unchanged state, STOP and file it with options** — do not reinstate this method on a hunch.

**5. `center` — `lib/theme/app_icons.dart:791` — DELETE.**

`final center = Offset(w / 2, h / 2);` computed once and never read; each `switch` branch derives its own geometry. Zero risk.

### 3.4 Validation

- **The falsifying measurement.** Run `flutter analyze lib test` **before** and **after**, and paste both summary lines into the commit body. Before: `220 issues found`, of which **13 warnings**. After: **0 warnings**, and the total drops to **207**.
- **Assert the shape, not just the count** — a count can be reached by silencing:
  ```bash
  flutter analyze lib test 2>&1 | grep -c "warning •"
  ```
  must print `0`, and
  ```bash
  git diff -- analysis_options.yaml
  ```
  must be **empty**. **S1 must not add a single lint suppression, `// ignore:` comment, or `analysis_options.yaml` rule.** The whole point of the user's modification is that dead code is deleted, not silenced.
- **The info count must not move.** `flutter analyze lib test 2>&1 | grep -c "info •"` must still print **207**. If it changed, you edited more than dead code.
- **Over-reach guard — the retained model fields survive.** `grep -c "lastReaction" lib/models/player_state.dart` must still be **non-zero**. This is the one deletion that would be expensive to undo.
- **Behaviour is unchanged.** `flutter test` stays at **≥ 258 passing**, and `npm --prefix functions test` at **≥ 102**. If any test moves, an "unused" symbol was not unused and you must stop and re-check rather than adjust the test.

**Blast radius:** `lib/screens/lobby_screen.dart` · `lib/screens/phase4_reveal.dart` · `lib/services/game_service.dart` · `lib/theme/app_icons.dart` · `lib/widgets/blinking_eye.dart` · `lib/widgets/deck_carousel.dart`. **Also update this guide's §1 table and the gate table in `ongoing_general_errors.md`** to read `0 errors · 0 warnings · 207 infos · exit 1`.

---

## 4. S2 — Make a re-aimed block impossible to land silently (140 → A, modified)

**What this means for the user:** the soak report stops being able to quietly change what it is testing. Today a block can be renamed and re-pointed at an easier assertion and every gate still says PASS — which has now happened twice on the same three items.

### 4.1 What to build — three pieces

Option A is the manifest and rule R6. **The user's modification adds the artefact hand-off format**, which was the missing piece named under Option C. Build all three.

#### Piece 1 — `docs/playthrough_manifest.md`, the single source of truth

A new file. One row per block that has a specification. **Blocks with no row are unaffected by R6**, which is deliberate — the 22 legacy blocks must not start failing.

Format — a pipe table, because the gate already parses markdown and a human has to keep it correct:

```
| Block | Title | Specified assertion | Artefact must depict |
|---|---|---|---|
| E47 | Own answer is sealed in round 2, and it is the option authored this round | In round 2, on a card where the player wrote a forgery, that player's own option is stamped SEALED / (Your Forgery), is not tappable, and its text is the forgery they authored in round 2 — not round 1. | The round-2 vote screen with the sealed option and its text both legible |
```

- **Title** must match the block heading after `### <id> — ` **verbatim**.
- **Specified assertion** must match the block's `**Specified assertion:**` field **verbatim**.
- **Artefact must depict** is prose for a human reviewer; R6 checks only that the block carries a non-empty `**Artefact depicts:**` field per cited screenshot. Naming the screen is what makes "open the artefact" a directed act instead of a vague instruction.

**Handling Option A's stated cons, which the user asked for:**

- *"A stale manifest produces false failures that erode trust."* → **The manifest is the only place the assertion text lives.** This guide's S3 sections quote it, but the file is authoritative, and R6 compares report-to-manifest only. When a block is legitimately re-scoped, the manifest row changes **in the same commit** and shows up in the diff — which is the entire point. R6's failure message must name the file and row to edit, so a false failure is a ten-second fix rather than a mystery.
- *"It only proves the block claims the right assertion, not that the claim is true."* → **True, and R6 must not be sold as more than it is.** Two mitigations: the `**Artefact depicts:**` field turns the human check into a directed comparison, and §9 keeps *open every artefact and ask what it shows* as a standing rule. **Write this limitation into the script's header comment** — lesson 2.21: state what a check does not prove when you add it.

#### Piece 2 — Rule R6 in `scripts/check_playthrough_evidence.sh`

The script is Python-in-shell, 217 lines, with rules R1–R5 and an existing non-zero match assertion at `:204`. Follow its established shape.

R6, for every block id present in the manifest:
1. The block exists in the report. Missing → violation.
2. The block's title matches the manifest title **verbatim** (after normalising surrounding whitespace only — not case, not punctuation).
3. The block contains a `**Specified assertion:**` field matching the manifest assertion **verbatim**.
4. Every PNG the block cites is accompanied by a non-empty `**Artefact depicts:**` field.

**⚠️ R6 must assert it matched something** (lesson 2.21 — a check that matches nothing returns the same number as a check that passes). The summary line must print **how many manifest entries were checked**, and R6 must **fail** if the manifest parsed to zero rows while the file exists. The current summary line is:

```
PASS: Checked 25 blocks (30 artefact file paths verified on disk) in <file>: 25 PASS, 0 NOT RUN, 0 FAIL.
```

Extend it, do not replace it — e.g. `… 0 FAIL. R6: 3 of 3 manifest entries matched.`

#### Piece 3 — The artefact hand-off format

**A single append-only TSV: `docs/playthrough_evidence/ARTEFACTS.tsv`.** One line per screenshot, written by the pass that *captures* it, at capture time. Five tab-separated columns, with a header row:

```
block_id	filename	device	captured_utc	depicts
E47	e47_p4_round2_sealed.png	P4 iPhone 17e (Dana)	2026-08-29T04:12:07Z	Round-2 vote screen; Dana's own forgery stamped SEALED / (Your Forgery)
```

- `filename` is the basename only — the directory is implied.
- `captured_utc` is ISO-8601 with a `Z`. For the presence block this column **is the evidence**, not bookkeeping.
- `depicts` is one sentence naming the screen and the asserted state.

**Why this is the hand-off:** a later pass — a reviewer, or a different agent writing the verdicts — can reconstruct what was captured from `ARTEFACTS.tsv` plus the images alone, with no access to the run session. That is the whole thing Option C needed and did not have. It also makes the "real screenshot of the wrong screen" failure visible as a **mismatch between `depicts` and the manifest's `Artefact must depict`** rather than something only a person opening the file can catch.

**Deliberately not built:** any requirement that the runner and the writer be different passes. That was Option C and it was not selected; the format is useful on its own.

### 4.2 Validation

- **The falsifying test — and this one matters more than the code.** Add a manifest row for an **existing** block, then run the gate three times:
  1. Unmodified → **exit 0**.
  2. With that block's **title** altered by one word in the report → **exit 1**, naming the block and the manifest row.
  3. With the title restored and its **`Specified assertion:`** altered by one word → **exit 1**.

  **Run 2 is the falsification the whole item exists for**: it is the exact defect that landed twice and passed every gate. **Paste all three exit codes and the two failure messages into the commit body.**
- **Over-reach guard — legacy blocks are untouched.** With the manifest containing only the three new rows, the 22 legacy blocks must still pass. Assert the gate still reports the full block count and does not flag E22–E43.
- **Over-reach guard — the empty-manifest case.** Temporarily empty the manifest's table body and confirm the gate **fails** with a "matched zero entries" message rather than passing vacuously. This is lesson 2.21 made executable; without it R6 is decoration the first time someone breaks the parser.
- **The TSV is checked, not just present.** Assert that every PNG cited by a manifest-governed block appears in `ARTEFACTS.tsv` with a matching `block_id`, and that its `depicts` is non-empty. Falsify by removing one row and confirming the gate fails.
- **Read the exit code bare.** Never through a pipe.

**Blast radius:** `scripts/check_playthrough_evidence.sh` · new `docs/playthrough_manifest.md` · new `docs/playthrough_evidence/ARTEFACTS.tsv` · this guide's §1 (the gate's expected output line changes) · **`ongoing_general_errors.md`** — record R6 and the TSV in the evidence-discipline section, since §2.33 and §2.34 both point at this hole.

---

## 5. S3 — Recover the three verifications as E47–E49 (135 → A)

**What this means for the user:** three fixes that shipped months apart — cross-round answer isolation, the ten-minute presence window, and the unmask window's host-absent close — have **never been verified on a real device**, across two attempts. This is the third attempt, and the first one running under a contract that can catch a substitution.

### 5.1 What is being recovered, and what is not

| Block | Recovers | Certifies |
|---|---|---|
| **E47** | Own answer sealed **in round 2**, and it is the option authored *that round* | **Issue 117** — cross-round `answerAuthors` isolation |
| **E48** | Unmask window **withholds then publishes** deltas, **including with the host absent** | **Issues 124 and 133** — Wave Q's entire subject |
| **E49** | Presence: still seated at **~2 min**, gone at **~11** | **Issue 123** — the ten-minute window |

**E47 and E48 share one match. E49 needs its own.** Two matches, two commits.

**Leave E44–E46 in place with their ⚠️ notices.** Do not edit or delete them. The pattern of re-aims is the evidence that motivated S2, and erasing it makes that argument invisible to the next reviewer. The report will carry 28 blocks.

**Do not re-run anything else.** E22–E39 and E41 were performed as specified and their artefacts hold up.

### 5.2 Prerequisites — all of them, every time

1. Five Marionette servers responding (`.agents/mcp_config.json` declares `marionette-p1`…`p5`). **If fewer than five are exposed, STOP and tell the user.**
2. Five booted simulators, five distinct models; record UDIDs and DDS ports.
3. **`.env` must contain `USE_EMULATOR=false`.** It is a bundled asset — changing it after the build has no effect.
4. **Uninstall on all five before installing.** `SharedPreferences` survives an install-over-the-top, so a device that played a previous room silently rejoins it.
5. Build once, install five times. Prove the binary is newer than the source and paste both lines.
6. **`./scripts/check_deploy_fresh.sh` must exit 0** before you start. No server change is in this wave.
7. **Record the build provenance — this was missed last time and is now mandatory.** The tested commit must contain S1 and S2 and all of Wave R (i.e. it must be a descendant of `aef9edb`). Put `- **Commit SHA Tested:** <sha>` in **each block**, and update the report header, which still incorrectly reads `eee5437`.
8. **Enable Reduce Motion on exactly one device** (Settings → Accessibility → Motion → Reduce Motion) and record its UDID. **Capture one screenshot of that device on the craft or vote screen** showing the background with **no drifting glyph particles** while the radial gradient and all content remain. Log it in `ARTEFACTS.tsv` against the block it was taken in. This is R0's device evidence, which Wave R never obtained.

**Drive by `ValueKey` or unique text, never pixel bounds** — five device models, five coordinate systems. Keys: `player_name_field`, `room_code_field`, `deck_<id>`, `forgeries_<n>`, `rounds_<n>`, `timer_seconds_field`, `answer_field`, `peek_inside_<id>`, `peek_prompt_<idx>`, `deck_peek_shuffle`, `kick_<playerId>`, `game_over_bottom_bar`. Labels: `CREATE ROOM`, `START GAME`, `SUBMIT DOSSIER`, `RE-ROLL PROMPT`, `CONFIRM VOTE`, `RETURN TO LOBBY`, `Leave game` → `LEAVE GAME` in game, and **`Leave room` → `CLOSE ROOM`/`LEAVE` in the lobby** (a different control).

### 5.3 Match N1 — E47 and E48

**Config:** five players · `forgeries` at the **default** (resolves to 4 at five players, so a card carries five options) · **`Rounds = 2`** · **timers OFF** · deck `hypotheticals`.

**`Rounds = 2` is the whole point of this match.** The first attempt ran `Rounds = 1`, which is exactly why the round-2 assertion was unreachable as configured. **If the lobby will not accept `Rounds = 2`, that is a defect — file it and stop. Do not proceed at `Rounds = 1` and assert something else.**

#### E47 — Own answer is sealed in round 2, and it is the option authored this round

Play round 1 normally. **In round 2**, on a card where the player wrote a forgery:

- Assert on that player's device that their own option is stamped **`SEALED`** / **`(Your Forgery)`** and **cannot be tapped**.
- **Assert the sealed option's text is the forgery they wrote in *round 2*, not round 1.** Issue 117's bug was that a round-1 option id leaked into round 2, so the lockout landed on the wrong option or on none. **A check that only confirms "something is sealed" passes against the bug** — quote both the round-1 and round-2 forgery text in `Observed:` so the distinction is visible.
- Then confirm a **different player's** own answer is sealed on a **different card**, so this is not one lucky alignment.

**Artefact must depict:** the round-2 vote screen with the sealed option **and its text** both legible. A Game Over screen does not satisfy this — that is exactly what E44 cited.

#### E48 — The unmask window withholds the deltas, then publishes them — including with the host gone

Reach a reveal on a card where **someone was actually fooled** — the window only opens when `hasFooled` is true, so verify at least one vote went to a forgery before expecting it.

- **During the window:** assert **no per-player points are displayed** — no `POINTS AWARDED THIS CARD` tray, no `▲`/`▼` deltas in the standings.
- **After it closes:** assert the tray appears with values that **include the unmask ±1**, and that the standings badges update.
- **Then the half that only a device can test.** On a **second fooled card**, have the **host leave before the deadline expires**, and confirm the tray still fills on the remaining devices. Q1 opened `closeUnmaskWindow` to any room member precisely so an absent host cannot strand it, and **no unit test can observe this.**

**⚠️ This third bullet is the reason E48 exists.** Last time it was replaced with "the host tapped RETURN TO LOBBY at Game Over and everyone reached the lobby" — which happens *after* the window has already closed and tests nothing about it. **If the host cannot be made to leave before the deadline, mark E48 `NOT RUN` with a `Reason:`. Do not substitute a post-close observation.**

**Artefacts must depict:** (a) the reveal screen **during** the window with no tray and no deltas; (b) the reveal screen **after** close with the tray and updated badges; (c) a remaining player's device showing the tray filled **while the host is absent**.

### 5.4 Match N2 — E49

**Config:** five players · **timers OFF** (with timers on, phases auto-advance during the wait and the match state changes underneath the assertion) · any forgery count · `Rounds = 1` is fine.

#### E49 — The presence window really is ten minutes

⚠️ **~12 minutes of wall clock. Budget for it; run it last.**

Reach an active phase, then `xcrun simctl terminate` P5 and **do not relaunch it**. Record the wall-clock time.

- **At ~2 minutes: assert P5 is STILL in the roster on every other device.** This is the entire point — before Issue 123, a host-initiated `handleDisconnect` evicted them at exactly this mark.
- **At ~11 minutes: assert P5 is gone from the roster.**
- **Record both wall-clock timestamps in the block, and in `ARTEFACTS.tsv`'s `captured_utc` column.** Here that column is the evidence, not bookkeeping — two screenshots ~9 minutes apart is the assertion.

**⚠️ A voluntary departure through the `Leave game` dialog is NOT this test.** That is a different mechanism, it takes seconds, and it cannot fail the way Issue 123 failed. It is precisely what E46 substituted. **If the ~12-minute wait cannot be performed, mark E49 `NOT RUN` with a `Reason:`.**

**Artefacts must depict:** a remaining device's roster **with P5 present** and the device status-bar clock legible; and the same roster **with P5 absent**, clock legible.

**No unit test can cover this** — fake timers do not suspend an isolate, which is why the emulator falsification (neutering the server guard fails exactly the 150 s test) is necessary but not sufficient.

### 5.5 Reporting and validation

- **Append E47–E49 to `docs/playthrough_findings_5player.md`.** One report per build; do not open a new file.
- **Use the existing block shape, plus the two new S2 fields:** `- **Verdict:**`, `- **Devices:**`, `- **Room Code:**`, `- **Commit SHA Tested:**`, `- **Specified assertion:**`, `- **What I did:**`, `- **Observed:**`, `- **Artefact depicts:**`, `- **Reference:**`, `- **Expected:**`.
- **Add the three manifest rows to `docs/playthrough_manifest.md` in the same commit**, and log every screenshot in `ARTEFACTS.tsv` at capture time.
- Screenshots into `docs/playthrough_evidence/` as `e47_p4_<what>.png`. **Cite a path only after the file is written.**
- **`**Observed:**` must contain a real artefact** — a screenshot path, a `Type:`/`Text: "…"` widget entry, or a `flutter:` log line. **A `grep -` is a hard failure.**
- **Run the gate after each match**, not at the end:
  ```bash
  ./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md
  ```
  It must exit 0, report **28 blocks**, and state that **R6 matched 3 of 3 manifest entries**. A gate that parses fewer blocks or fewer manifest rows than exist has told you nothing.
- **Commit per match** — two commits — so a crash costs one match, not both.
- **If a block cannot be performed, mark it `NOT RUN` with a `Reason:`.** Do **not** rename it and assert something easier. That is what produced Issue 135 and then produced it again.
- **Before you write a verdict, open every screenshot you cite and confirm it shows what `Artefact depicts:` claims.** Three separate defects have been found this way; two re-aims were missed by not doing it.

### 5.6 If S3 finds a defect

**File it with options, Pros/Cons and a blank selection line; finish the match you are in; then stop.** Do not fix it inside the soak, and do not start the second match against a build you already know is wrong.

---

## 6. Definition of Done

**S1** — ✅ done (commit `8bef4bf`)
- [x] `flutter analyze lib test` reports **0 warnings**; the info count is **206** (207 − 1: the `prefer_final_fields` info on `_lastReactionSentTime` vanished with the deleted field); errors still **0**.
- [x] Before/after analyze summary lines are in the commit body.
- [x] **No suppressions added** — `git diff -- analysis_options.yaml` is empty and no `// ignore:` was introduced.
- [x] All five dead declarations deleted, **plus** the `uuid` and `firebase_auth` imports orphaned by removing `_getPlayerId`.
- [x] **`lastReaction` / `lastReactionAt` still present in `lib/models/player_state.dart`.**
- [x] `flutter test` ≥ **258**, `npm --prefix functions test` ≥ **102** — unchanged.
- [x] The `_currentStateKey` note is in the commit body.

**S2** — ✅ done (commits `6119b9f`, `6b6bb97`)
- [x] `docs/playthrough_manifest.md` exists and is the single source of the assertion text.
- [x] R6 fails on a one-word title change **and** on a one-word assertion change; both messages name the block and the manifest row. **All three runs' exit codes are in the commit body.**
- [x] R6 **fails** on an empty manifest rather than passing vacuously.
- [x] The summary line reports how many manifest entries were matched.
- [x] The 22 legacy blocks are unaffected.
- [x] `docs/playthrough_evidence/ARTEFACTS.tsv` exists with the five-column header, and the gate fails if a cited PNG has no row.
- [x] The script's header comment states **what R6 does not prove**.

**S3** — ⚠️ partial: **E47/E48 done (Match N1); E49 not run — stopped on Issue 141**
- [x] `docs/playthrough_findings_5player.md` carries **E47, E48, E49**; the gate exits **0**, reports **28 blocks**, and **R6 matched 3 of 3**.
- [x] **E47** asserts the sealed option in **round 2** is the one authored *that round*, on two different players' cards (Bob, Charlie), with both rounds' text quoted.
- [x] **E48** asserts deltas absent during the window, present after, **and** that the tray fills with the **host absent**.
- [ ] **E49** records **both** wall-clock timestamps, P5 present at ~2 min and gone at ~11 — **is `NOT RUN`**, `Reason:` given (Match N2 not started; see Issue 141).
- [x] Every block records its **Commit SHA Tested**, and the report header no longer says only `eee5437` (both the original-pass SHA and the Match N1 SHA are now recorded).
- [ ] One device ran with **Reduce Motion on**, and a screenshot shows the in-game background with **no particles** — **still missing, and now understood why**: Reduce Motion does not gate `AppMotion.reduce()` on this Flutter/iOS combination at all (Issue 141). No screenshot can show the intended effect until that is resolved.
- [x] Every cited screenshot was **opened** and matches its `Artefact depicts:`.
- [x] E44–E46 were **left in place** with their notices.
- [x] Nothing was renamed.

**Across the wave**
- [x] **0 errors · 0 warnings · 206 infos** · `flutter test` ≥ 258 (258) · clean functions build · ≥ 102 functions (102) · deck sync exit 0 · both evidence gates exit 0 · **deploy still exit 0**.
- [ ] Issues **135, 139 and 140** moved into the **single** existing Resolved heading — **139 and 140 done; 135 stays open** (E49/Issue 123 still unverified) and **141 is newly filed, open**.

---

## 7. Already delivered — do NOT rework

Verified by reading source and re-running falsifications in a clean worktree, not by reading commit messages.

- **R0 (Issue 138)** — `AnimatedThinkingBackground` omits the particle layer under `AppMotion.reduce(context)`; `didChangeDependencies` stops the ticker. **Independently falsified:** removing only the ticker guard produces **5 failures with `pumpAndSettle timed out`** while the layer-presence guard still passes. **`EmberBackdrop` (`game_over_screen.dart:900`) was deliberately left alone** — its visuals honour Reduce Motion but its ticker still never settles, so `pumpAndSettle` on the game-over screen would hang. Latent, not fixed. **Do not fix it without filing it.**
- **R1 (Issue 136)** — `inGameAppBarHeight` (`lib/widgets/in_game_app_bar.dart`) measures each line with a `TextPainter` at the live `textScaler` against `screenWidth − 112`, using the **real style objects**; adds the 2 pt gaps and 8 pt breathing; clamps at `kToolbarHeight`. Applied to craft, vote and reveal. `TitleSettle` got **both** mitigations: `maxLines: 1` with ellipsis, and measurement at maximum letter spacing.
- **R2 (Issue 137)** — `FittedBox` removed, cap `min(screenHeight * 0.7, 560)`, content self-sizing with `SingleChildScrollView` as the floor. Its test **derives the longest prompt from `PromptDecks.allDecks` at run time** and loads the real fonts via `FontLoader`.
- **Wave Q** — **Q1** (Issue 133) deployed 2026-08-28T02:40–02:41Z; **Q3** `clock` moved to `dependencies`. **Wave P** — all eleven items. **Wave O's six good items**, **Issues 96–105**, **50–95**, **31**, **28/29**.
- **The soak's 19 good blocks** — **E31** (`e31_p3_relinked.png` shows room `YOGU`, Charlie re-pointed to Bob), **E33**, **E41**. **Do not re-run E22–E39 or E41.**

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it before the next upload.

### Accepted equivalents — do NOT "fix" these back

- **R0 leaves `..repeat()` in `initState` (`thinking_background.dart:22`).** `didChangeDependencies` always runs after `initState` and before the first frame, so the ticker stops before anything renders. Behaviourally identical; verified by the settle tests.
- **R1's and R2's `design_ui_direction.md` entries landed in the final Wave R commit** rather than each item's own. The content landed and is accurate. Do not re-split history.
- **`auto_advance_timer.dart:90` reads `MediaQuery.of(context).accessibleNavigation` directly** instead of `AppMotion.reduce`. Correct behaviour, inconsistent style. Normalise only if already editing that file.
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour, not a bug.

---

## 8. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** This is why `pendingScoreDeltas` lives there.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **Never let a client bound exceed the server's.** `castVote` and `closeUnmaskWindow` are the models.
- **The presence window gates the ACTION, not the caller.**
- **`pendingScoreDeltas` is flushed at three sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`. Guarding the first two would strand the deltas.
- **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and **caps every match at three departures** — the third ends it.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130); turning them on is the deviation to record.
- **`lastReaction` / `lastReactionAt` in `player_state.dart` are deliberately retained dead fields** from the reaction feature removed in Issue 74. Dropping them needs a rules deploy and a data migration. **Leave them.**
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit. `functions/src/prompt_decks.ts` is the source of truth, and **no file outside the catalogue may branch on a deck id.**

**Never accept Xcode's "Update to recommended settings" dialog** — it enables `ENABLE_USER_SCRIPT_SANDBOXING` and breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak to recover three blocks (135 B); **a screen-height fraction for the AppBar (136)**; auto-shrinking the dealt-card prompt (137 B); **freezing the thinking-background particles rather than removing the layer (138 A)**; **leaving the background unguarded as sub-threshold ambience (138 C)**; **correcting E44–E46 in place and erasing the re-aim evidence (135 B, this round)**; **a `Falsifies:` field in place of a manifest (140 B)**; **requiring separate run and report passes (140 C)** — its artefact hand-off format was adopted; the process split was not.

**There is no chat or emote feature.** `sendEmote` and `sendRoomChat` appeared only in a fabricated table in a soak report and have never existed in this repository. **This is distinct from the reaction feature, which did exist and was removed in Issue 74** — do not conflate them.

---

## 9. Validation standard

**Open the artefact and ask what it shows.** Rule R5 proves a path resolves on disk, nothing more. E45 cites the app's launch screen; E44 cites GAME OVER for a claim about a vote option. Both files are real; neither shows the asserted state.

**Diff block titles against the specification before reading any verdict** — and when the work *is* a recovery from a previous mis-verification, **verify it harder than the original**, because that is where the next re-aim lands.

**Falsify every guard.** Re-run it with the fix removed and confirm it fails. A guard whose test passes either way is decoration.

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number — and **state what a new check does not prove** when you add it.

**A constant's value is not behaviour.** Drive the assertion through the entry point a client actually uses.

**When you change a constant, grep the OTHER language for its literal value**, not its name.

**Measure the thing that actually constrains the layout.** Screen height does not determine whether text fits; text height does.

**Derive worst cases from data, not from a paste.**

**A green suite is not evidence about anything it cannot observe.** All eight gates were green while three blocks tested the wrong thing — twice.

**Treat 100% PASS on never-exercised paths as an anomaly, not a result.**

---

## 10. Feedback loop — what shaped this wave

- **Specificity was not the failure.** The previous spec named the mechanism, both checkpoints, the timestamps and the required screenshot subject. All of it was ignored and every gate stayed green. **More detailed prose was the wrong lever; S2 builds the check instead.** If you find yourself writing an even more emphatic paragraph, write a rule.
- **The guide made a reader hold two documents open.** Verifying meant manually pairing 25 report blocks against a spec in another file. S2's `Specified assertion:` field collapses that into a single read — and into a diff.
- **One real spec gap, and it was small:** the old guide constrained artefact *filenames* (`e44_p2_<what>.png`) but never what an artefact must *depict*. That is now a required field and a manifest column.
- **The dead-code check paid for itself immediately.** Asking "is this dead, or is its absence a missing feature?" surfaced two symbols implementing designs this project had explicitly rejected (`_generateRoomCode`, `_getPlayerId`) and one import cascade that would have *added* two warnings. A blanket "delete the warnings" instruction would have missed all three.

---

## THE LOOP

```
(1) STUDY the item here + its issue text in ongoing_general_errors.md + the
    files at the cited anchors. RE-GREP every anchor; line numbers drift.
(2) If the item is a playthrough: read docs/playthrough_manifest.md FIRST,
    DIFF THE BLOCK TITLES against it, and OPEN EVERY CITED SCREENSHOT,
    asking what each one SHOWS -- not whether it exists.
(3) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body.
(4) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE --
    including a renamed block, a changed viewport, or a dropped assertion.
(5) VALIDATE, including every over-reach guard, then RE-RUN THE GUARD WITH
    THE FIX REMOVED and confirm it fails.
(6) RE-RUN THE FULL BATTERY -- exit codes bare, except flutter analyze,
    where the bar is 0 errors / 0 warnings and the exit code is always 1.
(7) BLOCKED, or a decision is needed? STOP. File it with options, Pros/Cons,
    one (recommended), and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the relevant design doc.
```

**After S3, the queue is empty.** Report the state and stop. Do not invent work.
