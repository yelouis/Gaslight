# Agent Execution Guide — Active Build: SEC1 → SEC7 (security remediation) — August 17, 2026

**You are an engineering agent with no memory of this project.**

**This build fixes six verified security defects found in a whole-repository security review.** Every finding below was produced by a discovery pass and then **independently re-verified by a second reviewer that read the code from scratch and was instructed to reject or downgrade**. Two candidates were downgraded, one was rejected outright and is recorded in §10 so it is not re-proposed. One exploit was reproduced end-to-end against the Firebase emulator.

**Do not treat these as suggestions.** The severities, the file:line anchors and the exact code shapes below were verified against source. Where a fix has a subtle failure mode, it is called out — read the whole item before editing.

| # | Item | Severity | Touches | Deploy |
|---|---|---|---|---|
| **SEC1** | Deny `list` on `/rooms` | MEDIUM | `firestore.rules` | **rules only** |
| **SEC2** | `joinRoom` seat takeover | **HIGH** | server + client | functions |
| **SEC3** | `castVote` laundering the answer key | MEDIUM | server + **13 client/server readers** | functions |
| **SEC4** | Reveal merge publishes every card | MEDIUM | server | functions |
| **SEC5** | Unmask answer in client state pre-deadline | LOW-MED | client | — |
| **SEC6** | Debug callables lack membership/host checks | LOW | server | functions |
| **SEC7** | Deploy and verify | — | production | **both** |

Full finding text, exploit paths and rationale: `docs/ongoing_general_errors.md`, Issues 96–101.

---

## 0. Verified baseline — the regression bar

Measured at `1f15372`, clean tree. **Do not let any of these move except upward.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (26 warnings, 196 infos) |
| `flutter test` | **156/156** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **54/54** |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions |

---

## 1. Standing constraints

- **One item = one commit.** SEC1–SEC6 are six commits.
- **Write validation that fails against the broken state, and observe it fail** before fixing. **Apply this to the test as well as the code**: after writing a guard's test, remove the guard, watch the test go red, restore it, and record the failure text **in a comment on the test** as well as the commit body. A step whose only product is a commit-body sentence gets skipped — that is how Issues 89.2 and 92 happened.
- **Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run (Issue 92).
- **Match on the error `code`, never the message.** A raw `Error` from a callable flattens to `INTERNAL`.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Security tests belong in `functions/test/rules.spec.ts` (rules) and `functions/test/game_e2e.spec.ts` (callables).** `test/fake_functions.dart` does **not** enforce `firestore.rules` — a Dart widget test can never prove a rules or authorization fix. Keep it that way.
- **Do not touch anything in §9 or §10.**

---

## 2. SEC1 — Deny `list` on `/rooms`

**What this means for the user:** today anyone on the internet, with no account and no room code, can download a list of every live game and every player in it. That list is what turns SEC2 from a targeted attack into an automated sweep.

### The gap

```
// firestore.rules:9-18
match /rooms/{roomCode} {
  // Anyone can read rooms to fetch game state
  allow read: if true;
  ...
  match /players/{playerId} {
    // Anyone can read the player list
    allow read: if true;
```

In Firestore, `read` expands to **`get` + `list`**. Because the condition is the literal `true` and never dereferences `resource`, Firestore does not require a query to be provably constrained — so `db.collection('rooms').get()` returns **every live room**, unauthenticated. Verified empirically: a room document read with **no Authorization header at all** succeeds.

**The client never needs this.** `game_service.dart:232` and `:359` only ever address rooms by exact document ID. The `players` subcollection `list` **is** genuinely used (`game_service.dart:201`, `:371`), so that rule must stay.

### Implementation

Split the verbs on the room document only:

```
    match /rooms/{roomCode} {
      // Clients read a room by its exact code. Collection enumeration is denied:
      // `allow read` would grant `list`, letting anyone download every live room
      // and every player id in it (Issue 96). The app only ever does document gets.
      allow get: if true;
      allow list: if false;

      allow write: if false;
```

**Leave the `players` rule exactly as it is.** Changing it to `get`-only breaks the lobby roster.

**Do not "improve" this by adding `isAuthenticated()` to the reads.** It would be near-worthless — the app uses anonymous auth, so anyone can mint a token in one call. Denying `list` is the change that carries the weight.

### Validation

**Falsifying assertion — `functions/test/rules.spec.ts`:**

1. An unauthenticated (and separately, an authenticated) client calling `getDocs(collection(db,'rooms'))` must be **denied**. Use `assertFails`. **Observe this fail against the current rules first** — it passes today, which is the bug.
2. **Over-reach guard 1:** `getDoc(doc(db,'rooms',<code>))` must still **succeed**. Without this, `allow get: if false` would pass the main assertion and break the entire app.
3. **Over-reach guard 2:** `getDocs(collection(db,'rooms',<code>,'players'))` must still **succeed** — the roster listing the client depends on.

The existing suite has never exercised a `list`; that is why this shipped.

### Blast radius

`firestore.rules` only. **`firebase.json`'s `predeploy` hook does NOT gate `--only firestore:rules`** — rules deploy without running the suite, so run `npm --prefix functions test` yourself before deploying.

Commit: `fix(rules): deny collection enumeration of rooms`.

---

## 3. SEC2 — `joinRoom` seat takeover *(HIGH — fix this first after SEC1)*

**What this means for the user:** anyone who knows a room code can take over another player's seat — including the host's — read their private role and answer authorship, act as them, and lock them out. This is account takeover for the duration of a game.

### The gap

```ts
// functions/src/index.ts:171-184
if (playerSnap.exists) {
  // Rejoining player, update authUid and visual details
  const existing = playerSnap.data() as PlayerState;
  transaction.update(playerRef, {
    authUid: callerUid,          // ← overwritten with no ownership proof
    name: playerName, colorValue, avatarIndex,
    lastSeen: nowMs, expiresAt: ttlFrom(nowMs)
  });
  return { role: existing.role };   // ← also discloses the seat's secret role
}
```

The only gate is `if (!request.auth)` at `:143`, satisfiable by anyone (anonymous auth; **no App Check anywhere in the repo** — verified). There is no comparison against `existing.authUid`, no staleness requirement, no token.

**The intended secret is published.** The player document ID *is* the client-supplied `playerId` (`index.ts:160`), and `firestore.rules:18` makes that subcollection world-readable. Precedent "UUIDs are unguessable" does not rescue this: **the UUID is not guessed, it is listed.**

**Why this defeats everything else.** Every other callable authorizes by comparing the *stored* `authUid` to `request.auth.uid` — seats at `:459`, `:557`, `:595`, `:668`, `:760`, `:1402`; host checks at `:253`, `:720`, `:828`, `:1234`, `:1304`. Rewriting that one field passes all of them at once, including `handleDisconnect`'s lobby branch (`:838-845`) which deletes every player document and the room.

### Implementation

**The rule: a re-bind is permitted only when the caller already owns the seat, presents the seat's token, or the seat is provably abandoned.**

**1. Mint a seat token when a seat is created.** In `createRoom` (player write at `~:110-130`) and in `joinRoom`'s **new-player** branch (`~:196-215`), generate `const seatToken = randomUUID();` (Node's `crypto`, already imported for option ids at `:322`).

**Store only its hash, and store it where clients cannot read it** — the `sealed` subcollection is default-deny and is the right home:

```ts
// alongside the player doc write, in the same transaction/batch
transaction.set(
  roomRef.collection("sealed").doc(`seat_${playerId}`),
  { seatTokenHash: createHash("sha256").update(seatToken).digest("hex") }
);
```

**Never write the token or its hash into the player document** — that document is world-readable, which is the entire cause of this bug. Return the raw token to the caller once, in the callable's response.

**2. Gate the re-bind.** Replace the `playerSnap.exists` branch:

```ts
if (playerSnap.exists) {
  const existing = playerSnap.data() as PlayerState;
  const isOwner = existing.authUid === callerUid;

  const seatSnap = await transaction.get(roomRef.collection("sealed").doc(`seat_${playerId}`));
  const storedHash = seatSnap.exists ? (seatSnap.data() as any).seatTokenHash : null;
  const presentedHash = typeof data.seatToken === "string"
    ? createHash("sha256").update(data.seatToken).digest("hex")
    : null;
  const hasToken = !!storedHash && !!presentedHash && storedHash === presentedHash;

  // A seat nobody has heartbeated for 30s is abandoned and may be reclaimed.
  // This preserves recovery after a reinstall (which loses the token) without
  // letting anyone take a live seat. Mirrors handleDisconnect's isDead rule.
  const isStale = Date.now() - (existing.lastSeen ?? 0) > 30000;

  if (!isOwner && !hasToken && !isStale) {
    throw new HttpsError("permission-denied", "This seat is held by another player.");
  }
  ...existing update...
}
```

**Three properties this must have, each of which has a way to get subtly wrong:**

- **All reads before any write.** Firestore transactions require it, and this adds a `transaction.get`. Placing it after `transaction.update` throws at runtime — this project has already shipped that bug once (`1122f68`).
- **`existing.lastSeen ?? 0`, not `existing.lastSeen > x`.** A legacy document with no `lastSeen` must count as **stale**, not as fresh-forever. Note the loose-`!= null` invariant in §9 is about *server payloads*; here you genuinely want the nullish default.
- **Do not return `existing.role` to a caller who failed the check.** The throw must precede the return at `:183`.

**3. Client.** In `game_service.dart`, persist the returned token per room in `SharedPreferences` beside the existing `stable_device_player_id` (`:159-167`) — key it `seat_token_$roomCode` — and send it on every `joinRoom` call. Clear it in the teardown path when leaving a room.

**4. Rules.** No change. `sealed` has no `match` block and is therefore default-deny; verified by probe and by `functions/test/rules.spec.ts`.

### Validation

**Falsifying assertion — `functions/test/game_e2e.spec.ts`.** Player A creates a room and holds seat `p_host`, heartbeating. Player B (a different anonymous user, no token) calls `joinRoom({roomCode, playerId:'p_host', playerName:'x'})`. Assert it throws **`PERMISSION_DENIED`**, matched on the code. **Observe this fail first** — today it succeeds and returns A's `role`.

**Four over-reach guards, all required — each corresponds to a real way to break the app:**

1. **The owner can still rejoin.** Same `authUid`, no token → succeeds. Otherwise a network blip permanently ejects every player.
2. **The token holder can still rejoin.** Different `authUid`, correct `seatToken` → succeeds. This is the reinstall/second-device path.
3. **A stale seat can still be reclaimed.** `lastSeen` older than 30s, no token, different uid → succeeds. Otherwise a crashed player's seat is dead forever.
4. **The token never leaks.** Read the player document as a client and assert it contains **no** `seatToken` and **no** `seatTokenHash`; read `sealed/seat_<playerId>` as a client and assert it is **denied**. This is the guard that stops the fix from recreating the bug in a new field.

Additionally assert the **role is not disclosed** on a rejected call — the thrown error must carry no `role`.

### Blast radius

`functions/src/index.ts` (`createRoom`, `joinRoom`), `lib/services/game_service.dart`, plus tests. **Existing `joinRoom` tests that rejoin with a fresh anonymous user will now fail** — fix them by having the test present the token or reuse the owner's token, **never by relaxing the guard**.

Commit: `fix(auth): require ownership, a seat token, or staleness to rebind a seat`.

---

## 4. SEC3 — `castVote` launders the answer key into the public room document

**What this means for the user:** any player in the game can silently decrypt the entire answer key — who wrote every forgery, and which option is the truth — before voting ends, and win every round.

### The gap

The project built a real confidentiality boundary: `sealed` is default-deny, option ids are opaque v4 UUIDs, and `getMyOptionId` returns only the caller's own. `castVote` dereferences that boundary and republishes the plaintext:

```ts
// functions/src/index.ts:611-613, 629, 642-645
const answerAuthors: Record<string,string> = sealedData.answerAuthors || {};
const resolvedAuthorId = answerAuthors[votedForId];
...
const newVotes = { ...card.votes, [voterId]: resolvedAuthorId };   // author, not option id
transaction.update(roomRef, { cards: newCards, readyPlayers: newReadyMap });
```

`/rooms/{roomCode}` is world-readable (`firestore.rules:11`). **Three guards are absent**, all verified: no phase check, no check that `targetCardId === room.currentReaderId`, and no already-voted guard (`:629` overwrites). Nothing compensates — `advancePhaseInternal` only fires when *every* active player is ready, so a lone prober loops freely.

**Reproduced end-to-end against the emulator: 6 probes recovered 6/6 authors, reconstructing the full answer key for all three cards during vote round 1.** `docs/implementation_plan_selected_fixes.md:248` specifies a one-vote-per-card rule that was never implemented.

### ⚠️ This redefines what `votes` holds — for the third time

`votes` has been redefined twice before and broke its readers **both** times (Issues 62/63, then 71 → 78). **There are 13 read sites. Enumerate every one before you edit anything:**

| Where | Site |
|---|---|
| Server | `index.ts:629` (write), `:1170` (scoring), `:1428` (`submitUnmaskGuess`), `:1614-1624` (debug bots) |
| Model | `lib/models/card_model.dart:42`, `:61` |
| Reveal | `phase4_reveal.dart:103`, `:260`, `:279`, `:280`, `:294`, `:295`, `:443`, `:591`, `:699`, `:801`, `:850` |
| Scoring | `functions/src/scoring_logic.ts`, `lib/utils/scoring_logic.dart` (via `playerVotes`) |

Every one of them compares against a **player id** (`targetPlayerId`, `authorId`, `p.id`). Storing an option id naively breaks all of them.

### Implementation

**The design: `votes` holds opaque option ids during the vote phase, and the server publishes a resolved author view only at the reveal transition — where authorship is public by design anyway.**

1. **`castVote:629`** — store the opaque id the client sent:

```ts
const newVotes = { ...card.votes, [voterId]: votedForId };
```

Keep the `answerAuthors` lookup at `:612` — it is still needed to **validate** the option exists and to enforce the self-vote guard at `:618-620`. Only the stored value changes.

2. **Add the three missing guards** to `castVote`, before the write:

```ts
if (room.currentPhase !== "vote") {
  throw new HttpsError("failed-precondition", "Votes are only allowed during the vote phase.");
}
if (targetCardId !== room.currentReaderId) {
  throw new HttpsError("failed-precondition", "You can only vote on the card being read.");
}
if (card.votes?.[voterId]) {
  throw new HttpsError("failed-precondition", "You have already voted on this card.");
}
```

3. **Resolve at the reveal transition.** In `advancePhaseInternal`'s `"vote"` branch (`~:1153`), for the card being revealed, map each vote through that card's `answerAuthors` into a resolved `votes` map before it is written into the public card. **Every downstream reader then sees exactly what it sees today**, so sites 5–13 need no change — but re-read each one and confirm, rather than assuming.

4. **Scoring (`:1167-1198`)** runs inside that same branch and already has `sealedDataMap` in scope. Resolve before `ScoringLogic.calculateScores` so the scoring contract (`votes[voterId] == card.targetPlayerId` ⇒ truth vote, §9) is preserved unchanged.

5. **`submitUnmaskGuess:1428`** reads `currentCard.votes?.[voterId]` — by the time it runs, the reveal transition has resolved the map, so it keeps working. **Verify this ordering holds; do not assume it.**

6. **`debugSimulateBotResponses:1621`** writes `votes[p.id] = currentTargetId` (a player id). Under the new contract it must write the **truth option's id** for that card. If that is awkward, make the debug path resolve through `answerAuthors` the same way.

### Validation

**Falsifying assertion — the oracle must close.** In `game_e2e.spec.ts`: during the `vote` phase, a player votes for a **forgery** option; read the room document and assert `cards[].votes[voterId]` is the **opaque option id** and **not** any player id — specifically, assert it is **not** equal to the forger's `playerId`. **Observe it fail first**: today it equals the forger's id.

**Three guard assertions, each observed failing first:**
- Voting when `currentPhase !== 'vote'` throws `FAILED_PRECONDITION`.
- Voting with `targetCardId !== currentReaderId` throws `FAILED_PRECONDITION`.
- Voting twice on the same card throws `FAILED_PRECONDITION` — and the **first** vote is unchanged in the document.

**Over-reach guards — these protect the game, and the third has broken twice before:**
1. A legitimate vote still succeeds and still advances the phase when all players are ready.
2. **Scoring is unchanged.** Assert the truth-voter gains `ceil((P-1)/(S+1))` at **two** inputs — `P=4,S=1 → 2` and `P=5,S=3 → 1`. One value cannot pass both. Existing tests at `game_e2e.spec.ts:1684` and `:1793` already do this; they must stay green.
3. **The reveal still renders.** `flutter test` must stay at or above **156**, and `test/phase3_vote_test.dart` / `phase4_reveal` tests must pass unchanged — they are the readers.

### Blast radius

`functions/src/index.ts`, and **any of the 13 reader sites that turn out to need it**. `docs/design_game_state_and_models.md` §2 documents the `votes` contract — **update it in this commit**, or it will document the wrong thing for the third time.

Commit: `fix(vote): store opaque option ids in votes and gate castVote`.

---

## 5. SEC4 — The reveal merge publishes every card, not the one being revealed

**What this means for the user:** from the first reveal onward, the answers and authorship of every *remaining* card in the round are public, so the rest of the round is decided before it is played.

### The gap

```ts
// functions/src/index.ts:1153-1164
} else if (room.currentPhase === "vote") {
  const mergedCards: CardModel[] = [];
  for (const card of currentCards) {            // ← ALL cards
    const sealedData = sealedDataMap[card.targetPlayerId] || {};
    mergedCards.push({
      ...card,
      truthAnswer: sealedData.truthAnswer || kMissingAnswerPlaceholder,
      sabotageAnswers: sealedData.sabotageAnswers || {}
    });
  }
```

Confirmed by probe: after the first reveal, two unread cards were fully exposed in the public room document. `advanceToNextResolution` never re-strips them.

### Implementation

Merge sealed content **only** into the card currently being revealed; leave the others blank exactly as `startGame` initialises them (`:401-402`) and as the vote transition re-blanks them (`:1127-1130`).

```ts
  for (const card of currentCards) {
    if (card.targetPlayerId !== room.currentReaderId) {
      mergedCards.push({ ...card, truthAnswer: "", sabotageAnswers: {} });
      continue;
    }
    const sealedData = sealedDataMap[card.targetPlayerId] || {};
    mergedCards.push({ ...card, truthAnswer: sealedData.truthAnswer || kMissingAnswerPlaceholder, sabotageAnswers: sealedData.sabotageAnswers || {} });
  }
```

**`advanceToNextResolution` must then merge the next card's sealed data as it advances `currentReaderId`** (`~:1290-1330`) — otherwise card 2 reveals blank. **This is the half most likely to be missed**, and it is what turns a security fix into a broken game.

### Validation

**Falsifying assertion:** after the vote→reveal transition, read the room document and assert that **every card except `currentReaderId`'s** has `truthAnswer === ""` and `sabotageAnswers` empty. **Observe it fail first.**

**Over-reach guards:**
1. The **current** card's `truthAnswer` and `sabotageAnswers` are fully populated — a fix that blanks everything would otherwise pass.
2. After `advanceToNextResolution`, the **new** current card is populated and the previous one may be blanked or left as-is, but the *next* unread card is still blank. Walk all three cards of a round.

### Blast radius

`functions/src/index.ts` (`advancePhaseInternal` vote branch, `advanceToNextResolution`), plus tests. `docs/design_scoring_and_ui.md` §22 documents the reveal contract — extend it with the scoping rule.

Commit: `fix(reveal): merge sealed answers only for the card being revealed`.

---

## 6. SEC5 — The unmask answer sits in client state while guesses are open

**What this means for the user:** during the 20-second revenge window the correct answer is already in the player's device, so a modified client wins every unmask.

### The gap

`lib/screens/phase4_reveal.dart:295` and `:699` read `currentCard.votes[me.id]` as `actualForgerId` **while `unmaskDeadline` is still open**, and `card.sabotageAnswers` (forgerId → text) is public during that window. This contradicts `docs/design_scoring_and_ui.md:29` — *"forgery authorship must never be visible while guesses are still accepted."* The UI merely hides it.

### Implementation

**SEC3 and SEC4 change what is available here — do this item after both.** With SEC3, `votes` holds option ids until the reveal transition resolves them; with SEC4, only the current card carries sealed content.

The durable fix is server-side: **do not publish the resolved `votes` map (or `sabotageAnswers`) for the current card until `unmaskDeadline` has passed.** Publish them in `advanceToNextResolution`, or in a small transition the host already triggers, rather than at the vote→reveal edge.

**If that restructuring is too large for one commit, stop and file it** with options rather than half-doing it — a client-side-only mitigation is not a fix (§8), and this project has an explicit invariant that a client-only bound is not a bound.

### Validation

**Falsifying assertion:** with `unmaskDeadline` in the future, read the room document as a client and assert the current card exposes **no** mapping from the guesser to the forger — neither via `votes` nor via `sabotageAnswers`. **Observe it fail first.**

**Over-reach guard:** after the deadline passes and the host advances, that mapping **is** present — the reveal must still work. Assert both states in the same test.

Commit: `fix(reveal): withhold forgery authorship until the unmask window closes`.

---

## 7. SEC6 — Debug callables have no membership or host check

**What this means for the user:** a stranger can inject bots into, and force phase transitions in, any room created by a debug build — which includes every developer and QA session run against production.

### The gap

```ts
// functions/src/index.ts:1485-1502 (debugAddBots), :1538-1557 (debugSimulateBotResponses)
if (!request.auth) { ... }
...
if (!room.debugEnabled) {
  throw new HttpsError("permission-denied", "Debug commands are only allowed when debugEnabled is true.");
}
```

That is the entire authorization: authenticated, plus a flag on the room. **No `authUid` match and no `isHost` check** — unlike every sibling privileged callable (`:253`, `:720`, `:1234`, `:1304`). `debugEnabled` is client-supplied at `:67`, and `lib/screens/lobby_screen.dart:188` passes `kDebugMode`, so release builds set it false and there is no server path to flip it later. The reachable victim set is therefore developer/QA rooms — real, but narrow. `debugAddBots` writes 9 player documents that `firestore.rules` forbids clients to create, so it does cross a real trust boundary.

### Implementation

**Both fixes, not either:**

1. **Gate the exports** so they are not deployed to production:

```ts
const debugEnabledEnv = process.env.FUNCTIONS_EMULATOR === "true";
export const debugAddBots = debugEnabledEnv ? onCall(...) : undefined as any;
```

If conditional export proves awkward with the v2 API, keep the export and make the handler throw `permission-denied` immediately unless `process.env.FUNCTIONS_EMULATOR === "true"`. **Either way, `scripts/check_deploy_fresh.sh` expects 15 functions — if the deployed count changes, update `EXPECTED_FUNCTION_COUNT` and `EXPECTED_FUNCTIONS` in the same commit**, or the gate fails on a correct deploy and the next agent learns to ignore it.

2. **Add the standard host check** to both, matching `advancePhase:720-722`: resolve the caller's player document by `authUid` and require `isHost`.

### Validation

**Falsifying assertion:** in a room with `debugEnabled: true`, a caller who is **not** a member of that room calls `debugAddBots` and gets **`PERMISSION_DENIED`**. Then a member who is **not the host** calls it and also gets `PERMISSION_DENIED`. **Observe both fail first.**

**Over-reach guard:** the **host** of a `debugEnabled` room can still call it and 9 bots appear — the emulator suite depends on these callables (`debugSimulateBotResponses` drives several existing tests), so breaking them breaks the suite. If you gate on `FUNCTIONS_EMULATOR`, confirm the emulator sets it — **if the existing tests go red, that is the signal the gate works, not a reason to weaken it**; adjust the tests' expectations, not the guard.

Commit: `fix(debug): require room host for debug callables and keep them out of production`.

---

## 8. SEC7 — Deploy and verify

**Two deploys, and they are separate commands.** `firebase.json`'s `predeploy` hook gates `--only functions` and **not** `--only firestore:rules` — rules ship without running the suite.

**SEC1's rules deploy can and should go first, immediately after SEC1 lands.** It is one line, independently safe, and closes the mass-automation path:

```bash
npx firebase-tools deploy --only firestore:rules --project gaslight-46368
```

**The functions deploy covers SEC2, SEC3, SEC4 and SEC6 — one deploy, after all four are committed and green.** Never deploy mid-build: a production where `castVote` stores option ids but `advancePhaseInternal` still expects author ids is worse than either version alone.

```bash
npx firebase-tools deploy --only functions --project gaslight-46368
```

### Validation

`./scripts/check_deploy_fresh.sh` → **exit 0**, with every function's `updateTime` later than the last `functions/src` commit and the rules release later than the last `firestore.rules` commit. **A partial deploy is a failure, not a partial success.** If the gate exits **2** you have verified nothing — resolve the credentials before recording any result.

Paste the before and after tables into the commit body.

---

## 9. Invariants & intentional decisions — do NOT change

- **`sealed` and `embeddings` have no `match` block and are therefore default-deny.** Verified by probe and by `rules.spec.ts`. **Never add an explicit `allow read: if false`** — and never add a `match` block that accidentally grants access. SEC2's seat-token hash depends on this.
- **Never send *other players'* authorship to the client** — but this does not forbid telling a caller their own. `getMyOptionId` returns at most one id, only the caller's, and it is verified correct.
- **A truth vote is `votes[voterId] == card.targetPlayerId`** once resolved. There is no `'TRUTH'` sentinel; **never reintroduce one** (Issue 78 Option B, declined).
- **The option id is the authority; text is the fallback, consulted only when the id is null.** Never union the two.
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose. Do not "tidy" either.
- **`castVote` rejects only genuine self-votes** — never loosen it, and never let a client bound exceed the server's.
- **The readiness gate exempts the host deliberately** — requiring `hostPlayer.lobbyReady` deadlocks every lobby. Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and wins over the phase branches.
- **`handleDisconnect` has exactly three legitimate callers** — self, host-on-anyone, and any client reporting a stale `lastSeen`. **A non-host acting on a third player stays rejected with `permission-denied`.**
- **Never interpolate an exception object into user-facing text.** Map on `e.code` with a generic fallback.
- **`scoring_logic.{ts,dart}` must stay semantically identical; `text_similarity` byte-identical.**
- **Player-document write rules are sound** — the protected-key diff at `firestore.rules:26-29` is correctly scoped by `resource.data.authUid == request.auth.uid`. Do not widen it.
- **`predeploy` stays.** **`ROOM_TTL_MS` is 8 hours.** **Phase order is truth → forgery → vote → reveal.**

---

## 10. Assessed and rejected — do NOT re-propose

- **Room codes from `Math.random()` (`index.ts:40-47`) — rejected as a false positive**, confidence 9. Factually accurate but the wrong diagnosis: because `/rooms` is world-listable, an attacker **lists** live codes rather than guessing them, so code entropy protects nothing — and once SEC1 lands, the remaining narrative is "issue ~450k `joinRoom` calls until one lands," which is brute-force enumeration. The PRNG-state-recovery variant is speculative in Cloud Functions (multiple instances, up to 80 concurrent requests per isolate, ≥5 interleaved `Math.random()` consumers), and the truth option id is `crypto.randomUUID()` regardless. **Switching to `crypto.randomInt` is a fine style change with no security delta — do not spend a cycle on it and do not file it again.**
- **`authUid` exposure in world-readable player documents** — assessed, not a finding. It is an opaque anonymous identifier, not PII and not a credential; the ownership check compares it against the caller's server-verified token, so knowing the string grants nothing.
- **Prototype pollution via `selectedDeckId`** — `DECKS['__proto__']` reaches a truthy prototype object, but the immediate spread throws a `TypeError`. An error, not a write or a leak.
- Not reported per the review's exclusions: `.env` and the Firebase web API keys in `lib/firebase_options.dart` (public identifiers, not secrets).

---

## 11. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps, lessons | `docs/ongoing_general_errors.md` — **Issues 96–101 carry the full findings** |
| Phase order, 3-player floor, readiness gate, **`votes` contract** | `design_game_state_and_models.md` |
| Scoring, reveal beats, unmask bounds, own-answer lockout | `design_scoring_and_ui.md` |
| **Callable table, rules, `handleDisconnect`'s callers, deploy & freshness gate** | `design_database_and_security.md` |
| Dialog surface, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules tests | `functions/test/rules.spec.ts` |
| Callable / integration tests | `functions/test/game_e2e.spec.ts` |

---

## 12. Validation standard

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.**

**Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.

**A Dart widget test cannot prove a security fix.** `test/fake_functions.dart` does not enforce `firestore.rules` and does not model the real callable's authorization. Rules go in `rules.spec.ts`; authorization goes in `game_e2e.spec.ts`.

**Assert the negative as well as the positive.** SEC3's key assertion is that the stored value is **not** a player id; SEC2's is that the token appears in **no** client-readable document.

**Match on the error `code`, never the message.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**A check that cannot run must say so, not pass** — the deploy gate's exit 2.

**Assert a derived value at two different inputs.** One value cannot pass both.

**A clamp is not a rejection. A client-only bound is not a bound — and a client bound *tighter* than the server's is also a defect.**

**Structurally present is not actually wired.** Trace a fix from callable → service → screen → widget before believing it.

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

---

## 13. Feedback loop — what past specs got wrong

- **The security model was documented and then not enforced.** `design_database_and_security.md:35` states "never send other players' authorship to the client" — SEC3 is that exact invariant being violated by the one function privileged to read the sealed document. **A documented invariant with no test is a wish.** Every invariant in §9 should have an assertion behind it.
- **A world-readable identifier was treated as a secret.** SEC2's `playerId` is the recovery credential *and* the document ID of a world-readable collection. **When a design doc calls something a secret, grep for where it is published.**
- **When you redefine what a field holds, enumerate its readers.** `votes` has broken twice on exactly this; SEC3 makes it three times if the 13 sites are not walked.
- **A guard's test must be run with the guard removed** — the skip is invisible in a green run.
- **A layered fix must be ordered, not unioned** — the authority must be able to say *no*, not merely *also yes*.
- **"Verified in source" is not "shipped."** A written deploy instruction failed twice before it was replaced with a tool.
- **Fixing a class of defect promotes the next one.** Assume the next failure is one level up, and look there first.
- **One item = one commit.** **Doc structure rots silently** — append inside the single existing Resolved heading; never add a second.

---

## THE LOOP — follow this for every item

```
(1) STUDY the item here + its full finding text in ongoing_general_errors.md
    (Issues 96-101) + the exact files at the cited anchors.
    RE-GREP every anchor: line numbers drift, and they will drift as you edit.
(2) ENUMERATE the readers. For SEC3 this is mandatory and non-negotiable:
    13 sites, listed in section 4. For any item, grep for every consumer of a
    field or behaviour you are about to change.
(3) WRITE the falsifying validation FIRST, in the right suite:
    rules -> functions/test/rules.spec.ts
    callable authorization -> functions/test/game_e2e.spec.ts
    Run it. OBSERVE IT FAIL against the current code. Record the exact output.
(4) IMPLEMENT exactly as specified. Record any substitution you make.
(5) VALIDATE per section 12: the falsifying assertion now passes, AND every
    over-reach guard for that item passes, AND the guard can still fail --
    remove the guard, watch the test go red, restore it.
(6) RECORD the observed failure text in a comment on the test AND in the
    commit body. A step whose only product is a commit-body sentence gets
    skipped; this project has lost that step twice.
(7) RE-RUN THE FULL BATTERY before committing, including
    ./scripts/check_deploy_fresh.sh:
      flutter analyze lib test   -> 0 errors
      flutter test               -> >= 156
      npm --prefix functions run build -> clean
      npm --prefix functions test      -> >= 54
      ./scripts/check_deploy_fresh.sh  -> exit 0
(8) BLOCKED, or a design decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
    Do not improvise a security fix.
(9) COMMIT: Conventional Commit, one item per commit, WHY in the body,
    pre-fix failure output included. Move the issue into the SINGLE existing
    Resolved heading and update the design doc named in that item.
```

---

## Definition of Done

- [x] **SEC1** — `allow list: if false` on `/rooms`; rules test asserts collection enumeration is **denied**, observed failing first; room `get` and players `list` both still succeed.
- [x] **SEC1 deploy** — rules released; `check_deploy_fresh.sh` shows the rules release later than the last `firestore.rules` commit.
- [x] **SEC2** — re-bind requires ownership, token, or staleness; `PERMISSION_DENIED` for a stranger, observed failing first; **all four** over-reach guards pass (owner rejoins, token holder rejoins, stale seat reclaimable, token absent from every client-readable document); no `role` disclosed on rejection; all `transaction.get` calls precede writes.
- [x] **SEC3** — `votes` stores opaque option ids; all **three** guards throw `FAILED_PRECONDITION`, each observed failing first; the stored value asserted **not** to equal the forger's player id; scoring asserted at **two** inputs; all 13 reader sites walked; `design_game_state_and_models.md` §2 updated.
- [x] **SEC4** — only the current card carries sealed content; **`advanceToNextResolution` merges the next card** so reveal 2 and 3 are not blank; all three cards of a round walked.
- [x] **SEC5** — authorship withheld until `unmaskDeadline` passes, asserted in both states; or **filed with options** if it does not fit one commit.
- [x] **SEC6** — non-member and non-host both rejected, observed failing first; host path still works; `EXPECTED_FUNCTION_COUNT` updated if the deployed count changed.
- [x] **SEC7** — one functions deploy after SEC2/3/4/6; gate **exit 0**; before/after tables recorded.
- [x] Battery at or above §0 throughout: **0 errors** · **≥156** · clean build · **≥54** · gate exit **0**.
- [x] **Nothing in §9 changed. Nothing in §10 re-proposed.**
