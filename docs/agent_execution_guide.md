# Agent Execution Guide — Active Build: Wave Y — put the version on the title screen, then close the unchecked-citation hole — September 1, 2026

**You are an engineering agent with no memory of this project.**

**Two selections are made. A third issue is deliberately deferred.** Build exactly these.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **Y1** | Show the app's version discreetly on the title screen | **151 → A** | client | — |
| **Y2** | Extend R5 to check artefact paths cited in `NOT RUN` blocks | **149 → A** | tooling | — |

**No deploy is needed.** Nothing here touches `functions/src`; `./scripts/check_deploy_fresh.sh` must stay at exit 0.

**One item = one commit.** They are independent, but **do Y1 first** — a build is waiting on it (§0).

**Every number, formula and literal string below is a decision, not a suggestion.**

---

## 0. Ordering, and the deferred item

**Y1 → Y2.** Y1 is blocking a release: the user intends to ship **`1.0.0+6`** to TestFlight, and the whole point of Y1 is that build 6 should be the first build a tester can identify on sight. Land Y1, then bump and ship (`README.md` → Releasing). Y2 is tooling and can follow at any time.

**Issue 150 (the deck "PEEK INSIDE" affordance) is DEFERRED at the user's direction** — *"skip this for now because this might be just an issue with the versioning."* **Do not implement it, and do not close it.**

⚠️ **One fact the next agent should not re-derive:** the deferral is about confirming behaviour on a device, **not** about whether the feature shipped. That was already settled — `strings -a` on the build-5 archive finds `PEEK INSIDE`, `A TASTE OF WHAT'S INSIDE` and `SHUFFLE`, all absent from the build-2 IPA, and `test/deck_peek_test.dart:150` passes. **The button is in the app and it renders.** It is 8.5 pt text at `Positioned(left: 2, bottom: 2)` on a 150 × 110 pt card. **The trigger for revisiting 150 is: Y1 ships, the user confirms on-device which build they are running, and then re-checks whether the button is findable.**

---

## 1. Verified baseline — measured on `d7fbe47`

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **271 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **112 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 17 functions |
| `check_playthrough_evidence.sh` *(no args → marionette)* | **exit 0** — 21 blocks, 28 artefacts |
| `… docs/playthroughs/findings_marionette.md` | **exit 0** — 20 PASS, 1 NOT RUN |
| `… docs/playthroughs/findings_web.md` | **exit 0** — 20 PASS, 40 artefacts |
| `… docs/playthroughs/findings_5player.md` | **exit 0** — 28 PASS, 0 NOT RUN, R6 3 of 3, 37 artefacts |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** Use `lib test`, never bare `flutter analyze`.

**Read every other exit code bare, never through a pipe.**

**Production:** `cleanupDaily` runs `every day 04:00` America/Los_Angeles with `CLEANUP_DRY_RUN=false`. ⚠️ **That flag is revision-scoped and vanishes on any functions redeploy** — see `README.md` → Releasing → §3.

**Shipped iOS build:** TestFlight `1.0.0 (5)`, verified at binary level to contain all twelve checked features. **Build 4 is 26 client commits behind and is what most testers are running** — expiring it is a standing recommendation.

---

## 2. Y1 — Version on the title screen (151 → A)

**What this means for the user:** right now there is no way to tell, from inside the app, which build a phone is running. When a tester says "that feature isn't there", the only way to find out is to have them open TestFlight and read a number back. This puts it on the title screen.

**This cost a full debugging cycle on August 31.** A report of missing features required extracting strings from the shipped archive binary and diffing them against an older IPA to resolve — twelve features checked, all twelve present. The report was about *other people's* devices, on build 4. A version line would have answered it in five seconds.

### 2.1 Placement is already decided — it is not part of the implementation choice

- **Screen:** the title / entry state of `lib/screens/lobby_screen.dart` — the guest-ledger panel, whose heading `'THE GUEST LEDGER'` is at `:1187`.
- **Position:** immediately below the `READ MANUAL` `TextButton.icon` (`:1338–1352`), as the last child of that `Column`.
- **Format:** `v1.0.0 (6)` — marketing version **and** build number. **The build number is the part that distinguishes two TestFlight builds; a version without it is useless for this purpose.**
- **Styling:** discreet — roughly 10–11 pt, low-opacity ivory, `Lora`, consistent with the panel.
- ⚠️ **It must be plainly readable with no gesture, no menu, and no long-press.** Issue 150 is open right now *because* an affordance was made so subtle the person who commissioned it could not find it. Repeating that here would defeat the entire feature.
- **Entry state only.** Do not add it to the in-room lobby or any in-game screen; that is out of scope.

### 2.2 Implementation

**Step 1 — add the dependency and PROVE IT COMPILES BEFORE WRITING ANY UI.**

Add `package_info_plus` to `pubspec.yaml`, then immediately run a **real iOS build**:

```bash
flutter pub get
flutter build ios --release --no-codesign
```

⚠️ **`flutter analyze` and `flutter test` are not sufficient here and this is a recorded lesson: analyze ≠ compile.** `phosphor_flutter` once resolved cleanly, passed analysis, and then would not compile because `IconData` is a `final class`. `package_info_plus` is a native plugin with platform channels; if it is going to fail, it fails at the iOS build, and finding that out *after* writing the UI wastes the work. **If this build fails, STOP and file it — do not start swapping packages.**

**Step 2 — load it once during bootstrap, not at the render site.**

`main.dart` already awaits `dotenv.load()` before `runApp()`. Add the package-info load in the same place and hold the formatted string in a simple top-level holder.

- **Why bootstrap and not a `FutureBuilder`:** `PackageInfo.fromPlatform()` is async, so a `FutureBuilder` at the render site makes the line flash in after the first frame — on the *title screen*, which is the first thing a user sees. Loading it once up front makes every read synchronous.
- ⚠️ **Wrap it in `try`/`catch` and fall back to an empty string.** `main.dart`'s existing `dotenv.load()` is load-bearing — a missing `.env` kills the app before it paints (see `firebase.json`'s comment and `README.md` → Releasing → §1). **A version label must never acquire that power.** If `fromPlatform()` throws, the app must start normally and simply render no version line.

**Step 3 — render it.**

Append to the `Column` that ends with the `READ MANUAL` button. If the holder is empty, render `SizedBox.shrink()` rather than an empty `Text`.

⚠️ Note `isSmallHeight` is already in play in that subtree (`:1337`, `SizedBox(height: isSmallHeight ? 6 : 12)`) — the panel is **already height-constrained on small devices**. Add the smallest spacing that reads as deliberate, and verify at 320 × 568 (§2.3).

### 2.3 Validation

`package_info_plus` provides `PackageInfo.setMockInitialValues(...)` for tests — use it rather than mocking the platform channel by hand.

1. **The falsifying test.** Widget test on the entry screen with mocked package info (e.g. version `9.9.9`, build `42`) asserting `find.text('v9.9.9 (42)')` — or the agreed format — **findsOneWidget**. **Run it against current code and watch it fail** (no such text exists). Paste the failure into the commit body.
2. **⚠️ Over-reach guard — no gesture required.** Assert the version text is found **on the first pump, with no tap, scroll or long-press**. This is the assertion that prevents Issue 150 happening again in this wave; without it, a "discreet" implementation hidden behind an interaction would pass test 1 after a tap.
3. **Over-reach guard — nothing else moved.** Assert `CREATE ROOM`, `JOIN ROOM` and `READ MANUAL` all still render, **at 320 × 568 and at `textScaleFactor: 2.0`**. The guest-ledger panel is already height-constrained (`isSmallHeight`), and Issues 136 and 137 were both "one more line pushed content off a small screen". **Do not skip the small-device case.**
4. **The failure path is graceful.** With the holder empty (simulating a `fromPlatform()` failure), assert the entry screen still renders fully and no version line appears — and specifically that **the app does not fail to start**.
5. **The iOS build passes** — Step 1's `flutter build ios --release --no-codesign`, re-run at the end. Record it in the commit body.
6. **Full battery**: `flutter test` **≥ 271 + the new tests**; analyze still **0 errors, 0 warnings, 206 infos**; functions **112**; all four evidence gates exit 0.
7. **Manual confirmation, and it is the point of the item:** after building, the number shown on the title screen must match what TestFlight reports for that build. **A version display that can disagree with the installed artefact is worse than none, because it will be trusted.** Option A was chosen precisely because reading the bundle at runtime makes that disagreement impossible — do not replace it with a constant.

**Blast radius:** `pubspec.yaml` · `pubspec.lock` · `lib/main.dart` · `lib/screens/lobby_screen.dart` · a new widget test · **`docs/design_ui_direction.md`** — record that the title screen carries a discreet version label read from the bundle at runtime, and why a compile-time constant was rejected.

---

## 3. Y2 — Check artefact paths cited in `NOT RUN` blocks (149 → A)

**What this means for the user:** the evidence gate confirms every screenshot a report mentions really exists — except in blocks marked "not run", which it skips entirely. A citation in one of those went unchecked and turned out to name a file that had never existed.

### 3.1 The gap

`scripts/check_playthrough_evidence.sh` exempts `NOT RUN` blocks from rules R2–R5, deliberately, with its own falsification record — a block that legitimately was not run must not be forced to invent evidence. **That guard is correct and must survive this change.**

But the exemption is wider than intended. At `:151–157`:

```python
# Check NOT RUN rules (R5 over-reach guard: NOT RUN blocks carry no required artefact check)
if is_not_run:
    rmatch = reason_regex.search(body)
    if not rmatch or not rmatch.group(1).strip():
        violations.append(f"[{bid}] NOT RUN block is missing a non-empty **Reason:** line")
    continue
```

The `continue` skips everything, so a path *the block chose to mention* is never checked. **Wave X2's annotation to E9 cited `e31_p1_forgery_relinked.png`, a filename that has never existed, and all four gate invocations exited 0.**

There is a second, narrower gap in the same rule: for `PASS`/`FAIL` blocks, R5 scans only the **Observed** field (`cited_pngs = artefact_png_regex.findall(obs_content)`, `:194`). A path cited in `Artefact depicts:` — a field S2 introduced specifically to describe artefacts — is not checked either.

### 3.2 Implementation

1. **Check, but never require, in the `NOT RUN` branch.** Before the `continue` at `:157`, run the existing on-disk existence check over `artefact_png_regex.findall(body)`. If the block cites no paths, that is legal and it passes — **absence must stay legal, that is the whole point of the original guard.**
2. **Widen R5's scan for `PASS`/`FAIL` blocks** from `obs_content` to the full `body`, so `Artefact depicts:` is covered too. The regex is already anchored to `docs/playthroughs/evidence/…\.png` (`:123`), so `Reference:` fields citing source files cannot produce false positives.
3. **Count them.** The summary line's *"N artefact file paths verified on disk"* must include paths found by the widened scan, so the number reflects what was actually checked.
4. **⚠️ Update the falsification record in the script header.** The header documents the over-reach guard as *"NOT RUN blocks carry no required artefact check"*. That is still true and must stay true — but the record has to say the guard now exempts from **requiring**, not from **checking**, or the next reader will believe the guard was weakened by accident and restore the hole.

### 3.3 Validation

1. **The falsifying test.** Temporarily change E9's citation in `docs/playthroughs/findings_marionette.md` to a filename that does not exist. **Run the gate against current code: it exits 0 — that is the bug.** After the fix it must exit **1** with an R5 violation naming `E9`. Paste both exit codes, read **bare**.
2. **⚠️ Over-reach guard — the original exemption survives.** Temporarily remove the PNG path from E9's `Reason:` entirely, leaving prose. The gate must still exit **0**. **Without this, a fix that simply requires an artefact in `NOT RUN` blocks passes test 1 and breaks the guard the rule was built to provide.**
3. **Over-reach guard — the `Reason:` rule still fires.** A `NOT RUN` block with an empty `Reason:` must still be a violation.
4. **The widened `PASS`/`FAIL` scan works.** Put a bogus path in an `Artefact depicts:` field of a `PASS` block (E47 has one) and confirm the gate fails; restore it and confirm it passes. **This tests point 2 of §3.2, which test 1 does not reach.**
5. **All four invocations exit 0 on the real reports**, with counts unchanged or higher: marionette 21 blocks / 20 PASS / 1 NOT RUN, web 20 PASS, 5-player 28 PASS / R6 3 of 3.
6. **Nothing else moved:** `flutter test` still **271**, functions **112**.

**Blast radius:** `scripts/check_playthrough_evidence.sh` only · **`docs/ongoing_general_errors.md`** — update §2.39, which records this hole, to note it is now closed.

---

## 4. Definition of Done

**Y1** — [ ] **iOS build run and passing before any UI was written**, and again at the end, both recorded · [ ] falsifying widget test observed to fail first · [ ] **version found on first pump with no gesture** · [ ] `CREATE ROOM` / `JOIN ROOM` / `READ MANUAL` all still render at **320 × 568 and textScale 2.0** · [ ] empty-version path renders no line and **the app still starts** · [ ] format includes the **build number** · [ ] entry state only · [ ] suite ≥ 271 + new tests, analyze unchanged · [ ] the on-screen number matches TestFlight for that build.

**Y2** — [ ] falsifying test: bogus citation in a `NOT RUN` block fails the gate (and exits 0 before the fix), both codes pasted bare · [ ] **a `NOT RUN` block with no artefact still passes** · [ ] empty-`Reason:` rule still fires · [ ] bogus path in a `PASS` block's `Artefact depicts:` fails · [ ] all four invocations exit 0 with unchanged counts · [ ] the script header's falsification record updated to say the guard exempts from *requiring*, not *checking* · [ ] §2.39 updated.

**Across the wave** — [ ] **0 errors · 0 warnings · 206 infos** · `flutter test` ≥ 271 · functions **112** · decks exit 0 · all four evidence gates exit 0 · **deploy still exit 0** · [ ] Issues **149 and 151** moved into the **single** existing Resolved heading; **Issue 150 left open and deferred**, not closed.

---

## 5. Already delivered — do NOT rework

- **X1 (147)** `EmberBackdrop` ticker guarded — both `didChangeDependencies` and `didChangeAccessibilityFeatures`, observer removed in `dispose`. **The `pumpAndSettle` trap is closed**; all fifteen `.repeat(` call sites in `lib/` are guarded.
- **X2 (148)** E9 annotated as superseded by E31; its citation corrected to `e31_p3_relinked.png` after opening it.
- **W1 (146)** post-commit `recursiveDelete` on lobby close, transaction untouched; orphan sweep capped with the **scan** bounded · **W2 (145)** live deletion enabled; dry run predicted the live run exactly.
- **V1 (143, 144)** deployed environment verified; **24-hour retention settled** with its `ROOM_TTL_MS` coupling invariant (`design_database_and_security.md` §10.4).
- **U1 (140)** manifest scoping + R6 · **U2 (141)** real `reduceMotion` bit, device-verified · **U3 (142)** 30 s heartbeat, host-gated disconnects · **U4 (135)** E49 PASS — **first device verification of Issue 123**.
- **S1 (139)** · **E47/E48** · **R0 (138)** · **R1 (136)** · **R2 (137)** · soak blocks **E22–E49** · **Wave Q** · **Wave P** · **Wave O's six** · **Issues 96–105, 50–95, 31, 28/29**.
- **The playthrough reorganisation** — everything under `docs/playthroughs/`.
- **The release runbook** — `README.md` → **Releasing**. Preflight, web, iOS beta, functions, ordering. **Use it rather than reconstructing the steps.**

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. `pubspec.yaml` is at **`1.0.0+5`**, which is **already uploaded** — the next build must be **`1.0.0+6`** or higher.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206.** Bar is **206 and no new infos**.
- **`EmberBackdrop` and `AnimatedThinkingBackground` both keep `..repeat()` in `initState`.**
- **E48 merged two specified artefacts into one.**
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`.**
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 6. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — authorship is published *after* the unmask window closes.
- **Never let a client bound exceed the server's.**
- **The presence window gates the ACTION, not the caller.**
- **`pendingScoreDeltas` is flushed at three sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`.
- **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start** and **caps every match at three departures**.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130).
- **Heartbeat cadence is 30 s** against a 10-minute server window and a 60 s client check.
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and **must always exceed `ROOM_TTL_MS`** — see §10.4.
- **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`.**
- **The nightly orphan sweep is retained as a backstop.**
- **`CLEANUP_DRY_RUN=false` is revision-scoped** — re-apply after every functions deploy.
- **`AppMotion.reduce` must keep the `accessibleNavigation` OR term** and reads `platformDispatcher.accessibilityFeatures.reduceMotion`, which is **not** an inherited widget — live reaction needs `didChangeAccessibilityFeatures`.
- **`lastReaction` / `lastReactionAt` are deliberately retained dead fields** from Issue 74.
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit.
- **`main.dart`'s bootstrap is load-bearing.** `dotenv.load()` must complete before `runApp()`; a missing `.env` kills the app before it paints. **Nothing else added to that bootstrap may be allowed to throw.**

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and both at once (142 C); migrating `withOpacity` → `withValues` (139 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C); enabling deletion before fixing the leak (145 B); splitting `CLEANUP_DRY_RUN` into two flags (145 C); relying on the nightly sweep instead of fixing the orphan source (146 B); fixing the source while leaving the sweep uncapped (146 C); driving `EmberBackdrop`'s controller from `build` (147 B); accepting the unguarded ticker (147 C); re-running E9 (148 B); leaving its stale reason (148 C); **treating unchecked `NOT RUN` citations as a review habit rather than a rule (149 B) and forbidding artefact paths in `NOT RUN` blocks entirely (149 C)**; **generating the version from `pubspec.yaml` (151 B) and injecting it with `--dart-define` (151 C)** — both were rejected because they can disagree with the installed artefact, and a version display that can lie is worse than none.

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 7. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| **Release runbook — preflight, web, iOS beta, functions, ordering** | **`README.md` → Releasing** |
| **All playthrough material** | **`docs/playthroughs/`** |
| Block titles + specified assertions (R6's source) | `docs/playthroughs/manifest.md` |
| Screenshot hand-off record | `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| Rules, seat tokens, presence, heartbeat, retention, cleanup & the deploy trap | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, header sizing, reduce-motion signal, **title-screen version label** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 8. Validation standard

**A checker's exemption list is a map of where its guarantees stop.** R5 exempted `NOT RUN` blocks from *requiring* an artefact; that quietly meant it stopped *checking* one, and the first citation through the hole was invented. Y2 closes it without touching the guard that made the exemption correct.

**A test can prove a widget is in the tree; it cannot prove a person can find it.** `deck_peek_test.dart` passes and the button is still undiscoverable (Issue 150). Y1's "no gesture required" assertion exists because of that.

**Analyze ≠ compile.** A package can resolve, pass analysis, and fail the iOS build. Prove the native build before writing code against a new plugin.

**A prediction followed by a matching outcome beats either alone**, and **name the alarm condition before the run**.

**Read a safety mechanism's output as evidence, not a checkbox.**

**Be suspicious of counts that cannot both be true.**

**Cap the expensive operation, not the visible one.**

**A failure that reverts in the safe direction is still a failure.**

**Prefer the minimal structural change on a path with history.**

**Re-run every gate yourself before trusting a table.**

**Falsify every guard**, and when you *repair* or *move* one, re-run its falsifications to prove you did not weaken it.

**Open the artefact and ask what it shows** — including in `NOT RUN` blocks, which no rule checked until Y2.

**Read exit codes bare.**

---

## THE LOOP

```
(1) A selection exists? If NO -- stop. Never fill in a `Your selection:` line.
(2) If the spec says "determine X first" or "prove it compiles first", DO THAT
    AND RECORD THE RESULT before writing the fix.
(3) If the item is a playthrough: read docs/playthroughs/manifest.md FIRST,
    keep the heading and Specified assertion BYTE-IDENTICAL, and OPEN EVERY
    CITED SCREENSHOT -- including in NOT RUN blocks -- asking what it SHOWS.
(4) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body.
(5) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(6) VALIDATE, including every over-reach guard, then RE-RUN THE GUARD WITH
    THE FIX REMOVED and confirm it fails.
(7) ENUMERATE EVERY INVOCATION of anything you changed and run them all.
(8) RE-RUN THE FULL BATTERY -- exit codes bare, except flutter analyze,
    where the bar is 0 errors / 0 warnings and the code is always 1.
(9) SHIPPING? Follow README -> Releasing. Bump past 1.0.0+5, commit before
    deploying, and re-apply CLEANUP_DRY_RUN=false after any functions deploy.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**After Y1 and Y2, only the deferred Issue 150 remains. Do not implement it without a selection.**
