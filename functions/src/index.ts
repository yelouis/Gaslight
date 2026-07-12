import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import crypto from "crypto";
import { RotationEngine } from "./rotation_engine";
import { ScoringLogic, GameState, CardModel } from "./scoring_logic";
import { PromptDecks } from "./prompt_decks";

admin.initializeApp();
const db = admin.firestore();

const kMissingAnswerPlaceholder = "THE SOUL IS SILENT";

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
  hasRerolled: boolean;
  authUid: string;
}

function generateRoomCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  let result = "";
  for (let i = 0; i < 4; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function getAnswerHash(text: string): string {
  const normalized = text.toLowerCase().trim().replace(/\s+/g, " ");
  return crypto.createHash("md5").update(normalized).digest("hex");
}

async function getEmbedding(roomCode: string, text: string, geminiApiKey: string): Promise<number[]> {
  const hash = getAnswerHash(text);
  const cacheRef = db.collection("rooms").doc(roomCode).collection("embeddings").doc(hash);
  const cachedDoc = await cacheRef.get();

  if (cachedDoc.exists) {
    const data = cachedDoc.data();
    if (data && data.vector) {
      return data.vector;
    }
  }

  const url = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent";
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": geminiApiKey,
    },
    body: JSON.stringify({
      model: "models/text-embedding-004",
      content: {
        parts: [{ text: text }]
      }
    })
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini API returned ${response.status}: ${errText}`);
  }

  const resJson = await response.json();
  const vector = resJson.embedding.values as number[];

  await cacheRef.set({ text, vector });
  return vector;
}

function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) return 0.0;
  let dotProduct = 0.0;
  let normA = 0.0;
  let normB = 0.0;
  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) return 0.0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
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
  const sabotageAnswersCount = (data.sabotageAnswersCount as number) || 2;
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
    throw new HttpsError("internal", "Could not generate unique room code.");
  }

  const roomRef = db.collection("rooms").doc(roomCode);
  const playerRef = roomRef.collection("players").doc(playerId);

  const gameState = {
    roomCode,
    currentPhase: "lobby",
    totalPlayers: 1,
    sabotageAnswersCount,
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
    debugEnabled
  };

  const playerState = {
    id: playerId,
    name: playerName,
    totalScore: 0,
    role: "unassigned",
    isHost: true,
    colorValue,
    avatarIndex,
    lastSeen: Date.now(),
    timesFooled: 0,
    playersDeceived: 0,
    joinedAt: Date.now(),
    lobbyReady: false,
    lastReaction: null,
    lastReactionAt: null,
    hasRerolled: false,
    authUid: callerUid
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
      const existing = playerSnap.data() as PlayerState;
      transaction.update(playerRef, {
        authUid: callerUid,
        name: playerName,
        colorValue,
        avatarIndex,
        lastSeen: Date.now()
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

    const playerState = {
      id: playerId,
      name: playerName,
      totalScore: 0,
      role,
      isHost: false,
      colorValue,
      avatarIndex,
      lastSeen: Date.now(),
      timesFooled: 0,
      playersDeceived: 0,
      joinedAt: Date.now(),
      lobbyReady: false,
      lastReaction: null,
      lastReactionAt: null,
      hasRerolled: false,
      authUid: callerUid
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
    if (activePlayers.length < 2) {
      throw new HttpsError("failed-precondition", "Cannot start: Need at least 2 active players.");
    }

    if (activePlayers.length <= room.sabotageAnswersCount) {
      throw new HttpsError("failed-precondition", "Cannot start: Need more players than forgery rounds.");
    }

    const deckSize = PromptDecks.getDeckSize(selectedDeckId);
    if (deckSize < activePlayers.length) {
      throw new HttpsError("failed-precondition", `Cannot start: Selected deck has ${deckSize} prompts, but you need at least ${activePlayers.length} prompts.`);
    }

    const pIds = activePlayers.map(p => p.id);
    const nativeRotations = RotationEngine.generateRotations(pIds, room.sabotageAnswersCount);
    const stringRotations: Record<string, Record<string, string>> = {};
    for (const [key, val] of Object.entries(nativeRotations)) {
      stringRotations[key] = val;
    }

    const prompts = PromptDecks.drawPrompts(selectedDeckId, activePlayers.length);
    const startingCards: CardModel[] = pIds.map((pid, idx) => ({
      targetPlayerId: pid,
      promptText: prompts[idx],
      truthAnswer: "",
      sabotageAnswers: {},
      votes: {}
    }));

    const startIdx = 1;
    const initAssignments = stringRotations[startIdx.toString()];

    const endTime = room.isTimerDisabled ? null : Date.now() + 60000;

    transaction.update(roomRef, {
      currentPhase: "forgery",
      totalPlayers: players.length,
      selectedDeckId,
      currentRotationIndex: startIdx,
      cards: startingCards,
      currentCardAssignments: initAssignments,
      rotationPlan: stringRotations,
      readyPlayers: {},
      endTime,
      resolutionOrder: []
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

  // 1. Semantic similarity check (failing open on API errors)
  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (geminiApiKey) {
    try {
      const roomSnap = await roomRef.get();
      if (roomSnap.exists) {
        const room = roomSnap.data() as GameState;
        const card = room.cards.find(c => c.targetPlayerId === targetCardId);
        if (card) {
          const existingAnswers: string[] = [];
          if (card.truthAnswer && isTruth === false) {
            existingAnswers.push(card.truthAnswer);
          }
          for (const [sabId, sabotageText] of Object.entries(card.sabotageAnswers || {})) {
            // Exclude current author's overwrite attempt
            if (sabId !== authorId && sabotageText) {
              existingAnswers.push(sabotageText);
            }
          }

          if (existingAnswers.length > 0) {
            const newVector = await getEmbedding(roomCode, text, geminiApiKey);
            for (const ansText of existingAnswers) {
              const compVector = await getEmbedding(roomCode, ansText, geminiApiKey);
              const similarity = cosineSimilarity(newVector, compVector);
              if (similarity > 0.85) {
                throw new HttpsError("invalid-argument", "Answer is too similar to another player's answer!");
              }
            }
          }
        }
      }
    } catch (e) {
      if (e instanceof HttpsError) {
        throw e;
      }
      console.error("Gemini API Error (failing open):", e);
    }
  }

  // 2. Perform write in a transaction to prevent race conditions
  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }
    const playersSnap = await transaction.get(roomRef.collection("players"));

    const room = roomSnap.data() as GameState;
    const cardIdx = room.cards.findIndex(c => c.targetPlayerId === targetCardId);
    if (cardIdx === -1) {
      throw new HttpsError("not-found", "Target card not found.");
    }

    const card = room.cards[cardIdx];
    let updatedCard: CardModel;
    if (isTruth) {
      updatedCard = { ...card, truthAnswer: text };
    } else {
      const sabs = { ...card.sabotageAnswers, [authorId]: text };
      updatedCard = { ...card, sabotageAnswers: sabs };
    }

    const newCards = [...room.cards];
    newCards[cardIdx] = updatedCard;

    const newReadyMap: Record<string, boolean> = { ...room.readyPlayers, [authorId]: true };

    const activePlayers = playersSnap.docs.map(doc => doc.data() as PlayerState).filter(p => p.role !== "spectator");
    const allReady = activePlayers.every(p => newReadyMap[p.id] === true);

    transaction.update(roomRef, {
      cards: newCards,
      readyPlayers: newReadyMap
    });

    if (allReady && activePlayers.length > 0) {
      await advancePhaseInternal(transaction, roomRef, room, activePlayers, newCards);
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

  if (voterId === votedForId) {
    throw new HttpsError("invalid-argument", "Self-voting is not allowed.");
  }

  return await db.runTransaction(async (transaction) => {
    const roomSnap = await transaction.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Game room not found.");
    }
    const playersSnap = await transaction.get(roomRef.collection("players"));

    const room = roomSnap.data() as GameState;
    const cardIdx = room.cards.findIndex(c => c.targetPlayerId === targetCardId);
    if (cardIdx === -1) {
      throw new HttpsError("not-found", "Target card not found.");
    }

    const card = room.cards[cardIdx];
    const newVotes = { ...card.votes, [voterId]: votedForId };
    const updatedCard = { ...card, votes: newVotes };
    const newCards = [...room.cards];
    newCards[cardIdx] = updatedCard;

    const newReadyMap: Record<string, boolean> = { ...room.readyPlayers, [voterId]: true };

    const activePlayers = playersSnap.docs.map(doc => doc.data() as PlayerState).filter(p => p.role !== "spectator");
    const allReady = activePlayers.every(p => newReadyMap[p.id] === true);

    transaction.update(roomRef, {
      cards: newCards,
      readyPlayers: newReadyMap
    });

    if (allReady && activePlayers.length > 0) {
      await advancePhaseInternal(transaction, roomRef, room, activePlayers, newCards);
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

    transaction.update(roomRef, { readyPlayers: newReadyMap });

    if (allReady && activePlayers.length > 0) {
      await advancePhaseInternal(transaction, roomRef, room, activePlayers, room.cards);
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
    const playerSnap = await transaction.get(playerRef);

    if (!playerSnap.exists || (playerSnap.data() as PlayerState).authUid !== callerUid) {
      throw new HttpsError("permission-denied", "User does not own this player document.");
    }

    const player = playerSnap.data() as PlayerState;
    if (player.hasRerolled) {
      throw new HttpsError("failed-precondition", "Prompt already re-rolled once this game.");
    }

    // Find the player's card
    const cardIdx = room.cards.findIndex(c => c.targetPlayerId === playerId);
    if (cardIdx === -1) {
      throw new HttpsError("not-found", "Card not found for player.");
    }

    const excluded = new Set(room.cards.map(c => c.promptText));
    const newPrompt = PromptDecks.drawOneExcluding(room.selectedDeckId, excluded);

    const updatedCard = { ...room.cards[cardIdx], promptText: newPrompt };
    const newCards = [...room.cards];
    newCards[cardIdx] = updatedCard;

    transaction.update(roomRef, { cards: newCards });
    transaction.update(playerRef, { hasRerolled: true });

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
    const isDead = disconnectedPlayer && disconnectedPlayer.lastSeen && (Date.now() - disconnectedPlayer.lastSeen) > 30000;

    if (!callerPlayer || (!callerPlayer.isHost && callerPlayer.id !== disconnectedPlayerId && !isDead)) {
      throw new HttpsError("permission-denied", "Not authorized to trigger disconnect.");
    }

    const hasCard = room.cards.some(c => c.targetPlayerId === disconnectedPlayerId);
    if (!hasCard) {
      // Already pruned
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

    const phase = room.currentPhase;

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
      let remainingRotations = room.sabotageAnswersCount;
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

// Inner helper to execute phase advancement inside a transaction block.
// INVARIANT: must never call transaction.get — callers complete all reads first.
async function advancePhaseInternal(
  transaction: admin.firestore.Transaction,
  roomRef: admin.firestore.DocumentReference,
  room: GameState,
  activePlayers: PlayerState[],
  currentCards: CardModel[]
): Promise<void> {
  const forgeryDuration = 60000;
  const truthDuration = 60000;
  const voteDuration = 45000;

  const nextReadyPlayers: Record<string, boolean> = {};

  if (room.currentPhase === "forgery") {
    // 1. Timeout placeholder fill for missing forgery submissions
    const nextCards = currentCards.map(card => {
      let holderId: string | null = null;
      for (const [hId, tId] of Object.entries(room.currentCardAssignments)) {
        if (tId === card.targetPlayerId) {
          holderId = hId;
          break;
        }
      }

      if (holderId) {
        const answer = card.sabotageAnswers[holderId];
        if (!answer || answer.trim().length === 0) {
          const sabotageAnswers = { ...card.sabotageAnswers, [holderId]: kMissingAnswerPlaceholder };
          return { ...card, sabotageAnswers };
        }
      }
      return card;
    });

    if (room.currentRotationIndex < room.sabotageAnswersCount) {
      const nextRot = room.currentRotationIndex + 1;
      const nextAssignments = room.rotationPlan[nextRot.toString()];
      const endTime = room.isTimerDisabled ? null : Date.now() + forgeryDuration;

      transaction.update(roomRef, {
        cards: nextCards,
        currentRotationIndex: nextRot,
        currentCardAssignments: nextAssignments,
        readyPlayers: nextReadyPlayers,
        endTime
      });
    } else {
      // Move to Truth Phase: Every active player gets their own card back
      const pIds = activePlayers.map(p => p.id);
      const truthAssignments: Record<string, string> = {};
      for (const id of pIds) {
        truthAssignments[id] = id;
      }

      const endTime = room.isTimerDisabled ? null : Date.now() + truthDuration;

      transaction.update(roomRef, {
        currentPhase: "truth",
        cards: nextCards,
        currentCardAssignments: truthAssignments,
        readyPlayers: nextReadyPlayers,
        endTime
      });
    }
  } else if (room.currentPhase === "truth") {
    // 1. Timeout placeholder fill for truth
    const nextCards = currentCards.map(card => {
      if (!card.truthAnswer || card.truthAnswer.trim().length === 0) {
        return { ...card, truthAnswer: kMissingAnswerPlaceholder };
      }
      return card;
    });

    // 2. Shuffle order for voting resolution
    const pIds = activePlayers.map(p => p.id);
    for (let i = pIds.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [pIds[i], pIds[j]] = [pIds[j], pIds[i]];
    }

    const endTime = room.isTimerDisabled ? null : Date.now() + voteDuration;

    transaction.update(roomRef, {
      currentPhase: "vote",
      cards: nextCards,
      currentReaderId: pIds.length > 0 ? pIds[0] : null,
      resolutionOrder: pIds,
      readyPlayers: nextReadyPlayers,
      endTime
    });
  } else if (room.currentPhase === "vote") {
    // Tally scores and advance to Reveal
    const currentCard = currentCards.find(c => c.targetPlayerId === room.currentReaderId);
    if (currentCard) {
      const deltas = ScoringLogic.calculateScores(room, currentCard, currentCard.votes);

      const timesFooledDeltas: Record<string, number> = {};
      const playersDeceivedDeltas: Record<string, number> = {};

      for (const [voterId, votedForId] of Object.entries(currentCard.votes)) {
        if (votedForId !== "TRUTH" && votedForId !== voterId) {
          timesFooledDeltas[voterId] = (timesFooledDeltas[voterId] || 0) + 1;
          playersDeceivedDeltas[votedForId] = (playersDeceivedDeltas[votedForId] || 0) + 1;
        }
      }

      // Apply scores in transaction to players in room
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

    transaction.update(roomRef, {
      currentPhase: "reveal",
      readyPlayers: nextReadyPlayers,
      endTime: null
    });
  }
}

// 10. Update Lobby Settings
export const updateLobbySettings = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const callerUid = request.auth.uid;
  const { roomCode, sabotageAnswersCount, isTimerDisabled } = request.data;
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

    const data = roomSnap.data() as GameState;
    transaction.update(roomRef, {
      sabotageAnswersCount: sabotageAnswersCount !== undefined ? sabotageAnswersCount : data.sabotageAnswersCount,
      isTimerDisabled: isTimerDisabled !== undefined ? isTimerDisabled : data.isTimerDisabled
    });

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
        endTime: endTime
      });
    } else {
      transaction.update(roomRef, {
        currentPhase: "gameOver"
      });
    }

    return { success: true };
  });
});

// 12. Debug Add Bots
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
      lobbyReady: false,
      totalScore: 0,
      role: "unassigned",
      isReady: false,
      timesFooled: 0,
      playersDeceived: 0,
      lastSeen: Date.now(),
      lastReaction: null,
      lastReactionAt: null,
      hasRerolled: false,
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
      for (const p of players) {
        if (!p.id.startsWith("bot_")) continue;

        readyPlayers[p.id] = true;

        const targetId = room.currentCardAssignments?.[p.id];
        if (targetId) {
          const cardIdx = cards.findIndex(c => c.targetPlayerId === targetId);
          if (cardIdx !== -1) {
            const card = { ...cards[cardIdx] };
            if (phase === "truth") {
              card.truthAnswer = `Simulated Answer from ${p.name}`;
            } else {
              const sabotageAnswers = card.sabotageAnswers ? { ...card.sabotageAnswers } : {};
              sabotageAnswers[p.id] = `Simulated Answer from ${p.name}`;
              card.sabotageAnswers = sabotageAnswers;
            }
            cards[cardIdx] = card;
          }
        }

        // Also update player document in transaction to make it ready
        const pRef = roomRef.collection("players").doc(p.id);
        transaction.update(pRef, { isReady: true });
      }

      transaction.update(roomRef, {
        cards,
        readyPlayers
      });
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
            votes[p.id] = "TRUTH";
          }
        }
        card.votes = votes;
        cards[cardIdx] = card;
      }

      // If the current reader is a bot, mark them ready as well
      if (currentTargetId.startsWith("bot_")) {
        readyPlayers[currentTargetId] = true;
        const readerRef = roomRef.collection("players").doc(currentTargetId);
        transaction.update(readerRef, { isReady: true });
      }

      transaction.update(roomRef, {
        cards,
        readyPlayers
      });
    }

    return { success: true };
  });
});
