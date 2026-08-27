# Agent Execution Guide — BLOCKED: Issue 133 awaiting selection — August 27, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue. Do not start any implementation work.**

Wave P (Issues 122–132) is complete and **the server is deployed**. Ten of eleven items are verified good. One — P4 / Issue 124 — delivered its stated goal and **introduced a new hole in the process**, filed as **Issue 133** in `docs/ongoing_general_errors.md` with three options and a blank `Your selection: _____` line.

**Nothing here may be implemented until that line is filled.** A `(recommended)` label is advice to the user; it is **not** permission to proceed. If you are reading this and the selection line is still blank, your job is to report that and stop.

---

## 0. The one live defect — read this before touching `phase4_reveal.dart` or `index.ts`

**`closeUnmaskWindow` (`functions/src/index.ts:2241`) never checks the deadline, and it is live in production** (deployed 2026-08-27T16:02:43Z).

P4 correctly stopped publishing `scoreDeltas` while the unmask window is open. To close the window on the timeout path it added a callable — and the callable validates the phase, the current card, room membership and the sealed document, but **never reads `room.unmaskDeadline`**. Proven against a running emulator, with the fooled player (the one who is supposed to be *guessing*) making the call:

```
PROBE unmaskDeadline       = 1787846904973
PROBE window open?         = true
PROBE scoreDeltas at reveal= undefined          <- P4's core fix works
PROBE early close returned = {"success":true}   <- should have been failed-precondition
PROBE unmaskDeadline after = 0                  <- window ended for the WHOLE table
PROBE scoreDeltas after    = {"p_host":3,"p_g1":1}
PROBE actual forgerId      = p_host  target = p_g1
PROBE forger identified?   = true  via ["p_host"]
```

Two harms: it **re-opens Issue 100** by a new route, and it lets any single player **abort the guessing window for everyone** — a griefing vector the original leak did not have.

**There is a second, independent gap in the same item.** The client calls `closeUnmaskWindow` only when the caller `isHost` (`lib/screens/phase4_reveal.dart:89`). The spec said *any room member*, deliberately, to avoid host-dependency. As shipped, if the host has left or backgrounded the app **nobody closes the window**, `scoreDeltas` is never published, and the points tray and standings deltas stay empty for the rest of that card. **Both halves must be fixed together** — fixing only the guard leaves the empty-tray path; fixing only the trigger widens who can exploit the missing guard.

**Do not fix this by guessing.** Issue 133 has three options and they differ materially in what infrastructure they add.

---

## 1. Verified baseline — measured in-session, August 27, 2026

This is the regression bar. Every number came from running the command.

| Gate | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze lib test` | **0 errors**, 0 warnings, 221 infos |
| Client tests | `flutter test` | **227 passing** |
| Functions build | `npm --prefix functions run build` | clean |
| Functions tests | `npm --prefix functions test` | **94 passing** |
| Deck sync | `./scripts/check_decks_in_sync.sh` | **exit 0** — 5 decks, 295 lines |
| Deploy freshness | `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH.** 16 functions, deployed 2026-08-27T16:02–16:03Z |
| Playthrough evidence | `./scripts/check_playthrough_evidence.sh` | **exit 0** — 21 blocks: 20 PASS, 1 NOT RUN, 0 FAIL |

**Read a gate's exit code bare, never through a pipe.** `./scripts/check_deploy_fresh.sh | tail -6` reports `$?` from `tail`, which is always `0`.

**The deploy is fresh, which changes what "not yet true in production" means.** For the first time in several waves, the server in production matches the tree — including the unguarded `closeUnmaskWindow`. A fix for Issue 133 will need its own deploy, and that call is the user's.

---

## 2. Wave P — what is verified DONE. Do NOT rework these.

Verified by reading the source and running the battery in this session, and by falsifying the guards — not from the commit messages.

- **P1 / 122 — the red gate is repaired.** The timeout test now selects a non-placeholder, non-self option from `card.options` (asserting the filtered list is non-empty first) instead of voting blindly at `truthAnswerId`. **All three original assertions survive**, including `sabotageAnswers` containing `THE SOUL IS SILENT` — that is the test's real subject and the only coverage of the timeout-fill mechanism. The three sibling `truthAnswerId` sites were checked and correctly left alone.
- **P2 / 125 — an empty resolution order concludes the round.** `concludeResolutionRound` (`index.ts:1352`) was **moved, not copied** — one definition, two callers (`:1639`, `:2068`). The Firestore read/write trap was avoided properly: the empty-order path builds `playerSeenMap` from the **already-read** `sealedDataMap` and passes it in, so the helper performs no new reads inside a transaction that has already written. The tests assert the room **actually progresses** — `gameOver` for a single round, round 2 with three fresh cards for a multi-round game.
- **P3 / 123 — the presence window is real, and falsified.** `handleDisconnect` takes an explicit `"leave" | "kick" | "presence" | "reconcile"` reason and gates **the action, not the caller**: `if (disconnectedPlayer && !isDead) return { success: false, reason: "still-present" }`. It **returns rather than throws**, which matters because the client swallows errors. A missing reason defaults to `"leave"` when self and `"presence"` otherwise — slightly better than the spec's blanket `"presence"`, and correct for old builds. **Falsification performed:** disabling that return fails *exactly* the 150 s test (`expected true to be false`) and leaves the other five green. The client constant is gone — `grep -rn "120000\|presenceStaleMs" lib/` returns nothing.
- **P5 / 130 — timers off by default, duration configurable.** Defaults are `true` at all four sites, using `!== undefined` guards so `false` is not swallowed (lesson 2.1). **All six hardcoded durations are gone**; every phase reads `getPhaseDurations(room.timerSeconds)` (`index.ts:215`), which clamps to 15–300, falls back to 60, and derives vote as `Math.round(sec * 0.75)`. The lobby carries the exact helper text `15–300 seconds. Voting gets 75% of this.`
- **P6 / 127 — re-roll snackbars.** `clearSnackBars()` added before the success snackbar, `duration: 1200ms`.
- **P7 / 128 — departures announced.** Diff-based, exact string `'<name> has left the parlour.'`, suppressed on the first snapshot and in lobby/gameOver, and **`GameService` still does not import `material.dart`** — the messages are drained by the UI. *(See §3 for a testing weakness in this item.)*
- **P8 / 126 — deck peek.** `min(8, deck.prompts.length)` guards the sample, `SHUFFLE` redraws, and **nothing branches on a deck id**.
- **P9 / 132 — one option per row.** `ListView.separated` in portrait with `ConstrainedBox(minHeight: 72, maxHeight: 132)` — **the unbounded-height trap was avoided**, which is what keeps `AutoSizedAnswerText` measuring against a real box instead of picking 16 pt on the first iteration. Landscape keeps `crossAxisCount: 3`. The stale two-column doc comment was rewritten and the dead `answerFontSizeFor` deleted. Tests cover **320, 375 and 430 pt** at 1.0 and 1.3 text scale with the real Lora font, plus a discoverability assertion that six options exceed a 320×640 viewport.
- **P10 / 131 — done key and reachable button.** `textInputAction: TextInputAction.done` with `onSubmitted` routed through `_submitAnswer`, which now opens with `if (_isSubmitting) return;`. The 101-character path is tested through the done key, proving it did not route around the length guard.
- **P11 / 129 — guidance lines.** All three strings verbatim; the forgery line resolves the target's display name and falls back to `them`, never a raw id.

---

## 3. Accepted equivalents — do NOT "fix" these back

Implementations that reached the specified outcome by a different structure. Each was checked; each stands.

- **P10's submit button is not pinned with `viewInsets`.** The spec named `MediaQuery.viewInsets.bottom`; the implementation instead moved the button out of the inner scroll view into the parent column under `SafeArea`, relying on `Scaffold.resizeToAvoidBottomInset`. **Same guarantee, and the test proves it** — 320×640 with `FakeViewPadding(bottom: 300)`, asserting the button's `RenderBox` position sits above the inset. Accepted.
- **P11's guidance line is wrapped in a bordered parchment container**, where the spec said plain italic text with no container. It is a visual deviation on screens with a clipping history, but the 320 pt tests pass. Accepted; do not restyle it without a reason.
- **P1 adds a `setReady` fallback** when a voter has no non-self votable option. Not in the spec, sensible, and it cannot mask the assertion because the non-empty check precedes it. Accepted.
- **P3 defaults a missing `reason` to `"leave"` when the caller is the subject**, rather than the spec's blanket `"presence"`. Strictly better for old clients performing a voluntary leave. Accepted.
- **P4 went beyond Issue 124 Option A into Option B.** The user selected A (withhold the delta map). The implementation *also* defers `totalScore`, `timesFooled` and `playersDeceived` through `pendingScoreDeltas` / `pendingTimesFooled` / `pendingPlayersDeceived`, applied at window close. This closes the pre-existing inference channel Option A explicitly left open. The four apply sites each guard on `if (pendingScoreDeltas)` and `FieldValue.delete()` inside a transaction, so a racing transaction re-reads and skips — no double-application. **Accepted, not reverted.** Be aware the standings strip now legitimately holds still during the unmask window; that is Option B's stated cost, not a bug.

---

## 4. Carry into whichever wave comes next — no selection needed

- **P7's departure diff is implemented twice.** `processPlayersSnapshotForTesting` (`lib/services/game_service.dart:80`) is a `@visibleForTesting` mirror of the logic in the real players listener (`:476`). The unit test therefore exercises **the copy, not the shipped path**, and the two can drift silently — the harness cannot express a bug introduced in the listener alone (§7, and lesson 2.24). Fix by extracting one private method that both the listener and the test hook call.
- **`'THE SOUL IS SILENT'` is still a hardcoded Dart literal** in `lib/widgets/card_grid.dart`, duplicating `kMissingAnswerPlaceholder` (`index.ts:176`). Same shape as lesson 2.31 — a sentinel with two owners. It now appears in test code as well.
- **`kMaxAnswerLength` is duplicated** in the client cap and the server bound. It is currently consistent; a change to either needs the other in the same commit.

---

## 5. Standing constraints

- **One item = one commit**, Conventional Commit, WHY in the body. **P4's commit body was a bare title** — do not repeat that; the body is where the next verification pass looks for what you observed.
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.** That call is the user's.
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated. Regenerate with `./scripts/generate_prompt_decks_dart.sh`.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Read a gate's exit code bare, never through a pipe.**
- **Grep the existing suite for tests that assert the rule you are changing**, before writing new ones.
- **Assert behaviour, never a constant's own literal** (lesson 2.30).
- **When you change a constant, grep the other language for its literal value**, not its name (lesson 2.31).
- **When a change adds a callable, route or field, enumerate what it now permits** before enumerating what it fixes (lesson 2.32). This is the one that produced Issue 133.
- **Clients omit keys rather than sending `null`; callables guard with loose `!= null`** (lesson 2.1) — `false` and `0` are legitimate values.
- **A `grep` is not an observation.** Open the artefact.
- **Do not touch anything in §8 or §9.**

---

## 6. What legitimately starts a new build

An empty queue is a valid state. Refactors, renames and "while I was in there" cleanups are not work — they are risk against a green baseline with no issue behind them. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Every functional defect this project has had came from here. Issues 113–132 all came from playtests.
2. **The user asks for something**, or fills in a selection line.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

**Issue 133 is none of these four — it came from a verification pass, which is the fifth and rarest source.** It is real, it is proven, and it is live in production. It still waits for a selection.

If none of these has happened, **report the state and stop.**

---

## 7. Validation standard

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A constant's value is not behaviour** (lesson 2.30). Drive the assertion through the same entry point a client uses.

**Ask what the change now permits, not only what it fixes** (lesson 2.32). The probe that caught Issue 133 called the new callable; a probe that re-read the room document would have reported the leak closed.

**A rule change that leaves an old test green is a rule that did not change** — grep the suite before writing new tests.

**A test that exercises a mirror of the shipped logic tests nothing about the shipped logic** (§4, first bullet).

**Falsify every guard.** A guard whose test passes with the guard removed is decoration. Wave P's P3 was falsified this way and held; that is the bar.

**Record every substitution.** An omitted assertion reads as though it passed.

**Prove the artefact ships, not that it exists.** The guard is in the source; the button is in the binary.

**A green suite is not evidence about anything it cannot observe.** All seven gates were green while `closeUnmaskWindow` was unguarded and deployed.

**A driven playthrough is not a played one.**

---

## 8. Already delivered — do NOT rework

- **All of Wave P except the Issue 133 defect** — see §2 and §3.
- **Wave O's six good items:** **O1**/117 — `answerAuthors` no longer unions across rounds; the three `{ merge: true }` writes at `index.ts:691`, `:1459`, `:1857` became full-document sets, which is safe because `sealedDataMap` is a complete in-transaction read and the seat token lives in a **different** document (`sealed/seat_{playerId}`). **The `_summary` doc still uses `{ merge: true }` and must keep it** — that one is supposed to accumulate. **O3**/115 — names snapshotted into `sealed/_summary.playerNames`. **O6**/114, **O7**/116, **O8**/119, **O9**/121 — the server bound for the target's vote is independent and intact at `index.ts:924`.
- **Issue 102** — the pre-demo playthrough in room `GLRD`: **20 PASS, 1 NOT RUN, 0 FAIL**, every cited screenshot present. E7 seat recovery and E8 host kick both device-verified.
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R5 mechanically.
- **Issue 103** — seven `DEBUG:` sites gated; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken`, or a stale seat; `votes` stores opaque option UUIDs; the reveal merges only the current card; debug callables are emulator-only *and* host-only. *(Issue 100 is **re-opened by a new route** — that is Issue 133.)*
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

**Build numbers:** App Store Connect has consumed **build 4**. `pubspec.yaml` must exceed it before the next upload — `1.0.0+5` or higher. A reused build number is rejected at upload.

---

## 9. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin**.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — **do not simplify to one condition**.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** This is why `pendingScoreDeltas` lives there.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own. **Issue 133 is a live violation via `closeUnmaskWindow`.**
- **`castVote` rejects only genuine self-votes.** **Never let a client bound exceed the server's** — this is the invariant `closeUnmaskWindow` breaks, and the reason its deadline check is not optional.
- **The presence window gates the ACTION, not the caller.** `isDead` inside an authorization condition is what made Issue 120 inert for a full wave. Do not move it back.
- **The option id is the authority; text is the fallback, consulted only when the id is null.**
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **Dialogs render on `groundRaised`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which **breaks the iOS build** — four shell-script build phases put Flutter's artefacts outside the sandbox. Proven August 25, 2026: `Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter`. The answer stays no (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is **generated**. **No file outside the catalogue may branch on a deck id.** Exactly one deck sets `isFallback`; `getFallbackDeckId()` throws otherwise. `./scripts/check_decks_in_sync.sh` fails the battery when the two drift.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; distinguishing *why* a player left in the departure message (Issue 128 Option B); per-phase timer durations (Issue 130 Option B); plus the declined options in `ongoing_general_errors.md` §4.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens, presence & the disconnect reason union, callables, debug isolation, deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 11. Feedback loop — what the Wave P spec got right, and the one thing it did not

Wave P was the most faithfully implemented wave so far: ten of eleven items landed as specified, including both traps the spec called out in advance (P2's transaction read ordering, P9's unbounded height). Two things are worth carrying forward:

- **Naming the trap works.** P2 and P9 each had a ⚠️ box explaining the failure mode and why the naive version breaks. Both were implemented correctly first time. The boxes earned their space.
- **Naming a guard in prose is not enough if it is one line among ten.** Issue 133's deadline check was specified **twice** — in the implementation steps and in the Definition of Done — and still fell out, because it was one bullet inside a large item whose hard part was the `pendingScoreDeltas` plumbing. **When an item adds a new entry point, the guard on that entry point deserves its own numbered sub-item with its own falsifying test**, not a clause. A validation line that says "refuses an early close" is easy to read as already satisfied by the surrounding checks.
- **The probe must attack the new surface.** Verification of P4 by re-reading the room document reports success. Only calling the new callable finds the hole. **Write the adversarial test against what the change added, not against what it fixed.**

---

## THE LOOP — for when a selection exists

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) ENUMERATE WHAT THE CHANGE PERMITS, not only what it fixes. If it adds a
    callable, route or field, list who can now reach what, and write the
    adversarial test first.
(3) GREP THE EXISTING SUITE for tests asserting the rule you are changing.
    Update them in the SAME commit.
(4) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the exact
    output in the commit body.
(5) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(6) VALIDATE, including every over-reach guard. Re-run the guard with the fix
    REMOVED and confirm the test fails.
(7) RE-RUN THE FULL BATTERY before committing -- all seven, exit codes read
    BARE and not through a pipe.
(8) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options, Pros/Cons, one (recommended),
    and a blank `Your selection: _____`.
(9) COMMIT: Conventional Commit, WHY in the body -- never a bare title. Move
    the issue into the SINGLE existing Resolved heading and update the design
    doc that described the OLD behaviour.
```

---

## Definition of Done — for this guide, right now

- [x] Wave P verified item by item against source, the battery, and a running emulator — not against commit messages.
- [x] P3's guard **falsified** (disabling it fails exactly the 150 s test, five others stay green).
- [x] The ten delivered items recorded as do-not-rework, with their accepted equivalents listed so a later pass does not re-litigate them.
- [x] The P4 defect proven with reproducible probe output and filed as **Issue 133** with three options.
- [x] Two stale design-doc claims corrected; lesson 2.32 added.
- [ ] **The user fills in Issue 133's selection line.** Until then there is no queue.

**Queue empty — do not invent work.** Issue 133 being live in production is not licence to guess at it; the three options differ in what infrastructure they add, and that is the user's call.
