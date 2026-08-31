# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**No open issues in flight.** Wave W (W1 & W2) has been fully implemented, verified, and shipped to production on August 31, 2026.

**Wave W (W1 & W2) is ✅ VERIFIED and RESOLVED**:
- **W1 (Issue 146 → Option A)**: Stopped the lobby-close path from orphaning the `sealed` subcollection by performing `db.recursiveDelete(roomRef)` post-transaction in `handleDisconnect` (`index.ts:1352`). Capped the nightly orphan sweep at `DEFAULT_ORPHAN_SWEEP_LIMIT = 100` (`maxOrphansPerRun`) in `cleanup.ts` on the document scan iteration (`orphanSubtreesScanned`) to bound read costs. Retained the nightly sweep as an essential backstop. Added 4 unit/emulator tests (112 functions tests total, all passing). Falsification tests verified.
- **W2 (Issue 145 → Option A)**: Verified in production that a closed lobby leaves 0 orphans on disk. Activated live deletion in production via `gcloud run services update cleanupdaily --update-env-vars CLEANUP_DRY_RUN=false`. Documented revision-scoped env var trap and restore command in `design_database_and_security.md` §10.5. First live run executed and verified against prediction: 98 orphan subtrees swept, 200 stale anonymous accounts purged, 1 active user protected (`authUsersReferenced=1`), 0 errors. Subsequent sweep cleared the remaining 3 orphans (101 total) and reached 0 eligible.

**Wave V verified independently, August 31, 2026 — V1 (Issue 144 → Option A) delivered and verified.**

**V1 (Issue 144 & 143) is ✅ VERIFIED and RESOLVED**:
- **Step 1 (Environment check)**: Deployed Cloud Run container environment for `cleanupdaily` inspected via `gcloud run services describe`: `CLEANUP_DRY_RUN` was completely absent, proving `dryRun: true` (inert, log-only) before redeploying.
- **Step 2 (Redeploy)**: Clean redeploy of all 17 functions from committed tree (`firebase deploy --only functions`).
- **Step 3 (Deploy gate)**: `./scripts/check_deploy_fresh.sh` re-run bare; exited **0 — FRESH** reporting all 17 functions and security rules exceeding latest commits.
- **Step 4 (Dry-run log)**: Cloud Scheduler job triggered and execution log verified: `[CLEANUP] Completed run: dryRun=true, roomsScanned=0, roomsDeleted=0, orphanSubtreesSwept=101, authUsersScanned=206, authUsersReferenced=1, authUsersEligible=200, authUsersDeleted=0, errors=0`. Neither execution cap (100 rooms / 500 users) was hit.
- **Retention settled**: 24 hours confirmed and documented in `design_database_and_security.md` §10.4. Enabling live deletion remains a separate decision.

**Wave U (U1–U4) is ✅ VERIFIED and RESOLVED** (independent verification details below):
- U1 (Issue 140): manifest scoped per report; R6 falsifications verified.
- U2 (Issue 141): real Reduce Motion platform signal; particle suppression device-verified.
- U3 (Issue 142): heartbeat 30 s, snapshot equality comparison, host-gated cooldown.
- U4 (Issue 135): Match N2 on 5 iOS simulators, E49 presence window device-verified (7:07 vs 7:16).

**Housekeeping, August 31:** all playthrough material moved into a dedicated folder — `docs/playthroughs/` now holds `findings_5player.md`, `findings_marionette.md`, `findings_web.md`, `manifest.md` and `evidence/` (105 artefacts). 163 references were rewritten across 10 files including the three `test/web_e2e/` scripts that *write* screenshots. All four gate invocations re-verified green afterwards, and **R5 was falsified after the move** — removing one cited PNG produces `Rule R5 violation`, proving artefact paths still resolve rather than passing vacuously.

- **S1 (Issue 139) — ✅ VERIFIED and RESOLVED.** All five dead declarations and both cascade imports are gone; **0 warnings**, 206 infos, **no suppressions** (`analysis_options.yaml` untouched, zero new `// ignore:`), and `lastReaction`/`lastReactionAt` survive in `player_state.dart`. Diffed the info sets before and after: **zero new infos**, and the single info that disappeared was `prefer_final_fields` attached to the deleted `_lastReactionSentTime` — the lint died with the field. `flutter test` 258, functions 102.
- **U1 (Issue 140) — ✅ VERIFIED and RESOLVED.** Playthrough manifest now carries a `Report` column as its first column; `scripts/check_playthrough_evidence.sh` normalises paths and filters rows by report; zero-rows-overall remains a FATAL failure (exit 1), while un-governed reports pass cleanly (reporting `0 of N manifest entries govern this report`). All four gate invocations exit 0 bare; R6's title-drift, assertion-drift, and empty-manifest falsifications re-verified; over-reach guard passed.
- **U2 (Issue 141) — ✅ VERIFIED and RESOLVED.** `AppMotion.reduce(context)` reads `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion || MediaQuery.of(context).accessibleNavigation`. `AnimatedThinkingBackground` implements `WidgetsBindingObserver` to react dynamically to `didChangeAccessibilityFeatures()`. Normalized `AutoAdvanceTimer`. Falsification verified: `disableAnimations=false, reduceMotion=true` yields `AppMotion.reduce(context) == true`.
- **U3 (Issue 142) — ✅ VERIFIED and RESOLVED.** Heartbeat interval relaxed to 30 s (cutting idle writes from 6/min to 2/min per client), `_playersSubscription` suppresses `notifyListeners()` on `lastSeen`-only snapshots (cutting rebuilds from 30/min to 0 per room), `deadPlayers` disconnect evaluations host-gated with 60 s per-player cooldown (eliminating callable flood), and `_heartbeatTimer` pauses on `AppLifecycleState.paused` and resumes on `resumed`. All 4 falsifying assertions in `test/presence_chatter_test.dart` pass cleanly.
- **U4 (Issue 135) — ✅ VERIFIED and RESOLVED.** Match N2 completed on 5 live iOS simulators. E49 executed and verified PASS under verbatim assertion contract with both wall-clock timestamps recorded ($T_0=02:05:31\text{Z}$ termination; Checkpoint 1 at ~2 min / 7:07 showing P5 still present; Checkpoint 2 at ~11 min / 7:16 showing P5 absent/removed). Device screenshots logged in `ARTEFACTS.tsv` with clocks 9 minutes apart (`e49_p1_presence_within_window.png` and `e49_p1_presence_after_window.png`). R0/U2 Reduce Motion device evidence captured on P3 (`r0_u2_p3_reduce_motion.png`) confirming background particle suppression.
- **U5 (Issue 143) — ✅ VERIFIED and RESOLVED.** Scheduled Cloud Function `cleanupDaily` deployed to `us-central1` and active in live deletion mode (`CLEANUP_DRY_RUN=false`).

**Gate state, measured August 31, 2026:**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** · **0 warnings, 206 infos** · **exit 1**. The 206 infos are `deprecated_member_use` (`withOpacity`) and `avoid_print` in `test/` — accepted and tracked. |
| `flutter test` | **267 passing** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **112 passing** (including 8 cleanup unit/emulator tests + disconnect subtree deletion tests) |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH.** All 17 Cloud Functions and Firestore Rules exceed the latest tree commits. (Wave W1 delivered). |
| `./scripts/check_playthrough_evidence.sh` (all 4 invocations: no-args, marionette, web, 5player) | **exit 0** — all 4 invocations green (U1 / Issue 140 delivered) |
| `./scripts/check_playthrough_evidence.sh docs/playthroughs/findings_5player.md` | **exit 0** — 28 blocks, 37 artefacts on disk, R6: 3 of 3 manifest entries checked. |

**Read the exit code bare, not through a pipe.**

## ⚠️ Unresolved Issues & Suggestions

**No open unresolved issues.** All open items (Issues 145 and 146) are resolved in Wave W.

---

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

### Issues 65–146 — August 8 to 31, 2026

**71 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

| Area | Issues | Where the surviving contract lives |
|---|---|---|
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
| Playthrough evidence and its provenance | `findings_marionette.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |
| Full history of any resolved item | `git log` |

**A note on keeping this file short.** It was 903 lines in August, cut to 559, and cut again to ~200 on August 21. Both times the cause was the same: **each pass appended its summary without removing the one it superseded** — Issues 93–95 appeared three times, and §1 accumulated six stacked banners. When you resolve something, move the durable consequence into the design doc above and leave **one line** here. If you are adding a paragraph to this file, ask first whether it belongs in a design doc instead.
