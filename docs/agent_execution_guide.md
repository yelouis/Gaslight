# Agent Execution Guide — BLOCKED: 11 issues awaiting selection — August 27, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue. Do not start any implementation work.**

Wave O (Issues 113–121) has landed as nine commits. **Six of the nine are verified good.** Three did not land as specified, and the fallout — plus seven new playtest requests — is filed as **Issues 122–132** in `docs/ongoing_general_errors.md`. Every one of them ends in a blank `Your selection: _____` line.

**Nothing here may be implemented until the user fills in those lines.** A `(recommended)` label is advice to the user; it is **not** permission to proceed. If you are reading this and the selection lines are still blank, your job is to report that and stop.

---

## 0. The battery is RED, and you must not "fix" it

```
npm --prefix functions test   ->  80 passing, 1 FAILING
```

The failure is `should handle timeout and fill missing slots with placeholder` (`functions/test/game_e2e.spec.ts:1088`), failing with `Error: Cannot vote for a placeholder answer.`

**The guard is not broken. The test is out of date.** O4 made placeholder answers unvotable exactly as Issue 118 Option A specified; that test votes for the reader's truth option, which is a placeholder whenever the reader is the player who timed out. This is **Issue 122**, it has three options, and it has no selection yet.

**Do not delete the test to turn the gate green.** It is the only coverage of the timeout-fill mechanism that every other placeholder test depends on. That is Option C, and its cons say why it is the wrong answer.

---

## 1. Verified baseline — measured in-session, August 27, 2026

This is the regression bar. Every number was produced by running the command, not read from a commit message.

| Gate | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze lib test` | **0 errors**, 0 warnings, 225 infos |
| Client tests | `flutter test` | **202 passing** |
| Functions build | `npm --prefix functions run build` | clean |
| Functions tests | `npm --prefix functions test` | **RED — 80 passing, 1 failing** (Issue 122) |
| Deck sync | `./scripts/check_decks_in_sync.sh` | **exit 0** — 5 decks, 295 lines |
| Deploy freshness | `./scripts/check_deploy_fresh.sh` | **exit 1 — expected.** O1–O5 undeployed |
| Playthrough evidence | `./scripts/check_playthrough_evidence.sh` | **exit 0** — 21 blocks: 20 PASS, 1 NOT RUN, 0 FAIL |

**Read the script's exit code, not a pipeline's.** `./scripts/check_deploy_fresh.sh | tail -6` reports `$?` from `tail`, which is always `0`. Run the script bare, or redirect. The gate itself is correct — it `sys.exit(1)`s on staleness.

---

## 2. Wave O — what is verified DONE. Do NOT rework these.

Verified by reading the source in this session, not from the commit messages.

- **O1 / Issue 117 — `answerAuthors` no longer unions across rounds.** The three `transaction.set(..., { merge: true })` writes at `index.ts:685`, `:1436` and `:1856` became full-document sets. **This is safe, and here is why you must not "fix" it back:** `sealedDataMap` is built from a complete in-transaction `transaction.get` of the sealed doc (`index.ts:1326–1344`), so a full set rewrites every field it read — `seenPrompts`, `truthAnswer`, `sabotageAnswers`, `answerAuthors`, `truthAnswerId`. No field is dropped. The seat token lives in a **different document** (`sealed/seat_{playerId}`, `index.ts:438`) and is untouched. The `_summary` doc still uses `{ merge: true }` at `:1591` and **must keep it** — that one is supposed to accumulate across rounds.
- **O3 / Issue 115 — names snapshotted.** `sealed/_summary.playerNames` accumulates active player names at every reveal transition; `computeMatchSummary` embeds `authorName`, `targetPlayerName`, `deceiverName`, `victimName`. `game_over_screen.dart:706`, `:716`, `:763` read those fields and **never** consult the players subcollection. That is the fix.
- **O6 / Issue 114 — badge pills flex.** *(See §4 — the test is weaker than specified.)*
- **O7 / Issue 116 — raven on the sealed-ballot screen.** Exactly one, asserted at `test/phase3_vote_test.dart:723`.
- **O8 / Issue 119 — vote option sizing.** `AutoSizedAnswerText` (`lib/widgets/card_grid.dart:33`) is a genuine measurement loop — it lays out a `TextPainter` from 16 pt down to a 9.5 pt floor against the real `constraints` and the live `MediaQuery.textScalerOf`, and stops at the first size that fits. This is **not** another fixed-tier table, which is what was asked for and what makes it robust at widths nobody tested.
- **O9 / Issue 121 — the target sees the grid read-only.** Client gates selection on `isTarget` (`phase3_vote.dart:288`, `:442–446`); the server bound is independent and intact at `index.ts:903` (`voterId === targetCardId` → `failed-precondition`). A client that merely hid the button would not have been enough; this does both.

---

## 3. Wave O — what did NOT land, with the evidence

Each was verified against a **running emulator**. Do not re-derive these; the probes are already done.

### O5 / Issue 120 → **Issue 123.** The 10-minute presence window is inert.

```
PROBE server PRESENCE_STALE_MS = 600000 ( 600 s )
PROBE player stale by          = 150 s  -> inside the window, must survive
PROBE handleDisconnect (as HOST) returned = {"success":true}
PROBE Charlie still in the room? = false
PROBE VERDICT: 10-minute window DID NOT protect him
```

Two independent causes, and **fixing either one alone leaves it inert**:
1. `lib/services/game_service.dart:20` still reads `presenceStaleMs = 120000`, and `:457` is what calls `handleDisconnect`.
2. `index.ts:1155` uses `isDead` only inside the **authorization** condition. A host is authorized unconditionally, so the deletion proceeds regardless of how recently the player was seen.

### O2 / Issue 113 → **Issue 124.** The delta map names every fooling forger during the unmask window.

```
PROBE window open? = true
PROBE sabotageAnswers (withheld) = {}
PROBE votes (obfuscated) = {"p_g1":"71ce3cc2-...","p_g2":"p_host"}
PROBE scoreDeltas (published) = {"p_g2":3,"p_host":1}
PROBE actual forgerId = p_g2  -> identifies forger? true
```

This re-opens **Issue 100**. Note the scope honestly: the **UI does not render it** (both the points tray at `phase4_reveal.dart:424` and the standings delta at `:523` are gated on `revealStage >= 4`, and the unmask tray is stage 3), and it is **not wholly new** — `totalScore` and `playersDeceived` already increment at the reveal transition (`index.ts:1531`). O2 turned a diffuse inference into one labelled map.

**The Issue 113 ask itself was delivered.** The deltas are arithmetically right and render right. Do not revert O2.

### O4 / Issue 118 → **Issues 122 and 125.** The guard works; two consequences were missed.

```
PROBE phase           = vote
PROBE resolutionOrder = []
PROBE currentReaderId = null
PROBE after advanceToNextResolution phase = gameOver
```

A round where *every* card is all-placeholder enters the vote phase with no reader. `phase3_vote.dart:134` leaves `currentCard` null and the screen has nothing to show and no control that advances. The host can escape via `advanceToNextResolution`, but no UI offers it.

**The Issue 118 ask itself was delivered** — placeholder options are unvotable server-side (`index.ts:913`) and greyed client-side (`card_grid.dart:69`), and all-placeholder cards are filtered out of `resolutionOrder`.

---

## 4. Carry into whichever wave comes next — smaller gaps, no selection needed

These are not worth their own issues, but a spec that touches the same code should close them.

- **O6's test is weaker than its spec.** The guide asked for a `RenderBox`-bounds assertion at **320 pt and 375 pt**. `test/badge_pills_overflow_test.dart` tests **320 only**, and asserts `expect(tester.takeException(), isNull)` plus `find.text(...)`. `takeException` does catch RenderFlex overflow, so it is a real check — but `find.text` passes on a clipped or ellipsized widget, and 375 pt is untested. The badge bug has already recurred once.
- **O8's test substituted 360 pt for the specified 430 pt** (`test/vote_option_truncation_test.dart:150` covers 320/360/375). The risk direction is narrow, not wide, so this is low-severity — but it is an unrecorded substitution.
- **`answerFontSizeFor` (`lib/widgets/card_grid.dart:27`) is now dead in production.** Only `test/vote_option_truncation_test.dart:137–142` calls it. `AutoSizedAnswerText` replaced it. Delete both when Issue 132 touches this file.
- **`'THE SOUL IS SILENT'` is hardcoded as a Dart literal** at `card_grid.dart:69`, duplicating `kMissingAnswerPlaceholder` (`index.ts:170`). This is the same shape as lesson **2.31** — a sentinel with two owners. If the server's text ever changes, the client silently stops greying. Prefer a single named constant.

---

## 5. Standing constraints — these apply to every future item

- **One item = one commit**, Conventional Commit, WHY in the body.
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.** That call is the user's, and it is what makes O1–O5 real.
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated from `functions/src/prompt_decks.ts`. Regenerate with `./scripts/generate_prompt_decks_dart.sh`.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **A `grep` is not an observation.** **Open the artefact** before trusting a screenshot claim (lessons 2.25–2.28).
- **Assert behaviour, never a constant's own literal** (lesson 2.30). `expect(SOME_CONSTANT).to.equal(600_000)` is not a test.
- **When you change a constant, grep the other language for its literal value**, not its name (lesson 2.31). The mirror rarely shares the name.
- **File anything new** with Pros/Cons per option, exactly one `(recommended)`, and a blank selection line — format in `.agents/skills/bug_documentation_guidelines/SKILL.md`.
- **Do not touch anything in §7 or §8.**

---

## 6. What legitimately starts a new build

An empty queue is a valid state. Refactors, renames and "while I was in there" cleanups are not work — they are risk against a baseline with no issue behind them. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Every functional defect this project has had came from here. Issues 113–132 all came from playtests; **no gate has ever found one.**
2. **The user asks for something**, or fills in a selection line.
3. **A gate that was green goes red.** Fix the cause, not the gate. *(This is live right now — see §0. It still needs a selection, because the fix has three genuinely different shapes.)*
4. **The beta returns real feedback.**

If none of these has happened, **report the state and stop.**

---

## 7. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices:**

- **Wave O's six good items** — see §2.
- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match; with Issue 105's re-runs the report stands at **20 PASS, 1 NOT RUN (honestly labelled), 0 FAIL**, every cited screenshot present. **E7 seat recovery device-verified.** **E8 host kick device-verified on both sides.**
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R5 mechanically.
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`); **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline *(**partially regressed — Issue 124**)*; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

**Build numbers:** App Store Connect has consumed **build 4**. `pubspec.yaml` must exceed it before the next upload — `1.0.0+5` or higher. Do not reuse a consumed number; the upload is rejected.

---

## 8. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests; `debugSimulateBotResponses` drives several.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin**.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — **do not simplify to one condition**.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own. *(Issue 124 is a live violation of this; that is what makes it an issue rather than a preference.)*
- **`castVote` rejects only genuine self-votes.** Never let a client bound exceed the server's.
- **The option id is the authority; text is the fallback, consulted only when the id is null.**
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **`handleDisconnect` has exactly three legitimate callers.** *(Issue 123 Option A would make it distinguish them explicitly — that is a change to make deliberately, with the callers audited, not a drive-by.)*
- **Dialogs render on `groundRaised`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which **breaks the iOS build** — this project has four shell-script build phases and Flutter's artefacts fall outside the sandbox. Proven August 25, 2026: it produced `Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter`; reverting restored a clean build. Xcode will keep offering it; the answer stays no (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is **generated**. **No file outside the catalogue may branch on a deck id** — rating, display name, size and the fallback are declared per deck, and the UI maps rating→colour in `app_colors.dart`. Exactly one deck sets `isFallback`; `getFallbackDeckId()` throws otherwise. `./scripts/check_decks_in_sync.sh` fails the battery when the two drift.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; plus the declined options in `ongoing_general_errors.md` §4.

---

## 9. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens, callables, debug isolation, privacy manifest, deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 10. Validation standard

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A check written for one shape of a defect will not catch the next shape.** Assert positively — require the artefact — rather than only forbidding the known-bad token.

**A constant's value is not behaviour.** Drive the assertion through the same entry point a client uses (lesson 2.30).

**Prove the artefact ships, not that it exists.** The guard is in the source; the button is in the binary.

**Record every substitution.** An omitted assertion reads as though it passed. Two of Wave O's tests silently substituted viewport widths (§4).

**A test harness that cannot express the bug will pass against it.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Every defect in Issues 113–132 came from a person playing, and none from a gate.

---

## 11. Feedback loop — what the Wave O spec got wrong

Wave O's spec was detailed and still produced three misses. Each maps to something it left unpinned:

- **It named the constant, not the behaviour.** "Raise `PRESENCE_STALE_MS` to 10 minutes" was implemented literally and correctly — and was inert, because the spec never said *"a player stale by 150 s must still be in the room after the host's client calls `handleDisconnect`."* **Specify the observable outcome, and the caller that produces it.**
- **It stated a leak guard in prose and a different one in the checklist.** The prose warned that "a delta map keyed by player, published early, leaks who gained from a forgery before authorship is revealed"; the checklist said only "absent from non-revealed cards". The implementer built the checklist item. **The Definition of Done is what gets built — put the real guard there, not just in the rationale.**
- **It asked for a new test and never asked whether an old one still held.** O4 changed a rule that a pre-existing test encoded, and nothing prompted anyone to look. **When a spec changes a rule, require the implementer to grep the existing suite for tests that assert the old one** — before writing new tests, not after.
- **It said "assert the room actually progresses" and the test asserted a filtered array.** The wording was there; the falsification was not. **Name the exact assertion, not the property.**

---

## THE LOOP — for when selections exist

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) GREP THE EXISTING SUITE for tests asserting the rule you are changing.
    Update them in the same commit. A rule change that leaves an old test
    green is a rule that did not change.
(3) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output. For a mechanical check, confirm it matched a NON-ZERO
    count before believing its result.
(4) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE —
    including a viewport width or a test parameter you changed.
(5) VALIDATE, including the over-reach guard.
(6) RECORD observed output in the commit body and, for a guard, in a comment
    at the top of the script or test.
(7) RE-RUN THE FULL BATTERY before committing — all seven, exit codes read
    bare and not through a pipe. check_deploy_fresh may legitimately still
    be red for server changes you must not deploy.
(8) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(9) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done — for this guide, right now

- [x] Wave O verified item by item against source and a running emulator, not against commit messages.
- [x] The six delivered items recorded as do-not-rework, with the reason O1's `merge` removal is safe.
- [x] The three misses recorded with reproducible probe output.
- [x] Issues 122–132 filed with Pros/Cons and one `(recommended)` each.
- [x] Lessons 2.30 and 2.31 added.
- [ ] **The user fills in the eleven selection lines.** Until then there is no queue.

**Queue empty — do not invent work.** The battery being red is not licence to guess at Issue 122; it has three options and the difference between them matters.
