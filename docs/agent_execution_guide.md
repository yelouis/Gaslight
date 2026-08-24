# Agent Execution Guide — Active Build: Wave K — Game Over Payoff — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Both selections are made. Build exactly these:**

| # | Item | Issue & choice | Touches | Deploy |
|---|---|---|---|---|
| **K1** | Final standings + a server-written match summary that quotes real answers | **111 → Option C** | `functions/src/index.ts`, `lib/models/game_state.dart`, `lib/screens/game_over_screen.dart` | **functions** |
| **K2** | Case File downloads on web instead of refusing | **110 → Option B** | `lib/screens/game_over_screen.dart`, `lib/utils/`, `pubspec.yaml` | — |

**Order is K1 → K2.** Both edit `game_over_screen.dart`, and K1 changes what is *on* that screen — which is exactly what K2's Case File image captures. Doing K2 first means re-shooting its evidence.

**Do not run `firebase deploy`.** K1 is inert until deployed; that call is the user's.

## Verified baseline — the regression bar

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (21 warnings, 197 infos) | `flutter analyze lib test` |
| Client tests | **179/179** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **68/68** | `npm --prefix functions test` |
| Deploy freshness | **exit 1 — expected**, undeployed server commits already exist | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 19 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

---

## 0. The two facts that decide this wave — verified in source, do not re-derive

**Player counters survive the whole match.** `totalScore`, `timesFooled` and `playersDeceived` are applied as deltas inside the reveal transaction (`functions/src/index.ts:1317–1340`) and are zeroed only at player creation and game reset. **Standings and any counter-derived award need no backend at all.**

**No answer text survives.** Single-card reveal scoping blanks every non-current card on the room document, and the round advance additionally resets each `sealed/{playerId}` doc plus `votes` and `unmaskGuesses` (`:1587`, `:1595`). **By game over the match's answers exist nowhere.** Do not try to read `room.cards` at game over to find a best lie — those cards are blank by then. This is the entire reason Option C exists.

---

## 1. Standing constraints

- **One item = one commit.** Two items, two commits.
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **A mechanical check must assert it matched something.**
- **A `grep` is not an observation.** Neither is prose describing source.
- **Open the artefact.** A screenshot path satisfies the evidence gate; it does not prove the screenshot shows what the block claims (lesson 2.25 — that is how Issue 110 was found).
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects you find** with Pros/Cons and a blank selection line, per `.agents/skills/bug_documentation_guidelines/SKILL.md`. Do not fix them inline.
- **Do not touch anything in §6 or §7.**

---

## 2. K1 — Standings + match summary (Issue 111, Option C)

### 2.1 The cheap half: the standings table

`game_over_screen.dart:147` **already computes** `sortedByScore`, and then uses only `.first` and a runner-up. Render the whole thing: rank, player, score, and a per-row `fooled X · fooled by Y` from `playersDeceived` / `timesFooled`.

**This is the actual complaint.** A change that adds glamorous awards but still hides the table has not fixed the issue. Do this part first, and make it work with **no** summary present — a match that ends before any card resolves must still show standings.

### 2.2 Where the summary is accumulated, and why exactly there

Inside the reveal transaction, at roughly `index.ts:1305–1326`, three things are simultaneously in scope and exist **nowhere else, ever again**:

- `cardWithAnswers.truthAnswer` and `cardWithAnswers.sabotageAnswers` (authorId → forgery text), rehydrated from `sealed`
- `resolvedVotes` — voterId → the **authorId** they voted for, already resolved from opaque option ids
- `card.targetPlayerId`, `card.promptText`

Build one entry per resolved card there. For each forgery author, its `fooled` count is the number of `resolvedVotes` entries pointing at that author. Voters whose vote equals `targetPlayerId` found the truth.

```ts
interface CardSummary {
  round: number;
  targetPlayerId: string;
  promptText: string;        // truncate, see 2.4
  truthAnswer: string;       // truncate
  forgeries: { authorId: string; text: string; fooled: number }[];
  truthFinders: string[];    // voterIds who picked the truth
}
```

**Do not add a second traversal.** The loop that computes `timesFooledDeltas` is already walking `resolvedVotes`; the counts you need come out of that same pass.

### 2.3 Where it is stored — and the security constraint that is not optional

Accumulate into **`sealed/_summary`**. The `sealed` subcollection has **no `match` block in `firestore.rules`** and is therefore default-deny: clients cannot read it at all. That is the property you are relying on.

**It must not reach the world-readable room document before game over.** Publishing forgery authorship mid-match reopens Issues 99 and 100 — the reveal deliberately withholds who wrote which forgery until the unmask deadline passes. A summary leaked early hands players the answer to the game they are still playing.

**Firestore transactions require every read before any write.** The reveal transaction already performs reads; add the `sealed/_summary` read **in that read phase**, not next to the write. Getting this wrong throws at runtime, not at compile time.

### 2.4 Bounding the size

The room document is world-readable and has a 1 MiB ceiling.

- **Truncate** `promptText` and every answer to the existing 100-character answer bound (`kMaxAnswerLength`; prompts can be longer than answers, so truncate both).
- **Cap** the accumulated entries — 60 cards is far beyond any real match (5 rounds × 10 players) and is a hard stop rather than a guess.
- **Publish awards, not the raw log.** At game over, compute the awards server-side and write a compact `matchSummary` to the room. That keeps the published object a fixed size no matter how long the match ran, and means the client never receives per-card material it has no use for.

Awards to compute: **Best Lie of the Night** (forgery text + author + fooled count), **Cleanest Truth** (the truth the fewest players found), **The Sting** (the card with the most wrong votes), and a small **head-to-head** list ("Alice fooled Bob three times"). Ties: pick deterministically — highest count, then earliest round, then lowest `targetPlayerId` — so two runs of the same match agree.

### 2.5 Publish at ALL THREE game-over transitions

`grep -n 'currentPhase: "gameOver"' functions/src/index.ts` returns **three** sites:

- `:1081` and `:1089` — inside `handleDisconnect`, when the table drops below three players
- `:1617` — inside `advanceToNextResolution`, the normal end of the final round

**All three must publish the summary.** The disconnect path is the one that will be missed, and a match that ends because someone left is exactly when players most want to see where they finished. If a game ends before any card resolved, publish an explicit empty summary rather than leaving the field absent, so the client distinguishes "nothing happened" from "old room".

### 2.6 The Dart model trap — this has already bitten this project

`lib/models/game_state.dart`'s `toMap()` is an **explicit whitelist**, and `test/fake_functions.dart` round-trips room documents through `GameState.fromMap(...)` and `.toMap()`. A field the Dart model does not know is **silently erased on any round-trip**, so the harness stops reproducing production — the Issue 31 shape, and exactly what J1 had to handle for `effectiveDeckId`.

Add `matchSummary` to the Dart `GameState`: field, constructor, `copyWith`, `toMap` (**omit the key when null — never write `null`**), and `fromMap`. Prove it survives a round-trip in a test. Follow how `effectiveDeckId` was done; it is the working example.

### 2.7 Validation for K1

- **Standings first, and independently.** A widget test renders the game over screen for a 4-player match with **no** `matchSummary` and asserts every player appears with their score. This must pass before any summary code exists.
- **Emulator test, multi-round.** A 3-player, 2-round match played through both reveals. Assert `sealed/_summary` accumulated one entry per resolved card, and that at game over `room.matchSummary.bestLie.fooled` equals the number of voters who actually picked that forgery. **Compute the expected number from the votes the test cast**, not from the summary itself — an assertion that reads its own output proves nothing.
- **Rules test — the security property.** A signed-in client attempting to read `sealed/_summary` is **denied**. Put it in `functions/test/rules.spec.ts` beside the existing sealed assertions. **Falsify it**: it must fail if a `match /sealed/{doc}` allow-read block is added.
- **Mid-match leak guard.** After round 1 resolves but before game over, `room.matchSummary` is **absent**. This is the assertion that stops Issues 99/100 reopening.
- **The disconnect path.** A 3-player match that drops to 2 mid-round reaches game over **with** a summary published. This is the site most likely to be forgotten; assert it explicitly.
- **Degrade gracefully.** The screen renders standings without crashing when `matchSummary` is absent, and when it is present but every award is null (a match where nobody was ever fooled).
- **Falsify the accumulator.** With the summary write removed, the emulator test must fail. If it still passes, it is asserting something else.

---

## 3. K2 — Case File downloads on web (Issue 110, Option B)

### 3.1 What happens today

`_shareCaseFile()` renders the Case File to PNG bytes, then at `game_over_screen.dart:105` returns early under `kIsWeb` with `Sharing is only supported on mobile devices.` **The bytes already exist at that point** — this is a delivery change, not a rendering one. Do not re-render.

### 3.2 What to build

Replace the early return with a save that hands the browser the file.

**Use a conditional import.** There is **no conditional import anywhere in `lib/` yet**, so you are introducing the pattern — keep it small and obvious:

```dart
// lib/utils/case_file_saver.dart
export 'case_file_saver_io.dart'
    if (dart.library.js_interop) 'case_file_saver_web.dart';
```

Both files expose the same signature, `Future<void> saveCaseFilePng(Uint8List bytes, String filename)`. The web implementation builds a `Blob`, creates an object URL, clicks a synthetic anchor carrying `download`, and **revokes the object URL afterwards** — a leaked blob URL pins the whole PNG in memory for the life of the tab. The IO implementation is unreachable in practice (mobile takes the `Share.shareXFiles` path) but must compile; have it throw `UnsupportedError` rather than pretend to succeed.

**Prefer `package:web` + `dart:js_interop` over `dart:html`.** `dart:html` still works on Flutter 3.44.6 but is deprecated and will be removed. `package:web` is **not currently a dependency** — adding it is a `pubspec.yaml` change, and it is the only new dependency this wave should introduce.

Then show a confirmation snackbar naming what happened ("Case file saved to your downloads"), because a browser download can be silent and a button that appears to do nothing reads as broken.

### 3.3 Validation for K2

- **Mobile must not change.** A test asserting that on non-web the path still reaches `Share.shareXFiles`. **Falsify it by inverting the branch** — if it passes either way it is not testing the branch.
- **The web path must be OBSERVED, not argued.** Build for web, open the game over screen, click the button, and confirm a real file lands. **Then open it** and confirm it is a valid PNG of the Case File — not a 0-byte file, and not an HTML error page, which is the failure mode a naive blob URL produces.
- **Update block W14** in `docs/playthrough_findings_web.md` to describe the new behaviour, with a fresh screenshot. That block was corrected once already for claiming a mechanism that did not exist; **do not reintroduce a claim the evidence does not show.**
- Confirm no analyzer regression from the new dependency and the conditional import.

---

## 4. Validation standard for this wave

**Write the failing test first and watch it fail.** Record the observed failure in the commit body.

**Pair every fix with an over-reach guard that can actually fail.** Standings must work without a summary; mobile sharing must survive the web change; the summary must be unreadable mid-match.

**A green suite says nothing about what is deployed.** K1 is inert until `firebase deploy --only functions`, which you must not run. Expect `check_deploy_fresh.sh` to stay red and **say so in the commit** rather than leaving it looking like a regression.

**Verify K1 on a real multi-round match.** A single round cannot produce a best-lie contest, a comeback, or a repeat fooling — so a one-round test can pass while the feature is empty in practice.

---

## 5. Playthrough procedure — the standing setup

1. **`.env` must contain `USE_EMULATOR=false`** — a bundled asset; changing it after the build has no effect.
2. **Uninstall on every booted simulator** so no stale room is restored from `SharedPreferences`.
3. **Build, then prove the binary is newer than the source**; paste both lines into the report header:
   ```bash
   stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
   ```
4. **Launch one device at a time** — concurrent builds corrupt `build/`. Gate all three on `THE GUEST LEDGER`.
5. `Disable Game Timers` **on** (`lobby_screen.dart:623`), recorded as a deviation. `Family-Friendly Decks Only` **off** (`:643`).
6. **Three real clients. Never `DEBUG: ADD 9 BOTS`.**
7. Paste `flutter --version` into the header rather than recalling it.

**Evidence contract.**

| Field | Takes | Never takes |
|---|---|---|
| `Observed:` | `get_interactive_elements` output, screen text, a saved screenshot path, a `flutter:` log line | A `grep`. A source line. A test name. Prose describing code. |
| `Reference:` | `file:line` — optional context for the expected value | — |

**Name the field `Observed:`.** A renamed variant is what let E11 through a human review; `check_playthrough_evidence.sh` now catches the rename, but do not create the need.

---

## 6. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 22, 2026:**

- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match; with Issue 105's re-runs the report now stands at **14 PASS, 1 NOT RUN (E9, honestly labelled), 0 FAIL**, every cited screenshot present. **E7 seat recovery device-verified** (`xcrun simctl terminate` mid-match → relaunch → straight back to `/reveal`, seat and score intact). **E8 host kick device-verified on both sides.** **No product defect found.**
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R4 mechanically; **E10** re-run in room `YJUG` with the in-game `Leave game` control and evidence from **both** remaining devices; **E11** re-run on a **release** build outside Marionette (its screen coverage stated honestly — the lobby was observed, the rest rests on `kDebugMode` being one compile-time const); **E13** fixed beyond spec, having been found by the script and missed by two human passes.
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**The battery is seven gates:** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 7. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests; `debugSimulateBotResponses` drives several. Their gating is observable only in a release or profile build.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin**.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — **do not simplify to one condition**.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **`castVote` rejects only genuine self-votes.** Never let a client bound exceed the server's.
- **The option id is the authority; text is the fallback, consulted only when the id is null.**
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **`handleDisconnect` has exactly three legitimate callers.**
- **Dialogs render on `groundRaised`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; plus the declined options in `ongoing_general_errors.md` §4.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens (§5, device-verified), callables, debug isolation (§7.1), privacy manifest (§7.2), deploy verification (§8) | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 9. Validation standard

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number — `check_playthrough_evidence.sh` exists because a mandated check of mine did not.

**A check written for one shape of a defect will not catch the next shape.** The rule looked for `grep -`; the next instance was prose, and the one after that was a renamed field. **Assert positively — require the artefact — rather than only forbidding the known-bad token.**

**A `grep` is not an observation.**

**Prove the artefact ships, not that it exists.** The guard is in the source; the button is in the binary.

**Record every substitution.** An omitted assertion reads as though it passed.

**A test harness that cannot express the bug will pass against it.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Fifteen blocks can pass and the game may still not be fun. That question belongs to the Apple beta.

---

## 10. Feedback loop — what past specs got wrong

- **A check that matches nothing returns the same number as a check that passes.** Mine did, and it shipped as a mandatory step.
- **A defect class mutates faster than the rule written to catch it.** `grep` as observation → prose as observation → a **renamed field** hiding both. Each escaped a rule written for the previous shape. **Match the concept, not the literal.**
- **A convention introduced to stop one failure can become the next one.** `grep -F` traceability stopped invented quotes, then became the observation.
- **When a written step fails twice, replace it with a tool.** `check_deploy_fresh.sh` for deploys; `check_playthrough_evidence.sh` for evidence.
- **A fix can be correct while its design doc still describes the vulnerability.**
- **When you redefine what a field holds, enumerate its readers.**
- **A guard's test must be run with the guard removed.**
- **Working logs rot by appending.** One banner, one Resolved heading, one line per resolved issue.
- **One item = one commit.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output. For a mechanical check, confirm it matched a NON-ZERO
    count before believing its result.
(3) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(4) VALIDATE per section 8, including the over-reach guard.
(5) RECORD observed output in the commit body and, for a guard, in a comment
    at the top of the script or test.
(6) RE-RUN THE FULL BATTERY before committing — all six. check_deploy_fresh
    may legitimately still be red for server changes you must not deploy.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done

**K1 — Issue 111, Option C**
- [ ] **Full standings render for every active player** — rank, name, score, `fooled X · fooled by Y`. Works with **no** `matchSummary` present.
- [ ] Summary accumulated **inside the existing reveal transaction**, reusing the pass that already walks `resolvedVotes`. No second traversal.
- [ ] `sealed/_summary` is read in the transaction's **read phase**, before any write.
- [ ] Text truncated to `kMaxAnswerLength`; entries hard-capped; the **published** `matchSummary` is computed awards, not the raw per-card log.
- [ ] Tie-breaking is deterministic, so two runs of one match agree.
- [ ] **All three** `currentPhase: "gameOver"` sites publish — `:1081`, `:1089` (disconnect) and `:1617` (final round). The disconnect path is asserted explicitly.
- [ ] `matchSummary` added to Dart `GameState` (field, constructor, `copyWith`, `toMap` **omitting null**, `fromMap`) with a round-trip test proving it is not erased.
- [ ] **Rules test**: a client cannot read `sealed/_summary`, and the test **fails** if an allow-read block is added.
- [ ] **Leak guard**: `room.matchSummary` is absent after round 1 resolves and before game over.
- [ ] Emulator test computes the expected `fooled` count **from the votes it cast**, not from the summary.
- [ ] Degrades gracefully: no summary, and an all-null summary, both render without crashing.
- [ ] Accumulator falsified — removing the write fails the test.

**K2 — Issue 110, Option B**
- [ ] Conditional import shim with one shared signature; web impl **revokes the object URL**; IO impl throws rather than silently succeeding.
- [ ] `package:web` added to `pubspec.yaml` — the only new dependency this wave.
- [ ] Mobile still reaches `Share.shareXFiles`, proven by a test that **fails when the branch is inverted**.
- [ ] Web download **observed**: a real file saved, opened, and confirmed to be a valid PNG of the Case File — not 0 bytes, not an HTML error page.
- [ ] A confirmation snackbar tells the player the file was saved.
- [ ] Block **W14** updated with a fresh screenshot that shows what the block claims.

**Across the wave**
- [ ] Battery at or above baseline: **0 errors** · **≥179** · clean functions build · **≥68** · both evidence gates exit 0.
- [ ] `check_deploy_fresh.sh` still red, explained in the commit, and **`firebase deploy` was never run**.
- [ ] One item, one commit; Conventional Commit; WHY in the body.
- [ ] Issues 110 and 111 moved into the **single** existing Resolved heading, and `design_scoring_and_ui.md` updated — it currently documents the honors and P6 sharing, and both change here.
