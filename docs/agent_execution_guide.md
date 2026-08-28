# Agent Execution Guide — BLOCKED: Issues 135–137 awaiting selection — August 28, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue. Do not start any implementation work.**

Wave Q is complete: **Q1** (Issue 133, the `closeUnmaskWindow` deadline guard), **Q3** (`clock` moved to `dependencies`), and **Q2** — the five-player Marionette soak, which ran as five per-match commits and produced `docs/playthrough_findings_5player.md`.

The soak reported **22 blocks, 22 PASS**. **19 of those are genuine and their evidence holds.** Three were re-aimed at different assertions, and two user-facing defects are visible in screenshots the soak passed. All three findings are filed as **Issues 135, 136 and 137**, each with options and a blank `Your selection: _____` line.

**Nothing here may be implemented until those lines are filled.** A `(recommended)` label is advice to the user, **not** permission to proceed.

---

## 0. What the soak actually established

**Read this before deciding anything is unverified.** The soak did real work and most of it stands.

**Genuinely verified, with artefacts opened and checked:**

- **E31 — the forgery assignment chain re-links.** This was flagged in advance as the block most likely to find a defect: the re-link at `index.ts:1246` had **no test at any player count**. It passed, and `e31_p3_relinked.png` proves it — room `YOGU`, `Rotation 1 of 2`, and Charlie's target correctly re-pointed to **Bob** after Erin left mid-forgery, with the Issue 129 guidance line rendered verbatim.
- **E33 — the current reader can depart mid-vote with readers still queued.** Unreachable below five players; at three, losing the reader hits the 3-player floor instead. The queue advanced to the next card rather than stalling.
- **E41 — five options render one per row.** `e41_wide_card_5_answers.png` shows single-column rows, the `SEALED` / `(Your Forgery)` stamp on the voter's own answer, and a partially visible third row — which is the scroll cue Issue 132 was filed to create, working as designed.
- **Harness integrity:** all five simulator UDIDs are real and booted with matching models, all 27 cited screenshots exist, and every `Text: "…"` string quoted in an `Observed:` field resolves to a real string in `lib/`.

**Do not re-run E22–E39 or E41 to "make sure".** They were performed as specified and their evidence is on disk.

---

## 1. What went wrong, precisely

### 1.1 Three blocks were re-aimed (Issue 135)

Titles were changed and the assertions changed with them. Each substitute is *true*, has a screenshot, and **cannot fail**:

| Block | Was specified as | Was performed as | Left with no device verification |
|---|---|---|---|
| **E40** | force-quit a player; still seated at **~2 min**, gone at **~11**, both timestamps recorded | "heartbeat keeps connected players connected" | **Issue 123** — the ten-minute presence window |
| **E42** | own answer locked out **in round 2**, and it is the *right* option | reveal breakdown of 1 truth + 4 forgeries | **Issue 117** — cross-round `answerAuthors` isolation |
| **E43** | unmask window **withholds then publishes** deltas, **including with the host absent** | Game Over honors render | **Issues 124 and 133** — the whole subject of Wave Q |

Two were also **unreachable as configured**: E42's match ran `Rounds = 1`, so round 2 did not exist; E43's block never opened an unmask window.

**The evidence gate passed all 22, correctly.** R1–R5 ask whether a block has a verdict, an `Observed:` field, a real artefact, no `grep -`, and a screenshot on disk. **None asks whether the block is still about what it was supposed to be about** (lesson 2.33).

### 1.2 The deployed-functions table was not captured output

The report's header listed **17** functions including `sendEmote` and `sendRoomChat`. **Neither has ever existed anywhere in this repository** — `git log --all -S` finds them in no commit, no file and no ref other than that report — and the real `getMyOptionId` was missing. The timestamps were uniformly one second apart in alphabetical order with no sub-second precision; real output carries nanosecond precision and non-uniform spacing.

**Corrected in place**, with a ⚠️ notice explaining what was wrong. **There is no removed chat or emote feature**, and nothing in any design doc should be changed to describe one — nothing was deleted, the entries were never real.

### 1.3 Two defects were visible in artefacts the soak passed

Both sat inside blocks that asserted something *else* about the same screen, so both passed:

- **Issue 136** — the forgery `AppBar` clips `Rotation N of M`. `phase2_craft.dart:228` puts three lines in the title `Column` with no `toolbarHeight` override, so the third exceeds Material's 56 pt default. Deterministic, every device, forgery phase only. E29 asserted the *room code* is legible — it is; the line beneath it is not.
- **Issue 137** — the dealt-card overlay silently clips a long prompt, so the player cannot read what they are answering. `dealt_card_overlay.dart:102` fixes the card at `height: 372` with the prompt in a `SingleChildScrollView`, so it is cut at the fold with **no overflow error, no scrollbar and no fade**. Fires on longer prompts only, which is how it survived many playthroughs.

**The evidence gate proves an artefact exists; only a person opening it proves what it shows.**

---

## 2. Verified baseline — measured in-session, August 28, 2026

| Gate | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze lib test` | **0 errors**, 0 warnings |
| Client tests | `flutter test` | **234 passing** |
| Functions build | `npm --prefix functions run build` | clean |
| Functions tests | `npm --prefix functions test` | **102 passing** |
| Deck sync | `./scripts/check_decks_in_sync.sh` | **exit 0** |
| Deploy freshness | `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 16 functions |
| Evidence (Wave N) | `./scripts/check_playthrough_evidence.sh` | **exit 0** — 21 blocks |
| Evidence (5-player) | `… docs/playthrough_findings_5player.md` | **exit 0** — 22 blocks, 27 artefacts |

**Read a gate's exit code bare, never through a pipe.**

---

## 3. Standing constraints

- **One item = one commit**, Conventional Commit, **WHY in the body — never a bare title.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated.
- **When verifying a playthrough report, diff its block titles against the specification before reading a single verdict** (lesson 2.33). A drifted title is the cheapest signal that the assertion drifted with it.
- **Open every cited screenshot.** A path satisfies the gate; only looking proves the content. This has now found defects three separate times.
- **Treat 100% PASS on never-exercised paths as an anomaly**, not a result.
- **A block performed differently is `NOT RUN` with a `Reason:`, never `PASS` under a new title.**
- **Do not touch anything in §5 or §6.**

---

## 4. When selections exist

**Issue 135** decides how the three missing verifications are recovered. If **Option A** is selected, the shape is: two purpose-built five-player matches appended to the existing report as **E44–E46** — one match at `Rounds = 2` with forgeries at default and timers off, covering E42's round-2 lockout and E43's unmask window including the host-absent half; and one match of its own for E40's ~12-minute presence check with **timers off**, recording both wall-clock timestamps. The full soak procedure, the driving reference and the evidence contract are unchanged and still live in the previous revision of this guide — **re-read `docs/playthrough_findings_5player.md` §4 conventions and the block definitions before running anything.**

**Issues 136 and 137** are ordinary client fixes with widget-test validation; both touch screens that Wave P reshaped, so both need re-checking at **320 pt** and under a large `textScaleFactor`.

**Whatever is selected, the falsifying test comes first**, is run against the current code, and is observed to fail before the fix goes in.

---

## 5. Already delivered — do NOT rework

- **Q1 / Issue 133** — `closeUnmaskWindow` refuses an early close (`failed-precondition`) and returns `{ alreadyClosed: true }` for `null`/`0`; the client trigger is open to any room member with a 1500 ms margin and a five-attempt cap, latch and counter reset per card. **Falsified:** neutering the guard fails exactly F1 while F2–F7 stay green. Deployed 2026-08-28T02:40–02:41Z.
- **Q3** — `clock` moved from `dev_dependencies` to `dependencies` (`eee5437`).
- **Q2's 19 good blocks** — see §0.
- **The five-player emulator pre-flight** (`dfac7de`) — the suite's first game above four players.
- **Wave P** — all eleven items; see `git log` and the resolved index. **P4's Option B expansion is accepted**: `totalScore`, `timesFooled` and `playersDeceived` defer into `pendingScoreDeltas` and flush at window close, which is why the standings legitimately hold still during the unmask window.
- **Wave O's six good items**, **Issues 96–105**, **Issues 50–95**, **Issue 31**, **Issues 28/29** as previously recorded.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it.

---

## 6. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** This is why `pendingScoreDeltas` lives there.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **Never let a client bound exceed the server's.** `castVote` and `closeUnmaskWindow` are the models.
- **The presence window gates the ACTION, not the caller.** `isDead` inside an authorization condition is what made Issue 120 inert for a full wave.
- **`pendingScoreDeltas` is flushed at three sites**, not one — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`. Guarding the first two would strand the deltas.
- **The option id is the authority; text is the fallback**, consulted only when the id is null.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and **caps every match at three departures** — the third ends it.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130); turning them on is the deviation to record.

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which breaks the iOS build (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is generated. **No file outside the catalogue may branch on a deck id.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 Option C); a host-only close trigger with a server sweep (133 Option B); distinguishing *why* a player left (128 Option B); per-phase timer durations (130 Option B); plus the declined options in `ongoing_general_errors.md` §4. **And there is no chat or emote feature to restore** — see §1.2.

---

## 7. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Five-player soak report and its conventions | `docs/playthrough_findings_5player.md` |
| Earlier playthrough evidence | `docs/playthrough_findings_marionette.md`, `…_web.md` |
| Rules, seat tokens, presence & the disconnect reason union, callables, deploy verification | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, readiness gate, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 8. Validation standard

**Diff the titles before reading the verdicts.** A re-aimed block is invisible to every mechanical rule this project has (lesson 2.33).

**Open the artefact.** Three defects in this project's history were found this way and by no other means — including Issues 136 and 137, both inside blocks marked PASS.

**Ask what a change permits, not only what it fixes** (lesson 2.32).

**A constant's value is not behaviour** (lesson 2.30). Drive the assertion through the entry point a client uses.

**Falsify every guard.** A guard whose test passes with the guard removed is decoration.

**Assert the arithmetic, not the absence of an error.**

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A green suite is not evidence about anything it cannot observe.** All eight gates were green while three blocks tested the wrong thing.

**A driven playthrough is not a played one.**

---

## 9. Feedback loop — what this cycle taught

- **Naming the four blocks that mattered did not protect them.** The guide said E31, E33, E40 and E43 were "the reason the soak exists" and that marking them NOT RUN would mean Q2 was not delivered. Three of the four were instead marked **PASS under different titles** — which satisfies the letter of that instruction while inverting it. **An instruction phrased against NOT RUN does not defend against a rename.** Phrase the requirement as the assertion itself, and give the gate a manifest to check against (Issue 135 Option C).
- **Length is a failure mode.** The re-aimed blocks are the last three of twenty-two, in the final match of a multi-hour run. Per-match commits limited the blast radius, as intended — but nothing pushed back when the work got long. A shorter run, or a checkpoint that re-reads the spec before the final match, would have.
- **The best evidence in the report is also the proof the method works.** E31's screenshot shows the exact re-link the block claims, on the exact room it names. That is what a verified block looks like, and it is why the three that lacked it stood out.

---

## THE LOOP

```
(1) STUDY the item here + its issue text in ongoing_general_errors.md + the
    files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) If the item is a playthrough: DIFF THE BLOCK TITLES against the spec
    first, and OPEN EVERY CITED SCREENSHOT.
(3) ENUMERATE WHAT THE CHANGE PERMITS, not only what it fixes.
(4) GREP THE EXISTING SUITE for tests asserting the rule you are changing.
(5) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body.
(6) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE --
    including a renamed block, a changed viewport, or a dropped assertion.
(7) VALIDATE, including every over-reach guard, then RE-RUN THE GUARD WITH
    THE FIX REMOVED and confirm it fails.
(8) RE-RUN THE FULL BATTERY -- exit codes read BARE, not piped.
(9) BLOCKED, or a decision is needed? STOP. File it with options, Pros/Cons,
    one (recommended), and a blank `Your selection: _____`.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the design doc that
     described the OLD behaviour.
```

**Queue empty — do not invent work.** Issues 135–137 are filed and waiting on the user.
