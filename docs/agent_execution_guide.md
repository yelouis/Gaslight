# Agent Execution Guide — Awaiting one selection (Issue 105) — August 21, 2026

**You are an engineering agent with no memory of this project.**

**The pre-demo build is done and the playthrough ran for real.** Issues 1–104 are delivered; the app a friend installs has gated debug controls, the raven icon, a real launch screen, and an App Store privacy manifest inside the bundle. A full 3-round match ran across three simulators in room `GLRD` with device evidence, and **seat recovery after a force-quit was verified on a device for the first time**. **No product defect was found.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (22 warnings, 194 infos) |
| `flutter test` | **159/159** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **61/61** |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions and the rules release |

**One item is open: Issue 105.** It needs a `Your selection:` line before anything proceeds (§2).

---

## 1. Standing constraints

- **A `grep` is not an observation.** `Observed:` takes device output — a widget-tree entry, screen text, a saved screenshot path, a `flutter:` log line. Source citations go in `Reference:`.
- **A mechanical check must assert it matched something.** A check that reads zero lines returns the same number as a clean pass. **This is Issue 105.2 and it was my error, not the implementer's.**
- **One item = one commit.**
- **Record every substitution.** An omitted assertion reads as though it passed.
- **Do not renumber the assertion list.** E1–E12 are the specced set; E13–E15 are extra coverage.
- **Do not fix anything inline during a playthrough.** Failures are described, filed with options.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not touch anything in §5 or §6.**

---

## 2. Issue 105 *(blocked on selection)*

### 2.1 What is wrong

**105.1 — E10 has no device evidence and cites the wrong function.** Its verdict is `PASS (Cloud Functions backend verification)`; its method is *"Inspected `functions/src/index.ts:1488` disconnect transaction logic"*; its `Observed:` describes what the code does. The specced evidence was *"All devices at Game Over with scores intact."*

The citation is wrong in a way that matters:

| Claim | Reality |
|---|---|
| `index.ts:1488` is `handleDisconnect`'s below-3 logic | **1488 is inside `advanceToNextResolution`** (declared line 1394) — the normal end-of-match transition |
| — | The below-3 rule is at **`index.ts:986`**, inside `handleDisconnect` (declared line 842) |

**The behaviour is not in doubt.** `functions/test/game_e2e.spec.ts:2707` covers it, with the lobby-exemption over-reach guard at `:2788`. What is missing is the device observation; what is wrong is the pointer.

**105.2 — the self-check I specced cannot fail.** It mandated:

```bash
awk '/^\*\*Observed/,/^\*\*(Reference|Expected)/' docs/playthrough_findings_marionette.md | grep -c "grep -"
```

**It matched 0 lines** — the report writes `- **Observed:**` as list items and the `^\*\*` anchor requires column 0. It returned `0` because it read nothing, which is indistinguishable from a clean pass. It is also too narrow: it looks for the literal `grep -`, and **E10's `Observed:` is prose describing source**, so a correctly-anchored version would still have passed it.

### 2.2 The options

Full text in `docs/ongoing_general_errors.md`, Issue 105. In brief:

- **Option A (recommended)** — fix the check properly **and** run the one short device test E10 needs.
- **Option B** — fix the check; downgrade E10 to `PASS (emulator-verified) · NOT RUN on device` and repoint the citation.
- **Option C** — repoint the citation only.

**Under every option, 105.2's re-anchor is mandatory.** A check that silently matches nothing is worse than no check, because it produces a number that reads as evidence.

### 2.3 How to fix the check (all options)

The replacement must do three things the original did not:

1. **Match the real field shape.** Fields are list items: `- **Observed:**`. Drop the `^` anchor or match `^[-*] \*\*Observed`.
2. **Assert a non-zero denominator.** Count the `Observed:` blocks found and **fail if that count is less than the number of assertion blocks in the document.** A check with no denominator cannot distinguish "clean" from "read nothing".
3. **Assert positively, not just negatively.** Rather than only grepping for `grep -`, require each `Observed:` block to contain **at least one device artefact**: a path under `docs/playthrough_evidence/`, a `Type: Text` widget-tree entry, or a `flutter:` log line. That is what catches E10, whose `Observed:` is prose with no artefact in it.

**Validate the check by making it fail.** Temporarily replace one `Observed:` block's body with a source citation and confirm the check reports that block; restore it. **Record the observed failure output** — a check that has never failed has not been tested, which is the whole of 105.2.

### 2.4 If Option A is selected — running E10

E10 does not need a full match. Get three devices into an active match, have one leave, and observe the other two.

- Setup as in §4: `.env` with `USE_EMULATOR=false`, uninstall first, build debug, **prove the binary is newer than the last `lib/`/`ios/` commit**, launch one device at a time, gate on `THE GUEST LEDGER`.
- Reach any in-play phase with three players — `truth` is enough; a full 3-round match is not required.
- On P3, use the in-game **`LEAVE GAME`** control (`leading` slot of the AppBar), **not** a force-quit — E7 already covers force-quit, and the below-3 rule fires on `handleDisconnect`.
- **Observe on P1 and P2**: both reach Game Over, and their scores are intact. Capture `get_interactive_elements` output and a screenshot from **each** device.

**PASS requires evidence from both remaining devices**, not one. **If they do not both reach Game Over, that is a real defect** — record the room code, the phase each device is stuck in, and file it with options. Do not fix it during the run.

---

## 3. Do not invent work

Outside Issue 105 there is no queue. Legitimate triggers: a defect this work surfaces, a user-selected issue, `ROOM_TTL_MS` dropping below ~4 hours, or a sibling Phosphor glyph turning out wrong.

**The next real change should come from the Apple beta**, once the licence lands — friends on real devices is the strongest signal available, and every defect in the last six waves came from someone playing the game rather than from a gate.

**If you find something worth doing, file it — do not do it.**

---

## 4. Playthrough procedure — for whenever one is run again

**Setup.** Marionette is installed and working (`marionette_flutter`, binding at `lib/main.dart:26`, three servers in `.agents/mcp_config.json`). Verify rather than redo.

1. `.env` must contain `USE_EMULATOR=false` — a bundled asset; changing it after the build has no effect.
2. Uninstall on every booted simulator so no stale room is restored.
3. Build debug, then **prove the binary is newer than the source**; paste both lines into the report header:
   ```bash
   stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
   ```
4. Launch **one device at a time**; gate all three on `THE GUEST LEDGER` before any assertion.
5. `Disable Game Timers` **on**, recorded as a deviation. `Family-Friendly Decks Only` **off**.
6. **Three real clients. Never `DEBUG: ADD 9 BOTS`** — bots never traverse the client write path or the rules.
7. Prefix answers `AAA` / `BBB` / `CCC` — E5 and E6 depend on that ground truth.
8. Paste `flutter --version` into the header rather than recalling it.

**Evidence contract.**

| Field | Takes | Never takes |
|---|---|---|
| `Observed:` | `get_interactive_elements` output, screen text, a saved screenshot path, a `flutter:` log line | A `grep`. A source line. A test name. Prose describing code. |
| `Reference:` | `file:line` — optional context for the expected value | — |

Save screenshots under `docs/playthrough_evidence/` named by assertion (`e5_p1_standings.png`) and cite the path. **A screenshot you did not look at is not evidence.**

**⚠️ E11 can never be checked during a Marionette run.** `MarionetteBinding` is installed only `if (kDebugMode)` (`lib/main.dart:26`), and `kDebugMode` is `false` in both release and profile — the only builds where the `DEBUG:` gating takes effect. **In the session those buttons WILL be visible and that is CORRECT.** Do not record E11 as FAIL from it, do not delete the buttons (`debugSimulateBotResponses` drives emulator tests), and do not switch to profile — the binding is absent there too. E11 is a separate release build, installed and driven by hand, screenshotted, recorded as its own block **stating the different method and why**.

**The twelve assertions** are fixed and must not be renumbered: E1 full match · E2 reveals correct **including cards 2 and 3** · E3 unread cards blank · E4 unmask withholding · E5 scoring · E6 attribution by prefix · E7 seat recovery (force-quit) · E8 host kick · E9 4-player departure · E10 below-3 auto-end · E11 release build · E12 icon and launch screen. E13+ are extra coverage.

---

## 5. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 21, 2026:**

- **Issue 102** — the pre-demo playthrough ran in room `GLRD`: a full 3-round match, 13 of 15 blocks with device evidence, all 10 cited screenshots present on disk. **E7 seat recovery device-verified** — `xcrun simctl terminate` mid-match, relaunch, straight back to `/reveal` with seat, score and ballot history intact. **E8 host kick device-verified** on both the host and the evicted device. **No product defect found.**
- **Issue 103** — all seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` passes `plutil -lint`, declares three collected types with `Linked: false` / `Tracking: false`, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.
- **`test/debug_buttons_gating_test.dart`** — 9 assertions; keep it. It covers the source guard, not the release artefact.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 6. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests. Their gating is observable only in a release or profile build.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin**.
- **The 1024 icon must have no alpha and no pre-rounded corners.** Regenerate from the master; never hand-edit a slot.
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
| Rules, **seat tokens (§5, now device-verified)**, callables, debug isolation (§7.1), privacy manifest (§7.2), deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 8. Validation standard

**A `grep` is not an observation.** `Observed:` takes device output; `Reference:` takes source.

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A check written for one shape of a defect will not catch the next shape.** State what it does not prove.

**Prove the artefact ships, not that it exists.** The guard is in the source; the button is in the binary.

**Record every substitution.** An omitted assertion reads as though it passed.

**Check that a test's subject is the thing the spec named.**

**A test harness that cannot express the bug will pass against it.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Assert the negative as well as the positive.** **Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Twelve assertions passed and the game may still not be fun. That question is the Apple beta's.

---

## 9. Feedback loop — what past specs got wrong

- **A check that matches nothing returns the same number as a check that passes.** Mine did. Assert a non-zero denominator before believing a result.
- **A convention introduced to stop one failure can become the next one.** `grep -F` traceability stopped invented quotes, then got used *as* the observation.
- **A fix can be correct while its design doc still describes the vulnerability.**
- **A documented invariant with no test behind it is a wish.**
- **When a design doc calls something a secret, grep for where it is published.**
- **When you redefine what a field holds, enumerate its readers.**
- **A guard's test must be run with the guard removed.**
- **A spec can be over-cautious as well as wrong.**
- **Working logs rot by appending.** One banner, one Resolved heading, one line per resolved issue.
- **One item = one commit.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output. For anything shipped in a bundle, check the BUILT
    ARTEFACT. For a mechanical check, confirm it matched a non-zero count.
(3) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(4) VALIDATE per section 8, including the over-reach guard.
(5) RECORD observed output in the commit body and, for a guard, in a comment
    on the test.
(6) RE-RUN THE FULL BATTERY before committing, including
    ./scripts/check_deploy_fresh.sh.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done

- [ ] **Issue 105 selection recorded** before any work begins.
- [ ] **105.2 (mandatory under every option)** — the self-check re-anchored to list-form fields, asserting a **non-zero** count of `Observed:` blocks, and requiring a **device artefact** in each rather than only the absence of `grep -`. **Observed failing** against a deliberately-broken block, then restored, with the failure output recorded.
- [ ] **Under A** — E10 re-run on three devices; **evidence from both remaining devices**, not one; screenshots saved and cited.
- [ ] **Under B** — E10 reads `PASS (emulator-verified) · NOT RUN on device`, citing `game_e2e.spec.ts:2707`.
- [ ] **Under every option** — the `index.ts:1488` citation repointed to **`:986`**.
- [ ] Battery at or above the bar: **0 errors** · **≥159** · clean build · **61/61** · deploy gate **exit 0**.
