# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**Wave AA in progress, September 10, 2026.**
- **AA1 (Issue 155 → Option A) — ✅ VERIFIED and RESOLVED.** Deleted `DealtCardOverlay` widget (`lib/widgets/dealt_card_overlay.dart`) and removed the overlay branch from `Phase2CraftScreen` (`lib/screens/phase2_craft.dart`), allowing players to land directly on the writing screen without a redundant modal gate or misleading DISMISS/INSPECT buttons. Preserved the `:180` phase-change block (forgery->truth SnackBar and rotation tracking). Updated `docs/design_ui_direction.md:128` to record the removal. Cleaned up dead overlay taps in `test/phase2_craft_test.dart`, `test/reroll_deck_exhaustion_test.dart`, and `test/ui_e2e_test.dart`. Added `test/craft_dealt_overlay_removal_test.dart` asserting zero-gesture hit-testability and over-reach guard; falsified with ModalBarrier.
- **AA2 (Issue 156 → Option A) — ✅ VERIFIED and RESOLVED.** Wrapped `Phase2CraftScreen` Scaffold body in `GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => FocusScope.of(context).unfocus())` in `lib/screens/phase2_craft.dart`, allowing players to dismiss the keyboard by tapping away without forfeiting their answer via submission. Verified with widget test in `test/craft_keyboard_dismiss_test.dart` asserting focus release on empty background tap; verified unedited over-reach guards on submit and re-roll buttons (`craft_submit_test.dart` and `phase2_craft_test.dart`); falsified by removing wrapper (`Expected: false, Actual: true`).
- **AA3 (Issue 157 → Option A) — ✅ VERIFIED and RESOLVED.** Added `FocusNode` and `WidgetsBindingObserver` to `Phase2CraftScreen` (`lib/screens/phase2_craft.dart`), calling `Scrollable.ensureVisible(fieldContext, alignment: 1.0, duration: AppMotion.fast)` in a post-frame callback on metrics change and focus gain when `viewInsets.bottom > 0`. Prevents player typing blind behind keyboard. Added widget tests in `test/craft_keyboard_scroll_test.dart` asserting field bottom <= 367 on 375x667 with `viewInsets.bottom = 300`, and verified unedited over-reach guards with `viewInsets.bottom = 0` and pinned button bounds in `craft_submit_test.dart`; falsified without ensureVisible (`Actual: 559.5` vs `Expected: <= 367.0`).
- **AA4 (Issue 154 → Option A) — ✅ VERIFIED and RESOLVED.** Added live character counter displaying `$count/$kMaxAnswerLength` beneath the answer TextField in `Phase2CraftScreen` (`lib/screens/phase2_craft.dart`), driven by a `ValueListenableBuilder` on `_answerController`. Directly counts trimmed string length (`_answerController.text.trim().length`) to match submit guard without imposing a silent `maxLength` cap. Renders in normal ink color (`0x992C1E16`) at <= 100 characters and error color (`colorScheme.error`) at > 100 characters. Added widget tests in `test/craft_character_counter_test.dart`; verified unedited over-reach guards (`phase2_craft_test.dart` and `craft_submit_test.dart`); falsified by asserting absence of counter.
- **AA5 (Issue 166 → Option A) — ✅ VERIFIED and RESOLVED.** Added stems map for all 150 prompts across all 5 catalogue decks (`hypotheticals`, `real_life`, `unhinged_quirks`, `love_life`, `rated_r_nsfw`) in `functions/src/prompt_decks.ts` with module-load assertion (`validateDeckStems`) that throws if any stem key does not match a prompt in its deck. Emitted stems into `lib/utils/prompt_decks.dart` via `scripts/generate_prompt_decks_dart.mjs`. Rendered non-prefilling sentence stem hint in `Phase2CraftScreen` (`lib/screens/phase2_craft.dart`) beneath the answer counter (`Starter: "$stem…"` for truth, `Writing as $targetName: "$stem…"` for forgery). Verified `_answerController.text` is never populated. Verified catalogue prompts render stem, non-catalogue prompts render no stem and do not throw in `test/craft_sentence_stem_test.dart` (2 tests, 279 passing). Verified module load and stem lookup in `functions/test/prompt_decks.spec.ts` (4 tests, 116 passing). Falsified check_decks_in_sync.sh on tampered stem (exit 1); falsified module load on bogus stem key (`Stem prompt key ... does not match any prompt in deck ...`). Over-reach guard `test/guidance_strings_test.dart` passes unedited.
- **AA6 (Issue 158 → Option A) — ✅ VERIFIED and RESOLVED.** Added read-only recap of the player's own submitted answer and prompt in `Phase2CraftScreen`'s waiting UI (`_buildWaitingUI` in `lib/screens/phase2_craft.dart`), tracking `_lastSubmittedAnswer` and `_lastSubmittedPrompt` set in `_submitAnswer` before clearing the text controller. Added reset to `null` in the phase and rotation change block (`if (state.currentPhase != _lastPhase || state.currentRotationIndex != _lastRotation)` at line 219) ensuring state surviving across rotations does not leak previous answers. Verified with widget tests in `test/craft_waiting_recap_test.dart`: (1) single submission recap displays exact text and prompt; (2) consecutive rotations driven across State without re-pumping clears rotation 1 answer on rotation 2 ready transition and renders rotation 2 answer upon second submission. Falsification confirmed: removing reset caused test 2 to fail with found matching candidate "Bob forgery answer 1" while test 1 passed. Omitted answer revision per Option A scope note.
- **AA7 (Issue 153 → Option A) — ✅ VERIFIED and RESOLVED.** Hardened the room-code TextField at `lib/screens/lobby_screen.dart:1289` with `autocorrect: false`, `enableSuggestions: false`, `keyboardType: TextInputType.text`, and `inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')), UpperCaseTextFormatter()]`. The uppercase formatter preserves `newValue.selection` to prevent caret jumping. Retained `textCapitalization: TextCapitalization.characters`, `maxLength: 4`, and `_joinRoom`'s defensive upper-casing at `:197` without altering `generateRoomCode`. Added `test/lobby_room_code_input_test.dart` testing property assertions (`autocorrect` and `enableSuggestions` false), input filtering and auto-capitalization (`ab1c!d` -> `ABCD`), caret position preservation when typing into the middle, and `UpperCaseTextFormatter` selection preservation. Verified all four unedited over-reach guards (`lobby_entry_test.dart`, `lobby_join_error_test.dart`, `lobby_leave_test.dart`, `lobby_version_test.dart`). Falsified by removing formatters: test 2 failed (`Expected: 'ABCD', Actual: 'ab1c'`) and test 3 failed (`Expected: 'ABC', Actual: 'AbC'`).
- **AA8 (Issue 161 → Option A) — ✅ VERIFIED and RESOLVED.** Hardened `setReady` in `functions/src/index.ts` to reject calls when `room.currentPhase !== "vote"` with `failed-precondition`, preventing late un-ready calls from writing to `readyPlayers` after phase advance. In `lib/screens/phase3_vote.dart`, restricted `_buildWaitingUI` transition to voters (`!isTarget`), allowing target to remain on `_buildVotingUI`. Converted target ready button from local `_submitted` latch to server-driven toggle displaying `NOT READY` when `state.readyPlayers[me.id] == true` and `I'M READY` otherwise, calling `setPlayerReady(!isReady)` with re-entrancy protection (`_isSettingReady`). Added reader change reset for `_submitted`, `_localSelectedAuthorId`, and `_isSettingReady`. Added emulator test in `functions/test/game_e2e.spec.ts` asserting `setReady(false)` in `reveal` phase is rejected with `FAILED_PRECONDITION`. Added widget tests in `test/phase3_vote_target_ready_toggle_test.dart` (target ready/un-ready toggle, and reader change without re-pump reflecting new card readiness). Over-reach guard `test/phase3_vote_test.dart` passes unedited. Falsified by reverting to one-way button.
- **AA9 (Issue 159 → Option A) — ✅ VERIFIED and RESOLVED.** In `lib/screens/phase4_reveal.dart:110` (`_buildBestForgeryBanner`), suppressed the banner unless `maxVotes >= 2` and exactly one author holds `maxVotes` (showing nothing on tie or when maxVotes < 2). Prevents single-vote celebrations at 3 players and eliminates the arbitrary Map order tie-break bug. Added `test/reveal_best_forgery_banner_test.dart` (3 tests: 3 players with 1 vote -> no banner, 1-1 tie -> no banner, clear winner with 2 votes -> banner renders). Over-reach guards: all 7 tests in `test/phase4_reveal_test.dart` pass unedited. Falsified against un-fixed logic (tests 1 & 2 failed, test 3 passed). Confirmed clean reveal screen flow without banner.
- **AA10 (Issue 163 → Option A) — ✅ VERIFIED and RESOLVED.** Implemented per-round scoring multiplier (`Math.max(1, state.currentRound ?? 1)`) in `ScoringLogic.calculateScores` across both `functions/src/scoring_logic.ts` and `lib/utils/scoring_logic.dart`. Deliberately excluded revenge unmask guesses (±1 fixed social penalty). Amended §4 to record the reversal of the narrow scoring escalation while P7/P9/P11 remain rejected. Added tests in `functions/test/scoring_logic.spec.ts` (x1/x2/x3 and absent default) and mirrored tests in `test/scoring_logic_test.dart`. Over-reach guards (Case A and Case B) pass unedited. Falsified against unmultiplied logic.
- **AA11 (Issue 169 → Option A) — ✅ VERIFIED and RESOLVED.** Itemised score deltas per rule and rewrote manual copy in plain language. Added `ScoreBreakdownItem` and `scoreBreakdown?: Record<string, ScoreBreakdownItem[]>` to `CardModel` (`functions/src/scoring_logic.ts` & `lib/models/card_model.dart`). Added `calculateScoresAndBreakdown` and `calculateBreakdown` in `ScoringLogic`. Stashed `pendingScoreBreakdown` in `sealed/{card.targetPlayerId}` during `advancePhaseInternal`, added revenge guess breakdown items in `submitUnmaskGuess`, and wired flush across all 3 flush sites (`advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`) carrying `scoreBreakdown` to `room.cards` and clearing from `sealed`. Replaced reveal chip row in `lib/screens/phase4_reveal.dart` with itemised per-rule lines while strictly preserving player total lines (`${player.name}: $prefix${e.value}`). Rewrote `3. SCORING (Dynamic)` in `lib/screens/lobby_screen.dart` in plain language, explaining dynamic bounty, round multiplier, and demoting formula to footnote `* Formula: ceil((Players - 1) / (Forgeries + 1))`. Added 4 sum invariant fixtures (`functions/test/scoring_logic.spec.ts` & `test/scoring_logic_test.dart`); verified all 7 over-reach guards in `test/phase4_reveal_test.dart` pass unedited; verified 3 flush sites in `functions/test/game_e2e.spec.ts`; falsified by dropping `scoreBreakdown` at Flush Site 2 (`AssertionError: expected +0 to be above +0`); added widget test in `test/phase4_reveal_breakdown_test.dart`.


**Wave Z verified independently, September 7, 2026 — item delivered.**
- **Z1 (Issue 152 → Option A) — ✅ VERIFIED and RESOLVED.** Wrapped `await gs.leaveRoom()` in `try/finally` in `lib/screens/lobby_screen.dart` to reset `_isLeaving = false` upon leave completion, preventing the latch from persisting into subsequent rooms within the same session. Verified with widget test leaving two rooms consecutively without re-pumping `LobbyScreen`, verified mid-leave dialog block over-reach guard, and verified premature reset / missing reset falsification failures. Bumped version in `pubspec.yaml` to `1.0.0+7`.

**⚠️ Do not expire TestFlight build 5 until Z1 (build 7) ships.** Build 6 carries this bug, and testers need a working fallback. The next upload is **`1.0.0+7`**.

**Issue 150 is CLOSED with no code change** (user, September 7): *"No need to change anything. Once the version was updated, things look fine."* Its trigger fired favourably — on build 6 the user confirmed `v1.0.0 (6)` on the title screen and `PEEK INSIDE` renders legibly. **The original report was a build-version artefact, not a discoverability failure**, which is precisely what Issue 151's version label was built to disambiguate: the first time it was needed, it worked.

**Wave Y verified independently, September 1, 2026 — both items delivered.**
- **Y1 (Issue 151 → Option A) — ✅ VERIFIED and RESOLVED.** Read runtime bundle version and build number via `package_info_plus` during `main.dart` bootstrap (`initAppVersion()`), displayed discreetly below `READ MANUAL` in `lobby_screen.dart` (`ivoryColor.withValues(alpha: 0.4)`, `Lora` 10.5 pt). Verified native iOS compilation (`flutter build ios --release --no-codesign`), falsified widget tests in `test/lobby_version_test.dart` (asserted on first pump without gestures, 320x568 at text scale 2.0 without overflow, and graceful empty fallback). Bumped version to `1.0.0+6`.
- **Y2 (Issue 149 → Option A) — ✅ VERIFIED and RESOLVED.** Extended Rule R5 in `scripts/check_playthrough_evidence.sh` to check cited PNG paths across full `body` including `NOT RUN` blocks and `Artefact depicts:`, while strictly preserving the non-mandatory evidence invariant for `NOT RUN`. Fixed markdown field header regexes with `[ \t]` to prevent newline bleeding. Falsified against bogus citations in E9 (`exit 0` -> `exit 1`) and E47 (`exit 1`), verified over-reach guards (no PNG in E9 exits 0; empty Reason exits 1). All 4 evidence gate invocations exit 0 bare.
- **Issue 150 is deferred at the user's direction.**

**Wave X verified independently, August 31, 2026 — both items hold up.**

**X1 (Issue 147) — ✅ VERIFIED and RESOLVED.** `_EmberBackdropState` carries `WidgetsBindingObserver`, registers in `initState`, keeps `..repeat()` (matching the blessed `AnimatedThinkingBackground` shape), implements **both** `didChangeDependencies` and `didChangeAccessibilityFeatures` with `setState`, and removes the observer in `dispose` before disposing the controller. **Independently falsified this session:** removing both guards makes test 1 and test 3 fail with `pumpAndSettle timed out`, while tests 2 and 4 correctly still pass — they assert the build branch and dispose safety, which are independent of the ticker. **This was the last live instance of the `pumpAndSettle` trap:** every `.repeat(` call site in `lib/` now sits in a file that consults `AppMotion.reduce`, so the standing game-over caveat has been removed from `agent_execution_guide.md` rather than carried forward.

**X2 (Issue 148) — ✅ RESOLVED, with one correction applied this session.** `Verdict: NOT RUN` was correctly left untouched and the tally still reads **20 PASS, 1 NOT RUN, 0 FAIL**. **But the annotation cited a screenshot that does not exist** — `e31_p1_forgery_relinked.png`. The real artefacts are `e31_p3_relinked.png` and `e31_p5_left.png`. Corrected to the former, after opening it to confirm it shows what the annotation claims: FORGERY phase, room `YOGU`, the player writing as **BOB** — Charlie re-pointed to Bob after the 4→3 departure. **No gate caught this**, because rule R5's over-reach guard deliberately exempts `NOT RUN` blocks from artefact checks — which is now **Issue 149**.

**Wave X (X1 & X2) is ✅ VERIFIED and RESOLVED**:
- **X1 (Issue 147 → Option A)**: Implemented `WidgetsBindingObserver` in `_EmberBackdropState` (`game_over_screen.dart:889`), adding `didChangeDependencies` and `didChangeAccessibilityFeatures` to stop the `AnimationController` ticker when `AppMotion.reduce(context)` is true and restart when false, and removing the observer in `dispose()`. Falsified against un-fixed code with `pumpAndSettle timed out`. 4 widget tests in `test/ember_backdrop_reduce_motion_test.dart` cover settling, over-reach presence guard, live OS toggle, and clean disposal without `setState()`. Retired the last latent `pumpAndSettle` warning.
- **X2 (Issue 148 → Option A)**: Updated block **E9** in `docs/playthroughs/findings_marionette.md` to record that the historical 4-device blocker is obsolete, pointing to the passing 4-to-3 departure evidence in **E31** (`findings_5player.md`). `Verdict: NOT RUN` was strictly preserved. All 4 evidence gate invocations exit 0 bare (marionette reports 20 PASS, 1 NOT RUN, 0 FAIL).

**Wave W verified independently, August 31, 2026 — both items hold up, and this is the cleanest wave so far.**

**Independently reproduced this session, not taken from commit bodies:**
- **W1's falsification.** Reverting *only* the post-commit `recursiveDelete` block yields **111 passing, 1 failing** — `AssertionError: expected false to be true` on `sealedSnap.empty` — while all three over-reach guards still pass. That is the correct shape: exactly one test catches the regression, and the guards are not false positives. The transaction's contents were genuinely left untouched (the diff is two hunks), and the sweep's `break` sits **before** the counter increment, so the `.get()` scan is bounded and not just the deletions.
- **W2's live state.** Read directly from the deployed service: `{'name': 'CLEANUP_DRY_RUN', 'value': 'false'}`. Deletion is active and the flag has survived — which matters, because §10.5 records that a redeploy silently drops it.

**The dry run predicted the live run almost exactly**, which is the strongest evidence this project has produced about its own stored data: predicted **101** orphaned subtrees and ~**200** stale accounts; delivered **98 + 3 = 101** across two runs and **200**, with `authUsersReferenced=1` both times — the exclusion guard holding on real data. **The cap earned itself on its first live run**, stopping the scan at 100 and leaving the remainder for run 2.

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
| `flutter test` | **271 passing** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **112 passing** (including 8 cleanup unit/emulator tests + disconnect subtree deletion tests) |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH.** All 17 Cloud Functions and Firestore Rules exceed the latest tree commits. (Wave W1 delivered). |
| `./scripts/check_playthrough_evidence.sh` (all 4 invocations: no-args, marionette, web, 5player) | **exit 0** — all 4 invocations green (U1 / Issue 140 delivered) |
| `./scripts/check_playthrough_evidence.sh docs/playthroughs/findings_5player.md` | **exit 0** — 28 blocks, 37 artefacts on disk, R6: 3 of 3 manifest entries checked. |

**Read the exit code bare, not through a pipe.**

## ⚠️ Unresolved Issues & Suggestions

**Issues 153–169 were filed from a live playthrough on September 8, 2026** (build 7, iOS). They are ordered by the playthrough's own numbering, not by severity. Items 2, 5 and 6 of that report collapse into a single issue (**155**) because all three describe the same widget. Three items were ambiguous on filing and were clarified by the user before options were written: the craft-screen visibility failure is *the keyboard covering the field* (**157**), the irreversible ready is *the target's* on the vote screen (**161**), and the Quiplash comparison covers **all four** axes offered — core loop, tone, scoring and social dynamics (**165**).

**Read 162, 163 and 165 together before selecting any of them.** They are one design question approached from three sides — the empty target seat, the flat match arc, and the Quiplash resemblance — and a selection in 165 can moot the other two.

---

### Issue 153: Room code entry fights iOS autocorrect, and codes are unspeakable

**Status**: ✅ VERIFIED and RESOLVED (Option A delivered in Wave AA, September 10, 2026) — Hardened the room-code TextField in `lib/screens/lobby_screen.dart:1289` with `autocorrect: false`, `enableSuggestions: false`, `keyboardType: TextInputType.text`, and `inputFormatters` (`FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]'))` and `UpperCaseTextFormatter()`). Selection is preserved across text updates. Verified with `test/lobby_room_code_input_test.dart` (4 tests) and unedited over-reach guards (`lobby_entry_test.dart`, `lobby_join_error_test.dart`, `lobby_leave_test.dart`, `lobby_version_test.dart`). Falsified by removing formatters.

**Option A (recommended)**: **Harden the field** — set `autocorrect: false`, `enableSuggestions: false`, `keyboardType: TextInputType.text`, and add `FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]'))` plus an uppercasing formatter so the controller text matches what `_joinRoom` already upper-cases at `lobby_screen.dart:197`.
  - *Pros*: Fixes the reported failure at its source in one file; no server change, no migration, no effect on the existing 456,976-code space; the `room_code_field` widget key and every playthrough step that types into it keep working unchanged.
  - *Cons*: Does nothing for the *other* half of the complaint — reading "V K X Q" aloud across a table is still error-prone. Autocorrect is silenced but the code is still four arbitrary letters.

**Option B**: **Harden the field and draw codes from a word list** — do everything in A, and additionally replace the uniform `A–Z` draw in `generateRoomCode()` with a curated list of unambiguous 4-letter words.
  - *Pros*: Codes become speakable, memorable and easy to relay by voice; a fixed list can be screened once for offensive strings, which a random draw can never be.
  - *Cons*: Collapses the code space from 456,976 to the list size (typically ~1,000–2,000), which materially raises collision rate — the retry loop at `index.ts:394` must be re-examined and its bound justified for the smaller space. The list needs curating for offensive words *and* near-homophones (`BEAR`/`BARE`, `SEAM`/`SEEM`), which is ongoing content work. **Worthless without A**: a real word is *more* likely to be autocorrected into a different real word, not less.

**Option C**: **Segmented 4-box code input** — replace the free-text field with four single-character boxes that auto-advance.
  - *Pros*: Structurally immune to autocorrect and to the suggestion bar, because no box ever holds a word; a mistyped slot is visible at a glance; a pattern users already know from OTP entry.
  - *Cons*: A new custom widget owning focus traversal, paste-of-4, and backspace-across-boxes, plus its own accessibility labelling. The `ValueKey('room_code_field')` contract breaks, so the lobby widget tests and any playthrough scripts that type a code must be rewritten. Large surface area for a defect that Option A closes in one file.

Your selection: Proceed with Option A.

---

### Issue 154: The 100-character answer limit is invisible until submission is rejected

**Status**: ⚠️ Confirmed Unresolved — `kMaxAnswerLength = 100` (`lib/widgets/card_grid.dart:22`) is enforced only inside `_submitAnswer` (`lib/screens/phase2_craft.dart:64–84`), which shows an error SnackBar *after* the player has finished writing. The `TextField` at `phase2_craft.dart:563` deliberately sets no `maxLength`. **This is a reversal of a documented decision, not an oversight**: the comment at `phase2_craft.dart:69–73` states that silently refusing keystrokes gives the player no idea why the words stopped appearing, so the cap was moved to submit time on purpose. The playthrough shows the cost of that choice — a player who overruns loses their work's shape at the worst possible moment, under a timer. Any option here must preserve the *other* half of that comment: the server bound in `submitAnswer` is the real limit and stays.

**Option A (recommended)**: **Live counter, no cap** — add a `counterText`/counter widget showing `n/100` that turns to the error colour past 100, leaving the field itself uncapped and submit-time validation untouched.
  - *Pros*: Honours the original decision exactly — keystrokes are never silently swallowed — while removing the surprise. The player sees the ceiling approaching and can self-edit before the timer pressure hits. Purely additive: `_submitAnswer`'s guard and the server bound are unchanged, so no test in `vote_option_truncation_test.dart` is affected.
  - *Cons*: A player can still submit an over-long answer and be rejected; it only makes that outcome predictable rather than impossible. Adds visual weight to a deliberately spare parchment card.

**Option B**: **Hard cap the field** — set `maxLength: kMaxAnswerLength` with `maxLengthEnforcement: enforced`, which also renders Flutter's built-in counter.
  - *Pros*: The rejection path becomes unreachable from the UI; shortest possible diff; counter comes free.
  - *Cons*: Reintroduces exactly the failure the code comment was written to prevent — typing stops with no explanation, which is worse under a countdown. Also silently truncates a paste, destroying text the player may not notice is gone.

**Option C**: **State the limit in the hint and instruction copy only** — extend the `hintText` and the existing `instructionText` at `phase2_craft.dart:460` to name the 100-character bound.
  - *Pros*: Zero new widgets; the limit is stated before writing begins, when it is most actionable.
  - *Cons*: The hint disappears on the first keystroke, so it is gone for the entire period it would be useful; gives no feedback about *current* length, which is the actual complaint.

Your selection: Proceed with Option A.

---

### Issue 155: The dealt-card overlay is a redundant gate with two misleading button labels

**Status**: ✅ Resolved — Option A implemented in Wave AA (AA1). Deleted `DealtCardOverlay` and overlay branch from `phase2_craft.dart`; players now land directly on the writing screen without a redundant modal gate.

**Option A (recommended)**: **Remove the overlay entirely** — delete the `_showDealtOverlay` state and the `DealtCardOverlay` branch from `phase2_craft.dart`, landing the player directly on the writing screen, and fold the overlay's one unique line (the "You have been dealt the ledger of X" framing) into the existing `instructionText`.
  - *Pros*: Resolves all three reported items at once, and matches the playthrough's own conclusion. Removes a full-screen modal and a mandatory tap from every single rotation — with 5 players that is 5 taps per card cycle that convey nothing new. Deletes a widget, its `AnimationController`, and its entrance animation rather than debugging label copy. Makes `RE-ROLL PROMPT` reachable on first paint.
  - *Cons*: Loses the deliberate theatrical beat of a card being dealt, which is a real part of the parlour framing — this is a genuine cost to the game's identity, not just decoration. `dealt_card_overlay.dart` and any test referencing it must be removed, and the phase-change detection block at `phase2_craft.dart:180` needs its `_showDealtOverlay` assignment excised without disturbing the adjacent "nobody answered" SnackBar logic that shares the same branch.

**Option B**: **Keep the overlay but make it non-blocking and correctly labelled** — relabel the button to `BEGIN WRITING` in both phases, and auto-dismiss on a short timer or on tap-anywhere so it reads as a transition rather than a gate.
  - *Pros*: Preserves the dealt-card theatre; fixes the label complaint (items 2 and 5) with a one-line copy change; a tap-anywhere dismiss removes the sense of a wall.
  - *Cons*: Does not address item 6 at all — the page is still redundant with the screen behind it, which was the playthrough's main point. An auto-dismiss timer competes with the round timer and will feel arbitrary; too short and it is unreadable, too long and it is a wall with extra steps.

**Option C**: **Show the overlay only on the first card of a match** — raise it once per game as an orientation beat, then go straight to the writing screen for every later rotation.
  - *Pros*: Keeps the theatrical introduction where it has the most value and costs the least; removes the per-rotation tax that makes it feel redundant; a small, contained change to the trigger condition.
  - *Cons*: Still wrong on the one occasion it appears — it is shown on the *truth* round, which is exactly the round where it hides the re-roll affordance. Introduces a "first time only" flag whose lifetime must be reasoned about carefully; the `_isLeaving` latch in Issue 152 is the standing example of what that costs when the holding `State` outlives the match.

Your selection: Proceed with Option A.

---

### Issue 156: The keyboard cannot be dismissed by tapping away from the field

**Status**: ✅ Resolved — Option A implemented in Wave AA (AA2). Wrapped `Phase2CraftScreen` Scaffold body in `GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => FocusScope.of(context).unfocus())`.

**Option A (recommended)**: **Wrap the craft body in an unfocus gesture** — add a `GestureDetector` with `behavior: HitTestBehavior.translucent` and `onTap: () => FocusScope.of(context).unfocus()` around the craft screen body.
  - *Pros*: The universally expected behaviour, in a few lines, on the one screen that reports the problem. `translucent` means buttons underneath still receive their taps, so `RE-ROLL PROMPT` and `SUBMIT DOSSIER` are unaffected.
  - *Cons*: Only fixes the craft screen; the lobby name and room-code fields (`lobby_screen.dart:1201`, `:1289`) have the same gap and would still trap the keyboard, so the complaint can recur elsewhere.

**Option B**: **Use `TextField.onTapOutside`** — supply `onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus()` on the field itself.
  - *Pros*: Scoped to the field rather than the layout, so it survives future restructuring of the craft screen's widget tree; no extra wrapper in the tree.
  - *Cons*: Fires on *every* outside pointer-down including the submit button, so the unfocus races the button's own tap handling and must be verified not to swallow the first tap on `SUBMIT DOSSIER` — a regression that would be worse than the bug.

**Option C**: **Apply Option A's wrapper as a shared widget across every text-entry screen** — build one `DismissKeyboard` wrapper and use it in `phase2_craft.dart` and both lobby fields.
  - *Pros*: Closes the whole class of defect rather than the one reported instance, which is the same reasoning that retired the `pumpAndSettle` trap in Wave X.
  - *Cons*: Touches the lobby screen, which is the most test-covered and most recently regressed file in the project (Issues 151 and 152 both landed there); a wrapper over the lobby's `Stack` must be checked against the entry/parlour conditional in `lobby_screen.dart` so it does not intercept taps in the in-room branch.

Your selection: Proceed with Option A.

---

### Issue 157: Answers must be written without seeing them, because the keyboard covers the field

**Status**: ⚠️ Confirmed Unresolved — Clarified by the user on filing: the on-screen keyboard sits over the answer field, so the player types blind. `Scaffold` leaves `resizeToAvoidBottomInset` at its default `true`, so the body shrinks when the keyboard opens; the writing column is `Column > Expanded > SingleChildScrollView` (`phase2_craft.dart:506`) with a fixed-height `SUBMIT DOSSIER` button pinned below it (`phase2_craft.dart:682`). The `TextField` is the *last* element inside the scroll view, below the prompt block and instruction copy, so once the viewport shrinks, the field's resting position is behind the keyboard and the pinned button consumes part of what is left. This compounds Issue 156 — the player cannot see the field *and* cannot dismiss the keyboard to look at it.

**Option A (recommended)**: **Ensure the focused field is scrolled into view** — attach a `FocusNode` to the field and, on focus gain, call `Scrollable.ensureVisible` on its context after the inset animation settles (or attach a `ScrollController` and scroll to the field's offset), so the field lands above the keyboard.
  - *Pros*: Directly targets the reported failure and keeps the whole existing layout, including the prompt block the player needs to keep referring to. Verifiable in a widget test by pumping with a synthetic `viewInsets.bottom` and asserting the field's global rect sits above the inset.
  - *Cons*: Requires waiting out the keyboard's inset animation before measuring, so the implementation has a timing component that must be tested rather than eyeballed; if the remaining viewport is genuinely too short (small phones at large text scale), scrolling alone cannot create room.

**Option B**: **Reorder the writing column** — move the `TextField` above the prompt/instruction block so it is the first thing in the scroll view and is never pushed down.
  - *Pros*: No scroll orchestration and no timing to get right; the field is structurally always the highest element, so it survives future content being added below it.
  - *Cons*: Inverts the reading order the screen was designed around — the player would see the input before the prompt they are answering, which is the wrong sequence on first paint and undermines the `CASE DOSSIER` framing. A significant visual redesign for a positioning bug.

**Option C**: **Move writing into a dedicated full-height sheet** — open a modal bottom sheet or route containing the prompt and the field, sized against `viewInsets` so the field always sits directly above the keyboard.
  - *Pros*: Gives the input its own layout budget instead of competing with the app bar, prompt card, re-roll button and pinned submit button inside one shrinking column; a well-trodden pattern for keyboard-first input.
  - *Cons*: Substantial restructuring of the most timing-sensitive screen in the game — the craft screen also hosts the round timer, the phase-change detection at `phase2_craft.dart:180`, and the auto-advance path, all of which must keep working while a sheet is open and when a phase change closes it out from under the player.

Your selection: Proceed with Option A.

---

### Issue 158: Fast writers idle because forgery rotations advance in lock-step

**Status**: ✅ Resolved (September 10, 2026) — Added read-only recap of the player's own submitted answer and prompt in `Phase2CraftScreen`'s waiting UI (`_buildWaitingUI` in `lib/screens/phase2_craft.dart`), setting `_lastSubmittedAnswer` and `_lastSubmittedPrompt` in `_submitAnswer`, and resetting them on phase/rotation change at line 219. Verified in `test/craft_waiting_recap_test.dart` with both single-rotation display and multi-rotation state-persistence falsification.

**Option A (recommended)**: **Keep the barrier, fill the wait** — leave the lock-step architecture intact and give `_buildWaitingUI` something substantive: show the prompts and forgeries already written for cards the player has *finished* (their own contributions only), or let them revise their submitted forgery until the barrier lifts.
  - *Pros*: Zero change to the server's rotation contract, the `rotationPlan`, the readiness gate, or the disconnect/`forceAdvance` recalculation paths — all of which are load-bearing and well tested. Addresses the felt problem (dead time) without inheriting the correctness risk of B. Composes directly with Issue 162, which is the same complaint from the target's seat.
  - *Cons*: Does not actually let a fast player progress, so a table with one very slow writer still moves at that writer's pace; it makes waiting pleasant rather than shorter.

**Option B**: **Per-player rotation index** — replace the room-level `currentRotationIndex` with a per-player index so each player is handed their next card the moment they submit, converging only at the transition into the vote phase.
  - *Pros*: Actually eliminates the idle time the playthrough reported; total forgery-phase duration collapses toward the slowest *player's total*, not the sum of per-round maxima.
  - *Cons*: The largest architectural change in this queue. `currentCardAssignments`, the shared `endTime`, `readyPlayers`, `forceAdvance`, the timer-expiry path, the `kMissingAnswerPlaceholder` back-fill at `index.ts:1554`, and the disconnect recalculation in the rotation engine all assume one global rotation index. A single shared countdown no longer has a meaning, so the timer contract must be redesigned too. High risk of a mid-match state that no existing emulator test covers, and `design_rotation_engine.md` would need rewriting rather than amending.

**Option C**: **Shorten the barrier adaptively** — when every player but one has submitted, cut the remaining time to a short fixed grace window instead of the full round timer.
  - *Pros*: Cuts the worst case substantially with a contained change; the global rotation index and every path that depends on it survive untouched; naturally rewards a table that writes quickly.
  - *Cons*: Punishes one slow writer under social pressure, which cuts against a game about carefully impersonating someone. Needs a new server-side rule for when the grace window starts and a client countdown that can jump backwards, which will read as a bug unless it is explained on screen.

Your selection: Proceed with Option A.

---

### Issue 159: "Best forgery of the round" is meaningless at 3 players, and ties are decided arbitrarily

**Status**: ✅ VERIFIED and RESOLVED (Option A delivered in Wave AA, September 10, 2026) — Modified `_buildBestForgeryBanner` in `lib/screens/phase4_reveal.dart:110` to require both `maxVotes >= 2` and a unique top author (showing nothing on tie or when maxVotes < 2). Verified with `test/reveal_best_forgery_banner_test.dart` (3 tests) and all 7 unedited over-reach guards in `test/phase4_reveal_test.dart`. Falsified against un-fixed logic where tests 1 and 2 failed. Verified seamless screen flow on device without banner at 3 players.

**Option A (recommended)**: **Suppress the banner unless it is meaningful, and handle ties explicitly** — require both `maxVotes >= 2` and a unique maximum; when the maximum is tied, either name all tied authors or show nothing.
  - *Pros*: Fixes both the reported 3-player degeneracy and the unreported tie bug in one contained change to a single method. `>= 2` is self-justifying — it means "fooled more than one person", which is what "best" is claiming. Purely a client-side display rule; no server, scoring, or schema change, and `scoreDeltas` is untouched.
  - *Cons*: At 3 players the banner then never appears at all, which is a silently different reveal screen for small tables — acceptable only if the reveal still reads as complete without it, which must be checked on device rather than assumed.

**Option B**: **Scale the threshold to the table** — require a forgery to have fooled a majority of eligible voters rather than a fixed count.
  - *Pros*: Adapts to any player count instead of hard-coding 2; at large tables it raises the bar so the banner stays a genuine distinction rather than firing every round.
  - *Cons*: At 3 players, one of two voters *is* a majority, so it does not fix the reported case — the very complaint that opened this issue. Needs the eligible-voter count computed client-side, duplicating a rule the server already owns.

**Option C**: **Replace the banner with a per-card vote tally** — show every answer's vote count in the reveal rather than singling one out.
  - *Pros*: Never degenerate at any player count and never has a tie problem, because it makes no claim; feeds directly into Issue 169's request for a visible scoring transcript.
  - *Cons*: Removes a celebratory beat that a party game wants, trading a moment for a table. Overlaps with Issue 169 — if that lands, this becomes redundant work; decide 169 first.

Your selection: Proceed with Option A.

---

### Issue 160: Vote options require scrolling and do not scale with player count

**Status**: ⚠️ Confirmed Unresolved — In portrait, `CardGrid` renders one option per row at a hard-coded `height: 92` inside `BoxConstraints(minHeight: 72, maxHeight: 132)` (`lib/widgets/card_grid.dart:98–112`), inside the vote screen's outer `SingleChildScrollView`. The option list is preceded by the avatar, the "One of these is X's truth" line, the `WHICH ONE IS THE TRUTH?` heading, the full prompt in a `ParchmentCard`, and the "Talk it out" line (`phase3_vote.dart:386–467`) — roughly 300 logical pixels of chrome before the first option. Options number `forgeriesPerCard + 1`, which is `min(players - 1, 5) + 1` — up to **6** at 6+ players, or 552 px of options alone. Nothing above them collapses, so at typical phone heights the player cannot see all options at once and cannot compare them without scrolling — during the one phase where comparison *is* the game.

**Option A (recommended)**: **Make the option area the screen's priority and let the chrome yield** — collapse the pre-option chrome (fold the prompt into a compact single-line header, drop the redundant heading), then give options a flexible height computed from the remaining viewport and option count instead of a fixed 92, keeping `AutoSizedAnswerText` to scale text down to its 9.5 pt floor.
  - *Pros*: Keeps the existing one-option-per-row reading order, which is the right shape for comparing sentences; `AutoSizedAnswerText` and the `vote_option_truncation_test.dart` no-ellipsis contract already exist to make variable heights safe. Contained to `card_grid.dart` and the vote screen's layout.
  - *Cons*: At 6 options on a small phone with large text scale, fitting on one page may drive text to the 9.5 pt floor, and the truncation test's guarantee is that the longest legal 100-character answer renders in full — that must be re-verified at the new heights at 320, 375 and 430 pt, or the fix trades scrolling for unreadability.

**Option B**: **Two-column grid in portrait above a threshold** — keep single-column for ≤3 options and switch to two columns for 4+, reusing the landscape `GridView` path already in `card_grid.dart:117`.
  - *Pros*: Halves vertical space at the counts where the problem actually appears; the grid code path already exists and is exercised in landscape.
  - *Cons*: Halves the width available to each answer, which is the dimension a 100-character sentence needs most — this is the case `AutoSizedAnswerText` handles worst. Side-by-side prose is harder to compare than a vertical list. Likely trades a scrolling problem for a legibility problem.

**Option C**: **Paged or swipeable option cards** — present options one or two at a time in a carousel with position indicators.
  - *Pros*: Each answer gets the full screen and maximum legibility regardless of player count; scales to any number of options without shrinking anything.
  - *Cons*: Directly opposes the stated goal — the complaint is *too much scrolling* and wanting everything on one page; a carousel makes simultaneous comparison impossible rather than merely awkward. Also adds a new interaction to learn during a timed phase.

Your selection: Lets do option C but before actually implementing it, create some demo images for me to view and select which paged/swipeable design is the best.

#### Paged/Swipeable Vote Option Mockups (Generated in Wave AA / AA15)

To evaluate Option C without speculative implementation in production code, four authentic Flutter widget mockups were rendered using the authentic Gaslight design system (Cormorant Garamond, Lora, Victorian gold/brass/oxblood palette, authentic parchment cards). All mockups evaluate the worst-case layout: 6 options (7+ players) with a maximum-length 100-character answer (`kMaxAnswerLength = 100`) in Slot 1, rendered at both 320 pt (iPhone SE) and 430 pt (iPhone Pro Max) viewport widths.

**Design Option C1: Single Card Full Width with Dot Indicators**
- **Artefacts**:
  - `docs/mockups/vote_options/treatment_1_single_card_dots_320.png`
  - `docs/mockups/vote_options/treatment_1_single_card_dots_430.png`
- **Description**: Displays one large, prominent parchment card per page with navigation chevron buttons and horizontal dot indicators (`• • • • • •`) at the bottom.
- **Pros**: Maximum possible font size and line height; zero card crowding; 100-character answers fit easily without aggressive auto-sizing even on 320 pt devices.
- **Cons**: Players must swipe/paginate 5 times to read all 6 options; zero simultaneous comparison; highest interaction cost under a vote timer.

**Design Option C2: Two-Up Carousel**
- **Artefacts**:
  - `docs/mockups/vote_options/treatment_2_two_up_carousel_320.png`
  - `docs/mockups/vote_options/treatment_2_two_up_carousel_430.png`
- **Description**: Displays two full-width options stacked vertically on each page, with 3 page dot indicators at the bottom for 6 options (`Page 1 of 3`).
- **Pros**: Cuts pagination in half (3 screens instead of 6) while preserving generous card height and width; allows comparing pairs of answers directly.
- **Cons**: Still requires pagination to see all answers; pairs may feel arbitrarily grouped.

**Design Option C3: Stacked Deck with Peek (Atmospheric Parlour Deck)**
- **Artefacts**:
  - `docs/mockups/vote_options/treatment_3_stacked_deck_peek_320.png`
  - `docs/mockups/vote_options/treatment_3_stacked_deck_peek_430.png`
- **Description**: Physical parlour card aesthetic where the current card sits in the foreground and the next card peeks out from underneath with an offset layered shadow and border. Includes a vintage counter pill (`CARD I OF VI`) and next/previous controls.
- **Pros**: Deep thematic harmony with Gaslight's Victorian parlour mystery aesthetic; gives tactile visual feedback that more cards remain in the stack.
- **Cons**: Margins needed for the peek offset slightly reduce usable width; custom gesture/stack animations are more complex to implement cleanly.

**Design Option C4: Segmented Pager (Direct Tab Access)**
- **Artefacts**:
  - `docs/mockups/vote_options/treatment_4_segmented_pager_320.png`
  - `docs/mockups/vote_options/treatment_4_segmented_pager_430.png`
- **Description**: A brass-accented segmented tab bar along the top (`OPTION I` through `VI`) directly above a dedicated card display pane, with previous/next chevrons below.
- **Pros**: Random access — players can jump directly between options in a single tap without swiping sequentially through intermediates; clear overview of how many options exist.
- **Cons**: Segmented tab strip consumes ~44 pt of vertical height; tabs can feel tight on narrow 320 pt viewports.

⚠️ **Implementation Notice for Future Wave**: When the selected design is implemented, `test/vote_option_truncation_test.dart` ("P9 discoverability: six options at 320x640 portrait exceed viewport height and option at index 3 has non-zero height below fold") will need to be rewritten. That test currently asserts the below-the-fold scrolling behaviour that Option C is designed to replace.

Your selection: _____

---

### Issue 161: The target's "I'M READY" is irreversible

**Status**: ✅ VERIFIED and RESOLVED (Option A delivered in Wave AA, September 10, 2026) — Hardened `setReady` in `functions/src/index.ts` to guard against late un-readies during non-vote phases with `failed-precondition`. In `lib/screens/phase3_vote.dart`, kept target in `_buildVotingUI` instead of routing to waiting screen, driving the button from `state.readyPlayers[me.id] == true` to toggle between `NOT READY` and `I'M READY`. Tested emulator rejection of late un-ready after advance (`functions/test/game_e2e.spec.ts`), target button toggling, and reader change without re-pump in `test/phase3_vote_target_ready_toggle_test.dart`. Over-reach guard `phase3_vote_test.dart` passes unedited. Falsified with one-way button.

**Option A (recommended)**: **Make it a toggle, matching the lobby** — render `NOT READY` once ready and call `setPlayerReady(false)`, mirroring `toggleLobbyReady`'s shape.
  - *Pros*: Makes two identically labelled buttons behave identically, which is the actual defect; `setPlayerReady` already accepts a boolean (`game_service.dart:720`), so the client change is small. Removes an unrecoverable state from a timed screen.
  - *Cons*: The server-side readiness gate must be checked for whether un-readying after the gate has already fired is safe — if the phase advanced between the tap and the un-ready, the call must fail cleanly rather than corrupting `readyPlayers`. **That is the whole risk of this option and must be tested against the emulator, not reasoned about.**

**Option B**: **Confirm before locking** — keep it one-way but require a confirmation dialog.
  - *Pros*: No server-contract question at all; prevents the accidental tap, which is the likely real-world case; smallest diff.
  - *Cons*: Adds a modal to a timed screen; does nothing for a player who confirms and then changes their mind. Treats a design mismatch as a user error.

**Option C**: **Remove the button entirely** — advance the target automatically once all voters have sealed their ballots, since `$N of $M ballots sealed` is already displayed directly above it (`phase3_vote.dart:492`).
  - *Pros*: Deletes the irreversible state rather than managing it; the target has no decision to make here, so asking them for one is arguably the underlying mistake. Fewest moving parts afterwards.
  - *Cons*: Removes the target's only remaining agency on that screen, which makes Issue 162 strictly worse — do not select this without also selecting something in 162. The readiness gate's arithmetic must be re-derived to exclude the target, touching server logic that currently counts all non-spectators uniformly.

Your selection: Proceed with Option A.

---

### Issue 162: The target has nothing to do while their card is being voted on — SELECTED and REDIRECTED, specced as AA16a / AA16b

**Status**: ⚠️ Confirmed Unresolved — **rewritten September 8, 2026 at the user's direction.** The original three options were not selected. Instead the user proposed a specific mechanic and asked whether it is possible before anything is built:

> *"the target sees all the answers written for them and they can get points guessing which player would select which answer. Maybe something like a drag and drop using the player icon."*

**The underlying defect is unchanged.** When a player's own card is up, `phase3_vote.dart` gives them a read-only `CardGrid` (`onSelect: isTarget ? (_) {} : ...`, `selectedAuthorId: null`), a sealed-ballot counter, and one ready button. Across a full match that is one entire voting phase per player with no input, in the seat that should be the most engaged — the table is arguing about which answer is really theirs.

**⚠️ REDIRECTED by the user on September 9, 2026, after Option A had been selected and specced.** The mechanic changed from *predicting which answer each voter will pick* to **the target guessing who *wrote* each forgery** — *"The target guesses who wrote each lie for points."* The four options below describe the superseded vote-prediction framing and are kept only as the record of how the decision was reached. **The spec that is actually being built is `agent_execution_guide.md` → AA16a / AA16b.**

**What the redirection changed, and what it did not.** The contract became `Record<optionId, guessedAuthorId>`. Everything the feasibility verdict below established still holds and holds *more* strongly: the target already has the option texts, no authorship reaches the client, `sealed` is the right home, and the drag-and-drop is still the wrong interaction for a screen that does not fit. What improved is the mechanic's fit — the game already owns an authorship-guess verb in `submitUnmaskGuess` (P8), and **the target is the one player who can never use it, because they never vote and so are never fooled.** The new version extends an existing beat to the seat it excludes, rather than adding a new kind of guess.

#### Feasibility verdict (written for the superseded framing; the architectural findings carry over)

**What already exists, verified in source:**

- **The target already holds every answer text.** During the vote phase the server publishes `card.options` as unlabelled `{id, text}` pairs, and the target renders them today — `phase3_vote_test.dart` asserts exactly this in *"O9: Target player sees card prompt and read-only options grid with no confirm vote button (Issue 121)"*. **No new data has to reach the client.**
- **Predicting per-*option* needs no authorship**, so the mechanic does **not** violate the standing invariant that other players' authorship is never sent to the client before the unmask window. The target would map *voters → option ids*, never *voters → authors*. This is the single most important reason the idea is safe to build.
- **A private pre-reveal store already exists.** `sealed` is default-deny by having no `match` block, and is exactly where pre-reveal secrets already live. Predictions belong there.
- **Deferred scoring already exists.** `pendingScoreDeltas` is already flushed at three sites, so folding prediction points into the existing reveal scoring needs no new mechanism.

**What has to be built:** one callable (`submitTargetPredictions`) writing `Record<voterId, optionId>` into `sealed`, resolution at reveal, and a UI. That is a normal-sized feature, not an architectural change.

**What does not work: the drag-and-drop, specifically.** The vote screen is *already* the most space-starved surface in the app — that is **Issue 160**, which is open and unresolved, and whose own selection is currently blocked pending design mockups. At 6 options and 5 players the target would need 4 draggable player tokens plus a 6-row option list on a 320 pt screen where the options **already do not fit without scrolling**. Drag-and-drop across a scrolling list on a phone is the weakest possible interaction for that layout: auto-scroll-while-dragging is fiddly, drop targets are small, and it is hard to correct a mistake under a timer. **Tap-to-assign carries exactly the same information with none of that cost** — tap a player chip, then tap an answer.

**The one genuine design risk** is scale. With N players the target makes N−1 predictions, so an unweighted +1 each pays up to N−1 points, against a truth reward of `ceil((P−1)/(S+1))` — at 6 players that is 5 potential points against a truth reward of 1. **Any option below that scores per-voter must state its weighting**, or the target's seat becomes the highest-scoring seat in the game.

**Sequencing note:** the full mapping is the only option here whose UI must be designed on top of whatever Issue 160 settles. The one-tap options are layout-independent and can ship before it.

**Option A (recommended)**: **Full mapping by tap-to-assign, sequenced after Issue 160** — the user's mechanic, with tapping instead of dragging. The target taps a player chip then taps an answer, building `voterId → optionId` for every voter; unassigned voters simply score nothing. Resolved at reveal and folded into `scoreDeltas`.
  - *Pros*: This is the richest use of the one seat with private information — the target knows which answer is true *and* knows the people, which is the exact pairing Quiplash has no equivalent for, so it doubles as a real answer to Issue 165. Needs no new data on the client and no authorship leak. Tap-to-assign works at 320 pt, is trivially correctable, and is testable in a widget test in a way drag-and-drop is not.
  - *Cons*: The most expensive option here — a new callable, `sealed` writes, reveal resolution, a scoring term, and updates to `design_scoring_and_ui.md` and `design_database_and_security.md`. Its UI cannot be finalised until Issue 160 settles the vote screen's layout, so it is the only option that cannot start immediately. Scoring must be weighted (see the risk above) and every added scoring term worsens Issues 164 and 169.

**Option B**: **Name the one voter you will fool** — the target taps a single player they believe will pick a forgery, scored at reveal.
  - *Pros*: One tap, one chip row, completely independent of Issue 160's layout, so it can ship immediately. Keeps the social core of the user's idea — it is still "how well do you know this person" — at roughly a quarter of the build. A single fixed-value point cannot unbalance scoring, so the weighting risk disappears.
  - *Cons*: Much shallower than the mapping; one prediction per card rather than N−1, so it fills the seat without really occupying it. Reveals less about the target's read of the table.

**Option C**: **Mark the most dangerous forgery** — the target taps the one forgery they think will draw the most votes, scored if correct.
  - *Pros*: One tap and layout-independent, like B, and it reuses the tally the reveal already computes for Issue 159's banner, so resolution is nearly free. Reads naturally on the existing read-only grid — it is a selection on a grid that already renders.
  - *Cons*: Tests the target's read of the *answers*, not of the *people*, which is the weaker half of the premise and does the least for Issue 165. Collides directly with Issue 159, which suppresses that banner on ties and at small tables — the two must agree on what "most votes" means or they will disagree on screen.

**Option D**: **Predict the count** — the target guesses how many voters will find their truth.
  - *Pros*: The cheapest possible fill for the seat: one number, one control, no layout pressure, no new resolution logic beyond a comparison the reveal already has. Naturally bounded scoring.
  - *Cons*: The least interesting of the four and the least connected to the premise — it is a guess about an aggregate, not about anybody at the table. Unlikely to hold attention past the first match.

Your selection: Actually instead of the target guessing which answer each voter will pick, they should be guessing which answer each voter created. The target guesses who wrote each lie for points.

---

### Issue 163: Nothing escalates across rounds

**Status**: ✅ VERIFIED and RESOLVED (Option A delivered in Wave AA, September 10, 2026) — Applied per-round multiplier (`Math.max(1, state.currentRound ?? 1)`) to `ScoringLogic.calculateScores` in both `functions/src/scoring_logic.ts` and `lib/utils/scoring_logic.dart`. Verified round 1 ×1, round 2 ×2, round 3 ×3, and absent default in `functions/test/scoring_logic.spec.ts` and `test/scoring_logic_test.dart`. Over-reach guards (Case A and Case B) passed unedited. Falsified with unmultiplied deltas. Reversal of the narrow scoring escalation recorded in §4 while P7/P9/P11 remain rejected.

**⚠️ This conflicts with a standing decision and must be read before selecting.** Section 4 of this file records three escalation mechanics that were designed, costed and **consciously not built**: **P7 Confidence Wager** (stake points on your own forgery), **P9 House Cards** (per-round modifiers), and **P11 The Final Gambit** (a comeback round for trailing players). That section is titled *"do not re-propose"*. The playthrough now asks for exactly this, so **selecting any option below re-opens a closed decision** — which is the user's to make, but it should be made knowingly, and whichever option is chosen, Section 4 must be amended to record the reversal rather than left contradicting the queue.

**Option A (recommended)**: **Escalate the scoring multiplier only** — apply a per-round multiplier to points already awarded, leaving every rule, phase and screen unchanged.
  - *Pros*: The smallest possible change that produces an arc: later rounds matter more, so trailing players stay live and the finish has stakes. No new mechanics for players to learn, which keeps Issue 169's explainability problem from getting worse. Confined to `ScoringLogic`; the reveal's existing `POINTS AWARDED THIS CARD` block (`phase4_reveal.dart:454`) surfaces it for free.
  - *Cons*: The thinnest kind of escalation — it changes the arithmetic, not the play; a player doing nothing differently in round 3 is simply worth more. Devalues early rounds, which can make the first round feel like it does not matter. Does not resurrect P7/P9/P11, so the reversal it records is a narrow one.

**Option B**: **Revive P9 House Cards** — introduce per-round modifiers that change a rule for that round.
  - *Pros*: Escalation through variety rather than arithmetic; the design already exists and was costed once, so it is not starting from nothing; directly serves Issue 165 by making later rounds play differently from Quiplash's flat repetition.
  - *Cons*: A full re-opening of a deliberate rejection, with the original reasons for rejection unrecorded here and needing recovery from `git log` before proceeding. Every modifier is a rule the players must learn mid-match, worsening Issue 164's "nobody reads the rules" problem precisely when the rules stop being constant.

**Option C**: **Tighten the constraints each round** — shorten the writing timer and/or raise `forgeriesPerCard` in later rounds.
  - *Pros*: Escalation with no new rules and no new scoring terms — the same game gets harder, which players feel without being told; reuses parameters the server already validates.
  - *Cons*: A shorter timer makes Issues 154, 156 and 157 materially worse, since all three are about being unable to write comfortably under time pressure — **do not select this before those three are fixed**. Raising `forgeriesPerCard` directly worsens Issue 160's option-count problem.

Your selection: Proceed with Option A.

---

### Issue 164: The rules are only readable in the lobby, before any of them apply

**Status**: ✅ Resolved (Option A implemented in Wave AA12) — Extracted shared `GameInstructionsDialog` / `showGameInstructionsDialog` to `lib/widgets/instructions_dialog.dart` and wired to lobby screen. Added in-game manual ledger icon button (`Key('in_game_manual_button')`) to `InGameAppBar` across craft, vote, and reveal screens with parameterized `trailingSlots: 2` reserve width calculation (`56.0 + 56.0 * trailingSlots`). Rendered single-line contextual rules guidance on craft (`Phase2CraftScreen` truth and forgery variants), vote (`Phase3VoteScreen`), and reveal (`Phase4RevealScreen`) with text scaling protection and zero-width media query safety fallback.

**Option A (recommended)**: **One contextual line per phase, plus a manual button in the in-game app bar** — add a short "what you are doing right now" line to each phase screen and a rules icon in `in_game_app_bar.dart` that opens the existing manual.
  - *Pros*: Serves both kinds of player — the one who needs a nudge gets it without asking, the one who wants detail can reach the full manual from any screen. Reuses the manual that already exists rather than writing a second set of rules that can drift from it. `in_game_app_bar.dart` is 45 lines and already the shared header for all in-game phases, so the button lands in one place.
  - *Cons*: The craft and vote screens are already tight on vertical space — Issues 157 and 160 are both about running out of it — so any added line must come out of existing chrome, not on top of it. Some phase copy already exists (`instructionText`, "Talk it out"), so this risks duplicating what is there unless the existing lines are audited and folded in first.

**Option B**: **Manual button only** — add the rules affordance to the in-game app bar and change no phase copy.
  - *Pros*: Costs no vertical space on any screen, which sidesteps the direct conflict with Issues 157 and 160; single small change to one shared 45-line widget; nothing can drift out of sync because there is still exactly one rules source.
  - *Cons*: Still requires the player to know they are confused and to go looking, which is precisely the behaviour the playthrough says does not happen. Opening a full manual mid-round is impractical under a countdown.

**Option C**: **First-run coach marks** — show a one-time overlay explaining each phase the first time a player reaches it.
  - *Pros*: Teaches at the exact moment of need and then gets out of the way permanently; no permanent screen real estate consumed.
  - *Cons*: Adds a full-screen modal to timed phases — the same pattern Issue 155 is about *removing*, and it would land on the same craft screen. Needs persisted per-player state, whose lifetime is exactly the trap lesson 2.40 was written about. Useless to a player joining a friend's match on someone else's device.

Your selection: Proceed with Option A.

---

### Issue 165: The game reads as Quiplash across all four axes

**Status**: ⚠️ Confirmed Unresolved — Reported after a full playthrough. On filing, the user was asked which axis drove the comparison and selected **all four**: the core loop, the tone and presentation, the scoring and progression, and the social dynamics. That answer matters: it means the Victorian parlour framing is not currently doing differentiating work, and no single mechanic tweak will change the impression. **This is a product-direction question, not a defect**, and it is the parent of Issues 162 and 163 — both are partial answers to it. Decide this one first; a selection here may change what you want from those.

The structural asset the game already has and does not exploit: **the answers are impersonations of a specific person at the table, and that person is in the room.** Quiplash has no target. Every option below is a way of leaning on that.

**Option A (recommended)**: **Make the game about knowing the target, and say so everywhere** — re-weight scoring toward the target relationship (points for a forgery the *target themselves* rates as plausible; points for the target when their truth is found), give the target an active role during their own card (Issue 162), and re-cut the prompt decks toward personal history rather than absurdist invention.
  - *Pros*: Differentiates on the one axis Quiplash structurally cannot follow — it has no target and no relationships between players. Reuses the entire existing phase structure, so it is a re-weighting rather than a rewrite. Directly absorbs Issue 162, and gives Issue 163's escalation something to escalate.
  - *Cons*: Adds scoring terms, worsening the explainability problem in Issues 164 and 169 — those should be selected alongside it. Changes the deck's character, so `design_prompt_system.md` and the deck content both need revision, which is content work with no test to prove it landed. Weakest with strangers, where nobody knows the target well enough for the mechanic to bite.

**Option B**: **Make deception continuous rather than per-card** — carry accusation and trust across the whole match (a standing suspicion economy, unmasking that persists, running rivalries) instead of resetting every card.
  - *Pros*: Replaces the round-by-round arc that reads as Quiplash's with a match-long social one; the `headToHead` "RIVALRIES" data in the match summary already computes the raw material, so the game is halfway to tracking it. Answers Issue 163 without reviving P7/P9/P11.
  - *Cons*: The largest design change in this queue, touching scoring, the reveal beats, and the game-over screen simultaneously. Cross-card state introduces exactly the kind of long-lived state lesson 2.40 warns about, at server scale. Long feedback loops are hard to playtest and harder to explain.

**Option C**: **Differentiate on presentation and content only** — keep every mechanic and invest in the parlour framing: prompt decks, reveal theatre, the raven, the copy.
  - *Pros*: No mechanical risk whatsoever, no scoring or server change, and nothing to re-explain to players; the theming assets and vocabulary already exist and are strong. Fastest path to a *felt* difference.
  - *Cons*: The user reported presentation as one of the four axes that already feels same-y, so this option addresses the complaint least — it doubles down on the thing that was named as not working. Tone alone has never separated a party game from its ancestor.

**Option D**: **Accept the resemblance and compete on execution** — treat Quiplash-likeness as acceptable and spend the effort on Issues 153–162, which are all concrete usability defects.
  - *Pros*: Every one of those issues is a known, verifiable fix with a clear done condition, and the playthrough found nine of them — a game that is same-y but flawless beats a differentiated one that is hard to type into. No design risk, no doc churn, no reversal of Section 4.
  - *Cons*: Leaves the strategic concern unanswered, and it will be raised again by the next playtester; the longer the phase structure hardens, the more expensive Options A and B become.

Your selection: Lets put this off for now but don't lose this issue.

---

### Issue 166: Nothing helps a player who cannot think of what to write

**Status**: ✅ Resolved (September 10, 2026) — Added stems map for all 150 prompts across all 5 catalogue decks in `functions/src/prompt_decks.ts` with module-load assertion (`validateDeckStems`), generated `lib/utils/prompt_decks.dart` mirror, and rendered non-prefilled sentence stem hint beneath answer field counter in `lib/screens/phase2_craft.dart`. Verified `_answerController.text` remains empty. Verified in `test/craft_sentence_stem_test.dart` and `functions/test/prompt_decks.spec.ts`. Falsified sync check on tampered stem and falsified module load on mismatched key.

**Option A (recommended)**: **Sentence stems in the hint and instruction copy, drawn per prompt** — give each deck prompt one or more opening stems ("The worst part was…", "Nobody knows that I…") shown as the field's hint or beneath it, differing for truth and forgery rounds.
  - *Pros*: Attacks the blank page directly at the moment it blocks someone, with no new interaction, no extra tap, and no screen space beyond copy. Stems can be authored alongside the prompts they belong to, so they are always contextually apt. Extends the existing deck schema rather than adding a system.
  - *Cons*: Content work proportional to deck size — every prompt needs stems written and reviewed, and `check_decks_in_sync.sh` plus `design_prompt_system.md` must be extended to cover the new field or the decks will silently drift. A stem that all players see risks homogenising answers, which feeds the duplicate-answer heuristic in `design_semantic_integrity.md`.

**Option B**: **Generic stems not tied to the prompt** — show a small rotating set of universal openers, identical across all prompts.
  - *Pros*: No deck content work and no schema change at all; ships immediately; still removes the blank page.
  - *Cons*: A generic stem will fit some prompts and actively mislead on others, which is worse than no help; because every player sees the same small set, the homogenisation and duplicate-rejection risk is higher than in Option A.

**Option C**: **Extend re-roll to forgery rounds** — let a player swap the card they are forging, rather than helping them write.
  - *Pros*: Reuses machinery that already exists, including the exhaustion plumbing in `design_prompt_system.md`; gives an escape hatch on the round where there currently is none.
  - *Cons*: Does not answer the request — it changes the question instead of helping with the answer. Structurally much harder than truth re-roll: a forgery card is a *shared* card that other players are simultaneously writing on, so re-rolling it would invalidate their work. Likely infeasible without also changing the rotation plan.

Your selection: Proceed with Option A.

---

### Issue 167: Final standings are buried below the honors

**Status**: ✅ Resolved (Option A implemented in Wave AA13) — Swapped `_buildStandings` above `_buildHonorCards` in `GameOverScreen`. Retitled the top container headline to `FINAL RESULTS`, and gave the honors block its own dedicated `THE NIGHT'S HONORS` section header styled consistently with `FINAL STANDINGS` and `MATCH HIGHLIGHTS`. Verified ceremony animations and bottom bar pinning remain intact, with vertical order assertion and falsification confirmed in `test/game_over_screen_test.dart`.

**Option A (recommended)**: **Swap the two blocks and re-title the screen** — render `_buildStandings` before `_buildHonorCards`, and change the page heading so it no longer announces the honors as the screen's subject.
  - *Pros*: Exactly what was asked, in a straightforward reorder of two calls in one build method. The heading change is the part that is easy to miss and would otherwise leave the screen contradicting itself.
  - *Cons*: The honors block carries the reveal animation sequence (`honorsSequence` staggering, `game_over_screen.dart:323–330`); moving it below the standings means the animated payoff now begins off-screen, so the sequence's timing and any auto-scroll must be re-checked rather than assumed to survive the move.

**Option B**: **Standings first, honors and highlights behind a tab or expander**
  - *Pros*: Puts the result on screen with no scrolling at all, at any player count; keeps the celebratory material for those who want it.
  - *Cons*: Hides the honors, which are the screen's most distinctive content and part of what Issue 165 says the game needs more of, not less. Adds navigation to a terminal screen that currently has none.

Your selection: Proceed with Option A.

---

### Issue 168: Match highlight titles are truncated

**Status**: ✅ Resolved (Option A implemented in Wave AA14) — Separated highlight card title and badge chip into distinct lines in `HighlightCard` (`game_over_screen.dart`), allowing the title to occupy the full card width without competitive constraints. Relaxed `maxLines: 1` and ellipsis so titles wrap naturally rather than truncating at small widths or elevated text scales. Verified mechanical non-truncation (`RenderParagraph.didExceedMaxLines == false`) at 320pt width under both 1.0 and 2.0 text scales and verified falsification when restoring the shared row in `test/highlight_card_truncation_test.dart`.

**Option A (recommended)**: **Put the title and badge on separate lines** — stack the badge beneath the title (or move it to the card's footer) so the title owns the full card width.
  - *Pros*: Removes the competition rather than tuning it, so it cannot regress at any width, text scale or future title length. No measurement code and no fragile constants. Keeps both elements fully readable.
  - *Cons*: Makes each highlight card taller, and there can be three of them plus the rivalries block on an already-long screen — worth checking against Issue 167 if the standings move above them.

**Option B**: **Let the title wrap to two lines** — raise `maxLines` to 2 and keep the badge in the row.
  - *Pros*: Smallest possible diff, one constant; preserves the current compact side-by-side layout.
  - *Cons*: A two-line title beside a one-line badge needs deliberate cross-axis alignment or it will look misaligned; at large text scales two lines will not be enough either, so this defers the bug rather than closing it.

**Option C**: **Auto-size the title** — reuse the `AutoSizedAnswerText` measurement approach from `card_grid.dart:24` to shrink the title until it fits.
  - *Pros*: Guarantees fit in the current layout at any width; the measurement pattern already exists, is text-scale aware, and is proven in this codebase.
  - *Cons*: Shrinking a 14 pt letter-spaced display face has very little headroom before it becomes unreadable, so it can turn a truncation bug into a legibility bug. Solves a layout problem with measurement when Option A removes the constraint outright.

Your selection: Proceed with Option A.

---

### Issue 169: Scoring is explained as a formula and never shown being applied

**Status**: ✅ Resolved (Option A implemented in Wave AA11) — Two related failures. First, the in-app manual's section is titled `3. SCORING (Dynamic)` and its first line reads *"Points scale based on difficulty. Formula: ceil((Players - 1) / (Forgeries + 1))"* (`lobby_screen.dart:288–294`) — a raw expression printed at players, in a manual most will not read (Issue 164). Second, the reveal screen's `POINTS AWARDED THIS CARD` block (`phase4_reveal.dart:454`) shows only resulting `scoreDeltas`, never their derivation, so a player sees that they gained points but not which of the five rules fired. With five scoring rules in play — truth-finding, successful forgery, believable target, sharp eye, and unmask revenge — a bare delta is unattributable.

**Option A (recommended)**: **Itemise the deltas at the reveal, and rewrite the manual copy in plain language** — break each player's card total into named lines ("Found the truth +2", "Fooled 2 players +2"), and replace the printed formula with a sentence about what it means, keeping the expression only as a footnote for those who want it.
  - *Pros*: Answers both halves of the report. The reveal is where players are actually looking and where the numbers are already computed, so the transcript costs no new calculation — only the per-rule breakdown must be surfaced from `ScoringLogic` rather than summed away. Teaching by worked example is what makes the manual unnecessary, which is the same problem Issue 164 is about.
  - *Cons*: Requires `ScoringLogic` to emit an itemised breakdown alongside `scoreDeltas`, which is a change to the scoring contract in `design_scoring_and_ui.md` and to the room schema that carries it — a server change, not a copy change. Adds vertical content to the reveal, which is already a paced five-beat sequence and cannot simply absorb more.

**Option B**: **Fix the manual copy only** — rewrite `3. SCORING (Dynamic)` in plain language and leave the reveal as it is.
  - *Pros*: Pure copy change in one file, no server work, no schema change, no scoring-contract churn; removes the most obviously wrong thing (a formula shown to a player) immediately.
  - *Cons*: Ignores the actual request, which was for a transcript of how points were calculated; and it improves a manual that Issue 164 establishes is unread, so the benefit may be close to zero in practice.

**Option C**: **Add an end-of-match scoring transcript** — leave both the manual and the reveal alone and show a full per-card, per-rule breakdown on the game-over screen.
  - *Pros*: Unlimited space for the full derivation without disturbing the reveal's pacing; naturally accompanies the standings; the match summary infrastructure already exists to carry it.
  - *Cons*: Arrives long after the moment of confusion, so it explains rather than teaches; the game-over screen is already the busiest in the app and the subject of Issues 167 and 168. Same `ScoringLogic` breakdown requirement as Option A, so it is not cheaper in server terms — only later.

Your selection: Proceed with Option A.

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

### Issues 65–152 — August 8 to September 7, 2026

**77 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

| Area | Issues | Where the surviving contract lives |
|---|---|---|
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
| Playthrough evidence and its provenance | `findings_marionette.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |
| Full history of any resolved item | `git log` |

**A note on keeping this file short.** It was 903 lines in August, cut to 559, and cut again to ~200 on August 21. Both times the cause was the same: **each pass appended its summary without removing the one it superseded** — Issues 93–95 appeared three times, and §1 accumulated six stacked banners. When you resolve something, move the durable consequence into the design doc above and leave **one line** here. If you are adding a paragraph to this file, ask first whether it belongs in a design doc instead.
