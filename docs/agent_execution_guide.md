# Agent Execution Guide — Wave AB: 3 approved items — September 11, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.**

Two selections were made in `docs/ongoing_general_errors.md` on September 11, 2026, and one standing task was added by the user. They are **AB1–AB3** below.

**Do only what is specified here.** A `(recommended)` label in the issue file is not approval; a filled `Your selection:` line is. **Never fill one in.**

**⚠️ Implement in order. AB3 must be last** — it photographs the UI, and AB2 changes the reveal screen. Capturing before AB2 lands would re-stale the reveal evidence the same day it was produced.

---

## 1. Verified baseline — measured on `6500457`

**This is the regression bar.** Every number was run bare this session.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 195 infos · exit 1** |
| `flutter test` | **326 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **139 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** — 5 decks, 918 lines |
| `./scripts/check_playthrough_evidence.sh` (all four invocations) | **exit 0** — 20 PASS, 1 NOT RUN, 0 FAIL |
| `./scripts/check_deploy_fresh.sh` | **exit 1 — STALE.** See §2.0. Not a regression. |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*. The bar is **0 errors / 0 warnings / 195 infos**, never `exit 0`. Use `lib test`, never bare `flutter analyze`.

**⚠️ Read every exit code bare, never through a pipe.** `flutter analyze … | tail` reports `tail`'s status, which is always 0. This trap was hit during the September 11 verification and caught only by re-running without the pipe.

---

## 2.0 Standing constraints — these apply to every item below

**⚠️ The functions are not deployed, and AB1 and AB2 both change them.** Production runs 17 functions and **`submitTargetForgeryGuesses` is absent entirely** — target forgery guessing does not work in production today. Deploy after AB1 and AB2 land, not between them:
```
firebase deploy --only functions
gcloud run services update cleanupdaily --update-env-vars CLEANUP_DRY_RUN=false
```
**Then read the flag back** — `CLEANUP_DRY_RUN` is revision-scoped and a deploy silently drops it. Then re-run `./scripts/check_deploy_fresh.sh` bare and confirm exit 0.

**⚠️ `lib/utils/scoring_logic.dart` is a TEST-ONLY mirror of `functions/src/scoring_logic.ts`.** Nothing in `lib/` calls it; it exists for `test/fake_functions.dart` and `test/scoring_logic_test.dart`. **Change scoring in one and not the other and the entire client suite stays green while computing different numbers from production.** AB1 and AB2 both touch scoring.

**⚠️ `sum(breakdown[player]) == scoreDeltas[player]` must hold for every player**, including the revenge ±1 and the round multiplier. Both suites assert it over four mirrored fixtures. Any scoring change re-runs those.

**⚠️ Authorship never reaches the client before the unmask window closes.** `sealed` is default-deny; `scoreDeltas` and `scoreBreakdown` are withheld and stashed in `pendingScoreDeltas` / `pendingScoreBreakdown` while `unmaskDeadline != null`; they flush at **three** sites — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`. **AB2 publishes data derived from authorship and is the highest-risk item in this wave for that reason.**

**One item = one commit.** Conventional Commit, WHY in the body.

---

## 3. AB1 — Issue 170 → Option B: exempt the target's forgery guesses from the round multiplier

**What this means for the user.** Today a target who reads the table well on a late round is paid twice over — once for being guessed correctly, once for guessing others, and both are multiplied by the round number. At seven players in round 3 one card can swing 33 points and decide the match on a single player's reading of five strangers' prose. After this change the guesses pay a flat, honest rate and only the older rules escalate.

**The gap.** `functions/src/scoring_logic.ts:153` adds `target_forger_guess` points into `deltas`, and `:179` then multiplies **the whole of `deltas`** by `Math.max(1, state.currentRound ?? 1)`. The guess points are therefore scaled along with everything else. `lib/utils/scoring_logic.dart:71` has the identical ordering.

**Implementation — a block move, in both files.**

1. **Move the entire target-forgery-guess block to *after* the multiplier block**, in `functions/src/scoring_logic.ts` and `lib/utils/scoring_logic.dart`. Nothing inside either block changes; only their order does.
2. That alone implements Option B, because the multiplier operates on `deltas` as it stands when it runs. Guess points added afterwards are never scaled.
3. **The sum invariant survives the move by construction**, and you should satisfy yourself of this before running anything: the multiplier writes `round_multiplier = base × (m − 1)` and sets `delta = base × m`, so `base + base×(m−1) = base×m`. Adding `guesses` to both `delta` and the breakdown afterwards keeps the two sides equal.
4. **Do not** introduce a second multiplier constant, a per-rule multiplier map, or an exclusion list. The ordering *is* the mechanism, and it is the smallest change that cannot drift.

**⚠️ Blast radius — two existing tests assert the behaviour you are removing.** Both are named for it:

- `functions/test/scoring_logic.spec.ts:327` — *"4. round multiplier scales target forgery guess points and satisfies sum invariant"*
- `test/scoring_logic_test.dart:364` — the identical Dart twin

**Rewrite both in this commit** to assert the new contract, and **keep the sum-invariant half of each** — that half is still true and still valuable. Say plainly in the commit body that you inverted a passing assertion and why. **Do not delete them and do not loosen them.**

**Validation.**

1. New assertion in both suites, mirrored: at `currentRound: 3`, a target holding `believable_target = 2` and **3** correct attributions scores **9**, not 15. Spell the arithmetic out in the test name so a later reader cannot mistake which contract it encodes: `2 × 3 + 3 = 9`.
2. The rewritten test #4 in both suites asserts guess points are **unmultiplied** and that `sum(breakdown) == delta` still holds.
3. **Over-reach guards, unedited:** Fixtures 1, 2, 3 in both suites (round 1, ×2 and ×3 with no guesses involved) — the multiplier itself is unchanged and must stay so. Plus the two legacy Issue 78 cases.
4. **Falsification:** move the block back above the multiplier. The new assertion in (1) must fail with **15** against an expected **9**, while Fixtures 1–3 still pass. **If Fixtures 1–3 fail too, you moved more than the guess block.**
5. Re-run the AA16a emulator tests in `functions/test/game_e2e.spec.ts` — the ones numbered 1, 2 and 6 exercise guess scoring end to end.

**Blast radius to update in the same commit:** `docs/design_scoring_and_ui.md` — its Issue 162 paragraph currently states *"Points participate in round multipliers (Issue 163)"*, which becomes false. Replace it with the exemption and the reason, and note the precedent: the unmask revenge ±1 is already exempt, so this makes the two "guess a person" rules consistent with each other rather than adding an exception.

---

## 4. AB2 — Issue 165 → scoped Option A + B: rivalries every reveal, and who reads whom

**⚠️ Read the selection before scoping this.** The user wrote:

> *"I think it is already different enough now but if needed lets proceed with Option A and B by showing and updating the rivalries each reveal and making it clear who knows who best."*

**Build exactly the clause after "by", and nothing else.** Options A and B as filed also proposed re-cutting the prompt decks toward personal history and a match-long trust economy. **Those are not selected and must not be built.** The scope is two things: *rivalries shown and updated at every reveal*, and *who knows who best made clear*. If you find yourself editing `prompt_decks.ts` or adding a currency, you have left the selection.

**What this means for the user.** The game already tracks who fools whom, but only shows it once, at the very end, in a block most players have stopped reading by then. The one fact that makes this game not Quiplash — *these are people who know each other* — is computed and then hidden. This surfaces it while it still changes how people play the next card.

**The gap.** `headToHead` is built in `buildMatchSummary` (`functions/src/index.ts:139–176`) from `sealed/_summary`, filtered to `count >= 2`, sliced to the top 3, and reaches the room document **only at game over**. `design_scoring_and_ui.md` records why: publishing the summary earlier *"would expose forgery authorship while the unmask window is still open and reopen Issues 99 and 100."* There is also no measure at all of the opposite direction — who *recognises* whom.

### 4.1 The safe window — get this right before writing anything

**A rivalry is authorship.** "Alice fooled Bob" means Alice wrote the forgery Bob voted for. Publishing that during an open unmask window hands every player still holding a revenge guess a narrowed answer.

**There is exactly one safe moment: the author flip.** Once a card's authorship is published, every rivalry on that card is already derivable by any client from the published `votes` and `sabotageAnswers`. A running tally that includes **only cards whose authorship is already public** therefore leaks nothing new.

**⚠️ `sealed/_summary` accumulates at the vote→reveal transition, which is BEFORE the unmask window closes.** A card sits in `_summary` while its authorship is still withheld. **Never publish straight from `_summary`** — that is the trap this whole section exists to name. The published set is `_summary`'s cards **minus any card whose authorship has not yet flipped**.

### 4.2 Server

1. **Extend `CardSummary`** (`functions/src/scoring_logic.ts`) with the reading direction:
   ```ts
   /** Forger ids this card's target correctly attributed. Issue 165. */
   targetCorrectAttributions?: string[];
   ```
   Populate it in the accumulation block at `functions/src/index.ts:1753` — it is computed from `sealedData.targetForgeryGuesses` against `answerAuthors`, both of which are already in scope there. **This is the same comparison AA16a's scoring already performs; do not re-derive it differently, and do not award points here** — AB2 adds no scoring.

2. **Publish a running list on the room document** as `runningRivalries`, written **in the same transaction as the author flip, at all three flush sites** (`advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`). Shape:
   ```ts
   runningRivalries: {
     fools: Array<{ deceiverId, deceiverName, victimId, victimName, count }>;
     reads: Array<{ readerId, readerName, forgerId, forgerName, count }>;
   }
   ```
   **`fools` reuses the existing pair-counting loop** at `index.ts:139–155` — factor it out rather than copying it, so the running list and the game-over `headToHead` cannot disagree.

3. **Thresholds differ from game over, deliberately.** `headToHead` uses `count >= 2` because by the end there is enough data for that to mean something. A running list at `count >= 2` shows **nothing at all** for most of a match, which defeats the point. **Use `count >= 1` and slice to the top 3 per direction.** Ties break by the same deterministic ordering the existing sort uses — count desc, then id, then id — so two clients never render different lists.

4. **Do not touch `buildMatchSummary`'s output.** Game over keeps its existing `headToHead` contract; `runningRivalries` is additive.

### 4.3 Client

5. **Reveal screen** (`lib/screens/phase4_reveal.dart`): render the rivalries after the author flip — the same beat that already reveals forgery authorship, i.e. gated on the card's authorship being public, never earlier. Place it near the existing `POINTS AWARDED THIS CARD` block.
6. **Copy, exact:** section heading `THE PARLOUR REMEMBERS`; a fools line reads `{deceiver} has fooled {victim} ×{count}`; a reads line reads `{reader} has read {forger} ×{count}`. **Copy is the one place in this item where a recorded substitution is acceptable** if a string does not fit at 320 pt — record it in the commit body rather than silently changing it.
7. **"Who knows who best"** is the superlative over `reads`: the pair with the highest count, labelled `CLOSEST READ`. When `reads` is empty — nobody has attributed anything correctly yet — **render nothing at all rather than an empty state**; an empty superlative on a screen this busy is noise.
8. **Game over** (`lib/screens/game_over_screen.dart`): the existing `RIVALRIES` block gains the reads direction alongside the fools it already shows.

### 4.4 Validation

1. **Leak test, and it is the one that matters.** With `unmaskDeadline` active on the current card, `room.runningRivalries` must contain **no pair drawn from that card**, while still containing pairs from previously flipped cards. Then close the window and assert the current card's pairs appear. **This mirrors AA16a's leak test — copy its structure.**
2. Emulator test per flush site — all three publish `runningRivalries`.
3. Emulator test: `targetCorrectAttributions` is populated from real guesses and is empty (not absent, not throwing) when the target guessed nothing.
4. Emulator test: thresholds — a pair with `count == 1` **appears** in `runningRivalries` and **does not** appear in game-over `headToHead`. This is the one place the two lists legitimately differ; assert it so nobody "fixes" the running list to match.
5. `functions/test/rules.spec.ts`: `sealed/{cardId}` and `sealed/_summary` remain unreadable by clients. **A new public field is exactly when that guarantee gets eroded by accident.**
6. Widget test: the reveal renders nothing before the flip and the rivalries after it.
7. Widget test at 320 pt with three fools and three reads: no overflow. The reveal screen is already dense — see Issue 160.
8. **Over-reach guards, unedited:** all 7 tests in `test/phase4_reveal_test.dart`, all 10 in `test/game_over_screen_test.dart`, and the AA11 sum invariant in both suites. **AB2 awards no points; if any scoring test moves, you have added a scoring rule you were not asked for.**
9. **Falsification:** publish the current card's pairs while its window is open. Test 1 must fail. Then remove the `count >= 1` threshold override so the running list uses `>= 2`; test 4 must fail.

**Blast radius:** `docs/design_scoring_and_ui.md` (the running-vs-final distinction and why the thresholds differ), `docs/design_database_and_security.md` (the new public room field and the rule that it only ever carries flipped cards), `docs/design_ui_direction.md` (the reveal and game-over placement).

---
## 5. AB3 — Re-capture the playthrough evidence with Marionette

**⚠️ Do this LAST.** AB2 changes the reveal screen. Capturing before it lands means re-shooting the reveal the same week.

**What this means for the user.** There are 104 screenshots in `docs/playthroughs/evidence/` and almost every in-game one now shows a screen that no longer exists — a modal that was deleted, a scrolling option list that became a card deck, a game-over page under a heading that was renamed. Anyone opening that folder to check how the game behaves is looking at a different game.

### 5.1 The rule that governs this whole item

**⚠️ Evidence is a record of an observation at a point in time. You do not retro-edit it to match new code.**

Those screenshots are not stale documentation; they are a true record of builds that existed. **Do not overwrite an artefact, do not rewrite a findings block to describe the new UI, and above all do not change a block's `**Verdict:**` or its `**Specified assertion:**`** — rule R6 checks both verbatim against `docs/playthroughs/manifest.md` and will fail the gate.

**The precedent is Issue 148 (Wave X2)**, which annotated block E9's obsolete blocker as superseded, pointed it at newer evidence, and left `Verdict: NOT RUN` untouched. Follow that shape exactly:

- **Capture a new report.** `docs/playthroughs/findings_waveAA.md`, new block ids starting at **E50** (E49 is the highest in use).
- **Annotate superseded blocks in place** in the old reports with a single line naming the block that supersedes them. Titles, verdicts and assertions stay byte-identical.
- **New artefacts get new filenames.** Never reuse an existing one.

### 5.2 Marionette mechanics

**⚠️ Marionette only attaches to a debug build.** `MarionetteBinding.ensureInitialized()` sits behind `if (kDebugMode)` at `lib/main.dart:40`. Two consequences, both of which you must state in the new report's preamble rather than leave a later reader to discover:

1. **The seven `DEBUG:` buttons are visible in every screenshot.** That is correct and gated behaviour, not a regression — see the invariants in §7. The only release-build evidence in this repo (`e11_release_lobby.png`) was captured by hand for exactly this reason.
2. **Anything gated on `!kDebugMode` cannot be observed this way at all.** Do not claim it was.

**Bring up the devices.** Launch one debug build per player on its own simulator and note each VM service URI that `flutter run` prints:
```bash
flutter run -d <simulator-id>
```
Then connect one Marionette server per device — `mcp__marionette-p1__connect` … `mcp__marionette-p5__connect` — passing that device's URI. **P1 is the host throughout**; keeping that stable is what makes the report readable.

**The tools you will need, and what each is for:**

| Tool | Use |
|---|---|
| `get_interactive_elements` | **This is your `Observed:` field.** It yields the verbatim `Type: Text, Text: "…"` lines the existing blocks quote. |
| `take_screenshots` | The artefact. One per claim. |
| `tap` / `enter_text` | Driving the match. |
| `swipe` | **New and required** — the vote options are a stacked deck now (Issue 160); PREV/NEXT and jump dots are also tappable. |
| `scroll_to` | Reaching the game-over standings and highlights. |
| `get_logs` | Diagnosing a stuck device. Never evidence. |

**⚠️ Elements are matched by `ValueKey` or text.** Wave AA added keys you can rely on — `answer_field`, `answer_character_counter`, `room_code_field`, `stacked_deck_prev_button`, `game_over_bottom_bar`. If a widget cannot be located, **add a `ValueKey` to the source in a separate commit** rather than tapping blind coordinates.

### 5.3 Two matches, and why it must be two

**Match A — five players (P1–P5).** Gives 5 options on a card, enough forgeries for the stacked deck to matter, and enough pairs for AB2's rivalries to populate.

**Match B — three players (P1–P3).** **Required, and not substitutable.** AA9 suppresses the best-forgery banner unless a single author has ≥ 2 votes. At three players only two people vote on any card and neither can vote for their own answer, so **a forgery can never exceed one vote and the banner must never appear.** That is the whole point of Issue 159 and it is unobservable at five players. A five-player match proves nothing about it.

### 5.4 The blocks to capture

Each is one block in `findings_waveAA.md`, in the existing format: `**Verdict:**` · `**Devices:**` · `**Room Code:**` · `**What I did:**` · `**Observed:**` · `**Reference:**` · `**Expected:**`.

| Block | Match | Must depict |
|---|---|---|
| **E50** | A | Craft screen on first paint after a phase change, **with no modal over it** — the answer field is immediately usable. Supersedes any block showing `THE RECORD OF TRUTH` / `DECK OF FORGERIES`. |
| **E51** | A | The live character counter reading a value, and reading it in the error colour past 100. Two shots. |
| **E52** | A | A sentence stem rendered beneath the field **with the answer field still empty** — the stem is never pre-filled. |
| **E53** | A | The craft waiting screen showing this player's own submitted answer and its prompt. |
| **E54** | A | The answer field visible **above** the on-screen keyboard while typing. |
| **E55** | A | The vote screen as a stacked deck: active card in front, next peeking behind, `PREV`/`NEXT` and jump dots present. Then a second shot **after a right-swipe**, showing an earlier card back in front — backward navigation was the user's explicit requirement. |
| **E56** | A | The target's attribution chip row on a forgery, one author chip selected; plus a shot of the target's own truth showing **no** attribution affordance. |
| **E57** | A | The target's ready control reading `NOT READY` after being tapped once — the toggle, not the old one-way latch. |
| **E58** | A | The reveal screen's itemised score breakdown, showing named rule lines **and** the player totals still visible. |
| **E59** | A | **AB2's rivalries block on the reveal**, present after the author flip. Plus a shot of the same screen during an open unmask window showing it **absent**. |
| **E60** | A | Game over: `FINAL RESULTS` heading with standings **above** the honors. |
| **E61** | A | A match-highlight card with `BEST LIE OF THE NIGHT` fully legible and its badge on a separate line. |
| **E62** | A | The manual affordance in the in-game AppBar, and the manual open over a phase screen. |
| **E63** | **B** | A three-player reveal where a forgery drew one vote and **no best-forgery banner is shown.** Capture the vote tally in the same frame if possible, so the absence is evidently correct rather than merely absent. |

**E63 is the only block here that proves something by absence**, so its `Artefact depicts:` must say what should have been there and was not.

### 5.5 Gate compliance — read this before writing a single block

The evidence gate is mechanical and will reject sloppy blocks. Run it bare: `./scripts/check_playthrough_evidence.sh docs/playthroughs/findings_waveAA.md`.

- **R2** — every PASS/FAIL block needs a non-empty `**Observed:**`.
- **R3** — a PASS block's `Observed:` must cite at least one PNG under `docs/playthroughs/evidence/`.
- **R4** — `Observed:` must not contain `grep -`. **A grep is not an observation** (lesson §2.20): it proves a string exists in source, not that it rendered on a device. Quote `get_interactive_elements` output instead.
- **R5** — every cited PNG must exist on disk. Check your filenames against the directory before committing.
- **R6** — every new block needs a row in `docs/playthroughs/manifest.md` whose **Report**, **Block**, **Title** and **Specified assertion** match the block verbatim. Columns are `| Report | Block | Title | Specified assertion | Artefact must depict |`.

**Also append one row per artefact to `docs/playthroughs/evidence/ARTEFACTS.tsv`** — columns `block_id`, `filename`, `device`, `captured_utc`, `depicts`. `captured_utc` is the real capture time, not the commit time.

**⚠️ Open every screenshot you cite and ask what it actually shows** before writing the `depicts` text. This is a standing rule and it has caught a real error before: Issue 148 found a block citing `e31_p1_forgery_relinked.png`, a file that never existed, and Wave X2 found another whose cited screenshot was the app's launch screen rather than the claimed phase. **A filename that sounds right is not evidence.**

### 5.6 Validation

1. All **five** gate invocations exit 0 bare — no-arg, `findings_marionette.md`, `findings_web.md`, `findings_5player.md`, and the new `findings_waveAA.md`.
2. **Falsify R5 on the new report:** delete one cited PNG, confirm exit 1 naming it, restore, confirm exit 0. A gate that has never failed on your report is a gate you have not tested.
3. **Falsify R6 on the new report:** alter one manifest assertion by a word, confirm exit 1, restore.
4. Confirm the old reports still tally exactly as before — `findings_marionette.md` at **20 PASS, 1 NOT RUN, 0 FAIL**. **If that number moved you edited a verdict**, which this item forbids.
5. Every artefact cited in the new report exists, and every artefact added to `evidence/` is cited by some block. **An uncited screenshot is either a missing claim or a file that should not have been committed.**

**Blast radius:** `docs/playthroughs/manifest.md`, `docs/playthroughs/evidence/ARTEFACTS.tsv`, superseding annotations in the older reports, and `docs/ongoing_general_errors.md` §5 if the new report needs a pointer.

---
## 6. Already delivered — do NOT rework

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

### 6.1 Standing maintenance — alongside Wave AB, not instead of it

1. **⚠️ Deploy the functions, then restore the cleanup flag — but see §2.0: do it AFTER AB1 and AB2 land, not now.** `functions/src` changed under AA10, AA11 and AA16a, and **`submitTargetForgeryGuesses` is not deployed at all** — production runs 17 functions and the new callable is absent. **Target forgery guessing does not work in production today, and a client build shipped before this deploy would call a function that is not there.**
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

## 7. Invariants & intentional decisions — do NOT change

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

**Wave AB invariants (September 2026):**

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

## 8. Where the contracts live

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

## 9. Validation standard

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
    Wave AB (sections 3-5) is selected. Nothing else is.
(2) ORDER IS LOAD-BEARING: AB1, then AB2, then AB3. AB3 photographs the UI and
    AB2 changes the reveal screen.
(3) Read exit codes BARE. `flutter analyze ... | tail` reports tail's status,
    which is always 0.
(4) Changing scoring? Change BOTH functions/src/scoring_logic.ts AND the
    test-only mirror lib/utils/scoring_logic.dart, then re-run the sum
    invariant in both suites. AB1 and AB2 both qualify.
(5) Publishing anything derived from authorship? It may only carry cards whose
    author flip has already happened, and it must ride the SAME transaction at
    all THREE flush sites. Write the leak test first (AB2 validation 1).
(6) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the exact
    output in the commit body. A DELETION STILL NEEDS ONE.
(7) Inverting an existing passing assertion? Allowed when the contract genuinely
    changed -- AB1 does this to two tests -- but say so explicitly in the commit
    body and keep whatever half of the test is still true.
(8) State bugs: the test must NOT re-pump the widget between steps. Re-pumping
    builds a fresh State and passes against broken code.
(9) Changing two things that write to the SAME number, document or screen
    region? Compute the COMBINED worst case as a table of real figures before
    calling it done -- lesson 2.41 is why Issue 170 exists.
(10) Playthroughs: evidence records an observation, not current behaviour.
     NEVER edit a verdict or a specified assertion. Annotate as superseded and
     capture a NEW block. Open every screenshot and ask what it SHOWS.
(11) RE-RUN THE FULL BATTERY -- bare, except flutter analyze, where the bar is
     0 errors / 0 warnings / 195 infos and the code is always 1.
(12) DEPLOY after AB1 and AB2: firebase deploy --only functions, then re-apply
     CLEANUP_DRY_RUN=false and READ IT BACK. Revision-scoped.
(13) COMMIT: one item, one Conventional Commit, WHY in the body. Move the issue
     to the SINGLE existing Resolved heading, leave ONE line there, and put the
     durable consequence in the design doc.
```

**When AB1-AB3 are done the queue is empty again. Do not invent work.**
