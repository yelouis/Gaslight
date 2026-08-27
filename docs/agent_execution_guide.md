# Agent Execution Guide — Active Build: Wave P — Wave O repair + playtest requests (Issues 122–132) — August 27, 2026

**You are an engineering agent with no memory of this project.**

**All eleven selections are made.** Build exactly these, in this order.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **P1** | Repair the red functions gate | **122 → A** | test only | — |
| **P2** | An empty resolution order must not produce a reader-less vote phase | **125 → A** | server | ✅ |
| **P3** | Enforce the presence window on the server; delete the client's copy | **123 → A** | server + client | ✅ |
| **P4** | Withhold the delta map until the unmask window closes | **124 → A** | server + client | ✅ |
| **P5** | Timers off by default; host sets the length | **130 → A** | server + client | ✅ |
| **P6** | Re-roll snackbars stop queueing | **127 → A** | client | — |
| **P7** | Tell the table when someone leaves | **128 → A** | client | — |
| **P8** | Peek inside a deck before choosing it | **126 → A** | client | — |
| **P9** | One vote option per row | **132 → A** | client | — |
| **P10** | Return key submits, and the button is always reachable | **131 → C** | client | — |
| **P11** | One line per screen saying what you are trying to do | **129 → A** | client | — |

**P1–P5 are the server batch; land them as five commits and the user deploys once.** P6–P11 are client-only and need no deploy. **Do not run `firebase deploy` yourself** — that call is the user's, and it is what makes P2–P5 real.

**One item = one commit** — eleven commits, not one.

**Every number, range and literal string below is a decision, not a suggestion.** Implement as written. If a value is impossible, keep the intent, deviate minimally, and say so in the commit body.

---

## 0. Ordering, and why each position is what it is

1. **P1 first, always.** The battery is red right now (`npm --prefix functions test` → 80 passing, 1 failing). Every item after this one is validated by "the suite was green and stayed green"; that sentence is meaningless until P1 lands.
2. **P2 before P3.** A ten-minute presence window keeps absent players seated, and absent players generate placeholder answers. P2 is what stops an all-placeholder round stranding the table. This is the same dependency Wave O got right as "O4 before O5" — it was correct then and it is correct now.
3. **P4 after P2/P3** only because it is independent; group it in the server batch so there is one deploy.
4. **P5 last in the server batch.** It flips the default timer state, which changes how easily a manual playtest reaches the placeholder paths P2 fixes. Validate P2–P4 against today's defaults, then flip in a single easily-reverted commit.
5. **P9 before P11, and P10 before P11.** P9 restructures the vote grid and P10 restructures the craft screen's bottom. P11 adds copy to both. Adding copy to a settled layout costs one line; adding it first means re-tuning it twice.
6. **P6 before P7.** P7 shows a snackbar on departure and must follow the clear-before-show rule P6 establishes. Written the other way round, P7 reintroduces exactly the bug P6 fixes.

---

## 1. Standing constraints

- **One item = one commit**, Conventional Commit, WHY in the body.
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated. Regenerate with `./scripts/generate_prompt_decks_dart.sh`.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Read a gate's exit code bare, never through a pipe.** `./scripts/check_deploy_fresh.sh | tail -6` reports `$?` from `tail`, which is always `0`.
- **Grep the existing suite for tests that assert the rule you are changing**, before writing new ones. This is what Wave O missed and it is why P1 exists.
- **Assert behaviour, never a constant's own literal** (lesson 2.30).
- **When you change a constant, grep the other language for its literal value**, not its name (lesson 2.31).
- **Clients omit keys rather than sending `null`; callables guard with loose `!= null`, never a falsy check** (lesson 2.1) — `false` and `0` are legitimate values.
- **A `grep` is not an observation.** Open the artefact.
- **Do not touch anything in §14 or §15.**

---

## 2. P1 — Repair the red functions gate (122 → A)

**What this means for the user:** nothing directly — but until this is green, no later claim that "the suite passes" carries information.

**The gap.** `npm --prefix functions test` fails one test:

```
1) Gaslight E2E Game Emulator Tests
     should handle timeout and fill missing slots with placeholder:
   Error: Cannot vote for a placeholder answer.
    at async Context.<anonymous> (test/game_e2e.spec.ts:1088:9)
```

The test begins at `functions/test/game_e2e.spec.ts:994`. It deliberately has `p_guest2` time out on their truth, then at `:1083` reads `const truthOptId = sealedSnap.data()?.truthAnswerId || 'TRUTH';` and casts **every** vote at that option. When `currentReaderId` is `p_guest2` — and the resolution order is shuffled, so it often is — that option's text is `THE SOUL IS SILENT`, and `castVote` rejects it at `functions/src/index.ts:913`.

**The guard is correct.** The test encodes the pre-O4 rule.

**Implementation**

1. In that test only, stop voting at `truthOptId` unconditionally. After the phase reaches `vote`, read the current reader's card from `room.cards` and pick the voted option like this:
   - Read `card.options`.
   - Filter to options whose `text !== 'THE SOUL IS SILENT'` and whose text is non-empty.
   - **Assert that filtered list is non-empty** before using it — `expect(votable.length).to.be.greaterThan(0)`. If it is ever empty the test's premise has changed and it must fail loudly, not silently vote for nothing.
   - Each voter votes for the first entry of that list that is **not their own answer** (resolve via the `sealed/{reader}.answerAuthors` map, which the test already reads at `:1082`). `castVote` rejects self-votes at `index.ts:903`, so picking blind will flake.
2. **Leave every existing assertion in place** — in particular the three at the end of the test (`guestSealedSnap...truthAnswer === 'Guest truth'`, `hostSealedSnap...truthAnswer === 'Host truth'`, and `expect(Object.values(hostSealedSnap.data()?.sabotageAnswers || {})).to.include('THE SOUL IS SILENT')`). Those are the test's actual subject and the only coverage of the timeout-fill mechanism.
3. **Check the three sibling call sites** that use the same `truthAnswerId || 'TRUTH'` pattern — `:217`, `:1232`, `:2181`. They are green today because every player submits a truth in those tests. **Do not change them.** Note in the commit body that you checked them and why they are not at risk.

**Validation**
- `npm --prefix functions test` → **81 passing, 0 failing.**
- **Run the test five times in a row.** The resolution order is shuffled (`index.ts:1469`), so a fix that works for one seat assignment and not another will pass once and fail in CI. Five consecutive green runs is the bar; paste the count into the commit body.
- **Over-reach guard:** the two O4 tests (`O4: castVote throws invalid-argument…` and `O4: skips card from resolutionOrder…`) still pass unchanged. You must not have loosened the guard.

**Blast radius:** `functions/test/game_e2e.spec.ts` only. No production code changes. **No deploy.**

---

## 3. P2 — An empty resolution order must not produce a reader-less vote phase (125 → A)

**What this means for the user:** if a whole table goes quiet for a round, the game moves on instead of parking everyone on a blank screen nobody can leave.

**The gap.** `advancePhaseInternal` filters unvotable cards out of the resolution order at `functions/src/index.ts:1476`, then writes the vote phase unconditionally:

```ts
currentReaderId: validResolutionOrder.length > 0 ? validResolutionOrder[0] : null,
resolutionOrder: validResolutionOrder,
```

When every card is all-placeholder the filter empties the list and the room enters `vote` with a null reader. Proven in the emulator:

```
PROBE phase           = vote
PROBE resolutionOrder = []
PROBE currentReaderId = null
```

`lib/screens/phase3_vote.dart:134` then leaves `currentCard` null and the screen has nothing to render and no control that advances. The host *can* escape via `advanceToNextResolution`, but no UI offers it, and with P5's timers-off default nothing fires automatically.

**Implementation**

1. Extract the round-advance / game-over logic currently living inside the `advanceToNextResolution` callable (`index.ts:1810` onward — the `else` branch that either deals the next round or writes `gameOver`) into a **shared helper**, e.g. `async function concludeResolutionRound(transaction, roomRef, room, players)`. Move it; do not copy it. Two copies of the round-advance will diverge, and this codebase has already paid for that with the deck catalogue.
2. In `advancePhaseInternal`, where `validResolutionOrder` is computed: **if it is empty, call the shared helper instead of writing the vote phase.** The room must go straight to the next round, or to `gameOver` on the final round.
3. **Firestore transaction rule applies:** all reads must precede all writes. The helper reads the `sealed` docs for every active player (`index.ts:1820`). If you call it from inside `advancePhaseInternal` after that function has already written, the transaction throws. **Hoist the helper's reads to the top of `advancePhaseInternal`, or perform the empty-order check before any write in that branch.** This is the single most likely way to get P2 wrong.
4. Leave the existing skip-ahead loop in `advanceToNextResolution` (`:1788`) alone. It handles the partial case and still earns its place.

**Validation**
- **Emulator, the falsifying test:** three players, nobody submits a truth, nobody submits a forgery, two `advancePhase` calls. Assert the room's phase is **`gameOver`** (with `totalRounds: 1`) and that `currentPhase` was **never** observed as `vote` with an empty `resolutionOrder`. **Run it against the current code first and watch it fail** with `phase = vote, resolutionOrder = []`; paste that output into the commit body.
- **Emulator, multi-round:** same scenario with `totalRounds: 2` — assert the room reaches round 2's `truth` phase, with fresh cards dealt and `currentRound === 2`.
- **Over-reach guard:** a normal round where every player answers is completely unaffected — same `resolutionOrder` length as the player count, same reader, same scoring. **And the partial case still works:** one all-placeholder card among three is skipped while the other two resolve normally. That is the existing `O4: skips card from resolutionOrder…` test; it must still pass unchanged.
- **A round that vanishes needs to say so.** Add a brief client-side surface: when the phase advances past a round in which no card was resolvable, the next screen shows a one-off note — `'Nobody answered last round. Dealing a new one.'` Use the snackbar rule from P6 (clear first, ~2 s). Without it, players read a vanished round as a crash.

**Blast radius:** `functions/src/index.ts` (`advancePhaseInternal`, `advanceToNextResolution`, the new helper) · `functions/test/game_e2e.spec.ts` · the client note above. `docs/design_game_state_and_models.md` describes the phase sequence and must record that a round with no votable card is skipped entirely.

---

## 4. P3 — Enforce the presence window on the server; delete the client's copy (123 → A)

**What this means for the user:** locking your phone for five minutes no longer loses your seat. Today it loses it after two.

**The gap — two independent causes. Fixing either alone leaves the window inert.**

1. `lib/services/game_service.dart:20` still declares `static const int presenceStaleMs = 120000;`, and `:457` is what decides who gets reported.
2. `functions/src/index.ts:1155` uses `isDead` **only inside the authorization condition**:
   ```ts
   if (!callerPlayer || (!callerPlayer.isHost && callerPlayer.id !== disconnectedPlayerId && !isDead)) {
   ```
   A host is authorized unconditionally, so the deletion proceeds no matter how recently the player was seen. `isDead` has only ever decided whether a *peer* may evict someone.

Proven in the emulator — a player stale by 150 s, well inside the nominal 600 s window:

```
PROBE handleDisconnect (as HOST) returned = {"success":true}
PROBE Charlie still in the room? = false
PROBE VERDICT: 10-minute window DID NOT protect him
```

**Implementation**

1. **Add an explicit `reason` to the `handleDisconnect` contract.** Destructure it at `index.ts:1120` alongside `roomCode` and `disconnectedPlayerId`. Exactly three legal values — implement them as a union and reject anything else with `invalid-argument`:
   - `"leave"` — the player is removing themself. Requires `callerPlayer.id === disconnectedPlayerId`.
   - `"kick"` — the host is removing someone deliberately. Requires `callerPlayer.isHost`.
   - `"presence"` — a client observed a stale seat. **This is the only one the window gates.**
2. **Gate the action, not the caller.** For `reason === "presence"`, after the authorization check, compute staleness and **return early without deleting** when the player is inside the window:
   ```ts
   if (reason === "presence" && !isDead) {
     return { success: false, reason: "still-present" };
   }
   ```
   **Return; do not throw.** The client's call site swallows errors (`.catchError((_) {})`), so a thrown rejection would be invisible, and this path fires constantly.
3. **`"leave"` and `"kick"` are never time-gated.** A host kick must take effect immediately; so must a voluntary departure.
4. **Do not break the reconciliation path.** `game_service.dart:548` (`handlePlayerDisconnect`) is called by the host when a *card* references a player whose document is already gone. There `disconnectedPlayer` is `undefined`, so `isDead` is falsy — a naive "not stale ⇒ refuse" would deadlock the cleanup forever. Send `reason: "kick"` from that call site, or add a fourth value `"reconcile"` that skips the window check when the player document does not exist. **State which you chose and why in the commit body.**
5. **Backwards compatibility.** Builds already on testers' phones send no `reason`. Treat a missing `reason` as `"presence"` — the safe default, because it is the only one the window protects. An old client then behaves correctly the moment the server is deployed, without an app update. Say this in the commit body.
6. **Client:** delete `presenceStaleMs` from `game_service.dart:20` entirely. The filter at `:452–458` stops deciding staleness — it should report **any** peer whose `lastSeen` is older than a generous local interval (use **60 seconds**) and let the server decide. Removing the constant is the point: it is the thing that drifted.
7. Pass the right `reason` at all four call sites: `:399` → `"leave"`, `:415` → `"kick"`, `:461` → `"presence"`, `:548` → per step 4.

**Validation**
- **Emulator, the falsifying test — this is the one that maps to the symptom.** Set a player's `lastSeen` to `Date.now() - 150_000`, call `handleDisconnect` **as the host** with `reason: "presence"`, and assert the player document **still exists**. **Run it against the current code first and watch it fail**; paste both the failing and passing output into the commit body. This is the assertion Wave O did not have — `expect(PRESENCE_STALE_MS).to.equal(600_000)` cannot fail (lesson 2.30), so **delete that test and replace it with this one.**
- **Boundary:** stale by 601 s with `reason: "presence"` → the player **is** removed. Both sides of the boundary, or you have tested nothing.
- **Over-reach guards, all three:** a `"leave"` call for a player seen 1 second ago still removes them; a `"kick"` by the host for a player seen 1 second ago still removes them; a **peer** (non-host, not themself) calling `"presence"` on a fresh player is still rejected with `permission-denied`.
- **Regression:** the reconciliation path still cleans up a card whose player document is gone. Assert the card disappears.
- **Client:** `grep -rn "120000\|120_000\|presenceStaleMs" lib/` returns **nothing**. Add this grep to the commit body.

**Blast radius:** `functions/src/index.ts` (`handleDisconnect`) · `lib/services/game_service.dart` (four call sites + the deleted constant) · `functions/test/game_e2e.spec.ts` · `docs/design_database_and_security.md` §4–§5 currently carries a ⚠️ block saying the window is not in force — **replace it with the real behaviour, including the `reason` values and which ones the window gates.**

---

## 5. P4 — Withhold the delta map until the unmask window closes (124 → A)

**What this means for the user:** during the twenty seconds when you are guessing who wrote the answer that fooled you, the answer is no longer sitting in the room data.

**The gap.** `index.ts:1623` publishes `scoreDeltas: calculatedDeltas` inside the branch (`:1610`) whose entire purpose is to withhold authorship — the same branch sets `sabotageAnswers: {}` and rewrites votes to opaque UUIDs. `ScoringLogic.calculateScores` credits `deltas[votedForId] += 1` per person fooled (`functions/src/scoring_logic.ts:116`), so a non-target player with a positive delta **is** a forger who fooled someone:

```
PROBE window open? = true
PROBE sabotageAnswers (withheld) = {}
PROBE votes (obfuscated) = {"p_g1":"71ce3cc2-...","p_g2":"p_host"}
PROBE scoreDeltas (published) = {"p_g2":3,"p_host":1}
PROBE actual forgerId = p_g2  -> identifies forger? true
```

This re-opens **Issue 100**.

### ⚠️ Read this before you write anything — the naive fix ships a regression

The obvious change is "publish on window close instead of at reveal." **The window has no server-side close.** Trace it:

- `index.ts:1594` sets `unmaskDeadline = Date.now() + 20000`.
- `submitUnmaskGuess` sets `nextUnmaskDeadline = 0` **only when every fooled player has guessed** (`:2015`).
- When nobody guesses, **the deadline simply passes.** No server write ever happens. The client decides the window is over on its own wall clock (`lib/screens/phase4_reveal.dart:60–68`, `:88`) and renders `revealStage >= 4`.

So if you withhold the map and publish it only in `submitUnmaskGuess`, then in every round where the window times out, **the points tray and the standings deltas render empty** — silently undoing Issue 113, which is what O2 was built for.

**The fix therefore has to give the window a real server-side close.**

**Implementation**

1. **Stop publishing during the window.** At `:1623` (the `unmaskDeadline !== null` branch) **omit `scoreDeltas` entirely** — omit the key, do not write an empty map, so the leak guard can assert `to.be.undefined` the same way the unrevealed-card guard already does. `:1637` (the nobody-was-fooled branch, where `unmaskDeadline` is `null` and authorship is published immediately) **keeps** publishing — there is no secret there.
2. **Stash the computed deltas where clients cannot read them.** Write `calculatedDeltas` to `sealed/{targetPlayerId}.pendingScoreDeltas` in the same transaction. The `sealed` collection is default-deny by having no `match` block (§15) — that is why it is the right home. **Do not invent a new collection.**
3. **Add a `closeUnmaskWindow` callable.** Any authenticated member of the room may call it. In a transaction it must:
   - Load the room. If `unmaskDeadline` is `null` or `0`, **return `{ success: true, alreadyClosed: true }`** — idempotent, no error. Several clients will call this at once.
   - **Verify `Date.now() > room.unmaskDeadline`.** If not, throw `failed-precondition`. A client must never be able to close the window early — that is the same bound as `castVote`: *never let a client bound exceed the server's*.
   - Read `sealed/{currentReaderId}.pendingScoreDeltas`, write it onto the current card as `scoreDeltas`, and set `unmaskDeadline: 0`.
4. **In `submitUnmaskGuess`, publish only when the window actually closes.** `:2015` (the `allFooledGuessed` branch, which already sets `nextUnmaskDeadline = 0`) publishes the full map — that branch is correct as written. `:2022` (the else branch, window still open) **must stop publishing `scoreDeltas`.** Its running `nextScoreDeltas` accumulation must instead be written to `sealed/{...}.pendingScoreDeltas`, so an unmask ±1 that lands mid-window is still reflected when the window closes.
5. **Client:** in `phase4_reveal.dart`, where the screen already detects the deadline passing (`:88`), call `closeUnmaskWindow` once per card. Guard it with a `Set<String>` of card ids already requested so a rebuild does not spam it — the same shape as `_disconnectsInFlight` in `game_service.dart`. Keep the existing `?? const <String, int>{}` fallback at `:260`; the map is legitimately absent for a moment.

**Validation**
- **Leak guard, the falsifying test:** advance to reveal on a card where someone was fooled; assert `unmaskDeadline > Date.now()` **and** `card.scoreDeltas` is `undefined` in the same snapshot. Both assertions, in that order — asserting absence without proving the window was open proves nothing. **Run it against the current code first and watch it fail** with the probe output above.
- **The regression this item is most likely to cause:** a round where **nobody guesses**. Advance to reveal, wait past the deadline, call `closeUnmaskWindow`, and assert `card.scoreDeltas` is now the full correct map. **If you skip this test you will ship an empty points tray.**
- **Correctness:** on a card where a player is both scored and unmasked, the published delta equals card points **plus** the unmask adjustment — computed in the test from the votes and guesses it cast, **not** read back from the summary. The existing O2 test asserts `forgerId → 3` then `→ 2` after a successful guess; keep that arithmetic and move the reads to after the close.
- **Early-close guard:** calling `closeUnmaskWindow` **before** the deadline throws `failed-precondition` and leaves `scoreDeltas` absent.
- **Idempotency:** calling it twice succeeds twice and does not double-apply anything.
- **Over-reach guard:** a card where **nobody** was fooled still publishes `scoreDeltas` immediately at reveal (`unmaskDeadline` is `null`), exactly as today.
- **Widget test:** the reveal screen renders the tray and the standings deltas correctly once the map arrives, and renders without exception while it is absent.

**Blast radius:** `functions/src/index.ts` (reveal branch, `submitUnmaskGuess`, new callable) · `lib/screens/phase4_reveal.dart` · `lib/services/game_service.dart` (the new callable wrapper) · `functions/test/game_e2e.spec.ts` · `test/phase4_reveal_test.dart` · `firestore.rules` **if** `sealed` needs anything (it should not — default-deny is what we want) · `docs/design_scoring_and_ui.md` §3.3 carries a ⚠️ block saying the rule is aspirational — **replace it, and document the new close path as part of the five-beat reveal.**

---

## 6. P5 — Timers off by default; the host sets the length (130 → A)

**What this means for the user:** a new room is untimed, which is how most tables want to play. Turning timers on lets the host pick how long a round gets.

**The gap.** `isTimerDisabled` defaults to `false` — i.e. timers **on** — at four sites: `lib/models/game_state.dart:69` and `:182`, and `functions/src/index.ts:365` (`createRoom`) and `:1731` (`updateLobbySettings`). Durations are hardcoded and not configurable: truth `60000` (`:668`, `:1231`, `:1870`), `forgeryDuration = 60000` (`:1309`), `voteDuration = 45000` (`:1310`), resolution `45000` (`:1801`).

**Implementation**

1. **Flip the default at all four sites** so `isTimerDisabled` is `true`. A new room starts untimed.
2. **Add `timerSeconds` to the room.** Default **60**. Server-side, clamp to **15–300** inclusive and reject anything outside with `invalid-argument`; a client bound is a suggestion. Accept it in `createRoom` (`:365`) and `updateLobbySettings` (`:1684`), guarding with loose `!= null` (lesson 2.1) — `0` must not be silently swallowed, it must be *rejected*.
3. **Derive the three phase durations from it**, preserving today's 60/60/45 proportions:
   - truth: `timerSeconds * 1000`
   - forgery: `timerSeconds * 1000`
   - vote: `Math.round(timerSeconds * 0.75) * 1000`
   Replace all six hardcoded sites. **`:1801` (`advanceToNextResolution`, currently 45000) is the vote duration** — it re-enters the vote phase for the next card. Use the vote formula there, not the truth one.
4. **Lobby UI** (`lib/screens/lobby_screen.dart:753–765`): keep the `Disable Game Timers` switch. When it is **off** (timers on), reveal a numeric field beneath it labelled **`Seconds per round`**, defaulting to 60. Host-only, like every other lobby setting. Validate 15–300 on the client too and show the clamp in the helper text: **`15–300 seconds. Voting gets 75% of this.`** — the derivation must be visible, or a host who sets 60 and sees a 45-second vote timer will file it as a bug.
5. **Dart plumbing:** add `timerSeconds` to `GameState` (field, constructor default `60`, `copyWith`, `toMap`, `fromMap` with `?? 60`) and to `GameService.updateLobbySettings`, following the existing omit-if-null pattern at `game_service.dart:498–510`.
6. **A room in progress keeps the settings it started with.** Durations are read per-phase-transition, so a mid-game change would take effect immediately — that is fine and no special handling is needed, but say so in the commit body so nobody "fixes" it later.

**Validation**
- **Emulator:** `createRoom` with no `isTimerDisabled` → the room has `isTimerDisabled: true` and `endTime: null` after `startGame`. **This is the falsifying assertion for the default flip**; run it against the current code and watch it fail.
- **Emulator:** with timers enabled and `timerSeconds: 40`, assert the truth `endTime` is ~40 s out and the vote `endTime` is ~30 s out (assert the **difference from `Date.now()`** within a tolerance, never an absolute timestamp).
- **Emulator, both boundaries:** `timerSeconds: 14` and `timerSeconds: 301` are rejected with `invalid-argument`; `15` and `300` are accepted.
- **Widget test:** the seconds field is hidden when `isTimerDisabled` is true and shown when false; a non-host sees neither control enabled.
- **Over-reach guard:** an existing room document with no `timerSeconds` field behaves exactly as a 60-second room. Old rooms must not break.

**Blast radius:** `functions/src/index.ts` (four default sites, six duration sites, two callables) · `lib/models/game_state.dart` · `lib/services/game_service.dart` · `lib/screens/lobby_screen.dart` · `functions/test/game_e2e.spec.ts` · any existing test that assumes timers default on — **grep the suites for `isTimerDisabled` and `endTime` before you start**; §10 of this guide and the playthrough procedure both record "Disable Game Timers **on**" as a manual deviation, which becomes the default and must be updated.

---

## 7. P6 — Re-roll snackbars stop queueing (127 → A)

**What this means for the user:** Brian tapped re-roll several times and the confirmation kept reappearing for half a minute afterwards, following him onto the next screen. That stops.

**The gap.** `lib/screens/phase2_craft.dart:567` shows the success snackbar **without** `clearSnackBars()` first — the only snackbar in the file that does not (compare `:76`, `:121`, `:148`). `ScaffoldMessenger` **queues** rather than replaces, at 4 s each, and there is exactly one messenger for the whole app (`MaterialApp`, `lib/main.dart:68`; no screen installs its own), so the queue survives navigation. Eight taps ≈ 32 seconds of messages that follow the player to the waiting screen. Both halves of the report come from this one missing line.

**Implementation**

1. Add `ScaffoldMessenger.of(context).clearSnackBars();` immediately before the success snackbar at `:567`.
2. Give it `duration: const Duration(milliseconds: 1200)`.
3. **Leave the error snackbar at `:577` alone** — it already clears, and its message needs the full default duration to be read.

**Validation**
- **Widget test, the falsifying one:** pump the craft screen, tap re-roll **five times** in succession, and assert exactly **one** `SnackBar` is in the tree. Run it against the current code and watch it report five; paste that number into the commit body.
- **Cross-screen assertion — this is the half that matches the report:** tap re-roll three times, navigate away from the craft screen, pump, and assert **zero** `SnackBar`s remain.
- **Over-reach guard:** a re-roll that fails still shows its error snackbar, with its original duration.

**Blast radius:** `lib/screens/phase2_craft.dart` · `test/` (new or extended craft widget test).

---

## 8. P7 — Tell the table when someone leaves (128 → A)

**What this means for the user:** the roster changing mid-game currently looks like a glitch. It will say what happened.

**The gap.** `handleDisconnect` deletes the player document and rewrites `cards`, `resolutionOrder` and `totalPlayers` (`functions/src/index.ts:1176`). The client's players listener (`lib/services/game_service.dart:444`) rebuilds with one fewer avatar and says nothing.

**Implementation**

1. In the players listener, **before** reassigning `_players`, keep the previous list. Diff by id: any id present before and absent now is a departure.
2. For each departure, surface `'<name> has left the parlour.'` using the name from the **previous** snapshot (the document is already gone). Clear first, per P6, and use `duration: const Duration(seconds: 2)`.
3. **`GameService` must not reach for a `BuildContext`.** It is a `ChangeNotifier` and has none. Expose the departures as state the UI drains — e.g. a `List<String> consumeDepartureMessages()` that returns and clears — and have a single widget high in the game tree show them. **Do not import `material.dart` into the service to call `ScaffoldMessenger`.**
4. **Suppress the first snapshot.** When the previous list is empty because the listener just attached, every existing player would otherwise read as present-then-absent on some later rebuild. Skip the diff until at least one snapshot has been recorded.
5. **Do not fire in the lobby.** Lobby churn is normal and constant; restrict to `currentPhase` not `lobby` and not `gameOver`.

**Validation**
- **Unit test on the diff, not the UI:** feed the service two player lists differing by one id and assert exactly one message naming the departed player. Feed it the same list twice and assert **zero**. Feed it a *growing* list (someone joins) and assert **zero** — a join must never read as a departure.
- **Widget test:** with the service reporting one departure, the game screen shows exactly one `SnackBar` containing the name.
- **Over-reach guard:** the very first snapshot after attaching produces no messages, with any number of players.
- **Wording is deliberate.** Say `has left the parlour` for every case. It covers a voluntary leave, a kick and a presence eviction, which all end in the same deletion, and the client cannot tell them apart. Distinguishing them is Issue 128 Option B and was **not** selected — **do not invent a reason string.**

**Blast radius:** `lib/services/game_service.dart` · one shared game-screen widget · `test/`.

---

## 9. P8 — Peek inside a deck before choosing it (126 → A)

**What this means for the user:** picking a deck currently means picking a name. This shows a taste of what is in it.

**The gap.** `lib/widgets/deck_carousel.dart` shows name, rating seal and prompt count and nothing else. `PromptDecks.getDeck(deckId)` already returns the full `DeckDefinition` including `prompts`, compiled into the client — no network call, no Firestore read.

**Implementation**

1. **Add a visible affordance; do not overload the existing tap.** `deck_carousel.dart:190–198` already uses `onTap` to centre a card, and a hidden second-tap gesture is undiscoverable. On the **centred** card only, add a small text button reading **`PEEK INSIDE`**, below the prompt count, in `AppColors.brass`. Leave `onTap` exactly as it is.
2. Tapping it opens a modal bottom sheet showing: the deck's `displayName`, its rating seal (reuse `AppColors.sealColorFor` / `sealLabelFor` — **do not branch on deck id**, §15), the total prompt count, and **8 prompts drawn at random** under the heading **`A TASTE OF WHAT'S INSIDE`**.
3. Add a **`SHUFFLE`** control that redraws the 8.
4. **Guard the sample size.** Draw `min(8, deck.prompts.length)`. The smallest deck today has 25, but a future deck may not; `sublist(0, 8)` on a shorter list throws.
5. The sheet is **read-only** — it must not change the selected deck. Selecting stays with the carousel.

**Validation**
- **Widget test:** open the sheet for a known deck and assert exactly **8** prompt rows, every one of which is a member of that deck's `prompts` list. Membership, not just count — a sampler with an off-by-one reads adjacent decks.
- **Widget test:** `SHUFFLE` changes the rendered set. Because a random draw can legitimately repeat, assert over **five** shuffles that at least one produced a different set; asserting a single shuffle differs is flaky. (This is the coupon-collector trap that has bitten this project's randomness tests before.)
- **Widget test at 320 pt:** the sheet renders with no overflow exception, and the `PEEK INSIDE` button does not push the deck card's existing badges off-screen — **that is Issue 114's exact failure mode and this adds a widget to the same card.**
- **Over-reach guard:** opening and dismissing the sheet leaves `selectedDeckId` unchanged.
- **Falsify** the membership assertion by sampling from the wrong deck; it must fail.

**Blast radius:** `lib/widgets/deck_carousel.dart` · a new sheet widget · `test/deck_selection_test.dart` or a new file · `docs/design_prompt_system.md` should record that deck contents are previewable client-side from the compiled catalogue.

---

## 10. P9 — One vote option per row (132 → A)

**What this means for the user:** a playtester voted believing there were only two options, because the other two were below the fold with nothing to suggest it.

**The gap.** `lib/widgets/card_grid.dart:108` renders a `GridView.builder` with `crossAxisCount: 2` in portrait and `childAspectRatio: 1.1`, inside the vote screen's `SingleChildScrollView` (`lib/screens/phase3_vote.dart:439`). With an even option count, rows land flush — no partial row peeks, and there is no scrollbar and no fade. Nothing indicates more exists.

**Implementation**

1. In portrait, render **one option per row, full width**. Landscape (`crossAxisCount: 3`) may stay as it is.
2. **⚠️ `AutoSizedAnswerText` breaks in an unbounded column — this is the trap.** Its `LayoutBuilder` tests `textPainter.height <= constraints.maxHeight` (`card_grid.dart:67`). In a plain `Column`, `maxHeight` is `double.infinity`, every candidate size "fits", and it picks the 16 pt maximum on the first iteration — which then overflows the row. **Every row must impose a bounded height**, e.g. `ConstrainedBox(constraints: BoxConstraints(minHeight: 72, maxHeight: 132))`. Verify by asserting the chosen font size actually varies with text length; if a 100-character option renders at 16 pt, the bound is not being applied.
3. Keep the grid's existing `shrinkWrap: true` / `NeverScrollableScrollPhysics` relationship with the parent scroll view — the parent scrolls, the list does not.
4. Preserve every existing behaviour: the `SEALED` stamp and disabled tap for unvotable options (`card_grid.dart:123–124`), the selected-state styling, and the `isTarget` read-only mode from O9.
5. **Rewrite the doc comment at `card_grid.dart:13–24`.** It documents the two-column geometry ("two columns at 375 px wide with `childAspectRatio` 1.1, which gives the text 136.5 x 121.6 logical pixels") and becomes false the moment you change this. A stale comment describing the old layout is worse than none.
6. **Delete `answerFontSizeFor` (`card_grid.dart:27`) and its tests** (`test/vote_option_truncation_test.dart:137–142`). It is dead in production — `AutoSizedAnswerText` replaced it — and you are already in this file.

**Validation**
- **Extend `test/vote_option_truncation_test.dart`**, keeping the real Lora font loaded (`FontLoader` at `:23`). `flutter test` otherwise substitutes a square-glyph fallback that needed 10 lines where Lora needs 5; tuning against it shrinks real text to nothing.
- Assert `didExceedMaxLines == false` for a **100-character** option at **320, 375 and 430 pt** — **all three, including 430**, which Wave O silently substituted 360 for.
- Assert the same under a large `textScaleFactor` (1.3).
- **The discoverability assertion, which is the actual point:** with **six** options at 320 × 640, assert the rendered content height **exceeds** the viewport — proving there is something to scroll to — **and** that the option at index 3 has a non-zero height and is laid out below the fold rather than collapsed. A layout that silently shrinks everything to fit would pass a naive "no overflow" check while defeating the purpose.
- **Over-reach guard:** the `SEALED` stamp still appears on placeholder and own-answer options, and tapping them still does nothing.
- **Falsify** by restoring `crossAxisCount: 2`; the six-option height assertion must fail.

**Blast radius:** `lib/widgets/card_grid.dart` · `test/vote_option_truncation_test.dart` · `test/phase3_vote_test.dart` (any test asserting grid geometry) · `docs/design_scoring_and_ui.md` §3.2 describes the vote grid.

---

## 11. P10 — Return submits, and the button is always reachable (131 → C)

**What this means for the user:** you can press return to submit instead of dismissing the keyboard and hunting for a button that is below the fold.

**Note this is Option C — both halves.** Option A alone was not selected. Some Android IMEs replace the action key regardless of what the field requests, so the done key cannot be the only way to submit; the pinned button is what makes that safe.

**The gap.** `lib/screens/phase2_craft.dart:495` sets `maxLines: 3` with **no** `textInputAction` and **no** `onSubmitted`, so the return key inserts a newline. `SUBMIT DOSSIER` (`:530`) sits in the scrolling body and is below the keyboard on a small phone.

**Implementation**

1. On the `TextField`: add `textInputAction: TextInputAction.done` and `onSubmitted: (_) => _submitAnswer(gs)`. Keep `maxLines: 3` — it governs how the field *wraps*, and players are not typing deliberate line breaks in a one-sentence answer.
2. **Route through `_submitAnswer` (`:66`), never around it.** It holds the `kMaxAnswerLength` guard (`:75`) and the busy-state handling. A second submit path that skips the length check would let a 120-character answer reach the server and be rejected there instead — the user-visible message is the one at `:80`.
3. **Guard re-entrancy.** `onSubmitted` can fire while `_isSubmitting` is already true. Return early if it is, exactly as the button's `onPressed` does.
4. Move `SUBMIT DOSSIER` into a bottom bar that sits above the keyboard, using `MediaQuery.of(context).viewInsets.bottom` so it rises with it. Keep it inside the same `Scaffold`; do not add a second one.
5. Keep the button's existing disabled/busy states — it stays the primary affordance.

**Validation**
- **Widget test, the falsifying one:** enter text, send a `TextInputAction.done`, and assert the submit callable fired **once**. Run it against the current code and watch it fail (today the action does not exist).
- **Length guard via the new path:** enter **101** characters, send done, and assert **no** submission occurred and the `'Trim it to 100 or fewer'` snackbar is shown. This is the assertion that proves you routed through `_submitAnswer` rather than around it.
- **Re-entrancy:** send done twice in rapid succession; assert exactly one submission.
- **Widget test at 320 × 640 with simulated `viewInsets.bottom` of 300:** the submit button's `RenderBox` is fully within the visible area above the inset. Assert on the box, not on `find.text` — a clipped button is still found by a text finder.
- **Over-reach guard:** tapping the button still works, with the same length guard and busy behaviour.

**Blast radius:** `lib/screens/phase2_craft.dart` · `test/` craft widget tests · `docs/design_ui_direction.md` if it describes the craft screen's layout.

---

## 12. P11 — One line per screen saying what you are trying to do (129 → A)

**What this means for the user:** new players currently learn the objective by losing a round.

**The gap.** The craft screen shows the prompt and a `'Dip the quill…'` hint (`lib/screens/phase2_craft.dart:520`) with nothing distinguishing "write something true about you" from "write something that sounds like them". The vote screen never says discussion is allowed.

**Implementation**

Add one italic line under the prompt on each screen. **These strings are decisions — use them verbatim, including punctuation.**

- **Truth phase** (`phase2_craft.dart`, when `currentPhase == GamePhase.truth`):
  `Write something true about you — the more surprising, the better. Others must be able to believe it.`
- **Forgery phase** (same screen, otherwise):
  `You are writing as <name>. Make it sound like something they would say, so people pick yours.`
  `<name>` is the **target's display name**, resolved from `state.currentCardAssignments[me.id]` against `gs.players`. If it cannot be resolved, fall back to `them` — never render a raw player id.
- **Vote phase** (`phase3_vote.dart`, above the option grid):
  `Talk it out — discussion is part of the game.`

Style: `Lora`, italic, `AppColors.ivory` at 70% opacity, `fontSize: 13`, centred, `textAlign: TextAlign.center`. Do not add a container, border or icon.

**Validation**
- **Widget test per screen:** the exact string is present in the truth phase, the forgery phase (with a real target name substituted, asserted against the name and **not** against a player id), and the vote phase.
- **Widget test at 320 pt for each of the three screens:** no overflow exception, and — because P9 and P10 have already reshaped two of these screens — the primary action (submit button, option grid) is still fully on screen. **This is the risk this item carries: three more strings competing for vertical space on screens that have produced two clipping bugs already** (Issues 114, 119).
- **Over-reach guard:** the forgery line renders `them` rather than an id when the assignment cannot be resolved.

**Blast radius:** `lib/screens/phase2_craft.dart` · `lib/screens/phase3_vote.dart` · `test/` · `docs/design_ui_direction.md`.

---

## 13. Deploy, and what to tell the user

After **P1–P5**, stop and report that the server batch is ready. **The user runs the deploy:**

```bash
firebase deploy --only functions
```

`./scripts/check_deploy_fresh.sh` goes red the moment P2 lands and stays red until that runs. **Say so in each server commit body** rather than leaving it looking like a regression.

Then **P6–P11**, client-only. Afterwards the user will want a fresh `flutter build ipa` and a web redeploy. Two standing facts for that moment:

- **App Store Connect has consumed build 4.** `pubspec.yaml` must exceed it — `1.0.0+5` or higher. A reused build number is rejected at upload.
- The `friends-test` web channel serves a **stale** build and needs `flutter build web --release && firebase hosting:channel:deploy friends-test --expires 7d`.

---

## 14. Already delivered — do NOT rework

- **Wave O's six good items**, verified in source August 27, 2026:
  - **O1 / 117** — `answerAuthors` no longer unions across rounds. The three `{ merge: true }` writes at `index.ts:691`, `:1459`, `:1857` became full-document sets. **This is safe and must not be reverted:** `sealedDataMap` is built from a complete in-transaction `transaction.get` (`:1326–1344`), so a full set rewrites every field it read. The seat token lives in a **different document** (`sealed/seat_{playerId}`, `:438`). The `_summary` doc still uses `{ merge: true }` at `:1591` and **must keep it** — that one is supposed to accumulate.
  - **O3 / 115** — names snapshotted into `sealed/_summary.playerNames`; `game_over_screen.dart:706`, `:716`, `:763` read them and never consult the players subcollection.
  - **O6 / 114** — badge pills flex.
  - **O7 / 116** — exactly one raven on the sealed-ballot screen.
  - **O8 / 119** — `AutoSizedAnswerText` is a genuine measurement loop, not another tier table. **P9 depends on this; understand its `maxHeight` requirement before touching it.**
  - **O9 / 121** — target sees the grid read-only; the server bound is independent at `index.ts:903`.
- **Issue 102** — the pre-demo playthrough in room `GLRD`: **20 PASS, 1 NOT RUN, 0 FAIL**, every cited screenshot present. E7 seat recovery and E8 host kick both device-verified.
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R5 mechanically.
- **Issue 103** — seven `DEBUG:` sites gated; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken`, or a stale seat; `votes` stores opaque option UUIDs; the reveal merges only the current card; debug callables are emulator-only *and* host-only. *(Issue 100's unmask withholding is **partially regressed** — that is what P4 repairs.)*
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

---

## 15. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests; `debugSimulateBotResponses` drives several.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin**.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — **do not simplify to one condition**.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** **P4 depends on this** — it is why `pendingScoreDeltas` belongs there.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **`castVote` rejects only genuine self-votes.** Never let a client bound exceed the server's. **P4's `closeUnmaskWindow` inherits this rule** — the server verifies the deadline, the client does not get to assert it.
- **The option id is the authority; text is the fallback, consulted only when the id is null.**
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **Dialogs render on `groundRaised`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which **breaks the iOS build** — four shell-script build phases put Flutter's artefacts outside the sandbox. Proven August 25, 2026: `Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter`. Reverting restored a clean build. The answer stays no (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is **generated**. **No file outside the catalogue may branch on a deck id** — rating, display name, size and the fallback are declared per deck, and the UI maps rating→colour in `app_colors.dart`. **P8 must obey this.** Exactly one deck sets `isFallback`; `getFallbackDeckId()` throws otherwise. `./scripts/check_decks_in_sync.sh` fails the battery when the two drift.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; distinguishing *why* a player left in P7's message (Issue 128 Option B, not selected); per-phase timer durations (Issue 130 Option B, not selected); plus the declined options in `ongoing_general_errors.md` §4.

---

## 16. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens, callables, debug isolation, privacy manifest, deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 17. Verified baseline — measured in-session, August 27, 2026

This is the regression bar. Every number came from running the command.

| Gate | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze lib test` | **0 errors**, 0 warnings, 225 infos |
| Client tests | `flutter test` | **202 passing** |
| Functions build | `npm --prefix functions run build` | clean |
| Functions tests | `npm --prefix functions test` | **RED — 80 passing, 1 failing** → **P1 fixes this** |
| Deck sync | `./scripts/check_decks_in_sync.sh` | **exit 0** — 5 decks, 295 lines |
| Deploy freshness | `./scripts/check_deploy_fresh.sh` | **exit 1 — expected** |
| Playthrough evidence | `./scripts/check_playthrough_evidence.sh` | **exit 0** — 21 blocks: 20 PASS, 1 NOT RUN, 0 FAIL |

---

## 18. Validation standard

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A constant's value is not behaviour** (lesson 2.30). Drive the assertion through the same entry point a client uses. `expect(SOME_CONSTANT).to.equal(600_000)` is not a test — it is the reason P3 exists.

**A rule change that leaves an old test green is a rule that did not change** — grep the suite for tests asserting the old rule *before* writing new ones. This is the reason P1 exists.

**Prove the artefact ships, not that it exists.** The guard is in the source; the button is in the binary.

**Record every substitution.** An omitted assertion reads as though it passed. Two Wave O tests silently substituted viewport widths.

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**A driven playthrough is not a played one.** Every defect in Issues 113–132 came from a person playing the game. **No gate has ever found one.**

---

## 19. Feedback loop — what the Wave O spec got wrong

Wave O's spec was detailed and still produced three misses. Each maps to something it left unpinned — and each fix is already applied above:

- **It named the constant, not the behaviour.** "Raise `PRESENCE_STALE_MS` to 10 minutes" was implemented literally and was inert. **P3 states the observable outcome and the caller that produces it.**
- **It stated a leak guard in prose and a weaker one in the checklist.** The implementer built the checklist item. **P4 puts the real guard in the validation block, not the rationale.**
- **It asked for new tests and never asked whether an old one still held.** **P1 exists because of that, and §1 now makes the grep a standing rule.**
- **It said "assert the room actually progresses" and got an assertion on a filtered array.** **P2 names the exact assertion and the exact probe output that must change.**
- **New this wave: it never asked what happens on the path nobody takes.** O2's window-close only ever ran when every player guessed; the timeout path had no server write at all. **P4 §5 calls this out explicitly, because the naive fix silently empties the points tray.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) GREP THE EXISTING SUITE for tests asserting the rule you are changing.
    Update them in the SAME commit.
(3) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output in the commit body. For a mechanical check, confirm it
    matched a NON-ZERO count before believing its result.
(4) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE --
    including a viewport width or test parameter you changed.
(5) VALIDATE per the item's block, including every over-reach guard.
(6) RECORD observed output in the commit body and, for a guard, in a comment
    at the top of the script or test.
(7) RE-RUN THE FULL BATTERY before committing -- all seven, exit codes read
    BARE and not through a pipe. check_deploy_fresh may legitimately be red
    for server changes you must not deploy.
(8) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options, Pros/Cons, one (recommended),
    and a blank `Your selection: _____`.
(9) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done

**Server batch — P1–P5, five commits, then ONE deploy by the user**
- [ ] **P1** — `npm --prefix functions test` is **81 passing, 0 failing**, green **five consecutive runs**. The three sibling `truthAnswerId` sites were checked and left alone. The two O4 tests still pass.
- [ ] **P2** — an all-placeholder round reaches `gameOver` (or round 2) and is **never** observed as `vote` with an empty `resolutionOrder`. The round-advance logic was **moved** into a shared helper, not copied. Transaction read/write ordering verified. Players see a note explaining the skipped round.
- [ ] **P3** — a player stale by **150 s** survives a host-initiated `reason: "presence"` call; stale by **601 s** does not. `"leave"` and `"kick"` are never time-gated. The reconciliation path still works. `grep -rn "120000\|presenceStaleMs" lib/` returns **nothing**. The tautological O5 test is **deleted**.
- [ ] **P4** — `scoreDeltas` is **absent** while `unmaskDeadline > Date.now()`, asserted alongside proof the window was open. **A round where nobody guesses still ends with the full correct map** — this is the test that stops the regression. `closeUnmaskWindow` refuses an early close and is idempotent.
- [ ] **P5** — a new room is untimed by default; `timerSeconds` clamps at **15** and **300** on both boundaries; vote duration is 75% of it; a room with no `timerSeconds` behaves as 60.

**Client batch — P6–P11, six commits, no deploy**
- [ ] **P6** — five rapid re-rolls produce exactly **one** snackbar, and **zero** survive navigation.
- [ ] **P7** — the diff reports exactly one message for a departure, **zero** for an unchanged list, **zero** for a join, and **zero** on the first snapshot. No `BuildContext` in `GameService`.
- [ ] **P8** — exactly **8** prompts, every one a member of that deck's list; `SHUFFLE` differs across five draws; renders at 320 pt with no overflow; selection unchanged.
- [ ] **P9** — one option per row; no truncation of 100 characters at **320, 375 and 430 pt** and at 1.3 text scale with the **real Lora font loaded**; six options provably exceed the viewport. `AutoSizedAnswerText` has a bounded height. The stale doc comment and dead `answerFontSizeFor` are gone.
- [ ] **P10** — done submits once; **101 characters via the done key is refused with the same snackbar**; double-send submits once; the button is above a 300 pt keyboard inset at 320 pt, asserted on the `RenderBox`.
- [ ] **P11** — all three strings render verbatim; the forgery line shows a **name**, never an id, and falls back to `them`; all three screens clean at 320 pt with their primary action still on screen.

**Across the wave**
- [ ] Every fix has a falsifying test that was **run and observed to fail**, with the output in the commit body.
- [ ] Battery at or above baseline: **0 errors** · **≥202** client · clean functions build · **≥81** functions · deck sync PASS · evidence exit 0.
- [ ] `check_deploy_fresh.sh` red after P2 is expected and explained; **`firebase deploy` was never run by you**.
- [ ] One item, one commit. Issues 122–132 moved into the **single** existing Resolved heading, and the design docs that described the old behaviour updated — including the two **⚠️ blocks** now sitting in `design_database_and_security.md` §4–§5 (P3) and `design_scoring_and_ui.md` §3.3 (P4), which must be **replaced with the real behaviour**, not merely deleted.
