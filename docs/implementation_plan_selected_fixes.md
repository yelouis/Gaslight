# Implementation & Validation Plan — Selected Fixes

This document turns the **selected options** in `docs/ongoing_general_errors.md` (Issues 1–7) and `docs/design_scoring_and_ui.md` (Clarifications 1–2) into a concrete, ordered plan another engineer/model can execute. Each item states, in plain language, **what it means for the player**, then the **technical changes** and **how to validate** it.

> **How to read this**: Do the work in the order below. Steps are grouped into three waves so the game becomes correct and pleasant quickly, before the larger security migration. Where a later wave re-homes logic (Wave C moves rules onto a server), the plan flags what must be **mirrored** there so fixes are not lost.
>
> **Scope of this doc:** the selected **bug/correctness fixes** — Issues 1–11 and Clarifications 1–2. The selected **new features and visual redesign** (gameplay Proposals P1–P6 and the "Turn Down the Lamps" UI direction) live in the companion plan **`docs/implementation_plan_gameplay_and_ui.md`** (Waves D–E), which is sequenced to run *after* the correctness waves here. Start there only once Wave A is merged.

---

## Sequencing overview

| Wave | Goal | Items | Why this order |
|------|------|-------|----------------|
| **A — Correctness quick wins** | Make the *current* single-host flow correct and fair | Issues 2, 3, 5, 6, 7 + Clarifications 1, 2 | Small, self-contained, high value. Safe to ship for playtests. |
| **B — Responsiveness & robustness** | Remove lag and edge-case corruption | Issues 4, 8, 9, 10 | Depend on nothing external; improve feel and stability. |
| **C — Production multiplayer & security** | Make real multiplayer work and be cheat-resistant at App Store scale | Issue 1 (server-authoritative) | Largest lift; re-homes the Wave A/B game rules onto Cloud Functions. Do last so the rules are already correct before porting. |

**Critical mirroring note:** Wave C moves the game-rule logic (scoring, placeholders, phase advancement, honors data) from the Dart client into Cloud Functions. Every Wave A/B rule change (Issues 2, 3, 5, 7 + Clarification 1/2) must be **re-implemented identically** in the Cloud Function during Wave C. They are called out again in the Wave C checklist.

---

# WAVE A — Correctness Quick Wins

## A1 · Issue 2 — Host "Proceed to Reveal" loses that card's points
**Selected: Option A** — route the override through `forceAdvance()`.

**What it means for the player:** Today, if the host taps the "Proceed to Reveal" button before everyone has voted, **nobody gets the points they earned on that card** — the scoreboard silently skips a whole round of scoring. This makes the final standings wrong and feels broken.

**Technical changes** (`lib/screens/phase3_vote.dart`):
1. In `_buildWaitingUI`, change the "PROCEED TO REVEAL (HOST)" button `onPressed` from:
   `gs.updateGameState(state.copyWith(currentPhase: GamePhase.reveal))`
   to: `gs.forceAdvance();`
2. Do the identical replacement in `_buildSpectatorVoteUI` (the second copy of the same button).
3. `forceAdvance()` already: guards against double-advance via `_advancedStateKeys`, applies scores through `_advanceRotationOrPhase()`'s vote→reveal branch, resets `readyPlayers`, and clears the timer — so no other change is needed.
4. Optional polish: wrap the button in a confirmation dialog ("End voting now? Unvoted players will score nothing this card.") since it force-advances even if not everyone voted.

**Validation:**
- *Automated (unit):* In a `FakeFirestore` game, cast a known set of votes on a card, call the override path (now `forceAdvance`), then assert each player's `totalScore` matches `ScoringLogic.calculateScores` for that `votes` map. Repeat via the all-ready path and assert **identical** deltas.
- *Manual:* 4-player game; host taps "Proceed to Reveal" with only 2 of 3 votes in. Confirm the reveal screen still shows "POINTS AWARDED THIS CARD" chips and the running `totalScore` increased.

---

## A2 · Issue 3 — Timeouts leave blank/broken cards
**Selected: Option A** — fill placeholders inside `_advanceRotationOrPhase()` before advancing.

**What it means for the player:** If a timer runs out while someone hasn't written their answer, that person's card can end up with a **blank "The Truth" option** (impossible to guess, confusing) or a card with missing lies. The design always promised the game would auto-fill a placeholder so every card stays playable.

**Technical changes** (`lib/services/game_service.dart`, `_advanceRotationOrPhase`):
1. Add a helper that, given the current `GameState`, returns a `cards` list where every **active, non-spectator** player who was assigned a card this phase but has no answer gets a placeholder:
   - Forgery phase: for each `holderId → targetId` in `currentCardAssignments`, if `card(targetId).sabotageAnswers[holderId]` is missing/empty, set it to a placeholder string.
   - Truth phase: for each active player, if `card(playerId).truthAnswer` is empty, set it to a placeholder.
2. Placeholder copy should be thematic, e.g. `"(The ink ran dry…)"` rather than a blank. Keep a single constant `kMissingAnswerPlaceholder`.
3. Apply this **inside the same write** that advances the phase (so the placeholder + phase change are atomic). Do it in both the forgery→(next rotation/truth) branch and the truth→vote branch, computing placeholders against the phase that is **ending**.
4. Because `forceAdvance()` and all-ready both funnel through `_advanceRotationOrPhase()`, this covers both the timer path and any early advance.
5. **Interaction with Issue 5:** once placeholders exist, a card always has the expected number of options, but see A3 — scoring should still derive `S` from real forgery count so a placeholder-filled card scores consistently.

**Validation:**
- *Automated:* Build a forgery state where one active player never submitted; call `forceAdvance`; assert that player's forgery slot on the card they held is now the placeholder and the card has the full option count. Repeat for truth phase → assert no card has an empty `truthAnswer`.
- *Manual:* Start a timed game, leave one player idle through TRUTH, and confirm the vote screen shows no blank option and the reveal shows the placeholder text.

---

## A3 · Issue 5 — Scoring can inflate after a disconnect
**Selected: Option A** — derive the forgery count `S` per-card at scoring time.

**What it means for the player:** The points for "finding the truth" are supposed to scale with how many fake answers were on the card. A bug means that after someone leaves mid-game, the math can jump to the **maximum possible reward** for everyone, making the final scores unfair and unpredictable.

**Technical changes** (`lib/utils/scoring_logic.dart`):
1. In `calculateScores`, stop reading `S` from `state.sabotageAnswersCount`. Instead compute it from the card actually being scored:
   `final int s = currentCard.sabotageAnswers.length;`
2. Keep `P` as the count of players who could vote on this card. Prefer deriving it too: `final int p = currentCard.votes.length + 1` is fragile; instead pass/keep `state.totalPlayers` but document that `S` is now per-card. (Simplest correct choice: `p = state.totalPlayers`, `s = currentCard.sabotageAnswers.length`.)
3. Leave `sabotageAnswersCount` as a pure rotation-config value everywhere else (rotation generation, disconnect capping) — it no longer influences reward math.
4. Update `design_scoring_and_ui.md` §1 with one line: *"`S` in the formula is the number of forgeries actually present on the card being scored."*

**Validation:**
- *Automated:* Unit-test `calculateScores` on a card with exactly 2 forgeries while `state.sabotageAnswersCount == 0` (the corrupted value). Assert `truthReward == ceil((P-1)/3)`, **not** `P-1`.
- *Automated:* Simulate a forgery-phase disconnect that collapses the game to TRUTH, play it out, and assert final scores are within the expected per-card range.

---

## A4 · Issue 6 — "Waiting for N players" never reaches zero with spectators
**Selected: Option A** — count against active non-spectators.

**What it means for the player:** When a spectator is watching, the "Waiting for N players…" counter is inflated and **can never hit zero**, making everyone think the game is stuck when it is actually progressing fine.

**Technical changes:**
1. `lib/screens/phase2_craft.dart` `_buildWaitingUI`: replace
   `int unready = gs.players.length - readyCount;`
   with
   `final activeCount = gs.players.where((p) => p.role != PlayerRole.spectator).length;`
   `final unready = (activeCount - readyCount).clamp(0, activeCount);`
2. `lib/screens/phase3_vote.dart` `_buildWaitingUI`: same replacement.
3. Reuse the existing `totalActive` pattern already present in the spectator views for consistency.

**Validation:**
- *Automated (widget):* Render the waiting UI with 3 active + 1 spectator, 2 ready → label reads "Waiting for 1".
- *Manual:* Join a spectator mid-game; confirm the counter reaches zero when all active players are ready.

---

## A5 · Clarification 1 — Document the saboteur "found the truth" bonus
**Selected: Option A** — keep the bonus, document it.

**What it means for the player:** A player who wrote a fake answer AND still correctly spots the real truth gets a small extra point. This is a real, intended reward — it just was never written in the rules screen, so players couldn't know about it.

**Technical changes (docs + in-app copy only, no logic change):**
1. `docs/design_scoring_and_ui.md` §1: add a bullet under Formulas: *"**Saboteur Insight Bonus:** a saboteur who also correctly votes for the Truth on a card they forged earns +1 in addition to the standard voter reward."*
2. `lib/screens/lobby_screen.dart` `_showInstructions` → the "SCORING (Dynamic)" section: add a bullet mirroring the above in player-friendly language, e.g. *"Sharp Eye: Spot the truth on a card you also faked? Earn a bonus point."*
3. No change to `scoring_logic.dart`.

**Validation:** Manual — open "READ MANUAL" in the lobby and confirm the bonus is listed; cross-check it matches `scoring_logic.dart` behavior (saboteur voting TRUTH gets `truthReward + 1`).

---

## A6 · Issue 7 + Clarification 2 — Meaningful end-game honors
**Selected: Clarification 2 Option A (metric-based honors).** This **supersedes** Issue 7's cosmetic-only Option A: metric-based honors inherently exclude spectators and remove duplicates, so implement the richer version once.

**What it means for the player:** The end screen hands out fun titles ("The Trickster", "Most Gullible"), but today they are just "2nd place" and "last place" by score — and a spectator who never played can be crowned "Most Gullible". Players want titles that reflect **what they actually did**: who fooled the most people, who got fooled the most. This makes the payoff screen land.

**Technical changes:**
1. **Track per-player stats across the game.** Add integer fields to `PlayerState` (and its `toMap`/`fromMap`/`copyWith`): `timesFooled` (how often this player voted for a forgery) and `playersDeceived` (how many voters this player's forgeries fooled, summed over all their cards).
2. **Accumulate at scoring time.** In `GameService._advanceRotationOrPhase`'s vote→reveal branch (where scores are already applied per card), also compute and batch-increment:
   - For each voter who voted for a forgery (not `TRUTH` and not self), `+1` to that voter's `timesFooled`, and `+1` to the forgery author's `playersDeceived`.
   - Do this in the same `applyScoreDeltas` batch (extend it to write these fields too, or add a parallel batch).
3. **Honors selection** (`lib/screens/game_over_screen.dart`): rank only `players.where((p) => p.role != PlayerRole.spectator)`:
   - 🏆 **The Mastermind** — highest `totalScore`.
   - 🃏 **The Trickster** — highest `playersDeceived` (ties broken by score).
   - 🤡 **Most Gullible** — highest `timesFooled` (ties broken by fewest points).
   - Only render an honor if a **distinct** eligible player exists; never show the same player under two honors; guard empty/small lobbies.
4. Update `design_scoring_and_ui.md` Clarification 2 with the final metric definitions.

**Validation:**
- *Automated:* Play a scripted 4-player + 1-spectator game where Bob's forgeries fool 2 voters and Dave votes for forgeries twice; assert Trickster = Bob, Most Gullible = Dave, spectator never selected, no duplicate honoree.
- *Manual:* 2-player game — confirm no player holds two honors and the screen does not crash.

---

# WAVE B — Responsiveness & Robustness

## B1 · Issue 4 — Up to ~10s of dead air between phases
**Selected: Option A** — also evaluate readiness from the room-document listener.

**What it means for the player:** After the last person submits, the game can **sit frozen for up to ten seconds** before moving on, because the host only re-checks "is everyone ready?" on a slow background heartbeat. It should advance the instant the last player is ready.

**Technical changes** (`lib/services/game_service.dart`, `listenToRoom`):
1. In the **room** snapshot listener (the `_roomSubscription` handler), after `_gameState = GameState.fromMap(...)` and `notifyListeners()`, add: `if (currentPlayer?.isHost == true) { evaluateReadyState(); }`.
2. `evaluateReadyState()` is already idempotent via `_advancedStateKeys`, so the extra call is safe.
3. Guard for early snapshots where `currentPlayer` may be null (the `?.` handles it).
4. Optionally remove the now-unnecessary dead `isReady` player-doc write in `debugSimulateBotResponses` (it exists only to poke the players listener); leaving it is harmless.

**Validation:**
- *Automated:* Two `GameService` instances (host + one player). Mark all ready via room writes only (no heartbeat tick); assert the phase advances without waiting for a heartbeat.
- *Manual:* Two devices; confirm the phase flips immediately after the last submit, not after a visible pause.

> **Wave C note:** When mutations move to Cloud Functions (Issue 1), this becomes moot — the function that records the last readiness will advance the phase in the same transaction. Keep this fix for the interim; retire it in Wave C.

---

## B2 · Issue 8 — "Start Game" silently does nothing
**What it means for the player:** If the host taps **START GAME** with too few players (or picks more forgery rounds than there are players, or a small deck with too many players), **nothing happens and no message appears**. The host is left tapping a dead button with no idea why.

**Technical changes:**
1. `lib/services/game_service.dart` `startGame`: replace silent `return`/`throw` with a typed result. Simplest: keep it `async` but always `throw` a descriptive `Exception` for every failure (too few players, `players.length <= sabotageAnswersCount`, deck too small), and remove the silent `if (... < 2) return`.
2. `lib/screens/lobby_screen.dart`: `await` the call inside a `try/catch` and show a `SnackBar` with the message; only navigate on success. Also disable START (or show a hint) until `players.length >= 2` and `players.length > selectedRounds`.
3. Add a lobby-side pre-check surfacing the deck capacity (e.g. disable decks that can't supply one prompt per player, or show "Needs a bigger deck for N players").

**Validation:**
- *Automated:* Call `startGame` with 1 player → expect thrown exception; with `rounds >= players` → exception; assert the lobby handler shows a SnackBar (widget test).
- *Manual:* Try to start with 1 player and with 5 rounds/3 players; confirm a clear message each time.

---

## B3 · Issue 9 — A leaving player can be processed multiple times
**What it means for the player:** When someone drops out, the recovery logic can run **several times at once for the same person**, which can double-remove cards, over-shrink the number of rounds, or scramble who-writes-for-whom — occasionally corrupting the game after a disconnect.

**Technical changes** (`lib/services/game_service.dart`):
1. Add an in-flight guard set: `final Set<String> _disconnectsInFlight = {};`.
2. In the players-listener disconnect loop, skip IDs already in flight: `if (_disconnectsInFlight.contains(dpId)) continue; _disconnectsInFlight.add(dpId);`.
3. In `handlePlayerDisconnect`, wrap the body in `try/finally` and `_disconnectsInFlight.remove(disconnectedPlayerId)` in the `finally` **after** the `updateGameState` completes.
4. Additionally make `handlePlayerDisconnect` idempotent: early-return if the player's card is already gone (`!state.cards.any((c) => c.targetPlayerId == disconnectedPlayerId)`), so a late duplicate is a no-op.
5. Long-term: this fully resolves once mutations are server-side (Wave C), where a transaction makes disconnect handling atomic.

**Validation:**
- *Automated:* Fire the disconnect detection twice synchronously for the same player; assert `cards` shrinks by exactly one and `sabotageAnswersCount` is decremented at most once.
- *Manual:* Kill a bot mid-forgery; confirm exactly one card is removed and rotations look sane.

---

## B4 · Issue 10 — Host handoff picks a semi-random player (maybe a spectator)
**What it means for the player:** If the host leaves, the "new host" is supposed to be the longest-standing player. In reality it's chosen essentially at random (by internal ID order) and **could even be a spectator who isn't playing** — which can stall the game because that person has no reason to drive it.

**Technical changes** (`lib/services/game_service.dart`, host-transfer block in `listenToRoom`):
1. Record join order: set a `joinedAt` (epoch ms) field on `PlayerState` when a player is created in `createRoom`/`joinRoom`; include in `toMap`/`fromMap`.
2. When no host exists, select the new host as the **non-spectator** player with the smallest `joinedAt` (fallback to smallest `id` if `joinedAt` is null for legacy docs):
   `final candidates = _players.where((p) => p.role != PlayerRole.spectator).toList()..sort((a,b)=> (a.joinedAt ?? 0).compareTo(b.joinedAt ?? 0));`
   Promote `candidates.first`; if none, fall back to `_players.first`.
3. Update `design_database_and_security.md` "Host Transfer Logic" to state selection is by earliest `joinedAt` among active players.

**Validation:**
- *Automated:* Build a room with host + 2 players + 1 spectator; delete the host; assert the earliest-joined **non-spectator** becomes host.
- *Manual:* Host leaves mid-game; confirm a playing (not spectating) player takes over and the game continues.

---

## B5 · Issue 11 — Rejoin locks the player out after an identity change
**Selected: Option A** — stable local player ID decoupled from auth. *Note: the full Option A lands with Wave C (it needs server-side ownership validation); ship an interim guard now.*

**What it means for the player:** A player's seat is tied to their invisible anonymous account. If that account is lost (cleared web storage, reinstall, a failed silent sign-in), the app makes a new identity and the returning player is **locked out of their own seat** — they show up as a stranger who can't edit their record.

**Why this is split across two waves:** today's rules require `request.auth.uid == playerId` to write your own player doc, so a *stable* UUID playerId (Option A's core) can't work until ownership is validated server-side (Wave C). Do the durable fix there; do a small safety guard now so no one hits the silent locked-out state in the meantime.

**Interim (do now, `lib/services/game_service.dart` `tryRejoinSession`):**
1. After resolving `currentUser?.uid`, compare it to the cached `player_id`. If they differ (identity changed), **do not** silently restore: clear the saved `room_code`/`player_id`, return `false`, and let the lobby show a friendly "Your session expired — please rejoin" `SnackBar`.
2. This converts a broken, unwritable restored state into a clean restart (Option B's behavior) as a stopgap.

**Durable (do in Wave C, see C1/C2/C3):**
1. Generate a UUID `playerId` once per device, persist in `SharedPreferences`, keep it stable across auth changes.
2. Store the current `authUid` on the player doc; server callables validate `context.auth.uid == player.authUid` for ownership instead of `uid == playerId`.
3. Update `firestore.rules` so ownership no longer keys on `uid == playerId` (functions enforce it).
4. Add `playerId` + `authUid` to `PlayerState` serialization.

**Validation:**
- *Interim:* Simulate `currentUser.uid` changing between sessions; assert `tryRejoinSession` returns `false` and clears prefs (no restored, unwritable session). Manual (web): clear site data mid-lobby, reload → land cleanly on the entry screen with the message.
- *Durable (Wave C):* With the stable-ID model, simulate an auth-uid change and assert the player can still write via callables and keeps their seat/score.

---

# WAVE C — Production Multiplayer & Security (Issue 1)

**Selected: Option A (host-authoritative) — overridden by your note to use the Firebase industry standard for a scalable App Store game.** Accordingly this plan implements **Option D: Server-Authoritative via Cloud Functions**, which is the standard, cheat-resistant pattern for a public multiplayer Firebase game. (See the added Option D in `ongoing_general_errors.md` Issue 1.)

**What it means for the player / business:**
- **Today real multiplayer is broken:** only the host's phone is allowed to write the shared game; everyone else is silently rejected, so a second real player can't submit, vote, or ready up.
- **Why not just "let the host run it":** the host is only a player's phone. A modified host app could rewrite everyone's scores and answers. For an App Store game meant to scale, you want a **neutral referee** that no player can tamper with.
- **The fix:** move the *rules of the game* onto a small trusted server (Firebase Cloud Functions). Players ask the server to "submit my answer" / "cast my vote"; the server checks it's really them, enforces the rules, and updates the game. Players can **read** the game live (fast) but can't **write** it directly. This is the same pattern used by production Firebase multiplayer apps, scales automatically, and also lets us hide the Gemini API key on the server (closing the key-exposure risk the README already flags).

### C0 · Prerequisites & scaffolding
1. Initialize Cloud Functions: `firebase init functions` (TypeScript). Add the `firebase_functions`/`cloud_functions` Flutter plugin (`cloud_functions` package) to `pubspec.yaml`.
2. Set up the Firebase Emulator Suite (Auth + Firestore + Functions) for local, rules-enforced testing — this is also what closes the **testing blind spot** (today's tests never exercise a non-host writer).
3. Move the Gemini embedding call into the functions runtime; store the key in Functions config/Secret Manager, not `.env` on the client.

### C1 · Port the game rules to the server
Re-implement these as callable functions (`onCall`, validating `context.auth.uid`). **Mirror the Wave A/B logic exactly** — this is where the earlier fixes must be reproduced:
| Callable | Replaces client method | Must re-implement |
|----------|------------------------|-------------------|
| `submitAnswer` | `submitCardAnswer` | semantic-similarity check (A5 unchanged), write into `cards` |
| `castVote` | `castVote` | self-vote guard, one-vote-per-card, mark ready |
| `setReady` | `setPlayerReady` | readiness map |
| `advancePhase` | `evaluateReadyState`/`forceAdvance`/`_advanceRotationOrPhase` | **placeholder fill (A2)**, **per-card `S` scoring (A3)**, **saboteur bonus (A5)**, **honor stats (A6)**, instant advance when all ready (B1) |
| `startGame` | `startGame` | rotation generation, deck draw, validation with descriptive errors (B2) |
| `handleDisconnect` | `handlePlayerDisconnect` | idempotent, atomic (B3) |
Port `rotation_engine.dart` and `scoring_logic.dart` to TypeScript (they are pure functions — straightforward) and unit-test them to match the Dart versions.

### C2 · Lock down security rules (`firestore.rules`)
- `/rooms/{roomCode}`: `allow read: if true;` (or `if isAuthenticated()`); `allow write: if false;` — **no client writes the room doc**; only functions (admin SDK) do.
- `/rooms/{roomCode}/players/{playerId}`: `allow read: if true;` `allow create, update: if isOwner(playerId)` for **cosmetic self fields only** (name, avatar, color, lastSeen) via field validation; `totalScore`/`role`/honor stats/`isHost` writable only by functions. Use `request.resource.data.diff(resource.data).affectedKeys()` to restrict which fields a client may change.
- Delete/host-transfer handled by functions.

### C3 · Client refactor
1. `GameService.submitCardAnswer/castVote/setPlayerReady/startGame/handlePlayerDisconnect` become thin wrappers that call the corresponding callable and `await` the result.
2. Keep the read path unchanged: clients still `snapshots()`-listen to the room and players for instant UI.
3. Heartbeat: clients still write **their own** `lastSeen` (allowed); a scheduled function (or the `advancePhase` call) prunes stale players server-side.
4. Remove host-only advancement branches from the client (server owns advancement); the host UI buttons become "request advance" callables usable by any authorized driver, or are removed.

### C4 · Validation
- *Automated (emulator):* Integration test with **two** authenticated clients (host + joiner) against the Functions+Firestore emulator; assert the joiner can `submitAnswer`, `castVote`, `setReady` and the game advances — the exact path that is impossible today.
- *Automated:* Rules unit tests (`@firebase/rules-unit-testing`) asserting a client **cannot** write `totalScore` or another player's doc, and cannot write the room doc.
- *Automated:* Port the existing `simulation_test.dart` scenarios to drive callables instead of direct writes; keep 10-player, spectator, disconnect, and semantic-filter coverage.
- *Manual:* Two physical devices on the store build: full 4-player loop end-to-end; verify no `PERMISSION_DENIED`, correct scores, and that a tampered client cannot change another player's score.

### C5 · Interim option (optional, if you want friend playtests before the backend is ready)
If you need multiplayer working within a day for informal playtests, implement the original **Option A host-authoritative relay** as a temporary shim (non-hosts write only their own player doc; host merges). It is not cheat-resistant and should be **removed** when Wave C lands. Recommend skipping this unless a near-term playtest is required.

---

## Definition of Done (all waves)
- [x] Waves A & B merged; `flutter test` green; new unit/widget tests added per item. *(verified July 10–12)*
- [ ] Two-client emulator integration test passes (proves non-host multiplayer works). *(NOT built — open Issue 15)*
- [ ] Rules unit tests prove clients cannot tamper with scores/other players/room. *(NOT built — open Issue 15)*
- [x] Wave A/B rule changes verified **mirrored** in the Cloud Functions. *(verified July 12 — scoring, placeholders, honors, disconnect, host transfer all present in `functions/src/`)*
- [ ] `docs/ongoing_general_errors.md` issues moved to the Resolved section per the `resolved_issue_cleanup` skill; design docs updated where behavior changed. *(done for Issues 2–12; Issue 1 stays open pending Issues 13 + 15)*

> **Wave C verification status (July 12):** implemented but NOT done. The callables `submitAnswer`/`castVote`/`setReady` contain a fatal read-after-write transaction-ordering bug (**Issue 13** in `ongoing_general_errors.md`) that makes the backend unplayable, and the C4 validation above was skipped (**Issue 15**). See `docs/agent_execution_guide.md` for the remediation order (R1/R2 first).
