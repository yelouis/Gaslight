# Agent Execution Guide — Wave AF: 1 approved item (a release) — September 12, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.**

Issue 176 was selected on September 12, 2026 (**Option A**) and is specced as **AF1**. It is the only approved work.

**⚠️ AF1 is a release, not a code change.** Exactly **one line** of the repository changes. Everything else is procedure and verification. **If you find yourself editing a test, a screen or a plist, stop — you have left the item.**

---

## 1. Verified baseline — measured on `4a6aee7`

**This is the regression bar.** Every number was run bare. **All eight gates must be green before AF1 ships.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 188 infos · exit 1** |
| `flutter test` | **346 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **157 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five** invocations | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH** |
| `./scripts/check_web_e2e_strings.sh` | **exit 0** — 32 UI strings, 3 scripts containment-clean |

**⚠️ `flutter analyze lib test` exits 1 even when clean.** The bar is **0 errors / 0 warnings / 188 infos**, never `exit 0`. Use `lib test`, never bare `flutter analyze`.

**⚠️ Read every exit code bare, never through a pipe.** `… | tail` reports `tail`'s status, always 0.

---

## 2. AF1 — Issue 176 → Option A: ship as `1.1.0+8`

**What this means for the user.** Five waves of work — the re-worked craft screen, stacked-deck voting, target forgery guessing, running rivalries, the score transcript, sample answers, the re-roll cap — are currently queued to ship under `1.0.0+7`, a build number allocated to Wave Z's single leave-button fix. After this they ship as **`1.1.0 (8)`**, and the title-screen label tells a tester they are holding a genuinely different app.

### 2.1 The only code change

`pubspec.yaml`: `version: 1.0.0+7` → **`version: 1.1.0+8`**.

**That is the entire diff to the application.** Two things make it sufficient, and both were verified this session:

- **iOS needs no plist edit.** `ios/Runner/Info.plist` sets `CFBundleShortVersionString` to `$(FLUTTER_BUILD_NAME)` and `CFBundleVersion` to `$(FLUTTER_BUILD_NUMBER)`, both fed from `pubspec.yaml` at build time.
- **The title-screen label needs no code change.** It reads the *running bundle* via `PackageInfo.fromPlatform()` in `initAppVersion()`, which is the whole point of Issue 151 — it reports what is installed, not what the source claimed. It will read `v1.1.0 (8)` with no further work.

### 2.2 ⚠️ The one test you must not touch

`test/lobby_version_test.dart` contains `version: '1.0.0'` and `expect(find.text('v1.0.0 (6)'), findsOneWidget)`. **Leave both exactly as they are.**

Those values come from `PackageInfo.setMockInitialValues(...)` — the test **mocks** the bundle and asserts the *formatting* (`v{version} ({buildNumber})`), deliberately independent of whatever the app is actually versioned at. **Updating them to `1.1.0`/`8` would couple the test to the shipped version and guarantee churn on every future bump, for no gain.** A test that must be edited to stay green is a test that has stopped being a check.

**`flutter test` must still report 346 after the bump.** Any movement means something was edited that should not have been.

### 2.3 ⚠️ Delete two stale artefacts before building

Both exist on disk right now and both will mislead verification:

| Path | Contents | Why it is dangerous |
|---|---|---|
| `build/ios/archive/Runner.xcarchive` | dated **2026-09-07 21:21**, `CFBundleShortVersionString` **1.0.0**, `CFBundleVersion` **6** | It is the *build 6* archive. If the new build fails, this is what an inattentive check finds — and it reports a plausible-looking version. |
| `build/ios/ipa/gaslight.ipa` | dated **2026-08-25 19:16** | Eighteen days old, from the build-2 era. **`flutter build ipa` will not overwrite it**, because the export step fails on this machine. |

**Delete both first.** After that, anything present under `build/ios/` was produced by your run, and the timestamp check in §2.5 cannot be satisfied by an old file.

### 2.4 Build

Run the **full eight-gate preflight** from §1 first — a release is the one moment the whole battery has to be green simultaneously.

```bash
flutter build ipa
```

**⚠️ This will end in an error and that is expected, not a failure.** The *export* step fails with `No Accounts` / `No signing certificate "iOS Distribution" found` because this machine has **no Apple Distribution certificate**. **The `.xcarchive` is still produced**, and Organizer distributes it. Do not "fix" the signing configuration.

### 2.5 Verify the ARCHIVE, never the `.ipa`

```bash
stat -f "%Sm" -t "%Y-%m-%d %H:%M" build/ios/archive/Runner.xcarchive
/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" build/ios/archive/Runner.xcarchive/Info.plist
/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" build/ios/archive/Runner.xcarchive/Info.plist
```

**All three must hold: the timestamp is from your run, the short version is `1.1.0`, and the build version is `8`.** If any is wrong, the archive is not yours — go back to §2.3. **This is the check that has caught a stale archive before**, when one predated the fix it was supposed to contain by 27 minutes.

### 2.6 Distribute and confirm

1. `open build/ios/archive/Runner.xcarchive` → Organizer → **Distribute App** → **App Store Connect** → **Upload**.
2. TestFlight: add build **8** to the **ME** and **FR** groups.
3. **Expire builds 5 and 6.** Build 6 carries the Issue 152 leave bug and this has been pending since Wave Z. Build 7 never existed as an upload, so there is nothing to expire there.
4. **Confirm on device: the title screen reads `v1.1.0 (8)` beneath `READ MANUAL`.** This is the acceptance test for the whole item — everything else is plumbing.

### 2.7 Web, and what does NOT need doing

**Deploy hosting.** The web app serves the same client code and is equally far behind:

```bash
flutter build web --release
npx firebase-tools deploy --only hosting
```

Heed `README.md` §1's warnings — `.env` is a declared asset and must hold real keys with `USE_EMULATOR` not true, because it is baked in at build time.

**⚠️ Do NOT deploy functions, and do NOT re-apply `CLEANUP_DRY_RUN`.** `check_deploy_fresh.sh` is **exit 0 — FRESH**, and AF1 changes no file under `functions/src/`. The flag is revision-scoped, so it only needs re-applying *after a functions deploy*; touching it without one is unnecessary risk on a live service. **The runbook's conditional is "if touched" — and nothing is touched.**

### 2.8 Fix the runbook while you are in it

`README.md` → Releasing has drifted and a release is exactly when someone follows it:

- **§0 Preflight lists seven commands and there are now eight gates** — `./scripts/check_web_e2e_strings.sh` is missing.
- **The note says infos are "~206"; the bar is 188.** It already says the guide's §1 is the source of truth, so make the number agree rather than adding a second one to maintain.

### 2.9 Validation

1. `git diff` after the bump touches **exactly one line in one file**.
2. All **eight** gates green, read bare. **`flutter test` still reports 346** — see §2.2.
3. The archive's timestamp, `1.1.0` and `8` all verified per §2.5, with the output recorded in the commit body.
4. **On-device: `v1.1.0 (8)`.** Record it; a screenshot is ideal, and if you take one, **commit it** — a validation that leaves no artefact is a claim (lesson §2.36).
5. **Over-reach guard:** `git status` shows no modification under `lib/`, `functions/`, `test/` or `ios/` beyond the README and `pubspec.yaml`.
6. **Falsification is not available for a release**, and saying so is better than inventing one. **What replaces it is §2.5's three assertions** — they are the reason a wrong archive cannot be shipped silently. **If you cannot run a step (no Xcode, no Apple ID), say so plainly and leave the item open rather than reporting it done.**

**Blast radius:** `pubspec.yaml`, `README.md` → Releasing, this guide's §1, and `docs/ongoing_general_errors.md` when the item resolves.

---
## 3. Already delivered — do NOT rework

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

### 3.1 Standing maintenance — alongside AF1, not instead of it

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

**⚠️ Colour tokens name a SURFACE, not a role.** `colorScheme.onSurface` is `AppColors.ink` (`lib/main.dart:99`) — the near-black brown that `app_colors.dart:12` documents as **"Text on parchment"**. On the dark `ground` it measures **1.12 : 1** against a 4.5 : 1 floor and is effectively invisible; that is Issue 171. **Text on the dark ground is `AppColors.ivory`** (16.25 : 1), and `brass` (7.84 : 1) is for accents. **A passing `contrast_tokens_test.dart` does not cover you** — it checks five hand-curated pairs that are correct by construction, so it can never fail on a widget that reached for the wrong token (lesson §2.42).

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
    AF1 (section 2) is the only approved work. It is a RELEASE: exactly one
    line of the app changes.
(2) AF1 specifically: do NOT edit test/lobby_version_test.dart. Its 1.0.0 / 6
    values are a MOCK asserting the label's FORMAT. flutter test must still
    report 346 after the bump.
(3) AF1 specifically: delete the stale archive (2026-09-07, build 6) and the
    stale ipa (2026-08-25) BEFORE building, then verify the ARCHIVE's
    timestamp, 1.1.0 and 8. Never verify the .ipa.
(4) Deploy functions ONLY if functions/src changed. AF1 does not touch it, so
    do not deploy and do not re-apply CLEANUP_DRY_RUN. The flag is
    revision-scoped -- it needs re-applying after a deploy, not instead of one.
(5) A gate must be able to FAIL. Ask what input would make yours go red; if
    nothing would, it is not a gate. Record the failing run, not just the pass.
(6) Using a search to prove ABSENCE? It must not encode an incidental
    convention -- quoting, escaping, variable naming. And do not read a
    truncated listing as a complete one: `ls | head -3` hid a stale archive
    from this very verification pass (lesson 2.44).
(7) A check over a hand-written list can only verify the list. Add the
    containment half that makes drift impossible (lesson 2.42).
(8) A rename broke a test? UPDATE THE ASSERTION. Never move production code to
    satisfy a matcher (lesson 2.43).
(9) Never silence a failing check by deleting what it flagged unless the
    flagged thing is genuinely dead. A dead ALTERNATE in an OR with live
    siblings is deleted; a SOLE matcher for a live affordance is repointed.
(10) Read exit codes BARE. `... | tail` reports tail's status, always 0.
(11) A gate that did not run is not a pass, and one you ran that left no
     artefact is a claim. If a validation writes files, COMMIT THEM. If you
     cannot run a step, say so and leave the item OPEN.
(12) COLOUR: onSurface is AppColors.ink, text on PARCHMENT; on the dark ground
     it is 1.12:1. Text on ground is ivory. Assert on the RENDERED tree.
(13) Changing scoring? Change BOTH implementations and re-run the sum
     invariant in both suites.
(14) Publishing anything derived from authorship? Only cards whose author flip
     has happened, at all THREE flush sites. Write the leak test first.
(15) State bugs: the test must NOT re-pump the widget between steps.
(16) Playthroughs: evidence records an observation, not current behaviour.
     NEVER edit a verdict or a specified assertion.
(17) RE-RUN THE FULL BATTERY -- all EIGHT gates, bare, except flutter analyze,
     where the bar is 0 errors / 0 warnings / 188 infos and the code is 1.
(18) COMMIT: ONE ITEM, ONE Conventional Commit, WHY in the body. Move the issue
     to the SINGLE existing Resolved heading, leave ONE line there.
```

**When AF1 is done the queue is empty. Do not invent work.**
