# Agent Execution Guide — Build Complete: Lobby Lifecycle (Issues 50–53) — August 10, 2026


**You are an engineering agent with no memory of this project.** Everything approved is below. Four issues are queued, all four already selected by the user — the rejected options are recorded in `docs/ongoing_general_errors.md` §1, and re-litigating them is wasted work.

**Every number, literal string and field name here is a decision, not a suggestion.** Implement them as written; copy quoted strings verbatim including punctuation and capitalisation. If a value proves impossible, keep the intent, deviate minimally, and say so in the commit body. **If the design itself cannot work, STOP** and file it in `ongoing_general_errors.md` with options and a `Your selection: _____` line — never choose on the user's behalf.

**Do not touch anything in §10–§12.** Those are delivered work, accepted equivalents, and standing invariants.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`. No raw hex in widget code, no ad-hoc `Duration`.
3. **Every animation needs an `AppMotion.reduce(context)` path** — a static frame, never a faster animation.
4. **Text scale clamped 1.0–1.3.** **Touch targets ≥ 48 dp.**
5. **Scope by item.** Issues 51 and 53 change `functions/` and `firestore.rules`. **Issues 50 and 52 are client-only — if you are editing `functions/` while implementing them, you have left the spec. STOP.**
6. **Server-authoritative, always.** Clients read Firestore streams and write nothing to room documents. The **single** sanctioned client write is a player's own `lastSeen` heartbeat on their own player document. `expiresAt` is server-owned (§6). Every other mutation goes through a callable that validates `context.auth.uid`.
7. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

Run in this session at commit `185b961`, clean tree. **No change may lower any of these numbers.**

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** (270 infos/warnings, all pre-existing) |
| Client tests | `flutter test` | **106/106** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **31/31** (7 s, boots its own emulators) |
| iOS simulator build | `flutter build ios --simulator --debug` | succeeds (34.7 s) |
| iOS release build | `flutter build ios --release --no-codesign` | succeeds (`Runner.app` size **49.5 MB**) |

### ⚠️ Seven traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, **never bare `flutter analyze`** — the bare form walks `build/ios/SourcePackages` and reports ~678 phantom errors from vendored plugin source under gitignored `build/`. This has misled in both directions.
2. **Analyze ≠ compile.** Only `flutter test` or `flutter build` surfaces a broken dependency. A package resolving proves nothing.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions run build`.
4. **BSD `sed` does not support `\b`** — silently matches nothing and exits 0. Use `python3`.
5. **`Image.asset` loads no bytes under `flutter test`**, and a wrong icon codepoint renders as an empty tofu box. Neither is visible to any widget test. Verify on a simulator.
6. **`test/fake_functions.dart` does not enforce `firestore.rules`.** Non-host writes and `authUid` checks are never really exercised there, and bots are server-seeded documents that never touch the client path. Anything security- or multiplayer-critical must be proven in `functions/test/` or on real simulator clients.
7. **`tester.pumpAndSettle()` NEVER RETURNS on any screen in this app.** Nine widgets in the lobby tree alone drive `AnimationController.repeat()` — `raven_mascot`, `lobby_background`, `lamp_loading`, `lobby_logo`, `shared_ui`, `waiting_indicator`, `player_avatar`, `thinking_background`, `auto_advance_timer`. `pumpAndSettle` waits for the frame scheduler to go idle, which never happens, so it spins until its own 10-minute timeout. **Every existing lobby-family test uses this idiom instead, and no test in this repo uses `pumpAndSettle`:**

   ```dart
   await tester.pump();
   await tester.pump(const Duration(milliseconds: 500));
   ```

   Two companion rules travel with it, and all three are needed together — fixing only the pump still hangs (measured):

   - **Wrap the screen in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)`.** `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`), so this is the switch that puts every animation on its static path. Eleven test files already do it.
   - **Never `await` a fake callable inside `testWidgets`.** `testWidgets` bodies run under `FakeAsync`; awaiting `gameService.createRoom(...)` or `Future.delayed(Duration.zero)` deadlocks because no `pump()` can advance fake time while the await is outstanding. Seed `FakeFirestore` directly, then escape the zone once with `await tester.runAsync(() async { await Future.delayed(const Duration(milliseconds: 100)); });`.

   Cost so far: one full cycle. `test/lobby_leave_test.dart` hung for **6 m 06 s** without completing a single test, reporting only `did not complete` — which reads like a logic bug and is not one. Precedent to copy: **`lobby_parlor_sheet_test.dart:25–74`**, plus `lobby_entry_test.dart:42` and `house_rules_panel_test.dart:83`.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| 1 | ✅ **Issue 51** — host exit closes the lobby | **DELIVERED** in `5bb9d2c`, with `functions/test/game_e2e.spec.ts` and `test/room_closed_test.dart`. Do not rework it. |
| 2 | 🔧 **Issue 50** — leave control in the lobby | **IN FLIGHT, uncommitted, blocked on a test-harness trap — see §4's IN FLIGHT block first.** Depends on 51: the host dialog promises "will close the room for everyone", true only once 51 ships. |
| 3 | **Issue 52** — browsable read-only deck carousel | Client-only, dependency-free, lowest risk. Third so it does not delay the two correctness fixes. |
| 4 | **Issue 53** — 8-hour TTL on abandoned rooms | Last because 51 removes the common source of orphaned rooms, so the residual volume this must handle is only knowable once 51 has landed. Backend-and-rules only, and it blocks nothing else. |

---

## 3. Issue 51 — a host who leaves the lobby must close it

**What this means for the user:** today, when the host leaves a lobby, everyone still in it is trapped in a room that can never start and can never be left.

### The gap

- **`functions/src/index.ts:725–730`.** `handleDisconnect` computes `hasCard` and, when false, deletes the player document and **returns at line 729 — before the host-transfer block at lines 829–841 ever runs.**
- **`index.ts:91`** initialises `cards: []`; **`index.ts:391`** is the first write that populates it, inside `startGame`. So throughout `currentPhase == "lobby"`, `hasCard` is false for **every** player, and the early return is always taken.
- The room cannot self-heal: **`index.ts:186`** sets `isHost: false` for every joiner, and **`index.ts:239`** rejects `startGame` from a non-host.
- **`lib/services/game_service.dart:302–307`.** The room snapshot listener is `if (snapshot.exists) { … }` with **no `else`**. When the room document is deleted the client silently keeps its last `_gameState` forever. **Closing the room server-side evicts nobody until this is fixed** — this is the half that is easy to miss.

### Implementation — backend

**`functions/src/index.ts`, inside `handleDisconnect`'s transaction.**

**Step 1.** Move `const phase = room.currentPhase;` (currently line 752) to immediately after `const disconnectedPlayer = …` (line 718), i.e. **above** the `hasCard` computation.

**Step 2.** Replace lines 725–730 with this three-way branch, in exactly this order:

```ts
const hasCard = room.cards.some(c => c.targetPlayerId === disconnectedPlayerId);

// 1. Host leaves the lobby -> close the room entirely.
if (disconnectedPlayer?.isHost === true && phase === "lobby") {
  for (const doc of playersSnap.docs) {
    transaction.delete(doc.ref);          // playersSnap was read at line 715 — no new read
  }
  transaction.delete(roomRef);
  return { success: true, roomClosed: true };
}

// 2. Already pruned (no card dealt for this player) -> unchanged behaviour.
if (!hasCard) {
  transaction.delete(playerRef);
  return { success: true };
}

// 3. Otherwise fall through to the existing in-game logic, unchanged.
```

**Step 3.** **Leave lines 829–841 exactly as they are.** Host transfer now serves only the in-game case, which is the selected behaviour (Issue 51 Option A).

> **Transaction invariant** (`index.ts:848`): *must never call `transaction.get` — callers complete all reads first.* `playersSnap` is already in hand from line 715, so iterating it adds no read. **Do not add a `.get()` in this branch.**

> **Ordering matters.** Branch 1 must precede branch 2. A host in the lobby satisfies **both** conditions, and if `!hasCard` wins the race you have reimplemented the bug.

### Implementation — client

**`lib/services/game_service.dart`.**

**Step 4.** Extract the teardown currently inline in `leaveRoom()` (lines 262–288) into a private method. It must do exactly what `leaveRoom()` does today, minus the callable:

```dart
Future<void> _clearLocalRoomState() async {
  _roomSubscription?.cancel();
  _playersSubscription?.cancel();
  _heartbeatTimer?.cancel();
  _roomSubscription = null;
  _playersSubscription = null;
  _heartbeatTimer = null;

  _gameState = null;
  _players = [];
  _currentPlayerId = null;
  _advancedStateKeys.clear();

  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('room_code');
  await prefs.remove('player_id');
}
```

`leaveRoom()` then becomes: capture `roomCode`/`playerId` → cancel subscriptions → call `handleDisconnect` → `await _clearLocalRoomState()` → `notifyListeners()`. **Its observable behaviour must not change**; its only current caller is `lib/screens/game_over_screen.dart:289`.

**Step 5.** Add the missing `else` to the room listener at 302–307:

```dart
_roomSubscription = _db.collection('rooms').doc(roomCode).snapshots().listen((snapshot) async {
  if (snapshot.exists) {
    _gameState = GameState.fromMap(snapshot.data()!, snapshot.id);
    notifyListeners();
  } else if (_gameState != null) {
    _roomClosed = true;
    await _clearLocalRoomState();
    notifyListeners();
  }
});
```

**Do not call `handleDisconnect` here.** The room is already gone; the call fails with "Room not found."

The `_gameState != null` guard is load-bearing: without it, the listener's first emission for a room that never existed would fire a spurious eviction.

**Step 6.** Add `bool _roomClosed = false;` with `bool get roomClosed => _roomClosed;`, and set it back to `false` at the top of both the create-room and join-room paths. A stale `true` blocks the next room the player joins.

### Implementation — routing

**`lib/screens/lobby_screen.dart`.**

**Step 7.** When `gs.roomClosed` turns true, route to the entry screen and surface exactly:

> `The host has left. This room has closed.`

**Step 8.** **Gate it with a once-per-event key.** Firestore streams rebuild constantly; a bare `if (gs.roomClosed)` fires the route and the message on every tick, stacking routes. Follow the `_advancedStateKeys` / `_knownPlayerIds` pattern already in this file, and perform the navigation in a post-frame callback so it does not run during build.

### Validation

**Backend — `functions/test/game_e2e.spec.ts`:**

- `"closes the room when the host disconnects in the lobby"` — create a room, join a second client, call `handleDisconnect` for the host while `currentPhase === "lobby"`, then assert **both**:
  - `(await roomRef.get()).exists === false`
  - `(await roomRef.collection("players").get()).empty === true`
  
  **This is the falsifying assertion.** Against today's code the room document survives and the second player's document is still present, so it fails on `exists === false`. **Run it before the fix and record the output** in the Resolved entry.

- `"transfers host instead of closing when the game is in progress"` — **the over-reach guard.** Start a game so `currentPhase !== "lobby"`, disconnect the host, assert the room **still exists** and that exactly one remaining player has `isHost === true`. Must pass both before and after; it proves in-game transfer was not collateral damage.

**Client — `flutter test`, new file `test/room_closed_test.dart`:**

- Seed a room in `FakeFirestore`, attach the service, delete the room document, pump, assert `gameService.gameState == null` **and** `gameService.roomClosed == true`.
- Over-reach guard: assert `leaveRoom()` still performs its full teardown and still invokes `handleDisconnect` exactly once — the refactor in step 4 must not have dropped the callable.

**Manual, three simulators** (neither suite can see this — §1 trap 6): host creates, two clients join, host taps leave. Both non-hosts must land on the entry screen showing the exact copy, within one Firestore round-trip.

### Blast radius — same commit

`functions/src/index.ts` · `lib/services/game_service.dart` · `lib/screens/lobby_screen.dart` · `functions/test/game_e2e.spec.ts` · **`test/fake_functions.dart`** (must mirror the close behaviour or the client test cannot exercise it) · `docs/design_database_and_security.md` §4–§5 (the disconnect/host-handoff contract now has a phase gate).

---

## 4. Issue 50 — a leave control in the lobby

**What this means for the user:** today, joining a room is one-way. The only exits are finishing a whole game or force-quitting the app.

### 🔧 IN FLIGHT — read this before touching anything

An implementation attempt is uncommitted in the working tree: `lib/theme/app_icons.dart` (+5), `lib/screens/lobby_screen.dart` (+72), `docs/design_ui_direction.md`, and a new `test/lobby_leave_test.dart`. **The production code is essentially correct. Do not rewrite it.** Four specific things are wrong, diagnosed 9 Aug 2026.

**BLOCKER — the test hangs; it is not failing on logic. There are three independent causes, and fixing only one leaves it hanging** (measured: swapping just the pump idiom still hung past 7 minutes).

Observed on the current file: **6 m 06 s elapsed, zero tests completed**, all three reporting `did not complete [E]`, and a `TestDeviceException … SIGTERM` that came from the run being killed — not from the app. No assertion ever executed, so **nothing about the assertions is yet known to be right or wrong.**

1. **`await gameService.createRoom(...)` deadlocks inside the fake-async zone.** `testWidgets` runs its body under `FakeAsync`, where timers only fire when fake time advances. Awaiting a fake callable — and the `await Future.delayed(Duration.zero)` calls that follow it — blocks forever because no `pump()` can run while the await is outstanding. The log confirms execution reached `listenToRoom` (`DEBUG HEARTBEAT: started timer for room: TEST, player: p_guest`) and stopped there.
2. **No `MediaQuery(accessibleNavigation: true)`.** `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`). Eleven test files set it, and that is how they quiet the repeating animations. Without it every `.repeat()` controller runs.
3. **`pumpAndSettle()` × 7** — §1 trap 7.

**Do not invent a harness. Copy `lobby_parlor_sheet_test.dart:25–74` — it is the working precedent for pumping `LobbyScreen`.** Its shape:

```dart
Future<void> setupAndPump(WidgetTester tester, {required bool isHost}) async {
  const roomCode = 'TEST';
  // 1. Seed FakeFirestore DIRECTLY. Do not call createRoom() — it deadlocks (cause 1),
  //    and seeding is how you get a non-host without mutating state afterwards.
  final me = PlayerState(id: 'host_user', name: 'Me', isHost: isHost, joinedAt: 100);
  await mockDb.collection('rooms').doc(roomCode).set(
        GameState(roomCode: roomCode, totalPlayers: 1, sabotageAnswersCount: 2).toMap());
  await mockDb.collection('rooms').doc(roomCode).collection('players').doc(me.id).set(me.toMap());

  gameService.listenToRoom(roomCode);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('room_code', roomCode);
  await prefs.setString('player_id', me.id);
  await gameService.tryRejoinSession();

  // 2. Escape the fake-async zone so the fake's futures actually resolve.
  await tester.runAsync(() async {
    await Future.delayed(const Duration(milliseconds: 100));
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<GameService>.value(
      value: gameService,
      child: MaterialApp(
        home: MediaQuery(                                  // 3. quiets every .repeat()
          data: const MediaQueryData(accessibleNavigation: true),
          child: const LobbyScreen(),
        ),
      ),
    ),
  );
  await tester.pump();                                     // 4. never pumpAndSettle
  await tester.pump(const Duration(milliseconds: 500));
}
```

Note a non-host needs **`isHost: false` seeded up front**, not `createRoom` followed by an `update`. Dispose in a `try/finally` around each test body, as the precedent does, rather than in `tearDown`.

**Consequence to expect:** with `accessibleNavigation: true`, `AppMotion.reduce` is `true` in every test, so Defect 1 below means `barrierDismissible` will be `false` throughout the suite. Tapping the buttons still works; tapping the barrier will not.

**Defect 1 — the reduce-motion requirement is not implemented, and an unrelated behaviour was changed instead.** `_confirmLeave` computes `final reduceMotion = AppMotion.reduce(context);` and spends it on `barrierDismissible: !reduceMotion`. Those are unrelated concerns, and the effect is backwards: a reduce-motion user *loses* the ability to dismiss by tapping outside, which is an accessibility regression. Step 6 asks for the dialog's **entry animation** to be suppressed. Set `barrierDismissible: true` unconditionally, and route the reduce-motion path through the transition duration instead.

**Defect 2 — the double-tap guard does not guard anything.** `_isLeaving` is set inside the confirm handler *after* `Navigator.of(ctx).pop()` has already removed the button, and is reset in a `finally`. Both `if (_isLeaving) return;` checks are therefore unreachable as guards: the outer one cannot be true because a modal dialog covers the `AppBar` button, and the inner one cannot be true because the pop is synchronous. The real risk is two taps on the confirm `TextButton` landing in the same frame. **Fix: set the flag before `Navigator.pop()` and do not reset it** — the screen is being torn down — or capture a plain `bool` in the dialog builder's closure.

**Defect 3 — the test's over-reach guard is fragile and semantically wrong.** It locates the sound toggle with `find.byType(IconButton).last`, which now depends on tree ordering between `leading:` and `actions:`. The sound button has a tooltip (`lobby_screen.dart:471`). Use `find.byTooltip('Mute')` / `find.byTooltip('Unmute')`, matching how the test already finds the leave control.

**Still open:** the glyph at `0xe674` has **not** been seen on a simulator. Step 2's gate is unmet, and per the Definition of Done it cannot be ticked from a green suite.

### The gap

`GameService.leaveRoom()` (`game_service.dart:258–290`) is correct and complete — and the lobby never calls it. `lobby_screen.dart:377–386` declares one `AppBar` action, the sound toggle, and no `leading:`. A grep across `lobby_screen.dart`, `gaslight_route.dart` and `main.dart` for `PopScope|WillPopScope|Navigator.pop|maybePop|leading:|BackButton|Leave|Exit|Quit` returns **zero matches**.

### Implementation

**Step 1.** `lib/theme/app_icons.dart` — add `depart,` to `ThematicIconType` after `redraw` (line 29).

**Step 2.** Add its entry to `_phosphorGlyphs` (lines 46–58), matching the existing style:

```dart
ThematicIconType.depart: IconData(0xe674, fontFamily: _kPhosphorLight), // signOut
```

> ### ⚠️ The codepoint cannot be verified from this repo — only on a simulator
>
> The vendored `Phosphor-Light.ttf` has a `post` table at **version 3.0, which stores no glyph names** (confirmed 9 Aug 2026: 1,543 cmap entries, 0 recoverable names). A cmap presence check is **near-worthless here** — the font's cmap spans `0x0020–0xFFFD`, and three unrelated candidate codepoints all tested PRESENT. Presence rules out nothing.
>
> `0xe674` is the value proposed by the user and is present in the font, but **presence is not identity**. A wrong codepoint renders a plausible-looking but incorrect glyph, or an empty tofu box, and **no widget test in this project can detect either** (§1 trap 5).
>
> **The blocking gate is visual:** build to a simulator, open the lobby, and confirm the leading icon reads as a door / sign-out arrow. If it does not, try `0xe668`, then source the correct value from upstream Phosphor. **Do not commit this item without having seen the glyph.**

**Step 3.** `lib/screens/lobby_screen.dart` — add to the `AppBar` (which currently has no `leading:`):

```dart
leading: IconButton(
  icon: ThematicIcon(
    type: ThematicIconType.depart,
    color: theme.colorScheme.secondary,
  ),
  onPressed: () => _confirmLeave(context, gs, isHost),
  tooltip: 'Leave room',
),
```

`isHost` is already computed at `lobby_screen.dart:310`. **Leave the existing sound toggle in `actions:` untouched.**

**Step 4.** Implement `_confirmLeave`. Copy is verbatim — punctuation and capitalisation included:

| | Non-host | Host |
|---|---|---|
| Title | `Leave this room?` | `Close this room?` |
| Body | `You can rejoin with the room code as long as the game hasn't started.` | `You are the host. Leaving will close the room for everyone.` |
| Dismiss | `STAY` | `STAY` |
| Confirm | `LEAVE` | `CLOSE ROOM` |

**Step 5.** On confirm: `await gs.leaveRoom()`, then route to the entry screen. On dismiss: nothing changes. Guard against a double-tap producing two `leaveRoom()` calls.

**Step 6.** The dialog needs an `AppMotion.reduce(context)` path; both actions ≥ 48 dp; re-verify the lobby still fits at 360×640 dp with `leading:` present.

### Validation

**`test/lobby_leave_test.dart`** — already exists, uncommitted, and currently hangs. See the IN FLIGHT block above before editing it. (`test/lobby_screen_test.dart` does not exist and should not be created.) Copy the pump idiom from `lobby_entry_test.dart:42` or `lobby_parlor_sheet_test.dart:73`; **`pumpAndSettle()` is banned in this repo — §1 trap 7.** `FakeFirestore` comes from `simulation_test.dart` and `FakeFirebaseFunctions` from `fake_functions.dart`, which is the established import pattern across eleven test files; `fakeFunctions.callableInvocations` is the existing call counter and the fake room code is always `TEST`.

- `"non-host can leave from the lobby"` — pump the lobby as a non-host, `find.byTooltip('Leave room')`, tap; assert the dialog shows the exact title `Leave this room?`; tap `STAY`, assert still in the lobby and `leaveRoom()` **not** called; reopen, tap `LEAVE`, assert `leaveRoom()` called **exactly once**. **Falsifying:** today `find.byTooltip('Leave room')` matches nothing and the test fails at the first tap.
- `"host sees the room-closing copy"` — same flow with `isHost: true`; assert the title `Close this room?`, the body string verbatim, and the confirm label `CLOSE ROOM`.
- **Over-reach guard** — assert the sound toggle is still present in `actions:` and still toggles `gs.soundEnabled`.
- **Manual, simulator** — the blocking glyph check from step 2.

### Blast radius — same commit

`lib/theme/app_icons.dart` · `lib/screens/lobby_screen.dart` · **new** `test/lobby_leave_test.dart` · `test/thematic_icon_test.dart` (if it enumerates the enum) · `docs/design_ui_direction.md` §7 (icon inventory gains `depart`).

---

## 5. Issue 52 — non-hosts get the full carousel, read-only

**What this means for the user:** a non-host currently sees a single folder and has no way to learn the game ships six decks.

### The gap

`lib/widgets/deck_carousel.dart:102–121` early-returns a single centred `_FolderCard` under the label `THE CHOSEN FILE` whenever `widget.isHost` is false. The seven-item `PageView` at lines 123–141 is host-only. The data is fine: six decks in `functions/src/prompt_decks.ts`, mirrored in `lib/utils/prompt_decks.dart:7–126`, plus a synthetic `'custom'` appended at `lobby_screen.dart:339`; the `_familyFriendlyOnly` filter (`lobby_screen.dart:332–340`, default `false` at line 43) removes only the two mature decks and only while the toggle is on.

### Implementation

**Step 1.** Delete the early return at lines 102–121. Render the same `PageView` for both roles. Keep the `THE CHOSEN FILE` section label above the carousel **for non-hosts only** — the host has no label today and gains none.

**Step 2.** Suppress every selection affordance when `!widget.isHost`:

- In `_onPageChanged` (lines 79–80), return before `widget.onDeckSelected(newDeckId)`. The server rejects the write anyway (`updateLobbySettings` requires host — `index.ts:1007–1010`) but a rejected callable surfaces a visible error, so the client must not make the call at all.
- In `_playStampPulse()` (line 86), return immediately when `!widget.isHost`. The stamp reads as *"you just chose this."*

**Step 3.** Badge the host's live choice so a non-host who swipes away still knows what is selected: on the card where `deckId == widget.selectedDeckId`, overlay the text `CHOSEN`. Non-hosts only — the host already has the stamp pulse.

**Step 4.** **Do not yank the page out from under a reader.** When `selectedDeckId` changes from the Firestore stream, a non-host's `PageView` may animate back to the chosen deck **only if the user has not swiped within the last 3 seconds**. Record the last interaction time in `didUpdateWidget`/`_onPageChanged` and compare; reuse the existing `_debounceTimer` field (line 94) rather than adding another timer.

**Step 5.** `custom` stays in the non-host list. The custom-prompt editor (`lobby_screen.dart:428–431`) stays host-gated — **do not expose it.**

### Validation

**New file `test/deck_carousel_test.dart`** — it does not exist today. **These tests will hit §1 trap 7 as hard as Issue 50's did** — the carousel lives inside the lobby tree and `_pulseController` is its own animation. Use `await tester.pump(); await tester.pump(const Duration(milliseconds: 500));`, never `pumpAndSettle()`. For swipe assertions, `tester.fling` / `tester.drag` followed by two explicit pumps is the pattern that works here.

- `"non-host sees every deck"` — assert `find.byType(PageView)` is present with `itemCount == 7`. **Falsifying:** today there is no `PageView` for a non-host, so the finder fails immediately.
- `"non-host cannot select a deck"` — swipe one page; assert the fake's `updateLobbySettings` was **not** called and the stamp pulse did not run.
- `"non-host can still see which deck is chosen"` — assert the `CHOSEN` badge is present on the card matching `selectedDeckId`.
- `"host selection still works"` — **the over-reach guard.** Swiping as host still calls `updateLobbySettings` **exactly once per settled page** and still fires the stamp pulse.
- **Layout** — 360×640 dp with the carousel present for a non-host; `AppMotion.reduce` renders a static card with no pulse.

### Blast radius — same commit

`lib/widgets/deck_carousel.dart` · `lib/screens/lobby_screen.dart` (label/props) · **new** `test/deck_carousel_test.dart` · `docs/design_prompt_system.md` · `docs/design_ui_direction.md` §10.

---

## 6. Issue 53 — 8-hour Firestore TTL for abandoned rooms

**What this means for the user:** invisible in play. It keeps dead rooms out of production Firestore and stops the small 4-letter code space filling with corpses.

### The gap

`functions/src/index.ts` exports fourteen callables and **no scheduled or triggered function** — a grep across `functions/src/` for `onSchedule|pubsub|scheduler|onDocument|TTL` returns zero matches. Cleanup is entirely client-driven: the staleness sweep at `game_service.dart:310–328` only runs inside a subscribed client and cannot prune itself (line 317). When the last client closes the app, the room and its `players` subcollection persist indefinitely. Confirmed live on 9 Aug 2026: production room `KVOH` still holds a player document that nothing will ever remove.

### ⚠️ Why this interval needs no keepalive — and what would change that

The TTL is **+8 hours**, revised by the user on 9 Aug 2026 (from +1 h, originally +24 h). **Do not shorten it without re-reading this section.**

Nothing in this system tracks presence. A player document's `expiresAt` is written **once, at join, and never refreshed** — the 10-second heartbeat writes `lastSeen` and only `lastSeen`. Room documents fare a little better, being refreshed by writes that already happen (step 3), but an idle lobby produces **zero** room writes. So the whole scheme rests on a single bet:

> **every realistic session ends before the timer expires.**

At 8 hours that bet always wins. The two gaps that could break it:

| Gap | What it takes to hit | At 8 h |
|---|---|---|
| An idle lobby is deleted with players sitting in it | A lobby open, clients connected, no setting changes for the entire window | Unreachable — phones sleep and apps background long before |
| An active player's document is deleted mid-game | One continuous session, measured from that player's join, longer than the window | Unreachable — a party game does not run for eight hours |

**At +1 hour both gaps are ordinary occurrences**, which is why that interval required a host-only `touchRoom` keepalive callable plus a client timer. At 8 hours that machinery is dead weight, so **it is deliberately absent from this spec — do not add it back.**

**Tripwire:** if the interval is ever shortened below roughly 4 hours, re-derive the table above before writing code. The keepalive design that a short interval would need is preserved in `ongoing_general_errors.md` Issue 53.

### Implementation — backend

**Step 1 — the constant.** Define once, at module scope in `functions/src/index.ts`:

```ts
const ROOM_TTL_MS = 8 * 60 * 60 * 1000;           // 8 hours — see the interval note above
const ttlFrom = (now: number) =>
  admin.firestore.Timestamp.fromMillis(now + ROOM_TTL_MS);
```

**Do not inline the literal.** The interval is referenced in five places; duplicating it is how three of them go stale, and the interval has already been revised twice.

**Step 2 — write `expiresAt` at creation.**
- `createRoom` (`index.ts:83–97`) — add `expiresAt: ttlFrom(Date.now())` to the room document.
- `createRoom` (`index.ts:106`) and `joinRoom` (`index.ts:186`) — add the same to **each player document**. **TTL does not cascade to subcollections**; the `players` collection group needs its own field and its own policy. Skip this and every player document behind a deleted room is orphaned permanently.

**Step 3 — ride-along refresh on existing room writes.** Add `expiresAt: ttlFrom(Date.now())` to the room update already performed by `advancePhaseInternal` (its `nextState` object), `startGame` (`index.ts:389`) and `updateLobbySettings` (`index.ts:1017`). These are existing writes; one extra field costs nothing. Be honest about what this buys at 8 hours: it is **cheap insurance, not load-bearing**. It only matters for a session outliving the window, which the interval note above establishes as unreachable. Include it because it costs nothing and makes a room's lifetime track activity rather than creation — not because anything depends on it.

**Step 4 — `firestore.rules`.** `expiresAt` is **server-owned**. The player update rule at lines 25–28 is a denylist; add `'expiresAt'` to it:

```
.hasAny(['role', 'totalScore', 'timesFooled', 'playersDeceived', 'isHost', 'joinedAt', 'hasRerolled', 'authUid', 'id', 'expiresAt']);
```

Nothing refreshes a player document's `expiresAt` after join. That is a deliberate consequence of the interval note above, not an oversight.

### Implementation — client

**None.** Issue 53 is backend-and-rules only. If you are editing `lib/` for this item you have left the spec — the keepalive timer that a shorter interval would have needed is explicitly not part of this build.

### Deployment — out-of-band, not captured by any file in this repo

```bash
gcloud firestore fields ttls update expiresAt --collection-group=rooms --project=gaslight-46368 --enable-ttl
```

```bash
gcloud firestore fields ttls update expiresAt --collection-group=players --project=gaslight-46368 --enable-ttl
```

Record **both** in `docs/design_database_and_security.md`. Without that note there is no in-repo evidence these policies exist, and a fresh Firebase project silently accumulates rooms forever.

### Accepted limitations — do NOT "fix" these

Chosen knowingly on 9 Aug 2026 (Issue 53, Option B):

- Deletion is **best-effort and may lag expiry**, in Firestore's case by up to 24 hours. An expired room can still be joinable. Not a bug to work around.
- **The emulator does not enforce TTL.** No automated test can prove deletion happens. Only the writing and refreshing of `expiresAt` is testable — which is exactly why the refresh tests below are mandatory.

### Validation

**`functions/test/game_e2e.spec.ts`:**

- `"writes expiresAt on room and players at creation"` — after `createRoom`, assert the room document's `expiresAt` is a `Timestamp` falling **between 7 h 45 m and 8 h 15 m** in the future, and that **every** player document has one in the same window. **Falsifying:** the field does not exist today, so it fails on `undefined`. Assert the window, not merely that the field is present — a bare presence check would pass a value of `0`.
- `"refreshes expiresAt on existing room writes"` — capture `expiresAt`, advance a phase, assert the new value is **strictly greater**. Repeat for `startGame` and `updateLobbySettings`.

**`functions/test/rules.spec.ts`:**

- `"client cannot write expiresAt on its own player document"` — assert denied.
- `"client can still write lastSeen alone"` — **the over-reach guard.** Break this and the 10-second heartbeat dies silently, which no client test would catch (§1 trap 6).

**Out-of-band:** `gcloud firestore fields ttls list --collection-group=rooms --project=gaslight-46368` returns the policy.

### Blast radius — same commit

`functions/src/index.ts` (`createRoom`, `joinRoom`, `startGame`, `updateLobbySettings`, `advancePhaseInternal`) · `firestore.rules` · `functions/test/game_e2e.spec.ts` · `functions/test/rules.spec.ts` · `docs/design_database_and_security.md` (the `expiresAt` contract, the 8-hour interval and its rationale, and both `gcloud` commands).

**No client files change for this item** — `lib/` and `test/fake_functions.dart` are untouched by Issue 53.

---

## 7. Deferred — do NOT start

| Item | Trigger that would revive it |
|---|---|
| **Issue 53 Option A — scheduled cleanup function** | The 8-hour TTL proves insufficient, or orphaned `players` documents appear despite the second policy. |
| **The `touchRoom` keepalive callable + 5-minute client timer** | **The TTL interval is shortened below roughly 4 hours.** Designed and costed on 9 Aug 2026 for the briefly-selected 1-hour interval; removed when the interval moved to 8 h. Do not build it at the current interval — see §6's interval note. |
| **Issue 50 Option C — `PopScope` for system back / edge-swipe** | Playtesters reach for the back gesture and report nothing happens. The `AppBar` control ships first. |

---

## 8. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.** Issue 31 is the model — rebuilt from pre-fix source, the suite reported `expected null to equal 3` and `expected 'INTERNAL' to equal 'FAILED_PRECONDITION'`. **Record the observed failure output in the Resolved entry.**

**A test's name is not a test.** A test titled *"…rim contrast >= 4.5:1"* asserted only that a file was non-empty, and the mascot shipped at **1.02:1** — invisible — with a fully green suite. Read the assertion, not the title.

**A check that cannot fail is not a check.** The cmap presence script in §4 passes for essentially any codepoint in this font. Before trusting a verification, establish what it would take for it to fail.

**Some correctness is invisible to the harness.** `Image.asset` loads nothing under `flutter test`; a wrong icon codepoint renders as tofu. Verify the artefact directly, or on a simulator.

**Measure; do not estimate.** A layout overflow estimated at ~275 dp measured **593 dp**.

**Do not tune a threshold to make a test pass.** Report the measured number and say the guard failed.

**A criterion can be confidently wrong.** Two tests once required `beak_open` to place 40–50% of its pixels outside the body silhouette; that does not measure an open beak, and the art that reads correctly sits at 14.6%. Before lowering a threshold, establish which is wrong — the artefact or the criterion.

**Pair every fix assertion with an over-reach guard.** Each item in §3–§6 names its own.

---

## 9. Running 3 simulators for multiplayer testing

Bots are server-seeded documents and never exercise the non-host **client** path. Anything that must be correct for a second human needs a real second client.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```

```bash
flutter build ios --simulator --debug
```

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app; xcrun simctl launch "$U" com.whylabs.gaslight; done
```

Must be `--debug`: `lobby_screen.dart` passes `debugEnabled: kDebugMode` and the server refuses debug calls when false. **DEBUG: ADD 9 BOTS** is host-only and adds 9 unconditionally.

To clear a device's room memory, `xcrun simctl uninstall <UDID> com.whylabs.gaslight` — the room code lives in `SharedPreferences` and survives a relaunch.

For local play against the emulator set `USE_EMULATOR=true` in `.env` and rebuild — `.env` is bundled as an asset. **`USE_EMULATOR` must be `false` in any tester build.**

---

## 10. Already delivered — do NOT rework

**Issues 1–49, Tasks T1–T11.** Points bearing on current work:

- **T6–T11 — the mascot is finished.** Ten transient poses are pre-rendered 256 px sprite sheets built by `scripts/build_sprite_sheets.py`, whose `POSE_REGISTRY` is the single source of truth for frame counts and grids; `_poseSheets` in `lib/widgets/raven_mascot.dart` must agree with it and `flutter test` T6.2 enforces that by parsing the Dart. `idle` and `sleep` deliberately stay on the layered renderer. **Two renderers coexist by design — do not unify them.**
- **`RavenPoseHost.playRavenPose` takes a required `onceKey`**, because Firestore streams rebuild constantly and a bare `if (condition)` re-fires the pose every tick. The same hazard governs Issue 51's eviction message — §3 step 8.
- **Issue 31** — settings no longer wipe each other. The server uses loose `!= null`; **never "simplify" it to a falsy check**, because `false` and `0` are legitimate values.
- **Issues 28/29** — `phosphor_flutter` can never be used (`IconData` is a `final class`, proven twice). The app vendors the Phosphor Light font. **T2** — `cupertino_icons` deliberately absent.
- **Task T3** — `test/helpers/png_decoder.dart` decodes palette-indexed PNGs and computes WCAG contrast. Reuse it rather than writing another decoder.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` · Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `ITSAppUsesNonExemptEncryption = false` · `GoogleService-Info.plist` required on disk but gitignored · `.env` ships inside the IPA.

---

## 11. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field (M5); **Vote's CONFIRM** is bottom-anchored via `Expanded`+`SafeArea`.
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **Entry-form logo uses `SizedBox` + `FittedBox`**, not `Transform.scale`.
- **`isSmallHeight` uses a `< 700` dp breakpoint** with a 6/8/12/16/20 spacing scale.
- **House Rules non-host gating uses `IgnorePointer` + `Opacity(0.5)`.** **Issue 52 deliberately departs from this pattern** for the deck carousel — it becomes interactive-but-inert rather than dimmed, because its purpose is to be read. Do not "restore consistency" by dimming it.
- **The mascot's head tilt is whole-body**, a deliberate simplification for a single-silhouette design.
- **Leaving a room does not call `Navigator` explicitly.** `lobby_screen.dart:369` gates the waiting-room render on `gs.gameState != null && gs.currentPlayer != null` and otherwise falls through to `_buildEntryForm` (line 385), so clearing local state re-renders the entry form in place. Same guarantee as "route to the entry screen", different structure — **do not add a redundant `Navigator.pushReplacement` after `leaveRoom()`.** This is also why `gs.currentPlayer!` at line 389 is safe.

---

## 12. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; all mutations go through callables; `firestore.rules` denies client room writes. A player's own `lastSeen` heartbeat is the single sanctioned client write — **`expiresAt` is not, by §6 step 4.**
- **Portrait-locked on phones**; **text scale clamped 1.0–1.3**.
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.** Issue 50 adds an enum member; it does not add a second icon mechanism.
- **`_familyFriendlyOnly` is client-local and never synced** (Issue 30 Option C explicitly declined).
- **`RavenMascot`'s constructor signature (`state`, `size`) is fixed**, and `playRavenPose`'s `onceKey` stays required.
- **"Forgery Rounds" maps to `sabotageAnswersCount`.**
- **Declined, do not re-propose:** P7 (Confidence Wager), P9 (House Cards), P11 (The Final Gambit), Issue 30 Option C, Issue 34 Option C.

---

## 13. Where the contracts live

`ongoing_general_errors.md` is the live queue plus the traps that still bite — **not** a history. Do not re-expand it with delivered work; record outcomes in the design doc that owns the behaviour.

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Full history of any resolved item | `git log` |
| Backend write contract, rules, identity, disconnect/host handoff | `design_database_and_security.md` — **§7 is the `null` ≠ absent contract; §4–§5 gain Issue 51's phase gate plus the `expiresAt` contract and its 8-hour rationale** |
| Card passing, disconnect recalculation, input validation | `design_rotation_engine.md` §5 |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` §4 |
| Palette, typography, motif, icons, mascot, UI programme | `design_ui_direction.md` — **§7 gains `depart`; §10 gains the non-host carousel** |
| Prompt decks · duplicate answers | `design_prompt_system.md` · `design_semantic_integrity.md` |
| PNG decoding / contrast helper | `test/helpers/png_decoder.dart` |
| Mascot pose pipeline | `.agents/skills/mascot_pose_creation/SKILL.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 14. Feedback loop — what past specs got wrong

- **Changing a constant can change the architecture — and changing it back can un-change it.** The TTL moved 24 h → 1 h → 8 h in a single day. At 1 h the window no longer fit inside a realistic session, which forced a keepalive callable and a client timer into the design; at 8 h that machinery became dead weight and was deleted again. **When a spec tightens a time budget, re-derive which mechanisms still satisfy it — and when it loosens again, remove what the tight version required instead of leaving it in as "defensive".**
- **Two safe changes can compose into an unsafe one.** Issue 51 (deletion evicts clients) and Issue 53 (delete on a timer) are each correct alone. At the briefly-selected 1-hour interval they combined to throw live players out of a running game — a failure neither item's own spec described, and the reason §6 now carries an explicit interval note rather than a bare constant. **When two queued items touch the same state, write down what happens once both have shipped.**
- **"Handle disconnects" did not say *in which phase*.** The result is Issue 51: a function correct in four phases that silently corrupts the fifth. **Name the state space a rule applies to, and what happens in each part of it.**
- **"Listen to the room" did not say what a *deleted* room means.** `if (snapshot.exists)` with no `else` looks complete and is not. **When specifying a listener, specify the absent case.**
- **A hang is not a failure, and confusing the two costs a cycle.** `pumpAndSettle()` on an animated screen produces no assertion output at all — just `did not complete` after minutes of silence, which reads like a logic bug in the code under test. **When a test emits no assertion output whatsoever, suspect the pump strategy before the production code.** Check what the neighbouring tests in the same directory do before inventing a harness approach.
- **A verification that cannot fail is not a verification.** The cmap presence check reads as rigorous and passes for nearly any input.
- **A test's name is not a test.** A contrast test once asserted only that a file was non-empty.
- **Approval gates get skipped under momentum.** Artwork shipped unseen because sign-off lived in a checklist. State gates inline, marked blocking.
- **A cross-language `undefined` check is not a null check.**
- **Resolution is not compilation.** A package that resolves may still fail to build.
- **Layout overflow must be measured, not estimated** — estimated ~275 dp, measured **593 dp**.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Copy strings verbatim.
(3) VALIDATE per §8. Observe the falsifying assertion fail against the broken state
    before you fix it, and record that output. Run the item's over-reach guard.
    For anything the harness cannot see, check a simulator. Then the full §1 battery.
(4) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(5) RECORD: move the issue to Resolved (Problem / Solution / Validation) including
    the observed failure output. Sync any design doc whose behaviour changed.
(6) COMMIT: one issue = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **Issue 51** — host leaving a lobby deletes the room *and* every player document; the lobby branch precedes the `!hasCard` branch; in-game host transfer still works; the client's room listener handles deletion and evicts with **"The host has left. This room has closed."**, gated by a once-per-event key.
- [ ] **Issue 50** — `leading:` leave control in the lobby `AppBar`, both dialog copy variants verbatim, `leaveRoom()` called exactly once on confirm, sound toggle untouched.
- [ ] **The `depart` glyph seen rendering on a simulator.** A tofu box passes every automated test in this project. This checkbox may not be ticked from a green suite.
- [ ] **Issue 52** — non-hosts get all 7 cards, cannot select, cannot trigger the stamp pulse, see the `CHOSEN` badge, and are not page-yanked within 3 s of swiping; the host path is unchanged.
- [ ] **Issue 53** — `ROOM_TTL_MS` defined once at **8 hours**; `expiresAt` written at creation on rooms *and* players and asserted to land in a window, not merely to exist; refreshed on existing room writes; `expiresAt` in the `firestore.rules` denylist with the `lastSeen`-still-allowed guard passing; **both** `gcloud` TTL policies applied and recorded. **No `touchRoom`, no client timer, no changes under `lib/`.**
- [ ] Every item's **falsifying assertion was observed to fail** against the broken state, with the output recorded in its Resolved entry.
- [ ] Every item's **over-reach guard passes** before and after.
- [ ] Three-simulator playthrough: host leaves a lobby → both non-hosts evicted with the right message; a non-host leaves → the room survives and the host sees them go; a full game completes end to end. **Do not try to wall-clock the 8-hour TTL** — instead confirm in the Firebase console that a freshly created room and each of its player documents carries an `expiresAt` roughly eight hours out.
- [ ] Full battery at or above the §1 bar: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 106 + new** · functions build clean · `npm --prefix functions test` **≥ 31 + new**.
- [ ] `flutter build ios --release --no-codesign` run and `Runner.app` size **measured and recorded** — the 47.7 MB figure in §1 is stale and must not be quoted.
- [ ] Issues 50–53 moved to Resolved in `ongoing_general_errors.md`; design docs synced per each item's blast radius.
- [ ] **Guide rewritten** to `Queue Complete` or the next queue. If the queue is empty: **do not invent work.** The only legitimate triggers are a §7 deferred item's trigger firing, or a new user-selected issue.
