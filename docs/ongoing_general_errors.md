# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**Wave J — prompt source & sampling (J1 → J2 → J3) — is complete (August 24, 2026).** All three selected options delivered and tested: **109 → Option C** (`bf38434`), **108 → Option B** (`64daf11`), **107 → Option B** (`74489b0`).

**Issues 1–109 are delivered. Issues 110 and 111 are open** — found while verifying the web playthrough, and it needs your selection. Gate state, measured August 24, 2026:

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (21 warnings, 197 infos) |
| `flutter test` | **179/179** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **68/68** |
| `./scripts/check_deploy_fresh.sh` | **exit 1 — expected.** Server commits (`1c5d69b`, `bf38434`, `64daf11`, `74489b0`) are undeployed; it goes green after `firebase deploy --only functions`, which is the user's call |
| `./scripts/check_playthrough_evidence.sh` | **exit 0** — 15 blocks (iOS): 14 PASS, 1 NOT RUN, 0 FAIL |
| `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` | **exit 0** — 19 blocks (Web) |

**Wave I — the web E2E playthrough (I1 → I2 → I3) — is complete**, with PNG evidence under `docs/playthrough_evidence/`. The release web build compiles and renders on CanvasKit, Firebase initialises clean, anonymous auth and callables work from browser contexts, session restore survives reload, and layouts hold at mobile, tablet and desktop.

**Undeployed and therefore not yet true in production:** the curated deck contents (`3f570e6`), unlimited re-rolls (`1c5d69b`), prompt source resolution & custom multi-round advance (`bf38434`), custom pool drawing & re-rolls (`64daf11`), uniform re-roll sampling (`74489b0`), and the Issue 106 deck guard's later refinements. Prompts are drawn once at `startGame`, so even after deploying, a room already in progress keeps the prompts it started with — manual verification needs a **new** game.

**Only one banner lives here.** Replace this block when the state changes; do not stack a new one on top of it.

## ⚠️ Unresolved Issues & Suggestions

### Issue 111: The game over screen shows only superlatives — no final scores, and nothing memorable from the match
**Status**: ⚠️ Confirmed Unresolved — Verified in `lib/screens/game_over_screen.dart`. The screen renders `_buildHonorCards(...)` and nothing else: **The Mastermind**, **The Duplicitous**, **The Gullible**. `sortedByScore` is computed at `:147` but only `.first` and a runner-up are ever used, so **no player sees the full table** and everyone below third place learns nothing about how they did.

**Two data facts decide what is cheap and what is not, and they were checked in source:**

- **Player counters survive the whole match.** `totalScore`, `timesFooled` and `playersDeceived` are applied as deltas in the reveal transaction (`functions/src/index.ts:1317–1330`) and are zeroed only at player creation and game reset. Anything derivable from these needs **no backend change**.
- **No answer text survives.** Single-card reveal scoping blanks every non-current card on the room document (`truthAnswer: ""`, `sabotageAnswers: {}`), and the round advance additionally resets each `sealed/{playerId}` doc plus `votes` and `unmaskGuesses` (`:1587`, `:1595`). By game over **the match's answers no longer exist anywhere.** So "the answer that fooled the most players" cannot be computed on the client at any price — it has to be captured server-side as each card resolves, before the wipe.

**Option A**: **Final standings only** — add the full ranked table under the honors: rank, name, score.
  - *Pros*: Pure client change, no deploy, no new state. Directly answers the complaint that the screen is only superlatives, and every player finally sees where they placed.
  - *Cons*: Delivers none of the "best lie" idea. The screen is still the same three cards plus a list.

**Option B**: **Standings + awards from counters already tracked** — the table, plus awards computed from `totalScore` / `timesFooled` / `playersDeceived`: *The Perfect Read* (`timesFooled == 0`), *Nobody Bit* (`playersDeceived == 0`, a booby prize), and a per-row "fooled X · fooled by Y" line so every player gets a fact about themselves.
  - *Pros*: Still **zero server change and no deploy**. Gives everyone a line, not just the podium. Ships in one client commit.
  - *Cons*: **Cannot quote a single actual answer** — the memorable part of the request is impossible at this tier. Awards read as statistics rather than moments.

**Option C (recommended)**: **Standings + a server-written match summary that quotes real answers.** Accumulate a summary as each card resolves — in the same reveal transaction that already walks the votes at `:1317` — and expose it at game over. That unlocks: **Best Lie of the Night** (the forgery text, its author, and how many it fooled), **Cleanest Truth** (the truth nobody found), **The Sting** (the single card where the most players voted wrong), and head-to-head lines like "Alice fooled Bob three times" — plus everything in Option B.
  - *Pros*: Delivers exactly what was asked, and quoting the actual sentence is what people will screenshot. **The accumulation point already exists** — the reveal transaction is already computing per-voter deltas, so the summary is written in a pass that is happening anyway, not a new traversal.
  - *Cons*: Server change plus a functions deploy. New persisted state to place carefully: it must live in `sealed` (default-deny) while the match runs and only reach the world-readable room document at game over, or it leaks forgery authorship before the unmask window closes — the exact hazard Issues 99 and 100 exist to prevent. More tests, and the summary needs a size bound so a long match cannot bloat the room doc.

**Option D**: **Round-by-round standings chart** — a sparkline of each player's score across rounds, showing comebacks and collapses.
  - *Pros*: Shows the shape of the match rather than just its end state; genuinely fun with 3+ rounds.
  - *Cons*: Requires per-round score snapshots that are **not stored today**, so it is new persisted state for a single visual. Gives nothing at all in a 1-round game, which is the current default. More work than C for less payoff.

**Recommendation: C**, because it is the only option that delivers the answer-quoting idea, and because **B is a strict subset of C** — if C looks too large to land at once, build B first as a client-only commit and add the summary afterwards without rework. Option D is worth revisiting only once matches routinely run 3+ rounds.

Your selection: _____

---

### Issue 110: The Case File cannot be shared on web, which is how the demo is being played
**Status**: ⚠️ Confirmed Unresolved — Verified in `lib/screens/game_over_screen.dart:105`: `_shareCaseFile()` renders the Case File to PNG bytes and then returns early under `kIsWeb` with the snackbar `Sharing is only supported on mobile devices.` The screenshot cited by web playthrough block **W14** (`docs/playthrough_evidence/w14_case_file_share.png`) shows exactly that message. The guard is correct — `Share.shareXFiles` needs a `dart:io` temp file, which throws on web — but P6 (the shareable Case File) is a shipped feature and **the demo is currently being played in a browser**, so in practice nobody can share it. The bytes are already rendered when the early return fires, so the artwork exists and only the delivery is missing.

**Option A**: **Leave it disabled** — keep the message, treat sharing as mobile-only until TestFlight.
  - *Pros*: Zero work and zero risk; honest to the player rather than silently failing; the wording is already clear.
  - *Cons*: The end-of-game payoff is missing for every friend testing on web right now, which is the whole audience today.

**Option B (recommended)**: **Download the PNG on web** — feed the already-rendered bytes to a browser download (blob URL + anchor click) behind the same `kIsWeb` branch, keeping `Share.shareXFiles` for mobile.
  - *Pros*: Uses bytes the code already produces, so it is a delivery change, not a rendering one. Works in every browser without permissions and gives web players the artefact. Small and well-contained.
  - *Cons*: A download is not a share — no share sheet, no prefilled text — and the file lands in Downloads where a phone browser may bury it. **Note the Artifact/CSP caveat does not apply here; this is the app's own page, not a published artifact.**

**Option C**: **Use the Web Share API** — call `navigator.share` with the PNG when the browser supports file sharing, and fall back to Option B when it does not.
  - *Pros*: A real share sheet on supporting browsers, closest to the mobile experience.
  - *Cons*: Support for sharing *files* is uneven (notably absent or partial on desktop browsers), requires a secure context, and needs a JS interop path plus the Option B fallback anyway — so it is Option B plus more.

Your selection: Proceed with Option B.

---

## 2. Lessons that still bite

These are kept because each one describes a trap that is **still live in the codebase** — not because it is interesting history. Each points at the contract that now owns the detail.

### Code & architecture traps

Properties of this codebase that have each cost a cycle. They are not style preferences — every one of them shipped a defect.

#### 2.1 `null` is not "absent" across the Dart ↔ TypeScript boundary

Dart sends an omitted optional as `null`; TypeScript's `!== undefined` guard treats that as a real value and writes it. This erased lobby settings and made the game unstartable (Issue 31). **Clients must omit keys rather than send null; callables must guard with loose `!= null`, never a falsy check** — `false` and `0` are legitimate values. Full contract: **`design_database_and_security.md` §7**.

#### 2.2 The test harness has four structural blind spots

Each has hidden a real bug. None is a flaw to fix — they are limits to design around:
- **The emulator suite is written in TypeScript**, so an omitted key genuinely *is* `undefined` there. It cannot produce the payload the Dart client actually sends. Issue 31 lived behind this.
- **Client tests use a fake Firestore that does not enforce `firestore.rules`**, so non-host writes and `authUid` checks are never really exercised. Use real simulator clients for anything that must be correct — bots are server-seeded documents and do not exercise the client path at all.
- **`Image.asset` loads no bytes under `flutter test`.** `find.byType(Image)` counts widgets whether or not art exists, and a golden render of the mascot comes out blank. Verify art by decoding the PNG (`test/helpers/png_decoder.dart`) or on a simulator.
- **Bare `flutter analyze` reports ~678 errors** from vendored plugin source under gitignored `build/`. Always scope it: `flutter analyze lib test`.

#### 2.3 Stream-rebuild guards are load-bearing

Firestore streams rebuild constantly. Every animation, sound and mascot pose is gated behind a **once-per-event key** (the `_advancedStateKeys` pattern; `_playedRevealForTargetId`; `_knownPlayerIds`). Remove one and the effect re-fires on every tick. A missing key is invisible in code review and only shows up on device — which is why Issue 34 makes the key a required argument.

#### 2.4 Validate type and range before comparing

`3 <= null` is `false`, so a range check silently passes and the function returns an empty result far from the cause. Reject nonsense input outright and throw a readable `HttpsError`, not a raw `Error` — raw errors flatten to `INTERNAL` and tell the player nothing. Detail: **`design_rotation_engine.md` §5**.

#### 2.5 `IconData` is a `final class`

`phosphor_flutter` extends it and therefore **cannot compile** on this SDK. Proven twice. The app vendors the Phosphor Light font directly instead. Detail: **`design_ui_direction.md` §7**.

#### 2.6 Everything mutating goes through a Cloud Function

Clients read Firestore streams and write nothing to rooms; `firestore.rules` denies it. Transactions read before write. Detail: **`design_database_and_security.md`**.

#### 2.7 Widget tests on animated screens hang without `accessibleNavigation: true`

Nine widgets in the lobby tree drive `AnimationController.repeat()`, so the frame scheduler never goes idle and a widget test hangs — emitting **no assertion output at all**, just `did not complete` after minutes, which reads like a logic bug in the code under test. Wrap the screen under test in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)`: `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`), so the flag puts every animation on its static path. Separately, **never `await` a fake callable directly inside `testWidgets`** — those bodies run under `FakeAsync`, where no `pump()` can advance time while an await is outstanding, so `await gameService.createRoom(...)` deadlocks; wrap it in `tester.runAsync`. **`pumpAndSettle()` is not the culprit and is not banned** — it works once the flag is set. It was wrongly blamed and wrongly prohibited on August 9, 2026, costing a cycle.

#### 2.8 A counter placed after an early return counts only some paths


`test/fake_functions.dart` incremented `getMyOptionIdCallCount` **inside the default branch, below the `overrideHandler` early return** — so every call made through `overrideCallable` was invisible to it. No test had noticed, because no test had yet tried to count overridden calls. **Instrumentation has control flow too: put a counter at the entry point, not beside the work you happen to be looking at**, or it silently measures a subset. Discovered while fixing Issue 92, whose new assertion is impossible without it.

#### 2.9 A font glyph can be decoded — "unverifiable without a simulator" was wrong

`Phosphor-Light.ttf` has a `post` table at version 3.0, so it carries no glyph names and a codepoint cannot be looked up by name. That was mistaken for "identity can only be confirmed by eye on a device", and the gate was then skipped and the wrong icon shipped (Issue 57). **The outlines are decodable in pure Python**: parse `cmap` → glyph id (id `0` is `.notdef`, i.e. tofu), then `loca`/`glyf` → contours, and plot the contour points as ASCII. This identified `0xe674` as a capsule-and-toggle mark rather than a door, and was validated first against `0xe214` (envelope) and `0xe2d6` (key), both of which rendered unmistakably. **A cmap presence check is not a substitute** — this font's cmap spans `0x0020–0xFFFD`, so presence is true for almost any codepoint and the check cannot fail. Related: [[gaslight-testing-context]] blind spot 3, which says art must be verified by decoding it — the same answer applies to fonts.

---
### Verification & evidence discipline

How work gets proved here. **Every entry below is a case where a green suite, a passing test or a confident report was wrong** — these are the failure modes that survive good code.

#### 2.10 Measure; do not estimate, and do not trust a test's name

- A layout overflow estimated at ~275 dp measured **593 dp**.
- A mascot shipped at **1.02:1** contrast — invisible — with a fully green suite.
- A test titled *"…rim contrast >= 4.5:1"* asserted only that a file was non-empty. **Read the assertion, not the title.**

#### 2.11 "Verified in source" is not "shipped" — check the deploy, not the diff


Issues 71, 72 and 76 were each read in source, confirmed correct, and moved to Resolved. All three were still broken for players, because the commits containing them were never deployed and nobody ever asked production what it was running. A source-verified claim and a shipped fix are different facts, and this file spent three cycles conflating them. **`./scripts/check_deploy_fresh.sh` belongs in the battery as a mandatory gate**, verifying that all 14 functions and security rules strictly postdate the latest tree commits. See Issues 77 & 81.

#### 2.12 An observation that cannot be traced to a tool result is not an observation


The August 13 playthrough report quotes 18 prompts from a 12-prompt deck, none of which exist anywhere in the repository. It is fluent, specific, internally consistent, and wrong — and it sat inside a document whose other blocks are genuinely good. **Verbatim-looking text is not evidence of verbatim capture.** The cheap defence is mechanical: every quoted game string must be findable in source with `grep -F`. Where it cannot be, the assertion is NOT RUN. See Issue 82.

#### 2.13 Traceable quotes do not make a report arithmetically sound


Fixing §2.12 worked: the August 14 re-run's quotes are all real, checked mechanically. The next defect moved one level up — **the numbers between the quotes.** A4 claims a 20-prompt deck was exhausted in 16 recorded rolls; A12 states a player both voted the truth and was fooled by a forgery on the same card. Each individual string is genuine; the arithmetic joining them is not. **Traceability catches invention. It does not catch a count that does not add up — check the counts separately**, and require any count-dependent assertion to state the count, the deck, and the deck's size. See Issue 83.

#### 2.14 A verdict line can name a method the block has no data for


A4 now reads `PASS (… + Marionette Live Session)` and names two room codes. Its observation section contains two source citations and a test pass count — **no prompts, no counts, no device output at all.** Nothing is fabricated; the claim is simply larger than the evidence, and the specificity of the room codes makes it read as verified. **Check the verdict line against the observation section as two separate things**, and treat a named method with no corresponding data as NOT RUN. See Issue 89.

#### 2.15 A forward reference survives a renumber; the promise it made does not


A4 was correctly marked NOT RUN with its gap stated honestly and *"Queued for re-verification in S7 (Assertion A20)."* The S7 list was then renumbered during the run, A20 became a different assertion, and A4's pointer was never repointed. **The document now reads as though the gap is covered, and cites evidence about something else.** Nothing lied; a cross-reference went stale, which is indistinguishable from a lie to the next reader. **Whenever an assertion list is renumbered, grep for inbound references and repoint them in the same pass** — the same rule this project already applies to guide section numbers, arriving here by a different route. See Issue 88.

#### 2.16 A test can satisfy a spec's words while testing nothing


The X1 spec said: throw for a card, then fetch **that same card** and assert it is not permanently blocked. The implementation threw on `card_a` and fetched `card_b` — same shape, same assertion, zero coverage. Deleting the `finally` it exists to guard leaves the suite green. **The spec named the right thing and the reviewer had no way to see the substitution from a passing run**, because a passing test looks identical either way. **The only defence is the standing rule applied to the test itself: remove the guard, watch the test fail.** That step was performed for the leave-control guard two waves earlier and skipped here. See Issue 92.

#### 2.17 A documented invariant with no test behind it is a wish


`design_database_and_security.md:35` states "never send other players' authorship to the client." Issue 98 is that exact invariant being violated by `castVote` — the one function privileged to read the default-deny `sealed` document — which republished its contents into a world-readable one. The invariant was written down, believed, and never asserted anywhere. **Every invariant in the design docs should have an assertion behind it, in the suite that can actually observe it**: rules go in `functions/test/rules.spec.ts`, callable authorization in `functions/test/game_e2e.spec.ts`. A Dart widget test can never prove either — `test/fake_functions.dart` does not enforce `firestore.rules`.

#### 2.18 When a design doc calls something a secret, grep for where it is published


`design_database_and_security.md:69` treats `playerId` as the credential that makes seat recovery safe. The player document ID **is** that `playerId`, and `firestore.rules:18` makes the collection world-readable — so the secret is listed next to the lock (Issue 97). The "UUIDs are unguessable" precedent gave false comfort: **the UUID was never guessed, it was published.** Whenever a document ID doubles as an authorization credential, that is the bug.

#### 2.19 A fix can be correct while its design doc still describes the vulnerability


SEC1 and SEC2 shipped correctly, with tests and a verified deploy — and `design_database_and_security.md` §3 still read *"Room documents: `allow read: if true`"*, the exact rule that had just been retired for granting collection enumeration, while the seat-token mechanism that fixed the HIGH-severity takeover appeared **nowhere**. Four of the six items updated a design doc; the two most important did not. A future agent reading §3 would have found a documented invitation to "simplify" the split verbs back into the vulnerability. **Closing a security issue means updating the document that described the old behaviour as intended, not only the one describing the new behaviour as delivered** — and the doc most likely to be stale is the one that made the vulnerable design sound deliberate. Grep the design docs for the code you just deleted.
---

#### 2.25 The evidence gate proves an artefact exists, not that it agrees with the prose beside it

Web block **W14** claimed it had "verified share payload creation and clipboard/fallback handler execution on web", and its `Expected:` said the click "triggers share/clipboard action". Neither happens: `_shareCaseFile` returns early under `kIsWeb`, there is no clipboard path for the Case File at all, and **the very screenshot the block cited shows the snackbar `Sharing is only supported on mobile devices.`** The block passed `check_playthrough_evidence.sh` because R3 only asks whether a PNG path is present — it cannot read the PNG.

**So the gate bounds the *form* of evidence, never its *content*.** When verifying a playthrough, **open the artefact and check it says what the block says it says**, at least for any block whose claim you have a prior expectation about. Here the prior was concrete — `Share.shareXFiles` needs a `dart:io` temp file that cannot work on web — and it is exactly the block that turned out to overstate. A named mechanism that does not exist in the source (`grep -rn "Clipboard" lib/` returned only the room-code plaque) is the cheapest tell.

#### 2.24 A fake that models the CORRECT behaviour hides the bug better than a wrong one would

`test/fake_functions.dart` implemented `startGame` by reading `roomState.selectedDeckId` from the room document. That is the **right** design — it is what the server does *now*, after Issue 106. But the real server was reading `request.data.selectedDeckId`, so for as long as the two disagreed, **every outcome-based test drew from the correct deck and passed** while production drew from the wrong one. A fake that is subtly wrong gets noticed; a fake that is *better than production* is invisible, because everything it touches looks right.

**Two rules.** When a fake and its real counterpart resolve the same value from different sources, **that divergence is a bug in the fake even when the fake is more correct** — pin them together and add the real one's validation to the fake, so a test that violates the contract fails in the suite instead of in a friend's game. And when a defect lives in **what the client sends** rather than in what comes back, **assert the payload**: `lastCallParams` catches it, an outcome assertion never will. See [[testing-blind-spot-nonhost-writes]] and §2.2.

#### 2.23 A deploy filter can drop a required asset, and an SPA rewrite will hide that it did

The first Firebase Hosting deploy served a blank page. Cause: the hosting block's `"ignore": ["**/.*"]` — copied from Firebase's own template — matches any path segment starting with a dot, and **this app ships `.env` as a declared Flutter asset** (`pubspec.yaml`), so it builds to `build/web/assets/.env` and was silently excluded from the upload. `main.dart:32` calls `await dotenv.load()` **before `runApp()`**, so `main()` threw and Flutter never painted a frame.

**What made it hard to see:** the catch-all rewrite `{"source": "**", "destination": "/index.html"}` meant the missing file returned **HTTP 200 serving index.html**, not a 404. Every asset URL "worked". The give-away was that `/assets/.env` was **byte-identical to `/`** — same sha, same 7952 bytes. Reproduced locally by serving the build with only that one file removed: console showed `failed to fetch "assets/.env"` and an uncaught Dart exception, with the splash still spinning.

**Two rules.** **Never let a deploy-time filter decide which app assets ship** — check what the app actually loads at boot against what the filter excludes, and remember that a dotfile can be a required asset, not just editor cruft. And **a catch-all SPA rewrite converts every missing-file 404 into a 200**, so "no 404s in the network tab" proves nothing about a deployed SPA; compare a suspect asset's bytes against `index.html` instead. See [[gaslight-testing-context]].

#### 2.22 A tool catches what a careful reader misses — that is the point of building one

Two separate review passes read the playthrough report hunting for blocks that claimed PASS on source inspection. Between them they found **E10** and **E11**. `scripts/check_playthrough_evidence.sh`, run once against the same file, found **E10, E11 and E13** — a third instance nobody had noticed, in a block labelled *"extra coverage"* that both readers had skimmed as low-stakes. **A mechanical check does not get bored, does not assume a block is unimportant, and does not stop looking once it has found two.** When review keeps surfacing the same defect class, stop reviewing harder and write the check — and expect it to find more than you did on the very run where you validate it.

#### 2.21 A check that matches nothing returns the same number as a check that passes

§3.2 of the guide mandated `awk '/^\*\*Observed/,…' | grep -c "grep -"`, expecting `0`. It returned `0` — **because it matched zero lines.** The report writes its fields as list items (`- **Observed:**`) and the `^` anchor required column 0. A clean report and an unread report produce an identical result, and the number reads as evidence either way. The check was also too narrow to catch the defect that was actually present: it looked for the literal string `grep -`, while E10's `Observed:` was *prose describing source code*.

**Two rules follow.** A mechanical check must **assert it matched something** — a non-zero denominator — before its result means anything. And a check written to catch one shape of a defect will not catch the next shape; **state what the check does not prove** when you add it. See Issue 105.

#### 2.20 A `grep` is not an observation

The pre-demo playthrough answered *"what I observed, verbatim"* with `grep -Fn "THE RECORD OF TRUTH" lib/screens/phase2_craft.dart -> line 386` on every assertion. Nothing was fabricated — the greps are real and the lines check out — but **they prove a string exists in the source, not that it rendered on a device**, which is the only thing a playthrough can establish. The `grep -F` traceability rule (§2.12) was introduced to stop *invented* quotes; it was then used as a substitute for the observation itself. **A source citation belongs in a `Reference:` field; `Observed:` takes device output only.** The tell is that every block's evidence has the same shape as every other block's, and none of it mentions a screen. See Issue 102.

---

## 3. Resolved — index only

Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This is an index, not a record. **One heading, and only one — never add a second** (that is how this file reached 559 lines: each verification pass appended its own summary without removing the last, so Issues 93–95 appeared three times).

### Issues 65–109 — August 8 to 24, 2026

**44 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

| Area | Issues | Where the surviving contract lives |
|---|---|---|
| **Security — access control** (`/rooms` collection enumeration; seat/host takeover via `joinRoom` re-binding on a world-readable `playerId`; seat tokens hashed into default-deny `sealed`) | 96, 97 | `design_database_and_security.md` §3, §5 |
| **Security — answer secrecy** (`castVote` laundering `answerAuthors` into the public room doc; reveal merging every card instead of the current one; forgery authorship exposed during the unmask window) | 98, 99, 100 | `design_game_state_and_models.md` §2; `design_scoring_and_ui.md` |
| **Security — debug surface** (debug callables reachable in production with no membership or host check) | 101 | `design_database_and_security.md` §7.1 |
| **`votes` contract** — redefined three times; the sentinel purge, then opaque option ids resolved server-side at reveal | 71, 78, 98 | `design_game_state_and_models.md` §2 — **carries the "broken three times, enumerate its readers" warning** |
| **Deploy discipline** — `predeploy` wired so a red suite blocks a deploy; then production ran stale code for two cycles anyway, until the written instruction was replaced with `scripts/check_deploy_fresh.sh` (three exit codes, epoch comparison, rules checked separately) | 65, 77, 81 | `design_database_and_security.md` §8 |
| **Lobby authority** — readiness gate on `startGame` with the host-exemption deadlock guard; host kick reusing `handleDisconnect` | 86, 87 | `design_game_state_and_models.md` §1; `design_database_and_security.md` §4 |
| **Mid-match departure** — in-game leave controls; the 3-player floor applied during play, not only at start | 85 | `design_game_state_and_models.md` §1 |
| **Own-answer lockout** — option id as authority, per-card text as fallback, never unioned; `getMyOptionId` and its client call discipline | 90, 91, 92, 94 | `design_scoring_and_ui.md` §3.2; `design_database_and_security.md` §2 |
| **Reveal & unmask** — who may accuse vs who may be accused; the five-beat reveal and its deadline | 79, 80 | `design_scoring_and_ui.md` |
| **Prompts & decks** — per-player `seenPrompts` in `sealed`; exhaustion boundary and the `resource-exhausted` → SnackBar mapping whose fall-through is the failure mode | 67, 68, 69, 83, 88 | `design_prompt_system.md` §5 |
| **Answer integrity** — spurious `THE SOUL IS SILENT` placeholder; forgery author key derived server-side; forgery defaults and the 3-player floor as an independent guard | 72, 76 | `design_game_state_and_models.md` §1–§2 |
| **UI surfaces** — dialog contrast (ratio-asserted, not string-asserted); error surfaces mapped on `e.code` and never interpolating the exception; busy states as a correctness guard because `createRoom` is not idempotent | 84, 93, 95 | `design_ui_direction.md` §6 |
| **Debug controls & dead fields** — host debug controls cleaned up; reaction medallions removed with `lastReaction`/`lastReactionAt` deliberately retained in the model and rules to avoid a migration | 73, 74 | `design_database_and_security.md` §3 |
| **Standings & honors** — tabular-figure alignment; honors metrics | 75 | `design_scoring_and_ui.md` |
| **TTL** — 8-hour `expiresAt` on rooms and players, applied in production and backfilled | 53–56 | `design_database_and_security.md` §6 |
| **Evidence discipline** — a manual playthrough marked complete without being run, then tooled with Marionette rather than deferred an eighth time; guards that assert usage rather than presence; a report with fabricated quotes and mis-targeted assertions; a verdict citing a method its block had no data for; a guard whose test could not fail | 66, 70, 82, 89, 92 | **§2 below** — these produced lessons, not code contracts |
| **Pre-demo ship** — seven `DEBUG:` controls gated behind `kDebugMode` (buttons kept, not deleted — they drive emulator tests); the stock Flutter icon and 1×1 launch stubs replaced with generated raven art; the App Store privacy manifest added and made a member of the Runner target | 103, 104 | `design_ui_direction.md` §6; `design_database_and_security.md` §7.1–§7.2 |
| **Pre-demo E2E** — first playthrough after the security wave: full 3-round match on three simulators, 13 of 15 blocks with device evidence, all cited screenshots present. **Seat recovery after a force-quit device-verified for the first time.** No product defect found; the first attempt was a source audit and was re-run | 102 | `design_database_and_security.md` §5; `docs/playthrough_findings_marionette.md` |
| **Chosen deck ignored — every game played The Daily Grind** (`_selectedDeck` initialised once, read once, never assigned; `startGame` trusted the caller's deck over the room's). Fixed **A+C**: server resolves from `room.selectedDeckId` *and* rejects a mismatched claim with `invalid-argument`; dead field deleted; family-friendly toggle now writes through so it cannot desync the lobby from the room | 106 | `design_prompt_system.md` §2; `functions/src/index.ts:293`; `test/deck_selection_test.dart` |
| **Evidence mechanical gate & E10/E11 device verification** — `check_playthrough_evidence.sh` tool enforcing R1–R4 with 3 exit codes; E10 in-game leave auto-end verified on both remaining devices (`e10_p1_gameover.png`, `e10_p2_gameover.png`); E11 release build verified with zero DEBUG controls (`e11_release_lobby.png`); repointed dead citations to `functions/src/index.ts:986` | 105 | `docs/agent_execution_guide.md` §2–§3; `scripts/check_playthrough_evidence.sh`; `docs/playthrough_findings_marionette.md` |
| **Web E2E Playthrough (Wave I)** — Playwright automated harness (`test/web_e2e/`); I1 evidence gate widened with strict PNG requirement for W blocks; W1–W16 3-player match with falsification, truth, forgeries, voting lockout, unmasking, standings, GameOver, mid-match refresh restoral, case file share, console hygiene, and below-3 auto-end; W17–W19 responsive sweeps across mobile (375x812), tablet (768x1024), and desktop (1280x800) with 15 screenshots | 106 (Wave I) | `docs/playthrough_findings_web.md`; `test/web_e2e/`; `scripts/check_playthrough_evidence.sh` |
| **Prompt Source & Sampling (Wave J)** — resolved effective prompt source on `GameState` killing `"custom"` sentinel crash (109 / J1); custom game prompt drawing and re-rolls from players' contributed pool with self-author lockout (108 / J2); uniform re-roll sampling minus live in-play table cards (107 / J3) | 107, 108, 109 | `design_prompt_system.md` §3, §5; `functions/src/index.ts` |

> **The three highest-value things to know from this wave**, if you read nothing else: the `votes` field has been redefined three times and broken its readers twice (§2 and `design_game_state_and_models.md` §2); production silently ran stale code for two full cycles until a written step was replaced with a tool (`design_database_and_security.md` §8); and **`playerId` was treated as a secret while being published as a document ID** (`design_database_and_security.md` §5).

---

### Issues 1–64 — May 24 to August 7, 2026

64 items. Full text is in `git log`; the durable consequences are in the design docs. Grouped by what they touched:

| Area | Items | Where the surviving contract lives |
|---|---|---|
| **Write architecture & multiplayer** — non-host writes blocked by rules, read-after-write transaction order, unhandled server errors, direct client writes in debug tools, full-object writes | Issues 1, 13, 14, 17, 18 + the May race/leak/transaction fixes | `design_database_and_security.md` |
| **Identity & reconnection** — device-stable `playerId`, seat re-binding, anonymous-auth loss, heartbeat volume, disconnect cleanup, host handoff | Issues 16, 36, 42, 15, 34, 35 | `design_database_and_security.md` §4–§5 |
| **Game-loop correctness** — score application on host override, timeout blank cards, inflated scores after disconnect, spectator miscounts, deterministic card resolution, reader re-indexing | Issues 26–35, 21 | `design_rotation_engine.md`, `design_scoring_and_ui.md` |
| **Scoring & honors** — saboteur "found the truth" bonus, metric-based end-game honors | Issues 30, 31 | `design_scoring_and_ui.md` |
| **Prompts & decks** — thematic decks, custom decks, the 3-prompt server cap, re-roll | Issues 22, 48, P4, P10 | `design_prompt_system.md` |
| **Duplicate answers** — Gemini replaced by a local lexical heuristic mirrored byte-identically on both sides | Decision 2 | `design_semantic_integrity.md` |
| **Secrets** — Gemini/Firebase key exposure in the client binary; keys moved to `.env`, Gemini removed entirely | Issues 3, 14 | §2.6 above; `.env` is gitignored and ships inside the IPA |
| **UI programme** — M1–M5 mobile-first, V1–V5 character work, U1–U8 UX, E7 sound | 49 + the M/V/U proposal sets | `design_ui_direction.md` §10 |
| **Icons & mascot** — hybrid icon system, the `final class IconData` blocker, vendored font, mascot redraw, hollow-body fill | Issues 23, 28, 29, 32, 33 | `design_ui_direction.md` §7 and the mascot block |
| **Lobby & house rules** — entry-form fit at 360×640, House Rules consolidation, non-host read-only, settings-wipe crash | Issues 24, 25, 27, 30, 31 | `design_ui_direction.md` §10; `design_database_and_security.md` §7 |
| **Test infrastructure** — emulator + rules unit suite, coverage gaps, real PNG decoding and contrast assertions | Issue 41, Tasks T1–T3 | §2.2 above |
| **Dependencies** — unused `cupertino_icons` removed; Phosphor font vendored | Tasks T2, Issue 29 | `design_ui_direction.md` §7 |

---

---

## 4. Deliberately not built — do not re-propose

These were designed, costed and consciously **not** selected. Their absence is a decision, not an oversight:

- **P7 — Confidence Wager** ("seal it in blood"): stake points on your own forgery.
- **P9 — House Cards**: per-round modifiers.
- **P11 — The Final Gambit**: a comeback round for trailing players.
- **Issue 30 Option C**: making `_familyFriendlyOnly` a synced house rule. It stays client-local.
- **Issue 34 Option C**: priority arbitration between mascot poses. Available as an upgrade if reveal-screen collisions prove annoying in practice.

---

## 5. Where the detail lives now

| Looking for | Go to |
|---|---|
| What to work on next, and how to validate it | `agent_execution_guide.md` |
| **Security rules, seat tokens, callable table & guards, debug isolation, TTL, deploy verification** | `design_database_and_security.md` |
| **The `votes` two-phase contract**, phases, 3-player floor (start *and* in play), readiness gate, card/player/game schemas | `design_game_state_and_models.md` |
| Scoring formulas, reveal beats, unmask bounds, single-card reveal scoping, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, motif, icons, mascot, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Prompt decks, custom decks, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Card passing, disconnect recalculation, input validation | `design_rotation_engine.md` |
| Duplicate-answer heuristic | `design_semantic_integrity.md` |
| Manual playtest journeys | `e2e_testing_journeys.md` |
| Playthrough evidence and its provenance | `playthrough_findings_marionette.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |
| Full history of any resolved item | `git log` |

**A note on keeping this file short.** It was 903 lines in August, cut to 559, and cut again to ~200 on August 21. Both times the cause was the same: **each pass appended its summary without removing the one it superseded** — Issues 93–95 appeared three times, and §1 accumulated six stacked banners. When you resolve something, move the durable consequence into the design doc above and leave **one line** here. If you are adding a paragraph to this file, ask first whether it belongs in a design doc instead.
