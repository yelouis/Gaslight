# Agent Execution Guide — Remaining Work (all selections locked, July 13)

**You are an engineering agent picking up Gaslight (Flutter + Firebase party game).** The server-authoritative backend is done and proven (see §1). Everything below is user-approved and unblocked: two debug-tool bug fixes (Issues 19/20, Option A), one test-coverage gap, **two new gameplay features (P8 "Unmask the Forger" and P10 "Custom Decks", both Option A — N5/N6 below)**, and the visual-polish tail. Proposals **P7, P9, and P11 were declined — do not implement them.**

Context read (once): `docs/implementation_plan_gameplay_and_ui.md` **Section 0** (game, architecture, file map) and `docs/design_database_and_security.md` (the shipped server-authoritative architecture).

---

## 1. Verified state (July 13 — trust this, don't re-verify)

- **Backend (Issues 1, 13–18): DONE and proven.** `npm --prefix functions test` = **9/9** (full two-client game over real callables, negative auth checks, credential-reset seat re-bind, six rules tests). `flutter test` 12/12; `flutter analyze` **0 errors**; `cd functions && npm run build` clean. Resolved entries #38–44 are legitimate.
- **Gameplay P1–P6, UI foundation, E6 icons: DONE** (procedural `ThematicIcon`s in `lib/theme/app_icons.dart`; "SEALED" self-card ribbon in `card_grid.dart`).
- **Accepted deviation — do not "fix":** `_getPlayerId()` derives from the auth uid rather than a persisted UUID; the rejoin **re-bind** flow (emulator-proven) covers seat recovery.

## 2. Work queue

| # | Item | Status | Size |
|---|---|---|---|
| **N1** | Issue 19 — bots pruned as disconnected after 30s | ✅ Option A — build | 1 line + tests |
| **N2** | Issue 20 — BOTS SUBMIT doesn't advance when host submitted first | ✅ Option A — build | ~15 lines + tests |
| **N3** | Emulator-suite gap: force-advance/placeholder scenario | proceed | Small |
| **N5** | Feature P8 — "Unmask the Forger" revenge guess | ✅ Option A — build | Medium |
| **N6** | Feature P10 — Custom Decks (lobby-written prompts) | ✅ Option A — build | Medium |
| **N4** | Wave E tail: E5 components, E7 sound/motion, E8 a11y | proceed (last) | Medium |
| — | Proposals P7, P9, P11 | ⛔ **declined — do NOT implement** | — |

Execute in this order: **N1 → N2 → N3 → N5 → N6 → N4.** Bug fixes and the coverage test first (N3's scenario also protects N5/N6 regressions), then features, polish last.

---

## N1 · Issue 19 — Bots created with a live timestamp get pruned (Option A)

**Change** — `functions/src/index.ts` → `debugAddBots`, inside the `botState` object literal: replace `lastSeen: Date.now()` with `lastSeen: null`.

**Why this works:** bots never heartbeat. The client dead-player detector (`lib/services/game_service.dart` ~line 296) treats `lastSeen == null` as "never prune" (`if (lastSeen == null) return false;`), so a null-timestamp bot is permanently exempt. Server side is consistent too: `handleDisconnect`'s `isDead` check (`disconnectedPlayer.lastSeen && (Date.now() - lastSeen) > 30000`) evaluates falsy for null — no behavior change for real players. The TS `PlayerState` interface already types `lastSeen: number | null`, so no type change is needed.

**Also mirror the fake:** `test/fake_functions.dart` implements a fake `debugAddBots` — make its bot docs use `lastSeen: null` too, so Flutter widget tests model the same data.

**Validation:**
1. Emulator test (add to `functions/test/game_e2e.spec.ts`): create a room with `debugEnabled: true`, call `debugAddBots`, read `bot_1`'s doc via the Admin SDK, assert `lastSeen === null`.
2. Dart unit test: run the dead-player predicate (extract or replicate the filter logic) against a bot map with `lastSeen: null` and `now = anything` → assert not selected for pruning.
3. Manual (Journey 2): debug game with bots, idle 2+ minutes mid-forgery — all 9 bots persist, no `handleDisconnect` traffic in the emulator log.
4. `npm run build` clean; full suites green.

## N2 · Issue 20 — Debug bot submissions never trigger the phase advance (Option A)

**Where:** `functions/src/index.ts` → `debugSimulateBotResponses`. Current structure (verified July 13): one transaction; reads first (`roomSnap`, then `playersSnap` — both before any write, so the R1 invariant already holds); two branches (`forgery`/`truth` and `vote`) that each build local `cards` + `readyPlayers` copies and end with `transaction.update(roomRef, { cards, readyPlayers })`.

**Change — mirror the gameplay-callable pattern exactly** (see `submitAnswer` for the reference): in **each** branch, immediately **after** its existing `transaction.update(roomRef, { cards, readyPlayers })`, append:

1. `const activePlayers = players.filter(p => p.role !== "spectator");` — `players` is already in scope from the read phase; do not re-read.
2. `const allReady = activePlayers.length > 0 && activePlayers.every(p => readyPlayers[p.id] === true);` — use the **merged** local `readyPlayers`, never `room.readyPlayers`.
3. `if (allReady) { await advancePhaseInternal(transaction, roomRef, room, activePlayers, cards); }` — pass the **merged** local `cards` (this is what makes placeholder-fill and vote-scoring see the bot submissions). Passing `room` (pre-merge) is correct: `advancePhaseInternal` reads only phase/rotation/plan/assignment/timer fields, none of which the debug merge touches.

Notes:
- Issuing `advancePhaseInternal`'s room update after the branch's own update is the established pattern (`submitAnswer` does the same); later writes to the same doc override the earlier fields within the transaction.
- The legacy `transaction.update(pRef, { isReady: true })` player-doc writes in this callable are harmless leftovers — leave or remove, but if removed, confirm nothing reads `isReady` (grep first).
- `advancePhaseInternal` must remain read-free (invariant comment at its definition).
- **Mirror the fake:** update the fake `debugSimulateBotResponses` in `test/fake_functions.dart` to perform the same all-ready→advance step, or Flutter widget tests will behave differently from production.

**Validation:**
1. Emulator test — order-independence (the bug): host `submitAnswer` FIRST, then call `debugSimulateBotResponses`; assert `currentPhase` advanced (rotation incremented or moved to `truth`) with **no further calls**. Before this fix that assertion fails.
2. Emulator test — vote phase with a **bot reader**: humans vote, then `debugSimulateBotResponses`; assert phase flips to `reveal` and score/honor increments landed (proves the merged `cards` reached the scoring path).
3. Regression: the documented order (bots first, host last) still advances — covered by re-running the existing full-game flow after the change.
4. Manual: Journey 2 both orderings; `npm run build`; all suites green.

**On completion of N1+N2:** move Issues 19 and 20 to the Resolved section (what-was-solved format, per `bug_documentation_guidelines`); note in `e2e_testing_journeys.md` Journey 2 that tap order no longer matters.

## N3 · Coverage gap — force-advance/placeholder scenario (proceed now)

The delivered emulator suite lacks the timeout/force-advance path. Add one `it(...)` to `functions/test/game_e2e.spec.ts` (reuse `createAnonUser`/`callFn` helpers, same describe block):
1. Two players; start; during forgery rotation 1 only ONE submits.
2. Host calls `advancePhase`.
3. Assert the phase advanced AND the missing forgery slot equals the placeholder constant (assert the exact string used in `functions/src/index.ts` — `kMissingAnswerPlaceholder` — so copy drift breaks the test).
4. Continue to truth: one player never submits; host force-advances; assert that card's `truthAnswer` is the placeholder and the vote phase presents a full option set.

**Validation:** `npm --prefix functions test` → 10+ passing including the new scenario.

---

## N5 · Feature P8 — "Unmask the Forger" (Option A)

**What it is (player view):** After the Truth is revealed, every player who fell for a lie gets a 15-second window to guess **who wrote the lie they voted for**. Correct guess: +1 to the guesser, −1 to that forger. Then the forgery authors are unmasked and the guess results shown. Being fooled becomes the start of a grudge match instead of just a loss.

**⚠️ Core design constraint — the reveal must be re-sequenced.** Today the reveal flips **every** forgery's author early in the animation (`FlippingRevealCard` per option row). If authors are visible before the guess, the guess is trivial. The reveal becomes five beats:
1. Options + vote chips land (existing stagger).
2. **The Truth flips** (existing, but now FIRST among flips — forgery author cards stay sealed).
3. **Unmask window** (only when at least one voter was fooled): fooled voters see the guess tray; everyone else sees a status line ("The fooled are naming their deceivers…").
4. **Forgery authors flip + guess results** ("REVENGE" chips: who unmasked whom, ±1).
5. Points-awarded chips + standings strip + CONTINUE (existing).

### Data model
- **`CardModel`** (Dart `lib/models/card_model.dart` **and** TS interface in `functions/src/scoring_logic.ts`): add `unmaskGuesses: Map<String, String>` (guesserId → guessedAuthorId), default `{}`, full `toMap`/`fromMap`/`copyWith` + TS typing. Note: the actual author a guesser fell for is already known — it's `card.votes[guesserId]` (votes store the authorId, or `'TRUTH'`). Correctness = `unmaskGuesses[g] == votes[g]`.
- **`GameState`** (Dart + TS): add `unmaskDeadline: int?` (epoch ms). Serialize; `copyWith` needs a `clearUnmaskDeadline` flag (copy the existing `endTime`/`clearEndTime` pattern exactly).

### Server (`functions/src/index.ts`)
1. **Set the window at the vote→reveal transition** — in `advancePhaseInternal`'s vote branch, after scoring: compute `hasFooled = Object.values(currentCard.votes).some(v => v !== 'TRUTH')`. Include in the room update: `unmaskDeadline: hasFooled ? Date.now() + 20000 : null` (15 s window + 5 s buffer for the truth-flip beat). In `advanceToNextResolution`, clear it (`unmaskDeadline: null`) when moving to the next card.
2. **New callable `submitUnmaskGuess`** — args `{roomCode, guesserId, guessedAuthorId}`. Follow the `castVote` skeleton exactly (auth → ownership pre-check on `guesserId`'s doc via `authUid` → transaction with **all reads before writes**):
   - Reads: room doc, players collection.
   - Validate (throw `failed-precondition`/`invalid-argument`): `currentPhase == 'reveal'`; `currentReaderId` set and its card found; `card.votes[guesserId]` exists and `!== 'TRUTH'` (only fooled voters guess); `card.unmaskGuesses` lacks `guesserId` (one guess); `room.unmaskDeadline` non-null and `Date.now() <= unmaskDeadline`; `guessedAuthorId !== guesserId`.
   - Writes: merge the guess into the card's `unmaskGuesses` and update the room's `cards`; if `guessedAuthorId === card.votes[guesserId]` (correct), apply `FieldValue.increment(1)` to the guesser's `totalScore` and `increment(-1)` to the actual forger's. No floor — negative totals are acceptable and dramatic.
   - Return `{success: true}` only — **do not return correctness**; results are revealed at beat 4 with everyone else (clients compute correctness locally once authors are public).
3. **No changes** to `debugSimulateBotResponses` — bots never guess (they always vote TRUTH, so they're never fooled).

### Client (`lib/`)
1. `GameService`: thin wrapper `submitUnmaskGuess(String guessedAuthorId)` calling the callable with `currentPlayerId`.
2. `phase4_reveal.dart` — re-sequence `_revealStage` into the five beats, driven by `state.unmaskDeadline`:
   - Beat timing: beats 1–2 as now but **only the TRUTH row's `FlippingRevealCard` gets `isRevealed: true` before the window**; forgery rows stay sealed until beat 4. Beat 3 runs while `unmaskDeadline != null && now < unmaskDeadline` (compute remaining from the server timestamp — this also makes mid-reveal rejoin land in the correct beat); when `unmaskDeadline == null` (nobody fooled), skip straight to beat 4.
   - **Guess tray** (fooled local player who hasn't guessed): "UNMASK THE FORGER — who wrote the lie you fell for?" + avatar grid of `card.sabotageAnswers.keys` **minus self**, with a countdown (tabular figures). On tap → confirm → `submitUnmaskGuess`; on success show "Guess sealed." (try/catch + SnackBar per the Issue 14 pattern; leave the tray usable on failure). Non-fooled players and the reader see the status line.
   - Beat 4: flip forgery authors; render a "REVENGE" results row from `card.unmaskGuesses` vs `card.votes`: correct → "🔍 {guesser} unmasked {forger}! +1 / −1"; wrong → "{guesser} accused {innocent} — missed". The room stream delivers `unmaskGuesses` live.
   - Reduce-motion (`MediaQuery.accessibleNavigation`): skip flip animations but **keep the guess window** (it's gameplay, not decoration).
   - Note: the existing "POINTS AWARDED THIS CARD" chips are computed from `ScoringLogic` and won't include unmask ±1s — that's correct; the REVENGE row is their display.
3. **Mirror in `test/fake_functions.dart`**: fake `submitUnmaskGuess` with the same validation + scoring, and set `unmaskDeadline` in the fake's vote→reveal transition.

### Docs
Update `design_scoring_and_ui.md` (add the Unmask rule to Formulas + the five-beat reveal to Screen Architectures) and the lobby "HOW TO PLAY" manual (`lobby_screen.dart` `_showInstructions`) with one player-friendly line. Add a manual journey to `e2e_testing_journeys.md`.

### Validation
- **Emulator tests** (extend `functions/test/game_e2e.spec.ts`): (a) full-game variant where one voter votes for a forgery → assert `unmaskDeadline` set on reveal; correct guess → scores ±1 and `unmaskGuesses` recorded; (b) wrong guess → no score change; (c) rejections: second guess, guess from a TRUTH-voter, guess after deadline (seed a past deadline via Admin SDK), guess while phase != reveal — each the right error code; (d) nobody fooled → `unmaskDeadline` null.
- **Widget tests**: fooled player sees the tray, non-fooled doesn't; forgery author rows sealed during beat 3, flipped after; REVENGE row renders correct/missed cases from a seeded card.
- **Manual**: 3-human game on the emulator — fall for a lie, unmask, watch the ±1 land; confirm the reader's screen makes sense during the window.

---

## N6 · Feature P10 — Custom Decks (Option A)

**What it is (player view):** While waiting in the lobby, every player can secretly write up to 3 of their own prompts. If the host picks the **Custom Deck**, the game is played on the group's prompts (topped up from a standard deck if there aren't enough), and nobody ever receives a prompt they wrote themselves.

### Data model & rules
- **`PlayerState`** (Dart + TS): add `customPrompts: List<String>` (default `[]`), serialized. **Contributions ride on the player's own doc** — no new write path needed: the `firestore.rules` protected-field deny-list (`hasAny([...])`) doesn't include `customPrompts`, so owner-writes are already allowed. Verify with a rules test rather than assuming. (Docs are world-readable, so contributions are only secret *in-app* — acceptable for a party game; note it in the design doc.)
- **`GameState`**: no new field — reuse `selectedDeckId` with the sentinel id `'custom'`.

### Client — lobby (`lib/screens/lobby_screen.dart`)
1. **Contribution widget** in the waiting room (all players, always visible, collapsible): up to 3 single-line fields ("Write a prompt about *us*…"), 200-char cap, with a SAVE that writes a **field-scoped** update `{'customPrompts': [...trimmed non-empty...]}` to the player's own doc (Issue 18 pattern — never a full-object write). Editable until the game starts.
2. **Deck sync:** add `'custom'` to the host's deck dropdown (label "Custom Deck — write your own"). Extend the `updateLobbySettings` **callable** (server + client wrapper) with an optional `selectedDeckId` param so the host's choice lands on the room doc and every client sees it. When `selectedDeckId == 'custom'`, non-hosts see a banner ("Custom Deck selected — add your prompts!") and an aggregate count ("7 prompts from 3 players" — counts only, texts never displayed).
3. **Host warning:** if starting custom with zero contributions, show a non-blocking notice that standard prompts will fill in.

### Server (`functions/src/index.ts` + `functions/src/prompt_decks.ts`)
1. **`updateLobbySettings`**: accept + persist `selectedDeckId` (host-only, lobby-phase-only).
2. **`startGame`** when `selectedDeckId == 'custom'`:
   - **Harvest** from the already-read `playersSnap` (active non-spectators): per player take at most 3 prompts, trim, drop empties, cap 200 chars, dedupe case-insensitively across the pool. Build `pool: {text, authorId}[]`.
   - **Top up**: while `pool.length < activePlayers.length`, draw from the fallback deck `'the_daily_grind'` (`authorId: null`), skipping texts already in the pool.
   - **Skip the deck-size precondition** for `'custom'` (the top-up guarantees coverage); keep it for normal decks.
   - **Own-prompt-free assignment**: shuffle the pool; greedy-assign one prompt per player where `prompt.authorId !== playerId`. If a player is stuck with only their own prompt: scan previously assigned pairs `(holder j, prompt q)` for a swap where `q.authorId !== stuckPlayer && stuckPrompt.authorId !== j` and swap; if **no valid swap exists** (provable edge: 2 players where one authored every pooled prompt), replace the stuck player's prompt with a fresh fallback draw (`authorId: null`). This terminal fallback makes the algorithm total — implement it, don't assume the swap always exists.
   - Cards are built from the assignment as today; `promptAuthorId` need not be persisted on the card (assignment-time only).
3. **`rerollPrompt`**: when `room.selectedDeckId == 'custom'`, `PromptDecks.drawOneExcluding('custom', …)` would throw — branch to draw from `'the_daily_grind'` excluding all current card prompts **and** every pooled custom text still on cards. One-line branch selecting the fallback deck id before calling `drawOneExcluding`.
4. **Mirror in `test/fake_functions.dart`**: port the harvest/top-up/assignment logic into the fake `startGame` (and the reroll branch) so widget tests exercise the same rules.

### Docs
Update `design_prompt_system.md` (new "Custom Deck" section: player-doc contributions, harvest caps, top-up, own-prompt-free assignment with the swap + terminal-fallback rule, reroll fallback) and the lobby manual line. Add a manual journey to `e2e_testing_journeys.md`.

### Validation
- **Emulator tests**: (a) two players contribute marker prompts ("ALICE_P1"… ) via player-doc updates → `startGame('custom')` → assert every card's prompt ∈ contributions ∪ fallback AND no card's prompt is one its own target authored; (b) zero contributions → all-fallback game starts; (c) **the edge case**: 2 players, ALL pooled prompts authored by player A → assert A's card holds a fallback prompt (terminal fallback exercised); (d) reroll during a custom game → new prompt from fallback, not a duplicate; (e) `updateLobbySettings` rejects `selectedDeckId` from a non-host.
- **Rules tests**: owner can write `customPrompts` on their own doc; cannot write another player's; protected fields still denied alongside it.
- **Widget tests**: contribution SAVE issues a field-scoped update containing only `customPrompts`; banner + count render when the room's `selectedDeckId` is `'custom'`.
- **Manual**: two devices — both contribute, host picks Custom, play a card and confirm your own prompt never lands on you; try a reroll.

---

## N4 · Wave E tail (do last)

Verified missing as of July 13 (spec: `docs/implementation_plan_gameplay_and_ui.md` Wave E):
1. **E5 — pressed "stamp" feel on `PrimaryButton`** (`lib/widgets/shared_ui.dart`): tap = quick scale-down + faint wax-ring flash on commit actions.
2. **E5 — brass halo on the active reader's avatar** (`currentReaderId`) in the vote/reveal screens — nothing renders this today.
3. **E5 — timer "guttering lamp" flicker** (`auto_advance_timer.dart`): currently only a color swap on `isLowTime`; add a subtle flicker/pulse (guard with reduce-motion).
4. **E7 — sound + haptics behind a mute toggle**: quill scratch on submit, wax thunk on vote, low swell on truth reveal; `HapticFeedback` on commit/reveal; audio dependency + settings toggle; fully silent when muted.
5. **E8 — a11y audit**: brass/ivory contrast on soot at body sizes; no meaning via dim opacity alone; tabular figures on live numbers; extend the `MediaQuery.accessibleNavigation` reduce-motion pattern (`FlippingRevealCard`) to all new animation.

**Validation:** `flutter analyze` 0 errors; manual pass per item; reduce-motion ⇒ instant final states; mute ⇒ silence. Mark each item done or explicitly deferred in the plan doc.

---

## THE LOOP (per item)

```
 ORIENT once: read this guide · flutter pub get · flutter analyze ·
 cd functions && npm run build
      │
      ▼
 (1) SELECT next item: N1 → N2 → N3 → N5 → N6 → N4. (P7, P9, P11 are DECLINED — never build.)
 (2) STUDY the item spec + the exact files named.
 (3) IMPLEMENT. Invariants: transaction reads before writes, always;
     advancePhaseInternal never reads; never weaken firestore.rules;
     keep test/fake_functions.dart mirrored with functions/src/index.ts.
 (4) VALIDATE per the item block, then flutter analyze (0 errors) · flutter test ·
     and for anything touching functions/ or rules: npm --prefix functions test.
 (5) BLOCKED or spec wrong? STOP — file it in ongoing_general_errors.md
     (bug_documentation_guidelines format, with options) and ask the user.
 (6) RECORD: move resolved issues to Resolved with what-was-solved; sync design
     docs if behavior changed (e2e_testing_journeys.md for N2).
 (7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

## Definition of Done
- [ ] N1: bots persist past 30s; `lastSeen: null` asserted in the emulator; fake mirrored; Issue 19 → Resolved.
- [ ] N2: BOTS SUBMIT advances in either tap order incl. bot-reader vote case; fake mirrored; Issue 20 → Resolved; Journey 2 note updated.
- [ ] N3: force-advance/placeholder scenario green in the emulator suite.
- [ ] N5 (P8): five-beat reveal with sealed authors through the guess window; `submitUnmaskGuess` callable with all rejection cases emulator-tested; ±1 scoring proven; fakes mirrored; docs + manual updated; proposal marked delivered.
- [ ] N6 (P10): custom contributions via field-scoped own-doc writes; own-prompt-free assignment incl. the terminal-fallback edge case emulator-tested; reroll fallback works; `updateLobbySettings` deck sync host-gated; fakes mirrored; docs + manual updated; proposal marked delivered.
- [ ] N4: E5/E7/E8 done or explicitly deferred with notes in the plan doc.
- [ ] P7, P9, P11 not implemented (declined).
- [ ] Final: `flutter analyze` 0 errors · `flutter test` green · `npm --prefix functions test` green · docs synced · one-item commits.
