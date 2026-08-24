# Agent Execution Guide — One Observation Outstanding — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–111 are delivered. Waves J, K and L are complete and independently verified. The queue is empty and there is nothing to decide.**

**One task remains and it is not a code change:** the match summary awards have never been rendered in a real game. §2 is that task, written as a playthrough procedure. Everything else in this guide is context.

## Verified baseline — the regression bar

Measured August 24, 2026:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (18 warnings, 204 infos) | `flutter analyze lib test` |
| Client tests | **185/185** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **70/70** | `npm --prefix functions test` |
| Deploy freshness | **exit 0** — the server is current | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 19 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

**The deploy gate is green for the first time in several waves.** The server is current with the tree, so the match summary exists in production. Nothing here needs a deploy — **do not run `firebase deploy`.**

---

## 0. What is already verified — do NOT re-do this

- **The server half is deployed and live.** The deployed `advanceToNextResolution` source archive, at the generation Cloud Functions currently serves, contains `computeMatchSummary`, `matchSummary`, `_summary`, `bestLie` and `cleanestTruth`.
- **The summary logic is tested by equality, not by shape.** `game_e2e.spec.ts` records every vote it casts, computes the expected best-lie count independently, and asserts equality. **Falsified**: skewing the expectation by one gave `AssertionError: expected 1 to equal 2`, 69 passing / 1 failing; 70/70 restored.
- **The client renders the awards** (`_buildMatchHighlights`, `game_over_screen.dart:673`), with widget tests for both the populated and all-null cases.
- **Rule R5 works and is not vacuous** — moving a cited artefact aside makes the evidence gate exit 1 naming the block and path.
- **The artefact inventory reconciles**: 51 on disk, 51 cited, 0 orphaned, 0 dangling.
- **Issue 111's client half is device-verified** — the FINAL STANDINGS table is visible in `gaslight_case_file_xhpd.png` and `w14_case_file_download.png`.

**What is missing is only this: no real game has ever rendered real awards.**

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.** The server is already current.
- **A mechanical check must assert it matched something.**
- **Open the artefact.** R5 proves a cited file exists; it cannot prove the image shows what the block claims. That is still the reader's job — lessons 2.25–2.27 in `ongoing_general_errors.md`.
- **`git rm`, never `rm`**, for anything under `docs/playthrough_evidence/`.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects with Pros/Cons and a blank selection line**, per `.agents/skills/bug_documentation_guidelines/SKILL.md`. Do not fix them inline.
- **Do not touch anything in §5 or §6.**

---

## 2. The outstanding task — render the match summary in a real game

**Goal:** finish one real multi-round match and photograph the awards. This is observation, not implementation. **If the awards are wrong or absent, do not fix it inline** — file it with Pros/Cons and a blank selection line.

### 2.1 Two setup facts that will otherwise waste the run

**Somebody must actually be fooled.** `computeMatchSummary` only collects forgeries with `fooled > 0`, so if every voter finds the truth, `bestLie` is null — and when **all** awards are null, `_buildMatchHighlights` returns `SizedBox.shrink()`, rendering **nothing at all**. A tidy playthrough where everyone votes correctly will therefore show an empty section and look exactly like a broken feature. **Deliberately have at least one player vote for a forgery on at least one card.**

**Run more than one round.** A single round cannot produce a best-lie *contest* — the awards will be technically correct and completely uninteresting, and "The Sting" and head-to-head lines need repeated foolings to mean anything. Set **`totalRounds: 2` or more** in the lobby.

### 2.2 Route A — web, three isolated browser contexts (recommended)

This is where the demo actually lives, and the harness already exists under `test/web_e2e/` from Wave I.

**Three isolated contexts, not three tabs.** Two tabs in one browser profile are **one player** — web `SharedPreferences` is `localStorage` and the anonymous auth user lives in IndexedDB, both per-origin. Playwright's `browser.newContext()` gives separate storage partitions.

Serve the release build locally rather than a deployed URL, so what you observe is the tree you have:

```bash
flutter build web --release
python3 -m http.server 8777 --directory build/web
```

**Prove the artefact is newer than the source** before trusting anything, in epoch seconds, never strings:

```bash
stat -f %m build/web/main.dart.js; git log -1 --format=%ct -- lib
```

### 2.3 Route B — iOS via Marionette, three simulators

Use this if you want the summary confirmed on the platform the beta will ship to. The summary is server-side, so either client proves the same backend; the difference is which rendering you see.

Marionette drives a **debug** Flutter build over the VM service, so `MarionetteBinding` is active (`main.dart:26` — it is behind `kDebugMode`, which is why a release build cannot be driven this way). One MCP server per simulator, each on its own DDS port; the Wave G/H runs used `marionette-p1/p2/p3` on ports 8182/8282/8382 and that configuration is recorded in the header of `docs/playthrough_findings_marionette.md`.

Standing setup that applies to either route is in §4 — **read it before starting**, especially: `.env` must contain `USE_EMULATOR=false` and is bundled at build time so changing it afterwards does nothing; uninstall on every simulator first so no stale room is restored from `SharedPreferences`; launch one device at a time because concurrent builds corrupt `build/`; disable game timers and record that as a deviation; and **three real clients — never `DEBUG: ADD 9 BOTS`**, since bots are server-seeded documents and exercise none of the client path.

### 2.4 What to capture

1. The **game over screen with the awards visible** — at minimum **BEST LIE OF THE NIGHT** with its quote, author and "Fooled N players" badge.
2. Confirm **the quoted text is a forgery a player actually wrote in that match** — not a placeholder, not a truth, not an empty string. Cross-check it against what that player typed.
3. **The Sting** and **Cleanest Truth** if the match produced them.
4. The **standings** in the same shot where possible, so one artefact evidences both halves of Issue 111.

**Save under a new filename** — never reuse an existing artefact name. Reusing a name hides staleness from `ls`, from `git diff --stat`, and from review; that is precisely how block W14 came to overstate twice (lessons 2.26 and 2.27).

### 2.5 Recording it

Add a block to the appropriate findings doc following the existing format — `**Verdict:**`, `**What I did:**`, `**Observed:**`, `**Reference:**`, `**Expected:**` — with the new screenshot path under `Observed:` and the award text quoted verbatim. Then:

```bash
./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md
./scripts/check_playthrough_evidence.sh
```

Both must exit 0. **R5 will now fail the run if you cite an artefact you did not actually save**, which is the point of it.

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

**The outstanding observation (§2)**
- [ ] A **multi-round** match (`totalRounds` ≥ 2) played to game over with **three real clients** — isolated browser contexts or three simulators, never tabs of one profile and never bots.
- [ ] **At least one player deliberately voted for a forgery**, so `bestLie` is non-null and the highlights section is not `SizedBox.shrink()`.
- [ ] Build freshness proven in epoch seconds before the run.
- [ ] **BEST LIE OF THE NIGHT rendered**, and its quoted text **cross-checked against what that player actually typed** — not a placeholder, not a truth.
- [ ] Screenshot saved under a **new filename**; no existing artefact name reused.
- [ ] A findings block added in the existing format, citing the new artefact and quoting the award text verbatim.
- [ ] Both evidence gates exit **0**.
- [ ] If the awards are absent or wrong: filed with Pros/Cons and a blank selection line, **not fixed inline**.

**Across any work**
- [ ] Battery at or above baseline: **0 errors** · **≥185** · clean functions build · **≥70** · deploy gate **exit 0** · both evidence gates exit 0.
- [ ] **`firebase deploy` was never run** — the server is already current.
- [ ] One item, one commit; Conventional Commit; WHY in the body.

**When this is done the queue is genuinely empty.** Report the state and stop — §3 lists the only four things that start a build, and "the queue looked quiet" is not one of them.
