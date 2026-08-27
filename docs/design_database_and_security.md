# Database Structure & Security Rules

This document outlines the Firestore structure, the server-authoritative write architecture (Cloud Functions), security policies, and the heartbeat/disconnect model.

> **Architecture decision (July 2026, resolves the old §4 clarification):** the user chose the Firebase industry standard for a scalable App Store game — Gaslight is **server-authoritative** (Issue 1, Option D). Clients *read* the game live via Firestore streams for instant UI, but **only Cloud Functions write shared game state**: no player's device can rewrite scores, answers, or phases, and the Gemini API key lives on the server. Status: the migration is fully implemented, verified via a comprehensive emulator-based integration suite (proving Issue 1), and production-ready.

## 1. Document Hierarchies

* `/rooms/{roomCode}`: the root `GameState` document (phase, cards, votes, readiness, rotation plan).
* `/rooms/{roomCode}/players/{playerId}`: individual `PlayerState` documents. `playerId` is a client-chosen stable ID; the document stores `authUid` (the Firebase anonymous UID currently bound to that seat) for server-side ownership checks.
* `/rooms/{roomCode}/embeddings/{answerHash}`: server-managed cache of Gemini embedding vectors (md5 of the normalized answer text → vector) for the semantic-similarity filter. No client rule → default deny; server-only.
* `/rooms/{roomCode}/sealed/{cardId}`: server-managed answer keys (`truthAnswer` and `sabotageAnswers` forgery map) and per-player prompt history (`seenPrompts` list) stored during `truth`, `forgery`, and `vote` phases to conceal answer origin and prompt history until reveal. No client rule → default deny; server-only.

---

## 2. Write Architecture: Cloud Functions Callables

All game mutations are `onCall` Cloud Functions (`functions/src/index.ts`) that validate `request.auth.uid` against the player's stored `authUid` (or the host's, for host-only actions) and write with the Admin SDK:

| Callable | Replaces (old client method) | Guard / behavior |
|---|---|---|
| `createRoom` | `GameService.createRoom` | authenticated |
| `joinRoom` | `GameService.joinRoom` | authenticated; re-binds `authUid` for seat recovery **only on ownership, a valid `seatToken`, or a seat stale >30 s** — `playerId` alone is not a credential (§5) |
| `startGame` | `GameService.startGame` | host only; validates player count, rounds, deck size with descriptive errors |
| `submitAnswer` | `submitCardAnswer` | seat owner; server-side semantic-similarity check; marks author ready; auto-advances when all active players are ready |
| `getMyOptionId` | `GameService.fetchMyOptionId` | seat owner; reads default-deny `sealed/{cardId}.answerAuthors` server-side, returning **only the caller's own optionId** (`{ optionId }`) or `{ optionId: null }` if none authored; throws `permission-denied` on ownership mismatch |
| `castVote` | `castVote` | seat owner; enforces the self-vote guard; marks voter ready; auto-advances |
| `setReady` | `setPlayerReady` | seat owner; auto-advances when all ready |
| `advancePhase` | `forceAdvance`/`evaluateReadyState` | host only; applies timeout placeholders, per-card scoring, honor stats |
| `advanceToNextResolution` | `advanceToNextResolution` | host only; steps the vote→reveal card sequence / game over |
| `rerollPrompt` | `rerollMyPrompt` | seat owner; unlimited re-rolls allowed during the `truth` phase |
| `updateLobbySettings` | `updateLobbySettings` | host only |
| `handleDisconnect` | `handlePlayerDisconnect` | host, self, or anyone for a heartbeat-dead player; idempotent; card pruning, assignment bridging, reader re-indexing, **host transfer** |

> **Authorship invariant & `getMyOptionId`:** The invariant is *never send other players' authorship to the client*. `getMyOptionId` responds over a private callable channel to a single authenticated seat owner, returning only the opaque option ID corresponding to the caller's *own* submission on that card. It reveals nothing the player does not already know (they wrote the text), keeps all other options' authors concealed in the default-deny sealed document, and rejects queries for third-party player IDs with `permission-denied`.

### Client call discipline for `getMyOptionId` (Issues 91–92, August 2026)

Three properties of `GameService.fetchMyOptionId` look like oversights and are decisions. **Do not "tidy" any of them without a decision:**

* **It is called from `build()` on purpose.** Relocating it to a card-change trigger was considered and declined; the in-flight guard makes repeated invocation harmless, and the call site stays side-effect-simple.
* **A failed fetch is NOT cached, and will be retried.** The `catch` deliberately does not write `null` into the completion cache. **This is what makes the `finally` load-bearing and testable** — if failures were cached, the completion cache would short-circuit before the in-flight guard was ever consulted and no test could reach it. It also buys recovery from a transient failure, which the cached version could not.
* **`_optionIdFetchesInFlight` guards duplicate invocations**, added before the call and cleared in a **`finally`** — without the `finally`, a thrown call wedges that card permanently, because nothing writes the completion cache on that path either. Mirrors `_disconnectsInFlight`, the same idiom used for `handleDisconnect`.

The client falls back to per-card text matching whenever the id is unresolved or the call failed (`design_scoring_and_ui.md` §3.2).

Game logic mirrored in TypeScript: `functions/src/rotation_engine.ts`, `scoring_logic.ts` (per-card `S`, Sharp Eye bonus), `prompt_decks.ts`. **Regression rule: any change to a game rule must land in both the Dart client (display math) and the TS functions (authoritative math) — the functions are the source of truth.**

The Flutter client (`GameService`) is a thin wrapper: each mutation method calls its callable; reads remain live `snapshots()` listeners on the room and players. Setting `USE_EMULATOR=true` (dart-define or `.env`) points the client at local Auth/Firestore/Functions emulators.

---

## 3. Security Rules (`firestore.rules`)

* **Room documents**: **`allow get: if true`** (live game state for all) and **`allow list: if false`** — plus **`allow write: if false`**; only the Admin SDK (Cloud Functions) writes rooms.
  > ⚠️ **`get` and `list` are split deliberately (Issue 96, August 2026). Do not collapse them back to `allow read`.** In Firestore, `read` grants both verbs, and because the old condition was the literal `true` and never dereferenced `resource`, an unconstrained query against `/rooms` was permitted — anyone could download **every live room, unauthenticated**, and then harvest every player document. The client never needed it: `game_service.dart:232,359` only ever address a room by exact document ID. Adding `isAuthenticated()` here would be near-worthless under anonymous auth; denying `list` is the change that carries the weight. Guarded by two tests in `functions/test/rules.spec.ts` (authenticated and unauthenticated), each with over-reach guards proving room `get` and the players `list` still succeed.
* **Player documents**: `allow read: if true`. `create`/`delete`: **denied** (handled by `joinRoom`/`handleDisconnect`). `update`: permitted only when the caller's `request.auth.uid` matches the doc's stored `authUid` **and** the field diff touches none of the protected keys (`role`, `totalScore`, `timesFooled`, `playersDeceived`, `isHost`, `joinedAt`, `hasRerolled`, `authUid`, `id`). That leaves exactly the cosmetic/liveness surface players may write themselves: `name`, `colorValue`, `avatarIndex`, `lastSeen` (heartbeat), `lobbyReady`, `lastReaction`/`lastReactionAt` (emoji reactions).
* **Why field-diff rules**: clients doing own-doc writes must send **only the fields they intend to change** — a full-object write carrying a stale protected value counts as a change and is denied. The client write paths for reactions and lobby-ready updates (Issue 18) have been refactored to perform targeted, field-scoped updates.
* File: `firestore.rules` (workspace root); declared in `firebase.json`.

---

## 4. Heartbeat, Disconnects & Host Transfer

* Every client updates **only** `lastSeen` on its own player doc every 10 seconds (permitted by the rules).
* On app resume (`AppLifecycleState.resumed`), `GameService` (via `WidgetsBindingObserver`) writes `lastSeen` immediately and restarts its 10 s periodic timer, preventing suspended timers and closing the gap after phone unlock.
* Any client that observes a player with `lastSeen` older than its own `presenceStaleMs` calls the `handleDisconnect` callable. Duplicate or racing calls are safe (idempotent: if the player's card is already gone, it just deletes the doc). Client-side deletes no longer exist.
* **⚠️ The 10-minute window is not in force — see Issue 123.** The server exports `PRESENCE_STALE_MS = 600_000`, but two things defeat it: the client still uses `presenceStaleMs = 120000` (`lib/services/game_service.dart:20`), and `isDead` appears **only inside the authorization condition** in `handleDisconnect` (`functions/src/index.ts:1155`) — it decides whether a *peer* may evict someone, and has never limited the **host**, who is authorized unconditionally. The effective window is therefore still **120 seconds**. Verified in the emulator: a player stale by 150 s was deleted by a host-initiated call. **Do not describe the window as 10 minutes until Issue 123 is selected and built.**
* **`handleDisconnect` is also the host's kick and the player's quit** (Issues 85 and 87, August 2026). Its authorisation check rejects only a **non-host acting on another player's document**, so three callers are legitimate and no separate callable exists or should be added:
  * a player disconnecting **themselves** — the lobby leave control, and the in-game `LEAVE GAME` control on all three phase screens;
  * the **host** disconnecting **any** player — the lobby kick control;
  * **any** client reporting a player whose `lastSeen` is stale (`isDead`).
  > **The over-reach guard is the load-bearing half of this rule**: a non-host calling it for a third player must still be rejected with `permission-denied`. That single assertion is what keeps a kick control from becoming a kick-anyone control, and it is covered in the emulator suite. Never relax it.
* `handleDisconnect` performs, in one transaction:
  * **Lobby phase (`currentPhase == "lobby"`)**: host disconnect closes the room entirely by deleting all player subcollection documents and the room document, returning `{ success: true, roomClosed: true }`. Subscribed clients handle room deletion via their room snapshot listener, triggering local teardown, setting `roomClosed = true`, and routing to the entry screen with the exact notice: `"The host has left. This room has closed."`
  * **In-game phases (`currentPhase != "lobby"`)**: host disconnect retains the room, performing card removal, readiness/resolution-order pruning, forgery-phase assignment bridging + rotation regeneration (collapsing to TRUTH when too few players remain), vote/reveal reader re-indexing, and **host transfer to the earliest-joined active non-spectator** (smallest `joinedAt`, ID tiebreak). Rationale: join order is deterministic, and spectators must never inherit the host role (they aren't playing and would stall the game).

---

## 5. Identity Model

* `playerId` is a **device-stable UUID** persisted in `SharedPreferences`, decoupled from Firebase Auth; the anonymous `authUid` is just the credential currently bound to that seat, and `joinRoom` re-binds it so a reinstall or cleared storage keeps the player's seat and score.
* The client implements this via persistent UUID generation and rejoins via the `joinRoom` server re-bind endpoint rather than clearing the local session (Issue 16).

### Seat tokens — what actually authorises a re-bind (Issue 97, August 2026)

> ⚠️ **`playerId` is NOT a credential and must never be treated as one.** It is the player document's **ID**, and that subcollection is world-readable (§3) — so every seat's `playerId` is published to anyone who can read the room. Until August 2026 `joinRoom` re-bound `authUid` on nothing more than a matching `playerId`, which meant **any authenticated user who could read a room could take over any seat in it, including the host's**, inherit every host-only callable, and lock the victim out. The "UUIDs are unguessable" assumption gave false comfort: the UUID was never guessed, it was listed.

A re-bind is now permitted only when **one of three** conditions holds:

1. **Ownership** — `existing.authUid === request.auth.uid`. The ordinary reconnect.
2. **Seat token** — the caller presents the `seatToken` minted for that seat. The token is generated server-side with `randomUUID()` at `createRoom` and at the new-player branch of `joinRoom`, returned to that caller **once** in the callable response, and persisted client-side per room as `seat_token_{roomCode}`. **Only its SHA-256 hash is stored, and only in `sealed/seat_{playerId}` — the default-deny subcollection.** This is the reinstall / second-device path.
3. **Staleness** — nobody has heartbeated the seat for `PRESENCE_STALE_MS` (`Date.now() - (existing.lastSeen ?? 0) > PRESENCE_STALE_MS`), mirroring `handleDisconnect`'s `isDead` rule. This is what keeps a crashed player's seat reclaimable when the token is gone. **On this path the constant genuinely governs** — unlike the eviction path, which Issue 123 shows is still effectively 120 s.

**Three properties that must not be lost:**

* **The token, and its hash, must never be written into the player document.** That document is world-readable; putting the credential there would recreate the original bug in a new field. A test asserts the player document contains neither `seatToken` nor `seatTokenHash`.
* **The rejection must precede the `return { role }`.** A failed re-bind must disclose nothing — the old code handed the seat's secret `role` back to the caller. A test asserts `role` is absent on the thrown error.
* **`existing.lastSeen ?? 0`, not a bare comparison.** A legacy document with no `lastSeen` must count as *stale*, not as fresh-forever.

**Device-verified August 21, 2026.** Seat recovery ran on a simulator for the first time: `xcrun simctl terminate` mid-match, then relaunch. The client presented its stored `seat_token_{roomCode}`, bypassed the Guest Ledger entirely, and landed back on `/reveal` with the seat, score and ballot history intact — boot log `DEBUG HEARTBEAT: started timer for room: GLRD, player: 2d72eff1-…`. **Before this the whole three-condition rule existed only behind emulator tests**; a force-quit is the exact motion a real player makes, and it is now known to work.

**Do not simplify this to a single condition.** Staleness alone is too weak — an attacker just waits. Token alone strands any player who reinstalls. All three tested in `functions/test/game_e2e.spec.ts` ("SEC2"), with the stranger-takeover case as the falsifying assertion and four over-reach guards.

---

## 6. Firestore TTL Policy (Issue 53 — shipped August 2026)

- **8-Hour TTL Expiration**: Rooms and player documents store `expiresAt: Firestore.Timestamp` computed at creation (`now + 8 hours`). Active games refresh `expiresAt` on room updates (`startGame`, `updateLobbySettings`, `advancePhaseInternal`).
- **Security Rule Denylist**: `'expiresAt'` is added to the field write denylist in `firestore.rules`, preventing client devices from writing or altering `expiresAt` directly while preserving allowed client `lastSeen` updates.
- **Production TTL Index Commands**:
  ```bash
  gcloud firestore fields ttls update expiresAt --collection-group=rooms --enable-ttl
  gcloud firestore fields ttls update expiresAt --collection-group=players --enable-ttl
  ```
  Both policies were applied and verified `state: ACTIVE` on **August 10, 2026**. A policy acts only on documents where `expiresAt` **exists and is a Timestamp** — documents predating the field are ignored permanently, which is why the one-time backfill (`scripts/backfill_expires_at.js`, Issue 56) was needed. A fresh project never needs that backfill; it does need both `gcloud` commands re-run, since TTL policies live outside the repository.

---

## 7. Callable payload contract — `null` is not "absent" (Issue 31)

**This is the most expensive bug the project has shipped, and the shape of it will recur.** Absorbed from `ongoing_general_errors.md`, August 7.

The Dart client and the TypeScript callables disagree about what "I am not changing this field" looks like. Dart sends an omitted optional as **`null`**, which crosses the wire as JSON `null` and arrives in Node as `null` — **not `undefined`**. A server guard written as `x !== undefined ? x : existing` therefore treats a Dart null as a real value and **writes it over the stored data**.

Concretely: changing the deck erased `sabotageAnswersCount` and `isTimerDisabled`. The wiped round count then produced an empty rotation plan, and `startGame` died writing `undefined` to Firestore, surfacing to the player as an opaque `[firebase_functions/internal] INTERNAL`.

**The contract, both sides:**
1. **Clients build payloads conditionally** — omit a key entirely rather than sending `null`. See `GameService.updateLobbySettings`.
2. **Callables guard with loose `!= null`**, which in TypeScript means "neither `null` nor `undefined`". **Never use a falsy check** (`if (x)`) as a shortcut: `false` and `0` are legitimate values for `isTimerDisabled` and `sabotageAnswersCount`, and a falsy check silently discards them — re-creating the bug in a new shape. An over-reach test asserting `false` survives an update guards this.
3. **Validate before use, and fail readably.** Throw `HttpsError("failed-precondition", <human message>)` rather than letting a raw `Error` or a Firestore write failure bubble up — those flatten to `INTERNAL` and tell the player nothing.

**Why the 31-test emulator suite never caught it:** those tests are written in TypeScript, where an omitted key genuinely *is* `undefined`. The failing payload was unreachable from the harness. **When a boundary is crossed by two languages, at least one test must send the payload exactly as the real client sends it** — including explicit nulls. The same real-client blind spot also hides non-host write behaviour, since the fake Firestore used by client tests does not enforce security rules.

## 7.1 Debug Callables Isolation & Authorization (Issue 101 — August 2026)

* **Emulator Environment Isolation**: `debugAddBots` and `debugSimulateBotResponses` are gated on `process.env.FUNCTIONS_EMULATOR === "true"`, rejecting any invocation in production Cloud Functions with `permission-denied`.
* **Host Authorization Requirement**: In emulator environments, both debug callables require the authenticated caller (`request.auth.uid`) to be a member of the room and hold `isHost === true`, preventing strangers or non-host members from injecting bots or forcing phase transitions in developer/QA rooms.
* **UI gating (Issue 103.1, August 2026)**: the seven `DEBUG:` controls that invoke these callables are wrapped in `if (kDebugMode)` — `lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572` — each composing with that site's pre-existing condition rather than replacing it. **Do not delete these buttons**: they are load-bearing for local development and `debugSimulateBotResponses` drives several emulator tests. `kDebugMode` is a compile-time constant, so release builds tree-shake the widgets away entirely.
  > ⚠️ **This gating is only observable in a release or profile build.** `kDebugMode` is `false` in both, and `MarionetteBinding` is installed only `if (kDebugMode)` (`lib/main.dart:26`) — **so Marionette can never observe it**, because it cannot attach to any build where the gating is active. Verifying it requires a release build installed and driven by hand. Reading `if (kDebugMode)` in the source proves the guard was written, not that the artefact ships without the buttons.

### 7.2 Privacy manifest (Issue 104, August 2026)

`ios/Runner/PrivacyInfo.xcprivacy` declares what the app collects, which feeds the App Store privacy label. Three types, all `Linked: false`, all `Tracking: false`, all `AppFunctionality`:

| Data | Source in code | Apple type |
|---|---|---|
| Display name | `player_name_field` → `PlayerState.name` | `NSPrivacyCollectedDataTypeName` |
| Player-written truths and forgeries | `submitAnswer` → `sealed/{cardId}` | `NSPrivacyCollectedDataTypeOtherUserContent` |
| Anonymous Firebase UID | `signInAnonymously()` → `PlayerState.authUid` | `NSPrivacyCollectedDataTypeUserID` |

`NSPrivacyTracking` is `false` and `NSPrivacyTrackingDomains` is empty — there is no analytics SDK, no ad SDK, and no Gemini call left in the client. **`Linked` is `false` because the account is anonymous**: no email, no phone, no sign-in ties it to a person.

**`NSPrivacyAccessedAPITypes` is deliberately empty.** `ios/Runner/AppDelegate.swift` is Flutter boilerplate and the only other native file is the generated plugin registrant, so no code of ours calls a required-reason API. `SharedPreferences` does touch `UserDefaults`, but that call lives in `shared_preferences_foundation` and is that plugin's manifest to declare. **If a plugin is ever found without its own manifest, upgrade the plugin — do not write one on its behalf.**

> ⚠️ **The file must stay a member of the `Runner` target.** It is currently in `Copy Bundle Resources` (`project.pbxproj` carries the `PBXBuildFile`, the `PBXFileReference`, the group entry and the Resources phase entry). **A manifest present in the repo but absent from the target ships nothing, builds fine, runs fine, and fails silently at App Store upload.** Verify with `find build/…/Runner.app -name "PrivacyInfo.xcprivacy"`, never by checking the source tree.

---

## 8. Deployment, and how to prove a deploy actually happened

Committing backend code changes nothing for users. Issue 55 sat green, tested and marked "Resolved" for a full day while production ran a build from two days earlier — because **no gate in the test battery can observe a deployment**. This section is the antidote.

**Deploy:**

```bash
npx firebase-tools deploy --only functions,firestore:rules --project gaslight-46368
```

`firebase.json` carries a `predeploy` hook running both TypeScript build and backend emulator tests (`npm --prefix "$RESOURCE_DIR" run build` and `npm --prefix "$RESOURCE_DIR" test`), added under Issue 55/65. If tests fail, the deploy aborts before updating production Cloud Functions. **Never remove the hook.**

> ⚠️ **Limitation:** `predeploy` is attached to the `functions` configuration block in `firebase.json`. Running a rules-only deploy (`firebase deploy --only firestore:rules`) bypasses the `functions` predeploy hook. Rules deploys must still be verified independently via Check 3 below.

**⚠️ The manual checks below are now mechanized. Run `./scripts/check_deploy_fresh.sh` — it is a required gate in the test battery** (added under Issue 81, August 14 2026, after this section's written instruction failed **twice**: once for Issues 71/72/76, and again one cycle later for `1122f68`). Both times the instruction existed and was followed with `firebase functions:list`, which prints version, trigger, location, memory and runtime and **no timestamps at all**. When a written step fails twice, replace it with a tool.

The script's contract, which any replacement must preserve:

* **Three exit codes, and conflating any two of them defeats the gate.** `0` fresh · `1` stale, naming every lagging function with its lag in seconds · `2` **could not verify** — `gcloud` missing, unauthenticated, or the Rules API unreachable. **Exit 2 must never be reported as a pass.** A gate that reports success when it did not run is the same defect class as a fabricated test report.
* **It checks the function *count*, not just timestamps.** A function that fails to deploy does not appear with an old timestamp — it may not appear at all. Fewer than 14 is exit 1.
* **Timestamps are compared as epoch seconds, never as strings.** `git` emits local offsets (`2026-08-13T21:56:13-07:00`); Google emits Zulu with nanosecond precision (`2026-08-14T04:43:19.711837007Z`). Lexicographically the first sorts *before* the second, so a naive `>` reports a **774-second-stale deploy as fresh** — measured on this repo's real values, not hypothetical. Take git's side as `git log -1 --format=%ct` and truncate Google's fractional part to 19 characters before `datetime.fromisoformat`.
* **Rules need a separate call.** `gcloud functions list` cannot see them; the Firebase Rules API (`firebaserules.googleapis.com/v1/projects/{id}/releases`) can, and **requires an `x-goog-user-project` header** — without it it returns `PERMISSION_DENIED / SERVICE_DISABLED`, which reads like a disabled API and is really a missing quota project.

**The four manual checks remain the definition of what the script automates** — use them when the script exits 2, or when auditing it. `gcloud` is not on the default `PATH`; it lives at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`.

1. **Every function's timestamp moved.**
   ```bash
   gcloud functions list --project=gaslight-46368 --format="table(name,state,updateTime)"
   ```
   All 14 must show the deploy time. One stale row means one function did not ship.

2. **The deployed bundle really contains your change.** This is the strongest available evidence and needs no client:
   ```bash
   gcloud functions describe createRoom --project=gaslight-46368 \
     --format="value(buildConfig.source.storageSource.bucket,buildConfig.source.storageSource.object)"
   gcloud storage cp "gs://<bucket>/<object>" /tmp/deployed.zip && unzip -q /tmp/deployed.zip -d /tmp/deployed
   grep -c "ROOM_TTL_MS" /tmp/deployed/lib/index.js
   ```
   Grep the deployed `lib/index.js` for a token unique to the change you shipped.

3. **The rules ruleset moved, and contains your change.** Rules deploy on a separate track from functions and can silently lag. The Firebase Rules API needs a quota project supplied per-request:
   ```bash
   TOKEN=$(gcloud auth print-access-token)
   curl -s -H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: gaslight-46368" \
     "https://firebaserules.googleapis.com/v1/projects/gaslight-46368/releases"
   ```
   Take `rulesetName` from the response and `GET .../rulesets/<id>` to read the deployed source back. Without the `x-goog-user-project` header this returns **403 SERVICE_DISABLED**, which reads like a permissions problem and is not one.

4. **Behaviour on a real client.** Three simulators against production for anything user-visible — the emulator suite cannot see production at all.

---

## 9. Historical Note: the Resolved Write-Architecture Clarification

The original design had `firestore.rules` restricting room writes to the host while every client wrote the room directly — a contradiction that made non-host multiplayer non-functional (Issue 1). The clarification offered host-authoritative (A), server relay (B), and loosened rules (C); the user directed us to the industry standard, recorded as **Option D: server-authoritative Cloud Functions**, which is the architecture described above.

---
