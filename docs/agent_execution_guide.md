# Agent Execution Guide — Wave M Verified · One Beta-Only Check Outstanding — August 25, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–112 are delivered. Wave M is complete and independently verified.** The queue is empty and **there is nothing to decide.**

**One check remains and it cannot be done here** — it needs a real phone, on the TestFlight build. §2 is that procedure.

## Verified baseline — the regression bar

Measured August 25, 2026:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** | `flutter analyze lib test` |
| Client tests | **189/189** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **73/73** | `npm --prefix functions test` |
| Deploy freshness | **exit 0** — the presence fix is live | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 20 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |
| iOS release build | **exit 0** — 49.9 MB `Runner.app` | `flutter build ios --release --no-codesign` |

**The presence fix is deployed and live.** Verified August 26, 2026: the gate reports FRESH, all 15 functions were deployed after the last `functions/src` commit, and the deployed `handleDisconnect` bundle contains `PRESENCE_STALE_MS` and `120000` with **zero** occurrences of `30000`. Production now drops players at 120 s, not 30 s — so the beta will exercise the fix it is meant to validate.

---

## 0. What Wave M delivered — verified, do NOT rework

Checked against the code and falsified in both halves:

- **M1** — a single exported `PRESENCE_STALE_MS = 120_000` is read at both staleness sites; **the literal `30000` appears nowhere in `functions/src/index.ts`.** Boundary tests import the constant rather than hard-coding the number. **Falsified**: flipping the comparison at the `joinRoom` site took the suite to 71 passing / 2 failing; 73/73 restored.
- **M2** — `GameService` is a `WidgetsBindingObserver`; on `resumed` it writes `lastSeen` immediately **and** restarts the heartbeat timer. The observer is registered inside `_startHeartbeat` (session-scoped, **not** the constructor), guarded by `_isObserverRegistered`, and removed via `_stopObserver()` at four sites including `dispose()` and `stopHeartbeat()`. **Falsified**: removing the resume hook fails the immediate-write test while **both over-reach guards still pass** — which is what makes them guards rather than mirrors.
- **iOS builds clean at the committed state**, with `DEVELOPMENT_TEAM` now set in all three configurations.

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **Never accept Xcode's "Update to recommended settings" dialog** — see §6 and lesson 2.29. It breaks the build.
- **A mechanical check must assert it matched something.**
- **Open the artefact.** A cited screenshot path satisfies the gate; it does not prove the image shows what the block claims (lessons 2.25–2.28).
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects with Pros/Cons, a marked `(recommended)` option and a blank selection line**, per `.agents/skills/bug_documentation_guidelines/SKILL.md`.
- **Do not touch anything in §5 or §6.**

---

## 2. The outstanding check — presence on a real locked phone

**Why no test can do this.** Wave M is guarded everywhere a test can reach, and both guards were falsified. But `flutter test` uses fake timers and never suspends the isolate, so it **cannot reproduce iOS backgrounding** — the exact condition M1 and M2 exist to survive. A simulator is no better: it does not suspend timers the way a locked device does, so **a passing simulator run says nothing here.** This needs a physical phone.

**Prerequisite, already satisfied.** `PRESENCE_STALE_MS` lives in Cloud Functions and **is deployed** — confirmed in the shipped bundle, not just by the gate. Still re-run `./scripts/check_deploy_fresh.sh` and require **exit 0** before starting, since a later server commit would silently invalidate the run.

**The procedure**, on the TestFlight build:

1. Join a room with at least three players, one of them on the physical device under test.
2. **Lock that phone for 60 seconds.** Unlock. Confirm the player is **still in the room**, and that the host can still start — the failure this wave fixes was a host being refused for a player who was demonstrably present.
3. **Lock it again for 3 minutes.** Confirm the player **is** dropped. This half matters as much as the first: if a long absence no longer removes anyone, M1 has not raised presence, it has disabled it — and the below-3 auto-end depends on removal still working.
4. Capture both outcomes as screenshots under **new filenames**, and add a block to the appropriate findings doc in the existing format.
5. Re-run both evidence gates; both must exit 0.

**If either half fails, do not fix it inline.** File it with Pros/Cons and a blank selection line. If the 60-second case still drops the player, the likely candidates are that the deploy did not land, or that the resume hook is not firing on a real device the way it does under `handleAppLifecycleStateChanged` — **check the deploy first**, since it is the cheaper of the two to rule out.

**What this still will not prove.** Option B is a longer timeout plus a faster refresh; it does not save a phone locked for five minutes. That is Issue 112 Option C — an explicit *away* state that keeps the seat — which remains unbuilt **by choice**. If beta testers report drops despite this fix, C is the answer, not a larger number.

---

## 3. What legitimately starts a new build

An empty queue is a valid state. Refactors, renames and "while I was in there" cleanups are not work — they are risk against a green baseline with no issue behind them. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Every functional defect this project has had came from here. **No gate has ever found one** — and Issue 110 surfaced only because a person opened a screenshot the gate had passed.
2. **The user asks for something**, or fills in a selection line.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

If none of these has happened, **report the state and stop.**

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

**The battery is seven gates:** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

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

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which **breaks the iOS build** — this project has four shell-script build phases (two `xcode_backend.sh`, two CocoaPods `Podfile.lock` diffs) and Flutter's artefacts fall outside the sandbox. Proven August 25, 2026: enabling it produced `Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter` and `Failed to build iOS app`; reverting restored a clean build. Xcode will keep offering it; the answer stays no (lesson 2.29).

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

**There is no active build.** One check is outstanding and needs the beta.

**The presence check on a real phone (§2)**
- [ ] `./scripts/check_deploy_fresh.sh` exits **0** first — the threshold lives in Cloud Functions and must be live, or the run tests nothing.
- [ ] On a **physical device**, not a simulator: locked **60 s** → still in the room, host can still start.
- [ ] Locked **3 min** → correctly dropped. Both halves, or M1 has disabled presence rather than raised it.
- [ ] Both outcomes captured under **new** filenames and recorded as a findings block.
- [ ] Both evidence gates exit **0**.
- [ ] If either half fails: filed with Pros/Cons and a blank selection line, **not fixed inline** — and the deploy ruled out first.

**If you pick up new work instead**
- [ ] It came from one of the four triggers in §3 — most likely a human playing the game, which is where every functional defect here has come from. **No gate has ever found one.**
- [ ] The falsifying validation was written first, run, and **observed to fail**, with output in the commit body.
- [ ] An over-reach guard exists and can actually fail.
- [ ] Battery at or above the baseline table.
- [ ] One item, one commit; Conventional Commit; WHY in the body; the issue moved into the **single** existing Resolved heading, and the design doc that described the old behaviour updated.
