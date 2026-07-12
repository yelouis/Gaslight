# Agent Execution Guide — Remaining Work (selections locked, July 12)

**You are an engineering agent picking up Gaslight (Flutter + Firebase party game).** The server-authoritative backend (Cloud Functions) is built but has a **fatal transaction bug** and **no real tests**. The user has selected **Option A for every open issue (13–18)** in `docs/ongoing_general_errors.md` — nothing is awaiting a decision. This guide is the detailed implementation spec: follow it item by item, in order, with the validation attached to each.

Read first, once: `docs/implementation_plan_gameplay_and_ui.md` **Section 0** (game, architecture, file map) and `docs/design_database_and_security.md` (the shipped server architecture: callables table, locked-down rules, identity model).

**State right now (verified July 12):** Issues 2–12 + all gameplay proposals + the UI foundation are done and green (`flutter test`: 11/11 pass; `flutter analyze`: 0 errors in `lib/`, 2 known errors in the stale `integration_test/fake_firestore.dart`). Cloud Functions compile (`cd functions && npm run build`). The client no longer calls `evaluateReadyState` from listeners — the **server** auto-advances phases when the last player readies (once R1 fixes the transaction bug). Do not re-do finished work.

---

## Work queue (all selections = Option A)

| # | Issue | One-line goal | Size |
|---|---|---|---|
| **R1** | Issue 13 🔴 | Reorder transaction reads before writes in 3 callables | Small |
| **R2** | Issue 15 🔴 | Build the emulator integration + rules test suite | ~1 day |
| **R3** | Issue 14 🔴 | Surface callable errors; unstick the submit/vote spinners | Small |
| **R4** | Issue 16 🟠 | Device-stable playerId + rejoin re-bind (keep your seat) | Small–Med |
| **R5** | Issue 17 🟠 | Port debug/bot tools to gated dev callables | Medium |
| **R6** | Issue 18 🟡 | Field-scoped own-doc writes for reactions/lobby-ready | Tiny |
| **R7** | Wave E | UI polish: icons (E6), components (E5), sound (E7), a11y (E8) | Medium |

When **R1 + R2** are both green: move **Issues 1, 13, and 15** to the Resolved section (the two-client emulator test is the proof Issue 1 was waiting for) and update the status note at the top of `design_database_and_security.md`.

---

## R1 · Issue 13 — Fix the read-after-write transaction ordering (DO FIRST)

**Problem recap:** Firestore transactions require *all reads before any writes*. In `functions/src/index.ts`, `submitAnswer`, `castVote`, and `setReady` each do: `transaction.get(roomRef)` → `transaction.update(roomRef, …)` → `transaction.get(roomRef.collection("players"))` (to check "all ready → auto-advance"). The Admin SDK throws `Firestore transactions require all reads to be executed before all writes.` on that late read — on **every** call. Nobody can submit, vote, or ready.

**Implementation (Option A — reorder, keep one atomic transaction):**
For each of the three callables, restructure the transaction body to this exact phase order:

1. **Read phase (all `transaction.get` calls, nothing else):**
   - `const roomSnap = await transaction.get(roomRef);` (throw `not-found` if missing).
   - `const playersSnap = await transaction.get(roomRef.collection("players"));` — moved UP from below the write.
2. **Compute phase (pure logic, no transaction calls):**
   - Parse `room`, find the card (`submitAnswer`/`castVote`) and validate (`not-found` if the card is missing).
   - Build `newCards` (answer merged / vote merged) and `newReadyMap = { ...room.readyPlayers, [playerId]: true }` (for `setReady`, use the passed `ready` value).
   - `const activePlayers = playersSnap.docs.map(d => d.data() as PlayerState).filter(p => p.role !== "spectator");`
   - `const allReady = activePlayers.length > 0 && activePlayers.every(p => newReadyMap[p.id] === true);`
3. **Write phase (all writes, no reads after this point):**
   - `transaction.update(roomRef, { cards: newCards, readyPlayers: newReadyMap });` (`setReady` updates only `readyPlayers`).
   - `if (allReady) await advancePhaseInternal(transaction, roomRef, room, activePlayers, newCards);` — pass the **already-fetched** `activePlayers` and the **merged** `newCards` so `advancePhaseInternal` needs no reads. Audit `advancePhaseInternal` to confirm it performs **only** `transaction.update` calls (it does today — keep it that way; add a comment stating the invariant: *"must never call transaction.get — callers complete all reads first"*).

Notes:
- The per-player ownership check (`playerRef.get()` comparing `authUid`) currently runs **before** the transaction in all three callables — leave it there; it does not violate the ordering rule and avoids enlarging the transaction's read set.
- There is a subtle interaction with `advancePhaseInternal`'s vote branch: it writes score/honor increments to player docs via `transaction.update(pRef, …)` — writes are fine; just ensure no new `transaction.get` sneaks in.
- After editing: `cd functions && npm run build` must pass.

**Validation:**
- The definitive proof is R2's emulator suite. As an immediate smoke check before R2 exists: start the emulators (`firebase emulators:start --only auth,functions,firestore` after R2's config, or a minimal ad-hoc config), sign in anonymously via the Auth emulator REST API, call `createRoom` → `joinRoom` → `startGame` → one `submitAnswer`, and assert it returns `{success: true}` instead of an internal error. Today that single `submitAnswer` call fails; after R1 it must pass.
- Regression guard: R2's integration test covers all three callables through a full game.

---

## R2 · Issue 15 — Build the real emulator + rules test suite

**Problem recap:** the backend has never been executed by a test. `test/fake_functions.dart` re-implements the game logic in Dart, so the Flutter suite validates the fake, not the TypeScript. The Wave C4 mandate (two-client emulator test + rules unit tests) was skipped — which is exactly how Issue 13 shipped.

**Implementation (Option A — the full C4 suite):**

1. **Emulator config** — add to `firebase.json`:
   ```json
   "emulators": {
     "auth": { "port": 9099 },
     "functions": { "port": 5001 },
     "firestore": { "port": 8080 },
     "ui": { "enabled": false }
   }
   ```
   (The client already honors `USE_EMULATOR=true` for these exact ports.)

2. **Test harness location & runner** — put backend tests in `functions/test/` (TypeScript, run with mocha or vitest — pick one, add to `functions/package.json` `devDependencies`, and add scripts: `"test": "firebase emulators:exec --only auth,functions,firestore 'npm run test:inner'"` and `"test:inner"` running the compiled tests). Everything below runs inside `emulators:exec` so the emulators are guaranteed up.

3. **Auth + callable helpers** — write two small helpers:
   - `createAnonUser()`: POST to the Auth emulator REST endpoint `http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key` with `{returnSecureToken: true}` → returns `{idToken, localId}`.
   - `callFn(name, idToken, data)`: POST `http://localhost:5001/<projectId>/us-central1/<name>` with headers `Authorization: Bearer <idToken>`, `Content-Type: application/json`, body `{"data": <data>}`; parse `{result}` or the `{error}` envelope. (`<projectId>` comes from `.firebaserc` / the `GCLOUD_PROJECT` env inside `emulators:exec`.)

4. **Two-client full-game integration test** (the centerpiece — this is the test that proves Issue 1 and would have caught Issue 13):
   - Create two anon users (host, guest) with **stable playerIds** `"p_host"`, `"p_guest"`.
   - `createRoom` as host (2 forgery rounds → with 2 players, `startGame` requires players > rounds, so create with `sabotageAnswersCount: 1`); `joinRoom` as guest; `startGame` as host.
   - Read the room doc via the Admin SDK (`firebase-admin` pointed at the emulator with `FIRESTORE_EMULATOR_HOST`) to fetch `currentCardAssignments`; for each rotation have **both** users call `submitAnswer` for their assigned target — assert each returns success (this line fails before R1).
   - Assert the phase auto-advanced to `truth` after the last submission (server-side auto-advance); submit truths; assert phase `vote` + `resolutionOrder`/`currentReaderId` set.
   - Per card: the non-reader calls `castVote` (vote `'TRUTH'`); the reader calls `setReady`; assert phase flips to `reveal`; assert score deltas on player docs match `ScoringLogic` expectations **and** `timesFooled`/`playersDeceived` accumulate; host calls `advanceToNextResolution`; repeat; assert `gameOver` at the end.
   - **Force-advance branch:** a second scenario where one player never submits during forgery; host calls `advancePhase`; assert the missing slot contains the placeholder text and the phase advanced.
   - **Negative auth checks:** guest calling `startGame`/`advancePhase` → `permission-denied`; a user calling `submitAnswer` with the *other* player's `authorId` → `permission-denied`; `castVote` with `voterId === votedForId` → `invalid-argument`.

5. **Rules unit tests** — with `@firebase/rules-unit-testing` (loading `firestore.rules`):
   - `assertFails`: any write to `/rooms/{code}` by an authed client; `create`/`delete` of a player doc; updating own doc's `totalScore`, `isHost`, or `authUid`; updating **another** player's doc at all.
   - `assertSucceeds`: updating own doc's `lastSeen`; `{lastReaction, lastReactionAt}`; `lobbyReady`; `name`/`colorValue`/`avatarIndex` — where "own" means the doc's `authUid` equals the request auth uid.
   - Seed docs with the Admin bypass context (`withSecurityRulesDisabled`).

6. **Clean up the stale fake** — `integration_test/fake_firestore.dart` no longer compiles (2 `invalid_override` errors: `snapshots()` gained a `ListenSource source` parameter in the upgraded SDK). Fix by adding the missing named parameter to both overrides **or** delete the file plus its sole consumer `integration_test/app_test.dart` if that harness is fully superseded by the emulator suite — check imports before deleting. Target: `flutter analyze` back to **0 errors**.

7. **Document** the one-command run (`npm --prefix functions test`, requires `firebase-tools`) in `README.md` under a "Backend tests" section.

**Validation:** the suite *is* the validation. Acceptance: `npm --prefix functions test` green end-to-end including both scenarios and all negative checks; `flutter analyze` 0 errors; `flutter test` still 11/11.

---

## R3 · Issue 14 — Surface callable errors; never strand a player on a spinner

**Problem recap:** `_submitAnswer` (`lib/screens/phase2_craft.dart`) and `_castVote` / the reader "I'M READY" path (`lib/screens/phase3_vote.dart`) `await` callables with no try/catch. Any failure (server "too similar" rejection, network blip) leaves `_isSubmitting`/`_submitted` stuck `true` — an eternal spinner, no message, nothing sent.

**Implementation (Option A):**
1. **`phase2_craft.dart` → `_submitAnswer`:**
   - Delete the client-side `SemanticFilter` pre-check block (the `comparisonAnswers` build + `isAnswerUnique` call + its SnackBar) and the now-unused import — the server enforces similarity authoritatively.
   - Delete the `await gs.setPlayerReady(true);` that follows `submitCardAnswer` — the server's `submitAnswer` already marks the author ready inside the same transaction (post-R1).
   - Wrap the remaining `await gs.submitCardAnswer(targetId, me.id, text, isTruth);` in `try { … } on FirebaseFunctionsException catch (e) { SnackBar(e.message ?? 'Submission failed — try again.'); } catch (e) { generic SnackBar; } finally { if (mounted) setState(() => _isSubmitting = false); }` — and only clear `_answerController` on success. (Import `package:cloud_functions/cloud_functions.dart` for the exception type.)
2. **`phase3_vote.dart` → `_castVote`:** set `_submitted = true` optimistically as now, but on catch: SnackBar the message and `setState(() => _submitted = false)` so the grid returns and the player can re-vote.
3. **`phase3_vote.dart` → reader "I'M READY" button:** same pattern around `setPlayerReady(true)` — revert `_submitted` on failure.
4. Sweep the other user-triggered callables for the same gap: the reroll button (`phase2_craft.dart`) already try/catches — verify; `toggleLobbyReady`, `sendReaction` fail soft (fine); lobby `startGame` already handled (Issue 8).

**Validation:**
- Widget tests using a throwing fake: extend `test/fake_functions.dart` so a test can arm a one-shot failure for a named callable (e.g. `FakeFirebaseFunctions.failNext('submitAnswer', message: 'Answer is too similar…')` throwing `FirebaseFunctionsException`). Pump the craft screen, submit, assert: SnackBar with the message appears, the SUBMIT button is tappable again, the typed text is still in the field. Repeat for the vote grid (assert re-votable).
- Manual (emulator, post-R1): submit a near-duplicate answer → see the server's "too similar" message and retry successfully.

---

## R4 · Issue 16 — Device-stable identity: keep your seat across reinstalls

**Problem recap:** the server half is done (`joinRoom` re-binds `authUid` for a known `playerId`; callables validate `authUid`; rules lock `authUid`). But the client still uses the **auth uid as the playerId** (`lobby_screen.dart` `_getPlayerId()`), and `tryRejoinSession` **clears the session** on mismatch (the interim guard from Resolved #36) — so seats are still lost, and the guard blocks the server's re-bind from ever running.

**Implementation (Option A):**
1. **Stable ID generation** — in `lobby_screen.dart` `_getPlayerId()`: read SharedPreferences key `stable_player_id`; if absent, generate `const Uuid().v4()` and persist it; **always return it** (never `currentUser.uid`). This id is per-device and permanent.
2. **Rejoin re-bind** — in `GameService.tryRejoinSession()`:
   - **Delete** the interim mismatch guard (the `authUid != savedPlayerId → clear prefs → return false` block).
   - New flow: load `savedRoom`/`savedPlayerId`; fetch the room + player docs (reads are public). If either is missing → clear prefs, return false (room ended).
   - If the player doc exists, call the **`joinRoom` callable** with `roomCode: savedRoom, playerId: savedPlayerId` and the doc's existing `name`/`colorValue`/`avatarIndex` — the server's rejoin branch updates `authUid` to the current anonymous uid and returns the player's role, restoring write access. Then set `_currentPlayerId = savedPlayerId`, `listenToRoom(savedRoom)`, return true.
   - Wrap the callable in try/catch: on failure, fall back to clear-prefs/return-false (never restore a session that can't write).
3. **Migration:** old sessions cached `player_id = <old uid>` — that still works untouched: the saved id points at the existing player doc and `joinRoom` re-binds `authUid` regardless of what the id looks like. No special-casing needed. New sessions write both `stable_player_id` and the session `player_id` (they'll be equal going forward).
4. **Docs:** update `design_database_and_security.md` §5 — delete the "Current gap / Issue 16" note, state the client behavior as shipped.

**Validation:**
- Emulator test (add to the R2 suite): create+join as anon user A with playerId `p_x`; score some points; create a **new** anon user B (fresh uid); call `joinRoom` with the same `p_x` → assert the player doc's `authUid` == B's uid, `totalScore` preserved, and a follow-up `submitAnswer`/`setReady` as B succeeds.
- Flutter unit test: `_getPlayerId()` returns the same value across two invocations with mocked prefs; returns a UUID (not the auth uid) when `currentUser` exists.
- Manual (web): mid-lobby, clear only auth/site storage, reload → app signs in anonymously with a new uid, rejoins, and the same seat/name/score appear.

---

## R5 · Issue 17 — Port the debug/bot tools to gated dev callables

**Problem recap:** `debugAddBots` / `debugSimulateBotResponses` in `GameService` still write player docs and the room doc directly → `PERMISSION_DENIED` under the locked-down rules, in production **and** emulator. Journey 2 (`e2e_testing_journeys.md`) and the one-device dev workflow are dead. Also: `_resetAllPlayersReady` + `updateGameState` in `GameService` are unreachable remnants.

**Implementation (Option A — dev-only callables with an explicit gate):**
1. **Gate design:** add an optional `debugEnabled: boolean` to the `createRoom` callable's payload, stored on the room doc. The Flutter lobby passes `debugEnabled: kDebugMode` (import `flutter/foundation.dart`) when creating a room. In `functions/src/index.ts`, add a helper `assertDebugAllowed(room)` that throws `permission-denied` unless `room.debugEnabled === true` **or** `process.env.FUNCTIONS_EMULATOR === "true"`. (Belt-and-braces: release builds never set the flag; production functions reject even if someone forges it off-emulator only when the flag is absent.)
2. **`debugAddBots` callable** (`roomCode`): caller must be the host (same `authUid`→`isHost` check as `startGame`); `assertDebugAllowed`; in a batch, create `bot_1`…`bot_9` player docs — `authUid: "BOT"`, `isHost: false`, staggered `joinedAt`, and **`lastSeen: null`** (critical: the client's dead-player detector skips null `lastSeen`, so bots aren't pruned as disconnected); update `totalPlayers`.
3. **`debugSimulateBots` callable** (`roomCode`): host + `assertDebugAllowed`; **one transaction obeying the R1 read-order invariant** (read room, read players, then writes only):
   - Forgery/truth phase: for each bot, write `"Simulated Answer from <name>"` into its assigned card (`currentCardAssignments[botId]` → truth vs sabotage slot per phase) and set `readyPlayers[botId] = true`.
   - Vote phase: each non-reader bot votes `'TRUTH'` on the current card and is marked ready; if the reader is a bot, mark it ready too.
   - After merging, compute `allReady` over active players and call `advancePhaseInternal` when true — so a lone human + bots actually progresses (this replaces the old client-side behavior).
4. **Client refactor:** `GameService.debugAddBots()` / `debugSimulateBotResponses()` become 3-line callable wrappers (`httpsCallable('debugAddBots').call({'roomCode': …})`). Delete the direct-write bodies, the `_resetAllPlayersReady` method, and `updateGameState` (verify no remaining callers first — `_resetAllPlayersReady` is its only caller today). Keep the existing debug buttons/UI unchanged.
5. **Fake parity:** mirror the two callables in `test/fake_functions.dart` so existing widget tests keep passing (port the deleted Dart logic there).

**Validation:**
- Emulator: create a room (emulator ⇒ gate passes) → `debugAddBots` → 9 bot docs exist with `lastSeen: null`; `startGame` → `debugSimulateBots` twice + one human submit per rotation → phases advance to `gameOver` with sane scores. Negative: seed a room doc with `debugEnabled: false` via Admin SDK **and** temporarily unset `FUNCTIONS_EMULATOR` in the test process env when invoking the gate logic directly (unit-test `assertDebugAllowed` in isolation for the production-deny path, since the emulator env var is always set inside `emulators:exec`).
- `flutter test` still green (fakes updated); manual Journey 2 run on the emulator.

---

## R6 · Issue 18 — Field-scoped own-doc writes

**Problem recap:** `sendReaction` / `toggleLobbyReady` write the **entire** player map via `copyWith` + `updatePlayerState(merge: true)`. The field-diff rules deny the write if any *stale* protected field (e.g. `totalScore` an instant before the listener catches up after scoring) differs — the reaction/toggle silently vanishes.

**Implementation (Option A):**
1. `sendReaction(emoji)`: replace the `copyWith` + `updatePlayerState` with a direct targeted update: `_db.collection('rooms').doc(rCode).collection('players').doc(p.id).update({'lastReaction': emoji, 'lastReactionAt': DateTime.now().millisecondsSinceEpoch});`
2. `toggleLobbyReady()`: same pattern with `{'lobbyReady': !p.lobbyReady}`.
3. If `updatePlayerState` then has no remaining callers (check — R5 removes others), delete it.

**Validation:**
- Rules test (in the R2 suite): as the seat owner, `update` with exactly `{lastReaction, lastReactionAt}` → `assertSucceeds`; and (pre-fix behavior, as a regression demo) a full-object write where `totalScore` differs → `assertFails`.
- Widget/unit test on the fake asserting the update payload contains **only** the intended keys.
- Manual (emulator): react within a second of a reveal starting (fresh score delta) — emoji still broadcasts.

---

## R7 · Wave E polish (E5–E8)

Spec lives in `docs/implementation_plan_gameplay_and_ui.md` Wave E; statuses verified July 12:
1. **E6 icons (confirmed NOT done — do first):** stock Material icons remain in `phase2_craft.dart` (`remove_red_eye_outlined`), `phase3_vote.dart` (`remove_red_eye`), `lobby_screen.dart` (`timer_off`, `vpn_key`), `auto_advance_timer.dart` (`timer`), `player_avatar.dart` (glyph list incl. `vpn_key`, `casino`, `lightbulb_outline`). Create `lib/theme/app_icons.dart` mapping thematic replacements (monocle/magnifier = observe, pocket-watch = timer, quill = writing, wax seal = confirm, skeleton key = secret, gas lamp = host) — bundle SVGs (e.g. `flutter_svg`) or an icon font; swap the six avatar glyphs for the house sigils (moth, moon, key, raven, hourglass, flame) **keeping the `avatarIndex` positional mapping** so existing players keep their crest.
2. **E5 components:** audit against the plan — pressed "stamp" scale/flash on `PrimaryButton` commits; engraved bevel on avatar chips; **brass halo on the active reader's avatar** (`currentReaderId`) in vote/reveal; timer "guttering lamp" pulse on `isLowTime`; "SEALED — your own hand" ribbon on the disabled self-card in `card_grid.dart`.
3. **E7 motion/sound:** bundled sounds (quill scratch on submit, wax thunk on vote, swell on truth reveal) behind a **mute toggle**, plus haptics on commit/reveal; add a reduce-motion setting honored by every animation (the `FlippingRevealCard` already shows the `MediaQuery.accessibleNavigation` pattern — reuse it).
4. **E8 a11y:** contrast-check brass/ivory on soot at body sizes; ensure no meaning is carried by dim opacity alone; tabular figures on all live numbers.

**Validation:** `flutter analyze` clean; goldens or manual screenshot pass per screen; reduce-motion on ⇒ final states render without animation; each E-item either done or explicitly deferred with a note in the plan doc.

---

## THE LOOP (per item)

```
 ORIENT once: plan §0 · design_database_and_security.md · flutter pub get ·
 flutter analyze · cd functions && npm run build
      │
      ▼
 (1) SELECT next item R1→R7 (order encodes real dependencies).
 (2) STUDY the spec above + the exact files it names.
 (3) IMPLEMENT as specified. Invariants: transactions read-then-write only;
     never weaken firestore.rules to make something pass; the TS functions are
     the authoritative rules — keep test/fake_functions.dart mirrored.
 (4) VALIDATE per the item's Validation block, then: flutter analyze (0 errors),
     flutter test, and — for anything touching functions/ or rules —
     npm --prefix functions test (the emulator suite). Fakes never validate
     backend behavior.
 (5) BLOCKED or the spec is wrong? STOP; file it in ongoing_general_errors.md
     (bug_documentation_guidelines format, with options) and ask the user.
 (6) RECORD: move the issue to Resolved with what-was-solved; after R1+R2 also
     move Issue 1; sync design docs (esp. §5 identity note after R4).
 (7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

## Definition of Done
- [ ] R1: three callables read-before-write; `npm run build` clean; single-`submitAnswer` smoke passes on the emulator.
- [ ] R2: `npm --prefix functions test` green — two-client full game (both scenarios), negative auth checks, rules tests; stale `integration_test/fake_firestore.dart` fixed/removed; `flutter analyze` 0 errors; run command documented in README.
- [ ] Issues **1, 13, 15** moved to Resolved, citing the emulator test as proof; `design_database_and_security.md` status note updated.
- [ ] R3: failed submits/votes show the server message and allow retry; dead pre-check + redundant ready call removed.
- [ ] R4: stable UUID identity + rejoin re-bind; emulator re-bind test green; design doc §5 updated; Issue 16 → Resolved.
- [ ] R5: gated bot callables working on the emulator; direct-write bodies + dead remnants deleted; fakes mirrored; Issue 17 → Resolved.
- [ ] R6: targeted own-doc writes; rules test green; Issue 18 → Resolved.
- [ ] R7: E6 done; E5/E7/E8 done or explicitly deferred with notes.
- [ ] Final: `flutter analyze` 0 errors · `flutter test` green · emulator suite green · docs synced · one-item commits.
