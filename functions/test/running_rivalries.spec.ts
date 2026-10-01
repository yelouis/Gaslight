import { expect } from 'chai';
import {
  computeRunningRivalries,
  countFoolsPairs,
  countReadsPairs
} from '../src/index';
import { CardSummary } from '../src/scoring_logic';

describe('Wave AG: AG3 Server Running Rivalries (Issue 177)', () => {
  const playerNames: Record<string, string> = {
    p1: 'Alice',
    p2: 'Bob',
    p3: 'Charlie',
    p4: 'Diana',
    p5: 'Edward',
    p6: 'Fiona',
    p7: 'George'
  };

  function createSampleCard(round: number, targetId: string, overrides: Partial<CardSummary> = {}): CardSummary {
    return {
      round,
      targetPlayerId: targetId,
      targetPlayerName: playerNames[targetId],
      promptText: `Prompt for ${targetId} round ${round}`,
      truthAnswer: `Truth of ${targetId}`,
      truthFinders: [],
      forgeries: [
        {
          authorId: 'p2',
          authorName: 'Bob',
          text: `Bob lie for ${targetId}`,
          fooled: 1,
          fooledVoters: ['p3']
        },
        {
          authorId: 'p4',
          authorName: 'Diana',
          text: `Diana lie for ${targetId}`,
          fooled: 1,
          fooledVoters: ['p5']
        }
      ],
      targetCorrectAttributions: ['p2'],
      ...overrides
    };
  }

  it('1. over a multi-round fixture, occurrences.length === count for every pair in both directions', () => {
    const cards: CardSummary[] = [
      createSampleCard(1, 'p1'),
      createSampleCard(1, 'p2', {
        targetCorrectAttributions: ['p4'],
        forgeries: [
          { authorId: 'p1', authorName: 'Alice', text: 'Alice lie', fooled: 2, fooledVoters: ['p3', 'p5'] },
          { authorId: 'p4', authorName: 'Diana', text: 'Diana lie', fooled: 0, fooledVoters: [] }
        ]
      }),
      createSampleCard(2, 'p1', {
        forgeries: [
          { authorId: 'p2', authorName: 'Bob', text: 'Bob lie round 2', fooled: 2, fooledVoters: ['p3', 'p4'] }
        ]
      }),
      createSampleCard(2, 'p3', {
        targetCorrectAttributions: ['p2', 'p4'],
        forgeries: [
          { authorId: 'p2', authorName: 'Bob', text: 'Bob lie round 2 card 2', fooled: 1, fooledVoters: ['p1'] }
        ]
      })
    ];

    const fools = countFoolsPairs(cards, playerNames, 1);
    const reads = countReadsPairs(cards, playerNames, 1);

    expect(fools.length).to.be.greaterThan(0);
    expect(reads.length).to.be.greaterThan(0);

    for (const f of fools) {
      expect(f.occurrences).to.be.an('array');
      expect(f.occurrences.length).to.equal(f.count, `Fools pair ${f.deceiverId}->${f.victimId} count mismatch`);
    }

    for (const r of reads) {
      expect(r.occurrences).to.be.an('array');
      expect(r.occurrences.length).to.equal(r.count, `Reads pair ${r.readerId}->${r.forgerId} count mismatch`);
    }
  });

  it('2. a fools occurrence carries its card prompt and deceivers lie; a reads occurrence carries readers own prompt and forgers lie', () => {
    const card = createSampleCard(1, 'p1', {
      promptText: 'Whose secret is this?',
      forgeries: [
        { authorId: 'p2', authorName: 'Bob', text: 'Bob special lie', fooled: 1, fooledVoters: ['p3'] }
      ],
      targetCorrectAttributions: ['p2']
    });

    const result = computeRunningRivalries([card], playerNames, { round: 1, targetPlayerId: 'p1' });

    // Fools occurrence check
    const bobFooledCharlie = result.fools.find(f => f.deceiverId === 'p2' && f.victimId === 'p3');
    expect(bobFooledCharlie).to.not.be.undefined;
    expect(bobFooledCharlie!.occurrences[0].promptText).to.equal('Whose secret is this?');
    expect(bobFooledCharlie!.occurrences[0].lieText).to.equal('Bob special lie');
    expect(bobFooledCharlie!.occurrences[0].cardOwnerId).to.equal('p1');
    expect(bobFooledCharlie!.occurrences[0].cardOwnerName).to.equal('Alice');

    // Reads occurrence check (reader is card target: p1 / Alice)
    const aliceSpottedBob = result.reads.find(r => r.readerId === 'p1' && r.forgerId === 'p2');
    expect(aliceSpottedBob).to.not.be.undefined;
    expect(aliceSpottedBob!.occurrences[0].promptText).to.equal('Whose secret is this?');
    expect(aliceSpottedBob!.occurrences[0].lieText).to.equal('Bob special lie');
    expect(aliceSpottedBob!.occurrences[0].cardOwnerId).to.equal('p1');
    expect(aliceSpottedBob!.occurrences[0].cardOwnerName).to.equal('Alice');
  });

  it('4. completeness: a pair that gains its first occurrence but ranks outside top 3 is absent from fools and present in thisCard.fools', () => {
    // 3 pairs with high counts (e.g. 5, 4, 3)
    const pastCards: CardSummary[] = [
      createSampleCard(1, 'p1', {
        forgeries: [
          { authorId: 'p2', authorName: 'Bob', text: 'L1', fooled: 5, fooledVoters: ['p3', 'p4', 'p5', 'p6', 'p7'] },
          { authorId: 'p3', authorName: 'Charlie', text: 'L2', fooled: 4, fooledVoters: ['p4', 'p5', 'p6', 'p7'] },
          { authorId: 'p4', authorName: 'Diana', text: 'L3', fooled: 3, fooledVoters: ['p5', 'p6', 'p7'] }
        ]
      })
    ];

    // Current card has p5 fooling p1 for the first time (count = 1, ranks 4th or lower)
    const currentCard = createSampleCard(2, 'p2', {
      forgeries: [
        { authorId: 'p5', authorName: 'Edward', text: 'Edwards new lie', fooled: 1, fooledVoters: ['p1'] }
      ],
      targetCorrectAttributions: []
    });

    const allCards = [...pastCards, currentCard];
    const result = computeRunningRivalries(allCards, playerNames, { round: 2, targetPlayerId: 'p2' });

    // Should be top 3 only
    expect(result.fools.length).to.equal(3);
    const edwardInTop3 = result.fools.find(f => f.deceiverId === 'p5' && f.victimId === 'p1');
    expect(edwardInTop3).to.be.undefined;

    // But MUST be present in thisCard.fools
    expect(result.thisCard).to.not.be.null;
    const edwardInThisCard = result.thisCard!.fools.find(f => f.deceiverId === 'p5' && f.victimId === 'p1');
    expect(edwardInThisCard).to.not.be.undefined;
    expect(edwardInThisCard!.total).to.equal(1);
  });

  it('5. thisCard is null after advanceToNextResolution and after a round advance', () => {
    const cards = [createSampleCard(1, 'p1')];

    // advanceToNextResolution: next reader is p2 whose card is not resolved yet
    const afterNextRes = computeRunningRivalries(cards, playerNames, { round: 1, targetPlayerId: 'p2' });
    expect(afterNextRes.thisCard).to.be.null;

    // concludeResolutionRound: next round is 2, no reader
    const afterRoundAdvance = computeRunningRivalries(cards, playerNames, { round: 2, targetPlayerId: '' });
    expect(afterRoundAdvance.thisCard).to.be.null;

    // gameOver: current is null
    const gameOverResult = computeRunningRivalries(cards, playerNames, null);
    expect(gameOverResult.thisCard).to.be.null;
  });

  it('6. backward compatibility: every pair still carries deceiverName, victimName, readerName, forgerName and count with same types', () => {
    const card = createSampleCard(1, 'p1');
    const result = computeRunningRivalries([card], playerNames, { round: 1, targetPlayerId: 'p1' });

    expect(result.fools.length).to.be.greaterThan(0);
    for (const f of result.fools) {
      expect(typeof f.deceiverId).to.equal('string');
      expect(typeof f.deceiverName).to.equal('string');
      expect(typeof f.victimId).to.equal('string');
      expect(typeof f.victimName).to.equal('string');
      expect(typeof f.count).to.equal('number');
    }

    expect(result.reads.length).to.be.greaterThan(0);
    for (const r of result.reads) {
      expect(typeof r.readerId).to.equal('string');
      expect(typeof r.readerName).to.equal('string');
      expect(typeof r.forgerId).to.equal('string');
      expect(typeof r.forgerName).to.equal('string');
      expect(typeof r.count).to.equal('number');
    }
  });

  it('7. payload: worst-case fixture (7 players, 3 rounds, maximum occurrences) is well under 64 KB', () => {
    const players = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7'];
    const cards: CardSummary[] = [];

    // 3 rounds, 7 cards per round = 21 cards
    for (let round = 1; round <= 3; round++) {
      for (const targetId of players) {
        const otherPlayersList = players.filter(p => p !== targetId);
        const forgeries = otherPlayersList.map(authorId => ({
          authorId,
          authorName: playerNames[authorId],
          text: `A somewhat long and elaborate lie crafted by ${playerNames[authorId]} for round ${round} about ${playerNames[targetId]} that voters fell for`,
          fooled: otherPlayersList.filter(v => v !== authorId).length,
          fooledVoters: otherPlayersList.filter(v => v !== authorId)
        }));

        cards.push({
          round,
          targetPlayerId: targetId,
          targetPlayerName: playerNames[targetId],
          promptText: `Elaborate Victorian prompt for round ${round} regarding ${playerNames[targetId]} and secrets of the parlor`,
          truthAnswer: `The genuine confession of ${playerNames[targetId]}`,
          truthFinders: [],
          forgeries,
          targetCorrectAttributions: otherPlayersList
        });
      }
    }

    const result = computeRunningRivalries(cards, playerNames, { round: 3, targetPlayerId: 'p7' });
    const jsonStr = JSON.stringify(result);
    const sizeBytes = Buffer.byteLength(jsonStr, 'utf8');

    console.log(`MEASURED RUNNING RIVALRIES WORST-CASE PAYLOAD: ${sizeBytes} bytes (${(sizeBytes / 1024).toFixed(2)} KB)`);

    expect(sizeBytes).to.be.lessThan(64 * 1024, `Payload ${sizeBytes} bytes must be under 64 KB`);
  });
});
