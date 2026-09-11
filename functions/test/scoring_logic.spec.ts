import { expect } from 'chai';
import { ScoringLogic, GameState, CardModel } from '../src/scoring_logic';

describe('ScoringLogic Round Multiplier (AA10 / Issue 163)', () => {
  const createBaseState = (currentRound?: number): GameState => ({
    roomCode: 'TEST',
    currentPhase: 'reveal',
    totalPlayers: 4,
    forgeriesPerCard: 1,
    currentRound,
    isTimerDisabled: false,
    selectedDeckId: 'default',
    currentRotationIndex: 0,
    cards: [],
    currentCardAssignments: {},
    currentReaderId: 'p_host',
    rotationPlan: {},
    readyPlayers: {},
    endTime: null,
    resolutionOrder: ['p_host']
  });

  const card: CardModel = {
    targetPlayerId: 'p_host',
    promptText: 'What is my secret?',
    truthAnswer: 'I love cats',
    sabotageAnswers: {
      'p_g3': 'I love dogs'
    },
    votes: {
      'p_g1': 'p_host',
      'p_g2': 'p_g3',
      'p_g3': 'p_host'
    }
  };

  const votes: Record<string, string> = {
    'p_g1': 'p_host',
    'p_g2': 'p_g3',
    'p_g3': 'p_host'
  };

  it('1. identical votes at currentRound 1, 2 and 3 produce x1, x2 and x3 the deltas', () => {
    const deltasR1 = ScoringLogic.calculateScores(createBaseState(1), card, votes);
    expect(deltasR1['p_g1']).to.equal(2);
    expect(deltasR1['p_g3']).to.equal(4);
    expect(deltasR1['p_host']).to.equal(2);

    const deltasR2 = ScoringLogic.calculateScores(createBaseState(2), card, votes);
    expect(deltasR2['p_g1']).to.equal(4); // 2 * 2
    expect(deltasR2['p_g3']).to.equal(8); // 4 * 2
    expect(deltasR2['p_host']).to.equal(4); // 2 * 2

    const deltasR3 = ScoringLogic.calculateScores(createBaseState(3), card, votes);
    expect(deltasR3['p_g1']).to.equal(6); // 2 * 3
    expect(deltasR3['p_g3']).to.equal(12); // 4 * 3
    expect(deltasR3['p_host']).to.equal(6); // 2 * 3
  });

  it('2. currentRound absent -> behaves as round 1', () => {
    const deltasAbsent = ScoringLogic.calculateScores(createBaseState(undefined), card, votes);
    expect(deltasAbsent['p_g1']).to.equal(2);
    expect(deltasAbsent['p_g3']).to.equal(4);
    expect(deltasAbsent['p_host']).to.equal(2);
  });
});
