# Agent Execution Guide — Active Build: Playtest Findings (Issues 71–76) — August 11, 2026

**You are an engineering agent with no memory of this project.** Issues 50–70 are delivered and deployed. This queue is six findings from the **first real three-player playthrough** — the manual gate that had been deferred six times. It found more in one session than 167 automated tests ever have, and two of the six are correctness defects that every gate passed.

**All six were selected on August 11, 2026.** Five took Option A. **Issue 72 was answered with a redefinition rather than one of the options** — read §6 carefully; it changes what a "round" means.

**Every number and literal string here is a decision, not a suggestion.** If the design cannot work, STOP and file it with options and a `Your selection: _____` line.

---

## 1. Verified baseline — the regression bar

Measured at `4986cc7`, clean tree.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (276 infos) |
| `flutter test` | **127/127** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **40/40** |
| Production functions | all 14 at `2026-08-11T00:03 UTC` |

**Every gate above was green while Issues 71 and 76 were live in production.** Scoring was awarding points to nobody and a placeholder was occupying a voting slot. Do not treat a green battery as evidence about the vote path.

**`gcloud` is not on this shell's `PATH`**; it is at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`.

### ⚠️ Twelve traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`.** It models the server's error shape (Issue 68) — keep it that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** Gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| 1 | **§3 — Issue 71**, vote resolution | Highest severity: scoring is wrong *now*, in production. Backend. |
| 2 | **§4 — Issue 76**, spurious placeholder | Same answer/vote plumbing; ship with §3 in one deploy. |
| 3 | **§5 — Issues 73, 74, 75** | Client-only, no deploy, low risk. Cheap wins while §3/§4 bake. |
| 4 | **§6 — Issue 72**, round redefinition | Largest by far, and it changes `sabotageAnswersCount`'s meaning — which §3 and §4's tests reference. Do it last so those tests settle first. |

---

## 3. Issue 71 — resolve the option id to an author in `castVote` (Option A)

**What this means for the user:** points are currently awarded to nobody — the reveal literally reads `Unknown: +1` — and a player can vote for their own forgery.

### The gap

Issue 62 required votes to reference an *answer*, with the server resolving id → author from the sealed document. Issue 63 then made option ids opaque UUIDs. **The resolution step was never written.**

```ts
const { roomCode, targetCardId, voterId, votedForId } = request.data;   // index.ts:503
if (voterId === votedForId) { … }                                       // :516  dead guard
const newVotes = { ...card.votes, [voterId]: votedForId };              // :534  stored raw
```

`sealedData.answerAuthors` (option id → author id) is written at `index.ts:1006–1009` and **never read by `castVote`**. So `votes` holds UUIDs where player ids belong: scoring returns UUID-keyed deltas, `phase4_reveal.dart:444` fails its player lookup and renders `Unknown`, `playersDeceivedDeltas[votedForId]` (`index.ts:1056`) counts against a UUID, and the self-vote guard never fires.

### Implementation

**Step 1 — resolve server-side.** In `castVote`, read `/rooms/{code}/sealed/{targetCardId}` **before any write** (the transaction invariant at `index.ts:848`), look the incoming id up in `answerAuthors`, and store the **resolved author id** in `votes`. Everything downstream then works unchanged because `votes` regains its original meaning.

**Step 2 — reject an unknown id.** If the id is absent from `answerAuthors`, throw `HttpsError("invalid-argument", …)`. Silently storing an unresolvable id is how this defect stayed invisible.

**Step 3 — fix the self-vote guard.** Compare `voterId` against the **resolved author**, not the raw payload. Keep the rejection as `HttpsError("failed-precondition", …)`.

**Step 4 — restore the client's own-answer marking.** Redaction removed the client's ability to tell which option is its own, so the `(Your Forgery)` badge disappeared and nothing blocks selecting it. **Do not reopen the leak to fix this.** Have the client remember the answer text it submitted — it typed that text — and match on it to badge and disable that option. The duplicate-answer heuristic already prevents two identical submissions on one card, so text is a safe key.

### Validation

- **Falsifying assertion (backend):** play to the reveal and assert every key of the scoring delta map is a **player id present in the room's players collection**. **Observe it fail first** — today they are UUIDs.
- **Falsifying assertion (self-vote):** cast a vote for your own answer's option id; assert `failed-precondition`. Today it succeeds.
- **Unknown id:** a fabricated UUID is rejected with `invalid-argument`.
- **Client:** a widget test asserting the player's own option is badged and not selectable.
- **Over-reach guard:** a normal vote for another player's answer still scores correctly, and `playersDeceived` increments against a **player id**. Assert the final scores for a fixed three-player scenario are unchanged from the intended values — this is what catches a resolution that maps to the *wrong* author rather than to none.

### Blast radius

`functions/src/index.ts` (`castVote`) · `lib/services/game_service.dart` and `lib/screens/phase3_vote.dart` (own-answer marking) · `test/fake_functions.dart` · `functions/test/game_e2e.spec.ts` · **deploy required**.

---

## 4. Issue 76 — stop the spurious placeholder (Option A)

**What this means for the user:** `THE SOUL IS SILENT` appeared as a votable option although every player had answered. It occupies a slot, can be voted for, and scores as a forgery nobody wrote.

### The gap

The timeout fill in `advancePhaseInternal` (`index.ts:950–958`) reads the forgery keyed by **`holderId`** from `room.currentCardAssignments`:

```ts
const answer = sealedData.sabotageAnswers?.[holderId];
if (!answer || answer.trim().length === 0) { …placeholder… }
```

`submitAnswer` writes it keyed by the **author id it receives from the client** (`index.ts:479`). When those two identifiers disagree for a round, a genuinely submitted answer is invisible to the fill, which overwrites the slot.

### Implementation

**Step 1 — find which side diverges before changing either.** Instrument or reason out whether the client sends an `authorId` that differs from the round's `holderId`. **Do not "fix" this by making the fill more permissive** — that hides a lost answer rather than delivering it.

**Step 2 — make the write and the read use one identifier.** The holder of a card during a forgery round *is* the author of that forgery, so one of the two is redundant. Prefer deriving the key server-side from `currentCardAssignments` rather than trusting a client-supplied author id, which also removes a spoofing surface.

**Step 3 — leave the placeholder mechanism intact.** It is correct behaviour for a genuine timeout; only the false positive is the defect.

### Validation

- **The falsifying assertion:** an E2E test where **all** players submit well before the deadline, asserting **no card contains `kMissingAnswerPlaceholder`**. **Observe it fail first.**
- **Over-reach guard:** a test where one player deliberately does not submit still produces exactly one placeholder, on the right card. Removing the false positive must not remove the real one.

### Blast radius

`functions/src/index.ts` (`submitAnswer`, `advancePhaseInternal`) · `functions/test/game_e2e.spec.ts` · `test/fake_functions.dart` · **deploy required — ship with §3.**

---

## 5. Issues 73, 74, 75 — client-only cleanups (all Option A)

No deploy. Do them in one pass.

**§5.1 — Issue 73: remove `EVALUATE READY STATE (HOST)`.** Rendered twice in `lib/screens/phase2_craft.dart` (lines 293 and 335). It calls `advancePhase`, which force-advances regardless of who has finished — consistent with the ordering oddity reported alongside it. **Remove both, not one.** Phase advance is already automatic when everyone is ready, and the server still advances on timer expiry, so nothing legitimate depends on it.

**§5.2 — Issue 74: remove emoji reactions.** Delete the medallion tray in `phase4_reveal.dart`, `lib/theme/reaction_medallions.dart`, and `sendReaction` in `game_service.dart`. **Leave `lastReaction` / `lastReactionAt` on `PlayerState` and in `firestore.rules` untouched** — removing them needs a rules deploy and a migration for in-flight rooms, which this does not warrant.

> **The user asked explicitly for the cons of Option A to be addressed in comments.** Add a comment at each surviving field — on `PlayerState` and beside the `firestore.rules` allow-set — recording that these are **intentionally retained dead fields** from the removed reaction feature (Issue 74, August 2026), kept to avoid a rules change and a migration, and safe to drop whenever `firestore.rules` is next revised. Without that note the next reader finds two unexplained fields and either resurrects the feature or deletes them without realising a rules deploy is implied.

**§5.3 — Issue 75: enlarge the standings.** On the reveal, promote the standings block: larger avatars and score numerals, and **`FontFeature.tabularFigures()`** on the numbers so digits do not jitter as they tick. Separate it clearly from what sits below.

**Validation for all three:** `flutter test` stays at ≥ 127 with the reaction tests removed or updated; a widget test asserts `EVALUATE READY STATE (HOST)` is **absent** from the craft screen (falsifying today); and **the reveal is re-validated at 360×640 dp at text scale 1.3** — it already carries the prompt, answers, points chips and unmasking results, and §5.3 adds height to the same screen.

---

## 6. Issue 72 — split "rounds" from "forgeries", and add the outer round loop

> **The user did not pick an option here. They redefined the model:**
> *"Rounds are how many Truths each player gets to write. We need a setting for amount of forgeries. We know that the amount of forgeries cannot exceed numPlayers − 1. Add a setting for amount of forgeries in the host settings. Have the default be the min of numPlayers − 1 and 5."*

### What is true today

One setting, `sabotageAnswersCount`, does two jobs: it is the number of forgery rotation rounds **and** therefore the number of forgeries per card. The lobby labels it *"Forgery Rounds"* (`lobby_screen.dart:556`), defaults it to **2** (`:159`), and the game plays exactly **one** truth→forgery→vote→reveal cycle before game-over.

### The target model

- **Forgeries per card** — the existing quantity, correctly named. Capped at **numPlayers − 1**, defaulting to **`min(numPlayers − 1, 5)`**.
- **Rounds** — genuinely new: how many truths each player writes, i.e. how many full cycles the game plays.

### The exact rules — refined August 11, 2026

Read all five; an earlier draft of this guide got the second one wrong.

1. **Hard ceiling `n − 1`.** The host can never select more. **Values above `n − 1` must not be presented at all** — not shown-and-rejected, not greyed out. The chooser offers exactly `1 … n − 1`.
2. 🔴 **The 3-player minimum stays, as an explicit rule.** An earlier draft of this guide observed that defaulting forgeries to `min(n − 1, 5)` makes `activePlayers.length <= sabotageAnswersCount` (`index.ts:270`) vacuous, and concluded two-player games would become valid. **That conclusion is rejected.** Enforce `activePlayers.length < 3` in `startGame` **as its own guard**, with its own message, so the floor cannot be moved by changing an unrelated setting's default. Do not let a rule survive only as a side effect of arithmetic.
3. **`5` is a default, not a cap.** A host with enough players may choose **more than 5** — for example 7 forgeries with 9 players. The only ceiling is clause 1.
4. **`min(n − 1, 5)` applies only when the host has not chosen.** Once they pick a value, it is theirs.
5. **Clamp on player-count change.** If the count falls and the host's explicit choice now exceeds `n − 1`, clamp it down — do not start an impossible game, and do not silently keep an invalid value in the document.

The `n − 1` ceiling is **already the rotation engine's constraint** — `generateRotations` throws unless `playerIds.length > sabotageRounds` (`rotation_engine.ts`). Clause 1 promotes that runtime throw into an enforced setting bound, which is the right move; the throw stays as a backstop.

### Implementation

**Step 1 — rename before adding.** Rename `sabotageAnswersCount` to a name that says what it is (e.g. `forgeriesPerCard`) across `functions/src/`, `lib/models/game_state.dart`, the lobby, and both test suites. **Do this as its own commit with no behaviour change**, so the round-loop diff that follows is readable. The conflated name is why this defect was reportable as "only two options appeared".

**Step 2 — bound the setting, and keep the player floor separate.**

- The chooser **renders only `1 … n − 1`.** An out-of-range value is never drawn, so there is nothing to grey out or reject in the UI.
- `updateLobbySettings` **rejects** anything outside `[1, n − 1]` with an `HttpsError`. A client-only bound is not a bound — the callable is reachable directly.
- **Default `min(n − 1, 5)` only when the host has not chosen.** Track "unset" distinctly from "set to 5", or a host who deliberately picks 5 at nine players will have it silently re-derived when someone joins.
- **`5` is not a ceiling.** With 9 players the chooser offers up to 8, and 7 must be selectable.
- **Clamp downward on player-count change.** A host who set 6 forgeries and then drops to 4 players must land on 3, not be blocked at start with a stale value in the document.
- **Add `activePlayers.length < 3` to `startGame` as its own guard**, with its own message. Do **not** rely on `activePlayers.length <= forgeriesPerCard` for this — once forgeries are bounded by `n − 1` that guard is vacuous, and the 3-player floor must not disappear with it.

**Step 3 — add the outer round loop.** Introduce a rounds setting and a round counter on `GameState`. At the end of a reveal, if rounds remain, deal fresh prompts and return to `truth`; otherwise go to `gameOver`. **Prompt exclusion must span the whole game** — `seenPrompts` already lives per player in `/rooms/{code}/sealed/{cardId}`, and round 2 must not reissue a round 1 prompt. Scores accumulate across rounds; do not reset them.

**Step 4 — check deck sizing against the new totals.** `startGame` validates `deckSize >= activePlayers` (`index.ts:375`). With R rounds the game needs roughly `R × activePlayers` distinct prompts, and the smallest decks hold 12. Validate against the real total at start and reject with a readable `HttpsError` naming both numbers, rather than failing mid-game on round 3.

### Validation

- **Falsifying assertions:** the chooser **renders no option above `n − 1`** (assert the rendered option count, not just that a high value is rejected); `updateLobbySettings` rejects `n` and `0` server-side; **a 2-player game is still refused**, by the dedicated 3-player guard rather than incidentally; and with **9 players, 7 forgeries is selectable and starts** — that is the assertion that catches someone treating 5 as a cap.
- **Round loop:** a 2-round game returns to `truth` after the first reveal with **new prompts**, and no prompt from round 1 reappears in round 2. Scores carry over.
- **Deck sizing:** a rounds × players total exceeding the deck is rejected **at `startGame`**, not mid-game.
- **Over-reach guard:** a 1-round game behaves exactly as today — same phase sequence, same scoring — so the outer loop is additive rather than a rewrite of the existing path.

### Blast radius

`functions/src/index.ts`, `rotation_engine.ts`, `scoring_logic.ts` · `lib/models/game_state.dart` · `lib/screens/lobby_screen.dart` · `test/fake_functions.dart` · both test suites · `design_game_state_and_models.md` (phase order, rounds, forgeries, and the **retained** 3-player minimum — now its own guard rather than a consequence of `sabotageAnswersCount`) and `design_rotation_engine.md` · **deploy required.**

---

## 7. Already delivered — do NOT rework

Verified this session: **Issues 68/69** (sealed `seenPrompts`, `FirebaseFunctionsException` matching, mirror retired), **Issue 67** (per-player exclusions), **63–66** (opaque UUID option ids, re-roll alignment, deploy gate, render-based contrast guard), **58–62**, **50–57**. **Issue 31** — the server uses loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 8. Validation standard

**Write validation that fails against the broken state, and observe it fail.**

**A check that cannot fail is not a check.** Eight instances recorded.

**A green suite is not evidence about anything it cannot observe.** Issues 71 and 76 were live in production with all four gates green — **the playthrough found both.** Manual play is a gate, not a nicety.

**Match errors on codes, not message text** (trap 12). **Measure; do not estimate.** **Do not weaken an assertion or delete a test to reach green.**

**Pair every fix assertion with an over-reach guard** — §3's "scores unchanged for a fixed scenario" is the model, because it catches resolving to the *wrong* author, which an existence check would miss.

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; room reads stay open; `/rooms/{code}/sealed/{cardId}` is default-deny and holds the answer key, `answerAuthors`, and `seenPrompts`. **Never add an explicit `allow read: if false`.**
- **Option ids are opaque UUIDs.** §3 resolves them server-side; **do not send authorship to the client** to make voting easier.
- **Phase order is truth → forgery → vote → reveal.**
- **Re-rolls are unlimited during `truth`, rejected elsewhere, and never repeat a prompt.**
- **`text_similarity.ts` ↔ `text_similarity.dart` stay byte-identical.** The `prompt_decks` pair is **data-only**.
- **`ROOM_TTL_MS` is 8 hours**; below ~4 h a `touchRoom` keepalive becomes mandatory.
- **`firebase.json`'s `predeploy` stays** and runs the tests.
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, and the rejected options on 58–66.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Backend writes, rules, identity, TTL, **deploy & verification §8** | `design_database_and_security.md` |
| Card passing, **rotation and the forgery cap** | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, icons, mascot | `design_ui_direction.md` |
| **Phase order, rounds, forgeries, minimum players** | `design_game_state_and_models.md` |
| Deck catalogue, re-roll exclusion, mirror status | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 11. Feedback loop — what past specs got wrong

- **The manual gate earned its keep the first time it ran.** One playthrough surfaced six issues, two of them production correctness defects that four green gates could not see. **Schedule it per wave, not per year.**
- **A spec that changes a data shape must name every consumer of that shape.** Issue 62 said "votes must reference an answer, and the server resolves it"; Issue 63 changed the ids; nobody wrote the resolver, and `votes` silently changed meaning. **When you redefine what a field holds, enumerate its readers in the blast radius** — `castVote`, scoring, `playersDeceived`, and the reveal were four.
- **A name that does two jobs will be misread as doing one.** `sabotageAnswersCount` was both rounds and forgeries-per-card, which is why "only two options appeared" looked like a bug. §6 renames before it extends.
- **An instruction that costs the implementer something needs its consequence in the same sentence.**
- **Per-player state has a default home** — the sealed subcollection, not the readable room document.
- **Doc structure rots silently.** The Resolved section has been split by duplicate headings three times. **Append inside the existing heading; never add a second.**

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Copy strings verbatim.
(3) VALIDATE per §8. Observe the falsifying assertion fail first, and record it.
    Run the over-reach guard. Then the full §1 battery, including the BACKEND suite.
(4) BEFORE COMMITTING, re-run the battery. Do not write a completion claim from memory.
(5) BLOCKED, or found something needing human judgement? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
(6) RECORD: move the item to Resolved inside the SINGLE existing Resolved heading.
(7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **§3 (Issue 71)** — `castVote` resolves via `answerAuthors` and stores the **author id**; unknown ids rejected; self-vote guard compares the resolved author; client badges and disables the player's own option **without** learning others' authorship. Delta-map-keys and self-vote assertions **observed failing first**; fixed-scenario scores unchanged.
- [ ] **§4 (Issue 76)** — write and fill agree on one identifier, derived server-side; **no placeholder appears when everyone submits** (observed failing first); a genuine timeout still produces exactly one, on the right card.
- [ ] **§5** — both `EVALUATE READY STATE (HOST)` instances removed; reactions removed with **comments recording why `lastReaction`/`lastReactionAt` intentionally remain**; standings enlarged with tabular figures; reveal re-validated at 360×640 dp × 1.3.
- [ ] **§6 (Issue 72)** — rename committed separately from the round loop; the chooser **renders only `1 … n − 1`**; `updateLobbySettings` rejects out-of-range server-side; default `min(n − 1, 5)` applies **only when unset**; **7 forgeries selectable at 9 players** (5 is a default, not a cap); choice **clamped down** when the player count falls; **`activePlayers.length < 3` enforced as its own guard** and a 2-player game still refused; rounds loop returns to `truth` with fresh prompts and carried scores; deck sizing validated at `startGame`; a 1-round game behaves exactly as today.
- [ ] §3, §4 and §6 deployed and verified by artefact inspection per `design_database_and_security.md` §8.
- [ ] Full battery **pasted into the commit body**: `flutter analyze lib test` 0 errors · `flutter test` ≥ 127 · functions build clean · `npm --prefix functions test` ≥ 40.
- [ ] Issues 71–76 moved to Resolved **inside the single existing Resolved heading**; `design_game_state_and_models.md` and `design_rotation_engine.md` updated for the new round/forgery model.
- [ ] **A second playthrough after §6 lands** — it changes the game's shape, and the first one found six issues.
- [ ] **Guide rewritten** — body and title together — to `Queue Complete` or the next queue.
