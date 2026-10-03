# Agent Execution Guide — Wave AH: 1 approved item — October 3, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.**

**Wave AG is delivered and verified.** Verification found one gap: AG1 doesn't do its main job on iOS. That gap is **AH1**, which has one correct fix and needs no selection.

**There are no open issues and nothing awaits a selection.** Do not invent work beyond AH1 and §3.1.

---

## 1. Verified baseline — measured this session on `bf8eb0f`

Every number was run bare. **This is the regression bar.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 188 infos · exit 1** |
| `flutter test` | **357 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **164 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five** invocations | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH** |
| `./scripts/check_web_e2e_strings.sh` | **exit 0** |

**Production:** `cleanupdaily` runs with **`CLEANUP_DRY_RUN=false`**, read back from revision `cleanupdaily-00018-2wm` after the AG3 deploy.

**⚠️ `flutter analyze lib test` exits 1 even when clean.** The bar is **0 errors / 0 warnings / 188 infos**, never `exit 0`.

**⚠️ Read every exit code bare, never through a pipe, and never through `timeout`, which macOS doesn't have.** **An empty result means nothing until the same command has been seen to return something** (lesson §2.44).

**⚠️ AH1 doesn't touch `functions/src/`.** Don't deploy functions, and don't touch `CLEANUP_DRY_RUN`.

---

## 2. AH1 — Make a dropped connection on iOS say so

**What this means for the user.** AG1 was meant to replace the stack trace from your September 27 report with *"Could not reach the parlour. Check your connection and try again."* On an iPhone with no connection, it actually shows *"Something went wrong. Try again."*, which explains nothing. After this, it shows the connection sentence.

**The gap.** `lobbyCallableErrorMessage` (`lib/screens/lobby_screen.dart:44`) sends `unavailable` and `deadline-exceeded` to the connection sentence. **On iOS, almost no connection failure arrives as either.** Traced through the vendored sources this session:

1. **firebase-ios-sdk 12.15.0**, `FirebaseFunctions/Sources/Functions.swift`, `processedError(fromResponseError:endpointURL:)`. It maps HTTP status errors, and **only** `NSURLErrorDomain` + `NSURLErrorTimedOut` to `FunctionsError(.deadlineExceeded)`. Every other transport failure — no internet (`-1009`), DNS failure (`-1003`), cannot connect (`-1004`), connection lost (`-1005`) — is returned as a **raw `NSError`**.
2. **cloud_functions 6.3.5**, `ios/…/FirebaseFunctionsPlugin.swift`, `createFlutterError(from:)`. It starts from `var errorCode = "unknown"` and maps only errors whose domain is `com.firebase.functions`, so a raw `NSURLErrorDomain` error **keeps `unknown`**.
3. **cloud_functions_platform_interface 6.0.5**, `lib/src/method_channel/utils/exception.dart`, `platformExceptionToFirebaseFunctionsException`. It sets `code = details['code']`, so Dart receives **`FirebaseFunctionsException(code: 'unknown')`**.

`unknown` falls to the default branch, so the likeliest cause of the September 27 report still reads *"Something went wrong."* **Re-check this chain yourself before changing anything** — it takes a few minutes. The SDK lives under `~/Library/Developer/Xcode/DerivedData/Runner-*/SourcePackages/checkouts/firebase-ios-sdk/`, and both Dart packages under `~/.pub-cache/hosted/pub.dev/`. **If a package version differs from the ones above, re-trace that hop and record what you find.**

### 2.1 Implementation

1. In `lobbyCallableErrorMessage`, add **`case 'unknown':`** to the branch that returns **`Could not reach the parlour. Check your connection and try again.`**, alongside `unavailable` and `deadline-exceeded`. **The same sentence for both create and join.**
2. **Put a comment above that case naming the three hops and versions** from §2. Without it, `unknown` looks like a catch-all someone parked in the wrong branch, and a later tidy-up will move it back to the default.
3. **Leave `internal` alone.** It stays on the generic sentence because `test/lobby_join_error_test.dart`'s over-reach guard 3 asserts *"unmapped code (internal) produces generic message"*, and that test must pass unedited.
4. **A non-`FirebaseFunctionsException` stays generic.** The new `case` only applies inside the `FirebaseFunctionsException` branch, so a plain `Exception` still gets *"Something went wrong."*
5. **This evidence covers iOS only.** It says nothing about web. Don't change any other code, and don't make claims about web in comments or the commit.

### 2.2 Validation

1. **Widget test**, added to `test/lobby_create_error_test.dart`: create throws `FirebaseFunctionsException(code: 'unknown', message: 'The Internet connection appears to be offline.')`. The SnackBar must read exactly the connection sentence, **and the message text must not appear on screen** — no raw text, no stack trace.
2. Same as 1 for **join**, in the same file.
3. **Over-reach guards, unedited:** all 4 tests in `test/lobby_join_error_test.dart` — **guard 3 especially**, which keeps `internal` generic — all 4 in `test/lobby_busy_state_test.dart`, and every existing test in `test/lobby_create_error_test.dart`, **including "plain Exception maps to generic sentence"**.
4. **Falsification:** remove `case 'unknown':`. Tests 1 and 2 must fail, and everything in 3 must still pass. **Record the failing output in the commit body.**
5. **⚠️ The device check is REQUIRED, and its outcome goes in the commit body either way.** On a physical iPhone running a **release** build, turn off Wi-Fi and cellular and tap **CREATE ROOM**. Record:
   - the sentence on screen,
   - the code `debugPrint` logged in the Xcode console.

   **The commit body must contain one of these lines, verbatim in shape:**
   - `Device check: DONE — sentence "<what showed>", code "<what was logged>"`
   - `Device check: NOT RUN — <reason>`

   **Leaving the line out isn't allowed.** AG1's commit left it out, which is lesson §2.45. If the device shows a code other than `unknown`, **don't widen the mapping to match. Report it**, since that means the vendored chain and the real device disagree, and that needs a decision.

**Blast radius:** `lib/screens/lobby_screen.dart`, `test/lobby_create_error_test.dart`, and §4's AG invariant in this guide, which already describes the post-AH1 state.

---

## 3. Already delivered — do NOT rework

### Wave AG — verified October 3, 2026

| Item | What shipped | How it was verified |
|---|---|---|
| **AG1** | `lobbyCallableErrorMessage(error, action:)` shared by create and join; no raw exception reaches a player anywhere in `lib/`. | Restoring `'Error: $e'` fails 5 create tests. Join and busy-state tests byte-identical. **Gap found — see AH1.** |
| **AG2** | Point chip headers in ivory, exact `Name: ±N` format kept; collapsed ternary removed. | Fails at 1.84 : 1 on the rendered ratio walk alone, independently of the pinned colour checks. |
| **AG3** (Issue 177 → B) | `ParlourLedger` on both waiting screens; one-line `thisCard` teaser on the reveal; additive `occurrences` + `thisCard` on the server. | 4 falsifications, all failing as they should. All 7 publish sites pass the values they write. Worst-case payload 18,013 bytes. `CLEANUP_DRY_RUN=false` survived the deploy. |


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

### 3.1 Standing maintenance — alongside AH1, not instead of it

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

**⚠️ Colour tokens name a SURFACE, not a role — and `colorScheme.primary` is `AppColors.oxblood`, not "positive".** It is 1.57 : 1 on a chip fill. Never use it for text on the dark ground; the September 27 chip defect (AG2) is this trap, as `onSurface` was Issue 171's. `colorScheme.onSurface` is `AppColors.ink` (`lib/main.dart:99`) — the near-black brown that `app_colors.dart:12` documents as **"Text on parchment"**. On the dark `ground` it measures **1.12 : 1** against a 4.5 : 1 floor and is effectively invisible; that is Issue 171. **Text on the dark ground is `AppColors.ivory`** (16.25 : 1), and `brass` (7.84 : 1) is for accents. **A passing `contrast_tokens_test.dart` does not cover you** — it checks five hand-curated pairs that are correct by construction, so it can never fail on a widget that reached for the wrong token (lesson §2.42).

**Wave AG invariant — user-facing errors (September 2026):**

- **Never render an exception object to a player** — not `'$e'`, not `e.toString()`, not `e.message`. `FirebaseException.toString()` appends the full stack trace, which is how a player ended up screenshotting `#0 _extractReplyValueOrThrow` with the useful line hidden under the status bar. Map `e.code` to a sentence; send the raw exception to `debugPrint` only.
- **Create and join share one mapping** (`lobbyCallableErrorMessage`, added in AG1). **On iOS a dropped connection reaches Dart as `unknown`, not `unavailable`** (firebase-ios-sdk 12.15.0 maps only `NSURLErrorTimedOut`; cloud_functions 6.3.5 codes every other native error `unknown`). After AH1, `unknown` belongs to the connection sentence — **don't move it back to the default branch.** The raw-trace defect was fixed in `_joinRoom` in an earlier wave and survived in its twin `_createRoom` for months. **A fix applied to one of two twins is half a fix.**

**Wave AE invariant — the web E2E string contract (September 2026):**

- **`test/web_e2e/*.js` may not contain a bare string literal in any `.text` or `.ariaLabel` comparison.** Every one must reference `UI.*` or `FIXTURE.*` from `test/web_e2e/ui_strings.js`, and `scripts/check_web_e2e_strings.sh` fails the battery otherwise. **`UI` is existence-checked against `lib/`; `FIXTURE` is script-supplied data and is not.** The containment half is what stops the map becoming a curated list that drifts from what is actually matched — **do not weaken it to "the map is the source of truth" by convention alone.**
- **`UI` entries must be ≥ 3 characters and contain a letter.** Shorter values match any file and pass vacuously; the gate rejects them outright rather than skipping them.
- **The existence check normalises `\'` → `'`** before searching, because Dart writes `'THE NIGHT\'S HONORS'`. Removing that normalisation produces false absences.

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

## 5. Where the contracts live

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
    AH1 needs none. Nothing else is work.
(2) "Implemented to spec" and "fixed the problem" are different claims. Check
    the second against the ORIGINAL REPORT, not the spec (lesson 2.45).
(3) If a fix depends on how a platform or library behaves, read the vendored
    source and verify it -- DerivedData/SourcePackages, ~/.pub-cache. Do not
    leave it as an open question for someone else.
(4) A load-bearing check is REQUIRED, and its outcome goes in the commit body
    either way: DONE with the result, or NOT RUN with the reason. Never omit it.
(5) An EMPTY result is not evidence until the same query has been seen to
    return something. Never pipe through `timeout` on macOS.
(6) zsh does not word-split unquoted variables. `for f in $FILES` sees ONE
    argument. Use `while IFS= read -r f` or an explicit list.
(7) A falsification that fails to COMPILE proves nothing. Inject a change
    that builds -- keep const contexts const, keep variables in use under
    noUnusedLocals -- and confirm the test ran before trusting its result.
(8) A fix applied to one of two twins is half a fix. Fix siblings through ONE
    shared path.
(9) A test is only as wide as what it walks. Walk the whole block the player
    sees, and assert you actually inspected the parts that matter.
(10) COLOUR: colorScheme tokens name a SURFACE, not a role. onSurface is ink;
     primary is oxblood. Text on the dark ground is ivory.
(11) Never show an exception object to a player. Map e.code to a sentence.
(12) A rename broke a test? UPDATE THE ASSERTION, never the production code.
(13) Server changes the shipped client reads must be ADDITIVE. Build 1.1.0 (8)
     is on testers' phones.
(14) Read exit codes BARE. `... | tail` reports tail's status, always 0.
(15) RE-RUN THE FULL BATTERY -- all EIGHT gates, bare, except flutter analyze,
     where the bar is 0 errors / 0 warnings / 188 infos and the code is 1.
(16) COMMIT: ONE ITEM, ONE Conventional Commit, WHY in the body.
```

**When AH1 is done the queue is empty. Do not invent work.**
