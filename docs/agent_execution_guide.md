# Agent Execution Guide — Queue Complete: one deferred item awaiting its trigger — September 7, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue and nothing is broken.** Wave Y is delivered and verified; all ten gates are green. One issue is **deferred by the user with a named trigger** (§3) — it is not open work, and it must not be started without a selection.

**Do not invent work.** The only legitimate actions are in §3.

**Every number and literal string in this document is a decision, not a suggestion.**

---

## 1. Verified baseline — measured this session on `475a559`

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **274 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **112 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 17 functions |
| `check_playthrough_evidence.sh` *(no args → marionette)* | **exit 0** |
| `… docs/playthroughs/findings_marionette.md` | **exit 0** — 20 PASS, 1 NOT RUN |
| `… docs/playthroughs/findings_web.md` | **exit 0** — 20 PASS |
| `… docs/playthroughs/findings_5player.md` | **exit 0** — 28 PASS, 0 NOT RUN, R6 3 of 3 |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** Use `lib test`, never bare `flutter analyze`.

**Read every other exit code bare, never through a pipe.**

**⚠️ `pubspec.yaml` is at `1.0.0+6`, and build 6 has NOT been uploaded.** Wave Y1 bumped it. **Do not bump it again** before the next upload, or you will skip a number for no reason. `1.0.0+5` is the highest build in App Store Connect.

**⚠️ The archive at `build/ios/archive/Runner.xcarchive` is STALE.** It was cut **2026-08-31 19:54**, and Y1 landed **2026-09-07 21:06** — so it does **not** contain the version label. **Any release must rebuild.** See `README.md` → Releasing.

**Production:** `cleanupDaily` runs `every day 04:00` America/Los_Angeles with `CLEANUP_DRY_RUN=false`. ⚠️ **Revision-scoped — it vanishes on any functions redeploy.**

---

## 2. Already delivered — do NOT rework

Verified this session by reading source, re-running gates bare, and re-running falsifications in a clean worktree.

### Wave Y

- **Y1 (Issue 151) ✅** — `package_info_plus` reads the installed bundle during `main()`'s bootstrap (`initAppVersion()`), holding `v${version} (${buildNumber})` in `appVersionDisplay`; the entry screen renders it below `READ MANUAL` at 10.5 pt, `ivoryColor.withValues(alpha: 0.4)`.
  **The spec's hardest requirement was met:** the native iOS build was proven **before** any UI was written (`flutter build ios --release --no-codesign`, Runner.app 49.9 MB) and re-run at completion (50.0 MB) — the *analyze ≠ compile* lesson honoured rather than recited.
  **Independently falsified:** removing the render makes tests 1 and 2 fail with `Found 0 widgets with text "v1.0.0 (6)"`, while the graceful-fallback test correctly still passes — it asserts the *absence* of a line, so it is not sensitive to the removal. Exactly the right shape.
  ⚠️ **The failure path is deliberately non-fatal.** `PackageInfo.fromPlatform()` is wrapped in `try`/`catch` and falls back to an empty string, rendering `SizedBox.shrink()`. `main.dart`'s bootstrap already contains the load-bearing `dotenv.load()` — a missing `.env` kills the app before it paints. **Nothing else added to that bootstrap may be allowed to throw.**
- **Y2 (Issue 149) ✅** — R5 now checks any `docs/playthroughs/evidence/*.png` path cited **anywhere in a block, including `NOT RUN` blocks**, while never *requiring* one. The scan for `PASS`/`FAIL` blocks was widened from the `Observed` field to the full body, so `Artefact depicts:` is covered.
  **Independently falsified both ways:** a bogus path in a `NOT RUN` block exits **1** naming `E9`; removing the citation entirely still exits **0**. The over-reach guard the original exemption existed to provide is intact. The script header's falsification record was updated to state the guard exempts from **requiring**, not from **checking**.

### Earlier

- **X1 (147)** `EmberBackdrop` ticker guarded — **the `pumpAndSettle` trap is closed**; all fifteen `.repeat(` call sites in `lib/` are guarded · **X2 (148)** E9 annotated as superseded by E31.
- **W1 (146)** post-commit `recursiveDelete` on lobby close, sweep capped with the **scan** bounded · **W2 (145)** live deletion enabled; the dry run predicted the live run exactly.
- **V1 (143, 144)** deployed environment verified; **24-hour retention settled** with its `ROOM_TTL_MS` coupling invariant.
- **U1 (140)** manifest scoping + R6 · **U2 (141)** real `reduceMotion` bit, device-verified · **U3 (142)** 30 s heartbeat, host-gated disconnects · **U4 (135)** E49 PASS — **first device verification of Issue 123**.
- **S1 (139)** · **E47/E48** · **R0 (138)** · **R1 (136)** · **R2 (137)** · soak blocks **E22–E49** · **Wave Q** · **Wave P** · **Wave O's six** · **Issues 96–105, 50–95, 31, 28/29**.
- **The playthrough reorganisation** — everything under `docs/playthroughs/`.
- **The release runbook** — `README.md` → **Releasing**. **Use it rather than reconstructing the steps.**

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206.** Bar is **206 and no new infos**.
- **Y1 bumped `pubspec.yaml` to `1.0.0+6`** as part of its commit rather than leaving it to the release step. Harmless and useful — the on-screen version now matches what the next build will report. **Do not bump again before uploading build 6.**
- **`EmberBackdrop` and `AnimatedThinkingBackground` both keep `..repeat()` in `initState`.**
- **E48 merged two specified artefacts into one.**
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`.**
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 3. The only open item — deferred, with a trigger

**Issue 150 — the deck "PEEK INSIDE" affordance is effectively invisible.** Deferred by the user: *"skip this for now because this might be just an issue with the versioning."*

**Do not implement it and do not close it.**

⚠️ **One fact that must not be re-derived.** The deferral is about confirming behaviour **on a device**, not about whether the feature shipped. That is settled: `strings -a` on the build-5 archive finds `PEEK INSIDE`, `A TASTE OF WHAT'S INSIDE` and `SHUFFLE`, all **absent** from the build-2 IPA, and `test/deck_peek_test.dart:150` passes. **The button is in the app and it renders.** It is 8.5 pt text at `Positioned(left: 2, bottom: 2)` on a **150 × 110 pt** card, shown only on the centred card, nested inside the card's own tap handler that selects the deck.

**The trigger:** build 6 ships with Y1's version label → the user confirms on-device which build they are running → they re-check whether the button is findable. **Only then does 150 get a selection.**

**The only legitimate actions until then:**
1. Answer questions about the state of the repository.
2. Re-run the baseline in §1 to confirm it still holds.
3. If a gate that §1 says is green goes red, investigate and **file** it.
4. **After any `firebase deploy --only functions`, re-apply `CLEANUP_DRY_RUN=false` and read it back** (`README.md` → Releasing → §3). Maintenance of an existing decision, not new work.

---

## 4. Invariants & intentional decisions — do NOT change

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
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and **must always exceed `ROOM_TTL_MS`** — the constants live in different files and neither references the other. See `design_database_and_security.md` §10.4.
- **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`** — collapsing it to `lastRefreshTime` would purge live players.
- **The nightly orphan sweep is retained as a backstop** even though W1 fixed the source.
- **`CLEANUP_DRY_RUN=false` is revision-scoped** — re-apply after every functions deploy.
- **`AppMotion.reduce` must keep the `accessibleNavigation` OR term** and reads `platformDispatcher.accessibilityFeatures.reduceMotion`, which is **not** an inherited widget — live reaction needs `didChangeAccessibilityFeatures`.
- **The title-screen version is read from the bundle at runtime**, never from a constant — see `design_ui_direction.md` §10. A version display that can disagree with the installed artefact is worse than none, because it will be trusted.
- **`main.dart`'s bootstrap is load-bearing.** `dotenv.load()` must complete before `runApp()`; a missing `.env` kills the app before it paints. **Nothing added there may be allowed to throw** — `initAppVersion()` is wrapped in `try`/`catch` for exactly this reason.
- **`lastReaction` / `lastReactionAt` are deliberately retained dead fields** from Issue 74.
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit.

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and both at once (142 C); migrating `withOpacity` → `withValues` (139 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C); enabling deletion before fixing the leak (145 B); splitting `CLEANUP_DRY_RUN` into two flags (145 C); relying on the nightly sweep instead of fixing the orphan source (146 B); fixing the source while leaving the sweep uncapped (146 C); driving `EmberBackdrop`'s controller from `build` (147 B); accepting the unguarded ticker (147 C); re-running E9 (148 B); leaving its stale reason (148 C); treating unchecked `NOT RUN` citations as a review habit (149 B); forbidding artefact paths in `NOT RUN` blocks entirely (149 C); **generating the version from `pubspec.yaml` (151 B) and injecting it with `--dart-define` (151 C)**.

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 5. Where the contracts live

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
| Palette, typography, header sizing, reduce-motion signal, **title-screen version label (§10)** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 6. Validation standard

**Analyze ≠ compile.** A package can resolve, pass analysis, and fail the iOS build. Y1 proved the native build *before* writing UI against a new plugin, which is the shape to copy.

**A checker's exemption list is a map of where its guarantees stop.** R5 exempted `NOT RUN` blocks from *requiring* an artefact; that quietly meant it stopped *checking* one. Y2 closed it without touching the guard that made the exemption correct — and the test proving the guard survives matters more than the test proving the hole is closed.

**A test can prove a widget is in the tree; it cannot prove a person can find it.** `deck_peek_test.dart` passes and the button is still undiscoverable (Issue 150). Y1's "found on first pump with no gesture" assertion exists because of that.

**A prediction followed by a matching outcome beats either alone**, and **name the alarm condition before the run**.

**Read a safety mechanism's output as evidence, not a checkbox.**

**Be suspicious of counts that cannot both be true.**

**Cap the expensive operation, not the visible one.**

**A failure that reverts in the safe direction is still a failure.**

**Re-run every gate yourself before trusting a table.**

**Falsify every guard**, and when you *repair* or *move* one, re-run its falsifications to prove you did not weaken it.

**Open the artefact and ask what it shows** — including in `NOT RUN` blocks.

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
(9) SHIPPING? Follow README -> Releasing. pubspec is ALREADY at 1.0.0+6 and
    build 6 is not yet uploaded -- do not bump again. Commit before deploying,
    and re-apply CLEANUP_DRY_RUN=false after any functions deploy.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**The queue is empty. Issue 150 is deferred until its trigger fires. Do not invent work.**
