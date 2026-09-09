# Agent Execution Guide — Awaiting Selections: no approved work — September 8, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue.** Wave Z is delivered and verified and all ten gates are green.

**⚠️ 17 issues (153–169) are open in `docs/ongoing_general_errors.md`, filed from a live playthrough on September 8, 2026 — but NONE of them has been selected yet.** Every one ends in a blank `Your selection: _____` line. **That line belongs to the user and an agent must never fill it in.** Until a selection exists, an open issue is a question, not an instruction: **do not implement any option, and do not treat an `(recommended)` label as approval.** When selections land, this guide gets rewritten with the specs; until then §2.1 is still the only legitimate action.

**Do not invent work.** The only legitimate actions are in §2.1.

**Every number and literal string in this document is a decision, not a suggestion.**

---

## 1. Verified baseline — measured this session on `18865d3`

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **276 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **112 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 17 functions |
| all four `check_playthrough_evidence.sh` invocations | **exit 0** |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** Use `lib test`, never bare `flutter analyze`.

**Read every other exit code bare, never through a pipe.**

**⚠️ `pubspec.yaml` is at `1.0.0+7` and build 7 has NOT been uploaded.** Wave Z1 bumped it. **Do not bump again** before the next upload. TestFlight builds 5 and 6 are live; **6 carries the Issue 152 leave bug**, so once 7 ships, expire both 5 and 6.

**⚠️ Any `.xcarchive` under `build/ios/` predates Wave Z1 and must be rebuilt** before a release. `flutter build ipa` will fail at the *export* step on this machine (no Apple Distribution certificate) — **that is expected and is not a build failure**; the archive is still produced and Organizer distributes it. **Verify the archive's timestamp and `CFBundleVersion`, never the `.ipa`.** Full detail in `README.md` → Releasing.

**Production:** `cleanupDaily` runs `every day 04:00` America/Los_Angeles with `CLEANUP_DRY_RUN=false`. ⚠️ **Revision-scoped — re-apply after any functions redeploy.**

---

## 2. Already delivered — do NOT rework

### Wave Z

- **Z1 (Issue 152) ✅** — the leave latch is reset in a `finally`:
  ```dart
  try { await gs.leaveRoom(); } finally { if (mounted) _isLeaving = false; }
  ```
  **Independently falsified:** removing the `finally` makes **both** new tests fail while **all seven original tests still pass**, including *"double-tapping confirm leaves exactly once"* — which was left unedited. That is the right shape: the new tests catch the regression and the existing suite is untouched.
  **The falsifying test was built correctly**, which was the hard part: it uses `pumpLobbyScreen` once and then drives the second room through `gameService.createRoom` inside `runAsync` **without re-pumping**. Re-pumping would have constructed a fresh `State` and passed against the broken code.
  See lesson **§2.40** in `ongoing_general_errors.md` for the durable version of this trap.

### 2.1 The only legitimate actions now

1. Answer questions about the state of the repository.
2. Re-run the baseline in §1 to confirm it still holds.
3. If a gate that §1 says is green goes red, investigate and **file** it.
4. **After any `firebase deploy --only functions`, re-apply `CLEANUP_DRY_RUN=false` and read it back.** Maintenance of an existing decision, not new work.
5. Ship a release by following `README.md` → **Releasing**.

### Earlier

- **Y1 (151)** title-screen version label read from the bundle at runtime. **It worked the first time it was needed** — it is what let a "missing feature" report be resolved as a build-version artefact (Issue 150).
- **Y2 (149)** R5 checks cited evidence paths **anywhere in a block, including `NOT RUN` blocks**, while never requiring one.
- **Issue 150 — CLOSED with no code change.** The deck `PEEK INSIDE` affordance ships, renders, and is legible on build 6. **Do not "improve" it without a new selection.**
- **X1 (147)** `EmberBackdrop` ticker guarded — **the `pumpAndSettle` trap is closed** · **X2 (148)** E9 annotated as superseded by E31.
- **W1 (146)** post-commit `recursiveDelete` on lobby close, sweep capped with the **scan** bounded · **W2 (145)** live deletion enabled; the dry run predicted the live run exactly.
- **V1 (143, 144)** deployed environment verified; **24-hour retention settled** with its `ROOM_TTL_MS` coupling invariant.
- **U1 (140)** manifest scoping + R6 · **U2 (141)** real `reduceMotion` bit, device-verified · **U3 (142)** 30 s heartbeat, host-gated disconnects · **U4 (135)** E49 PASS — **first device verification of Issue 123**.
- **S1 (139)** · **E47/E48** · **R0 (138)** · **R1 (136)** · **R2 (137)** · soak blocks **E22–E49** · **Wave Q** · **Wave P** · **Wave O's six** · **Issues 96–105, 50–95, 31, 28/29**.
- **The playthrough reorganisation** — everything under `docs/playthroughs/`.
- **The release runbook** — `README.md` → **Releasing**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206.** Bar is **206 and no new infos**.
- **Waves Y1 and Z1 both bumped `pubspec.yaml` inside their own commits** rather than at release time. Harmless and useful — the on-screen version matches what the next build reports.
- **`EmberBackdrop` and `AnimatedThinkingBackground` both keep `..repeat()` in `initState`.**
- **E48 merged two specified artefacts into one.**
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`.**
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 3. Invariants & intentional decisions — do NOT change

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
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and **must always exceed `ROOM_TTL_MS`** — see `design_database_and_security.md` §10.4.
- **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`.**
- **The nightly orphan sweep is retained as a backstop.**
- **`CLEANUP_DRY_RUN=false` is revision-scoped** — re-apply after every functions deploy.
- **`AppMotion.reduce` must keep the `accessibleNavigation` OR term** and reads `platformDispatcher.accessibilityFeatures.reduceMotion`, which is **not** an inherited widget — live reaction needs `didChangeAccessibilityFeatures`.
- **The title-screen version is read from the bundle at runtime**, never from a constant — `design_ui_direction.md` §10.
- **`main.dart`'s bootstrap is load-bearing.** `dotenv.load()` must complete before `runApp()`. **Nothing added there may be allowed to throw** — `initAppVersion()` is wrapped in `try`/`catch` for this reason.
- **`LobbyScreen` renders both the entry screen and the parlour from one `State`** (`:433–449`), pushed once as a route. **Any flag on that `State` outlives every room** — Issue 152 is what happens when one is set and never reset.
- **`lastReaction` / `lastReactionAt` are deliberately retained dead fields** from Issue 74.
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit.

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and both at once (142 C); migrating `withOpacity` → `withValues` (139 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C); enabling deletion before fixing the leak (145 B); splitting `CLEANUP_DRY_RUN` into two flags (145 C); relying on the nightly sweep instead of fixing the orphan source (146 B); fixing the source while leaving the sweep uncapped (146 C); driving `EmberBackdrop`'s controller from `build` (147 B); accepting the unguarded ticker (147 C); re-running E9 (148 B); leaving its stale reason (148 C); treating unchecked `NOT RUN` citations as a review habit (149 B); forbidding artefact paths in `NOT RUN` blocks entirely (149 C); **enlarging or relocating the `PEEK INSIDE` affordance (150 A/B/C — closed, no change needed)**; generating the version from `pubspec.yaml` (151 B) and injecting it with `--dart-define` (151 C); **clearing `_isLeaving` from `build` (152 B) and scoping the guard to the dialog (152 C)**.

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 4. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| **Release runbook** | **`README.md` → Releasing** |
| **All playthrough material** | **`docs/playthroughs/`** |
| Block titles + specified assertions (R6's source) | `docs/playthroughs/manifest.md` |
| Screenshot hand-off record | `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| Rules, seat tokens, presence, heartbeat, retention, cleanup & the deploy trap | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, header sizing, reduce-motion signal, title-screen version | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 5. Validation standard

**A guard flag lives as long as the object holding it.** `_isLeaving` guards "a leave is in flight", but it sits on a `State` that outlives every room. When a flag's lifetime is longer than the thing it guards, it needs an explicit reset — and the reset belongs in a `finally`, because the failure path is exactly when it matters.

**Write the test for the journey, not the defence.** Seven leave tests existed, including the double-tap case the latch was written for. None left two rooms in a row — the ordinary thing a user does, and the only one that exposes the bug.

**A test that reconstructs the world hides state bugs.** Re-pumping the widget between steps would have made this test pass against broken code. When the defect *is* surviving state, the test must not reset it.

**Analyze ≠ compile.** Prove the native build before writing code against a new plugin.

**A checker's exemption list is a map of where its guarantees stop.**

**A test can prove a widget is in the tree; it cannot prove a person can find it.**

**A prediction followed by a matching outcome beats either alone**, and **name the alarm condition before the run**.

**A failure that reverts in the safe direction is still a failure.**

**Re-run every gate yourself before trusting a table.**

**Falsify every guard**, and when you *repair* one, re-run its original falsifications to prove you did not weaken it.

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
(9) SHIPPING? Follow README -> Releasing. Next build is 1.0.0+7. The CLI
    export failure is expected; distribute the .xcarchive from Organizer.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**The queue is empty. Do not invent work.**
