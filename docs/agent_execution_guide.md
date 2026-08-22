# Agent Execution Guide — Awaiting one selection (Issue 102) — August 21, 2026

**You are an engineering agent with no memory of this project.**

**F1, F2 and F3 shipped and are independently verified** (§4). The app a friend installs now has its debug controls gated, the raven icon, a real launch screen, and an App Store privacy manifest inside the bundle.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (22 warnings, 194 infos) |
| `flutter test` | **159/159** (was 156; +3 from the debug-gating test) |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **61/61** |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions and the rules release |

**F4 did not land.** The work happened, but the record it produced is a **source audit wearing a playthrough's format** — every assertion's "what I observed" is a `grep` into `lib/`. **Issue 102 is re-opened with three options and needs a `Your selection:` line before anything proceeds** (§2).

---

## 1. Standing constraints

- **One item = one commit.**
- **A `grep` into `lib/` is never an answer to "what did you observe."** In a playthrough record, `Observed:` takes **device output only** — text read off a screen, a widget-tree dump, a screenshot. Source citations go in a separate `Reference:` field. **This rule exists because the last attempt used the traceability convention as a substitute for the observation itself** (§2.2).
- **Write validation that fails against the broken state, and observe it fail** — and apply it to the test itself: remove the guard, watch the test go red, restore it, record the failure text **in a comment on the test** as well as the commit body.
- **Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.
- **Record every substitution.** If you test something other than what was specced, say so in the block. **An omitted assertion reads as though it passed.**
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not fix anything inline during a playthrough.** Failures are described, not repaired.
- **Do not touch anything in §4 or §5.**

---

## 2. Issue 102 — the E2E record *(blocked on selection)*

### 2.1 What is actually wrong

`docs/playthrough_findings_marionette.md` records twelve assertions, all PASS. **None carries device evidence.** Four specific, independently checkable problems:

1. **E11 was verified by reasoning.** Its stated method is *"Unit test + compile-time tree-shaking check."* No release build was made, installed or screenshotted — which §2.3 of the previous guide required, because **source inspection cannot distinguish "the guard was written" from "the artefact ships without the buttons."**
2. **E9 cites `functions/index.js:671`. That file does not exist** — the source is `functions/src/index.ts`. A traceability line pointing at a non-existent path was not run.
3. **The assertion list was reassigned without recording it.** `grep -ic "kick"` over the whole document returns **0** — the host-kick assertion is gone. Attribution-by-prefix and "unread cards stay blank" have no block either. Their slots hold subjects never specced: *Audio Cues*, *Play Again & Lobby Reset*, *Game Over Honors*.
4. **The header says Flutter 3.27.x; this machine runs 3.44.6.** Three plausible device UDIDs are named, two matching earlier real sessions — so a session may have happened. **Whatever occurred on those devices was not written down.**

**Worth keeping from the attempt:** `test/debug_buttons_gating_test.dart` is a real test with 9 assertions and is why the suite rose to 159. It covers the *source* guard well. It is not evidence about a release artefact.

### 2.2 The rule this cost us

> **`Observed:` means device output. `Reference:` means source.**
>
> The `grep -F` traceability rule was introduced after a playthrough report **invented** prompt text (Issue 82). It worked — nothing is fabricated this time. But it was then used *as* the observation, which it can never be. A source citation proves a string exists in a file; only a device can prove it rendered. **The tell is that every block's evidence has the same shape and none of it mentions a screen.**

### 2.3 The options

Full text, pros and cons: `docs/ongoing_general_errors.md`, Issue 102. In brief:

- **Option A (recommended)** — re-run all twelve assertions as a real playthrough on three simulators.
- **Option B** — relabel the existing report `PASS (source-level) · NOT RUN on device`, repoint E9, restore the missing assertions as NOT RUN, and let the Apple beta be the real E2E.
- **Option C** — re-run only what source inspection cannot reach: seat recovery, the release build, reveal timing and unmask withholding.

**Under every option**, two corrections are mandatory: **repoint E9's dead citation**, and **restore the missing assertions as NOT RUN** rather than leaving them absent.

### 2.4 If Option A or C is selected — how to run it

**Setup.** Marionette is installed and working (`marionette_flutter` in `pubspec.yaml`, binding at `lib/main.dart:26`, three servers in `.agents/mcp_config.json`). **Verify rather than redo.**

- `.env` must contain `USE_EMULATOR=false` — a bundled asset, so changing it needs a rebuild.
- Uninstall on all three simulators; launch **one device at a time** (concurrent builds corrupt `build/`).
- **Prove the binary is newer than the source before starting:**
  ```bash
  stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
  ```
  If the binary is older, the build did not pick up F1–F3 and the run is worthless.
- `Disable Game Timers` **on** (`lobby_screen.dart:623`), recorded as a deviation. `Family-Friendly Decks Only` **off** (`:643`).
- **Three real clients. Never `DEBUG: ADD 9 BOTS`** — bots are server-seeded and never traverse the client write path or the rules.
- **Prefix each device's answers `AAA` / `BBB` / `CCC`.** Assertions E5 and E6 are only checkable with that ground truth, and E6 was dropped last time for lack of it.
- Gate on `THE GUEST LEDGER` on all three before any assertion.

**The twelve assertions.** Restore the specced list — do not renumber it:

| # | Assertion | What counts as evidence |
|---|---|---|
| **E1** | A 3-round match reaches `THE NIGHT'S HONORS` without stalling | The round indicator advancing twice, read off a device |
| **E2** | Every reveal shows the right truth and forgeries, **cards 2 and 3 included** | Card text from each device. Issue 99 changed this path |
| **E3** | **Unread cards stay blank before their turn** | The absence of answers on a not-yet-revealed card |
| **E4** | The unmask window shows no authorship; results correct once it closes | `REVENGE UNMASKING RESULTS` text. Issue 100 changed *when* this appears |
| **E5** | Scoring is right — truth-finder `ceil((P−1)/(S+1))`, truth-teller `+1` per finder, forger `+1` per fooled voter | `STANDINGS` numbers before and after |
| **E6** | **Attribution is correct** — the named author actually wrote it | Your `AAA`/`BBB`/`CCC` ground truth against the reveal |
| **E7** | **Seat recovery: force-quit a player mid-match and relaunch — same seat, same score** | Both devices. **Never run on a device; Issue 97's seat token is the mechanism** |
| **E8** | **Host kick** removes a lobby player; the removed player sees the notice | Both devices |
| **E9** | A player leaves mid-match from a 4-player game; the match continues | The remaining three |
| **E10** | A 3-player match dropping to 2 ends for everyone at the final score | All devices reach Game Over, scores intact |
| **E11** | **No `DEBUG:` control visible on a RELEASE build** | ⚠️ **Not checkable in the Marionette session — §2.5** |
| **E12** | Icon and launch screen are the real ones | Home screen at 60 px; cold start from a full quit |

**E7 is the one to get right.** Force-quit from the app switcher — not a background — and relaunch. The token lives in `SharedPreferences` as `seat_token_{roomCode}`. **If it fails, capture the room code, the player id and the error code before doing anything else, and file it** — that is a security-critical path and a fix must not be improvised.

**E9 and E10 destroy the match — run them last, E9 before E10.**

### 2.5 ⚠️ E11 still cannot be checked during the Marionette run

```dart
// lib/main.dart:26
if (kDebugMode) {
  MarionetteBinding.ensureInitialized();   // ← Marionette exists ONLY in debug
}
```

`kDebugMode` is `false` in **both** profile and release. So Marionette can only attach to a debug build, and F1's gating only takes effect where `kDebugMode` is false. **There is no build in which Marionette can observe the buttons being hidden.**

> **In the Marionette session the `DEBUG:` buttons WILL be visible, and that is CORRECT.**
> **Do NOT record E11 as FAIL from that session.**
> **Do NOT "fix" F1 by deleting the buttons** — `debugSimulateBotResponses` drives existing emulator tests; deleting them would pass a misread E11 and break the suite.
> **Do NOT switch to a profile build** — `kDebugMode` is false there too, so the binding is not installed and Marionette cannot connect at all.

**E11's procedure — a separate release build, driven by hand:**

```bash
flutter build ios --simulator --release
```

```bash
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app && xcrun simctl launch <UDID> com.whylabs.gaslight
```

Walk the lobby, the truth/forgery screen and the vote screen, and **screenshot each** with `xcrun simctl io <UDID> screenshot`. Record E11 as its own block **stating it was verified on a release build outside the Marionette session, and why** — otherwise the next reader cannot tell rigour from a shortcut. *(Reaching the vote screen needs three players; if you only cover lobby and truth/forgery, say so.)*

### 2.6 How to write the record

`docs/playthrough_findings_marionette.md`, one block per assertion, **all twelve, including passes**:

```markdown
### E5 — Scoring

**Verdict:** PASS | FAIL | NOT RUN
**Devices:** P1 `iPhone 17 Pro` (Alpha, host), P2 …
**What I did:** <the exact tool calls, in order>
**Observed (device output only):** <text read off the screen / widget-tree dump / screenshot path>
**Reference (source, optional):** <file:line — NEVER a substitute for Observed>
**Expected:** <what the assertion required>
```

Header: date, commit SHA, **`flutter --version` output pasted rather than recalled**, the three devices and UDIDs, build mode, `USE_EMULATOR`, and the timers-disabled deviation.

**Do not write into `ongoing_general_errors.md`.** A failure becomes a tracked issue with options — a fix applied during the run destroys the evidence that it was needed.

---

## 3. Do not invent work

Outside Issue 102 there is no queue. Legitimate triggers: a defect the playthrough surfaces, a user-selected issue, `ROOM_TTL_MS` dropping below ~4 hours, or a sibling Phosphor glyph turning out wrong.

**If you find something worth doing, file it — do not do it.** `ongoing_general_errors.md`, with options and a blank `Your selection: _____`.

---

## 4. Already delivered — do NOT rework

**Verified in source and in the built artefacts, August 21, 2026:**

- **F1 / Issue 103.1** — all seven `DEBUG:` sites gated: `lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`, each composing with that site's pre-existing condition. **All seven buttons still exist** — they were gated, not deleted, and `debugSimulateBotResponses` depends on them.
- **F2 / Issue 103.2–3** — the icon is the raven on `#14110E` with a brass outline; the 1024 master is **1024 × 1024, 8-bit/color RGB, no alpha** (the App Store requirement, verified with `file`); launch images are 375×812 / 750×1624 / 1125×2436, no longer 1×1. `flutter_launcher_icons` and `flutter_native_splash` are configured, so regenerate from the master rather than editing slots.
- **F3 / Issue 104** — `ios/Runner/PrivacyInfo.xcprivacy` passes `plutil -lint`, declares the three collected types with `Linked: false` / `Tracking: false` / `AppFunctionality`, and keeps `NSPrivacyAccessedAPITypes` **empty** by design. **It is a member of the Runner target** — `project.pbxproj` carries the `PBXBuildFile`, the `PBXFileReference`, the group entry and the Copy Bundle Resources entry.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 5. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests. Their gating is only observable in a release or profile build (`design_database_and_security.md` §7.1).
- **`PrivacyInfo.xcprivacy` must stay in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty because no code of ours calls a required-reason API. If a plugin lacks its own manifest, **upgrade the plugin — do not write one on its behalf** (§7.2).
- **The 1024 icon must have no alpha and no pre-rounded corners.** Regenerate from the master; never hand-edit a slot.
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — do not simplify to one condition.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** Never add an explicit `allow read: if false`.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **`castVote` rejects only genuine self-votes.** Never loosen it; never let a client bound exceed the server's.
- **The option id is the authority; text is the fallback, consulted only when the id is null.** Never union the two.
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase branches.
- **`handleDisconnect` has exactly three legitimate callers.** A non-host acting on a third player stays rejected.
- **Dialogs render on `groundRaised`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; plus the declined options in `ongoing_general_errors.md` §4.

---

## 6. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens, callables, **debug isolation (§7.1)**, **privacy manifest (§7.2)**, deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, **release identity (icon/splash)**, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 7. Validation standard

**A `grep` is not an observation.** `Observed:` takes device output; `Reference:` takes source. This is the rule Issue 102 cost us.

**Prove the artefact ships, not that it exists.** F3's risk was a manifest in the repo but not in the target; F1's is a guard in the source but a button in the binary. **Check the built output.**

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.**

**Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.

**Record every substitution.** An omitted assertion reads as though it passed.

**A test harness that cannot express the bug will pass against it.** `kDebugMode` is `true` under `flutter test`, so F1 cannot be proved by a widget test — the release build is the evidence.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Assert the negative as well as the positive.** **Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** It can check every string and still miss whether the game is fun.

---

## 8. Feedback loop — what past specs got wrong

- **A convention introduced to stop one failure can become the next one.** `grep -F` traceability was added after a report invented prompt text. It stopped invention — and was then used *as* the observation, which it can never be. **When you add an evidence rule, say what it does not prove.**
- **A fix can be correct while its design doc still describes the vulnerability.** Grep the design docs for the code you just deleted.
- **A documented invariant with no test behind it is a wish.**
- **When a design doc calls something a secret, grep for where it is published.**
- **When you redefine what a field holds, enumerate its readers.** `votes` has done it three times.
- **A guard's test must be run with the guard removed** — the skip is invisible in a green run.
- **A spec can be over-cautious as well as wrong**, and a warning that sends someone chasing a non-problem costs a cycle too.
- **Working logs rot by appending.** One banner in §1, one Resolved heading, one line per resolved issue.
- **One item = one commit.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output. For anything shipped in a bundle, the check is on the
    BUILT ARTEFACT, not the source tree.
(3) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(4) VALIDATE per section 7, including the over-reach guard, and remove the
    guard to prove the test can still fail.
(5) RECORD the observed failure text in a comment on the test AND in the
    commit body.
(6) RE-RUN THE FULL BATTERY before committing, including
    ./scripts/check_deploy_fresh.sh.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output
    included. Move the issue into the SINGLE existing Resolved heading and
    update the design doc that described the OLD behaviour.
```

---

## Definition of Done

- [ ] **Issue 102 selection recorded** before any playthrough work begins.
- [ ] **Under every option** — E9's `functions/index.js` citation repointed to `functions/src/index.ts`, and the missing assertions (host kick, attribution-by-prefix, unread-cards-blank) restored as NOT RUN rather than left absent.
- [ ] **Under A or C** — every re-run block has `Observed:` containing **device output**, not a `grep`; `flutter --version` pasted into the header, not recalled; the binary-newer-than-source check recorded.
- [ ] **E7 (seat recovery) explicitly recorded** — force-quit, not background. It has never run on a device.
- [ ] **E11 recorded as verified on a release build outside the Marionette session, with that stated in its block** — and **not** reported FAIL from the debug run (§2.5).
- [ ] **Under B** — every verdict relabelled `PASS (source-level) · NOT RUN on device`, with the header saying so once, plainly.
- [ ] Battery at or above the bar: **0 errors** · **≥159** · clean build · **61/61** · deploy gate **exit 0**.
- [ ] **Nothing fixed inline during the run.**
