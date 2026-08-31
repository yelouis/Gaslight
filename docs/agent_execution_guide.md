# Agent Execution Guide — Active Build: Wave U — repair the gate, fix the wrong accessibility flag, cut the network chatter, then verify presence on a device — August 30, 2026

**You are an engineering agent with no memory of this project.**

**Four items are approved. A fifth is written up and ready but must not be started until the user gives an explicit go-ahead** (§8).

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **U1** | Scope the playthrough manifest per report — R6 fails 3 of 4 gate invocations | **140 → A** (completes it) | tooling | — |
| **U2** | `AppMotion.reduce()` reads the wrong accessibility flag | **141 → A** | client | — |
| **U3** | Cut the presence chatter — the dominant battery cost | **142 → A** | client | — |
| **U4** | Run Match N2 and finish **E49**, the presence window | **135 → A** (completes it) | test only | — |
| **U5** | Nightly cleanup of expired rooms, subtrees and anonymous users | **143 → A** | **server** | **YES** ⚠️ |

**U1–U4 need no deploy** and `./scripts/check_deploy_fresh.sh` must stay at exit 0 throughout. **U5 is the first item in five waves that touches `functions/src` and requires `firebase deploy`** — see §8.

**One item = one commit.**

**Every number, formula and literal string below is a decision, not a suggestion.**

---

## 0. Ordering, and why

**U1 → U2 → U3 → U4.** U5 is independent and gated.

- **U1 first.** The evidence gate is **currently red on three of its four invocations**. Every later item's acceptance includes "the gate is green"; you cannot certify anything with a broken instrument.
- **U2 before U4.** Wave T deliberately *dropped* the Reduce Motion device-evidence prerequisite from the soak, because Issue 141 made the OS toggle unobservable. **Fixing 141 restores it** — so U4 can finally capture R0's device evidence, which has been outstanding since Wave R.
- **U3 before U4.** U3 changes heartbeat cadence and the presence-disconnect path. E49 is a device test *of the presence window*. Landing U3 first means **E49 verifies the behaviour that actually ships**, and doubles as the device proof that U3 did not break the 10-minute window. This is the single most valuable ordering decision in the wave.
- **U4 last.** It is the only item costing ~12 minutes of wall clock plus a full five-device setup.

---

## 1. Verified baseline — measured on `e09833a`

| Gate | Result | After Wave U |
|---|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** | unchanged |
| `flutter test` | **258 passing**, exit 0 | ≥ 258 |
| `npm --prefix functions run build` | clean, exit 0 | clean |
| `npm --prefix functions test` | **102 passing**, exit 0 | ≥ 102 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** | exit 0 |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH** | exit 0 (re-deploy for U5) |
| `./scripts/check_playthrough_evidence.sh` *(no args → marionette)* | ⚠️ **exit 1 — REGRESSED by S2** | **exit 0** |
| `… docs/playthrough_findings_marionette.md` | ⚠️ **exit 1 — REGRESSED** | **exit 0** |
| `… docs/playthrough_findings_web.md` | ⚠️ **exit 1 — REGRESSED** | **exit 0** |
| `… docs/playthrough_findings_5player.md` | **exit 0** — 28 blocks, 27 PASS, 1 NOT RUN, R6 3/3 | **28 blocks, 28 PASS, 0 NOT RUN** |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are 206. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** The 206 infos are accepted and tracked; they must not grow.

**Read every other exit code bare, never through a pipe.** A piped run of the broken gate printed `EXIT=0` during verification while the bare run gave 1.

---

## 2. U1 — Scope the manifest per report (completes Issue 140)

**What this means for the user:** nothing visible. A safety check added last wave is failing on reports it was never meant to govern, and a gate that is *expected* to be red teaches everyone to ignore it.

### 2.1 The gap

`scripts/check_playthrough_evidence.sh` takes a report path and defaults to `docs/playthrough_findings_marionette.md`. R6 reads `docs/playthrough_manifest.md` and requires **every** manifest row's block to exist in **whatever report is being checked**. The three rows (E47, E48, E49) exist only in the five-player report, so:

```
FAIL: 3 violation(s) found across 21 blocks:
  [E47] R6 violation: Block is listed in docs/playthrough_manifest.md but does not exist in
        .../docs/playthrough_findings_marionette.md.
```

**Measured — three of four invocations regressed from exit 0 to exit 1:** no-args ❌, `…marionette.md` ❌, `…web.md` ❌, `…5player.md` ✅.

This is the exact con recorded against Option A when it was chosen — *"a stale manifest will produce false failures that erode trust in the gate"* — arriving one commit later.

### 2.2 Implementation

1. **Add a `Report` column to `docs/playthrough_manifest.md` as the first column**, carrying the repo-relative path of the report the row governs:
   ```
   | Report | Block | Title | Specified assertion | Artefact must depict |
   |---|---|---|---|---|
   | docs/playthrough_findings_5player.md | E47 | Own answer is sealed in round 2, … | … | … |
   ```
   First column because it is the scoping key and reads as one. All three existing rows take `docs/playthrough_findings_5player.md`. **The parser's capture-group indices shift by one — update them.**
2. **R6 filters rows by report before doing anything else.** Normalise both sides to a repo-relative path so `./docs/x.md`, `docs/x.md` and an absolute path compare equal. Rows for other reports are skipped entirely — not checked, not counted as violations.
3. **Keep the FATAL, but scope the counting.** This is where a careless fix silently disables R6:
   - Manifest exists but parses to **zero rows overall** → **FATAL**, exit 1. Keep exactly as-is (lesson 2.21).
   - Manifest parses rows but **none govern the report under test** → **legitimate**. Pass, and say so: `R6: 0 of 3 manifest entries govern this report.` The Wave N and web reports are permanently in this state.
   - Rows govern it → check them: `R6: 3 of 3 manifest entries checked.`

   **Do not collapse the last two into "no rows, nothing to do".** The distinction between *"the manifest is broken"* and *"this report is ungoverned"* is the entire reason the FATAL exists.
4. **The summary line must name the report it scoped to**, so a reader can tell which invocation produced a given line.

### 2.3 Validation

- **The falsifying test.** Run the gate **with no arguments**: currently exits **1**, must exit **0**. Same for `…marionette.md` and `…web.md`. Paste all bare, not piped.
- **Run all four invocations and paste all four exit codes.** Enumerating every invocation is the actual lesson (§2.35 in the tracking doc): a rule's blast radius is every file the tool can be pointed at.
- **R6 must not be weakened.** Re-run its three original falsifications against the five-player report: (a) one-word title change → exit 1; (b) one-word `Specified assertion:` change → exit 1; (c) empty manifest table body → **FATAL**, exit 1.
- **Over-reach guard — scoping must *select*, not *disable*.** Add a temporary manifest row governing `docs/playthrough_findings_marionette.md` for a block that really exists there, alter that block's title by one word, and confirm the **no-argument** run fails. **Without this guard, a fix that simply ignores the manifest everywhere passes every other check in this list.** Remove the temporary row afterwards.

**Blast radius:** `scripts/check_playthrough_evidence.sh` · `docs/playthrough_manifest.md` · §1 here · the gate table in `ongoing_general_errors.md`.

---

## 3. U2 — Read the real Reduce Motion flag (141 → A)

**What this means for the user:** someone who turns on **Reduce Motion** in iOS Settings currently gets no change anywhere in the app. The setting the code checks is the one iOS sets for **VoiceOver**, which is a different thing. Every "respect reduced motion" behaviour in the app is wired to the wrong switch.

### 3.1 The gap

`lib/theme/app_motion.dart:11`:
```dart
static bool reduce(BuildContext c) => MediaQuery.of(c).accessibleNavigation;
```

Confirmed at SDK level. `dart:ui`'s `AccessibilityFeatures` (`bin/cache/pkg/sky_engine/lib/ui/window.dart`) carries **three separate bits**: `accessibleNavigation` (`1 << 0`), `disableAnimations` (`1 << 2`), `reduceMotion` (`1 << 4`). `packages/flutter/lib/src/widgets/media_query.dart` populates the first two from `platformDispatcher.accessibilityFeatures` (`:313–320`) and mentions `reduceMotion` **zero times**. `grep -rn disableAnimations lib/ test/` finds no use in this app.

`AppMotion.reduce` has **38 call sites across 17 files**, so every motion-reduction behaviour in the app — the R0 particle suppression, `lobby_background`, `raven_mascot`, `waiting_indicator`, `lamp_loading`, `lobby_logo`, `shared_ui`, `player_avatar`, `game_over`'s ember backdrop, `TitleSettle` — responds to VoiceOver/Switch Control instead.

### 3.2 ⚠️ STEP ZERO — run the deciding experiment before writing any fix

**The device evidence proves only that `accessibleNavigation` is the wrong flag. It does not establish which replacement is right, and the two candidates imply materially different implementations.**

On a simulator with **Reduce Motion ON** (verify with `xcrun simctl spawn <udid> defaults read com.apple.Accessibility ReduceMotionEnabled` → `1`), print both:

```dart
debugPrint('disableAnimations=${MediaQuery.of(context).disableAnimations} '
           'reduceMotion=${PlatformDispatcher.instance.accessibilityFeatures.reduceMotion}');
```

- **If `disableAnimations` is `true`** → take the simple path. `AppMotion.reduce` becomes `MediaQuery.of(c).disableAnimations || MediaQuery.of(c).accessibleNavigation`. It stays a **pure function of `BuildContext`**, all 38 call sites keep working unchanged, `didChangeDependencies` keeps firing correctly because `MediaQuery` is an inherited widget, and **no `WidgetsBindingObserver` is needed anywhere.** Stop here.
- **If only `reduceMotion` is `true`** → the `PlatformDispatcher` path in §3.3 is required.

**Paste both printed values into the commit body.** **Do not build the observer version on the assumption that it is required** — that assumption is what the experiment exists to test.

### 3.3 Implementation (only if the experiment says `disableAnimations` is false)

1. `AppMotion.reduce(BuildContext c)` returns
   `PlatformDispatcher.instance.accessibilityFeatures.reduceMotion || MediaQuery.of(c).accessibleNavigation`.
   **Keep the `accessibleNavigation` term.** Every existing widget test injects `MediaQueryData(accessibleNavigation: true)`; OR-ing preserves all of them, and a VoiceOver user genuinely should get reduced motion too.
2. **Live updates need an observer**, because a `PlatformDispatcher` read bypasses `MediaQuery` and therefore does not trigger `didChangeDependencies`. Add `WidgetsBindingObserver` with `didChangeAccessibilityFeatures() => setState(() {})` to the stateful widgets that must react **while mounted**. `thinking_background.dart` already registers an observer for its ticker — extend it rather than adding a second.
3. **Normalise `auto_advance_timer.dart:90`**, which reads `MediaQuery.of(context).accessibleNavigation` directly. It has the same bug. Route it through `AppMotion.reduce`. The guide previously listed this as an accepted style inconsistency; **Issue 141 shows it is a behavioural one, so that entry is withdrawn.**

### 3.4 Validation

- **The falsifying test.** A widget test that stubs the accessibility feature as Reduce-Motion-on **without** setting `accessibleNavigation`, and asserts `AppMotion.reduce(context)` is `true`. **Run it against current code and watch it fail** — that failure is the whole issue in one line. Paste it into the commit body.
- **Over-reach guard — the existing injection pattern still works.** With `MediaQueryData(accessibleNavigation: true)` and Reduce Motion off, `AppMotion.reduce` must still be `true`. **Run the full suite: all 258 tests must still pass.** If any test that injects `accessibleNavigation` breaks, you dropped the OR term.
- **Over-reach guard — motion is not disabled unconditionally.** With both signals false, assert `AppMotion.reduce` is `false` and the particle layer **is** present (scoped `find.descendant`, as `thinking_background_reduce_motion_test.dart` already does). Otherwise "fixing" this by returning `true` passes everything else.
- **If §3.3 step 2 was needed:** a test that flips the feature on a mounted tree and asserts it re-renders — proving the observer is wired, not just the getter.
- **Device check.** On the simulator with Reduce Motion on, the craft/vote/reveal background must have **no drifting glyph particles** while the gradient and content remain. **Screenshot it — U4 needs this artefact anyway** (§5.2 item 8).

**Blast radius:** `lib/theme/app_motion.dart` · `lib/widgets/auto_advance_timer.dart` · possibly `lib/widgets/thinking_background.dart` · a new test · **`docs/design_ui_direction.md`** (record which platform signal the app treats as "reduce motion", and that `accessibleNavigation` alone was wrong).

---

## 4. U3 — Cut the presence chatter (142 → A)

**What this means for the user:** the game drains battery mainly because every phone tells the server "I'm still here" every 10 seconds, and every one of those messages wakes up all the other phones and makes them redraw. The server only cares every 10 minutes. This is four small changes that stop the app shouting.

### 4.1 The gap — four causes, in impact order

1. **Heartbeat ~60× more frequent than needed.** `game_service.dart:320` — `Timer.periodic(const Duration(seconds: 10))` writing `lastSeen`. Server threshold `PRESENCE_STALE_MS = 600_000` (10 min, `index.ts:179`); the client's own local check is 60 s (`game_service.dart:490`).
2. **Every heartbeat wakes every device.** `game_service.dart:459` listens to the whole `players` collection and calls `notifyListeners()` **unconditionally** (`:501`). Five writers × 6 writes/min × 5 receivers ≈ **150 rebuilds/min per room**.
3. **A rejected-callable storm.** The `deadPlayers` loop (`:485–499`) fires `handleDisconnect` for anyone unseen 60 s, **is not gated to the host**, and re-fires on every snapshot — while the server refuses a presence disconnect until 10 minutes (`index.ts:1180`). ≈ **1,000+ rejected invocations per stale player.**
4. **No `paused` branch.** `didChangeAppLifecycleState` (`:341`) handles only `resumed`, so nothing deliberately stops the heartbeat when the app leaves the foreground.

### 4.2 Implementation

**Change 1 — heartbeat interval 10 s → 30 s.** `game_service.dart:320`.
Margin check, and these are the numbers that matter: the client marks a peer stale at **60 s**, so 30 s gives **2 beats** inside that window — one lost beat is tolerated, two is not. The server's window is 10 min = **20 beats**. **Do not go above 30 s** without also raising the client's 60 s threshold; at 45 s a single dropped write would false-positive.

**Change 2 — suppress the rebuild when only `lastSeen` moved.** In the players listener, before `notifyListeners()`, compare the incoming list to `_players` on **every field except `lastSeen`**. If nothing else changed, update `_players` (so staleness math stays fresh) and **return without notifying**.
⚠️ **`_players` must still be assigned.** Skipping the assignment as well would freeze the staleness check that Change 3 depends on.
⚠️ Implement the comparison as an **explicit field-by-field equality on `PlayerState`**, not `toString()` or `hashCode` — a `PlayerState` gaining a field later must not silently start being ignored.

**Change 3 — gate the disconnect loop and give it a cooldown.**
- Gate the `deadPlayers` loop to **the host only** (`currentPlayer?.isHost == true`). One caller is sufficient; the server is authoritative and the invariant is that the presence window gates the *action*, not the caller.
- Add a per-player cooldown map, `Map<String, int> _lastDisconnectAttemptAt`, and skip a player if fired within the last **60 s**. Clear the entry when the player disappears from the roster.
- **Both are required.** Host-gating alone still yields ~30 rejected calls/min from the host; the cooldown alone still multiplies by every device.

**Change 4 — stop the heartbeat when backgrounded.** Extend `didChangeAppLifecycleState` with a `paused` branch that cancels `_heartbeatTimer`. `resumed` already writes `lastSeen` immediately and restarts it (`_handleAppResumed`), so the resume path is done.
⚠️ **Do not cancel the Firestore listeners on `paused`.** Only the timer. Killing the subscriptions changes reconnect behaviour and is out of scope.

### 4.3 Validation

**All four changes are countable. Prove each with a number, not an impression.**

- **The falsifying tests**, each run against current code first and **observed to fail**:
  1. **Cadence.** With a fake clock, advance 60 s and assert **exactly 2** `lastSeen` writes, not 6. Drive it through `GameService`, not by reading the constant — *a constant's value is not behaviour.*
  2. **Rebuild suppression.** Attach a listener counter to `GameService`, deliver a players snapshot whose only delta is one `lastSeen`, and assert the counter **does not increment**. Then deliver a snapshot with a real change (a name, a score, a departure) and assert it **does**. The second half is the over-reach guard — without it, "never notify" passes.
  3. **Disconnect storm.** Simulate a player stale for 5 minutes with `FakeFirebaseFunctions` counting `handleDisconnect` invocations. On a **non-host** device assert **0**. On the **host**, assert **≤ 5** over those 5 minutes (one per 60 s cooldown), against ~150 today.
  4. **Backgrounding.** Push `AppLifecycleState.paused`, advance 5 minutes of fake time, assert **0** writes; push `resumed`, assert writes resume **and** one immediate `lastSeen` write occurs.
- **⚠️ The over-reach guard that matters most — presence must still work.** `test/presence_lifecycle_test.dart` exists; **it must still pass**, and the 10-minute server window must be unchanged. **Re-run `npm --prefix functions test` (102) — if any presence test moves, stop.** Issues 120, 123 and 141 all came out of this code path.
- **Falsify Change 3's gate:** remove the host check and confirm the non-host test fails. A guard whose test passes either way is decoration.
- **Full suite ≥ 258.**
- **U4 is the device proof.** E49 exercises the real presence window on five phones against this build. If U3 broke presence, E49 is where it shows up — which is exactly why U3 lands before U4.

**Blast radius:** `lib/services/game_service.dart` · new tests · **`docs/design_database_and_security.md`** — record the heartbeat cadence, the client-vs-server thresholds, and that only the host triggers presence disconnects.

---

## 5. U4 — Run Match N2 and finish E49 (completes Issue 135)

**What this means for the user:** when a phone dies mid-game the player should keep their seat for ten minutes and be able to rejoin. That shipped as Issue 123 and **has never once been checked on a real device**, across three attempts.

### 5.1 The block

E49 already exists in `docs/playthrough_findings_5player.md` as `NOT RUN`, and its manifest row is written. **Its title and `Specified assertion:` are fixed by the manifest — R6 rejects any drift.**

> **E49 — Presence: still seated at ~2 min, gone at ~11**
> *After xcrun simctl terminate on P5 (no relaunch), P5 is still present in every other device's roster at approximately 2 minutes and absent at approximately 11 minutes, with both wall-clock timestamps recorded.*

**Config:** five players · **timers OFF** (with timers on, phases auto-advance during the wait and the state changes underneath the assertion) · any forgery count · `Rounds = 1` is fine.

**Procedure:**
1. Reach an active phase with all five seated.
2. `xcrun simctl terminate <P5 udid> <bundle id>` — **do not relaunch.** Record wall-clock time.
3. **At ~2 minutes: assert P5 is STILL in the roster on every other device.** Before Issue 123 a host-initiated `handleDisconnect` evicted them at exactly this mark.
4. **At ~11 minutes: assert P5 is gone.**
5. Record **both** wall-clock timestamps in the block **and** in `ARTEFACTS.tsv`'s `captured_utc`. **Here that column is the evidence** — two screenshots ~9 minutes apart *is* the assertion.

**Artefacts must depict:** a remaining device's roster **with P5 present**, status-bar clock legible; and the same roster **with P5 absent**, clock legible.

⚠️ **A voluntary departure via the `Leave game` dialog is NOT this test.** Different mechanism, seconds not minutes, cannot fail the way Issue 123 failed. It is exactly what E46 substituted. **If the ~12-minute wait cannot be performed, leave E49 `NOT RUN` and update its `Reason:`.** Substitute nothing.

**This also serves as U3's device verification.** If the heartbeat changes broke presence, this is where it surfaces. Note U3's SHA in the block.

### 5.2 Prerequisites

Five Marionette servers (`marionette-p1`…`p5`; **if fewer than five are exposed, STOP and tell the user**) · five booted simulators, distinct models, UDIDs and DDS ports recorded · **`.env` with `USE_EMULATOR=false`** (a bundled asset — changing it post-build has no effect) · **uninstall on all five before installing** (`SharedPreferences` survives install-over-the-top and a device silently rejoins its old room) · build once, install five times, prove the binary is newer than the source · `./scripts/check_deploy_fresh.sh` exit 0 · **record `Commit SHA Tested`, which must contain U1, U2 and U3.**

**8. Reduce Motion device evidence is BACK IN SCOPE — U2 restores it.** Wave T dropped this prerequisite because Issue 141 made the toggle unobservable. With U2 landed it is observable again. **Enable Reduce Motion on exactly one device, record its UDID, and capture one screenshot of that device on craft or vote showing the background with no drifting glyph particles** while the gradient and content remain. Log it in `ARTEFACTS.tsv`. **This is R0's device evidence and U2's — outstanding since Wave R.**

**Drive by `ValueKey` or unique text, never pixel bounds.** Keys: `player_name_field`, `room_code_field`, `deck_<id>`, `forgeries_<n>`, `rounds_<n>`, `timer_seconds_field`, `answer_field`, `game_over_bottom_bar`. Labels: `CREATE ROOM`, `START GAME`, `SUBMIT DOSSIER`, `CONFIRM VOTE`, `RETURN TO LOBBY`, `Leave game` → `LEAVE GAME` in game, and **`Leave room` → `CLOSE ROOM`/`LEAVE` in the lobby** (a different control).

### 5.3 Reporting

- **Replace the E49 `NOT RUN` block in place.** Keep the heading and `Specified assertion:` **byte-identical** — R6 enforces it, and a "helpful" rewording fails the gate.
- Block shape: `Verdict`, `Devices`, `Room Code`, `Commit SHA Tested`, `Specified assertion`, `What I did`, `Observed`, `Artefact depicts`, `Reference`, `Expected`.
- **`Observed:` must contain a real artefact** — screenshot path, `Type:`/`Text: "…"` widget entry, or a `flutter:` log line. **A `grep -` is a hard failure.**
- **Gate must report 28 blocks, 28 PASS, 0 NOT RUN, R6 3 of 3.** Exit code bare.
- **Open both screenshots and confirm the status-bar clocks really are ~9 minutes apart.** That single check would have caught two of the three previous re-aims.
- **If E49 finds a defect:** file it with options, Pros/Cons and a blank selection line, then stop.

---

## 6. Definition of Done

**U1** — [ ] all **four** invocations exit 0, pasted bare · [ ] R6's three original falsifications still fail correctly · [ ] the scoping over-reach guard passed · [ ] `Report` column added and parser indices updated · [ ] zero-rows-overall still FATAL, zero-rows-for-this-report passes and says so.

**U2** — [ ] **the deciding experiment was run and both values pasted** · [ ] falsifying test observed to fail first · [ ] all 258 tests still pass (the `accessibleNavigation` OR term survives) · [ ] with both signals false, motion is **not** reduced · [ ] `auto_advance_timer.dart` normalised · [ ] device screenshot shows no particles under Reduce Motion.

**U3** — [ ] four falsifying tests, each observed to fail first · [ ] 60 s of fake time yields **exactly 2** writes · [ ] a `lastSeen`-only snapshot does **not** notify, a real change **does** · [ ] non-host fires **0** `handleDisconnect`, host **≤ 5** per 5 min · [ ] `paused` stops the heartbeat, `resumed` restarts it with an immediate write · [ ] **`presence_lifecycle_test.dart` and all 102 functions tests still pass** · [ ] host-gate falsified by removal.

**U4** — [ ] E49 is `PASS` (or still `NOT RUN` with an updated `Reason:` — never re-aimed) · [ ] both wall-clock timestamps recorded, P5 present ~2 min, gone ~11 · [ ] both screenshots logged in `ARTEFACTS.tsv`, **opened**, clocks legible and ~9 min apart · [ ] heading and `Specified assertion:` byte-identical · [ ] `Commit SHA Tested` contains U1–U3 · [ ] **Reduce Motion artefact captured** · [ ] gate reports **28 blocks, 28 PASS, 0 NOT RUN, R6 3/3**.

**Across the wave** — [ ] **0 errors · 0 warnings · 206 infos** · `flutter test` ≥ 258 · clean functions build · ≥ 102 functions · deck sync exit 0 · **all four** evidence-gate invocations exit 0 · deploy exit 0 · [ ] Issues **135, 140, 141, 142** moved into the **single** existing Resolved heading, with `design_ui_direction.md` and `design_database_and_security.md` updated.

---

## 7. U5 — Nightly cleanup (143 → A) — ⚠️ DO NOT START WITHOUT AN EXPLICIT GO-AHEAD

**The user selected Option A and asked for the running cost first.** The cost report is §8. **U5 is fully specified here so it is ready the moment they say go — but it must not be started until they do.**

### 7.1 The gap

`ROOM_TTL_MS = 8 * 60 * 60 * 1000` (`index.ts:181`) and `expiresAt: ttlFrom(...)` is written and refreshed at **ten** sites. But `grep -rn "onSchedule|pubsub|scheduler" functions/` returns nothing — all 16 deployed functions are `onCall`, and no Firestore TTL policy is configured. **The expiry stamp is written and never read**, so every room ever created still exists.

**⚠️ The trap, already visible in production:** Firestore deletes documents, not subtrees. Rooms own `players`, `sealed` and `embeddings` (the latter two are default-deny by having no `match` block in `firestore.rules` — that is intentional and must stay). The user's console shows room **`BGHW` in italics with "This document does not exist"** while still owning a `sealed` subcollection. **Orphaned subtrees are already accumulating**, invisible to the app and to any cleanup that targets room documents only.

### 7.2 Implementation

`firebase-functions ^5.0.0` and `firebase-admin ^12.0.0` are already in `functions/package.json`, so `firebase-functions/v2/scheduler` and `firestore.recursiveDelete()` are available with no dependency change.

One new scheduled function, e.g. `functions/src/cleanup.ts`, exported from `index.ts`:

1. **`onSchedule`, once daily**, off-peak. Give it a generous timeout and modest memory; it is I/O-bound.
2. **Query expired rooms**: `where('expiresAt', '<=', Timestamp.now())`, `limit(MAX_ROOMS_PER_RUN)`. **A composite index may be required — check `firestore.indexes.json` and add one if the query is rejected.**
3. **`recursiveDelete()` each room reference**, not `.delete()`. This is the only call that removes `players`, `sealed` and `embeddings` with the parent, and it is the entire reason Option A was selected over the TTL policy.
4. **Then sweep orphans**: rooms whose document is gone but whose subcollections are not. `listDocuments()` on `rooms` returns references for missing parents that still have subcollections — exactly the `BGHW` case. Recursive-delete those too.
   ⚠️ **Order matters: expired-room deletion first, orphan sweep second.** Reversed, the sweep re-walks what was just deleted.
5. **Then purge anonymous auth users**, and this is the dangerous step:
   - `listUsers()` paginated; select `providerData.length === 0` (anonymous) **and** `metadata.lastRefreshTime` older than the retention window.
   - **Build the set of `authUid`s still referenced by any surviving room's `players` subcollection, and exclude them.** ⚠️ **Compute this set AFTER the deletions in steps 3–4**, so it reflects the post-cleanup world. Deleting an auth user whose seat is live destroys a player's session mid-match.
   - `deleteUsers()` takes at most **1000 UIDs per call** — batch accordingly.
6. **Mandatory safety rails, all three:**
   - **`DRY_RUN` flag, defaulting to `true`.** First deploy logs what it *would* delete and deletes nothing. Only flip it after reading a real run's log.
   - **A hard cap per run** on rooms and on users. The backlog then drains over several nights instead of one unbounded run — which also keeps every night inside the free tier (§8).
   - **Structured logging**: counts of rooms scanned/deleted, subtrees swept, users considered/skipped-as-referenced/deleted. A silent scheduled job that stops working is the failure mode of this whole category.

### 7.3 Validation

- **Emulator tests in `functions/test/` — this is the project's strongest gate and this feature must not ship without them.** Cover: (a) an expired room with populated `players`/`sealed`/`embeddings` is deleted **including all three subcollections** — assert each is empty afterwards; (b) a **non-expired** room is untouched; (c) an orphaned subtree with no parent document is swept; (d) an anonymous user referenced by a surviving room is **NOT** deleted; (e) an old unreferenced anonymous user **is**; (f) with `DRY_RUN=true` **nothing is deleted** and the log still reports what it would have.
- **(b) and (d) are the over-reach guards and they are the point.** A cleanup job that deletes everything passes (a), (c) and (e) perfectly.
- **Falsify the subtree deletion:** replace `recursiveDelete()` with `.delete()` and confirm test (a) fails on the leftover subcollections. If it still passes, the test is asserting the parent only and proves nothing about the trap this option exists to solve.
- **Falsify the reference guard:** remove the "still referenced" exclusion and confirm (d) fails.
- **Deploy discipline.** U5 is the **first `functions/src` change in five waves**. `predeploy` runs build + tests, so a red suite blocks the deploy. After deploying, `./scripts/check_deploy_fresh.sh` must exit **0** and report **17** functions, not 16.
- **First production run must be `DRY_RUN=true`.** Read the log, confirm the counts are plausible, and only then flip it.

**Blast radius:** new `functions/src/cleanup.ts` · `functions/src/index.ts` export · possibly `firestore.indexes.json` · new emulator tests · **`docs/design_database_and_security.md`** — record the retention window, what the job deletes, the ordering constraint, and the auth-reference exclusion.

---

## 8. U5 cost report — answering the user's question before U5 starts

**Running cost at this app's current scale: $0.00/month.** Every component sits inside a free allowance with several orders of magnitude of headroom.

| Component | No-cost allowance | What one nightly job uses | Cost |
|---|---|---|---|
| **Cloud Scheduler** | **3 jobs/month per billing account** | 1 job | **$0.00** |
| **Cloud Functions invocations** | 2M/month | ~30/month | **$0.00** |
| **Cloud Functions compute** | 400K GB-s + 200K CPU-s/month | ~225 GB-s/month (30 s @ 256 MB × 30) | **$0.00** |
| **Firestore reads** | 50,000/day | a few hundred per night | **$0.00** |
| **Firestore deletes** | 20,000/day | ~15 docs × rooms cleaned | **$0.00** |
| **Firebase Auth** | billed by **MAU** (50K free), not stored users; deletes are free | — | **$0.00** |

**Paid rates if the free tier were ever exceeded** (nam5, the database's region per the console): reads **$0.06/100K**, writes **$0.18/100K**, **deletes $0.02/100K**, storage **$0.18/GB-month** (first 1 GB free), egress $0.12/GB (first 10 GB free).

**Worst case, the one-time backlog.** Even if the accumulated backlog were 100,000 documents, deleting all of it costs **$0.02** — two cents, once. With the per-run cap in §7.2 it drains over a few nights and stays inside the free tier entirely, costing nothing.

**Two honest caveats:**
1. **Cloud Scheduler's 3 free jobs are per *billing account*, not per project.** This project has no scheduled functions today, so job #1 is free. If that billing account already runs 3+ jobs elsewhere, this becomes **$0.10/month**.
2. **This will not save money, because nothing is being spent.** Stored data is almost certainly under the 1 GB free tier, so the storage bill today is $0.00 and will be $0.00 after. **The case for U5 is operational, not financial**: unbounded, invisible orphan growth; an ever-expanding auth list; and a `rooms` collection that keeps getting slower to list. Choose it on those grounds or not at all.

**One uncertainty from the original filing is now resolved.** Issue 143's Option B asked to confirm whether TTL deletions are billed. Firebase's documentation lists **"TTL deletes" among the operations that do not include free usage** — so platform TTL deletes would be billed from the first document, while the scheduled function's deletes draw on the 20,000/day free tier. **This makes the selected Option A cheaper than the alternative, not merely tidier.**

Sources: [Cloud Scheduler pricing](https://cloud.google.com/scheduler/pricing) · [Firebase pricing](https://firebase.google.com/pricing) · [Firestore billing example (nam5 rates)](https://docs.cloud.google.com/firestore/native/docs/billing-example) · [Understand Cloud Firestore billing](https://firebase.google.com/docs/firestore/pricing)

---

## 9. Already delivered — do NOT rework

- **S1 (Issue 139)** — 15 removals; 0 warnings, 206 infos, no suppressions; retained `lastReaction` fields intact. Verified.
- **S2's manifest, R6 and `ARTEFACTS.tsv` (Issue 140)** — built and sound; **only the report scoping is wrong** (U1). Do not rewrite R6; fix its scope.
- **R0 (Issue 138)** — `AnimatedThinkingBackground` omits the particle layer when `AppMotion.reduce()` is true; ticker stopped in `didChangeDependencies`. Falsified: removing only the ticker guard yields 5 `pumpAndSettle timed out` failures while the layer guard still passes. ⚠️ **Inert on device until U2** — the code is right, the flag is wrong. **`EmberBackdrop` (`game_over_screen.dart:900`) deliberately untouched**; its ticker still never settles, so `pumpAndSettle` on game-over would hang. Latent. **Do not fix without filing.**
- **R1 (136)** — `inGameAppBarHeight` measures each line with a `TextPainter` at the live `textScaler` against `screenWidth − 112`, real style objects, 2 pt gaps, 8 pt breathing, clamped at `kToolbarHeight`; craft, vote and reveal. `TitleSettle` got **both** mitigations.
- **R2 (137)** — `FittedBox` removed, cap `min(screenHeight * 0.7, 560)`, self-sizing content, scroll view as floor; test derives the longest prompt from `PromptDecks.allDecks` at run time with real fonts.
- **E47 and E48** — verified by opening every artefact. **Do not re-run.** The E48 pair shows `SEALED ANSWER` during the unmask window and `FORGERY BY BOB` after — authorship withholding and publication in one contrast.
- **The soak's 19 good blocks** — E31, E33, E41 among them. **Do not re-run E22–E48.**
- **Wave Q** (Q1/133 deployed 2026-08-28T02:40–02:41Z; Q3), **Wave P** (eleven items), **Wave O's six**, **Issues 96–105**, **50–95**, **31**, **28/29**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206, not 207.** Deleting `_lastReactionSentTime` removed the `prefer_final_fields` info attached to it. Bar is **206 and no new infos**.
- **E48 merged two specified artefacts into one.** One post-close shot from a non-host device with the host confirmed terminated satisfies both "(b) after close" and "(c) host absent", and is stronger than two shots.
- **R0 leaves `..repeat()` in `initState`.** `didChangeDependencies` always runs before the first frame.
- **R1/R2 design-doc entries landed in the final Wave R commit** rather than each item's own. Content landed and is accurate.
- **~~`auto_advance_timer.dart:90` reading `accessibleNavigation` directly is a harmless style inconsistency.~~ WITHDRAWN** — Issue 141 shows it is the same behavioural bug. **U2 fixes it.**
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 10. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** U5 deletes them with admin credentials, which bypass rules — **do not add match blocks to make cleanup easier.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own, and authorship is correctly published *after* the unmask window closes.
- **Never let a client bound exceed the server's.** `castVote` and `closeUnmaskWindow` are the models.
- **The presence window gates the ACTION, not the caller.** U3 gates the *trigger* to the host for efficiency; **it must not change what the server enforces.**
- **`pendingScoreDeltas` is flushed at three sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`.
- **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and **caps every match at three departures**.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130).
- **`lastReaction` / `lastReactionAt` in `player_state.dart` are deliberately retained dead fields** from the reaction feature removed in Issue 74. Dropping them needs a rules deploy and a data migration. **Leave them.**
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit. `functions/src/prompt_decks.ts` is the source of truth; **no file outside the catalogue may branch on a deck id.**

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak to recover three blocks (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles rather than removing the layer (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); **renaming Issue 138's intent to "VoiceOver" instead of fixing the flag (141 B)**; **a narrow fix inside `AnimatedThinkingBackground` only (141 C)**; **fixing rendering before network for battery (142 B) and doing both at once (142 C)**; **Firestore native TTL plus a leftovers job (143 B)**; **manual cleanup scripts (143 C)**.

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 11. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Block titles + specified assertions (R6's source of truth) | `docs/playthrough_manifest.md` |
| Screenshot hand-off record | `docs/playthrough_evidence/ARTEFACTS.tsv` |
| Five-player soak report | `docs/playthrough_findings_5player.md` |
| Earlier playthrough evidence | `docs/playthrough_findings_marionette.md`, `…_web.md` |
| Rules, seat tokens, presence, **heartbeat cadence**, **retention**, callables, deploy verification | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, header sizing, dealt-card growth, **which signal means "reduce motion"** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 12. Validation standard

**Enumerate every invocation of anything you change.** A rule added to a shared checker runs against every file that checker can be pointed at. S2's R6 was correct for its own report and broke three others.

**When the spec records a *con* for the option you are implementing, that con is a required test case.** 140 A's con was "false failures"; the test *"run the gate against an ungoverned report"* should have existed before the code did.

**Determine, then implement.** U2's §3.2 exists because the evidence proved the current flag wrong without proving which replacement is right. When a spec says "find out X first", finding out is the deliverable.

**Check the layer, not the symbol.** `AppMotion.reduce()` has a correct name, 38 call sites and a green suite — and reads the wrong platform bit.

**A test that injects the value it is testing proves the branch, not the wiring.** R0's tests set `accessibleNavigation: true` by hand; nothing established a real user could make it true.

**Open the artefact and ask what it shows.** R5 proves a path resolves; R6 proves a block still claims the right assertion. **Neither proves the claim is true.**

**Falsify every guard**, and when you *repair* a guard, re-run its original falsifications to prove you did not weaken it.

**Prefer the countable win.** U3 was chosen over the rendering work because writes/min and invocations/hour can be asserted in a test, while battery drain currently cannot be measured at all here.

**A mechanical check must assert it matched something** — and **state what it does not prove.**

**Read exit codes bare.**

---

## THE LOOP

```
(1) STUDY the item here + its issue text in ongoing_general_errors.md + the
    files at the cited anchors. RE-GREP every anchor; line numbers drift.
(2) If the spec says "determine X first", DO THAT AND RECORD THE RESULT
    before writing the fix.
(3) If the item is a playthrough: read docs/playthrough_manifest.md FIRST,
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
(9) BLOCKED, or a decision is needed? STOP. File it with options, Pros/Cons,
    one (recommended), and a blank `Your selection: _____`.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**After U4, stop and report.** U5 runs only on an explicit go-ahead from the user (§7, §8). Do not invent work.
