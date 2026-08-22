# Agent Execution Guide — Queue Complete — August 22, 2026

**You are an engineering agent with no memory of this project.**

**There is no active build. Issues 1–105 are delivered, and the queue in `ongoing_general_errors.md` is empty.** The pre-demo playthrough is complete and every assertion in it is device-verified. Do not go looking for work in this file — §2 below is the only list of things that legitimately start a new build.

## Verified baseline — the regression bar

Re-run all six before you change anything, so you know which failures are yours:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (22 warnings, 194 infos) | `flutter analyze lib test` |
| Client tests | **159/159** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **61/61** | `npm --prefix functions test` |
| Deploy freshness | **exit 0** — 15/15 functions **and** the rules release | `./scripts/check_deploy_fresh.sh` |
| Playthrough evidence | **exit 0** — 15 blocks: 14 PASS, 1 NOT RUN, 0 FAIL | `./scripts/check_playthrough_evidence.sh` |

**Two of these six are tools that replaced written steps which had failed twice.** `check_deploy_fresh.sh` exists because "verify the deploy landed" was skipped or eyeballed; `check_playthrough_evidence.sh` exists because "do not cite source as an observation" was violated three times in three different shapes. **Do not weaken either to make a run pass** — a failing gate is the gate working.

---

## 1. Standing constraints

- **One item = one commit.**
- **A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.
- **A `grep` is not an observation.** `Observed:` takes device output; `Reference:` takes source.
- **Record every substitution.** An omitted assertion reads as though it passed.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.** That line is the user's.
- **Do not touch anything in §5 or §6.**
- **Do not invent work.** See §2.

---

## 2. What legitimately starts a new build

The queue is empty, and an empty queue is a valid state — **it is not a prompt to find something**. Refactors, renames, dependency bumps, and "while I was in there" cleanups are not work; they are risk against a green baseline with no issue behind them. Exactly four things start a build:

1. **A human plays the game and something is wrong.** This is the one that matters. **Five of the last six functional waves came from the user playing on simulators; none came from a gate.** The gates protect what is already known — they have never once discovered a product defect.
2. **The user asks for something**, or selects an option on an open issue.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The Apple beta returns real feedback** — the next expected source, and the first that can answer whether the game is *fun*, which no assertion here can.

If none of these has happened, **the correct action is to report the state and stop.** Verify the six gates, say so plainly, and wait.

---

## 3. If you are here to verify rather than to build

Run all six gates and read the source at the cited anchors — **not the commit messages**, which describe intent rather than what landed. **Re-grep every line number in this file before trusting it; they drift.** Spot-check the highest-severity claim independently instead of accepting the summary. For any guard, **remove it and watch its test fail** — a test that passes both with and without the guard is not testing the guard. If verification turns up a gap, prefer fixing it in place over filing an issue, and only escalate when the fix needs a decision that is the user's to make.

---

## 4. Playthrough procedure — the standing setup

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

## 5. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 22, 2026:**

- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match; with Issue 105's re-runs the report now stands at **14 PASS, 1 NOT RUN (E9, honestly labelled), 0 FAIL**, every cited screenshot present. **E7 seat recovery device-verified** (`xcrun simctl terminate` mid-match → relaunch → straight back to `/reveal`, seat and score intact). **E8 host kick device-verified on both sides.** **No product defect found.**
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R4 mechanically; **E10** re-run in room `YJUG` with the in-game `Leave game` control and evidence from **both** remaining devices; **E11** re-run on a **release** build outside Marionette (its screen coverage stated honestly — the lobby was observed, the rest rests on `kDebugMode` being one compile-time const); **E13** fixed beyond spec, having been found by the script and missed by two human passes.
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**The battery is six gates:** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 6. Invariants & intentional decisions — do NOT change

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

## 7. Where the contracts live

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

## 8. Validation standard

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

## 9. Feedback loop — what past specs got wrong

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
(6) RE-RUN THE FULL BATTERY before committing — all six.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done — for whatever you pick up next

There is no checklist for the current build, because there is no current build. Any item you do take on is done when:

- [ ] The **falsifying validation was written first, run, and observed to fail** — with the exact output recorded in the commit body, and in a comment at the top of any script or test you added.
- [ ] For a mechanical check: it was confirmed to match a **non-zero count** before its result was believed, and what it **does not** prove is written down beside it.
- [ ] The **over-reach guard** exists and was observed flagging a deliberately-broken case, then restored.
- [ ] Every **substitution or omitted assertion is recorded**, not silently dropped.
- [ ] **All six gates** are at or above the baseline table above.
- [ ] The issue moved into the **single existing Resolved heading** in `ongoing_general_errors.md`, and **the design doc that described the old behaviour was updated** — a fix whose doc still describes the vulnerability is half a fix.
- [ ] **One item, one commit**, Conventional Commit, WHY in the body.
