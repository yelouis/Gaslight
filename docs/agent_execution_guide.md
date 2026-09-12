# Agent Execution Guide — Wave AD: 3 cleanup items — September 12, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.**

**Wave AC is delivered and verified.** All five items (Issues 171–174 and the re-roll feature) work as specified, and their guards were re-falsified this session. **Wave AD is the cleanup that verification found** — three items, none of which needs a decision, each with exactly one correct fix.

**There are no open issues and nothing awaits a selection.** Do not invent work beyond AD1–AD3 and §5.1.

---

## 1. Verified baseline — measured this session on `76334b1`

Every number was run bare. **This is the regression bar.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 188 infos · exit 1** |
| `flutter test` | **346 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **157 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five** invocations | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH** |
| `test/web_e2e/*.js` | **DID NOT RUN.** Needs a web server and Chromium; it is in no gate script. **AD3 exists because of this.** |

**⚠️ Infos are now 188, down from 195.** The bar is **188 and no new infos**.

**⚠️ `flutter analyze lib test` exits 1 even when clean.** The bar is 0 errors / 0 warnings, never `exit 0`.

**⚠️ Read every exit code bare, never through a pipe.** `… | tail` reports `tail`'s status, always 0.

**⚠️ `pubspec.yaml` is at `1.0.0+7` and build 7 has NOT been uploaded.** TestFlight 5 and 6 are live; **6 carries the Issue 152 leave bug**, so once 7 ships, expire both. `flutter build ipa` fails at the *export* step here — expected. Verify the **archive**, never the `.ipa`. See `README.md` → Releasing.

---

## 2. AD1 — Delete the decoy `CONFIRM VOTE` widget and fix the assertion it was propping up

**What this means for the user.** Nothing visible. This removes an invisible widget that exists only to keep a test green, and restores that test's ability to catch a real regression.

**The gap.** `lib/screens/phase3_vote.dart:580–581`:

```dart
if (_localSelectedAuthorId == null)
  const SizedBox(width: 0, height: 0, child: Opacity(opacity: 0, child: Text('CONFIRM VOTE'))),
```

An invisible, zero-sized `CONFIRM VOTE` rendered **precisely when the visible button says `TAP A CARD TO CHOOSE`**. It was added during AC3 so that `test/phase3_vote_target_ready_toggle_test.dart:171` — `expect(find.text('CONFIRM VOTE'), findsOneWidget)` — kept passing after the rename.

**⚠️ Measured this session, not argued:** delete the entire `PrimaryButton` from that screen, leave the decoy, and `flutter test test/phase3_vote_target_ready_toggle_test.dart` reports **"All tests passed"**. **A guard written to prove the confirm button is present now passes with the confirm button deleted.** See lesson §2.43.

**Implementation.**

1. **Delete the decoy** — both lines, including the `if`.
2. **Fix the assertion it was propping up.** That test's own comment states its intent: *"As a voter on Card 2, Alice sees CONFIRM VOTE (not target ready buttons)"* — it is proving the player is on the **voter** path, not the target path. Replace `expect(find.text('CONFIRM VOTE'), findsOneWidget)` with an assertion on the label that is actually rendered in that state: **`expect(find.text('TAP A CARD TO CHOOSE'), findsOneWidget)`**. The two following lines already assert the target's controls are absent; **keep them** — together they are the real proof.
3. **Audit every other `find.text('CONFIRM VOTE')` for the same vacuity.** `test/phase3_vote_target_forgery_attribution_test.dart:557` and `test/vote_tap_cue_test.dart:127` both reference the string. **For each, determine whether it is reached with something selected** — if not, it was matching the decoy and must be repointed the same way. `test/phase3_vote_test.dart:802` asserts `findsNothing` on the *target* path where the decoy never rendered; it is sound and should be left alone.

**Do not** re-add a hidden widget, a `Semantics` label, a test-only key, or any other affordance whose sole consumer is a matcher.

**Validation.**

1. With the decoy deleted and the assertion fixed, the full suite is green at **346**.
2. **Falsification, and this is the point of the item:** delete the `PrimaryButton` again. `phase3_vote_target_ready_toggle_test.dart` must now **FAIL**. **If it still passes, another proxy is standing in for the button and you have not finished.**
3. **Over-reach guards, unedited:** all 5 in `test/vote_tap_cue_test.dart`, all 11 in `test/phase3_vote_test.dart`, all 4 in `test/stacked_deck_navigation_test.dart`.

---

## 3. AD2 — Write AC5's three missing validations

**What this means for the user.** Nothing visible. The deck top-up behaves correctly; nothing currently stops a future change from breaking it silently.

**The gap.** AC5 specified five tests. Two were written (`AC5.1`, `AC5.2`); **three were not.** The behaviour they cover is *currently correct* — `drawWithFallbackExcluding` (`functions/src/prompt_decks.ts:822`) tries the room deck first at `:834–835` and only reaches the fallback at `:838–839` when nothing unseen remains — **which is exactly why the tests matter: nothing marks that ordering as load-bearing.**

**Implementation — three tests in `functions/test/`, no production change.**

1. **AC5.3 — the terminal case.** A player whose history covers **both** the room deck and the fallback still receives a prompt and **does not throw**. This guards the never-refuses contract in `design_prompt_system.md` §5, which is what keeps a long match playable.
2. **AC5.4 — the over-reach guard, and the most important of the three.** While the room deck still has unseen prompts for this player, the fallback is **never consulted**. Assert the returned prompt is a member of the room's deck. **A top-up that fired eagerly would quietly drift every room onto `hypotheticals` and make the lobby's deck selection meaningless — and no existing test would notice.**
3. **AC5.5 — the rating property.** Assert `PromptDecks.getDeckRating(PromptDecks.getFallbackDeckId()) === "PG"`. Cheap, and it is the guard on a safety property: because the fallback is PG, a top-up can only make content **milder**, never more explicit, so a family-friendly room cannot be handed something stronger. **If a future deck is ever marked `isFallback` with a rating above PG that property inverts silently**, and this assertion is what stops it landing unnoticed.

**Validation.** Each of the three must be falsified: make the top-up eager and **AC5.4 must fail**; point `isFallback` at `rated_r_nsfw` in a scratch copy and **AC5.5 must fail**; give `drawOneExcluding` a throwing path and **AC5.3 must fail**. **A test you have not seen fail is a test you have not written.**

**Blast radius:** `docs/design_prompt_system.md` §5 — state that the top-up is exhaustion-only and that the fallback's PG rating is load-bearing.

---

## 4. AD3 — Re-point the web E2E scripts at the renamed button

**What this means for the user.** Nothing visible. It keeps the web playthrough scripts able to run, which is how the web evidence in `docs/playthroughs/findings_web.md` gets produced.

**The gap, and why nothing caught it.** AC3 renamed the vote screen's disabled button to `TAP A CARD TO CHOOSE`. **`test/web_e2e/*.js` is in no gate script** — it needs a web server and Chromium — so the battery has never exercised it. Two scripts match that area literally:

- `test/web_e2e/run_full_playthrough.js:53` picks a card with a filter that **excludes buttons containing `CONFIRM`**: `!n.text.includes('CONFIRM')`. The confirm button no longer contains that word, **so it is now a candidate for the "Card Select" click** — the script may click the disabled confirm button instead of a card, after which the `CONFIRM VOTE` click at `:55` finds nothing because nothing was selected.
- `run_match_summary_playthrough.js:82` and `:110` match `text === 'CONFIRM VOTE'` directly. These run **after** an option is selected, where the label has reverted, so they are expected to be sound — **confirm that rather than assuming it.**

**⚠️ State plainly whether this is a real break or only a latent one.** It depends on whether a disabled `PrimaryButton` is exposed with `role === 'button'` in the semantics tree and on traversal order. **Determine that first and record the answer**; do not "fix" a script that was never broken, and do not declare it fine without checking.

**Implementation.** Make the card-select filter select cards positively rather than by exclusion — match the option card's own text or its `OPTION` label — instead of relying on a blacklist of button words. **A filter defined by what it excludes breaks every time a label changes; one defined by what it includes does not.** Exclude `TAP A CARD TO CHOOSE` explicitly as well, so the immediate hazard is closed regardless.

**Validation.** Run the affected script end to end against a local web build and confirm a vote is cast on every card. **This is the one item in this wave whose validation is not a unit test**; if the script cannot be run in your environment, **say so explicitly and leave the item open rather than marking it done** — a "gate that did not run" recorded as passing is what created AD3 in the first place.

**Blast radius:** `docs/playthroughs/findings_web.md` is produced by these scripts; do not edit its existing blocks — evidence records an observation and is never retro-edited.

---
## 5. Already delivered — do NOT rework

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

### 5.1 Standing maintenance — alongside Wave AD, not instead of it

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

## 6. Invariants & intentional decisions — do NOT change

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

## 7. Where the contracts live

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

## 8. Validation standard

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
    Wave AD (sections 2-4) needs no selection: each item has one correct fix.
(2) A rename broke a test? UPDATE THE ASSERTION. Never move production code to
    satisfy a matcher, and never add a widget whose only consumer is a test --
    that is AD1 and lesson 2.43.
(3) Ask what input would make your check go red. If nothing would, it is not a
    check. AD1's falsification is exactly this: delete the button and the
    suite must fail.
(4) Read exit codes BARE. `... | tail` reports tail's status, always 0.
(5) A gate that did not run is not a pass. Say so in the baseline table --
    web_e2e has never been gated and that is how AD3 shipped unnoticed.
(6) COLOUR: check which SURFACE a token is for. onSurface is AppColors.ink,
    text on PARCHMENT; on the dark ground it is 1.12:1. Text on ground is
    ivory. Assert on the RENDERED tree, not a curated pair list (lesson 2.42).
(7) Changing scoring? Change BOTH functions/src/scoring_logic.ts AND the
    test-only mirror lib/utils/scoring_logic.dart, then re-run the sum
    invariant in both suites.
(8) Publishing anything derived from authorship? Only cards whose author flip
    has happened, at all THREE flush sites. Write the leak test first.
(9) Adding a callable? Copy castVote's authorization shape (index.ts:942).
    playerId is NOT a credential. Validate every client-supplied string
    against server state.
(10) Server bound first, client bound second. A client-side limit is a
     suggestion.
(11) State bugs: the test must NOT re-pump the widget between steps.
(12) Changing two things that write to the SAME number, document or screen
     region? Compute the COMBINED worst case as a table of real figures first.
(13) Playthroughs: evidence records an observation, not current behaviour.
     NEVER edit a verdict or a specified assertion. Annotate as superseded.
(14) RE-RUN THE FULL BATTERY -- bare, except flutter analyze, where the bar is
     0 errors / 0 warnings / 188 infos and the code is always 1.
(15) COMMIT: one item, one Conventional Commit, WHY in the body. Move the issue
     to the SINGLE existing Resolved heading, leave ONE line there, and put the
     durable consequence in the design doc.
```

**When AD1-AD3 are done the queue is empty. Do not invent work.**
