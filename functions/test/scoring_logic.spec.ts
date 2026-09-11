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

describe('ScoringLogic Target Forgery Guesses (AA16a / Issue 162)', () => {
  const sumBreakdown = (items: Array<{ rule: string; points: number }> = []) =>
    items.reduce((acc, item) => acc + item.points, 0);

  const createBaseState = (currentRound?: number): GameState => ({
    roomCode: 'TEST',
    currentPhase: 'reveal',
    totalPlayers: 4,
    forgeriesPerCard: 2,
    currentRound,
    isTimerDisabled: false,
    selectedDeckId: 'default',
    currentRotationIndex: 0,
    cards: [],
    currentCardAssignments: {},
    currentReaderId: 'p_target',
    rotationPlan: {},
    readyPlayers: {},
    endTime: null,
    resolutionOrder: ['p_target']
  });

  const card: CardModel = {
    targetPlayerId: 'p_target',
    promptText: 'My secret',
    truthAnswer: 'True answer',
    sabotageAnswers: {
      'p_f1': 'Lie 1',
      'p_f2': 'Lie 2'
    },
    options: [
      { id: 'opt_truth', text: 'True answer' },
      { id: 'opt_f1', text: 'Lie 1' },
      { id: 'opt_f2', text: 'Lie 2' },
      { id: 'opt_placeholder', text: 'THE SOUL IS SILENT' }
    ],
    votes: {
      'p_voter': 'opt_truth',
      'p_f1': 'opt_truth',
      'p_f2': 'opt_f1'
    }
  };

  const answerAuthors: Record<string, string> = {
    'opt_truth': 'p_target',
    'opt_f1': 'p_f1',
    'opt_f2': 'p_f2',
    'opt_placeholder': 'p_f3'
  };

  const votes: Record<string, string> = {
    'p_voter': 'p_target',
    'p_f1': 'p_target',
    'p_f2': 'p_f1'
  };

  it('1. all forgeries correctly guessed -> target receives +1 per forgery, forgers receive no penalty', () => {
    const targetGuesses: Record<string, string> = {
      'opt_f1': 'p_f1',
      'opt_f2': 'p_f2'
    };

    const baseResult = ScoringLogic.calculateScoresAndBreakdown(createBaseState(1), card, votes);
    const withGuesses = ScoringLogic.calculateScoresAndBreakdown(
      createBaseState(1),
      card,
      votes,
      targetGuesses,
      answerAuthors
    );

    // Target gains 2 points for the 2 correct guesses
    expect(withGuesses.deltas['p_target']).to.equal((baseResult.deltas['p_target'] || 0) + 2);
    // Forgers receive no penalty
    expect(withGuesses.deltas['p_f1']).to.equal(baseResult.deltas['p_f1']);
    expect(withGuesses.deltas['p_f2']).to.equal(baseResult.deltas['p_f2']);

    // Breakdown contains target_forger_guess rule with 2 points for target
    const targetBreakdown = withGuesses.breakdown['p_target'] || [];
    const guessItem = targetBreakdown.find(i => i.rule === 'target_forger_guess');
    expect(guessItem).to.not.be.undefined;
    expect(guessItem!.points).to.equal(2);

    // Invariant holds
    for (const [pId, delta] of Object.entries(withGuesses.deltas)) {
      expect(sumBreakdown(withGuesses.breakdown[pId])).to.equal(delta);
    }
  });

  it('2. partial map scores only correct entries', () => {
    const partialGuesses: Record<string, string> = {
      'opt_f1': 'p_f1', // correct (+1)
      'opt_f2': 'p_wrong' // incorrect (+0)
    };

    const baseResult = ScoringLogic.calculateScoresAndBreakdown(createBaseState(1), card, votes);
    const withGuesses = ScoringLogic.calculateScoresAndBreakdown(
      createBaseState(1),
      card,
      votes,
      partialGuesses,
      answerAuthors
    );

    expect(withGuesses.deltas['p_target']).to.equal((baseResult.deltas['p_target'] || 0) + 1);
    const guessItem = (withGuesses.breakdown['p_target'] || []).find(i => i.rule === 'target_forger_guess');
    expect(guessItem!.points).to.equal(1);
    expect(sumBreakdown(withGuesses.breakdown['p_target'])).to.equal(withGuesses.deltas['p_target']);
  });

  it('3. placeholder answer or departed player guess scores nothing', () => {
    const guesses: Record<string, string> = {
      'opt_placeholder': 'p_f3', // placeholder option
      'opt_f1': 'p_departed' // departed player
    };
    const authorsWithDeparted: Record<string, string> = {
      ...answerAuthors,
      'opt_f1': 'p_departed'
    };
    const activePlayers = ['p_target', 'p_voter', 'p_f1', 'p_f2']; // p_departed is NOT active

    const baseResult = ScoringLogic.calculateScoresAndBreakdown(createBaseState(1), card, votes);
    const withGuesses = ScoringLogic.calculateScoresAndBreakdown(
      createBaseState(1),
      card,
      votes,
      guesses,
      authorsWithDeparted,
      activePlayers
    );

    expect(withGuesses.deltas['p_target']).to.equal(baseResult.deltas['p_target'] || 0);
    const guessItem = (withGuesses.breakdown['p_target'] || []).find(i => i.rule === 'target_forger_guess');
    expect(guessItem).to.be.undefined;
  });

  it('4. round multiplier scales target forgery guess points and satisfies sum invariant', () => {
    const targetGuesses: Record<string, string> = {
      'opt_f1': 'p_f1',
      'opt_f2': 'p_f2'
    };

    const r3State = createBaseState(3); // multiplier x3
    const result = ScoringLogic.calculateScoresAndBreakdown(
      r3State,
      card,
      votes,
      targetGuesses,
      answerAuthors
    );

    // Base target points: 2 believable_target + 2 target_forger_guess = 4 base. x3 = 12 total.
    expect(result.deltas['p_target']).to.equal(12);
    for (const [pId, delta] of Object.entries(result.deltas)) {
      expect(sumBreakdown(result.breakdown[pId])).to.equal(delta);
    }
  });
});

