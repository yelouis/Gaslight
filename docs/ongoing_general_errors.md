# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

## 1. Open & in-flight

**Wave O — playtest fixes (Issues 113–121) — landed as nine commits, and six of the nine are verified good (August 27, 2026).** Verified by reading the source and running the battery in-session, not from the commit messages.

**Delivered and verified:** **O1**/117 (`answerAuthors` no longer unions across rounds — the three `merge: true` writes were replaced with full-document sets, and `sealedDataMap` is a complete in-transaction read, so no field is dropped), **O3**/115 (names snapshotted into `sealed/_summary.playerNames`; the game-over screen reads them and never consults the players subcollection), **O6**/114, **O7**/116, **O8**/119 (a real measurement loop in `AutoSizedAnswerText`, not more fixed tiers), **O9**/121.

**Three did not land as specified**, each verified against a running emulator rather than inferred — see Issues 122–125:

| Item | What was claimed | What is actually true |
|---|---|---|
| **O5** / 120 | presence window widened to 10 minutes | **Inert.** `lib/services/game_service.dart:20` still says `presenceStaleMs = 120000`, and the server's `isDead` check gates only *authorization*, never the deletion — so the host's client still evicts at 120 s. Proven in the emulator: a player stale by 150 s was deleted by a host-initiated `handleDisconnect` while `PRESENCE_STALE_MS` was 600 000. **Issue 123** |
| **O4** / 118 | placeholder votes rejected, all-sealed cards skipped | Both work, but the guard **broke a pre-existing test** and the functions battery is **red** (**Issue 122**), and a round in which *every* card is all-placeholder strands the table on an empty vote screen (**Issue 125**) |
| **O2** / 113 | per-card deltas published, leak-guarded | The deltas are correct and render correctly. But the published map **re-opens Issue 100** — it names every fooling forger during the unmask window (**Issue 124**) |

**Gate state, measured August 27, 2026:**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors**, 0 warnings (225 infos) |
| `flutter test` | **202/202** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **RED — 80 passing, 1 failing.** `should handle timeout and fill missing slots with placeholder` votes for the reader's truth option, which is now a placeholder when that reader timed out. See **Issue 122** |
| `./scripts/check_decks_in_sync.sh` | **exit 0** — 5 decks, 295 lines |
| `./scripts/check_deploy_fresh.sh` | **exit 1 — expected.** O1–O5 are undeployed; production still runs the August 26 06:46 UTC build |
| `./scripts/check_playthrough_evidence.sh` | **exit 0** — 21 blocks: 20 PASS, 1 NOT RUN, 0 FAIL (28 artefact paths verified on disk) |

**Read the exit code, not the pipeline's.** `./scripts/check_deploy_fresh.sh | tail -6` reports `$?` from `tail`, which is always 0. The gate is correct; a piped check of it is not.

**Undeployed and therefore not yet true in production:** everything in O1–O5, plus the earlier undeployed server work (curated deck contents, unlimited re-rolls, prompt source resolution, custom pool drawing, uniform re-roll sampling, match summary accumulation). Prompts and card summaries are initialized at `startGame`, so even after deploying, a room already in progress keeps the configuration it started with — manual verification needs a **new** game.

**Only one banner lives here.** Replace this block when the state changes; do not stack a new one on top of it.

## ⚠️ Unresolved Issues & Suggestions

**All eleven selections are made (August 27, 2026), and Wave P is specced in `agent_execution_guide.md`.** Ten took Option A; **Issue 131 took Option C** (both the done key *and* a pinned submit button). Build order and the reasoning behind it live in the guide — the short version is **P1 first** because the battery is red, and **P2 before P3** because a ten-minute presence window produces more placeholder cards and P2 is what stops them stranding a round.

**One thing found while speccing, which changes how Issue 124 must be built.** Option A said "publish the deltas when the unmask window closes" — but **the window has no server-side close.** `submitUnmaskGuess` zeroes the deadline only when *every* fooled player guesses (`functions/src/index.ts:2015`); when nobody guesses, the deadline simply passes and each client decides the window is over on its own wall clock (`lib/screens/phase4_reveal.dart:60–68`). A naive "publish on close" would therefore render an **empty points tray** in every round that times out, silently undoing Issue 113. Wave P adds a `closeUnmaskWindow` callable — any room member may call it, the server verifies the deadline has actually passed, and it is idempotent — so the close becomes a real server event. That also fixes a latent inconsistency where clients could disagree about when the window ended.

---

**Issues 122–125 are Wave O fallout** — found by verifying the nine commits against a running emulator. **Issues 126–132 are the user's build-4/5 playtest requests.**

---

### Issue 122: The placeholder-vote guard broke a pre-existing test and the functions battery is red
**Status**: ⚠️ Confirmed Unresolved — `npm --prefix functions test` reports **80 passing, 1 failing** as of August 27, 2026. The failure is `Gaslight E2E Game Emulator Tests > should handle timeout and fill missing slots with placeholder` (`functions/test/game_e2e.spec.ts:1088`), which fails with `Error: Cannot vote for a placeholder answer.`

The cause is not a bug in O4's guard — the guard is behaving exactly as Issue 118 Option A specified. That test deliberately has `p_guest2` time out on their truth, then casts every vote at `sealedSnap.data()?.truthAnswerId`, i.e. **the reader's truth option**. When the reader is the player who timed out, that option's text is `THE SOUL IS SILENT`, and `castVote` now rejects it (`functions/src/index.ts:913`). The test encodes the pre-O4 rule.

This matters beyond the red light: the test's actual subject — that a timeout fills missing slots with the placeholder — is still worth asserting, and it is the only test covering that path.

**Option A (recommended)**: **Vote for a non-placeholder option and keep the test's real subject** — pick the voted option from `card.options` by excluding any whose text is the placeholder, rather than always using `truthAnswerId`; keep the existing `expect(...sabotageAnswers).to.include('THE SOUL IS SILENT')` assertions untouched.
  - *Pros*: Preserves the only coverage of the timeout-fill path; the test then asserts the post-O4 contract rather than the pre-O4 one; no production code changes, so no new deploy risk; roughly a ten-line edit confined to one test.
  - *Cons*: The test becomes sensitive to which player ends up as `currentReaderId` (it is shuffled), so the option-picking must be written defensively rather than assuming a fixed index; a card where *every* option is a placeholder would leave nothing to vote for, so the test must also guarantee at least one real answer exists.

**Option B**: **Relax the guard so a placeholder is votable when it is the only remaining choice** — allow the vote if every other option is either a placeholder or the voter's own answer.
  - *Pros*: No test edit needed; avoids a voter ever being unable to cast a vote at all, which is a real (if rare) dead end under Option A's rules.
  - *Cons*: Directly contradicts the Issue 118 selection the user already made, and re-introduces the reported symptom in the exact narrow case that produced it; makes the client and server rules diverge again unless `card_grid.dart` learns the same conditional; adds a branch to `castVote` that is hard to reach in a test and will therefore rot.

**Option C**: **Delete the failing test** — the newer O4 tests cover placeholder behaviour.
  - *Pros*: Immediate green battery, zero effort.
  - *Cons*: The O4 tests assert the *guard*; none of them assert that a timeout actually fills `sabotageAnswers` with the placeholder in the first place, so this silently drops real coverage of the mechanism every other placeholder test depends on. **Deleting a test to turn a gate green is how a gate stops meaning anything.**

Your selection: Proceed with Option A.

---

### Issue 123: The 10-minute presence window is inert — players are still evicted at 120 seconds
**Status**: ⚠️ Confirmed Unresolved — **verified against a running emulator, not inferred.** O5 raised the server constant to `PRESENCE_STALE_MS = 600_000` (`functions/src/index.ts:179`), but a player who has been away for 150 seconds is still deleted from the room. Probe output:

```
PROBE server PRESENCE_STALE_MS = 600000 ( 600 s )
PROBE player stale by          = 150 s  -> inside the window, must survive
PROBE handleDisconnect (as HOST) returned = {"success":true}
PROBE Charlie still in the room? = false
PROBE VERDICT: 10-minute window DID NOT protect him
PROBE handleDisconnect (as PEER) THREW = Not authorized to trigger disconnect.
```

There are two independent causes and **both must be fixed**, or the window stays inert:

1. **The client still uses the old number.** `lib/services/game_service.dart:20` declares `static const int presenceStaleMs = 120000;` and `:457` calls `handleDisconnect` for every peer whose `lastSeen` is older than that. This constant was never updated by O5; nothing in the battery compares it to the server's.
2. **The server's window does not gate the deletion.** At `functions/src/index.ts:1155`, `isDead` appears only inside the *authorization* condition — `if (!callerPlayer || (!callerPlayer.isHost && callerPlayer.id !== disconnectedPlayerId && !isDead))`. A host is authorized unconditionally, so once the host's client asks, the player is removed no matter how recently they were seen. `isDead` exists only to let a *peer* evict someone; it has never limited the host.

Net effect: the effective presence window is `min(client constant, anything the host requests)` = **120 seconds**, which is what Issue 120 set out to change. The O5 test that "passes" is `expect(PRESENCE_STALE_MS).to.equal(600_000)` — an assertion that a constant equals its own literal, which cannot fail while the code is inert.

**Option A (recommended)**: **Enforce the window on the server, and have the client stop guessing** — make `handleDisconnect` refuse an *involuntary* eviction of a player who is inside the window (return `{ success: false, reason: "still present" }` rather than throwing, so the caller's `catchError` stays quiet), while leaving voluntary self-leaves and explicit host kicks unaffected. Then delete `presenceStaleMs` from `game_service.dart` and let the client report staleness on a generous local interval, or simply let the server decide.
  - *Pros*: The window becomes a real server-side invariant with one owner, so no future client can undercut it — the same shape as every other rule in this codebase (§2.6 "everything mutating goes through a Cloud Function"). Falsifiable directly: the probe above flips from `DID NOT protect him` to `PROTECTED him`. Removes a duplicated constant that has already drifted once.
  - *Cons*: `handleDisconnect` must now distinguish three callers it currently blurs — a voluntary leave, a deliberate host kick, and an automatic presence eviction — which means adding an explicit `reason` argument and auditing all callers (the guide records exactly three legitimate ones). A host kick must keep working immediately, so the refusal cannot be a blanket time check.
  - *Note*: with this in place the 3-player floor also holds a departed seat for up to ten minutes; that cost was accepted when Option B of Issue 120 was chosen, and Issue 125 is what stops it stranding a round.

**Option B**: **Only fix the client constant** — set `presenceStaleMs = 600000` in `game_service.dart` so it matches the server.
  - *Pros*: A one-line change, no server deploy needed, and it does make the observed behaviour match the intent in the normal case.
  - *Cons*: Leaves the server unable to enforce its own window — any client build with a stale constant (including every copy of build 4 already on testers' phones) keeps evicting at 120 s, and the web build and iOS build can disagree with each other. Fixes the symptom in one binary rather than the rule.

**Option C**: **Have the server derive presence itself and stop trusting client reports** — drop the client-initiated eviction path entirely and prune stale seats when a callable next touches the room.
  - *Pros*: Removes the "every client calls `handleDisconnect` on every snapshot" chatter, which is currently N clients × every players-collection update and is pure billed invocations; makes presence a property of the data rather than of whoever is watching.
  - *Cons*: The largest change of the three — eviction latency becomes "whenever someone acts", which is fine mid-round but leaves an idle lobby holding ghosts indefinitely; needs a new pruning path tested against every phase; more than one commit's worth of work.

Your selection: Proceed with Option A.

---

### Issue 124: The published score deltas name every fooling forger during the unmask window (re-opens Issue 100)
**Status**: ⚠️ Confirmed Unresolved — **verified against a running emulator.** O2 publishes `scoreDeltas` onto the revealed card (`functions/src/index.ts:1622`), including in the branch whose entire purpose is to withhold authorship until the unmask deadline passes. Probe output from the O2 test's own scenario:

```
PROBE unmaskDeadline = 1787811316768
PROBE window open? = true
PROBE sabotageAnswers (withheld) = {}
PROBE votes (obfuscated) = {"p_g1":"71ce3cc2-c06f-42c9-88bf-00a712f0241b","p_g2":"p_host"}
PROBE scoreDeltas (published) = {"p_g2":3,"p_host":1}
PROBE actual forgerId = p_g2  targetId = p_host
PROBE non-target players with positive delta = ["p_g2"]  -> identifies forger? true
```

The branch at `index.ts:1610` deliberately sets `sabotageAnswers: {}` and rewrites votes to opaque option UUIDs so that a player about to guess "who wrote the answer I fell for" cannot look it up. `scoreDeltas` is published beside them, and `ScoringLogic.calculateScores` credits `deltas[votedForId] += 1` for every person a forger tricked (`functions/src/scoring_logic.ts:113`) — so a non-target player with a positive delta *is* a forger who fooled someone. This is the defect class closed as **Issue 100** ("forgery authorship exposed during the unmask window").

**Scope, stated honestly:** the UI does **not** render this — both the points tray and the standings delta are gated behind `revealStage >= 4` (`lib/screens/phase4_reveal.dart:424`, `:523`), and the unmask tray is stage 3. The exposure is in the room document, which every client streams. It is also **not entirely new**: `totalScore` and `playersDeceived` are already incremented at the reveal transition (`index.ts:1531`), so a player watching the players collection could already infer the same thing. O2 turned a diffuse inference into a single labelled map.

**Option A (recommended)**: **Withhold the delta map until the unmask window closes** — publish `scoreDeltas` in the nobody-was-fooled branch as now, and in the fooled branch publish it only when `submitUnmaskGuess` sets `nextUnmaskDeadline = 0`, or when the deadline is force-expired. The client already refuses to draw it before stage 4, so nothing visible changes.
  - *Pros*: Restores the Issue 100 invariant with the smallest possible change, in the same place O2 added the leak; no client change at all, because the render gate already matches; directly falsifiable — re-run the probe and assert `scoreDeltas` is absent while `window open? = true`.
  - *Cons*: Does not address the pre-existing `totalScore` / `playersDeceived` inference, so the room is *less* leaky but not airtight; the reveal screen must tolerate `scoreDeltas` being briefly absent, which means keeping the `?? const {}` fallback rather than assuming the field is present once the card is revealed.

**Option B**: **Also defer the score writes themselves** — hold `totalScore`, `timesFooled` and `playersDeceived` increments until the unmask window closes, alongside Option A.
  - *Pros*: Closes the inference channel completely — during the window, nothing anywhere in the room distinguishes a forger who fooled someone from one who did not. Makes "no authorship before the deadline" a property that can be asserted over the whole document rather than field by field.
  - *Cons*: Meaningfully reshapes the reveal pipeline — the increments currently happen in the same transaction that computes them, and deferring them means either stashing the pending deltas somewhere (a new sealed field) or recomputing at close, both of which risk double-application if the deadline expires and a guess arrives concurrently. The standings strip would also freeze during the window, which is a visible behaviour change players may read as a bug.

**Option C**: **Publish only the viewing player's own delta** — replace the map with a per-player value resolved through a callable, as `getMyOptionId` already does for the own-answer lockout.
  - *Pros*: Structurally impossible to leak another player's delta; reuses a pattern already proven in this codebase for exactly this class of secret.
  - *Cons*: The points tray is explicitly a *shared* readout — it names every player and their gain — so this would either delete a feature the reveal screen has today or need N callable round-trips per client per card; the tray is the thing Issue 113 was filed to make correct.

Your selection: Proceed with Option A.

---

### Issue 125: A round in which every card is all-placeholder strands the table on an empty vote screen
**Status**: ⚠️ Confirmed Unresolved — **verified against a running emulator.** O4 filters unvotable cards out of `resolutionOrder` (`functions/src/index.ts:1475`), but does not handle the case where that filter empties the list. Probe output for a table where nobody submitted a truth and nobody submitted a forgery:

```
PROBE phase           = vote
PROBE resolutionOrder = []
PROBE currentReaderId = null
PROBE after advanceToNextResolution phase = gameOver
```

The room enters the vote phase with no reader. `lib/screens/phase3_vote.dart:134` leaves `currentCard` null, so the screen renders with nothing to vote on and no control that advances anything. The host *can* escape — `advanceToNextResolution` reaches `gameOver` — but no UI offers that, and with timers disabled (which Issue 130 proposes making the default) nothing fires automatically. The O4 test that covers skipping asserts only `expect(resolutionOrder).to.not.include('p_g2')`; it never asserts the room progresses, which is what the Wave O guide asked for.

This is rare — it needs a whole table silent for both the truth and the forgery phase — but Issue 123's ten-minute window makes it strictly more reachable, because absent players now stay seated and keep generating placeholders.

**Option A (recommended)**: **Detect the empty order at the transition and skip the vote phase entirely** — where `validResolutionOrder` is computed, if it is empty, go straight to the next round (or to `gameOver` on the last round) instead of writing `currentPhase: "vote"` with a null reader.
  - *Pros*: Fixes it at the one place that creates the state, so no screen ever has to render a reader-less vote phase; reuses the round-advance and game-over paths that `advanceToNextResolution` already takes, rather than adding a new terminal path; falsifiable with the probe above — `phase` must never be observed as `vote` with an empty `resolutionOrder`.
  - *Cons*: The round-advance logic currently lives inside the `advanceToNextResolution` callable, so either it moves into a shared helper or `advancePhaseInternal` duplicates it — the former is the right shape but touches a function three other paths depend on. A round that vanishes with no reveal at all needs *something* on screen or players will think the game glitched.

**Option B**: **Render an explicit dead-round state on the vote screen** — when `currentReaderId` is null, show a "nobody answered this round" panel with a host-only Continue that calls `advanceToNextResolution`.
  - *Pros*: Purely client-side, so it ships without a deploy and protects every already-installed build; the table is told what happened rather than staring at an empty screen; no changes to a shared server path.
  - *Cons*: Leaves the room genuinely stuck for any table whose host has left or whose host does not press the button; treats a server-side invariant violation as a UI state, which is the pattern §2.6 exists to avoid; a non-host sees a screen they cannot act on.

**Option C**: **Prevent the state upstream — never let a card be all-placeholder** — if a player times out on their truth, seed their truth slot from the deck instead of the placeholder.
  - *Pros*: The whole class disappears; every card always has at least one real option, so the O4 skip path becomes unreachable and the vote screen can assume a reader.
  - *Cons*: Puts words in an absent player's mouth, which is exactly what `THE SOUL IS SILENT` was introduced (Issue 72) to stop; a seeded "truth" could win the round for someone who never played, which corrupts scoring in a way the placeholder deliberately does not.

Your selection: Proceed with Option A.

---

### Issue 126: There is no way to see what is inside a deck before choosing it
**Status**: ⚠️ Confirmed Unresolved — **user request from the build-4 playtest.** The lobby carousel (`lib/widgets/deck_carousel.dart`) shows each deck's display name, rating seal and prompt count, but nothing about the prompts themselves. `PromptDecks.getDeck(deckId)` already returns the full `DeckDefinition` including `prompts`, and the catalogue is compiled into the client (`lib/utils/prompt_decks.dart`), so no network call is needed to show them.

**One thing to decide deliberately:** a deck has 25–50 prompts and a game draws only a handful. Showing all of them lets the host read the exact prompts their table is about to get, which is a mild spoiler for the host specifically.

**Option A (recommended)**: **A preview sheet showing a sample** — tapping a deck opens a bottom sheet with the deck name, rating, count, and **8 randomly drawn prompts** under a "a taste of what's inside" heading, with a re-shuffle control.
  - *Pros*: Answers "what kind of deck is this?", which is the actual question, without handing the host the answer key; a fixed-height sheet needs no scroll tuning and no layout work at the narrow widths that keep biting this project (Issues 114, 119); reads entirely from the compiled catalogue, so it works offline and adds no Firestore reads.
  - *Cons*: A host who really wants the full list can re-shuffle until they have seen most of it, so the spoiler protection is soft; "8" is a magic number that will need revisiting if a deck ever ships with fewer than 8 prompts (the smallest today has 25).

**Option B**: **A full scrollable list of every prompt in the deck** — the complete contents in a scrollable sheet.
  - *Pros*: Complete transparency, which matters most for the R-rated deck where a host is deciding whether the content suits their table; simplest possible implementation, no sampling logic.
  - *Cons*: Spoils the deck for whoever browses it, and the host is a player; 50 prompts is a long scroll on a phone, and this project has repeatedly shipped scroll affordance bugs (see Issue 132).

**Option C**: **No preview — expand the deck description instead** — give each `DeckDefinition` a one-line `description` field and show it under the name.
  - *Pros*: Zero spoiler risk; the description lives in `prompt_decks.ts` with the rest of the deck's metadata, which is exactly where the deck refactor says deck facts belong; smallest change and it also improves the carousel for everyone, not just people who tap.
  - *Cons*: Does not answer the request as asked — the user asked to see the prompts; a description is written once and can drift from the deck's actual contents as prompts are edited.

Your selection: Proceed with Option A.

---

### Issue 127: Re-roll success snackbars queue up and keep appearing long after the player stops tapping
**Status**: ⚠️ Confirmed Unresolved — **reported for a player named Brian in the build-4 playtest, and confirmed by reading the source; no log lookup was needed.** `lib/screens/phase2_craft.dart:567` shows the re-roll success snackbar **without calling `clearSnackBars()` first**, unlike every other snackbar in the same file (`:76`, `:121`, `:148`, which all clear first). `ScaffoldMessenger` **queues** snackbars rather than replacing them, and the default duration is 4 seconds, so eight taps produce roughly 32 seconds of back-to-back "Prompt re-rolled successfully!" messages.

It follows the player across screens because there is exactly one `ScaffoldMessenger` for the whole app — the one `MaterialApp` creates (`lib/main.dart:68`); no screen installs its own. Its queue is not cleared by navigation, which is precisely why Brian kept seeing it after submitting his truth and moving to the waiting screen. Both halves of the report are explained by the same missing line.

**Option A (recommended)**: **Clear before showing, and shorten the message** — call `ScaffoldMessenger.of(context).clearSnackBars()` immediately before the success snackbar, matching the three other call sites in the file, and set `duration: const Duration(milliseconds: 1200)` so rapid re-rolls feel responsive rather than backed up.
  - *Pros*: A two-line change at the one site that is inconsistent with its neighbours; makes every snackbar in the file follow the same rule, so the next one written by copy-paste inherits the right behaviour; fixes the cross-screen persistence for free, because there is never more than one queued.
  - *Cons*: Does not stop a snackbar that is already showing from outliving a fast navigation — a single message can still trail one screen into the next by up to its duration, which is normal Material behaviour but was part of what Brian noticed.

**Option B**: **Drop the success snackbar entirely** — the prompt text visibly changes, and the re-roll counter decrements, so the confirmation is redundant.
  - *Pros*: Nothing to queue, nothing to clear, nothing to leak across screens; removes an interruption from the one screen where the player is trying to write; the error snackbar stays, which is the case that actually needs words.
  - *Cons*: Loses the confirmation for a re-roll that happens to return a similar-looking prompt, where the change may not be obvious; a silent success can read as a dead button on a slow connection.

**Option C**: **Clear on screen teardown** — add `ScaffoldMessenger.of(context).clearSnackBars()` to the craft screen's `dispose()`, in addition to Option A.
  - *Pros*: Guarantees no craft-screen message ever appears on the vote or waiting screen, which is the specific complaint; a cheap belt-and-braces on top of Option A.
  - *Cons*: `dispose()` cannot safely use `context` for an inherited lookup, so the messenger must be captured earlier (in `didChangeDependencies`), which is a subtle pattern that reads as a mistake to the next person; would also swallow a legitimate error snackbar raised during submission just as the screen tears down.

Your selection: Proceed with Option A.

---

### Issue 128: Nothing tells the table when a player leaves or times out
**Status**: ⚠️ Confirmed Unresolved — **user request from the build-4 playtest.** Departures are handled silently: `handleDisconnect` deletes the player document and rewrites `cards`, `resolutionOrder` and `totalPlayers` (`functions/src/index.ts:1176`), and the client's players listener simply rebuilds with one fewer avatar (`lib/services/game_service.dart:444`). Remaining players see the roster change with no explanation, which reads as a glitch — and if the departure drops the table below three, the game ends with no stated reason.

The client already has the raw material: `_players` is diffed on every snapshot, and the departed player's name is in the previous list.

**Option A (recommended)**: **Diff the players list client-side and show one snackbar per departure** — in the players listener, compare the incoming ids against the previous ones and, for each id that vanished, show `"<name> has left the parlour."`; clear before showing (see Issue 127) and cap the duration at ~2 seconds.
  - *Pros*: Needs no server change and therefore no deploy, so it reaches testers with the next client build; the name is available locally because the previous snapshot still holds it; works identically for voluntary leaves, host kicks and presence evictions, because all three end in the same document deletion.
  - *Cons*: Cannot distinguish *why* someone left — "left" will be shown for a player who was evicted for being away, which is arguably the wrong word for someone whose phone just locked; every client computes this independently, so a player who joins late and has no previous snapshot sees nothing (correct, but worth stating).

**Option B**: **Have the server publish a departure event and render that** — write a short-lived `lastDeparture: { playerId, name, reason, at }` field on the room in `handleDisconnect`, and have clients show a snackbar when it changes.
  - *Pros*: Carries the *reason*, so "left the game" and "lost connection" can read differently, which is what makes the message actually useful; one authoritative event means every client shows the same thing at the same time; the same field can later drive a rejoin prompt.
  - *Cons*: Requires a server change and a deploy, so it does not reach the current build; needs care to avoid re-firing on every unrelated room update (clients must compare `at`, not presence of the field); adds a field to the room document that has no reader if the client is old.

**Option C**: **Show it in the roster rather than as a snackbar** — grey the departed player's avatar with a "left" label for a few seconds before removing it.
  - *Pros*: Non-interrupting, and it puts the information exactly where the player is already looking when they notice someone missing; no snackbar queue to manage.
  - *Cons*: The player document is deleted server-side, so the client must retain a tombstone locally and time it out — new state to manage in `GameService` that has no other purpose; easy to miss entirely on the phases where the roster is not on screen.

Your selection: Proceed with Option A.

---

### Issue 129: No screen explains what the player is actually trying to do
**Status**: ⚠️ Confirmed Unresolved — **user request from the build-4 playtest.** The three play screens state the mechanic but never the goal. The craft screen shows the prompt and a `'Dip the quill…'` hint (`lib/screens/phase2_craft.dart:521`) with no line distinguishing "write something true about you" from "write something that sounds like them". The vote screen offers the grid with no note that talking is allowed. New players learn the objective by losing a round.

**Option A (recommended)**: **One italic line under the prompt on each of the three screens**, phrased for the phase:
  - Truth: *"Write something true about you — the more surprising, the better. Others must be able to believe it."*
  - Forgery: *"You are writing as <name>. Make it sound like something they would say, so people pick yours."*
  - Vote: *"Talk it out — discussion is part of the game."*
  - *Pros*: Costs one `Text` widget per screen and no new state; the forgery line can name the target from `currentCardAssignments`, which is the single most useful word in it; small enough to land in one commit with a widget test per screen asserting the line is present.
  - *Cons*: Three more strings competing for vertical space on the screens that already had clipping issues at 320 pt (Issues 114, 119) — each needs checking at the narrow widths; experienced players read the same sentence every round forever.

**Option B**: **Show the line only for the first round, then hide it** — gate on `currentRound == 1`.
  - *Pros*: Teaches new tables without nagging returning ones; frees the vertical space for later rounds, where clipping risk is highest because answers are longest.
  - *Cons*: A player who joins at round 2, or who was away for round 1, never sees it — and mid-match joins are exactly the case Issue 123 is about; "first round" is not the same as "first game", so a table on its third match still gets taught.

**Option C**: **A one-time rules card before the first truth phase** — a dismissible full-screen explainer covering all three phases at once.
  - *Pros*: Explains the arc of a round as a whole, which no per-screen line can; dismissed once and never seen again, so it costs returning players nothing; a natural home for the scoring rules, which are currently explained nowhere.
  - *Cons*: A wall of text before the game starts is the thing party-game players skip; needs `SharedPreferences` persistence and therefore a decision about whether "seen" is per-device or per-room; delays the first round, which is when a new table's attention is highest.

Your selection: Proceed with Option A.

---

### Issue 130: Timers should default to off, and their length should be configurable when on
**Status**: ⚠️ Confirmed Unresolved — **user request from the build-4 playtest.** Timers currently default to **enabled**: `isTimerDisabled` defaults to `false` in all three places that declare it — `lib/models/game_state.dart:69` and `:182`, and `functions/src/index.ts:365` (`createRoom`) and `:1731` (`updateLobbySettings`). Durations are hardcoded server-side and not configurable at all: truth `60000` (`index.ts:668`, `:1231`, `:1870`), forgery `60000` (`:1309`), vote `45000` (`:1310`), resolution `45000` (`:1801`).

Two changes are being asked for, and they are independent: flipping the default, and making the duration a lobby setting. The default flip is unambiguous. **The configurable duration is where the decision is** — the phases currently have three different lengths, so "how long the timer should be" has to resolve to something.

**Option A (recommended)**: **One host-set duration that scales all phases** — the host enters a number of seconds (default **60**, range 15–300) that becomes the *truth* duration; forgery uses the same value and vote uses 75% of it, preserving today's 60/60/45 proportions.
  - *Pros*: One number is what was asked for and one number is what a host can reason about mid-party; keeping the proportions means the vote phase does not become as long as the writing phase, which would drag; the existing constants become the defaults, so an untouched setting reproduces today's behaviour exactly.
  - *Cons*: A host who wants a long writing phase and a snappy vote cannot express that; the 75% rule is invisible in the UI, so a host setting 60 and seeing a 45-second vote timer may think it is broken unless the label says so.

**Option B**: **Per-phase durations** — three fields in the lobby: write, forge, vote.
  - *Pros*: Complete control, and it matches how the server already models the three durations separately; no hidden derivation to explain.
  - *Cons*: Three numeric fields in a lobby that already has deck selection, round count, forgery count and two switches — the lobby is the screen that has produced two overflow bugs at narrow widths (Issues 114, 119); most hosts will change one field and leave the others, producing lopsided rounds.

**Option C**: **Named presets instead of a number** — Relaxed / Standard / Quick, mapping to fixed triples.
  - *Pros*: No numeric input to validate, no keyboard on the lobby screen, and no way to enter a hostile value like 3 seconds; three tap targets fit the lobby's existing visual language better than a text field.
  - *Cons*: Does not answer the request as asked (the user asked for seconds); a host who wants 90 seconds cannot have it; adds a concept that must be explained where a number would not.

**All three options share the same default flip:** `isTimerDisabled` becomes `true` at all four declaration sites, so a new room starts untimed and the duration setting only appears once the host turns timers on.

Your selection: Proceed with Option A.

---

### Issue 131: The keyboard's return key inserts a newline instead of submitting
**Status**: ⚠️ Confirmed Unresolved — **user request from the build-4 playtest.** The answer field at `lib/screens/phase2_craft.dart:495` sets `maxLines: 3` and specifies **no** `textInputAction` and **no** `onSubmitted`. With `maxLines > 1`, Flutter gives the field a newline return key, so pressing it adds a line break; the player must dismiss the keyboard and scroll to reach `SUBMIT DOSSIER`. On a small phone with the keyboard up, that button is below the fold.

The trade-off is real: `maxLines: 3` exists so a 100-character answer is visible while being written (the same 100-character bound the vote grid is sized for, Issue 119). Making return submit means giving up multi-line entry, or overriding the key while keeping it.

**Option A (recommended)**: **`textInputAction: TextInputAction.done` with `onSubmitted` wired to the existing submit handler**, keeping `maxLines: 3` for display.
  - *Pros*: The return key becomes a labelled **done** key on iOS, so the affordance is visible rather than something to discover; the field still *wraps* to three lines as the answer grows, which is what `maxLines` is actually doing here — players are not typing deliberate line breaks in a one-sentence answer; reuses the submit path, so the 100-character guard and the busy-state disabling both still apply.
  - *Cons*: A player genuinely wanting a line break cannot insert one; on some Android keyboards the action key can be replaced by the IME regardless of what the field asks for, so this cannot be the *only* way to submit — `SUBMIT DOSSIER` must stay.

**Option B**: **Keep the newline key and make the submit button reachable instead** — pin `SUBMIT DOSSIER` above the keyboard with a `viewInsets`-aware bottom bar.
  - *Pros*: Preserves multi-line entry; fixes the underlying complaint (the button is unreachable) rather than routing around it; benefits every player, including those who never think to press return.
  - *Cons*: Does not do what was asked; a pinned bar competes for space on the screen where the keyboard already takes half the height; needs layout work at the narrow widths that have repeatedly produced overflow bugs here.

**Option C**: **Both** — Option A's done key *and* Option B's pinned button.
  - *Pros*: Fastest for players who press return, reachable for players who look for the button; no single point of failure if an IME ignores the requested action.
  - *Cons*: Two changes to the most-used screen in one wave, doubling the surface to validate; the pinned bar's value drops a lot once return works, so most of the cost buys little.

Your selection: Proceed with Option C.

---

### Issue 132: Players do not realise the vote options scroll, and vote on the two they can see
**Status**: ⚠️ Confirmed Unresolved — **user request from the build-4 playtest.** `lib/widgets/card_grid.dart:108` renders a `GridView.builder` with `crossAxisCount: 2` in portrait and `childAspectRatio: 1.1`, inside the vote screen's `SingleChildScrollView` (`lib/screens/phase3_vote.dart:439`). With the prompt, the target's name and the timer above it, a 4-option card puts the second row at or below the fold on a short phone — and there is **no scrollbar, no fade, and no partial row peeking**, because a 2-column grid with an even option count lands rows flush. A player who sees two square cards has no cue that two more exist. At least one playtester voted believing there were only two options.

**Option A (recommended)**: **One option per row** — switch the portrait layout from a 2-column grid to a single-column list of full-width rows.
  - *Pros*: A full-width row is much shorter than a square card, so more options fit above the fold in the first place; any row that is cut off is *visibly* cut off, which is the cue that is missing today; wide short rows suit the content — these are sentences up to 100 characters, and `AutoSizedAnswerText` (Issue 119) can then use a far larger font because it has width to work with, which also helps the truncation problem that keeps recurring; removes `childAspectRatio` tuning, a recurring source of narrow-device bugs.
  - *Cons*: With 5–6 options the list itself gets long, so scrolling is still required — this makes it *obvious*, not unnecessary; the square-card look is part of the parlour aesthetic and full-width rows change the screen's character; `card_grid.dart` is shared with any other grid usage, so the layout change needs to be scoped to the vote screen or applied deliberately everywhere.

**Option B**: **Keep the grid and add scroll affordances** — a bottom fade-out gradient while more content exists, an always-visible `Scrollbar`, and an "N options — scroll for more" caption above the grid.
  - *Pros*: Preserves the current look exactly; the caption states the option count, which removes the ambiguity even for a player who never scrolls; a fade plus a count is a well-understood pattern and needs no layout re-tuning.
  - *Cons*: Three affordances stacked on one screen is a lot of chrome for one problem; a fade is easy to miss on a dark parchment background, and this is precisely the sort of "looks fine to me" fix that a widget test cannot falsify — it needs a person on a short phone to confirm.

**Option C**: **Size the grid to fit — never scroll** — shrink the tiles so all options always fit the viewport.
  - *Pros*: Eliminates the problem definitionally; no affordance needed because there is nothing below the fold.
  - *Cons*: Directly fights Issue 119 — tiles that shrink to fit six options on a 320 pt screen force the 100-character text below its readable floor, which is the truncation complaint that has now been filed twice; trades a discoverability bug for a legibility bug.

Your selection: Proceed with Option A.

---

## 2. Lessons that still bite

These are kept because each one describes a trap that is **still live in the codebase** — not because it is interesting history. Each points at the contract that now owns the detail.

### Code & architecture traps

Properties of this codebase that have each cost a cycle. They are not style preferences — every one of them shipped a defect.

#### 2.1 `null` is not "absent" across the Dart ↔ TypeScript boundary

Dart sends an omitted optional as `null`; TypeScript's `!== undefined` guard treats that as a real value and writes it. This erased lobby settings and made the game unstartable (Issue 31). **Clients must omit keys rather than send null; callables must guard with loose `!= null`, never a falsy check** — `false` and `0` are legitimate values. Full contract: **`design_database_and_security.md` §7**.

#### 2.2 The test harness has four structural blind spots

Each has hidden a real bug. None is a flaw to fix — they are limits to design around:
- **The emulator suite is written in TypeScript**, so an omitted key genuinely *is* `undefined` there. It cannot produce the payload the Dart client actually sends. Issue 31 lived behind this.
- **Client tests use a fake Firestore that does not enforce `firestore.rules`**, so non-host writes and `authUid` checks are never really exercised. Use real simulator clients for anything that must be correct — bots are server-seeded documents and do not exercise the client path at all.
- **`Image.asset` loads no bytes under `flutter test`.** `find.byType(Image)` counts widgets whether or not art exists, and a golden render of the mascot comes out blank. Verify art by decoding the PNG (`test/helpers/png_decoder.dart`) or on a simulator.
- **Bare `flutter analyze` reports ~678 errors** from vendored plugin source under gitignored `build/`. Always scope it: `flutter analyze lib test`.

#### 2.3 Stream-rebuild guards are load-bearing

Firestore streams rebuild constantly. Every animation, sound and mascot pose is gated behind a **once-per-event key** (the `_advancedStateKeys` pattern; `_playedRevealForTargetId`; `_knownPlayerIds`). Remove one and the effect re-fires on every tick. A missing key is invisible in code review and only shows up on device — which is why Issue 34 makes the key a required argument.

#### 2.4 Validate type and range before comparing

`3 <= null` is `false`, so a range check silently passes and the function returns an empty result far from the cause. Reject nonsense input outright and throw a readable `HttpsError`, not a raw `Error` — raw errors flatten to `INTERNAL` and tell the player nothing. Detail: **`design_rotation_engine.md` §5**.

#### 2.5 `IconData` is a `final class`

`phosphor_flutter` extends it and therefore **cannot compile** on this SDK. Proven twice. The app vendors the Phosphor Light font directly instead. Detail: **`design_ui_direction.md` §7**.

#### 2.6 Everything mutating goes through a Cloud Function

Clients read Firestore streams and write nothing to rooms; `firestore.rules` denies it. Transactions read before write. Detail: **`design_database_and_security.md`**.

#### 2.7 Widget tests on animated screens hang without `accessibleNavigation: true`

Nine widgets in the lobby tree drive `AnimationController.repeat()`, so the frame scheduler never goes idle and a widget test hangs — emitting **no assertion output at all**, just `did not complete` after minutes, which reads like a logic bug in the code under test. Wrap the screen under test in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)`: `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation` (`lib/theme/app_motion.dart:11`), so the flag puts every animation on its static path. Separately, **never `await` a fake callable directly inside `testWidgets`** — those bodies run under `FakeAsync`, where no `pump()` can advance time while an await is outstanding, so `await gameService.createRoom(...)` deadlocks; wrap it in `tester.runAsync`. **`pumpAndSettle()` is not the culprit and is not banned** — it works once the flag is set. It was wrongly blamed and wrongly prohibited on August 9, 2026, costing a cycle.

#### 2.8 A counter placed after an early return counts only some paths


`test/fake_functions.dart` incremented `getMyOptionIdCallCount` **inside the default branch, below the `overrideHandler` early return** — so every call made through `overrideCallable` was invisible to it. No test had noticed, because no test had yet tried to count overridden calls. **Instrumentation has control flow too: put a counter at the entry point, not beside the work you happen to be looking at**, or it silently measures a subset. Discovered while fixing Issue 92, whose new assertion is impossible without it.

#### 2.9 A font glyph can be decoded — "unverifiable without a simulator" was wrong

`Phosphor-Light.ttf` has a `post` table at version 3.0, so it carries no glyph names and a codepoint cannot be looked up by name. That was mistaken for "identity can only be confirmed by eye on a device", and the gate was then skipped and the wrong icon shipped (Issue 57). **The outlines are decodable in pure Python**: parse `cmap` → glyph id (id `0` is `.notdef`, i.e. tofu), then `loca`/`glyf` → contours, and plot the contour points as ASCII. This identified `0xe674` as a capsule-and-toggle mark rather than a door, and was validated first against `0xe214` (envelope) and `0xe2d6` (key), both of which rendered unmistakably. **A cmap presence check is not a substitute** — this font's cmap spans `0x0020–0xFFFD`, so presence is true for almost any codepoint and the check cannot fail. Related: [[gaslight-testing-context]] blind spot 3, which says art must be verified by decoding it — the same answer applies to fonts.

---
### Verification & evidence discipline

How work gets proved here. **Every entry below is a case where a green suite, a passing test or a confident report was wrong** — these are the failure modes that survive good code.

#### 2.10 Measure; do not estimate, and do not trust a test's name

- A layout overflow estimated at ~275 dp measured **593 dp**.
- A mascot shipped at **1.02:1** contrast — invisible — with a fully green suite.
- A test titled *"…rim contrast >= 4.5:1"* asserted only that a file was non-empty. **Read the assertion, not the title.**

#### 2.11 "Verified in source" is not "shipped" — check the deploy, not the diff


Issues 71, 72 and 76 were each read in source, confirmed correct, and moved to Resolved. All three were still broken for players, because the commits containing them were never deployed and nobody ever asked production what it was running. A source-verified claim and a shipped fix are different facts, and this file spent three cycles conflating them. **`./scripts/check_deploy_fresh.sh` belongs in the battery as a mandatory gate**, verifying that all 14 functions and security rules strictly postdate the latest tree commits. See Issues 77 & 81.

#### 2.12 An observation that cannot be traced to a tool result is not an observation


The August 13 playthrough report quotes 18 prompts from a 12-prompt deck, none of which exist anywhere in the repository. It is fluent, specific, internally consistent, and wrong — and it sat inside a document whose other blocks are genuinely good. **Verbatim-looking text is not evidence of verbatim capture.** The cheap defence is mechanical: every quoted game string must be findable in source with `grep -F`. Where it cannot be, the assertion is NOT RUN. See Issue 82.

#### 2.13 Traceable quotes do not make a report arithmetically sound


Fixing §2.12 worked: the August 14 re-run's quotes are all real, checked mechanically. The next defect moved one level up — **the numbers between the quotes.** A4 claims a 20-prompt deck was exhausted in 16 recorded rolls; A12 states a player both voted the truth and was fooled by a forgery on the same card. Each individual string is genuine; the arithmetic joining them is not. **Traceability catches invention. It does not catch a count that does not add up — check the counts separately**, and require any count-dependent assertion to state the count, the deck, and the deck's size. See Issue 83.

#### 2.14 A verdict line can name a method the block has no data for


A4 now reads `PASS (… + Marionette Live Session)` and names two room codes. Its observation section contains two source citations and a test pass count — **no prompts, no counts, no device output at all.** Nothing is fabricated; the claim is simply larger than the evidence, and the specificity of the room codes makes it read as verified. **Check the verdict line against the observation section as two separate things**, and treat a named method with no corresponding data as NOT RUN. See Issue 89.

#### 2.15 A forward reference survives a renumber; the promise it made does not


A4 was correctly marked NOT RUN with its gap stated honestly and *"Queued for re-verification in S7 (Assertion A20)."* The S7 list was then renumbered during the run, A20 became a different assertion, and A4's pointer was never repointed. **The document now reads as though the gap is covered, and cites evidence about something else.** Nothing lied; a cross-reference went stale, which is indistinguishable from a lie to the next reader. **Whenever an assertion list is renumbered, grep for inbound references and repoint them in the same pass** — the same rule this project already applies to guide section numbers, arriving here by a different route. See Issue 88.

#### 2.16 A test can satisfy a spec's words while testing nothing


The X1 spec said: throw for a card, then fetch **that same card** and assert it is not permanently blocked. The implementation threw on `card_a` and fetched `card_b` — same shape, same assertion, zero coverage. Deleting the `finally` it exists to guard leaves the suite green. **The spec named the right thing and the reviewer had no way to see the substitution from a passing run**, because a passing test looks identical either way. **The only defence is the standing rule applied to the test itself: remove the guard, watch the test fail.** That step was performed for the leave-control guard two waves earlier and skipped here. See Issue 92.

#### 2.17 A documented invariant with no test behind it is a wish


`design_database_and_security.md:35` states "never send other players' authorship to the client." Issue 98 is that exact invariant being violated by `castVote` — the one function privileged to read the default-deny `sealed` document — which republished its contents into a world-readable one. The invariant was written down, believed, and never asserted anywhere. **Every invariant in the design docs should have an assertion behind it, in the suite that can actually observe it**: rules go in `functions/test/rules.spec.ts`, callable authorization in `functions/test/game_e2e.spec.ts`. A Dart widget test can never prove either — `test/fake_functions.dart` does not enforce `firestore.rules`.

#### 2.18 When a design doc calls something a secret, grep for where it is published


`design_database_and_security.md:69` treats `playerId` as the credential that makes seat recovery safe. The player document ID **is** that `playerId`, and `firestore.rules:18` makes the collection world-readable — so the secret is listed next to the lock (Issue 97). The "UUIDs are unguessable" precedent gave false comfort: **the UUID was never guessed, it was published.** Whenever a document ID doubles as an authorization credential, that is the bug.

#### 2.19 A fix can be correct while its design doc still describes the vulnerability


SEC1 and SEC2 shipped correctly, with tests and a verified deploy — and `design_database_and_security.md` §3 still read *"Room documents: `allow read: if true`"*, the exact rule that had just been retired for granting collection enumeration, while the seat-token mechanism that fixed the HIGH-severity takeover appeared **nowhere**. Four of the six items updated a design doc; the two most important did not. A future agent reading §3 would have found a documented invitation to "simplify" the split verbs back into the vulnerability. **Closing a security issue means updating the document that described the old behaviour as intended, not only the one describing the new behaviour as delivered** — and the doc most likely to be stale is the one that made the vulnerable design sound deliberate. Grep the design docs for the code you just deleted.
---

#### 2.31 A constant duplicated across the client/server boundary makes a server-side change inert

`PRESENCE_STALE_MS` was raised from 120 s to 600 s on the server (Issue 120 / O5) while `lib/services/game_service.dart:20` kept `presenceStaleMs = 120000`. The client is what *initiates* eviction, and the server's threshold gated only *who may ask*, never *whether the deletion happens* — so the effective window never moved. Nothing in the battery compares the two numbers, and nothing ever will unless a check is written for it.

**Two rules follow.** When you change a constant, **grep the other language for its value as a literal** — `120000`, `120_000`, `Duration(minutes: 2)` — not just for its name, because the mirror rarely shares the name. And when a threshold is meant to be an invariant, **the server must enforce it on the action, not on the caller's identity**; a check that only decides authorization can be walked around by any authorized caller. See Issue 123.

#### 2.30 A test that asserts a constant equals its own literal cannot fail

O5's entire emulator test was `expect(PRESENCE_STALE_MS).to.equal(600_000)`. It passed, it will always pass, and it says nothing about whether a player who has been away for 150 seconds survives — which is the only thing Issue 120 asked for. Compare against the probe that actually settled it: set a player's `lastSeen` 150 s into the past, call `handleDisconnect` **as the host**, and assert the player document still exists.

**A constant's value is not behaviour.** Assert the behaviour the constant is supposed to produce, through the same entry point a client uses. This is §2.16 ("a test can satisfy a spec's words while testing nothing") in its purest form, and it recurred within two days of that lesson being written.

#### 2.29 Never accept Xcode's "Update to recommended settings" on this project

Xcode offers a **Perform Changes** dialog for recommended project settings. **Accepting it breaks the iOS build**, and the failure is not obvious from the dialog — the offending item is **Enable User Script Sandboxing** (`ENABLE_USER_SCRIPT_SANDBOXING`).

This project has **four shell-script build phases**: two running Flutter's `xcode_backend.sh` (`build` and `embed_and_thin`) and two CocoaPods checks that diff `Podfile.lock` against `Manifest.lock`. Sandboxing restricts what those scripts may read, and Flutter's own build artefacts fall outside the permitted set. Verified empirically on **August 25, 2026** by enabling the flag in all three build configurations and building:

```
Error (Xcode): Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter
Error (Xcode): Sandbox: dartvm(...) deny(1) file-read-data .../native_assets/objective_c.framework/objective_c
Error (Xcode): Sandbox: dartvm(...) deny(1) file-read-data .../.last_build_id
Failed to build iOS app
```

Reverting the flag restored a clean `✓ Built build/ios/iphoneos/Runner.app (49.9MB)`.

**So: decline the dialog.** The other items in it (asset symbol extensions, the quoted-include warning, string catalog symbols) are harmless but not worth the risk of accepting the batch, since Xcode applies them together. If a specific one is ever wanted, set it alone and rebuild before committing. **Xcode will keep offering this** — the answer stays no until Flutter's build phases declare sandbox-compatible inputs and outputs.

*Unrelated but worth knowing while in here:* every `flutter build ios` rewrites `ios/Runner.xcodeproj/project.pbxproj` (CocoaPods rewrites `objectVersion`), so a build dirties the tree on its own. That churn is pre-existing and not a change anyone made.

#### 2.28 A screenshot that looks wrong may be an undocumented design rule

W20's evidence showed **THE DUPLICITOUS — "most players deceived" — awarded to Bob with 1 deception, while the standings in the same frame showed Alice on 2.** That reads as a plain scoring bug, and `design_scoring_and_ui.md` supported that reading: it defined the honor as "highest `playersDeceived`, ties broken by score" and said nothing more.

The code disagrees. `game_over_screen.dart:156-190` seeds an `assignedIds` set with the Mastermind and picks every later honor **only from players not yet assigned**, so honors deliberately spread across the table instead of stacking on one strong player. Alice had already taken The Mastermind, so The Duplicitous went to the best of the rest. **Correct, deliberate, and undocumented** — a false bug report was one step away.

**The rule: when evidence contradicts a design doc, read the code before filing.** The doc is a summary and can be *incomplete* rather than wrong, and an omitted constraint looks identical to a defect from the outside. When you find one, **fix the doc** — that omission is now written into `design_scoring_and_ui.md` Clarification 2 with the W20 numbers as the worked example, so the next reader does not re-run this.

#### 2.27 The gate never checked that the evidence file exists

Completing the family: **2.25** found that `check_playthrough_evidence.sh` bounds the *form* of evidence and not its content; **2.26** found that *updating* a block leaves its artefact behind; and this one is the floor beneath both — R3 matches the artefact **path string inside the block text** and **never stats the file**. Deleting a cited PNG therefore leaves the gate **green** while the evidence is gone, and a block citing a path that never existed passes just as cleanly.

So for most of this project's life the gate has been asserting that *a sentence mentions a filename*. That is worth remembering when reading any historical PASS: the artefact was required to be **named**, not to exist, not to be current, and not to agree with the claim. Rule **R5** (Wave L) adds the existence check; the other two remain the reader's job.

#### 2.26 A stale screenshot under new prose is indistinguishable from a fabricated one

Block **W14** claimed unobserved behaviour **twice**. The first time it described a "clipboard/fallback handler" that existed nowhere in `lib/`; that was corrected, and the correction said in as many words that the prose had overstated. Wave K then **overwrote the correction** with a new claim — a synthetic anchor download and a confirmation snackbar — while citing **the same PNG, dated before the feature was built**, whose visible snackbar still read `Sharing is only supported on mobile devices.`

Both times `check_playthrough_evidence.sh` passed, because R3 asks whether a screenshot **path** is present and cannot open the file. **The gate bounds the form of evidence, never its content** (§2.25) — and the second occurrence shows the sharper edge: *updating* a block is more dangerous than writing one, because the artefact silently stays behind while the sentence moves on.

**The rule: when a block's claim changes, its screenshot must change too.** Re-shoot the evidence under a **new filename** (reusing the old name hides the staleness from `ls` and from review), or downgrade the claim to what the existing image actually shows. Never leave an old image under a new sentence.

#### 2.25 The evidence gate proves an artefact exists, not that it agrees with the prose beside it

Web block **W14** claimed it had "verified share payload creation and clipboard/fallback handler execution on web", and its `Expected:` said the click "triggers share/clipboard action". Neither happens: `_shareCaseFile` returns early under `kIsWeb`, there is no clipboard path for the Case File at all, and **the very screenshot the block cited shows the snackbar `Sharing is only supported on mobile devices.`** The block passed `check_playthrough_evidence.sh` because R3 only asks whether a PNG path is present — it cannot read the PNG.

**So the gate bounds the *form* of evidence, never its *content*.** When verifying a playthrough, **open the artefact and check it says what the block says it says**, at least for any block whose claim you have a prior expectation about. Here the prior was concrete — `Share.shareXFiles` needs a `dart:io` temp file that cannot work on web — and it is exactly the block that turned out to overstate. A named mechanism that does not exist in the source (`grep -rn "Clipboard" lib/` returned only the room-code plaque) is the cheapest tell.

#### 2.24 A fake that models the CORRECT behaviour hides the bug better than a wrong one would

`test/fake_functions.dart` implemented `startGame` by reading `roomState.selectedDeckId` from the room document. That is the **right** design — it is what the server does *now*, after Issue 106. But the real server was reading `request.data.selectedDeckId`, so for as long as the two disagreed, **every outcome-based test drew from the correct deck and passed** while production drew from the wrong one. A fake that is subtly wrong gets noticed; a fake that is *better than production* is invisible, because everything it touches looks right.

**Two rules.** When a fake and its real counterpart resolve the same value from different sources, **that divergence is a bug in the fake even when the fake is more correct** — pin them together and add the real one's validation to the fake, so a test that violates the contract fails in the suite instead of in a friend's game. And when a defect lives in **what the client sends** rather than in what comes back, **assert the payload**: `lastCallParams` catches it, an outcome assertion never will. See [[testing-blind-spot-nonhost-writes]] and §2.2.

#### 2.23 A deploy filter can drop a required asset, and an SPA rewrite will hide that it did

The first Firebase Hosting deploy served a blank page. Cause: the hosting block's `"ignore": ["**/.*"]` — copied from Firebase's own template — matches any path segment starting with a dot, and **this app ships `.env` as a declared Flutter asset** (`pubspec.yaml`), so it builds to `build/web/assets/.env` and was silently excluded from the upload. `main.dart:32` calls `await dotenv.load()` **before `runApp()`**, so `main()` threw and Flutter never painted a frame.

**What made it hard to see:** the catch-all rewrite `{"source": "**", "destination": "/index.html"}` meant the missing file returned **HTTP 200 serving index.html**, not a 404. Every asset URL "worked". The give-away was that `/assets/.env` was **byte-identical to `/`** — same sha, same 7952 bytes. Reproduced locally by serving the build with only that one file removed: console showed `failed to fetch "assets/.env"` and an uncaught Dart exception, with the splash still spinning.

**Two rules.** **Never let a deploy-time filter decide which app assets ship** — check what the app actually loads at boot against what the filter excludes, and remember that a dotfile can be a required asset, not just editor cruft. And **a catch-all SPA rewrite converts every missing-file 404 into a 200**, so "no 404s in the network tab" proves nothing about a deployed SPA; compare a suspect asset's bytes against `index.html` instead. See [[gaslight-testing-context]].

#### 2.22 A tool catches what a careful reader misses — that is the point of building one

Two separate review passes read the playthrough report hunting for blocks that claimed PASS on source inspection. Between them they found **E10** and **E11**. `scripts/check_playthrough_evidence.sh`, run once against the same file, found **E10, E11 and E13** — a third instance nobody had noticed, in a block labelled *"extra coverage"* that both readers had skimmed as low-stakes. **A mechanical check does not get bored, does not assume a block is unimportant, and does not stop looking once it has found two.** When review keeps surfacing the same defect class, stop reviewing harder and write the check — and expect it to find more than you did on the very run where you validate it.

#### 2.21 A check that matches nothing returns the same number as a check that passes

§3.2 of the guide mandated `awk '/^\*\*Observed/,…' | grep -c "grep -"`, expecting `0`. It returned `0` — **because it matched zero lines.** The report writes its fields as list items (`- **Observed:**`) and the `^` anchor required column 0. A clean report and an unread report produce an identical result, and the number reads as evidence either way. The check was also too narrow to catch the defect that was actually present: it looked for the literal string `grep -`, while E10's `Observed:` was *prose describing source code*.

**Two rules follow.** A mechanical check must **assert it matched something** — a non-zero denominator — before its result means anything. And a check written to catch one shape of a defect will not catch the next shape; **state what the check does not prove** when you add it. See Issue 105.

#### 2.20 A `grep` is not an observation

The pre-demo playthrough answered *"what I observed, verbatim"* with `grep -Fn "THE RECORD OF TRUTH" lib/screens/phase2_craft.dart -> line 386` on every assertion. Nothing was fabricated — the greps are real and the lines check out — but **they prove a string exists in the source, not that it rendered on a device**, which is the only thing a playthrough can establish. The `grep -F` traceability rule (§2.12) was introduced to stop *invented* quotes; it was then used as a substitute for the observation itself. **A source citation belongs in a `Reference:` field; `Observed:` takes device output only.** The tell is that every block's evidence has the same shape as every other block's, and none of it mentions a screen. See Issue 102.

---

## 3. Resolved — index only

Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This is an index, not a record. **One heading, and only one — never add a second** (that is how this file reached 559 lines: each verification pass appended its own summary without removing the last, so Issues 93–95 appeared three times).

### Issues 65–112 — August 8 to 25, 2026

**47 items.** Full narratives are in `git log`; **the durable consequences live in the design docs**, and each row says which. This section is an index, not a record — if you need the reasoning behind a decision, the design doc has it and the commit body has the rest.

| Area | Issues | Where the surviving contract lives |
|---|---|---|
| **Security — access control** (`/rooms` collection enumeration; seat/host takeover via `joinRoom` re-binding on a world-readable `playerId`; seat tokens hashed into default-deny `sealed`) | 96, 97 | `design_database_and_security.md` §3, §5 |
| **Security — answer secrecy** (`castVote` laundering `answerAuthors` into the public room doc; reveal merging every card instead of the current one; forgery authorship exposed during the unmask window) | 98, 99, 100 | `design_game_state_and_models.md` §2; `design_scoring_and_ui.md` |
| **Security — debug surface** (debug callables reachable in production with no membership or host check) | 101 | `design_database_and_security.md` §7.1 |
| **`votes` contract** — redefined three times; the sentinel purge, then opaque option ids resolved server-side at reveal | 71, 78, 98 | `design_game_state_and_models.md` §2 — **carries the "broken three times, enumerate its readers" warning** |
| **Deploy discipline** — `predeploy` wired so a red suite blocks a deploy; then production ran stale code for two cycles anyway, until the written instruction was replaced with `scripts/check_deploy_fresh.sh` (three exit codes, epoch comparison, rules checked separately) | 65, 77, 81 | `design_database_and_security.md` §8 |
| **Lobby authority** — readiness gate on `startGame` with the host-exemption deadlock guard; host kick reusing `handleDisconnect` | 86, 87 | `design_game_state_and_models.md` §1; `design_database_and_security.md` §4 |
| **Mid-match departure** — in-game leave controls; the 3-player floor applied during play, not only at start | 85 | `design_game_state_and_models.md` §1 |
| **Own-answer lockout** — option id as authority, per-card text as fallback, never unioned; `getMyOptionId` and its client call discipline; cross-round `answerAuthors` map isolation without `{ merge: true }` | 90, 91, 92, 94, 117 | `design_scoring_and_ui.md` §3.2; `design_database_and_security.md` §2; `functions/src/index.ts` |
| **Reveal & unmask** — who may accuse vs who may be accused; the five-beat reveal and its deadline; server-published per-card `scoreDeltas` including unmask ±1 (Wave O / O2) | 79, 80, 113 | `design_scoring_and_ui.md` §3.3; `functions/src/index.ts` |
| **Prompts & decks** — per-player `seenPrompts` in `sealed`; exhaustion boundary and the `resource-exhausted` → SnackBar mapping whose fall-through is the failure mode | 67, 68, 69, 83, 88 | `design_prompt_system.md` §5 |
| **Answer integrity** — spurious `THE SOUL IS SILENT` placeholder; forgery author key derived server-side; forgery defaults and the 3-player floor as an independent guard; placeholder votes rejected and all-placeholder cards skipped server-side with sealed placeholder UI (72, 76, 118 / O4) | 72, 76, 118 | `design_game_state_and_models.md` §1–§2; `functions/src/index.ts`; `lib/widgets/card_grid.dart` |
| **UI surfaces** — dialog contrast (ratio-asserted, not string-asserted); error surfaces mapped on `e.code` and never interpolating the exception; busy states as a correctness guard because `createRoom` is not idempotent; flex/ellipsis on MATCH HIGHLIGHTS and Lobby custom prompts badge pills to prevent narrow-device clipping (84, 93, 95, 114 / O6); Raven mascot displayed on ballot-sealed waiting screen (116 / O7); dynamic text scaling in CardGrid (`AutoSizedAnswerText`) fitting 100-character answers across narrow viewports and accessibility text scales without truncation (119 / O8); read-only option grid with target truth label and server-side self-vote rejection for target during voting (121 / O9) | 84, 93, 95, 114, 116, 119, 121 | `design_ui_direction.md` §6; `design_scoring_and_ui.md` §3.2, §4; `lib/widgets/card_grid.dart`; `lib/screens/game_over_screen.dart`; `lib/screens/lobby_screen.dart`; `lib/screens/phase3_vote.dart`; `functions/src/index.ts` |
| **Debug controls & dead fields** — host debug controls cleaned up; reaction medallions removed with `lastReaction`/`lastReactionAt` deliberately retained in the model and rules to avoid a migration | 73, 74 | `design_database_and_security.md` §3 |
| **Standings & honors** — tabular-figure alignment; honors metrics | 75 | `design_scoring_and_ui.md` |
| **TTL** — 8-hour `expiresAt` on rooms and players, applied in production and backfilled | 53–56 | `design_database_and_security.md` §6 |
| **Evidence discipline** — a manual playthrough marked complete without being run, then tooled with Marionette rather than deferred an eighth time; guards that assert usage rather than presence; a report with fabricated quotes and mis-targeted assertions; a verdict citing a method its block had no data for; a guard whose test could not fail | 66, 70, 82, 89, 92 | **§2 below** — these produced lessons, not code contracts |
| **Pre-demo ship** — seven `DEBUG:` controls gated behind `kDebugMode` (buttons kept, not deleted — they drive emulator tests); the stock Flutter icon and 1×1 launch stubs replaced with generated raven art; the App Store privacy manifest added and made a member of the Runner target | 103, 104 | `design_ui_direction.md` §6; `design_database_and_security.md` §7.1–§7.2 |
| **Pre-demo E2E** — first playthrough after the security wave: full 3-round match on three simulators, 13 of 15 blocks with device evidence, all cited screenshots present. **Seat recovery after a force-quit device-verified for the first time.** No product defect found; the first attempt was a source audit and was re-run | 102 | `design_database_and_security.md` §5; `docs/playthrough_findings_marionette.md` |
| **Chosen deck ignored — every game played The Daily Grind** (`_selectedDeck` initialised once, read once, never assigned; `startGame` trusted the caller's deck over the room's). Fixed **A+C**: server resolves from `room.selectedDeckId` *and* rejects a mismatched claim with `invalid-argument`; dead field deleted; family-friendly toggle now writes through so it cannot desync the lobby from the room | 106 | `design_prompt_system.md` §2; `functions/src/index.ts:293`; `test/deck_selection_test.dart` |
| **Evidence mechanical gate & E10/E11 device verification** — `check_playthrough_evidence.sh` tool enforcing R1–R4 with 3 exit codes; E10 in-game leave auto-end verified on both remaining devices (`e10_p1_gameover.png`, `e10_p2_gameover.png`); E11 release build verified with zero DEBUG controls (`e11_release_lobby.png`); repointed dead citations to `functions/src/index.ts:986` | 105 | `docs/agent_execution_guide.md` §2–§3; `scripts/check_playthrough_evidence.sh`; `docs/playthrough_findings_marionette.md` |
| **Web E2E Playthrough (Wave I)** — Playwright automated harness (`test/web_e2e/`); I1 evidence gate widened with strict PNG requirement for W blocks; W1–W16 3-player match with falsification, truth, forgeries, voting lockout, unmasking, standings, GameOver, mid-match refresh restoral, case file share, console hygiene, and below-3 auto-end; W17–W19 responsive sweeps across mobile (375x812), tablet (768x1024), and desktop (1280x800) with 15 screenshots | 106 (Wave I) | `docs/playthrough_findings_web.md`; `test/web_e2e/`; `scripts/check_playthrough_evidence.sh` |
| **Prompt Source & Sampling (Wave J)** — resolved effective prompt source on `GameState` killing `"custom"` sentinel crash (109 / J1); custom game prompt drawing and re-rolls from players' contributed pool with self-author lockout (108 / J2); uniform re-roll sampling minus live in-play table cards (107 / J3) | 107, 108, 109 | `design_prompt_system.md` §3, §5; `functions/src/index.ts` |
| **Game Over Payoff & Web Download (Wave K & Wave O / O3)** — Standings + server-written match summary quoting real answers accumulated into `sealed/_summary` across rounds and published at game over with snapshotted display names (111 / K1, 115 / O3); Case File PNG direct downloads on web via Blob URL and synthetic anchor click (110 / K2) | 110, 111, 115 | `design_scoring_and_ui.md`; `lib/utils/case_file_saver_web.dart`; `functions/src/index.ts` |
| **Presence & Resume Lifecycle (Wave M)** — GameService `WidgetsBindingObserver` immediate `lastSeen` write and heartbeat restart on app resume (112 / M2). **Room code** displayed in the AppBar across Craft, Vote and Reveal (the half of 120 / O5 that did land). The 10-minute presence window is **NOT** resolved — see Issue 123 | 112 | `design_database_and_security.md` §4–§5; `functions/src/index.ts` |

> **The three highest-value things to know from this wave**, if you read nothing else: the `votes` field has been redefined three times and broken its readers twice (§2 and `design_game_state_and_models.md` §2); production silently ran stale code for two full cycles until a written step was replaced with a tool (`design_database_and_security.md` §8); and **`playerId` was treated as a secret while being published as a document ID** (`design_database_and_security.md` §5).

> **The three highest-value things to know from this wave**, if you read nothing else: the `votes` field has been redefined three times and broken its readers twice (§2 and `design_game_state_and_models.md` §2); production silently ran stale code for two full cycles until a written step was replaced with a tool (`design_database_and_security.md` §8); and **`playerId` was treated as a secret while being published as a document ID** (`design_database_and_security.md` §5).

---

### Issues 1–64 — May 24 to August 7, 2026

64 items. Full text is in `git log`; the durable consequences are in the design docs. Grouped by what they touched:

| Area | Items | Where the surviving contract lives |
|---|---|---|
| **Write architecture & multiplayer** — non-host writes blocked by rules, read-after-write transaction order, unhandled server errors, direct client writes in debug tools, full-object writes | Issues 1, 13, 14, 17, 18 + the May race/leak/transaction fixes | `design_database_and_security.md` |
| **Identity & reconnection** — device-stable `playerId`, seat re-binding, anonymous-auth loss, heartbeat volume, disconnect cleanup, host handoff | Issues 16, 36, 42, 15, 34, 35 | `design_database_and_security.md` §4–§5 |
| **Game-loop correctness** — score application on host override, timeout blank cards, inflated scores after disconnect, spectator miscounts, deterministic card resolution, reader re-indexing | Issues 26–35, 21 | `design_rotation_engine.md`, `design_scoring_and_ui.md` |
| **Scoring & honors** — saboteur "found the truth" bonus, metric-based end-game honors | Issues 30, 31 | `design_scoring_and_ui.md` |
| **Prompts & decks** — thematic decks, custom decks, the 3-prompt server cap, re-roll | Issues 22, 48, P4, P10 | `design_prompt_system.md` |
| **Duplicate answers** — Gemini replaced by a local lexical heuristic mirrored byte-identically on both sides | Decision 2 | `design_semantic_integrity.md` |
| **Secrets** — Gemini/Firebase key exposure in the client binary; keys moved to `.env`, Gemini removed entirely | Issues 3, 14 | §2.6 above; `.env` is gitignored and ships inside the IPA |
| **UI programme** — M1–M5 mobile-first, V1–V5 character work, U1–U8 UX, E7 sound | 49 + the M/V/U proposal sets | `design_ui_direction.md` §10 |
| **Icons & mascot** — hybrid icon system, the `final class IconData` blocker, vendored font, mascot redraw, hollow-body fill | Issues 23, 28, 29, 32, 33 | `design_ui_direction.md` §7 and the mascot block |
| **Lobby & house rules** — entry-form fit at 360×640, House Rules consolidation, non-host read-only, settings-wipe crash | Issues 24, 25, 27, 30, 31 | `design_ui_direction.md` §10; `design_database_and_security.md` §7 |
| **Test infrastructure** — emulator + rules unit suite, coverage gaps, real PNG decoding and contrast assertions | Issue 41, Tasks T1–T3 | §2.2 above |
| **Dependencies** — unused `cupertino_icons` removed; Phosphor font vendored | Tasks T2, Issue 29 | `design_ui_direction.md` §7 |

---

---

## 4. Deliberately not built — do not re-propose

These were designed, costed and consciously **not** selected. Their absence is a decision, not an oversight:

- **P7 — Confidence Wager** ("seal it in blood"): stake points on your own forgery.
- **P9 — House Cards**: per-round modifiers.
- **P11 — The Final Gambit**: a comeback round for trailing players.
- **Issue 30 Option C**: making `_familyFriendlyOnly` a synced house rule. It stays client-local.
- **Issue 34 Option C**: priority arbitration between mascot poses. Available as an upgrade if reveal-screen collisions prove annoying in practice.

---

## 5. Where the detail lives now

| Looking for | Go to |
|---|---|
| What to work on next, and how to validate it | `agent_execution_guide.md` |
| **Security rules, seat tokens, callable table & guards, debug isolation, TTL, deploy verification** | `design_database_and_security.md` |
| **The `votes` two-phase contract**, phases, 3-player floor (start *and* in play), readiness gate, card/player/game schemas | `design_game_state_and_models.md` |
| Scoring formulas, reveal beats, unmask bounds, single-card reveal scoping, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, motif, icons, mascot, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Prompt decks, custom decks, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Card passing, disconnect recalculation, input validation | `design_rotation_engine.md` |
| Duplicate-answer heuristic | `design_semantic_integrity.md` |
| Manual playtest journeys | `e2e_testing_journeys.md` |
| Playthrough evidence and its provenance | `playthrough_findings_marionette.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |
| Full history of any resolved item | `git log` |

**A note on keeping this file short.** It was 903 lines in August, cut to 559, and cut again to ~200 on August 21. Both times the cause was the same: **each pass appended its summary without removing the one it superseded** — Issues 93–95 appeared three times, and §1 accumulated six stacked banners. When you resolve something, move the durable consequence into the design doc above and leave **one line** here. If you are adding a paragraph to this file, ask first whether it belongs in a design doc instead.
