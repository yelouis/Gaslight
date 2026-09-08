# Agent Execution Guide — Active Build: Wave Z — the lobby leave button dies after the first leave — September 7, 2026

**You are an engineering agent with no memory of this project.**

**One item, selected. It is a user-facing bug found in the shipped TestFlight build.**

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **Z1** | Reset the `_isLeaving` latch so the leave button keeps working | **152 → A** | client | — |

**No deploy is needed.** Nothing here touches `functions/src`; `./scripts/check_deploy_fresh.sh` must stay at exit 0.

**One item = one commit.**

**Every number, formula and literal string below is a decision, not a suggestion.**

---

## 1. Verified baseline — measured on `4c95dec`

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **274 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **112 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 17 functions |
| all four `check_playthrough_evidence.sh` invocations | **exit 0** |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** Use `lib test`, never bare `flutter analyze`.

**Read every other exit code bare, never through a pipe.**

**Shipped:** TestFlight `1.0.0 (6)`, live in Testing alongside build 5. `pubspec.yaml` is at `1.0.0+6`; **the next upload must be `1.0.0+7` or higher.** Builds 2–4 are expired. **Do not expire build 5 until Z1 ships** — build 6 has the bug this wave fixes, and testers need a fallback.

**Production:** `cleanupDaily` runs `every day 04:00` America/Los_Angeles with `CLEANUP_DRY_RUN=false`. ⚠️ **Revision-scoped — re-apply after any functions redeploy.**

---

## 2. Z1 — Reset the leave latch (152 → A)

**What this means for the user:** leave a room, join another, and the exit button in the top-left stops working — no dialog, no error, nothing. The only way out is force-quitting the app. This was found on the shipped build.

### 2.1 The gap

`lib/screens/lobby_screen.dart` holds a one-way latch:

```dart
bool _isLeaving = false;                       // :43

void _confirmLeave(BuildContext context, GameService gs, bool isHost) {
  if (_isLeaving) return;                      // :49  — silently does nothing
  ...
}

onPressed: () async {                          // the dialog's CLOSE ROOM / LEAVE button
  if (_isLeaving) return;                      // :100
  _isLeaving = true;                           // :101 — set here, and nowhere else
  Navigator.of(ctx).pop();
  await gs.leaveRoom();
},
```

**`grep -n "_isLeaving" lib/screens/lobby_screen.dart` returns exactly four lines — the declaration and three reads/writes. There is no `_isLeaving = false` in the file.**

**Why that outlives the room, which is what turns a sensible guard into a dead button.** `LobbyScreen` renders **both** the entry screen and the in-room parlour from a **single `State`**, as a conditional inside `build` (`:433–449`):

```dart
if (gs.gameState != null && gs.currentPlayer != null) { … THE PARLOR … }
return AnimatedLobbyBackground(child: _buildEntryForm(theme));
```

`LobbyScreen()` is pushed once as a route (`lib/main.dart:120`). Leaving clears `gameState` and re-renders the entry branch — **no route is popped and the `State` is never disposed.** So the latch carries into the next room and every later tap silently returns at `:49`.

**This is not network-dependent.** `gs.leaveRoom()` already wraps its `handleDisconnect` call in `try`/`catch` and swallows failures, so the bug reproduces on a clean, fully successful leave.

### 2.2 Implementation

```dart
onPressed: () async {
  if (_isLeaving) return;
  _isLeaving = true;
  Navigator.of(ctx).pop();
  try {
    await gs.leaveRoom();
  } finally {
    if (mounted) _isLeaving = false;
  }
},
```

Five things to get right:

1. **⚠️ It must be a `finally`, not an assignment after the `await`.** `leaveRoom()` swallows its own callable errors, but it then awaits `_clearLocalRoomState()`, which touches `SharedPreferences` and *can* throw. A trailing assignment would be skipped on that path and the button would stay dead — **reproducing this exact bug by a rarer route, which is the worst possible outcome for a fix.**
2. **⚠️ Do NOT wrap the reset in `setState`.** `_isLeaving` is read only in the two tap handlers (`:49`, `:100`) and appears **nowhere in `build`** — confirm with `grep` before assuming. A `setState` would force a pointless rebuild, and doing so from a `finally` after an async gap invites a rebuild at an awkward lifecycle moment. A plain field assignment is correct here.
3. **`if (mounted)` is belt-and-braces, not load-bearing.** Because there is no `setState`, writing a field on a disposed `State` is harmless. Keep the guard for convention; **do not treat its absence in review as a defect**, and do not add `setState` to "justify" it.
4. **Do not touch the guard at `:49`.** That is what stops the dialog being reopened while a leave is in flight, and it is still wanted.
5. **Do not change `gs.leaveRoom()`.** Its internal `try`/`catch` is deliberate and out of scope.

### 2.3 Validation

**The construction of the falsifying test *is* the item.** A carelessly written version passes against the broken code and proves nothing.

1. **The falsifying test — leave two rooms in a row from the same screen.** Add to `test/lobby_leave_test.dart`, reusing the existing `pumpLobbyScreen` helper for the *first* room only:

   ⚠️ **After the first leave, do NOT call `pumpLobbyScreen` or `pumpWidget` again.** The bug exists precisely because the `State` survives; re-pumping risks constructing a fresh `State`, and the test would then pass against unfixed code — a worthless test that looks like coverage. Drive the second room through `gameService` inside `tester.runAsync(...)`, then `await tester.pumpAndSettle()`.

   Sequence:
   - `await pumpLobbyScreen(tester, isHost: true);`
   - tap `find.byTooltip('Leave room')`, settle, assert `find.text('CLOSE ROOM')` is present, tap it, settle.
   - **Assert the entry screen is now showing** (e.g. `find.text('THE GUEST LEDGER')`). This proves the first leave genuinely completed — without it the test could be passing through a half-state and asserting nothing meaningful.
   - Inside `tester.runAsync`: `await gameService.createRoom('Host', 'p_host2'); gameService.stopHeartbeat();` and a short delay, mirroring `pumpLobbyScreen`'s own setup.
   - `await tester.pumpAndSettle();` and assert the parlour is showing again.
   - Tap `find.byTooltip('Leave room')`, settle.
   - **Assert `find.text('CLOSE ROOM')` findsOneWidget.** ← the assertion that fails today.

   **Run it against current code and observe it fail.** Paste the failure into the commit body.

2. **⚠️ Over-reach guard — the double-tap protection must survive.** `test/lobby_leave_test.dart:194` (*"double-tapping confirm leaves exactly once"*) must still pass **unchanged, with no edits to that test**. It is the reason the latch exists. **If it breaks, the reset was placed wrongly** — almost certainly before the `await` rather than in the `finally`.

3. **Over-reach guard — reopening mid-leave is still blocked.** While `leaveRoom()` is in flight, tapping the leave icon must **not** open a second dialog. `FakeFirebaseFunctions.overrideCallable` (`test/fake_functions.dart`) lets you hold `handleDisconnect` open with a `Completer`: register a handler that awaits the completer, tap through the leave, assert no dialog appears on a second tap, then complete it and assert a subsequent tap **does** open the dialog. That last step is what proves the reset fires on the real path rather than only on an error path.

4. **Falsify the fix itself.** Remove the `finally` (or move the reset above the `await`) and confirm test 1 fails again. A reset whose test passes either way is decoration.

5. **Full battery:** `flutter test` **≥ 274 + the new tests**; analyze still **0 errors, 0 warnings, 206 infos**; functions **112**; decks exit 0; all four evidence gates exit 0; deploy exit 0.

**Blast radius:** `lib/screens/lobby_screen.dart` · `test/lobby_leave_test.dart`. **No design-doc change** — this is a defect in an existing behaviour, not a change to a contract.

---

## 3. Definition of Done

- [ ] Falsifying two-room test written **without re-pumping the widget**, observed to fail first, failure pasted into the commit body.
- [ ] The intermediate assertion (entry screen visible after the first leave) is present.
- [ ] Reset is in a **`finally`**, not after the `await`.
- [ ] **No `setState`** around the reset; `_isLeaving` still appears nowhere in `build`.
- [ ] `:49`'s guard and `gs.leaveRoom()` unchanged.
- [ ] **`double-tapping confirm leaves exactly once` still passes, unedited.**
- [ ] Mid-leave reopen still blocked, and a tap **after** completion opens the dialog.
- [ ] Fix falsified by removing the `finally`.
- [ ] Battery: **0 errors · 0 warnings · 206 infos** · `flutter test` ≥ 274 + new · functions **112** · all gates exit 0.
- [ ] Issue **152** moved into the **single** existing Resolved heading.

---

## 4. Already delivered — do NOT rework

- **Y1 (151)** title-screen version label, read from the bundle at runtime during `main()`'s bootstrap. **It worked the first time it was needed** — it is what let a "missing feature" report be resolved as a build-version artefact (Issue 150).
- **Y2 (149)** R5 now checks cited evidence paths **anywhere in a block, including `NOT RUN` blocks**, while never requiring one.
- **Issue 150 — CLOSED with no code change.** The deck `PEEK INSIDE` affordance ships, renders, and is legible on build 6. **Do not "improve" it without a new selection.**
- **X1 (147)** `EmberBackdrop` ticker guarded — **the `pumpAndSettle` trap is closed**; all fifteen `.repeat(` call sites in `lib/` are guarded · **X2 (148)** E9 annotated as superseded by E31.
- **W1 (146)** post-commit `recursiveDelete` on lobby close, sweep capped with the **scan** bounded · **W2 (145)** live deletion enabled; the dry run predicted the live run exactly.
- **V1 (143, 144)** deployed environment verified; **24-hour retention settled** with its `ROOM_TTL_MS` coupling invariant.
- **U1 (140)** manifest scoping + R6 · **U2 (141)** real `reduceMotion` bit, device-verified · **U3 (142)** 30 s heartbeat, host-gated disconnects · **U4 (135)** E49 PASS — **first device verification of Issue 123**.
- **S1 (139)** · **E47/E48** · **R0 (138)** · **R1 (136)** · **R2 (137)** · soak blocks **E22–E49** · **Wave Q** · **Wave P** · **Wave O's six** · **Issues 96–105, 50–95, 31, 28/29**.
- **The playthrough reorganisation** — everything under `docs/playthroughs/`.
- **The release runbook** — `README.md` → **Releasing**. ⚠️ **`flutter build ipa` fails at export on this machine** (no Apple Distribution certificate) and that is expected — the `.xcarchive` is still produced, and Organizer distributes it. **Verify the archive's timestamp and `CFBundleVersion`, never the `.ipa`.**

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206.** Bar is **206 and no new infos**.
- **Y1 bumped `pubspec.yaml` to `1.0.0+6`** inside its own commit rather than at release time. Build 6 is uploaded; the next must be `+7`.
- **`EmberBackdrop` and `AnimatedThinkingBackground` both keep `..repeat()` in `initState`.**
- **E48 merged two specified artefacts into one.**
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`.**
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 5. Invariants & intentional decisions — do NOT change

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

## 6. Where the contracts live

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

## 7. Validation standard

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

**After Z1, the queue is empty. Do not invent work.**
