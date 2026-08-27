# Agent Execution Guide — Playtest Triage: Issues 113–121 Awaiting Selection — August 26, 2026

**You are an engineering agent with no memory of this project.**

**Build 4 reached real testers and the playtest produced eleven reports, now filed as nine issues (113–121) in `ongoing_general_errors.md`.** Every one ends in a blank `Your selection: _____`.

## ⛔ STOP — all nine are blocked on the user

Do not start any of them. Each carries options with pros, cons and a marked `(recommended)`; **that label is advice for the user, not permission for you.** Never fill in a selection line.

**Read the issues before touching anything** — several contain investigation that is already done and should not be repeated:

- **113 folds two reported symptoms into one bug.** The reveal's ▲ badge is computed client-side from card scoring only and omits the unmask ±1, so it disagrees with the authoritative total beside it. The "Louis got +3 but shows 2" report is **the badge being wrong, not the score** — 2 was correct.
- **117 records two ruled-out causes**, so nobody re-checks them: the client's option-id cache is already round-scoped, and so is the text fallback. It also names a real hazard found nearby — `answerAuthors` survives the round reset — which is **not** confirmed as the cause.
- **116 is unconfirmed in source** and its recommended option is to reproduce first, not to fix.
- **120 is Issue 112 Option C**, previously filed and deliberately deferred. It is the largest item here and touches the 3-player floor.

## Verified baseline — the regression bar

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** | `flutter analyze lib test` |
| Client tests | **191/191** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **73/73** | `npm --prefix functions test` |
| **Deck sync** | **PASS** — 5 decks, 295 lines compared | `./scripts/check_decks_in_sync.sh` |
| Deploy freshness | **exit 1 until deployed** | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 20 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

---

## 0. The catalogue you are validating against

`functions/src/prompt_decks.ts` is the **source of truth**. `lib/utils/prompt_decks.dart` is **generated** — never hand-edit it; regenerate with `./scripts/generate_prompt_decks_dart.sh`.

| id | Display name | Rating | Prompts | |
|---|---|---|---|---|
| `hypotheticals` | **Hypotheticals** | PG | 50 | **fallback** |
| `real_life` | **Real Life** | PG | 25 | |
| `unhinged_quirks` | **Unhinged Quirks** | PG | 25 | |
| `love_life` | **Love Life** | PG | 25 | |
| `rated_r_nsfw` | **Rated R NSFW** | R | 25 | |

Seal colours (`app_colors.dart`, keyed by rating — never by deck): **PG `0xFF7A6A3A`**, **R `0xFF8B0000`** (oxblood), X `0xFF2A2226` (no deck currently uses X).

**These five values are what every assertion below compares against.** If the catalogue changes before you run, re-read it rather than trusting this table.

---

## 1. Standing constraints

- **Do not run `firebase deploy`.**
- **Never hand-edit `lib/utils/prompt_decks.dart`.** It is generated; edits are erased and `check_decks_in_sync.sh` will fail.
- **Never fill in a `Your selection: _____` line.**
- **A `grep` is not an observation.** `Observed:` takes widget-tree output, screen text, or a screenshot path.
- **Open the artefact.** A screenshot path satisfies the evidence gate; it does not prove the image shows what the block claims (lessons 2.25–2.28).
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Do not fix product defects inline.** File them with Pros/Cons, a marked `(recommended)` option, and a blank selection line, per `.agents/skills/bug_documentation_guidelines/SKILL.md`.
- **Do not touch anything in §7 or §8.**

---

## 2. Marionette setup

The standing procedure is §6 — **read it before starting.** The essentials, plus what is specific to this wave:

- **Three simulators, one MCP server each, on separate DDS ports.** The Wave G/H runs used `marionette-p1/p2/p3` on 8182/8282/8382; that configuration is recorded in the header of `docs/playthrough_findings_marionette.md`.
- **Marionette drives a DEBUG build.** `MarionetteBinding.ensureInitialized()` sits behind `kDebugMode` (`main.dart:26`), so a release build cannot be driven this way.
- **Because it is a debug build, `DEBUG: ADD 9 BOTS` is available. Do not use it.** Bots are server-seeded documents and exercise none of the client path — and this wave is specifically about what the *client* renders and sends. **Three real clients.**
- `.env` must contain `USE_EMULATOR=false`; it is a bundled asset, so changing it after the build has no effect.
- **Uninstall on every simulator first**, or a stale room is restored from `SharedPreferences` — and a room created before the refactor holds a deck id that no longer exists.
- **Launch one device at a time**; concurrent builds corrupt `build/`.
- `Disable Game Timers` **on**, recorded as a deviation.

---

## 3. What to validate

Write findings to `docs/playthrough_findings_marionette.md` as new `### E<n>` blocks continuing the existing numbering, in the existing format. Screenshots go to `docs/playthrough_evidence/` under **new** filenames.

### D1 — The catalogue renders, with declared names

All five decks appear in the lobby carousel, with the **display names exactly as in §0**.

**The decisive one is `Rated R NSFW`.** The old code derived names by splitting the id on underscores, which rendered it **`Rated R Nsfw`**. Seeing the correct capitalisation is proof the declared-name path is live; seeing the old form means the client is running stale code.

### D2 — Seals come from ratings

Four decks show a **PG** seal, one shows **R**. Compare the seal colours against §0 from a screenshot — the widget tree will give you the label but not reliably the colour.

**No deck may show a seal whose letter does not match its rating in §0.**

### D3 — Sizes and the deck-size ceiling

Hypotheticals reports **50** prompts, the other four **25**.

Then confirm the ceiling behaves: a **25-prompt deck cannot serve `players × rounds > 25`**. With 3 players, set rounds to 5 → 15, fine. **This is expected behaviour, not a defect** — the lobby's own `Deck too small` warning should state the real numbers and block START GAME. Only file something if the warning is absent, or its numbers are wrong.

### D4 — The family-friendly filter is rating-driven

Toggle **Family-Friendly Decks Only** ON. **Exactly `Rated R NSFW` disappears**; the four PG decks and `custom` remain. Toggle off and it returns.

### D5 — The toggle writes through (mirror-image of Issue 106)

Select **Rated R NSFW**, then toggle Family-Friendly **ON**. The room's `selectedDeckId` must change to the fallback, **`hypotheticals`**, and the carousel must show Hypotheticals as chosen.

**Verify the room document, not just the screen.** If the UI switches but the room still holds `rated_r_nsfw`, the host sees one deck while the server would start another — the exact class of bug Issue 106 was.

### D6 — Prompts actually come from the chosen deck ⭐

**This is the assertion the whole refactor exists for, and the one that is easy to fake.** "A prompt appeared" proves nothing — the original bug was a prompt appearing from the *wrong* deck.

For **each** of the five decks: select it, start a 3-player game, and **cross-check the prompt text on each card against that deck's `prompts` array in `functions/src/prompt_decks.ts`.** Quote the prompt and name the deck it belongs to in `Observed:`.

A prompt that appears in no deck, or in a different deck than the one selected, is a **FAIL** — file it, do not fix it.

### D7 — Custom games fall back to `hypotheticals`

Create a custom-deck game, contribute prompts, and re-roll until the pool cannot serve one. The replacement must come from **Hypotheticals** — the deck marked `isFallback` — not from any other deck and not from a hardcoded name. Cross-check the text the same way as D6.

### D8 — Re-roll and the carousel preview still work

Re-roll changes the card and the new prompt belongs to the same deck. The carousel's preview line shows a prompt from the deck on that card — this path changed from drawing the whole deck to drawing one, so confirm it still renders text rather than blank.

---

## 4. What NOT to conclude

- **A blocked start on a 25-prompt deck at high player×round counts is correct**, not a bug. See D3.
- **A prompt repeating after many re-rolls is correct.** Re-rolls sample uniformly minus what is live on the table (Issue 107 Option B); repeats across a player's own history are legal by design.
- **The absence of an X-rated deck is correct.** `cah_dark_humor` was removed by the deck rewrite; the X seal colour remains defined for a future deck.
- **The Case File share, the match summary, and presence timing are out of scope.** They were validated in Waves K–M; do not re-run them.

---
## 5. What legitimately starts a new build

An empty queue is a valid state. Refactors, renames and "while I was in there" cleanups are not work — they are risk against a green baseline with no issue behind them. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Every functional defect this project has had came from here. **No gate has ever found one** — and Issue 110 surfaced only because a person opened a screenshot the gate had passed.
2. **The user asks for something**, or fills in a selection line.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

If none of these has happened, **report the state and stop.**

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

**The battery is eight gates:** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

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

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which **breaks the iOS build** — this project has four shell-script build phases (two `xcode_backend.sh`, two CocoaPods `Podfile.lock` diffs) and Flutter's artefacts fall outside the sandbox. Proven August 25, 2026: enabling it produced `Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter` and `Failed to build iOS app`; reverting restored a clean build. Xcode will keep offering it; the answer stays no (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is **generated** and must never be hand-edited. **No file outside the catalogue may branch on a deck id** — rating, display name, size and the fallback are all declared per deck, and the UI maps rating→colour in `app_colors.dart`. Exactly one deck sets `isFallback`; `getFallbackDeckId()` throws otherwise. Regenerate with `./scripts/generate_prompt_decks_dart.sh`; `./scripts/check_decks_in_sync.sh` fails the battery when the two drift.

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

**Before any device work**
- [ ] `./scripts/check_deploy_fresh.sh` exits **0**. If it exits 1, the server still has the old decks — **stop and report**, do not deploy.
- [ ] `./scripts/check_decks_in_sync.sh` exits **0**, so the client you are about to build matches the catalogue you are asserting against.
- [ ] Build freshness proven in epoch seconds; both numbers pasted into the report header.
- [ ] Three simulators, uninstalled first, launched one at a time. **No bots.**

**The assertions**
- [ ] **D1** — five decks render with the declared display names, **`Rated R NSFW` capitalised correctly**.
- [ ] **D2** — four PG seals and one R seal; colours checked against §0 from a screenshot.
- [ ] **D3** — sizes 50 / 25 / 25 / 25 / 25, and the `Deck too small` warning states real numbers when the ceiling is crossed.
- [ ] **D4** — the toggle hides exactly `Rated R NSFW` and nothing else.
- [ ] **D5** — toggling with NSFW selected switches the **room document** to `hypotheticals`, verified in Firestore and not only on screen.
- [ ] **D6** — for **all five** decks, every prompt observed is quoted and matched to that deck's array in the catalogue. This is the wave's core assertion; a block that says "prompts appeared" has not done it.
- [ ] **D7** — a custom game's fallback prompt is traced to **Hypotheticals**.
- [ ] **D8** — re-roll changes the card and stays in-deck; the carousel preview renders text.

**Recording it**
- [ ] New `### E<n>` blocks in `docs/playthrough_findings_marionette.md`, existing format, screenshots under **new** filenames.
- [ ] `./scripts/check_playthrough_evidence.sh` exits **0**.
- [ ] Any failure is **filed** with Pros/Cons, a `(recommended)` option and a blank selection line — **not fixed inline**.

**Across the wave**
- [ ] Battery at or above baseline: **0 errors** · **≥191** · clean functions build · **≥73** · deck sync PASS · both evidence gates exit 0.
- [ ] **`firebase deploy` was never run by you.**
- [ ] `lib/utils/prompt_decks.dart` was never hand-edited.
- [ ] One item, one commit; Conventional Commit; WHY in the body.
