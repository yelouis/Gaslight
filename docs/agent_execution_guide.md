# Agent Execution Guide — Wave AC: 5 approved items — September 12, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.**

Two selections were made in `docs/ongoing_general_errors.md` on September 12, 2026, and the user added one new feature. They are **AC1–AC5**.

**⚠️ AC3 changed shape twice on September 12 and the history matters.** Issue 173 first selected **Option B** — *the visible card is the selection* — which was then withdrawn before any code was written (*"scrap AC3. Lets not make this change."*). It was replaced by a narrowed **Option A**: add an instruction, change no behaviour. **`CONFIRM VOTE` still requires a tap on a card. Do not implement Option B.** If you find a spec describing an always-live selection, a `CONFIRM OPTION {numeral}` label, or a 400 ms tap cool-down, it is the withdrawn version.

**Do only what is specified here.** A `(recommended)` label is not approval; a filled `Your selection:` line is. **Never fill one in.**

**Issue 174 was selected on September 12 (Option A) and is specced as AC5.** AC4 still ships first and still de-duplicates its chooser; AC5 then removes the underlying cause. **There are no unselected issues.**

**Implement in order: AC1, AC2, AC3, AC4, AC5.** AC2 and AC4 both edit the craft screen; AC2 first so AC4 builds on settled copy.

---

## 1. Verified baseline — measured on `ff0b9cd`

**This is the regression bar.** Every number was run bare.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 195 infos · exit 1** |
| `flutter test` | **331 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **144 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five** invocations | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH** |

**⚠️ `flutter analyze lib test` exits 1 even when clean.** The bar is **0 errors / 0 warnings / 195 infos**, never `exit 0`. Use `lib test`.

**⚠️ Read exit codes bare, never through a pipe.** `… | tail` reports `tail`'s status, always 0.

---

## 2.0 Standing constraints

**⚠️ Colour tokens name a SURFACE, not a role.** `colorScheme.onSurface` is `AppColors.ink` (`lib/main.dart:99`) — *"Text on parchment"*. On the dark `ground` it measures **1.12 : 1** against a 4.5 : 1 floor. **Text on ground is `AppColors.ivory`** (16.25 : 1); `brass` is 7.84 : 1 for accents. This is AC1's subject and applies to every item.

**⚠️ `lib/utils/scoring_logic.dart` is a TEST-ONLY mirror** of `functions/src/scoring_logic.ts`. Change one without the other and the client suite stays green while computing different numbers from production.

**⚠️ Never let a client bound exceed the server's.** A client-side limit is a suggestion; the server's is the limit. AC4 adds a cap and must enforce it in both places.

**⚠️ `lib/utils/prompt_decks.dart` is GENERATED.** Never hand-edit. Regenerate with `./scripts/generate_prompt_decks_dart.sh`; `check_decks_in_sync.sh` fails the battery when it is stale.

**One item = one commit.** Conventional Commit, WHY in the body. Deploy functions after AC4 and re-apply `CLEANUP_DRY_RUN=false`, reading it back.

---

## 3. AC1 — Issue 171 → Option C: collapse the transcript behind a tap, and make it legible

**What this means for the user.** The per-rule score breakdown shipped in Issue 169 is drawn in near-black on a near-black background — it is on screen and cannot be read. Today the reveal shows four differently-sized boxes with what looks like empty space in them; that "space" is the breakdown.

**The gap.** `lib/screens/phase4_reveal.dart`, the `POINTS AWARDED THIS CARD` block. Two defects:

1. Each rule line renders `theme.colorScheme.onSurface.withValues(alpha: 0.8)` — `AppColors.ink` on the dark ground, **1.12 : 1**.
2. The chips sit in a `Wrap`, each a `Column(mainAxisSize: MainAxisSize.min)`, so every box shrinks to its own content and a player with two rule lines gets a box twice the height of a player with one.

**Implementation.**

1. **Collapse the breakdown behind a tap.** Each chip shows only `avatar · {name}: {±N}` — one line, so **every chip is the same height and the ragged-box defect disappears as a consequence of Option C rather than needing its own fix.** Tapping a chip expands that player's rule lines; tapping again collapses. Expansion state is local to the reveal screen.
2. **Fix the colour.** Expanded rule lines use `AppColors.ivory` for the value and `AppColors.brass` for the rule name. **Do not use `onSurface` anywhere on this screen.**
3. **Add the hint the user asked for.** Beneath the `POINTS AWARDED THIS CARD` heading, render exactly: `Tap a player to see their score breakdown`, in `brass` at 11 pt. Without it, Option C's cost — that a player who does not know the detail exists will never tap — is unmitigated.
4. **⚠️ Expansion state lives on a `State` that survives card changes.** Reset it in the same place the reveal already resets per-card state, keyed on `currentReaderId`. This is the lesson §2.40 trap; three Wave AA items hit it.

**Validation.**

1. **A RENDERED contrast test, not another curated pair.** This is the durable half of this item. Pump the reveal with a breakdown expanded, walk the rendered `Text` widgets in that subtree, resolve each one's effective colour against the colour actually painted behind it, and assert **≥ 4.5 : 1**. `test/contrast_tokens_test.dart` already contains one test of this shape for the reveal answer and prompt — extend that approach; **do not add a sixth hand-curated pair, which is exactly why this defect shipped (lesson §2.42).**
2. Widget test: breakdown lines are absent before tapping a chip and present after.
3. Widget test: the hint string renders verbatim.
4. Widget test: all chips report equal height when players have differing rule counts.
5. Widget test: expand a chip, advance `currentReaderId` **without re-pumping**, assert the expansion is cleared.
6. **Over-reach guards, unedited:** all 7 tests in `test/phase4_reveal_test.dart`, including `O2: renders published scoreDeltas …` — **totals must remain visible at all times**; Option C hides the rules, never the total.
7. **Falsification:** restore `onSurface` on the rule lines; test 1 must fail with a ratio near 1.1. Then remove the reset; test 5 must fail.

**Blast radius:** `docs/design_ui_direction.md` — record the collapse-on-tap contract and the colour rule.

---

## 4. AC2 — Issue 172 → Option B: replace stems with inline sample answers

**What this means for the user.** A stuck player is currently shown half of somebody else's sentence to continue, which is harder than answering the prompt. They will instead see a complete example answer, always visible, so the shape of a good answer is obvious.

**The gap.** `functions/src/prompt_decks.ts` carries `stems?: Record<string, string[]>` — 150 openers across 150 prompts — rendered beneath the answer field as `Starter: "…"`.

**Implementation.**

1. **Rename the field to `samples`** and replace all 150 entries with complete sample answers. A rename rather than a content swap, because `stems` would then be a lie about what the data is, and the next reader would rely on the name.
2. Keep **every** structural property of AA5 — they were the reason it shipped safely:
   - `samples?: Record<string, string[]>`, keyed by **exact prompt text**.
   - **`validateDeckStems`** (rename to `validateDeckSamples`) still **throws at module load** if a key matches no prompt in its deck. **Never soften to a warning:** a detached key fails invisibly.
   - Emitted into the generated Dart mirror by `scripts/generate_prompt_decks_dart.mjs`; `check_decks_in_sync.sh` must still catch a samples-only divergence.
   - Resolved client-side by prompt text; a custom-deck prompt finds nothing and renders nothing.
3. **⚠️ Display only. Never write a sample into `_answerController`.** Unchanged from AA5 and still the most important rule here.
4. Copy: render exactly `For example: "{sample}"` beneath the field, replacing the `Starter: "…"` line.

**⚠️ Option B's known consequence, which you must not try to engineer away.** Every player writing on a card sees the *same* prompt and therefore the *same* sample. `TextSimilarity.isTooSimilar` compares a new answer against the other answers already on that card, so **if two players both lean on the sample, the second one is rejected with *"Too similar to an existing answer! Be more creative."*** That is the heuristic working correctly. It was named in Issue 172's cons and the user selected Option B anyway. **Write a test that documents this behaviour rather than a mitigation that weakens the duplicate check** — the duplicate check protects the whole game and a writing aid does not outrank it.

**Validation.**

1. Widget test: a catalogue prompt renders `For example: "…"`; `_answerController.text` is still empty after pump.
2. Widget test: a prompt absent from the catalogue renders no sample and does not throw.
3. Functions test: a `samples` key matching no prompt throws at module load. **Falsify with a bogus key.**
4. `./scripts/check_decks_in_sync.sh` exits 0 bare; **then falsify it** by hand-editing one sample in the Dart mirror and confirming exit 1. **If it still exits 0 the generator is not emitting samples and the mirror can drift silently** — this exact falsification is what proved AA5's gate was real.
5. Test documenting the collision: two answers both derived from the sample on one card — the second is rejected by the similarity check.
6. **Over-reach guard, unedited:** `test/guidance_strings_test.dart` — its four verbatim phase strings are untouched by this item.
7. Count check: **150 samples across 150 prompts**, no prompt left uncovered.

**Blast radius:** `docs/design_prompt_system.md` §6 — currently describes stems and the phase-framing decision. Rewrite it for samples, and **keep the paragraph explaining why an aid is never pre-filled**, which still applies.

---

## 5. AC3 — Issue 173 → Option A (narrowed): tell the player they must tap a card

**⚠️ This item changes NO behaviour.** Selection still requires a tap on a card; navigating still does not select; `CONFIRM VOTE` is still disabled until something is selected. **Option B — "the visible card is the selection" — was selected on September 12 and withdrawn the same day. Do not implement it.** This item adds instruction and nothing else, which is Issue 173's Option A reduced to its first half.

**What this means for the user.** Today you can page through every option and the confirm button stays dead, because selecting requires a tap on the card and nothing says so. After this, the screen tells you.

**The gap.** `CONFIRM VOTE` is greyed exactly when `_localSelectedAuthorId == null` (`phase3_vote.dart:582`), which is the state on arrival at every card and after any tap on a card that cannot be voted for. Selection is set only by `onSelect`, reached only from a tap (`card_grid.dart:169`) — swipe, `PREV`, `NEXT` and the jump dots change the front card and nothing else.

**What already exists — do not rebuild it.** The active card is **not** short of state signals; it is short of one instruction:
- **Selected** already renders a thickened accent border (`card_grid.dart:517–520`) and a wax seal (`:650`, key `active_card_wax_seal_stamp`).
- **Unvotable** already renders a diagonal `SEALED` ribbon (`:805`) and a `(Your Forgery)` / `(Your Truth)` label (`:621`).

**Implementation.**

1. **The disabled button carries the instruction.** While `_localSelectedAuthorId == null`, render the `PrimaryButton` with the text `TAP A CARD TO CHOOSE` instead of `CONFIRM VOTE`. It stays disabled. Once something is selected it reverts to `CONFIRM VOTE`, enabled.
   **This is the primary half of the fix and the one to ship if only one lands.** It costs zero layout space, and it puts the explanation exactly where the player is looking at the moment they are confused — at the control that appears broken.
2. **The active card carries a tap cue**, rendered **only when that card is votable and not currently selected**: the exact string `Tap to choose this one`, in `brass` at 11 pt, beneath the answer text inside the active card.
3. **⚠️ Suppress the cue on an unvotable card — this is the part that is easy to get wrong and would make the screen worse than it is now.** On the player's own answer or a placeholder, a tap is silently ignored: all three tap sites read `onTap: isUnvotable ? null : …` (`card_grid.dart:507`, `:674`, `:740`), so there is **no handler at all** and the tap produces nothing, not even a ripple. **Printing "Tap to choose this one" on a card that cannot be tapped instructs an action that does nothing** — strictly worse than saying nothing, because the player will conclude the app is broken rather than that the card is sealed. The existing `SEALED` ribbon and `(Your Forgery)` label already explain that card; leave them to do it.
4. **The button keeps saying `TAP A CARD TO CHOOSE` even when the front card is unvotable.** That remains true and actionable — the player can tap a *different* card. Do not special-case it into a second message; two competing explanations on one screen is how the reveal got unreadable.

**Validation.**

1. Widget test: on arrival, with nothing selected, the button reads `TAP A CARD TO CHOOSE` and is disabled, and the active card shows `Tap to choose this one`.
2. Widget test: tap the active card — the cue disappears, the wax seal appears, and the button reads `CONFIRM VOTE` and is enabled.
3. Widget test, **the over-reach guard for point 3**: navigate to the player's own answer; **assert `Tap to choose this one` is absent** while the `SEALED` ribbon is present, and the button still reads `TAP A CARD TO CHOOSE`.
4. Widget test: the same for a placeholder option (`THE SOUL IS SILENT`).
5. **⚠️ Layout guard — this item adds a line to the most space-constrained screen in the app.** Re-run `test/vote_option_truncation_test.dart` **unedited**, and assert no overflow at **320 pt with six options** at text scale 1.0 and 1.3. Issue 160 was fought over exactly this viewport; **a hint that pushes the confirm button off screen would be a worse defect than the one being fixed.**
6. **Over-reach guards, unedited:** all 4 tests in `test/stacked_deck_navigation_test.dart` and all 11 in `test/phase3_vote_test.dart`, **including `O9`** — the target sees no vote button and must see no tap cue either.
7. **Falsification:** remove the button's conditional label; test 1 fails. Remove the unvotable suppression; test 3 fails by finding the cue on a sealed card.

**Blast radius:** `docs/design_ui_direction.md` — record, in the stacked-deck section, that selection is tap-only and that the instruction lives on the disabled button.

---
## 6. AC4 — NEW FEATURE: cap re-rolls at 3 per round, then let the player choose

**The request, verbatim:**

> *"I want reroll to be a max of 3 per round. After 3, the player can see the 3 prompts that they rerolled on and select one of those 3 to answer. However, make sure to not fall into the trap of using the same 3 prompts per round for the same player"*

**What this means for the user.** Re-rolls are unlimited today, so a player can spin forever and the button never resolves anything. After this they get three, and if none of the three suits them they are not stuck with the last one — they pick whichever of the three they liked best. The trap named in the request is the important half: a player must not be shown prompts they have already seen this match.

### 6.1 The trap is real and already in the code — fix it first

**⚠️ The re-roll draw ignores the player's history.** `rerollPrompt` reads the player's `seenPrompts` into `cardSeen` and then **never uses it**: both branches draw with `inPlay` as *both* the `excluded` and `mustAvoid` argument. `inPlay` is only *"prompts sitting on a card right now"*. A prompt the player saw and rerolled away from is no longer on a card, so **it is immediately eligible to come back** — within the same round, and again in the next.

This is exactly the failure the user anticipated, and it is **load-bearing for this feature**: with a cap of three and a chooser, players now have a reason to use all three re-rolls every round, so a repeat that used to be a rare annoyance becomes the common case.

**The fix, in both branches of the draw:**

- Deck branch: `PromptDecks.drawOneExcluding(deckId, new Set([...inPlay, ...cardSeen]), inPlay)`.
- Custom-pool branch: the candidate filter must drop `cardSeen` as well as `inPlay`.

**⚠️ Pass history in `excluded`, never in `mustAvoid`.** `design_prompt_system.md` §5 records the contract: `drawOneExcluding` **prefers** a prompt outside `excluded`, relaxes to anything outside `mustAvoid` when that is impossible, and **never refuses**. History belongs in the soft set so an exhausted deck still returns something; `inPlay` stays in the hard set so two players can never share a prompt. **Putting history in `mustAvoid` would make the draw throw on a small deck.**

### 6.2 Server — the cap and the candidates

**State.** Two new fields on `sealed/{playerId}`, which is default-deny and already holds `seenPrompts`:

- `rerollsThisRound: number`
- `rerollCandidates: string[]` — the prompts produced by this round's re-rolls, in order.

**Cap.** `rerollPrompt` rejects with `failed-precondition` when `rerollsThisRound >= 3`. Define the bound as a named constant, `kMaxRerollsPerRound = 3`, exported so the client and the tests reference it rather than repeating a literal.

**On each successful re-roll:** increment `rerollsThisRound`, append the new prompt to both `seenPrompts` and `rerollCandidates`.

**⚠️ The per-round reset currently works by accident and is one word away from breaking.** `concludeResolutionRound` resets each sealed doc with `transaction.set(sealedRef, { seenPrompts: updatedSeen, truthAnswer: "", … })` — **a `set` with no `{ merge: true }`**, so it replaces the document and any new field vanishes. That happens to be the behaviour we want, but it is invisible. **Write `rerollsThisRound: 0` and `rerollCandidates: []` into that object explicitly**, so the reset is a decision a reader can see. Note that `rerollPrompt` itself writes with `{ merge: true }` — if anyone ever "harmonises" the round-advance write to match, an un-reset counter would silently carry a player's exhausted re-rolls into the next round, and the symptom would be a button that is dead from the first moment of a round.

**The chooser callable.** `selectRerolledPrompt({ roomCode, playerId, promptText })`, following `castVote`'s authorization shape (`index.ts:942`) — `request.auth`, then `authUid` on the player doc, then checks inside the transaction. `playerId` is not a credential.

Validation, in order:

1. `room.currentPhase === "truth"` → else `failed-precondition`. Re-rolls and this chooser are truth-phase only, matching `rerollPrompt`.
2. The caller owns the card (`cardIdx` found for `playerId`).
3. `rerollsThisRound >= kMaxRerollsPerRound` → else `failed-precondition`. **The chooser only opens once the cap is spent**; before that the player still has re-rolls and does not need it.
4. `promptText` is a member of `rerollCandidates` → else `invalid-argument`. **Never trust a prompt string from the client** — this is the whole reason candidates are stored server-side.
5. **⚠️ Re-validate `inPlay` at selection time.** A candidate is not on any card while it sits in the list, so **another player's re-roll can legitimately draw it in the meantime.** If the chosen prompt is now in play, reject with `failed-precondition` and a message naming the collision; the client removes it from the chooser and the player picks another. **Do not silently substitute a different prompt** — the player chose a specific one and a silent swap is indistinguishable from a bug.
6. The player has not already submitted a truth answer this round.

On success: set the card's `promptText`, and leave `rerollsThisRound` at its cap so the chooser stays available if they change their mind before submitting.

### 6.3 Which three prompts the chooser shows — a decision, recorded

A player who re-rolls three times has seen **four** prompts: the original `P0` they were dealt, and `P1`, `P2`, `P3` from the three re-rolls. *"The 3 prompts that they rerolled on"* admits more than one reading, so this spec fixes one:

**The chooser shows `P1`, `P2`, `P3` — the three prompts the re-rolls produced.** `P0` is excluded because the player actively rejected it before spending any re-roll. This is what `rerollCandidates` accumulates, and it is exactly three entries.

**If the user wants `P0` included, that is a one-line change**: seed `rerollCandidates` with the dealt prompt when the round begins, and the chooser becomes four. **Do not make that change without a selection** — flag it and leave it.

### 6.4 Graceful degradation on a small deck

With the history fix, candidates are drawn preferring prompts the player has not seen. **On a small deck the unseen pool can run out**, at which point `drawOneExcluding` relaxes and may return a seen prompt; it may also return the same prompt twice across two re-rolls.

**De-duplicate `rerollCandidates` on append.** If a re-roll produces a prompt already in the list, still consume the re-roll and still change the card, but do not add a duplicate entry — **a chooser offering the same prompt twice is the visible form of the exact complaint this feature was asked to prevent.** The chooser therefore shows *up to* three distinct prompts, and fewer when the deck cannot supply three.

**This is the safe degradation, not the fix.** The underlying capacity problem is **Issue 174**, now selected and specced as **AC5**: four catalogue decks hold 25 prompts, and five players using all three re-rolls consume **20 of them in a single round**, while the capacity check at `index.ts:733` only requires `players × rounds`. **Keep the de-duplication anyway** — AC5 removes the cause, but the terminal case where every deck is exhausted still exists and de-duplication is what keeps the chooser honest there.

### 6.5 Client

`lib/screens/phase2_craft.dart` and `lib/services/game_service.dart`.

1. The `RE-ROLL PROMPT` button shows what is left: `RE-ROLL PROMPT ({n} LEFT)`, disabled at zero. Keep the existing disabled conditions (`isTimerLast5Sec`, `_isSubmitting`).
2. At zero, show the chooser: the distinct `rerollCandidates`, each tappable, the current one marked. Selecting calls `selectRerolledPrompt`.
3. Error surfaces **match on `e.code`, never on the message** — a standing invariant. The collision in 6.2(5) arrives as `failed-precondition`; show a specific sentence for it and the generic *"Something went wrong. Try again."* for everything else.
4. The client must read the cap from the shared constant, **and must not be the only thing enforcing it.**

### 6.6 Validation

1. Emulator: three re-rolls succeed; the fourth is rejected with `failed-precondition`.
2. Emulator, **the trap test**: with a player's `seenPrompts` pre-loaded with most of the deck, repeated re-rolls return prompts outside that set for as long as any remain. **Falsify by reverting the `excluded` argument to `inPlay`** and confirm this test fails — it is the only test that proves the reported trap is closed.
3. Emulator: `rerollsThisRound` and `rerollCandidates` are both reset by `concludeResolutionRound`. **Falsify by removing the two explicit fields** — and note whether the test still passes, since the non-merge `set` also resets them; **if it passes either way, assert the fields are present in the written object**, or the guard is measuring nothing.
4. Emulator: `selectRerolledPrompt` sets the card's prompt to the chosen candidate.
5. Emulator, the five rejections: wrong phase; cap not yet spent; prompt not in `rerollCandidates`; prompt now in play (collision); caller not the card owner.
6. Emulator: a duplicate draw does not produce a duplicate chooser entry.
7. Widget: the button shows `3 LEFT`, `2 LEFT`, `1 LEFT`, then disables and the chooser appears with the distinct candidates.
8. Widget: choosing a candidate updates the displayed prompt.
9. **Over-reach guards, unedited:** `test/reroll_deck_exhaustion_test.dart` and `test/phase2_craft_test.dart`'s `Issue 88.1` re-roll error case. **The "re-rolls never refuse" contract in `design_prompt_system.md` §5 is about the draw, not the cap** — the draw still never throws; the *callable* now refuses past three. Keep those distinct in the commit body.

**Blast radius:** `docs/design_prompt_system.md` §5 (the cap, the chooser, and the corrected exclusion), `docs/design_database_and_security.md` (two new `sealed` fields and the new callable row), `docs/design_ui_direction.md` (the chooser).

---
## 7. AC5 — Issue 174 → Option A: top up from the fallback deck when the room's deck runs dry

**Do AC4 first.** AC5 modifies the same draw AC4 corrects, and its whole purpose is to catch the case AC4's de-duplication can only paper over.

**What this means for the user.** With three re-rolls each, a five-player table burns 20 of a 25-prompt deck in one round. Today the draw quietly starts handing back prompts people have already seen — which is the exact complaint that prompted the re-roll cap. After this, the game reaches into the large fallback deck instead, and a player only ever sees a repeat when there is genuinely nothing new left anywhere.

**The gap.** `PromptDecks.drawOneExcluding(deckId, excluded, mustAvoid)` **never refuses** — it prefers a prompt outside `excluded`, then relaxes to anything outside `mustAvoid` (`design_prompt_system.md` §5). That relaxation is what silently produces repeats. The check at `index.ts:733` only budgets `players × rounds`, so it never sees this coming.

**Implementation.**

1. **Extend the existing pattern, do not invent one.** `rerollPrompt`'s custom-deck branch already does exactly this shape: when its pool is empty it calls `PromptDecks.drawOneExcluding(promptSource.fallbackDeckId, …)`. Give the catalogue-deck branch the same escape.
2. **The rule:** attempt the draw against the room's deck excluding the player's history. **If that yields nothing the player has not seen**, draw from `PromptDecks.getFallbackDeckId()` — again excluding history and `inPlay` — before falling back to relaxation.
3. **⚠️ Apply this to the round-advance deal as well, not only to re-rolls.** Issue 174's Option A speaks about re-rolls, but `concludeResolutionRound` draws each player's next-round prompt with the same `drawOneExcluding(deckId, seen, assignedThisRound)` and relaxes the same way. **The dealt prompt matters more than a re-roll result** — it is the prompt the player actually answers — so protecting re-rolls while leaving the deal to repeat would fix the lesser path and leave the greater one broken. **This is a deliberate extension of the option's letter to its intent; record it in the commit body.**
4. **The terminal case.** When the room's deck *and* the fallback are both exhausted for this player, **let `drawOneExcluding` relax exactly as it does today.** It must still never refuse — that contract is load-bearing and is what keeps a long match playable. A repeat at that point is correct behaviour, not a bug.
5. **Do not touch the capacity check at `index.ts:733`.** Tightening it was Option B and was **not** selected; it would block configurations that play perfectly well.

**⚠️ The content-rating property that makes this safe — verify it rather than assuming it.** The fallback deck is `hypotheticals`, rated **PG** (`prompt_decks.ts:40–41`), and it is the only deck marked `isFallback`. Every other deck is PG except `rated_r_nsfw`. **Topping up therefore can only make content milder, never more explicit**, so a room that selected a family-friendly deck cannot be handed something stronger by this mechanism. `lobby_screen.dart:309` defines family-friendly as exactly `rating == PG`. **If a future deck is ever marked `isFallback` with a rating above PG, this property silently inverts and a PG room starts receiving R content** — assert the fallback's rating in a test so that change cannot land quietly.

**Validation.**

1. Functions test: a player whose `seenPrompts` covers the entire room deck receives a **fallback-deck** prompt on re-roll, not a repeat.
2. Functions test: the same holds for the round-advance deal — a player whose history covers the room deck is dealt from the fallback, not a repeat.
3. Functions test, the terminal case: history covering **both** decks still returns a prompt and **does not throw**. This is the guard on the never-refuses contract.
4. Functions test: while the room deck still has unseen prompts, the fallback is **never** consulted. **This is the over-reach guard** — a top-up that fires early would quietly homogenise every room onto one deck and erase the deck choice entirely.
5. Functions test: `getFallbackDeckId()`'s deck is rated PG. Cheap, and it is what stops the safety property above from inverting unnoticed.
6. **Over-reach guards, unedited:** `test/reroll_deck_exhaustion_test.dart`, and the custom-deck branch's existing fallback behaviour — **this item must not change how custom decks already top up.**
7. **Falsification:** remove the catalogue-deck top-up; tests 1 and 2 must fail with a repeat, while tests 3 and 4 still pass.

**Blast radius:** `docs/design_prompt_system.md` §5 — record the top-up, that it applies to both the re-roll and the deal, and the PG-fallback property.

---
## 8. Already delivered — do NOT rework

### Wave AA — sixteen items, verified September 11, 2026

Verified by reading source and re-falsifying, not by reading commit bodies. Full index in `ongoing_general_errors.md` §3; durable contracts in the design docs.

| Items | What shipped |
|---|---|
| **AA1–AA6** (155, 156, 157, 154, 166, 158) | Craft screen: dealt-card overlay **deleted**; tap-away dismisses the keyboard; the focused field scrolls above the keyboard; a live `n/100` counter that **does not cap**; sentence stems for **150/150** prompts; the waiting screen recaps your own submitted answer. |
| **AA7–AA9** (153, 161, 159) | Room-code field hardened against autocorrect; the target's ready is a **server-driven toggle**; the best-forgery banner is suppressed below 2 votes and on ties. |
| **AA10–AA11** (163, 169) | Per-round score multiplier; itemised `scoreBreakdown` carried through all three flush sites; manual scoring copy rewritten. |
| **AA12–AA14** (164, 167, 168) | In-game manual button on all three phase screens; standings above honors under `FINAL RESULTS`; highlight titles own the full card width. |
| **AA15 + Issue 160** | Four vote-option mockups rendered, user chose **Treatment 3 (stacked deck)** with backward navigation; implemented with PREV/NEXT, swipe, and jump dots. |
| **AA16a + AA16b** (162) | `submitTargetForgeryGuesses` callable with thirteen rejections, storing to `sealed`; `+1` per correct attribution; tap-to-assign chip row on the vote screen. |

**Falsifications re-run this session — these guards are real, not decorative:**
- Removing only the multiplier's breakdown line fails **exactly 3** Dart tests (the multiplied fixtures) while round-1 and revenge fixtures still pass.
- Injecting `scoreDeltas` into the withheld branch fails **4** emulator tests including AA16a's leak test and the pre-existing P4 guard, with 135 still passing.
- Tampering with one stem key in the generated Dart mirror makes `check_decks_in_sync.sh` exit **1**; restoring makes it exit **0**. The gate genuinely covers stems rather than passing vacuously on two empty sides.

### 8.1 Standing maintenance — alongside Wave AC, not instead of it

1. **Deploy the functions after any `functions/src` change, then restore the cleanup flag.** The gate is green today; it goes red the moment server code changes. `functions/src` changed under AA10, AA11 and AA16a, and **`submitTargetForgeryGuesses` is not deployed at all** — production runs 17 functions and the new callable is absent. **Target forgery guessing does not work in production today, and a client build shipped before this deploy would call a function that is not there.**
   ```
   firebase deploy --only functions
   gcloud run services update cleanupdaily --update-env-vars CLEANUP_DRY_RUN=false
   ```
   **Then read the flag back** — `CLEANUP_DRY_RUN` is **revision-scoped** and a deploy silently drops it. Then re-run `./scripts/check_deploy_fresh.sh` bare and confirm exit 0.
2. Answer questions about the state of the repository.
3. Re-run the §1 baseline to confirm it still holds.
4. If a gate §1 says is green goes red, investigate and **file** it.
5. Ship a release by following `README.md` → **Releasing**. **Deploy functions first** (action 1) — the client calls the new callable.

### Earlier waves

- **Wave Z (152)** leave latch reset in a `finally` — see lesson §2.40.
- **Y1 (151)** runtime version label · **Y2 (149)** R5 checks cited evidence in `NOT RUN` blocks · **Issue 150** closed, no change.
- **X1 (147)** `EmberBackdrop` ticker guarded — **the `pumpAndSettle` trap is closed** · **X2 (148)**.
- **W1 (146)** post-commit `recursiveDelete` · **W2 (145)** live deletion enabled · **V1 (143, 144)** 24-hour retention.
- **U1–U5**, **S1**, **R0–R2**, soak blocks **E22–E49**, Waves **Q/P/O**, Issues **96–105, 50–95, 31, 28/29**.
- The playthrough reorganisation under `docs/playthroughs/`, and the release runbook in `README.md`.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

### Accepted equivalents — do NOT "fix" these back

Each of these reaches the specified outcome by a different structure than the spec described. They were checked this session and are correct as they stand.

- **The target's attribution UI is a separate chip row, not an interactive option grid.** The AA16b spec predicted `phase3_vote_test.dart`'s O9 assertion (*"read-only options grid with no confirm vote button"*) would have to be edited. It did not: the implementation left the option grid read-only and appended the attribution chips beneath the card. **O9 passes unedited and both halves of it are still true.** This is better than what was specced — do not "correct" it by making the grid interactive.
- **AA16b enforces one-player-per-option on the client** (`_targetForgeryGuesses.removeWhere((k, v) => v == authorId)`). The spec said not to enforce uniqueness. **The server remains permissive** — it accepts any map and has no uniqueness rejection — so this is a guiding affordance, not a constraint, and it cannot deadlock because partial maps are legal. Keep both halves as they are.
- **AA5 ships one stem list per prompt with phase-dependent framing**, rather than distinct truth/forgery stem lists. Recorded with its reasoning in `design_prompt_system.md` §6.
- **AA8 added a phase guard to `setReady` beyond its item's scope.** A late `setReady(false)` after phase advance would have written to `readyPlayers` and corrupted room state. The guard is correct, emulator-tested, and its blast radius was confirmed contained — `setReady` is only ever called during the vote phase.
- **Analyze infos are 195, not 206.** The drop is the deleted overlay and its tests.
- **`GameService.kMissingAnswerPlaceholder` (`"(The ink ran dry...)"`) is declared and never referenced.** It is dead, it is not the server's placeholder (`"THE SOUL IS SILENT"`), and it predates Wave AA. **Leave it** unless a cleanup item is selected — the project deliberately retains some dead declarations (see `lastReaction` in §3).
- **Waves Y1, Z1 and Wave AA bumped `pubspec.yaml` inside their own commits** rather than at release time.
- **`EmberBackdrop` and `AnimatedThinkingBackground` both keep `..repeat()` in `initState`.**
- **E48 merged two specified artefacts into one** · **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`** · **P4's Option B deferral**.

---

## 9. Invariants & intentional decisions — do NOT change

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
- **`LobbyScreen` renders both the entry screen and the parlour from one `State`** (`:436–453`), pushed once as a route. **Any flag on that `State` outlives every room** — Issue 152 is what happens when one is set and never reset.
- **`lastReaction` / `lastReactionAt` are deliberately retained dead fields** from Issue 74.
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit.

**⚠️ Colour tokens name a SURFACE, not a role.** `colorScheme.onSurface` is `AppColors.ink` (`lib/main.dart:99`) — the near-black brown that `app_colors.dart:12` documents as **"Text on parchment"**. On the dark `ground` it measures **1.12 : 1** against a 4.5 : 1 floor and is effectively invisible; that is Issue 171. **Text on the dark ground is `AppColors.ivory`** (16.25 : 1), and `brass` (7.84 : 1) is for accents. **A passing `contrast_tokens_test.dart` does not cover you** — it checks five hand-curated pairs that are correct by construction, so it can never fail on a widget that reached for the wrong token (lesson §2.42).

**Wave AB invariants (September 2026) — now shipped and verified:**


- **The target's forgery guesses are NOT multiplied by the round** (Issue 170 → Option B). The ordering in `calculateScoresAndBreakdown` *is* the mechanism: the guess block runs **after** the multiplier block. **Do not "tidy" it back above**, and do not replace it with an exclusion list.
- **`runningRivalries` may only ever contain cards whose authorship is already public.** `sealed/_summary` accumulates at the vote→reveal transition, before the unmask window closes — **publishing straight from it leaks authorship.**
- **The running rivalries threshold is `count >= 1`; game-over `headToHead` stays `count >= 2`.** They differ on purpose and a test asserts the difference. Do not "align" them.

**Wave AA invariants (September 2026):**

- **`inGameAppBarHeight` reserves `56 + 56*trailingSlots`.** All three in-game screens pass **2**. **Any screen that adds or removes a trailing `AppBar` action MUST update its `trailingSlots` in the same change** — getting it wrong does not throw, it measures the title against width the screen does not have and clips silently at narrow widths or high text scale. Extend `in_game_app_bar_test.dart` and `phase4_header_overflow_test.dart` whenever the count changes.
- **`validateDeckStems(DECK_LIST)` throws at module load.** Never soften it to a warning: a stem key that no longer matches its prompt fails *invisibly* (the stem just stops appearing), which is the class of bug that survives a green suite.
- **Sentence stems are displayed, never inserted into the answer field.** Pre-filling makes every answer open identically and feeds the duplicate-answer heuristic — the game would reject answers for a similarity it created itself.
- **`lib/utils/scoring_logic.dart` is a TEST-ONLY mirror of `functions/src/scoring_logic.ts`.** Nothing in `lib/` calls it; it exists for `test/fake_functions.dart` and `test/scoring_logic_test.dart`. **Change scoring in one and not the other and the whole client suite stays green while computing different numbers from production.**
- **The target maps `optionId → guessedAuthorId`, never `voter → author`.** Authorship does not reach the client before the unmask window closes. Target guess points flow through `calculateScoresAndBreakdown` so they inherit the existing withholding — **do not give them a separate write path**, or a moving score reveals a correct guess before the author flip.
- **`kTargetForgeryGuessPoints = 1` and the round multiplier are the Issue 170 balance knobs**, defined as named constants in both implementations. **Do not change either without a selection on Issue 170.**
- **`scoreBreakdown` must satisfy `sum(breakdown[player]) == scoreDeltas[player]`** for every player, including the revenge ±1 and the round multiplier. Both suites assert it over four mirrored fixtures.

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and both at once (142 C); migrating `withOpacity` → `withValues` (139 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C); enabling deletion before fixing the leak (145 B); splitting `CLEANUP_DRY_RUN` into two flags (145 C); relying on the nightly sweep instead of fixing the orphan source (146 B); fixing the source while leaving the sweep uncapped (146 C); driving `EmberBackdrop`'s controller from `build` (147 B); accepting the unguarded ticker (147 C); re-running E9 (148 B); leaving its stale reason (148 C); treating unchecked `NOT RUN` citations as a review habit (149 B); forbidding artefact paths in `NOT RUN` blocks entirely (149 C); **enlarging or relocating the `PEEK INSIDE` affordance (150 A/B/C — closed, no change needed)**; generating the version from `pubspec.yaml` (151 B) and injecting it with `--dart-define` (151 C); **clearing `_isLeaving` from `build` (152 B) and scoping the guard to the dialog (152 C)**.

**Rejected in the September 8 selections — do NOT re-propose:** room codes drawn from a curated word list (153 B) and a segmented 4-box code input (153 C); capping the answer field with `maxLength` (154 B) and stating the limit in hint copy only (154 C); keeping the dealt-card overlay with a corrected label (155 B) or showing it once per match (155 C); `TextField.onTapOutside` (156 B) and a shared keyboard-dismiss wrapper across the lobby too (156 C); reordering the craft column so the field sits above the prompt (157 B) and moving writing into a modal sheet (157 C); a per-player rotation index (158 B) and an adaptive shortened barrier (158 C); a majority-of-voters threshold for the best-forgery banner (159 B) and replacing it with a full vote tally (159 C); a two-column portrait grid for vote options (160 B); confirming before locking the target's ready (161 B) and removing that button entirely (161 C); reviving P9 House Cards (163 B) and tightening timers or forgery counts per round (163 C); a manual button with no phase copy (164 B) and first-run coach marks (164 C); generic prompt-independent sentence stems (166 B) and extending re-roll to forgery rounds (166 C); hiding honors behind a tab (167 B); wrapping the highlight title to two lines (168 B) and auto-sizing it (168 C); itemising the manual copy only (169 B) and deferring the transcript to the game-over screen (169 C).

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| **Release runbook** | **`README.md` → Releasing** |
| **All playthrough material** | **`docs/playthroughs/`** |
| Block titles + specified assertions (R6's source) | `docs/playthroughs/manifest.md` |
| Screenshot hand-off record | `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| Rules, seat tokens, presence, heartbeat, retention, cleanup & the deploy trap, **`sealed` target guesses** | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding, the unmask close, **itemised breakdown & target forgery guessing** | `design_scoring_and_ui.md` |
| Palette, typography, header sizing & **the `trailingSlots` reserve**, reduce-motion signal, title-screen version, **stacked-deck vote options**, game-over order, highlight cards | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, **sentence stems (§6)** | `design_prompt_system.md` |

---

## 11. Validation standard

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
    Wave AC (sections 3-6) is selected. Issue 174 is FILED and UNSELECTED --
    AC4 ships without it, but do NOT implement its options.
(2) ORDER: AC1, AC2, AC3, AC4, AC5. AC2 and AC4 both edit the craft screen;
    AC5 modifies the same draw AC4 corrects, so it must follow AC4. AC3 adds
    instruction only and changes no vote behaviour.
(3) Read exit codes BARE. `... | tail` reports tail's status, always 0.
(4) COLOUR: check which SURFACE a token is for. onSurface is AppColors.ink --
    text on PARCHMENT; on the dark ground it is 1.12:1. Text on ground is
    ivory. A passing contrast_tokens_test does NOT cover you (lesson 2.42):
    a curated pair list cannot fail on a wrong-token widget. Assert on the
    RENDERED tree.
(5) Changing scoring? Change BOTH implementations and re-run the sum invariant.
(6) Adding a callable? Copy castVote's authorization shape (index.ts:942).
    playerId is NOT a credential. Validate every client-supplied string
    against server state -- AC4 validates the chosen prompt against
    rerollCandidates for exactly this reason.
(7) Server bound first, client bound second. A client-side limit is a
    suggestion. AC4's cap must exist in both and the client reads the constant.
(8) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the exact
    output in the commit body. A DELETION STILL NEEDS ONE.
(9) Ask what input would make your new check go red. If the answer is "a value
    not in its list", the list IS the test. If a guard passes with the fix
    removed, it is measuring nothing -- see AC4 validation 3.
(10) State bugs: the test must NOT re-pump the widget between steps. AC1's
     expansion state lives on a State that outlives the card.
(11) Changing two things that write to the SAME number, document or screen
     region? Compute the COMBINED worst case as a table of real figures first.
(12) Playthroughs: evidence records an observation, not current behaviour.
     NEVER edit a verdict or a specified assertion.
(13) RE-RUN THE FULL BATTERY -- bare, except flutter analyze, where the bar is
     0 errors / 0 warnings / 195 infos and the code is always 1.
(14) DEPLOY after AC4: firebase deploy --only functions, then re-apply
     CLEANUP_DRY_RUN=false and READ IT BACK. Revision-scoped.
(15) COMMIT: one item, one Conventional Commit, WHY in the body. Move the issue
     to the SINGLE existing Resolved heading, leave ONE line there, and put the
     durable consequence in the design doc.
```

**When AC1-AC5 are done the queue is empty again. Do not invent work.**
