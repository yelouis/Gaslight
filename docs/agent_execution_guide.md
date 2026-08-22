# Agent Execution Guide — Active Build: H1 → H2 (Issue 105, Option A) — August 21, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–104 are delivered** (§5). The pre-demo playthrough ran for real in room `GLRD`: a full 3-round match on three simulators, 13 of 15 blocks with device evidence, **seat recovery after a force-quit device-verified for the first time**, and **no product defect found**.

**Two blocks claim PASS on source inspection**, and the self-check that should have caught them cannot fail. The user selected **Option A: fix the check properly, and run the device tests.**

| # | Item | Touches | Deploy |
|---|---|---|---|
| **H1** | Replace the evidence self-check with a real script | `scripts/` | — |
| **H2** | Re-run **E10** and **E11** on devices | evidence | — |

**H1 before H2, and this is a genuine dependency:** H1 exists to catch blocks shaped like E10 and E11. If H2 writes its blocks first, the thing that validates them does not exist yet — and the two defects H1 targets are precisely the ones a human reviewer already missed twice.

## Verified baseline — the regression bar

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (22 warnings, 194 infos) |
| `flutter test` | **159/159** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **61/61** |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions and the rules release |

---

## 1. Standing constraints

- **One item = one commit.**
- **A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number. **This is what H1 fixes and it was my error.**
- **A `grep` is not an observation.** `Observed:` takes device output; `Reference:` takes source.
- **Record every substitution.** An omitted assertion reads as though it passed.
- **Do not fix anything inline during H2.** Failures are described, filed with options.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not touch anything in §5 or §6.**

---

## 2. H1 — `scripts/check_playthrough_evidence.sh`

**What this means for the user:** the rule that playthrough evidence must come from a device has now failed twice — once by using a `grep` as the observation, once by a check that read nothing and reported clean. **When a written step fails twice, replace it with a tool.** That is what `check_deploy_fresh.sh` did for the deploy gap, and it is the precedent to follow.

### 2.1 The gap

The guide mandated:

```bash
awk '/^\*\*Observed/,/^\*\*(Reference|Expected)/' docs/playthrough_findings_marionette.md | grep -c "grep -"
```

Three separate failures, each of which alone defeats it:

1. **It matched 0 lines.** The report writes fields as list items — `- **Observed:**` — and `^\*\*` requires column 0. Returning `0` because it read nothing is **indistinguishable in its output from a clean pass**.
2. **It only looks for the literal `grep -`.** E10's `Observed:` is *prose describing source code*; a correctly-anchored version would still have passed it.
3. **It would have missed E11 entirely**, because E11's field is named **`Observed (test mode):`** — a rename that dodges an exact-literal match.

### 2.2 What the script must do

Create **`scripts/check_playthrough_evidence.sh`**, executable, taking an optional path argument that defaults to `docs/playthrough_findings_marionette.md`.

**Parse per block.** Split the document on `^### E` headings. For each block, extract:
- the **verdict** — the value after `**Verdict:**`
- the **Observed field**, matched as **`\*\*Observed[^*]*:\*\*`** so it catches `Observed:`, `Observed (test mode):` and any other suffix. **Matching the exact literal `- **Observed:**` is the mistake that let E11 through — do not do it.**
- everything from that field up to the next `**`-prefixed field or the block end.

**Then apply four rules:**

| # | Rule | Rationale |
|---|---|---|
| **R1** | **Assert a non-zero denominator.** Count the blocks found. If it is `0`, **exit 2** — "could not verify". | A parse that matches nothing must never look like a pass. |
| **R2** | A block whose verdict starts with `PASS` **must have an Observed field**. | E11 claims PASS with none. |
| **R3** | A `PASS` block's Observed field **must contain at least one device artefact** — a path matching `docs/playthrough_evidence/[a-z0-9_]+\.png`, a widget-tree entry matching `Type: *Text`, or a log line matching `flutter:`. | This is the **positive** assertion. Only checking for the absence of `grep -` cannot catch prose about code. |
| **R4** | A `PASS` block's Observed field **must not contain** `grep -`, or a bare `file.dart:NN` / `file.ts:NN` citation with no accompanying artefact. | The original negative rule, kept. |

**`NOT RUN` blocks are exempt from R2–R4** but must carry a `**Reason:**` or `**Reason**` line — a NOT RUN with no reason is a silent gap. `FAIL` blocks are held to the same standard as `PASS`.

**Exit codes — three, and conflating any two defeats the tool** (mirroring `check_deploy_fresh.sh`):

| Code | Meaning | Must print |
|---|---|---|
| **0** | Every block satisfies its rules | The block count and how many were PASS / NOT RUN / FAIL — **so a passing run still shows its work** |
| **1** | One or more violations | Each offending block by id, which rule it broke, and the offending line |
| **2** | **Could not verify** — file missing, or **zero blocks parsed** | An explicit "could not verify" naming the cause |

**Exit 2 must never be treated as a pass.** That is the whole lesson of this item.

### 2.3 Validation — and it must actually fail

**Run it against the current report first. It must exit 1 and name E10 and E11.** Those are the two known-bad blocks; a check that passes the file as it stands today has not been written correctly. **Record that output** — it is the falsification, and it goes in the commit body **and** in a comment at the top of the script.

**Then three more observations, each proving a different rule:**

1. **R1** — run it against an empty file or one with no `### E` headings; confirm **exit 2**, not 0.
2. **R3** — temporarily replace a good block's Observed body with prose containing no artefact; confirm it is flagged; restore.
3. **R4** — temporarily put `grep -Fn "foo" lib/main.dart` into a good block's Observed; confirm it is flagged; restore.

**Over-reach guard:** E9 is `NOT RUN` with a reason and **must not** be flagged. If it is, the exemption is wrong and every future honest NOT RUN will be reported as a violation — which trains the next agent to ignore the tool.

**Add it to the battery** in §5 of this guide and in `ongoing_general_errors.md` §1, alongside `check_deploy_fresh.sh`.

### Blast radius

`scripts/check_playthrough_evidence.sh` (new), plus the battery lists. **No production code. No deploy.**

Commit: `test(ci): add a playthrough evidence check that can actually fail`.

---

## 3. H2 — Re-run E10 and E11 on devices

**Run H1 first**, then use it to validate what you write here.

### 3.1 E10 — the below-3 auto-end

**What is wrong today:** verdict `PASS (Cloud Functions backend verification)`; method *"Inspected `functions/src/index.ts:1488` disconnect transaction logic"*; `Observed:` describes code.

**The citation is also wrong.** `1488` is inside `advanceToNextResolution` (declared line 1394) — the normal end-of-match transition. **The below-3 rule is at `index.ts:986`, inside `handleDisconnect` (declared line 842).** Repoint it whatever else you do.

**The behaviour is not in doubt** — `functions/test/game_e2e.spec.ts:2707` covers it, with the lobby-exemption over-reach guard at `:2788`. **What is missing is the device observation.**

**Procedure.** This does not need a full match — just enough to be in play:

1. Setup per §4. Three devices, gated on `THE GUEST LEDGER`.
2. Reach any in-play phase with three players. **`truth` is enough**; do not spend a full 3-round match on this.
3. On P3, use the in-game **`LEAVE GAME`** control — the depart icon in the AppBar's **`leading`** slot — and confirm the dialog. **Not a force-quit**: E7 already covers force-quit, and the below-3 rule fires through `handleDisconnect`, which the leave control invokes.
4. **Observe on P1 and P2 — both of them.** Each must reach Game Over with its score intact. Capture `get_interactive_elements` output **and** a screenshot from **each** device: `e10_p1_gameover.png`, `e10_p2_gameover.png`.

**PASS requires evidence from both remaining devices, not one.** A single device reaching Game Over does not show the transition reached everyone, which is the entire claim.

**If they do not both reach Game Over, that is a real defect.** Record the room code, the phase each device is stuck in, and the `get_logs` output from each, then **file it with options and stop**. Do not fix it during the run.

### 3.2 E11 — the release build

**What is wrong today:** verdict `PASS`, field named `Observed (test mode):`, content = source line numbers plus `flutter test …: 3/3 tests passed`. **No release build was made; `docs/playthrough_evidence/` contains no `e11_*` file.** The procedure below was specced and approved in the F-wave and was not performed.

> ⚠️ **This cannot be done with Marionette, and that is not a limitation to work around.** `MarionetteBinding` is installed only `if (kDebugMode)` (`lib/main.dart:26`), and `kDebugMode` is `false` in release **and** profile — the only builds where the `DEBUG:` gating takes effect. **There is no build in which Marionette can observe the buttons being hidden.** Drive it by hand.

```bash
flutter build ios --simulator --release
```

```bash
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app && xcrun simctl launch <UDID> com.whylabs.gaslight
```

Walk **the lobby**, **the truth/forgery screen** and **the vote screen**, and screenshot each:

```bash
xcrun simctl io <UDID> screenshot docs/playthrough_evidence/e11_release_lobby.png
```

**Confirm zero `DEBUG:` strings on each.** A 10 px grey label is easy to miss — zoom into the region where each button used to sit rather than glancing at the whole screen.

**Reaching the vote screen needs three players.** Either run the release build on three devices, or cover lobby + truth/forgery only and **say so explicitly in the block**. Either is acceptable; silently covering two screens and claiming three is not.

**Rewrite E11's block** with `**Observed:**` (not `Observed (test mode):`), the screenshot paths, and a line stating it was verified on a **release build outside the Marionette session, and why**. **Keep `test/debug_buttons_gating_test.dart` and cite it under `Reference:`** — it is good coverage of the source guard; it is simply not evidence about a release artefact.

### 3.3 Validation for H2

- **`./scripts/check_playthrough_evidence.sh` exits 0** — and paste its output into the report header.
- `grep -c "index.ts:1488" docs/playthrough_findings_marionette.md` → **0**.
- `ls docs/playthrough_evidence/e10_*.png e11_*.png` lists the new screenshots, and every path cited in the report exists on disk.
- The full battery at or above §5's bar.

Commit: `docs(playthrough): verify E10 and E11 on devices`.

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

**Name the field `Observed:`.** A renamed variant is what let E11 through a human review; H1's check now catches the rename, but do not create the need.

---

## 5. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 21, 2026:**

- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match, 13 of 15 blocks with device evidence, all cited screenshots present. **E7 seat recovery device-verified** (`xcrun simctl terminate` mid-match → relaunch → straight back to `/reveal`, seat and score intact). **E8 host kick device-verified on both sides.** **No product defect found.**
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**The battery is five gates**, and after H1 it is six: analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

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

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number — H1 exists because mine did not.

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
(6) RE-RUN THE FULL BATTERY before committing — six gates after H1.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done

- [ ] **H1** — `scripts/check_playthrough_evidence.sh` exists, executable, matching **any `Observed` variant** (not the literal `- **Observed:**`), with rules R1–R4 and three distinct exit codes.
- [ ] **H1 falsification** — run against the report **as it stands today**, it **exits 1 and names E10 and E11**; output recorded in the commit body and in a comment at the top of the script.
- [ ] **H1** — exit **2** observed on a file with zero blocks; R3 and R4 each observed flagging a deliberately-broken block, then restored.
- [ ] **H1 over-reach guard** — **E9 (`NOT RUN` with a reason) is NOT flagged.**
- [ ] **H1** — added to the battery in this guide §5 and in `ongoing_general_errors.md` §1.
- [ ] **H2 / E10** — re-run with the in-game **`LEAVE GAME`** control, not a force-quit; **evidence from BOTH remaining devices**; `index.ts:1488` repointed to **`:986`**.
- [ ] **H2 / E11** — release build installed and driven **by hand**; screenshots saved as `e11_*.png`; block renamed to `**Observed:**`; the gating test kept and cited under `Reference:`; screen coverage stated honestly.
- [ ] **After H2** — `./scripts/check_playthrough_evidence.sh` **exits 0**, and its output is pasted into the report header.
- [ ] Battery at or above §5: **0 errors** · **≥159** · clean build · **61/61** · deploy gate **exit 0** · evidence gate **exit 0**.
