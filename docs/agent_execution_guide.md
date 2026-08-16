# Agent Execution Guide — Active Build: S0 → S7 — August 15, 2026

**You are an engineering agent with no memory of this project.**

**What is done and independently verified** (§9): Issues 71–82 — the `'TRUTH'` sentinel purge, the unmask bounds, the deploy of all 14 functions and the rules, and the deploy-freshness gate whose three exit codes were each exercised deliberately. **Do not rework any of it.**

**What this build does.** A manual three-simulator session on August 15 found four defects that nine automated gates and two driven playthroughs had all missed. Every one of them is a **missing affordance or an unenforced gate, not missing logic** — in three of the four cases the backend was already built and simply unreachable. The user has selected on all five open issues:

| Item | Issue | Selection | Touches |
|---|---|---|---|
| **S0** | 83 residue | *(carried forward, no selection needed)* | docs |
| **S1** | 84 | Option A — `dialogTheme` + clearer copy | client |
| **S2** | 83 | **Option C** — close deck exhaustion by emulator test | tests |
| **S3** | 87 | Option A — host kick in the lobby | client |
| **S4** | 86 | Option A — gate START GAME in *both* places | client + **server** |
| **S5** | 85 | Option A **+ auto-end below 3 players** | client + **server** |
| **S6** | — | deploy S4 and S5 together | production |
| **S7** | — | re-test the new controls | playthrough |

**Every number and literal string below is deliberate — implement as written; do not substitute your own.** Full issue text and rationale live in `docs/ongoing_general_errors.md`.

---

## Standing constraints

- **One item = one commit.** S1–S5 are five commits, not one.
- **Write validation that fails against the broken state, and observe it fail** before fixing. Record the failure output in the commit body.
- **A client-only bound is not a bound.** S4 and S5 both have a server half; shipping only the client half is not the selected option.
- **Every quoted game string in any report must be findable in source with `grep -F`**, and any count-dependent assertion must state the count, the deck, and the deck's size.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not touch anything in §9 or §10.**

---

## 1. Verified baseline — the regression bar

Measured **August 15, 2026** at `6cc6d69`, clean tree.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (222 issues) |
| `flutter test` | **130/130** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **46/46** ✅ |
| `./scripts/check_deploy_fresh.sh` | **exit 0** ✅ |

**Run the deploy gate as the fifth gate every pass.** Its contract — three exit codes, epoch-second comparison, function-count check, and the Rules API's mandatory `x-goog-user-project` header — is in `design_database_and_security.md` §8. **Exit 2 means "could not verify" and must never be reported as a pass.**

### ⚠️ Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`**.
2. **Analyze ≠ compile.**
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`. **S1's test needs this.**
8. **`firebase.json`'s `predeploy` runs the test suite.** It gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe — or about what is deployed.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.
13. **Line numbers drift.** Re-grep for the expression, never the number.
14. **Deck sizes are facts.** `cah_dark_humor` = **12**, `the_daily_grind` = **20**. Count before quoting a total:

```bash
awk "/'the_daily_grind': \[/,/^    \],/" lib/utils/prompt_decks.dart | grep -cE '^\s+"'
```

15. **`git` and Google timestamps must never be string-compared.** See `design_database_and_security.md` §8.
16. **A spec can demand something the app cannot do.** The last cycle's A9/A10 asked for a mid-match leave that has no control; the agent tested the nearest reachable thing and reported PASS. **Before writing an assertion against a control, grep that the control exists.**

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| **S0** | Findings-report hygiene | Free, docs-only, and it removes the artefact that hid two deploy gaps. Do it first so it cannot be forgotten again — it has already slipped one cycle. |
| **S1** | Issue 84 — dialog theme | Smallest code change, client-only, no deploy. Its contrast test establishes the measurement pattern S7 will reuse. |
| **S2** | Issue 83 — exhaustion test | Test-only, no production risk. Closes an open verification question before new features churn the same machinery. |
| **S3** | Issue 87 — host kick | **Before S4.** S4 gates the start on everyone being ready; without a kick, one idle player holds the lobby hostage. Land the escape hatch first. |
| **S4** | Issue 86 — ready gate | After S3. Client + server. |
| **S5** | Issue 85 — quit + auto-end | Client + server. Last of the code because its server half touches `handleDisconnect`, which S3 also calls — landing S3 first means its behaviour is already understood. |
| **S6** | Deploy | **One deploy covering S4 and S5.** Never deploy mid-build with only one server half live. |
| **S7** | Playthrough | Last. Needs the deploy and a rebuilt client. **This is the first time mid-match departure will be testable at all.** |

---

## 3. S0 — Findings-report hygiene *(carried forward)*

**What this means for the user:** the report is what the next agent reads as proof, and it still contains the artefact that hid a production gap twice.

**Gap:** `grep -c "firebase functions:list" docs/playthrough_findings_marionette.md` returns **1** and `grep -c "Provenance"` returns **0**. Both were specced last cycle and neither was done.

### Implementation

1. Delete the box-drawing table at `docs/playthrough_findings_marionette.md` lines ~17–38 — **Function · Version · Trigger · Location · Memory · Runtime, with no timestamp in it.** Replace with real output:

```bash
/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud functions list --project=gaslight-46368 --format="table(name,updateTime)"
```

2. Add to the header, after **Deliberate Deviations**:

```markdown
- **Provenance:** A3, A4, A9, A10, A13 were re-run on August 14, 2026 against the deployed build at `a428201`. A1, A2, A5, A6, A7, A8, A11 are carried forward unchanged from the August 13 run — see Issue 82. A12 was corrected in place without a re-run. A14 has never been run.
- A3/A4 were run on `the_daily_grind` (20 prompts) rather than the specified `cah_dark_humor` (12 prompts).
```

3. **Correct the A9/A10 framing.** Both blocks describe the **lobby** leave flow, which is the only one that exists today (Issue 85). Add one line to each: `Scope: lobby leave flow. Departure during a match is not reachable until Issue 85 ships — see S7.` **Do not change their verdicts** — what they tested, they tested correctly.

### Validation

`grep -c "firebase functions:list"` → **0**. Header contains `Provenance:` covering all fourteen assertions. No verdict changes.

Commit: `docs(playthrough): replace non-evidential deploy table and record provenance`.

---

## 4. S1 — Issue 84: make dialog text legible, and say what "nothing" means

**What this means for the user:** the host is warned what happens to players who have not voted, and cannot read the warning. Measured at **1.02:1** contrast — the text and its background differ by fewer than 3 values per channel.

### The gap

`main.dart:73–84` sets `textTheme.apply(bodyColor: AppColors.ivory, displayColor: AppColors.brass)` — right for the dark ground — while `ColorScheme.dark(surface: AppColors.parchment)` makes Material 3 paint every `AlertDialog` on paper. The explicit `textTheme` colours beat `onSurface: ink`. `phase3_vote.dart:165` sets no styles and inherits the collision; `lobby_screen.dart:71` sets its own `backgroundColor: AppColors.groundRaised` plus explicit styles and is readable. **The next bare `AlertDialog` will be invisible too** — which is why the fix is the theme, not the screen.

| Element | On `parchment #F4EBD8` | Ratio |
|---|---|---|
| content `ivory #F5EEDB` | | **1.02 : 1** |
| title `brass #C9A24B` | | **2.02 : 1** |
| actions `oxblood` | | 9.67 : 1 |

### Implementation

1. **`lib/main.dart`, inside `ThemeData` (~`:69–86`)** — add a dialog theme so the default matches the lobby dialog's already-shipped pattern:

```dart
        dialogTheme: DialogTheme(
          backgroundColor: AppColors.groundRaised,
          titleTextStyle: AppTextStyles.cardHeader.copyWith(color: AppColors.brass),
          contentTextStyle: AppTextStyles.bodyIvory,
        ),
```

**Flutter 3.44 may require `DialogThemeData` rather than `DialogTheme` for this field.** Let the analyzer decide — use whichever type `ThemeData.dialogTheme` accepts; the three properties are the same either way. Do not change `colorScheme.surface`: parchment is correct for cards and sheets, and other screens depend on it.

2. **Leave `lobby_screen.dart:71` alone.** Its explicit styles now agree with the theme and override harmlessly. Deleting them is out of scope.

3. **`lib/screens/phase3_vote.dart:167`** — replace the content string with:

```dart
          content: const Text('End voting now? Players who have not voted will score nothing on this card, and their vote cannot be cast later.'),
```

This is accurate: `advancePhaseInternal`'s vote branch tallies `currentCard.votes`, and a player with no entry receives no deltas and is not counted as fooled. **Nothing back-fills a missing vote** — unlike the answer path's `kMissingAnswerPlaceholder`.

### Validation

**The falsifying assertion — assert the ratio, not the string.** A test asserting the copy is present **passes today**, and that is precisely the bug; it is the same shape as the placeholder tests that let Issue 76 ship.

Add a widget test that pumps the app's `ThemeData`, resolves the effective dialog background and the effective `contentTextStyle.color`, and asserts:

```
contrastRatio(relativeLuminance(content RGB), relativeLuminance(background RGB)) >= 4.5
```

Both helpers already exist in `test/helpers/png_decoder.dart` (`relativeLuminance(int r, int g, int b)`, `contrastRatio(double, double)`). **Run it against unmodified `main.dart` first and record that it reports 1.02.** Set `accessibleNavigation: true` if you render the dialog (trap 7).

**Over-reach guard, same test:** assert the **title** also clears **3.0:1** (large text), so a fix that darkens only the body still fails.

Battery: `flutter analyze lib test` 0 errors · `flutter test` **≥131**.

### Blast radius

`lib/main.dart`, `lib/screens/phase3_vote.dart`, one new test. **The theme change affects both `AlertDialog`s in `lib/`** — check the lobby leave dialog still renders correctly, since its copy was quoted verbatim in the playthrough and S7 re-reads it.

Commit: `fix(theme): give dialogs a legible surface and state the vote consequence`.

---

## 5. S2 — Issue 83 Option C: close deck exhaustion in the emulator suite

**What this means for the user:** the game should tell you when a deck runs out rather than misbehaving quietly — and right now nobody can prove at what count it does that.

### The gap

A3 recorded 16 re-rolls on a 20-prompt deck and A4 claimed exhaustion. The count never reconciled, and three readings fit — including one where exhaustion fires **early**, which would be a real defect in the `drawOneExcluding` / `seenPrompts` machinery Issue 67 rebuilt. **The user selected Option C: settle it in the emulator suite, where the count is exact and free to re-run.**

### Implementation

Add a describe block to `functions/test/game_e2e.spec.ts`. For a deck of known size `n`:

1. Create a room, join to 3 players, `startGame` on that deck. **The player's own card consumes one prompt at deal**, so their sealed doc starts with `seenPrompts.length === 1`.
2. Call `rerollPrompt` exactly **`n − 1`** times. Assert each returns a prompt **not previously seen**, and that the set of all returned prompts has size **`n − 1`**.
3. Assert call **`n`** throws **`resource-exhausted`** — match on the **code**, never the message (trap 12).
4. **Over-reach guard, in the same test:** a *different* player in the same room must still be able to re-roll successfully afterwards. `seenPrompts` lives in `/rooms/{code}/sealed/{cardId}` **per player, not globally** — a regression that exhausted the deck room-wide would otherwise pass.

**Run it at two deck sizes — `cah_dark_humor` (12) and `the_daily_grind` (20).** A test hard-coded to one size cannot distinguish "exhausts at `n`" from "exhausts at 12".

### Validation

`npm --prefix functions test` rises above **46**. **If the boundary does not hold — if exhaustion fires before `n`, or a second player is blocked — STOP and file it.** That is a real defect, not a test to adjust.

**Also update the findings report:** A4 becomes **NOT RUN via the UI**, citing this test by `file:line`, and records the gap Option C leaves — **the client SnackBar path is not covered by an emulator test.** Queue that half for S7.

Commit: `test(functions): assert deck exhaustion at the boundary for two deck sizes`.

---

## 6. S3 — Issue 87: host kick in the lobby

**What this means for the user:** a host stuck with an idle or duplicate player currently has to close the room and make everyone rejoin. **S4 makes this urgent** — once the start is gated on everyone being ready, one idle player blocks the lobby entirely.

### The gap

No kick control exists in `lobby_screen.dart`. **The backend already authorises one.** `handleDisconnect`'s check (`index.ts:786–789`) rejects only *non-hosts* acting on another player's document:

```ts
if (!callerPlayer || (!callerPlayer.isHost && callerPlayer.id !== disconnectedPlayerId && !isDead)) {
  throw new HttpsError("permission-denied", "Not authorized to trigger disconnect.");
}
```

In the lobby no card is dealt, so it takes the `!hasCard` branch (`index.ts:804–807`) and simply deletes the player document. **No new callable, no rules change, no deploy.**

### Implementation

1. **`lib/services/game_service.dart`** — add alongside `leaveRoom()` (`:303`):

```dart
  Future<void> kickPlayer(String playerId) async {
    final roomCode = _gameState?.roomCode;
    if (roomCode == null || currentPlayer?.isHost != true) return;
    await _functions.httpsCallable('handleDisconnect').call({
      'roomCode': roomCode,
      'disconnectedPlayerId': playerId,
    });
  }
```

Match the argument names `leaveRoom()` already sends (`game_service.dart:316–318`) — **re-read them rather than trusting this snippet.**

2. **`lib/screens/lobby_screen.dart`, the roster row (~`:812–835`)** — the per-player `Column` holding `PlayerAvatar` and the name `Text`. Add a small remove control, rendered **only when `isHost && !player.isHost`**. Use `ThematicIconType.depart` for consistency with the existing leave control (`:465`).

3. **Confirm before removing**, naming the player, using the same `AlertDialog` shape as `_confirmLeave` (`:48`) — which S1 has just made legible by default:

- Title: `Remove player?`
- Content: `Remove ${player.name} from this room? They can rejoin with the room code.`
- Actions: `CANCEL` and `REMOVE`

4. **The removed player lands on the entry screen** by the existing mechanism — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null (§10). **They get no explanation**, which is the stated cost of Option A. Show them a SnackBar in the same style as the eviction notice at `:369`: `The host has removed you from this room.`

### Validation

**Falsifying assertion (emulator, `game_e2e.spec.ts`):** a host calls `handleDisconnect` with another lobby player's id; assert that player's document no longer exists and the remaining roster is intact.

**Over-reach guard, and it is the one that matters:** a **non-host** calling `handleDisconnect` for a third player must still be rejected with **`permission-denied`**, matched on the code. Without this, a kick control becomes a kick-anyone control.

**Client:** a widget test asserting the remove control renders for the host on non-host rows and **does not render** on the host's own row, nor for a non-host viewer.

### Blast radius

`lib/services/game_service.dart`, `lib/screens/lobby_screen.dart`, plus tests. No server change.

Commit: `feat(lobby): let the host remove a player before the game starts`.

---

## 7. S4 — Issue 86: gate START GAME on readiness, in both places

**What this means for the user:** the lobby shows `(2/3 Ready)`, decides everyone is ready, glows the button about it — and starts anyway.

### The gap

`lobby_screen.dart:452–456` computes `allNonHostsReady`. It is rendered as a count at `:787` and read at **`:871` in a `decoration`**. **It is never read in the `onPressed` gate at `:885`**, which checks only `startWarning != null || _isStartingGame`; `startWarning` (`:443–450`) covers player count, forgeries and deck size.

**The server never checks either.** `startGame` (`index.ts:229–266`) validates host, `activePlayers.length >= 3`, and forgery sanity. `lobbyReady` is declared (`index.ts:33`), initialised `false` at `createRoom` (`:126`) and `joinRoom` (`:209`), and reset `false` after a start (`:426–428`) — **written and cleared, never read as a condition.**

### Implementation

1. **Server — `functions/src/index.ts`, `startGame`, immediately after the 3-player guard (`~:260–262`):**

```ts
    const unreadyNonHosts = activePlayers.filter(p => !p.isHost && p.lobbyReady !== true);
    if (unreadyNonHosts.length > 0) {
      throw new HttpsError(
        "failed-precondition",
        `Every player must be ready before starting (${unreadyNonHosts.length} not ready).`
      );
    }
```

**The host is deliberately excluded.** The host has no ready toggle — `lobby_screen.dart:909` renders it for the current player, and the host's own control is the start button. Requiring `hostPlayer.lobbyReady` would deadlock **every** lobby. Keep this guard **separate from the 3-player floor**, which is its own guard by long-standing invariant (§10).

Use `!== true`, not a falsy check — **loose `!= null` semantics are an invariant here** (Issue 31); an absent `lobbyReady` on a legacy document must count as *not ready*, which `!== true` gives you.

2. **Client — `lib/screens/lobby_screen.dart`, `startWarning` (`:443–450`)** — add a branch after the existing three, so `allNonHostsReady` finally drives the gate it already decorates:

```dart
    } else if (!allNonHostsReady) {
      startWarning = "Waiting on ${totalNonHostsCount - readyNonHostsCount} of $totalNonHostsCount players to ready up.";
    }
```

`allNonHostsReady`, `readyNonHostsCount` and `totalNonHostsCount` are computed at `:452–456`, **below** `startWarning`. Move that computation above the `startWarning` block; it depends only on `players`, so it hoists cleanly. Re-grep — do not assume the line numbers survived S1 and S3.

### Validation

**Falsifying assertion (emulator):** three players, two non-hosts of whom **one is ready and one is not**; `startGame` must throw **`failed-precondition`** — matched on the code.

**Two over-reach guards, both required:**
- With **all** non-hosts ready, `startGame` **succeeds** — proving the guard is not simply always-on.
- With all non-hosts ready and the **host's own `lobbyReady` false**, `startGame` still **succeeds**. This is the deadlock guard and it must be explicit.

**Client:** a widget test asserting the START GAME button is disabled and the warning text renders when one non-host is unready, and enabled when all are.

### Blast radius

`functions/src/index.ts`, `lib/screens/lobby_screen.dart`, tests. **Server change — S6 must deploy it.** Existing emulator tests that call `startGame` will now fail unless their players are marked ready: **expect several to break, and fix them by setting `lobbyReady`, never by weakening the new guard.**

Commit: `fix(lobby): require every player ready before the host can start`.

---

## 8. S5 — Issue 85: let players quit a match, and end it below 3

**What this means for the user:** once a match starts there is no way out until Game Over. With `Disable Game Timers` on, the in-game app bar is completely empty — a player who wants to stop must force-quit and wait out a 30-second timeout.

### The gap

Every in-game `AppBar` sets `automaticallyImplyLeading: false` and carries only the countdown in `actions`: `phase2_craft.dart:157–186`, `phase3_vote.dart:113–140`, `phase4_reveal.dart:281–290`. When `state.isTimerDisabled`, `actions` renders `SizedBox.shrink()`.

**The server is already complete.** `leaveRoom()` (`game_service.dart:303`) calls `handleDisconnect`, which is phase-aware: deletes the player document, filters their card from `room.cards`, prunes `readyPlayers` and `resolutionOrder`, decrements `totalPlayers`, reassigns the forgery rotation when the leaver held a card, advances `currentReaderId`, and falls to `gameOver` when the resolution order empties (`index.ts:888–896`).

**What is missing beyond the affordance** is the user's added requirement: **when active players drop below 3, end the match for everyone and show the final score.** Today the 3-player minimum is enforced at `startGame` (`index.ts:260`) and **nowhere else**, so two players can continue a match whose scoring assumes three.

### Implementation

1. **Client — add a depart control to all three in-game `AppBar`s.** Mirror the lobby's control at `lobby_screen.dart:460–469`: `IconButton` with `ThematicIcon(type: ThematicIconType.depart)`, `tooltip: 'Leave game'`, as the AppBar `leading` (replacing `automaticallyImplyLeading: false` with an explicit `leading:`). **Do not put it in `actions`** — that is where the timer lives, and it vanishes when timers are disabled.

2. **Confirmation dialog** — a match in progress is not a lobby, so the copy differs from `_confirmLeave`:

- Title: `Leave this game?`
- Content: `Your card and answers will be removed from this round. You cannot rejoin a game in progress.`
- Actions: `STAY` and `LEAVE GAME`
- On confirm: `gs.leaveRoom()` — already correct for every phase.

3. **Server — the below-3 auto-end.** In `handleDisconnect`, after `activePlayerCount` is computed (`~index.ts:819–820`) and **before** the phase-specific branches, add:

```ts
    if (phase !== "lobby" && activePlayerCount < 3) {
      nextState = { ...nextState, currentPhase: "gameOver", unmaskDeadline: null, endTime: null };
    }
```

Three things this must respect:
- **It must not fire in the lobby.** Below-3 in a lobby is the normal pre-start state; `startGame` is what guards that.
- **It must win over the phase-specific branches**, including the existing `resolutionOrder`-empty → `gameOver` at `:895`. Apply it last, or guard the later branches on it — **either is fine, but assert which one you did.**
- **Scores are already on the player documents** (`totalScore`), and `game_over_screen.dart` reads them. "Bringing them to the final score" needs no score computation — only the phase transition.

### Validation

**Falsifying assertion (emulator), and it is two tests:**
- **3-player match, one player leaves** → `handleDisconnect` → assert `currentPhase === "gameOver"` for the room, and that both remaining players' `totalScore` values are unchanged by the transition.
- **Over-reach guard — 4-player match, one player leaves** → assert `currentPhase` is **unchanged** and the match continues with `totalPlayers === 3`. Without this, a rule that ended every match on any departure would pass.

**Also assert the lobby exemption:** a 3-player *lobby* losing a player must **not** flip to `gameOver`. S3's kick makes this reachable in one call.

**Client:** widget tests asserting the leave control renders on all three in-game screens **including when `isTimerDisabled` is true** — that is the state in which the app bar is currently empty, and the whole point.

### Blast radius

`lib/screens/phase2_craft.dart`, `lib/screens/phase3_vote.dart`, `lib/screens/phase4_reveal.dart`, `functions/src/index.ts`, tests. **Server change — S6 must deploy it.**

Commit: `feat(game): let players leave a match and end it below three players`.

---

## 9. S6 — Deploy, then S7 — re-test

### S6 — one deploy covering S4 and S5

Do not deploy between S4 and S5. Two functions disagreeing about whether readiness gates a start, or about when a match ends, is worse than either version alone.

```bash
npx firebase-tools deploy --only functions --project gaslight-46368
```

`predeploy` runs the suite and needs Java. Rules are unchanged by this build — **verify that rather than assuming**, with the Rules API call in `design_database_and_security.md` §8.

**Validation:** `./scripts/check_deploy_fresh.sh` → **exit 0**, with all 14 functions later than the last `functions/src` commit. Paste before and after tables into the findings report. **A partial deploy is a failure, not a partial success.** If it exits 2, you have not verified anything — resolve the credentials before continuing.

### S7 — playthrough of the new controls

Rebuild the client first (S1, S3, S4, S5 all changed `lib/`). Three simulators, `USE_EMULATOR=false`, debug build, `Disable Game Timers` **on**, `Family-Friendly Decks Only` **off**. Marionette is installed and working; verify rather than redo.

New assertions, each with `grep -F` traceability for every quoted string:

| # | Assertion | Verdict from |
|---|---|---|
| **A15** | The "End Voting?" dialog is **readable**, and its text names the consequence | Screenshot plus the verbatim string. S1 |
| **A16** | Host **cannot** start with one player unready; the warning names how many; the start succeeds once all are ready | The button state and the warning copy. S4 |
| **A17** | Host removes a lobby player; roster updates; the removed player lands on the entry screen with the removal notice | Both devices. S3 |
| **A18** | A player leaves **mid-match** from a 4-player game; the match continues | The remaining three. S5 — **never testable before this build** |
| **A19** | A player leaves mid-match from a **3-player** game; **all remaining players land on the final score screen** | All devices show Game Over with scores intact. S5 + the user's added requirement |
| **A20** | The exhaustion SnackBar still appears in the client at the deck boundary | The verbatim string `No more prompts left in this deck.` — the half S2's emulator test cannot cover |

**A18/A19 destroy the match — run them last, A18 before A19.** Record findings in `docs/playthrough_findings_marionette.md` per assertion, verbatim, with the provenance line from S0 updated to cover this run. **Do not write into `ongoing_general_errors.md`; do not fix anything inline.**

---

## 10. Do not invent work · escalation

Outside S0–S7 there is no queue. Legitimate triggers: a defect S7 surfaces, a user-selected issue, or the TTL interval dropping below ~4 hours.

**Bounded deviation:** keep the intent, deviate minimally, note it in the commit body — **and record any substitution of deck, device or fixture.** An unrecorded deck substitution is what made Issue 83 unreadable.

**If the design cannot work — STOP.** File it in `ongoing_general_errors.md` with options and a blank `Your selection: _____`. Specifically: **do not** reintroduce the `'TRUTH'` sentinel (Issue 78 B, declined), **do not** disable `predeploy`, **do not** let `check_deploy_fresh.sh` exit 0 when it could not check, **do not** weaken S4's guard to make old tests pass, **do not** require the host's own `lobbyReady`, and **do not** reconstruct an observation you did not capture.

---

## 11. Already delivered — do NOT rework

**Verified in source and against the live project, August 15, 2026, at `6cc6d69`:**

- **Issue 78** — nine readers resolve truth votes as `votedForId == card.targetPlayerId`; dead disjunct at `index.ts:1378` removed; dead `_generateShuffledAnswers` path deleted. Tests at two inputs (`game_e2e.spec.ts:1684`, `:1793`) with over-reach guards, mirrored in `test/scoring_logic_test.dart`.
- **Issue 79** — target excluded client-side (`phase4_reveal.dart:694`), rejected server-side with `invalid-argument` (`index.ts:1394`), both carrying the paired-guard comment. Test at `:1805`.
- **Issues 77 / 81** — 14/14 functions deployed; rules released; `scripts/check_deploy_fresh.sh` in the battery with all three exit codes exercised.
- **Issue 80** — `'SUCCESS! (+1)'` (`phase4_reveal.dart:421`) observed with standings `0 → 1`.
- **Issue 82** — A3's 16 quotes all verified in source; A9/A10 exercise the **lobby** leave flow correctly (see S0's framing correction).
- **Issue 76** — `submitAnswer` validates against `room.currentCardAssignments?.[authorId]`.
- **Issue 72** — forgery default `Math.min(activePlayers.length - 1, 5)` from the live count; range-validated server-side; the 3-player floor is its own guard.
- **Issue 71** — `castVote` resolves option ids via `sealedData.answerAuthors`. **The change that created Issue 78** — correct, but its readers were not enumerated.
- **Issues 50–75** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 12. Accepted equivalents & invariants — do NOT change

- **`votes` maps `voterId` → resolved author id. There is no sentinel.** A truth vote is `votes[voterId] == card.targetPlayerId`. Contract: `design_game_state_and_models.md` §2. **Redefined twice, broke its readers both times.**
- **Who may accuse and who may be accused are two separate bounds**, enforced in two places by design (`design_scoring_and_ui.md`).
- **The deploy gate's three exit codes are a contract** (`design_database_and_security.md` §8). Collapsing exit 2 into 0 defeats the mechanism.
- **The 3-player floor is its own guard**, never a side effect of forgery arithmetic — and after S4 it is also **separate from the readiness guard**.
- **`scoring_logic.{ts,dart}` must stay semantically identical**; `text_similarity` byte-identical.
- **Issue 76 validates rather than re-derives** — same guarantee, different structure.
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null. **S3 and S5 both rely on this.**
- **The leave dialog uses `showGeneralDialog`.** **The non-host carousel is interactive-but-inert, not dimmed.**
- **`lastReaction` / `lastReactionAt` stay on `PlayerState` and in the rules deliberately** (Issue 74).
- **Sealed documents are created lazily. `seenPrompts` is per-sealed-document, not global** — S2's over-reach guard depends on this.
- **`_ThematicIconPainter` carries unreachable fallback cases** — do not wire them up.
- **Server-authoritative**; room reads stay open; `/rooms/{code}/sealed/{cardId}` is default-deny. **Never add an explicit `allow read: if false`.**
- **Option ids are opaque UUIDs**, resolved server-side. **Never send authorship to the client.**
- **Phase order is truth → forgery → vote → reveal.**
- **Forgeries per card: hard ceiling `n − 1`; `5` is a default, not a cap.** **Re-rolls unlimited during `truth`, rejected elsewhere, never repeating.**
- **`ROOM_TTL_MS` is 8 hours.** **`firebase.json`'s `predeploy` stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 C, Issue 34 C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, Issue 78 B/C, Issue 79 B, Issue 81 B/C, Issue 82 B/C, **Issue 83 A/B, Issue 84 B/C, Issue 85 B/C, Issue 86 B/C, Issue 87 B/C**, and the rejected options on 58–66.

---

## 13. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| **`votes` contract, schemas, phase order** | `design_game_state_and_models.md` |
| **Scoring formulas, reveal beats, unmask bounds** | `design_scoring_and_ui.md` |
| **Deploy, and the freshness gate's contract (§8)** | `design_database_and_security.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| Palette, typography, icons, mascot | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |
| **PNG decoding + WCAG contrast helper** | `test/helpers/png_decoder.dart` — S1 depends on it |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 14. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the output.

**A test that asserts the happy path of a bug is not a test for the bug.** S1's copy is already present and already correct — a test asserting the string passes today.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every game string you quote.

**Traceable quotes do not make a report arithmetically sound.** Check counts separately.

**A check that cannot run must say so, not pass.**

**Assert a derived value at two different inputs** — S2 requires two deck sizes for exactly this reason.

**A clamp is not a rejection. A client-only bound is not a bound** — S4 and S5 both have server halves because of it.

**Measure; do not estimate.** **Pair every fix assertion with an over-reach guard.** Every item in this build names its guard; none is optional.

**A driven playthrough is not a played one.** Four of this build's five items came from a human with three simulators, not from any gate.

---

## 15. Feedback loop — what past specs got wrong

- **The backend keeps being ahead of the client.** Mid-match departure, host-initiated removal, and lobby readiness were all fully built server-side and either unreachable or never consulted. **Missing affordances and unenforced gates are invisible to server tests and to source audits alike** — only someone using the app finds them.
- **A computed value that feeds a `decoration` looks like a gate and is not.** `allNonHostsReady` was correct, current, and rendered — into a glow. **Grep where a guard value is *read*, not just where it is computed.**
- **A spec can demand something the app cannot do**, and the agent will test the nearest reachable thing and report PASS. Before asserting against a control, grep that the control exists.
- **Fixing a class of defect promotes the next one.** Fabricated quotes → arithmetic that does not add up → missing controls. Assume the next failure is one level up.
- **When a written step fails twice, replace it with a tool.** `check_deploy_fresh.sh` ended a two-cycle deploy gap — and works only because exit 2 is distinct from exit 0.
- **A gate that has never failed has not been tested.** Exercise every exit path deliberately.
- **When you redefine what a field holds, enumerate its readers.**
- **One item = one commit.** Issues 71–76 landed as one; five were real, one untouched, and the batch read as complete.
- **Doc structure rots silently.** Append inside the existing Resolved heading; never add a second.

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors (re-grep; line numbers drift).
(2) WRITE the falsifying validation FIRST. Run it. Observe it fail. Record the output.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per §14, including the over-reach guard.
(5) BEFORE COMMITTING, re-run the full battery INCLUDING ./scripts/check_deploy_fresh.sh.
(6) BLOCKED, or needing human judgement? STOP. File it in ongoing_general_errors.md
    with options and a blank `Your selection: _____`.
(7) RECORD: resolved items go inside the SINGLE existing Resolved heading;
    playthrough observations go to docs/playthrough_findings_marionette.md.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output included.
```

---

## Definition of Done

- [ ] **S0** — `grep -c "firebase functions:list"` returns **0**; header carries `Provenance:` for all fourteen assertions; A9/A10 scoped to the lobby flow without changing their verdicts.
- [ ] **S1** — dialog contrast asserted **≥ 4.5:1** for content and **≥ 3.0:1** for the title, observed reporting **1.02** before the fix; vote copy states the consequence.
- [ ] **S2** — exhaustion asserted at **two** deck sizes (12 and 20), with the per-player over-reach guard; A4 marked NOT RUN via UI citing the test.
- [ ] **S3** — host kick works; **a non-host calling `handleDisconnect` on a third player is still rejected with `permission-denied`**; the removed player sees a notice.
- [ ] **S4** — server rejects an unready start with `failed-precondition`; **succeeds when all non-hosts are ready even with the host's own `lobbyReady` false**; client warning names the count. Pre-existing `startGame` tests fixed by marking players ready, **never by weakening the guard**.
- [ ] **S5** — leave control on all three in-game screens **including when timers are disabled**; 3-player departure → `gameOver` with scores intact; **4-player departure leaves the match running**; a lobby losing a player does **not** end anything.
- [ ] **S6** — one deploy; all 14 functions fresh; `check_deploy_fresh.sh` exit **0**; before/after tables recorded.
- [ ] **S7** — A15–A20 attempted, each PASS / FAIL / NOT RUN with a reason and `grep -F` traceability. **A19 confirms all remaining players reach the final score screen.**
- [ ] Battery at or above §1: **0 errors** · **≥130** · clean build · **≥46** · deploy gate exit **0**.
- [ ] **Nothing fixed inline during S7.**
