# Agent Execution Guide — Active Build: Wave I — Web E2E Playthrough — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–105 are delivered** (§8) and the iOS playthrough is complete and device-verified. The Apple Developer licence has not arrived yet, so the demo is going out to friends as a **Flutter web build** first. Wave I proves the web build end to end, on three screen sizes, with the same evidence discipline the iOS playthrough was held to.

| # | Item | Touches | Deploy |
|---|---|---|---|
| **I1** | Teach the evidence gate about web blocks | `scripts/` | — |
| **I2** | Playwright harness + full 3-player web playthrough | harness, evidence | — |
| **I3** | Responsive sweep at mobile / tablet / desktop | evidence | — |

**I1 before I2, and this is the same genuine dependency H1 had before H2:** the gate exists to catch blocks that claim PASS without device evidence. If I2 writes its blocks first, the thing that validates them does not exist yet. **Do not reorder.**

**You must not run `firebase deploy`.** The whole playthrough runs against a local release build. Publishing a public URL is the user's call, not yours.

## Verified baseline — the regression bar

Run all six before you touch anything, so you know which failures are yours:

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (22 warnings, 194 infos) | `flutter analyze lib test` |
| Client tests | **159/159** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **61/61** | `npm --prefix functions test` |
| Deploy freshness | **exit 0** | `./scripts/check_deploy_fresh.sh` |
| iOS playthrough evidence | **exit 0** — 15 blocks: 14 PASS, 1 NOT RUN, 0 FAIL | `./scripts/check_playthrough_evidence.sh` |

---

## 0. What is already known about the web build — do NOT rediscover this

Verified on **August 23, 2026** against a local `flutter build web --release`, backed by live Firebase (`gaslight-46368`, `USE_EMULATOR=false`). Treat this as given; your job is to go past it.

**Confirmed working.** `flutter build web --release` exits **0** with zero errors (`main.dart.js` 2.9 MB). The app renders correctly — tavern art, raven, Phosphor tokens, all four font families. `firebase_core`, `firebase_auth`, `cloud_firestore` and `cloud_functions` all initialise with **zero console errors**. Anonymous auth works. **`createRoom` succeeds from the browser** — room `GJCB` was created, the roster streamed live, and the button's busy state fired. CORS on v2 callables is a non-issue.

**Three traps, each of which will cost you a cycle if you meet it cold:**

**0.1 — There is no widget tree. CanvasKit renders into a `<canvas>`.** `read_page` returns an empty accessibility tree (`generic [ref_1]`, nothing else). Every technique the iOS playthrough leaned on — `get_interactive_elements`, `Type: Text, Text: "…"` — **does not exist here**. This is the single biggest difference from Marionette and it is why I2 specifies a real driver rather than hand-driving.

**0.2 — Two tabs in one browser profile are ONE player.** A second tab on the same origin printed `Rejoined active game session!` and the roster stayed at 1. `SharedPreferences` on web is `localStorage`, and the anonymous auth user persists in IndexedDB (`firebaseLocalStorageDb`) — both are per-origin, so tabs share an identity. **A three-player web match cannot be driven from three tabs of one browser.** Solving this is W1 and everything else depends on it.

**0.3 — Do not clear IndexedDB while another tab of the app is open.** I did, and it wedged the app into a permanent black screen: `deleteDatabase` blocks while another connection is open, so every later page load queued behind a delete that could never finish. No error, no network request, survived a forced reload. Closing the holding tab fixed it instantly. **This was self-inflicted, not a product defect — do not file it as one.** If you see a silent black screen with no console error and no request to `identitytoolkit`, this is your first suspect.

**Two things I reasoned about but did NOT observe.** Both are yours to settle with evidence, not argument:
- The **Case File share** at `lib/screens/game_over_screen.dart:112` writes a temp PNG through `dart:io`. It compiles because dart2js ships `dart:io` stubs, but `File()` should throw at runtime on web. The existing `try/catch` should degrade it to a "Failed to share" snackbar rather than a crash. **I never reached the game-over screen.** W14 settles it.
- Whether the app is usable at all at tablet and desktop widths. I only ever saw it at 1280×720. I3 settles it.

---

## 1. Standing constraints

- **One item = one commit.**
- **A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.
- **A `grep` is not an observation.** Neither is prose describing source. `Observed:` takes artefacts (§6).
- **Record every substitution.** An omitted assertion reads as though it passed.
- **Do not fix product defects inline during I2 or I3.** Failures are described and filed with options and a blank `Your selection: _____`. Harness bugs you may fix; game bugs you may not.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.** That line is the user's.
- **Never run `firebase deploy`.**
- **Do not touch anything in §8 or §9.**

---

## 2. What legitimately starts a new build

Refactors, renames and "while I was in there" cleanups are not work; they are risk against a green baseline. Exactly four things start a build:

1. **A human plays the game and something is wrong.** Five of the last six functional waves came from the user playing on simulators; **none came from a gate.**
2. **The user asks for something**, or selects an option on an open issue.
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

Wave I exists under (2). When it is done and the queue is empty again, **report the state and stop.**

---

## 3. I1 — Teach the evidence gate about web blocks

`scripts/check_playthrough_evidence.sh` already accepts a report path as `$1` (defaulting to the iOS report), so it can validate a second report **without a copy**. Two things stop it working on a web report today, and you are changing exactly those two.

**3.1 — The heading regex only matches `E`.** It is `^###\s+(E\d+.*?)$`. A report whose blocks are `### W1 …` parses **zero blocks and exits 2**. Widen it to accept both prefixes, e.g. `^###\s+([EW]\d+.*?)$`, and widen the id capture (`^([EW]\d+)`) to match.

**3.2 — R3's artefact classes are iOS-shaped, and for `W` blocks that is exactly right.** R3 currently accepts three artefact classes: a PNG under `docs/playthrough_evidence/`, a widget entry (`Type:\s*\w+` or `Text:\s*"`), or a Flutter log line (`flutter:\s*` etc.). **On web there is no widget tree and no `flutter:` log**, so accepting those classes for a `W` block would mean accepting reasoning dressed as observation — the precise defect this script was built to stop.

**So make `W` blocks strictly stricter than `E` blocks: a `W` block with a PASS or FAIL verdict must contain a PNG path under `docs/playthrough_evidence/`. The widget and log classes must NOT satisfy a `W` block.** A screenshot is the only thing a canvas-rendered app can prove itself with, and requiring one per block is the whole point.

**Falsification — mandatory, and the run must be recorded in a comment at the top of the script and in the commit body:**

1. Write a throwaway file with one `### W1` block, verdict PASS, whose `Observed:` contains `Type: Text, Text: "GAME OVER"` **and no PNG path.** Run the gate against it. **It must exit 1 naming W1 under R3.** If it exits 0, your artefact classes are still being applied to `W` blocks and the change does nothing.
2. Add a PNG path under `docs/playthrough_evidence/` to that same block. **It must now exit 0.**
3. Run it against a file with an `### E1` PASS block whose only artefact is `Type: Text, Text: "x"`. **It must still exit 0** — you must not have tightened the iOS rules by accident.
4. **Over-reach guard:** a `### W2` block with verdict `NOT RUN` and a non-empty `**Reason:**` must **not** be flagged.
5. **Regression:** `./scripts/check_playthrough_evidence.sh` with no argument must still exit **0** on the iOS report, printing 15 blocks / 14 PASS / 1 NOT RUN.

**Do not weaken any existing rule to make a run pass.** If R1–R4 reject something you believe is legitimate evidence, that is a finding to file, not a rule to soften.

---

## 4. I2 — The harness, and the playthrough

### 4.1 Why Playwright and not hand-driving

Marionette gave the iOS run a live widget tree, deterministic taps and screenshots on disk. The browser MCP gives you **none of those** for a canvas app (§0.1), and it cannot write a PNG to a path, which I1 now requires of every `W` block. Use **Playwright with Chromium**, which supplies all three:

- **`browser.newContext()` gives isolated storage per context** — separate `localStorage` and IndexedDB, therefore a **separate anonymous user per context**. This is the clean answer to §0.2: three contexts, three players, one browser process.
- **`page.screenshot({ path: 'docs/playthrough_evidence/w4_lobby.png' })`** writes the real file R3 demands.
- **`page.setViewportSize()`** gives exact, repeatable dimensions for I3.
- It is a **reusable regression asset**, which is this project's standing preference: when a written step fails twice, replace it with a tool (§12).

Setup: `npm i -D playwright && npx playwright install chromium`. Keep the harness under `test/web_e2e/` and commit it. It is test tooling, not app code — **do not add Playwright to the Flutter app's dependencies.**

Serve the build locally and drive that; do not test a deployed URL:

```bash
flutter build web --release
python3 -m http.server 8777 --directory build/web
```

**Prove the artefact is newer than the source before you trust a single result** — the same discipline `check_deploy_fresh.sh` enforces for functions, and compare epoch seconds, never strings:

```bash
stat -f %m build/web/main.dart.js; git log -1 --format=%ct -- lib
```

Paste both numbers into the report header. A stale `build/web` is the easiest way to spend a day testing code that is not the code you changed.

### 4.2 Make the app readable before you drive it

Driving a canvas by hard-coded pixel coordinates is brittle and produces weak evidence. **Flutter web can expose a real DOM semantics tree.** It ships a hidden placeholder element (`flt-semantics-placeholder`, `aria-label="Enable accessibility"`); activating it turns on the semantics tree, after which the app's text and controls become queryable DOM with aria labels — the closest thing web has to Marionette's widget tree.

**Verify this rather than assuming it.** In each context, attempt to enable semantics, then assert the tree is real: query for the text `THE GUEST LEDGER` in the DOM and require a hit. Record the exact snippet you used in the report header.

- **If it works:** drive by accessible name/role, and your `Observed:` fields can quote DOM text as well as screenshots.
- **If it does not work:** fall back to coordinate clicks derived from a screenshot, and **say so plainly in the report header as a deliberate deviation.** Do not quietly switch techniques — an undeclared substitution reads as though the stronger method passed.

### 4.3 The match

Three contexts: **P1 host `Alice`, P2 `Bob`, P3 `Charlie`.** Live Firebase, `USE_EMULATOR=false`, a **release** build. `Disable Game Timers` **on**, recorded as a deviation, so phases do not auto-advance under you. **Three real clients — never `DEBUG: ADD 9 BOTS`;** bots are server-seeded documents and exercise none of the client path. Run a **full 3-round match** to Game Over.

Write findings to a **new file, `docs/playthrough_findings_web.md`**, mirroring the block format of `docs/playthrough_findings_marionette.md` exactly — `- **Verdict:**`, `- **What I did:**`, `- **Observed:**`, `- **Reference:**`, `- **Expected:**` — with `### W<n> — <title>` headings. Screenshots go in `docs/playthrough_evidence/` named `w<n>_<what>.png`.

| # | Assertion | What makes it PASS |
|---|---|---|
| **W1** | Three isolated contexts yield **three distinct players** | Roster reads `3 SUSPECTS JOINED` with three different names. **Falsify first:** two tabs in ONE context must still show `Rejoined active game session!` and a roster of 1 (§0.2). If you cannot show the failure, you have not proven the isolation. |
| **W2** | Cold boot of the release build | Lobby renders; **zero console errors**; paste the Firebase init lines |
| **W3** | Semantics tree enabled (or fallback declared) | DOM query for `THE GUEST LEDGER` returns a hit, snippet recorded — or an explicit declared deviation |
| **W4** | Create room + two joins, roster streams live | All three contexts show the same room code and all three names |
| **W5** | Readiness gate | Host's start control is **blocked** until all non-hosts are ready; **the host is exempt by design — do not file that as a bug** |
| **W6** | Truth phase | Each player submits; `Players ready: X / Y` advances |
| **W7** | Forgery phase | Forgeries accepted; a near-duplicate of the truth on the **same card** is rejected |
| **W8** | Vote — own-answer lockout | A player's own option is greyed **and untappable**. **Confirm the bound is not too wide:** an option by someone else whose text merely matches something you wrote on an *earlier* card must remain votable (`design_scoring_and_ui.md` §3.2) |
| **W9** | Reveal — five beats and the unmask window | Truth flips before forgery authors; **while `unmaskDeadline` is live, forgery authorship is not visible**; authors flip only after it lapses |
| **W10** | Scoring and the running leaderboard | Points match `ScoringLogic`; no `Unknown` labels anywhere |
| **W11** | Full match to Game Over + honors | Mastermind / Trickster / Most Gullible all populated with real names |
| **W12** | **Browser refresh mid-match restores the session** | Hard-reload P2 during an active phase; it must return to the same phase with seat and score intact. This is the web analogue of E7 seat recovery and it runs through `localStorage`, so it is genuinely different code from iOS |
| **W13** | Same-origin second tab = same player | Documented as observed behaviour with a screenshot, so the constraint is on the record for whoever writes the invite |
| **W14** | **Case File share on web** | Reach Game Over, press share, and record what actually happens. Expected: a "Failed to share" snackbar, **not** a crash or a frozen screen. If it crashes or wedges, that is a **finding — file it with options, do not fix it inline** |
| **W15** | Console hygiene in a release web build | Record verbatim what the console prints. `DEBUG HEARTBEAT: started timer for room: …, player: …` was observed leaking the room code and a player UUID in **release**, because `debugPrint` is not stripped the way `kDebugMode` blocks are. Quantify it: how many lines, and does anything worse than room/player ids appear? |
| **W16** | Below-3 auto-end on web | P3 uses the in-game **`Leave game`** control (not a tab close). **Both** remaining contexts must land on Game Over with scores intact. Cite `functions/src/index.ts:986` |

**On W16, one warning that has already burned a previous agent:** test the **in-game leave control**, not `RETURN TO LOBBY`, and not a closed tab. They are different code paths and only one of them is the assertion.

---

## 5. I3 — The responsive sweep

The user asked for this explicitly, and it is the part of Wave I most likely to find something, because **the app has only ever been seen at phone aspect ratios and at 1280×720.** Friends will open the link on whatever they have.

Run at three sizes. `resize_window` presets are the reference dimensions; in Playwright use `page.setViewportSize()` to the same numbers:

| Block | Size | Notes |
|---|---|---|
| **W17** | **375 × 812** — mobile | Widths under 768 also switch the UA to Android Chrome, enable touch points and translate mouse to touch, so **hover states stop existing**. This is the most important of the three: it is how most friends will actually open the link |
| **W18** | **768 × 1024** — tablet | |
| **W19** | **1280 × 800** — desktop | Most likely to expose stretched or stranded layout, since the design targets phones |

**Reload the page after every resize** so any load-time layout or device gate re-runs. A resize without a reload tests a layout that no real user ever loads into.

**At each size, capture all five screens** — lobby, craft, vote, reveal, game over — as `w17_lobby.png`, `w17_craft.png`, and so on. Fifteen screenshots total, and they are the evidence for these three blocks.

**What counts as a defect here, stated concretely** so this does not become a matter of taste:

- **Any control that is clipped, overlapped, or cannot be tapped.** This is the severe one — an unreachable `READY` or `SUBMIT` button makes the game unplayable at that size.
- **Text truncated to the point of losing meaning** — a prompt, a forgery option, or a player name cut off mid-word.
- **Horizontal scrolling on the page body**, or content running off-canvas.
- **The vote grid collapsing** at 375 px so options overlap or become ambiguous.
- **Dialogs rendering off-screen or unreadable.** They draw on `groundRaised` (`design_ui_direction.md` §6).

**Note that a release build hides its own overflow.** Flutter's yellow-and-black overflow stripes and the `RenderFlex overflowed` console error appear in **debug** builds only; in release the content simply clips silently. So for these three blocks, **the screenshots are the evidence** — read them, do not assume a clean console means a clean layout. If you want the diagnostics, take a second pass with a debug build and cite it under `Reference:`, never under `Observed:` for the release claim.

**File layout problems; do not fix them.** A layout fix is a design decision and belongs to the user.

---

## 6. Web evidence contract

The iOS contract (§7) still governs `E` blocks. For `W` blocks:

| Field | Takes | Never takes |
|---|---|---|
| `Observed:` | A **screenshot path** under `docs/playthrough_evidence/` (**required** — I1 enforces it), a verbatim browser console line, a network request line, a `javascript_tool`/DOM return value, quoted semantics-tree text | A `grep`. A source line. A test name. **Prose describing what the code does.** A `Type:`/`Text:` widget entry — there is no widget tree on web, so anything shaped like one is fabricated |
| `Reference:` | `file:line` — optional context for the expected value | — |

**Name the field exactly `Observed:`.** A renamed variant is what let a bad block through a human review once already.

**State screen coverage honestly.** If you verified something on the lobby but not on the vote screen, say which. A block that quietly implies full coverage is the defect this gate exists to catch — it has now been caught three times in three different disguises (§12).

---

## 7. Playthrough procedure — the standing setup

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

## 8. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 22, 2026:**

- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match; with Issue 105's re-runs the report now stands at **14 PASS, 1 NOT RUN (E9, honestly labelled), 0 FAIL**, every cited screenshot present. **E7 seat recovery device-verified** (`xcrun simctl terminate` mid-match → relaunch → straight back to `/reveal`, seat and score intact). **E8 host kick device-verified on both sides.** **No product defect found.**
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R4 mechanically; **E10** re-run in room `YJUG` with the in-game `Leave game` control and evidence from **both** remaining devices; **E11** re-run on a **release** build outside Marionette (its screen coverage stated honestly — the lobby was observed, the rest rests on `kDebugMode` being one compile-time const); **E13** fixed beyond spec, having been found by the script and missed by two human passes.
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**The battery is six gates (seven once I1 lands):** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 9. Invariants & intentional decisions — do NOT change

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

## 10. Where the contracts live

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

## 11. Validation standard

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

## 12. Feedback loop — what past specs got wrong

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
(6) RE-RUN THE FULL BATTERY before committing — all six, and after I1
    the web report must pass the gate too.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done

**I1 — the gate**
- [ ] `check_playthrough_evidence.sh` parses `### W<n>` blocks; a report of only `W` blocks no longer exits 2.
- [ ] **A `W` block claiming PASS/FAIL requires a PNG under `docs/playthrough_evidence/`.** Widget and `flutter:` log classes do **not** satisfy a `W` block.
- [ ] **Falsification observed and recorded** in a comment at the top of the script and in the commit body: a `W` PASS block carrying only `Type: Text, Text: "…"` and no PNG **exits 1 naming W1**; adding a PNG makes it exit 0.
- [ ] **No iOS rule tightened by accident** — an `E` PASS block whose only artefact is a widget entry still exits 0.
- [ ] **Over-reach guard** — a `W` block with `NOT RUN` + a non-empty `**Reason:**` is not flagged.
- [ ] **Regression** — no-argument run still exits 0 on the iOS report: 15 blocks, 14 PASS, 1 NOT RUN.

**I2 — the playthrough**
- [ ] Playwright harness committed under `test/web_e2e/`, **not** added to the Flutter app's dependencies.
- [ ] Build freshness proven in epoch seconds and pasted into the report header.
- [ ] **W1 falsified before it is trusted** — two tabs in one context shown producing `Rejoined active game session!` and a roster of 1, *then* three contexts shown producing three distinct players.
- [ ] Semantics tree either enabled and proven by a DOM hit on `THE GUEST LEDGER`, **or** the coordinate-driving fallback declared as a deviation in the header.
- [ ] `docs/playthrough_findings_web.md` exists with **W1–W16**, each with a verdict, and every PASS carrying a screenshot.
- [ ] A **full 3-round match** reached Game Over with three real clients and no bots.
- [ ] **W14 settled by observation, not argument** — the Case File share was actually pressed on web and what happened is recorded.
- [ ] **W15 quantified** — what a release web console prints, verbatim.

**I3 — the responsive sweep**
- [ ] **W17–W19** complete at 375×812, 768×1024 and 1280×800, **with a reload after each resize.**
- [ ] **Fifteen screenshots** — all five screens at all three sizes.
- [ ] Every clipped, overlapped or untappable control is filed as an issue with options and a blank `Your selection: _____`. **None fixed inline.**

**Across the wave**
- [ ] `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` **exits 0**, and its output is pasted into the report header.
- [ ] Battery at or above the baseline table at the top of this guide: **0 errors** · **≥159** · clean functions build · **61/61** · deploy gate **exit 0** · **both** evidence reports exit 0.
- [ ] `firebase deploy` was never run.
- [ ] One item, one commit; Conventional Commit; WHY in the body; `ongoing_general_errors.md` updated with a single banner and a single Resolved heading.
