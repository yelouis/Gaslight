export interface ScoreBreakdownItem {
  rule: string;
  points: number;
}

export interface CardModel {
  targetPlayerId: string;
  promptText: string;
  truthAnswer: string;
  sabotageAnswers: Record<string, string>;
  options?: Array<{ id: string; text: string }>;
  votes: Record<string, string>;
  unmaskGuesses?: Record<string, string>;
  scoreDeltas?: Record<string, number>;
  scoreBreakdown?: Record<string, ScoreBreakdownItem[]>;
  targetForgeryGuesses?: Record<string, string>;
  answerAuthors?: Record<string, string>;
}

export const kTargetForgeryGuessPoints = 1;
export const kMissingAnswerPlaceholder = "THE SOUL IS SILENT";

export interface GameState {
  roomCode: string;
  currentPhase: string;
  totalPlayers: number;
  forgeriesPerCard: number;
  sabotageAnswersCount?: number;
  totalRounds?: number;
  currentRound?: number;
  isTimerDisabled: boolean;
  timerSeconds?: number;
  selectedDeckId: string;
  effectiveDeckId?: string;
  currentRotationIndex: number;
  cards: CardModel[];
  currentCardAssignments: Record<string, string>;
  currentReaderId: string | null;
  rotationPlan: Record<string, Record<string, string>>;
  readyPlayers: Record<string, boolean>;
  endTime: number | null;
  resolutionOrder: string[];
  debugEnabled?: boolean;
  expiresAt?: any;
  unmaskDeadline?: number | null;
  matchSummary?: MatchSummary;
  runningRivalries?: {
    fools: Array<{ deceiverId: string; deceiverName: string; victimId: string; victimName: string; count: number }>;
    reads: Array<{ readerId: string; readerName: string; forgerId: string; forgerName: string; count: number }>;
  };
}

export interface CardSummary {
  round: number;
  targetPlayerId: string;
  targetPlayerName?: string;
  promptText: string;
  truthAnswer: string;
  forgeries: Array<{
    authorId: string;
    authorName?: string;
    text: string;
    fooled: number;
    fooledVoters?: string[];
  }>;
  truthFinders: string[];
  /** Forger ids this card's target correctly attributed. Issue 165. */
  targetCorrectAttributions?: string[];
}

export interface MatchSummary {
  bestLie?: {
    authorId: string;
    authorName: string;
    text: string;
    promptText: string;
    fooled: number;
  } | null;
  cleanestTruth?: {
    targetPlayerId: string;
    targetPlayerName: string;
    text: string;
    promptText: string;
    foundCount: number;
  } | null;
  theSting?: {
    targetPlayerId: string;
    promptText: string;
    wrongVoteCount: number;
  } | null;
  headToHead?: Array<{
    deceiverId: string;
    deceiverName: string;
    victimId: string;
    victimName: string;
    count: number;
  }>;
}

export class ScoringLogic {
  /**
   * Dynamically tallies points and computes rule breakdown for the Mimicry Edition.
   * Returns deltas and breakdown per player.
   */
  static calculateScoresAndBreakdown(
    state: GameState,
    currentCard: CardModel,
    playerVotes: Record<string, string>,
    targetForgeryGuesses?: Record<string, string>,
    answerAuthors?: Record<string, string>,
    activePlayerIds?: string[]
  ): { deltas: Record<string, number>; breakdown: Record<string, ScoreBreakdownItem[]> } {
    const deltas: Record<string, number> = {};
    const breakdown: Record<string, ScoreBreakdownItem[]> = {};

    const p = state.totalPlayers;
    const s = Object.keys(currentCard.sabotageAnswers || {}).length;
    const truthReward = Math.ceil((p - 1) / (s + 1));

    const addBreakdown = (playerId: string, rule: string, points: number) => {
      if (points === 0) return;
      if (!breakdown[playerId]) {
        breakdown[playerId] = [];
      }
      const existing = breakdown[playerId].find(item => item.rule === rule);
      if (existing) {
        existing.points += points;
      } else {
        breakdown[playerId].push({ rule, points });
      }
    };

    // Evaluate every single vote
    for (const [voterId, votedForId] of Object.entries(playerVotes)) {
      if (voterId === votedForId) continue; // Self-vote prevention!

      if (votedForId === currentCard.targetPlayerId) {
        // The voter gets points for finding the truth
        deltas[voterId] = (deltas[voterId] || 0) + truthReward;
        addBreakdown(voterId, "truth_found", truthReward);

        // Bonus: +1 point if the Saboteur *also* correctly identifies the Truth
        if (currentCard.sabotageAnswers && Object.prototype.hasOwnProperty.call(currentCard.sabotageAnswers, voterId)) {
          deltas[voterId] = (deltas[voterId] || 0) + 1;
          addBreakdown(voterId, "sharp_eye", 1);
        }

        // The Target gets 1 point because someone correctly guessed their truth
        const targetId = currentCard.targetPlayerId;
        deltas[targetId] = (deltas[targetId] || 0) + 1;
        addBreakdown(targetId, "believable_target", 1);
      } else {
        // A Saboteur tricked someone and gets 1 point
        deltas[votedForId] = (deltas[votedForId] || 0) + 1;
        addBreakdown(votedForId, "successful_forgery", 1);
      }
    }

    const multiplier = Math.max(1, state.currentRound ?? 1);
    if (multiplier > 1) {
      for (const playerId of Object.keys(deltas)) {
        const basePoints = deltas[playerId];
        const multBonus = basePoints * (multiplier - 1);
        deltas[playerId] *= multiplier;
        if (multBonus !== 0) {
          addBreakdown(playerId, "round_multiplier", multBonus);
        }
      }
    }

    // Target forgery author guesses (Issue 162 / AA16a / Issue 170 exempt from multiplier)
    const guesses = targetForgeryGuesses || currentCard.targetForgeryGuesses;
    const authors = answerAuthors || currentCard.answerAuthors;
    if (guesses && authors) {
      const targetId = currentCard.targetPlayerId;
      for (const [optionId, guessedAuthorId] of Object.entries(guesses)) {
        if (!guessedAuthorId) continue;
        // The target cannot guess themselves
        if (guessedAuthorId === targetId) continue;
        // Skip placeholder options
        const opt = currentCard.options?.find(o => o.id === optionId);
        if (opt && (opt.text === kMissingAnswerPlaceholder || opt.text.trim() === "")) {
          continue;
        }
        // If an active player roster is supplied, skip players who have departed
        if (activePlayerIds && !activePlayerIds.includes(guessedAuthorId)) {
          continue;
        }
        // Check if guess matches actual author
        if (authors[optionId] === guessedAuthorId) {
          deltas[targetId] = (deltas[targetId] || 0) + kTargetForgeryGuessPoints;
          addBreakdown(targetId, "target_forger_guess", kTargetForgeryGuessPoints);
        }
      }
    }

    return { deltas, breakdown };
  }

  /**
   * Dynamically tallies points for the Mimicry Edition.
   * Returns a map of playerId -> point delta.
   */
  static calculateScores(
    state: GameState,
    currentCard: CardModel,
    playerVotes: Record<string, string>,
    targetForgeryGuesses?: Record<string, string>,
    answerAuthors?: Record<string, string>,
    activePlayerIds?: string[]
  ): Record<string, number> {
    return this.calculateScoresAndBreakdown(
      state,
      currentCard,
      playerVotes,
      targetForgeryGuesses,
      answerAuthors,
      activePlayerIds
    ).deltas;
  }

  /**
   * Returns a map of playerId -> array of ScoreBreakdownItem.
   */
  static calculateBreakdown(
    state: GameState,
    currentCard: CardModel,
    playerVotes: Record<string, string>,
    targetForgeryGuesses?: Record<string, string>,
    answerAuthors?: Record<string, string>,
    activePlayerIds?: string[]
  ): Record<string, ScoreBreakdownItem[]> {
    return this.calculateScoresAndBreakdown(
      state,
      currentCard,
      playerVotes,
      targetForgeryGuesses,
      answerAuthors,
      activePlayerIds
    ).breakdown;
  }
}

