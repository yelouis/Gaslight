# Database Structure & Security Rules

This document outlines the Firestore structure, the server-authoritative write architecture (Cloud Functions), security policies, and the heartbeat/disconnect model.

> **Architecture decision (July 2026, resolves the old §4 clarification):** the user chose the Firebase industry standard for a scalable App Store game — Gaslight is **server-authoritative** (Issue 1, Option D). Clients *read* the game live via Firestore streams for instant UI, but **only Cloud Functions write shared game state**: no player's device can rewrite scores, answers, or phases, and the Gemini API key lives on the server. Status: the migration is fully implemented, verified via a comprehensive emulator-based integration suite (proving Issue 1), and production-ready.

## 1. Document Hierarchies

* `/rooms/{roomCode}`: the root `GameState` document (phase, cards, votes, readiness, rotation plan).
* `/rooms/{roomCode}/players/{playerId}`: individual `PlayerState` documents. `playerId` is a client-chosen stable ID; the document stores `authUid` (the Firebase anonymous UID currently bound to that seat) for server-side ownership checks.
* `/rooms/{roomCode}/embeddings/{answerHash}`: server-managed cache of Gemini embedding vectors (md5 of the normalized answer text → vector) for the semantic-similarity filter. No client rule → default deny; server-only.

---

## 2. Write Architecture: Cloud Functions Callables

All game mutations are `onCall` Cloud Functions (`functions/src/index.ts`) that validate `request.auth.uid` against the player's stored `authUid` (or the host's, for host-only actions) and write with the Admin SDK:

| Callable | Replaces (old client method) | Guard / behavior |
|---|---|---|
| `createRoom` | `GameService.createRoom` | authenticated |
| `joinRoom` | `GameService.joinRoom` | authenticated; **re-binds `authUid`** when a known `playerId` rejoins (seat recovery) |
| `startGame` | `GameService.startGame` | host only; validates player count, rounds, deck size with descriptive errors |
| `submitAnswer` | `submitCardAnswer` | seat owner; server-side semantic-similarity check; marks author ready; auto-advances when all active players are ready |
| `castVote` | `castVote` | seat owner; enforces the self-vote guard; marks voter ready; auto-advances |
| `setReady` | `setPlayerReady` | seat owner; auto-advances when all ready |
| `advancePhase` | `forceAdvance`/`evaluateReadyState` | host only; applies timeout placeholders, per-card scoring, honor stats |
| `advanceToNextResolution` | `advanceToNextResolution` | host only; steps the vote→reveal card sequence / game over |
| `rerollPrompt` | `rerollMyPrompt` | seat owner; once per game (`hasRerolled`), truth phase only |
| `updateLobbySettings` | `updateLobbySettings` | host only |
| `handleDisconnect` | `handlePlayerDisconnect` | host, self, or anyone for a heartbeat-dead player; idempotent; card pruning, assignment bridging, reader re-indexing, **host transfer** |

Game logic mirrored in TypeScript: `functions/src/rotation_engine.ts`, `scoring_logic.ts` (per-card `S`, Sharp Eye bonus), `prompt_decks.ts`. **Regression rule: any change to a game rule must land in both the Dart client (display math) and the TS functions (authoritative math) — the functions are the source of truth.**

The Flutter client (`GameService`) is a thin wrapper: each mutation method calls its callable; reads remain live `snapshots()` listeners on the room and players. Setting `USE_EMULATOR=true` (dart-define or `.env`) points the client at local Auth/Firestore/Functions emulators.

---

## 3. Security Rules (`firestore.rules`)

* **Room documents**: `allow read: if true` (live game state for all); **`allow write: if false`** — only the Admin SDK (Cloud Functions) writes rooms.
* **Player documents**: `allow read: if true`. `create`/`delete`: **denied** (handled by `joinRoom`/`handleDisconnect`). `update`: permitted only when the caller's `request.auth.uid` matches the doc's stored `authUid` **and** the field diff touches none of the protected keys (`role`, `totalScore`, `timesFooled`, `playersDeceived`, `isHost`, `joinedAt`, `hasRerolled`, `authUid`, `id`). That leaves exactly the cosmetic/liveness surface players may write themselves: `name`, `colorValue`, `avatarIndex`, `lastSeen` (heartbeat), `lobbyReady`, `lastReaction`/`lastReactionAt` (emoji reactions).
* **Why field-diff rules**: clients doing own-doc writes must send **only the fields they intend to change** — a full-object write carrying a stale protected value counts as a change and is denied. The client write paths for reactions and lobby-ready updates (Issue 18) have been refactored to perform targeted, field-scoped updates.
* File: `firestore.rules` (workspace root); declared in `firebase.json`.

---

## 4. Heartbeat, Disconnects & Host Transfer

* Every client updates **only** `lastSeen` on its own player doc every 10 seconds (permitted by the rules).
* Any client that observes a player with `lastSeen` older than 30 s calls the `handleDisconnect` callable. The function verifies staleness/authority itself, so duplicate or racing calls are safe (idempotent: if the player's card is already gone, it just deletes the doc). Client-side deletes no longer exist.
* `handleDisconnect` performs, in one transaction: card removal, readiness/resolution-order pruning, forgery-phase assignment bridging + rotation regeneration (collapsing to TRUTH when too few players remain), vote/reveal reader re-indexing, and — if the departed player was the host — **host transfer to the earliest-joined non-spectator** (smallest `joinedAt`, ID tiebreak). Rationale: join order is deterministic, and spectators must never inherit the host role (they aren't playing and would stall the game).

---

## 5. Identity Model

* `playerId` is designed to be a **device-stable UUID** persisted in `SharedPreferences`, decoupled from Firebase Auth; the anonymous `authUid` is just the credential currently bound to that seat, and `joinRoom` re-binds it when the same `playerId` returns — so a reinstall or cleared storage keeps the player's seat and score.
* The client implements this via persistent UUID generation and rejoins via the `joinRoom` server re-bind endpoint rather than clearing the local session (Issue 16).

---

## 6. Historical Note: the Resolved Write-Architecture Clarification

The original design had `firestore.rules` restricting room writes to the host while every client wrote the room directly — a contradiction that made non-host multiplayer non-functional (Issue 1). The clarification offered host-authoritative (A), server relay (B), and loosened rules (C); the user directed us to the industry standard, recorded as **Option D: server-authoritative Cloud Functions**, which is the architecture described above.
