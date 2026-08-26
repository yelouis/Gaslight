# Agent Execution Guide — Active Build: Wave M — Presence Before the Beta — August 25, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–111 are delivered.** The Apple Developer account has come through and an iOS TestFlight beta is next, so Wave M fixes the one thing most likely to sour it.

| # | Item | Issue & choice | Touches | Deploy |
|---|---|---|---|---|
| **M1** | One shared presence threshold, raised | **112 → Option B** (server half) | `functions/src/index.ts` | **functions** |
| **M2** | Refresh presence the moment the app resumes | **112 → Option B** (client half) | `lib/services/game_service.dart` | — |

**Order is M1 → M2.** M1 defines the constant the whole feature is named around; M2 is the client behaviour that makes the raised threshold sufficient rather than merely longer.

**Do not run `firebase deploy`.** M1 is inert until deployed and that call is the user's.

## Verified baseline — the regression bar

Measured August 25, 2026. All seven green before you start:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (18 warnings, 204 infos) | `flutter analyze lib test` |
| Client tests | **185/185** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **70/70** | `npm --prefix functions test` |
| Deploy freshness | **exit 0** | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 20 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

**iOS builds.** `flutter build ios --release --no-codesign` exits 0 (49.9 MB Runner.app), verified August 25 — the first iOS build since Wave K added `package:web` and the conditional `case_file_saver` imports.

---

## 0. What is already known — do not re-derive it

- **The client heartbeats every 10 s** by writing `lastSeen` **directly** to its own player document (`game_service.dart:300`), not through a callable. That direct write is permitted by the rules for non-protected player fields.
- **The server has exactly two staleness sites, both hardcoded `30000`:** `index.ts:481` (`isStale`, the seat re-bind path in `joinRoom`) and `index.ts:1133` (`isDead`, in `handleDisconnect`). **Nothing else reads a staleness window.**
- **No test encodes the 30-second contract.** `grep` for `30000`, `isStale` and `isDead` across `functions/test/` returns nothing, so raising the number breaks no test — and equally, **nothing currently guards it.** That is a gap M1 closes, not a licence to skip validation.
- **`GameService` is a `ChangeNotifier` and NOT a `WidgetsBindingObserver`.** The lifecycle hook does not exist yet in any form.
- **`marionette_flutter` is safe to ship.** It has no entry in `GeneratedPluginRegistrant` or `Podfile.lock`, and there are zero `marionette` strings in the release binary — pure Dart, fully tree-shaken. **Do not "clean it up" as part of beta prep.**

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **A mechanical check must assert it matched something.**
- **Open the artefact.** A cited screenshot path satisfies the gate; it does not prove the image shows what a block claims (lessons 2.25–2.28).
- **When evidence contradicts a design doc, read the code before filing** — the doc may be incomplete rather than wrong.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects with Pros/Cons, a marked `(recommended)` option and a blank selection line**, per `.agents/skills/bug_documentation_guidelines/SKILL.md`.
- **Do not touch anything in §6 or §7.**

---

## 2. M1 — One shared presence threshold, raised

### 2.1 The change

Replace both hardcoded `30000` literals with a **single exported constant**, and raise it:

```ts
/** How long a player may go unheard from before the server treats them as gone. */
export const PRESENCE_STALE_MS = 120_000;
```

Use it at `index.ts:481` and `index.ts:1133`. **Two independent copies of a timeout is exactly how the `"custom"` sentinel came to disagree with itself in Issue 109** — one definition, two readers.

### 2.2 Why 120 seconds, and what it costs

A screen timeout is typically 30–60 s and a glance at a message is often longer than 30 s, so the current window fires during entirely normal play. **Two minutes clears the common case with margin.**

It is not free, and the trade must be understood rather than discovered later:

- **The below-3 auto-end reacts more slowly.** A player who genuinely walks away keeps a 3-player game alive for up to two minutes before the match ends. That is the right trade — ending a live game early is worse than ending it late — but say so in the commit.
- **Seat takeover is slower.** `joinRoom`'s stale path lets a *different* device claim a seat. This path is unaffected for the common case, because a returning player rejoins with the **same** `playerId` cached in `SharedPreferences` and re-binds by ownership, not staleness.

**State the limitation plainly and do not overclaim in the commit: this does not fix a phone locked for five minutes.** No timeout does. That is what Issue 112 Option C — an explicit *away* state that keeps the seat — exists for, and it remains unbuilt by choice.

### 2.3 Validation for M1

- **A test at each boundary, at both sites.** A player stale by **less** than `PRESENCE_STALE_MS` is **not** reaped; one stale by **more** is. Write it against the constant, not the literal, so it follows a future change.
- **Falsify it.** Flip the comparison (`>` to `<`) and confirm the test fails. A boundary test that passes both ways is testing nothing.
- **Both sites read the constant.** Assert mechanically that the literal `30000` no longer appears in `functions/src/index.ts`, **and assert the check actually read a non-empty file first** — a grep that matches nothing returns the same "clean" as a grep that passes (lesson 2.21).
- **Over-reach guard:** the below-3 auto-end still fires when a player is stale beyond the new threshold. Raising a timeout must not disable the rule it feeds.

---

## 3. M2 — Refresh presence the moment the app resumes

### 3.1 Why the threshold alone is not enough

Raising the window helps the long lock. It does nothing for the **race immediately after unlocking**: the player is back on screen, but their `lastSeen` is still whatever it was when the phone suspended, and stays that way for up to a full 10-second tick. During that gap the host can press START GAME and be refused for a player who is demonstrably present. **That gap is what M2 closes.**

### 3.2 The change

Make `GameService` a `WidgetsBindingObserver` and, on `AppLifecycleState.resumed`:

1. **Write `lastSeen` immediately** — do not wait for the next tick. Reuse the same direct-write path the heartbeat uses, including its `try/catch`: a resume can land before auth and Firestore have settled, and a thrown exception there must not take down the app.
2. **Cancel and restart the heartbeat timer.** This is the step that is easy to miss. A `Timer.periodic` that was suspended with the app cannot be relied on to resume on its own cadence, and a stalled timer reintroduces the whole problem silently. Restarting is cheap and deterministic.

**Register and unregister deliberately.** Add the observer where a room session begins — alongside `_startHeartbeat` — and remove it in `dispose()` and wherever local room state is cleared. **An observer that is added and never removed leaks**, and widget tests here call `gameService.dispose()` explicitly, so a missing `removeObserver` will surface as cross-test interference rather than a clean failure.

**Do not register in the constructor.** `GameService` is constructed in plain `test()` cases that have no widget binding; touching `WidgetsBinding.instance` there fails in a way unrelated to what those tests are checking. Tying the observer's lifetime to an active room session avoids that entirely, and `_heartbeatDisabledForTest` already gives tests an escape hatch on that path.

### 3.3 Validation for M2

- **A widget test drives the lifecycle**, not the internals: dispatch `AppLifecycleState.resumed` and assert a `lastSeen` write happened **immediately**, without advancing 10 seconds of fake time. That distinction is the whole feature — if the test pumps 10 s first, it proves nothing about the fix.
- **Falsify it** by removing the resume hook; the test must fail.
- **Assert the heartbeat still runs** on its normal cadence afterwards, so the restart did not cancel it into silence — a plausible and completely invisible way to break this.
- **Over-reach guard:** no observer is registered when `_heartbeatDisabledForTest` is set, and `dispose()` leaves none behind.

### 3.4 The check no test can make

**None of this proves a real phone survives a real lock.** Timers under `flutter test` are fake, and the iOS suspension behaviour being worked around does not exist there.

Before the beta goes out, someone must do this by hand: join a room on a **physical device**, **lock the phone for 60 seconds**, unlock, and confirm the player is still in the room and the host can still start. Then repeat at **three minutes** and confirm the player *is* dropped — the threshold must still do its job, or M1 has simply disabled presence. Record both as a playthrough block with screenshots under new filenames.

A simulator is not sufficient evidence here: it does not suspend timers the way a locked device does, so **a passing simulator run says nothing about the case this wave exists to fix.**

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

**M1 — the server threshold**
- [ ] A single exported `PRESENCE_STALE_MS` is read at **both** `index.ts:481` and `:1133`; the literal `30000` appears in neither.
- [ ] The "no literal remains" check **asserts it read a non-empty file** before reporting clean.
- [ ] Boundary tests at both sites: below the threshold is not reaped, above it is — written against the constant, not the number.
- [ ] **Falsified**: flipping the comparison makes the tests fail; output in the commit body.
- [ ] **Over-reach guard**: the below-3 auto-end still fires past the new threshold.
- [ ] The commit states the cost plainly — slower auto-end — and does **not** claim this fixes a long lock.

**M2 — the resume hook**
- [ ] `GameService` observes lifecycle; on `resumed` it writes `lastSeen` **immediately** and **restarts** the heartbeat timer.
- [ ] The observer is registered with the room session, **not in the constructor**, and removed in `dispose()` and on room-state clear.
- [ ] Widget test dispatches `AppLifecycleState.resumed` and asserts the write happens **without advancing 10 s**.
- [ ] **Falsified**: removing the hook fails that test.
- [ ] The heartbeat still ticks afterwards — the restart did not silence it.
- [ ] No observer registered under `_heartbeatDisabledForTest`; none left after `dispose()`.

**Before the beta ships**
- [ ] **On a physical device**: locked 60 s → still in the room, host can still start. Locked 3 min → correctly dropped.
- [ ] Recorded as a playthrough block with screenshots under **new** filenames; both evidence gates exit 0.
- [ ] A simulator run is **not** accepted as evidence for this.

**Across the wave**
- [ ] Battery at or above baseline: **0 errors** · **≥185** · clean functions build · **≥70** · both evidence gates exit 0.
- [ ] `check_deploy_fresh.sh` will go **red** after M1 and that is correct — say so in the commit rather than leaving it looking like a regression. **`firebase deploy` was never run by you.**
- [ ] One item, one commit; Conventional Commit; WHY in the body; Issue 112 moved into the **single** existing Resolved heading, and `design_database_and_security.md` updated — it owns the presence and disconnect contract.
