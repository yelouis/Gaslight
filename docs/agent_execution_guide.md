# Agent Execution Guide — Queue Blocked: two low-priority selections pending (Issues 147, 148) — August 31, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue, and nothing is broken.** Wave W is delivered and verified; every gate is green and the cleanup job is running live in production as intended. The two open issues were filed *because* the queue emptied — they are the last two known loose ends, and neither is urgent.

**Do not start either. Do not invent work.** The only legitimate actions today are in §4.

**Every number and literal string in this document is a decision, not a suggestion.**

---

## 1. Verified baseline — measured this session on `d071201`

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **267 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **112 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 17 functions |
| `check_playthrough_evidence.sh` *(no args → marionette)* | **exit 0** — 21 blocks, R6: 0 of 3 govern |
| `… docs/playthroughs/findings_marionette.md` | **exit 0** — 20 PASS, 1 NOT RUN |
| `… docs/playthroughs/findings_web.md` | **exit 0** — 20 PASS |
| `… docs/playthroughs/findings_5player.md` | **exit 0** — 28 PASS, 0 NOT RUN, R6: 3 of 3 |

**All ten gates green.** Playthrough totals across all three reports: **68 PASS, 1 NOT RUN, 0 FAIL** — the single `NOT RUN` is E9, which is Issue 148.

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.**

**Read every other exit code bare, never through a pipe.**

**Production state:** `cleanupDaily` runs `every day 04:00` America/Los_Angeles with **`CLEANUP_DRY_RUN=false`** — **live deletion is active.** Verified by reading the deployed service this session. The backlog is cleared: 101 orphaned subtrees and 200 stale anonymous accounts purged, `authUsersEligible` now 0.

**⚠️ The flag is revision-scoped.** `firebase deploy --only functions` creates a new Cloud Run revision **without** it, silently reverting the job to dry-run — still running, still logging, no longer deleting. **After any functions deploy, re-apply it** and confirm by reading it back:
```bash
gcloud run services update cleanupdaily --region us-central1 --update-env-vars CLEANUP_DRY_RUN=false
```
Full detail in `design_database_and_security.md` §10.5.

---

## 2. Already delivered — do NOT rework

Verified this session by reading source, re-running gates bare, re-running falsifications in a clean worktree, and reading the live deployed environment.

### Wave W

- **W1 (Issue 146) ✅** — `handleDisconnect` captures the transaction result and recursive-deletes the room reference **after** the commit, with the failure logged and swallowed so the caller is never told a completed close failed. **The transaction's contents were left untouched** — the diff is two hunks — which was the explicit instruction on a path that has produced Issues 85, 87 and 123. The sweep is capped at `DEFAULT_ORPHAN_SWEEP_LIMIT = 100`, and **the `break` sits before the counter increment, so the `.get()` scan is bounded rather than just the deletions**.
  **Independently falsified:** reverting only the post-commit block gives **111 passing, 1 failing** (`AssertionError: expected false to be true` on `sealedSnap.empty`) while all three over-reach guards still pass — exactly one test catches the regression, and the guards are not false positives.
- **W2 (Issue 145) ✅** — the production precondition was genuinely done first: room `VYRY` closed by host departure, with room, players and `sealed` all confirmed gone **before** the flag was flipped. **Prediction matched outcome:** the dry run forecast 101 orphans and ~200 accounts; the live runs delivered 98 + 3 = **101** and **200**, `authUsersReferenced=1` throughout. The cap fired on its first live run, stopping the scan at 100.

### Earlier

- **V1 (143, 144)** — deployed environment verified before redeploy; deploy gate restored; first dry-run log captured. **The 24-hour retention window is settled** (user, August 31, 2026) — rationale and the **`ROOM_TTL_MS` coupling invariant** in `design_database_and_security.md` §10.4.
- **U1 (140)** manifest `Report` column + R6 scoping · **U2 (141)** real `reduceMotion` bit, device-verified · **U3 (142)** 30 s heartbeat, rebuild suppression, host-gated disconnects · **U4 (135)** E49 PASS, **first genuine device verification of Issue 123**.
- **S1 (139)** · **E47/E48** · **R0 (138)** · **R1 (136)** · **R2 (137)** · soak blocks **E22–E49** · **Wave Q** · **Wave P** · **Wave O's six** · **Issues 96–105, 50–95, 31, 28/29**.
- **The playthrough reorganisation** — everything under `docs/playthroughs/`; R5 falsified after the move.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it before the next upload.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206, not 207.** Deleting `_lastReactionSentTime` removed the `prefer_final_fields` info attached to it. Bar is **206 and no new infos**.
- **E48 merged two specified artefacts into one.**
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`** — U2/R0 evidence captured during E49's match.
- **R0 leaves `..repeat()` in `initState`** of `AnimatedThinkingBackground`; `didChangeDependencies` always runs before the first frame.
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 3. The blocked queue

| Issue | What it decides | Urgency |
|---|---|---|
| **147** | Whether to guard `EmberBackdrop`'s ticker, restructure it, or accept it | Low — visuals are already correct; costs are a frame request on one screen and a latent `pumpAndSettle` hazard |
| **148** | Whether to annotate E9 as superseded, re-run it, or leave it | Low — the gate is green either way |

**They are independent.** Either can be done without the other, in any order.

**⚠️ Issue 147 is the last known instance of the `pumpAndSettle` trap.** Until it is resolved, this warning must keep being carried: **`pumpAndSettle` on the game-over screen will hang** — ten minutes per test, no output — because `_EmberBackdropState`'s controller repeats unconditionally (`game_over_screen.dart:900`) even when `build` correctly returns the static painter. `game_over_screen_test.dart` and `badge_pills_overflow_test.dart` both use `pump()` today, which is why nobody has hit it. **If you write a game-over widget test before 147 is resolved, use `pump(Duration)`.**

**The only legitimate actions until a selection appears:**
1. Answer questions about the state of the repository.
2. Re-run the baseline in §1 to confirm it still holds.
3. If a gate that §1 says is green goes red, investigate and **file** it.
4. **After any `firebase deploy --only functions`, re-apply `CLEANUP_DRY_RUN=false` and read it back** (§1). This is maintenance of an existing decision, not new work.

---

## 4. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** Cleanup deletes them with admin credentials, which bypass rules — **do not add match blocks to make cleanup easier.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — authorship is correctly published *after* the unmask window closes.
- **Never let a client bound exceed the server's.** `castVote` and `closeUnmaskWindow` are the models.
- **The presence window gates the ACTION, not the caller.**
- **`pendingScoreDeltas` is flushed at three sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`.
- **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and **caps every match at three departures**.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130).
- **Heartbeat cadence is 30 s** (Issue 142) against a 10-minute server presence window and a 60 s client-local check. **Do not raise it above 30 s** without also raising the 60 s threshold.
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and **must always exceed `ROOM_TTL_MS` (8 h) by a wide margin** — the two constants live in different files and neither references the other. See `design_database_and_security.md` §10.4.
- **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`** and must not be collapsed to `lastRefreshTime` — that would make brand-new accounts look 24 hours old and purge live players.
- **The nightly orphan sweep is retained as a backstop** even though W1 fixed the source. It covers the post-commit failure path and any orphan created by another route, such as a manual console delete. **Do not remove it.**
- **`CLEANUP_DRY_RUN=false` is revision-scoped** and must be re-applied after every functions deploy (§1, §10.5).
- **`AppMotion.reduce` must keep the `accessibleNavigation` OR term** (Issue 141) — every existing widget test injects it.
- **`lastReaction` / `lastReactionAt` in `player_state.dart` are deliberately retained dead fields** from Issue 74. Dropping them needs a rules deploy and a data migration.
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit. `functions/src/prompt_decks.ts` is the source of truth.

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and both at once (142 C); **migrating `withOpacity` → `withValues` across the tree to clear the 206 infos (139 C)**; Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C); enabling deletion before fixing the leak (145 B); splitting `CLEANUP_DRY_RUN` into two flags (145 C); relying on the nightly sweep instead of fixing the orphan source (146 B); fixing the source while leaving the sweep uncapped (146 C).

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 5. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| **All playthrough material** | **`docs/playthroughs/`** |
| Block titles + specified assertions (R6's source) | `docs/playthroughs/manifest.md` |
| Screenshot hand-off record | `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| Rules, seat tokens, presence, heartbeat, **retention, cleanup & the deploy trap (§10)** | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, header sizing, **which signal means "reduce motion"** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 6. Validation standard

**A prediction followed by a matching outcome beats either alone.** Wave V's dry run forecast 101 orphans and 200 accounts; Wave W's live runs delivered exactly that. Neither number would have proved much on its own — a rehearsal is a claim about what code *would* do, and a live run is the same code reporting on itself.

**Name the alarm condition before the run.** W2's spec said `authUsersReferenced == 0` would mean the guard protecting live accounts had matched nothing. Naming the stop condition in advance is what turns monitoring into a check rather than a narration.

**Read a safety mechanism's output as evidence, not a checkbox.** `CLEANUP_DRY_RUN` existed to prevent premature deletion; its first log found a leak every gate, test and playthrough had missed.

**Be suspicious of counts that cannot both be true.** `roomsScanned=0` beside `orphanSubtreesSwept=101` was the whole finding, in one line.

**Cap the expensive operation, not the visible one.** Bounding deletions while leaving a `.get()` per document unbounded fixes the symptom and leaves the cost.

**A failure that reverts in the safe direction is still a failure.** The live-deletion flag vanishes on redeploy: the job keeps running and stops deleting, and nobody notices.

**Prefer the minimal structural change on a path with history.**

**Re-run every gate yourself before trusting a table.** This file has twice recorded a gate result that did not match reality.

**Falsify every guard**, and when you *repair* or *move* one, re-run its falsifications to prove you did not weaken it.

**Open the artefact and ask what it shows.** R5 proves a path resolves; R6 proves a block still claims the right assertion. Neither proves the claim is true.

**Read exit codes bare.**

---

## THE LOOP

```
(1) A selection exists? If NO -- stop. Do not start work on an unselected
    issue, and never fill in a `Your selection:` line yourself.
(2) If the spec says "determine X first", DO THAT AND RECORD THE RESULT
    before writing the fix.
(3) If the item is a playthrough: read docs/playthroughs/manifest.md FIRST,
    keep the heading and Specified assertion BYTE-IDENTICAL, and OPEN EVERY
    CITED SCREENSHOT, asking what it SHOWS -- not whether it exists.
(4) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body.
(5) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(6) VALIDATE, including every over-reach guard, then RE-RUN THE GUARD WITH
    THE FIX REMOVED and confirm it fails.
(7) ENUMERATE EVERY INVOCATION of anything you changed and run them all.
(8) RE-RUN THE FULL BATTERY -- exit codes bare, except flutter analyze,
    where the bar is 0 errors / 0 warnings and the code is always 1.
(9) COMMIT BEFORE DEPLOYING, and after any functions deploy RE-APPLY
    CLEANUP_DRY_RUN=false and read it back.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**The queue is empty until Issues 147 or 148 are selected. Do not invent work.**
