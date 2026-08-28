# Agent Execution Guide — Active Build: Wave Q — Q2: run the five-player soak — August 28, 2026

**You are an engineering agent with no memory of this project.**

**Q1 is COMPLETE, verified and falsified — do not rebuild it.** §2 and §3 are kept as the record of what was built and why.

**Q2 is now UNBLOCKED and is the active item.** The user deployed on **2026-08-28T02:40–02:41Z**; `./scripts/check_deploy_fresh.sh` exits **0** — 16 Cloud Functions, all newer than the last `functions/src` commit. Q1's deadline guard is live in production, which is the precondition the soak was waiting on.

**Issue 134 → Option A: run the full soak, M0–M4, all 22 blocks.** Not a reduced set. The user chose the complete run with the time cost stated.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **Q1** | `closeUnmaskWindow` must refuse an early close, and any room member must be able to call it | **133 → A** | server + client | ✅ |
| **Q2** | Five-player Marionette soak — departures in every phase, and every Wave O/P/Q feature on a real device | user request | test only | — |
| **Q3** | Move `clock` from `dev_dependencies` to `dependencies` | verification finding | client | — |

**Do not run `firebase deploy` yourself** — that call is the user's, and it is what makes the server half of Q1 real.

### Before you start: re-confirm the deploy yourself

**The soak runs against production** (`USE_EMULATOR=false`), so what matters is the deployed server, not the local tree. It was fresh when this guide was written, but **do not take that on trust — run it bare and read the exit code**:

```bash
./scripts/check_deploy_fresh.sh
```

**It must exit 0.** If it exits 1, someone has committed server code since the deploy: **stop and tell the user.** A soak against a stale server certifies nothing, and you will not find out until the report is written.

**Q3 is independent** and may be done at any time; it needs no deploy and no simulators.

**Every number and literal string below is a decision, not a suggestion.** Implement as written. If a value is impossible, keep the intent, deviate minimally, and say so in the commit body.

---

## 0. What these items are

Wave P's Issue 124 fix correctly stopped publishing `scoreDeltas` while the unmask window is open, and added a `closeUnmaskWindow` callable to close the window on the timeout path. **The callable shipped without the deadline check that made it safe.** Any player can call it the instant the reveal begins, which ends the guessing window for the whole table and publishes the map that names every fooling forger. Separately, the client only calls it when the caller is the host, so a table whose host has left never closes the window at all. **Q1 fixes both halves in one commit**, because fixing only the guard leaves the empty-tray path and fixing only the trigger widens who can exploit the missing guard.

**Q1 is done and verified** — the guard is in `closeUnmaskWindow`, the client trigger is open to any member with a bounded retry, F1–F7 and W1–W7 are green, and F1 was **re-run with the guard neutered and observed to fail** while the six over-reach guards stayed green. §2 and §3 remain as the record of what was built and why; **do not rebuild them.**

**Q2 is a five-player Marionette soak**, requested by the user. Every functional defect this project has ever had was found by a person playing, and every one of them was found at **three** players — the most this harness has ever driven. Five is where the forgery chain, the reader rotation and the departure logic all become non-trivial, and where a card first carries five options. Q2 writes a report and files what it finds; **it writes no production code.**

---

## 1. Standing constraints

- **One item = one commit**, Conventional Commit, **WHY in the body — never a bare title.** Wave P's Issue 124 commit was a title with no body, and that is part of why this defect took a verification pass to find.
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Read a gate's exit code bare, never through a pipe.** `./scripts/check_deploy_fresh.sh | tail -6` reports `$?` from `tail`, which is always `0`.
- **Never hand-edit `lib/utils/prompt_decks.dart`** — it is generated.
- **When a change adds or alters a callable, enumerate what it now permits** before enumerating what it fixes (lesson 2.32). That is the lesson this whole wave exists to apply.
- **Q2 finds defects; it does not fix them.** A report written against a moving build proves nothing. File and stop.
- **Do not touch anything in §9 or §10.**

---

## 2. Q1 — the server guard (133 → A, part 1 of 2)

**What this means for the user:** during the twenty seconds when players are guessing who fooled them, nobody can skip to the answer — or end the round early for everyone else.

### 2.1 The gap, with reproducible evidence

`closeUnmaskWindow` (`functions/src/index.ts:2241`) validates the phase, the current card, room membership and the sealed document. **It never reads `room.unmaskDeadline`.** Proven against a running emulator, with the fooled player — the one who is supposed to be guessing — making the call:

```
PROBE unmaskDeadline       = 1787846904973
PROBE window open?         = true
PROBE scoreDeltas at reveal= undefined          <- Issue 124's core fix works
PROBE early close returned = {"success":true}   <- should have been failed-precondition
PROBE unmaskDeadline after = 0                  <- window ended for the WHOLE table
PROBE scoreDeltas after    = {"p_host":3,"p_g1":1}
PROBE actual forgerId      = p_host  target = p_g1
PROBE forger identified?   = true  via ["p_host"]
```

### 2.2 The four states `unmaskDeadline` can hold — handle all of them

This is the part that is easy to get half-right. The field is not a boolean.

| Value | Meaning | Required behaviour |
|---|---|---|
| `null` | No window ever opened for this card — nobody was fooled, and `scoreDeltas` was already published at reveal | Early return `{ success: true, alreadyClosed: true }`. **Do not write anything.** |
| `0` | The window has already been closed | Early return `{ success: true, alreadyClosed: true }`. **Do not write anything.** |
| A **future** timestamp | The window is open | **Throw `failed-precondition`.** This is the fix. |
| A **past** timestamp | The window expired and nobody has closed it | Proceed with the existing flush-and-publish logic, unchanged. |

### 2.3 Implementation

1. **Add the early return for `null` and `0`** immediately after `const room = roomSnap.data() as GameState;` and the existing `currentPhase !== "reveal"` check:
   ```ts
   if (room.unmaskDeadline === null || room.unmaskDeadline === undefined || room.unmaskDeadline === 0) {
     return { success: true, alreadyClosed: true };
   }
   ```
   **Use an explicit comparison, not a falsy check** (lesson 2.1). This also turns the N−1 redundant transactions from concurrent callers into cheap no-ops instead of repeated writes.
2. **Add the deadline guard**, placed **after** the caller-membership check (`if (!callerPlayer)`) so an outsider always receives `permission-denied` regardless of window state — authorize first, then validate state:
   ```ts
   if (Date.now() <= room.unmaskDeadline) {
     throw new HttpsError("failed-precondition", "The unmask window has not expired yet.");
   }
   ```
   **Throw here, unlike `handleDisconnect`'s `still-present` return.** The client needs to distinguish "not yet" from "done" so it can retry (§3.3); a silent success would latch the client and the window would never close.
3. **Change nothing else in this function.** The flush block, the `resolvedVotes` construction, the `updatedCards` write and `unmaskDeadline: 0` are all correct as written.
4. **Do not add this guard to the other two flush sites.** `pendingScoreDeltas` is flushed in three places — `advancePhaseInternal` (`index.ts:~1836`), `advanceToNextResolution` (`~2013`) and `closeUnmaskWindow` (`~2282`). The first two run when the game legitimately moves past the card, at which point nobody is guessing any more. Guarding those would strand the pending deltas. **This is also the reason a failed close is not a disaster:** if `closeUnmaskWindow` never succeeds for a card, the tray stays empty for that card but the scores are still applied when the host advances. No score is ever lost or double-applied.

### 2.4 Validation — the falsifying test comes first

**Write this one before anything else, run it against the current code, and watch it fail.** Paste the failing output into the commit body.

- **F1 — the fix.** Advance to reveal on a card where someone was fooled. Assert `unmaskDeadline > Date.now()` (proving the window is genuinely open — *asserting the rejection without proving the window was open proves nothing*), then call `closeUnmaskWindow` as the fooled voter and assert it throws `failed-precondition`. Then assert, in a fresh read: `card.scoreDeltas` is still `undefined`, and `unmaskDeadline` is **unchanged** — not `0`.
- **F2 — the happy path still works.** With the deadline forced into the past (write `unmaskDeadline: Date.now() - 1000` directly onto the room), call it and assert `scoreDeltas` is the full correct map and `unmaskDeadline === 0`.
- **F3 — idempotency, asserted on scores and not on absence of error.** Call it **twice** after expiry and assert each player's `totalScore` equals the value implied by the votes the test cast — computed in the test, **not** read back from the summary. Because Issue 124's implementation defers `totalScore`, `timesFooled` and `playersDeceived` into `pendingScoreDeltas`, a double flush would corrupt scores, and "it returned success twice" would not catch it.
- **F4 — concurrency.** Two different members call in the same tick (`await Promise.all([...])`). Assert scores are applied exactly once, by the same computed-in-test arithmetic as F3.
- **F5 — over-reach guard, non-member.** A user who is authenticated but not in the room gets `permission-denied`, both while the window is open and after it has expired. The guard must not have changed who may call.
- **F6 — over-reach guard, nobody fooled.** On a card where `unmaskDeadline` is `null`, calling it returns success and **leaves `card.scoreDeltas` exactly as reveal published it** — it must not be overwritten with `{}`.
- **F7 — over-reach guard, the other flush paths.** `advanceToNextResolution` still flushes pending deltas when the host advances **during** an open window. This must still work; it is not the leak, and guarding it would strand the deltas.

**Then re-run F1 with the guard removed and confirm it fails.** A guard whose test passes with the guard removed is decoration.

---

## 3. Q1 — the client trigger (133 → A, part 2 of 2)

**What this means for the user:** the points tray fills in even when the host has already left the game.

### 3.1 The gap

`lib/screens/phase4_reveal.dart:89` reads:

```dart
if (gs.currentPlayer?.isHost == true && !_hasClosedUnmaskWindow) {
```

If the host has left or backgrounded the app, nobody calls, `scoreDeltas` is never published, and the points tray and standings deltas stay empty for the rest of that card.

### 3.2 ⚠️ The trap: this timer ticks every 200 ms

`_countdownTimer` is `Timer.periodic(const Duration(milliseconds: 200), ...)` (`phase4_reveal.dart:83`). Two consequences that must both be handled, or the fix is worse than the bug:

- **Never clear the latch unconditionally on failure.** A client whose clock runs 5 seconds fast would fire **25 rejected calls per card**, times every player at the table.
- **But never latch permanently on failure either.** `unmaskDeadline` is a server-generated absolute timestamp compared against each client's own clock. If every client's clock is ahead of the server's, every client calls early, every call is rejected, and — if they all latched — **the window would never close for that card.** That is the empty-tray regression this item exists to remove, reintroduced by the fix for it.

### 3.3 Implementation

1. **Delete the `isHost` condition.** Any room member triggers the call. Keep the existing per-card `_hasClosedUnmaskWindow` latch, which is already reset when the card changes (`phase4_reveal.dart:264`) — that reset is correct; do not touch it.
2. **Add a safety margin.** Fire only when `now >= state.unmaskDeadline! + 1500`, not at the deadline itself. 1500 ms absorbs ordinary clock skew so the common case never produces a rejected call.
3. **Make the service wrapper report the outcome.** Change `GameService.closeUnmaskWindow()` (`lib/services/game_service.dart:704`) from `Future<void>` to **`Future<bool>`**:
   - `true` — the server closed it, or it was already closed.
   - `false` — the server threw `failed-precondition` (not yet expired). Match on `e.code == 'failed-precondition'`, **on the code and never on the message** — that rule already burned this project once (Issue 93).
   - Any other exception: log via `debugPrint` and return `true`, so an unrelated failure does not spin the retry loop.
4. **Retry, but bounded.** In the timer callback:
   ```dart
   if (!_hasClosedUnmaskWindow && now >= state.unmaskDeadline! + 1500) {
     _hasClosedUnmaskWindow = true;              // latch immediately: stops the 200ms storm
     gs.closeUnmaskWindow().then((closed) {
       if (!closed && mounted && _closeAttempts < 5) {
         _closeAttempts++;
         _hasClosedUnmaskWindow = false;         // allow exactly one more attempt
       }
     });
   }
   ```
   Add `int _closeAttempts = 0;` beside `_hasClosedUnmaskWindow`, and **reset it to 0 in the same place the latch is reset** (`:264`, when `currentTargetId != _previousTargetId`). Five attempts across a card is ample for any plausible skew and bounded enough that a badly-set clock cannot spam.
5. **A rejected call must never surface to the user.** No snackbar, no dialog. It is an expected outcome of clock skew, not an error.
6. **Give up quietly after five attempts.** Per §2.3 step 4, the pending deltas are still flushed when the host advances, so the worst case is one card whose tray stayed empty — not a lost or wrong score. Say this in the commit body so nobody later "fixes" it with an unbounded retry.

### 3.4 Validation

- **W1 — the falsifying widget test.** A **non-host** player on the reveal screen, past `unmaskDeadline + 1500`, causes exactly one `closeUnmaskWindow` call. **Run it against the current code and watch it fail** — today only the host calls.
- **W2 — the host still calls.** Over-reach guard: removing the `isHost` condition must not have removed the host's own trigger.
- **W3 — no storm.** Hold the clock at `unmaskDeadline + 1500` and pump **20 ticks (4 seconds)** with the fake returning `true`. Assert the call count is exactly **1**. This is the assertion that proves the latch works at 200 ms.
- **W4 — bounded retry.** With the fake returning `false` every time, pump 60 ticks and assert the call count is exactly **6** (the initial call plus five retries) and no more. Falsify by removing the `_closeAttempts` cap and confirm the count runs away.
- **W5 — the margin.** At `unmaskDeadline + 500` (inside the margin), assert **zero** calls. At `+1500`, assert one.
- **W6 — per-card reset.** Advance to a second card and assert a fresh call is made — the latch and the attempt counter both reset.
- **W7 — silence.** After a `false` response, assert no `SnackBar` is in the tree.

### 3.5 Blast radius

`functions/src/index.ts` (`closeUnmaskWindow` only) · `lib/services/game_service.dart:704` (return type; **check for other callers before changing the signature** — there is currently one) · `lib/screens/phase4_reveal.dart` (`:41` field, `:89` trigger, `:264` reset) · `functions/test/game_e2e.spec.ts` · `test/phase4_reveal_test.dart` or a new `test/unmask_close_test.dart` · **`docs/design_scoring_and_ui.md` §3.3** currently describes the close path without the deadline bound — update it to state that the server refuses an early close and that any member may trigger it.

---

## 4. Q2 — Five-player Marionette soak

**What this means for the user:** every functional defect this project has ever had was found by a person playing the game, and every one of them was found at **three** players. Five players is where the rotation, the forgery chain and the departure logic all get harder, and none of it has ever been driven on a device.

**This is a test-only item. Write no production code.** If the soak finds a defect, **stop and file it** in `docs/ongoing_general_errors.md` with options and a blank selection line — do not fix it inside the soak, because a report written against a moving build proves nothing.

### 4.1 Why five, specifically

At five players the following become reachable for the first time, and all of them are untested on a device:

- `forgeriesPerCard` defaults to `Math.min(activePlayers.length - 1, 5)` = **4** (`index.ts:640`), so a card carries **1 truth + 4 forgeries = 5 options**. Issue 132's one-option-per-row layout was designed for exactly this and has only ever been seen with 3.
- A table can lose **two** players and still play. The 3-player floor (`activePlayerCount < 3` → `gameOver`, `index.ts:1321`) has only ever been hit from 3 → 2.
- The forgery **assignment chain** has enough links to re-link non-trivially when someone in the middle leaves (`index.ts:1246`).
- The **current reader** can leave mid-vote with other readers still queued behind them (`index.ts:1306`), which at 3 players almost always collapsed straight to game over instead.

### 4.2 Prerequisites — do these in order, and prove each one

1. **Five Marionette servers must be responding.** `.agents/mcp_config.json` already declares `marionette-p1` … `marionette-p5` (committed in `68e4bac`). **The MCP client must have been restarted since that commit to see p4 and p5** — confirm all five respond before booting anything. If the harness only exposes three, **stop and tell the user**; do not silently run a 3-player soak and label it five.
2. **Five booted simulators, five distinct device models.** Record each `udid` and DDS port in the report header. The existing convention is p1→8182, p2→8282, p3→8382; continue it as **p4→8482, p5→8582**.
3. **`.env` must contain `USE_EMULATOR=false`.** It is a bundled asset — changing it after the build has no effect.
4. **Uninstall the app on every one of the five simulators** before installing, so no stale room is restored from `SharedPreferences`. A resumed room from a previous run is the single most common way these soaks produce nonsense.
5. **Build once, then prove the binary is newer than the source.** Paste both lines into the report header:
   ```bash
   stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
   ```
6. **Install to one device at a time.** Concurrent builds corrupt `build/`.
7. **Paste `flutter --version` into the header** rather than recalling it.
8. **Confirm `./scripts/check_deploy_fresh.sh` exits 0** and paste the function count and timestamp. The soak hits production; a stale server invalidates every server-side assertion in it.
9. **Run the five-player emulator pre-flight (§4.5) and confirm it passes.** Do this before booting a single simulator.

**A workable device sequence.** Adapt models to what this Mac has; the requirement is five distinct, booted devices, not these exact ones:

```bash
xcrun simctl list devices available          # pick five, record the UDIDs
xcrun simctl boot <udid>                     # one per device
xcrun simctl uninstall <udid> com.whylabs.gaslight   # MUST run on all five
flutter build ios --simulator                # ONCE, before any install
xcrun simctl install <udid> build/ios/iphonesimulator/Runner.app
```

**`uninstall` is the step people skip and then lose an hour to.** `SharedPreferences` survives a reinstall-over-the-top, so a device that played a previous room will silently rejoin it instead of showing `THE GUEST LEDGER`, and the first two blocks will make no sense.

**Never run two `flutter build` invocations at once.** Build once, install five times.

### 4.3 Where the report goes, and the evidence contract

Write to a **new file, `docs/playthrough_findings_5player.md`.** Do not append to `docs/playthrough_findings_marionette.md` — that is the Wave N report and its header describes a different build.

**Block IDs must be `E<number>` and must continue from the existing report: start at `E22`.** The gate only recognises headings matching `^### [EW]\d+`, and reusing `E1`–`E21` would make cross-references ambiguous.

Add the new file to the battery and say so in the commit:
```bash
./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md
```

Every block takes this shape. The gate parses it mechanically:

```
### E22 — Short title
- **Verdict:** PASS | FAIL | NOT RUN
- **Devices:** P1 `model` (Name), … 
- **Room Code:** `XXXX`
- **What I did:** numbered steps
- **Observed:** …
- **Reference:** file:line
- **Expected:** one sentence
```

**Rules the gate enforces — R1–R5:**
- A `PASS` or `FAIL` block **must** have a non-empty `**Observed:**` field. `NOT RUN` **must** have a `**Reason:**`.
- `**Observed:**` must contain at least one real artefact: a screenshot path matching `docs/playthrough_evidence/<name>.png`, a widget entry (`Type: …` or `Text: "…"`), or a `flutter:` log line.
- **A `grep -` in an Observed field is a hard failure.** A grep is not an observation.
- **Every cited `.png` must exist on disk.** Cite it only after you have written it.
- **Name the field `Observed:`.** A renamed variant is what let a bad block through a human review once already.

**And a rule the gate cannot enforce, which matters more than the ones it can:** **open the screenshot and look at it.** A path satisfies R5; it does not prove the image shows what the prose claims. Three separate defects in this project's history survived because nobody did.
### 4.4 Driving reference — target keys, not pixel bounds

Earlier reports recorded taps by `bounds: {"x":4.0,"y":66.0,…}`. **Do not drive that way.** Bounds differ across five device models, and a soak that hits the right pixel on an iPhone 17 Pro hits the wrong widget on an iPhone SE. Every control the soak needs either has a `ValueKey` or unique text. Use those.

| What you need to do | Target |
|---|---|
| Enter a display name | key `player_name_field` |
| Enter / re-enter a room code | key `room_code_field` |
| Create a room | text `CREATE ROOM` |
| Select a deck in the carousel | key `deck_<deckId>` — e.g. `deck_hypotheticals`, `deck_rated_r_nsfw` |
| Open the deck preview | key `peek_inside_<deckId>`, label `PEEK INSIDE` |
| Read a previewed prompt | keys `peek_prompt_0` … `peek_prompt_7` |
| Re-draw the preview sample | key `deck_peek_shuffle`, label `SHUFFLE` |
| Set forgeries per card | key `forgeries_<n>` — at five players `forgeries_1` … `forgeries_4` |
| Set round count | key `rounds_<n>` |
| Set timer length | key `timer_seconds_field` |
| Toggle timers | the `Disable Game Timers` switch (host-only) |
| Kick a player | key `kick_<playerId>`, then `REMOVE` |
| Start the match | text `START GAME` |
| Write a truth or forgery | key `answer_field` |
| Submit an answer | text `SUBMIT DOSSIER`, or send the keyboard **done** action (E28) |
| Re-roll a prompt | text `RE-ROLL PROMPT` |
| Cast a vote | tap the option row, then text `CONFIRM VOTE` |
| Leave mid-game (truth / forgery / vote / reveal) | the `Leave game` IconButton in the AppBar leading slot, then `LEAVE GAME` in the dialog |
| Leave **from the lobby** | a **different control**: the `Leave room` IconButton (`lobby_screen.dart:595`), then **`CLOSE ROOM`** if host, **`LEAVE`** if guest — *not* `LEAVE GAME`, which does not exist on that screen |
| Return to lobby after a match | text `RETURN TO LOBBY` (bar keyed `game_over_bottom_bar`) |

**Deck ids come from the catalogue, never from a guess:** `hypotheticals`, `real_life`, `unhinged_quirks`, `love_life`, `rated_r_nsfw` (`functions/src/prompt_decks.ts`). `hypotheticals` is the fallback and has 50 prompts — use it unless a block says otherwise.

**E23 becomes mechanical with these keys:** assert `peek_prompt_0` through `peek_prompt_7` exist and **`peek_prompt_8` does not**. That is a far stronger assertion than counting rows in a screenshot, and it is the one that would catch an off-by-one in the sampler.

**If a control you need has no key and no unique text, add a `ValueKey` for it** — that is a legitimate, tiny production change, and it is the only production change Q2 may make. Note it in the commit body.

### 4.5 Pre-flight: prove five players works in the emulator FIRST

**Do this before booting a single simulator.** The emulator suite's largest game is **four** players (`p_g3`/"Dave", `game_e2e.spec.ts:2431`). **Five players has never been exercised anywhere in this project** — not in a test, not on a device. The rotation plan at five players with four forgeries is therefore unproven, and a rotation bug found after an hour of device driving costs an hour.

Write one throwaway emulator test: five players, `forgeriesPerCard` at its default, one full round to `gameOver`. Assert only that it completes and that every card ends with **five options** and a distinct author per option. **If this fails, stop and file it** — a device soak on a broken rotation produces nothing but noise. Keep the test; it is worth having regardless.

### 4.6 Match configuration, and the constraint that shapes it

**⚠️ The 3-player floor caps every match at three departures.** `handleDisconnect` ends the match when the remaining active count drops below 3 (`index.ts:1321`). From five that means: lose one → 4 (continues), lose two → 3 (continues), **lose three → 2 → `gameOver`.** You cannot run every departure block in one match, and you must not plan to.

**Two consequences to design around:**
- **The third departure always ends the match**, so any block that asserts "the match continues" must be the **first or second** departure — never the third. E35 (host departs, crown transfers, play continues) is the one most easily got wrong this way.
- A rejoin (E32) does **not** consume a departure. A force-quit followed by a relaunch returns the player to their seat, so the count never drops.

**Run five matches, not ten.** Each row below is one room, played from the lobby:

| Match | Config | Blocks | Departures used |
|---|---|---|---|
| **M0 — lobby** | any | E22, E23, E24, E25, E26 | E26 destroys the room deliberately |
| **M1 — writing-phase departures** | forgeries **2**, rounds **2**, timers off | E27, E28, E29, E30, E31, then a third departure → E36, E37 | 3 (truth, forgery, any) |
| **M2 — resolution-phase departures** | forgeries **2**, rounds **2**, timers off | E35 *(first)*, E33 *(second)*, E34 *(third → ends)* | 3 (host, reader-in-vote, reveal) |
| **M3 — timers** | forgeries **2**, rounds **1** | E32, E38, E39 | 0 (E32 is a rejoin) |
| **M4 — wide card + presence** | forgeries **default (4)**, rounds **2** | E41, E42, E43, E40 | 0 (E40 is a force-quit that is never relaunched) |

**Why forgeries = 2 for M1–M3.** At five players the default is 4, which means four forgery rotations — twenty text entries per round on top of five truths. Two keeps the typing tractable while leaving every departure path reachable. **M4 deliberately uses the default of 4** so a card carries five options; that is the whole point of M4 and the reason it is only one round for the wide-card blocks.

**Driving the lobby controls.** `Forgeries Per Card:` renders as `ChoiceChip`s keyed `forgeries_1` … `forgeries_4` at five players (`lobby_screen.dart:700`); the count is `(activeCount - 1).clamp(1, 8)`. `Disable Game Timers` and the `Seconds per round` field are host-only.

**Timers now default OFF** (Issue 130), so the old reports' "timers ON as a deliberate deviation" note is **inverted** — turning them *on* is now the deviation. Record it wherever you do.

### 4.7 The blocks

Each entry gives the setup, the action, and **what must be true afterwards**. Assert the stated post-condition on **every** device named, not just the one that acted — a departure that looks right to the leaver and wrong to everyone else is the failure mode.

**⚠️ Marionette drives the UI and cannot read Firestore.** Every assertion below must be satisfied by something on a screen: a widget entry, visible text, a screenshot, or a `flutter:` log line. Where a server field matters, the block says which UI surface reveals it. **Do not write an assertion you cannot observe** — mark it NOT RUN with a reason instead.

#### M0 — lobby

- **E22 — Five players join and the ledger shows all five.** Alice hosts; Bob, Charlie, Dana, Erin join by code. **Assert on all five devices:** five avatars in the roster, exactly one marked host, and the room code visible. *(The 10-player cap at `index.ts:535` is nowhere near.)*
- **E23 — Peek inside a deck before choosing.** On P1, tap `PEEK INSIDE` on the centred deck card. **Assert:** exactly **8** prompt rows under `A TASTE OF WHAT'S INSIDE`; `SHUFFLE` changes the visible set; dismissing leaves the selected deck unchanged (the carousel still shows the same deck name). *(Issue 126.)*
- **E24 — Timers default to off; the duration field appears only when they are on.** **Assert:** `Disable Game Timers` is **on** by default; toggling it off reveals `Seconds per round` defaulting to **60** with helper text `15–300 seconds. Voting gets 75% of this.`; entering `10` and `301` are both refused. *(Issue 130.)*
- **E25 — Host kicks a guest in the lobby.** Alice kicks Erin. **Assert:** Erin's device returns to `THE GUEST LEDGER`; the other four rosters show four players. Erin rejoins afterwards.
- **E26 — Host leaving the lobby closes the room for everyone.** Run this **last in M0**, because it destroys the room. Alice taps the `Leave room` IconButton — **not `Leave game`; that control does not exist in the lobby.** **Assert the warning first:** the dialog reads `Close this room?` with body `You are the host. Leaving will close the room for everyone.` and offers `STAY` / `CLOSE ROOM`. Confirm with `CLOSE ROOM`. **Assert on all five:** every device returns to `THE GUEST LEDGER`. **Then prove the room is really gone the only way the UI can:** have Bob type that same room code into `room_code_field` and assert the **room-not-found error surface** appears. **Reference:** `index.ts:1213` (`roomClosed: true`). *(A guest doing the same sees `Leave this room?` and `LEAVE`, and the room survives — worth a second, cheap assertion while you are here.)*

#### M1 — writing-phase departures

- **E27 — Guidance lines are present in all three phases.** **Assert the exact strings:** truth — `Write something true about you — the more surprising, the better. Others must be able to believe it.`; forgery — begins `You are writing as ` and names a **real player name**, never an id; vote — `Talk it out — discussion is part of the game.` **Reference:** `lib/screens/phase2_craft.dart:434`. *(Issue 129.)*
- **E28 — The return key submits, and still enforces the length bound.** On P2 during truth, type an answer and send the keyboard's **done** action instead of tapping the button. **Assert:** submitted, screen advances to waiting. Then on P3, type **101 characters** and send done. **Assert:** refused, with a snackbar containing `Trim it to 100 or fewer`, and no submission. **Reference:** `lib/screens/phase2_craft.dart:540`. *(Issue 131.)*
- **E29 — The room code is visible in every in-game phase.** **Assert:** `ROOM:` plus the code is legible in the AppBar during truth, forgery, vote and reveal. Capture it on the narrowest device in the set, where clipping would show first. *(Issue 120.)*
- **E30 — Guest departs during the TRUTH phase (5 → 4).** Dana taps `Leave game` and confirms. **Assert:** Dana's device returns to the ledger; **each of the other four shows a snackbar reading `Dana has left the parlour.`** *(Issue 128)*; play continues; **the roster on each remaining device now shows four players** (this is how you observe `totalPlayers` — do not try to read the field).
- **E31 — Guest departs during the FORGERY phase (4 → 3), and the assignment chain re-links.** **Before Erin leaves, write down what every device's forgery screen says after `You are writing as …`.** That line is your view of `currentCardAssignments`. Erin leaves mid-forgery. **Assert:** the device that had been writing on *Erin's* card now names a **different, still-present** target — nobody is left writing on a card that no longer exists — and no device shows a blank or id-shaped target. Play continues at three. **Reference:** `index.ts:1246`. **This is the block most likely to find something:** it is the only place the chain is re-linked, and it has never been driven at any player count.
- **E36 — Dropping below three auto-ends the match with scores intact.** A third player leaves. **Assert on both survivors:** navigation to Game Over, `THE NIGHT'S HONORS` present, and **scores preserved** rather than zeroed. **Reference:** `index.ts:1321`.
- **E37 — A departed player still appears by name in MATCH HIGHLIGHTS.** On that same Game Over screen, **assert a player who left mid-match is still named** in `BEST LIE OF THE NIGHT`, `CLEANEST TRUTH` or a head-to-head line — **a display name, never a raw id.** *(Issue 115. This is the cross-feature assertion: it exists only where a departure and a completed match meet, which no unit test does.)*

#### M2 — resolution-phase departures

- **E35 — The host departs mid-match and the crown transfers.** ⚠️ **This must be the FIRST departure of M2** — as the third it would end the match and the assertion would be untestable. Alice leaves during an active phase. **Assert:** exactly one remaining device now shows the host-only controls, and it is the **earliest joiner** (`remainingActivePlayers[0]`, `index.ts:1342`); play continues; the room is **not** closed — that only happens from the lobby (E26).
- **E33 — The current reader departs mid-VOTE with readers still queued.** Wait until the vote screen names Charlie's card **and at least two more readers remain**, then Charlie leaves. **Assert:** the vote phase moves to another player's card rather than stalling; the remaining players can still cast a vote; **nobody sees an empty vote screen.** **Reference:** `index.ts:1306`. **This case is unreachable below five players** — at three, losing the reader hits the floor instead.
- **E34 — A player departs during REVEAL (third departure → match ends).** **Assert:** the reveal does not strand; the standings drop the departed player; the survivors reach Game Over cleanly.

#### M3 — rejoin and timers

- **E32 — Rejoin after a force-quit (seat recovery at five players).** Mid-match, `xcrun simctl terminate` on P4, then relaunch. **Assert:** P4 returns straight into the current phase with its seat, name and score intact — not to the ledger. *(Extends E7 to five players.)*
- **E38 — Timeout fills placeholders, and a placeholder cannot be voted for.** Timers **on**, `Seconds per round = 60`. **⚠️ Not 15.** Four players must actually type an answer before the timer expires, and Marionette entry across four devices does not fit in fifteen seconds; at 15 s you would be testing a mass timeout, not a single one. Have exactly **one** player stay silent through truth. **Assert:** their slot fills with `THE SOUL IS SILENT`; on the vote screen that option is stamped `SEALED` and **cannot be tapped**; the rest of the card votes normally. *(Issue 118.)*
- **E39 — A round where nobody answers is skipped, not stranded.** Timers **on**, `Seconds per round = 15` — here the short timer is correct, because everybody is meant to stay silent. Let all five time out through truth **and** forgery. **Assert:** the table does **not** land on an empty vote screen — it advances to the next round or Game Over — and players see `Nobody answered last round. Dealing a new one.` **Reference:** `index.ts:1630`. *(Issue 125.)*

#### M4 — wide card, and the presence window

- **E41 — Five options, one per row, all reachable.** With forgeries at the default of 4, reach the vote phase. **Assert:** options render **one per row**, not a two-column grid; **all five are reachable by scrolling**; no text truncated or ellipsized on the narrowest device. Screenshot every device. *(Issue 132 — the configuration it was designed for and has never been seen in.)*
- **E42 — Your own answer is locked out in round 2, not just round 1.** In round **2**, assert the option the player themself authored is greyed and untappable, **and that it is the right one** — the option whose text they wrote *this* round. *(Issue 117: the bug was round 1's option id leaking into round 2, so a single-round check cannot see it.)*
- **E43 — The unmask window withholds the deltas, then publishes them.** On a card where someone was fooled: **assert during the 20-second window** that no per-player points are shown; **assert after it closes** that `POINTS AWARDED THIS CARD` appears with correct values including the unmask ±1, and the standings badges update. **Then assert it still works with the host absent** — have the host leave before the window expires and confirm the tray still fills on the remaining devices. *(Issues 124 and 133. That last sentence is the entire point of Q1's client change and cannot be tested any other way.)*
- **E40 — The presence window really is ten minutes.** ⚠️ **~12 minutes of wall clock. Run it last.** **Timers must be OFF for this block** — with timers on, phases auto-advance during the wait and the match state changes underneath the assertion. Force-quit P5 (`xcrun simctl terminate`) mid-match, **do not relaunch**, and note the time. **Assert at ~2 minutes: P5 is still in the roster on every other device** — this is the whole point, because before Issue 123 they were evicted at exactly this mark. **Assert at ~11 minutes: P5 is gone from the roster.** Record both wall-clock timestamps. **Reference:** `index.ts:179`. **No unit test can cover this** — fake timers do not suspend an isolate. *(Issue 123.)*

### 4.8 Reporting

- One block per assertion, in the shape of §4.3, with a screenshot for anything visual.
- **A block you did not run is `NOT RUN` with a `Reason:`** — never omitted, and never quietly folded into a neighbouring block. An omitted assertion reads as though it passed.
- **Record every deviation**, including any block you simplified because five devices proved unwieldy.
- Close with a **What the harness could not see** section. Known entries before you start: real network jitter; App Store ingestion; anything gated on `kDebugMode`, since Marionette can only attach to a debug build and the release gating is therefore invisible to it.
- **Every defect found is filed, not fixed** — `ongoing_general_errors.md`, options, Pros/Cons, one `(recommended)`, blank selection line.

**Screenshot naming.** Into `docs/playthrough_evidence/`, as `e<block>_p<device>_<what>.png` — the convention already in use there (`e10_p1_gameover.png`, `e16_d3_deck_too_small_warning.png`). Cite the path only **after** the file is written; Rule R5 checks it exists, and a cited-but-absent artefact fails the gate.

**Write the report as you go, not at the end.** This run is hours long across five simulators. Append each block to `docs/playthrough_findings_5player.md` as it completes, and **run the evidence gate after each match**:

```bash
./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md
```

Catching a malformed block after M0 costs a minute; catching it after M4 means re-reading four hours of work. **Check the block count it reports against the number you have written** — a gate that parsed fewer blocks than exist has told you nothing (lesson 2.21).

**Commit per match, not once at the end.** Five commits — `test(playthrough): M0 lobby blocks (E22-E26)` and so on — so a crash or a context limit costs one match, not the whole soak. This is the one place the one-item-one-commit rule bends, and it bends deliberately: the item is a report, and a half-written report that exists beats a complete one that was lost.

**If a block fails, finish the match you are in, then stop.** File the defect with options and report. Do not start the next match: every later block would be running against a build you already know is wrong, and those results would have to be discarded anyway.

### 4.9 Definition of Done for Q2

- [ ] **The five-player emulator pre-flight (§4.5) passed** before any simulator was booted.
- [ ] Five Marionette servers responding, five simulators, five distinct models, ports recorded.
- [ ] `.env` `USE_EMULATOR=false`; app uninstalled on all five before install; binary-newer-than-source proof pasted.
- [ ] `./scripts/check_deploy_fresh.sh` exited **0** before the soak began, with Q1 deployed.
- [ ] `docs/playthrough_findings_5player.md` exists with blocks **E22–E43**, each PASS/FAIL/NOT RUN.
- [ ] `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_5player.md` exits **0**, and the count of blocks it reports **matches the number you wrote** — a gate that parsed fewer blocks than exist has told you nothing.
- [ ] **Every cited screenshot was opened and looked at**, not merely written and referenced.
- [ ] The five matches **M0–M4** were run as laid out in §4.6, and **no match was planned around more than three departures**.
- [ ] E31 (forgery chain re-link), E33 (reader departs mid-vote), E40 (ten-minute presence) and E43 (unmask window without the host) are all genuinely attempted — **these four are the reason the soak exists**; a run that marks them NOT RUN has not delivered Q2.
- [ ] Every defect found is filed with options; **none is fixed in this commit**.
- [ ] **All 22 blocks attempted** — Issue 134 selected **Option A**, the full run. A reduced set is not this item.
- [ ] Controls were driven **by key or unique text, never by pixel bounds** (§4.4). Any `ValueKey` added to make that possible is noted in the commit body.
- [ ] The report was committed **per match**, so no single failure cost more than one match's work.

---

## 5. Q3 — `clock` is imported by production code but declared dev-only

**What this means for the user:** nothing visible today — but a package that ships in the app is currently declared as if it were test-only.

**The gap.** `lib/screens/phase4_reveal.dart:18` has `import 'package:clock/clock.dart';`, and Q1 added `clock: ^1.1.1` under **`dev_dependencies`** (`pubspec.yaml:53`). The analyzer says so, as an **info** — which is why it slipped past a "0 errors, 0 warnings" baseline:

```
info • The imported package 'clock' isn't a dependency of the importing package.
       Try adding a dependency for 'clock' in the 'pubspec.yaml' file
     • lib/screens/phase4_reveal.dart:18:8 • depend_on_referenced_packages
```

**Measured, not assumed:** `flutter build web --release` **succeeds** as things stand, because an application package resolves its own dev dependencies at build time. So this is a mis-declaration, **not** a broken build — do not report it as one. It matters because the declaration is wrong for code that ships, and because the guard against it is an `info` nobody reads.

**Implementation.** Move the `clock: ^1.1.1` line from `dev_dependencies` to `dependencies` in `pubspec.yaml`. Run `flutter pub get`. That is the whole change.

**Validation**
- `flutter analyze lib test` no longer emits `depend_on_referenced_packages` for `clock`. **Grep the analyzer output for that rule and assert zero matches** — the info count alone will not tell you.
- `flutter build web --release` still succeeds.
- `flutter test` still passes at **≥234**.
- **Over-reach guard:** `clock` is still available to `test/unmask_close_test.dart` — a package in `dependencies` is visible to tests too, so nothing is lost by the move.

**Blast radius:** `pubspec.yaml`, `pubspec.lock`. Nothing else.

---

## 6. Definition of Done — Q1 (already met)

- [ ] **F1 written first, run against the current code, and observed to fail.** Failing output pasted into the commit body.
- [ ] The guard **throws `failed-precondition`** while the window is open, and `scoreDeltas` and `unmaskDeadline` are both left untouched by the rejected call.
- [ ] `null` and `0` return early with **no write**, using explicit comparisons rather than a falsy check.
- [ ] **F3 and F4 assert `totalScore` arithmetic**, not merely the absence of an error — deferred increments make double-flush a scoring bug, not a cosmetic one.
- [ ] F5, F6 and F7 pass: non-members still refused; a nobody-fooled card keeps the deltas reveal published; `advanceToNextResolution` still flushes during an open window.
- [ ] **F1 re-run with the guard removed and observed to fail.**
- [ ] W1 written first and observed to fail; a non-host now triggers the close.
- [ ] **W3 asserts exactly 1 call across 20 ticks**, and **W4 asserts exactly 6 across 60** with the cap falsified.
- [ ] A rejected close is invisible to the user.
- [ ] Battery at or above baseline: **0 errors** · **≥227** client · clean functions build · **≥94** functions · deck sync PASS · evidence exit 0.
- [ ] `check_deploy_fresh.sh` goes **red** the moment this lands and stays red until the user deploys — **say so in the commit body** rather than leaving it looking like a regression.
- [ ] Issue 133 moved into the **single** existing Resolved heading, and `design_scoring_and_ui.md` §3.3 updated.

---

## 7. Carry forward — no selection needed, not part of Q1

Do these only if a future item already touches the file. They are not work on their own.

- **P7's departure diff is implemented twice.** `processPlayersSnapshotForTesting` (`lib/services/game_service.dart:80`) is a `@visibleForTesting` mirror of the logic in the real players listener (`:476`). The unit test therefore exercises **the copy, not the shipped path**, and the two can drift silently. Fix by extracting one private method both call — then prove it by breaking the shared method and confirming the test fails.
- **`'THE SOUL IS SILENT'` is a hardcoded Dart literal** in `lib/widgets/card_grid.dart`, duplicating `kMissingAnswerPlaceholder` (`index.ts:176`). A sentinel with two owners (lesson 2.31).
- **`kMaxAnswerLength` is duplicated** across the client cap and the server bound. Consistent today; a change to either needs the other in the same commit.

---

## 8. Verified baseline — measured in-session, August 27, 2026

This is the regression bar. Every number came from running the command.

| Gate | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze lib test` | **0 errors**, 0 warnings, 221 infos |
| Client tests | `flutter test` | **227 passing** |
| Functions build | `npm --prefix functions run build` | clean |
| Functions tests | `npm --prefix functions test` | **94 passing** |
| Deck sync | `./scripts/check_decks_in_sync.sh` | **exit 0** — 5 decks, 295 lines |
| Deploy freshness | `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH** (16 functions, deployed 2026-08-27T16:02–16:03Z). **Q1 will turn this red.** |
| Playthrough evidence | `./scripts/check_playthrough_evidence.sh` | **exit 0** — 21 blocks: 20 PASS, 1 NOT RUN, 0 FAIL |

---

## 9. Already delivered — do NOT rework

- **All of Wave P except the Issue 133 defect.** Verified in source and against a running emulator, August 27, 2026:
  - **P1**/122 — the timeout test picks a non-placeholder, non-self option; all three original assertions survive.
  - **P2**/125 — `concludeResolutionRound` (`index.ts:1352`) was **moved, not copied**: one definition, two callers (`:1639`, `:2068`). The empty-order path passes the already-read `sealedDataMap`, so the helper performs no reads after a write.
  - **P3**/123 — the presence window gates **the action, not the caller**. `handleDisconnect` takes a `"leave" | "kick" | "presence" | "reconcile"` reason and **returns** `{ success: false, reason: "still-present" }` rather than throwing, because the client swallows errors. **Falsified:** disabling that return fails exactly the 150 s test and leaves the other five green.
  - **P5**/130 — timers off by default at all four sites with `!== undefined` guards; all six hardcoded durations replaced by `getPhaseDurations` (`index.ts:215`), clamped 15–300, vote at 75%.
  - **P6**/127 · **P7**/128 · **P8**/126 · **P9**/132 (`ListView.separated` with `ConstrainedBox(minHeight: 72, maxHeight: 132)` — the unbounded-height trap avoided; tests at 320/375/430 pt with the real Lora font) · **P10**/131 · **P11**/129.
- **Wave O's six good items:** **O1**/117 — the `{ merge: true }` writes to `sealed/{playerId}` became full-document sets: `startGame` (`index.ts:712`), the round advance inside `concludeResolutionRound` (`:1411`), and the `transaction.set(sealedRef, sealedData)` calls in `advancePhaseInternal` (`:1502`–`:1607`). This is safe because `sealedDataMap` is a complete in-transaction read and the seat token lives in a **different** document (`sealed/seat_{playerId}`). **The `_summary` doc still uses `{ merge: true }` (`:1771`) and must keep it** — that one is supposed to accumulate. **O3**/115 · **O6**/114 · **O7**/116 · **O8**/119 · **O9**/121 (the target's vote is refused independently at `index.ts:924`).
- **Issue 102** — the pre-demo playthrough in room `GLRD`: **20 PASS, 1 NOT RUN, 0 FAIL**. E7 seat recovery and E8 host kick both device-verified.
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R5 mechanically.
- **Issue 103** — seven `DEBUG:` sites gated; **all seven buttons still exist** — gated, not deleted.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken`, or a stale seat; `votes` stores opaque option UUIDs; the reveal merges only the current card; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**.

**Build numbers:** App Store Connect has consumed **build 4**. `pubspec.yaml` must exceed it — `1.0.0+5` or higher. A reused number is rejected at upload.

---

## 10. Accepted equivalents & intentional decisions — do NOT change

**Accepted equivalents** — different structure, same guarantee. Do not "fix" these back:

- **P10's submit button is not pinned with `viewInsets`.** It was moved out of the inner scroll view and relies on `Scaffold.resizeToAvoidBottomInset`. The test proves the guarantee at 320×640 with `FakeViewPadding(bottom: 300)`.
- **P11's guidance line sits in a bordered parchment container** rather than the plain italic text the spec named. Validated at 320 pt.
- **P1 adds a `setReady` fallback** when a voter has no non-self votable option.
- **P3 defaults a missing `reason` to `"leave"` when the caller is the subject**, rather than a blanket `"presence"`. Better for old clients.
- **Issue 124's implementation went beyond Option A into Option B**, deferring `totalScore`, `timesFooled` and `playersDeceived` through `pendingScoreDeltas` / `pendingTimesFooled` / `pendingPlayersDeceived`. **Accepted.** It closes the inference channel Option A left open, and the three flush sites each guard on the field's presence and `FieldValue.delete()` inside a transaction. **The standings strip legitimately holds still during the unmask window — that is Option B's stated cost, not a bug.** Q1's F3 and F4 exist because these deferred increments make a double flush a scoring bug.

**Invariants** — do not change:

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** This is why `pendingScoreDeltas` lives there.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **Never let a client bound exceed the server's.** This is the invariant Q1 restores; `castVote` is the model.
- **The presence window gates the ACTION, not the caller.** `isDead` inside an authorization condition is what made Issue 120 inert for a full wave. Do not move it back.
- **The option id is the authority; text is the fallback**, consulted only when the id is null.
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **Error surfaces match on `e.code`, never on the message**, and never interpolate an exception into user-facing text.
- **Dialogs render on `groundRaised`.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Never accept Xcode's "Update to recommended settings" dialog.** It enables `ENABLE_USER_SCRIPT_SANDBOXING`, which **breaks the iOS build**. Proven August 25, 2026: `Sandbox: dartvm(...) deny(1) file-read-data .../Flutter.framework/Flutter`. The answer stays no (lesson 2.29).

**The deck catalogue is data and lives in exactly one file.** `functions/src/prompt_decks.ts` is the source of truth; `lib/utils/prompt_decks.dart` is **generated**. **No file outside the catalogue may branch on a deck id.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; a scheduled-task close for the unmask window (Issue 133 Option C); a host-only trigger with a server-side sweep (Issue 133 Option B); distinguishing *why* a player left (Issue 128 Option B); per-phase timer durations (Issue 130 Option B); plus the declined options in `ongoing_general_errors.md` §4.

---

## 11. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens, presence & the disconnect reason union, callables, deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 12. Validation standard

**Ask what the change permits, not only what it fixes** (lesson 2.32). The probe that caught Issue 133 called the new callable; a probe that re-read the room document reported the leak closed.

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number.

**A constant's value is not behaviour** (lesson 2.30). Drive the assertion through the entry point a client uses.

**Falsify every guard.** A guard whose test passes with the guard removed is decoration.

**Assert the arithmetic, not the absence of an error.** F3 and F4 exist because "it returned success twice" cannot detect a double-applied score.

**A test that exercises a mirror of the shipped logic tests nothing about the shipped logic** (§7, first bullet).

**Record every substitution.** An omitted assertion reads as though it passed.

**A green suite is not evidence about anything it cannot observe.** All seven gates were green while `closeUnmaskWindow` was unguarded and deployed.

**A driven playthrough is not a played one.**

---

## 13. Feedback loop — why this defect escaped a detailed spec

The Wave P spec named this guard **twice** — once in the implementation steps, once in the Definition of Done — and it still fell out. Three corrections, all applied in this document:

- **A guard on a new entry point needs its own numbered sub-item, not a clause.** In Wave P it was one bullet inside a large item whose hard part was the `pendingScoreDeltas` plumbing, and a validation line reading "refuses an early close" is easy to skim as already satisfied by the surrounding checks. Here it is §2 with its own state table and its own F1.
- **The adversarial test must attack what the change added.** Verifying Issue 124 by re-reading the room document reports success. Only calling the new callable finds the hole.
- **State every value a field can hold when the guard reads it.** `unmaskDeadline` is `null`, `0`, future or past, and a naive truthy check gets two of those wrong. §2.2 is a table for that reason.

---

## THE LOOP

```
(1) STUDY §2 and §3 (Q1) or §4 (Q2) here + Issue 133 in
    ongoing_general_errors.md + the files at the cited anchors. RE-GREP every anchor; numbers drift -- three did
    between Wave P and this document.
(2) ENUMERATE WHAT THE CHANGE PERMITS, not only what it fixes.
(3) GREP THE EXISTING SUITE for tests asserting the rule you are changing.
    Update them in the SAME commit.
(4) WRITE F1 and W1 FIRST. Run them. OBSERVE THEM FAIL. Record the exact
    output.
(5) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(6) VALIDATE F1-F7 and W1-W7, then RE-RUN F1 WITH THE GUARD REMOVED and
    confirm it fails.
(7) RE-RUN THE FULL BATTERY -- all seven, exit codes read BARE, not piped.
    check_deploy_fresh WILL be red; that is expected and must be explained.
(8) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options, Pros/Cons, one (recommended),
    and a blank `Your selection: _____`.
(9) COMMIT: Conventional Commit, WHY in the body -- never a bare title. Move
    Issue 133 into the SINGLE existing Resolved heading and update
    design_scoring_and_ui.md §3.3.
```

**Q1 has landed. The deploy is the user's and Q2 cannot start until it happens.** Q3 may be done now. Once Q2's report is written and any defects it found are filed with options, **the queue is empty.** Report the state and stop. Do not invent work.
