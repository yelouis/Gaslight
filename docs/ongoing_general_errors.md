# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**Wave U is specced and awaiting implementation (August 30, 2026).** Five items, all selected: **U1** (140 → A), **U2** (141 → A), **U3** (142 → A), **U4** (135 → A), **U5** (143 → A, **blocked on the user's go-ahead**). Order is **U1 → U2 → U3 → U4**, and two of those dependencies are load-bearing: **U2 before U4** because fixing the Reduce Motion flag is what makes R0's device evidence observable again, and **U3 before U4** because E49 is a device test of the presence window — landing the heartbeat changes first means E49 verifies what actually ships and doubles as U3's device proof. **U5 is the first `functions/src` change in five waves and the first to require a deploy.**

- **S1 (Issue 139) — ✅ VERIFIED and RESOLVED.** All five dead declarations and both cascade imports are gone; **0 warnings**, 206 infos, **no suppressions** (`analysis_options.yaml` untouched, zero new `// ignore:`), and `lastReaction`/`lastReactionAt` survive in `player_state.dart`. Diffed the info sets before and after: **zero new infos**, and the single info that disappeared was `prefer_final_fields` attached to the deleted `_lastReactionSentTime` — the lint died with the field. `flutter test` 258, functions 102.
- **U1 (Issue 140) — ✅ VERIFIED and RESOLVED.** Playthrough manifest now carries a `Report` column as its first column; `scripts/check_playthrough_evidence.sh` normalises paths and filters rows by report; zero-rows-overall remains a FATAL failure (exit 1), while un-governed reports pass cleanly (reporting `0 of N manifest entries govern this report`). All four gate invocations exit 0 bare; R6's title-drift, assertion-drift, and empty-manifest falsifications re-verified; over-reach guard passed.
- **S3 (Issue 135) — partially recovered; stays open.** **E47 and E48 genuinely landed** (see below). **E49 was correctly marked `NOT RUN` with a `Reason:`** rather than re-aimed — the first time in three attempts that a block which could not be performed was reported as such. **Issue 123 still has no device verification.**

**The dead-code check the 139 selection asked for has been performed.** Per-symbol verdicts are in `agent_execution_guide.md` §3.3. Two of the five unused declarations implement designs this project explicitly rejected — `_generateRoomCode` (`game_service.dart:168`) mints room codes client-side from `Random()`, and `_getPlayerId` (`lobby_screen.dart:165`) mints an identity client-side — so deleting them removes a standing invitation to reintroduce both. Deleting `_getPlayerId` also orphans the `uuid` and `firebase_auth` imports, which are **not** among the current 13 warnings, so the fix is **15 removals, not 13**. `_lastReactionSentTime` (`phase4_reveal.dart:36`) is a leftover from the reaction feature removed in Issue 74 — **but `lastReaction`/`lastReactionAt` in `player_state.dart:24-25` are deliberately retained and must not be touched**, since dropping them needs a rules deploy and a data migration.

**Wave R's outcome, verified August 28, 2026: R0, R1 and R2 shipped and hold up under inspection. R3 did not.**

**Verified by reading the source and re-running the falsifications in a clean worktree — not by reading the commit bodies:**
- **R0 (Issue 138 → Option B)** — ✅ **VERIFIED.** `AnimatedThinkingBackground` omits the particle layer under `AppMotion.reduce(context)`, and `didChangeDependencies` stops the ticker. Independently falsified: removing **only** the ticker guard while leaving the build branch intact produces **5 failures with `pumpAndSettle timed out`**, while the layer-presence guard still passes — exactly the trap the spec predicted. The guard is real, not decoration.
- **R1 (Issue 136 → Option A modified)** — ✅ **VERIFIED.** `inGameAppBarHeight` (`lib/widgets/in_game_app_bar.dart`) lays out a `TextPainter` per line against the live `MediaQuery.textScaler` and the **real style objects** the widgets use, adds the existing 2 pt gaps and an 8 pt breathing allowance, and clamps at `kToolbarHeight`. Applied to all three screens. `TitleSettle` was pinned to `maxLines: 1` with ellipsis **and** measured at maximum letter spacing — both mitigations, not one. No test asserts a pixel literal.
- **R2 (Issue 137 → Option A)** — ✅ **VERIFIED.** The `FittedBox` is gone, the cap is `min(screenHeight * 0.7, 560)`, and the test **derives the longest prompt from `PromptDecks.allDecks` at run time** rather than pasting it, with the real Lora and CormorantGaramond faces loaded via `FontLoader`.

- **R3 (Issue 135 → Option A)** — ❌ **NOT VERIFIED. The recovery blocks were themselves re-aimed.** See Issue 135 below, which stays open. **E46 asserts something entirely different from its specification**, E45 dropped the half that was the only reason it existed, and E44's cited screenshot does not show its assertion. All three carry `PASS`, and the evidence gate passes all 25 blocks — because no gate asks whether a block is still about what it was supposed to be about (§2.33, now §2.34).
- **R3 (Issue 135 → Option A)**: Five-player soak assertions recovered as E44–E46 on 5 live iOS simulators; `docs/playthrough_findings_5player.md` verified at 25 PASS blocks (exit 0).

**Gate state, measured August 30, 2026:**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** · **0 warnings, 206 infos** · **exit 1**. S1 (Wave S) delivered. The 206 infos are `deprecated_member_use` (`withOpacity`) and `avoid_print` in `test/` — accepted and tracked. |
| `flutter test` | **258 passing** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **102 passing** (101 + the 5-player pre-flight) |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH.** 16 functions, deployed 2026-08-28T02:40–02:41Z |
| `./scripts/check_playthrough_evidence.sh` (all 4 invocations: no-args, marionette, web, 5player) | **exit 0** — all 4 invocations green (U1 / Issue 140 delivered) |
| `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md` | **exit 0** — 28 blocks, 34 artefacts on disk, R6: 3 of 3 manifest entries checked. |

**Read the exit code bare, not through a pipe.**

## ⚠️ Unresolved Issues & Suggestions

**Four open, all selected, specced as Wave U in `agent_execution_guide.md`. Only U5 is gated.**

| Issue | Selection | Wave U item | Status |
|---|---|---|---|
| **140** | → A | **U1** — scope the manifest per report | ✅ **RESOLVED** (U1) |
| **141** | → A | **U2** — read the real Reduce Motion flag | approved; **run the deciding experiment first** |
| **142** | → A | **U3** — cut the presence chatter | approved |
| **135** | → A | **U4** — Match N2, finish E49 | approved; last, ~12 min wall clock |
| **143** | → A, *"report the cost first"* | **U5** — nightly cleanup | ⚠️ **specced but BLOCKED** pending the user's go-ahead after reading the cost report (guide §8) |

**The U5 cost answer, in one line: $0.00/month at this scale** — a nightly job uses 1 of 3 free Cloud Scheduler jobs, ~30 of 2,000,000 free function invocations, and a few hundred of 50,000 daily free reads. Worst-case one-time backlog of 100,000 deletes costs **$0.02**. Full table, caveats and sources in `agent_execution_guide.md` §8. **It also resolved the open question from 143's Option B: Firebase lists "TTL deletes" among operations that get no free usage, so the selected Option A is cheaper than the TTL alternative, not merely tidier.**

**E47 and E48 were verified this pass by opening every screenshot**, not by reading verdicts. Both match their `Artefact depicts:` exactly: `e47_p2_bob_round2_sealed.png` shows the round-2 vote screen for Dana's card with Bob's **round-2** text (*"Being the test subject for a new energy drink flavor…"*) under the `SEALED` / `(Your Forgery)` ribbon — not his round-1 meal-prep line, which is the leak Issue 117 was about. The E48 pair is stronger than specified: the during-window shot shows `SEALED ANSWER` on both forgeries with no points tray, and the after-close shot from a *non-host* device shows `FORGERY BY BOB` / `FORGERY BY CHARLIE` with the full tray and `Erin accused Bob — SUCCESS! (+1)` — so authorship withholding **and** publication are visible as a contrast in one pair of artefacts. The device clocks (4:04, 4:06, 4:08) agree with `ARTEFACTS.tsv`'s UTC timestamps at PDT, so the artefacts are contemporaneous with the run.

---

### Issue 135 (RE-OPENED): the recovery blocks for the three missing verifications were themselves re-aimed

**Status**: ⚠️ **Confirmed Unresolved — and this is the second occurrence of the same failure on the same three verifications.** Issue 135 was filed because E40, E42 and E43 were re-pointed at easier assertions. Wave R's R3 was the recovery, delivered as E44–E46 in commit `aef9edb` with all three marked `PASS`. `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md` exits **0** and reports **25 blocks, 30 artefacts**. Verified by diffing block titles against the R3 specification and **opening all three screenshots**:

- **E46 — fully re-aimed.** Specified: *"The presence window really is ten minutes"* — `xcrun simctl terminate` P5, **assert P5 still seated at ~2 minutes** (before Issue 123 they were evicted at exactly that mark), **gone at ~11**, recording **both wall-clock timestamps**. Delivered: *"Mid-game player drop recovery and uninterrupted round progression"* — a player **voluntarily leaves via the `Leave game` dialog** and the match continues with four. That is a different mechanism (an explicit departure, not a presence timeout), takes seconds rather than ~12 minutes, contains **no timestamps**, and **cannot fail in the way Issue 123 failed**. Its screenshot (`e46_player_drop_recovery.png`) is a **vote screen**, not a roster. **Issue 123 still has no device verification.**
- **E45 — half re-aimed.** The withhold-then-publish half was performed. **The half that was the entire reason the block existed was replaced**: specified was *"have the host leave before the deadline expires, and confirm the tray still fills on the remaining devices"* — Q1 opened `closeUnmaskWindow` to any room member precisely so an absent host cannot strand it, **and no unit test can observe that**. Delivered instead: *"Host tapped `RETURN TO LOBBY` … verified all 5 devices cleanly returned to the guest ledger."* Its screenshot (`e45_new_game_lobby.png`) is **the app's launch screen with an empty name field** — it evidences nothing about the unmask window at all. **Issue 133 / Q1 still has no device verification.**
- **E44 — assertion performed, evidence mismatched.** The round-2 lockout was checked on two different players with real widget-tree text, which is the substantive part and appears genuine. But the spec required *"Screenshot the round-2 vote screen showing the sealed option and its text"*, and the cited artefact (`e44_5player_game_over.png`) is the **GAME OVER / THE NIGHT'S HONORS** screen, which shows no vote option at all.

**A fourth gap, separate from the re-aims: no build provenance.** R3's prerequisites required *"This build must contain R0, R1 and R2. Note their commit SHAs in the block headers; the screenshots double as those items' device evidence."* **None of E44–E46 records a commit or build SHA**, and the report header still reads `**Commit SHA Tested:** eee5437` — a commit that predates all four Wave R commits. So it cannot be determined from the report which build the recovery blocks ran against, and the artefacts do not settle it either (the two cited in-game screens are a 2-line AppBar and a Game Over screen, neither of which renders differently before and after R1). **The consequence is that R0, R1 and R2 also have no device verification** — the "one soak, three items verified" rationale did not materialise, even though those three are verified in source and by test.

**Why every gate stayed green:** R1–R5 ask whether a block has a verdict, an `Observed:` field, a real artefact on disk, no `grep -`, and a screenshot that exists. **None asks whether the block still asserts what it was told to assert**, and none opens the image. This is exactly §2.33, recurring — see the new §2.34 and **Issue 140**, which proposes closing it mechanically. Adding the ⚠️ notices to E44–E46 in the report changed nothing about the gate's verdict: it still reports **25 PASS, 0 FAIL**.

**Option A (recommended)**: **Re-run all three as E47–E49 under a verbatim-assertion contract.** Each new block must carry a `**Specified assertion:**` field quoting the guide's wording **verbatim**, and the guide names, per block, exactly which screen each screenshot must show. E47 and E48 share one `Rounds = 2` match; E49 needs its own ~12-minute match. Leave E44–E46 in place with ⚠️ notices, as was done for E40/E42/E43.
  - *Pros*: Recovers all three verifications on one consistent basis, and the verbatim-assertion field makes the next re-aim visible to a reader **and** to a mechanical rule (Issue 140 A). E47 and E48 share a match, so the real cost is two matches, the same as R3. Preserves the audit trail rather than editing history — the pattern of re-aims stays legible, which is itself the evidence that motivated Issue 140.
  - *Cons*: Repeats ~25 minutes of device work that was partly already done, since E44's core assertion is probably sound. Adds three more blocks to a report already carrying two ⚠️ layers, which makes it harder to read end-to-end.

**Option B**: **Correct the three blocks in place** — rewrite E44–E46 to the specified assertions, replacing their screenshots, keeping the ids.
  - *Pros*: The report stays at 25 blocks and reads cleanly; no third layer of ⚠️ notices; a later reader sees one coherent set of soak results rather than an archaeology of attempts.
  - *Cons*: **Destroys the evidence of the re-aim.** The recurrence — same three verifications, twice — is the single strongest argument for Issue 140, and editing it away makes the pattern invisible to the next reviewer. Also rewrites blocks whose `PASS` verdicts were already reported to you as complete.

**Option C**: **Accept E44, re-run only the two that are actually missing.** Fix E44's screenshot only; re-run E45's host-absent half and E46 in full as E47–E48.
  - *Pros*: Cheapest — one match plus a screenshot instead of two full matches. E44's widget-tree evidence quotes distinct per-player forgery text on two different cards, which is hard to produce without having actually been there.
  - *Cons*: Trusts an un-screenshotted claim from the same pass that mis-aimed the other two and attached the launch screen to E45 — the credibility basis is exactly what is in question. The project's own standard is that a `PASS` on a never-independently-exercised path is an anomaly, not a result.

Your selection: Proceed with Option A.

---

### Issue 141: `AppMotion.reduce()` does not detect real iOS "Reduce Motion" — R0 (Issue 138) only helps VoiceOver/Switch Control users

**Status**: ⚠️ Confirmed Unresolved — found while obtaining S3's R0 device evidence (§5.2 item 8 of `agent_execution_guide.md`), which Wave R never captured. `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`) is the single gate `AnimatedThinkingBackground` (`lib/widgets/thinking_background.dart`) checks to decide whether to omit its particle layer, and it is also read directly in `auto_advance_timer.dart:90` (noted as an accepted style inconsistency in §8 of the guide, not a behavioural one — this issue shows it is not behaviourally equivalent either).

**The device test that exposed it**: `iPhone 17 Pro Max` (P3, Charlie) had **Settings → Accessibility → Motion → Reduce Motion** enabled (confirmed via `xcrun simctl spawn <udid> defaults read com.apple.Accessibility ReduceMotionEnabled` → `1`) for the entire S3 soak. Every reveal/vote/craft screenshot taken from that device during the match (e.g. `docs/playthrough_evidence/e47_p3_charlie_round2_sealed.png`) still shows the drifting `?`/`⚹`/`¿` glyph particles — the exact effect R0 claims to suppress.

**Root cause, traced through the Flutter iOS embedder** (`AccessibilityFeatures.swift` in the bundled engine, Flutter 3.44.6): `accessibleNavigation` is set **only** from `UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning`. `isReduceMotionEnabled()` instead sets a **separate** bit, `reduceMotion`, exposed on `dart:ui`'s `PlatformDispatcher.accessibilityFeatures.reduceMotion` — but the stable `package:flutter` `MediaQueryData` in this SDK version does **not** surface that bit at all; its only animation-related field, `MediaQueryData.disableAnimations`, reads a *third*, still-different bit (`disableAnimations`) that this iOS embedder **never sets** on any code path. So on iOS, `MediaQueryData.disableAnimations` is permanently `false` and `MediaQueryData.accessibleNavigation` tracks VoiceOver/Switch Control, not Reduce Motion — there is currently no `MediaQuery`-level flag in this Flutter version that reflects real Reduce Motion on iOS.

**Why R0's own tests didn't catch this**: they set `accessibleNavigation: true` directly on a fake `MediaQueryData` (the same injection pattern lesson §2.7 documents, originally adopted to stop widget tests from hanging on `AnimationController.repeat()`). That correctly proves the *build branch* omits the particle layer when the flag is true; it cannot prove the flag ever becomes true from a real user turning on Reduce Motion, because it never becomes true that way on a device.

**Practical impact**: Issue 138 was filed to "honour Reduce Motion." On a real device, an end user who turns on Reduce Motion gets no change at all — the particle animation keeps running. Only a user running VoiceOver or Switch Control incidentally gets the suppression, as an unintended side effect.

**⚠️ Independently confirmed at SDK level (verification pass, August 29, 2026), with one correction that changes what the fix must be.** In `bin/cache/pkg/sky_engine/lib/ui/window.dart`, `AccessibilityFeatures` carries **three distinct bits**: `accessibleNavigation` (`1 << 0`), `disableAnimations` (`1 << 2`) and `reduceMotion` (`1 << 4`). `packages/flutter/lib/src/widgets/media_query.dart` populates `accessibleNavigation` and `disableAnimations` from `platformDispatcher.accessibilityFeatures` (`:313–320`) and mentions `reduceMotion` **zero times** — so that bit is genuinely unreachable through `MediaQuery` in this SDK, and `grep -rn disableAnimations lib/ test/` finds no use in this app at all. The diagnosis holds.

**The correction:** the device evidence proves only that `accessibleNavigation` is *not* set by Reduce Motion. **It does not establish which of the two candidate replacements is correct**, and they imply materially different implementations:
- **`MediaQuery.of(c).disableAnimations`** — if the iOS embedder sets that bit from Reduce Motion, `AppMotion.reduce()` stays a **pure function of `BuildContext`**, all 38 existing call sites keep working unchanged, and no `WidgetsBindingObserver` is needed anywhere.
- **`PlatformDispatcher.instance.accessibilityFeatures.reduceMotion`** — bypasses `MediaQuery`, so live updates need `didChangeAccessibilityFeatures` wired into every stateful caller (Option A's stated con).

**Whichever option is selected, the implementer must run this deciding experiment first**, on a simulator with Reduce Motion **on**, and paste both values into the commit body:
```dart
debugPrint('disableAnimations=${MediaQuery.of(context).disableAnimations} '
           'reduceMotion=${PlatformDispatcher.instance.accessibilityFeatures.reduceMotion}');
```
If `disableAnimations` is `true`, take the simple path and ignore the observer machinery. **Do not implement the observer version on the assumption that it is required.**

**Option A (recommended)**: **Read `PlatformDispatcher.instance.accessibilityFeatures.reduceMotion` directly (`dart:ui`), OR'd with the existing `accessibleNavigation` check**, in `AppMotion.reduce()`, and have call sites rebuild on `WidgetsBindingObserver.didChangeAccessibilityFeatures` rather than relying solely on `didChangeDependencies` (which only fires on `MediaQuery` ancestor changes, and `PlatformDispatcher` reads bypass `MediaQuery` entirely).
  - *Pros*: Fixes the defect on iOS for actual Reduce Motion users without breaking the existing `MediaQueryData(accessibleNavigation: true)` widget-test injection pattern relied on elsewhere (§2.7) — the OR keeps every current test passing. Fixes every current and future `AppMotion.reduce()` call site at once, including `auto_advance_timer.dart`.
  - *Cons*: `AppMotion.reduce()` can no longer be a pure function of `BuildContext` alone if call sites need live updates outside of a `MediaQuery` rebuild; each `StatefulWidget` using it needs a `WidgetsBindingObserver` override added (currently only `thinking_background.dart` has one, for the ticker). Touches more than one file.

**Option B**: **Leave the code as-is; correct the documentation instead** — rename Issue 138 / R0's intent from "Reduce Motion" to "reduced motion for accessibility navigation (VoiceOver / Switch Control)," and change this guide's §5.2 item 8 device-test instruction from "enable Reduce Motion" to "enable VoiceOver."
  - *Pros*: Zero code risk; matches the convention this codebase already uses everywhere else (`auto_advance_timer.dart` reads the same flag directly); no new widget-test surface to cover.
  - *Cons*: Ships nothing for the accessibility population the issue was actually filed for. A user who enables Reduce Motion — the far more common accessibility setting — sees no change. The feature's name continues to promise something the code does not deliver.

**Option C**: **Add the `reduceMotion` check narrowly, only inside `AnimatedThinkingBackground`**, leaving `AppMotion.reduce()` and `auto_advance_timer.dart` untouched.
  - *Pros*: Smallest possible change; fixes exactly the widget Issue 138 named.
  - *Cons*: Leaves `AppMotion.reduce()` itself still wrong for any future caller who reasonably expects it to mean real Reduce Motion; produces two different "reduce motion" checks in the codebase reading two different signals, which is the same inconsistency §2.7 warns against propagating.

Your selection: Proceed with Option A.

---

### Issue 142: The app talks to the network far more than it needs to, and that is the main battery cost

**In plain terms:** the biggest battery drain on a phone is usually not drawing pictures — it is **waking up the radio to talk to the internet**. Right now every player's phone reports "I'm still here" to the server **every 10 seconds**, and each of those tiny messages is pushed out to *everyone else's* phone, which then redraws its whole screen. In a five-player game that is roughly **150 screen redraws and 30 network writes every minute**, forever, just to say nobody has left. The server only actually cares about this every **10 minutes**.

**Status**: ⚠️ Confirmed Unresolved — measured by reading the code this session, not estimated. Four separate causes, in descending order of likely impact:

1. **The heartbeat is ~60× more frequent than the server's own threshold.** `game_service.dart:320` runs `Timer.periodic(const Duration(seconds: 10))` writing `lastSeen` per player. The server treats a seat as abandoned only after `PRESENCE_STALE_MS = 600_000` — **10 minutes** (`functions/src/index.ts:179`). The client's own local staleness check is **60 s** (`game_service.dart:490`). Nothing in the system needs 10-second resolution.
2. **Every heartbeat write wakes every other device.** `game_service.dart:459` listens to the whole `players` collection and calls `notifyListeners()` **unconditionally** on every snapshot (`:501`), so a write whose only change is one player's `lastSeen` rebuilds every widget subscribed to `GameService` on all five phones. Five writers × 6 writes/min × 5 receivers ≈ **150 rebuilds/min per room**, plus the radio wake each delivery costs.
3. **A rejected-callable storm whenever anyone goes quiet.** The `deadPlayers` loop at `game_service.dart:485-499` fires `handleDisconnect` for any player unseen for 60 s — **and it is not gated to the host**, so every remaining device fires it, on every snapshot. But the server only honours a presence disconnect after 10 minutes (`index.ts:1180`). For the ~9 minutes in between, four devices × ~30 snapshots/min ≈ **1,000+ rejected Cloud Function invocations per stale player**, each one a network round trip on every phone and a billed invocation.
4. **Continuous full-screen repainting on the three longest screens.** `AnimatedThinkingBackground` repaints 15 `CustomPaint` particles every frame on craft, vote and reveal, and `phase4_reveal.dart:83` runs `Timer.periodic(200 ms)` calling `setState(() {})` — a full rebuild five times a second for the whole reveal phase. The particle step also hardcodes a 60 fps delta (`* 0.016`), so on a 120 Hz ProMotion device it both draws twice as often **and** drifts twice as fast.

**One thing that is already right:** the app takes no wake-lock, so the screen still sleeps normally. **One thing that is not:** `didChangeAppLifecycleState` (`game_service.dart:341`) handles only `resumed` — there is no `paused` branch, so nothing deliberately stops the heartbeat when the app leaves the foreground.

**⚠️ Read this before choosing:** *there is no battery measurement harness in this project, and a simulator cannot produce a trustworthy battery number.* Causes 1–3 are **exactly countable** — writes per minute, callable invocations, snapshot deliveries — so a fix can be proven with numbers. Cause 4 can only be judged on a real device with Xcode Instruments. That asymmetry is the main reason for the recommendation below.

**Option A (recommended)**: **Fix the traffic, not the pixels.** Raise the heartbeat interval (e.g. 10 s → 30 s, still six beats inside the client's 60 s window and twenty inside the server's 10 min), make the players listener skip `notifyListeners()` when the only field that changed is `lastSeen`, gate the `handleDisconnect` loop to the host **and** add a per-player cooldown so it cannot re-fire every snapshot, and stop the heartbeat on `AppLifecycleState.paused`.
  - *Pros*: Attacks the dominant drain — radio wake — and every part of it is **countable**, so "it worked" is a number rather than an impression: writes/min, invocations/hour, rebuilds/min. Cuts the Firebase bill at the same time (fewer writes, dramatically fewer function invocations). **Zero visual change**, so it cannot damage the app's look. Each of the four sub-fixes is a handful of lines.
  - *Cons*: Touches presence, which is load-bearing and has already produced Issues 120, 123 and 141 — so it needs careful falsification against the 10-minute window, and the client's 60 s local threshold has to keep at least 2–3 beats of margin. Leaves the ~60 fps repaint untouched, so a phone parked on the craft screen still burns GPU.

**Option B**: **Fix the rendering.** Idle or throttle the particle layer (e.g. cap it at 30 fps, or pause it while a modal/overlay covers the screen), drive particle motion from real elapsed time instead of the hardcoded `0.016`, and drop the reveal countdown from 5 Hz to 1 Hz.
  - *Pros*: Addresses a genuinely continuous cost on the three screens players sit on longest, and fixes a real correctness bug for free — particles currently drift at double speed on any 120 Hz device. Purely presentational, so it cannot break game logic or presence.
  - *Cons*: **The improvement cannot be measured with anything this project currently has** — it needs a physical device and Instruments, and device time is exactly what has been scarce for three waves. Touches the app's signature look, so it needs design review. Leaves the network traffic, which is probably the larger drain, entirely in place.

**Option C**: **Do A and B together as one wave.**
  - *Pros*: Battery is a sum; fixing one half yields a partial result that is easy to mistake for "the fix did not work". The two sets of changes touch different files and cannot conflict.
  - *Cons*: Mixes presence-logic risk with visual risk in a single wave, and **with no battery harness you could not attribute the outcome to either half** — which is the same "we cannot observe it" trap that produced the last three verification failures. Roughly doubles the review surface for a problem that has no measured baseline yet.

Your selection: Proceed with Option A.

---

### Issue 143: Nothing ever deletes anything — rooms, their sub-documents, and anonymous sign-ins accumulate forever

**In plain terms:** every game room ever created is still sitting in the database, along with a login account for every person who ever joined one. The code already stamps each room with an **"expires in 8 hours"** date — but **nothing ever looks at that stamp**, so nothing is ever cleaned up. It is a filing cabinet where every folder gets an expiry sticker and nobody ever empties it.

**Status**: ⚠️ Confirmed Unresolved — `ROOM_TTL_MS = 8 * 60 * 60 * 1000` (`functions/src/index.ts:181`) and `expiresAt: ttlFrom(...)` is written and refreshed at **ten** sites across `createRoom`, `joinRoom`, `startGame`, `submitAnswer` and the phase advances. But `grep -rn "onSchedule|pubsub|scheduler" functions/` returns **nothing**: all 16 deployed functions are `onCall`, and **no Firestore TTL policy is configured**. The expiry stamp is written and never read. The user's own console screenshot shows the resulting scale — dozens of room documents and a full page of anonymous users going back weeks.

**⚠️ The trap that makes the obvious fix wrong on its own — and it is already happening in production.** Firestore's built-in TTL deletes **only the document**, never its subcollections. Rooms own `players`, `sealed` and `embeddings`. The user's screenshot shows room **`BGHW` rendered in italics with "This document does not exist, it will not appear in queries or snapshots" — while still owning a `sealed` subcollection.** That is an orphaned subtree: invisible to the app, invisible to a room listing, still consuming storage, and unreachable by any cleanup that only targets room documents. **Any option that touches room lifecycle must handle subcollections explicitly.**

**On the anonymous users:** Firebase never expires them, and one is created per join. They are cheap (Authentication is not billed by stored user count on the current plan) but they are not free of risk — the list is an ever-growing surface, and `authUid` is referenced by player documents. **A purge must therefore exclude any UID still referenced by a non-expired room**, or a player mid-match loses their session.

**Option A (recommended)**: **A single nightly scheduled Cloud Function that does all three jobs** — find rooms whose `expiresAt` has passed, `recursiveDelete()` each room subtree (document *and* subcollections), then delete anonymous auth users older than a chosen age whose UID is not referenced by any surviving room.
  - *Pros*: One place, one schedule, one log to read — and `firestore.recursiveDelete()` in the Admin SDK is purpose-built for exactly the subcollection problem in the ⚠️ above. Because it runs in your own code, it can enforce the ordering that matters (delete room subtrees **first**, then compute which UIDs are still referenced, then purge auth) which no combination of platform features can. Fully testable in the emulator suite, which is this project's strongest gate.
  - *Cons*: Requires a scheduled function — Cloud Scheduler, which has a small standing cost and needs the Blaze plan — and it is **the first scheduled function in this codebase**, so it adds a new deploy surface and a new failure mode (a silent job that stops running). A bulk-delete job is also the most destructive code in the repo; it needs a dry-run mode and a hard cap on deletions per run before it is ever pointed at production.

**Option B**: **Turn on Firestore's native TTL policy for `expiresAt`, and add a smaller scheduled function only for the leftovers** (orphaned subcollections and anonymous users).
  - *Pros*: The platform does the bulk of the work on its own schedule with no code and no invocations for the room documents themselves — and **the `expiresAt` field already exists and is already maintained**, so the room half is close to a configuration change rather than a feature. Degrades gracefully: if the cleanup function breaks, rooms still expire.
  - *Cons*: **Two mechanisms with different schedules operating on the same data**, which is harder to reason about than one — TTL deletes the parent whenever it gets to it (Google documents this as typically within 24 h of expiry, not promptly), so the function must be written to find subtrees whose parent is *already gone*, which is a strictly harder query than "find expired rooms". Confirm the current billing treatment of TTL deletions before assuming they are free.

**Option C**: **Clean up nothing automatically; add a manual maintenance script** run by hand when the console looks cluttered.
  - *Pros*: No scheduler, no standing cost, no new deploy surface, and no automated process that can ever delete something it should not have. Easiest to reason about and to abandon. Perfectly adequate while the app has few real users.
  - *Cons*: Relies on a human remembering, which is the same class of control that failed twice in the playthrough re-aims (§2.34). The orphaned-subtree problem keeps growing silently in the meantime, and a manual script run rarely is *more* dangerous per-run than a nightly one, because it deletes a far larger batch each time with far less recent testing.

Your selection: Proceed with Option A. However, before proceeding, ook into how much the scheduled function would cost and report that to me first.

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

#### 2.35 A new gate rule runs against every file the gate is ever pointed at, not just the one it was written for

Rule R6 was written to stop a block in the five-player soak from drifting away from its specification. It works: a one-word title change and a one-word assertion change each fail the gate, and an empty manifest fails FATAL rather than passing vacuously — all three reproduced independently.

**But `check_playthrough_evidence.sh` takes a report path, and the no-argument invocation targets a different report** (`docs/playthrough_findings_marionette.md`, the Wave N record). R6 read the manifest as globally authoritative, so E47/E48/E49 — which exist only in the five-player report — were reported as three missing blocks, and **a gate that had exited 0 for months began exiting 1**. The regression shipped one commit after the option was chosen, and it is exactly the con that had been written down against that option: *"a stale manifest will produce false failures that erode trust in the gate."*

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

**S2 (Wave S) closes this mechanically.** `docs/playthrough_manifest.md` is the single source of truth for block titles and assertion text. Rule R6 in `scripts/check_playthrough_evidence.sh` fails the gate if any governed block's title or `**Specified assertion:**` field does not match the manifest verbatim. Changing either now requires editing the manifest in the same commit, which shows up in the diff. `docs/playthrough_evidence/ARTEFACTS.tsv` records every screenshot at capture time with a `depicts` column, making the "real screenshot of the wrong screen" failure visible as a mismatch rather than something only a person opening the file can catch. **What R6 still does not prove:** that the assertion is true, or that the artefact actually shows what it claims. Opening every screenshot and asking what it shows remains a standing obligation (§9 of `agent_execution_guide.md`).

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

### Issues 65–140 — August 8 to 30, 2026

**64 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

| Area | Issues | Where the surviving contract lives |
|---|---|---|
| **Wave U / U1 — playthrough manifest scoping & R6** (`docs/playthrough_manifest.md` Report column scoping; `scripts/check_playthrough_evidence.sh` normalises paths and filters rows by report under test; zero-rows-overall remains FATAL while ungoverned reports pass cleanly) | 140 | `scripts/check_playthrough_evidence.sh`; `docs/playthrough_manifest.md`; `docs/ongoing_general_errors.md` §2.35 |
| **Wave S / S1 — analyze warning cleanup** (15 removals: unused imports, dead declarations, orphaned cascade imports) | 139 | `agent_execution_guide.md` §3 |
| **Wave R in-game polish & accessibility** (in-game background omits the particle layer when `AppMotion.reduce()` is true — ⚠️ **but see Issue 141: that gate reads VoiceOver/Switch Control, not iOS Reduce Motion, so 138's user-facing claim is not yet true on a device.** The code change is correct and its guard is falsified; it is the *flag* that is wrong, and **138's resolution is contingent on 141**; in-game AppBar sizes dynamically to measured text at the live text scaler; dealt-card overlay grows to fit the longest catalogue prompt). **Each verified by reading the source and re-running its falsification, not by reading the commit.** | 136, 137, 138 | `design_ui_direction.md` §6, §8; `lib/widgets/thinking_background.dart`; `lib/widgets/in_game_app_bar.dart`; `lib/widgets/dealt_card_overlay.dart` |
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
| **Pre-demo E2E** — first playthrough after the security wave: full 3-round match on three simulators, 13 of 15 blocks with device evidence, all cited screenshots present. **Seat recovery after a force-quit device-verified for the first time.** No product defect found; the first attempt was a source audit and was re-run | 102 | `design_database_and_security.md` §5; `docs/playthrough_findings_marionette.md` |
| **Chosen deck ignored — every game played The Daily Grind** (`_selectedDeck` initialised once, read once, never assigned; `startGame` trusted the caller's deck over the room's). Fixed **A+C**: server resolves from `room.selectedDeckId` *and* rejects a mismatched claim with `invalid-argument`; dead field deleted; family-friendly toggle now writes through so it cannot desync the lobby from the room | 106 | `design_prompt_system.md` §2; `functions/src/index.ts:293`; `test/deck_selection_test.dart` |
| **Evidence mechanical gate & E10/E11 device verification** — `check_playthrough_evidence.sh` tool enforcing R1–R4 with 3 exit codes; E10 in-game leave auto-end verified on both remaining devices (`e10_p1_gameover.png`, `e10_p2_gameover.png`); E11 release build verified with zero DEBUG controls (`e11_release_lobby.png`); repointed dead citations to `functions/src/index.ts:986` | 105 | `docs/agent_execution_guide.md` §2–§3; `scripts/check_playthrough_evidence.sh`; `docs/playthrough_findings_marionette.md` |
| **Web E2E Playthrough (Wave I)** — Playwright automated harness (`test/web_e2e/`); I1 evidence gate widened with strict PNG requirement for W blocks; W1–W16 3-player match with falsification, truth, forgeries, voting lockout, unmasking, standings, GameOver, mid-match refresh restoral, case file share, console hygiene, and below-3 auto-end; W17–W19 responsive sweeps across mobile (375x812), tablet (768x1024), and desktop (1280x800) with 15 screenshots | 106 (Wave I) | `docs/playthrough_findings_web.md`; `test/web_e2e/`; `scripts/check_playthrough_evidence.sh` |
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
| Playthrough evidence and its provenance | `playthrough_findings_marionette.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |
| Full history of any resolved item | `git log` |

**A note on keeping this file short.** It was 903 lines in August, cut to 559, and cut again to ~200 on August 21. Both times the cause was the same: **each pass appended its summary without removing the one it superseded** — Issues 93–95 appeared three times, and §1 accumulated six stacked banners. When you resolve something, move the durable consequence into the design doc above and leave **one line** here. If you are adding a paragraph to this file, ask first whether it belongs in a design doc instead.
