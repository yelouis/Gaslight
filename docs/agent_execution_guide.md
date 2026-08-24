# Agent Execution Guide — Wave J Complete · Issue 110 Awaiting Selection — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Wave J is delivered and independently verified. Issues 1–109 are done.** One issue is open — **Issue 110**, and it is **blocked on the user's selection**.

## ⛔ STOP — the one open item is blocked

**Issue 110 ends in a blank `Your selection: _____`.** It offers three options with pros, cons and a `(recommended)` label. **That label is advice for the user, not permission for you.** Do not guess, do not "pick the recommended one to unblock yourself", and never fill the line in on their behalf.

If the line is filled when you arrive, build it. If not, **report the state and stop** — §2 lists the only four things that legitimately start a build, and "the queue looked quiet" is not one of them.

## Verified baseline — the regression bar

Measured August 24, 2026:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (21 warnings, 197 infos) | `flutter analyze lib test` |
| Client tests | **179/179** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **68/68** | `npm --prefix functions test` |
| Deploy freshness | **exit 1 — expected**, see below | `./scripts/check_deploy_fresh.sh` |
| iOS playthrough evidence | **exit 0** — 15 blocks: 14 PASS, 1 NOT RUN, 0 FAIL | `./scripts/check_playthrough_evidence.sh` |
| Web playthrough evidence | **exit 0** — 19 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

**`check_deploy_fresh.sh` exits 1 and that is correct, not a regression.** Server commits through `74489b0` are undeployed. It goes green after `firebase deploy --only functions` — **which is the user's call, not yours.** Until then, none of Wave J is live: the curated deck contents, unlimited re-rolls, the custom-deck fix and the uniform re-roll sampling all sit in the repo only.

---

## 0. What Wave J delivered — verified in source, do NOT rework

Checked against the code on August 24, 2026, not against the commit messages:

- **J1 / Issue 109 (Option C).** `startGame` writes `effectiveDeckId` (`index.ts:508`); `resolvePromptSource()` is the only code that decides where prompts come from; **the string `"custom"` appears zero times inside `rerollPrompt` and `advanceToNextResolution`**, each of which calls the resolver once. A legacy fallback lives inside the resolver, so a room started before the change still resolves. Verified by calling the resolver directly against three shapes — custom with `effectiveDeckId`, custom **without** it (the old crash path), and a built-in deck — all three return a usable source.
- **J2 / Issue 108 (Option B).** `buildCustomPromptPool()` and `assignPromptsFromCustomPool()` are extracted and shared by `startGame`, the re-roll, and the round advance, so the three cannot drift. **Never-your-own-prompt is enforced in the assigner** (`authorId !== player.id`) and on the re-roll path.
- **J3 / Issue 107 (Option B).** The re-roll calls `drawOneExcluding(deckId, inPlay, inPlay)` — uniform, excluding only what is live on a card. `cardSeen` survives **only** to append to `seenPrompts`. **The round-advance draw still consults `seenPrompts`**, exactly as specified; Option B was not over-applied there.
- **The test swap was deliberate and correct.** Four assertions of the form `seenByHost.has(...) === false` were removed — they asserted Option C's without-replacement property, which the user did not choose — and replaced with Option B's two promises: the card visibly changes, and the new prompt was not live on the table. The commit names the change and why.
- **Both mandated guards are present:** the distribution test asserts `sampleCount > 0` before believing its result, and the sentinel-containment check asserts it actually read the function bodies (`body.split('\n').length > 10`) before believing a zero-match.

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.** A `(recommended)` label is advice for the user.
- **Do not run `firebase deploy`.**
- **A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.
- **A `grep` is not an observation.** Neither is prose describing source.
- **Open the artefact.** A screenshot path satisfies the evidence gate; it does not prove the screenshot shows what the block claims (§8, lesson 2.25).
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects you find, with Pros/Cons and a blank selection line**, per `.agents/skills/bug_documentation_guidelines/SKILL.md`. Do not fix them inline.
- **Do not touch anything in §5 or §6.**

---

## 2. What legitimately starts a new build

1. **A human plays the game and something is wrong.** Every functional defect this project has had came from here. **No gate has ever found one** — and the playthrough that produced Issue 110 found it only because a human read the screenshot.
2. **The user asks for something**, or fills in a selection line.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

An empty queue is a valid state. **Report it and stop.**

---

## 3. If you are here to verify rather than build

Run all seven gates, then read the **source** at the cited anchors — not the commit messages, which describe intent rather than what landed. **Re-grep every line number before trusting it; they drift.**

Two things this project has learned the hard way, both of which paid off again this pass:

- **Spot-check the highest-severity claim independently.** For Wave J that meant calling `resolvePromptSource` directly against the shape that used to crash, rather than trusting a passing test named after the bug.
- **Open the evidence.** Web block W14 claimed a "clipboard/fallback handler" that does not exist anywhere in `lib/`, and the screenshot it cited showed the feature declining to run. The evidence gate passed it, because R3 checks that a PNG path is present — it cannot read the PNG. That became Issue 110 and lesson 2.25.

If verification turns up a gap, prefer correcting it in place over filing, and escalate only when the fix needs a decision that is the user's to make.

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

There is no active build. Issue 110 is blocked on the user.

**If Issue 110 has been selected, it is done when:**
- [ ] The selected option is implemented behind the existing `kIsWeb` branch in `game_over_screen.dart:105`, reusing the **already-rendered** PNG bytes rather than re-rendering.
- [ ] Mobile is untouched — `Share.shareXFiles` still runs on iOS, proven by a test that fails if the branch is inverted.
- [ ] The web path is **observed**, not asserted from source: a screenshot showing what the user actually gets, and the W14 block updated to match.
- [ ] If Option C: the Option B fallback is implemented **and tested**, because file sharing via `navigator.share` is unevenly supported.
- [ ] Battery at or above the baseline table: **0 errors** · **≥179** · clean functions build · **≥68** · both evidence gates exit 0.
- [ ] Issue 110 moved into the **single** existing Resolved heading, and `design_scoring_and_ui.md` updated if P6's delivery changed.

**If it has not been selected, the only correct action is to report the state and stop.**
