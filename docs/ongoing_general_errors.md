# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**Wave L — artefact re-verification (L1 → L2 → L3) — is complete (August 24, 2026).** All three steps delivered and tested:
- **L1** (`ea2186d`): Rule R5 implemented in `scripts/check_playthrough_evidence.sh` requiring every cited PNG artefact in PASS/FAIL blocks to exist on disk, resolving relative to repo root with non-zero match assertion and NOT RUN exemption.
- **L2** (`e014845`): Classified all 54 artefacts into Orphaned (4 removed via `git rm`), Falsified (1 replaced), and Outdated-but-true (10 retained).
- **L3** (`187a923`): Ran live 3-player web playthrough across isolated browser contexts on release build (mtime `1787554079` > commit `1787552503`), runtime-verified Case File Blob download (`gaslight_case_file_xhpd.png`, 629,585 bytes), captured confirmation snackbar (`w14_case_file_download.png`), final standings table (`w11_gameover.png`), and refreshed responsive sweeps (`w17_*`, `w18_*`, `w19_*`).

**Issues 1–111 are delivered. Zero active unresolved issues are open.** Gate state, measured August 24, 2026:

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (18 warnings, 204 infos) |
| `flutter test` | **185/185** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **70/70** |
| `./scripts/check_deploy_fresh.sh` | **exit 1 — expected.** Server commits (`1c5d69b`, `bf38434`, `64daf11`, `74489b0`, `24a2398`) are undeployed; it goes green after `firebase deploy --only functions`, which is the user's call |
| `./scripts/check_playthrough_evidence.sh` | **exit 0** — 15 blocks (iOS): 14 PASS, 1 NOT RUN, 0 FAIL (14 artefact paths verified on disk) |
| `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` | **exit 0** — 19 blocks (Web): 19 PASS, 0 NOT RUN, 0 FAIL (38 artefact paths verified on disk) |

**Undeployed and therefore not yet true in production:** the curated deck contents (`3f570e6`), unlimited re-rolls (`1c5d69b`), prompt source resolution & custom multi-round advance (`bf38434`), custom pool drawing & re-rolls (`64daf11`), uniform re-roll sampling (`74489b0`), match summary accumulation and game over publishing (`24a2398`), and the Issue 106 deck guard's later refinements. Prompts and card summaries are initialized at `startGame`, so even after deploying, a room already in progress keeps the configuration it started with — manual verification needs a **new** game.

**Only one banner lives here.** Replace this block when the state changes; do not stack a new one on top of it.

## ⚠️ Unresolved Issues & Suggestions

**No open issues and nothing to decide.** Issues 1–112 are delivered and Wave M is complete.

**One check remains, and it can only be done on the beta itself.** Wave M's presence fix is verified everywhere a test can reach — both server sites are guarded by boundary tests written against `PRESENCE_STALE_MS` (falsified: flipping the comparison fails 2 tests), and the resume hook has a widget test asserting the immediate write (falsified: removing the hook fails it). **But fake timers under `flutter test` cannot reproduce iOS suspension, which is the entire condition the wave exists for.** On the first TestFlight build: join a room, **lock the phone 60 s** → still in the room and the host can still start; **lock 3 min** → correctly dropped. The second half matters as much as the first, or M1 has simply disabled presence. A simulator is not evidence — it does not suspend timers the way a locked device does. Procedure in `agent_execution_guide.md` §2.

---

**The match summary has now been observed rendering in a real game** (block **W20**, room `QZER`, 3 players, `totalRounds = 2`, three isolated browser contexts). Verified on August 24, 2026 by opening the artefact rather than reading the block: every quoted string in W20 appears verbatim in `w20_match_summary.png` — **BEST LIE OF THE NIGHT** `"Sapphire"` by Alice with `Fooled 1 player`, **CLEANEST TRUTH** `"Archimedes"` with `Found by only 0 players`, and **THE STING** with `2 wrong votes` — alongside the FINAL STANDINGS table. Best Lie quotes a genuine player-authored forgery, not a placeholder.

An independent consistency check on the same frame: **`sum(playersDeceived)` must equal `sum(timesFooled)`**, because every fooling has exactly one deceiver and one deceived. The standings show Alice 2/1, Bob 1/1, Charlie 0/1 — **3 and 3.** The counters are coherent, not merely present.

That closes Issue 111 end to end: server logic (equality-asserted and falsified), deployment (confirmed in the shipped bundle), client rendering (widget-tested), and now a real match on screen. The durable contract moved to **`design_scoring_and_ui.md`** — the match-highlights section, its `sealed/_summary` storage and publish-at-game-over rule, and the empty-is-legitimate caveat.

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

#### 2.29 Never accept Xcode's "Update to recommended settings" on this project

Xcode offers a **Perform Changes** dialog for recommended project settings. **Accepting it breaks the iOS build**, and the failure is not obvious from the dialog — the offending item is **Enable User Script Sandboxing** (`ENABLE_USER_SCRIPT_SANDBOXING`).

This project has **four shell-script build phases**: two running Flutter's `xcode_backend.sh` (`build` and `embed_and_thin`) and two CocoaPods checks that diff `Podfile.lock` against `Manifest.lock`. Sandboxing restricts what those scripts may read, and Flutter's own build artefacts fall outside the permitted set. Verified empirically on **August 25, 2026** by enabling the flag in all three build configurations and building:

```
Error (Xcode): Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter
Error (Xcode): Sandbox: dartvm(...) deny(1) file-read-data .../native_assets/objective_c.framework/objective_c
Error (Xcode): Sandbox: dartvm(...) deny(1) file-read-data .../.last_build_id
Failed to build iOS app
```

Reverting the flag restored a clean `✓ Built build/ios/iphoneos/Runner.app (49.9MB)`.

**So: decline the dialog.** The other items in it (asset symbol extensions, the quoted-include warning, string catalog symbols) are harmless but not worth the risk of accepting the batch, since Xcode applies them together. If a specific one is ever wanted, set it alone and rebuild before committing. **Xcode will keep offering this** — the answer stays no until Flutter's build phases declare sandbox-compatible inputs and outputs.

*Unrelated but worth knowing while in here:* every `flutter build ios` rewrites `ios/Runner.xcodeproj/project.pbxproj` (CocoaPods rewrites `objectVersion`), so a build dirties the tree on its own. That churn is pre-existing and not a change anyone made.

#### 2.28 A screenshot that looks wrong may be an undocumented design rule

W20's evidence showed **THE DUPLICITOUS — "most players deceived" — awarded to Bob with 1 deception, while the standings in the same frame showed Alice on 2.** That reads as a plain scoring bug, and `design_scoring_and_ui.md` supported that reading: it defined the honor as "highest `playersDeceived`, ties broken by score" and said nothing more.

The code disagrees. `game_over_screen.dart:156-190` seeds an `assignedIds` set with the Mastermind and picks every later honor **only from players not yet assigned**, so honors deliberately spread across the table instead of stacking on one strong player. Alice had already taken The Mastermind, so The Duplicitous went to the best of the rest. **Correct, deliberate, and undocumented** — a false bug report was one step away.

**The rule: when evidence contradicts a design doc, read the code before filing.** The doc is a summary and can be *incomplete* rather than wrong, and an omitted constraint looks identical to a defect from the outside. When you find one, **fix the doc** — that omission is now written into `design_scoring_and_ui.md` Clarification 2 with the W20 numbers as the worked example, so the next reader does not re-run this.

#### 2.27 The gate never checked that the evidence file exists

Completing the family: **2.25** found that `check_playthrough_evidence.sh` bounds the *form* of evidence and not its content; **2.26** found that *updating* a block leaves its artefact behind; and this one is the floor beneath both — R3 matches the artefact **path string inside the block text** and **never stats the file**. Deleting a cited PNG therefore leaves the gate **green** while the evidence is gone, and a block citing a path that never existed passes just as cleanly.

So for most of this project's life the gate has been asserting that *a sentence mentions a filename*. That is worth remembering when reading any historical PASS: the artefact was required to be **named**, not to exist, not to be current, and not to agree with the claim. Rule **R5** (Wave L) adds the existence check; the other two remain the reader's job.

#### 2.26 A stale screenshot under new prose is indistinguishable from a fabricated one

Block **W14** claimed unobserved behaviour **twice**. The first time it described a "clipboard/fallback handler" that existed nowhere in `lib/`; that was corrected, and the correction said in as many words that the prose had overstated. Wave K then **overwrote the correction** with a new claim — a synthetic anchor download and a confirmation snackbar — while citing **the same PNG, dated before the feature was built**, whose visible snackbar still read `Sharing is only supported on mobile devices.`

Both times `check_playthrough_evidence.sh` passed, because R3 asks whether a screenshot **path** is present and cannot open the file. **The gate bounds the form of evidence, never its content** (§2.25) — and the second occurrence shows the sharper edge: *updating* a block is more dangerous than writing one, because the artefact silently stays behind while the sentence moves on.

**The rule: when a block's claim changes, its screenshot must change too.** Re-shoot the evidence under a **new filename** (reusing the old name hides the staleness from `ls` and from review), or downgrade the claim to what the existing image actually shows. Never leave an old image under a new sentence.

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

### Issues 65–112 — August 8 to 25, 2026

**47 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

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
| **Game Over Payoff & Web Download (Wave K)** — Standings + server-written match summary quoting real answers accumulated into `sealed/_summary` across rounds and published at game over (111 / K1); Case File PNG direct downloads on web via Blob URL and synthetic anchor click (110 / K2) | 110, 111 | `design_scoring_and_ui.md`; `lib/utils/case_file_saver_web.dart`; `functions/src/index.ts` |
| **Presence & Resume Lifecycle (Wave M)** — 120 s server presence threshold (`PRESENCE_STALE_MS = 120_000`); GameService `WidgetsBindingObserver` immediate `lastSeen` write and heartbeat restart on app resume | 112 (Wave M) | `design_database_and_security.md` §4–§5 |

> **The three highest-value things to know from this wave**, if you read nothing else: the `votes` field has been redefined three times and broken its readers twice (§2 and `design_game_state_and_models.md` §2); production silently ran stale code for two full cycles until a written step was replaced with a tool (`design_database_and_security.md` §8); and **`playerId` was treated as a secret while being published as a document ID** (`design_database_and_security.md` §5).

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
