import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { randomUUID, createHash } from "crypto";
import { RotationEngine } from "./rotation_engine";
import { ScoringLogic, GameState, CardModel, CardSummary, MatchSummary } from "./scoring_logic";
import { PromptDecks } from "./prompt_decks";
import { isTooSimilar } from "./text_similarity";

admin.initializeApp();
const db = admin.firestore();

export function computeMatchSummary(
  cards: CardSummary[],
  players: PlayerState[],
  snapshottedPlayerNames: Record<string, string> = {}
): MatchSummary {
  const playerNameMap: Record<string, string> = { ...snapshottedPlayerNames };
  for (const p of players) {
    if (p && p.id && p.name) {
      playerNameMap[p.id] = p.name;
    }
  }

  // 1. Best Lie of the Night
  interface FlatForgery {
    authorId: string;
    authorName: string;
    text: string;
    promptText: string;
    fooled: number;
    round: number;
    targetPlayerId: string;
  }
  const allForgeries: FlatForgery[] = [];
  for (const card of cards) {
    for (const f of card.forgeries) {
      if (f.fooled > 0) {
        allForgeries.push({
          authorId: f.authorId,
          authorName: playerNameMap[f.authorId] || f.authorName || f.authorId,
          text: f.text,
          promptText: card.promptText,
          fooled: f.fooled,
          round: card.round,
          targetPlayerId: card.targetPlayerId
        });
      }
    }
  }

  allForgeries.sort((a, b) => {
    if (b.fooled !== a.fooled) return b.fooled - a.fooled;
    if (a.round !== b.round) return a.round - b.round;
    if (a.targetPlayerId !== b.targetPlayerId) return a.targetPlayerId.localeCompare(b.targetPlayerId);
    return a.authorId.localeCompare(b.authorId);
  });

  const bestLie = allForgeries.length > 0 ? {
    authorId: allForgeries[0].authorId,
    authorName: allForgeries[0].authorName,
    text: allForgeries[0].text,
    promptText: allForgeries[0].promptText,
    fooled: allForgeries[0].fooled
  } : null;

  // 2. Cleanest Truth
  interface FlatTruth {
    targetPlayerId: string;
    targetPlayerName: string;
    text: string;
    promptText: string;
    foundCount: number;
    round: number;
  }
  const allTruths: FlatTruth[] = [];
  for (const card of cards) {
    if (card.truthAnswer && card.truthAnswer.trim().length > 0 && card.truthAnswer !== kMissingAnswerPlaceholder) {
      allTruths.push({
        targetPlayerId: card.targetPlayerId,
        targetPlayerName: playerNameMap[card.targetPlayerId] || card.targetPlayerName || card.targetPlayerId,
        text: card.truthAnswer,
        promptText: card.promptText,
        foundCount: card.truthFinders.length,
        round: card.round
      });
    }
  }

  allTruths.sort((a, b) => {
    if (a.foundCount !== b.foundCount) return a.foundCount - b.foundCount;
    if (a.round !== b.round) return a.round - b.round;
    return a.targetPlayerId.localeCompare(b.targetPlayerId);
  });

  const cleanestTruth = allTruths.length > 0 ? {
    targetPlayerId: allTruths[0].targetPlayerId,
    targetPlayerName: allTruths[0].targetPlayerName,
    text: allTruths[0].text,
    promptText: allTruths[0].promptText,
    foundCount: allTruths[0].foundCount
  } : null;

  // 3. The Sting
  interface FlatSting {
    targetPlayerId: string;
    promptText: string;
    wrongVoteCount: number;
    round: number;
  }
  const allStings: FlatSting[] = [];
  for (const card of cards) {
    const wrongVoteCount = card.forgeries.reduce((sum, f) => sum + f.fooled, 0);
    if (wrongVoteCount > 0) {
      allStings.push({
        targetPlayerId: card.targetPlayerId,
        promptText: card.promptText,
        wrongVoteCount,
        round: card.round
      });
    }
  }

  allStings.sort((a, b) => {
    if (b.wrongVoteCount !== a.wrongVoteCount) return b.wrongVoteCount - a.wrongVoteCount;
    if (a.round !== b.round) return a.round - b.round;
    return a.targetPlayerId.localeCompare(b.targetPlayerId);
  });

  const theSting = allStings.length > 0 ? {
    targetPlayerId: allStings[0].targetPlayerId,
    promptText: allStings[0].promptText,
    wrongVoteCount: allStings[0].wrongVoteCount
  } : null;

  // 4. Head to Head
  const pairCounts: Record<string, { deceiverId: string; victimId: string; count: number }> = {};
  for (const card of cards) {
    for (const f of card.forgeries) {
      for (const victimId of f.fooledVoters || []) {
        if (f.authorId !== victimId) {
          const key = `${f.authorId}:::${victimId}`;
          if (!pairCounts[key]) {
            pairCounts[key] = { deceiverId: f.authorId, victimId, count: 0 };
          }
          pairCounts[key].count++;
        }
      }
    }
  }

  const headToHeadPairs = Object.values(pairCounts)
    .filter(p => p.count >= 2)
    .map(p => ({
      deceiverId: p.deceiverId,
      deceiverName: playerNameMap[p.deceiverId] || p.deceiverId,
      victimId: p.victimId,
      victimName: playerNameMap[p.victimId] || p.victimId,
      count: p.count
    }));

  headToHeadPairs.sort((a, b) => {
    if (b.count !== a.count) return b.count - a.count;
    if (a.deceiverId !== b.deceiverId) return a.deceiverId.localeCompare(b.deceiverId);
    return a.victimId.localeCompare(b.victimId);
  });

  return {
    bestLie,
    cleanestTruth,
    theSting,
    headToHead: headToHeadPairs.slice(0, 3)
  };
}

const kMissingAnswerPlaceholder = "THE SOUL IS SILENT";

/** How long a player may go unheard from before the server treats them as gone. */
export const PRESENCE_STALE_MS = 600_000; // 10 minutes (Issue 120 / O5)

const ROOM_TTL_MS = 8 * 60 * 60 * 1000;

function ttlFrom(nowMs: number): Timestamp {
  return Timestamp.fromMillis(nowMs + ROOM_TTL_MS);
}

export interface PlayerState {
  id: string;
  name: string;
  totalScore: number;
  role: string;
  isHost: boolean;
  colorValue: number;
  avatarIndex: number;
  lastSeen: number | null;
  timesFooled: number;
  playersDeceived: number;
  joinedAt: number | null;
  lobbyReady: boolean;
  lastReaction: string | null;
  lastReactionAt: number | null;
  authUid: string;
  expiresAt?: any;
}

function generateRoomCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  let result = "";
  for (let i = 0; i < 4; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

export interface PromptItem {
  text: string;
  authorId: string;
}

export type PromptSource =
  | { kind: "deck"; deckId: string }
  | { kind: "custom"; pool: PromptItem[]; fallbackDeckId: string };

export function buildCustomPromptPool(activePlayers: PlayerState[], targetSize: number): PromptItem[] {
  const pool: PromptItem[] = [];
  const seen = new Set<string>();

  for (const p of activePlayers) {
    const pPrompts = (p as any).customPrompts || [];
    let playerCollectedCount = 0;
    for (const promptText of pPrompts) {
      if (playerCollectedCount >= 3) break;
      const trimmed = (promptText || "").trim();
      if (trimmed.length > 0 && trimmed.length <= 200) {
        const lower = trimmed.toLowerCase();
        if (!seen.has(lower)) {
          seen.add(lower);
          pool.push({ text: trimmed, authorId: p.id });
          playerCollectedCount++;
        }
      }
    }
  }

  const fallbackDeckId = PromptDecks.getFallbackDeckId();
  let topUpNeeded = targetSize - pool.length;
  if (topUpNeeded > 0) {
    const fallbackPrompts = PromptDecks.drawPrompts(fallbackDeckId, Math.max(targetSize, activePlayers.length) * 2);
    for (const fp of fallbackPrompts) {
      if (topUpNeeded <= 0) break;
      const fpLower = fp.toLowerCase();
      if (!seen.has(fpLower)) {
        seen.add(fpLower);
        pool.push({ text: fp, authorId: "fallback" });
        topUpNeeded--;
      }
    }
  }

  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }

  return pool;
}

export function assignPromptsFromCustomPool(
  pool: PromptItem[],
  activePlayers: PlayerState[],
  fallbackDeckId: string,
  playerSeenMap?: Record<string, Set<string>>
): Record<string, string> {
  const assigned: Record<string, string> = {};
  const usedIndices = new Set<number>();

  for (const player of activePlayers) {
    const playerSeen = playerSeenMap?.[player.id];
    let assignedIdx = -1;
    for (let i = 0; i < pool.length; i++) {
      if (usedIndices.has(i)) continue;
      if (pool[i].authorId !== player.id && (!playerSeen || !playerSeen.has(pool[i].text))) {
        assignedIdx = i;
        break;
      }
    }

    if (assignedIdx !== -1) {
      assigned[player.id] = pool[assignedIdx].text;
      usedIndices.add(assignedIdx);
    } else {
      let swapDone = false;
      const stuckPromptIdx = pool.findIndex(
        (p, idx) => !usedIndices.has(idx) && p.authorId === player.id && (!playerSeen || !playerSeen.has(p.text))
      );
      if (stuckPromptIdx !== -1) {
        const stuckPrompt = pool[stuckPromptIdx];
        for (const [otherPlayerId, otherPromptText] of Object.entries(assigned)) {
          const otherPlayerSeen = playerSeenMap?.[otherPlayerId];
          if (otherPlayerSeen && otherPlayerSeen.has(stuckPrompt.text)) continue;

          const otherPromptIdx = pool.findIndex(p => p.text === otherPromptText);
          if (otherPromptIdx !== -1) {
            const otherPrompt = pool[otherPromptIdx];
            if (
              stuckPrompt.authorId !== otherPlayerId &&
              otherPrompt.authorId !== player.id &&
              (!playerSeen || !playerSeen.has(otherPrompt.text))
            ) {
              assigned[otherPlayerId] = stuckPrompt.text;
              assigned[player.id] = otherPrompt.text;
              usedIndices.add(stuckPromptIdx);
              swapDone = true;
              break;
            }
          }
        }
      }

      if (!swapDone) {
        const assignedThisRound = new Set(Object.values(assigned));
        const excluded = new Set([
          ...Array.from(assignedThisRound),
          ...(playerSeen ? Array.from(playerSeen) : [])
        ]);
        const freshFP = PromptDecks.drawOneExcluding(fallbackDeckId, excluded, assignedThisRound);
        assigned[player.id] = freshFP;
      }
    }
  }

  return assigned;
}

export function resolvePromptSource(room: GameState, activePlayers: PlayerState[]): PromptSource {
  const isCustom = room.selectedDeckId === "custom";
  const fallbackDeckId = room.effectiveDeckId || PromptDecks.getFallbackDeckId();

  if (isCustom && activePlayers && activePlayers.length > 0) {
    const pool = buildCustomPromptPool(activePlayers, activePlayers.length);
    return { kind: "custom", pool, fallbackDeckId };
  }

  const effective =
    room.effectiveDeckId ||
    (isCustom ? PromptDecks.getFallbackDeckId() : room.selectedDeckId) ||
    PromptDecks.getFallbackDeckId();
  return { kind: "deck", deckId: effective };
}

// 1. Create Room
export const createRoom = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const data = request.data;
  const playerName = data.playerName as string;
  const playerId = data.playerId as string; // stable UUID
  const colorValue = (data.colorValue as number) || 0xFF58A6FF;
  const avatarIndex = (data.avatarIndex as number) || 0;
  const forgeriesPerCard = data.forgeriesPerCard != null ? Number(data.forgeriesPerCard) : (data.sabotageAnswersCount != null ? Number(data.sabotageAnswersCount) : null);
  const totalRounds = (data.totalRounds as number) || 1;
  const isTimerDisabled = (data.isTimerDisabled as boolean) || false;
  const selectedDeckId = (data.selectedDeckId as string) || PromptDecks.getFallbackDeckId();
  const debugEnabled = (data.debugEnabled as boolean) || false;

  if (!playerName || !playerId) {
    throw new HttpsError("invalid-argument", "playerName and playerId are required.");
  }

  let roomCode = "";
  let exists = true;
  for (let attempt = 0; attempt < 5; attempt++) {
    roomCode = generateRoomCode();
    const doc = await db.collection("rooms").doc(roomCode).get();
    if (!doc.exists) {
      exists = false;
      break;
    }
  }

  if (exists) {
    throw new HttpsError("resource-exhausted", "Could not generate a unique room code. Try again.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(playerId);

  const nowMs = Date.now();
  const gameState = {
    roomCode,
    currentPhase: "lobby",
    totalPlayers: 1,
    forgeriesPerCard: forgeriesPerCard ?? null,
    sabotageAnswersCount: forgeriesPerCard ?? null,
    totalRounds,
    currentRound: 1,
    isTimerDisabled,
    selectedDeckId,
    currentRotationIndex: 0,
    cards: [],
    currentCardAssignments: {},
    currentReaderId: null,
    rotationPlan: {},
    readyPlayers: {},
    endTime: null,
    resolutionOrder: [],
    debugEnabled,
    expiresAt: ttlFrom(nowMs)
  };

  const playerState: PlayerState = {
    id: playerId,
    name: playerName,
    totalScore: 0,
    role: "unassigned",
    isHost: true,
    colorValue,
    avatarIndex,
    lastSeen: nowMs,
    timesFooled: 0,
    playersDeceived: 0,
    joinedAt: nowMs,
    lobbyReady: false,
    lastReaction: null,
    lastReactionAt: null,
    authUid: callerUid,
    expiresAt: ttlFrom(nowMs)
  };

  const seatToken = randomUUID();
  const batch = db.batch();
  batch.set(roomRef, gameState);
  batch.set(playerRef, playerState);
  batch.set(
    roomRef.collection("sealed").doc(`seat_${playerId}`),
    { seatTokenHash: createHash("sha256").update(seatToken).digest("hex") }
  );
  await batch.commit();

  return { roomCode, seatToken };
});

// 2. Join Room
export const joinRoom = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const data = request.data;
  const roomCode = data.roomCode as string;
  const playerName = data.playerName as string;
  const playerId = data.playerId as string; // stable UUID
  const colorValue = (data.colorValue as number) || 0xFF58A6FF;
  const avatarIndex = (data.avatarIndex as number) || 0;

  if (!roomCode || !playerName || !playerId) {
    throw new HttpsError("invalid-argument", "roomCode, playerName, and playerId are required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(playerId);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }

    const room = roomSnap.data() as GameState;
    const playerSnap = await transaction.get(playerRef);

    if (playerSnap.exists) {
      const existing = playerSnap.data() as PlayerState;
      const isOwner = existing.authUid === callerUid;

      const seatSnap = await transaction.get(roomRef.collection("sealed").doc(`seat_${playerId}`));
      const storedHash = seatSnap.exists ? (seatSnap.data() as any).seatTokenHash : null;
      const presentedHash = typeof data.seatToken === "string"
        ? createHash("sha256").update(data.seatToken).digest("hex")
        : null;
      const hasToken = !!storedHash && !!presentedHash && storedHash === presentedHash;

      // A seat nobody has heartbeated for PRESENCE_STALE_MS is abandoned and may be reclaimed.
      // This preserves recovery after a reinstall (which loses the token) without
      // letting anyone take a live seat. Mirrors handleDisconnect's isDead rule.
      const isStale = Date.now() - (existing.lastSeen ?? 0) > PRESENCE_STALE_MS;

      if (!isOwner && !hasToken && !isStale) {
        throw new HttpsError("permission-denied", "This seat is held by another player.");
      }

      // Rejoining player, update authUid and visual details
      const nowMs = Date.now();
      transaction.update(playerRef, {
        authUid: callerUid,
        name: playerName,
        colorValue,
        avatarIndex,
        lastSeen: nowMs,
        expiresAt: ttlFrom(nowMs)
      });
      return { role: existing.role };
    }

    // New joining player
    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const activeCount = players.filter(p => p.role !== "spectator").length;

    let role = "unassigned";
    if (room.currentPhase !== "lobby" || activeCount >= 10) {
      role = "spectator";
    }

    const seatToken = randomUUID();
    const nowMs = Date.now();
    const playerState = {
      id: playerId,
      name: playerName,
      totalScore: 0,
      role,
      isHost: false,
      colorValue,
      avatarIndex,
      lastSeen: nowMs,
      timesFooled: 0,
      playersDeceived: 0,
      joinedAt: nowMs,
      lobbyReady: false,
      lastReaction: null,
      lastReactionAt: null,
      authUid: callerUid,
      expiresAt: ttlFrom(nowMs)
    };

    transaction.set(playerRef, playerState);
    transaction.set(
      roomRef.collection("sealed").doc(`seat_${playerId}`),
      { seatTokenHash: createHash("sha256").update(seatToken).digest("hex") }
    );

    if (role !== "spectator") {
      transaction.update(roomRef, {
        totalPlayers: activeCount + 1
      });
    }

    return { role, seatToken };
  });
});

// 3. Start Game
// Longest answer the vote screen can display in full. Mirrored by
// kMaxAnswerLength in lib/widgets/card_grid.dart - change both together.
const MAX_ANSWER_LENGTH = 100;

export const startGame = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, selectedDeckId } = request.data;
  if (!roomCode || !selectedDeckId) {
    throw new HttpsError("invalid-argument", "roomCode and selectedDeckId are required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }

    const room = roomSnap.data() as GameState;

    // Verify caller is host
    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const hostPlayer = players.find(p => p.authUid === callerUid);

    if (!hostPlayer || !hostPlayer.isHost) {
      throw new HttpsError("permission-denied", "Only the host can start the game.");
    }

    // Issue 106 - the deck is resolved from the ROOM, never from the caller.
    // updateLobbySettings already maintains room.selectedDeckId, so that field
    // is the single source of truth; a client value is only ever a claim about
    // it. The claim is still validated rather than ignored, so a client that
    // disagrees fails loudly here instead of silently starting a deck the
    // lobby is not showing.
    const deckId: string = room.selectedDeckId || PromptDecks.getFallbackDeckId();
    if (selectedDeckId !== deckId) {
      throw new HttpsError(
        "invalid-argument",
        `Deck mismatch: caller asked for "${selectedDeckId}" but the room has "${deckId}" selected.`
      );
    }

    const activePlayers = players.filter(p => p.role !== "spectator");
    if (activePlayers.length < 3) {
      throw new HttpsError("failed-precondition", "At least 3 players are required to start the game.");
    }

    const unreadyNonHosts = activePlayers.filter(p => !p.isHost && p.lobbyReady !== true);
    if (unreadyNonHosts.length > 0) {
      throw new HttpsError(
        "failed-precondition",
        `Every player must be ready before starting (${unreadyNonHosts.length} not ready).`
      );
    }

    let forgeriesPerCard = room.forgeriesPerCard ?? room.sabotageAnswersCount;
    if (forgeriesPerCard == null) {
      forgeriesPerCard = Math.min(activePlayers.length - 1, 5);
    }
    if (!Number.isInteger(forgeriesPerCard) || forgeriesPerCard < 1) {
      throw new HttpsError(
        "failed-precondition",
        `This room has an invalid forgery-round count (${JSON.stringify(forgeriesPerCard)}). Re-set the house rules, then start again.`
      );
    }

    if (forgeriesPerCard > activePlayers.length - 1) {
      forgeriesPerCard = activePlayers.length - 1;
    }

    const totalRounds = room.totalRounds || 1;

    let prompts: string[] = [];
    if (deckId === "custom") {
      const promptSource = resolvePromptSource(room, activePlayers);
      if (promptSource.kind === "custom") {
        const assigned = assignPromptsFromCustomPool(
          promptSource.pool,
          activePlayers,
          promptSource.fallbackDeckId
        );
        prompts = activePlayers.map(p => assigned[p.id]);
      } else {
        prompts = PromptDecks.drawPrompts(promptSource.deckId, activePlayers.length);
      }
    } else {
      const totalPromptsNeeded = activePlayers.length * totalRounds;
      const deckSize = PromptDecks.getDeckSize(deckId);
      if (deckSize < totalPromptsNeeded) {
        throw new HttpsError("failed-precondition", `Deck size (${deckSize}) is insufficient for ${activePlayers.length} players over ${totalRounds} rounds (${totalPromptsNeeded} prompts required).`);
      }
      prompts = PromptDecks.drawPrompts(deckId, activePlayers.length);
    }

    const pIds = activePlayers.map(p => p.id);
    const startingCards: CardModel[] = pIds.map((pid, idx) => ({
      targetPlayerId: pid,
      promptText: prompts[idx],
      truthAnswer: "",
      sabotageAnswers: {},
      options: [],
      votes: {},
      unmaskGuesses: {}
    }));

    const endTime = room.isTimerDisabled ? null : Date.now() + 60000;

    transaction.update(roomRef, {
      currentPhase: "truth",
      totalPlayers: players.length,
      selectedDeckId: deckId,
      effectiveDeckId: deckId === "custom" ? PromptDecks.getFallbackDeckId() : deckId,
      forgeriesPerCard,
      sabotageAnswersCount: forgeriesPerCard,
      totalRounds,
      currentRound: 1,
      currentRotationIndex: 0,
      cards: startingCards,
      currentCardAssignments: {},
      rotationPlan: {},
      readyPlayers: {},
      endTime,
      resolutionOrder: [],
      expiresAt: ttlFrom(Date.now())
    });

    pIds.forEach((pid, idx) => {
      const sealedRef = roomRef.collection("sealed").doc(pid);
      transaction.set(sealedRef, { seenPrompts: [prompts[idx]], truthAnswer: "", sabotageAnswers: {}, answerAuthors: {} });
    });

    transaction.set(roomRef.collection("sealed").doc("_summary"), { cards: [] });

    // Reset player readiness
    playersSnap.docs.forEach(doc => {
      transaction.update(doc.ref, { lobbyReady: false });
    });

    return { success: true };
  });
});

// 4. Submit Answer
export const submitAnswer = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, targetCardId, authorId, text, isTruth } = request.data;
  if (!roomCode || !targetCardId || !authorId || text === undefined || isTruth === undefined) {
    throw new HttpsError("invalid-argument", "Missing required submission arguments.");
  }

  // The vote screen renders an option in full - no ellipsis - and that is only
  // possible against a bounded length (see lib/widgets/card_grid.dart). The
  // client caps the field at the same number; this is the bound that counts,
  // because a client-side limit is a suggestion.
  if (typeof text !== "string") {
    throw new HttpsError("invalid-argument", "Answer text must be a string.");
  }
  if (text.length > MAX_ANSWER_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Answer is ${text.length} characters; the maximum is ${MAX_ANSWER_LENGTH}.`
    );
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(authorId);

  // Read player details first to verify ownership
  const playerSnap = await playerRef.get();
  if (!playerSnap.exists || (playerSnap.data() as PlayerState).authUid !== callerUid) {
    throw new HttpsError("permission-denied", "User does not own this player document.");
  }

  // 1. Heuristic similarity check against sealed answer document
  const sealedRef = roomRef.collection("sealed").doc(targetCardId);
  const sealedSnap = await sealedRef.get();
  const sealedData = sealedSnap.exists ? (sealedSnap.data() as any) : { truthAnswer: "", sabotageAnswers: {} };

  const existing: string[] = [];
  if (sealedData.truthAnswer && isTruth === false) {
    existing.push(sealedData.truthAnswer);
  }
  for (const [sabId, sabotageText] of Object.entries(sealedData.sabotageAnswers || {})) {
    if (sabId !== authorId && sabotageText) {
      existing.push(sabotageText as string);
    }
  }

  if (isTooSimilar(text, existing)) {
    throw new HttpsError("invalid-argument", "Answer is too similar to another player's answer!");
  }

  // 2. Perform write in a transaction to prevent race conditions
  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }
    const playersSnap = await transaction.get(roomRef.collection("players"));

    const room = roomSnap.data() as GameState;

    if (isTruth) {
      if (room.currentPhase !== "truth") {
        throw new HttpsError("failed-precondition", "Truth submissions are only allowed during the truth phase.");
      }
      if (targetCardId !== authorId) {
        throw new HttpsError("failed-precondition", "Players can only submit truth for their own card.");
      }
    } else {
      if (room.currentPhase !== "forgery") {
        throw new HttpsError("failed-precondition", "Forgery submissions are only allowed during the forgery phase.");
      }
      const assignedTargetCardId = room.currentCardAssignments?.[authorId];
      if (!assignedTargetCardId || assignedTargetCardId !== targetCardId) {
        throw new HttpsError("failed-precondition", "Player is not assigned to forge this card in the current rotation.");
      }
    }

    const cardIdx = room.cards.findIndex(c => c.targetPlayerId === targetCardId);
    if (cardIdx === -1) {
      throw new HttpsError("not-found", "Target card not found.");
    }

    // Prepare sealed answer document in memory
    const txSealedSnap = await transaction.get(sealedRef);
    const txSealedData = txSealedSnap.exists ? (txSealedSnap.data() as any) : { truthAnswer: "", sabotageAnswers: {} };

    if (isTruth) {
      txSealedData.truthAnswer = text;
    } else {
      txSealedData.sabotageAnswers = { ...(txSealedData.sabotageAnswers || {}), [authorId]: text };
    }

    const newReadyMap: Record<string, boolean> = { ...room.readyPlayers, [authorId]: true };
    const activePlayers = playersSnap.docs.map(doc => doc.data() as PlayerState).filter(p => p.role !== "spectator");
    const allReady = activePlayers.every(p => newReadyMap[p.id] === true);

    if (allReady && activePlayers.length > 0) {
      await advancePhaseInternal(transaction, roomRef, room, activePlayers, room.cards, { [targetCardId]: txSealedData });
    } else {
      transaction.set(sealedRef, txSealedData, { merge: true });
      transaction.update(roomRef, {
        readyPlayers: newReadyMap
      });
    }

    return { success: true };
  });
});

// 4.5. Get My Option ID for Current Card (Issue 90 / W4)
export const getMyOptionId = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, cardId, playerId } = request.data || {};
  if (!roomCode || !cardId || !playerId) {
    throw new HttpsError("invalid-argument", "Missing required arguments: roomCode, cardId, and playerId.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(playerId);

  const playerSnap = await playerRef.get();
  if (!playerSnap.exists || (playerSnap.data() as PlayerState).authUid !== callerUid) {
    throw new HttpsError("permission-denied", "User does not own this player document.");
  }

  const sealedRef = roomRef.collection("sealed").doc(cardId);
  const sealedSnap = await sealedRef.get();
  if (!sealedSnap.exists) {
    return { optionId: null };
  }

  const sealedData = sealedSnap.data() as any;
  const answerAuthors: Record<string, string> = sealedData.answerAuthors || {};

  for (const [optionId, authorId] of Object.entries(answerAuthors)) {
    if (authorId === playerId) {
      return { optionId };
    }
  }

  return { optionId: null };
});

// 5. Cast Vote
export const castVote = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, targetCardId, voterId, votedForId } = request.data;
  if (!roomCode || !targetCardId || !voterId || !votedForId) {
    throw new HttpsError("invalid-argument", "Missing required vote arguments.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(voterId);

  const playerSnap = await playerRef.get();
  if (!playerSnap.exists || (playerSnap.data() as PlayerState).authUid !== callerUid) {
    throw new HttpsError("permission-denied", "User does not own this player document.");
  }

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }
    const room = roomSnap.data() as GameState;
    if (room.currentPhase !== "vote") {
      throw new HttpsError("failed-precondition", "Votes are only allowed during the vote phase.");
    }
    if (targetCardId !== room.currentReaderId) {
      throw new HttpsError("failed-precondition", "You can only vote on the card being read.");
    }

    const playersSnap = await transaction.get(roomRef.collection("players"));

    const sealedRef = roomRef.collection("sealed").doc(targetCardId);
    const sealedSnap = await transaction.get(sealedRef);
    if (!sealedSnap.exists) {
      throw new HttpsError("not-found", "Sealed card document not found.");
    }
    const sealedData = sealedSnap.data() as any;
    const answerAuthors: Record<string, string> = sealedData.answerAuthors || {};
    const resolvedAuthorId = answerAuthors[votedForId];
    if (!resolvedAuthorId) {
      throw new HttpsError("invalid-argument", "Option ID is invalid or does not exist.");
    }

    if (voterId === targetCardId || voterId === resolvedAuthorId) {
      throw new HttpsError("failed-precondition", "Self-voting is not allowed.");
    }

    const cardIdx = room.cards.findIndex(c => c.targetPlayerId === targetCardId);
    if (cardIdx === -1) {
      throw new HttpsError("not-found", "Target card not found.");
    }

    const card = room.cards[cardIdx];
    const votedOption = (card.options || []).find(o => o.id === votedForId);
    if (votedOption && (votedOption.text === kMissingAnswerPlaceholder || votedOption.text.trim() === "")) {
      throw new HttpsError("invalid-argument", "Cannot vote for a placeholder answer.");
    }

    if (card.votes?.[voterId]) {
      throw new HttpsError("failed-precondition", "You have already voted on this card.");
    }

    const newVotes = { ...card.votes, [voterId]: votedForId };
    const updatedCard = { ...card, votes: newVotes };
    const newCards = [...room.cards];
    newCards[cardIdx] = updatedCard;

    const newReadyMap: Record<string, boolean> = { ...room.readyPlayers, [voterId]: true };

    const activePlayers = playersSnap.docs.map(doc => doc.data() as PlayerState).filter(p => p.role !== "spectator");
    const allReady = activePlayers.every(p => newReadyMap[p.id] === true);

    if (allReady && activePlayers.length > 0) {
      await advancePhaseInternal(transaction, roomRef, room, activePlayers, newCards);
    } else {
      transaction.update(roomRef, {
        cards: newCards,
        readyPlayers: newReadyMap
      });
    }

    return { success: true };
  });
});

// 6. Set Ready
export const setReady = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, playerId, ready } = request.data;
  if (!roomCode || !playerId || ready === undefined) {
    throw new HttpsError("invalid-argument", "roomCode, playerId, and ready are required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(playerId);

  const playerSnap = await playerRef.get();
  if (!playerSnap.exists || (playerSnap.data() as PlayerState).authUid !== callerUid) {
    throw new HttpsError("permission-denied", "User does not own this player document.");
  }

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }
    const playersSnap = await transaction.get(roomRef.collection("players"));

    const room = roomSnap.data() as GameState;
    const newReadyMap: Record<string, boolean> = { ...room.readyPlayers, [playerId]: ready };

    const activePlayers = playersSnap.docs.map(doc => doc.data() as PlayerState).filter(p => p.role !== "spectator");
    const allReady = activePlayers.every(p => newReadyMap[p.id] === true);

    if (allReady && activePlayers.length > 0) {
      await advancePhaseInternal(transaction, roomRef, room, activePlayers, room.cards);
    } else {
      transaction.update(roomRef, { readyPlayers: newReadyMap });
    }

    return { success: true };
  });
});

// 7. Force Advance Phase
export const advancePhase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode } = request.data;
  if (!roomCode) {
    throw new HttpsError("invalid-argument", "roomCode is required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }

    const room = roomSnap.data() as GameState;

    // Verify host caller
    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const hostPlayer = players.find(p => p.authUid === callerUid);

    if (!hostPlayer || !hostPlayer.isHost) {
      throw new HttpsError("permission-denied", "Only the host can force advance the phase.");
    }

    const activePlayers = players.filter(p => p.role !== "spectator");
    await advancePhaseInternal(transaction, roomRef, room, activePlayers, room.cards);

    return { success: true };
  });
});

// 8. Reroll Prompt
export const rerollPrompt = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, playerId } = request.data;
  if (!roomCode || !playerId) {
    throw new HttpsError("invalid-argument", "roomCode and playerId are required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(playerId);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }

    const room = roomSnap.data() as GameState;
    if (room.currentPhase !== "truth") {
      throw new HttpsError("failed-precondition", "Prompt re-rolls are only allowed during the truth phase.");
    }

    const playerSnap = await transaction.get(playerRef);
    if (!playerSnap.exists || (playerSnap.data() as PlayerState).authUid !== callerUid) {
      throw new HttpsError("permission-denied", "User does not own this player document.");
    }

    // Find the player's card
    const cardIdx = room.cards.findIndex(c => c.targetPlayerId === playerId);
    if (cardIdx === -1) {
      throw new HttpsError("not-found", "Card not found for player.");
    }

    const sealedRef = roomRef.collection("sealed").doc(playerId);
    const sealedSnap = await transaction.get(sealedRef);

    const targetCard = room.cards[cardIdx];
    const sealedData = sealedSnap.exists ? (sealedSnap.data() as any) : {};
    const cardSeen: string[] = (sealedData && Array.isArray(sealedData.seenPrompts) && sealedData.seenPrompts.length > 0)
      ? sealedData.seenPrompts
      : [targetCard.promptText];

    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const activePlayers = players.filter(p => p.role !== "spectator");

    // Prompts sitting on a card right now - including this player's current
    // one. Never hand any of these back: a re-roll must visibly change something,
    // and two players must never end up on the same prompt.
    // Under Option B (Issue 107), sampling is uniform minus what is currently live on cards.
    const inPlay = new Set(room.cards.map(c => c.promptText));
    const promptSource = resolvePromptSource(room, activePlayers);
    let newPrompt: string;

    if ("pool" in promptSource) {
      const candidates = promptSource.pool.filter(
        item => item.authorId !== playerId && !inPlay.has(item.text)
      );
      if (candidates.length > 0) {
        const chosen = candidates[Math.floor(Math.random() * candidates.length)];
        newPrompt = chosen.text;
      } else {
        newPrompt = PromptDecks.drawOneExcluding(promptSource.fallbackDeckId, inPlay, inPlay);
      }
    } else {
      newPrompt = PromptDecks.drawOneExcluding(promptSource.deckId, inPlay, inPlay);
    }

    const updatedCard = {
      ...targetCard,
      promptText: newPrompt
    };
    const newCards = [...room.cards];
    newCards[cardIdx] = updatedCard;

    const updatedSeen = [...cardSeen, newPrompt];

    transaction.update(roomRef, { cards: newCards });
    transaction.set(sealedRef, { seenPrompts: updatedSeen }, { merge: true });

    return { success: true };
  });
});

// 9. Handle Player Disconnect
export const handleDisconnect = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, disconnectedPlayerId, reason } = request.data;
  if (!roomCode || !disconnectedPlayerId) {
    throw new HttpsError("invalid-argument", "roomCode and disconnectedPlayerId are required.");
  }

  if (reason !== undefined && reason !== null) {
    if (reason !== "leave" && reason !== "kick" && reason !== "presence" && reason !== "reconcile") {
      throw new HttpsError("invalid-argument", "Invalid disconnect reason.");
    }
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(disconnectedPlayerId);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      return { success: false, reason: "Room not found." };
    }

    const room = roomSnap.data() as GameState;

    // Verify caller is either host, or the disconnected player themself
    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const summarySnap = await transaction.get(roomRef.collection("sealed").doc("_summary"));
    const summaryDoc = summarySnap.exists ? (summarySnap.data() as any) : { cards: [], playerNames: {} };
    const accumulatedCards: CardSummary[] = Array.isArray(summaryDoc.cards) ? summaryDoc.cards : [];
    const snapshottedPlayerNames: Record<string, string> = { ...(summaryDoc.playerNames || {}) };
    for (const p of players) {
      if (p && p.id && p.name) {
        snapshottedPlayerNames[p.id] = p.name;
      }
    }

    const callerPlayer = players.find(p => p.authUid === callerUid);
    const disconnectedPlayer = players.find(p => p.id === disconnectedPlayerId);
    const phase = room.currentPhase;
    const isDead = disconnectedPlayer && disconnectedPlayer.lastSeen && (Date.now() - disconnectedPlayer.lastSeen) > PRESENCE_STALE_MS;

    if (!callerPlayer) {
      throw new HttpsError("permission-denied", "Not authorized to trigger disconnect.");
    }

    const effectiveReason = reason || (callerPlayer.id === disconnectedPlayerId ? "leave" : "presence");

    if (effectiveReason === "leave") {
      if (callerPlayer.id !== disconnectedPlayerId) {
        throw new HttpsError("permission-denied", "Only the player themself may leave.");
      }
    } else if (effectiveReason === "kick" || effectiveReason === "reconcile") {
      if (!callerPlayer.isHost) {
        throw new HttpsError("permission-denied", "Only host may kick or reconcile.");
      }
    } else if (effectiveReason === "presence") {
      if (!callerPlayer.isHost && callerPlayer.id !== disconnectedPlayerId && !isDead) {
        throw new HttpsError("permission-denied", "Not authorized to trigger disconnect.");
      }
      if (disconnectedPlayer && !isDead) {
        return { success: false, reason: "still-present" };
      }
    }

    const hasCard = room.cards.some(c => c.targetPlayerId === disconnectedPlayerId);

    // 1. Host leaves the lobby -> close the room entirely.
    if (disconnectedPlayer?.isHost === true && phase === "lobby") {
      for (const doc of playersSnap.docs) {
        transaction.delete(doc.ref);
      }
      transaction.delete(roomRef);
      return { success: true, roomClosed: true };
    }

    // 2. Already pruned (no card dealt for this player) -> unchanged behaviour.
    if (!hasCard) {
      if (disconnectedPlayer) {
        transaction.delete(playerRef);
      }
      return { success: true };
    }

    // 1. Delete player document
    if (disconnectedPlayer) {
      transaction.delete(playerRef);
    }

    // 2. Adjust GameState arrays/maps
    const remainingCards = room.cards.filter(c => c.targetPlayerId !== disconnectedPlayerId);
    const newReadyPlayers = { ...room.readyPlayers };
    delete newReadyPlayers[disconnectedPlayerId];

    const newResolutionOrder = room.resolutionOrder.filter(id => id !== disconnectedPlayerId);

    const remainingActivePlayers = players.filter(p => p.id !== disconnectedPlayerId && p.role !== "spectator");
    const activePlayerCount = remainingActivePlayers.length;

    let nextState: Partial<GameState> = {
      cards: remainingCards,
      totalPlayers: activePlayerCount,
      readyPlayers: newReadyPlayers,
      resolutionOrder: newResolutionOrder
    };

    if (phase === "forgery") {
      const assignments = { ...room.currentCardAssignments };

      let holderOfDisconnected: string | null = null;
      for (const [holderId, targetId] of Object.entries(assignments)) {
        if (targetId === disconnectedPlayerId) {
          holderOfDisconnected = holderId;
        }
      }

      const targetOfDisconnected = assignments[disconnectedPlayerId];
      delete assignments[disconnectedPlayerId];

      if (holderOfDisconnected && targetOfDisconnected) {
        assignments[holderOfDisconnected] = targetOfDisconnected;
      }

      const activePlayerIds = remainingActivePlayers.map(p => p.id);
      let remainingRotations: number = room.forgeriesPerCard ?? room.sabotageAnswersCount ?? 2;
      if (activePlayerIds.length <= remainingRotations) {
        remainingRotations = activePlayerIds.length - 1;
      }

      if (remainingRotations <= 0 || room.currentRotationIndex > remainingRotations) {
        // Drop back to truth mode
        const truthAssignments: Record<string, string> = {};
        for (const id of activePlayerIds) {
          truthAssignments[id] = id;
        }
        nextState = {
          ...nextState,
          currentPhase: "truth",
          currentCardAssignments: truthAssignments,
          sabotageAnswersCount: 0,
          currentRotationIndex: 0,
          endTime: room.isTimerDisabled ? null : Date.now() + 60000
        };
      } else {
        const newRotations = RotationEngine.generateRotations(activePlayerIds, remainingRotations);
        const stringRotations: Record<string, Record<string, string>> = {};
        for (const [key, val] of Object.entries(newRotations)) {
          stringRotations[key] = val;
        }

        nextState = {
          ...nextState,
          currentCardAssignments: assignments,
          rotationPlan: stringRotations,
          sabotageAnswersCount: remainingRotations
        };
      }
    } else if (phase === "truth") {
      const assignments = { ...room.currentCardAssignments };
      delete assignments[disconnectedPlayerId];
      nextState = {
        ...nextState,
        currentCardAssignments: assignments
      };
    } else if (phase === "vote" || phase === "reveal") {
      if (room.currentReaderId === disconnectedPlayerId) {
        if (newResolutionOrder.length > 0) {
          const originalIdx = room.resolutionOrder.indexOf(disconnectedPlayerId);
          if (originalIdx !== -1 && originalIdx < newResolutionOrder.length) {
            nextState = { ...nextState, currentReaderId: newResolutionOrder[originalIdx] };
          } else {
            nextState = { ...nextState, currentReaderId: newResolutionOrder[0] };
          }
        } else {
          nextState = { ...nextState, currentPhase: "gameOver" };
        }
      }
    }

    if (nextState.currentPhase === "gameOver" || (phase !== "lobby" && activePlayerCount < 3)) {
      const matchSummary = computeMatchSummary(accumulatedCards, players, snapshottedPlayerNames);
      nextState = {
        ...nextState,
        currentPhase: "gameOver",
        unmaskDeadline: null,
        endTime: null,
        matchSummary
      };
    }

    transaction.update(roomRef, nextState);

    // Host transfer logic if the host was the one who disconnected
    if (disconnectedPlayer && disconnectedPlayer.isHost && remainingActivePlayers.length > 0) {
      // Promote earliest joined player
      remainingActivePlayers.sort((a, b) => {
        const aTime = a.joinedAt || 0;
        const bTime = b.joinedAt || 0;
        if (aTime !== bTime) return aTime - bTime;
        return a.id.localeCompare(b.id);
      });
      const newHost = remainingActivePlayers[0];
      const newHostRef = roomRef.collection("players").doc(newHost.id);
      transaction.update(newHostRef, { isHost: true });
    }


    return { success: true };
  });
});

async function concludeResolutionRound(
  transaction: FirebaseFirestore.Transaction,
  roomRef: FirebaseFirestore.DocumentReference,
  room: GameState,
  players: PlayerState[],
  accumulatedCards: CardSummary[],
  snapshottedPlayerNames: Record<string, string>,
  playerSeenMap?: Record<string, Set<string>>
) {
  const totalRounds = room.totalRounds || 1;
  const currentRound = room.currentRound || 1;

  if (currentRound < totalRounds) {
    const nextRound = currentRound + 1;
    const activePlayers = players.filter(p => p.role !== "spectator");
    const promptSource = resolvePromptSource(room, activePlayers);

    let finalPlayerSeenMap = playerSeenMap;
    if (!finalPlayerSeenMap) {
      const sealedDocs = await Promise.all(
        activePlayers.map(p => transaction.get(roomRef.collection("sealed").doc(p.id)))
      );

      finalPlayerSeenMap = {};
      for (let i = 0; i < activePlayers.length; i++) {
        const p = activePlayers[i];
        const sealedSnap = sealedDocs[i];
        const sealedData = sealedSnap.exists ? (sealedSnap.data() as any) : {};
        const seenPrompts: string[] = Array.isArray(sealedData.seenPrompts) ? sealedData.seenPrompts : [];
        finalPlayerSeenMap[p.id] = new Set(seenPrompts);
      }
    }

    let assignedPrompts: Record<string, string>;
    if ("pool" in promptSource) {
      assignedPrompts = assignPromptsFromCustomPool(
        promptSource.pool,
        activePlayers,
        promptSource.fallbackDeckId,
        finalPlayerSeenMap
      );
    } else {
      assignedPrompts = {};
      const assignedThisRound = new Set<string>();
      for (const p of activePlayers) {
        const seen = finalPlayerSeenMap[p.id] || new Set<string>();
        const chosen = PromptDecks.drawOneExcluding(promptSource.deckId, seen, assignedThisRound);
        assignedPrompts[p.id] = chosen;
        assignedThisRound.add(chosen);
      }
    }

    const newCards: CardModel[] = [];
    for (let i = 0; i < activePlayers.length; i++) {
      const p = activePlayers[i];
      const newPrompt = assignedPrompts[p.id];
      const seenPrompts = Array.from(finalPlayerSeenMap[p.id] || []);
      const updatedSeen = [...seenPrompts, newPrompt];
      const sealedRef = roomRef.collection("sealed").doc(p.id);
      transaction.set(sealedRef, { seenPrompts: updatedSeen, truthAnswer: "", sabotageAnswers: {}, answerAuthors: {}, truthAnswerId: "" });

      newCards.push({
        targetPlayerId: p.id,
        promptText: newPrompt,
        truthAnswer: "",
        sabotageAnswers: {},
        options: [],
        votes: {},
        unmaskGuesses: {}
      });
    }

    const endTime = room.isTimerDisabled ? null : Date.now() + 60000;

    transaction.update(roomRef, {
      currentPhase: "truth",
      currentRound: nextRound,
      currentRotationIndex: 0,
      cards: newCards,
      currentCardAssignments: {},
      rotationPlan: {},
      readyPlayers: {},
      endTime,
      resolutionOrder: [],
      unmaskDeadline: null,
      expiresAt: ttlFrom(Date.now())
    });
  } else {
    const matchSummary = computeMatchSummary(accumulatedCards, players, snapshottedPlayerNames);
    transaction.update(roomRef, {
      currentPhase: "gameOver",
      unmaskDeadline: null,
      matchSummary
    });
  }
}

async function advancePhaseInternal(
  transaction: FirebaseFirestore.Transaction,
  roomRef: FirebaseFirestore.DocumentReference,
  room: GameState,
  activePlayers: PlayerState[],
  currentCards: CardModel[],
  sealedDataOverrides: Record<string, any> = {}
) {
  const forgeryDuration = 60000;
  const voteDuration = 45000;

  const nextReadyPlayers: Record<string, boolean> = {};

  // Fetch all sealed documents up front (READS BEFORE WRITES)
  const summaryRef = roomRef.collection("sealed").doc("_summary");
  const summarySnap = await transaction.get(summaryRef);
  const summaryDoc = summarySnap.exists ? (summarySnap.data() as any) : { cards: [], playerNames: {} };
  const accumulatedCards: CardSummary[] = Array.isArray(summaryDoc.cards) ? summaryDoc.cards : [];
  const accumulatedPlayerNames: Record<string, string> = { ...(summaryDoc.playerNames || {}) };
  for (const p of activePlayers) {
    if (p && p.id && p.name) {
      accumulatedPlayerNames[p.id] = p.name;
    }
  }

  const sealedDataMap: Record<string, any> = {};
  for (const card of currentCards) {
    const sealedRef = roomRef.collection("sealed").doc(card.targetPlayerId);
    const sealedSnap = await transaction.get(sealedRef);
    const base = sealedSnap.exists ? (sealedSnap.data() as any) : { truthAnswer: "", sabotageAnswers: {} };
    const override = sealedDataOverrides[card.targetPlayerId];
    if (override) {
      sealedDataMap[card.targetPlayerId] = {
        ...base,
        ...override,
        sabotageAnswers: {
          ...(base.sabotageAnswers || {}),
          ...(override.sabotageAnswers || {})
        }
      };
    } else {
      sealedDataMap[card.targetPlayerId] = base;
    }
  }

  if (room.currentPhase === "truth") {
    // 1. Timeout placeholder fill for missing truth answers in sealed documents
    for (const card of currentCards) {
      const sealedData = sealedDataMap[card.targetPlayerId];
      if (!sealedData.truthAnswer || sealedData.truthAnswer.trim().length === 0) {
        sealedData.truthAnswer = kMissingAnswerPlaceholder;
      }
      const sealedRef = roomRef.collection("sealed").doc(card.targetPlayerId);
      transaction.set(sealedRef, sealedData);
    }

    // 2. Generate forgery rotations now that truth phase is complete
    const pIds = activePlayers.map(p => p.id);
    const forgeriesPerCard = room.forgeriesPerCard ?? room.sabotageAnswersCount ?? 2;
    const nativeRotations = RotationEngine.generateRotations(pIds, forgeriesPerCard);
    const stringRotations: Record<string, Record<string, string>> = {};
    for (const [key, val] of Object.entries(nativeRotations)) {
      stringRotations[key] = val;
    }
    const startIdx = 1;
    const initAssignments = stringRotations[startIdx.toString()] || {};

    const endTime = room.isTimerDisabled ? null : Date.now() + forgeryDuration;

    transaction.update(roomRef, {
      currentPhase: "forgery",
      currentRotationIndex: startIdx,
      currentCardAssignments: initAssignments,
      rotationPlan: stringRotations,
      readyPlayers: nextReadyPlayers,
      endTime,
      expiresAt: ttlFrom(Date.now())
    });
  } else if (room.currentPhase === "forgery") {
    // 1. Timeout placeholder fill for missing forgery submissions in sealed documents
    for (const card of currentCards) {
      let holderId: string | null = null;
      for (const [hId, tId] of Object.entries(room.currentCardAssignments)) {
        if (tId === card.targetPlayerId) {
          holderId = hId;
          break;
        }
      }

      if (holderId) {
        const sealedData = sealedDataMap[card.targetPlayerId];
        const answer = sealedData.sabotageAnswers?.[holderId];
        if (!answer || answer.trim().length === 0) {
          sealedData.sabotageAnswers = { ...(sealedData.sabotageAnswers || {}), [holderId]: kMissingAnswerPlaceholder };
          const sealedRef = roomRef.collection("sealed").doc(card.targetPlayerId);
          transaction.set(sealedRef, sealedData);
        }
      }
    }

    const forgeriesPerCard = room.forgeriesPerCard ?? room.sabotageAnswersCount ?? 2;
    if (room.currentRotationIndex < forgeriesPerCard) {
      for (const card of currentCards) {
        const sealedData = sealedDataMap[card.targetPlayerId];
        const sealedRef = roomRef.collection("sealed").doc(card.targetPlayerId);
        transaction.set(sealedRef, sealedData);
      }

      const nextRot = room.currentRotationIndex + 1;
      const nextAssignments = room.rotationPlan[nextRot.toString()] || {};
      const endTime = room.isTimerDisabled ? null : Date.now() + forgeryDuration;

      transaction.update(roomRef, {
        currentRotationIndex: nextRot,
        currentCardAssignments: nextAssignments,
        readyPlayers: nextReadyPlayers,
        endTime,
        expiresAt: ttlFrom(Date.now())
      });
    } else {
      // Forgery rounds complete -> build unlabelled options for voting and move to Vote Phase
      const updatedCards: CardModel[] = [];

      for (const card of currentCards) {
        const sealedData = sealedDataMap[card.targetPlayerId];

        const truthOptId = randomUUID();
        const allAnswers: Array<{ id: string; text: string; authorId: string }> = [];
        allAnswers.push({
          id: truthOptId,
          text: sealedData.truthAnswer || kMissingAnswerPlaceholder,
          authorId: card.targetPlayerId
        });

        for (const [forgerId, text] of Object.entries(sealedData.sabotageAnswers || {})) {
          allAnswers.push({
            id: randomUUID(),
            text: (text as string) || kMissingAnswerPlaceholder,
            authorId: forgerId
          });
        }

        // Shuffle answers list
        for (let i = allAnswers.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [allAnswers[i], allAnswers[j]] = [allAnswers[j], allAnswers[i]];
        }

        const answerAuthors: Record<string, string> = {};
        const options: Array<{ id: string; text: string }> = [];
        for (const ans of allAnswers) {
          options.push({ id: ans.id, text: ans.text });
          answerAuthors[ans.id] = ans.authorId;
        }

        sealedData.answerAuthors = answerAuthors;
        sealedData.truthAnswerId = truthOptId;
        const sealedRef = roomRef.collection("sealed").doc(card.targetPlayerId);
        transaction.set(sealedRef, sealedData);

        updatedCards.push({
          ...card,
          options,
          truthAnswer: "",
          sabotageAnswers: {}
        });
      }

      // Shuffle order for voting resolution, excluding any cards where all options are placeholders
      const pIds = activePlayers.map(p => p.id);
      for (let i = pIds.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [pIds[i], pIds[j]] = [pIds[j], pIds[i]];
      }

      const validResolutionOrder = pIds.filter(pid => {
        const c = updatedCards.find(card => card.targetPlayerId === pid);
        if (!c || !c.options || c.options.length === 0) return false;
        return c.options.some(o => o.text && o.text.trim().length > 0 && o.text !== kMissingAnswerPlaceholder);
      });

      if (validResolutionOrder.length === 0) {
        // If all cards are placeholder/unvotable, skip vote phase and conclude round immediately
        const playerSeenMap: Record<string, Set<string>> = {};
        for (const p of activePlayers) {
          const sealedData = sealedDataMap[p.id] || {};
          const seenPrompts: string[] = Array.isArray(sealedData.seenPrompts) ? sealedData.seenPrompts : [];
          playerSeenMap[p.id] = new Set(seenPrompts);
        }

        await concludeResolutionRound(
          transaction,
          roomRef,
          room,
          activePlayers,
          accumulatedCards,
          accumulatedPlayerNames,
          playerSeenMap
        );
      } else {
        const endTime = room.isTimerDisabled ? null : Date.now() + voteDuration;

        transaction.update(roomRef, {
          currentPhase: "vote",
          cards: updatedCards,
          currentReaderId: validResolutionOrder[0],
          resolutionOrder: validResolutionOrder,
          readyPlayers: nextReadyPlayers,
          endTime,
          expiresAt: ttlFrom(Date.now())
        });
      }
    }
  } else if (room.currentPhase === "vote") {
    // Merge sealed data into public cards ONLY for the card being revealed
    const currentCardIdx = currentCards.findIndex(c => c.targetPlayerId === room.currentReaderId);
    let hasFooled = false;
    let calculatedDeltas: Record<string, number> = {};
    if (currentCardIdx !== -1) {
      const card = currentCards[currentCardIdx];
      const sealedData = sealedDataMap[card.targetPlayerId] || {};
      const answerAuthors: Record<string, string> = sealedData.answerAuthors || {};

      // Resolve stored option IDs into author IDs
      const rawVotes = card.votes || {};
      const resolvedVotes: Record<string, string> = {};
      for (const [voterId, votedOptionId] of Object.entries(rawVotes)) {
        resolvedVotes[voterId] = answerAuthors[votedOptionId] || votedOptionId;
      }

      const cardWithAnswers: CardModel = {
        ...card,
        truthAnswer: sealedData.truthAnswer || kMissingAnswerPlaceholder,
        sabotageAnswers: sealedData.sabotageAnswers || {}
      };

      hasFooled = Object.values(resolvedVotes).some(v => v !== card.targetPlayerId);
      const deltas = ScoringLogic.calculateScores(room, cardWithAnswers, resolvedVotes);
      calculatedDeltas = deltas;

      const timesFooledDeltas: Record<string, number> = {};
      const playersDeceivedDeltas: Record<string, number> = {};

      for (const [voterId, votedForId] of Object.entries(resolvedVotes)) {
        if (votedForId !== card.targetPlayerId && votedForId !== voterId) {
          timesFooledDeltas[voterId] = (timesFooledDeltas[voterId] || 0) + 1;
          playersDeceivedDeltas[votedForId] = (playersDeceivedDeltas[votedForId] || 0) + 1;
        }
      }

      if (!hasFooled) {
        // If nobody was fooled (no unmask window), apply scores immediately
        for (const p of activePlayers) {
          const sDelta = deltas[p.id] || 0;
          const tfDelta = timesFooledDeltas[p.id] || 0;
          const pdDelta = playersDeceivedDeltas[p.id] || 0;

          if (sDelta !== 0 || tfDelta !== 0 || pdDelta !== 0) {
            const pRef = roomRef.collection("players").doc(p.id);
            transaction.update(pRef, {
              totalScore: FieldValue.increment(sDelta),
              timesFooled: FieldValue.increment(tfDelta),
              playersDeceived: FieldValue.increment(pdDelta)
            });
          }
        }
      } else {
        // Unmask window will open: withhold scores and stash pending deltas in sealed document
        const sealedRef = roomRef.collection("sealed").doc(card.targetPlayerId);
        transaction.set(sealedRef, {
          ...sealedData,
          pendingScoreDeltas: deltas,
          pendingTimesFooled: timesFooledDeltas,
          pendingPlayersDeceived: playersDeceivedDeltas
        });
      }

      // Accumulate card summary for match highlights
      const truthFinders: string[] = [];
      const forgeriesSummary: Array<{
        authorId: string;
        authorName?: string;
        text: string;
        fooled: number;
        fooledVoters: string[];
      }> = [];

      for (const [forgerId, fText] of Object.entries(cardWithAnswers.sabotageAnswers || {})) {
        const fooledVoters: string[] = [];
        for (const [voterId, votedAuthor] of Object.entries(resolvedVotes)) {
          if (votedAuthor === forgerId && voterId !== forgerId) {
            fooledVoters.push(voterId);
          }
        }
        forgeriesSummary.push({
          authorId: forgerId,
          authorName: accumulatedPlayerNames[forgerId] || forgerId,
          text: (fText || "").slice(0, 100),
          fooled: fooledVoters.length,
          fooledVoters
        });
      }

      for (const [voterId, votedAuthor] of Object.entries(resolvedVotes)) {
        if (votedAuthor === card.targetPlayerId && voterId !== card.targetPlayerId) {
          truthFinders.push(voterId);
        }
      }

      const newCardSummary: CardSummary = {
        round: room.currentRound || 1,
        targetPlayerId: card.targetPlayerId,
        targetPlayerName: accumulatedPlayerNames[card.targetPlayerId] || card.targetPlayerId,
        promptText: (card.promptText || "").slice(0, 100),
        truthAnswer: (cardWithAnswers.truthAnswer || "").slice(0, 100),
        forgeries: forgeriesSummary,
        truthFinders
      };

      if (accumulatedCards.length < 60) {
        accumulatedCards.push(newCardSummary);
      }
      transaction.set(summaryRef, { cards: accumulatedCards, playerNames: accumulatedPlayerNames }, { merge: true });
    }

    const unmaskDeadline = hasFooled ? Date.now() + 20000 : null;

    const mergedCards: CardModel[] = [];
    for (const card of currentCards) {
      if (card.targetPlayerId !== room.currentReaderId) {
        mergedCards.push({
          ...card,
          truthAnswer: "",
          sabotageAnswers: {}
        });
        continue;
      }

      const sealedData = sealedDataMap[card.targetPlayerId] || {};
      const answerAuthors: Record<string, string> = sealedData.answerAuthors || {};

      if (unmaskDeadline !== null) {
        // While unmask window is open, withhold sabotage answers, score deltas, and forgery author mapping
        const publicVotes: Record<string, string> = {};
        for (const [voterId, votedOptionId] of Object.entries(card.votes || {})) {
          const author = answerAuthors[votedOptionId] || votedOptionId;
          publicVotes[voterId] = author === card.targetPlayerId ? card.targetPlayerId : votedOptionId;
        }

        mergedCards.push({
          ...card,
          votes: publicVotes,
          truthAnswer: sealedData.truthAnswer || kMissingAnswerPlaceholder,
          sabotageAnswers: {}
        });
      } else {
        // Nobody was fooled: publish full answers, resolved votes, and score deltas immediately
        const resolvedVotes: Record<string, string> = {};
        for (const [voterId, votedOptionId] of Object.entries(card.votes || {})) {
          resolvedVotes[voterId] = answerAuthors[votedOptionId] || votedOptionId;
        }

        mergedCards.push({
          ...card,
          votes: resolvedVotes,
          truthAnswer: sealedData.truthAnswer || kMissingAnswerPlaceholder,
          sabotageAnswers: sealedData.sabotageAnswers || {},
          scoreDeltas: calculatedDeltas
        });
      }
    }

    transaction.update(roomRef, {
      currentPhase: "reveal",
      cards: mergedCards,
      readyPlayers: nextReadyPlayers,
      endTime: null,
      unmaskDeadline,
      expiresAt: ttlFrom(Date.now())
    });
  } else if (room.currentPhase === "reveal") {
    // When advancing from reveal, if unmask window was open, publish the revealed sabotage answers, resolve votes, and flush score deltas
    const currentCardIdx = currentCards.findIndex(c => c.targetPlayerId === room.currentReaderId);
    if (currentCardIdx !== -1) {
      const currentCard = currentCards[currentCardIdx];
      const sealedData = sealedDataMap[currentCard.targetPlayerId] || {};
      const answerAuthors: Record<string, string> = sealedData.answerAuthors || {};
      const pendingScoreDeltas = sealedData.pendingScoreDeltas;

      if (pendingScoreDeltas) {
        for (const p of activePlayers) {
          const sDelta = pendingScoreDeltas[p.id] || 0;
          const tfDelta = (sealedData.pendingTimesFooled?.[p.id]) || 0;
          const pdDelta = (sealedData.pendingPlayersDeceived?.[p.id]) || 0;

          if (sDelta !== 0 || tfDelta !== 0 || pdDelta !== 0) {
            const pRef = roomRef.collection("players").doc(p.id);
            transaction.update(pRef, {
              totalScore: FieldValue.increment(sDelta),
              timesFooled: FieldValue.increment(tfDelta),
              playersDeceived: FieldValue.increment(pdDelta)
            });
          }
        }

        const sealedRef = roomRef.collection("sealed").doc(currentCard.targetPlayerId);
        transaction.update(sealedRef, {
          pendingScoreDeltas: FieldValue.delete(),
          pendingTimesFooled: FieldValue.delete(),
          pendingPlayersDeceived: FieldValue.delete()
        });
      }

      const resolvedVotes: Record<string, string> = {};
      for (const [vId, optId] of Object.entries(currentCard.votes || {})) {
        resolvedVotes[vId] = answerAuthors[optId] || optId;
      }

      const updatedCards = [...currentCards];
      updatedCards[currentCardIdx] = {
        ...currentCard,
        votes: resolvedVotes,
        sabotageAnswers: sealedData.sabotageAnswers || {},
        scoreDeltas: pendingScoreDeltas || currentCard.scoreDeltas || {}
      };

      transaction.update(roomRef, {
        cards: updatedCards,
        unmaskDeadline: 0
      });
    }
  }
}

// 10. Update Lobby Settings
export const updateLobbySettings = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const callerUid = request.auth.uid;
  const { roomCode, forgeriesPerCard, sabotageAnswersCount, totalRounds, isTimerDisabled, selectedDeckId } = request.data as any;
  if (!roomCode) {
    throw new HttpsError("invalid-argument", "roomCode is required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }

    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const hostPlayer = players.find(p => p.authUid === callerUid);

    if (!hostPlayer || !hostPlayer.isHost) {
      throw new HttpsError("permission-denied", "Only host can update lobby settings.");
    }

    const activePlayers = players.filter(p => p.role !== "spectator");
    const numPlayers = activePlayers.length;

    const data = roomSnap.data() as GameState;
    const isExplicitForgeriesUpdate = forgeriesPerCard != null || sabotageAnswersCount != null;
    let newForgeries: number | undefined = isExplicitForgeriesUpdate
      ? Number(forgeriesPerCard != null ? forgeriesPerCard : sabotageAnswersCount)
      : (data.forgeriesPerCard ?? data.sabotageAnswersCount ?? undefined);

    if (isExplicitForgeriesUpdate && newForgeries != null) {
      const maxAllowed = numPlayers > 1 ? numPlayers - 1 : 8;
      if (!Number.isInteger(newForgeries) || newForgeries < 1 || newForgeries > maxAllowed) {
        throw new HttpsError(
          "invalid-argument",
          `Forgeries per card (${newForgeries}) must be between 1 and active players - 1 (${maxAllowed}).`
        );
      }
    }

    let newTotalRounds = totalRounds != null ? totalRounds : (data.totalRounds || 1);
    if (!Number.isInteger(newTotalRounds) || newTotalRounds < 1 || newTotalRounds > 5) {
      throw new HttpsError("invalid-argument", `Total rounds (${newTotalRounds}) must be between 1 and 5.`);
    }

    const updatePayload: Record<string, any> = {
      totalRounds: newTotalRounds,
      isTimerDisabled: isTimerDisabled != null ? isTimerDisabled : (data.isTimerDisabled || false),
      selectedDeckId: selectedDeckId != null ? selectedDeckId : (data.selectedDeckId || PromptDecks.getFallbackDeckId()),
      expiresAt: ttlFrom(Date.now())
    };
    if (newForgeries !== undefined) {
      updatePayload.forgeriesPerCard = newForgeries;
      updatePayload.sabotageAnswersCount = newForgeries;
    }

    transaction.update(roomRef, updatePayload);

    return { success: true };
  });
});

// 11. Advance to Next Resolution
export const advanceToNextResolution = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const callerUid = request.auth.uid;
  const { roomCode } = request.data;
  if (!roomCode) {
    throw new HttpsError("invalid-argument", "roomCode is required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }

    const room = roomSnap.data() as GameState;

    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const activePlayers = players.filter(p => p.role !== "spectator");

    const summarySnap = await transaction.get(roomRef.collection("sealed").doc("_summary"));
    const summaryDoc = summarySnap.exists ? (summarySnap.data() as any) : { cards: [], playerNames: {} };
    const accumulatedCards: CardSummary[] = Array.isArray(summaryDoc.cards) ? summaryDoc.cards : [];
    const snapshottedPlayerNames: Record<string, string> = { ...(summaryDoc.playerNames || {}) };
    for (const p of players) {
      if (p && p.id && p.name) {
        snapshottedPlayerNames[p.id] = p.name;
      }
    }

    const currentReaderSealedSnap = room.currentReaderId
      ? await transaction.get(roomRef.collection("sealed").doc(room.currentReaderId))
      : null;

    // Pre-read all sealed docs for active players before any write
    const sealedDocs = await Promise.all(
      activePlayers.map(p => transaction.get(roomRef.collection("sealed").doc(p.id)))
    );

    const playerSeenMap: Record<string, Set<string>> = {};
    for (let i = 0; i < activePlayers.length; i++) {
      const p = activePlayers[i];
      const sealedSnap = sealedDocs[i];
      const sealedData = sealedSnap.exists ? (sealedSnap.data() as any) : {};
      const seenPrompts: string[] = Array.isArray(sealedData.seenPrompts) ? sealedData.seenPrompts : [];
      playerSeenMap[p.id] = new Set(seenPrompts);
    }

    if (currentReaderSealedSnap && currentReaderSealedSnap.exists) {
      const sealedData = currentReaderSealedSnap.data() as any;
      const pendingScoreDeltas = sealedData.pendingScoreDeltas;
      if (pendingScoreDeltas) {
        for (const p of players) {
          const sDelta = pendingScoreDeltas[p.id] || 0;
          const tfDelta = (sealedData.pendingTimesFooled?.[p.id]) || 0;
          const pdDelta = (sealedData.pendingPlayersDeceived?.[p.id]) || 0;
          if (sDelta !== 0 || tfDelta !== 0 || pdDelta !== 0) {
            const pRef = roomRef.collection("players").doc(p.id);
            transaction.update(pRef, {
              totalScore: FieldValue.increment(sDelta),
              timesFooled: FieldValue.increment(tfDelta),
              playersDeceived: FieldValue.increment(pdDelta)
            });
          }
        }
        transaction.update(currentReaderSealedSnap.ref, {
          pendingScoreDeltas: FieldValue.delete(),
          pendingTimesFooled: FieldValue.delete(),
          pendingPlayersDeceived: FieldValue.delete()
        });
      }
    }

    const hostPlayer = players.find(p => p.authUid === callerUid);

    if (!hostPlayer || !hostPlayer.isHost) {
      throw new HttpsError("permission-denied", "Only host can advance resolution.");
    }

    const order = room.resolutionOrder || [];
    const currentIdx = order.indexOf(room.currentReaderId || "");

    let nextIdx = currentIdx + 1;
    while (nextIdx < order.length) {
      const nextCardTargetId = order[nextIdx];
      const nextCard = room.cards.find(c => c.targetPlayerId === nextCardTargetId);
      const isCardVotable = nextCard && nextCard.options && nextCard.options.some(o => o.text && o.text.trim().length > 0 && o.text !== kMissingAnswerPlaceholder);
      if (isCardVotable) {
        break;
      }
      nextIdx++;
    }

    if (currentIdx !== -1 && nextIdx < order.length) {
      const nextReaderId = order[nextIdx];
      const endTime = room.isTimerDisabled ? null : Date.now() + 45000;
      transaction.update(roomRef, {
        currentPhase: "vote",
        currentReaderId: nextReaderId,
        readyPlayers: {},
        endTime: endTime,
        unmaskDeadline: null
      });
    } else {
      await concludeResolutionRound(
        transaction,
        roomRef,
        room,
        players,
        accumulatedCards,
        snapshottedPlayerNames,
        playerSeenMap
      );
    }

    return { success: true };
  });
});

// 12. Submit Unmask Guess
export const submitUnmaskGuess = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const { roomCode, guesserId, guessedAuthorId } = request.data;
  if (!roomCode || !guesserId || !guessedAuthorId) {
    throw new HttpsError("invalid-argument", "roomCode, guesserId, and guessedAuthorId are required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(guesserId);

  const playerSnap = await playerRef.get();
  if (!playerSnap.exists || (playerSnap.data() as PlayerState).authUid !== callerUid) {
    throw new HttpsError("permission-denied", "User does not own this player document.");
  }

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }
    const room = roomSnap.data() as GameState;

    if (room.currentPhase !== "reveal") {
      throw new HttpsError("failed-precondition", "Unmask guesses are only allowed during reveal phase.");
    }

    if (!room.unmaskDeadline || Date.now() > room.unmaskDeadline) {
      throw new HttpsError("failed-precondition", "Unmask guess deadline has passed or is inactive.");
    }

    const currentCardIdx = room.cards.findIndex(c => c.targetPlayerId === room.currentReaderId);
    if (currentCardIdx === -1) {
      throw new HttpsError("failed-precondition", "Current reader card not found.");
    }
    const currentCard = room.cards[currentCardIdx];

    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);

    const sealedRef = roomRef.collection("sealed").doc(currentCard.targetPlayerId);
    const sealedSnap = await transaction.get(sealedRef);
    if (!sealedSnap.exists) {
      throw new HttpsError("not-found", "Sealed card not found.");
    }
    const sealedData = sealedSnap.data() as any;
    const answerAuthors: Record<string, string> = sealedData.answerAuthors || {};

    const voterId = guesserId;
    const votedOptionId = currentCard.votes?.[voterId];
    if (!votedOptionId) {
      throw new HttpsError("failed-precondition", "Player did not cast a vote for this card.");
    }

    const votedForId = answerAuthors[votedOptionId] || votedOptionId;
    if (votedForId === currentCard.targetPlayerId) {
      throw new HttpsError("failed-precondition", "Only players who fell for a forgery can make an unmask guess.");
    }

    if (currentCard.unmaskGuesses?.[voterId]) {
      throw new HttpsError("failed-precondition", "Player has already submitted an unmask guess.");
    }

    if (guessedAuthorId === voterId) {
      throw new HttpsError("invalid-argument", "Cannot guess yourself as the author.");
    }

    // Paired with the identical exclusion in lib/screens/phase4_reveal.dart:_buildRevengeGuessTray. The client
    // copy keeps the impossible choice off screen; the server copy is the real
    // guard — a stale or modified client must not be able to submit it. Change
    // both or neither.
    if (guessedAuthorId === currentCard.targetPlayerId) {
      throw new HttpsError(
        "invalid-argument",
        "The card's target wrote the truth and cannot be accused of forgery."
      );
    }

    const unmaskGuesses = currentCard.unmaskGuesses ? { ...currentCard.unmaskGuesses } : {};
    unmaskGuesses[voterId] = guessedAuthorId;

    const fooledVoterIds = Object.entries(currentCard.votes || {})
      .filter(([vId, optId]) => (answerAuthors[optId] || optId) !== currentCard.targetPlayerId)
      .map(([vId]) => vId);
    const allFooledGuessed = fooledVoterIds.length > 0 && fooledVoterIds.every(vId => unmaskGuesses[vId] !== undefined);

    let updatedCard: CardModel;
    let nextUnmaskDeadline = room.unmaskDeadline;
    const isCorrect = guessedAuthorId === votedForId;
    const currentPendingDeltas: Record<string, number> = { ...(sealedData.pendingScoreDeltas || currentCard.scoreDeltas || {}) };
    if (isCorrect) {
      currentPendingDeltas[voterId] = (currentPendingDeltas[voterId] || 0) + 1;
      currentPendingDeltas[votedForId] = (currentPendingDeltas[votedForId] || 0) - 1;
    }

    if (allFooledGuessed) {
      // Flush all pending score deltas and pending stats to player documents
      for (const p of players) {
        const sDelta = currentPendingDeltas[p.id] || 0;
        const tfDelta = (sealedData.pendingTimesFooled?.[p.id]) || 0;
        const pdDelta = (sealedData.pendingPlayersDeceived?.[p.id]) || 0;

        if (sDelta !== 0 || tfDelta !== 0 || pdDelta !== 0) {
          const pRef = roomRef.collection("players").doc(p.id);
          transaction.update(pRef, {
            totalScore: FieldValue.increment(sDelta),
            timesFooled: FieldValue.increment(tfDelta),
            playersDeceived: FieldValue.increment(pdDelta)
          });
        }
      }

      transaction.update(sealedRef, {
        pendingScoreDeltas: FieldValue.delete(),
        pendingTimesFooled: FieldValue.delete(),
        pendingPlayersDeceived: FieldValue.delete()
      });

      const resolvedVotes: Record<string, string> = {};
      for (const [vId, optId] of Object.entries(currentCard.votes || {})) {
        resolvedVotes[vId] = answerAuthors[optId] || optId;
      }
      updatedCard = {
        ...currentCard,
        votes: resolvedVotes,
        sabotageAnswers: sealedData.sabotageAnswers || {},
        unmaskGuesses,
        scoreDeltas: currentPendingDeltas
      };
      nextUnmaskDeadline = 0;
    } else {
      transaction.update(sealedRef, {
        pendingScoreDeltas: currentPendingDeltas
      });

      updatedCard = {
        ...currentCard,
        unmaskGuesses
      };
    }

    const newCards = [...room.cards];
    newCards[currentCardIdx] = updatedCard;

    transaction.update(roomRef, {
      cards: newCards,
      unmaskDeadline: nextUnmaskDeadline
    });

    return { success: true };
  });
});

// 12.1 Close Unmask Window
export const closeUnmaskWindow = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const callerUid = request.auth.uid;
  const { roomCode } = request.data;
  if (!roomCode) {
    throw new HttpsError("invalid-argument", "roomCode is required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }
    const room = roomSnap.data() as GameState;
    if (room.currentPhase !== "reveal") {
      return { success: true };
    }

    const currentCardIdx = room.cards.findIndex(c => c.targetPlayerId === room.currentReaderId);
    if (currentCardIdx === -1) {
      return { success: true };
    }
    const currentCard = room.cards[currentCardIdx];

    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const callerPlayer = players.find(p => p.authUid === callerUid);
    if (!callerPlayer) {
      throw new HttpsError("permission-denied", "Caller is not in this room.");
    }

    const sealedRef = roomRef.collection("sealed").doc(currentCard.targetPlayerId);
    const sealedSnap = await transaction.get(sealedRef);
    if (!sealedSnap.exists) {
      return { success: true };
    }
    const sealedData = sealedSnap.data() as any;
    const pendingScoreDeltas = sealedData.pendingScoreDeltas;
    const answerAuthors: Record<string, string> = sealedData.answerAuthors || {};

    if (pendingScoreDeltas) {
      for (const p of players) {
        const sDelta = pendingScoreDeltas[p.id] || 0;
        const tfDelta = (sealedData.pendingTimesFooled?.[p.id]) || 0;
        const pdDelta = (sealedData.pendingPlayersDeceived?.[p.id]) || 0;
        if (sDelta !== 0 || tfDelta !== 0 || pdDelta !== 0) {
          const pRef = roomRef.collection("players").doc(p.id);
          transaction.update(pRef, {
            totalScore: FieldValue.increment(sDelta),
            timesFooled: FieldValue.increment(tfDelta),
            playersDeceived: FieldValue.increment(pdDelta)
          });
        }
      }

      transaction.update(sealedRef, {
        pendingScoreDeltas: FieldValue.delete(),
        pendingTimesFooled: FieldValue.delete(),
        pendingPlayersDeceived: FieldValue.delete()
      });
    }

    const resolvedVotes: Record<string, string> = {};
    for (const [vId, optId] of Object.entries(currentCard.votes || {})) {
      resolvedVotes[vId] = answerAuthors[optId] || optId;
    }

    const updatedCards = [...room.cards];
    updatedCards[currentCardIdx] = {
      ...currentCard,
      votes: resolvedVotes,
      sabotageAnswers: sealedData.sabotageAnswers || {},
      scoreDeltas: pendingScoreDeltas || currentCard.scoreDeltas || {}
    };

    transaction.update(roomRef, {
      cards: updatedCards,
      unmaskDeadline: 0
    });

    return { success: true };
  });
});

// 13. Debug Add Bots
export const debugAddBots = onCall(async (request) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError("permission-denied", "Debug commands are only available in the local emulator.");
  }
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const callerUid = request.auth.uid;
  const { roomCode } = request.data;
  if (!roomCode) {
    throw new HttpsError("invalid-argument", "roomCode is required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) {
    throw new HttpsError("not-found", "Room not found.");
  }
  const room = roomSnap.data() as GameState;
  if (!room.debugEnabled) {
    throw new HttpsError("permission-denied", "Debug commands are only allowed when debugEnabled is true.");
  }

  const playersSnap = await roomRef.collection("players").get();
  const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
  const callerPlayer = players.find(p => p.authUid === callerUid);
  if (!callerPlayer || !callerPlayer.isHost) {
    throw new HttpsError("permission-denied", "Only the host can execute debug commands.");
  }

  const botColors = [
    0xFF58A6FF, 0xFFFF7B72, 0xFF7EE787, 0xFFA5D6FF, 0xFFFFE68C,
    0xFFD3A4FF, 0xFFFF80BF, 0xFF79C0FF, 0xFFFF935A, 0xFF85EA2D
  ];

  const batch = db.batch();
  for (let i = 1; i <= 9; i++) {
    const botId = `bot_${i}`;
    const botState = {
      id: botId,
      name: `Bot ${i}`,
      isHost: false,
      colorValue: botColors[i % botColors.length],
      avatarIndex: i % 6,
      joinedAt: Date.now() + i,
      lobbyReady: true,
      totalScore: 0,
      role: "unassigned",
      isReady: false,
      timesFooled: 0,
      playersDeceived: 0,
      lastSeen: null,
      lastReaction: null,
      lastReactionAt: null,
      authUid: `bot_auth_${botId}`
    };
    const playerRef = roomRef.collection("players").doc(botId);
    batch.set(playerRef, botState);
  }
  await batch.commit();
  return { success: true };
});

// 13. Debug Simulate Bot Responses
export const debugSimulateBotResponses = onCall(async (request) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError("permission-denied", "Debug commands are only available in the local emulator.");
  }
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const callerUid = request.auth.uid;
  const { roomCode } = request.data;
  if (!roomCode) {
    throw new HttpsError("invalid-argument", "roomCode is required.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }
    const room = roomSnap.data() as GameState;
    if (!room.debugEnabled) {
      throw new HttpsError("permission-denied", "Debug commands are only allowed when debugEnabled is true.");
    }

    const playersSnap = await transaction.get(roomRef.collection("players"));
    const players = playersSnap.docs.map(doc => doc.data() as PlayerState);
    const callerPlayer = players.find(p => p.authUid === callerUid);
    if (!callerPlayer || !callerPlayer.isHost) {
      throw new HttpsError("permission-denied", "Only the host can execute debug commands.");
    }

    const phase = room.currentPhase;
    const cards = room.cards ? [...room.cards] : [];
    const readyPlayers = room.readyPlayers ? { ...room.readyPlayers } : {};

    if (phase === "forgery" || phase === "truth") {
      const sealedDataOverrides: Record<string, any> = {};

      for (const p of players) {
        if (!p.id.startsWith("bot_")) continue;

        readyPlayers[p.id] = true;

        const targetId = phase === "truth" ? p.id : room.currentCardAssignments?.[p.id];
        if (targetId) {
          if (phase === "truth") {
            sealedDataOverrides[targetId] = {
              ...(sealedDataOverrides[targetId] || {}),
              truthAnswer: `Simulated Answer from ${p.name}`
            };
          } else {
            const currentSabs = sealedDataOverrides[targetId]?.sabotageAnswers || {};
            sealedDataOverrides[targetId] = {
              ...(sealedDataOverrides[targetId] || {}),
              sabotageAnswers: { ...currentSabs, [p.id]: `Simulated Answer from ${p.name}` }
            };
          }
        }
      }

      const activePlayers = players.filter(p => p.role !== "spectator");
      const allReady = activePlayers.length > 0 && activePlayers.every(p => readyPlayers[p.id] === true);

      if (allReady) {
        await advancePhaseInternal(transaction, roomRef, room, activePlayers, cards, sealedDataOverrides);
      } else {
        for (const [tId, sData] of Object.entries(sealedDataOverrides)) {
          const sRef = roomRef.collection("sealed").doc(tId);
          transaction.set(sRef, sData, { merge: true });
        }
        transaction.update(roomRef, {
          readyPlayers
        });
      }
    } else if (phase === "vote") {
      const currentTargetId = room.currentReaderId;
      if (!currentTargetId) {
        throw new HttpsError("failed-precondition", "No current reader.");
      }

      const sealedRef = roomRef.collection("sealed").doc(currentTargetId);
      const sealedSnap = await transaction.get(sealedRef);
      const sealedData = sealedSnap.exists ? (sealedSnap.data() as any) : {};
      const truthAnswerId = sealedData.truthAnswerId || currentTargetId;

      const cardIdx = cards.findIndex(c => c.targetPlayerId === currentTargetId);
      if (cardIdx !== -1) {
        const card = { ...cards[cardIdx] };
        const votes = card.votes ? { ...card.votes } : {};

        for (const p of players) {
          if (!p.id.startsWith("bot_")) continue;

          readyPlayers[p.id] = true;
          if (currentTargetId !== p.id) {
            votes[p.id] = truthAnswerId;
          }
        }
        card.votes = votes;
        cards[cardIdx] = card;
      }

      if (currentTargetId.startsWith("bot_")) {
        readyPlayers[currentTargetId] = true;
      }

      const activePlayers = players.filter(p => p.role !== "spectator");
      const allReady = activePlayers.length > 0 && activePlayers.every(p => readyPlayers[p.id] === true);

      if (allReady) {
        await advancePhaseInternal(transaction, roomRef, room, activePlayers, cards);
      } else {
        transaction.update(roomRef, {
          cards,
          readyPlayers
        });
      }
    }

    return { success: true };
  });
});
