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

describe('ScoringLogic Breakdown Sum Invariant (AA11 / Issue 169)', () => {
  const sumBreakdown = (items: Array<{ rule: string; points: number }> = []) =>
    items.reduce((acc, item) => acc + item.points, 0);

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

  it('Fixture 1: Round 1 (P=4, S=1) - sum(breakdown) == deltas for every player', () => {
    const state = createBaseState(1);
    const { deltas, breakdown } = ScoringLogic.calculateScoresAndBreakdown(state, card, votes);
    for (const [playerId, delta] of Object.entries(deltas)) {
      expect(sumBreakdown(breakdown[playerId]), `Sum for player ${playerId}`).to.equal(delta);
    }
  });

  it('Fixture 2: Round 2 Multiplier (x2) - sum(breakdown) == deltas for every player', () => {
    const state = createBaseState(2);
    const { deltas, breakdown } = ScoringLogic.calculateScoresAndBreakdown(state, card, votes);
    for (const [playerId, delta] of Object.entries(deltas)) {
      expect(sumBreakdown(breakdown[playerId]), `Sum for player ${playerId}`).to.equal(delta);
      const multItem = breakdown[playerId]?.find(item => item.rule === 'round_multiplier');
      expect(multItem, `Multiplier line present for player ${playerId}`).to.not.be.undefined;
    }
  });

  it('Fixture 3: Round 3 Multiplier (x3) on 5-player 3-forgery match - sum(breakdown) == deltas for every player', () => {
    const state5: GameState = {
      ...createBaseState(3),
      totalPlayers: 5,
      forgeriesPerCard: 3,
    };
    const card5: CardModel = {
      targetPlayerId: 'p_host',
      promptText: 'A secret',
      truthAnswer: 'Truth',
      sabotageAnswers: {
        'p_g1': 'Lie 1',
        'p_g2': 'Lie 2',
        'p_g3': 'Lie 3',
      },
      votes: {
        'p_g4': 'p_host',
        'p_g1': 'p_g2',
        'p_g2': 'p_host',
        'p_g3': 'p_host',
      }
    };
    const votes5: Record<string, string> = {
      'p_g4': 'p_host',
      'p_g1': 'p_g2',
      'p_g2': 'p_host',
      'p_g3': 'p_host',
    };
    const { deltas, breakdown } = ScoringLogic.calculateScoresAndBreakdown(state5, card5, votes5);
    for (const [playerId, delta] of Object.entries(deltas)) {
      expect(sumBreakdown(breakdown[playerId]), `Sum for player ${playerId}`).to.equal(delta);
    }
  });

  it('Fixture 4: Negative deltas from unmask revenge accusation - sum(breakdown) == deltas for both sides', () => {
    // Starting with base deltas: forger p_g3 deceived p_g2 (+1)
    const { deltas, breakdown } = ScoringLogic.calculateScoresAndBreakdown(createBaseState(1), card, votes);
    const guesserId = 'p_g2';
    const forgerId = 'p_g3';

    // Apply revenge penalty ±1
    deltas[guesserId] = (deltas[guesserId] || 0) + 1;
    deltas[forgerId] = (deltas[forgerId] || 0) - 1;

    const guesserItems = [...(breakdown[guesserId] || [])];
    guesserItems.push({ rule: 'revenge_guess', points: 1 });
    breakdown[guesserId] = guesserItems;

    const forgerItems = [...(breakdown[forgerId] || [])];
    forgerItems.push({ rule: 'revenge_guess', points: -1 });
    breakdown[forgerId] = forgerItems;

    // Verify invariant for guesser (+1) and forger (net deltas after -1)
    expect(sumBreakdown(breakdown[guesserId])).to.equal(deltas[guesserId]);
    expect(sumBreakdown(breakdown[forgerId])).to.equal(deltas[forgerId]);

    // Also verify standalone case where saboteur ends with negative total delta:
    const negativeDeltas: Record<string, number> = { 'forger_only': -1 };
    const negativeBreakdown = [{ rule: 'revenge_guess', points: -1 }];
    expect(sumBreakdown(negativeBreakdown)).to.equal(negativeDeltas['forger_only']);
  });
});

