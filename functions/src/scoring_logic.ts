export interface CardModel {
  targetPlayerId: string;
  promptText: string;
  truthAnswer: string;
  sabotageAnswers: Record<string, string>;
  votes: Record<string, string>;
  unmaskGuesses?: Record<string, string>;
}

export interface GameState {
  roomCode: string;
  currentPhase: string;
  totalPlayers: number;
  sabotageAnswersCount: number;
  isTimerDisabled: boolean;
  selectedDeckId: string;
  currentRotationIndex: number;
  cards: CardModel[];
  currentCardAssignments: Record<string, string>;
  currentReaderId: string | null;
  rotationPlan: Record<string, Record<string, string>>;
  readyPlayers: Record<string, boolean>;
  endTime: number | null;
  resolutionOrder: string[];
  debugEnabled?: boolean;
  unmaskDeadline?: number | null;
}

export class ScoringLogic {
  /**
   * Dynamically tallies points for the Mimicry Edition.
   * Returns a map of playerId -> point delta.
   */
  static calculateScores(
    state: GameState,
    currentCard: CardModel,
    playerVotes: Record<string, string>
  ): Record<string, number> {
    const deltas: Record<string, number> = {};

    const p = state.totalPlayers;
    const s = Object.keys(currentCard.sabotageAnswers || {}).length;
    const truthReward = Math.ceil((p - 1) / (s + 1));

    // Evaluate every single vote
    for (const [voterId, votedForId] of Object.entries(playerVotes)) {
      if (voterId === votedForId) continue; // Self-vote prevention!

      if (votedForId === 'TRUTH') {
        // The voter gets points for finding the truth
        deltas[voterId] = (deltas[voterId] || 0) + truthReward;

        // Bonus: +1 point if the Saboteur *also* correctly identifies the Truth
        if (currentCard.sabotageAnswers && Object.prototype.hasOwnProperty.call(currentCard.sabotageAnswers, voterId)) {
          deltas[voterId] = (deltas[voterId] || 0) + 1;
        }

        // The Target gets 1 point because someone correctly guessed their truth
        const targetId = currentCard.targetPlayerId;
        deltas[targetId] = (deltas[targetId] || 0) + 1;
      } else {
        // A Saboteur tricked someone and gets 1 point
        deltas[votedForId] = (deltas[votedForId] || 0) + 1;
      }
    }

    return deltas;
  }
}
