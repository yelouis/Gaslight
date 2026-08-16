# Engineering Issues & Decisions — Working Log

**What this file is:** the live queue of open issues, the decisions the user has selected, and the small set of engineering lessons that still affect how new code must be written.

**What this file is no longer:** a complete history. On **August 7, 2026** it was consolidated from 903 lines to this, because a working log that grows forever becomes context rot for the next agent — every line spent on a bug fixed in May is a line not spent understanding the system. The full record of all 64 resolved items lives in **`git log`**, and the *design consequences* of that work were moved into the relevant `docs/design_*.md` contracts (see §5). Nothing was deleted without a home.

**Bug-filing format** is in `.agents/skills/bug_documentation_guidelines/`. Open issues end with a `Your selection: _____` line; that line is the user's, and an agent must never fill it in on their own behalf.

---

## 1. Open & in-flight

**Queue Complete for all code, deployments, and verification — Issues 1–82 delivered, deployed, and independently verified (August 14, 2026).** Battery measured this session: `flutter analyze lib test` **0 errors** (25 warnings, 197 infos) · `flutter test` **130/130** · functions build clean · `npm --prefix functions test` **46/46** · `./scripts/check_deploy_fresh.sh` **0 (ALL 14 DEPLOYED FUNCTIONS FRESH)**.

**All outstanding items from this wave are closed:**
- **Issue 81 (Deploy Freshness Gate)**: All 14 Cloud Functions deployed to project `gaslight-46368` (`2026-08-14T17:47:40Z` - `17:48:24Z`). `./scripts/check_deploy_fresh.sh` added as a required battery gate in `agent_execution_guide.md`.
- **Issue 82 (Playthrough Findings Audit)**: Assertions A3, A4, A9, A10, and A13 re-run on live iOS simulators via Marionette MCP with authentic verbatim quotes verified in source via `grep -Fn`. A12 math formula corrected in place; A14 marked NOT RUN.
- **Issue 80 (Unmask Accuracy Reporting)**: Observed in live playthrough (A13.2) that a correct revenge unmask accusation reports `"SUCCESS! (+1)"` and increments the guesser's standings by `+1` (`▲+1`).

**Independent verification pass — August 15, 2026.** Battery re-measured, not copied: `flutter analyze lib test` **0 errors** (222 issues) · `flutter test` **130/130** · functions build clean · `npm --prefix functions test` **46/46** · `./scripts/check_deploy_fresh.sh` **exit 0**. Deploy confirmed against the live project: all **14** functions `2026-08-14T17:47:40Z`–`17:48:24Z`, rules ruleset `04:24:13Z`. **Issues 77, 80, 81 and 82 hold up under independent checking** — including all three of the freshness gate's exit codes, exercised rather than assumed, and a mechanical re-check of all 16 A3 prompt quotes against source (0 missing, against 18/18 missing on August 13). **One residue is open as Issue 83** and needs a selection: A4's exhaustion count does not reconcile with its deck, and A12's worked example contradicts itself.

**Manual testing, August 15, 2026** (three simulators, fresh debug install, production backend, deploy gate exit 0) found two issues, both needing a selection:

- **Issue 84** — the "End Voting?" host dialog renders its warning at a measured **1.02:1** contrast, so the text is present and invisible.
- **Issue 85** — there is no exit control anywhere in a match: no player quit, no host end-game. `handleDisconnect` already handles mid-game departure completely; nothing in the UI calls it between the lobby and Game Over. **This also corrects a claim I made in the August 15 verification pass** — A9/A10 did not test a mid-session leave flow, because none exists.
- **Issue 86** — the lobby computes `allNonHostsReady` and uses it to *decorate* the START GAME button rather than gate it; the server never reads `lobbyReady` as a condition at all.
- **Issue 87** — the host cannot remove a lobby player, although `handleDisconnect` already authorises exactly that.

**⚠️ Issues 86 and 87 must be decided together.** Gating the start on everyone being ready without giving the host a way to remove an idle player lets one AFK guest hold a lobby hostage.

**A pattern across 85, 86 and 87: the backend is ahead of the client.** `handleDisconnect` already handles mid-match departure and already authorises host-initiated removal; `lobbyReady` is already written, cleared and shipped in both models. Three of the last four reports are missing *affordances and gates*, not missing logic — which is the class of defect no server test and no source audit can see, and the reason the manual gate keeps earning its keep.

**Both were found in minutes by three simulators and a human. Nine automated gates and two driven playthroughs found neither** — one is a dialog only the host sees when advancing early, the other is the *absence* of a control, which no assertion written against the app's actual screens can see.

---

## ⚠️ Unresolved Issues & Suggestions

### Issue 86: Readiness decorates the START GAME button instead of gating it — and the server never checks it at all

**Status**: ⚠️ Confirmed in source, August 15, 2026. Found in manual testing.

The lobby has a full readiness mechanism and **uses it for styling only**. `lobby_screen.dart:452–456` computes exactly the value needed:

```dart
final nonHostPlayers = playingPlayers.where((p) => !p.isHost).toList();
final readyNonHostsCount = nonHostPlayers.where((p) => p.lobbyReady).length;
final totalNonHostsCount = nonHostPlayers.length;
final allNonHostsReady = totalNonHostsCount > 0 && readyNonHostsCount == totalNonHostsCount;
```

`readyNonHostsCount` is rendered as `(2/3 Ready)` at `:787`, and `allNonHostsReady` is read at **`:871` — in a `decoration`**, to glow the button. **It is never read in the `onPressed` gate.** That gate is `startWarning != null || _isStartingGame` (`:885`), and `startWarning` (`:443–450`) covers only three things: fewer than 3 active players, forgeries ≥ player count, and deck too small. **Readiness is not among them.** So the app counts who is ready, decides whether everyone is, lights the button up about it, and then starts anyway.

**The server does not check either.** `startGame` (`index.ts:229–266`) validates the caller is host, that `activePlayers.length >= 3`, and that `forgeriesPerCard` is sane. `lobbyReady` exists in the server's `PlayerState` (`index.ts:33`), is initialised `false` at `createRoom` (`:126`) and `joinRoom` (`:209`), and is reset to `false` after a start (`:426–428`) — **the server writes and clears the field and never once reads it as a condition.**

This matters beyond tidiness: **a client-only bound is not a bound** (§2 and this project's standing invariant). Fixing only the button leaves a modified client able to start regardless.

**⚠️ This issue and Issue 87 interact — decide them together.** Gating the start on everyone being ready, while the host has no way to remove an idle player, means **one AFK player can hold a lobby hostage indefinitely.** Option A below is only safe if Issue 87 also ships.

**Option A (recommended, paired with Issue 87): gate in both places**
- Server: `startGame` rejects with `failed-precondition` when any non-host active player has `lobbyReady !== true`. Client: add the condition to `startWarning` — e.g. `"Waiting on N of M players to ready up."` — so `allNonHostsReady` finally drives the gate it already decorates.
- Pros: the real bound lives on the server; the client explains it. Reuses a value that is already computed and already displayed, so the diff is small.
- Cons: requires a deploy, and is unsafe on its own — see the interaction note.

**Option B: client-side gate only**
- Pros: no deploy; ships in one edit by adding readiness to `startWarning`.
- Cons: not a bound. This project has already recorded "a client-only bound is not a bound" as a standing lesson, and Issue 72 was reopened for exactly this shape.

**Option C: leave it advisory — the glow is the signal, and the host may override**
- Pros: defensible as designed. A host often *must* start with someone idle, and today that is the only way to do it. Zero work.
- Cons: then the readiness toggle is decoration for players too, and the report will recur. If chosen, say so in `design_scoring_and_ui.md` so it stops reading as a bug.

Your selection: _____

**Falsifying validation for A or B:** a test where two of three players are ready and the third is not, asserting the start is refused — server-side by `failed-precondition` code (never the message), client-side by the button being disabled. **Over-reach guard in the same test:** with all non-hosts ready the start must still succeed, and **the host's own `lobbyReady` must not be required** — the host has no ready toggle, so requiring it would deadlock every lobby.

---

### Issue 87: The host cannot remove a player from the lobby

**Status**: ⚠️ Confirmed in source, August 15, 2026. Found in manual testing. **The backend already authorises this; only the affordance is missing.**

There is no kick control anywhere in `lobby_screen.dart`. A host faced with an idle, duplicate, or unwanted player has no recourse but to close the room and have everyone rejoin.

**`handleDisconnect` already permits it.** Its authorisation check reads (`index.ts:786–789`):

```ts
if (!callerPlayer || (!callerPlayer.isHost && callerPlayer.id !== disconnectedPlayerId && !isDead)) {
  throw new HttpsError("permission-denied", "Not authorized to trigger disconnect.");
}
```

A host is explicitly allowed to disconnect **any** player — the condition only rejects non-hosts acting on someone else's document. And the lobby path is the simple one: with no card dealt yet, `handleDisconnect` takes the `!hasCard` branch (`index.ts:804–807`) and just deletes the player document. **No new callable is needed; this is client-only work**, exactly like Issue 85's quit affordance.

**Option A (recommended): host-only kick in the lobby roster**
- Add a control on each non-host row in the lobby player list, host-only, with a confirmation naming the player. Call `handleDisconnect` with that player's id. Show the removed player the same entry-screen return the leave flow already produces.
- Pros: no backend change, no rules change, no deploy. Unblocks Issue 86 Option A, which is otherwise a hostage situation.
- Cons: the kicked player currently gets no explanation — they simply land on the entry screen. Worth a distinct message, which does not exist yet.

**Option B: kick available at any time, including mid-match**
- Pros: covers the AFK-mid-game case too, and `handleDisconnect`'s phase-aware branch already handles a mid-match removal correctly (Issue 85).
- Cons: a much bigger social and correctness surface — removing a player mid-round changes card assignments and scoring mid-flight. Wider than the report asked for.

**Option C: do not build; rely on closing and recreating the room**
- Pros: zero work; the close-room path exists and is verified.
- Cons: punishes every other player for one problem player, and leaves Issue 86 Option A unsafe.

Your selection: _____

**Falsifying validation:** a host calls `handleDisconnect` for another lobby player and the player document is gone; a **non-host** attempting the same call is rejected with `permission-denied` — matched on the **code**. The second half is the over-reach guard, and it is the one that matters: it is what stops a kick control from becoming a kick-anyone control.

---

### Issue 85: There is no way out of a game in progress — no player quit, no host end-game

**Status**: ⚠️ Confirmed in source, August 15, 2026. Found in manual testing. **The backend already supports this completely; only the affordance is missing.**

Once a match starts there is **no exit control of any kind** until the Game Over screen. Every in-game `AppBar` sets `automaticallyImplyLeading: false` and carries exactly one thing in `actions` — the countdown:

| Screen | Exit control |
|---|---|
| `lobby_screen.dart:460–469` | ✅ depart icon → `_confirmLeave` → `leaveRoom()` |
| `phase2_craft.dart:157–186` (truth / forgery) | ❌ `automaticallyImplyLeading: false`, actions = timer only |
| `phase3_vote.dart:113–140` (vote) | ❌ same |
| `phase4_reveal.dart:281–290` (reveal) | ❌ same |
| `game_over_screen.dart:289` | ✅ `RETURN TO LOBBY` → `leaveRoom()` |

**With `Disable Game Timers` on, `actions` renders `SizedBox.shrink()` — the in-game app bar is completely empty.** A player who wants to stop has no option but to force-quit the app and wait out the 30-second `lastSeen` timeout.

**The server side is already built and correct.** `gs.leaveRoom()` (`game_service.dart:303`) calls `handleDisconnect`, which is phase-aware: it deletes the player document, filters their card out of `room.cards`, prunes `readyPlayers` and `resolutionOrder`, decrements `totalPlayers`, reassigns the forgery rotation when the departing player was a holder, advances `currentReaderId`, and falls to `currentPhase: "gameOver"` when the resolution order empties (`index.ts:888–896`). **None of that is reachable from the UI mid-match.**

**The host case is genuinely absent, not just unwired.** `handleDisconnect` closes the room only when `phase === "lobby"` (`index.ts:794`). A host leaving mid-match is pruned like any other player and host transfers to the earliest-joined active player. **No callable ends a match on demand** — the only routes to `gameOver` are the round loop completing (`index.ts:1321`) and the resolution order emptying. So "host ends the game early" needs new server work; "player quits" does not.

**One open design question either way:** the 3-player minimum is enforced at `startGame` (`index.ts:260`) and **nowhere else**. If a player quits a 3-player match, two players keep playing a game whose scoring assumes at least three. Whatever is chosen below has to say what happens there.

**Option A (recommended): ship the player-quit affordance now; treat host end-game as a separate item**
- Add the same depart icon and `_confirmLeave` dialog from `lobby_screen.dart` to the three in-game `AppBar`s, wording the confirmation for a match in progress ("Your card and answers will be removed from this round"). Client-only — `leaveRoom()` and `handleDisconnect` already do the right thing.
- Pros: the larger half of the complaint, fixed with no backend change and no new failure modes, reusing a dialog that already ships and was verified in the last playthrough. It also makes the mid-session leave assertion *reachable* for the first time — see the correction below.
- Cons: the host still cannot end a match for everyone; they can only leave it and hand over.

**Option B: build both — quit affordance plus a host `endGame` callable**
- Pros: answers the whole report in one pass. A host-only `endGame` setting `currentPhase: "gameOver"` is a small callable next to `advanceToNextResolution`.
- Cons: a new mutating callable needs its own auth check, its own rules review, and a deploy; it is strictly more work than A and mixes a UI fix with a backend feature in one item, which this project has been bitten by before.

**Option C: quit affordance only, and record host end-game as deliberately not built**
- Pros: honest and cheap if you consider host-leaves-and-transfers sufficient — a host who wants out can already get out.
- Cons: with no end-game control, the last players in an abandoned match must each quit individually or wait for the 8-hour TTL.

Your selection: _____

**Whichever is chosen, the minimum-player question needs an answer**, and it is yours to make: end the match immediately when active players drop below 3, let it continue degraded, or convert the remainder to spectators.

---

### ⚠️ Correction to the August 15 verification pass — A9/A10 were not what I said they were

My previous pass recorded that the re-run *"A9/A10 now exercise the real mid-session leave flow."* **That is wrong, and Issue 85 is why: there is no mid-session leave flow to exercise.** The August 14 report tested the leave control in `THE PARLOR` lobby, which is the only one that exists, and it was right to. The error is mine — the D3 spec I wrote demanded *"with the game in progress, `tap(text: 'LEAVE')`"*, which is not something the app can do.

What A9/A10 actually verified stands and is worth keeping: the **lobby** leave and close-room flows, with `The host has left. This room has closed.` observed for the first time. **What has still never been tested is departure during a match** — and until Issue 85 ships, it cannot be. Do not re-file this as a playthrough defect; it is a missing feature, not a failed assertion.

---

### Issue 84: The "End Voting?" dialog renders its warning at 1.02:1 contrast — the text is there and cannot be seen

**Status**: ⚠️ Confirmed and measured, August 15, 2026. Found in manual testing on iPhone 17 Pro. **Reported as "no information on what proceed to reveal will do" — the information is present and invisible**, which changes what the fix is.

`phase3_vote.dart:167` already carries the warning the report asked for:

```dart
content: const Text('End voting now? Unvoted players will score nothing this card.'),
```

That copy is also **accurate** — `advancePhaseInternal`'s vote branch tallies `currentCard.votes` and a player with no entry receives no deltas and is not counted as fooled. Nothing fills a missing vote, unlike the answer path's `kMissingAnswerPlaceholder`.

**The defect is that it cannot be read.** Measured with the WCAG formula against the real palette values:

| Element | Colour on `parchment #F4EBD8` | Ratio | WCAG AA |
|---|---|---|---|
| **Content text** | `ivory #F5EEDB` | **1.02 : 1** | needs 4.5 : 1 — **fails by 4.4×** |
| **Title** | `brass #C9A24B` | **2.02 : 1** | needs 3.0 : 1 (large) — fails |
| `CANCEL` / `PROCEED` | `oxblood` | 9.67 : 1 | passes |
| *(what it should be)* | `ink #2C1E16` | 13.59 : 1 | passes |

Ivory and parchment differ by **fewer than 3 values per channel**. The buttons passing at 9.67:1 is why the dialog looks like a chrome-only prompt with no message.

**Root cause is the theme, not the screen.** `main.dart:73–84` sets `textTheme.apply(bodyColor: AppColors.ivory, displayColor: AppColors.brass)` — correct for the dark ground — while `ColorScheme.dark(surface: AppColors.parchment, onSurface: AppColors.ink)` makes Material 3 paint every `AlertDialog` on **parchment**. The explicit `textTheme` colours win over `onSurface`, so any bare `AlertDialog` gets ground text on a paper surface.

**There are exactly two `AlertDialog`s in `lib/`, and the difference between them proves the diagnosis.** `lobby_screen.dart:71` sets `backgroundColor: AppColors.groundRaised` and explicit styles (`brass` title, `AppTextStyles.bodyIvory` content) — it is readable, and its copy was quoted verbatim in the August 14 playthrough. `phase3_vote.dart:165` sets neither. **The next bare `AlertDialog` anyone adds will be invisible too.**

**Option A (recommended): add a `dialogTheme` to `ThemeData` so the default is correct, and tighten the copy**
- Give `ThemeData` a `DialogTheme` with `backgroundColor: AppColors.groundRaised`, `titleTextStyle` in `brass` and `contentTextStyle` in `ivory` — matching the lobby dialog, which is the established pattern and already an accepted equivalent. Then delete nothing: `lobby_screen.dart`'s explicit styles keep overriding harmlessly.
- Pros: fixes the screen, the class, and every future dialog in one place. The failing element becomes ivory on `groundRaised` rather than ivory on parchment.
- Cons: a theme-level change touches every dialog at once, so it needs a contrast assertion rather than a look-at-it check.

**Option B: style the `phase3_vote.dart` dialog explicitly, exactly as `lobby_screen.dart` does**
- Pros: smallest possible diff, zero blast radius, and it copies a pattern already shipped and verified.
- Cons: leaves the trap armed — the third `AlertDialog` will land on parchment again, and the theme still says one thing while every call site says another.

**Option C: keep the parchment surface and switch the text to `ink`**
- Pros: 13.59:1, the best ratio of any option, and parchment-with-ink is the app's own paper metaphor.
- Cons: dialogs would stop matching the dark chrome the rest of the game uses, and it needs per-dialog overrides anyway since the global `textTheme` would still be fighting it.

Your selection: _____

**Whichever is chosen, the copy should also say what "nothing" means**, since that is what prompted the report. Suggested: `End voting now? Players who have not voted will score nothing on this card, and their vote cannot be cast later.` Reword freely — but the sentence must state the consequence, not just the action.

**Falsifying validation required:** a widget test that renders the dialog and asserts the measured contrast between the content text colour and the dialog's actual background is **≥ 4.5:1**, using the WCAG helper in `test/helpers/png_decoder.dart`. Run it against today's code first and observe it report **1.02:1**. **A test that only asserts the string is present would pass today** — that is exactly the bug.

---

### Issue 83: A4's exhaustion count does not reconcile with its deck, and A12's observations contradict each other

**Status**: ⚠️ Confirmed by arithmetic against source, August 15, 2026. **This is a much smaller thing than Issue 82 and a different class of thing** — the quotes are real this time and I checked all of them. What does not hold is the counting.

**A4 — the deck does not add up.** A3 records **16** re-rolls on `the_daily_grind`. That deck holds **20** prompts (`lib/utils/prompt_decks.dart`). A4 then reports reaching `No more prompts left in this deck.` — but a player's own card consumes one prompt at deal, leaving **19** possible re-rolls, and 16 is three short of exhausting it. Either:

- the run performed more re-rolls than A3 lists, and A4's PASS rests on a count that was never recorded; or
- the exhaustion message fired **early**, which would be a real defect in `drawOneExcluding` / `seenPrompts` accumulation and is exactly the behaviour Issue 67 rebuilt; or
- A4 was run on a different deck than A3 — the guide specified `cah_dark_humor` (12 prompts) and A3 used `the_daily_grind` without recording the substitution as a deviation, so the two blocks may not describe the same session at all.

**Nothing in the report distinguishes these**, and the third possibility silently changes what A4 proves.

**A12 — the observations contradict each other.** The block reads: *"Alpha voted truth (+1), Bravo fooled Alpha (+1), Alpha fooled Bravo (+1)."* **Alpha cannot both vote the truth and be fooled by Bravo's forgery on the same card** — they are the same choice. A13 independently states Alpha *was* fooled by Bravo, so the "voted truth" clause appears to be wrong. The published standings (`Alpha: 2`, `Bravo: 1`) do not follow from the listed deltas under any reading I can construct. The corrected formula (`1`) is right; the worked example under it is not.

**Two spec items were also skipped**, both objective: the timestamp-free `firebase functions:list` table is still in the report header — the guide required replacing it, since it is the artefact that hid Issue 81 — and the header does not state which blocks were re-run versus carried forward from August 13, so the report's mixed provenance is invisible to the next reader.

**Option A (recommended): re-run A3+A4 as one continuous sequence on one named deck, and re-derive A12 from the same card A13 describes**
- Pros: settles the only question that matters — whether exhaustion fires at the right count — and it is a short run needing one device for A3/A4. A12 needs no new session, only re-reading A13's card and writing the deltas that actually follow.
- Cons: another Marionette session and rebuild for the A3/A4 half.

**Option B: treat both as reporting defects, correct the record, and re-verify at the next playthrough**
- Pros: free. If exhaustion is genuinely broken, `test/reroll_deck_exhaustion_test.dart` and Issue 67's emulator coverage would likely have caught it, so the reporting-error reading is the more probable one.
- Cons: "probably a reporting error" is precisely the reasoning that let Issues 71, 76 and 78 ship. The count is cheap to check and the conclusion is currently unfalsifiable.

**Option C: close A4 by unit test instead of by playthrough**
- Pros: assert exhaustion at the exact boundary — `n` distinct prompts then the `resource-exhausted` code — in the emulator suite, where the count is exact and free to re-run forever. Strictly stronger than one manual observation.
- Cons: does not exercise the client SnackBar path, which is the half A4 exists to cover; would need pairing with a UI check eventually.

Your selection: _____

**Regardless of the option chosen:** when an assertion depends on a count, the report must state the count, the deck, and the deck's size. A4 currently states none of the three.

---

## 🧪 Resolved Issues & Implementation Refinements

0c. **Issue 80: Revenge unmasking accuracy reporting and points attribution (Resolved — August 14, 2026)**:
   - **Problem**: Previous playthrough reports lacked concrete evidence that a correct revenge unmasking accusation was reported as successful and correctly credited to the guesser's standings.
   - **Solution**: Re-evaluated via multi-device Marionette playthrough (Assertion A13.2). Fooled player Alpha accused forger Bravo on Charlie's card. Observed `"REVENGE UNMASKING RESULTS"` (`phase4_reveal.dart:397`), `"Alpha accused Bravo — "` and `"SUCCESS! (+1)"` (`phase4_reveal.dart:421`), points chip `Alpha: +1` (`phase4_reveal.dart:475`), and immediate standings increment `Alpha: 1 (▲+1)`. Server-side guard rejection was verified via `game_e2e.spec.ts:1805` (`The card's target wrote the truth and cannot be accused of forgery.`).
   - **Verification**: Verified in live Marionette E2E session and recorded with exact line cross-references in `docs/playthrough_findings_marionette.md`.

0d. **Issue 81: Deploy freshness verification and automated battery gate (Resolved — August 14, 2026, `a428201`)**:
   - **Problem**: Backend transaction-ordering fixes in `1122f68` were committed after the last deployment, creating a deploy gap where production functions predated repository code.
   - **Solution**: Option A. Deployed all 14 Cloud Functions to project `gaslight-46368` (`2026-08-14T17:47:40Z` - `17:48:24Z`). Implemented `scripts/check_deploy_fresh.sh` comparing deployed functions' `updateTime` against the latest commit touching `functions/src`, and integrated the script as a mandatory gate in `agent_execution_guide.md` (§1).
   - **Verification**: `./scripts/check_deploy_fresh.sh` executed cleanly with exit code 0 (`ALL 14 DEPLOYED FUNCTIONS FRESH`).
   - **Independently re-verified August 15, 2026 — all three exit codes exercised, not just the passing one.** Exit **0** at `6cc6d69` (oldest deployed `createRoom` @ `2026-08-14T17:47:40Z`, epoch `1786729660`, against last `functions/src` commit epoch `1786683373`). Exit **1** on a throwaway commit touching `functions/src`, naming all 14 functions with per-function lag in seconds. Exit **2** via `GCLOUD_BIN_OVERRIDE=/nonexistent/gcloud`, printing "Could not verify deploy freshness" rather than passing. The script compares **epoch seconds**, checks the function **count** against an expected list of 14, and queries the Rules API with the required `x-goog-user-project` header. **The contract is now recorded in `design_database_and_security.md` §8** so a rewrite cannot quietly drop the exit-2 distinction.

0e. **Issue 82: Playthrough findings audit & unsupported assertion remediation (Resolved — August 14, 2026)**:
   - **Problem**: The August 13 playthrough report recorded assertions with fabricated prompt quotes (A3/A4), incorrect end-game leave flows (A9/A10), an erroneous arithmetic formula (A12), and overclaimed verification for unmasking and TTL (A13/A14).
   - **Solution**: Option A. Re-ran assertions A3, A4, A9, A10, A13 on real iOS simulators via Marionette MCP with authentic verbatim observations findable in source (`grep -Fn`). Corrected the A12 math formula to $\lceil (P-1)/(S+1) \rceil = 1$ in place. Marked A14 as NOT RUN. Updated `docs/playthrough_findings_marionette.md`.
   - **Verification**: Every quoted game string in `docs/playthrough_findings_marionette.md` verified against source with `grep -Fn`.
   - **Independently confirmed August 15, 2026 — the fabrication is genuinely gone.** All **16** prompts quoted in A3 were checked mechanically against `lib/utils/prompt_decks.dart`: **0 missing** (the August 13 report had 18 quotes and 18 misses). A9/A10 now exercise the real mid-session leave flow, and every cited line resolves: `lobby_screen.dart:78` (`'Close this room?' : 'Leave this room?'`), `:83`, `:84`, `:94` (`'STAY'`), `:109` (`'CLOSE ROOM' : 'LEAVE'`), and `:369` — **the first time in nine cycles that `The host has left. This room has closed.` has actually been observed.** A13's `'SUCCESS! (+1)'` resolves to `phase4_reveal.dart:421`, and the server guard message to `index.ts:1397`. A12's formula is corrected to `1`. A14 is a clean NOT RUN.
   - ⚠️ **A residue survives and is tracked as Issue 83** — A4's exhaustion count does not reconcile with the deck it was run on, A12's observations contradict each other, and two header-hygiene items from the spec were not done. **The fabrication class of defect is closed; an arithmetic-consistency class is not.**

0f. **Issue 77: Cloud Functions deployment of backend fixes (Resolved — August 14, 2026)**:
   - **Problem**: Three commits of backend fixes (`4986cc7`, `3aa3148`, `1e12748`) touching scoring, option-id resolution, placeholder prevention, and forgery range defaults were committed without being deployed to production.
   - **Solution**: Option A. Deployed all 14 Cloud Functions and security rules to production project `gaslight-46368`. Added `scripts/check_deploy_fresh.sh` to prevent recurrence.
   - **Verification**: Verified deployment timestamps via `gcloud functions list` and automated freshness script exit code 0.

0a. **Issue 78: `votes` sentinel purge — truth votes resolve by target identity (Resolved — August 13, 2026, `d34af33`; independently verified in source August 14)**:
   - **Problem**: Issue 71 redefined `votes` from `optionId | 'TRUTH'` to a resolved author id, and updated one of its nine readers. A player who correctly picked the truth scored **0** instead of `ceil((P − 1) / (S + 1))`; the truth-teller was paid as though they had fooled someone; and `votes[me.id] != 'TRUTH'` — the "was I fooled?" predicate — became permanently true, so every player saw the revenge tray. Deltas keyed to a non-player were silently dropped by `advancePhaseInternal`, which is why the reveal showed `Unknown: +1` while standings stayed at `0`.
   - **Solution**: Option A. A vote is a truth vote **iff `votedForId == card.targetPlayerId`**; the sentinel is gone. Changed all nine sites — `scoring_logic.ts:54`, `scoring_logic.dart:25`, `phase4_reveal.dart:105/250/265/359/554/764`, `index.ts:1566` — plus the now-dead disjunct at `index.ts:1378`, the stale contract comment at `scoring_logic.dart:13`, and the dead `_generateShuffledAnswers` path in `phase3_vote.dart` that was the last remaining *producer* of the sentinel in `lib/`.
   - **`phase4_reveal.dart:359` was worse than a comparison**: `_buildOptionRow` uses its `authorId` argument at `:806` to find that option's voters, so passing `'TRUTH'` matched nobody and **the truth row showed no voters at all**.
   - **Verification**: falsifying assertions at **two** inputs, because one value cannot pass both — `P=4, S=1 → 2` (`game_e2e.spec.ts:1684`) and `P=5, S=3 → 1` (`:1793`), each with an over-reach guard asserting the forgery-voter receives nothing (`:1690`, `:1795`). Mirrored client-side in the new `test/scoring_logic_test.dart`. Battery after: `flutter test` **130/130**, `npm --prefix functions test` **46/46**.
   - **Design updated**: `design_game_state_and_models.md` §2 now documents the real `votes` contract and records that it has broken twice.

0b. **Issue 79: The card target can no longer be accused of forgery (Resolved — August 13, 2026, `1eda59f`; independently verified in source August 14)**:
   - **Problem**: the revenge tray excluded only the guesser, so the card's target — who authored the truth and by definition forged nothing — was offered as an accusation target on every card. `submitUnmaskGuess` rejected only self-accusation.
   - **Solution**: Option A, both bounds. Client exclusion at `phase4_reveal.dart:694`; server rejection with `invalid-argument` at `index.ts:1394`. Per the selection's *"leave comments to address the cons of Option A"*, both sites carry a comment naming the other and stating why both exist — the client copy is UX, the server copy is the real guard, change both or neither.
   - **Verification**: `game_e2e.spec.ts:1805` asserts the rejection **by code**, not message.
   - **Design updated**: `design_scoring_and_ui.md` now separates *who may accuse* from *who may be accused* and records the paired-guard requirement.

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

### 2.12 Traceable quotes do not make a report arithmetically sound

Fixing §2.11 worked: the August 14 re-run's quotes are all real, checked mechanically. The next defect moved one level up — **the numbers between the quotes.** A4 claims a 20-prompt deck was exhausted in 16 recorded rolls; A12 states a player both voted the truth and was fooled by a forgery on the same card. Each individual string is genuine; the arithmetic joining them is not. **Traceability catches invention. It does not catch a count that does not add up — check the counts separately**, and require any count-dependent assertion to state the count, the deck, and the deck's size. See Issue 83.

### 2.11 An observation that cannot be traced to a tool result is not an observation

The August 13 playthrough report quotes 18 prompts from a 12-prompt deck, none of which exist anywhere in the repository. It is fluent, specific, internally consistent, and wrong — and it sat inside a document whose other blocks are genuinely good. **Verbatim-looking text is not evidence of verbatim capture.** The cheap defence is mechanical: every quoted game string must be findable in source with `grep -F`. Where it cannot be, the assertion is NOT RUN. See Issue 82.

### 2.10 "Verified in source" is not "shipped" — check the deploy, not the diff

Issues 71, 72 and 76 were each read in source, confirmed correct, and moved to Resolved. All three were still broken for players, because the commits containing them were never deployed and nobody ever asked production what it was running. A source-verified claim and a shipped fix are different facts, and this file spent three cycles conflating them. **`./scripts/check_deploy_fresh.sh` belongs in the battery as a mandatory gate**, verifying that all 14 functions and security rules strictly postdate the latest tree commits. See Issues 77 & 81.

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
