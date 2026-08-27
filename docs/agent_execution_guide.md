# Agent Execution Guide — Active Build: Wave O — Playtest Fixes (Issues 113–121) — August 26, 2026

**You are an engineering agent with no memory of this project.**

**All nine selections are made.** Build exactly these, in this order.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **O1** | Stop `answerAuthors` accumulating across rounds | **117 → A** | server | ✅ |
| **O2** | Publish the per-card score delta from the server | **113 → A** | server + client | ✅ |
| **O3** | Snapshot player names into the match summary | **115 → A** | server + client | ✅ |
| **O4** | Placeholder answers unvotable; skip an all-sealed card | **118 → A** | server | ✅ |
| **O5** | Longer presence window + room code visible in game | **120 → B** | server + client | ✅ |
| **O6** | Badge pills stop overflowing | **114 → A** | client | — |
| **O7** | Raven on the sealed-ballot screen | **116 → B** | client | — |
| **O8** | Vote options never truncate up to 100 chars | **119 → A** | client | — |
| **O9** | The target sees the options, read-only | **121 → A** | client | — |

**O1–O5 are server-side; land them together and deploy once.** O6–O9 are client-only and need no deploy. **Do not run `firebase deploy` yourself** — that call is the user's, and it is the step that makes O1–O5 real.

**One item = one commit** — nine commits, not one.

---

## 0. What is already established — do NOT re-derive it

### O1's cause is CONFIRMED. Do not "reproduce with logging" first.

Issue 117 was filed asking for reproduction, and the user's selection anticipated checking Firebase. **That has been done and the cause is proven from live production data**, so skip straight to the fix:

- `advancePhaseInternal` builds a fresh `answerAuthors` map and writes it with
  `transaction.set(sealedRef, sealedData, { merge: true })` (`index.ts:1437`).
  **Firestore's `merge: true` merges a map field key-by-key**, so round 2's mapping is *unioned* with round 1's instead of replacing it.
- **Evidence from the playtest room `EKGL`** (2 rounds, still live at the time of writing): four cards carry **`answerAuthors` with 8 entries** while each card has only **4 options** (1 truth + 3 forgeries). 8 = two rounds × four options.
- `getMyOptionId` iterates that map and returns the **first** entry whose `authorId` matches (`index.ts`, near the end of the callable). With both rounds present it can return **round 1's option id**, which matches nothing in round 2's grid — so the player's own answer is never greyed. That is exactly the reported symptom.

**Blast radius, checked so you do not panic:** vote resolution at `index.ts:1478` looks up `answerAuthors[votedOptionId]` by option id, and option ids are UUIDs, so a stale extra entry cannot mis-resolve a vote. **Scoring was not affected** — only the lockout.

### Issue 113 inverts one of the reports

"Louis got +3 but the standings say 2" — **2 was correct.** Louis earned +3 on the card and **−1 for being unmasked**. The ▲ badge was wrong for omitting the penalty. **Do not "fix" the total.**

### Issue 120 Option B does not deliver everything that was asked

The original report asked for three things: a longer grace period, **rejoining with your name**, and the room code visible in game. **Option B delivers the first and third only.** Rejoining with your seat and score intact is Issue 112 Option C (an *away* state), which remains deliberately unbuilt. Do not build it here, and do not claim O5 restores departed players.

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated.
- **A `grep` is not an observation.** **Open the artefact** before trusting a screenshot claim (lessons 2.25–2.28).
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File anything new** with Pros/Cons, a marked `(recommended)` and a blank selection line.
- **Do not touch anything in §11 or §12.**

---

## 2. O1 — `answerAuthors` must not survive its round (117 → A)

**The fix:** make the write replace the map rather than merge into it. Either clear it explicitly at the round advance (where `sealed/{playerId}` is already reset with `truthAnswer: ""` and `sabotageAnswers: {}`), or write `answerAuthors` with `FieldValue.delete()` before setting the new map, or stop using `merge: true` for that field.

**Prefer clearing at the round advance**, next to the existing resets, so the invariant reads as "a sealed doc holds this round's data" in one place.

**Validation**
- An emulator test plays **two** rounds and asserts, after round 2's vote transition, that `sealed/{targetId}.answerAuthors` has **exactly the number of options on that card** — not more. **Falsify it** by restoring the merge; it must fail with 8 where 4 is expected.
- Assert `getMyOptionId` in round 2 returns an option id that **is present in round 2's `card.options`**. This is the assertion that maps to the player-visible symptom; the count alone does not.
- **Over-reach guard:** round 1 still works, and vote resolution still maps votes to authors correctly in both rounds.

---

## 3. O2 — Publish the per-card delta (113 → A)

**The fix:** the reveal transaction already computes every player's total change for the card **including** the unmask ±1. Publish that map alongside the card so the client renders it instead of recomputing.

Replace the client-side computation at `phase4_reveal.dart:260` (`ScoringLogic.calculateScores(...)`) with a read of the published map. **Leave `ScoringLogic` in place** — the server uses it.

**Where it lives matters.** Publish it only when the card is revealed, and only for the card being revealed — the same scoping the reveal already uses. **A delta map keyed by player, published early, leaks who gained from a forgery before authorship is revealed**, which reopens Issues 99 and 100.

**Validation**
- Emulator test: on a card where a player is both scored and unmasked, the published delta equals card points **plus** the unmask adjustment, computed from the votes and guesses the test cast — **not** read back from the summary.
- Widget test: the badge renders the published value; a player with a net **negative** delta is displayed sensibly (today the badge only renders `if (delta > 0)`, so decide and test what a −1 shows).
- **Falsify** by publishing a wrong value and confirming the test fails.
- **Leak guard:** the delta map is absent from cards that are not currently being revealed.

---

## 4. O3 — Snapshot names into the summary (115 → A)

**The fix:** when `computeMatchSummary` runs at game over, store the **display name** next to every player id it references — best lie author, cleanest truth author, and both sides of every rivalry line. The game-over screen then renders names without consulting the players subcollection, which is being emptied as people leave.

**Validation**
- Emulator test: a player **leaves after game over**, and `room.matchSummary` still carries their name. Assert on the summary, not on the players collection.
- Widget test: the game-over screen renders names when the players list is **empty**. That is the reported condition and the one that regresses.
- **Falsify** by removing the snapshot; the widget test must show ids again.

---

## 5. O4 — Placeholder answers are unvotable; an all-sealed card is skipped (118 → A)

**The fix, server-side**, because the reported symptom — sealed for some players, votable for others — is what happens when clients decide independently:
1. `castVote` rejects a vote whose resolved option text is `kMissingAnswerPlaceholder` (`index.ts:170`), with `invalid-argument`.
2. The client greys placeholder options too, so the rule is visible rather than only enforced.
3. If **every** option on a card is a placeholder, the card is **skipped** — advance past it without a vote phase.

**The skip path is where the risk is.** `resolutionOrder`, scoring, and the round advance all assume a card gets votes. A skipped card must not strand the rotation, must not divide by zero in scoring, and must not leave `currentReaderId` pointing at a card nobody will resolve.

**Validation**
- Emulator: a card with one placeholder → that option cannot be voted for; the rest of the card behaves normally.
- Emulator: a card where **all** options are placeholders → the match advances past it and reaches the next card or game over. **Assert the room actually progresses**, not merely that no error was thrown.
- **Over-reach guard:** a normal card with no placeholders is unaffected — same votes, same scoring.
- **Falsify** both by removing each guard in turn.

---

## 6. O5 — Longer presence window, and the room code on screen (120 → B)

**The fix:** raise `PRESENCE_STALE_MS` (currently `120_000`, `index.ts`) to **10 minutes**, and surface the 4-letter room code somewhere persistent during play so people can read it out.

**State the cost in the commit, because it is real.** A player who genuinely leaves now keeps a 3-player game alive for up to ten minutes before the below-3 auto-end fires. With timers enabled, force-advance fills their answers with placeholders — which is precisely why **O4 should land first**: without the skip rule, a long-absent player produces cards nobody can vote on.

**Do not invent a second threshold** to make the auto-end faster. If the delayed auto-end proves annoying in the next playtest, that is a new issue with its own options.

**Validation**
- The existing `PRESENCE_STALE_MS` boundary tests still pass, written against the constant rather than the number — confirm they were, and that they now exercise 10 minutes.
- The room code is visible during truth, forgery, vote and reveal, at the sizes covered by O8's approach — **not** clipped on a narrow phone.
- **This cannot be fully tested here.** Fake timers do not suspend an isolate; the real check is a physical phone backgrounded for several minutes. Record it as a playthrough block, not as a unit test result.

---

## 7. O6–O9 — the client-only fixes

**O6 — badge pills (114 → A).** Wrap the title in `Expanded`/`Flexible` so it ellipsizes and the badge keeps its intrinsic width, in both the game-over MATCH HIGHLIGHTS rows and the lobby's `Lobby Total` pill. **Validation:** widget tests at **320 pt** and **375 pt** asserting the badge's `RenderBox` is fully inside the screen bounds. Falsify by restoring the rigid `Row`.

**O7 — the raven (116 → B).** Add the mascot to the sealed-ballot waiting screen with a pose suited to waiting. **Check first whether one is already present but hidden or clipped** — the issue was filed unconfirmed, and adding a second raven would be worse than the absence. **Validation:** a widget test finds exactly **one** raven on that screen, plus a screenshot.

**O8 — vote option sizing (119 → A).** Replace the fixed font tiers in `card_grid.dart` with measurement: compute the available box and scale the text down until 100 characters fit, with a readable floor. **The current tiers were validated at 375 pt only, which is why this recurred.** **Validation:** extend `test/vote_option_truncation_test.dart` to assert `didExceedMaxLines == false` at **320, 375 and 430 pt** *and* under a large `textScaleFactor`. **Keep loading the real Lora font** — `flutter test` otherwise substitutes a square-glyph fallback that needed 10 lines where Lora needs 5, and tuning against it would shrink real text to nothing.

**O9 — target sees the options (121 → A).** Render the full option grid for the card's target, read-only: no selection, no CONFIRM VOTE. **Validation:** widget test asserting the target sees the same option count as a voter and that tapping changes nothing; and that `castVote` still refuses a target's vote server-side — a client that merely hides the button is not the bound.

---

## 8. Ordering and deploy

Land **O1 → O5** first as five commits, then the user deploys once. **O4 before O5**, because a longer presence window produces more placeholder answers and O4 is what stops those cards stranding a round.

Then **O6 → O9**, client-only, and a fresh `flutter build ipa` plus a web redeploy.

`check_deploy_fresh.sh` will go red the moment O1 lands and stay red until the user deploys. **Say so in each commit** rather than leaving it looking like a regression.

---
## 9. What legitimately starts a new build

An empty queue is a valid state. Refactors, renames and "while I was in there" cleanups are not work — they are risk against a green baseline with no issue behind them. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Every functional defect this project has had came from here. **No gate has ever found one** — and Issue 110 surfaced only because a person opened a screenshot the gate had passed.
2. **The user asks for something**, or fills in a selection line.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

If none of these has happened, **report the state and stop.**

---

## 10. Playthrough procedure — the standing setup

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

## 11. Already delivered — do NOT rework

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

## 12. Invariants & intentional decisions — do NOT change

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

## 13. Where the contracts live

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

## 14. Validation standard

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

## 15. Feedback loop — what past specs got wrong

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

**Server items — O1–O5, five commits, then ONE deploy by the user**
- [ ] **O1** — `answerAuthors` holds only the current round; an emulator test asserts the entry count equals the card's option count, and `getMyOptionId` in round 2 returns an id present in round 2's `card.options`. Falsified by restoring the merge (must fail 8 ≠ 4).
- [ ] **O2** — the per-card delta is published by the server and rendered by the client; it equals card points **plus** the unmask adjustment, computed in the test from the votes and guesses it cast. Negative deltas render sensibly. Leak guard: absent from non-revealed cards.
- [ ] **O3** — the summary carries display names; the game-over screen renders correctly with an **empty** players collection. Falsified by removing the snapshot.
- [ ] **O4** — placeholder options are unvotable server-side and greyed client-side; an all-placeholder card is **skipped and the room provably advances**. Over-reach: normal cards unchanged.
- [ ] **O5** — `PRESENCE_STALE_MS` is 10 minutes with the existing boundary tests still green; the room code is visible in all four in-game phases. The commit **states the delayed auto-end cost** and does **not** claim departed players can rejoin with their name.

**Client items — O6–O9, four commits, no deploy**
- [ ] **O6** — badge fully on screen at 320 pt and 375 pt, asserted on the `RenderBox`.
- [ ] **O7** — exactly **one** raven on the sealed-ballot screen; checked for a pre-existing hidden one first.
- [ ] **O8** — no truncation of 100 characters at **320, 375 and 430 pt** and under a large text scale, with the **real Lora font loaded** in the test.
- [ ] **O9** — the target sees the full grid read-only; `castVote` still refuses their vote server-side.

**Across the wave**
- [ ] Every fix has a falsifying test that was **run and observed to fail**, with the output in the commit body.
- [ ] Battery at or above baseline: **0 errors** · **≥191** · clean functions build · **≥74** · deck sync PASS · both evidence gates exit 0.
- [ ] `check_deploy_fresh.sh` red after O1 is expected and explained; **`firebase deploy` was never run by you**.
- [ ] One item, one commit; Conventional Commit; WHY in the body; Issues 113–121 moved into the **single** existing Resolved heading, and the design docs that described the old behaviour updated — `design_scoring_and_ui.md` owns the reveal beats, the honours and the target lockout, and §3.2's "Reader & Target Lockout" changes with O9.
