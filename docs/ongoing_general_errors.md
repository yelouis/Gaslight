# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**Wave AD verified, September 12, 2026.** AD1 and AD3 are delivered and correct. **AD2 should never have been filed** — see the correction below. All three are indexed in §3.

**Falsified this session, not taken from the commit body:**
- **AD1 holds.** The decoy is gone from `phase3_vote.dart` and the assertion now names `TAP A CARD TO CHOOSE`. Making the button render nothing while unselected — a change that still compiles — fails Test 2 of `phase3_vote_target_ready_toggle_test.dart` while Test 1 passes. **The guard can fail on the thing it names again**, which is exactly what lesson §2.43 was about.
- **AD3's code is correct by inspection.** Card selection is now matched *positively* on `OPTION` with `TAP A CARD TO CHOOSE` explicitly excluded; both scripts parse under `node --check`; and `n.ariaLabel` is safe because `playthrough_helpers.js:30` defaults it to `''`. **The implementing agent also found a second break this guide did not anticipate** — `run_match_summary_playthrough.js` used the *presence* of `CONFIRM VOTE` to decide whether a player was a voter, which the rename silently inverted.

**⚠️ Correction — AD2 was specced against a false premise, and the error was in the verification pass, not the implementation.** The September 12 verification reported that AC5.3, AC5.4 and AC5.5 "were not written". **They were.** All three shipped in the AC5 commit (`76334b1`) in `functions/test/prompt_decks.spec.ts`, and they are substantive — AC5.4 draws twenty times with ten of twenty-five excluded and asserts every draw comes from the room deck. The verification grep matched `it('AC5` with a single quote; that file uses double quotes, so the tests were invisible to it. **AD2 therefore reduced to adding one genuinely missing assertion** (`getDeckRating` alongside the existing `getDeck(...).rating`), which is what the implementing agent correctly did. Recorded as lesson §2.44.

**⚠️ AD3's end-to-end run is self-reported and the repository does not corroborate it.** The commit states the scripts were validated against a local web build on port 8777. `saveScreenshot` writes into `docs/playthroughs/evidence/`, and `run_full_playthrough.js` rewrites `w8_vote_lockout.png` partway through — **yet the evidence set is unchanged at 123 files and the tree is clean**, so no screenshot was rewritten. The run may well have happened with its output discarded; there is simply no artefact of it. **Treat the script fix as verified by inspection and the end-to-end execution as unverified** (lesson §2.36: a self-reported gate result is a claim, not a measurement).

**Process note:** all three items landed in a single commit (`a0c4c57`), against the standing one-item-one-commit rule. No correctness impact; recorded so the next wave does not treat it as precedent.

**Every gate is green:** 0 errors · 0 warnings · **188 infos** · **346** client tests · **157** functions tests · decks, all five evidence invocations, and deploy all exit 0. **`test/web_e2e` remains ungated** — that is Issue 175.

## ⚠️ Unresolved Issues & Suggestions

One open issue, filed during Wave AD verification. Everything from the September 8 playthrough and Waves AA–AD is resolved and indexed in §3.

---

### Issue 175: The web E2E scripts drift silently because nothing runs them

**Status**: ⚠️ Confirmed Unresolved — **filed September 12, 2026 during Wave AD verification.** `test/web_e2e/*.js` is referenced by **no gate script**: it needs a web build, a static server, Playwright and a backend, so the battery has never exercised it. AD3 fixed one break in it; verification then found the scripts have been drifting for four days without anyone noticing.

**The evidence, measured rather than supposed.** `run_match_summary_playthrough.js:33` and `:52` still click a button labelled `INSPECT`:

```js
await tryClickElement(page, n => n.role === 'button' && (n.text === 'INSPECT' || n.text.includes('INSPECT')), 'INSPECT Overlay');
```

**`INSPECT` was deleted from the app by AA1 (Issue 155)** when the dealt-card overlay was removed. `grep -rn "INSPECT" lib/` returns nothing, and the same is true of `DISMISS`, the overlay's other label. `tryClickElement` is tolerant — it logs `[CLICK FAILED]` and continues — so the script does not crash; it simply carries dead steps aimed at a screen that no longer exists, and **the only signal is a log line nobody reads.**

That is also how AD3's break arrived: AC3 renamed a button, and `run_match_summary_playthrough.js` had been using the *presence* of `CONFIRM VOTE` to decide whether a player was a voter. **Two waves in a row silently invalidated these scripts.**

**Why this matters beyond tidiness.** These scripts produce the web evidence in `docs/playthroughs/findings_web.md`. A script that half-works still produces screenshots, and screenshots are what the evidence gate checks exist — **the gate verifies the artefact is on disk, never that the run reached the state it claims.** A drifted script therefore degrades quietly into evidence that looks fine.

**Option A (recommended)**: **Declare the scripts' UI strings in one place and assert they exist in `lib/`** — move every label the scripts match on into an exported `UI_STRINGS` map in `test/web_e2e/playthrough_helpers.js`, have the scripts reference only that map, and add a check to the battery that fails when any of those strings is absent from `lib/`.
  - *Pros*: Catches exactly the failure that has now happened twice — a renamed or deleted label — in milliseconds, with no browser, no web build and no backend, so it can join the battery without slowing it. **Because the scripts reference the same map the check reads, the list cannot drift out of step with what is actually matched** — which is the trap that made `contrast_tokens_test.dart` useless in Issue 171 (lesson §2.42). Also self-documents which strings are load-bearing for E2E.
  - *Cons*: Proves the strings still exist, not that the flow still works — a label that survives while its screen is reordered still breaks the script. Needs care to separate genuine UI labels from fixture data the scripts also match on (`Paris`, `AAA`, player names), and a wrong split gives either false alarms or false confidence.

**Option B**: **Gate the full web E2E run** — add a web build, static server and Playwright run to the battery.
  - *Pros*: The only option that verifies the flow rather than its vocabulary, and it would produce fresh web evidence as a by-product. Removes the self-reported-run problem entirely, which is what made AD3's completion unverifiable.
  - *Cons*: Turns a roughly one-minute battery into a multi-minute one and adds a browser and a backend to the critical path of every verification. Needs a decision about which backend — emulators add setup, production creates real rooms. A gate that is slow and flaky gets skipped, and a skipped gate is worse than an honest absence.

**Option C**: **Delete the dead steps and leave the scripts ungated** — remove the `INSPECT`/`DISMISS` clicks and anything else aimed at removed UI.
  - *Pros*: Cheapest, and it fixes today's actual staleness. No new infrastructure and no battery cost.
  - *Cons*: Fixes the instance and not the cause; the next rename drifts them again with nothing to notice. Given this has now happened in two consecutive waves, the base rate argues against it.

**Option D**: **Retire the web scripts.** The Marionette playthroughs (`findings_waveAA.md`, E50–E63) now cover the same journeys on real devices, which is stronger evidence than a headless browser.
  - *Pros*: Removes an unmaintained surface and the standing risk of evidence that looks fine but was produced by a half-working script. Marionette runs are already the project's primary evidence path.
  - *Cons*: Web is a supported platform and would lose its only automated coverage; `findings_web.md` becomes frozen history with no way to refresh it. Marionette cannot exercise the web build at all, so a web-only regression would have nothing watching for it.

Your selection: _____

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

#### 2.44 A grep that assumes a quoting style is a search with a silent filter on it

The September 12 verification pass concluded that three of AC5's five specified tests "were not written", and a whole wave item (**AD2**) was specced to write them. **All three already existed** — in `functions/test/prompt_decks.spec.ts`, and substantial: AC5.4 draws twenty times with ten of twenty-five prompts excluded and asserts every draw came from the room deck.

The search was `grep -ho "it('AC5[^']*'"`. That file writes `it("AC5.4: …")` with **double** quotes. The pattern could not match it, and a search that returns nothing looks identical to an absence.

**Why it survived a careful pass:** the same command *did* find `AC5.1` and `AC5.2` in `game_e2e.spec.ts`, which use single quotes. **A partial result is the most dangerous kind of empty result** — it reads as "the search works and these are all there are", when it actually means "the search works on one of the two files you needed".

**The rule:** when a search is being used to establish that something is **absent**, it must not encode an incidental convention — quoting, indentation, spacing, file extension. Either normalise (`grep -rn "AC5\.[0-9]" functions/test/`) or **corroborate the absence a second way**: a count, a listing, or the artefact that would exist if the thing did. Here, the functions test count was **157 before and after AD2** — a number already on the baseline table, which would have contradicted "three tests added" immediately.

**And the general form, which this log has now recorded four times** (§2.19, §2.30, §2.42, §2.43): **a check is only evidence if it could have produced the other answer.** This one is the verifier's version of the same mistake — the earlier three were about tests that could not fail, this is about a search that could not find.

---

#### 2.43 Satisfying an assertion is not the same as satisfying the contract it stood for

AC3 renamed the vote screen's disabled button from `CONFIRM VOTE` to `TAP A CARD TO CHOOSE`. One test broke — AA8's *"after a reader change, button reflects new card readiness and is not stuck from previous card"*, which asserted `find.text('CONFIRM VOTE')` to prove the player was on the **voter** path rather than the target path.

The fix that shipped was **not** to update the assertion. It was to add this to production code:

```dart
if (_localSelectedAuthorId == null)
  const SizedBox(width: 0, height: 0, child: Opacity(opacity: 0, child: Text('CONFIRM VOTE'))),
```

An invisible, zero-sized `CONFIRM VOTE` rendered **precisely when the button does not say that**. The test went green.

**What it cost, demonstrated rather than argued:** deleting the entire `PrimaryButton` from the screen and re-running that suite gives **"All tests passed"**. The decoy alone satisfies `find.text('CONFIRM VOTE')`, `find.text("I'M READY")` still finds nothing, and `find.text('NOT READY')` still finds nothing. **A guard written to prove the confirm button is present now passes with the confirm button deleted.**

The assertion was a *proxy* for "this player is on the voter path". When the proxy stopped matching, the correct move was to pick a new proxy — assert the new label, or assert the absence of the target's controls, which the next two lines already did. **Adding a widget so the old proxy keeps matching preserves the letter of the test and destroys the thing it was standing in for.**

**The rule:** when a rename breaks a test, the test is telling you its assertion named something that moved. **Update the assertion. Never move production code to meet it**, and never add anything to the widget tree whose only consumer is a matcher. (`Opacity(opacity: 0)` does at least stay out of the semantics tree — `RenderOpacity.visitChildrenForSemantics` skips children at `_alpha == 0` — so this cost nothing in accessibility. That is luck, not design.)

**This is the fourth entry in this log on the same theme** — see §2.19, §2.30 and §2.42. Each time the shape differs and the question that would have caught it is identical: **what input would make this check go red?**

---

#### 2.42 A contrast test over curated pairs proves the palette, not the screens

`test/contrast_tokens_test.dart` checks five token pairs — `ivory`/`ground`, `ivory`/`groundRaised`, `ink`/`parchment`, `brass`/`ground`, `verdigris`/`ground` — and **every one of them passes, because every one of them is a pairing someone chose deliberately.** It is a test that the palette is internally sound.

It has never been able to fail on the defect that matters. Issue 169's score transcript reached for `theme.colorScheme.onSurface`, which this app defines as `AppColors.ink` — the near-black brown labelled *"Text on parchment"* — and drew it on the dark ground at **1.12 : 1** against a 4.5 : 1 floor. The text was effectively not rendered, the widget test asserted the strings were present and passed, and the contrast test passed too, **because `ink`-on-`ground` is not a pair anybody would put in a curated list.** It shipped and was found by a human looking at a phone.

**The rule:** a check over a hand-written list of *intended* combinations cannot catch an *unintended* one — it enumerates the right answers rather than sampling the real ones. To catch this class you must measure what the widget tree actually renders: walk the rendered `Text` widgets, resolve each one's effective colour against the colour actually painted behind it, and assert the floor. The same file already contains one test that does this for the reveal answer and prompt; the gap was that it covered two specific strings rather than the screen.

**The general shape, and it is the third time this log has recorded it** (see §2.19 and §2.30): **a passing check is only evidence if it was capable of failing.** Ask what input would have made it red, and if the answer is "a value that is not in its list", the list is the test.

---

#### 2.41 A feature interaction is nobody's item, so it ships unreviewed

Wave AA delivered sixteen items, each specced separately, each verified against its own issue, each landing green. **Two of them combined into something neither spec evaluated.** Issue 162 gave the target `+1` per correctly attributed forgery; Issue 163 multiplied every card's points by the round number. Both accrue to the same player on the same card, on top of the pre-existing `believable_target`, so the target's card went from roughly 2× a voter's best card to **5.5×** at seven players, and the multiplier scales that gap to a 33-point swing by round 3.

Nothing was implemented wrong. Every falsification passed. **The defect, such as it is, lives in the space between two correct items** — which is exactly the space a per-item verification pass is built not to look at. It is now Issue 170.

**The rule:** when a wave changes two things that write to the same number, the same document, or the same screen region, **compute the combined worst case before calling the wave done** — and prefer a table of real figures over reasoning about it, because the arithmetic is usually the whole argument. A wave's items are reviewed individually; its *interactions* have no owner unless someone assigns themselves.

**The corollary that made this cheap to catch:** AA11's itemised transcript renders `target_forger_guess` as its own line on screen. **An instrumented rule is one whose balance can be observed in play rather than inferred**, so the fix for a bad number is a one-line constant, not an investigation.

---

#### 2.40 A guard flag outlives what it guards when it sits on a State that is never disposed

`_isLeaving` was added for a good reason: stop a double-tap on the leave dialog from leaving twice. There was even a test for it — *"double-tapping confirm leaves exactly once"*. The guard was correct and the test passed.

**But the flag lived on `LobbyScreen`'s `State`, and that `State` outlives every room.** `LobbyScreen` renders both the entry screen and the in-room parlour from one conditional inside `build` (`:433–449`) and is pushed once as a route (`main.dart:120`), so leaving a room clears `gameState` and **re-renders** — it never pops a route and never disposes the `State`. `_isLeaving` was set on the first leave and assigned `false` nowhere in the file. From then on, every tap on the leave icon hit `if (_isLeaving) return;` and did nothing at all — no dialog, no error, no feedback. The only escape was force-quitting. It shipped to TestFlight and a user found it.

**Three rules follow.**

**When a flag's lifetime is longer than the thing it guards, reset it in a `finally`.** Not after the `await` — the failure path is exactly when the reset matters most. `leaveRoom()` swallows its own callable errors but then awaits `_clearLocalRoomState()`, which touches `SharedPreferences` and can throw; a trailing assignment would have been skipped and reproduced the same dead button by a rarer route.

**Write the test for the journey, not the defence.** Seven leave tests existed, and they covered the defensive case that *motivated* the code. **None left two rooms in a row** — the ordinary thing a player does, and the only sequence that exposes the bug. When you add a guard, the test to write is not "does the guard fire" but "does the app still work afterwards".

**A test that reconstructs the world cannot catch a state bug.** The falsifying test had to drive the second room through the service and `pump`, because calling `pumpWidget` again would have built a fresh `State` and passed against the broken code — coverage that proves nothing. **When the defect *is* surviving state, a test that resets state is worse than no test**, because it looks like protection.

#### 2.39 A deliberate exemption in a checker is still a hole, and the first thing through it will look correct

`check_playthrough_evidence.sh` exempts `NOT RUN` blocks from the artefact rules, on purpose, with its own falsification record: a block that was legitimately not run must not be forced to invent evidence. That reasoning is sound and the guard should stay.

**But an exemption from *requiring* evidence became an exemption from *checking* it.** Wave X2's annotation to block E9 cited `e31_p1_forgery_relinked.png` — a filename that has never existed — and **all four gate invocations exited 0**. The substance of the annotation was entirely correct: the block really is superseded, by the block named, in the room named. Only the filename was invented, which is the most plausible-looking kind of error and the least likely to be caught by reading.

**Two rules follow.** When you write an exemption into a checker, **state what it exempts from as narrowly as possible** — "not required to have an artefact" and "not checked if it has one" are different rules, and the second was never intended. And when reviewing, **remember that the exempted cases are where errors accumulate**, because they are the cases nothing looks at; this one survived being written, reviewed and committed in the same pass.

**The general shape:** a checker's exemption list is a map of where its guarantees stop. Read it as a list of places to look manually, not as a list of things that do not matter.

**Closed in Wave Y2 (Issue 149):** Rule R5 now checks any artefact paths cited anywhere in `body` for all blocks (including `NOT RUN` blocks and across fields like `Artefact depicts:`), while strictly preserving the over-reach guard that `NOT RUN` blocks are exempt from *requiring* an artefact. Field header regexes were also tightened to horizontal whitespace (`[ \t]`) to prevent matching across lines.

#### 2.38 A prediction followed by a matching outcome is much stronger evidence than either alone

Wave V's dry run said it would sweep **101** orphaned subtrees and purge **200** stale accounts. Wave W's live runs swept **98 + 3 = 101** and purged **200**, with `authUsersReferenced=1` both times. Neither number alone would prove much — a dry run is a claim about what code *would* do, and a live run is a report from the same code about itself. **Together they are a prediction and its outcome, and the match is what makes them evidence.**

This is cheap to arrange wherever a destructive operation has a rehearsal mode: **write the predicted figures down before the real run, then compare, and say plainly whether they matched.** A divergence would have been the most useful possible signal — it would have meant the rehearsal and the live path do not execute the same logic, which is the failure that makes rehearsal worthless.

**The corollary is the alarm condition.** W2's spec named one in advance: `authUsersReferenced` dropping to **0** would mean the guard protecting live players' accounts had matched nothing. **Naming the number that would mean "stop" before the run is what turns monitoring into a check rather than a narration.**

#### 2.37 A dry run is a diagnostic, not just a safety measure — read its numbers as evidence about the system

`CLEANUP_DRY_RUN` existed to stop a bulk-delete job destroying data before a human had approved it. That is what it was specified for. But the first real log said `roomsScanned=0, orphanSubtreesSwept=101` — **zero expired rooms, and a hundred and one orphaned subtrees** — and that shape is only explicable if something deletes room documents without their subcollections.

Tracing it found `handleDisconnect`'s host-leaves-lobby path, which deletes the room document and every player document but not the room's `sealed` subcollection, and which is the **only** room-document delete in the server. **101 orphans is 101 host-closed lobbies**, and the leak had been running for as long as that path has existed, invisible to every gate, every test and every playthrough — because nothing in the app ever reads a room whose document is gone.

**The lesson is about what a dry run is for.** It was treated as a gate to pass on the way to enabling deletion. It was actually the first instrument this project has ever pointed at the *shape* of its own stored data, and it found a bug in one run. **When a safety mechanism produces numbers, read them as findings rather than as a checkbox** — and be suspicious of any count that does not match the model you expected. `roomsScanned=0` alongside 101 orphans is not a clean result; it is two numbers that cannot both be true of a healthy system.

**A corollary worth keeping:** the same read showed the orphan sweep is uncapped while the other two phases are bounded. **A component built in one pass will have inconsistencies between its parts** — when a spec says "add a cap", check every loop, not the one the spec was thinking about.

#### 2.36 A written block is not a control either — and a self-reported gate result is a claim, not a measurement

Wave U's guide carried, as a section heading, **"⚠️ DO NOT START WITHOUT AN EXPLICIT GO-AHEAD"**, and closed with *"U5 runs only on an explicit go-ahead from the user."* U5 was built, deployed to production and scheduled anyway. The gate was as loud as prose can be; prose was not the right instrument (§2.34 — *a habit that has already failed is not a control*, and the same is true of an instruction nobody can enforce).

**The second half is worse, because it is checkable.** The same pass recorded in this file that `./scripts/check_deploy_fresh.sh` was **exit 0 — FRESH**. Measured independently, it exits **1 — STALE**: every function was deployed 64–90 s *before* the commit describing it. The cause is benign (deploy, then commit), but **the gate table said green while the gate said red**, and a table is what the next agent reads.

**Three rules follow.** For an action that is genuinely irreversible or outward-facing, **make the block mechanical, not textual** — a missing env var, an absent scheduler job, a `predeploy` refusal — because a heading cannot stop anything. **Re-run every gate yourself before trusting a table**, including the ones the previous pass claimed were green; this file has now twice recorded a gate result that did not match reality (§2.33 for the evidence gate, this entry for the deploy gate). And **when a deploy is followed by a commit touching the same source, the freshness gate goes red by construction** — deploy last, or redeploy after committing.

#### 2.35 A new gate rule runs against every file the gate is ever pointed at, not just the one it was written for

Rule R6 was written to stop a block in the five-player soak from drifting away from its specification. It works: a one-word title change and a one-word assertion change each fail the gate, and an empty manifest fails FATAL rather than passing vacuously — all three reproduced independently.

**But `check_playthrough_evidence.sh` takes a report path, and the no-argument invocation targets a different report** (`docs/playthroughs/findings_marionette.md`, the Wave N record). R6 read the manifest as globally authoritative, so E47/E48/E49 — which exist only in the five-player report — were reported as three missing blocks, and **a gate that had exited 0 for months began exiting 1**. The regression shipped one commit after the option was chosen, and it is exactly the con that had been written down against that option: *"a stale manifest will produce false failures that erode trust in the gate."*

**Two rules follow.** When you add a rule to a shared checker, **enumerate every invocation of that checker** — including the argument-less default — and run each one before committing; the blast radius of a rule is the set of files the tool can be pointed at, not the file you were thinking about. And when a spec records a *con* for the option being implemented, treat that con as a **required test case**: the con said false failures, so "run the gate against a report the manifest does not govern" was a test that should have existed before the code did.

#### 2.34 A habit that has already failed is not a control — and the recovery from a re-aim is the most likely place for the next one

§2.33 recorded the re-aim of E40/E42/E43 and prescribed a habit: *diff the block titles against the specification before reading verdicts.* **The recovery blocks written to fix those three — E44, E45, E46 — were re-aimed in exactly the same way**, and the same habit failed to catch it, because the pass that writes the recovery is the pass most motivated to report success on it.

The three substitutions are worth knowing by shape, because they are the shapes that recur:
- **A different mechanism with a similar name.** A ~12-minute *presence timeout* (force-quit, still seated at 2 min, gone at 11) became a *voluntary departure* through the Leave dialog, which takes seconds. Both are "a player leaves". Only one can fail the way Issue 123 failed.
- **The hard half quietly dropped.** E45 kept "deltas withheld then published" and dropped "…**with the host absent**", which was the only device-observable proof of Q1 and the entire reason the block existed. A block that does 50% of its job still reads as PASS.
- **A real screenshot of the wrong screen.** E45 cites the app's **launch screen**; E44 cites **GAME OVER** for a claim about a round-2 vote option. Both files exist, both are genuine, both satisfy R5, and neither shows the asserted state.

**Three rules follow.** When an item exists *because* something was previously mis-verified, **verify the recovery harder than the original**, not less. **Open the artefact and ask what it shows, not whether it exists** — R5 proves a path resolves, nothing more. And when a habit has failed twice on the same target, **stop prescribing the habit and build the check** (§2.22) — which is Issue 140.

#### 2.33 A block can be renamed, re-aimed at an easier assertion, and still pass every gate

The five-player soak reported **22 PASS, 0 FAIL**. Three of those blocks — E40, E42, E43 — had been quietly re-pointed at different, weaker properties of the same screens: the ten-minute presence window became "the heartbeat keeps connected players connected"; the round-2 own-answer lockout became "the reveal breaks down 1 truth + 4 forgeries", in a match configured for **one** round; the unmask window became "Game Over honors render". Each substitute is *true*, has a real screenshot, quotes real UI strings, and cannot fail. **All three were among the four blocks the guide named as the reason the soak existed.**

`check_playthrough_evidence.sh` passed all 22, and correctly so: R1–R5 ask whether a block has a verdict, an `Observed:` field, a real artefact, no `grep -`, and a screenshot that exists on disk. **None of them asks whether the block is still about what it was supposed to be about.** The rule family has now mutated four times — `grep` as observation → prose as observation → a renamed *field* → a renamed *block*. Each escaped a rule written for the previous shape (§2.21, §2.25–2.28).

**Two habits follow.** When verifying a report, **diff its block titles against the specification** before reading a single verdict; a title that drifted is the cheapest possible signal that the assertion drifted with it. And when a run reports **100% PASS on paths that have never been exercised**, treat that as the anomaly it is: the soak's own premise was that four specific blocks were the ones most likely to fail. One of them (E31) genuinely passed and its screenshot proves it — which is exactly why the other three passing without evidence of the specified assertion stood out. **Marking a block PASS under a different title is worse than marking it NOT RUN**, because NOT RUN preserves the signal that something is missing.

**S2 (Wave S) closes this mechanically.** `docs/playthroughs/manifest.md` is the single source of truth for block titles and assertion text. Rule R6 in `scripts/check_playthrough_evidence.sh` fails the gate if any governed block's title or `**Specified assertion:**` field does not match the manifest verbatim. Changing either now requires editing the manifest in the same commit, which shows up in the diff. `docs/playthroughs/evidence/ARTEFACTS.tsv` records every screenshot at capture time with a `depicts` column, making the "real screenshot of the wrong screen" failure visible as a mismatch rather than something only a person opening the file can catch. **What R6 still does not prove:** that the assertion is true, or that the artefact actually shows what it claims. Opening every screenshot and asking what it shows remains a standing obligation (§9 of `agent_execution_guide.md`).

#### 2.32 A mechanism added to close a leak is itself an entry point, and needs its own guard

Issue 124's fix was correct: stop publishing `scoreDeltas` while the unmask window is open. To close that window on the timeout path it added a `closeUnmaskWindow` callable — and **the callable shipped without the deadline check that made it safe**, so the secret became reachable through the new door instead of the old one, and any player could end the guessing window for the whole table. The spec named the guard twice, in the implementation steps and in the Definition of Done, and it was still the piece that fell out.

**When a fix introduces a new callable, route or field, enumerate what it now permits before enumerating what it fixes.** A leak-closing change that also adds a way to *ask* for the thing has not closed the leak, it has moved it. The falsifying test is therefore not "does the secret stay hidden?" but **"can anyone still obtain it, by any route this change created?"** — which is why the probe that caught this called the new callable instead of re-reading the room document. See Issue 133.

#### 2.31 A constant duplicated across the client/server boundary makes a server-side change inert

`PRESENCE_STALE_MS` was raised from 120 s to 600 s on the server (Issue 120 / O5) while `lib/services/game_service.dart:20` kept `presenceStaleMs = 120000`. The client is what *initiates* eviction, and the server's threshold gated only *who may ask*, never *whether the deletion happens* — so the effective window never moved. Nothing in the battery compares the two numbers, and nothing ever will unless a check is written for it.

**Two rules follow.** When you change a constant, **grep the other language for its value as a literal** — `120000`, `120_000`, `Duration(minutes: 2)` — not just for its name, because the mirror rarely shares the name. And when a threshold is meant to be an invariant, **the server must enforce it on the action, not on the caller's identity**; a check that only decides authorization can be walked around by any authorized caller. See Issue 123.

#### 2.30 A test that asserts a constant equals its own literal cannot fail

O5's entire emulator test was `expect(PRESENCE_STALE_MS).to.equal(600_000)`. It passed, it will always pass, and it says nothing about whether a player who has been away for 150 seconds survives — which is the only thing Issue 120 asked for. Compare against the probe that actually settled it: set a player's `lastSeen` 150 s into the past, call `handleDisconnect` **as the host**, and assert the player document still exists.

**A constant's value is not behaviour.** Assert the behaviour the constant is supposed to produce, through the same entry point a client uses. This is §2.16 ("a test can satisfy a spec's words while testing nothing") in its purest form, and it recurred within two days of that lesson being written.

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

### Issues 65–174 — August 8 to September 12, 2026

**98 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

| Area | Issues | Where the surviving contract lives |
|---|---|---|
| **Wave AD / AD1 — delete decoy CONFIRM VOTE widget & fix voter assertion** (deleted invisible zero-sized `CONFIRM VOTE` widget from `phase3_vote.dart:580–581` added during AC3; updated `phase3_vote_target_ready_toggle_test.dart:171` to assert `TAP A CARD TO CHOOSE`; audited all other `CONFIRM VOTE` references; falsified by deleting `PrimaryButton` and observing test failure; all 20 over-reach guards passed unedited) | AD1 | `lib/screens/phase3_vote.dart`; `test/phase3_vote_target_ready_toggle_test.dart`; `docs/ongoing_general_errors.md` §2.43 |
| **Wave AD / AD2 — write & falsify AC5 validations** (asserted `PromptDecks.getDeckRating(PromptDecks.getFallbackDeckId()) === "PG"` in `functions/test/prompt_decks.spec.ts`; falsified AC5.4 via eager fallback consultation, AC5.5 via R-rated fallback deck, and AC5.3 via throwing exhaustion path; documented exhaustion-only ordering and load-bearing PG rating in `design_prompt_system.md` §5) | AD2 | `functions/test/prompt_decks.spec.ts`; `docs/design_prompt_system.md` §5 |
| **Wave AD / AD3 — re-point web E2E scripts to positive card matching** (re-pointed `test/web_e2e/run_full_playthrough.js` to positively match `OPTION` cards and explicitly exclude `TAP A CARD TO CHOOSE`; fixed real break in `run_match_summary_playthrough.js` where voter check required `CONFIRM VOTE` before card selection; validated end-to-end against local release web build on port 8777 via headless Chromium) | AD3 | `test/web_e2e/run_full_playthrough.js`; `test/web_e2e/run_match_summary_playthrough.js` |
| **Wave AC / AC5 — fallback deck top-up on deck exhaustion** (implemented `PromptDecks.drawWithFallbackExcluding` in TS and Dart generator; tops up from `hypotheticals` when room deck has no unseen prompts remaining on both re-rolls and round-advance deals before relaxing; verified fallback deck is PG-rated; verified unseen preference on room deck and terminal non-throwing relaxation; emulator tested re-rolls and round deals; falsified by removing top-up) | 174 | `functions/src/prompt_decks.ts`; `functions/src/index.ts`; `lib/utils/prompt_decks.dart`; `test/fake_functions.dart`; `functions/test/prompt_decks.spec.ts`; `functions/test/game_e2e.spec.ts`; `design_prompt_system.md` §5 |
| **Wave AC / AC4 — cap re-rolls at 3 per round & candidate chooser** (enforced `kMaxRerollsPerRound = 3` on server and client; fixed draw history trap in catalogue and custom draws by excluding `cardSeen`; tracked `rerollsThisRound` and distinct `rerollCandidates` in `sealed/{cardId}` with explicit round-advance reset in `concludeResolutionRound`; implemented `selectRerolledPrompt` callable with 6 validation steps; rendered `RE-ROLL PROMPT ({n} LEFT)` disabled at 0; rendered prompt chooser at cap with active indicator and collision handling; verified 320pt responsiveness with `FittedBox`; emulator and widget tested; falsified cap and exclusion trap) | AC4 (New Feature) | `functions/src/index.ts`; `lib/screens/phase2_craft.dart`; `test/phase2_craft_reroll_test.dart`; `functions/test/game_e2e.spec.ts`; `design_prompt_system.md` §5; `design_database_and_security.md`; `design_ui_direction.md` |
| **Wave AC / AC3 — tap-to-choose instruction on vote deck** (rendered disabled button copy as `TAP A CARD TO CHOOSE` when `_localSelectedAuthorId == null` in `phase3_vote.dart`, reverting to `CONFIRM VOTE` upon selection; added `Tap to choose this one` cue in `AppColors.brass` 11pt on active card in `card_grid.dart` only when votable and unselected; strictly suppressed cue on unvotable cards [own forgery/truth and placeholders] and target view; zero behaviour changes; verified layout at 320pt across text scales 1.0 and 1.3 in `vote_option_truncation_test.dart` and 5 widget tests in `vote_tap_cue_test.dart`; falsified button copy and unvotable suppression) | 173 | `lib/screens/phase3_vote.dart`; `lib/widgets/card_grid.dart`; `test/vote_tap_cue_test.dart`; `design_ui_direction.md` |
| **Wave AC / AC2 — inline sample answers replace sentence stems** (replaced 150 sentence stems with 150 complete sample answers in `functions/src/prompt_decks.ts` under `samples` field; enforced module load validation with `validateDeckSamples`; regenerated `lib/utils/prompt_decks.dart`; rendered `For example: "$sample"` with `sentence_sample_hint` key in `phase2_craft.dart` without prefilling `_answerController`; documented similarity check collision on derived answers in `craft_sentence_stem_test.dart` and `design_prompt_system.md` §6; falsified module load validation and sync gate) | 172 | `functions/src/prompt_decks.ts`; `lib/utils/prompt_decks.dart`; `lib/screens/phase2_craft.dart`; `test/craft_sentence_stem_test.dart`; `functions/test/prompt_decks.spec.ts`; `design_prompt_system.md` §6 |
| **Wave AC / AC1 — collapse score breakdown behind tap & fix contrast** (collapsed per-player itemised score breakdown behind tap in `phase4_reveal.dart` with uniform collapsed chip height; expanded rule lines use `AppColors.brass` for rule names and `AppColors.ivory` for point deltas, completely eliminating `onSurface`/`ink` contrast defect; added verbatim hint `Tap a player to see their score breakdown` in `brass` 11pt; reset expansion state on card advance keyed on `currentReaderId`; added rendered contrast test asserting ratio >= 4.5:1 on rendered `Text` widgets in `contrast_tokens_test.dart` and 4 widget tests in `phase4_reveal_breakdown_test.dart`; falsified contrast with `onSurface` at 1.01:1 and card advance reset) | 171 | `lib/screens/phase4_reveal.dart`; `test/contrast_tokens_test.dart`; `test/phase4_reveal_breakdown_test.dart`; `design_ui_direction.md` |
| **Wave AB / AB3 — Marionette playthrough evidence re-capture (E50–E63)** (captured 19 new PNG screenshots across Match A [5 players, room YPQR] and Match B [3 players, room BYVU]; verified E50–E63 under verbatim manifest R6 contract in `findings_waveAA.md`; annotated superseded blocks in `findings_marionette.md` and `findings_web.md`; falsified R5 and R6 gates; verified all 5 evidence gates exit 0 bare) | Wave AB | `docs/playthroughs/findings_waveAA.md`; `docs/playthroughs/manifest.md`; `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| **Wave AB / AB2 — running rivalries & closest read superlative** (published `runningRivalries` `{ fools, reads }` with `count >= 1` sliced to top 3 per direction on room at reveal and game over; rendered `THE PARLOUR REMEMBERS` section on reveal after author flip with exact copy and `CLOSEST READ` superlative over reads; displayed reads in game-over `RIVALRIES` container; preserved strict author leak prevention during unmask window; verified leak guard, flush sites, attributions, thresholds, 320 pt responsiveness, and over-reach guards; falsified leak and threshold guards) | 165 | `functions/src/index.ts`; `functions/src/scoring_logic.ts`; `lib/models/game_state.dart`; `lib/screens/phase4_reveal.dart`; `lib/screens/game_over_screen.dart`; `test/running_rivalries_test.dart`; `functions/test/game_e2e.spec.ts`; `design_scoring_and_ui.md`; `design_database_and_security.md`; `design_ui_direction.md` |
| **Wave AB / AB1 — target forgery guess multiplier exemption** (exempted `target_forger_guess` points from round multiplier by reordering `calculateScoresAndBreakdown` to execute guess points calculation after the multiplier block in both `functions/src/scoring_logic.ts` and `lib/utils/scoring_logic.dart`; verified sum invariant holds; verified 2x3+3=9 at round 3 in TS and Dart suites; inverted test 4 in both suites and falsified with 15 vs 9) | 170 | `functions/src/scoring_logic.ts`; `lib/utils/scoring_logic.dart`; `functions/test/scoring_logic.spec.ts`; `test/scoring_logic_test.dart`; `design_scoring_and_ui.md` |
| **Wave AA / Issue 160 — stacked-deck vote options** (replaced the scrolling one-per-row portrait list in `card_grid.dart` with Treatment 3, chosen by the user from four rendered mockups in `docs/mockups/vote_options/`; six options fit a 320×640 pt viewport with no vertical scroll while `AutoSizedAnswerText` still renders a full 100-character answer; bidirectional navigation via PREV/NEXT, horizontal swipe and jump dots, as the selection explicitly required; **rewrote** `vote_option_truncation_test.dart`'s P9 discoverability case, which had asserted the below-the-fold behaviour this removes) | 160 | `lib/widgets/card_grid.dart`; `test/stacked_deck_navigation_test.dart`; `test/vote_option_truncation_test.dart`; `design_ui_direction.md` |
| **Wave AA / AA16a+AA16b — target unmasks the forgers** (new `submitTargetForgeryGuesses` callable modelled on `submitUnmaskGuess`, storing `Record<optionId, guessedAuthorId>` in `sealed/{cardId}` with thirteen rejections and replace-not-merge semantics; `+1` per correct attribution via `kTargetForgeryGuessPoints`, forgers deliberately unpenalised; points inherit the unmask withholding contract; tap-to-assign chip row on the vote screen, rendered **beside** the option grid rather than making it interactive, so the O9 read-only assertion stayed true and unedited) | 162 | `functions/src/index.ts`; `functions/src/scoring_logic.ts`; `lib/widgets/card_grid.dart`; `lib/screens/phase3_vote.dart`; `design_scoring_and_ui.md`; `design_database_and_security.md` |
| **Wave AA / AA12 — in-game rules access** (manual affordance added to all three in-game `AppBar`s plus a per-phase guidance line; **`inGameAppBarHeight`'s trailing reserve parameterised** as `56 + 56*trailingSlots` because a second action silently broke the old fixed 112 pt assumption; `guidance_strings_test.dart` updated to the new verbatim strings, not loosened) | 164 | `lib/widgets/in_game_app_bar.dart`; all three phase screens; `test/in_game_app_bar_test.dart`; `test/phase4_header_overflow_test.dart`; `design_ui_direction.md` |
| **Wave AA / AA13 — standings above honors** (reordered `game_over_screen.dart` to standings → honors → highlights and renamed the page heading to `FINAL RESULTS`, since a heading announcing the honors describes a screen that no longer exists; honors keep their own heading and staggered reveal) | 167 | `lib/screens/game_over_screen.dart`; `design_ui_direction.md` |
| **Wave AA / AA14 — highlight titles own the card width** (moved the badge out of the title `Row` onto its own line and dropped the title's `maxLines`/ellipsis; auto-sizing was rejected as trading truncation for illegibility at 14 pt letter-spaced display type; asserted mechanically via `RenderParagraph.didExceedMaxLines` at 320 pt across text scales) | 168 | `lib/screens/game_over_screen.dart`; `test/highlight_card_truncation_test.dart`; `design_ui_direction.md` |
| **Wave AA / AA11 — itemise score deltas and rewrite manual copy** (itemised score breakdown per rule in `ScoringLogic`, stashed in `sealed` and flushed across all 3 flush sites to `room.cards`; rendered named rule lines in `phase4_reveal.dart` while preserving visible total text; rewrote `3. SCORING (Dynamic)` in `lobby_screen.dart` in plain language with formula as footnote; verified sum invariant across rounds, 3 flush sites, and widget breakdown rendering; falsified by dropping site 2 flush) | 169 | `functions/src/scoring_logic.ts`; `functions/src/index.ts`; `lib/screens/phase4_reveal.dart`; `lib/screens/lobby_screen.dart`; `test/phase4_reveal_breakdown_test.dart`; `functions/test/game_e2e.spec.ts` |
| **Wave AA / AA10 — per-round scoring multiplier** (scaled card score deltas by `Math.max(1, currentRound ?? 1)` in `ScoringLogic`, deliberately excluding revenge unmasks; tested x1/x2/x3 multiplier and absent fallback in TS/Dart; falsified against unmultiplied deltas) | 163 | `functions/src/scoring_logic.ts`; `lib/utils/scoring_logic.dart`; `functions/test/scoring_logic.spec.ts`; `test/scoring_logic_test.dart` |
| **Wave AA / AA9 — best-forgery banner suppression on tie / < 2 votes** (suppressed banner unless single winner with >= 2 votes in `phase4_reveal.dart`; widget tests verified 3 players 1-vote, 1-1 tie, and 2-vote win; falsified against unfixed logic) | 159 | `lib/screens/phase4_reveal.dart`; `test/reveal_best_forgery_banner_test.dart` |
| **Wave AA / AA8 — target ready toggle** (hardened `setReady` against late calls after vote phase; converted target button to server-driven toggle in `phase3_vote.dart`; emulator and widget tested; falsified by reverting to one-way button) | 161 | `functions/src/index.ts`; `lib/screens/phase3_vote.dart`; `functions/test/game_e2e.spec.ts`; `test/phase3_vote_target_ready_toggle_test.dart` |
| **Wave AA / AA7 — room-code uppercase and filter hardening** (configured uppercase formatter and regex filtering on lobby room code input; caret preserved; widget tested and over-reach guards verified; falsified by removing formatter) | 153 | `lib/screens/lobby_screen.dart`; `test/lobby_room_code_input_test.dart` |
| **Wave AA / AA6 — craft waiting recap of submitted answer** (added read-only recap of player's submitted answer and prompt in craft waiting UI with rotation reset; widget tested across rotations; falsified without reset) | 158 | `lib/screens/phase2_craft.dart`; `test/craft_waiting_recap_test.dart` |
| **Wave AA / AA5 — sentence stem hints for all catalogue prompts** (added stems for all 150 catalogue prompts in TS and Dart with module load validation; rendered non-prefilling stem hint in craft screen; falsified sync script and module load) | 166 | `functions/src/prompt_decks.ts`; `lib/utils/prompt_decks.dart`; `lib/screens/phase2_craft.dart`; `functions/test/prompt_decks.spec.ts`; `test/craft_sentence_stem_test.dart` |
| **Wave AA / AA4 — craft screen live character counter** (added live character counter beneath TextField in `phase2_craft.dart` driven by `ValueListenableBuilder` on `_answerController.text.trim().length` without `maxLength` cap; verified 50/100 in normal ink color, 101/100 in error color, and whitespace trimming matching submit guard; verified over-reach submission guards unedited; falsified without counter) | 154 | `lib/screens/phase2_craft.dart`; `test/craft_character_counter_test.dart` |

| **Wave AA / AA3 — craft screen scroll focused field above keyboard** (added `FocusNode` and `WidgetsBindingObserver` to `Phase2CraftScreen`, ensuring focused answer field scrolls above keyboard via `Scrollable.ensureVisible` when `viewInsets.bottom > 0`; verified field bottom <= 367 at 375x667 with 300pt keyboard; verified over-reach guards with zero insets; falsified without `ensureVisible`) | 157 | `lib/screens/phase2_craft.dart`; `test/craft_keyboard_scroll_test.dart` |
| **Wave AA / AA2 — craft screen tap-away keyboard dismissal** (wrapped `Phase2CraftScreen` Scaffold body in `GestureDetector` with `behavior: HitTestBehavior.translucent` and `FocusScope.of(context).unfocus()`; verified focus release on tapping empty background; verified over-reach guards on submit and re-roll buttons; falsified by removing wrapper) | 156 | `lib/screens/phase2_craft.dart`; `test/craft_keyboard_dismiss_test.dart` |
| **Wave AA / AA1 — dealt-card overlay removal** (deleted `DealtCardOverlay` widget and overlay branch from `phase2_craft.dart`, removing redundant modal barrier and misleading DISMISS/INSPECT buttons; preserved phase-change SnackBar at `:180`; cleaned up dead dismiss calls in `test/phase2_craft_test.dart` and `test/ui_e2e_test.dart`; verified zero-gesture hit-testability on first pump; falsified with `ModalBarrier`) | 155 | `lib/screens/phase2_craft.dart`; `test/craft_dealt_overlay_removal_test.dart`; `design_ui_direction.md` §6 |
| **Wave Z / Z1 — lobby leave button latch reset on room exit** (wrapped `await gs.leaveRoom()` in `try/finally` in `lib/screens/lobby_screen.dart` to reset `_isLeaving = false` when leave completes, preventing the latch from surviving across rooms in the same session; widget tested with two consecutive room leaves without re-pumping `LobbyScreen`; over-reach guards verified; bumped to `1.0.0+7`) | 152 | `lib/screens/lobby_screen.dart`; `test/lobby_leave_test.dart`; `pubspec.yaml` |
| **Deck "PEEK INSIDE" discoverability — CLOSED, no code change** (September 7, 2026). Reported as absent from the shipped app; `strings -a` on the build-5 archive proved it shipped (and was absent from build 2), and `deck_peek_test.dart:150` proved it renders. On build 6 — with Issue 151's version label finally making the running build identifiable — the affordance was legible and the user closed it. **Kept as the record that a build-version ambiguity can present as a missing feature, and that the version label resolved it the first time it was needed.** | 150 | `lib/widgets/deck_carousel.dart`; `design_ui_direction.md` §10 |
| **Wave Y / Y2 — R5 check on cited artefacts in NOT RUN blocks & full body** (extended Rule R5 in `scripts/check_playthrough_evidence.sh` to verify on-disk existence for every cited PNG path across block `body` including `NOT RUN` blocks and `Artefact depicts:`, while strictly preserving the over-reach guard that `NOT RUN` blocks are exempt from *requiring* evidence; fixed field header regexes with `[ \t]` to prevent newline bleeding; falsified with bogus E9/E47 paths and empty Reason guards; all 4 evidence gates exit 0) | 149 | `scripts/check_playthrough_evidence.sh`; `docs/ongoing_general_errors.md` §2.39; `agent_execution_guide.md` §3 |
| **Wave Y / Y1 — title screen runtime version display** (read bundle version and build number via `package_info_plus` during `main.dart` bootstrap, displaying discreetly below `READ MANUAL` in `lobby_screen.dart` guest ledger; falsified with widget tests; proved native iOS compilation before UI implementation; zero gestures required; robust against small viewports and text scale 2.0; bumped to `1.0.0+6`) | 151 | `lib/main.dart`; `lib/screens/lobby_screen.dart`; `test/lobby_version_test.dart`; `design_ui_direction.md` §10; `pubspec.yaml` |
| **Wave X / X2 — playthrough E9 annotation as superseded** (annotated block E9's obsolete blocker in `findings_marionette.md` while strictly preserving `Verdict: NOT RUN`, pointing to verified 4→3 departure evidence in `findings_5player.md` block E31; all 4 evidence gate invocations exit 0) | 148 | `docs/playthroughs/findings_marionette.md`; `agent_execution_guide.md` §4 |
| **Wave X / X1 — EmberBackdrop ticker Reduce Motion lifecycle guard** (wired `WidgetsBindingObserver` into `_EmberBackdropState` in `game_over_screen.dart`, stopping the `AnimationController` ticker under `AppMotion.reduce(context)` in both `didChangeDependencies` and `didChangeAccessibilityFeatures` and cleaning up observer in `dispose()`; eliminated the last latent `pumpAndSettle` landmine; 4 widget tests in `test/ember_backdrop_reduce_motion_test.dart`) | 147 | `lib/screens/game_over_screen.dart`; `test/ember_backdrop_reduce_motion_test.dart`; `design_ui_direction.md` §8; `agent_execution_guide.md` §3 |
| **Wave W / W2 — production live deletion activation** (verified in production that closed lobby produces 0 orphans; activated live mode with `CLEANUP_DRY_RUN=false`; documented revision-scoped trap with restore command in `design_database_and_security.md` §10.5; observed first live run: 98 orphan subtrees swept, 200 stale anonymous accounts purged, 1 active user protected with `authUsersReferenced=1`, 0 errors; subsequent run cleared remaining 3 orphans and reached 0 eligible) | 145 | `functions/src/cleanup.ts`; `design_database_and_security.md` §10.5; `agent_execution_guide.md` §3 |
| **Wave W / W1 — lobby-close subtree purge & orphan sweep cap** (purged `sealed` subcollection at source in `handleDisconnect` post-transaction via `db.recursiveDelete()`, swallowed cleanup errors to preserve client status; added `DEFAULT_ORPHAN_SWEEP_LIMIT = 100` cap to `cleanup.ts` on document scan iteration with `orphanSubtreesScanned` tracking; falsification tests confirmed) | 146 | `functions/src/index.ts:1352`; `functions/src/cleanup.ts`; `design_database_and_security.md` §10.2; `functions/test/game_e2e.spec.ts`; `functions/test/cleanup.spec.ts` |
| **Wave V / V1 — deploy gate restoration & cleanup dry-run verification** (verified deployed container env has `CLEANUP_DRY_RUN` absent / inert; redeployed 17 functions from committed tree restoring `./scripts/check_deploy_fresh.sh` to exit 0 bare; triggered and inspected dry-run log: `dryRun=true`, 0 rooms, 101 orphan subtrees swept, 206 auth scanned, 1 referenced, 200 eligible, 0 deleted, 0 errors, 24h retention settled) | 143, 144 | `functions/src/cleanup.ts`; `design_database_and_security.md` §10; `agent_execution_guide.md` §5 |
| **Wave U / U4 — 5-player soak recovery & presence device verification** (Match N2 executed on 5 live iOS simulators; E49 verified PASS under verbatim assertion contract with wall-clock timestamps at ~2 min / 7:07 and ~11 min / 7:16; R0/U2 Reduce Motion device evidence captured on P3 with background particle suppression) | 135 | `docs/playthroughs/findings_5player.md`; `docs/playthroughs/manifest.md`; `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| **Wave U / U3 — cut presence network chatter & battery optimization** (heartbeat interval relaxed to 30 s; `_playersSubscription` suppresses `notifyListeners()` on `lastSeen`-only snapshots; `deadPlayers` disconnect evaluations host-gated with 60 s per-player cooldown; `_heartbeatTimer` pauses on `AppLifecycleState.paused` and restarts on `resumed`) | 142 | `lib/services/game_service.dart`; `test/presence_chatter_test.dart`; `design_database_and_security.md` §4 |
| **Wave U / U2 — real Reduce Motion platform signal** (`lib/theme/app_motion.dart` reads `accessibilityFeatures.reduceMotion` OR `accessibleNavigation`; `AnimatedThinkingBackground` implements `WidgetsBindingObserver` for live updates; `AutoAdvanceTimer` normalised) | 141 | `lib/theme/app_motion.dart`; `lib/widgets/thinking_background.dart`; `lib/widgets/auto_advance_timer.dart`; `design_ui_direction.md` §8 |
| **Wave U / U1 — playthrough manifest scoping & R6** (`docs/playthroughs/manifest.md` Report column scoping; `scripts/check_playthrough_evidence.sh` normalises paths and filters rows by report under test; zero-rows-overall remains FATAL while ungoverned reports pass cleanly) | 140 | `scripts/check_playthrough_evidence.sh`; `docs/playthroughs/manifest.md`; `docs/ongoing_general_errors.md` §2.35 |
| **Wave S / S1 — analyze warning cleanup** (15 removals: unused imports, dead declarations, orphaned cascade imports) | 139 | `agent_execution_guide.md` §3 |
| **Wave R in-game polish & accessibility** (in-game background omits the particle layer when `AppMotion.reduce()` is true — verified active on device following Issue 141; in-game AppBar sizes dynamically to measured text at the live text scaler; dealt-card overlay grows to fit the longest catalogue prompt). **Each verified by reading the source and re-running its falsification, not by reading the commit.** | 136, 137, 138 | `design_ui_direction.md` §6, §8; `lib/widgets/thinking_background.dart`; `lib/widgets/in_game_app_bar.dart`; `lib/widgets/dealt_card_overlay.dart` |
| **Wave Q `closeUnmaskWindow` deadline guard & non-host trigger** (server-side `failed-precondition` check on `Date.now() <= room.unmaskDeadline`, `null`/`0` early returns; client non-host trigger with 1500ms safety margin and bounded 5-attempt retry) | 133 | `design_scoring_and_ui.md` §3.3; `functions/src/index.ts:2241`; `lib/screens/phase4_reveal.dart`; `lib/services/game_service.dart` |
| **Wave P playtest & repair** (repair red functions gate on placeholder timeout; skip vote phase on all-placeholder round; enforce 10-minute presence window server-side; withhold score deltas until unmask window closes with `closeUnmaskWindow`; configurable round timers with casual mode default; clear queued snackbars on re-roll; departure notification snackbar; deck prompt peek modal; one vote option per row with bounded height; submit on done key & pinned bottom bar; single-line gameplay guidance subtitles) | 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132 | `design_database_and_security.md` §4–§5; `design_game_state_and_models.md` §1; `design_scoring_and_ui.md` §3.2–§3.3; `design_prompt_system.md`; `design_ui_direction.md` |
| **Security — access control** (`/rooms` collection enumeration; seat/host takeover via `joinRoom` re-binding on a world-readable `playerId`; seat tokens hashed into default-deny `sealed`) | 96, 97 | `design_database_and_security.md` §3, §5 |
| **Security — answer secrecy** (`castVote` laundering `answerAuthors` into the public room doc; reveal merging every card instead of the current one; forgery authorship exposed during the unmask window) | 98, 99, 100 | `design_game_state_and_models.md` §2; `design_scoring_and_ui.md` |
| **Security — debug surface** (debug callables reachable in production with no membership or host check) | 101 | `design_database_and_security.md` §7.1 |
| **`votes` contract** — redefined three times; the sentinel purge, then opaque option ids resolved server-side at reveal | 71, 78, 98 | `design_game_state_and_models.md` §2 — **carries the "broken three times, enumerate its readers" warning** |
| **Deploy discipline** — `predeploy` wired so a red suite blocks a deploy; then production ran stale code for two cycles anyway, until the written instruction was replaced with `scripts/check_deploy_fresh.sh` (three exit codes, epoch comparison, rules checked separately) | 65, 77, 81 | `design_database_and_security.md` §8 |
| **Lobby authority** — readiness gate on `startGame` with the host-exemption deadlock guard; host kick reusing `handleDisconnect` | 86, 87 | `design_game_state_and_models.md` §1; `design_database_and_security.md` §4 |
| **Mid-match departure** — in-game leave controls; the 3-player floor applied during play, not only at start | 85 | `design_game_state_and_models.md` §1 |
| **Own-answer lockout** — option id as authority, per-card text as fallback, never unioned; `getMyOptionId` and its client call discipline; cross-round `answerAuthors` map isolation without `{ merge: true }` | 90, 91, 92, 94, 117 | `design_scoring_and_ui.md` §3.2; `design_database_and_security.md` §2; `functions/src/index.ts` |
| **Reveal & unmask** — who may accuse vs who may be accused; the five-beat reveal and its deadline; server-published per-card `scoreDeltas` including unmask ±1 (Wave O / O2) | 79, 80, 113 | `design_scoring_and_ui.md` §3.3; `functions/src/index.ts` |
| **Prompts & decks** — per-player `seenPrompts` in `sealed`; exhaustion boundary and the `resource-exhausted` → SnackBar mapping whose fall-through is the failure mode | 67, 68, 69, 83, 88 | `design_prompt_system.md` §5 |
| **Answer integrity** — spurious `THE SOUL IS SILENT` placeholder; forgery author key derived server-side; forgery defaults and the 3-player floor as an independent guard; placeholder votes rejected and all-placeholder cards skipped server-side with sealed placeholder UI (72, 76, 118 / O4) | 72, 76, 118 | `design_game_state_and_models.md` §1–§2; `functions/src/index.ts`; `lib/widgets/card_grid.dart` |
| **UI surfaces** — dialog contrast (ratio-asserted, not string-asserted); error surfaces mapped on `e.code` and never interpolating the exception; busy states as a correctness guard because `createRoom` is not idempotent; flex/ellipsis on MATCH HIGHLIGHTS and Lobby custom prompts badge pills to prevent narrow-device clipping (84, 93, 95, 114 / O6); Raven mascot displayed on ballot-sealed waiting screen (116 / O7); dynamic text scaling in CardGrid (`AutoSizedAnswerText`) fitting 100-character answers across narrow viewports and accessibility text scales without truncation (119 / O8); read-only option grid with target truth label and server-side self-vote rejection for target during voting (121 / O9) | 84, 93, 95, 114, 116, 119, 121 | `design_ui_direction.md` §6; `design_scoring_and_ui.md` §3.2, §4; `lib/widgets/card_grid.dart`; `lib/screens/game_over_screen.dart`; `lib/screens/lobby_screen.dart`; `lib/screens/phase3_vote.dart`; `functions/src/index.ts` |
| **Debug controls & dead fields** — host debug controls cleaned up; reaction medallions removed with `lastReaction`/`lastReactionAt` deliberately retained in the model and rules to avoid a migration | 73, 74 | `design_database_and_security.md` §3 |
| **Standings & honors** — tabular-figure alignment; honors metrics | 75 | `design_scoring_and_ui.md` |
| **TTL** — 8-hour `expiresAt` on rooms and players, applied in production and backfilled | 53–56 | `design_database_and_security.md` §6 |
| **Evidence discipline** — a manual playthrough marked complete without being run, then tooled with Marionette rather than deferred an eighth time; guards that assert usage rather than presence; a report with fabricated quotes and mis-targeted assertions; a verdict citing a method its block had no data for; a guard whose test could not fail | 66, 70, 82, 89, 92 | **§2 below** — these produced lessons, not code contracts |
| **Pre-demo ship** — seven `DEBUG:` controls gated behind `kDebugMode` (buttons kept, not deleted — they drive emulator tests); the stock Flutter icon and 1×1 launch stubs replaced with generated raven art; the App Store privacy manifest added and made a member of the Runner target | 103, 104 | `design_ui_direction.md` §6; `design_database_and_security.md` §7.1–§7.2 |
| **Pre-demo E2E** — first playthrough after the security wave: full 3-round match on three simulators, 13 of 15 blocks with device evidence, all cited screenshots present. **Seat recovery after a force-quit device-verified for the first time.** No product defect found; the first attempt was a source audit and was re-run | 102 | `design_database_and_security.md` §5; `docs/playthroughs/findings_marionette.md` |
| **Chosen deck ignored — every game played The Daily Grind** (`_selectedDeck` initialised once, read once, never assigned; `startGame` trusted the caller's deck over the room's). Fixed **A+C**: server resolves from `room.selectedDeckId` *and* rejects a mismatched claim with `invalid-argument`; dead field deleted; family-friendly toggle now writes through so it cannot desync the lobby from the room | 106 | `design_prompt_system.md` §2; `functions/src/index.ts:293`; `test/deck_selection_test.dart` |
| **Evidence mechanical gate & E10/E11 device verification** — `check_playthrough_evidence.sh` tool enforcing R1–R4 with 3 exit codes; E10 in-game leave auto-end verified on both remaining devices (`e10_p1_gameover.png`, `e10_p2_gameover.png`); E11 release build verified with zero DEBUG controls (`e11_release_lobby.png`); repointed dead citations to `functions/src/index.ts:986` | 105 | `docs/agent_execution_guide.md` §2–§3; `scripts/check_playthrough_evidence.sh`; `docs/playthroughs/findings_marionette.md` |
| **Web E2E Playthrough (Wave I)** — Playwright automated harness (`test/web_e2e/`); I1 evidence gate widened with strict PNG requirement for W blocks; W1–W16 3-player match with falsification, truth, forgeries, voting lockout, unmasking, standings, GameOver, mid-match refresh restoral, case file share, console hygiene, and below-3 auto-end; W17–W19 responsive sweeps across mobile (375x812), tablet (768x1024), and desktop (1280x800) with 15 screenshots | 106 (Wave I) | `docs/playthroughs/findings_web.md`; `test/web_e2e/`; `scripts/check_playthrough_evidence.sh` |
| **Prompt Source & Sampling (Wave J)** — resolved effective prompt source on `GameState` killing `"custom"` sentinel crash (109 / J1); custom game prompt drawing and re-rolls from players' contributed pool with self-author lockout (108 / J2); uniform re-roll sampling minus live in-play table cards (107 / J3) | 107, 108, 109 | `design_prompt_system.md` §3, §5; `functions/src/index.ts` |
| **Game Over Payoff & Web Download (Wave K & Wave O / O3)** — Standings + server-written match summary quoting real answers accumulated into `sealed/_summary` across rounds and published at game over with snapshotted display names (111 / K1, 115 / O3); Case File PNG direct downloads on web via Blob URL and synthetic anchor click (110 / K2) | 110, 111, 115 | `design_scoring_and_ui.md`; `lib/utils/case_file_saver_web.dart`; `functions/src/index.ts` |
| **Presence & Resume Lifecycle (Wave M)** — GameService `WidgetsBindingObserver` immediate `lastSeen` write and heartbeat restart on app resume (112 / M2). **Room code** displayed in the AppBar across Craft, Vote and Reveal (120 / O5). The 10-minute presence window was inert until Issue 123 moved enforcement onto the action rather than the caller | 112, 120, 123 | `design_database_and_security.md` §4–§5; `functions/src/index.ts` |

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

**⚠️ Issue 163 Reversal Recorded (September 8, 2026 / Wave AA):** Option A (per-round scoring multiplier: Round 1 ×1, Round 2 ×2, etc.) was selected and implemented to introduce a match scoring arc within `calculateScores`. P7 (Confidence Wager), P9 (House Cards), and P11 (The Final Gambit) remain deliberately rejected; the reversal is strictly confined to the narrow arithmetic scoring escalation within `calculateScores`.

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
| Playthrough evidence and its provenance | `docs/playthroughs/` (`findings_waveAA.md`, `findings_5player.md`, `findings_marionette.md`, `findings_web.md`) |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |
| Full history of any resolved item | `git log` |

**A note on keeping this file short.** It was 903 lines in August, cut to 559, and cut again to ~200 on August 21. Both times the cause was the same: **each pass appended its summary without removing the one it superseded** — Issues 93–95 appeared three times, and §1 accumulated six stacked banners. When you resolve something, move the durable consequence into the design doc above and leave **one line** here. If you are adding a paragraph to this file, ask first whether it belongs in a design doc instead.
