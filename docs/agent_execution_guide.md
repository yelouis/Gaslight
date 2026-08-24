# Agent Execution Guide — Active Build: Wave J — Prompt Draw Semantics — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–106 are delivered.** Wave J settles how prompts are drawn: what "random from the selected deck" means for a re-roll (**Issue 107**), and a confirmed crash that stops a custom-deck game reaching round 2 (**Issue 108**).

| # | Item | Touches | Deploy |
|---|---|---|---|
| **J1** | Issue 107 — re-roll sampling + what `custom` re-rolls from | `functions/src/prompt_decks.ts`, `lib/utils/prompt_decks.dart`, `functions/src/index.ts` | functions |
| **J2** | Issue 108 — custom-deck game cannot advance past round 1 | `functions/src/index.ts` | functions |

## ⛔ STOP — this wave is blocked on the user

**Issue 107 has two `Your selection: _____` lines and Issue 108 has one, and all three are blank.** Every option changes what you build, so **do not start.** Do not guess, do not "pick the recommended one to unblock yourself," and **never fill a selection line in on the user's behalf** — that line is theirs.

Read the full text of both issues in `ongoing_general_errors.md` before doing anything else. **Settle 107 Decision 2 before 108**, because both answer the same underlying question — what a custom game draws from — and 108's fix must agree with it.

If the selections are filled in when you arrive, proceed. If not, say so and stop.

## Verified baseline — the regression bar

Run all six before you touch anything, so you know which failures are yours:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (21 warnings, 197 infos) | `flutter analyze lib test` |
| Client tests | **178/178** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **63/63** | `npm --prefix functions test` |
| Deploy freshness | see below | `./scripts/check_deploy_fresh.sh` |
| Playthrough evidence | **exit 0** | `./scripts/check_playthrough_evidence.sh` |

**`check_deploy_fresh.sh` currently exits 1 and that is correct** — commits `1c5d69b` and earlier changed `functions/src/` and have not been deployed. It goes green after `firebase deploy --only functions`. **Do not run that deploy yourself** (§1).

---

## 0. What is already correct — do NOT "fix" it

Verified in source on **August 24, 2026**. An agent that changes any of this is churning working code.

**The initial draw is already uniformly random from the selected deck.** `startGame` calls `PromptDecks.drawPrompts(deckId, activePlayers.length)`, which Fisher-Yates shuffles a copy of the deck and slices the first `count`. `deckId` comes from `room.selectedDeckId` (Issue 106), and each player's first prompt is seeded into `sealed/{playerId}.seenPrompts` at `functions/src/index.ts:476`. **Issue 107 is about the re-roll, not this.**

**The deck is resolved from the room, and a mismatched caller is rejected** (Issue 106, `index.ts:293`). Do not reintroduce a client-supplied deck.

**Re-rolls already never refuse.** `drawOneExcluding(deckId, excluded, mustAvoid)` degrades in steps rather than throwing `resource-exhausted`; only a missing deck throws. See `design_prompt_system.md` §5. Issue 107 changes *which* prompt it prefers, not whether it can fail.

**The next-round draw already avoids collisions within a round.** `advanceToNextResolution` accumulates `assignedThisRound`, so two players cannot be handed the same prompt.

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.** That line is the user's.
- **Do not run `firebase deploy`.** These changes need a functions deploy to take effect; that call is the user's.
- **A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.
- **A `grep` is not an observation.** Neither is prose describing source.
- **Record every substitution.** An omitted assertion reads as though it passed.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Do not touch anything in §7 or §8.**

---

## 2. What legitimately starts a new build

Refactors, renames and "while I was in there" cleanups are not work. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Every recent functional defect came from this — Issues 106, 107 and the whole vote-screen wave. **No gate has ever found one.**
2. **The user asks for something**, or selects an option on an open issue. *(Wave J is this.)*
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

---

## 3. J1 — Issue 107, re-roll sampling

### 3.1 What the code does today

`functions/src/prompt_decks.ts`, `drawOneExcluding(deckId, excluded, mustAvoid)`:

1. `preferred = deck.filter(p => !excluded.has(p))` — pick uniformly from that if non-empty.
2. else `relaxed = deck.filter(p => !mustAvoid.has(p))` — pick uniformly from that.
3. else pick uniformly from the whole deck.

`rerollPrompt` (`index.ts:~850`) builds `inPlay` = every prompt currently on a card, and `excluded` = `inPlay ∪ cardSeen`, where `cardSeen` is that player's `sealed.seenPrompts` history. It calls `drawOneExcluding(deckId, excluded, inPlay)`.

**So step 1 is a draw without replacement across the player's whole history.** That is what Issue 107 Decision 1 is about.

### 3.2 Implementing Decision 1

**If Option A (uniform random every time):** sampling ignores history entirely — pick uniformly from the deck on every re-roll. `seenPrompts` must still be *written* (other code reads it) but stops being consulted for sampling. Expect the player-visible consequence that a re-roll can return the same prompt twice in a row; if the user picked A they have accepted that, so **do not quietly add a "not the same as last time" guard** — that is Option B.

**If Option B (uniform minus what is live):** sample uniformly from `deck.filter(p => !inPlay.has(p))`, where `inPlay` includes the caller's current prompt. History is no longer an exclusion. This is the smallest change: pass `inPlay` as *both* arguments and stop building the `excluded` union from `cardSeen`.

**If Option C (keep today's behaviour):** J1 reduces to documentation. Say so in the commit and change no sampling code. **Do not invent work to justify the item.**

Whichever is chosen, the sampling rule must live in **one** place — `drawOneExcluding` — with `rerollPrompt` supplying sets. Do not branch on the option at the call site.

### 3.3 Implementing Decision 2 (what `custom` re-rolls from)

`index.ts:856` maps `custom` → `the_daily_grind` today.

**Option A** keeps it; the work is to make sure it is *documented at the call site*, because the next reader will otherwise think it is a bug (it looked like one while this was being specced).

**Option B** draws from the players' contributed prompts. The assignment rule already exists in `startGame`'s custom branch (`index.ts:336`) — **reuse it, do not re-derive it.** It enforces the P10 constraint that a player never receives their own prompt, and tops up from `the_daily_grind` when the pool is short. Extract it into a helper both sites call rather than copying it, or the two will drift exactly the way `:856` and `:1476` did (Issue 108).

### 3.4 The mirror is not optional

`lib/utils/prompt_decks.dart` mirrors `functions/src/prompt_decks.ts`. `design_prompt_system.md` requires the **prompt arrays byte-for-byte identical** and the drawing behaviour equivalent; the Dart copy backs client display and `test/fake_functions.dart`. **Any change to sampling must land in both.** A verification pass has already been burned once by a parser that only *appeared* to show divergence — if you check the mirror, bound your parse at the deck's closing bracket, because `cah_dark_humor` is the last entry and a naive slice runs into the class methods below it and reports phantom differences.

---

## 4. J2 — Issue 108, custom games cannot reach round 2

### 4.1 The defect, confirmed

`advanceToNextResolution` resolves the next round's deck as:

```ts
const deckId = room.selectedDeckId || "the_daily_grind";   // index.ts:1476
```

For a custom game `room.selectedDeckId` is the sentinel `"custom"`, and `DECKS` has no such key:

```
$ node -e "PromptDecks.drawOneExcluding('custom', new Set())"
THROWS: not-found | Failed to load deck: custom. Ensure it is defined in PromptDecks.
```

Every custom-deck room with `totalRounds > 1` therefore throws as the last card of round 1 resolves, and the match cannot advance. `rerollPrompt` at `:856` maps the sentinel correctly; `:1476` does not, and **that disagreement is the whole bug.**

### 4.2 What to build

Follow the selected option, and note the recommendation attached to the issue: **whatever the draw rule, resolve the deck in one place.** If two sites can each decide what `custom` means, they will disagree again. Option C's discipline is worth adopting even if A or B is chosen for the draw rule.

**Reproduce before you fix.** A test that has never failed proves nothing here — this defect is invisible in a single-round game, which is why every playthrough missed it (the web sweep W1–W19 ran one round).

---

## 5. Validation for this wave

**Write the failing test first and watch it fail.** For J2 that means an emulator test that starts a **custom-deck, 2-round** game, plays round 1 to resolution, and asserts round 2 begins with real prompts. It must throw `not-found` before your fix.

**Randomness needs a test that can actually fail.** If Decision 1 changes sampling, assert the *distribution*, not one draw:
- Draw many times from a fixed deck and assert **every** prompt appears at least once (a sampler stuck on one element fails).
- **Assert the sample size is non-zero before believing the result** — a loop that ran zero times and a uniform sampler produce the same "no violations" (§10, lesson 2.21).
- Assert the property the option promises: under Option B, a returned prompt is **never** one that was live on a card; under Option A, repeats across history **are** permitted (so a test forbidding repeats would be wrong).
- Seed or repeat enough that the test is not flaky. A randomness test that fails one run in twenty will be deleted by the next agent.

**Existing tests encode the old contract.** Three emulator tests were rewritten in `1c5d69b` when re-rolls became unlimited. If your change breaks a test, decide deliberately whether the test states a requirement that still holds. **Update it to the new contract; never weaken a guard to make a run pass**, and say in the commit which assertions changed and why.

**Do not fix product defects you find inline.** File them with options and a blank selection line.

---

## 6. Playthrough procedure — the standing setup

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

## 7. Already delivered — do NOT rework

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

## 8. Invariants & intentional decisions — do NOT change

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

## 9. Where the contracts live

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

## 10. Validation standard

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

## 11. Feedback loop — what past specs got wrong

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

**Before anything**
- [ ] All three `Your selection: _____` lines (Issue 107 ×2, Issue 108 ×1) are **filled in by the user**. If not, stop and report.
- [ ] Six gates run and recorded, so you know which failures are yours.

**J1 — Issue 107**
- [ ] The selected sampling rule is implemented in **`drawOneExcluding` only**; `rerollPrompt` supplies sets and does not branch on the option.
- [ ] **The Dart mirror is updated to match**, and the prompt arrays remain byte-for-byte identical.
- [ ] A distribution test asserts every prompt in a deck can be drawn, **and asserts its own sample size is non-zero.**
- [ ] The test asserts the property the chosen option actually promises — and does **not** assert a property that only the rejected option would have.
- [ ] If Option C was selected, the commit says plainly that no sampling code changed. **No invented work.**
- [ ] `design_prompt_system.md` §5 updated to describe the rule that now holds.

**J2 — Issue 108**
- [ ] **Reproduced first:** an emulator test with a **custom deck and `totalRounds` ≥ 2** fails with `not-found` before the fix, and the failure output is recorded in the commit body.
- [ ] After the fix, that game reaches round 2 with a prompt on every card.
- [ ] The deck is resolved in **one** place; `index.ts:856` and `:1476` can no longer disagree about what `custom` means.
- [ ] Single-round custom games still work — over-reach guard.
- [ ] `design_prompt_system.md` §3 updated if the custom draw rule changed.

**Across the wave**
- [ ] Battery at or above the baseline table: **0 errors** · **≥178** · clean functions build · **≥63** · evidence gate exit 0.
- [ ] `check_deploy_fresh.sh` may still exit 1 — these are server changes and **you must not deploy**. Say so in the commit rather than leaving it looking like a regression.
- [ ] Any test you changed is explained: which assertion, and why the old one no longer states a requirement.
- [ ] One item, one commit; Conventional Commit; WHY in the body; issues moved into the **single** existing Resolved heading in `ongoing_general_errors.md`.
