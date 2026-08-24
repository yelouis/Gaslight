# Agent Execution Guide — Wave L Verified · Two Observations Outstanding — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–111 are delivered. Wave L is complete and independently verified.** The queue is empty and **there is nothing to decide.**

**Two things remain, and neither is a code change.** Both are observations someone still has to make. §2 and §3 are those tasks; everything else is context.

## Verified baseline — the regression bar

Measured August 24, 2026:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (18 warnings, 204 infos) | `flutter analyze lib test` |
| Client tests | **185/185** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **70/70** | `npm --prefix functions test` |
| Deploy freshness | **exit 1 — expected**, see §2 | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 19 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

---

## 0. What Wave L delivered — verified, do NOT rework

Checked against the code and the artefacts themselves, not the commit messages:

- **L1 — Rule R5 works and is not vacuous.** Every cited artefact path in a PASS/FAIL block must now exist on disk. **Falsified independently**: moving `w1_falsify_same_tab.png` aside produced `FAIL: 1 violation(s) ... [W1] Rule R5 violation: Cited artefact does not exist on disk`, with the absolute path, exit **1**; restoring it returned exit **0**.
- **L2 — the classification was done properly, and the hard call was made correctly.** The full three-bucket audit is in the body of `e014845`, file by file with reasons. The 4 orphans were removed with `git rm`. **The 10 outdated-but-true artefacts were retained, not deleted** — that was the judgement this wave turned on, and deleting them on age would have destroyed valid evidence for claims those images still support.
- **The inventory now reconciles exactly: 51 on disk, 51 cited, 0 orphaned, 0 dangling.**
- **L3 — the evidence is real this time, and I opened it rather than reading about it.** `gaslight_case_file_xhpd.png` is a genuine `PNG image data, 2464 x 1510, 8-bit/color RGBA, non-interlaced` at **629,585 bytes**, matching W14's quoted `file` output exactly. `w14_case_file_download.png` shows the snackbar **`Case File saved to Downloads!`**. Both also show the **FINAL STANDINGS** table, so **Issue 111's client half is now device-verified for the first time.**
- **No block claims the undeployed match summary was observed.** That restraint is correct and should not be "improved".

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.** §2 depends on a deploy, and that call is the user's.
- **A mechanical check must assert it matched something.**
- **Open the artefact.** R5 now proves a cited file *exists*; it still cannot prove the image shows what the block claims. That remains the reader's job — lessons 2.25–2.27 in `ongoing_general_errors.md`.
- **`git rm`, never `rm`**, for anything under `docs/playthrough_evidence/`.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects with Pros/Cons and a blank selection line**, per `.agents/skills/bug_documentation_guidelines/SKILL.md`.
- **Do not touch anything in §6 or §7.**

---

## 2. Outstanding — the match summary has never been seen running

**Issue 111 shipped in two halves and only one has been observed.**

The client half is verified: the FINAL STANDINGS table renders, visible in two artefacts from the Wave L session. The **server half — Best Lie of the Night, Cleanest Truth, The Sting — is committed and undeployed**, so `room.matchSummary` has never existed in a real game and no screen has ever rendered those awards.

**This is blocked on the user, not on you.** `check_deploy_fresh.sh` exits 1 for exactly this reason. **Do not deploy to unblock yourself.**

**Once the user has deployed**, the check is small and should reuse the L3 procedure in §4:

1. Play one **multi-round** match to game over — a single round cannot produce a best-lie contest, so a 1-round game can render an empty summary and look fine.
2. Confirm the awards appear, and that **Best Lie quotes an actual forgery a player wrote** in that match — not a placeholder and not a truth.
3. Capture it under a **new filename**, and add or update the block that claims it.
4. **If the awards are absent or wrong, do not fix it inline.** File it with Pros/Cons and a blank selection line.

Until then, the honest position is the one the docs now take: the client half is device-verified, the server half is unverified. **Do not upgrade any block's wording to cover the summary before it has been seen.**

---

## 3. Outstanding — one weak assertion

`functions/test/game_e2e.spec.ts:3530` asserts `summary.bestLie.fooled` is **greater than zero**, never that it is *right*.

The computation itself was verified correct by reading `index.ts:1521-1533` — for each forgery author it counts voters whose resolved vote is that author, excluding self-votes — so **this is a weak test, not a broken feature**, and it is not a reason to stop anything. But `> 0` would pass equally on a double count, an off-by-one, or a count that wrongly included truth-finders.

If you are in this suite anyway: record which option each voter chose, compute the expected fooled count for the winning forgery from those votes, and assert **equality**. **An assertion that reads its own output proves nothing.** Falsify it by skewing the count by one and confirming it fails.

---

## 4. What legitimately starts a new build

An empty queue is a valid state. Refactors, renames and "while I was in there" cleanups are not work — they are risk against a green baseline with no issue behind them. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Every functional defect this project has had came from here. **No gate has ever found one** — and Issue 110 surfaced only because a person opened a screenshot the gate had passed.
2. **The user asks for something**, or fills in a selection line.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

If none of these has happened, **report the state and stop.**

---

## 5. Playthrough procedure — the standing setup

1. **`.env` must contain `USE_EMULATOR=false`** — a bundled asset; changing it after the build has no effect.
2. **Uninstall on every booted simulator** so no stale room is restored from `SharedPreferences`.
3. **Build, then prove the binary is newer than the source**; paste both lines into the report header:
   ```bash
   stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
   ```
4. **Launch one device at a time** — concurrent builds corrupt `build/`. Gate all three on `THE GUEST LEDGER`.
5. `Disable Game Timers` **on** (`lobby_screen.dart:623`), recorded as a deviation. `Family-Friendly Decks Only` **off** (`:643`).
6. **Three real clients. Never `DEBUG: ADD 9 BOTS`.**
7. Paste `flutter --version` into the header rather than recalling it.

**Evidence contract.**

| Field | Takes | Never takes |
|---|---|---|
| `Observed:` | `get_interactive_elements` output, screen text, a saved screenshot path, a `flutter:` log line | A `grep`. A source line. A test name. Prose describing code. |
| `Reference:` | `file:line` — optional context for the expected value | — |

**Name the field `Observed:`.** A renamed variant is what let E11 through a human review; `check_playthrough_evidence.sh` now catches the rename, but do not create the need.

---

## 6. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 22, 2026:**

- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match; with Issue 105's re-runs the report now stands at **14 PASS, 1 NOT RUN (E9, honestly labelled), 0 FAIL**, every cited screenshot present. **E7 seat recovery device-verified** (`xcrun simctl terminate` mid-match → relaunch → straight back to `/reveal`, seat and score intact). **E8 host kick device-verified on both sides.** **No product defect found.**
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R4 mechanically; **E10** re-run in room `YJUG` with the in-game `Leave game` control and evidence from **both** remaining devices; **E11** re-run on a **release** build outside Marionette (its screen coverage stated honestly — the lobby was observed, the rest rests on `kDebugMode` being one compile-time const); **E13** fixed beyond spec, having been found by the script and missed by two human passes.
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**The battery is seven gates:** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 7. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests; `debugSimulateBotResponses` drives several. Their gating is observable only in a release or profile build.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin**.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — **do not simplify to one condition**.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **`castVote` rejects only genuine self-votes.** Never let a client bound exceed the server's.
- **The option id is the authority; text is the fallback, consulted only when the id is null.**
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **`handleDisconnect` has exactly three legitimate callers.**
- **Dialogs render on `groundRaised`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; plus the declined options in `ongoing_general_errors.md` §4.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens (§5, device-verified), callables, debug isolation (§7.1), privacy manifest (§7.2), deploy verification (§8) | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 9. Validation standard

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number — `check_playthrough_evidence.sh` exists because a mandated check of mine did not.

**A check written for one shape of a defect will not catch the next shape.** The rule looked for `grep -`; the next instance was prose, and the one after that was a renamed field. **Assert positively — require the artefact — rather than only forbidding the known-bad token.**

**A `grep` is not an observation.**

**Prove the artefact ships, not that it exists.** The guard is in the source; the button is in the binary.

**Record every substitution.** An omitted assertion reads as though it passed.

**A test harness that cannot express the bug will pass against it.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Fifteen blocks can pass and the game may still not be fun. That question belongs to the Apple beta.

---

## 10. Feedback loop — what past specs got wrong

- **A check that matches nothing returns the same number as a check that passes.** Mine did, and it shipped as a mandatory step.
- **A defect class mutates faster than the rule written to catch it.** `grep` as observation → prose as observation → a **renamed field** hiding both. Each escaped a rule written for the previous shape. **Match the concept, not the literal.**
- **A convention introduced to stop one failure can become the next one.** `grep -F` traceability stopped invented quotes, then became the observation.
- **When a written step fails twice, replace it with a tool.** `check_deploy_fresh.sh` for deploys; `check_playthrough_evidence.sh` for evidence.
- **A fix can be correct while its design doc still describes the vulnerability.**
- **When you redefine what a field holds, enumerate its readers.**
- **A guard's test must be run with the guard removed.**
- **Working logs rot by appending.** One banner, one Resolved heading, one line per resolved issue.
- **One item = one commit.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output. For a mechanical check, confirm it matched a NON-ZERO
    count before believing its result.
(3) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(4) VALIDATE per section 8, including the over-reach guard.
(5) RECORD observed output in the commit body and, for a guard, in a comment
    at the top of the script or test.
(6) RE-RUN THE FULL BATTERY before committing — all six. check_deploy_fresh
    may legitimately still be red for server changes you must not deploy.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done

There is no active build. Both outstanding items are observations.

**If the user has deployed and you are verifying the match summary (§2)**
- [ ] `./scripts/check_deploy_fresh.sh` exits **0** — confirm the deploy actually landed before trusting anything you see.
- [ ] A **multi-round** match reached game over; a 1-round game cannot produce a best-lie contest.
- [ ] The awards render, and **Best Lie quotes a forgery a player actually wrote in that match** — not a placeholder, not a truth.
- [ ] Captured under a **new filename**; no existing artefact name reused.
- [ ] The block claiming it is written only to what the capture shows.
- [ ] `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` exits 0.
- [ ] If the awards are absent or wrong: filed with Pros/Cons and a blank selection line, **not fixed inline**.

**If you strengthen the summary assertion (§3)**
- [x] Expected `fooled` computed from the votes the test cast, asserted with equality.
- [x] Falsified: skewing the count by one makes it fail.

**Across any work**
- [x] Battery at or above baseline: **0 errors** · **≥185** · clean functions build · **≥70** · both evidence gates exit 0.
- [x] **`firebase deploy` was never run by you.**
- [x] One item, one commit; Conventional Commit; WHY in the body.

**If neither task is actionable yet, the correct action is to report the state and stop.** §4 lists the only four things that start a build, and "the queue looked quiet" is not one of them.
