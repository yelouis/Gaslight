# Agent Execution Guide — Queue Complete: All Issues Delivered & Deployed (Issues 50–56) — August 10, 2026


**You are an engineering agent with no memory of this project.** Issues 51, 52, 53 and 54 are implemented and verified in source (§8) — **do not rework them.** They are also **not reaching users**, because the backend was never deployed. Your queue closes that gap, cleans up the migration boundary it created, and finishes three defects that shipped inside Issue 50.

**Every number, literal string and field name here is a decision, not a suggestion.** Copy quoted strings verbatim. If a value proves impossible, keep the intent, deviate minimally, and say so in the commit body. **If the design itself cannot work, STOP** and file it in `ongoing_general_errors.md` with options and a `Your selection: _____` line — never choose on the user's behalf.

All three items were selected by the user on August 10, 2026: **Issue 55 → Option A**, **Issue 56 → Option A**, **Issue 50 → Option A**.

> ⚠️ **§3 and §4 touch production.** They are the only items in this guide that do. Run the preflight gates as written; do not improvise a deploy.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`. No raw hex in widget code, no ad-hoc `Duration`.
3. **Every animation needs an `AppMotion.reduce(context)` path — a static frame, never a faster animation.** §5 exists because this was not honoured.
4. **Text scale clamped 1.0–1.3.** **Touch targets ≥ 48 dp.**
5. **Server-authoritative.** Clients read Firestore streams and write nothing to room documents. `lastSeen` is the only sanctioned client write; `expiresAt` is server-owned.
6. **Never commit a credential.** §4 requires Application Default Credentials, not a key file — and `.gitignore` does not currently protect you from the latter. See §4.
7. **One item = one commit**, Conventional Commits, WHY in the body. §5 is its own commit; §6 and §7 may share one.

---

## 1. Verified baseline — the regression bar

Measured at commit `56c183a`, clean tree. **No change may lower any of these.**

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** (270 infos/warnings, pre-existing) |
| Client tests | `flutter test` | **117/117** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **36/36** |
| Firestore TTL policies | `gcloud firestore fields ttls list` | **2 × ACTIVE** (`rooms`, `players`), applied August 10, 2026 |
| iOS release build | `flutter build ios --release --no-codesign` | ⚠️ not re-run since `56c183a`, where it measured 49.5 MB. Re-measure before quoting. |
| **Production deployment** | `gcloud functions list` | 🔴 **All 14 functions last updated `2026-08-07T05:20`.** This wave is not live. §3 fixes it. |

**`gcloud` is not on this shell's `PATH`** — the same quirk that makes `functions/package.json` prepend `/opt/homebrew/bin`. It is installed at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`; invoke it by absolute path. Authenticated as `chengluye@gmail.com`.

### ⚠️ Eight traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, **never bare `flutter analyze`** — the bare form walks gitignored vendored plugin source and reports ~678 phantom errors.
2. **Analyze ≠ compile.** Only `flutter test` or `flutter build` surfaces a broken dependency.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions run build`.
4. **BSD `sed` does not support `\b`** — silently matches nothing and exits 0. Use `python3`.
5. **`Image.asset` loads no bytes under `flutter test`**, and a wrong icon codepoint renders as an empty box. Neither is visible to any widget test. Verify on a simulator.
6. **`test/fake_functions.dart` does not enforce `firestore.rules`.** Security- or multiplayer-critical behaviour must be proven in `functions/test/` or on real clients.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation`.** Nine widgets in the lobby tree drive `AnimationController.repeat()`. Wrap the screen under test in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)` — `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`). Separately, **never `await` a fake callable directly inside `testWidgets`**; those bodies run under `FakeAsync` and deadlock — wrap in `tester.runAsync`. `pumpAndSettle()` is **not** the culprit and is **not** banned. ⚠️ Because every lobby test sets this flag, `AppMotion.reduce` is `true` throughout the suite — which is exactly the branch §5's bug lives on.
8. **🆕 `firebase.json` has NO `predeploy` hook.** Verified August 10, 2026. `firebase deploy --only functions` therefore uploads **whatever is already sitting in `functions/lib/`** — and `functions/lib/` is gitignored, so on a fresh clone it does not exist at all. **Deploying without building first ships stale or empty JavaScript, and the CLI still reports success.** §3 both works around this and fixes it permanently.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| 1 | **§3 — Issue 55: deploy functions + rules** | Closes a bug that is live for users **right now** and has a verified reproduction. Everything else in this wave is invisible until it lands. |
| 2 | **§4 — Issue 56: backfill `expiresAt`** | **Must follow §3.** The backfill sets expiry on legacy documents; if the functions are not yet live, nothing refreshes those timestamps, and a legacy room still in use would be deleted out from under its players. After §3, any live room refreshes itself on its next write. |
| 3 | **§5 — Issue 50 defect 1: reduce-motion path** | Client-only and independent of §3/§4. Own commit. |
| 4 | **§6 / §7 — Issue 50 defects 2 and 3** | §5 rewrites the dialog's presentation and §6 edits the confirm handler inside it; doing §6 first guarantees a conflict with yourself. |
| 5 | **§8 — the `depart` glyph** | Blocking, and satisfiable only by looking at a simulator. |

---

## 3. Issue 55 — deploy the backend (Option A)

**What this means for the user:** today, a host who leaves a lobby still strands everyone in a room that can never start — the failure reproduced in room `KVOH`. The fix has existed, tested and committed, since August 9 and has never run for a single user.

### The gap

All 14 production functions were last updated `2026-08-07T05:20 UTC`. `5bb9d2c` (Issue 51's `handleDisconnect` phase gate, committed 2026-08-09 18:08) and `f2d89f3` (Issue 53's `expiresAt` writes, 19:30) have never shipped. `firestore.rules` deploys on a separate track and must be assumed stale too. Consequently the TTL policies enabled under Issue 54 are `ACTIVE` and delete nothing, because production never writes the field they key on.

### Implementation

**Step 1 — fix the predeploy gap first, in its own commit.** `firebase.json`'s `functions` entry has no `predeploy`, which is what makes a stale-code deploy possible. Add the standard hook so the build can never be skipped again:

```json
"predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
```

Commit this **before** deploying. It converts a manual discipline into an enforced one, and it is the durable fix for trap 8.

**Step 2 — preflight. Every one of these must pass before you deploy.**

1. `git status` is clean and you are on the commit you intend to ship.
2. The full §1 battery is green — including `npm --prefix functions test` at **36/36**, which is the only evidence the backend behaves.
3. `npm --prefix functions run build` completes clean. Do this even after step 1; a green predeploy hook you have never watched run is not evidence.
4. Confirm the target: `.firebaserc` sets `gaslight-46368` as default. **Pass `--project` explicitly anyway.**

**Step 3 — deploy.**

```bash
npm --prefix functions run build && npx firebase-tools deploy --only functions,firestore:rules --project gaslight-46368
```

`firebase-tools` is invoked through `npx` by repo convention (see `functions/package.json`). `engines.node` is `22`, which pins the **deployed runtime**; the local Node is v26.5.0 and the CLI may warn about the mismatch — that warning is about your machine, not the deploy target, and is expected.

### Validation — prove behaviour, not that a command exited 0

**Check 1 — the code actually moved.** This is the falsifying check.

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,state,updateTime)"
```

**Before:** every row reads `2026-08-07T05:20`. **After:** all 14 must read today. Any row still showing August 7 means that function did not ship — paste the before and after tables into the Resolved entry.

**Check 2 — production writes `expiresAt`.** Create a room from a real client pointed at production (`USE_EMULATOR=false`), then inspect it in the Firebase console. The **room document and the host's player document** must each carry an `expiresAt` timestamp roughly 8 hours ahead. **Falsifying before deploy:** the field is absent entirely. This is the only check that proves Issue 53 is live — `npm --prefix functions test` passes either way and always has.

**Check 3 — the Issue 51 fix is live.** Three simulators against production (§9): host creates, two clients join, host leaves. Both non-hosts must be evicted showing **"The host has left. This room has closed."** Run this **before** deploying too, and record both outcomes — before, it reproduces the original bug with the room persisting and the others stranded. A before/after pair on a real device is the strongest evidence this build can produce.

**Check 4 — rules shipped.** From a production client, attempt a write of `expiresAt` to your own player document and confirm it is **denied**, while a `lastSeen`-only write still succeeds. Alternatively confirm the rules version timestamp in the Firebase console reads today.

### Rollback

`functions:delete` is not a rollback. To revert, redeploy the previous source:

```bash
git checkout 185b961 -- functions/src && npm --prefix functions run build && npx firebase-tools deploy --only functions --project gaslight-46368
```

**Understand what that costs:** `185b961` is the August 7 code, which contains the Issue 51 bug. Rolling back reinstates a known user-facing failure — prefer fixing forward unless the new build is worse than a stranded lobby.

### Blast radius

`firebase.json` (step 1, its own commit) · no other repo files change. Record the deploy in `ongoing_general_errors.md` Issue 55 with the before/after `gcloud functions list` output and the before/after simulator result.

---

## 4. Issue 56 — backfill `expiresAt` on legacy documents (Option A)

**What this means for the user:** invisible. It clears the rooms created before the TTL field existed, which are otherwise undeletable forever and squat a 4-letter code space.

### The gap

Firestore TTL acts only on documents where the designated field **exists and holds a timestamp**. Documents missing it are ignored permanently — not treated as expired. Every room and player document created before §3's deploy is therefore exempt with no automatic path to removal. Room `KVOH` is the known example; the true count is unknown until you query.

### ⚠️ Ordering and credentials — read before writing any code

**This must run only after §3 is verified live.** Before the deploy, nothing refreshes an `expiresAt` you write, so a legacy room still in use would be deleted out from under its players. After the deploy, any live room refreshes itself on its next write.

**Use Application Default Credentials. Do not download a service-account key.**

```bash
gcloud auth application-default login
```

`firebase-admin` picks this up through `applicationDefault()`.

> 🔴 **`.gitignore` will not protect you here.** Verified August 10, 2026: it covers `google-services.json`, `GoogleService-Info.plist` and `web_config.txt`, and has **no rule matching an Admin SDK key** — `serviceAccount*.json`, `*-adminsdk-*.json`, `*.pem` are all uncovered. A downloaded key would sit untracked-but-not-ignored, one `git add .` away from being committed to a repo whose history is permanent. **Add these three patterns to `.gitignore` in the same commit**, whether or not you use a key:
> ```
> *serviceAccount*.json
> *-adminsdk-*.json
> *.pem
> ```

### Implementation

Write `scripts/backfill_expires_at.js`. **Commit it** — `scripts/` is the project's record of what was actually run, and a one-time migration with no artefact is unauditable.

Resolve `firebase-admin` from the functions install rather than adding a root dependency:

```bash
NODE_PATH="$(pwd)/functions/node_modules" node scripts/backfill_expires_at.js --dry-run
```

Seven requirements:

1. **`--dry-run` is the default and `--apply` is explicit.** Running the script with no flags must change nothing. Print the counts and stop.
2. **Only write where the field is absent.** `if (data.expiresAt !== undefined) → skip`. Never overwrite a live room's expiry.
3. **Cover both levels.** `db.collection('rooms')` for room documents **and** `db.collectionGroup('players')` for every player document. This is the same two-level trap the TTL policies have, and it is the single most likely way this job is done wrong.
4. **Skip rooms that might still be in use.** A room is eligible only if it has **no player whose `lastSeen` falls within the last 24 hours** (rooms with no players at all are eligible). Do not rely on the room document alone — it carries no creation timestamp.
5. **Set the expiry to `Date.now() + 60 * 60 * 1000` (1 hour), not 8.** These are known-dead documents; an 8-hour value delays the cleanup for no benefit. Write an `admin.firestore.Timestamp`, not a number — TTL ignores a field that is not a timestamp, which would make the whole run a silent no-op.
6. **Batch under the 500-operation limit.** Chunk at 400 writes per `WriteBatch` and commit sequentially.
7. **Idempotent.** A second `--apply` run must report zero changes.

### Validation

- **Before:** `--dry-run` and record the count of room documents and player documents lacking `expiresAt`. This number goes in the Resolved entry.
- **After `--apply`:** re-run `--dry-run`. It must report **0 remaining at both levels**. **This is the falsifying assertion** — a non-zero player count with a zero room count is precisely the collection-group mistake requirement 3 exists to prevent, and it looks like success if you only check rooms.
- **Over-reach guard:** the script must print, and you must record, how many documents it **skipped** for a recent `lastSeen` and how many already had `expiresAt`. A run that skipped nothing on a live database means requirement 4 is not wired up.
- **Do not wall-clock the deletion.** TTL is best-effort and may lag by up to 24 hours; the policy's correctness was established under Issue 54. Verify the field is set, not that documents vanished.

### Blast radius

`scripts/backfill_expires_at.js` (new, committed) · `.gitignore` (the three key patterns) · `docs/design_database_and_security.md` §6 — record that this was a one-time migration boundary and that a fresh project never needs it.

---

## 5. Issue 50 defect 1 — give the dialog a real reduce-motion path (Option A)

**What this means for the user:** someone with reduced motion enabled currently gets a dialog that still animates *and* can no longer be dismissed by tapping outside. They pay the cost of the accommodation and get none of the benefit.

### The gap

`lib/screens/lobby_screen.dart:49` computes `final reduceMotion = AppMotion.reduce(context);` and spends it at line 53 on `barrierDismissible: !reduceMotion`. Dismissibility and motion are unrelated concerns. Two failures at once: reduce-motion users **lose** barrier dismissal, and no transition duration is suppressed anywhere — `showDialog` always inserts its own `FadeTransition`, so the dialog animates identically in both modes.

### Implementation

Replace `showDialog(...)` with `showGeneralDialog<void>(...)`:

```dart
void _confirmLeave(BuildContext context, GameService gs, bool isHost) {
  if (_isLeaving) return;
  final bool reduce = AppMotion.reduce(context);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,                                   // unconditional
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,                               // showDialog's default
    transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 150),
    pageBuilder: (ctx, animation, secondaryAnimation) =>
        _buildLeaveDialog(ctx, gs, isHost),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      if (reduce) return child;                                 // static, not faster
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
```

Five things that bite if skipped:

1. **`barrierLabel` is mandatory.** `showGeneralDialog` asserts when `barrierDismissible: true` and the label is null. Use `MaterialLocalizations.of(context).modalBarrierDismissLabel` — do not invent a string; it is read by screen readers and is already localised.
2. **`barrierColor` must be supplied.** `showGeneralDialog` defaults to no scrim; without `Colors.black54` the dialog floats over an unshaded lobby and looks like a rendering bug. `showDialog` supplied this for you.
3. **Under reduce, return `child` unchanged.** Do not wrap it in a `FadeTransition` driven by a zero-duration animation — that leaves an animation widget in the tree and makes the validation below ambiguous.
4. **Move the existing `AlertDialog` verbatim into `_buildLeaveDialog(BuildContext ctx, GameService gs, bool isHost)`.** Cut and paste; do not retype. Every copy string, style, `minimumSize` and `isHost` ternary must be byte-identical, or the existing copy assertions break and you will be tempted to edit the test instead of the regression.
5. **Do not add a `Center`.** `AlertDialog` builds a `Dialog`, which aligns and constrains itself. A `SafeArea` is the only wrapper worth considering, for parity with `showDialog`.

`useRootNavigator` defaults to `true` on both APIs, so navigation behaviour is unchanged.

### Validation

Both assertions fail against the current code. **Run them before fixing and record the output.**

**Test A — `"reduce-motion users can still dismiss by tapping outside"`.** Standard harness (`accessibleNavigation: true`, so `reduce` is `true`): open the dialog, `await tester.tapAt(const Offset(10, 10));`, pump, assert `find.text('Leave this room?')` finds nothing. **Falsifying:** today `barrierDismissible` evaluates to `!true == false`, the barrier swallows the tap, and the dialog stays.

**Test B — `"no transition widget is inserted under reduced motion"`.** Same harness:

```dart
expect(
  find.ancestor(
    of: find.text('Leave this room?'),
    matching: find.byType(FadeTransition),
  ),
  findsNothing,
);
```

**Falsifying:** `showDialog` routes through `DialogRoute`, whose transition builder always inserts a `FadeTransition`, so one is present today even with reduce on. **Scope the finder with `find.ancestor` exactly as written** — a bare `find.byType(FadeTransition)` matches unrelated transitions elsewhere in the app and would pass for the wrong reason, making it this project's fourth check-that-cannot-fail.

**Over-reach guard — `"the dialog still animates when reduced motion is off"`.** Pump the lobby **without** `accessibleNavigation: true`; in that configuration the lobby's repeating animations are live, so use `pump()` + `pump(const Duration(milliseconds: 150))` rather than `pumpAndSettle()` (trap 7). Assert the same scoped `find.ancestor` **finds one widget**. This stops a later agent simplifying the transition away for everyone.

**Second over-reach guard:** every existing test in `test/lobby_leave_test.dart` passes **unedited**. If you had to change a copy assertion, you changed a string you were told to paste.

### Blast radius

`lib/screens/lobby_screen.dart` · `test/lobby_leave_test.dart` · `docs/design_ui_direction.md` — record that the leave dialog uses `showGeneralDialog` with a reduce-gated transition, so the next audit does not read it as an inconsistency.

---

## 6. Issue 50 defect 2 — make the double-tap guard real

**What this means for the user:** two fast taps on confirm can fire `leaveRoom()` twice. The second call fails harmlessly, but the guard meant to stop it does nothing while reading as though it does.

### The gap

`lobby_screen.dart:45` declares `bool _isLeaving = false;`. It is checked at lines 48 and 85, but **only set at line 86 — after `Navigator.of(ctx).pop()` at line 84 has already removed the button** — and reset in a `finally` at line 90. Both checks are unreachable: the outer one cannot be true because a modal dialog covers the `AppBar` button; the inner one cannot be true because the pop is synchronous. The real exposure is two taps landing in the same frame, before the pop is processed.

### Implementation

1. Set the flag **before** `Navigator.of(ctx).pop()`.
2. **Do not reset it in a `finally`** — the screen is being torn down, and a reset re-arms the race the flag exists to prevent.
3. Keep the check at line 48; it is harmless and covers a future non-modal entry point.

Acceptable alternative: capture a plain `bool tapped` in the dialog builder's closure. If you do, **delete `_isLeaving` entirely** rather than leaving a dead field.

### Validation

- `"double-tapping confirm leaves exactly once"` — open the dialog, tap confirm **twice with no pump between the taps**, then pump. Assert `fakeFunctions.callableInvocations['handleDisconnect'] == 1`. **Falsifying:** today this records 2.
- **Over-reach guard:** `"non-host can leave from the lobby"` passes unchanged — a single tap still leaves.

### Blast radius

`lib/screens/lobby_screen.dart` · `test/lobby_leave_test.dart`.

---

## 7. Issue 50 defect 3 — replace the fragile test finder

**What this means for the user:** nothing directly. It protects the guarantee that adding the leave control did not break the sound toggle.

### The gap

`test/lobby_leave_test.dart:112` finds the sound toggle with `find.byType(IconButton).last`. Since Issue 50 added a `leading:` `IconButton` there are now two, and `.last` silently depends on the order Flutter builds `leading:` versus `actions:`. If that order changes, the guard starts asserting against the *leave* button and passes for the wrong reason.

### Implementation

Use a tooltip finder, as the same file already does for the leave control. The sound button's tooltip is `gs.soundEnabled ? 'Mute' : 'Unmute'` (`lobby_screen.dart:471`). Assert the seeded state's tooltip, tap, then assert the **toggled** tooltip — so the finder proves the control flipped rather than merely existing.

### Validation

Temporarily delete the sound toggle from `actions:` and confirm the test goes **red**, then restore it. A finder that cannot fail is not a guard — this project has already shipped two.

### Blast radius

`test/lobby_leave_test.dart`.

---

## 8. The `depart` glyph — the one gate a green suite cannot satisfy

**Status: still unmet.** `0xe674` was committed in `a7f1d19` and has **never been seen rendering.**

The vendored `Phosphor-Light.ttf` has a `post` table at version 3.0, which stores no glyph names, so nothing in this repo can map a name to a codepoint. A cmap presence check is worthless here — the font's cmap spans `0x0020–0xFFFD`, and three unrelated candidate codepoints all tested PRESENT on August 9, 2026. **Presence is not identity.** A wrong codepoint renders a plausible-but-wrong glyph or an empty box, and no widget test in this project can detect either (trap 5).

```bash
flutter build ios --simulator --debug
```

Install on a booted simulator, open a lobby, confirm the leading icon reads as a door / sign-out arrow. If not, try `0xe668`, then source the correct value from upstream Phosphor. **Record what you actually saw.** This box may not be ticked from a green suite.

---

## 9. Running 3 simulators — required by §3 check 3

Bots are server-seeded documents and never exercise the non-host client path.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```

```bash
flutter build ios --simulator --debug
```

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app; xcrun simctl launch "$U" com.whylabs.gaslight; done
```

Must be `--debug`: `lobby_screen.dart` passes `debugEnabled: kDebugMode` and the server refuses debug calls when false. To clear a device's room memory, `xcrun simctl uninstall <UDID> com.whylabs.gaslight` — the room code lives in `SharedPreferences` and survives relaunch. **`USE_EMULATOR` must be `false` in `.env` for §3's production checks**, and `.env` is a bundled asset, so changing it requires a rebuild.

---

## 10. Already delivered — do NOT rework

Verified in source on August 10, 2026 at `56c183a` — read, not inferred from commit messages:

- **Issue 51** (`5bb9d2c`) — branch ordering confirmed correct: `hasCard` at `functions/src/index.ts:741`, the lobby-host close branch at 744 returning at 749, `!hasCard` at 753. **The lobby branch must precede `!hasCard`** — a host in the lobby satisfies both, and reversing them silently reinstates the original bug.
- **Issue 52** (`09ed9a9`) — one `PageView` serves both roles (`deck_carousel.dart:133`); `onDeckSelected` suppressed at 102, stamp pulse at 115; `CHOSEN` badge at 174; `THE CHOSEN FILE` label at 215; 3-second snap-back via `_lastSwipeTime` (36, consulted 83–91). Contract in `design_prompt_system.md` §67–70.
- **Issue 53 code** (`f2d89f3`) — `ROOM_TTL_MS` at `index.ts:14`, `ttlFrom()` at 16, `expiresAt` at ten sites, `'expiresAt'` in the `firestore.rules:28` denylist.
- **Issue 54** — both Firestore TTL policies applied and verified `state: ACTIVE` on `rooms` and `players`. **Do not re-run the enable commands.**
- **Issues 1–49, Tasks T1–T11** — the mascot programme is finished. `POSE_REGISTRY` in `scripts/build_sprite_sheets.py` is the single source of truth for frame geometry; two renderers coexist by design.
- **Issue 31** — the server uses loose `!= null`; **never "simplify" to a falsy check** — `false` and `0` are legitimate values.
- **Issues 28/29** — `phosphor_flutter` can never be used (`IconData` is a `final class`, proven twice); the app vendors the Phosphor Light font.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` · Firebase project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 11. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the observed output in the Resolved entry — Issues 51, 53 and 54 all did, and their entries are the model.

**A test's name is not a test.** A test titled *"…rim contrast >= 4.5:1"* asserted only that a file was non-empty; the mascot shipped at **1.02:1** with a fully green suite.

**A check that cannot fail is not a check.** Three instances: the cmap presence script, `find.byType(IconButton).last`, and a bare `find.byType(FadeTransition)` — which is why §5 specifies `find.ancestor`.

**A green suite is not delivery, and "Resolved" is not "live."** Issues 51 and 53 were green, verified and Resolved while production ran a two-day-old build. **Ask what your gates structurally cannot observe** — §3 and §4 exist entirely inside that blind spot, which is why both are validated against the real environment rather than a test.

**Measure; do not estimate.** A layout overflow estimated at ~275 dp measured **593 dp**.

**Do not tune a threshold to make a test pass.** Report the measured number and say the guard failed.

**Pair every fix assertion with an over-reach guard.**

---

## 12. Accepted equivalents — do NOT "fix" back

- **Leaving a room does not call `Navigator` explicitly.** `lobby_screen.dart` gates the waiting room on `gs.gameState != null && gs.currentPlayer != null` and otherwise falls through to `_buildEntryForm`, so clearing local state re-renders the entry form in place. Same guarantee, different structure — **do not add a redundant `pushReplacement`.** This is also why the `gs.currentPlayer!` deref below it is safe.
- **The non-host carousel is interactive-but-inert, not dimmed.** Elsewhere non-host gating uses `IgnorePointer` + `Opacity(0.5)`; the carousel deliberately departs because its purpose is to be read.
- **`pumpAndSettle()` and `pump()` + `pump(500ms)` are both acceptable** once `accessibleNavigation: true` is set.
- **Craft SUBMIT is in-flow** under the text field; **Vote's CONFIRM** is bottom-anchored via `Expanded`+`SafeArea`.
- **`isSmallHeight` uses a `< 700` dp breakpoint** with a 6/8/12/16/20 spacing scale.

---

## 13. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; `firestore.rules` denies client room writes. `lastSeen` is the only sanctioned client write; `expiresAt` is server-owned.
- **Portrait-locked on phones**; **text scale clamped 1.0–1.3**.
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.**
- **`_familyFriendlyOnly` is client-local and never synced.**
- **`playRavenPose`'s `onceKey` stays required.**
- **`ROOM_TTL_MS` is 8 hours.** No keepalive is needed at that interval. **If it is ever shortened below roughly 4 hours, a host-only `touchRoom` keepalive callable plus a client timer become mandatory** — an idle lobby writes nothing, and a player document's `expiresAt` is never refreshed after join. That design is recorded in `ongoing_general_errors.md` Issue 53.
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C.

---

## 14. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Full history of any resolved item | `git log` |
| Backend writes, rules, identity, disconnect/host handoff, **TTL §6** | `design_database_and_security.md` |
| Card passing, disconnect recalculation, input validation | `design_rotation_engine.md` §5 |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` §4 |
| Palette, typography, icons (**`depart`, §129**), mascot, dialog motion | `design_ui_direction.md` |
| Deck catalogue and **non-host carousel contract §67–70** | `design_prompt_system.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 15. Feedback loop — what past specs got wrong

- **"Resolved" is not "deployed."** Issues 51 and 53 were implemented, tested, verified in source and recorded as Resolved while production ran a two-day-old build. Every gate passed; none could observe a deployment. **A Definition of Done for backend work must include a check against the real environment.**
- **Enabling a thing is not the same as the thing working.** The TTL policies went `ACTIVE` and deleted nothing, because the field they key on was never written in production and legacy documents lack it entirely. **When you turn something on, verify the input it consumes actually exists.**
- **A convenience the tooling normally provides may be absent here.** `firebase.json` has no `predeploy` hook, so the build step every Firebase TypeScript project takes for granted is manual — and skipping it ships stale code with a success message. **Check the config; do not assume the default.**
- **Defects filed before a commit do not fix themselves.** All three Issue 50 defects were written into this guide *before* `a7f1d19` and shipped unchanged, because the tests went green and green read as done.
- **A confident diagnosis can be wrong in the same direction twice.** `pumpAndSettle` was blamed and banned; the real cause was the missing `accessibleNavigation` flag. **Before writing a prohibition into a guide, find the counter-example that would disprove it.**
- **An accommodation implemented against the wrong axis is a regression.** §5's `barrierDismissible: !reduceMotion` reads as accessibility work and takes a capability away from the users it names. **Name the property a flag is supposed to change, and check the implementation changes that property.**
- **Name the state space a rule applies to** ("handle disconnects" did not say *in which phase* — that was Issue 51), and **when specifying a listener, specify the absent case** (`if (snapshot.exists)` with no `else`).

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Copy strings verbatim; paste, do not retype.
(3) VALIDATE per §11. Observe the falsifying assertion fail against the broken state
    before you fix it, and record that output. Run the item's over-reach guard.
    For anything the harness cannot see — deploys, glyphs, art — check the real thing.
    Then the full §1 battery.
(4) BEFORE COMMITTING, re-read this guide's open defect list for the item you are
    finishing. Green tests are not evidence that a filed defect was addressed.
(5) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(6) RECORD: move the issue to Resolved (Problem / Solution / Observed Falsifying
    Output / Over-reach Guard). Sync any design doc whose behaviour changed.
(7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **§3 step 1** — `predeploy` hook added to `firebase.json` and committed **before** the deploy.
- [ ] **§3** — functions and rules deployed; `gcloud functions list` shows **all 14** updated today, with the before/after tables recorded. A single row still reading `2026-08-07` means the item is not done.
- [ ] **§3 check 2** — a room created against production carries `expiresAt` on **both** the room and the host player document, roughly 8 hours ahead.
- [ ] **§3 check 3** — the three-simulator host-leaves test recorded **before and after** the deploy, showing the bug reproducing first and the eviction copy appearing second.
- [ ] **§3 check 4** — a client write of `expiresAt` is denied while a `lastSeen`-only write succeeds.
- [ ] **§4** — `.gitignore` gains the three credential patterns; `scripts/backfill_expires_at.js` committed; `--dry-run` counts recorded before and after, with the after count **0 at both the room and player level**; skip counts recorded.
- [ ] **§4 ordering** — the backfill ran only after §3 was verified live.
- [ ] **§5** — `showGeneralDialog` with unconditional `barrierDismissible`, `barrierLabel` from `MaterialLocalizations`, `barrierColor: Colors.black54`, `transitionDuration` gated on `AppMotion.reduce`. Tests A and B **observed failing first**, output recorded; the reduce-off over-reach guard passes; existing copy assertions pass **unedited**.
- [ ] **§6** — `_isLeaving` set before `Navigator.pop()` and never reset; double-tap test observed recording 2 first, then 1.
- [ ] **§7** — sound-toggle guard uses a tooltip finder, observed going red when the toggle was temporarily removed.
- [ ] **§8 — the `depart` glyph seen rendering on a simulator, with what you saw written down.** This box may not be ticked from a green suite.
- [ ] Full battery at or above the §1 bar: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 117 + new** · functions build clean · `npm --prefix functions test` **36/36**.
- [ ] `flutter build ios --release --no-codesign` re-run and `Runner.app` size measured — 49.5 MB is inherited, not re-verified.
- [ ] Issues 50, 55 and 56 moved to Resolved with observed output; `design_database_and_security.md` §6 records the one-time migration.
- [ ] **Guide rewritten** to `Queue Complete` or the next queue. If the queue is empty: **do not invent work.** The only legitimate triggers are a user-selected issue or a §13 invariant's stated trigger firing.
