# Agent Execution Guide — Active Build: Wave J — Prompt Source & Sampling — August 24, 2026

**You are an engineering agent with no memory of this project.**

**The user has made all three selections.** Build exactly these:

| # | Item | Issue & choice | Touches | Deploy |
|---|---|---|---|---|
| **J1** | One prompt-source resolver; kill the `"custom"` sentinel crash | **109 → Option C** | `functions/src/index.ts`, `lib/models/game_state.dart` | functions |
| **J2** | Custom games draw from the players' own pool | **108 → Option B** | `functions/src/index.ts` | functions |
| **J3** | Re-roll samples uniformly, minus what is live | **107 → Option B** | `functions/src/index.ts` | functions |

**Order is J1 → J2 → J3 and it is a real dependency.** J1 creates the single place that decides where prompts come from; J2 teaches that place about custom pools; J3 changes how a prompt is picked from it. Built in any other order you will write the sentinel check three times and delete it twice.

**On Issue 107 the user wrote: "Option B if it is not too hard to do. Otherwise do Option A."** **It is not hard — Option B is *less* code than what is there now**, because it deletes the union with the player's history rather than adding anything. Implement B. The only thing that would justify falling back to A is discovering that some other caller depends on re-roll consulting `seenPrompts`; §3.3 tells you how to check that in one command, and the expected answer is that nothing does. **"It felt hard" is not the condition.**

**Do not run `firebase deploy`.** All three items are server-side and inert until deployed; that call is the user's.

## Verified baseline — the regression bar

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (21 warnings, 197 infos) | `flutter analyze lib test` |
| Client tests | **178/178** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **63/63** | `npm --prefix functions test` |
| Deploy freshness | **exit 1, and that is correct** — undeployed server commits already exist | `./scripts/check_deploy_fresh.sh` |
| Playthrough evidence | **exit 0** | `./scripts/check_playthrough_evidence.sh` |

---

## 0. What is already correct — do NOT "fix" it

- **The initial draw is already uniformly random from the selected deck.** `startGame` → `PromptDecks.drawPrompts(deckId, n)` Fisher-Yates shuffles a copy and slices. `deckId` is resolved from `room.selectedDeckId` (Issue 106) and each first prompt is seeded into `sealed/{playerId}.seenPrompts` at `index.ts:476`. **Wave J does not touch this.**
- **The deck is resolved from the room and a mismatched caller is rejected** (Issue 106, `index.ts:293`). Never reintroduce a client-supplied deck.
- **Re-rolls already never refuse.** `drawOneExcluding` degrades in three steps instead of throwing `resource-exhausted`; only a missing deck throws.
- **The next-round draw already avoids collisions inside a round** via `assignedThisRound`.
- **`startGame`'s custom assignment already works** — per-player cap of 3, trim, length 1–200, case-insensitive dedupe, top-up from `the_daily_grind`, shuffle, and a swap so nobody receives their own prompt. J2 **extracts** it; it does not rewrite it.

---

## 1. Standing constraints

- **One item = one commit.** Three items, three commits.
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.
- **A `grep` is not an observation.** `Observed:` takes device or runtime output.
- **Record every substitution.** An omitted assertion reads as though it passed.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Do not fix unrelated defects inline.** File them with Pros/Cons and a blank selection line, per `.agents/skills/bug_documentation_guidelines/SKILL.md`.
- **Do not touch anything in §8 or §9.**

---

## 2. What legitimately starts a new build

1. **A human plays the game and something is wrong.** Every recent functional defect came from this. **No gate has ever found one.**
2. **The user asks for something**, or selects an option. *(Wave J is this.)*
3. **A gate that was green goes red.** Fix the cause, not the gate.
4. **The beta returns real feedback.**

---

## 3. J1 — One prompt-source resolver (Issue 109, Option C)

### 3.1 The defect being fixed

`advanceToNextResolution` resolves the next round's deck as `const deckId = room.selectedDeckId || "the_daily_grind";` (`index.ts:1476`). For a custom game that is the literal sentinel `"custom"`, which has no entry in `DECKS`:

```
$ node -e "PromptDecks.drawOneExcluding('custom', new Set())"
THROWS: not-found | Failed to load deck: custom. Ensure it is defined in PromptDecks.
```

**Every custom room with `totalRounds > 1` throws as the last card of round 1 resolves.** `rerollPrompt` at `:856` maps the sentinel correctly and `:1476` does not. **The disagreement is the bug**, so the fix is not to add a third mapping — it is to leave exactly one.

### 3.2 What to build

**(a) `startGame` stores the resolved deck.** In the same `transaction.update` that sets `currentPhase: "truth"`, add:

```ts
effectiveDeckId: deckId === "custom" ? "the_daily_grind" : deckId,
```

`deckId` is the Issue-106 room-resolved value. Keep `selectedDeckId` exactly as it is — it is the host's *choice* and the lobby renders it. `effectiveDeckId` is the *built-in deck to draw from*, and after `startGame` the sentinel must never reach a draw again.

**(b) Add one resolver, and let nothing else decide.** Put it beside the callables in `index.ts`:

```ts
type PromptSource =
  | { kind: "deck"; deckId: string }
  | { kind: "custom"; pool: PromptItem[]; fallbackDeckId: string };

function resolvePromptSource(room: GameState, activePlayers: PlayerState[]): PromptSource
```

In **J1 it always returns `{ kind: "deck", … }`** — custom still resolves to the fallback, i.e. today's re-roll behaviour, extended to the round-advance path. J1 is therefore a refactor plus a crash fix and nothing else. J2 adds the `custom` arm.

**(c) Tolerate rooms started before this change.** A room already in flight has no `effectiveDeckId`, and it must not crash:

```ts
const effective =
  room.effectiveDeckId ||
  (room.selectedDeckId === "custom" ? "the_daily_grind" : room.selectedDeckId) ||
  "the_daily_grind";
```

Put that fallback **inside the resolver only.** The 8-hour room TTL bounds how long it matters, but a live game must not break on deploy.

**(d) Both draw sites call the resolver.** `rerollPrompt` (`:856`) and `advanceToNextResolution` (`:1476`) stop deriving a deck id themselves. After J1, **the string `"custom"` must not appear in either function.**

### 3.3 The trap that will bite you: the Dart model drops unknown fields

`lib/models/game_state.dart`'s `toMap()` is an **explicit whitelist**, and `test/fake_functions.dart` round-trips room documents through `GameState.fromMap(...)` and `.toMap()`. A field the Dart model does not know is therefore **silently erased** on any round-trip — the harness would then not reproduce production, which is precisely the shape of Issue 31 and lesson 2.1.

**So add `effectiveDeckId` to the Dart `GameState`**: the field, the constructor, `copyWith`, `toMap`, and `fromMap` (defaulting to `null`/absent, and **omit the key when null** — never write `null`, per lesson 2.1). Prove it survives a round-trip in a test.

Also run this before you start, to confirm nothing else already depends on re-roll history — the expected count is zero outside the two draw sites and the sealed writes:

```bash
grep -rn "seenPrompts" functions/src lib test | grep -v "_test\|spec"
```

### 3.4 Validation for J1

- **Reproduce first.** An emulator test that starts a **custom deck with `totalRounds: 2`**, plays round 1 to resolution, and asserts round 2 begins with a prompt on every card. **It must fail with `not-found` before your change** — paste that failure into the commit body. A single-round game hides this defect entirely, which is why W1–W19 missed it.
- **Over-reach guard:** a single-round custom game, and a normal built-in-deck multi-round game, must both still pass unchanged.
- **Round-trip test:** a `GameState` carrying `effectiveDeckId` survives `toMap()` → `fromMap()` with the value intact, and a `GameState` without it does not emit a `null` key.
- **Sentinel containment.** Add a source assertion that `"custom"` does not appear inside `rerollPrompt` or `advanceToNextResolution`. **It must assert it actually read those function bodies — a non-zero line count — before believing a zero-match result** (§11, lesson 2.21). A check that matches nothing returns the same number as a check that passes.

---

## 4. J2 — Custom games draw from the players' pool (Issue 108, Option B)

### 4.1 What to build

**(a) Extract, do not rewrite.** The pool builder is inside `startGame`'s custom branch at `index.ts:336`. Lift it verbatim into a helper:

```ts
interface PromptItem { text: string; authorId: string; }
function buildCustomPromptPool(activePlayers: PlayerState[], targetSize: number): PromptItem[]
```

It must preserve every existing rule: a **per-player cap of 3**, `trim()`, length **1–200**, **case-insensitive** dedupe, top-up from `the_daily_grind` tagged `authorId: "fallback"`, and the shuffle. `startGame` then calls the helper and keeps its existing assignment loop, **including the swap that stops a player receiving their own prompt.**

**(b) The resolver grows its `custom` arm.** When the room is a custom game, `resolvePromptSource` returns `{ kind: "custom", pool, fallbackDeckId: room.effectiveDeckId }`.

**(c) Both draw sites honour the pool.**
- **Re-roll:** choose from pool entries where `authorId !== callerPlayerId`. If the pool cannot supply one, draw from `fallbackDeckId`. **The P10 rule that you never receive your own prompt survives every path** — it is the core deduction guarantee, not a nicety.
- **Round advance:** re-run the assignment for the new round against the pool, excluding prompts already used and each player's own authorship, topping up from `fallbackDeckId` when short.

### 4.2 Validation for J2

- **`startGame` behaviour is unchanged.** Every existing custom-deck test passes **without modification**. If one needs editing, you have changed behaviour that was not in scope — stop and re-read.
- A custom game's re-roll returns a **contributed** prompt when the pool can supply one. Assert it is a prompt a player actually wrote, not merely that it is a string.
- **Never your own:** a player whose contribution is in the pool never receives it, on the initial draw, on re-roll, or in round 2.
- **The fallback path is tested too**, not just the happy one: a pool too small to serve everyone must still start and still re-roll.

---

## 5. J3 — Re-roll samples uniformly, minus what is live (Issue 107, Option B)

### 5.1 What to build

Today `rerollPrompt` builds `excluded = inPlay ∪ cardSeen` and prefers anything outside it, so successive re-rolls **walk** the deck instead of sampling it.

Change it to sample **uniformly from the source, excluding only prompts currently on a card — including the caller's own current prompt.** Concretely, at the re-roll call site the soft and hard exclusion sets become the same `inPlay` set, and `cardSeen` is no longer unioned in.

- **Keep writing `seenPrompts`.** It stops governing re-roll sampling but is still history, and the round-advance draw still uses it (see below). Do not delete the writes.
- **Scope: `rerollPrompt` only.** The round-advance draw keeps excluding that player's `seenPrompts`. Getting the same prompt again in a later *round* is a worse experience than a repeat while re-rolling, and the user asked about re-rolls. **Do not "consistently" apply B to the round-advance path.**
- Leave `drawOneExcluding`'s three-tier signature alone — the round-advance caller still needs the history-aware behaviour.

### 5.2 Validation for J3

- **Distribution, not one draw.** Re-roll many times against a fixed deck and assert **every** prompt in that deck is reachable. A sampler stuck on one element must fail this.
- **Assert the sample size is non-zero before believing the result.** A loop that ran zero times and a uniform sampler produce identical "no violations" output.
- **Assert what Option B promises, and only that:** a returned prompt is **never** one that was live on a card at the moment of the call. **Repeats across the player's own history are now legal — a test forbidding them would be asserting Option C** and must not be written.
- **Make it non-flaky.** Repeat enough, or seed, that it does not fail one run in twenty. A flaky randomness test gets deleted by the next agent, and then nothing guards this.
- **Existing tests encode the old contract.** Three emulator tests were already rewritten in `1c5d69b` when re-rolls became unlimited. If one fails now, decide deliberately whether it states a requirement that still holds, **update it to the new contract, and say in the commit which assertions changed and why.** Never weaken a guard to make a run pass.

---

## 6. Validation for this wave

**Write the failing test first and watch it fail.** For J1 that is the custom 2-round game; for J3 it is the distribution test. Record the observed failure output in the commit body.

**Pair every fix assertion with an over-reach guard that can actually fail.** Built-in decks must keep working while custom changes; single-round games must keep working while multi-round is fixed; `startGame` must be untouched while re-roll changes.

**A green suite says nothing about what is deployed.** All three items are inert until `firebase deploy --only functions`, which you must not run. Expect `check_deploy_fresh.sh` to stay red and **say so in the commit** rather than leaving it looking like a regression.

**Prompts are drawn once, at `startGame`, and written into `room.cards`.** A room already in progress keeps its prompts after any deploy. Manual verification needs a **new** game.

---

## 7. Playthrough procedure — the standing setup

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

## 8. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 22, 2026:**

- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match; with Issue 105's re-runs the report now stands at **14 PASS, 1 NOT RUN (E9, honestly labelled), 0 FAIL**, every cited screenshot present. **E7 seat recovery device-verified** (`xcrun simctl terminate` mid-match → relaunch → straight back to `/reveal`, seat and score intact). **E8 host kick device-verified on both sides.** **No product defect found.**
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R4 mechanically; **E10** re-run in room `YJUG` with the in-game `Leave game` control and evidence from **both** remaining devices; **E11** re-run on a **release** build outside Marionette (its screen coverage stated honestly — the lobby was observed, the rest rests on `kDebugMode` being one compile-time const); **E13** fixed beyond spec, having been found by the script and missed by two human passes.
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**The battery is six gates:** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 9. Invariants & intentional decisions — do NOT change

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

## 10. Where the contracts live

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

## 11. Validation standard

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

## 12. Feedback loop — what past specs got wrong

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

**J1 — Issue 109, Option C**
- [x] `startGame` writes `effectiveDeckId` in the same update that sets `currentPhase: "truth"`.
- [x] `resolvePromptSource()` exists and is the **only** code that decides where prompts come from.
- [x] `rerollPrompt` and `advanceToNextResolution` both call it; **the string `"custom"` appears in neither**.
- [x] Legacy rooms without `effectiveDeckId` resolve through the fallback **inside the resolver** and do not crash.
- [x] `effectiveDeckId` added to Dart `GameState` (field, constructor, `copyWith`, `toMap`, `fromMap`), **omitted when null**, with a round-trip test proving it is not erased.
- [x] **Reproduced first:** a custom-deck `totalRounds: 2` emulator test fails with `not-found` before the fix; failure output in the commit body. Passes after.
- [x] Over-reach guards: single-round custom, and multi-round built-in deck, both unchanged.
- [x] Sentinel-containment check asserts a **non-zero** read of the two function bodies before reporting zero matches.

**J2 — Issue 108, Option B**
- [x] `buildCustomPromptPool()` extracted from `startGame` **verbatim** — cap of 3, trim, length 1–200, case-insensitive dedupe, `the_daily_grind` top-up tagged `"fallback"`, shuffle.
- [x] **Every existing custom-deck test passes without modification.** Editing one means behaviour changed out of scope.
- [x] A custom re-roll returns a prompt a player actually wrote when the pool can supply one.
- [x] **Never your own prompt** — on initial draw, on re-roll, and in round 2.
- [x] The too-small-pool fallback path is tested, not just the happy path.

**J3 — Issue 107, Option B**
- [x] Re-roll excludes only what is live on a card, including the caller's own current prompt; `cardSeen` is no longer unioned into the exclusion.
- [x] `seenPrompts` is still written, and the **round-advance draw still consults it** — B was not applied there.
- [x] Distribution test shows every prompt in a deck is reachable, **and asserts its own sample size is non-zero**.
- [x] No test asserts "never repeats across history" — that is Option C, which the user did not choose.
- [x] Not flaky across repeated runs.
- [x] Any pre-existing test changed to the new contract is named in the commit, with why.

**Across the wave**
- [x] Battery at or above baseline: **0 errors** · **≥178** · clean functions build · **≥63** · evidence gate exit 0.
- [x] `check_deploy_fresh.sh` still red, explained in the commit, and **`firebase deploy` was never run**.
- [x] One item, one commit; Conventional Commit; WHY in the body.
- [x] Issues 107, 108 and 109 moved into the **single** existing Resolved heading in `ongoing_general_errors.md`, and `design_prompt_system.md` §3 and §5 updated to describe the rules that now hold.
