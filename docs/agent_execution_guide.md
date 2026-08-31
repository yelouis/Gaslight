# Agent Execution Guide — Active Build: Wave W — stop the orphan leak, bound the sweep, then turn deletion on — August 31, 2026

**You are an engineering agent with no memory of this project.**

**Both selections are made.** Build exactly these, in this order.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **W1** | Stop the lobby-close path orphaning `sealed`, and cap the orphan sweep | **146 → A** | **server** | **YES** |
| **W2** | Enable live deletion, after W1 has proven the leak is closed | **145 → A** | **server (ops)** | **YES** |

**One item = one commit.** W1 is one commit; W2 is one commit.

**Every number, formula and literal string below is a decision, not a suggestion.**

---

## 0. Ordering, and why it is not negotiable

**W1 → W2.** Issue 145's selected option is literally *"fix Issue 146 first, then enable deletion."* Two reasons, and both matter:

1. **The orphan sweep is currently unbounded.** Enabling deletion before capping it turns an unbounded loop into an unbounded **destructive** loop. Capping costs a few lines now; discovering the limit in production costs a partially-completed delete pass at the 540 s timeout.
2. **The leak regenerates.** Enabling deletion first would make the nightly job permanent cover for a bug that keeps producing work, rather than hygiene that occasionally has something to do.

**W2 has a hard precondition beyond "W1 is committed": W1 must be deployed and observed to work in production** (§4.2 Step 1). Do not flip the flag on the strength of passing tests alone.

---

## 1. Verified baseline — measured this session on `e02cd8f`

| Gate | Result | After Wave W |
|---|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** | unchanged |
| `flutter test` | **267 passing**, exit 0 | **267** — W1 and W2 touch no client code |
| `npm --prefix functions run build` | clean, exit 0 | clean |
| `npm --prefix functions test` | **108 passing**, exit 0 | **≥ 112** (W1 adds at least 4) |
| `./scripts/check_decks_in_sync.sh` | **exit 0** | exit 0 |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 17 functions | exit 0, still 17 |
| all four `check_playthrough_evidence.sh` invocations | **exit 0** | exit 0 |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.**

**Read every other exit code bare, never through a pipe.**

**The production state you are starting from**, measured by Wave V's dry run:

```
dryRun=true, roomsScanned=0, roomsDeleted=0, orphanSubtreesSwept=101,
authUsersScanned=206, authUsersReferenced=1, authUsersEligible=200,
authUsersDeleted=0, errors=0
```

**Nothing has been deleted yet.** `cleanupDaily` is live, scheduled `every day 04:00` America/Los_Angeles, and inert because `CLEANUP_DRY_RUN` is absent from the deployed environment.

---

## 2. W1 — Stop the leak and bound the sweep (146 → A)

**What this means for the user:** every time a host closes a lobby, the app leaves behind a hidden sub-folder holding that room's secret seat tokens. It is invisible to the app and never cleaned up until the nightly job sweeps it. 101 have piled up. This stops new ones being created, and puts a limit on how much the nightly job will try to clear in one go.

### 2.1 The gap

**Part A — the leak.** `functions/src/index.ts:1209–1216`, inside `handleDisconnect`:

```ts
// 1. Host leaves the lobby -> close the room entirely.
if (disconnectedPlayer?.isHost === true && phase === "lobby") {
  for (const doc of playersSnap.docs) { transaction.delete(doc.ref); }
  transaction.delete(roomRef);
  return { success: true, roomClosed: true };
}
```

It deletes every player document and the room document, **but not the room's `sealed` subcollection.** Every room has one from creation — `createRoom` writes `sealed/seat_<playerId>` (`:460`), `joinRoom` adds one per player (`:564`), and `startGame` writes `sealed/_summary` (`:717`). **`transaction.delete(roomRef)` at `:1214` is the only room-document delete in the entire server**, so this path is the sole producer of orphans, and the 101 in the dry run are 101 host-closed lobbies.

**Part B — the unbounded sweep.** In `functions/src/cleanup.ts`, step 1 uses `.limit(maxRooms)` and step 3 honours `maxUsers`, but **step 2 iterates every ref from `rooms.listDocuments()`, calls `.get()` on each, and recursive-deletes every orphan it finds, with no bound.** That contradicts U5's "hard cap per run". **The `.get()` per ref is the part that actually scales badly** — it costs a read for every room in the collection, live or orphaned, every night, regardless of how many orphans exist.

### 2.2 Implementation — Part A: close the leak

**The constraint that shapes this:** the close path runs inside `db.runTransaction` (`index.ts:1158`), and **`recursiveDelete()` cannot be called inside a transaction.** The fix is therefore structural, not a one-line addition.

1. **Capture the transaction's result instead of returning it directly.** `handleDisconnect` currently ends with `return await db.runTransaction(...)`. Change to assign the result, act on it, then return it.

2. **After the transaction commits, if the room was closed, recursive-delete the room reference:**
   ```ts
   const result = await db.runTransaction(async (transaction) => { /* unchanged */ });

   if ((result as any)?.roomClosed === true) {
     try {
       await db.recursiveDelete(roomRef);
     } catch (err) {
       console.error(`[handleDisconnect] Subtree cleanup failed for room ${roomCode}:`, err);
     }
   }
   return result;
   ```

3. **⚠️ Do NOT change what happens inside the transaction.** Leave the per-player `transaction.delete(doc.ref)` loop and `transaction.delete(roomRef)` exactly as they are. It is tempting to drop them and let `recursiveDelete` handle everything — **do not.** That would move the player-document deletion outside the transaction, changing the atomicity of a path that has already produced Issues 85, 87 and 123. The minimal change is the correct one here.

4. **⚠️ `recursiveDelete()` on a reference whose document is already deleted still removes its subcollections.** That is not a workaround — it is exactly what `cleanup.ts` step 2 relies on to sweep orphans, so the behaviour is already proven in this codebase.

5. **⚠️ The `catch` must swallow the error, not rethrow.** From the client's point of view the room *is* closed — the transaction committed. Throwing would make the caller believe the close failed and possibly retry, which is strictly worse than a leaked subtree. **Log it with the room code so it is greppable, and let the nightly sweep pick it up.**

6. **Idempotency is already handled and must not be disturbed.** A retry after close hits `if (!roomSnap.exists) return { success: false, reason: "Room not found." }` (`:1160`), so `roomClosed` is absent and the recursive delete does not re-fire.

7. **⚠️ Do NOT remove or weaken the nightly orphan sweep.** It remains the backstop for exactly the failure in step 5 — and for orphans created by any other route, such as a manual console deletion. This is the explicit cost recorded against Option A; honour it.

### 2.3 Implementation — Part B: bound the sweep

In `functions/src/cleanup.ts`:

1. **Add a constant beside the existing two**, mirroring their naming and the rooms limit:
   ```ts
   export const DEFAULT_ORPHAN_SWEEP_LIMIT = 100;
   ```
2. **Add `maxOrphansPerRun?: number` to `CleanupOptions`**, resolved with `options.maxOrphansPerRun ?? DEFAULT_ORPHAN_SWEEP_LIMIT`, matching how `maxRooms` and `maxUsers` are resolved.
3. **Bound the loop on the expensive operation, not just the deletion.** The `.get()` per ref is the cost that scales; capping only the deletes would leave the read cost unbounded. Break out of the iteration once the cap is reached, so **the number of `.get()` calls is bounded too.**
4. **Add `orphanSubtreesScanned: number` to `CleanupResult`** alongside the existing `orphanSubtreesSwept`, and include both in the structured log line. Without a scanned count there is no way to tell a completed sweep from one that stopped at the cap — and "did we hit the cap?" is the single most useful thing the log can say about the backlog.
5. **Leave steps 1 and 3 alone.** They are already correct.

### 2.4 Validation

**Emulator tests in `functions/test/cleanup.spec.ts` and `functions/test/game_e2e.spec.ts`.** There is already coverage of the close path — `game_e2e.spec.ts:2009` asserts `disconnectRes.roomClosed === true` — so extend near it rather than building a new fixture.

**Part A tests:**

1. **The falsifying test.** Create a room, join a second player (so `sealed` holds more than one document), have the **host** leave while `phase === "lobby"`, then assert **`roomRef.collection("sealed").get()` returns empty** — and likewise for `players` and the room document itself. **Run it against current code and watch it fail** with the `sealed` documents still present. Paste the failure into the commit body.
2. **Over-reach guard — non-lobby departures must NOT trigger a subtree delete.** Have the host leave during an **active phase** (not lobby) and assert the room document **still exists** and `sealed` is **untouched**. Without this, "always recursive-delete" passes test 1 and destroys live games.
3. **Over-reach guard — a non-host leaving the lobby must not close the room.** Assert the room and its `sealed` survive.
4. **The failure path is logged, not thrown.** Simulate `recursiveDelete` rejecting, and assert the callable still returns `{ success: true, roomClosed: true }` rather than throwing. This is the behaviour that protects the client from a misleading retry, and it is the one most likely to be "simplified" away later.

**Part B tests:**

5. **The cap is honoured.** Seed **3** orphaned subtrees, run with `maxOrphansPerRun: 1`, and assert `orphanSubtreesSwept === 1` and that **two orphans remain**. Then run with the default and assert all three are swept.
6. **Falsify the cap** by removing the break and confirming test 5 fails. A cap whose test passes either way is decoration.
7. **The scan is bounded too**, not just the deletion — assert `orphanSubtreesScanned` reflects the cap rather than the whole collection.

**Wave-level:**
- `npm --prefix functions run build` clean; `npm --prefix functions test` **≥ 112**.
- **`flutter test` must still be exactly 267** — W1 touches no client code. If it moves, you changed something you should not have.
- **Deploy:** `firebase deploy --only functions` from a **clean working tree**, and **commit before deploying** — deploy-then-commit makes `check_deploy_fresh.sh` red by construction (§2.36 in the tracking doc). Afterwards the gate must exit **0** bare, still reporting **17** functions.

**Blast radius:** `functions/src/index.ts` · `functions/src/cleanup.ts` · `functions/test/cleanup.spec.ts` · `functions/test/game_e2e.spec.ts` · **`docs/design_database_and_security.md` §10** — record that the lobby-close path now deletes its own subtree, that the nightly sweep is retained as the backstop, and that the sweep is capped at 100 orphans per run.

---

## 3. W2 — Enable live deletion (145 → A)

**What this means for the user:** the cleanup job stops writing "here's what I would delete" and starts actually deleting. On the first real run that means roughly 101 orphaned subtrees and around 200 stale anonymous accounts.

**Do not start this until W1 is deployed and verified in production.**

### 3.1 Step 1 — Prove in production that the leak is closed

Tests prove the code path; this proves the deployed system. After W1 is deployed:

1. Create a room, add a second player, and **close it by having the host leave the lobby** — the exact path W1 fixed.
2. Trigger `cleanupDaily` manually (as Wave V did) and read the log.
3. **Assert `orphanSubtreesSwept` did not increase by one for that room.** The number should reflect only the pre-existing backlog.

**If a new orphan appears, STOP.** W1 did not work in production regardless of what the tests say, and enabling deletion would be enabling it on top of a live leak.

### 3.2 Step 2 — Flip the flag, and know how it will be undone

`dryRun` resolves from `process.env.CLEANUP_DRY_RUN === "false"` (`cleanup.ts:37`). It is currently **absent** from the deployed environment.

```bash
gcloud run services update cleanupdaily --region us-central1 \
  --update-env-vars CLEANUP_DRY_RUN=false
```

**⚠️ This is the trap in W2, and it is easy to miss because it fails in the safe direction.** A `gcloud run services update` sets the variable on the current Cloud Run revision. **The next `firebase deploy --only functions` creates a new revision and the variable is gone**, silently returning the job to dry-run. Nobody would notice: the job keeps running, keeps logging, and stops deleting.

Two consequences, both mandatory:
- **Record in `design_database_and_security.md` §10 that `CLEANUP_DRY_RUN` lives on the Cloud Run revision and does not survive a redeploy**, with the exact command to restore it.
- **Add re-applying it to the deploy checklist**, so the next person to deploy functions knows to check. The durable alternative is a `functions/.env.gaslight-46368` file — but note that `.env` and `.env.*` are **gitignored** (`.gitignore:72–73`), so that file would not travel with the repository and its absence on another machine would also silently revert to dry-run. **Whichever route is taken, the fact that it is revertible must be written down.**

### 3.3 Step 3 — Watch the first live run and check it against its prediction

After the next 04:00 run, read the log and **compare the outcome against the dry run's prediction**, which is the whole value of having had one:

| Predicted (dry run) | Expect on the live run |
|---|---|
| `orphanSubtreesSwept=101` | ~101, or fewer if W1 already reduced it |
| `authUsersEligible=200` | `authUsersDeleted` ≈ 200 |
| `authUsersReferenced=1` | ≥ 1 — **this must never be 0** |
| `roomsDeleted=0` | 0, unless rooms have since expired |
| `errors=0` | 0 |

**⚠️ `authUsersReferenced` dropping to 0 is the alarm.** It means the exclusion guard matched nothing — the guard that stops live players' accounts being deleted. **If it is 0, stop and investigate before the next run**, even though deletions have already occurred.

**Report the actual numbers to the user.** Do not enable anything further, change caps, or adjust the retention window.

### 3.4 Validation

- **Step 1's production check is the gate**, and it is not optional. Paste the before/after `orphanSubtreesSwept` figures into the commit body.
- **Confirm the flag took effect** by reading the deployed environment back — the same `gcloud run services describe` command Wave V used — rather than assuming the update applied. Paste the observed value.
- **The full battery must be unchanged**: 0 errors · 0 warnings · 206 infos · `flutter test` 267 · functions ≥ 112 · decks exit 0 · all four evidence gates exit 0 · deploy exit 0.
- **W2 changes no source.** `git diff --stat -- functions/src lib test` must be empty for this item. If the flip required a code change, something has been misread.

**Blast radius:** no source. **`docs/design_database_and_security.md` §10** — the revision-scoped env var, its restore command, and the live-run figures. **`docs/ongoing_general_errors.md`** — resolve Issues 145 and 146.

---

## 4. Definition of Done

**W1**
- [ ] Falsifying test observed to fail first, with the `sealed` leftovers in the output, pasted into the commit body.
- [ ] Host closes lobby → room, players **and `sealed`** are all gone.
- [ ] **Over-reach guards pass:** a non-lobby host departure leaves the room and `sealed` intact; a non-host leaving the lobby does not close the room.
- [ ] `recursiveDelete` failure is **logged and swallowed**; the callable still returns `roomClosed: true`.
- [ ] Transaction contents unchanged — the player-doc deletes and room delete still happen inside it.
- [ ] **The nightly orphan sweep is retained**, not removed.
- [ ] Sweep capped at `DEFAULT_ORPHAN_SWEEP_LIMIT = 100`; **the scan is bounded, not just the deletion**; `orphanSubtreesScanned` added to the result and the log line.
- [ ] Cap falsified by removing the break.
- [ ] `npm --prefix functions test` ≥ **112**; `flutter test` still exactly **267**.
- [ ] Committed **before** deploying; `check_deploy_fresh.sh` exits **0** bare with **17** functions.

**W2**
- [ ] **Production check done first:** a lobby closed after W1 produced **no new orphan**, figures pasted.
- [ ] `CLEANUP_DRY_RUN=false` applied **and read back** from the deployed environment.
- [ ] The revert-on-redeploy behaviour is documented in `design_database_and_security.md` §10 with the restore command.
- [ ] First live run's numbers compared against the dry-run prediction and reported.
- [ ] **`authUsersReferenced` is ≥ 1** on the live run.
- [ ] No source changed.

**Across the wave**
- [ ] Issues **145 and 146** moved into the **single** existing Resolved heading, with `design_database_and_security.md` §10 updated.

---

## 5. Already delivered — do NOT rework

- **V1 (143, 144)** — deployed environment verified, 17 functions redeployed from the committed tree, deploy gate exit 0, first dry-run log captured. **The 24-hour retention window is settled** (user, August 31, 2026); rationale and the `ROOM_TTL_MS` coupling invariant are in `design_database_and_security.md` §10.4.
- **U1 (140)** — manifest `Report` column + R6 scoping. Falsified independently.
- **U2 (141)** — `AppMotion.reduce` reads the real `reduceMotion` bit OR `accessibleNavigation`; deciding experiment was run. Device-verified.
- **U3 (142)** — 30 s heartbeat, `lastSeen`-only rebuild suppression via explicit field comparison, host-gated disconnects with 60 s cooldown, `paused`/`resumed`.
- **U4 (135)** — E49 PASS; screenshots show Erin seated at 7:07 among five and gone at 7:16 among four, clocks 9 minutes apart. **First genuine device verification of Issue 123.**
- **S1 (139)**, **E47/E48**, **R0 (138)**, **R1 (136)**, **R2 (137)**, **soak blocks E22–E49**, **Wave Q**, **Wave P**, **Wave O's six**, **Issues 96–105**, **50–95**, **31**, **28/29**.
- ⚠️ **`EmberBackdrop` (`game_over_screen.dart:900`) deliberately untouched** — its ticker never settles, so `pumpAndSettle` on game-over would hang. Latent. **Do not fix without filing.**

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206, not 207.** Bar is **206 and no new infos**.
- **E48 merged two specified artefacts into one.**
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`.**
- **R0 leaves `..repeat()` in `initState`.**
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 6. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** Cleanup deletes them with admin credentials, which bypass rules — **do not add match blocks to make cleanup easier.** This is also why Issue 146's orphaned tokens were never client-readable.
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
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and **must always exceed `ROOM_TTL_MS` (8 h) by a wide margin** — see `design_database_and_security.md` §10.4.
- **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`** and must not be collapsed to `lastRefreshTime`.
- **`AppMotion.reduce` must keep the `accessibleNavigation` OR term** (Issue 141).
- **`lastReaction` / `lastReactionAt` in `player_state.dart` are deliberately retained dead fields** from Issue 74. Dropping them needs a rules deploy and a data migration.
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit.

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and both at once (142 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C); **enabling deletion before fixing the leak (145 B) and splitting `CLEANUP_DRY_RUN` into two flags (145 C)**; **leaving the orphan source in place and relying on the nightly sweep (146 B)**; **fixing the source while leaving the sweep uncapped (146 C)**.

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 7. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| **All playthrough material** | **`docs/playthroughs/`** |
| Block titles + specified assertions (R6's source) | `docs/playthroughs/manifest.md` |
| Screenshot hand-off record | `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| Rules, seat tokens, presence, heartbeat, **retention & cleanup (§10)** | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, header sizing, **which signal means "reduce motion"** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 8. Validation standard

**Read a safety mechanism's output as evidence, not a checkbox.** `CLEANUP_DRY_RUN` existed to prevent premature deletion; its first log found a leak every gate, test and playthrough had missed (§2.37 in the tracking doc). W2 Step 3's prediction-vs-outcome table exists for the same reason.

**Be suspicious of counts that cannot both be true.** `roomsScanned=0` beside `orphanSubtreesSwept=101` was the whole finding, visible in one line.

**A component built in one pass will have inconsistencies between its parts.** `cleanup.ts` capped two of its three phases. When a spec says "add a cap", check every loop.

**Cap the expensive operation, not the visible one.** Bounding deletions while leaving a `.get()` per document unbounded fixes the symptom and leaves the cost.

**Prefer the minimal structural change on a path with history.** The close path has produced Issues 85, 87 and 123; W1 deliberately leaves the transaction's contents alone.

**A failure that reverts in the safe direction is still a failure.** W2's env var silently disappears on the next deploy — the job keeps running and stops deleting, and nobody notices.

**Re-run every gate yourself before trusting a table.** This file has twice recorded a gate result that did not match reality.

**Falsify every guard**, and when you *repair* one, re-run its original falsifications to prove you did not weaken it.

**Read exit codes bare.**

---

## THE LOOP

```
(1) STUDY the item here + its issue text in ongoing_general_errors.md + the
    files at the cited anchors. RE-GREP every anchor; line numbers drift.
(2) If the spec says "determine X first", DO THAT AND RECORD THE RESULT
    before writing the fix.
(3) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body.
(4) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(5) VALIDATE, including every over-reach guard, then RE-RUN THE GUARD WITH
    THE FIX REMOVED and confirm it fails.
(6) ENUMERATE EVERY INVOCATION of anything you changed and run them all.
(7) RE-RUN THE FULL BATTERY -- exit codes bare, except flutter analyze,
    where the bar is 0 errors / 0 warnings and the code is always 1.
(8) COMMIT BEFORE DEPLOYING. Deploy-then-commit makes the freshness gate
    red by construction.
(9) BLOCKED, or a decision is needed? STOP. File it with options, Pros/Cons,
    one (recommended), and a blank `Your selection: _____`.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**After W2's Step 3, report the live-run numbers and stop. Do not invent work.**
