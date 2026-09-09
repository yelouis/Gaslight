# Agent Execution Guide — Wave AA: 15 approved code items, 1 blocked, 1 mockup item — September 9, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.**

Selections were made by the user in `docs/ongoing_general_errors.md` on **September 8, 2026** against Issues 153–169, filed from a live playthrough of build 7. **Fifteen items are approved and buildable: AA1–AA14 and AA16a.** Two are not ordinary implementation work:

- **AA15 (Issue 160)** produces design mockups for the user to choose between. **No production code.**
- **AA16b (Issue 162, client half)** is **approved but BLOCKED** on Issue 160's design landing. Its server half, **AA16a, is unblocked and should be built now** — the data contract does not depend on the layout.

**⚠️ Issue 162 was redirected by the user on September 9, 2026** after its first spec was written. The mechanic is now **the target guessing who *wrote* each forgery**, not predicting who will *vote* for what. AA16a and AA16b below carry the current spec; **anything describing a `Record<voterId, optionId>` prediction contract is stale.**

**Issue 165 (Quiplash differentiation) is deferred at the user's direction and must not be worked on, but must not be closed either.**

**Do only what is specified here.** A `(recommended)` label in the issue file is not approval; a filled `Your selection:` line is. **Never fill one in.**

---

## 1. Verified baseline — measured on `f8b8566`

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **276 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **112 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH**, 17 functions |
| all four `check_playthrough_evidence.sh` invocations | **exit 0** |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** Use `lib test`, never bare `flutter analyze`.

**Read every other exit code bare, never through a pipe.**

**⚠️ `pubspec.yaml` is at `1.0.0+7` and build 7 has NOT been uploaded.** Wave Z1 bumped it. **Do not bump again** before the next upload. TestFlight builds 5 and 6 are live; **6 carries the Issue 152 leave bug**, so once 7 ships, expire both 5 and 6.

**⚠️ Any `.xcarchive` under `build/ios/` predates Wave Z1 and must be rebuilt** before a release. `flutter build ipa` will fail at the *export* step on this machine (no Apple Distribution certificate) — **that is expected and is not a build failure**; the archive is still produced and Organizer distributes it. **Verify the archive's timestamp and `CFBundleVersion`, never the `.ipa`.** Full detail in `README.md` → Releasing.

**Production:** `cleanupDaily` runs `every day 04:00` America/Los_Angeles with `CLEANUP_DRY_RUN=false`. ⚠️ **Revision-scoped — re-apply after any functions redeploy.**

---

## 2. Wave AA — the approved queue

**One item = one commit.** Conventional Commit, WHY in the body, never a bare title.

**Implement in the order given.** Six items land on `phase2_craft.dart` and two on `game_over_screen.dart`; the order below is chosen so each builds on a settled tree. **AA1 must be first** — it deletes a widget that later items would otherwise have to work around.

**Two ordering constraints are hard, not stylistic.** **AA10 before AA11** — the round multiplier becomes a line in the itemised transcript. **AA11 before or with AA16a** — the target's forgery guesses add a `target_forger_guess` rule that must satisfy AA11's sum invariant. **AA16b is last and gated**: it cannot start until Issue 160 has a selected design *and* that design is implemented.

### 2.0 Read this before touching anything

**⚠️ Four existing tests currently assert behaviour that Wave AA changes.** They are not bugs. Each is called out in the item that touches it. **Do not edit an existing test unless the item that owns it explicitly says to, and when you do, say why in the commit body.**

| Test | Owned by |
|---|---|
| `vote_option_truncation_test.dart` → *"P9 discoverability: six options at 320x640 portrait exceed viewport height and option at index 3 has non-zero height below fold"* | AA15 (Issue 160) — **asserts the very behaviour the eventual fix removes** |
| `guidance_strings_test.dart` → four exact-string assertions on craft and vote copy | AA12 (Issue 164) |
| `phase4_reveal_test.dart` → *"O2: renders published scoreDeltas …"* | AA11 (Issue 169) — must keep passing, totals stay visible |
| `game_over_screen_test.dart` → *"ceremony gates share button and handles staggers stepwise"* | AA13 (Issue 167) |

**⚠️ `lib/utils/scoring_logic.dart` is a test-only mirror of the server's `functions/src/scoring_logic.ts`.** Nothing in `lib/` calls it. It exists solely for `test/fake_functions.dart` and `test/scoring_logic_test.dart`. **If you change scoring on the server and not in the mirror, the entire client suite will keep passing while computing different numbers from production.** AA10 and AA11 both touch scoring; both must change **both files**.

**⚠️ Playthrough files under `docs/playthroughs/` are evidence, not documentation.** `findings_5player.md` mentions `DealtCardOverlay`, which AA1 deletes. **Do not rewrite a playthrough finding to match new code.** It records what was observed on a build that existed. Leave it.

---

### AA1 — Issue 155 → Option A: delete the dealt-card overlay

**What and why.** `DealtCardOverlay` gates every phase and rotation change behind a full-screen modal whose content is a strict subset of the screen behind it, and whose button is labelled `DISMISS` on truth rounds and `INSPECT` on forgery rounds when it actually *proceeds to writing*. On truth rounds it also hides `RE-ROLL PROMPT`, which sits below the fold on the screen it covers. Remove it.

**Files**

- **Delete** `lib/widgets/dealt_card_overlay.dart`.
- **Delete** `test/dealt_card_overlay_test.dart` (3 tests) and `test/dealt_card_overlay_growth_test.dart` (4 tests). **Expected: `flutter test` drops from 276 to 269 before you add anything.** If it does not drop by exactly 7, stop and find out why.
- `lib/screens/phase2_craft.dart`: remove the import; remove the `bool _showDealtOverlay = false;` field; remove the overlay branch from the `Stack` at `:299`; remove the `_showDealtOverlay = true;` assignment from the phase-change block at `:180`.
- `test/reroll_deck_exhaustion_test.dart`: remove the import and the **four** dead `if (find.byType(DealtCardOverlay).evaluate().isNotEmpty)` blocks (around `:79`, `:165`, `:252`, `:345`).
- `docs/design_ui_direction.md:128`: the paragraph recording the Wave R sizing work (Issue 137) describes a widget that no longer exists. **Replace it with a record that the overlay was removed under Issue 155 and why** — do not simply delete the history.

**⚠️ The phase-change block at `:180` does three other things.** It shows the *"Nobody answered last round. Dealing a new one."* SnackBar on a forgery→truth transition, and it maintains `_lastPhase` and `_lastRotation`. **Only the `_showDealtOverlay` assignment is removed.** The `if (!(state.readyPlayers[me.id] ?? false))` condition guarding it goes with it; everything else stays.

**Copy.** The overlay's one line the writing screen lacks is the *"You have been dealt the ledger of X"* framing. Fold its sense into `instructionText` at `:460`. **This changes a string asserted verbatim by `guidance_strings_test.dart`** — that test is AA12's, so either keep `instructionText` byte-identical and drop the framing, or update the assertion here and say so in the commit. **Prefer keeping it byte-identical**; AA12 rewrites this copy properly.

**Validation**

1. New widget test: entering the craft screen on a phase change, **on the first pump and with zero gestures**, the `ValueKey('answer_field')` field is present and hit-testable, and `RE-ROLL PROMPT` is findable on a truth round. That is the user-facing claim — the previous behaviour required a tap first.
2. **Over-reach guard:** the *"Nobody answered last round. Dealing a new one."* SnackBar still appears on a forgery→truth transition. This is the part of the `:180` block most likely to be damaged by a careless deletion.
3. **Falsification:** stash the deletion, re-add the overlay, and confirm test 1 fails (the modal barrier intercepts the field) while test 2 still passes. **A deletion still needs a falsification** — write the test so the old code fails it.

**⚠️ `AppMotion.deal` is already unused today** — it was the overlay's interstitial timing and has zero references in `lib/` or `test/` before this change, so deleting the overlay does not orphan it and removing it is **not** part of this item. Leave it; the project deliberately retains some dead declarations (see `lastReaction` in §4).

**⚠️ The four guards you are removing from `reroll_deck_exhaustion_test.dart` are conditional (`if present, tap it`), so that file passes whether or not the overlay exists.** It proves nothing about this change either way. Do not cite it as evidence.

---

### AA2 — Issue 156 → Option A: dismiss the keyboard by tapping away

**What and why.** The craft screen has no `GestureDetector`, no `TapRegion`, and no `onTapOutside`. The only way to close the keyboard is `TextInputAction.done`, which *submits*. A player cannot close the keyboard to read the screen without giving up their answer.

**File.** `lib/screens/phase2_craft.dart` — wrap the `Scaffold` body (the `Stack` at `:299`, simplified by AA1) in:

```dart
GestureDetector(
  behavior: HitTestBehavior.translucent,
  onTap: () => FocusScope.of(context).unfocus(),
  child: /* existing Stack */,
)
```

**⚠️ `behavior: HitTestBehavior.translucent` is load-bearing**, not decoration. With the default `deferToChild` the wrapper will not receive taps on empty space; with `opaque` it will swallow taps meant for `SUBMIT DOSSIER` and `RE-ROLL PROMPT`. **Do not substitute either.**

**Scope.** The craft screen only. The lobby fields have the same gap, but that was Option C and was **not** selected — do not touch `lobby_screen.dart` here.

**Validation**

1. New test: focus the answer field, tap empty background, assert focus is released (`tester.binding.focusManager.primaryFocus` is not the field's node, or assert `find.byType(EditableText)` no longer has focus).
2. **Over-reach guards, both existing and both to be run unedited:** `craft_submit_test.dart` → *"Tapping SUBMIT DOSSIER button directly still submits correctly"*, and `phase2_craft_test.dart` → *"shows error SnackBar with 'No more prompts left in this deck.' …"*, which taps re-roll. **If either breaks, your hit-test behaviour is wrong.**
3. **Falsification:** remove the `GestureDetector`; test 1 must fail and both guards must still pass.

---

### AA3 — Issue 157 → Option A: scroll the focused field above the keyboard

**What and why.** `Scaffold` shrinks the body when the keyboard opens. The writing column is `Column > Expanded > SingleChildScrollView` (`:506`) with a pinned `SUBMIT DOSSIER` below (`:682`), and the `TextField` is the **last** element in the scroll view. Once the viewport shrinks, the field's resting position is behind the keyboard and the player types blind.

**File.** `lib/screens/phase2_craft.dart`.

**Implementation**

- Give the `TextField` at `:563` a `FocusNode` stored on the `State`, and **dispose it in `dispose()` alongside `_answerController`**.
- Make `_Phase2CraftScreenState` a `WidgetsBindingObserver`; register in `initState`, **remove in `dispose` before disposing the controller and node**. This is the same shape already used by `AnimatedThinkingBackground` and `_EmberBackdropState` — follow it rather than inventing one.
- Implement `didChangeMetrics()`. When the field has focus and `MediaQuery.viewInsetsOf(context).bottom > 0`, schedule `Scrollable.ensureVisible(fieldContext, alignment: 1.0, duration: AppMotion.fast)` in a post-frame callback.
- Also call it on focus gain, for the case where the keyboard is already open.

**⚠️ Do not do this by adding a fixed bottom padding.** The inset is animated and device-dependent; a constant will be wrong on some device and will not react to a hardware keyboard being attached or detached.

**Validation**

1. **Reuse the existing harness.** `craft_submit_test.dart` already simulates a keyboard: *"Pinned SUBMIT DOSSIER button stays within visible bounds above simulated keyboard (viewInsets.bottom = 300)"*. Copy that `MediaQuery` override technique exactly. New test at 375×667 with `viewInsets.bottom = 300`: after focusing the field, `tester.getRect(find.byKey(const ValueKey('answer_field'))).bottom` must be `<= 667 - 300`.
2. **Over-reach guard:** with `viewInsets.bottom = 0`, the scroll offset must be unchanged from first paint and the `CASE DOSSIER` prompt must still be visible. The fix must not scroll when there is no keyboard.
3. **Over-reach guard:** the existing pinned-button test must still pass unedited.
4. **Falsification:** remove the `ensureVisible` call; test 1 must fail, tests 2 and 3 must pass.

---

### AA4 — Issue 154 → Option A: live character counter, no cap

**What and why.** `kMaxAnswerLength = 100` is enforced only at submit, so a player learns they overran *after* writing, under a timer. **The absence of a cap is deliberate** — the comment at `phase2_craft.dart:69` explains that silently refusing keystrokes leaves the player with no idea why the words stopped. **That reasoning still holds. Do not add `maxLength`.** Add visibility, not enforcement.

**File.** `lib/screens/phase2_craft.dart`, the `TextField` at `:563`.

**Implementation.** Render a counter beneath the field showing `n/100`, driven by a `ValueListenableBuilder<TextEditingValue>` on `_answerController` (or a listener + `setState`). Normal ink colour at `<= 100`; `Theme.of(context).colorScheme.error` above.

**⚠️ Count exactly what the guard counts.** `_submitAnswer` computes `final text = _answerController.text.trim();` then tests `text.length` — Dart `String.length`, i.e. UTF-16 code units, **after trimming**. The counter must use `_answerController.text.trim().length`. **Do not use `.characters.length`** (grapheme clusters) and **do not skip the `.trim()`** — either will disagree with the guard on emoji, accents, or trailing spaces, and a counter that contradicts the error message is worse than no counter.

**Do not touch** `_submitAnswer`'s guard or the server bound. Both stay exactly as they are.

**Validation**

1. New test: enter 50 characters → counter reads `50/100` in the normal colour. Enter 101 → reads `101/100` in the error colour.
2. New test: enter `"  abc  "` → counter reads `3/100`, matching the trimmed guard.
3. **Over-reach guards, both existing, both unedited:** `phase2_craft_test.dart` → *"warns and blocks submission when the answer exceeds 100 characters"* and `craft_submit_test.dart` → *"101-character text via done key triggers length guard and shows snackbar without submission"*. **If either fails you have added a cap, which is Option B and was rejected.**
4. **Falsification:** remove the counter; tests 1 and 2 fail, both guards pass.

---

### AA5 — Issue 166 → Option A: sentence stems per prompt

**What and why.** A player stuck on a prompt has no help. `RE-ROLL PROMPT` exists only on truth rounds; on forgery rounds — the harder task, writing in someone else's voice — there is no escape and no aid.

**Architecture decision, and the reason for it.** Stems live in the deck catalogue and are looked up **client-side by prompt text**. The server, the room document and the card schema **do not change at all**. The card already carries `promptText`, the client already has a generated deck mirror, and custom-deck prompts simply will not be found — which correctly yields no stem. Adding stems to the card would be a hot-path schema change for no benefit.

**Files**

- `functions/src/prompt_decks.ts` — add an optional sibling field to `DeckDefinition`:
  ```ts
  /** Optional writing aids, keyed by the EXACT prompt text they belong to. */
  stems?: Record<string, string[]>;
  ```
  **Keep `prompts: string[]` exactly as it is.** All 150 existing prompt literals stay untouched, which keeps `check_decks_in_sync.sh`'s sanity floor (`DECKS >= 1`, `LINES >= 50`) meaningful.
- **Add a module-load assertion** that every key of every `stems` map matches a prompt in that same deck, and throw if not — the same style as `getFallbackDeckId()`, which already throws on a malformed catalogue. **A text-keyed map silently detaches when a prompt is reworded; this assertion converts that into a startup failure instead of a silently missing feature.** Without it, do not ship this item.
- `scripts/generate_prompt_decks_dart.mjs` — emit the stems map into the Dart mirror.
- `lib/utils/prompt_decks.dart` — **generated, never hand-edited.** Regenerate with `./scripts/generate_prompt_decks_dart.sh`.
- `lib/screens/phase2_craft.dart` — look up stems for `targetCard.promptText` and display one beneath the field.

**⚠️ Display the stem. Never insert it into the controller.** If stems are pre-filled, every player's answer starts identically, which is both boring and a direct feed into the duplicate-answer heuristic in `design_semantic_integrity.md` — the game would start rejecting answers for being too similar because it made them similar. **Assert this in a test.**

**⚠️ Substitution recorded.** Issue 166 Option A says the stems should differ "for truth and forgery rounds". This spec uses **one stem list per prompt with phase-dependent framing** — truth renders it plainly, forgery renders it as writing *as* the target — because the stem is an opener for the same prompt and the deceit is in the content, not the opener. This halves the content work from 300 stems to 150. **If the user wants genuinely distinct stems per phase, the field becomes `Record<string, {truth: string[], forgery: string[]}>` and the content cost doubles.** Flag this rather than deciding it silently.

**Content.** There are **150 prompts across 5 decks** (`hypotheticals`, `real_life`, `unhinged_quirks`, `love_life`, `rated_r_nsfw`). Stems must match each deck's register — the `rated_r_nsfw` stems are not the `hypotheticals` stems. **This content authoring is the bulk of the work, not the plumbing.**

**Validation**

1. New test: a catalogue prompt with stems renders a stem; `_answerController.text` is still empty after pump.
2. New test: a prompt **not** in the catalogue (simulating a custom deck) renders no stem and does not throw.
3. New functions test: a `stems` key that matches no prompt in its deck throws at module load. **Falsify it by adding a bogus key.**
4. `./scripts/check_decks_in_sync.sh` exits 0 bare. **Then falsify it:** hand-edit a stem in `lib/utils/prompt_decks.dart` and confirm exit 1. If it still exits 0, the generator is not emitting stems and the mirror can silently diverge.
5. **Over-reach guard:** `guidance_strings_test.dart`'s four exact-string assertions still pass. The stem is *additional* copy, not a replacement.

---

### AA6 — Issue 158 → Option A: give the waiting screen something to show

**What and why.** A player who submits early is sent to `_buildWaitingUI` (`:402`) and blocked until the slowest writer finishes. With `forgeriesPerCard = min(players - 1, 5)` that is up to 4 barriers per card cycle. Option A keeps the barrier and fills the wait.

**⚠️ Show only the player's own writing.** Other players' answers live in the `sealed` subcollection, which is **default-deny by having no `match` block**, and "never send other players' authorship to the client" is a standing invariant. The waiting screen must not attempt to fetch or display anything but what this player themselves typed.

**Implementation.** `_submitAnswer` clears `_answerController` on success (`:135`), so the submitted text is gone. (The re-roll handler clears it too, at `:629` — that path is unrelated and must not be touched.) Retain it:

- Add `String? _lastSubmittedAnswer;` to the `State` and set it in `_submitAnswer` immediately before clearing the controller.
- Render it in `_buildWaitingUI` beneath the existing *"THE INK DRIES…"* block, together with the prompt it answered.

**⚠️ This field is exactly the trap lesson 2.40 was written about.** It sits on a `State` that survives every rotation, so **it must be reset in the same `_lastPhase` / `_lastRotation` block at `:180`** that AA1 edits. Without the reset, rotation 2's waiting screen displays rotation 1's answer. **The test for this must drive two rotations without re-pumping the widget** — re-pumping constructs a fresh `State` and will pass against the broken code. This is precisely how Issue 152 shipped.

**Not in scope.** Option A also permitted letting the player *revise* a submitted answer. That needs `submitCardAnswer` to accept an overwrite and the similarity check to re-run server-side, which is work the cheaper half of the option does not cover. **Implement the read-only recap only, and note the omission in the commit body.**

**Validation**

1. New test: submit an answer, assert the waiting screen shows that exact text.
2. New test, **the important one**: submit on rotation 1, advance to rotation 2 **without re-pumping**, submit again, assert the recap shows rotation 2's answer and not rotation 1's.
3. **Falsification:** remove the reset; test 2 must fail and test 1 must still pass. **If test 2 passes without the reset, your test re-pumped — rewrite it.**

---

### AA7 — Issue 153 → Option A: harden the room-code field

**What and why.** `lobby_screen.dart:1289` leaves `autocorrect` and `enableSuggestions` at their defaults (`true`) with no `inputFormatters`, so iOS treats a 4-letter code as a misspelling and offers substitutions.

**File.** `lib/screens/lobby_screen.dart`, the `TextField` at `:1289`. Add:

```dart
autocorrect: false,
enableSuggestions: false,
keyboardType: TextInputType.text,
inputFormatters: [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
  UpperCaseTextFormatter(),   // must preserve TextEditingValue.selection
],
```

**Keep** `textCapitalization: TextCapitalization.characters` and `maxLength: 4`. **Do not touch `generateRoomCode`** — the word-list change was Option B and was **not** selected. **Do not touch `_joinRoom`'s `.toUpperCase()` at `:197`**; a client-side formatter is a convenience, not a guarantee.

**⚠️ The uppercasing formatter must carry `selection` through**, or the caret jumps to position 0 on every keystroke. Return a new `TextEditingValue` with the original `selection`, not just a new string.

**Validation**

1. New test: `autocorrect` and `enableSuggestions` on the `TextField` widget are both `false`. **These are platform behaviours that cannot be observed in a widget test — assert the widget's properties, which is exactly what is being changed.**
2. New test: entering `ab1c!d` leaves the controller holding `ABCD`.
3. New test: type into the middle of an existing value and assert the caret does not jump — this is the formatter regression.
4. **Over-reach guards, unedited:** `lobby_entry_test.dart`, `lobby_join_error_test.dart`, `lobby_leave_test.dart`, `lobby_version_test.dart`. `lobby_screen.dart` is the most-regressed file in the project (Issues 151 and 152 both landed there); run all four.
5. **Falsification:** remove the formatters; tests 2 and 3 fail, guards pass.

---

### AA8 — Issue 161 → Option A: make the target's ready a toggle

**What and why.** `phase3_vote.dart:504` renders `I'M READY` for the target, sets a local `_submitted = true`, and offers no way back. The lobby's identically-labelled button at `lobby_screen.dart:1137` *does* toggle. Two buttons, one label, two contracts.

**⚠️ Step 1 — determine this before writing any client code, and record the answer in the commit body.** Read `setReady` in `functions/src/index.ts` and establish **what happens when a player un-readies after the readiness gate has already fired and the phase has advanced.** If it can corrupt `readyPlayers` or resurrect a completed phase, **the server must reject it** and that rejection is part of this item. This is the entire risk of the option, named in its own cons. **Do not reason about it — write an emulator test in `functions/test/` that calls `setReady(false)` after the phase advanced, and report what it does.**

**Implementation, client.** Render `NOT READY` and call `setPlayerReady(false)` when `state.readyPlayers[me.id] == true`.

**⚠️ Drive the button from server state, not from `_submitted`.** `_submitted` is a `State` field on a screen that persists across readers and rotations — the same class of latch as Issue 152's `_isLeaving`. **Derive the button's appearance from `state.readyPlayers[me.id]` and remove the local latch from this path entirely.** Keep whatever re-entrancy guard is needed for the in-flight call, but it must not be the source of truth for what the button shows.

**Validation**

1. New test: target taps `I'M READY`, sees `NOT READY`, taps again, is un-readied.
2. New test: after a reader change, the button reflects the new card's readiness and is not stuck from the previous one. **Do not re-pump between the two cards.**
3. New functions test: `setReady(false)` after the phase advanced behaves as Step 1 determined — rejected or a clean no-op, never a corruption.
4. **Over-reach guard, unedited:** `phase3_vote_test.dart` → *"O9: Target player sees card prompt and read-only options grid with no confirm vote button (Issue 121)"*.
5. **Falsification:** revert to the one-way button; tests 1 and 2 fail, the guard passes.

---

### AA9 — Issue 159 → Option A: suppress the meaningless best-forgery banner and handle ties

**What and why.** `_buildBestForgeryBanner` (`phase4_reveal.dart:110`) crowns a winner whenever any forgery got at least one vote. **At 3 players `forgeriesPerCard = 2` and only 2 players vote, neither able to vote for their own answer — so a forgery can receive at most 1 vote and the banner celebrates it as the round's best.** Separately, the tie-break at `:124` uses a strict `entry.value > maxVotes` over map entries, so a 1–1 tie silently crowns whichever author Firestore yields first. **The tie bug affects every player count and was not in the playthrough report.**

**File.** `lib/screens/phase4_reveal.dart`, `_buildBestForgeryBanner`.

**Implementation.** After computing `voteCounts`, return `null` unless **both**:
- `maxVotes >= 2` — "best" must mean it fooled more than one person; and
- exactly one author holds `maxVotes`.

**Decision recorded.** Option A allowed either naming all tied authors or showing nothing on a tie. **Show nothing** — naming several contradicts "BEST", and it keeps the two suppression rules uniform.

**Consequence to accept.** At 3 players the banner will now never appear. That is intended. **Check on device that the reveal still reads as complete without it** rather than assuming.

**Validation**

1. New test: 3 players, best forgery has 1 vote → no banner.
2. New test: 1–1 tie → no banner.
3. New test: clear winner with 2 votes → banner renders and names them.
4. **Over-reach guards, unedited:** all 7 tests in `phase4_reveal_test.dart`.
5. **Falsification:** revert the guard; tests 1 and 2 fail, test 3 passes.

---

### AA10 — Issue 163 → Option A: per-round scoring multiplier

**What and why.** Every round scores identically, so a match has no arc and an early deficit is permanent. Apply a multiplier to points already awarded, changing no rule and no screen.

**⚠️ This reverses a standing decision and the reversal must be recorded.** `docs/ongoing_general_errors.md` §4 lists **P7 Confidence Wager**, **P9 House Cards** and **P11 The Final Gambit** as consciously not built, under the heading *"do not re-propose"*. §4 already carries a pointer to Issue 163. **Amend §4 in this commit** to record that the narrow scoring escalation was selected on September 8, 2026 while P7/P9/P11 themselves remain rejected. **Leaving §4 contradicting the queue is not acceptable.**

**Files — both of them.**

- `functions/src/scoring_logic.ts` — the real implementation.
- `lib/utils/scoring_logic.dart` — **the test-only mirror.** See §2.0. Changing one and not the other leaves the client suite green while computing different numbers from production.

**Implementation.** In `calculateScores`, multiply the accumulated deltas by `Math.max(1, state.currentRound ?? 1)`. Round 1 = ×1, round 2 = ×2, and so on.

**⚠️ Verify `currentRound` is actually populated on the object passed in.** `index.ts:1698` passes `room`; `currentRound` is set at `:420`, `:701` and `:1441`. **Default to 1 if absent — never to 0**, which would zero every score.

**Decision recorded.** The multiplier applies **only inside `calculateScores`**, not to the ±1 unmask revenge. Revenge is a fixed social penalty; multiplying it would make a late wrong accusation catastrophic. **State this in the commit body** so the next agent does not "fix" the inconsistency.

**Validation**

1. New functions test: identical votes at `currentRound` 1, 2 and 3 produce ×1, ×2 and ×3 the deltas.
2. New functions test: `currentRound` absent → behaves as round 1.
3. **The same fixtures, mirrored** into `test/scoring_logic_test.dart` against the Dart copy, asserting the same numbers. **This is the only defence against the two implementations drifting.**
4. **Over-reach guards, unedited:** the 2 existing tests in `test/scoring_logic_test.dart` (Issue 78) — they run at round 1 and must be unaffected.
5. **Falsification:** remove the multiplier; tests 1 and 3 fail, tests 2 and 4 pass.

---

### AA11 — Issue 169 → Option A: itemise the deltas and rewrite the manual copy

**What and why.** Two failures. The in-app manual prints a raw formula — *"Formula: ceil((Players - 1) / (Forgeries + 1))"* (`lobby_screen.dart:288`) — at players. And the reveal's `POINTS AWARDED THIS CARD` block (`phase4_reveal.dart:454`) shows only totals, so with five scoring rules in play a player cannot tell which one fired.

**Do AA10 first.** The round multiplier becomes one of the lines this transcript shows.

**Part 1 — server.** Emit an itemised breakdown alongside `scoreDeltas`: `Record<playerId, Array<{rule: string, points: number}>>`, with rules `truth_found`, `sharp_eye`, `believable_target`, `successful_forgery`, and `round_multiplier`. Add it to `CardModel` in **both** `functions/src/scoring_logic.ts` and the Dart model, and to the test-only mirror.

**⚠️ `pendingScoreDeltas` is flushed at three sites — `advancePhaseInternal`, `advanceToNextResolution`, and `closeUnmaskWindow`.** This is a standing invariant. **The breakdown must be carried at all three or it will be silently missing at one**, and the one it goes missing at will be whichever path your manual test does not exercise. Enumerate all three and test each.

**Part 2 — client.** Replace the `Chip` row at `:451–475` with itemised lines per player. **Totals must remain visible** — `phase4_reveal_test.dart` → *"O2: renders published scoreDeltas including negative deltas (▼-1) and positive deltas (▲+3)"* is an over-reach guard and must pass unedited.

**Part 3 — manual copy.** Rewrite `3. SCORING (Dynamic)` at `lobby_screen.dart:288–294` in plain language. Demote the formula to a footnote; do not delete it.

**Validation**

1. **The strongest available invariant, and it must be a test:** for every player on every fixture, `sum(breakdown[player].points) == scoreDeltas[player]`. Run it over several fixtures including negative deltas and a multiplied round.
2. New functions test per flush site: the breakdown survives `advancePhaseInternal`, `advanceToNextResolution` and `closeUnmaskWindow`.
3. New widget test: the reveal renders a named line per rule and still renders the total.
4. **Over-reach guards, unedited:** all 7 tests in `phase4_reveal_test.dart`.
5. **Falsification:** drop the breakdown from one flush site; test 2 must fail for that site and pass for the other two. **If all three still pass, your test is not reaching the flush sites.**

---

### AA12 — Issue 164 → Option A: rules per phase, and a manual button in-game

**What and why.** `READ MANUAL` exists at exactly one place — `lobby_screen.dart:1347`, on the pre-game entry screen. Once a match starts there is no route back to it.

**⚠️ The option's premise is wrong and this spec corrects it.** Issue 164 Option A says the button "lands in one place" because `in_game_app_bar.dart` is a shared header. **It is not a widget.** That file exports a single function, `inGameAppBarHeight()`, which computes a height. Each of `phase2_craft.dart`, `phase3_vote.dart` and `phase4_reveal.dart` builds **its own `AppBar`**. The button must be added to **three** `actions:` arrays.

**⚠️ And adding it breaks the height calculation.** `inGameAppBarHeight` computes `availableWidth = screenWidth - 112.0`, where 112 is 56 pt of leading plus 56 pt of trailing reserve. **A second trailing action makes the real reserve 168 pt**, so titles will be measured against more width than they have and can overflow. **Parameterise the reserve** (e.g. a `trailingSlots` argument) and pass the correct count from each screen.

`in_game_app_bar_test.dart` and `phase4_header_overflow_test.dart` exist and are your guards here. **Extend them to cover the two-action case** rather than only running them.

**Contextual copy.** Craft already has `instructionText`; vote already has *"Talk it out — discussion is part of the game."*; reveal has none. **Audit what exists before writing new copy and fold rather than duplicate** — the craft and vote screens are the two most space-starved in the app (Issues 157 and 160), so a new line must come out of existing chrome, not on top of it.

**This item owns `guidance_strings_test.dart`.** Its four exact-string assertions will change, and that is legitimate here because the copy *is* the deliverable. **Update them to the new exact strings. Do not loosen them to `contains`** — verbatim assertion is the point of that file.

**Validation**

1. New test: a rules affordance is present in the app bar on all three in-game screens and opens the manual.
2. New test: each phase renders its contextual line.
3. **Extended guards:** `in_game_app_bar_test.dart` and `phase4_header_overflow_test.dart` must cover two trailing actions at 320 pt and at text scale 2.0 with no overflow.
4. `guidance_strings_test.dart` updated to the new verbatim strings and passing, including its 320 pt no-overflow test.
5. **Falsification:** revert the `trailingSlots` parameterisation while keeping the button; the extended header tests must fail. **If they pass, they are not measuring the reserve.**

---

### AA13 — Issue 167 → Option A: standings above honors

**What and why.** `game_over_screen.dart:241–256` renders `THE NIGHT'S HONORS` heading → honor cards → `FINAL STANDINGS` → `MATCH HIGHLIGHTS`. The score is what every player wants first and it is below a full block of superlatives.

**Implementation.** Render `_buildStandings` before `_buildHonorCards`. **Retitle the page heading** — it currently announces the honors as the screen's subject, which becomes wrong the moment they are not first — and give the honors block its own heading.

**⚠️ The honors block carries the staggered reveal sequence** (`honorsSequence`, `:323–330`). Moving it below the standings means the animated payoff now begins off-screen. **Verify the ceremony still works rather than assuming the move is inert.**

**Validation**

1. New test: standings render above honors in the widget tree order.
2. **Over-reach guards, unedited:** `game_over_screen_test.dart` → *"ceremony gates share button and handles staggers stepwise"* and *"MF1: pins actions in bottom bar and is visible at 360x640 portrait without scrolling"*.
3. **Falsification:** swap the order back; test 1 fails, guards pass.

---

### AA14 — Issue 168 → Option A: highlight titles on their own line

**What and why.** `_highlightCard` (`game_over_screen.dart:779`) puts the title (`Expanded`, `maxLines: 1`, ellipsis) and the badge (`Flexible`) in one `Row`, after a 16 pt icon and two 6 px gaps. `BEST LIE OF THE NIGHT` in CormorantGaramond 14 pt with `letterSpacing: 1.2` loses that contest on narrow viewports and at raised text scale.

**Implementation.** Move the badge onto its own line — beneath the title or into the card footer — so the title owns the full card width. With the competition removed, the title's `maxLines: 1` and ellipsis can be relaxed.

**⚠️ Do not solve this by auto-sizing the title.** That was Option C and was rejected: a letter-spaced display face at 14 pt has almost no headroom before it becomes unreadable, which trades a truncation bug for a legibility bug.

**Validation**

1. New test, **mechanical, not visual**: at 320 pt width, render `_highlightCard` with the longest real title (`BEST LIE OF THE NIGHT`) and assert `RenderParagraph.didExceedMaxLines == false`. `vote_option_truncation_test.dart` uses exactly this technique — copy it.
2. Repeat at text scale 1.0 and 2.0.
3. **Over-reach guard, unedited:** *"MF1: pins actions in bottom bar and is visible at 360x640 portrait without scrolling"* — the cards get taller and there are three of them plus the rivalries block.
4. **Falsification:** restore the shared `Row`; test 1 fails.

---

### AA15 — Issue 160: **design mockups only — do not implement**

**The user selected Option C (paged/swipeable options) but explicitly gated it:**

> *"Lets do option C but before actually implementing it, create some demo images for me to view and select which paged/swipeable design is the best."*

**The deliverable is images and a recommendation, not code.** Do not modify `card_grid.dart` or `phase3_vote.dart` in this item.

**What to produce.** Four distinct paged/swipeable treatments of the vote options:

1. **Single card, full width, dot indicators** — one answer per page.
2. **Two-up carousel** — two answers visible, swipe for the next pair.
3. **Stacked deck with peek** — the next card's edge visible behind the current one, matching the parlour framing.
4. **Segmented pager** — numbered tabs above a single answer pane, so any option is reachable in one tap rather than N swipes.

**Render each at 320 pt and 430 pt width**, with **6 options** (the 7-player case) and with a genuine **100-character** answer in at least one slot — the longest legal answer is the case that breaks layouts, and `kMaxAnswerLength = 100`.

**Render them with the real palette and typography** from `design_ui_direction.md` — CormorantGaramond, Lora, parchment/brass/oxblood — by building throwaway widgets and capturing them from a widget test. **Mockups drawn in a different toolchain will not tell the user what the screen will actually look like**, which is the entire purpose of this exercise.

Save to `docs/playthroughs/evidence/` **only if** the evidence gate tolerates it; otherwise create a new directory (e.g. `docs/mockups/vote_options/`) and **verify all four `check_playthrough_evidence.sh` invocations still exit 0 bare** — that gate has rules about what lives under `docs/playthroughs/`.

**Then stop and present them.** File the choice as a new option set in `ongoing_general_errors.md` under Issue 160 with a fresh `Your selection: _____`.

**⚠️ Record now, for whoever implements the chosen design:** `vote_option_truncation_test.dart` → *"P9 discoverability: six options at 320x640 portrait exceed viewport height and option at index 3 has non-zero height below fold"* **asserts the current below-the-fold behaviour that Option C exists to remove.** That test will have to be rewritten, and rewriting a passing assertion needs its own justification in the commit body. **It is not collateral damage — it is a deliberate contract being replaced.**

---

### AA16a — Issue 162 → server half: the target unmasks the forgers

**Redirected by the user on September 9, 2026.** The mechanic is **not** predicting which answer each voter will pick. It is:

> *"the target guesses which answer each voter **created**. The target guesses who wrote each lie for points."*

While their own card is being voted on, the target attributes each forgery to the player they think wrote it. Correct attributions score.

**⚠️ This supersedes the vote-prediction spec entirely.** If you are reading a `Record<voterId, optionId>` contract anywhere, it is stale — the contract is now `Record<optionId, guessedAuthorId>`.

**Why this version is better founded than the one it replaces.** The game already has an authorship-guess mechanic — `submitUnmaskGuess`, the revenge guess (P8). This is that verb, extended to the one player who can never use it: **the target is never fooled, because the target never votes**, so they are currently excluded from the only deduction beat in the game. It is also a genuinely harder puzzle than the vote prediction was — each forger writes at most one forgery per card, so the target is matching people to prose, which is exactly the "how well do you know these people" premise.

**⚠️ Split into two items on purpose. AA16a is unblocked; AA16b is not.** The contract `Record<optionId, guessedAuthorId>` does not depend on the layout, so the whole server half can be built and proven with emulator tests now. **AA16b needs the vote screen's layout, which Issue 160 has not settled.**

#### What already exists — read it before writing anything

- **`submitUnmaskGuess` (`index.ts:2096`) is your template.** Copy its authorization shape, its validation ordering, and above all its deliberate silence: it **does not return correctness**, so results land with the author flip. The new callable must be equally silent.
- **`sealed/{cardId}.answerAuthors` is `Record<optionId, authorId>`** (`index.ts:868`), already populated. It is both the answer key and the validator.
- **`sealed` is default-deny by having no `match` block.** Guesses go there and nowhere else.
- **The exclusion-in-two-places idiom.** `submitUnmaskGuess` at `index.ts:2166–2173` rejects accusing the card's target, and carries a comment naming its client twin in `phase4_reveal.dart:_buildRevengeGuessTray`: *"Change both or neither."* **Follow that idiom for every exclusion you add here — client copy keeps the impossible choice off screen, server copy is the real guard, and each site names the other.**

#### The callable

`submitTargetForgeryGuesses({ roomCode, cardId, guesses })` where `guesses` is `Record<optionId, guessedAuthorId>`.

**Phase gate — and this is the one place it deliberately differs from `submitUnmaskGuess`.** That callable requires `currentPhase === "reveal"` inside an active `unmaskDeadline`. **This one requires `currentPhase === "vote"`**, because the entire point of Issue 162 is the dead seat during voting. Guessing during the vote phase is also a *purer* test: by the reveal, vote tallies are visible and would leak inference.

Validation, in order:

1. No `request.auth` → `unauthenticated`.
2. `rooms/{roomCode}/players/{cardId}` exists and `authUid === request.auth.uid` → `permission-denied`. **`playerId` is not a credential** (§4).
3. Transaction. Room exists. `room.currentPhase === "vote"` → else `failed-precondition`.
4. `cardId === room.currentReaderId` → else `failed-precondition`.
5. **The caller must be the card's target.** The target is the only player who guesses here, and `cardId` *is* the target's player id, so steps 2 and 4 together already bind it — **assert it explicitly anyway** rather than relying on that coincidence holding after a refactor.
6. `room.readyPlayers[cardId] !== true` → else `failed-precondition`. **Guessing closes when the target readies.** AA8 makes that ready a toggle, so un-readying reopens the window. That is intended and must be tested.
7. Read `sealed/{cardId}`; take `answerAuthors`.

Then, for **every entry** in `guesses`:

- `optionId` must be a key of `answerAuthors` → else `invalid-argument`.
- **Reject if `answerAuthors[optionId] === cardId`.** That is the target's own truth. They wrote it; attributing it is not a guess. **Two places, cross-commented.**
- **Reject placeholder options** — an option whose text is `kMissingAnswerPlaceholder` was authored by nobody. Mirrors `castVote`'s placeholder refusal.
- `guessedAuthorId` must be an **active non-spectator player** in the room → else `invalid-argument`.
- **Reject `guessedAuthorId === cardId`.** The target cannot have forged on their own card. This is Issue 79's exclusion inverted, and deserves the same two-place treatment.

**Write semantics: replace, not merge.** A resubmission overwrites the whole map, so the target can *unassign* a guess. A merge makes that impossible.

**No uniqueness constraint — a decision, with a reason.** Each forger writes at most one forgery per card, so a complete correct answer *is* a matching, and it is tempting to enforce one-player-per-option. **Do not.** A forger who never submitted leaves a placeholder, and a mid-card departure removes a candidate, so the bijection is not guaranteed and a uniqueness rule would deadlock the UI in exactly the awkward cases. Accept any map; let the client hint visually if it wants.

**Partial maps are legal.** Unguessed forgeries score nothing.

**Storage:** `sealed/{cardId}.targetForgeryGuesses`. **Never on the room document** — the room is world-readable and the target's guesses are a live read of the table.

**Return `{ success: true }` and nothing else.** No correctness, no count, no hint. `submitUnmaskGuess` is deliberately silent for this exact reason and the design contract in `design_scoring_and_ui.md` records it.

#### Scoring

Add an optional parameter to `calculateScores` in **both** `functions/src/scoring_logic.ts` and the test-only mirror `lib/utils/scoring_logic.dart` (§2.0 — both or neither):

```ts
targetForgeryGuesses?: Record<string, string>   // optionId -> guessedAuthorId
```

Award the target `kTargetForgeryGuessPoints` for each entry where `answerAuthors[optionId] === guesses[optionId]`.

**⚠️ Decision: `+1` per correct guess, and no penalty to anyone.** The revenge guess costs the forger `−1` because that forger *successfully deceived that specific voter* and is being caught out. **The target was never deceived — they do not vote — so there is no revenge to take**, and penalising a forger for being recognisable by someone who was never their victim would be a different rule wearing the same coat. Define the value as a **single named constant in both implementations** so rebalancing is one line. Tell the user it is the knob.

**Rule id for AA11's breakdown: `target_forger_guess`.** It must be distinct from the revenge guess's rule id — they are different rules with different eligibility and different penalties, and collapsing them in the transcript would be a lie about how the points were earned.

#### ⚠️ The leak, and it is not obvious

`design_scoring_and_ui.md` records that while `unmaskDeadline != null`, `scoreDeltas` is **withheld** from the public card and player `totalScore` increments are stashed in `sealed/{cardId}.pendingScoreDeltas` (Issues 113, 124, 133) — precisely so that a score moving does not reveal forgery authorship before the authors flip.

**The target's guess points are authorship information by construction.** If they reach the public card or a `totalScore` while the unmask window is open, the table learns the target guessed right — which narrows authorship for everyone still holding a revenge guess.

**Therefore: route these points through `calculateScores` so they inherit the existing withholding automatically, and prove it with a test.** Do not add a separate write path. **Enumerate all three `pendingScoreDeltas` flush sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow` (§4) — and confirm the points survive each.

Likewise, **the guesses themselves stay in `sealed` until authorship is published.** Publish results with the author flip, never before.

#### Departures and placeholders

A guessed player who leaves mid-card, and a forgery that is a placeholder, must both **score nothing and not throw**. The 3-player floor and the departure recalculation already exist; this must not become a new crash path.

#### Docs to update

- `design_scoring_and_ui.md` — the new scoring term, its eligibility, and its place in the withholding contract alongside P8.
- `design_database_and_security.md` — the new `sealed/{cardId}.targetForgeryGuesses` field and why it cannot live on the room.

#### Validation

1. Emulator test: all forgeries attributed correctly scores `forgeries × 1` to the target and nothing to anyone else. **In particular, assert no forger is penalised** — that is the decision above, and a test is how it stays decided.
2. Emulator test: a partial map scores only the correct entries.
3. Emulator test per rejection — **eight of them, eight assertions**: non-target caller; wrong phase (`reveal`); wrong card; target already ready; `optionId` not on the card; guess on the target's own truth; guess naming the target as a forger; guess naming a player not in the room. Add a ninth for the placeholder option.
4. Emulator test: resubmission **replaces** — guess two options, resubmit with one, assert the other is gone.
5. Emulator test: un-readying reopens the window (pairs with AA8).
6. **Leak test, the important one:** with `unmaskDeadline` active, the public card carries **no** `scoreDeltas` and no `totalScore` has moved, while `sealed/{cardId}.pendingScoreDeltas` holds the target's guess points. Then close the window and assert they land.
7. Emulator test per flush site — all three.
8. **`functions/test/rules.spec.ts`: a non-target client still cannot read `sealed/{cardId}`.** Proves the new field did not change the default-deny posture.
9. Emulator test: a guessed player who left mid-card scores nothing and the reveal completes.
10. **Mirror the scoring fixtures into `test/scoring_logic_test.dart`** against the Dart copy, same numbers. §2.0.
11. **AA11's sum invariant re-run** with `target_forger_guess` in play.
12. **Over-reach guards, unedited:** every existing test in `functions/test/game_e2e.spec.ts` and `functions/test/rules.spec.ts`. **The revenge guess must be untouched** — same eligibility, same ±1, same silence.
13. **Falsification:** remove the own-truth rejection; test 3's matching case fails and the other eight pass. Then remove the scoring term; tests 1 and 2 fail and the rejections pass. Then route the points around `calculateScores`; **test 6 must fail** — if it still passes, it is not observing the withholding.

---

### AA16b — Issue 162 → client half: forgery attribution on the vote screen

**⚠️ BLOCKED. Do not start until Issue 160 has a selected design and it is implemented.** The attribution UI sits on the target's branch of the vote screen, and that screen's option layout is being redesigned — AA15 produces mockups, the user picks one, and only then does this have a surface. **Building it against today's scrolling `CardGrid` means building it twice.**

**Interaction: tap-to-assign, not drag.** Tap a player chip, then tap a forgery. The vote screen already does not fit at 320 pt with six options (that is Issue 160), and drag across a scrolling list needs auto-scroll-while-dragging, offers small drop zones, and is hard to correct under a timer. Tap carries identical information, works at 320 pt, is trivially correctable, and is testable in a widget test in a way drag is not.

**If Issue 160 lands on a paged layout the interaction gets easier, not harder** — with one answer on screen the target picks its author from a chip row beneath it. Do not treat the redesign as an obstacle.

**Two exclusions must be enforced on the client too**, each carrying a comment naming its server twin, per the `submitUnmaskGuess` idiom:

- The target's **own truth** is not attributable — no affordance on it.
- The **target themselves** is not a candidate author.

**Scope.** The target's branch of `phase3_vote.dart` only. The voter path is untouched. Call the `game_service.dart` wrapper added in AA16a; **this item adds no server surface.**

**⚠️ No feedback of any kind.** Do not show correctness, a running score, or a "that one's already taken" hint derived from anything but local state. The server is deliberately silent (AA16a); the client must not invent a signal it does not have.

**⚠️ This item edits an existing passing test — say so in the commit body.** `phase3_vote_test.dart` → *"O9: Target player sees card prompt and read-only options grid with no confirm vote button (Issue 121)"*. **The "no confirm vote button" half stays true and must keep being asserted — the target still never votes.** The "read-only" half stops being true. Update that assertion precisely; **do not delete the test and do not loosen it to a `contains`.**

**Validation**

1. Widget test: tap a player chip then a forgery; the attribution renders; tapping another chip on the same forgery replaces it; tapping the assigned chip again clears it.
2. Widget test: the target's own truth offers no attribution affordance.
3. Widget test: the target does not appear in the candidate author list.
4. Widget test at 320 pt with six options and the maximum candidate count for the chosen layout — no overflow, every chip reachable.
5. Widget test: a partial map submits successfully.
6. **State-lifetime guard.** The local attribution map lives on a `State` that survives reader changes. **Advance to the next card without re-pumping and assert the map is cleared.** This is the Issue 152 / lesson 2.40 trap for the third time in this wave; a re-pump builds a fresh `State` and passes against broken code.
7. **Over-reach guard:** the voter path is unchanged — `CONFIRM VOTE` still works, self-voting still refused.
8. **Falsification:** remove the clear-on-reader-change; test 6 fails and test 1 passes. Then remove the own-truth exclusion; test 2 fails.

---

### Not in Wave AA

- **Issue 165 (Quiplash differentiation) is deferred** — *"Lets put this off for now but don't lose this issue."* **It stays open with a blank selection line. Do not close it, do not implement any part of it, and do not let a later consolidation drop it.**

---

## 3. Already delivered — do NOT rework

### Wave Z

- **Z1 (Issue 152) ✅** — the leave latch is reset in a `finally`:
  ```dart
  try { await gs.leaveRoom(); } finally { if (mounted) _isLeaving = false; }
  ```
  **Independently falsified:** removing the `finally` makes **both** new tests fail while **all seven original tests still pass**, including *"double-tapping confirm leaves exactly once"* — which was left unedited. That is the right shape: the new tests catch the regression and the existing suite is untouched.
  **The falsifying test was built correctly**, which was the hard part: it uses `pumpLobbyScreen` once and then drives the second room through `gameService.createRoom` inside `runAsync` **without re-pumping**. Re-pumping would have constructed a fresh `State` and passed against the broken code.
  See lesson **§2.40** in `ongoing_general_errors.md` for the durable version of this trap.

### 3.1 Standing maintenance actions — not queue work

These are always legitimate, alongside — not instead of — Wave AA in §2.

1. Answer questions about the state of the repository.
2. Re-run the baseline in §1 to confirm it still holds.
3. If a gate that §1 says is green goes red, investigate and **file** it.
4. **After any `firebase deploy --only functions`, re-apply `CLEANUP_DRY_RUN=false` and read it back.** Maintenance of an existing decision, not new work.
5. Ship a release by following `README.md` → **Releasing**.

### Earlier

- **Y1 (151)** title-screen version label read from the bundle at runtime. **It worked the first time it was needed** — it is what let a "missing feature" report be resolved as a build-version artefact (Issue 150).
- **Y2 (149)** R5 checks cited evidence paths **anywhere in a block, including `NOT RUN` blocks**, while never requiring one.
- **Issue 150 — CLOSED with no code change.** The deck `PEEK INSIDE` affordance ships, renders, and is legible on build 6. **Do not "improve" it without a new selection.**
- **X1 (147)** `EmberBackdrop` ticker guarded — **the `pumpAndSettle` trap is closed** · **X2 (148)** E9 annotated as superseded by E31.
- **W1 (146)** post-commit `recursiveDelete` on lobby close, sweep capped with the **scan** bounded · **W2 (145)** live deletion enabled; the dry run predicted the live run exactly.
- **V1 (143, 144)** deployed environment verified; **24-hour retention settled** with its `ROOM_TTL_MS` coupling invariant.
- **U1 (140)** manifest scoping + R6 · **U2 (141)** real `reduceMotion` bit, device-verified · **U3 (142)** 30 s heartbeat, host-gated disconnects · **U4 (135)** E49 PASS — **first device verification of Issue 123**.
- **S1 (139)** · **E47/E48** · **R0 (138)** · **R1 (136)** · **R2 (137)** · soak blocks **E22–E49** · **Wave Q** · **Wave P** · **Wave O's six** · **Issues 96–105, 50–95, 31, 28/29**.
- **The playthrough reorganisation** — everything under `docs/playthroughs/`.
- **The release runbook** — `README.md` → **Releasing**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206.** Bar is **206 and no new infos**.
- **Waves Y1 and Z1 both bumped `pubspec.yaml` inside their own commits** rather than at release time. Harmless and useful — the on-screen version matches what the next build reports.
- **`EmberBackdrop` and `AnimatedThinkingBackground` both keep `..repeat()` in `initState`.**
- **E48 merged two specified artefacts into one.**
- **`r0_u2_p3_reduce_motion.png` is logged under `block_id E49`.**
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 4. Invariants & intentional decisions — do NOT change

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

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and both at once (142 C); migrating `withOpacity` → `withValues` (139 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C); enabling deletion before fixing the leak (145 B); splitting `CLEANUP_DRY_RUN` into two flags (145 C); relying on the nightly sweep instead of fixing the orphan source (146 B); fixing the source while leaving the sweep uncapped (146 C); driving `EmberBackdrop`'s controller from `build` (147 B); accepting the unguarded ticker (147 C); re-running E9 (148 B); leaving its stale reason (148 C); treating unchecked `NOT RUN` citations as a review habit (149 B); forbidding artefact paths in `NOT RUN` blocks entirely (149 C); **enlarging or relocating the `PEEK INSIDE` affordance (150 A/B/C — closed, no change needed)**; generating the version from `pubspec.yaml` (151 B) and injecting it with `--dart-define` (151 C); **clearing `_isLeaving` from `build` (152 B) and scoping the guard to the dialog (152 C)**.

**Rejected in the September 8 selections — do NOT re-propose:** room codes drawn from a curated word list (153 B) and a segmented 4-box code input (153 C); capping the answer field with `maxLength` (154 B) and stating the limit in hint copy only (154 C); keeping the dealt-card overlay with a corrected label (155 B) or showing it once per match (155 C); `TextField.onTapOutside` (156 B) and a shared keyboard-dismiss wrapper across the lobby too (156 C); reordering the craft column so the field sits above the prompt (157 B) and moving writing into a modal sheet (157 C); a per-player rotation index (158 B) and an adaptive shortened barrier (158 C); a majority-of-voters threshold for the best-forgery banner (159 B) and replacing it with a full vote tally (159 C); a two-column portrait grid for vote options (160 B); confirming before locking the target's ready (161 B) and removing that button entirely (161 C); reviving P9 House Cards (163 B) and tightening timers or forgery counts per round (163 C); a manual button with no phase copy (164 B) and first-run coach marks (164 C); generic prompt-independent sentence stems (166 B) and extending re-roll to forgery rounds (166 C); hiding honors behind a tab (167 B); wrapping the highlight title to two lines (168 B) and auto-sizing it (168 C); itemising the manual copy only (169 B) and deferring the transcript to the game-over screen (169 C).

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 5. Where the contracts live

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

## 6. Validation standard

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
    Wave AA in section 2 is selected. Two carry gates: Issue 160 needs mockups
    before any code (AA15), and Issue 162's client half (AA16b) is blocked on
    160 landing -- its server half (AA16a) is not. 165 is deferred, and must
    stay open.
(2) If the spec says "determine X first", DO THAT AND RECORD THE RESULT
    BEFORE writing the fix. AA8 has one: what setReady(false) does after the
    gate has fired. Answer it with an emulator test, not by reasoning.
(3) Changing scoring? You must change BOTH functions/src/scoring_logic.ts AND
    the test-only mirror lib/utils/scoring_logic.dart, or the client suite
    stays green while computing different numbers from production. Three items
    touch scoring: AA10, AA11, AA16a.
(3b) Adding a callable? Copy castVote's authorization shape (index.ts:880):
    request.auth, then authUid on the player doc, then phase and card checks
    inside the transaction. playerId is NOT a credential.
(4) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body. A DELETION STILL NEEDS ONE (AA1).
(5) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(6) VALIDATE, including every named over-reach guard, then RE-RUN THE GUARD
    WITH THE FIX REMOVED and confirm it fails.
(7) State bugs: the test must NOT re-pump the widget between steps. AA6, AA8
    and AA16b all carry state on a State that outlives what it guards.
    Re-pumping builds a fresh State and passes against broken code -- that is
    how Issue 152 shipped.
(8) ENUMERATE EVERY INVOCATION of anything you changed and run them all.
    pendingScoreDeltas has THREE flush sites (AA11).
(9) RE-RUN THE FULL BATTERY -- exit codes bare, except flutter analyze,
    where the bar is 0 errors / 0 warnings and the code is always 1.
(10) SHIPPING? Follow README -> Releasing. Next build is 1.0.0+7. The CLI
     export failure is expected; distribute the .xcarchive from Organizer.
(11) COMMIT: one item, one Conventional Commit, WHY in the body. Move the
     issue into the SINGLE existing Resolved heading and update the relevant
     design doc. AA10 must ALSO amend section 4 of ongoing_general_errors.md,
     which currently says escalation was rejected.
```

**Do not invent work. Wave AA is the queue.**
