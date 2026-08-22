# Agent Execution Guide — Active Build: G0 → G1 (re-run the pre-demo E2E) — August 21, 2026

**You are an engineering agent with no memory of this project.**

**F1, F2 and F3 shipped and are independently verified** (§6). The app a friend installs has its debug controls gated, the raven icon, a real launch screen, and an App Store privacy manifest inside the bundle.

**F4 did not.** Twelve assertions were marked PASS and **none carried device evidence** — every block answered *"what I observed"* with a `grep` into `lib/`. Issue 102 was re-opened and the user selected **Option A: re-run it properly.**

| # | Item | Issue | Blocked? |
|---|---|---|---|
| **G0** | Two mandatory corrections to the existing report | 102 | **No. Do first** — it makes the record honest even if G1 is interrupted. |
| **G1** | Re-run all twelve assertions as a real playthrough | 102 | No. After G0. |

**Nothing here needs a deploy.** The backend is current and verified. This is evidence work.

## Verified baseline — the regression bar

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (22 warnings, 194 infos) |
| `flutter test` | **159/159** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **61/61** |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions and the rules release |

---

## 1. Standing constraints

- **A `grep` into `lib/` is NEVER an answer to "what did you observe."** `Observed:` takes **device output only**. Source citations go in a separate `Reference:` field. **This is the rule the last attempt broke, and §3.2 makes it mechanically checkable.**
- **One item = one commit.**
- **Record every substitution.** If you test something other than what was specced — a different screen, a different device count, a different order — say so **in the block**. **An omitted assertion reads as though it passed.**
- **Do not renumber the assertion list.** E1–E12 are fixed (§4). The last attempt reassigned them and three specced assertions vanished without anyone noticing.
- **Do not fix anything inline during G1.** Failures are described, not repaired, and filed with options.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not touch anything in §6 or §7.**

---

## 2. G0 — The two mandatory corrections

**Do these first.** They are five minutes of editing, and they make `docs/playthrough_findings_marionette.md` honest immediately — so that if G1 is interrupted, the record is not left overstating.

### 2.1 Repoint E9's dead citation

E9's traceability line reads:

```
grep -Fn "currentPhase = \"gameOver\"" functions/index.js -> line 671
```

**`functions/index.js` does not exist.** The source is `functions/src/index.ts`; the compiled output lives in `functions/lib/`. Re-grep the real file, get the real line, and correct it — or, if G1 re-runs E9 anyway, delete the line rather than leaving a citation nobody ran.

### 2.2 Restore the three missing assertions

The specced list had twelve. Three were dropped and their slots filled with subjects that were never specced:

| Missing assertion | What replaced it |
|---|---|
| **Host kick** (`grep -ic "kick"` over the doc returns **0**) | *Play Again & Lobby Reset* |
| **Attribution by `AAA`/`BBB`/`CCC` prefix** | *Game Over Honors & Accolades* |
| **Unread cards stay blank before their turn** | *Audio Cues and UI Controls* |

**Restore all three as explicit `NOT RUN` blocks** with a one-line reason, so the gap is visible. **Do not delete the replacement blocks** — *Play Again*, *Honors* and *Audio Cues* are real coverage somebody produced; keep them, renumbered as **E13, E14, E15** and marked with their evidence standard. **What must not survive is a twelve-item list that silently omits three of the twelve.**

### Validation

- `grep -c "functions/index.js" docs/playthrough_findings_marionette.md` → **0**.
- The document contains blocks **E1 through E12** with the §4 subjects, plus any extras numbered E13+.
- Every restored block reads `NOT RUN` with a reason, not PASS.

Commit: `docs(playthrough): repoint a dead citation and restore the dropped assertions`.

---

## 3. G1 — Re-run the twelve assertions

### 3.1 Setup

Marionette is installed and working — `marionette_flutter` in `pubspec.yaml`, the binding at `lib/main.dart:26`, three servers in `.agents/mcp_config.json`. **Verify rather than redo.**

1. **`.env` must contain `USE_EMULATOR=false`.** It is a bundled asset — changing it after the build has no effect.
2. **Uninstall on every booted simulator**, so no stale room is restored from `SharedPreferences`:
   ```bash
   for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl uninstall "$U" com.whylabs.gaslight 2>/dev/null; done
   ```
3. **Build debug, then prove the binary is newer than the source.** If it is older, the build did not pick up F1–F3 and the whole run is worthless:
   ```bash
   flutter build ios --simulator --debug
   ```
   ```bash
   stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
   ```
   **Paste both lines into the report header.**
4. **Launch one device at a time** — concurrent builds against the same `build/` directory corrupt each other. Wait for P1 to come up before starting P2.
5. **Gate on `THE GUEST LEDGER`** via `take_screenshots` on all three before any assertion. **Three devices, not two** — the 3-player minimum is enforced server-side.
6. **House rules:** `Disable Game Timers` **on** (`lobby_screen.dart:623`) — record as a deviation. `Family-Friendly Decks Only` **off** (`:643`).
7. **Three real clients. Never `DEBUG: ADD 9 BOTS`** — bots are server-seeded and never traverse the client write path or the security rules, which is exactly the surface this run exists to exercise.
8. **Prefix every answer per device — `AAA` / `BBB` / `CCC`.** E5 and E6 are only checkable with that ground truth, and E6 was dropped last time for lack of it.

### 3.2 The evidence contract — what counts, concretely

**This is the section the last attempt needed and did not have.**

| Field | Takes | Never takes |
|---|---|---|
| `Observed:` | Output from a Marionette call or `xcrun simctl` — a widget-tree dump, text read off a screen, a saved screenshot path, a log line | A `grep`. A source line number. A test name. An inference from code. |
| `Reference:` | `file:line` in `lib/` or `functions/` — optional context for *why* the expected value is what it is | — |

**The three calls that produce acceptable `Observed:` evidence:**

- **`get_interactive_elements`** — returns the live widget tree with text and bounds. **This is the primary evidence for any assertion about what is on screen.** Paste the relevant entries verbatim.
- **`take_screenshots`** — returns base64 PNGs. **Decode and save them** under `docs/playthrough_evidence/` with the assertion id in the filename (`e5_p1_standings.png`), and cite the path. A screenshot you did not look at is not evidence.
- **`get_logs`** — for anything that surfaces as a client log rather than UI.

**The self-check, and it is not optional.** Before committing the report, run:

```bash
awk '/^\*\*Observed/,/^\*\*(Reference|Expected)/' docs/playthrough_findings_marionette.md | grep -c "grep -"
```

**That must return `0`.** If it does not, an `Observed:` field contains a source citation and the block is not evidence. **Paste the command and its output into the report header** — this is the check that would have caught the last attempt, and it is cheap enough that there is no excuse for skipping it.

### 3.3 The block format

```markdown
### E5 — Scoring

**Verdict:** PASS | FAIL | NOT RUN
**Devices:** P1 `iPhone 17 Pro` (Alpha, host), P2 `iPhone Air` (Bravo), P3 `iPhone 17` (Charlie)
**What I did:** <the exact tool calls, in order>
**Observed:** <widget-tree entries / screen text / screenshot path — device output ONLY>
**Reference:** <optional file:line explaining the expected value>
**Expected:** <what the assertion required>
**Evidence:** docs/playthrough_evidence/e5_p1_standings.png
```

**Header must carry:** the date, the commit SHA, **`flutter --version` pasted rather than recalled** *(the last attempt claimed 3.27.x on a 3.44.6 machine)*, the three device names and UDIDs, build mode, `USE_EMULATOR`, the binary-vs-source timestamps from §3.1 step 3, the timers-disabled deviation, and the §3.2 self-check output.

### 3.4 ⚠️ E11 still cannot be checked during the Marionette run

```dart
// lib/main.dart:26
if (kDebugMode) {
  MarionetteBinding.ensureInitialized();   // ← Marionette exists ONLY in debug
}
```

`kDebugMode` is `false` in **both** profile and release. Marionette attaches only in debug; F1's gating only takes effect where `kDebugMode` is false. **There is no build in which Marionette can observe the buttons being hidden.**

> **In the Marionette session the `DEBUG:` buttons WILL be visible, and that is CORRECT.**
> **Do NOT record E11 as FAIL from that session.**
> **Do NOT "fix" F1 by deleting the buttons** — `debugSimulateBotResponses` drives existing emulator tests; deleting them would pass a misread E11 *and* break the suite.
> **Do NOT switch to a profile build** — `kDebugMode` is false there too, so the binding is not installed and Marionette cannot connect at all.

**E11's procedure — a separate release build, driven by hand:**

```bash
flutter build ios --simulator --release
```

```bash
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app && xcrun simctl launch <UDID> com.whylabs.gaslight
```

Walk the lobby, the truth/forgery screen and the vote screen; **screenshot each** with `xcrun simctl io <UDID> screenshot` and save under `docs/playthrough_evidence/`. Record E11 as its own block **stating it was verified on a release build outside the Marionette session, and why**. Reaching the vote screen needs three players — if you only cover lobby and truth/forgery, **say so in the block**.

### 3.5 If something cannot be reached

**Record it as `NOT RUN` with the reason, mark every downstream assertion `NOT RUN`, and continue with whatever remains reachable.** A blocked run reporting six honest NOT RUNs is worth more than one reporting six passes it did not observe — which is precisely how this item came back.

**If an assertion fails, do not fix it.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`, and carry on. A fix applied during the run destroys the evidence that it was needed.

---

## 4. The twelve assertions — do not renumber

**E9 and E10 destroy the match. Run them last, E9 before E10.**

| # | Assertion | Required `Observed:` evidence |
|---|---|---|
| **E1** | A 3-round match reaches `THE NIGHT'S HONORS` without stalling | The round indicator at each round, then the Game Over title, read from the widget tree on any device |
| **E2** | Every reveal shows the right truth and forgeries — **cards 2 and 3 included** | The revealed card text from each device, per card. **Issue 99 changed this path; card 1 passing proves nothing about cards 2 and 3** |
| **E3** | **Unread cards stay blank before their turn** | The absence of answer text on a not-yet-revealed card — quote what *is* there |
| **E4** | The unmask window shows no authorship; results correct once it closes | `REVENGE UNMASKING RESULTS` text, plus what was visible *during* the window. **Issue 100 changed when this appears** |
| **E5** | Scoring is right — truth-finder `ceil((P−1)/(S+1))`, truth-teller `+1` per finder, forger `+1` per fooled voter | `STANDINGS` numbers **before and after**, as numbers, with the arithmetic written out |
| **E6** | **Attribution is correct** — the named author actually wrote it | The reveal's author labels against your `AAA`/`BBB`/`CCC` ground truth |
| **E7** | **Seat recovery: force-quit a player mid-match and relaunch — same seat, same score** | The rejoining device's screen and score. **Never run on a device** |
| **E8** | **Host kick** removes a lobby player; the removed player sees the notice | The roster on the host device **and** the notice on the removed device |
| **E9** | A player leaves mid-match from a 4-player game; the match continues | The remaining three devices still in play |
| **E10** | A 3-player match dropping to 2 ends for everyone at the final score | All devices at Game Over with scores intact |
| **E11** | **No `DEBUG:` control on a RELEASE build** | ⚠️ Screenshots from a release build, **outside** the Marionette session — §3.4 |
| **E12** | Icon and launch screen are the real ones | Home-screen screenshot at small size; a cold-start screenshot from a **full quit** |

### The two that matter most

**E7 — seat recovery.** Force-quit from the app switcher, **not** a background. The token lives in `SharedPreferences` as `seat_token_{roomCode}`; a relaunch should present it and land back in the same seat with the same score. **This path has never run on a device and it is security-critical** (Issue 97). **If it fails, capture the room code, the player id and the error code before doing anything else, then file it** — a fix here must not be improvised.

**E2 and E4** — both sit on paths the security wave rewrote. `votes` now stores an opaque option UUID resolved server-side at the reveal transition, the reveal merges only the current card, and authorship is withheld until `unmaskDeadline` closes. **Nothing has played these on a device.** Card 1 rendering correctly says nothing about cards 2 and 3, because they take a different code path.

---

## 5. Do not invent work

Outside G0 and G1 there is no queue. Legitimate triggers: a defect this run surfaces, a user-selected issue, `ROOM_TTL_MS` dropping below ~4 hours, or a sibling Phosphor glyph turning out wrong.

**If you find something worth doing, file it — do not do it.**

---

## 6. Already delivered — do NOT rework

**Verified in source and in the built artefacts, August 21, 2026:**

- **F1 / Issue 103.1** — all seven `DEBUG:` sites gated: `lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`, each composing with that site's pre-existing condition. **All seven buttons still exist** — gated, not deleted; `debugSimulateBotResponses` depends on them.
- **F2 / Issue 103.2–3** — the icon is the raven on `#14110E` with a brass outline; the 1024 master is **1024 × 1024, 8-bit/color RGB, no alpha**; launch images are 375×812 / 750×1624 / 1125×2436. `flutter_launcher_icons` and `flutter_native_splash` are configured — regenerate from the master, never edit a slot.
- **F3 / Issue 104** — `PrivacyInfo.xcprivacy` passes `plutil -lint`, declares three collected types with `Linked: false` / `Tracking: false` / `AppFunctionality`, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.
- **`test/debug_buttons_gating_test.dart`** — 9 assertions, and why the suite is at 159. **Keep it.** It covers the source guard; it is not evidence about a release artefact.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 7. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests. Their gating is only observable in a release or profile build.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin — do not write one on its behalf**.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — do not simplify to one condition.
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
| Rules, seat tokens, callables, debug isolation (§7.1), privacy manifest (§7.2), deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 9. Validation standard

**A `grep` is not an observation.** `Observed:` takes device output; `Reference:` takes source. **§3.2 makes this mechanically checkable — run the check.**

**Prove the artefact ships, not that it exists.** F1's guard is in the source; the button is in the binary. Check the built output.

**Record every substitution.** An omitted assertion reads as though it passed.

**Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.

**A test harness that cannot express the bug will pass against it.** `kDebugMode` is `true` under `flutter test`, so F1 cannot be proved by a widget test.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Assert the negative as well as the positive.** **Measure; do not estimate.** **Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** It can check every string and still miss whether the game is fun. Say so in "what the harness could not see."

---

## 10. Feedback loop — what past specs got wrong

- **A convention introduced to stop one failure can become the next one.** `grep -F` traceability was added after a report *invented* prompt text. It stopped invention — then got used *as* the observation, which it can never be. **When you add an evidence rule, say what it does not prove**, and make the rule checkable rather than aspirational.
- **A fix can be correct while its design doc still describes the vulnerability.** Grep the design docs for the code you just deleted.
- **A documented invariant with no test behind it is a wish.**
- **When a design doc calls something a secret, grep for where it is published.**
- **When you redefine what a field holds, enumerate its readers.** `votes` has done it three times.
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
    the exact output. For anything shipped in a bundle, the check is on the
    BUILT ARTEFACT, not the source tree.
(3) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(4) VALIDATE per section 9. For a playthrough, run the section 3.2 self-check
    and paste its output into the report.
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

- [ ] **G0** — `grep -c "functions/index.js"` on the report returns **0**; blocks E1–E12 exist with the §4 subjects; the three restored assertions read `NOT RUN` with a reason; the extra blocks kept and renumbered E13+.
- [ ] **G1 setup** — binary-vs-source timestamps recorded in the header; `flutter --version` **pasted**, not recalled; all three devices gated on `THE GUEST LEDGER`.
- [ ] **G1 evidence** — every `Observed:` field contains device output. **The §3.2 self-check returns 0 and its output is pasted into the header.**
- [ ] **All twelve assertions attempted**, each PASS / FAIL / NOT RUN with a reason, none renumbered, none omitted.
- [ ] **E7 (seat recovery) explicitly recorded** — force-quit, not background. Never run on a device before.
- [ ] **E2 covers cards 2 and 3**, not just card 1 — they take a different code path.
- [ ] **E11 recorded from a release build outside the Marionette session**, with that stated in its block, and **not** reported FAIL from the debug run (§3.4).
- [ ] **Screenshots saved** under `docs/playthrough_evidence/` and cited by path; commit images for FAIL and NOT RUN blocks.
- [ ] **Nothing fixed inline.** Failures filed with options.
- [ ] Battery at or above the bar: **0 errors** · **≥159** · clean build · **61/61** · deploy gate **exit 0**.
