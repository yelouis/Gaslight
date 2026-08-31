# Agent Execution Guide — Queue Blocked: two selections pending (Issues 145, 146) — August 31, 2026

**You are an engineering agent with no memory of this project.**

**There is no approved queue.** Wave V is delivered and verified. The dry-run log it produced then exposed a real upstream leak, and both of the resulting questions need a human decision before any work starts.

**Do not start either. Do not invent work.** The only legitimate actions today are in §4.

**Every number and literal string in this document is a decision, not a suggestion.**

---

## 1. Verified baseline — measured this session on `e02cd8f`

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **267 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **108 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH.** 17 functions, oldest `cleanupDaily` @ 2026-08-31T04:05:23Z |
| `check_playthrough_evidence.sh` *(no args → marionette)* | **exit 0** — 21 blocks, R6: 0 of 3 govern |
| `… docs/playthroughs/findings_marionette.md` | **exit 0** — 21 blocks, 20 PASS, 1 NOT RUN |
| `… docs/playthroughs/findings_web.md` | **exit 0** — 20 blocks, 20 PASS |
| `… docs/playthroughs/findings_5player.md` | **exit 0** — 28 blocks, 28 PASS, 0 NOT RUN, R6: 3 of 3 |

**All ten gates are green.** The deploy gate was red last session and is now fixed — Wave V redeployed from the committed tree.

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** The infos are `deprecated_member_use` (`withOpacity`) and `avoid_print` in `test/`; accepted and tracked, and they must not grow.

**Read every other exit code bare, never through a pipe.** `... | head` reports the pipe's status.

**Gates that could not run:** none.

---

## 2. What Wave V delivered, and what it uncovered

**V1 (Issue 144 → Option A) is verified.** The step that mattered was actually performed: Step 1 read the **deployed** Cloud Run environment via `gcloud run services describe` and pasted the output verbatim, rather than restating the repository's default. `CLEANUP_DRY_RUN` is **absent**, so the deployed job is genuinely inert. The 17 functions were then redeployed from the committed tree, restoring the deploy gate to exit 0, and **V1 touched no source** — exactly as specified.

**Then the dry-run log did something nobody asked it to.** Verbatim:

```
[CLEANUP] Completed run: dryRun=true, roomsScanned=0, roomsDeleted=0,
orphanSubtreesSwept=101, authUsersScanned=206, authUsersReferenced=1,
authUsersEligible=200, authUsersDeleted=0, errors=0
```

**`roomsScanned=0` alongside `orphanSubtreesSwept=101` is not a clean result — it is two numbers that cannot both be true of a healthy system.** Zero rooms are expired, yet 101 subcollections exist whose parent room document is already gone. Something deletes room documents without their subtrees.

Tracing it found **`handleDisconnect`'s host-leaves-lobby path** (`functions/src/index.ts:1209–1216`), which deletes every player document and the room document but **not** the room's `sealed` subcollection — and `:1214` is the **only** room-document delete in the entire server. Every room gets a `sealed` subcollection at creation (`:460`) and one entry per join (`:564`). **So all 101 orphans are host-closed lobbies, and they regenerate every time a host closes one.** Filed as **Issue 146**, along with a coupled defect found in the same read: `cleanup.ts` step 2 sweeps orphans with **no cap**, while steps 1 and 3 are bounded.

**The rest of the numbers are reassuring**, which is why Issue 145 is a real decision rather than a formality: 0 expired rooms means the riskiest category is empty; **1 account was skipped as still-referenced, which is the exclusion guard firing on real production data** rather than only in tests; neither cap was hit, so the run is the whole picture and not a truncated sample; 0 errors.

---

## 3. Already delivered — do NOT rework

Verified by reading source, re-running gates bare, and opening every artefact.

- **V1 (144, 143)** — deployed environment verified, 17 functions redeployed from the committed tree, deploy gate exit 0, first dry-run log captured. **The cleanup job is live, scheduled `every day 04:00` America/Los_Angeles, and inert** (`CLEANUP_DRY_RUN` absent). **Do not enable deletion** — that is Issue 145.
- **The 24-hour anonymous retention window is settled** (user, August 31, 2026). Its rationale and the **`ROOM_TTL_MS` coupling invariant** are in `design_database_and_security.md` §10.4. **Not a tuning parameter.**
- **U1 (140)** — manifest `Report` column + R6 scoping. Falsified independently: one-word title drift fails, one-word assertion drift fails, empty manifest fails FATAL, legacy blocks unaffected.
- **U2 (141)** — `AppMotion.reduce` reads `platformDispatcher.accessibilityFeatures.reduceMotion || MediaQuery.of(c).accessibleNavigation`. The deciding experiment was genuinely run (`disableAnimations=false, reduceMotion=true`). Device-verified.
- **U3 (142)** — 30 s heartbeat, `lastSeen`-only snapshots suppressed via explicit field-by-field comparison, host-gated disconnects with 60 s cooldown, `paused`/`resumed` handling.
- **U4 (135)** — E49 PASS. Screenshots opened: Erin seated at 7:07 among five, gone at 7:16 among four, clocks 9 minutes apart. **First genuine device verification of Issue 123.** The Reduce Motion artefact is a clean A/B: same room, same phase, no particles on P3 while P1's shots either side are full of them.
- **S1 (139)** — 15 removals, 0 warnings, no suppressions, retained `lastReaction` fields intact.
- **E47 / E48** — verified by opening artefacts; the pair shows `SEALED ANSWER` during the unmask window and `FORGERY BY BOB` after.
- **R0 (138)** — particle layer omitted under `AppMotion.reduce`, ticker stopped. ⚠️ **`EmberBackdrop` (`game_over_screen.dart:900`) deliberately untouched** — its ticker still never settles, so `pumpAndSettle` on game-over would hang. Latent. **Do not fix without filing.**
- **R1 (136)**, **R2 (137)**, **the soak's blocks E22–E49**, **Wave Q**, **Wave P**, **Wave O's six**, **Issues 96–105**, **50–95**, **31**, **28/29**.
- **The playthrough reorganisation** — everything under `docs/playthroughs/`. R5 was falsified after the move.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206, not 207.** Deleting `_lastReactionSentTime` removed the `prefer_final_fields` info attached to it. Bar is **206 and no new infos**.
- **E48 merged two specified artefacts into one.** A post-close shot from a non-host device with the host confirmed terminated satisfies both.
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`** — U2/R0 evidence captured during E49's match. Correct and traceable.
- **R0 leaves `..repeat()` in `initState`.** `didChangeDependencies` always runs before the first frame.
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 4. The blocked queue

| Issue | What it decides | Blocks |
|---|---|---|
| **146** | How to stop the lobby-close path orphaning `sealed`, and whether to bound the uncapped orphan sweep | Whether enabling deletion runs an unbounded destructive loop |
| **145** | Whether to enable live deletion now, after 146, or partially | 200 anonymous accounts and 101 orphan subtrees actually being removed |

**They are ordered.** Issue 145's recommended option is *"fix 146 first"*, so if both are selected as recommended, **146 lands before 145**. Read both selections before planning a wave — 145 selected alone as "enable now" would mean deliberately running the uncapped sweep destructively, which is a legitimate choice but must be a deliberate one.

**The only legitimate actions until a selection appears:**
1. Answer questions about the state of the repository.
2. Re-run the baseline in §1 to confirm it still holds.
3. If a gate that §1 says is green goes red, investigate and **file** it.

**Do not** enable deletion, change the schedule, alter `DEFAULT_AUTH_RETENTION_MS`, or edit `cleanup.ts` — every one of those is inside a pending decision.

---

## 5. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** `cleanupDaily` deletes them with admin credentials, which bypass rules — **do not add match blocks to make cleanup easier.** This is also why Issue 146's orphaned tokens are not client-readable.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own; authorship is correctly published *after* the unmask window closes.
- **Never let a client bound exceed the server's.** `castVote` and `closeUnmaskWindow` are the models.
- **The presence window gates the ACTION, not the caller.** U3 host-gates the *trigger* for efficiency; the server's enforcement is unchanged.
- **`pendingScoreDeltas` is flushed at three sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`.
- **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and **caps every match at three departures**.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130).
- **Heartbeat cadence is 30 s** (Issue 142) against a **10-minute** server presence window and a **60 s** client-local staleness check. **Do not raise it above 30 s** without also raising the 60 s threshold.
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** (confirmed August 31, 2026) and **must always exceed `ROOM_TTL_MS` (8 h) by a wide margin.** The two constants live in different files and neither references the other — see `design_database_and_security.md` §10.4. Raising `ROOM_TTL_MS` without raising retention makes live accounts deletable.
- **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`** and must not be collapsed to `lastRefreshTime` — that would make brand-new accounts look 24 hours old and purge live players (§10.4).
- **`AppMotion.reduce` must keep the `accessibleNavigation` OR term** (Issue 141) — every existing widget test injects it.
- **`lastReaction` / `lastReactionAt` in `player_state.dart` are deliberately retained dead fields** from the reaction feature removed in Issue 74. Dropping them needs a rules deploy and a data migration. **Leave them.**
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit. `functions/src/prompt_decks.ts` is the source of truth; **no file outside the catalogue may branch on a deck id.**

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak to recover three blocks (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles rather than removing the layer (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and doing both at once (142 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C).

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 6. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| **All playthrough material** | **`docs/playthroughs/`** |
| Block titles + specified assertions (R6's source of truth) | `docs/playthroughs/manifest.md` |
| Screenshot hand-off record | `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| Five-player soak report | `docs/playthroughs/findings_5player.md` |
| Earlier playthrough evidence | `docs/playthroughs/findings_marionette.md`, `findings_web.md` |
| Rules, seat tokens, presence, heartbeat cadence, **retention & cleanup (§10)** | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, header sizing, dealt-card growth, **which signal means "reduce motion"** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 7. Validation standard

**Read a safety mechanism's output as evidence, not as a checkbox.** `CLEANUP_DRY_RUN` existed to prevent premature deletion. Its first log found a leak that every gate, test and playthrough had missed for as long as the code has existed — because nothing in the app ever reads a room whose document is gone (§2.37).

**Be suspicious of counts that cannot both be true.** `roomsScanned=0` beside `orphanSubtreesSwept=101` is the whole finding, visible in one line, if you read the numbers against the model instead of skimming for errors.

**A component built in one pass will have inconsistencies between its parts.** `cleanup.ts` caps two of its three phases. When a spec says "add a cap", check every loop, not the one the spec was thinking about.

**Re-run every gate yourself before trusting a table.** This file has twice recorded a gate result that did not match reality.

**For an irreversible or outward-facing action, make the block mechanical, not textual** (§2.36).

**Enumerate every invocation of anything you change** — including a *path* change, which reaches every file that reads or writes it, scripts that only write included.

**Determine, then implement.** U2's deciding experiment is the model.

**Open the artefact and ask what it shows.** R5 proves a path resolves; R6 proves a block still claims the right assertion. **Neither proves the claim is true.**

**Falsify every guard**, and when you *move* or *repair* something, re-run its falsifications to prove you did not weaken it.

**Prefer the countable win.**

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
(9) NEVER deploy, undeploy, or change production configuration unless the
    item you are working on explicitly says to.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**The queue is empty until Issues 145 and 146 are selected. Do not invent work.**
