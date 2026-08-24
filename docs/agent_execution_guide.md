# Agent Execution Guide — Wave K Verified · One Runtime Check Outstanding — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Wave K is built and independently verified in source. Issues 1–111 are delivered.** There is **no open issue and nothing to decide** — the queue is empty.

**One task remains, and it is not a code change:** the web Case File download (Issue 110) has never been *run*. It compiles and the source is right, but nobody has watched a file land. §3 is the procedure to settle that. Everything else in this guide is context.

## Verified baseline — the regression bar

Measured August 24, 2026:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (21 warnings, 201 infos) | `flutter analyze lib test` |
| Client tests | **185/185** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **70/70** | `npm --prefix functions test` |
| Web release build | **exit 0** | `flutter build web --release` |
| Deploy freshness | **exit 1 — expected**, see below | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 19 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

**`check_deploy_fresh.sh` exits 1 and that is correct.** Wave K's server half (Issue 111) is committed and **not deployed**, so the match summary does not exist in production yet. `firebase deploy --only functions` is **the user's call, not yours.**

---

## 0. What Wave K delivered — verified in source, do NOT rework

Checked against the code, not the commit messages:

- **K1 / Issue 111 (Option C).** Standings render for **every** active player (`_buildStandings`, `game_over_screen.dart:548`, `itemCount: sortedByScore.length`). The summary accumulates inside the existing reveal transaction, reusing the pass that already walks `resolvedVotes`. `sealed/_summary` is initialised at `startGame` (`index.ts:685`), read in `advancePhaseInternal`'s **read phase** (reads at 1296/1303, first write at 1328 — verified in that order), and published to the room **only** inside `gameOver` branches. **All three** `gameOver` sites publish, including both disconnect paths (`:1244`, `:1253`, `:1832`).
- **The security property holds, and its test is not vacuous.** A rules test denies client reads of `sealed/_summary`. **Falsified by injecting `allow read: if true` on a `match /sealed/{docId}` block: the suite went to 69 passing / 1 failing, and back to 70/70 with the rules restored.** The mid-match leak guard asserts `room.matchSummary` is `undefined` after round 1 resolves — this is what keeps Issues 99/100 shut.
- **The `fooled` count is computed correctly** (`index.ts:1521-1533`): for each forgery author it counts voters whose resolved vote is that author **excluding self-votes**, and `truthFinders` counts voters who picked `targetPlayerId`. Answer text is truncated to 100 characters.
- **The Dart whitelist trap was handled.** `matchSummary` is on `GameState` with `toMap` **omitting the key when null**, proven by a round-trip test (`test/deck_selection_test.dart:128`).
- **K2 / Issue 110 (Option B).** Conditional-import shim (`lib/utils/case_file_saver.dart`), web implementation does Blob → `createObjectURL` → anchor with `download` → `click()` → **`revokeObjectURL`**, IO implementation throws `UnsupportedError` rather than pretending to succeed, `web: ^1.1.1` added. **`flutter build web --release` exits 0**, so the interop and the conditional import genuinely resolve.

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **A mechanical check must assert it matched something.**
- **A `grep` is not an observation.** Neither is prose describing source.
- **Open the artefact.** This is the rule that matters most right now — see §2.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects with Pros/Cons and a blank selection line**, per `.agents/skills/bug_documentation_guidelines/SKILL.md`. Do not fix them inline.
- **Do not touch anything in §6 or §7.**

---

## 2. The one gap, and how it happened twice

**Web block W14 has now claimed unobserved behaviour twice.**

The first time it described a "clipboard/fallback handler" that exists nowhere in `lib/`. That was corrected, and the correction explicitly recorded that the prose had overstated.

Wave K then **overwrote that correction** with a fresh claim — that the button "triggers a synthetic anchor download ... followed by showing a confirmation snackbar" — while citing **the same screenshot file, dated August 23 19:35**, taken *before* Issue 110 was built. That image shows the old snackbar, `Sharing is only supported on mobile devices.` The evidence gate passed both times, because R3 checks that a PNG **path** is present; **it cannot open the PNG.**

W14 has been rewritten again to claim only what is evidenced: the web build compiles and the source path is correct; whether a file actually lands is **pending**. Do not restore the stronger wording until §3 has been done.

**The general rule, which is lesson 2.25:** when a block's claim changes, its screenshot must change too. **A stale artefact under new prose is indistinguishable from a fabricated one.** If you update a finding, re-shoot its evidence or downgrade the claim — never leave the old image under the new sentence.

---

## 3. The outstanding task — observe the web Case File download

**Goal:** watch a real PNG land in a browser, then update W14 to match. This is observation, not implementation. **If the download does not work, do not fix it inline** — file it with Pros/Cons and a blank selection line.

### 3.1 Why this needs a browser and not a test

The saver is `package:web` interop: `Blob`, `URL.createObjectURL`, an anchor click, `revokeObjectURL`. None of that exists under `flutter test`, which runs on the Dart VM with no DOM. A unit test can only prove the shim resolves — which `flutter build web --release` already proves. **The only thing that settles this is a browser.**

### 3.2 Reaching the game over screen — the part that costs time

The Case File button lives on the game over screen, which needs a **finished 3-player match**. Two routes:

**Route A — drive three isolated browser contexts (preferred, and how W1–W19 were produced).** Playwright with three `browser.newContext()` instances gives three separate storage partitions and therefore three distinct anonymous players; the harness from Wave I already exists under `test/web_e2e/`. Two tabs in ONE browser profile are **one player** — web `SharedPreferences` is `localStorage` and the anonymous auth user lives in IndexedDB, both per-origin — so tabs will not work.

**Route B — shortcut the match over HTTP, then attach one browser.** The callables can be driven directly with `curl` (mint anonymous tokens against `identitytoolkit`, then `createRoom` / `joinRoom` / `setReady` / `startGame` / `submitAnswer` / `castVote` / `advancePhase` / `advanceToNextResolution`) to reach `gameOver` in seconds. **The catch: a browser cannot then *be* one of those players**, because you cannot inject their anonymous auth session into its IndexedDB. Route B is good for producing a finished room to inspect; it does **not** put you on the game over screen. **Prefer Route A.**

Serve the release build locally rather than testing a deployed URL, so what you observe is the tree you have:

```bash
flutter build web --release
python3 -m http.server 8777 --directory build/web
```

**Prove the artefact is newer than the source before trusting anything**, comparing epoch seconds, never strings:

```bash
stat -f %m build/web/main.dart.js; git log -1 --format=%ct -- lib
```

**Note the server half is undeployed.** The match summary will be **absent** until someone runs `firebase deploy --only functions`. That is fine for this task — Issue 110 is client-only, and the standings render without a summary by design. **Do not deploy to make the summary appear.**

### 3.3 What to capture

1. Reach game over with three real clients and click **Share Case File**.
2. **Confirm a file actually arrives.** Check the browser's download list and the filesystem for `gaslight_case_file_<roomcode>.png`.
3. **Open it.** It must be a valid PNG showing the Case File — not 0 bytes, and not an HTML error page, which is the failure mode a malformed blob URL produces. Record `file <path>` output and the byte size.
4. Screenshot the confirmation snackbar, and save it as **a new file** — `w14_case_file_download.png`, not a re-use of the old name. Put it under `docs/playthrough_evidence/`.
5. Also capture the **standings** on that same screen while you are there; `w14`'s neighbour blocks do not cover them, and Issue 111 has never been seen on a device either.

### 3.4 Updating the report

Rewrite W14's `Observed:` to cite the **new** screenshot and the `file` output, and restore a full-strength `Expected:` only if the download genuinely worked. Keep the note that the block previously overstated — that history is why the rule in §2 exists.

Re-run the gate afterwards; it must still exit 0:

```bash
./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md
```

---

## 4. A weaker assertion worth strengthening while you are in there

The Wave K emulator test asserts `summary.bestLie.fooled` is **greater than zero** and that the award fields are strings/objects. It never checks the count is *right*.

The specification asked for the expected value to be derived **from the votes the test cast**. The computation itself is correct — verified by reading `index.ts:1521-1533` — so this is a weak test rather than a broken feature, and it is **not** a reason to stop. But `fooled > 0` would still pass if the count were double-counted, off by one, or included truth-finders.

If you touch this suite: have the test record which option each voter chose, compute the expected fooled count for the winning forgery itself, and assert equality. **An assertion that reads its own output proves nothing.**

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

**The outstanding runtime check (§3)**
- [ ] Game over reached with **three real browser contexts**, not tabs of one profile.
- [ ] Build freshness proven in epoch seconds before trusting the run.
- [ ] **A file actually landed**, named `gaslight_case_file_<roomcode>.png`.
- [ ] **The file was opened** and is a valid PNG of the Case File — `file` output and byte size recorded. Not 0 bytes, not HTML.
- [ ] The confirmation snackbar was captured in a **new** screenshot, `w14_case_file_download.png` — the old filename is not reused.
- [ ] The **standings** were captured on the same screen; Issue 111 has never been seen on a device.
- [ ] W14 rewritten to cite the new evidence, with full-strength wording **only if the download worked**.
- [ ] `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` exits 0.
- [ ] If the download failed: filed with Pros/Cons and a blank selection line. **Not fixed inline.**

**If you strengthen the summary test (§4)**
- [ ] The expected `fooled` count is computed from the votes the test cast, and asserted with equality rather than `> 0`.
- [ ] Falsified: the assertion fails if the count is deliberately skewed by one.

**Across any work**
- [ ] Battery at or above baseline: **0 errors** · **≥185** · clean functions build · **≥70** · both evidence gates exit 0.
- [ ] `check_deploy_fresh.sh` still red, explained rather than left looking like a regression, and **`firebase deploy` was never run**.
- [ ] One item, one commit; Conventional Commit; WHY in the body.

**When §3 is done and nothing failed, the queue is empty.** Report the state and stop — §2 of the standing sections lists the only four things that start a build, and "the queue looked quiet" is not one of them.
