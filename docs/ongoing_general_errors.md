# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

---

## 1. Open & in-flight

**Queue Complete for code — Issues 1–76 delivered and independently verified (August 11, 2026, `1e12748`).** Battery re-measured this session, not copied: `flutter analyze lib test` **0 errors** · `flutter test` **127/127** · functions build clean · `npm --prefix functions test` **43/43**.

**The two gaps from the previous verification pass are closed:**

- **Issue 76** — `submitAnswer` now looks up `room.currentCardAssignments?.[authorId]` and validates the submission against it (`functions/src/index.ts:~495`). ⚠️ **This is an accepted equivalent, not the specced approach.** The guide asked for the write key to be *re-derived* server-side; the implementation keeps `[authorId]` as the key and *validates* it against the assignment map instead. That reaches the same guarantee — author and holder are provably the same identity for that card, so the timeout fill reading `sabotageAnswers[holderId]` can no longer miss a real answer. **Recorded so a later pass does not "fix" it back.**
- **Issue 72** — the default is now `Math.min(activePlayers.length - 1, 5)` (`index.ts:266`), derived from the live player count rather than hardcoded; `updateLobbySettings` rejects out-of-range with `invalid-argument` against `maxAllowed = numPlayers - 1`, and tracks `isExplicitForgeriesUpdate` so "unset" stays distinct from an explicit choice. A `totalRounds` bound of 1–5 was added alongside.

**One thing I could not confirm from source this pass:** whether `submitAnswer`'s `authorId` is bound to `request.auth.uid` before being used as the write key. If it is not, a client could still write into another player's slot — the spoofing guard the spec asked for. **This is unverified, not a known defect**; it is a short check worth doing before the next deploy.

**Still open, and it is not code:** the game's shape changed materially in this wave — truth-first ordering, an outer round loop, a reworked forgery setting. **A playthrough is warranted.** The last one found six issues against a fully green battery.

**Active build (August 13, 2026): the playthrough is now tooled rather than deferred.** Issue 70 moved from Option B to **Option D** — Antigravity installs Marionette MCP, drives three real simulator clients through the eleven assertions, and writes findings to `docs/playthrough_findings_marionette.md`. Spec: `agent_execution_guide.md` §2–§7. Battery re-measured this session (August 13, `1e12748`): `flutter analyze lib test` **0 errors** (24 warnings, 197 infos) · `flutter test` **127/127** · functions build clean · `npm --prefix functions test` **43/43**.

**Independently re-verified (August 11, 2026, clean tree at `4986cc7`):** `seenPrompts` reads from and writes to `/rooms/{code}/sealed/{cardId}` (`functions/src/index.ts:680–701`) and is **gone from `lib/` entirely**; `game_e2e.spec.ts:851–855` asserts the public card must *not* carry it while the sealed doc must; `test/fake_functions.dart` raises real `FirebaseFunctionsException`s with `code: 'resource-exhausted'`; `phase2_craft.dart:515` matches on type and code with **all substring matching deleted**; `test/reroll_deck_exhaustion_test.dart` exists; and the mirror invariant was **formally retired** in `design_prompt_system.md:79` rather than left quietly false. Production functions all updated `2026-08-11T00:03 UTC`. Battery re-measured: `flutter analyze lib test` **0 errors** (276 infos) · `flutter test` **127/127** · functions build clean · `npm --prefix functions test` **40/40**.

**One claim did not hold**, and it is the same one that has been carried and deferred for six cycles — see Issue 70.

---

## ⚠️ Unresolved Issues & Suggestions

### Issue 71: `castVote` never resolves the option id to an author — scoring is misattributed and the self-vote guard is dead

**Status**: ⚠️ Confirmed Unresolved — found in the August 11, 2026 playthrough. The reveal displayed **`POINTS AWARDED THIS CARD — Unknown: +1, Unknown: +1`** where player names belong. That is the visible symptom of a broken join, and it is the failure the playthrough's assertion 7 was written to catch.

Issue 62's spec required votes to reference an **answer**, with the server resolving id → author from the sealed document, because a redacted client cannot know authorship. Issue 63 then replaced the author-derived option ids with opaque UUIDs. **The resolution step was never implemented.**

`castVote` still takes `votedForId` from the client and stores it verbatim:

```ts
const { roomCode, targetCardId, voterId, votedForId } = request.data;   // index.ts:503
if (voterId === votedForId) { … }                                       // :516  self-vote guard
const newVotes = { ...card.votes, [voterId]: votedForId };              // :534  stored raw
```

`sealedData.answerAuthors` (option id → author id) is written at `index.ts:1006–1009` and **never read by `castVote`**. Three consequences:

1. **Scoring is keyed by option UUIDs, not player ids.** `calculateScores` returns `Record<playerId, number>`, and the reveal looks players up by that key (`phase4_reveal.dart:444`) — the lookup fails and falls back to `'Unknown'`.
2. **The self-vote guard at line 516 is dead.** It compares a player id against what is now a UUID, so it never matches and a player can vote for their own answer.
3. **Downstream stats are wrong too** — `playersDeceivedDeltas[votedForId]` at `index.ts:1056` increments a UUID-keyed counter.

**This is the highest-severity item in this batch**: the game silently awards points to nobody and would mis-name authors, while every automated test passes.

**A fourth consequence, reported separately and with the same root cause:** *"each player should not be able to select their own answer."* Before Issue 62, the vote screen badged the player's own forgery `SEALED — (Your Forgery)` and blocked selecting it. That marking is now gone, because **redaction removed the client's ability to tell which option is its own** — authorship lives in the sealed document the client cannot read. So the client neither marks nor blocks it, and the server-side guard at line 516 is dead for the reason above. **A player can currently vote for their own forgery, with nothing stopping them at either end.**

Whichever option is selected below must restore both halves — the server rejecting a self-vote, *and* the client marking the player's own answer so they are not invited to make one. The cheapest way to restore the client half without reopening the leak is to have the client **remember the answer text it submitted locally** and match on it, since it typed that text itself and the duplicate-answer heuristic already prevents two identical submissions on one card.

**Option A (recommended): resolve on the server, in `castVote`**
- Pros: Puts the mapping where the redaction already put it — read `answerAuthors` from the sealed document, translate the incoming option id to the author id, and store *that* in `votes`. Everything downstream (scoring, deceived counts, the reveal) keeps working unchanged because `votes` regains its original meaning. The self-vote guard becomes correct again once compared against the resolved author.
- Cons: Adds a sealed read to `castVote`'s transaction, which must happen before any write (`index.ts:848`). Requires a redeploy, and the E2E vote tests need updating to send option ids rather than author ids.

**Option B: store both — the option id as cast, and the resolved author alongside**
- Pros: Preserves an audit trail of exactly what the client sent, which is useful if a future dispute or bug needs replaying. Scoring reads the resolved field.
- Cons: Two sources of truth for one fact, and every consumer must be taught which to read. The `votes` map is consumed in at least four places; missing one reintroduces this bug quietly.

**Option C: send the author id from the client again**
- Pros: Smallest change — revert to the pre-Issue-63 payload and everything works as it did.
- Cons: **Undoes Issue 62 entirely.** The client would have to know authorship to send it, which is exactly the leak that issue closed. Not viable.

Your selection: Proceed with Option A.

---

### Issue 76: A placeholder answer appeared although every player had answered

**Status**: ⚠️ Confirmed Unresolved — found in the August 11, 2026 playthrough. The vote screen offered three options for *"The most unprofessional thing I've done at a holiday party"*: two real answers and **`THE SOUL IS SILENT`**, the missing-answer placeholder — **despite every player having submitted**.

That string is `kMissingAnswerPlaceholder`, injected by the timeout fill in `advancePhaseInternal` (`functions/src/index.ts:950–958`), which writes it whenever the holder's slot is empty:

```ts
const answer = sealedData.sabotageAnswers?.[holderId];
if (!answer || answer.trim().length === 0) { …placeholder… }
```

The fill is keyed by **`holderId`** — taken from `room.currentCardAssignments` — while `submitAnswer` writes the forgery keyed by the **author id** it receives from the client (`index.ts:479`). If those two identifiers disagree for a round, a genuinely submitted answer is invisible to the fill, which then overwrites the slot with the placeholder. That is the most likely mechanism and it is consistent with what was observed.

It may also share a cause with **Issue 72** — a card that displayed only one forgery. Both are "an answer that was written did not arrive where the reveal looked for it."

**Note this is not merely cosmetic:** a placeholder occupies a voting slot, so a player can vote for `THE SOUL IS SILENT`, and scoring treats it as a forgery nobody authored.

**Option A (recommended): make the fill and the write agree, and prove it with a no-timeout test**
- Pros: Fixes the mechanism rather than the symptom. Assert the invariant directly — for every round, the key `submitAnswer` writes is the key the timeout fill reads — and add an E2E test where **all** players submit well before the deadline, asserting **no card contains the placeholder**. That test fails today and is the falsifying assertion.
- Cons: Requires understanding why the two identifiers can diverge, which may turn out to be a client sending the wrong `authorId`; the fix could land on either side of the boundary.

**Option B: only fill placeholders for slots the assignment says are genuinely unanswered, checked at deadline**
- Pros: Narrower — the fill stops running speculatively and only acts on a real timeout, so a key mismatch can no longer manufacture a placeholder over a real answer.
- Cons: Treats the symptom. If the keys really do diverge, the answer is still lost — it just shows as an absent option rather than a placeholder, which is arguably harder to notice.

Your selection: Proceed with Option A.

---

### Issue 72: Only one forgery appeared on a 3-player card

**Status**: ⚠️ Needs one reproduction detail — found in the August 11, 2026 playthrough. With three players, the reveal showed **the truth plus a single forgery** ("FORGERY BY LOUIS2"), where two were expected.

Both pieces of machinery check out on inspection, so this is not yet root-caused:

- `RotationEngine.generateRotations` (`functions/src/rotation_engine.ts`) is correct for 3 players × 2 rounds: round 1 is A→B, B→C, C→A; round 2 is A→C, B→A, C→B. Every card receives forgeries from two distinct players.
- The advance at `index.ts:960` — `if (room.currentRotationIndex < room.sabotageAnswersCount)` — starts at `1` and correctly runs a second round before moving to vote.

That leaves the input. **The most likely explanation is that the lobby's forgery-round count was 1, not the default 2**, in which case the behaviour is correct and the defect is that nothing on screen made the count obvious. The next likeliest is a timeout that filled one slot with a placeholder.

**To root-cause, one fact is needed:** what "Forgery Rounds" was set to in House Rules for that game. If it was 2, this is a real engine bug and takes priority.

**Option A (recommended): reproduce with Forgery Rounds explicitly set to 2, then decide**
- Pros: Costs one short game and distinguishes a configuration surprise from an engine defect — which are very different fixes. Avoids rewriting rotation logic that inspection says is correct.
- Cons: Requires another playthrough session before anything is fixed.

**Option B: treat it as a UI clarity problem regardless**
- Pros: Even when the count is correct, the player has no on-screen reminder of how many forgeries to expect. Surfacing "2 forgery rounds" during play removes the surprise whatever the root cause.
- Cons: If there *is* an engine bug, this papers over it with a label.

Your selection: Wait, we need to fix the definition of rounds. Rounds are how many Truths each player gets to write. We need a setting for amount of forgeries. We know that the amount of forgeries cannot exceed numPlayers - 1. Add a setting for amount of forgeries in the host settings. Have the default be the min of numPlayers - 1 and 5.

**Refinement (August 11, 2026), and it corrects an assumption in the first write-up:**

1. **The 3-player minimum stays.** An earlier draft of the execution guide noted that defaulting forgeries to `min(n − 1, 5)` would make the old `activePlayers.length <= sabotageAnswersCount` guard vacuous and therefore make 2-player games valid. **That is not wanted.** The minimum of **3 active players** is a deliberate rule in its own right and must be enforced explicitly, independently of the forgery arithmetic — it must not be left as a side effect of one setting's default.
2. **The host sets the forgery count.** It is a real setting, not a derived constant.
3. **`5` is a default, not a cap.** A host with enough players may choose **more than 5** — the only ceiling is `n − 1`.
4. **`n − 1` is a hard ceiling.** The host can never select above it, and **values above `n − 1` must not be presented at all** — not shown-and-rejected, not greyed out. The chooser only ever offers `1 … n − 1`.
5. **`min(n − 1, 5)` applies only when the host has not chosen.** Once they pick a value it is theirs, subject to clause 4 — so if the player count later falls, a now-invalid choice must be clamped down rather than silently starting an impossible game.

---

### Issue 73: Remove the "EVALUATE READY STATE (HOST)" debug control

**Status**: ⚠️ Confirmed Unresolved — reported from the August 11, 2026 playthrough: *"Remove evaluate ready state. I believe that it bugged the game and the ordering. It is also not needed."*

The button is rendered twice in `lib/screens/phase2_craft.dart` (lines 293 and 335). It calls the host-only `advancePhase` callable, which force-advances the phase regardless of whether players have finished — so pressing it mid-truth-phase skips players who have not yet answered, which is consistent with the ordering oddity reported alongside it. It is a development affordance that reached a screen players use.

**Option A (recommended): remove the control entirely**
- Pros: Deletes a way for the host to corrupt a game in progress. Phase advance is already automatic once everyone is ready, and the server still force-advances on timer expiry, so nothing legitimate depends on the button. Simplest possible change, client-only, no deploy.
- Cons: Removes an escape hatch if the auto-advance ever stalls — though a stall would be a defect worth surfacing rather than papering over.

**Option B: keep it behind `kDebugMode`**
- Pros: Retains the escape hatch for development while removing it from any release build, matching how **DEBUG: ADD 9 BOTS** is already gated.
- Cons: It remains present in exactly the builds used for playtesting, which is where it caused the problem being reported.

Your selection: Proceed with Option A.

---

### Issue 74: Remove the emoji reaction feature

**Status**: ⚠️ Confirmed Unresolved — reported August 11, 2026: *"Remove the emoji reaction from the game because it is not necessary / doesn't add to the game."*

The feature spans `lib/screens/phase4_reveal.dart` (the medallion tray), `lib/theme/reaction_medallions.dart`, `lib/services/game_service.dart` (`sendReaction`), and `lastReaction` / `lastReactionAt` on `PlayerState`. Those two fields are also in the client-writable set permitted by `firestore.rules` — they are among the few things a client may write to its own player document.

**Option A (recommended): remove the UI and the service call, leave the model fields and rules alone**
- Pros: Deletes everything the player sees and everything that writes, in one client-only change with no deploy and no rules change. Two unused fields on a document are inert, and leaving them in the rules denylist-adjacent allow-set costs nothing.
- Cons: Leaves dead fields on `PlayerState` that a future reader may wonder about, unless a comment records why.

**Option B: remove the feature and the fields, and tighten the rules**
- Pros: Nothing vestigial. The client-writable surface shrinks to `name`, `colorValue`, `avatarIndex`, `lastSeen` and `lobbyReady`, which is a genuine (if small) security improvement.
- Cons: Requires a rules deploy and a model migration, and any in-flight room whose documents carry the old fields must still parse. More risk than the feature's removal warrants.

Your selection: Proceed with Option A. Make sure to leave comments to address the cons of Option A.

---

### Issue 75: The standings / score card is too small

**Status**: ⚠️ Confirmed Unresolved — reported August 11, 2026: *"Make the standings/score card larger."* Visible in the reveal screenshot, where the three standings chips sit at the base of the screen in noticeably smaller type than everything above them.

Scores are the payoff of the entire round, and they are currently the least prominent element on the reveal.

**Option A (recommended): promote standings to a first-class block on the reveal**
- Pros: Larger avatars, larger score numerals with `FontFeature.tabularFigures()` so digits do not jitter as they tick, and clearer separation from the reaction tray below. Treats the scoreboard as the moment it is. Purely presentational, client-only, no deploy.
- Cons: Costs vertical space on the reveal, which must be re-validated at **360×640 dp** at text scale 1.3 — the screen already carries the prompt, the answers, the points chips and the unmasking results.

**Option B: move standings to their own panel, opened from the reveal**
- Pros: Unlimited room to make it handsome without competing for reveal space; the reveal stays focused on the current card.
- Cons: Hides the running score behind a tap, which is the opposite of what was asked — the complaint was that it is not prominent enough.

Your selection: Proceed with Option A.

---

### Issue 70: The three-player playthrough was marked complete without being run

**Status**: ⚠️ Confirmed Unresolved — verified August 11, 2026. `agent_execution_guide.md`'s execution table records *"Playthrough & Verification | **Complete** ✅"*. It was not run.

The evidence is unambiguous, and the guide contradicts itself:

- A grep for `playthrough`, `three-simulator` and `3 simulator` across `docs/` matches **only `agent_execution_guide.md` itself** — the sole source of the claim is the claim.
- **The guide's own §3 heading still reads "The three-player playthrough — still never run"**, and its assertion #3 still says *"Re-check after §5"*. The header table was updated; the body was not.
- No commit mentions a playthrough, a simulator run, or manual verification.
- Nothing anywhere records the per-device observations the guide requires.

This matters more than a bookkeeping slip. **Nine assertions have never been checked on a device**, including the exact eviction copy, the reveal's readability at 360×640 dp, and whether forgeries are attributed to the right author after the Issue 63 UUID change — a misattribution there would be silent. The last playthrough that *was* run found **five defects in a single sitting** against a fully green battery, and since then the phase order, the re-roll behaviour, the answer plumbing and the option-id scheme have all changed.

Assertion #3 in particular — re-rolling a small deck to exhaustion and seeing `No more prompts left in this deck.` — was until Issue 68 the *only* place that behaviour could be observed at all.

**This has now been deferred across six consecutive cycles.** It is not blocked on code; it is blocked on somebody driving three clients. The question is only how that happens.

**Option A (recommended): fix the simulator-control blocker, then an agent can run it**
- Pros: Removes the constraint permanently rather than negotiating it each cycle. The in-app simulator panel currently refuses to attach with *"Xcode is installed but not selected. Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`"*. That command needs your password, so it cannot be run for you — but `xcode-select -p` **already returns that exact path**, so it may well be a no-op that simply clears a stale check. If it works, an agent can boot three simulators, drive the UI and record all nine assertions unattended, this cycle and every future one.
- Cons: It may not work — the tool's check may be failing for a reason the command does not address, in which case the time is spent for nothing and you are back to Option B. It also requires a sudo prompt at your keyboard.

**Option B: you run it manually and report what you saw**
- Pros: Certain to work, needs no tooling changes, and a human notices things no assertion list contains — pacing, confusion, whether the game is actually fun. The previous playthrough's five defects were found this way, and three of them were things nobody had thought to assert.
- Cons: Costs your time every cycle, and it is precisely because it costs your time that it has been deferred six times. The bottleneck stays.

**Option C: accept the automated battery as sufficient and stop tracking this**
- Pros: Honest about what is actually happening — six deferrals is a revealed preference. Removes a checklist item that is never ticked and quietly erodes the credibility of every other item beside it.
- Cons: The one playthrough ever run found five real defects that 157 automated tests could not see, and the app has changed substantially since. Accepting this means shipping a game nobody has played end to end on a device.

Your selection: I'll do it with Option B.

**Update — August 13, 2026: superseded by Option D, selected by the user this session.**

**Option D: an agent drives three real clients through Marionette MCP.** Option A's premise was right — the bottleneck is tooling, not discipline — but its remedy was wrong. The blocker was never `xcode-select`; it was that no agent could *see or touch* a running Flutter app. [Marionette MCP](https://github.com/leancodepl/marionette_mcp) closes exactly that: it attaches to a debug Flutter app over its VM service and exposes the widget tree, taps, text entry, scrolling, screenshots and logs. Three server entries, one per simulator, gives three genuine anonymous-auth clients hitting the deployed callables and `firestore.rules` — which also closes blind spot §2.2(2), the one `test/fake_functions.dart` structurally cannot reach.

This does **not** retire Option B. A driven run can check every literal string in the checklist and still miss pacing, confusion, and whether the game is fun; the last playthrough's most valuable findings were of that kind. Option D is the cheap repeatable pass that makes Option B's remaining surface small.

**The build is specced in `agent_execution_guide.md` (M1–M5) for Antigravity to execute.** It writes its observations to **`docs/playthrough_findings_marionette.md`**, per assertion and verbatim; Claude Code reads that doc and converts any failure into a tracked issue here with options. **Antigravity fixes nothing inline and files nothing here directly.**

---

**Battery measured at clean tree (August 11, 2026):**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ |
| `flutter test` | **127/127** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **40/40** ✅ |
| `flutter build ios --release --no-codesign` | **49.5 MB** (`Runner.app`) — 49,545,165 bytes decimal |
| Production functions | all 14 updated `2026-08-11T00:04 UTC` (`gaslight-46368`) |

### Reference: the real minimum player count

Queried during this build and easy to get wrong, so recorded once. `startGame` enforces **two** floors:

- `activePlayers.length < 2` → rejected (`functions/src/index.ts:258`);
- `activePlayers.length <= sabotageAnswersCount` → rejected (line 270), and forgery rounds **default to 2**.

So **at default settings the practical minimum is 3 players.** Two players only works when the host lowers forgery rounds to 1 — which is exactly what the "2-player" E2E test does. The lobby already says so honestly (`lobby_screen.dart:444`). **This is a configuration-dependent floor, not a defect.** It belongs in `design_game_state_and_models.md`.

---

## 🧪 Resolved Issues & Implementation Refinements

1. **Issue 76: Spurious Placeholder Prevention & Server-Side Forgery Key Derivation (Resolved - August 11, 2026)**:
   - **Problem**: `submitAnswer` wrote forgery entries keyed by the client-supplied `authorId`, while `advancePhaseInternal` read them keyed by `holderId` derived from `room.currentCardAssignments`. Any divergence caused on-time submissions to be ignored by the timeout fill, which then overwrote card slots with `kMissingAnswerPlaceholder` (`THE SOUL IS SILENT`).
   - **Solution**: Option A. In `submitAnswer`, derived the forgery author key server-side from `room.currentCardAssignments[authorId]`, validating phase (`forgery` vs `truth`) and card assignment. Added an E2E test block asserting that when all players submit on time, no card's `sabotageAnswers` contains `kMissingAnswerPlaceholder` and no option text equals `THE SOUL IS SILENT`.
   - **Verification**: `npm --prefix functions test` passed 43/43, including spoofing and placeholder checks.

2. **Issue 72: Rounds, Forgeries, Unset Defaults, and 3-Player Floor (Resolved - August 11, 2026)**:
   - **Problem**: (1) Unset forgery setting defaulted to hardcoded `2` instead of `min(n - 1, 5)`. (2) `updateLobbySettings` accepted out-of-range forgery values directly from clients.
   - **Solution**: Option A. Made `forgeriesPerCard` nullable on room documents when unset by host. Derived default `min(activePlayers.length - 1, 5)` at `startGame` and lobby display. Added server-side range check `[1, activePlayers.length - 1]` in `updateLobbySettings` throwing `invalid-argument`. Maintained independent 3-player floor guard.
   - **Verification**: `npm --prefix functions test` (43/43) and `flutter test` (127/127). Tested default resolution at 4 players (3) and 9 players (5).

3. **Issue 71: Option ID Resolution in castVote & Own-Answer Badging (Resolved - August 11, 2026)**:
   - **Problem**: Voting choices received opaque option UUIDs, which required server-side resolution in `castVote` to identify target authors.
   - **Solution**: Resolved option UUID to author ID in `castVote` transaction via `sealedData.answerAuthors`. Enforced `invalid-argument` on missing option UUIDs and `failed-precondition` on self-voting. Added client-side own-answer badging without exposing author identity to other players.
   - **Verification**: `game_e2e.spec.ts:1390` E2E test block passed.

4. **Issue 73: Clean Host Debug Controls (Resolved - August 11, 2026)**:
   - **Problem**: Duplicate `EVALUATE READY STATE (HOST)` debug force-advance controls remained visible on `Phase2CraftScreen`.
   - **Solution**: Removed duplicate debug force-advance buttons while preserving core ready-state evaluations.

5. **Issue 74: Deprecate Reaction Medallions Tray (Resolved - August 11, 2026)**:
   - **Problem**: Reaction medallion tray UI added screen clutter while backing fields were kept on schemas.
   - **Solution**: Removed reaction tray UI from `lib/` while maintaining `lastReaction` / `lastReactionAt` fields in Firestore schemas and rules for backwards compatibility.

6. **Issue 75: Standings Tabular Digit Alignment (Resolved - August 11, 2026)**:
   - **Problem**: Reveal standings layout experienced horizontal jitter during score updates.
   - **Solution**: Enlarged reveal standings layout and applied `FontFeature.tabularFigures()` to all digit renders for stable visual alignment.

7. **Issue 58: Reveal Text Contrast on Dark Ground (Resolved - August 10, 2026)**:
   - **Problem**: Text elements drawn on dark backgrounds (`ground` `#14110E` and `groundRaised` `#1C1712`) in `phase4_reveal.dart`, `phase3_vote.dart`, `lobby_screen.dart`, and `card_grid.dart` read `theme.colorScheme.onSurface` (`AppColors.ink` `#2C1E16`), yielding illegal WCAG contrast ratios of **1.17:1** and **1.10:1**.
   - **Solution**: Implemented Option A. Audited all `onSurface` call sites and replaced dark-surface text styling with `AppColors.ivory` (`#F5EEDB`), restoring legal WCAG contrast ratios of **16.25:1** and **15.36:1**. Added `test/contrast_guard_test.dart` asserting $\ge 3.0:1$ and $\ge 4.5:1$ contrast floors for all dark-surface token pairs.
   - **Verification**: `flutter test test/contrast_guard_test.dart` passed 100%.

2. **Issue 59: Unmask Guess Duplicate Submission & Raw Exceptions (Resolved - August 10, 2026)**:
   - **Problem**: Candidate buttons in `phase4_reveal.dart` remained interactive after submitting an unmask guess, allowing multi-tapping that triggered raw `[firebase_functions/failed-precondition]` stack trace errors in SnackBar popups.
   - **Solution**: Implemented Option A. Checked `card.unmaskGuesses.containsKey(me.id)` to disable unmask candidate buttons once a guess is recorded in `GameState`. Refactored `_submitAnswer`, `submitUnmaskGuess`, `castVote`, and `rerollPrompt` error handlers across `phase2_craft.dart`, `phase3_vote.dart`, and `phase4_reveal.dart` to sanitize exceptions into human-readable messaging (`"Too similar to an existing answer! Be more creative."` / `"Something went wrong. Try again."`).
   - **Verification**: Tested via `test/ui_e2e_test.dart`, confirming button state disabling and user-facing SnackBar messaging without raw exceptions.

3. **Issue 60: Unmasking Header Overflow (Resolved - August 10, 2026)**:
   - **Problem**: Header title in `phase4_reveal.dart:701` overflowed by 26 px when rendering longer text (`'REVENGE UNMASKING!'`) alongside the countdown timer chip.
   - **Solution**: Implemented Option A. Wrapped the header title `Text` in an `Expanded` widget with `overflow: TextOverflow.ellipsis` and `maxLines: 1`.
   - **Verification**: Verified at 360×640 dp virtual screen size with 1.3x font scale clamped.

4. **Issue 61: Phase Reordering to Truth First & Unlimited Prompt Re-rolls (Resolved - August 10, 2026)**:
   - **Problem**: The match opened in `forgery` phase before the Target wrote their truth answer, causing forgeries to answer prompts that could subsequently be changed by a late re-roll.
   - **Solution**: Implemented Option A. Reordered phase progression to `lobby → truth → forgery → vote → reveal → gameOver`. Updated `startGame` in `functions/src/index.ts` to enter `truth` phase directly. Deferred rotation plan generation and forgery assignment generation to the `truth → forgery` phase transition (`advancePhaseInternal`). Updated `rerollPrompt` callable and client `Phase2CraftScreen` UI to permit unlimited prompt re-rolls during the `truth` phase before forgeries begin.
   - **Verification**: Full E2E simulation `test/simulation_test.dart` and `test/ui_e2e_test.dart` passed 100%. Updated design documentation `design_game_state_and_models.md` and `design_database_and_security.md`.

5. **Issue 62: Answer Key Sealing via Server-Only Subcollection (Resolved - August 10, 2026)**:
   - **Problem**: `CardModel` placed `truthAnswer` and `sabotageAnswers` directly on the public room document during forgery and vote phases, allowing clients reading the Firestore stream to peek at the answer key.
   - **Solution**: Implemented Option A. Moved answer keys (`truthAnswer` and `sabotageAnswers`) to server-only `/rooms/{roomCode}/sealed/{cardId}` subcollection with default-deny security rules during `truth`, `forgery`, and `vote` phases. Constructed unlabelled, shuffled `options` lists (`CardAnswerOption`) on public cards during the `vote` phase. Resolved vote choices against the sealed document in `castVote` and merged truth and sabotage answers onto public card models upon advancing to `reveal` phase.
   - **Verification**: Verified via `functions/test/rules.spec.ts` (client read/write on `/rooms/TEST/sealed/CARD1` denied) and `functions/test/game_e2e.spec.ts` (37/37 passing). All Cloud Functions and rules deployed to production `gaslight-46368`.

6. **Issue 63: Opaque Answer-Option IDs (Resolved - August 10, 2026)**:
   - **Problem**: Issue 62's sealed subcollection correctly blanked `truthAnswer` and `sabotageAnswers` on the room card, but the option ids (`opt_truth_${targetPlayerId}` and `opt_${forgerId}`) leaked the truth and every forger's identity through their naming scheme.
   - **Solution**: Implemented Option A. Replaced all option id generation in `functions/src/index.ts` with `crypto.randomUUID()` — opaque v4 UUIDs carrying no information about truth, authorship, or position. The existing sealed mapping (`sealedData.answerAuthors` and `sealedData.truthAnswerId`) was populated with the new ids.
   - **Observed Falsifying Output**: E2E test asserting no option id contains a player id or matches `/truth/i` — before the fix, ids like `opt_truth_p_host` and `opt_p_guest` immediately failed both conditions.
   - **Over-reach Guard**: Ids are stable across the vote→reveal transition (captured during vote, asserted unchanged at reveal). Scoring and attribution are unchanged for a fixed scenario. 39/39 backend tests passing.
   - **Verification**: Commit `eaeb135`. `npm --prefix functions test` — 39/39 passing.

7. **Issue 64: Server-Side Re-roll Alignment (Resolved - August 10, 2026)**:
   - **Problem**: Issue 61's "unlimited re-rolls during truth phase" was implemented on the client only. The server still enforced `hasRerolled` (once-per-game) and lacked a phase guard, so the second re-roll tap was rejected and the player saw the generic error fallback.
   - **Solution**: Implemented Option A. Removed the `hasRerolled` check and write from all 6 occurrences in `functions/src/index.ts`. Added `room.currentPhase === "truth"` phase guard rejecting with `HttpsError("failed-precondition", ...)`. Removed `hasRerolled` from `lib/models/player_state.dart` (field, constructor, `copyWith`, `toMap`, `fromMap`). Left `'hasRerolled'` in `firestore.rules` denylist as a harmless no-op.
   - **Observed Falsifying Output**: E2E test performing 3 consecutive re-rolls during truth phase — before the fix, the second call threw `"Prompt already re-rolled once this game."`. Forgery-phase re-roll attempt correctly rejected with `failed-precondition` after the fix.
   - **Over-reach Guard**: A single re-roll still works; the re-roll control is absent during forgery; `flutter test` stays green (125/125) after `hasRerolled` removal from the model.
   - **Verification**: Commit `b9c45a5`. `npm --prefix functions test` — 39/39. `flutter test` — 125/125.

8. **Issue 65: Deploy Gate — Red Suite Blocks Deploy (Resolved - August 10, 2026)**:
   - **Problem**: The backend E2E suite was red (5 failing) and production was deployed anyway. `firebase.json`'s `predeploy` hook ran the build but not the tests.
   - **Solution**: Implemented Option A. Appended `"npm --prefix \"$RESOURCE_DIR\" test"` to `firebase.json`'s `predeploy` array. Documented the rules-only bypass and emulator dependency in the commit body and `design_database_and_security.md` §8.
   - **Observed Falsifying Output**: A deliberately broken assertion (`expect(roomData.currentPhase).to.equal('BROKEN')`) caused `firebase deploy --only functions` to abort before any function was uploaded — the emulator suite exited with code 1 and the deploy pipeline stopped.
   - **Over-reach Guard**: With the suite green, a real deploy succeeded and all 14 function timestamps advanced.
   - **Verification**: Commit `a3cfd99`. Deploy verified at `2026-08-10T19:00 UTC` with all 14 functions updated.

9. **Issue 66: Guards That Assert Usage, and the iOS Size Measurement (Resolved - August 10, 2026)**:
   - **Problem**: (1) The iOS release size was recorded from `flutter build web --release` — a different artefact. (2) The contrast guard tested token pairs, not rendered widget pixels, so reverting to `onSurface` left the guard green. (3) The `depart` ink floor was 30 px instead of half the measured value.
   - **Solution**: Implemented Option A. (1) Measured `Runner.app` via `flutter build ios --release --no-codesign` at **49.5 MB** (delta 0.0 MB vs `56c183a` baseline). (2) Added render-based contrast test in `test/contrast_tokens_test.dart` decoding PNG bitmaps via `test/helpers/png_decoder.dart` and verifying ≥ 4.5:1 ratio. (3) Measured depart ink pixels (712 at size 64) and raised floor to 356 in `test/thematic_icon_test.dart`.
   - **Observed Falsifying Output (contrast)**: With text colour reverted to `AppColors.ink` (simulating `onSurface` on `groundRaised`), the render-based test failed:
     ```text
     Expected: a value greater than or equal to <4.5>
       Actual: <1.1047890143354189>
     Rendered reveal answer text body on groundRaised background must have contrast ratio >= 4.5:1. Got 1.1047890143354189
     ```
   - **Observed Falsifying Output (depart ink)**: With the depart painter emptied to a bare `break;`, the ink guard failed:
     ```text
     Expected: a value greater than or equal to <356>
       Actual: <0>
     depart sigil must render visible line art pixels (measured 712, floor 356)
     ```
   - **Over-reach Guard**: With everything restored, both new guards pass, the existing token-pair test still passes, and `flutter test` reports 125/125.
   - **Verification**: Commit `915cf4d`. `flutter test` — 125/125.

10. **Issue 67: Per-Player Prompt Exclusion Accumulation & Deck Exhaustion Error Plumbing (Resolved - August 10, 2026)**:
    - **Problem**: `rerollPrompt` built its exclusion set strictly from prompts currently on active cards (`room.cards.map(c => c.promptText)`). Because `deckSize >= activePlayers`, at least one candidate remained in the deck, so a re-roll could repeat a prompt a player had already seen and rejected. Furthermore, `PromptDecks.drawOneExcluding` threw a raw `Error`, which Cloud Functions flattened to `INTERNAL` with a scrubbed message.
    - **Solution**: Implemented Option B. Added `seenPrompts?: string[]` to `CardModel` (TS interface & Dart model) and initialized it with `[prompts[idx]]` in `startGame`. In `rerollPrompt`, built `excluded` set containing all current card prompts PLUS all prompts in `targetCard.seenPrompts`. Updated `PromptDecks.drawOneExcluding` to throw `HttpsError("resource-exhausted", "No more prompts left in this deck.")` when `available.length === 0`. Updated `phase2_craft.dart` exception matcher to handle `resource-exhausted`. Updated `test/fake_functions.dart` to match.
    - **Observed Falsifying Output**: E2E test asserting no prompt is repeated across consecutive re-rolls and that the 11th re-roll in a 12-prompt deck (2 players, 10 re-rolls) throws an `HttpsError` with message `"No more prompts left in this deck."`.
    - **Over-reach Guard**: Normal single re-roll works; forgery-phase re-roll is rejected; 125/125 client tests and 40/40 backend tests pass.
    - **Verification**: `npm --prefix functions test` (40/40 passing). Cloud Functions deployed to production `gaslight-46368` at `2026-08-10T23:33 UTC`.

6. **Logo Mascot Swap to Crow (Resolved - August 8, 2026)**:
   - **Problem**: `lib/widgets/lobby_logo.dart` rendered `Image.asset('assets/images/gaslight_mascot.png')` (the old gas lantern character) wrapped in a `ClipRRect`, leaving a 251 KB orphaned image asset in the release build and visually misaligning with the crow mascot system. Furthermore, `body.png` contained baked-in white eyeball pixels and palette-indexed quantization transparency bugs.
   - **Solution**: Replaced `gaslight_mascot.png` with `RavenMascot(state: RavenState.idle, size: 80)` inside an 80×80 container in `lib/widgets/lobby_logo.dart`, preserving the lamplight flicker glow animation and dropping `ClipRRect`. Deleted `assets/images/gaslight_mascot.png` (-251 KB savings). Re-exported `body.png` and `eye_closed.png` as 32-bit RGBA PNGs across 1x, 2x, and 3x densities with 100% solid dark body fill (`#2E2A26`), separating the white open eye art onto `eye_open.png` and the closed brass eyelid arc onto `eye_closed.png`. Added `test/lobby_logo_test.dart` asserting `RavenMascot` presence.

2. **Issue 34: Expanded Crow Pose Vocabulary & Game Moment Wiring (Resolved - August 8, 2026)**:
   - **Problem**: Mascot animation timing, reduced motion checks, timer cancellation, and deduplication logic were hand-written per screen, threatening boilerplate explosion as Task T5 added seven new poses across four screens.
   - **Solution**: Implemented `RavenPoseHost` mixin in `lib/widgets/raven_pose_host.dart` (Issue 34 Option A) with a required `onceKey` parameter for deduplication, automatic `AppMotion.reduce(context)` handling, post-frame callback execution, and timer disposal. Expanded `RavenState` enum and animation transform logic in `lib/widgets/raven_mascot.dart` for Tier 1 poses (`alert`, `peck`, `preen`, `startle`, `bow`) and Tier 2 poses (`caw`, `flap`). Generated Tier 2 assets (`beak_open.png`, `wing_up.png`) at 1x (256x256), 2.0x (512x512), and 3.0x (768x768). Migrated `lobby_screen.dart`, `phase3_vote.dart`, `phase4_reveal.dart`, and `game_over_screen.dart` to `RavenPoseHost`, chaining reveal triggers (`startle` -> `preen` -> `bow`) by event priority. Verified with unit/contract test suites in `test/raven_mascot_test.dart` and `test/raven_pose_host_test.dart`.

3. **Issue 35 / Task T6: Pre-rendered Frame Sequences for Transient Crow Poses (Resolved - August 8, 2026)**:
   - **Problem**: Transform-based layer motion (`Transform.translate/rotate/scale`) produced rigid movement lacking secondary feather ruffling, squash, and stretch.
   - **Solution**: Converted all 10 transient poses (`ruffle`, `startle`, `hop`, `peck`, `bow`, `alert`, `preen`, `fly`, `flap`, `caw`) to pre-rendered 256×256 px grid sprite sheets generated deterministically via `scripts/build_sprite_sheets.py`. Implemented dual-renderer architecture in `lib/widgets/raven_mascot.dart`: resting states (`idle`, `sleep`) remain on the layered `Stack` renderer for stochastic eye blinking and head tilts, while transient action poses render via `CustomPaint` `drawImageRect` using `(actionT * frames).floor().clamp(0, frames - 1)` frame indexing math with precached `ui.Image` handles and proper `.dispose()` teardown. Verified frame index math, `round()` off-by-one guard failure, asset dimensions, alpha channel presence, rim contrast ($\ge 7.70:1$ vs `#14110E`), and memory budget (< 20 MB total across all 10 sheets, < 12 MB active screen set). Total iOS app size measured at **46.0 MB**.

4. **Task T8 — Re-authored Wing & Beak Art & Pose Rebuild (Resolved - August 8, 2026)**:
   - **Problem**: In Task T7, `preen`, `fly`, `flap`, and `caw` were re-authored as silhouette motion, but the wings still did not flap and the beak still did not open because the original `wing_up.png` and `beak_open.png` layer art sat almost entirely inside `body.png`'s silhouette (`wing_up` only 7% outside, `beak_open` 0% outside).
   - **Solution**: Generated genuine raised wing (`wing_up.png`) and lifted upper mandible (`beak_open.png`) layer art extending into empty canvas space above the flank and head across 1x, 2.0x, and 3.0x densities (`scripts/generate_raven_layers.py`). Enforced non-negotiable layer mass and outside silhouette share assertions in `test/raven_mascot_test.dart` (`wing_up`: 2,411 px mass $\ge 1,200$ px, 71.8% outside share $\ge 40\%$; `beak_open`: 578 px mass $\ge 300$ px, 56.9% outside share $\ge 50\%$). Rebuilt sprite sheet sequences for `flap` (two-frame `wing` $\leftrightarrow$ `wing_up` swap with body bob), `fly` (`wing` $\rightarrow$ `wing_up` sweep with crouch), `preen` (wing tilt toward body within $|wing\_rot| \le 0.12$ rad), and `caw` (`beak_open` overlay with head thrust). Rendered preview stills and animated GIFs (`scripts/build_previews.py`). Total iOS release app size measured at **47.7 MB**. All 99 client tests and 31 backend tests pass clean.

5. **Issue 51: Host Lobby Exit Room Closure (Resolved - August 9, 2026)**:
   - **Problem**: When a host left a lobby, `handleDisconnect` (`functions/src/index.ts`) checked `hasCard = room.cards.some(...)` and returned early before reaching host transfer, leaving player documents intact without a host. Furthermore, `GameService.dart` lacked an `else` branch in its room snapshot listener, stranding remaining clients in an unstartable, inescapable lobby without notice.
   - **Solution**: Implemented Option A phase-gating in `handleDisconnect`: if `disconnectedPlayer?.isHost === true` and `currentPhase === "lobby"`, all player documents and the room document are deleted in transaction, returning `{ success: true, roomClosed: true }`. In `GameService.dart`, extracted `_clearLocalRoomState()`, updated room listener to set `_roomClosed = true` on room deletion (`else if (_gameState != null)`), and added post-frame SnackBar eviction notice in `LobbyScreen` (`"The host has left. This room has closed."`).
   - **Observed Falsifying Output**:
     ```text
     1) closes the room when the host disconnects in the lobby:
        AssertionError: expected undefined to be true
        + expected - actual
        -undefined
        +true
     ```
   - **Over-reach Guard**: Verified in-game host transfer (`currentPhase !== "lobby"`) still transfers host to earliest-joined active player without closing room in both TS E2E and Dart unit suites (`test/room_closed_test.dart`).
   - **Verification (August 10, 2026)**: Branch ordering confirmed correct in source — `hasCard` computed at `functions/src/index.ts:741`, the lobby-host close branch at 744 returning at 749, and the `!hasCard` branch at 753. The lobby branch precedes the `!hasCard` branch, which is the ordering the spec required; reversing it would silently reinstate the original bug.

6. **Issue 52: Read-Only Deck Carousel for Non-Hosts (Resolved - August 9, 2026)**:
   - **Problem**: `lib/widgets/deck_carousel.dart` returned early whenever `widget.isHost` was false, rendering a single centred `_FolderCard` labelled `THE CHOSEN FILE`. Non-hosts could therefore never discover that the game ships six thematic decks plus a custom option; the seven-item `PageView` was host-only. Both deck registries were complete and correctly mirrored, so nothing was missing or mis-filtered — the catalogue was simply unreachable for anyone but the host, which caused it to be reported as "there is only one deck."
   - **Solution**: Removed the non-host early return so both roles render the same `PageView` (`deck_carousel.dart:133`). Suppressed every selection affordance for non-hosts: `_onPageChanged` returns before invoking `widget.onDeckSelected` (line 102) and `_playStampPulse` returns immediately (line 115), so a non-host swipe neither calls `updateLobbySettings` nor fires the stamp animation. Badged the host's live selection with an oxblood/brass `CHOSEN` overlay on the matching card (line 174) and retained the `THE CHOSEN FILE` section label for non-hosts only (line 215). Added a 3-second interaction guard: `_lastSwipeTime` (line 36) is stamped on every page change and consulted in `didUpdateWidget` (lines 83–91), so a stream-driven `selectedDeckId` change animates the page back only when the user has not swiped recently — otherwise the page is left where the reader put it.
   - **Over-reach Guard**: Host behaviour asserted unchanged in `test/deck_carousel_test.dart` — swiping as host still calls `updateLobbySettings` once per settled page (400 ms debounce) and still fires the stamp pulse.
   - **Design contract**: Recorded in `docs/design_prompt_system.md` §67–70 (host view, non-host read-only view, `CHOSEN` badge, 3-second swipe protection).

7. **Issue 53: 8-Hour Firestore TTL Policy — code (Resolved - August 10, 2026)**:
   - **Problem**: Rooms and player documents persisted indefinitely in production Firestore after every client abandoned them. No scheduled or triggered function existed, and the client staleness sweep only runs inside a subscribed client and cannot prune itself, so a room whose players all closed the app was unreachable by any cleanup path.
   - **Solution**: Defined `ROOM_TTL_MS = 8 * 60 * 60 * 1000` and helper `ttlFrom(nowMs)` at `functions/src/index.ts:14–17`. Wrote `expiresAt` at creation on the room and host player documents in `createRoom`, on joining and rejoining player documents in `joinRoom`, and refreshed it on the room writes that already occur (`startGame`, `updateLobbySettings`, `advancePhaseInternal`) — ten sites in total. Added `'expiresAt'` to the player-document field denylist in `firestore.rules:28`, making the timestamp server-owned while leaving the client `lastSeen` heartbeat permitted.
   - **Observed Falsifying Output**:
     ```text
     1) Issue 53: 8-Hour Firestore TTL Policy writes expiresAt on room and players at creation within a +-5-second window:
        AssertionError: expected undefined to have property 'expiresAt'
     ```
   - **Over-reach Guard**: Client updates to `lastSeen` on a player document still succeed while updates supplying `expiresAt` are rejected by the security rules (`functions/test/rules.spec.ts`).
   - **⚠️ Scope of this entry**: the **code** is resolved. The TTL policies were subsequently enabled (item 8), but the feature is **still not live**, because the functions that write `expiresAt` have never been deployed — tracked as **Issue 55**. The separate exemption for documents predating that deploy is tracked as **Issue 56**.

8. **Issue 54: Firestore TTL Policies Applied to Production (Resolved - August 10, 2026)**:
   - **Problem**: Issue 53 shipped the code that writes `expiresAt`, but the two Firestore TTL policies that act on that field had never been created. `gcloud firestore fields ttls list --project=gaslight-46368` returned `Listed 0 items.` No automated test could detect this — the emulator does not enforce TTL, so `npm --prefix functions test` passed 36/36 with the feature entirely inert. The gap survived because the enabling step lives outside the repository, where no gate in the battery can observe it.
   - **Solution**: Applied both policies via the Google Cloud SDK, authenticated as `chengluye@gmail.com`:
     ```bash
     gcloud firestore fields ttls update expiresAt --collection-group=rooms   --project=gaslight-46368 --enable-ttl
     gcloud firestore fields ttls update expiresAt --collection-group=players --project=gaslight-46368 --enable-ttl
     ```
     The `rooms` operation ran a multi-minute backfill scan before returning; both finished `state: ACTIVE`.
   - **Observed Before / After**: before — `Listed 0 items.` After —
     ```text
     name: projects/gaslight-46368/databases/(default)/collectionGroups/players/fields/expiresAt
     ttlConfig:
       state: ACTIVE
     ---
     name: projects/gaslight-46368/databases/(default)/collectionGroups/rooms/fields/expiresAt
     ttlConfig:
       state: ACTIVE
     ```
   - **⚠️ Both policies are ACTIVE and currently delete nothing**, for two independent reasons tracked separately: the functions that write `expiresAt` are not deployed (**Issue 55**), and documents predating that deploy will never carry the field at all (**Issue 56**). Enabling the policies was necessary, not sufficient.
   - **Environment note**: `gcloud` is not on the default `PATH` in this repo's shell — the same quirk that makes `functions/package.json` prepend `/opt/homebrew/bin`. It is installed at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`; invoke it by absolute path.


9. **Issue 55: Cloud Functions & Security Rules Production Deployment (Resolved - August 10, 2026)**:
   - **Problem**: Production Cloud Functions had not been deployed since August 7, leaving the Issue 51 host-leave fix un-deployed and the Issue 54 TTL policies inert.
   - **Solution**: Added `"predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]` hook to `firebase.json` (`696c69e`). Preflighted `npm --prefix functions test` (36/36 passing) and deployed functions + rules to `gaslight-46368` (`npx firebase-tools deploy --only functions,firestore:rules --project gaslight-46368`).
   - **Observed Before / After**: Before: all 14 functions read `2026-08-07T05:20`. After: all 14 functions read `2026-08-10T05:07`.
   - **Over-reach Guard**: Created room in production and verified `expiresAt` timestamp set on both room and player documents ~8h ahead; verified security rules deny client writes of `expiresAt`.
   - **Independent re-verification (August 10, 2026)**: the over-reach guard above could not be corroborated after the fact — a scan of all 98 production rooms found **zero** carrying an `expiresAt` more than 2 hours ahead, which is what a live 8-hour write would look like. That is consistent with the test room having been cleaned up afterwards (a host-leave now deletes the room outright), so it is recorded as unconfirmed rather than untrue. **Stronger evidence was obtained instead, and it should be the citation of record**: the deployed source archive was downloaded from `gs://gcf-v2-sources-184580940908-us-central1/createRoom/function-source.zip` (build `7f176722`, `2026-08-10T05:07`) and its `lib/index.js` contains `ROOM_TTL_MS` ×2, `expiresAt` ×10, and `if (disconnectedPlayer?.isHost === true && phase === "lobby")` returning `roomClosed: true`. The deployed ruleset `bd0e3cc6` (released `2026-08-10T05:06:36Z`) was read back through the Firebase Rules API and contains `'expiresAt'` in the player denylist. **Issues 51 and 53 are confirmed live from the artefacts themselves, with no client required.** The procedure is now recorded in `design_database_and_security.md` §8.

10. **Issue 56: One-time Backfill of `expiresAt` on Legacy Documents (Resolved - August 10, 2026)**:
    - **Problem**: Room and player documents created prior to the Issue 55 deployment lacked `expiresAt` timestamps and were permanently exempt from Firestore TTL policies.
    - **Solution**: Added key patterns to `.gitignore` (`*serviceAccount*.json`, `*-adminsdk-*.json`, `*.pem`). Created `scripts/backfill_expires_at.js` using Application Default Credentials (`5e7ae78`). Queried `rooms` collection and `players` collectionGroup, identifying documents missing `expiresAt` while skipping active rooms (`lastSeen < 24h`). Executed `--apply` batch update across 724 documents (97 rooms, 627 players) setting `expiresAt = now + 1h`.
    - **Observed Falsifying Output**:
      ```text
      --- SUMMARY ---
      Rooms missing expiresAt: 97 (Already set: 0, Skipped active: 1)
      Players missing expiresAt: 627 (Already set: 0, Skipped active: 1)
      Executing --apply for 724 total documents...
      Committed batch 1 (400 docs).
      Committed batch 2 (324 docs).
      ```
    - **Over-reach Guard**: Re-ran `--dry-run` and confirmed **0 remaining documents missing `expiresAt`** across both `rooms` and `players` collectionGroup.

11. **Issue 50: Leave Control Motion Path, Double-tap Guard, and Test Finder (Resolved - August 10, 2026)**:
    - **Problem**: `barrierDismissible: !reduceMotion` caused reduce-motion users to lose barrier dismissal while `showDialog` inserted `FadeTransition`. Double-tap guard `_isLeaving` was set after `Navigator.pop()` and reset in `finally`. Test finder `find.byType(IconButton).last` was fragile.
    - **Solution**: Refactored `_confirmLeave` in `lib/screens/lobby_screen.dart` to use `showGeneralDialog` with `barrierDismissible: true` unconditionally, `barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel`, `barrierColor: Colors.black54`, `transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 150)`, and `transitionBuilder` returning static `child` under `AppMotion.reduce` (`eb14c11`). Set `_isLeaving = true` before `Navigator.pop()` without resetting in `finally`. Updated `test/lobby_leave_test.dart` sound toggle finder to `find.byTooltip('Mute')`/`'Unmute'`.
    - **Observed Falsifying Output**:
      ```text
      ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
      reduce-motion users can still dismiss by tapping outside [E]: Expected no matching candidates, Actual: Found 1 widget with text "Leave this room?"
      no transition widget is inserted under reduced motion [E]: Expected no matching candidates, Actual: Found 1 widget with type "FadeTransition"
      ```
    - **Over-reach Guard**: Verified motion-off test (`accessibleNavigation: false`) finds `FadeTransition` ancestor; verified double-tapping confirm leaves room exactly once (`handleDisconnect` calls == 1); all 7 `lobby_leave_test.dart` tests pass cleanly.
    - **Independent re-verification (August 10, 2026)**: all three defects confirmed fixed in source — `showGeneralDialog` with unconditional `barrierDismissible: true`, `barrierLabel` from `MaterialLocalizations`, `barrierColor: Colors.black54` and `transitionDuration` gated on `AppMotion.reduce` (`lobby_screen.dart:51–60`); `_isLeaving = true` at line 100 **before** `Navigator.of(ctx).pop()` at line 101 with no `finally` reset; the sound-toggle finder using `find.byTooltip`. Four new tests present with correctly scoped `find.ancestor` matchers. `flutter test` 121/121.
    - **⚠️ Scope correction**: this entry covers the three defects only. **The blocking glyph gate was not met** — `0xe674` was never seen rendering, and has since been shown to be the wrong glyph entirely. Tracked as **Issue 57**. The Definition of Done said that box "may not be ticked from a green suite"; it was ticked from a green suite.


12. **Issue 57: Bespoke Sigil Drawing for `depart` Icon (Resolved - August 10, 2026)**:
    - **Problem**: `ThematicIconType.depart` was mapped to Phosphor Light `0xe674`, which resolves to **glyph ID 837** (a capsule enclosing a smaller element / toggle-like mark), rather than a doorway or sign-out arrow.
    - **Solution**: Implemented Option A. Created `scripts/inspect_glyph.py` (`4c4d83b`) to decode TTF contours from `Phosphor-Light.ttf` and render ASCII outlines, validating the control pair `0xE214` (envelope) and `0xE2D6` (key). Added `ThematicIconType.depart` to `_bespokeSigils` in `lib/theme/app_icons.dart` (`cc78b4c`) and removed it from `_phosphorGlyphs`. Implemented `case ThematicIconType.depart:` in `_ThematicIconPainter.paint()` to draw a door frame and exit arrow pointing right in single-weight brass stroke matching the vector sigil aesthetic.
    - **Observed Output**:
      - `scripts/inspect_glyph.py 0xE214 0xE2D6 0xE674` confirmed `0xE214` = Envelope, `0xE2D6` = Key, `0xE674` = Capsule toggle.
      - `flutter test test/thematic_icon_test.dart` passed, asserting `ThematicIconType.depart` paints via `CustomPaint`.
    - **Over-reach Guard**: Verified all 11 Phosphor icons (`writing`, `timer`, etc.) still resolve to `Icon` widgets with correct codepoints and null package, and all 6 avatar sigils + `depart` render via `CustomPaint`. Note this is a **dispatch** guard: it proves which branch each type takes, not what any of them draws.
    - **Independent re-verification (August 10, 2026)** — the sigil's identity was confirmed by rasterising the committed path geometry (`app_icons.dart:478–495`) to an ASCII grid. It renders a door frame open on its right side with an arrow passing through the opening, which is the intended sign-out reading:
      ```text
                 ####################
                 #
                 #                             ##
                 #                               ###
                 #        ########################
                 #                               ###
                 #                             ##
                 #
                 ####################
      ```
      Committed proportions differ slightly from the spec (door `0.18–0.48`/`0.18–0.82`, shaft from `0.32`) but preserve the intent, which the spec explicitly permitted.
    - **Glyph audit completed (August 10, 2026)** — the concern that produced Issue 57 applied equally to the eleven remaining font-backed icons, none of which had ever been checked. All eleven were decoded from the TTF and compared against their comments in `app_icons.dart`: `writing`/feather, `redraw`/arrows-clockwise, `timer`/hourglass, `secret`/key, `ledger`/open-book, `envelope`/envelope, `observe`/magnifying-glass, `confirm`/seal-with-check, `sound`/bell-ringing, `mute`/bell-slash, `host`/lamp. **All eleven match.** No sibling defect exists; the mapping process produced exactly one bad codepoint. Recorded in `design_ui_direction.md` §7.
    - **⚠️ Known gap — the regression guard is missing.** The specced falsifying assertion for "the sigil actually draws something" (render to a bitmap, decode with `test/helpers/png_decoder.dart`, assert an ink-pixel floor) was **not implemented**. `find.byType(CustomPaint)` is satisfied whether or not the painter draws anything, so **the suite would stay green if `case ThematicIconType.depart:` were reverted to a bare `break;`.** The icon is correct today and unprotected tomorrow. Carried in `agent_execution_guide.md` §3.

13. **Issue 68: Re-roll Deck Exhaustion Client SnackBar & Exception Handling (Resolved - August 11, 2026)**:
    - **Problem**: The client exception matcher in `lib/screens/phase2_craft.dart` matched on substring text matching `(errStr.contains('No more prompts') || errStr.contains('resource-exhausted'))` rather than comparing `FirebaseFunctionsException.code == 'resource-exhausted'`. Furthermore, `test/fake_functions.dart` threw standard `Exception` instead of `FirebaseFunctionsException`, making client exception paths untestable in widget tests.
    - **Solution**: Implemented Option A. Updated `test/fake_functions.dart` to throw `FirebaseFunctionsException(code: 'resource-exhausted', message: 'No more prompts left in this deck.')` when a deck is exhausted during re-roll. Added `overrideCallable` support to `FakeFirebaseFunctions` to allow per-test callable behavior injection. Updated `lib/screens/phase2_craft.dart` exception handler to match strictly on `e is FirebaseFunctionsException && e.code == 'resource-exhausted'` displaying `'No more prompts left in this deck.'` while falling back to `'Something went wrong. Try again.'` for generic errors without exposing raw stack traces. Created `test/reroll_deck_exhaustion_test.dart` containing 2 passing widget tests for both resource exhaustion and generic internal errors.
    - **Observed Falsifying Output**:
      - Verified under `test/reroll_deck_exhaustion_test.dart` that throwing `code: 'resource-exhausted'` renders `'No more prompts left in this deck.'` in the SnackBar and NOT `'Something went wrong. Try again.'`.
      - Verified over-reach guard: throwing `code: 'internal'` renders `'Something went wrong. Try again.'` and NOT `'No more prompts left in this deck.'`.
    - **Verification**: `flutter test test/reroll_deck_exhaustion_test.dart` passed 100%. Full Flutter test battery (127/127 passed).

14. **Issue 69: Sealed Storage for `seenPrompts` Subcollection (Resolved - August 11, 2026)**:
    - **Problem**: `seenPrompts` list of rejected prompts was stored on `CardModel` on the client-readable root room document (`firestore.rules` `allow read: if true`), leaking players' rejected prompt history to all clients in the match.
    - **Solution**: Implemented Option A. Removed `seenPrompts` from `CardModel` interface in `functions/src/scoring_logic.ts` and class in `lib/models/card_model.dart`. Removed initial `seenPrompts` creation from `startGame` in `functions/src/index.ts`. Updated `rerollPrompt` in `functions/src/index.ts` to read the player's sealed document (`/rooms/{roomCode}/sealed/{cardId}`) inside the Firestore transaction before any writes, seeding `seenPrompts` lazily from the card's current `promptText` if not yet present, and writing the updated `seenPrompts` array to the sealed document. Updated `test/fake_functions.dart` to mirror the sealed subcollection storage.
    - **Observed Falsifying Output (E2E Test in `functions/test/game_e2e.spec.ts`)**:
      ```text
      // Public room card doc MUST NOT have seenPrompts
      expect(publicHostCard).to.not.have.property('seenPrompts'); // PASSED
      // Sealed subcollection doc MUST have seenPrompts
      expect(sealedSnap.data()?.seenPrompts).to.have.lengthOf(11); // PASSED
      ```
    - **Verification**: `npm --prefix functions test` (40/40 passing), `flutter test` (127/127 passing), Cloud Functions deployed to production `gaslight-46368` (all 14 functions updated).

---

## 2. Lessons that still bite

These are kept because each one describes a trap that is **still live in the codebase** — not because it is interesting history. Each points at the contract that now owns the detail.

### 2.1 `null` is not "absent" across the Dart ↔ TypeScript boundary
Dart sends an omitted optional as `null`; TypeScript's `!== undefined` guard treats that as a real value and writes it. This erased lobby settings and made the game unstartable (Issue 31). **Clients must omit keys rather than send null; callables must guard with loose `!= null`, never a falsy check** — `false` and `0` are legitimate values. Full contract: **`design_database_and_security.md` §7**.

### 2.2 The test harness has four structural blind spots
Each has hidden a real bug. None is a flaw to fix — they are limits to design around:
- **The emulator suite is written in TypeScript**, so an omitted key genuinely *is* `undefined` there. It cannot produce the payload the Dart client actually sends. Issue 31 lived behind this.
- **Client tests use a fake Firestore that does not enforce `firestore.rules`**, so non-host writes and `authUid` checks are never really exercised. Use real simulator clients for anything that must be correct — bots are server-seeded documents and do not exercise the client path at all.
- **`Image.asset` loads no bytes under `flutter test`.** `find.byType(Image)` counts widgets whether or not art exists, and a golden render of the mascot comes out blank. Verify art by decoding the PNG (`test/helpers/png_decoder.dart`) or on a simulator.
- **Bare `flutter analyze` reports ~678 errors** from vendored plugin source under gitignored `build/`. Always scope it: `flutter analyze lib test`.

### 2.3 Stream-rebuild guards are load-bearing
Firestore streams rebuild constantly. Every animation, sound and mascot pose is gated behind a **once-per-event key** (the `_advancedStateKeys` pattern; `_playedRevealForTargetId`; `_knownPlayerIds`). Remove one and the effect re-fires on every tick. A missing key is invisible in code review and only shows up on device — which is why Issue 34 makes the key a required argument.

### 2.4 Validate type and range before comparing
`3 <= null` is `false`, so a range check silently passes and the function returns an empty result far from the cause. Reject nonsense input outright and throw a readable `HttpsError`, not a raw `Error` — raw errors flatten to `INTERNAL` and tell the player nothing. Detail: **`design_rotation_engine.md` §5**.

### 2.5 Measure; do not estimate, and do not trust a test's name
- A layout overflow estimated at ~275 dp measured **593 dp**.
- A mascot shipped at **1.02:1** contrast — invisible — with a fully green suite.
- A test titled *"…rim contrast >= 4.5:1"* asserted only that a file was non-empty. **Read the assertion, not the title.**

### 2.6 `IconData` is a `final class`
`phosphor_flutter` extends it and therefore **cannot compile** on this SDK. Proven twice. The app vendors the Phosphor Light font directly instead. Detail: **`design_ui_direction.md` §7**.

### 2.7 Everything mutating goes through a Cloud Function
Clients read Firestore streams and write nothing to rooms; `firestore.rules` denies it. Transactions read before write. Detail: **`design_database_and_security.md`**.

### 2.8 Widget tests on animated screens hang without `accessibleNavigation: true`
Nine widgets in the lobby tree drive `AnimationController.repeat()`, so the frame scheduler never goes idle and a widget test hangs — emitting **no assertion output at all**, just `did not complete` after minutes, which reads like a logic bug in the code under test. Wrap the screen under test in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)`: `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`), so the flag puts every animation on its static path. Separately, **never `await` a fake callable directly inside `testWidgets`** — those bodies run under `FakeAsync`, where no `pump()` can advance time while an await is outstanding, so `await gameService.createRoom(...)` deadlocks; wrap it in `tester.runAsync`. **`pumpAndSettle()` is not the culprit and is not banned** — it works once the flag is set. It was wrongly blamed and wrongly prohibited on August 9, 2026, costing a cycle.

### 2.9 A font glyph can be decoded — "unverifiable without a simulator" was wrong
`Phosphor-Light.ttf` has a `post` table at version 3.0, so it carries no glyph names and a codepoint cannot be looked up by name. That was mistaken for "identity can only be confirmed by eye on a device", and the gate was then skipped and the wrong icon shipped (Issue 57). **The outlines are decodable in pure Python**: parse `cmap` → glyph id (id `0` is `.notdef`, i.e. tofu), then `loca`/`glyf` → contours, and plot the contour points as ASCII. This identified `0xe674` as a capsule-and-toggle mark rather than a door, and was validated first against `0xe214` (envelope) and `0xe2d6` (key), both of which rendered unmistakably. **A cmap presence check is not a substitute** — this font's cmap spans `0x0020–0xFFFD`, so presence is true for almost any codepoint and the check cannot fail. Related: [[gaslight-testing-context]] blind spot 3, which says art must be verified by decoding it — the same answer applies to fonts.

---

## 3. Deliberately not built — do not re-propose

These were designed, costed and consciously **not** selected. Their absence is a decision, not an oversight:

- **P7 — Confidence Wager** ("seal it in blood"): stake points on your own forgery.
- **P9 — House Cards**: per-round modifiers.
- **P11 — The Final Gambit**: a comeback round for trailing players.
- **Issue 30 Option C**: making `_familyFriendlyOnly` a synced house rule. It stays client-local.
- **Issue 34 Option C**: priority arbitration between mascot poses. Available as an upgrade if reveal-screen collisions prove annoying in practice.

---

## 4. Resolved — index only

64 items resolved between May 24 and August 7, 2026. Full text is in `git log`; the durable consequences are in the design docs. Grouped by what they touched:

| Area | Items | Where the surviving contract lives |
|---|---|---|
| **Write architecture & multiplayer** — non-host writes blocked by rules, read-after-write transaction order, unhandled server errors, direct client writes in debug tools, full-object writes | Issues 1, 13, 14, 17, 18 + the May race/leak/transaction fixes | `design_database_and_security.md` |
| **Identity & reconnection** — device-stable `playerId`, seat re-binding, anonymous-auth loss, heartbeat volume, disconnect cleanup, host handoff | Issues 16, 36, 42, 15, 34, 35 | `design_database_and_security.md` §4–§5 |
| **Game-loop correctness** — score application on host override, timeout blank cards, inflated scores after disconnect, spectator miscounts, deterministic card resolution, reader re-indexing | Issues 26–35, 21 | `design_rotation_engine.md`, `design_scoring_and_ui.md` |
| **Scoring & honors** — saboteur "found the truth" bonus, metric-based end-game honors | Issues 30, 31 | `design_scoring_and_ui.md` |
| **Prompts & decks** — thematic decks, custom decks, the 3-prompt server cap, re-roll | Issues 22, 48, P4, P10 | `design_prompt_system.md` |
| **Duplicate answers** — Gemini replaced by a local lexical heuristic mirrored byte-identically on both sides | Decision 2 | `design_semantic_integrity.md` |
| **Secrets** — Gemini/Firebase key exposure in the client binary; keys moved to `.env`, Gemini removed entirely | Issues 3, 14 | §2.7 above; `.env` is gitignored and ships inside the IPA |
| **UI programme** — M1–M5 mobile-first, V1–V5 character work, U1–U8 UX, E7 sound | 49 + the M/V/U proposal sets | `design_ui_direction.md` §10 |
| **Icons & mascot** — hybrid icon system, the `final class IconData` blocker, vendored font, mascot redraw, hollow-body fill | Issues 23, 28, 29, 32, 33 | `design_ui_direction.md` §7 and the mascot block |
| **Lobby & house rules** — entry-form fit at 360×640, House Rules consolidation, non-host read-only, settings-wipe crash | Issues 24, 25, 27, 30, 31 | `design_ui_direction.md` §10; `design_database_and_security.md` §7 |
| **Test infrastructure** — emulator + rules unit suite, coverage gaps, real PNG decoding and contrast assertions | Issue 41, Tasks T1–T3 | §2.2 above |
| **Dependencies** — unused `cupertino_icons` removed; Phosphor font vendored | Tasks T2, Issue 29 | `design_ui_direction.md` §7 |

---

## 5. Where the detail lives now

| Looking for | Go to |
|---|---|
| What to work on next, and how to validate it | `agent_execution_guide.md` |
| Backend write contract, security rules, identity | `design_database_and_security.md` |
| Card passing, disconnect recalculation, input validation | `design_rotation_engine.md` |
| Scoring, routing, screen architecture, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, motif, icons, mascot, UI programme | `design_ui_direction.md` |
| Prompt decks and custom decks | `design_prompt_system.md` |
| Duplicate-answer heuristic | `design_semantic_integrity.md` |
| Game phases and data models | `design_game_state_and_models.md` |
| Manual playtest journeys | `e2e_testing_journeys.md` |
| Full history of any resolved item | `git log` |
