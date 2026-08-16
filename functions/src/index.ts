import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { randomUUID } from "crypto";
import { RotationEngine } from "./rotation_engine";
import { ScoringLogic, GameState, CardModel } from "./scoring_logic";
import { PromptDecks } from "./prompt_decks";
import { isTooSimilar } from "./text_similarity";

admin.initializeApp();
const db = admin.firestore();

const kMissingAnswerPlaceholder = "THE SOUL IS SILENT";

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
  const selectedDeckId = (data.selectedDeckId as string) || "the_daily_grind";
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

  const batch = db.batch();
  batch.set(roomRef, gameState);
  batch.set(playerRef, playerState);
  await batch.commit();

  return { roomCode };
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
      // Rejoining player, update authUid and visual details
      const nowMs = Date.now();
      const existing = playerSnap.data() as PlayerState;
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

    if (role !== "spectator") {
      transaction.update(roomRef, {
        totalPlayers: activeCount + 1
      });
    }

    return { role };
  });
});

// 3. Start Game
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
    if (selectedDeckId === "custom") {
      interface PromptItem {
        text: string;
        authorId: string;
      }
      const pool: PromptItem[] = [];
      const seen = new Set<string>();

      for (const p of activePlayers) {
        const pPrompts = (p as any).customPrompts || [];
        let playerCollectedCount = 0;
        for (const promptText of pPrompts) {
          if (playerCollectedCount >= 3) break;
          const trimmed = promptText.trim();
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

      const fallbackDeckId = "the_daily_grind";
      let topUpNeeded = activePlayers.length - pool.length;
      if (topUpNeeded > 0) {
        const fallbackPrompts = PromptDecks.drawPrompts(fallbackDeckId, activePlayers.length * 2);
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

      const assigned: Record<string, string> = {};
      const usedIndices = new Set<number>();

      for (const player of activePlayers) {
        let assignedIdx = -1;
        for (let i = 0; i < pool.length; i++) {
          if (usedIndices.has(i)) continue;
          if (pool[i].authorId !== player.id) {
            assignedIdx = i;
            break;
          }
        }

        if (assignedIdx !== -1) {
          assigned[player.id] = pool[assignedIdx].text;
          usedIndices.add(assignedIdx);
        } else {
          let swapDone = false;
          const stuckPromptIdx = pool.findIndex((p, idx) => !usedIndices.has(idx) && p.authorId === player.id);
          if (stuckPromptIdx !== -1) {
            const stuckPrompt = pool[stuckPromptIdx];
            for (const [otherPlayerId, otherPromptText] of Object.entries(assigned)) {
              const otherPromptIdx = pool.findIndex(p => p.text === otherPromptText);
              if (otherPromptIdx !== -1) {
                const otherPrompt = pool[otherPromptIdx];
                if (stuckPrompt.authorId !== otherPlayerId && otherPrompt.authorId !== player.id) {
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
            const fallbackPrompts = PromptDecks.drawPrompts(fallbackDeckId, activePlayers.length * 2);
            let freshFP = "";
            for (const fp of fallbackPrompts) {
              const fpLower = fp.toLowerCase();
              if (!seen.has(fpLower)) {
                seen.add(fpLower);
                freshFP = fp;
                break;
              }
            }
            assigned[player.id] = freshFP;
          }
        }
      }

      prompts = activePlayers.map(p => assigned[p.id]);
    } else {
      const totalPromptsNeeded = activePlayers.length * totalRounds;
      const deckSize = PromptDecks.getDeckSize(selectedDeckId);
      if (deckSize < totalPromptsNeeded) {
        throw new HttpsError("failed-precondition", `Deck size (${deckSize}) is insufficient for ${activePlayers.length} players over ${totalRounds} rounds (${totalPromptsNeeded} prompts required).`);
      }
      prompts = PromptDecks.drawPrompts(selectedDeckId, activePlayers.length);
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
      selectedDeckId,
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
      transaction.set(sealedRef, { seenPrompts: [prompts[idx]] }, { merge: true });
    });

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

    if (voterId === resolvedAuthorId) {
      throw new HttpsError("failed-precondition", "Self-voting is not allowed.");
    }

    const room = roomSnap.data() as GameState;
    const cardIdx = room.cards.findIndex(c => c.targetPlayerId === targetCardId);
    if (cardIdx === -1) {
      throw new HttpsError("not-found", "Target card not found.");
    }

    const card = room.cards[cardIdx];
    const newVotes = { ...card.votes, [voterId]: resolvedAuthorId };
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

    const excluded = new Set([
      ...room.cards.map(c => c.promptText),
      ...cardSeen
    ]);
    const deckId = room.selectedDeckId === "custom" ? "the_daily_grind" : room.selectedDeckId;
    const newPrompt = PromptDecks.drawOneExcluding(deckId, excluded);

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
  const { roomCode, disconnectedPlayerId } = request.data;
  if (!roomCode || !disconnectedPlayerId) {
    throw new HttpsError("invalid-argument", "roomCode and disconnectedPlayerId are required.");
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
    const callerPlayer = players.find(p => p.authUid === callerUid);
    const disconnectedPlayer = players.find(p => p.id === disconnectedPlayerId);
    const phase = room.currentPhase;
    const isDead = disconnectedPlayer && disconnectedPlayer.lastSeen && (Date.now() - disconnectedPlayer.lastSeen) > 30000;

    if (!callerPlayer || (!callerPlayer.isHost && callerPlayer.id !== disconnectedPlayerId && !isDead)) {
      throw new HttpsError("permission-denied", "Not authorized to trigger disconnect.");
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
      transaction.delete(playerRef);
      return { success: true };
    }

    // 1. Delete player document
    transaction.delete(playerRef);

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

    if (phase !== "lobby" && activePlayerCount < 3) {
      nextState = {
        ...nextState,
        currentPhase: "gameOver",
        unmaskDeadline: null,
        endTime: null,
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
      transaction.set(sealedRef, sealedData, { merge: true });
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
          transaction.set(sealedRef, sealedData, { merge: true });
        }
      }
    }

    const forgeriesPerCard = room.forgeriesPerCard ?? room.sabotageAnswersCount ?? 2;
    if (room.currentRotationIndex < forgeriesPerCard) {
      for (const card of currentCards) {
        const sealedData = sealedDataMap[card.targetPlayerId];
        const sealedRef = roomRef.collection("sealed").doc(card.targetPlayerId);
        transaction.set(sealedRef, sealedData, { merge: true });
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
        transaction.set(sealedRef, sealedData, { merge: true });

        updatedCards.push({
          ...card,
          options,
          truthAnswer: "",
          sabotageAnswers: {}
        });
      }

      // Shuffle order for voting resolution
      const pIds = activePlayers.map(p => p.id);
      for (let i = pIds.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [pIds[i], pIds[j]] = [pIds[j], pIds[i]];
      }

      const endTime = room.isTimerDisabled ? null : Date.now() + voteDuration;

      transaction.update(roomRef, {
        currentPhase: "vote",
        cards: updatedCards,
        currentReaderId: pIds.length > 0 ? pIds[0] : null,
        resolutionOrder: pIds,
        readyPlayers: nextReadyPlayers,
        endTime,
        expiresAt: ttlFrom(Date.now())
      });
    }
  } else if (room.currentPhase === "vote") {
    // Merge sealed data into public cards for scoring and reveal screen
    const mergedCards: CardModel[] = [];
    for (const card of currentCards) {
      const sealedData = sealedDataMap[card.targetPlayerId] || {};

      mergedCards.push({
        ...card,
        truthAnswer: sealedData.truthAnswer || kMissingAnswerPlaceholder,
        sabotageAnswers: sealedData.sabotageAnswers || {}
      });
    }

    // Tally scores and advance to Reveal
    const currentCard = mergedCards.find(c => c.targetPlayerId === room.currentReaderId);
    let hasFooled = false;
    if (currentCard) {
      const votes = currentCard.votes || {};
      hasFooled = Object.values(votes).some(v => v !== currentCard.targetPlayerId);
      const deltas = ScoringLogic.calculateScores(room, currentCard, votes);

      const timesFooledDeltas: Record<string, number> = {};
      const playersDeceivedDeltas: Record<string, number> = {};

      for (const [voterId, votedForId] of Object.entries(votes)) {
        if (votedForId !== currentCard.targetPlayerId && votedForId !== voterId) {
          timesFooledDeltas[voterId] = (timesFooledDeltas[voterId] || 0) + 1;
          playersDeceivedDeltas[votedForId] = (playersDeceivedDeltas[votedForId] || 0) + 1;
        }
      }

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
    }

    const unmaskDeadline = hasFooled ? Date.now() + 20000 : null;

    transaction.update(roomRef, {
      currentPhase: "reveal",
      cards: mergedCards,
      readyPlayers: nextReadyPlayers,
      endTime: null,
      unmaskDeadline,
      expiresAt: ttlFrom(Date.now())
    });
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
      selectedDeckId: selectedDeckId != null ? selectedDeckId : (data.selectedDeckId || "the_daily_grind"),
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
    const hostPlayer = players.find(p => p.authUid === callerUid);

    if (!hostPlayer || !hostPlayer.isHost) {
      throw new HttpsError("permission-denied", "Only host can advance resolution.");
    }

    const order = room.resolutionOrder || [];
    const currentIdx = order.indexOf(room.currentReaderId || "");

    if (currentIdx !== -1 && currentIdx < order.length - 1) {
      const nextReaderId = order[currentIdx + 1];
      const endTime = room.isTimerDisabled ? null : Date.now() + 45000;
      transaction.update(roomRef, {
        currentPhase: "vote",
        currentReaderId: nextReaderId,
        readyPlayers: {},
        endTime: endTime,
        unmaskDeadline: null
      });
    } else {
      const totalRounds = room.totalRounds || 1;
      const currentRound = room.currentRound || 1;

      if (currentRound < totalRounds) {
        const nextRound = currentRound + 1;
        const activePlayers = players.filter(p => p.role !== "spectator");
        const deckId = room.selectedDeckId || "the_daily_grind";

        const sealedDocs = await Promise.all(
          activePlayers.map(p => transaction.get(roomRef.collection("sealed").doc(p.id)))
        );

        const newCards: CardModel[] = [];
        for (let i = 0; i < activePlayers.length; i++) {
          const p = activePlayers[i];
          const sealedSnap = sealedDocs[i];
          const sealedData = sealedSnap.exists ? (sealedSnap.data() as any) : {};
          const seenPrompts: string[] = Array.isArray(sealedData.seenPrompts) ? sealedData.seenPrompts : [];

          const newPrompt = PromptDecks.drawOneExcluding(deckId, new Set(seenPrompts));
          const updatedSeen = [...seenPrompts, newPrompt];
          const sealedRef = roomRef.collection("sealed").doc(p.id);
          transaction.set(sealedRef, { seenPrompts: updatedSeen, truthAnswer: "", sabotageAnswers: {} }, { merge: true });

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
        transaction.update(roomRef, {
          currentPhase: "gameOver",
          unmaskDeadline: null
        });
      }
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

    const voterId = guesserId;
    const votedForId = currentCard.votes?.[voterId];
    if (!votedForId) {
      throw new HttpsError("failed-precondition", "Player did not cast a vote for this card.");
    }

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

    const newCards = [...room.cards];
    newCards[currentCardIdx] = {
      ...currentCard,
      unmaskGuesses
    };

    transaction.update(roomRef, { cards: newCards });

    const isCorrect = guessedAuthorId === votedForId;
    if (isCorrect) {
      const guesserRef = roomRef.collection("players").doc(voterId);
      const forgerRef = roomRef.collection("players").doc(votedForId);

      transaction.update(guesserRef, {
        totalScore: FieldValue.increment(1)
      });
      transaction.update(forgerRef, {
        totalScore: FieldValue.increment(-1)
      });
    }

    return { success: true };
  });
});

// 13. Debug Add Bots
export const debugAddBots = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
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
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
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

      const cardIdx = cards.findIndex(c => c.targetPlayerId === currentTargetId);
      if (cardIdx !== -1) {
        const card = { ...cards[cardIdx] };
        const votes = card.votes ? { ...card.votes } : {};

        for (const p of players) {
          if (!p.id.startsWith("bot_")) continue;

          readyPlayers[p.id] = true;
          if (currentTargetId !== p.id) {
            votes[p.id] = currentTargetId;
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
