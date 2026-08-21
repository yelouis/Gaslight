# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**Issues 1–101 are delivered, deployed and independently verified — August 21, 2026. Three pre-demo items are now open: Issues 102–104.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (22 warnings, 194 infos) |
| `flutter test` | **156/156** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **61/61** |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions **and** the rules release, each after its own commit |

The last wave was a whole-repository security review that found six defects (Issues 96–101), one **HIGH** (seat and host takeover) and one whose exploit was reproduced end-to-end against the emulator. All six shipped with tests, both deploys were confirmed, and two design docs that still described the vulnerable model were corrected during verification (§2.19).

**Do not invent work.** The four legitimate triggers are listed in `agent_execution_guide.md` §2 — and the first is the one that has actually produced every recent defect: **a human playing the game**. Five of the last six functional waves came from that; none came from a gate.

**Only one banner lives here.** Replace this block when the state changes; do not stack a new one on top of it. Six superseded banners had accumulated here by August 21, each announcing that the one below it was out of date.

## ⚠️ Unresolved Issues & Suggestions

**Three items stand between the current build and handing a demo to friends.** Issue 102 is the acceptance gate; 103 is what a friend would see and think "this isn't finished"; 104 is how they install it at all. Only 103 and 104 need a selection.

---

### Issue 102: Final pre-demo E2E playthrough (Marionette, three simulators)

**Status**: 🔵 Task, approved on filing — no selection needed. **Run this before the Apple Developer licence arrives**, so the full-device test suite starts from a known-good build.

**Why now, and why it is not optional.** The security wave (Issues 96–101) changed **four load-bearing gameplay paths** and nothing has played the game since:

* `votes` now stores an opaque option UUID and is resolved server-side at the reveal transition (Issue 98) — the third redefinition of that field, and the first two both broke the reveal.
* The reveal merge is scoped to a single card (Issue 99), so cards 2 and 3 of a round take a different code path than they did before.
* Forgery authorship is withheld until `unmaskDeadline` closes (Issue 100), which changes **when** data appears, not just what.
* `joinRoom` now requires ownership, a seat token, or staleness (Issue 97). **The seat-token rejoin path has never been exercised on a device.**

The emulator suite (61 passing) proves the server. It cannot prove the reveal renders, the standings are right, or that a player who backgrounds the app can get back into their seat. **Every defect in the last six waves came from a human or a driven client playing the game; none came from a gate.**

**Setup.** Marionette MCP is installed and working — `marionette_flutter` in `pubspec.yaml`, the binding in `lib/main.dart`, three servers in `.agents/mcp_config.json`, stable keys from `f3a5a1d`. Verify rather than redo. `.env` must have `USE_EMULATOR=false`; rebuild first (`lib/` changed across the security wave); uninstall on all three simulators so no stale room is restored; `Disable Game Timers` **on**, `Family-Friendly Decks Only` **off**; three real clients, **never `DEBUG: ADD 9 BOTS`**. Full procedure and traps: `agent_execution_guide.md`.

**Assertions — a full 3-player, 3-round match, plus the paths the security wave touched:**

| # | Assertion | Verdict comes from |
|---|---|---|
| E1 | A 3-round match plays to `THE NIGHT'S HONORS` without stalling | The round counter advancing twice, then Game Over |
| E2 | **Every reveal shows the right truth and forgeries** — cards 2 and 3 included | The card text on all three devices. Issue 99 changed this path |
| E3 | **Unread cards stay blank before their turn** | No answers visible for a card that has not been revealed |
| E4 | **The unmask window shows no authorship**, and results are correct once it closes | `REVENGE UNMASKING RESULTS`. Issue 100 changed *when* this appears |
| E5 | **Scoring is right** — truth-finder gains `ceil((P−1)/(S+1))`, truth-teller `+1` per finder, forger `+1` per fooled voter | `STANDINGS` before and after, as numbers. Issue 98 changed what `votes` holds |
| E6 | **Attribution is correct** — the named author actually wrote it | Prefix each device's answers `AAA`/`BBB`/`CCC` |
| E7 | **Seat recovery works.** Force-quit a player mid-match and relaunch: they return to their own seat with their score | **Never tested live. Issue 97's seat token is the mechanism** |
| E8 | Host kick removes a lobby player; the removed player sees the notice | Both devices |
| E9 | A player leaves mid-match from a 4-player game; the match continues | The remaining three |
| E10 | A 3-player match dropping to 2 ends for everyone at the final score | All devices reach Game Over with scores intact |
| E11 | **No `DEBUG:` control is visible anywhere** | Every screen. Fails today — see Issue 103 |

**Do not fix anything inline.** Record findings in `docs/playthrough_findings_marionette.md`, one block per assertion, verbatim, with `grep -F` traceability for every quoted string. A failure becomes a tracked issue here with options — a fix applied during the run destroys the evidence that it was needed.

---

### Issue 103: The release build ships developer artefacts

**Status**: ⚠️ Confirmed in source, August 21, 2026. **This is what a friend sees in the first ten seconds.**

**103.1 — Seven `DEBUG:` buttons ship in release, and they are completely unguarded.**

```dart
// lib/screens/lobby_screen.dart:741-747 — the ONLY condition is a player count
if (players.length < 10)
  TextButton(onPressed: () => gs.debugAddBots(),
    child: const Text('DEBUG: ADD 9 BOTS', ...))
```

Seven sites: `lobby_screen.dart:745`, `phase2_craft.dart:331,368,569`, `phase3_vote.dart:257,414,572`. The single `kDebugMode` in `lobby_screen.dart` is `debugEnabled: kDebugMode` at `:188` — the room flag, **not a guard on any button**. Since Issue 101 gated the callables on `FUNCTIONS_EMULATOR`, these buttons are now **visible, tappable, and guaranteed to fail** with `permission-denied` in production. A tester will press one.

**Approved fix:** wrap every one in `if (kDebugMode)`. Client-only, no deploy.

**103.2 — The app icon is the stock Flutter logo.** `ios/Runner/Assets.xcassets/AppIcon.appiconset/` holds 15 PNGs and all of them are the default blue Flutter chevron — verified by opening `Icon-App-1024x1024@1x.png`. On a friend's home screen the app is indistinguishable from any other Flutter demo.

**103.3 — The launch screen is a 1×1 placeholder.** `LaunchImage.png`, `@2x` and `@3x` are all **1 × 1 pixel** greyscale stubs, so the app opens on a blank white flash before the first frame — jarring against a dark, candlelit game.

**Option A (recommended): fix all three, using art the repo already has**
- Gate the buttons; build the icon from the existing raven mascot (`assets/images/raven/`) on the oxblood/parchment palette; make the launch screen a solid `AppColors.ground` (`#14110E`) field, optionally with the wordmark, so the cold start reads as the game rather than as a blank page. Add `flutter_launcher_icons` and `flutter_native_splash` to `dev_dependencies` and generate both from source art — **hand-placing 15 PNGs is how they drift.**
- Pros: one commit, no backend, and the raven is already the app's identity. **A 1024×1024 icon with no alpha channel is an App Store requirement**, so doing it now avoids a rejected upload later.
- Cons: the icon is a design decision, and a generated one from an existing sprite may not be what you want at 60×60.

**Option B: gate the buttons now; icon and splash later**
- Pros: the embarrassing half is one commit and needs no art direction.
- Cons: friends still install a blue Flutter chevron called "Gaslight".

**Option C: buttons and splash now, keep the placeholder icon deliberately**
- Pros: honest for a pre-licence demo where you may want it to look unfinished.
- Cons: an icon is the cheapest signal that a build is real, and you will need one regardless.

Your selection: _____

**Validation:** a release build (`flutter build ipa` or `--release` to a simulator) with **zero** `DEBUG:` strings on any screen — grep the widget tree, do not eyeball it. `AppIcon` 1024×1024 present, **no alpha channel**. Launch screen renders the dark ground, not white.

---

### Issue 104: How friends install it while the Apple licence is pending

**Status**: 🔵 Open question, needs a decision. Not a defect — a distribution choice that changes what work is worth doing now.

Confirmed release plumbing: bundle ID `com.whylabs.gaslight`, `CFBundleDisplayName` **`Gaslight`** ✅, `ITSAppUsesNonExemptEncryption` **`false`** ✅ (so TestFlight will not stall on an export-compliance prompt), version `1.0.0+2`. **There is no `PrivacyInfo.xcprivacy`** anywhere in `ios/` — Apple requires a privacy manifest for App Store submission, and this app uses `SharedPreferences` (a required-reason `UserDefaults` API), so it will need one before an upload is accepted.

**Option A: wait for the licence, then TestFlight**
- Pros: the real thing on real devices, and internal testers (up to 100) need no Beta App Review. Everything in Issue 103 is worth doing regardless.
- Cons: blocked on Apple. Also needs the privacy manifest, and **external** testers (friends who are not on your team) require Beta App Review, which adds a round trip.

**Option B: ship a Flutter web build on Firebase Hosting now**
- The backend is already deployed and the client is Firebase-based. `web/` scaffolding exists, but **Hosting is not configured** — `firebase.json` declares only `firestore`, `functions` and `emulators`, so this needs `firebase init hosting` plus a `flutter build web`.
- Pros: friends test **today**, on any device, by opening a link — no licence, no install, no TestFlight. Best possible feedback loop for a party game people play in the same room.
- Cons: untested surface. The app has only ever run on iOS simulators; web needs its own pass for layout, fonts (`CormorantGaramond`/`Lora`/vendored Phosphor), `audioplayers`, and `SharedPreferences` persistence. **`firestore.rules` and the callables are unchanged, so the security work carries over** — but Issue 97's seat token lives in browser storage, which a friend clearing site data will lose.
- ⚠️ **A public web URL means anonymous auth open to the internet**, and there is still **no App Check** anywhere in the repo. For a link shared with friends that is likely fine; before anything wider, App Check should be filed as its own issue.

**Option C: both — web now for feedback, TestFlight when the licence lands**
- Pros: unblocks testing immediately and keeps the iOS path on track. Issue 103's work applies to both.
- Cons: two surfaces to keep working, and the web pass is real effort you may not want before the game design is settled.

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

## 3. Resolved — index only

Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This is an index, not a record. **One heading, and only one — never add a second** (that is how this file reached 559 lines: each verification pass appended its own summary without removing the last, so Issues 93–95 appeared three times).

### Issues 65–101 — August 8 to 21, 2026

**37 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

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
