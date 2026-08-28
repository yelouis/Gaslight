import { expect } from 'chai';
import admin from 'firebase-admin';
import { PRESENCE_STALE_MS } from '../src/index';
import { PromptDecks } from '../src/prompt_decks';

// Deck ids are derived from the catalogue, never hardcoded. Renaming a deck in
// functions/src/prompt_decks.ts used to break 33 assertions across this file;
// now it breaks none, and a deck that disappears fails loudly at import time.
const FALLBACK_DECK = PromptDecks.getFallbackDeckId();
/** Smallest deck that is not the fallback — keeps the exhaustion loop short. */
const ALT_DECK = PromptDecks.getAvailableDecks()
  .filter((d) => d !== FALLBACK_DECK)
  .sort((a, b) => PromptDecks.getDeckSize(a) - PromptDecks.getDeckSize(b))[0];

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
try {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || 'demo-no-project'
  });
} catch (e) {
  // Already initialized
}

const db = admin.firestore();

// Helper to create an anonymous user using the Auth emulator REST endpoint
async function createAnonUser(): Promise<{ idToken: string; localId: string }> {
  const url = `http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true })
  });
  if (!res.ok) {
    throw new Error(`Failed to create anon user: ${res.statusText}`);
  }
  const data = await res.json() as any;
  return {
    idToken: data.idToken,
    localId: data.localId
  };
}

// Helper to call an HTTPS Callable Function using the local emulator HTTP endpoint
async function callFn(name: string, idToken: string, data: any): Promise<any> {
  const projectId = process.env.GCLOUD_PROJECT || 'demo-no-project';
  const url = `http://127.0.0.1:5001/${projectId}/us-central1/${name}`;
  console.log(`DEBUG callFn: url=${url}, projectId=${projectId}`);
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${idToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ data })
  });

  let json: any;
  try {
    json = await res.json();
  } catch (e) {
    // Response not JSON
  }

  if (json && json.error) {
    const err = new Error(json.error.message || 'Callable error');
    (err as any).status = json.error.status;
    throw err;
  }

  if (!res.ok) {
    console.log(`DEBUG callFn failure: status=${res.status}, url=${url}`);
    throw new Error(`HTTP Error ${res.status} calling function ${name}`);
  }
  return json.result;
}

describe('Gaslight E2E Game Emulator Tests', () => {
  beforeEach(async () => {
    // Clear Firestore database before each test
    const projectId = process.env.GCLOUD_PROJECT || 'demo-no-project';
    const clearUrl = `http://127.0.0.1:8080/emulator/v1/projects/${projectId}/databases/(default)/documents`;
    const res = await fetch(clearUrl, { method: 'DELETE' });
    if (!res.ok) {
      throw new Error(`Failed to clear firestore emulator: ${res.statusText}`);
    }
  });

  it('should run a full 3-player game loop successfully', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    // 1. Create Room (debugEnabled = true)
    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;
    expect(roomCode).to.be.a('string').and.have.lengthOf(4);

    // 2. Join Room
    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    // 3. Start Game
    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    // Verify room has entered truth phase
    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    let roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.equal('truth');
    expect(roomState.cards).to.have.lengthOf(3);

    // 4. Submit Truths
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: 'p_host',
      authorId: 'p_host',
      text: 'Alice Real Truth',
      isTruth: true
    });
    await callFn('submitAnswer', guestUser.idToken, {
      roomCode,
      targetCardId: 'p_guest',
      authorId: 'p_guest',
      text: 'Bob Real Truth',
      isTruth: true
    });
    await callFn('submitAnswer', guest2User.idToken, {
      roomCode,
      targetCardId: 'p_guest2',
      authorId: 'p_guest2',
      text: 'Charlie Real Truth',
      isTruth: true
    });

    // Verify auto-advance to forgery phase & rotation assignments
    roomSnap = await roomRef.get();
    roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.equal('forgery');

    const assignments = roomState.currentCardAssignments;
    const hostTarget = assignments['p_host'];
    const guestTarget = assignments['p_guest'];
    const guest2Target = assignments['p_guest2'];
    expect(hostTarget).to.be.ok;
    expect(guestTarget).to.be.ok;
    expect(guest2Target).to.be.ok;

    // 5. Submit Forgeries
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: hostTarget,
      authorId: 'p_host',
      text: 'Alice Forged Sabotage',
      isTruth: false
    });
    await callFn('submitAnswer', guestUser.idToken, {
      roomCode,
      targetCardId: guestTarget,
      authorId: 'p_guest',
      text: 'Bob Forged Sabotage',
      isTruth: false
    });
    await callFn('submitAnswer', guest2User.idToken, {
      roomCode,
      targetCardId: guest2Target,
      authorId: 'p_guest2',
      text: 'Charlie Forged Sabotage',
      isTruth: false
    });

    // Verify auto-advance to vote phase
    roomSnap = await roomRef.get();
    roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.equal('vote');
    expect(roomState.resolutionOrder).to.have.lengthOf(3);

    // Issue 63 / §5: Assert option IDs are opaque random UUIDs and leak neither player IDs nor truth
    const playerIds = ['p_host', 'p_guest', 'p_guest2'];
    const votePhaseOptionIds: string[] = [];
    for (const card of roomState.cards) {
      expect(card.options).to.be.an('array').that.is.not.empty;
      for (const opt of card.options) {
        votePhaseOptionIds.push(opt.id);
        expect(opt.id).to.not.match(/truth/i);
        for (const pId of playerIds) {
          expect(opt.id).to.not.include(pId);
        }
      }
    }

    // 6. Voting: All non-readers cast vote
    const currentReader = roomState.currentReaderId;
    const readerToken = currentReader === 'p_host' ? hostUser.idToken : (currentReader === 'p_guest' ? guestUser.idToken : guest2User.idToken);
    const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
    const truthOptId = sealedSnap.data()?.truthAnswerId || 'TRUTH';

    for (const pId of playerIds) {
      if (pId !== currentReader) {
        const token = pId === 'p_host' ? hostUser.idToken : (pId === 'p_guest' ? guestUser.idToken : guest2User.idToken);
        await callFn('castVote', token, {
          roomCode,
          targetCardId: currentReader,
          voterId: pId,
          votedForId: truthOptId
        });
      }
    }

    // Reader sets ready
    await callFn('setReady', readerToken, {
      roomCode,
      playerId: currentReader,
      ready: true
    });

    // Verify auto-advance to reveal phase & option ID stability
    roomSnap = await roomRef.get();
    roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.equal('reveal');

    // Host advances to next resolution
    await callFn('advanceToNextResolution', hostUser.idToken, { roomCode });

    // Verify it advanced to next reader or game over
    roomSnap = await roomRef.get();
    roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.be.oneOf(['vote', 'gameOver']);
  });

  it('should deny unauthorized gameplay requests', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });

    // Guest tries to start game (should fail)
    try {
      await callFn('startGame', guestUser.idToken, {
        roomCode,
        selectedDeckId: FALLBACK_DECK
      });
      expect.fail('Guest started the game but should have been blocked');
    } catch (err: any) {
      expect(err.message).to.contain('host');
    }

    // Guest tries to submit a vote with self-vote during vote phase (should fail)
    await db.collection('rooms').doc(roomCode).update({ currentPhase: 'vote', currentReaderId: 'p_host', cards: [{ targetPlayerId: 'p_host', votes: {} }] });
    await db.collection('rooms').doc(roomCode).collection('sealed').doc('p_host').set({
      answerAuthors: { 'opt_guest': 'p_guest' }
    });
    try {
      await callFn('castVote', guestUser.idToken, {
        roomCode,
        targetCardId: 'p_host',
        voterId: 'p_guest',
        votedForId: 'opt_guest'
      });
      expect.fail('Self-vote succeeded but should have failed');
    } catch (err: any) {
      expect(err.message).to.contain('Self-voting');
    }
  });

  it('SEC3: should store opaque option id in votes during vote phase and enforce phase, reader, and duplicate vote guards', async () => {
    /*
     * Falsification run against current code (where castVote launders resolved author id):
     * Expected: card.votes[voterId] equals the opaque option ID and not the forger's player ID.
     * Observed failure on current code:
     *   AssertionError: expected 'p_charlie' to equal '2db83788-...'
     */
    const hostUser = await createAnonUser();
    const bobUser = await createAnonUser();
    const charlieUser = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_alice',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', bobUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_bob'
    });

    await callFn('joinRoom', charlieUser.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_charlie'
    });

    // Guard 1: Voting when phase is not 'vote' throws FAILED_PRECONDITION
    try {
      await callFn('castVote', bobUser.idToken, {
        roomCode,
        targetCardId: 'p_alice',
        voterId: 'p_bob',
        votedForId: 'some_opt'
      });
      expect.fail('Voting in lobby succeeded but should have failed');
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('FAILED_PRECONDITION');
    }

    // Ready up in lobby
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_bob').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_charlie').update({ lobbyReady: true });

    // Start game -> truth phase
    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    // Submit truth answers -> forgery phase
    await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_alice', authorId: 'p_alice', text: 'Alice Truth', isTruth: true });
    await callFn('submitAnswer', bobUser.idToken, { roomCode, targetCardId: 'p_bob', authorId: 'p_bob', text: 'Bob Truth', isTruth: true });
    await callFn('submitAnswer', charlieUser.idToken, { roomCode, targetCardId: 'p_charlie', authorId: 'p_charlie', text: 'Charlie Truth', isTruth: true });

    // Submit forgeries -> vote phase
    const roomSnapForgeries = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnapForgeries.data()?.currentPhase).to.equal('forgery');
    const assignments = roomSnapForgeries.data()?.currentCardAssignments || {};

    await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_alice'], authorId: 'p_alice', text: 'Alice Forgery', isTruth: false });
    await callFn('submitAnswer', bobUser.idToken, { roomCode, targetCardId: assignments['p_bob'], authorId: 'p_bob', text: 'Bob Forgery', isTruth: false });
    await callFn('submitAnswer', charlieUser.idToken, { roomCode, targetCardId: assignments['p_charlie'], authorId: 'p_charlie', text: 'Charlie Forgery', isTruth: false });

    // Check room is in vote phase
    const roomDoc = await db.collection('rooms').doc(roomCode).get();
    const roomData = roomDoc.data()!;
    expect(roomData.currentPhase).to.equal('vote');
    const currentReaderId = roomData.currentReaderId;
    expect(currentReaderId).to.be.a('string');

    // Get the card for current reader
    const currentCard = roomData.cards.find((c: any) => c.targetPlayerId === currentReaderId);
    expect(currentCard).to.not.be.undefined;
    expect(currentCard.options).to.be.an('array').with.lengthOf.at.least(2);

    // Read sealed doc to find a forgery option and its author
    const sealedSnap = await db.collection('rooms').doc(roomCode).collection('sealed').doc(currentReaderId).get();
    const answerAuthors = sealedSnap.data()?.answerAuthors || {};

    // Find the forgery option on currentReader card and its author
    const forgeryEntry = Object.entries(answerAuthors).find(([optId, author]) => author !== currentReaderId);
    expect(forgeryEntry).to.not.be.undefined;
    const [forgeryOptId, forgerId] = forgeryEntry!;

    // Find voter who is not the forger and not the target/reader
    const activeVoterId = ['p_alice', 'p_bob', 'p_charlie'].find(id => id !== forgerId && id !== currentReaderId)!;
    const voterToken = activeVoterId === 'p_alice' ? hostUser.idToken : (activeVoterId === 'p_bob' ? bobUser.idToken : charlieUser.idToken);

    // Guard 2: Voting for a card other than currentReaderId throws FAILED_PRECONDITION
    const wrongCardId = ['p_alice', 'p_bob', 'p_charlie'].find(id => id !== currentReaderId)!;
    try {
      await callFn('castVote', voterToken, {
        roomCode,
        targetCardId: wrongCardId,
        voterId: activeVoterId,
        votedForId: forgeryOptId
      });
      expect.fail('Voting on wrong card succeeded but should have failed');
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('FAILED_PRECONDITION');
    }

    // Cast vote for forgery option on currentReader card
    await callFn('castVote', voterToken, {
      roomCode,
      targetCardId: currentReaderId,
      voterId: activeVoterId,
      votedForId: forgeryOptId
    });

    // Falsification assertion: In public room doc, card.votes[activeVoterId] must be the option ID and NOT the forgerId
    const roomSnapAfterVote = await db.collection('rooms').doc(roomCode).get();
    const cardAfterVote = roomSnapAfterVote.data()!.cards.find((c: any) => c.targetPlayerId === currentReaderId);
    expect(cardAfterVote.votes[activeVoterId]).to.equal(forgeryOptId);
    expect(cardAfterVote.votes[activeVoterId]).to.not.equal(forgerId);

    // Guard 3: Voting twice on the same card throws FAILED_PRECONDITION and first vote is preserved
    try {
      await callFn('castVote', voterToken, {
        roomCode,
        targetCardId: currentReaderId,
        voterId: activeVoterId,
        votedForId: forgeryOptId
      });
      expect.fail('Voting twice succeeded but should have failed');
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('FAILED_PRECONDITION');
    }
    const roomSnapAfterDoubleVote = await db.collection('rooms').doc(roomCode).get();
    const cardAfterDoubleVote = roomSnapAfterDoubleVote.data()!.cards.find((c: any) => c.targetPlayerId === currentReaderId);
    expect(cardAfterDoubleVote.votes[activeVoterId]).to.equal(forgeryOptId);

    // Over-reach guard: Complete voting on currentReader and assert votes resolve to player IDs at reveal
    const otherPlayers = ['p_alice', 'p_bob', 'p_charlie'].filter(id => id !== activeVoterId);
    for (const pid of otherPlayers) {
      const pToken = pid === 'p_alice' ? hostUser.idToken : (pid === 'p_bob' ? bobUser.idToken : charlieUser.idToken);
      if (pid === currentReaderId) {
        await callFn('setReady', pToken, { roomCode, playerId: pid, ready: true });
      } else {
        const truthEntry = Object.entries(answerAuthors).find(([optId, author]) => author === currentReaderId)!;
        await callFn('castVote', pToken, {
          roomCode,
          targetCardId: currentReaderId,
          voterId: pid,
          votedForId: truthEntry[0]
        });
      }
    }

    const roomSnapReveal = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnapReveal.data()?.currentPhase).to.equal('reveal');
    const cardInReveal = roomSnapReveal.data()!.cards.find((c: any) => c.targetPlayerId === currentReaderId);
    // With SEC5, while unmaskDeadline is active, votes holds the opaque option id; after unmask closes, it resolves
    expect(cardInReveal.votes[activeVoterId]).to.equal(forgeryOptId);

    await callFn('submitUnmaskGuess', voterToken, {
      roomCode,
      guesserId: activeVoterId,
      guessedAuthorId: forgerId
    });
    const roomSnapClosed = await db.collection('rooms').doc(roomCode).get();
    const cardClosed = roomSnapClosed.data()!.cards.find((c: any) => c.targetPlayerId === currentReaderId);
    expect(cardClosed.votes[activeVoterId]).to.equal(forgerId);
  });

  it('SEC4: should merge sealed answers only for the card currently being revealed and leave unread cards blank', async () => {
    /*
     * Falsification run against current code (where all cards are merged at first reveal):
     * Expected: every card except currentReaderId has truthAnswer === "" and empty sabotageAnswers.
     * Observed failure on current code:
     *   AssertionError: expected 'Bob Truth' to equal ''
     */
    const hostUser = await createAnonUser();
    const bobUser = await createAnonUser();
    const charlieUser = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_alice',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', bobUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_bob'
    });

    await callFn('joinRoom', charlieUser.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_charlie'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_bob').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_charlie').update({ lobbyReady: true });

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    // Truth phase
    await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_alice', authorId: 'p_alice', text: 'Alice Truth', isTruth: true });
    await callFn('submitAnswer', bobUser.idToken, { roomCode, targetCardId: 'p_bob', authorId: 'p_bob', text: 'Bob Truth', isTruth: true });
    await callFn('submitAnswer', charlieUser.idToken, { roomCode, targetCardId: 'p_charlie', authorId: 'p_charlie', text: 'Charlie Truth', isTruth: true });

    // Forgery phase
    const roomSnapForgeries = await db.collection('rooms').doc(roomCode).get();
    const assignments = roomSnapForgeries.data()?.currentCardAssignments || {};

    await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_alice'], authorId: 'p_alice', text: 'Alice Forgery', isTruth: false });
    await callFn('submitAnswer', bobUser.idToken, { roomCode, targetCardId: assignments['p_bob'], authorId: 'p_bob', text: 'Bob Forgery', isTruth: false });
    await callFn('submitAnswer', charlieUser.idToken, { roomCode, targetCardId: assignments['p_charlie'], authorId: 'p_charlie', text: 'Charlie Forgery', isTruth: false });

    // Room is in vote phase for card 1
    let roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('vote');
    const card1ReaderId = roomSnap.data()?.currentReaderId;
    const resolutionOrder = roomSnap.data()?.resolutionOrder as string[];
    expect(resolutionOrder).to.have.lengthOf(3);
    expect(card1ReaderId).to.equal(resolutionOrder[0]);

    // Read sealed for card 1 to get truth option id
    const sealed1Snap = await db.collection('rooms').doc(roomCode).collection('sealed').doc(card1ReaderId).get();
    const answerAuthors1 = sealed1Snap.data()?.answerAuthors || {};
    const truthOpt1 = Object.entries(answerAuthors1).find(([optId, author]) => author === card1ReaderId)![0];

    // Non-readers vote on card 1 and reader readies up -> advances to reveal
    const players = ['p_alice', 'p_bob', 'p_charlie'];
    for (const pid of players) {
      const pToken = pid === 'p_alice' ? hostUser.idToken : (pid === 'p_bob' ? bobUser.idToken : charlieUser.idToken);
      if (pid === card1ReaderId) {
        await callFn('setReady', pToken, { roomCode, playerId: pid, ready: true });
      } else {
        await callFn('castVote', pToken, {
          roomCode,
          targetCardId: card1ReaderId,
          voterId: pid,
          votedForId: truthOpt1
        });
      }
    }

    // Assert room is in reveal phase
    roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('reveal');

    // Falsification assertion: Only card 1 is populated; cards 2 & 3 have truthAnswer === "" and empty sabotageAnswers
    const cardsInReveal1 = roomSnap.data()?.cards as any[];
    const card1 = cardsInReveal1.find(c => c.targetPlayerId === card1ReaderId);
    expect(card1.truthAnswer).to.be.a('string').and.not.equal('');
    expect(Object.keys(card1.sabotageAnswers || {})).to.have.lengthOf.at.least(1);

    for (const unreadCard of cardsInReveal1.filter(c => c.targetPlayerId !== card1ReaderId)) {
      expect(unreadCard.truthAnswer).to.equal('');
      expect(Object.keys(unreadCard.sabotageAnswers || {})).to.have.lengthOf(0);
    }

    // Over-reach guard: Advance to card 2 and walk full round
    await callFn('advanceToNextResolution', hostUser.idToken, { roomCode });
    roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('vote');
    const card2ReaderId = roomSnap.data()?.currentReaderId;
    expect(card2ReaderId).to.equal(resolutionOrder[1]);

    const sealed2Snap = await db.collection('rooms').doc(roomCode).collection('sealed').doc(card2ReaderId).get();
    const answerAuthors2 = sealed2Snap.data()?.answerAuthors || {};
    const truthOpt2 = Object.entries(answerAuthors2).find(([optId, author]) => author === card2ReaderId)![0];

    for (const pid of players) {
      const pToken = pid === 'p_alice' ? hostUser.idToken : (pid === 'p_bob' ? bobUser.idToken : charlieUser.idToken);
      if (pid === card2ReaderId) {
        await callFn('setReady', pToken, { roomCode, playerId: pid, ready: true });
      } else {
        await callFn('castVote', pToken, {
          roomCode,
          targetCardId: card2ReaderId,
          voterId: pid,
          votedForId: truthOpt2
        });
      }
    }

    roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('reveal');

    const cardsInReveal2 = roomSnap.data()?.cards as any[];
    const card2 = cardsInReveal2.find(c => c.targetPlayerId === card2ReaderId);
    expect(card2.truthAnswer).to.be.a('string').and.not.equal('');
    expect(Object.keys(card2.sabotageAnswers || {})).to.have.lengthOf.at.least(1);

    // Card 3 is still unread and must be blank
    const card3ReaderId = resolutionOrder[2];
    const card3 = cardsInReveal2.find(c => c.targetPlayerId === card3ReaderId);
    expect(card3.truthAnswer).to.equal('');
    expect(Object.keys(card3.sabotageAnswers || {})).to.have.lengthOf(0);
  });

  it('SEC5: should withhold forgery authorship and sabotageAnswers while unmask window is open, and publish them when closed', async () => {
    /*
     * Falsification run against current code (where sabotageAnswers and resolved votes are published during unmask window):
     * Expected: with unmaskDeadline in the future, currentCard.sabotageAnswers is empty and votes contains no forger player IDs.
     * Observed failure on current code:
     *   AssertionError: expected { p_bob: 'Bob Forgery' } to have a length of 0 but got 1
     */
    const hostUser = await createAnonUser();
    const bobUser = await createAnonUser();
    const charlieUser = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_alice',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', bobUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_bob'
    });

    await callFn('joinRoom', charlieUser.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_charlie'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_bob').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_charlie').update({ lobbyReady: true });

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    // Truth phase
    await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_alice', authorId: 'p_alice', text: 'Alice Truth', isTruth: true });
    await callFn('submitAnswer', bobUser.idToken, { roomCode, targetCardId: 'p_bob', authorId: 'p_bob', text: 'Bob Truth', isTruth: true });
    await callFn('submitAnswer', charlieUser.idToken, { roomCode, targetCardId: 'p_charlie', authorId: 'p_charlie', text: 'Charlie Truth', isTruth: true });

    // Forgery phase
    const roomSnapForgeries = await db.collection('rooms').doc(roomCode).get();
    const assignments = roomSnapForgeries.data()?.currentCardAssignments || {};

    await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_alice'], authorId: 'p_alice', text: 'Alice Forgery', isTruth: false });
    await callFn('submitAnswer', bobUser.idToken, { roomCode, targetCardId: assignments['p_bob'], authorId: 'p_bob', text: 'Bob Forgery', isTruth: false });
    await callFn('submitAnswer', charlieUser.idToken, { roomCode, targetCardId: assignments['p_charlie'], authorId: 'p_charlie', text: 'Charlie Forgery', isTruth: false });

    // Room is in vote phase for card 1
    let roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('vote');
    const currentReaderId = roomSnap.data()?.currentReaderId;

    // Read sealed for current reader card
    const sealedSnap = await db.collection('rooms').doc(roomCode).collection('sealed').doc(currentReaderId).get();
    const answerAuthors = sealedSnap.data()?.answerAuthors || {};

    // Find forgery option and its author
    const forgeryEntry = Object.entries(answerAuthors).find(([optId, author]) => author !== currentReaderId);
    expect(forgeryEntry).to.not.be.undefined;
    const [forgeryOptId, forgerId] = forgeryEntry! as [string, string];

    // Find a voter who is not the forger and not the reader
    const fooledVoterId = ['p_alice', 'p_bob', 'p_charlie'].find(id => id !== forgerId && id !== currentReaderId)!;
    const fooledVoterToken = fooledVoterId === 'p_alice' ? hostUser.idToken : (fooledVoterId === 'p_bob' ? bobUser.idToken : charlieUser.idToken);

    // Cast vote for forgery option
    await callFn('castVote', fooledVoterToken, {
      roomCode,
      targetCardId: currentReaderId,
      voterId: fooledVoterId,
      votedForId: forgeryOptId
    });

    // Cast other vote for truth and reader sets ready
    const otherPlayers = ['p_alice', 'p_bob', 'p_charlie'].filter(id => id !== fooledVoterId);
    for (const pid of otherPlayers) {
      const pToken = pid === 'p_alice' ? hostUser.idToken : (pid === 'p_bob' ? bobUser.idToken : charlieUser.idToken);
      if (pid === currentReaderId) {
        await callFn('setReady', pToken, { roomCode, playerId: pid, ready: true });
      } else {
        const truthEntry = Object.entries(answerAuthors).find(([optId, author]) => author === currentReaderId)!;
        await callFn('castVote', pToken, {
          roomCode,
          targetCardId: currentReaderId,
          voterId: pid,
          votedForId: truthEntry[0]
        });
      }
    }

    // Room is in reveal phase with unmask window open
    roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('reveal');
    const unmaskDeadline = roomSnap.data()?.unmaskDeadline;
    expect(unmaskDeadline).to.be.a('number').and.be.greaterThan(Date.now());

    // Falsification assertion: While unmaskDeadline is active, currentCard has NO forgery authorship
    const currentCardInUnmask = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReaderId);
    expect(Object.keys(currentCardInUnmask.sabotageAnswers || {})).to.have.lengthOf(0);
    expect(currentCardInUnmask.votes[fooledVoterId]).to.not.equal(forgerId);
    expect(currentCardInUnmask.votes[fooledVoterId]).to.equal(forgeryOptId);

    // Over-reach guard: Submit unmask guess while unmask window is open
    await callFn('submitUnmaskGuess', fooledVoterToken, {
      roomCode,
      guesserId: fooledVoterId,
      guessedAuthorId: forgerId
    });

    // After all fooled players guessed, the server closes unmask window and publishes revealed forgeries
    const roomSnapClosed = await db.collection('rooms').doc(roomCode).get();
    const currentCardClosed = (roomSnapClosed.data()?.cards as any[]).find(c => c.targetPlayerId === currentReaderId);
    expect(currentCardClosed.sabotageAnswers[forgerId]).to.be.a('string').and.not.equal('');
    expect(currentCardClosed.votes[fooledVoterId]).to.equal(forgerId);
    expect(currentCardClosed.unmaskGuesses[fooledVoterId]).to.equal(forgerId);

    // Verify scoring delta applied from unmask guess
    const guesserDoc = await db.collection('rooms').doc(roomCode).collection('players').doc(fooledVoterId).get();
    const forgerDoc = await db.collection('rooms').doc(roomCode).collection('players').doc(forgerId).get();
    expect(guesserDoc.data()?.totalScore).to.be.a('number');
    expect(forgerDoc.data()?.totalScore).to.be.a('number');
  });

  it('SEC6: should require room host for debug callables (debugAddBots, debugSimulateBotResponses) and reject strangers and non-host members', async () => {
    /*
     * Falsification run against current code (where any authenticated user can call debug callables in a debugEnabled room):
     * Expected: stranger without room membership rejected with PERMISSION_DENIED.
     * Observed failure on current code:
     *   AssertionError: Stranger call to debugAddBots succeeded unexpectedly
     */
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const strangerUser = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_alice',
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_bob'
    });

    // Guard 1: Stranger caller gets PERMISSION_DENIED on debugAddBots
    try {
      await callFn('debugAddBots', strangerUser.idToken, { roomCode });
      expect.fail('Stranger call to debugAddBots succeeded unexpectedly');
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('PERMISSION_DENIED');
    }

    // Guard 2: Non-host member (guest) caller gets PERMISSION_DENIED on debugAddBots
    try {
      await callFn('debugAddBots', guestUser.idToken, { roomCode });
      expect.fail('Non-host member call to debugAddBots succeeded unexpectedly');
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('PERMISSION_DENIED');
    }

    // Guard 3: Stranger caller gets PERMISSION_DENIED on debugSimulateBotResponses
    try {
      await callFn('debugSimulateBotResponses', strangerUser.idToken, { roomCode });
      expect.fail('Stranger call to debugSimulateBotResponses succeeded unexpectedly');
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('PERMISSION_DENIED');
    }

    // Guard 4: Non-host member (guest) caller gets PERMISSION_DENIED on debugSimulateBotResponses
    try {
      await callFn('debugSimulateBotResponses', guestUser.idToken, { roomCode });
      expect.fail('Non-host member call to debugSimulateBotResponses succeeded unexpectedly');
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('PERMISSION_DENIED');
    }

    // Over-reach guard: Room host calls debugAddBots and 9 bots are added
    const addBotsRes = await callFn('debugAddBots', hostUser.idToken, { roomCode });
    expect(addBotsRes.success).to.be.true;
    const playersSnap = await db.collection('rooms').doc(roomCode).collection('players').get();
    expect(playersSnap.docs.length).to.equal(11); // Alice + Bob + 9 bots
  });

  it('SEC2: should reject seat takeover without token or ownership, and allow rebind with token, ownership, or staleness', async () => {
    /*
     * Falsification run against current code (where anyone can rebind any seat):
     * Expected: stranger without token rejected with PERMISSION_DENIED.
     * Observed failure on current code:
     *   AssertionError: Stranger takeover succeeded with result: {"role":"unassigned"}
     */
    const hostUser = await createAnonUser();
    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;
    const hostSeatToken = createRes.seatToken;

    // Falsification assertion: stranger attempts to take over live host seat without token
    const strangerUser = await createAnonUser();
    try {
      const res = await callFn('joinRoom', strangerUser.idToken, {
        roomCode,
        playerName: 'Attacker',
        playerId: 'p_host'
      });
      expect.fail(`Stranger takeover succeeded with result: ${JSON.stringify(res)}`);
    } catch (err: any) {
      if (err.name === 'AssertionError') throw err;
      expect(err.status).to.equal('PERMISSION_DENIED');
      expect((err as any).role).to.be.undefined;
    }

    // Over-reach Guard 1: Owner rejoining (same authUid, no token provided) succeeds
    const ownerRejoin = await callFn('joinRoom', hostUser.idToken, {
      roomCode,
      playerName: 'Alice Updated',
      playerId: 'p_host'
    });
    expect(ownerRejoin.role).to.equal('unassigned');

    // Over-reach Guard 2: Token holder rejoining with new authUid and correct seatToken succeeds
    const newDeviceUser = await createAnonUser();
    const tokenRejoin = await callFn('joinRoom', newDeviceUser.idToken, {
      roomCode,
      playerName: 'Alice New Device',
      playerId: 'p_host',
      seatToken: hostSeatToken
    });
    expect(tokenRejoin.role).to.equal('unassigned');

    // Over-reach Guard 3: Stale seat (> PRESENCE_STALE_MS) can be reclaimed without token by different user
    const playerRef = db.collection('rooms').doc(roomCode).collection('players').doc('p_host');
    await playerRef.update({ lastSeen: Date.now() - (PRESENCE_STALE_MS + 5000) });
    const staleReclaimUser = await createAnonUser();
    const staleReclaim = await callFn('joinRoom', staleReclaimUser.idToken, {
      roomCode,
      playerName: 'Reclaimer',
      playerId: 'p_host'
    });
    expect(staleReclaim.role).to.equal('unassigned');

    // Over-reach Guard 4: Token never leaks into client-readable player document
    const playerDoc = await playerRef.get();
    const pData = playerDoc.data() || {};
    expect(pData.seatToken).to.be.undefined;
    expect(pData.seatTokenHash).to.be.undefined;
  });

  it('should recover a player seat and re-bind authUid on credential reset', async () => {
    const hostUser = await createAnonUser();
    const guestUserOld = await createAnonUser();

    // 1. Host creates room
    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    // 2. Guest joins room with a stable playerId
    const joinRes = await callFn('joinRoom', guestUserOld.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });

    // Verify initial authUid is guestUserOld.localId
    const playerRef = db.collection('rooms').doc(roomCode).collection('players').doc('p_guest');
    let playerSnap = await playerRef.get();
    expect(playerSnap.data()?.authUid).to.equal(guestUserOld.localId);

    // 3. Guest simulates app reinstall/credential reset, gets a new token
    const guestUserNew = await createAnonUser();
    expect(guestUserNew.localId).to.not.equal(guestUserOld.localId);

    // 4. Guest rejoins with the same stable playerId and presented seatToken
    const rejoinRes = await callFn('joinRoom', guestUserNew.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest',
      seatToken: joinRes.seatToken
    });
    expect(rejoinRes.role).to.equal('unassigned');

    // 5. Verify the guest's seat has been recovered and authUid is updated to guestUserNew.localId
    playerSnap = await playerRef.get();
    expect(playerSnap.data()?.authUid).to.equal(guestUserNew.localId);
    expect(playerSnap.data()?.name).to.equal('Bob');
  });

  it('should add bots with lastSeen set to null', async () => {
    const hostUser = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('debugAddBots', hostUser.idToken, { roomCode });

    const botRef = db.collection('rooms').doc(roomCode).collection('players').doc('bot_1');
    const botSnap = await botRef.get();
    expect(botSnap.exists).to.be.true;
    expect(botSnap.data()?.lastSeen).to.be.null;
  });

  it('should advance phase when host submits first then bots simulate', async () => {
    const hostUser = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('debugAddBots', hostUser.idToken, { roomCode });

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    // Submit host truth
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: 'p_host',
      authorId: 'p_host',
      text: 'Host truth',
      isTruth: true
    });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    // Bots submit truth, auto-advancing to forgery
    await callFn('debugSimulateBotResponses', hostUser.idToken, { roomCode });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('forgery');
    expect(roomSnap.data()?.currentRotationIndex).to.equal(1);

    const assignments = roomSnap.data()?.currentCardAssignments;
    const targetId = assignments['p_host'];

    // Submit host forgery
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: targetId,
      authorId: 'p_host',
      text: 'Host forgery',
      isTruth: false
    });

    // Bots submit forgery, auto-advancing to vote
    await callFn('debugSimulateBotResponses', hostUser.idToken, { roomCode });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('vote');
  });

  it('should handle timeout and fill missing slots with placeholder', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    // Submit host and guest truth
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: 'p_host',
      authorId: 'p_host',
      text: 'Host truth',
      isTruth: true
    });
    await callFn('submitAnswer', guestUser.idToken, {
      roomCode,
      targetCardId: 'p_guest',
      authorId: 'p_guest',
      text: 'Guest truth',
      isTruth: true
    });

    // Advance phase to fill missing guest2 truth with placeholder -> moves to forgery phase
    await callFn('advancePhase', hostUser.idToken, { roomCode });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('forgery');

    const assignments = roomSnap.data()?.currentCardAssignments;

    // Submit host forgery
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: assignments['p_host'],
      authorId: 'p_host',
      text: 'Host lie',
      isTruth: false
    });
    await callFn('submitAnswer', guestUser.idToken, {
      roomCode,
      targetCardId: assignments['p_guest'],
      authorId: 'p_guest',
      text: 'Guest lie',
      isTruth: false
    });

    // Advance phase to fill missing guest2 forgery with placeholder -> moves to vote phase
    await callFn('advancePhase', hostUser.idToken, { roomCode });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('vote');

    // Advance from vote to reveal so sealed answers fold into public card models
    const currentReader = roomSnap.data()?.currentReaderId;
    const getToken = (id: string) => id === 'p_host' ? hostUser.idToken : (id === 'p_guest' ? guestUser.idToken : guest2User.idToken);
    const readerToken = getToken(currentReader);

    const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
    const answerAuthors = sealedSnap.data()?.answerAuthors || {};

    const card = (roomSnap.data()?.cards || []).find((c: any) => c.targetPlayerId === currentReader);
    const options = card?.options || [];
    const votable = options.filter((o: any) => o.text !== 'THE SOUL IS SILENT' && o.text && o.text.trim().length > 0);
    expect(votable.length).to.be.greaterThan(0);

    const playerIds = ['p_host', 'p_guest', 'p_guest2'];
    for (const pId of playerIds) {
      if (pId !== currentReader) {
        const chosenOption = votable.find((o: any) => answerAuthors[o.id] !== pId);
        if (chosenOption) {
          await callFn('castVote', getToken(pId), {
            roomCode,
            targetCardId: currentReader,
            voterId: pId,
            votedForId: chosenOption.id
          });
        } else {
          await callFn('setReady', getToken(pId), {
            roomCode,
            playerId: pId,
            ready: true
          });
        }
      }
    }
    await callFn('setReady', readerToken, {
      roomCode,
      playerId: currentReader,
      ready: true
    });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('reveal');

    const guestSealedSnap = await roomRef.collection('sealed').doc('p_guest').get();
    expect(guestSealedSnap.data()?.truthAnswer).to.equal('Guest truth');

    const hostSealedSnap = await roomRef.collection('sealed').doc('p_host').get();
    expect(hostSealedSnap.data()?.truthAnswer).to.equal('Host truth');
    expect(Object.values(hostSealedSnap.data()?.sabotageAnswers || {})).to.include('THE SOUL IS SILENT');
  });

  it('should handle submitUnmaskGuess E2E revenge guesses and scoring', async () => {
    const hostUser = await createAnonUser();
    const guest1User = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guest1User.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest1'
    });

    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest1').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    // 1. Submit truths first
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: 'p_host',
      authorId: 'p_host',
      text: 'Alice truth',
      isTruth: true
    });
    await callFn('submitAnswer', guest1User.idToken, {
      roomCode,
      targetCardId: 'p_guest1',
      authorId: 'p_guest1',
      text: 'Bob truth',
      isTruth: true
    });
    await callFn('submitAnswer', guest2User.idToken, {
      roomCode,
      targetCardId: 'p_guest2',
      authorId: 'p_guest2',
      text: 'Charlie truth',
      isTruth: true
    });

    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('forgery');

    const assignments = roomSnap.data()?.currentCardAssignments;

    // 2. Submit forgeries
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: assignments['p_host'],
      authorId: 'p_host',
      text: 'Alice forgery for Bob',
      isTruth: false
    });
    await callFn('submitAnswer', guest1User.idToken, {
      roomCode,
      targetCardId: assignments['p_guest1'],
      authorId: 'p_guest1',
      text: 'Bob forgery for Charlie',
      isTruth: false
    });
    await callFn('submitAnswer', guest2User.idToken, {
      roomCode,
      targetCardId: assignments['p_guest2'],
      authorId: 'p_guest2',
      text: 'Charlie forgery for Alice',
      isTruth: false
    });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('vote');
    const readerId = roomSnap.data()?.currentReaderId;

    let forgerId = '';
    let voterId = '';
    let voterToken = '';
    let forgerToken = '';
    let readerToken = '';

    if (readerId === 'p_host') {
      forgerId = 'p_guest2';
      voterId = 'p_guest1';
      voterToken = guest1User.idToken;
      forgerToken = guest2User.idToken;
      readerToken = hostUser.idToken;
    } else if (readerId === 'p_guest1') {
      forgerId = 'p_host';
      voterId = 'p_guest2';
      voterToken = guest2User.idToken;
      forgerToken = hostUser.idToken;
      readerToken = guest1User.idToken;
    } else {
      forgerId = 'p_guest1';
      voterId = 'p_host';
      voterToken = hostUser.idToken;
      forgerToken = guest1User.idToken;
      readerToken = guest2User.idToken;
    }

    await new Promise(r => setTimeout(r, 100));
    const sealedSnap = await roomRef.collection('sealed').doc(readerId).get();
    const answerAuthors = sealedSnap.data()?.answerAuthors || {};
    const forgerOptId = Object.keys(answerAuthors).find(k => answerAuthors[k] === forgerId) || forgerId;
    const truthOptId = sealedSnap.data()?.truthAnswerId || 'TRUTH';

    await callFn('castVote', voterToken, {
      roomCode,
      targetCardId: readerId,
      voterId: voterId,
      votedForId: forgerOptId
    });

    await callFn('castVote', forgerToken, {
      roomCode,
      targetCardId: readerId,
      voterId: forgerId,
      votedForId: truthOptId
    });

    await callFn('setReady', readerToken, {
      roomCode,
      playerId: readerId,
      ready: true
    });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('reveal');
    expect(roomSnap.data()?.unmaskDeadline).to.be.a('number');

    const voterRef = roomRef.collection('players').doc(voterId);
    const forgerRef = roomRef.collection('players').doc(forgerId);

    let voterSnap = await voterRef.get();
    let forgerSnap = await forgerRef.get();

    let rejected = false;
    try {
      await callFn('submitUnmaskGuess', voterToken, {
        roomCode,
        guesserId: voterId,
        guessedAuthorId: voterId
      });
    } catch (e: any) {
      rejected = true;
      expect(e.status).to.equal('INVALID_ARGUMENT');
    }
    expect(rejected).to.be.true;

    await callFn('submitUnmaskGuess', voterToken, {
      roomCode,
      guesserId: voterId,
      guessedAuthorId: forgerId
    });

    voterSnap = await voterRef.get();
    forgerSnap = await forgerRef.get();
    expect(voterSnap.data()?.totalScore).to.equal(1);
    expect(forgerSnap.data()?.totalScore).to.equal(2);

    roomSnap = await roomRef.get();
    const cards = roomSnap.data()?.cards as any[];
    const readerCard = cards.find(c => c.targetPlayerId === readerId);
    expect(readerCard.unmaskGuesses[voterId]).to.equal(forgerId);

    rejected = false;
    try {
      await callFn('submitUnmaskGuess', voterToken, {
        roomCode,
        guesserId: voterId,
        guessedAuthorId: forgerId
      });
    } catch (e: any) {
      rejected = true;
      expect(e.message).to.be.a('string');
    }
    expect(rejected).to.be.true;

    rejected = false;
    try {
      await callFn('submitUnmaskGuess', forgerToken, {
        roomCode,
        guesserId: forgerId,
        guessedAuthorId: voterId
      });
    } catch (e: any) {
      rejected = true;
    }
    expect(rejected).to.be.true;
  });

  it('should handle custom deck prompt selection, top-ups, and reroll fallback', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    const roomRef = db.collection('rooms').doc(roomCode);

    let rejected = false;
    try {
      await callFn('updateLobbySettings', guestUser.idToken, {
        roomCode,
        selectedDeckId: 'custom'
      });
    } catch (e: any) {
      rejected = true;
      expect(e.status).to.equal('PERMISSION_DENIED');
    }
    expect(rejected).to.be.true;

    await callFn('updateLobbySettings', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'custom'
    });

    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.selectedDeckId).to.equal('custom');

    await roomRef.collection('players').doc('p_host').update({
      customPrompts: ['Alice prompt 1', 'Alice prompt 2']
    });
    await roomRef.collection('players').doc('p_guest').update({
      customPrompts: ['Bob prompt 1'],
      lobbyReady: true
    });
    await roomRef.collection('players').doc('p_guest2').update({
      lobbyReady: true
    });

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'custom'
    });

    roomSnap = await roomRef.get();
    const cards = roomSnap.data()?.cards as any[];
    const aliceCard = cards.find(c => c.targetPlayerId === 'p_host');
    const bobCard = cards.find(c => c.targetPlayerId === 'p_guest');

    expect(aliceCard.promptText).to.equal('Bob prompt 1');
    expect(['Alice prompt 1', 'Alice prompt 2']).to.include(bobCard.promptText);

    await callFn('rerollPrompt', hostUser.idToken, {
      roomCode,
      playerId: 'p_host'
    });

    roomSnap = await roomRef.get();
    const cardsAfterReroll = roomSnap.data()?.cards as any[];
    const aliceCardAfterReroll = cardsAfterReroll.find(c => c.targetPlayerId === 'p_host');
    expect(aliceCardAfterReroll.promptText).to.not.equal('Bob prompt 1');
    expect(aliceCardAfterReroll.promptText).to.not.equal('Alice prompt 1');
    expect(aliceCardAfterReroll.promptText).to.not.equal('Alice prompt 2');
  });

  it('Issue 64: should allow unlimited re-rolls during truth phase, enforce phase guard during forgery phase, and handle deck exhaustion', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    // Issue 106: the server resolves the deck from the room document, so the
    // lobby must actually hold it before start - exactly as a real client does.
    await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });
    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });

    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    // Perform 3 consecutive re-rolls during truth phase
    const p1 = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host').promptText;
    await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
    roomSnap = await roomRef.get();
    const p2 = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host').promptText;
    expect(p2).to.not.equal(p1);

    await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
    roomSnap = await roomRef.get();
    const p3 = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host').promptText;
    expect(p3).to.not.equal(p2);

    await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
    roomSnap = await roomRef.get();
    const p4 = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host').promptText;
    expect(p4).to.not.equal(p3);

    // Advance to forgery phase
    await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'T1', isTruth: true });
    await callFn('submitAnswer', guestUser.idToken, { roomCode, targetCardId: 'p_guest', authorId: 'p_guest', text: 'T2', isTruth: true });
    await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_guest2', authorId: 'p_guest2', text: 'T3', isTruth: true });
    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('forgery');

    // Attempt re-roll during forgery phase (must be rejected with failed-precondition)
    let threwPhaseGuard = false;
    try {
      await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
    } catch (e: any) {
      threwPhaseGuard = true;
    }
    expect(threwPhaseGuard).to.be.true;
  });

  it('Issue 67 Option B: should accumulate seenPrompts, never repeat prompts during re-rolls, and keep re-rolling past deck exhaustion', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    // Re-roll counts are derived from the deck, so this still genuinely reaches
    // exhaustion after a deck is resized. It used to assume "exactly 12 prompts".
    const altDeckSize = PromptDecks.getDeckSize(ALT_DECK);
    // Issue 106: the server resolves the deck from the room document, so the
    // lobby must actually hold it before start - exactly as a real client does.
    await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });
    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });

    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    const seenByHost = new Set<string>();
    const hostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
    seenByHost.add(hostCard.promptText);

    // Re-roll until the host has seen every prompt the deck holds, so the loop
    // below genuinely tests behaviour PAST exhaustion.
    for (let i = 0; i < altDeckSize - 1; i++) {
      const cardBefore = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host').promptText;
      const inPlayBefore = new Set((roomSnap.data()?.cards as any[]).map(c => c.promptText));
      await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
      roomSnap = await roomRef.get();
      const updatedHostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
      expect(updatedHostCard.promptText).to.not.equal(cardBefore);
      expect(inPlayBefore.has(updatedHostCard.promptText)).to.be.false;
      seenByHost.add(updatedHostCard.promptText);
    }

    // Issue 69 assertion: Public cards MUST NOT carry seenPrompts
    const publicHostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
    expect(publicHostCard).to.not.have.property('seenPrompts');

    // Issue 69 assertion: Sealed document MUST carry seenPrompts
    const sealedSnap = await db.collection('rooms').doc(roomCode).collection('sealed').doc('p_host').get();
    expect(sealedSnap.exists).to.be.true;
    expect(sealedSnap.data()?.seenPrompts).to.be.an('array');
    expect(sealedSnap.data()?.seenPrompts).to.have.lengthOf(altDeckSize);

    // The host has now seen every prompt the deck holds. Re-rolls are
    // unlimited: past that point the deck repeats rather than refusing, but a
    // re-roll must still visibly change the card and must never collide with a
    // prompt that is live on someone else's card.
    for (let i = 0; i < 3; i++) {
      const before = await db.collection('rooms').doc(roomCode).get();
      const inPlayBefore = new Set((before.data()?.cards as any[]).map(c => c.promptText));

      await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });

      const after = await db.collection('rooms').doc(roomCode).get();
      const hostCard = (after.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
      expect(hostCard.promptText, 're-roll past exhaustion must still return a prompt').to.be.a('string').and.not.empty;
      expect(
        inPlayBefore.has(hostCard.promptText),
        're-roll must not return a prompt that was already on the table'
      ).to.be.false;
    }
  });

  // The vote card renders an answer in full, which is only possible against a
  // bounded length. The client caps its field at 100; this asserts the bound
  // that actually holds, since a client-side limit is only a suggestion.
  it('submitAnswer rejects an answer longer than 100 characters and accepts exactly 100', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, { roomCode, playerName: 'Bob', playerId: 'p_guest' });
    await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_guest2' });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });
    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

    const tooLong = 'x'.repeat(101);
    let threwTooLong = false;
    let message = '';
    try {
      await callFn('submitAnswer', hostUser.idToken, {
        roomCode, targetCardId: 'p_host', authorId: 'p_host', text: tooLong, isTruth: true
      });
    } catch (e: any) {
      threwTooLong = true;
      message = e.message || e.toString() || '';
    }
    expect(threwTooLong).to.be.true;
    expect(message).to.include('101 characters');

    // Exactly at the bound is legal — the vote card is sized for it.
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'y'.repeat(100), isTruth: true
    });
    const sealed = await db.collection('rooms').doc(roomCode).collection('sealed').doc('p_host').get();
    expect(sealed.data()?.truthAnswer).to.have.lengthOf(100);
  });

  // Issue 106 — the deck the game plays is the deck the ROOM holds, and a
  // caller who claims otherwise is rejected rather than quietly obeyed.
  // Falsified: with the pre-fix server (which drew from request.data), the
  // mismatch call below started cah_dark_humor and threwMismatch stayed false.
  // Two properties of the opening deal that nothing guarded until now, and that
  // a Wave N playthrough block appeared to contradict: it recorded the same
  // prompt on two players' cards. That turned out to be a transcription error
  // — drawPrompts slices a shuffled copy WITHOUT replacement and startingCards
  // maps prompts[idx] one-to-one — but "holds by construction" is not a test,
  // and nothing here would have caught a regression that broke it.
  it('the opening deal gives every player a distinct prompt, all from the selected deck', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, { roomCode, playerName: 'Bob', playerId: 'p_guest' });
    await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_guest2' });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });
    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });

    const roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    const prompts = (roomSnap.data()?.cards as any[]).map((c) => c.promptText);

    // Guard the guard: a run that found no cards must not pass silently.
    expect(prompts.length, 'expected one card per active player').to.equal(3);

    // 1. Distinct — two players must never open on the same prompt.
    expect(new Set(prompts).size, `duplicate opening prompt: ${JSON.stringify(prompts)}`)
      .to.equal(prompts.length);

    // 2. In-deck — every prompt traced back to the SELECTED deck, which is the
    //    original Issue 106 defect: prompts arriving from a deck nobody chose.
    const deckPrompts = new Set(PromptDecks.getAllDecks().find((d) => d.id === ALT_DECK)!.prompts);
    for (const p of prompts) {
      expect(deckPrompts.has(p), `"${p}" is not in deck ${ALT_DECK}`).to.be.true;
    }
  });

  it('Issue 106: startGame resolves the deck from the room and rejects a mismatched claim', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, { roomCode, playerName: 'Bob', playerId: 'p_guest' });
    await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_guest2' });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    // The lobby settles on one deck...
    await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });

    // ...and a caller asking for a different one is refused, not obeyed.
    let threwMismatch = false;
    let mismatchMessage = '';
    try {
      await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'rated_r_nsfw' });
    } catch (e: any) {
      threwMismatch = true;
      mismatchMessage = e.message || e.toString() || '';
    }
    expect(threwMismatch).to.be.true;
    expect(mismatchMessage).to.include('Deck mismatch');

    // The room is untouched by the refused call.
    let roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('lobby');
    expect(roomSnap.data()?.selectedDeckId).to.equal(ALT_DECK);

    // The honest call starts, and the prompts really come from that deck.
    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });
    roomSnap = await db.collection('rooms').doc(roomCode).get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');
    expect(roomSnap.data()?.selectedDeckId).to.equal(ALT_DECK);

    // Prompt-source coverage (that a deck id really governs which prompts are
    // drawn) is already carried by the Issue 64/67/83 exhaustion tests, which
    // depend on cah_dark_humor holding exactly 12 prompts. DECKS is module
    // private, and a production accessor is not worth adding for one assertion.
    expect((roomSnap.data()?.cards || []).length).to.equal(3);
  });

  it('should enforce the server-side cap of at most 3 custom prompts per player', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    const roomRef = db.collection('rooms').doc(roomCode);

    await callFn('updateLobbySettings', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'custom'
    });

    // Seed p_host with 10 prompts
    await roomRef.collection('players').doc('p_host').update({
      customPrompts: [
        'FLOOD_01', 'FLOOD_02', 'FLOOD_03', 'FLOOD_04', 'FLOOD_05',
        'FLOOD_06', 'FLOOD_07', 'FLOOD_08', 'FLOOD_09', 'FLOOD_10'
      ]
    });
    // Seed p_guest with 0 prompts (so all custom prompts in pool must come from p_host)
    await roomRef.collection('players').doc('p_guest').update({
      customPrompts: [],
      lobbyReady: true
    });
    await roomRef.collection('players').doc('p_guest2').update({
      lobbyReady: true
    });

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'custom'
    });

    const roomSnap = await roomRef.get();
    const cards = roomSnap.data()?.cards as any[];

    // Count how many cards got assigned a FLOOD_ prompt
    const floodPromptsDealt = cards.filter(c => c.promptText.startsWith('FLOOD_')).length;

    // Since p_host submitted 10, but only at most 3 are harvested, and p_guest submitted 0 (with rest topped up from fallback deck),
    // the number of FLOOD_ prompts dealt can never be more than 3!
    expect(floodPromptsDealt).to.be.at.most(3);
  });

  it('should enforce duplicate-answer rejection in submitAnswer Cloud Function', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();
    const guest2User = await createAnonUser();

    // 1. Create Room (debugEnabled = true)
    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      forgeriesPerCard: 1,
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;

    // 2. Join Room
    await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    await callFn('joinRoom', guest2User.idToken, {
      roomCode,
      playerName: 'Charlie',
      playerId: 'p_guest2'
    });

    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
    await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

    // 3. Start Game
    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: FALLBACK_DECK
    });

    // 4. Submit Truths first to transition to forgery phase
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: 'p_host',
      authorId: 'p_host',
      text: 'Alice truth',
      isTruth: true
    });
    await callFn('submitAnswer', guestUser.idToken, {
      roomCode,
      targetCardId: 'p_guest',
      authorId: 'p_guest',
      text: 'Bob truth',
      isTruth: true
    });
    await callFn('submitAnswer', guest2User.idToken, {
      roomCode,
      targetCardId: 'p_guest2',
      authorId: 'p_guest2',
      text: 'Charlie truth',
      isTruth: true
    });

    const roomRef = db.collection('rooms').doc(roomCode);
    const roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('forgery');
    const targetCardId = roomSnap.data()?.currentCardAssignments['p_host'];
    const guestTargetCardId = roomSnap.data()?.currentCardAssignments['p_guest'];
    expect(targetCardId).to.be.a('string');
    expect(guestTargetCardId).to.be.a('string');

    // 5. Submit first forgery (distinct) -> succeeds
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId,
      authorId: 'p_host',
      text: 'sleeping in my bed all day',
      isTruth: false
    });

    const guestSealed = await db.collection('rooms').doc(roomCode).collection('sealed').doc(guestTargetCardId).get();
    const guestTruth = guestSealed.data()?.truthAnswer || 'Bob truth';

    // 6. Submit near-duplicate forgery from another player against their assigned card's truth -> rejects
    try {
      await callFn('submitAnswer', guestUser.idToken, {
        roomCode,
        targetCardId: guestTargetCardId,
        authorId: 'p_guest',
        text: `${guestTruth}!`,
        isTruth: false
      });
      expect.fail('Should have rejected the duplicate answer');
    } catch (err: any) {
      expect(err.message).to.contain("similar to another player's answer");
      expect(err.status).to.equal('INVALID_ARGUMENT');
    }

    // 7. Submit distinct forgery from the second player -> succeeds
    await callFn('submitAnswer', guestUser.idToken, {
      roomCode,
      targetCardId: guestTargetCardId,
      authorId: 'p_guest',
      text: 'playing video games',
      isTruth: false
    });

    // Verify forgery answers in sealed document (Issue 62 & 63)
    const hostSealedSnap = await db.collection('rooms').doc(roomCode).collection('sealed').doc(targetCardId).get();
    expect(hostSealedSnap.data()?.sabotageAnswers['p_host']).to.equal('sleeping in my bed all day');

    const guestSealedSnap = await db.collection('rooms').doc(roomCode).collection('sealed').doc(guestTargetCardId).get();
    expect(guestSealedSnap.data()?.sabotageAnswers['p_guest']).to.equal('playing video games');
  });

  describe('Issue 31: updateLobbySettings & startGame null handling', () => {
    it('should not erase stored settings when updateLobbySettings is called with nulls', async () => {
      const hostUser = await createAnonUser();
      const createRes = await callFn('createRoom', hostUser.idToken, {
        playerName: 'Alice',
        playerId: 'p_host',
        sabotageAnswersCount: 3,
        isTimerDisabled: true,
        debugEnabled: true
      });
      const roomCode = createRes.roomCode;
      const roomRef = db.collection('rooms').doc(roomCode);

      // Call updateLobbySettings with explicit nulls for untouched fields
      await callFn('updateLobbySettings', hostUser.idToken, {
        roomCode,
        selectedDeckId: 'custom',
        sabotageAnswersCount: null,
        isTimerDisabled: null
      });

      const roomSnap = await roomRef.get();
      const data = roomSnap.data();
      expect(data?.selectedDeckId).to.equal('custom');
      expect(data?.sabotageAnswersCount).to.equal(3);
      expect(data?.isTimerDisabled).to.be.true;
    });

    it('should preserve false and 0 values when updating settings', async () => {
      const hostUser = await createAnonUser();
      const createRes = await callFn('createRoom', hostUser.idToken, {
        playerName: 'Alice',
        playerId: 'p_host',
        sabotageAnswersCount: 2,
        isTimerDisabled: true,
        debugEnabled: true
      });
      const roomCode = createRes.roomCode;
      const roomRef = db.collection('rooms').doc(roomCode);

      await callFn('updateLobbySettings', hostUser.idToken, {
        roomCode,
        isTimerDisabled: false
      });

      const roomSnap = await roomRef.get();
      expect(roomSnap.data()?.isTimerDisabled).to.be.false;
    });

    it('should throw failed-precondition with a readable error message when starting a game with invalid rounds count', async () => {
      const hostUser = await createAnonUser();
      const guestUser = await createAnonUser();
      const guest2User = await createAnonUser();
      const createRes = await callFn('createRoom', hostUser.idToken, {
        playerName: 'Alice',
        playerId: 'p_host'
      });
      const roomCode = createRes.roomCode;
      await callFn('joinRoom', guestUser.idToken, {
        roomCode,
        playerName: 'Bob',
        playerId: 'p_guest'
      });
      await callFn('joinRoom', guest2User.idToken, {
        roomCode,
        playerName: 'Charlie',
        playerId: 'p_guest2'
      });

      await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
      await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

      const roomRef = db.collection('rooms').doc(roomCode);
      await roomRef.update({ sabotageAnswersCount: 0, forgeriesPerCard: 0 });

      try {
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        expect.fail('Should have thrown failed-precondition for null sabotageAnswersCount');
      } catch (err: any) {
        expect(err.message).to.contain('invalid forgery-round count');
      }
    });
  });

  describe('Issue 51: Host Lobby Disconnect Lifecycle', () => {
    it('closes the room when the host disconnects in the lobby', async () => {
      const hostUser = await createAnonUser();
      const guestUser = await createAnonUser();

      const createRes = await callFn('createRoom', hostUser.idToken, {
        playerName: 'Alice',
        playerId: 'p_host',
        sabotageAnswersCount: 2,
        debugEnabled: true
      });
      const roomCode = createRes.roomCode;

      await callFn('joinRoom', guestUser.idToken, {
        roomCode,
        playerName: 'Bob',
        playerId: 'p_guest'
      });

      const roomRef = db.collection('rooms').doc(roomCode);

      // Host disconnects in lobby phase
      const disconnectRes = await callFn('handleDisconnect', hostUser.idToken, {
        roomCode,
        disconnectedPlayerId: 'p_host'
      });
      expect(disconnectRes.roomClosed).to.be.true;

      const roomSnap = await roomRef.get();
      const playersSnap = await roomRef.collection('players').get();

      expect(roomSnap.exists).to.be.false;
      expect(playersSnap.empty).to.be.true;
    });

    it('transfers host instead of closing when the game is in progress', async () => {
      const hostUser = await createAnonUser();
      const guestUser = await createAnonUser();
      const guest2User = await createAnonUser();

      const createRes = await callFn('createRoom', hostUser.idToken, {
        playerName: 'Alice',
        playerId: 'p_host',
        forgeriesPerCard: 1,
        sabotageAnswersCount: 1,
        debugEnabled: true
      });
      const roomCode = createRes.roomCode;

      await callFn('joinRoom', guestUser.idToken, {
        roomCode,
        playerName: 'Bob',
        playerId: 'p_guest'
      });
      await callFn('joinRoom', guest2User.idToken, {
        roomCode,
        playerName: 'Charlie',
        playerId: 'p_guest2'
      });

      await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
      await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

      // Start game so phase is no longer lobby
      await callFn('startGame', hostUser.idToken, {
        roomCode,
        selectedDeckId: FALLBACK_DECK
      });

      const roomRef = db.collection('rooms').doc(roomCode);

      // Host disconnects while game is in progress
      await callFn('handleDisconnect', hostUser.idToken, {
        roomCode,
        disconnectedPlayerId: 'p_host'
      });

      const roomSnap = await roomRef.get();
      expect(roomSnap.exists).to.be.true;

      const playersSnap = await roomRef.collection('players').get();
      const activePlayers = playersSnap.docs.map(d => d.data());
      const hosts = activePlayers.filter(p => p.isHost === true);
      expect(hosts.length).to.equal(1);
      expect(hosts[0].id).to.equal('p_guest');
    });

    describe('Issue 53: 8-Hour Firestore TTL Policy', () => {
      it('writes expiresAt on room and players at creation within a +-5-second window', async () => {
        const hostUser = await createAnonUser();
        const guestUser = await createAnonUser();
        const nowMs = Date.now();
        const expectedTtlMs = nowMs + 8 * 60 * 60 * 1000;

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;

        await callFn('joinRoom', guestUser.idToken, {
          roomCode,
          playerName: 'Bob',
          playerId: 'p_guest'
        });

        const roomRef = db.collection('rooms').doc(roomCode);
        const roomSnap = await roomRef.get();
        const roomData = roomSnap.data();

        expect(roomData).to.have.property('expiresAt');
        const roomExpiresMs = roomData?.expiresAt.toMillis();
        expect(Math.abs(roomExpiresMs - expectedTtlMs)).to.be.below(5000);

        const hostSnap = await roomRef.collection('players').doc('p_host').get();
        const hostExpiresMs = hostSnap.data()?.expiresAt.toMillis();
        expect(Math.abs(hostExpiresMs - expectedTtlMs)).to.be.below(5000);

        const guestSnap = await roomRef.collection('players').doc('p_guest').get();
        const guestExpiresMs = guestSnap.data()?.expiresAt.toMillis();
        expect(Math.abs(guestExpiresMs - expectedTtlMs)).to.be.below(5000);
      });

      it('refreshes expiresAt on existing room writes', async () => {
        const hostUser = await createAnonUser();
        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        const initialSnap = await roomRef.get();
        const initialExpiresMs = initialSnap.data()?.expiresAt.toMillis();

        await new Promise(r => setTimeout(r, 200));

        await callFn('updateLobbySettings', hostUser.idToken, {
          roomCode,
          selectedDeckId: 'rated_r_nsfw'
        });

        const updatedSnap = await roomRef.get();
        const updatedExpiresMs = updatedSnap.data()?.expiresAt.toMillis();
        expect(updatedExpiresMs).to.be.above(initialExpiresMs);
      });
    });

    describe('Issue 61 Sequence Invariant: Full Phase Progression', () => {
      it('asserts exact phase sequence: lobby -> truth -> forgery -> vote -> reveal -> gameOver', async () => {
        const hostUser = await createAnonUser();
        const guestUser = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        await callFn('joinRoom', guestUser.idToken, {
          roomCode,
          playerName: 'Bob',
          playerId: 'p_guest'
        });
        await callFn('joinRoom', guest2User.idToken, {
          roomCode,
          playerName: 'Charlie',
          playerId: 'p_guest2'
        });

        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });

        const roomRef = db.collection('rooms').doc(roomCode);

        // 1. Lobby phase
        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('lobby');

        // 2. Start Game -> Truth phase
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');

        // 3. Submit Truths -> Forgery phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'T1', isTruth: true });
        await callFn('submitAnswer', guestUser.idToken, { roomCode, targetCardId: 'p_guest', authorId: 'p_guest', text: 'T2', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_guest2', authorId: 'p_guest2', text: 'T3', isTruth: true });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');

        // 4. Submit Forgeries -> Vote phase
        const assignments = roomSnap.data()?.currentCardAssignments;
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_host'], authorId: 'p_host', text: 'F1', isTruth: false });
        await callFn('submitAnswer', guestUser.idToken, { roomCode, targetCardId: assignments['p_guest'], authorId: 'p_guest', text: 'F2', isTruth: false });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: assignments['p_guest2'], authorId: 'p_guest2', text: 'F3', isTruth: false });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        // 5. Vote -> Reveal phase
        const reader = roomSnap.data()?.currentReaderId;
        const readerToken = reader === 'p_host' ? hostUser.idToken : (reader === 'p_guest' ? guestUser.idToken : guest2User.idToken);
        const playerIds = ['p_host', 'p_guest', 'p_guest2'];
        
        const sealedSnap = await roomRef.collection('sealed').doc(reader).get();
        const truthOptId = sealedSnap.data()?.truthAnswerId || 'TRUTH';

        for (const pId of playerIds) {
          if (pId !== reader) {
            const token = pId === 'p_host' ? hostUser.idToken : (pId === 'p_guest' ? guestUser.idToken : guest2User.idToken);
            await callFn('castVote', token, { roomCode, targetCardId: reader, voterId: pId, votedForId: truthOptId });
          }
        }
        await callFn('setReady', readerToken, { roomCode, playerId: reader, ready: true });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');
      });
    });

    describe('Issue 71: Option ID resolution in castVote', () => {
      it('resolves option UUID to author ID and rejects self-voting against resolved author', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_guest1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_guest2' });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest1').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice truth', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_guest1', authorId: 'p_guest1', text: 'Bob truth', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_guest2', authorId: 'p_guest2', text: 'Charlie truth', isTruth: true });

        const roomRef = db.collection('rooms').doc(roomCode);
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments;

        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_host'], authorId: 'p_host', text: 'Alice forgery', isTruth: false });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: assignments['p_guest1'], authorId: 'p_guest1', text: 'Bob forgery', isTruth: false });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: assignments['p_guest2'], authorId: 'p_guest2', text: 'Charlie forgery', isTruth: false });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const targetCardId = roomSnap.data()?.currentReaderId;
        expect(targetCardId).to.be.ok;

        const sealedSnap = await roomRef.collection('sealed').doc(targetCardId).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors || {};

        // Find an option on targetCard and its author
        const ownOptionId = Object.keys(answerAuthors)[0];
        const ownAuthorId = answerAuthors[ownOptionId];
        const ownUserToken = ownAuthorId === 'p_host' ? hostUser.idToken : (ownAuthorId === 'p_guest1' ? guest1User.idToken : guest2User.idToken);
        expect(ownOptionId).to.be.ok;

        // Self-vote check: author tries to vote for own option -> fails with FAILED_PRECONDITION
        try {
          await callFn('castVote', ownUserToken, {
            roomCode,
            targetCardId,
            voterId: ownAuthorId,
            votedForId: ownOptionId
          });
          expect.fail('Should have failed self-vote check');
        } catch (err: any) {
          expect(err.status).to.equal('FAILED_PRECONDITION');
          expect(err.message).to.contain('Self-voting');
        }

        // Invalid option ID check
        try {
          await callFn('castVote', hostUser.idToken, {
            roomCode,
            targetCardId,
            voterId: 'p_host',
            votedForId: 'invalid-uuid-1234'
          });
          expect.fail('Should have failed for invalid option ID');
        } catch (err: any) {
          expect(err.status).to.equal('INVALID_ARGUMENT');
        }
      });
    });

    describe('Issue 76: Spurious placeholder prevention', () => {
      it('generates no placeholder card when all players submit on time and rejects spoofed submissions', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, { playerName: 'Alice', playerId: 'p_host', forgeriesPerCard: 1, sabotageAnswersCount: 1, debugEnabled: true });
        const roomCode = createRes.roomCode;
        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_guest1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_guest2' });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest1').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice truth', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_guest1', authorId: 'p_guest1', text: 'Bob truth', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_guest2', authorId: 'p_guest2', text: 'Charlie truth', isTruth: true });

        const roomRef = db.collection('rooms').doc(roomCode);
        await new Promise(r => setTimeout(r, 100));
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments || {};

        // Spoofing guard test: submitting for a card caller is not assigned to must be rejected
        let spoofRejected = false;
        try {
          await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Spoofed forgery', isTruth: false });
        } catch (err: any) {
          spoofRejected = true;
          expect(err.status).to.equal('FAILED_PRECONDITION');
        }
        expect(spoofRejected).to.be.true;

        // Genuine submissions
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_host'], authorId: 'p_host', text: 'Alice forgery', isTruth: false });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: assignments['p_guest1'], authorId: 'p_guest1', text: 'Bob forgery', isTruth: false });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: assignments['p_guest2'], authorId: 'p_guest2', text: 'Charlie forgery', isTruth: false });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        for (const card of roomSnap.data()?.cards || []) {
          for (const opt of card.options || []) {
            expect(opt.text).to.not.equal('THE SOUL IS SILENT');
          }
        }

        // Verify sealed documents contain no placeholder values
        const sealedSnaps = await roomRef.collection('sealed').get();
        for (const doc of sealedSnaps.docs) {
          const sabs = doc.data()?.sabotageAnswers || {};
          for (const val of Object.values(sabs)) {
            expect(val).to.not.equal('THE SOUL IS SILENT');
          }
        }
      });
    });

    describe('Issue 72: Rounds, Forgeries, and 3-Player Floor', () => {
      it('refuses 2-player game start, validates unset defaults at 4 and 9 players, and rejects out-of-range updateLobbySettings', async () => {
        const hostUser = await createAnonUser();
        const guestUser = await createAnonUser();
        const guest2User = await createAnonUser();
        const guest3User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, { playerName: 'Alice', playerId: 'p_host', debugEnabled: true });
        const roomCode = createRes.roomCode;
        await callFn('joinRoom', guestUser.idToken, { roomCode, playerName: 'Bob', playerId: 'p_guest' });

        // 1. Refuses 2-player start with dedicated guard
        try {
          await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
          expect.fail('Should have failed 2-player start');
        } catch (err: any) {
          expect(err.status).to.equal('FAILED_PRECONDITION');
          expect(err.message).to.contain('At least 3 players are required');
        }

        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_guest2' });
        await callFn('joinRoom', guest3User.idToken, { roomCode, playerName: 'Dave', playerId: 'p_guest3' });

        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest2').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_guest3').update({ lobbyReady: true });

        // 2. updateLobbySettings range validation: 0 or activePlayers (4) must be rejected
        let rejectedZero = false;
        try {
          await callFn('updateLobbySettings', hostUser.idToken, { roomCode, forgeriesPerCard: 0 });
        } catch (err: any) {
          rejectedZero = true;
          expect(err.status).to.equal('INVALID_ARGUMENT');
        }
        expect(rejectedZero).to.be.true;

        let rejectedN = false;
        try {
          await callFn('updateLobbySettings', hostUser.idToken, { roomCode, forgeriesPerCard: 4 });
        } catch (err: any) {
          rejectedN = true;
          expect(err.status).to.equal('INVALID_ARGUMENT');
        }
        expect(rejectedN).to.be.true;

        // 3. Unset default resolution at 4 players (should resolve to min(4-1, 5) = 3)
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        const roomRef = db.collection('rooms').doc(roomCode);
        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.forgeriesPerCard).to.equal(3);

        // 4. Create new room with 9 players (unset default should resolve to min(9-1, 5) = 5)
        const create9Res = await callFn('createRoom', hostUser.idToken, { playerName: 'Alice', playerId: 'p_host', debugEnabled: true });
        const room9Code = create9Res.roomCode;
        await callFn('joinRoom', guestUser.idToken, { roomCode: room9Code, playerName: 'Bob', playerId: 'p_guest' });
        await db.collection('rooms').doc(room9Code).collection('players').doc('p_guest').update({ lobbyReady: true });
        await callFn('debugAddBots', hostUser.idToken, { roomCode: room9Code }); // adds 7 bots -> total 9

        // 5. Update settings to 7 forgeries (selectable at 9 players)
        await callFn('updateLobbySettings', hostUser.idToken, { roomCode: room9Code, forgeriesPerCard: 7 });
        const room9Ref = db.collection('rooms').doc(room9Code);
        let room9Snap = await room9Ref.get();
        expect(room9Snap.data()?.forgeriesPerCard).to.equal(7);

        // Starts successfully with 7 forgeries
        await callFn('startGame', hostUser.idToken, { roomCode: room9Code, selectedDeckId: FALLBACK_DECK });
        room9Snap = await room9Ref.get();
        expect(room9Snap.data()?.currentPhase).to.equal('truth');
        expect(room9Snap.data()?.forgeriesPerCard).to.equal(7);
      });
    });

    describe('Issue 78: Truth vote scoring by target identity (no TRUTH sentinel)', () => {
      it('Case A: calculates correct score deltas for P=4, S=1 (truth reward = 2)', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();
        const guest3User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await callFn('joinRoom', guest3User.idToken, { roomCode, playerName: 'Dave', playerId: 'p_g3' });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_g1').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_g2').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_g3').update({ lobbyReady: true });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase: all submit
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });
        await callFn('submitAnswer', guest3User.idToken, { roomCode, targetCardId: 'p_g3', authorId: 'p_g3', text: 'Dave Truth', isTruth: true });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');
        const assignments = roomSnap.data()?.currentCardAssignments;

        // Forgery phase: all submit assigned
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_host'], authorId: 'p_host', text: 'Alice Lie', isTruth: false });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: assignments['p_g1'], authorId: 'p_g1', text: 'Bob Lie', isTruth: false });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: assignments['p_g2'], authorId: 'p_g2', text: 'Charlie Lie', isTruth: false });
        await callFn('submitAnswer', guest3User.idToken, { roomCode, targetCardId: assignments['p_g3'], authorId: 'p_g3', text: 'Dave Lie', isTruth: false });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const targetCardId = roomSnap.data()?.currentReaderId; // Target player of the card being voted on
        const sealedSnap = await roomRef.collection('sealed').doc(targetCardId).get();
        const sealedData = sealedSnap.data() as any;
        const truthOptId = sealedData.truthAnswerId;
        const answerAuthors = sealedData.answerAuthors; // optId -> authorId

        // Find a forgery option id and its forger author id
        let forgeryOptId = '';
        let forgerAuthorId = '';
        for (const [optId, aId] of Object.entries(answerAuthors)) {
          if (optId !== truthOptId) {
            forgeryOptId = optId;
            forgerAuthorId = aId as string;
            break;
          }
        }

        const allPlayers = [
          { id: 'p_host', token: hostUser.idToken },
          { id: 'p_g1', token: guest1User.idToken },
          { id: 'p_g2', token: guest2User.idToken },
          { id: 'p_g3', token: guest3User.idToken },
        ];
        const voters = allPlayers.filter(p => p.id !== targetCardId);
        const reader = allPlayers.find(p => p.id === targetCardId)!;

        // In 4p S=1, voters are 1 forger and 2 innocent guessers
        const innocentVoters = voters.filter(p => p.id !== forgerAuthorId);
        const forgerVoter = voters.find(p => p.id === forgerAuthorId)!;

        const innocentTruthVoter = innocentVoters[0];
        const innocentForgeryVoter = innocentVoters[1];

        // 1. Innocent truth voter votes for truth
        await callFn('castVote', innocentTruthVoter.token, { roomCode, targetCardId, voterId: innocentTruthVoter.id, votedForId: truthOptId });
await callFn('castVote', innocentForgeryVoter.token, { roomCode, targetCardId, voterId: innocentForgeryVoter.id, votedForId: forgeryOptId });
        // 3. Forger votes for truth
        await callFn('castVote', forgerVoter.token, { roomCode, targetCardId, voterId: forgerVoter.id, votedForId: truthOptId });

        await callFn('setReady', reader.token, { roomCode, playerId: reader.id, ready: true });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');

        // Unmask window opens -> expire deadline then close unmask window before checking finalized scores
        await roomRef.update({ unmaskDeadline: Date.now() - 1000 });
        await callFn('closeUnmaskWindow', hostUser.idToken, { roomCode });

        // Check scores:
        // P=4, S=1 -> ceil((4-1)/(1+1)) = ceil(3/2) = 2 for truth voter
        const itvSnap = await roomRef.collection('players').doc(innocentTruthVoter.id).get();
        const ifvSnap = await roomRef.collection('players').doc(innocentForgeryVoter.id).get();
        const targetSnap = await roomRef.collection('players').doc(targetCardId).get();
        const forgerSnap = await roomRef.collection('players').doc(forgerAuthorId).get();

        // Innocent truth voter gains truth reward (2)
        expect(itvSnap.data()?.totalScore).to.equal(2);
        // Card target gains 1 per truth voter (innocentTruthVoter + forgerVoter = 2)
        expect(targetSnap.data()?.totalScore).to.equal(2);
        // Forger gains truthReward(2) + saboteurBonus(1) + forgerCredit(1) = 4
        expect(forgerSnap.data()?.totalScore).to.equal(4);
        // Innocent forgery voter gains 0 (over-reach guard)
        expect(ifvSnap.data()?.totalScore).to.equal(0);
      });

      it('Case B: calculates correct score deltas for P=5, S=3 (truth reward = 1)', async () => {
        const hostUser = await createAnonUser();
        const g1 = await createAnonUser();
        const g2 = await createAnonUser();
        const g3 = await createAnonUser();
        const g4 = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 3,
          sabotageAnswersCount: 3,
          debugEnabled: true,
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await callFn('joinRoom', g3.idToken, { roomCode, playerName: 'Dave', playerId: 'p_g3' });
        await callFn('joinRoom', g4.idToken, { roomCode, playerName: 'Eve', playerId: 'p_g4' });

        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g3').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g4').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice painted a red sailboat on canvas', isTruth: true });
        await callFn('submitAnswer', g1.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob baked twelve chocolate muffins yesterday', isTruth: true });
        await callFn('submitAnswer', g2.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie climbed a snowy mountain in winter', isTruth: true });
        await callFn('submitAnswer', g3.idToken, { roomCode, targetCardId: 'p_g3', authorId: 'p_g3', text: 'Dave found an antique brass pocket watch', isTruth: true });
        await callFn('submitAnswer', g4.idToken, { roomCode, targetCardId: 'p_g4', authorId: 'p_g4', text: 'Eve grew purple orchids in her greenhouse', isTruth: true });

        // Forgery phase (3 rotations)
        const lieSentences: Record<string, string[]> = {
          'p_host': ['Alice rode an elephant through the jungle', 'Alice swam across the wide blue lake', 'Alice flew a tiny kite near the beach'],
          'p_g1': ['Bob repaired an ancient wooden grandfather clock', 'Bob planted giant sunflowers along the garden fence', 'Bob solved a mysterious puzzle box'],
          'p_g2': ['Charlie played acoustic guitar in the village tavern', 'Charlie caught three rainbow trout in the river', 'Charlie read ten leather books'],
          'p_g3': ['Dave designed a miniature solar powered carriage', 'Dave mapped the stars through an iron telescope', 'Dave brewed spicy ginger beer'],
          'p_g4': ['Eve crafted beautiful silver jewelry with emeralds', 'Eve sculpted a stone gargoyle for the castle', 'Eve wrote funny poems in secret'],
        };
        for (let rot = 1; rot <= 3; rot++) {
          const rSnap = await roomRef.get();
          const assignments = rSnap.data()?.currentCardAssignments as Record<string, string>;
          for (const [holderId, targetId] of Object.entries(assignments)) {
            const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1 : (holderId === 'p_g2' ? g2 : (holderId === 'p_g3' ? g3 : g4)));
            const text = lieSentences[holderId][rot - 1];
            await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text, isTruth: false });
          }
        }

        // Vote phase
        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const targetCardId = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === targetCardId);

        const sealedSnap = await roomRef.collection('sealed').doc(targetCardId).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

        const truthOptId = currentCard.options.find((o: any) => answerAuthors[o.id] === targetCardId).id;
        const forgeryOpts = currentCard.options.filter((o: any) => answerAuthors[o.id] !== targetCardId);

        const allPlayers = [
          { id: 'p_host', token: hostUser.idToken },
          { id: 'p_g1', token: g1.idToken },
          { id: 'p_g2', token: g2.idToken },
          { id: 'p_g3', token: g3.idToken },
          { id: 'p_g4', token: g4.idToken },
        ];

        const reader = allPlayers.find(p => p.id === targetCardId)!;
        const nonReaders = allPlayers.filter(p => p.id !== targetCardId);

        const forger1AuthorId = answerAuthors[forgeryOpts[0].id];
        const forger2AuthorId = answerAuthors[forgeryOpts[1].id];
        const forger3AuthorId = answerAuthors[forgeryOpts[2].id];

        const forger1 = nonReaders.find(p => p.id === forger1AuthorId)!;
        const forger2 = nonReaders.find(p => p.id === forger2AuthorId)!;
        const forger3 = nonReaders.find(p => p.id === forger3AuthorId)!;
        const innocentVoter = nonReaders.find(p => p.id !== forger1AuthorId && p.id !== forger2AuthorId && p.id !== forger3AuthorId)!;

        // innocentVoter votes TRUTH
        await callFn('castVote', innocentVoter.token, { roomCode, targetCardId, voterId: innocentVoter.id, votedForId: truthOptId });
        // forger1 votes for forger2's lie (fooled by forger2)
        await callFn('castVote', forger1.token, { roomCode, targetCardId, voterId: forger1.id, votedForId: forgeryOpts[1].id });
        // forger2 votes TRUTH
        await callFn('castVote', forger2.token, { roomCode, targetCardId, voterId: forger2.id, votedForId: truthOptId });
        // forger3 votes TRUTH
        await callFn('castVote', forger3.token, { roomCode, targetCardId, voterId: forger3.id, votedForId: truthOptId });

        await callFn('setReady', reader.token, { roomCode, playerId: reader.id, ready: true });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');

        // Unmask window opens -> expire deadline then close unmask window before checking finalized scores
        await roomRef.update({ unmaskDeadline: Date.now() - 1000 });
        await callFn('closeUnmaskWindow', hostUser.idToken, { roomCode });

        // P=5, S=3 -> ceil((5-1)/(3+1)) = ceil(4/4) = 1
        const itvSnap = await roomRef.collection('players').doc(innocentVoter.id).get();
        const f1Snap = await roomRef.collection('players').doc(forger1.id).get();
        const f2Snap = await roomRef.collection('players').doc(forger2.id).get();
        const f3Snap = await roomRef.collection('players').doc(forger3.id).get();
        const targetSnap = await roomRef.collection('players').doc(targetCardId).get();

        // Innocent voter gets truth reward = 1
        expect(itvSnap.data()?.totalScore).to.equal(1);
        // Forger 1 was fooled by Forger 2 -> 0 (over-reach guard)
        expect(f1Snap.data()?.totalScore).to.equal(0);
        // Forger 2 gets truth reward (1) + saboteur bonus (1) + forger credit from forger 1 (1) = 3
        expect(f2Snap.data()?.totalScore).to.equal(3);
        // Forger 3 gets truth reward (1) + saboteur bonus (1) = 2
        expect(f3Snap.data()?.totalScore).to.equal(2);
        // Target gets +1 per truth voter (innocentVoter + forger2 + forger3 = 3)
        expect(targetSnap.data()?.totalScore).to.equal(3);
      });
    });

    describe('Issue 79: Exclude card target from unmask revenge accusation', () => {
      it('rejects accusing the card target with INVALID_ARGUMENT and accepts valid forger guess', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true,
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });

        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? guest1User : guest2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
        }

        roomSnap = await roomRef.get();
        const targetCardId = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === targetCardId);

        const sealedSnap = await roomRef.collection('sealed').doc(targetCardId).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

        const truthOptId = currentCard.options.find((o: any) => answerAuthors[o.id] === targetCardId).id;
        const forgeryOpt = currentCard.options.find((o: any) => answerAuthors[o.id] !== targetCardId);
        const forgerAuthorId = answerAuthors[forgeryOpt.id];

        const allPlayers = [
          { id: 'p_host', token: hostUser.idToken },
          { id: 'p_g1', token: guest1User.idToken },
          { id: 'p_g2', token: guest2User.idToken },
        ];

        const reader = allPlayers.find(p => p.id === targetCardId)!;
        const forgerVoter = allPlayers.find(p => p.id === forgerAuthorId)!;
        const otherVoter = allPlayers.find(p => p.id !== targetCardId && p.id !== forgerAuthorId)!;

        // otherVoter votes for the forger's lie -> fooled
        await callFn('castVote', otherVoter.token, { roomCode, targetCardId, voterId: otherVoter.id, votedForId: forgeryOpt.id });
        // forger votes for truth
        await callFn('castVote', forgerVoter.token, { roomCode, targetCardId, voterId: forgerVoter.id, votedForId: truthOptId });

        await callFn('setReady', reader.token, { roomCode, playerId: reader.id, ready: true });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');

        // 1. Falsifying assertion: otherVoter attempts to accuse targetCardId (who wrote truth)
        let rejectedTargetAccusation = false;
        try {
          await callFn('submitUnmaskGuess', otherVoter.token, {
            roomCode,
            guesserId: otherVoter.id,
            guessedAuthorId: targetCardId,
          });
        } catch (err: any) {
          rejectedTargetAccusation = true;
          expect(err.status).to.equal('INVALID_ARGUMENT');
        }
        expect(rejectedTargetAccusation).to.be.true;

        // 2. Over-reach guard: accusing the real forger succeeds and adjusts scores (+1 guesser, -1 forger)
        await callFn('submitUnmaskGuess', otherVoter.token, {
          roomCode,
          guesserId: otherVoter.id,
          guessedAuthorId: forgerAuthorId,
        });

        const forgerScoreAfter = (await roomRef.collection('players').doc(forgerAuthorId).get()).data()?.totalScore || 0;
        const guesserScoreAfter = (await roomRef.collection('players').doc(otherVoter.id).get()).data()?.totalScore || 0;

        expect(guesserScoreAfter).to.equal(1);
        expect(forgerScoreAfter).to.equal(2);
      });
    });

    describe('Issue 83 Option C: re-rolls past the deck boundary, and per-player isolation for two deck sizes', () => {
      const testCases = [
        { deckId: ALT_DECK, totalPrompts: 12 },
        { deckId: FALLBACK_DECK, totalPrompts: 20 },
      ];

      for (const tc of testCases) {
        it(`keeps re-rolling ${tc.deckId} (${tc.totalPrompts} prompts) past the boundary and permits second player to re-roll`, async () => {
          const hostUser = await createAnonUser();
          const guest1User = await createAnonUser();
          const guest2User = await createAnonUser();

          const createRes = await callFn('createRoom', hostUser.idToken, {
            playerName: 'Alice',
            playerId: 'p_host',
            forgeriesPerCard: 1,
            debugEnabled: true
          });
          const roomCode = createRes.roomCode;
          const roomRef = db.collection('rooms').doc(roomCode);

          await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
          await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
          await db.collection('rooms').doc(roomCode).collection('players').doc('p_g1').update({ lobbyReady: true });
          await db.collection('rooms').doc(roomCode).collection('players').doc('p_g2').update({ lobbyReady: true });

          // Issue 106: the server resolves the deck from the room document, so the
          // lobby must actually hold it before start - exactly as a real client does.
          await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: tc.deckId });
          await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: tc.deckId });

          let roomSnap = await roomRef.get();
          expect(roomSnap.data()?.currentPhase).to.equal('truth');

          // Host starts with 1 prompt; other 2 players hold 2 prompts.
          // In a 3-player match, available prompts for host = totalPrompts - 3 active cards.
          const expectedHostRerolls = tc.totalPrompts - 3;
          const seenByHost = new Set<string>();

          const initialHostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
          seenByHost.add(initialHostCard.promptText);

          for (let i = 0; i < expectedHostRerolls; i++) {
            const cardBefore = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host').promptText;
            const inPlayBefore = new Set((roomSnap.data()?.cards as any[]).map(c => c.promptText));
            await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
            roomSnap = await roomRef.get();
            const updatedCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
            expect(updatedCard.promptText).to.not.equal(cardBefore);
            expect(inPlayBefore.has(updatedCard.promptText)).to.be.false;
            seenByHost.add(updatedCard.promptText);
          }

          expect(seenByHost.size).to.be.greaterThan(0);

          // Past the boundary the re-roll keeps working - unlimited re-rolls -
          // and still refuses to hand back anything currently on the table.
          const beforeBoundary = await roomRef.get();
          const inPlayAtBoundary = new Set((beforeBoundary.data()?.cards as any[]).map(c => c.promptText));
          await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
          const afterBoundary = await roomRef.get();
          const hostCardPastBoundary = (afterBoundary.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
          expect(hostCardPastBoundary.promptText).to.be.a('string').and.not.empty;
          expect(
            inPlayAtBoundary.has(hostCardPastBoundary.promptText),
            'a repeat is allowed, but not one that is live on a card right now'
          ).to.be.false;

          // Over-reach guard: Guest 1 in the same room must still be able to re-roll successfully
          const guest1InitialCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_g1');
          await callFn('rerollPrompt', guest1User.idToken, { roomCode, playerId: 'p_g1' });
          roomSnap = await roomRef.get();
          const guest1UpdatedCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_g1');
          expect(guest1UpdatedCard.promptText).to.not.equal(guest1InitialCard.promptText);
        });
      }
    });

    describe('Issue 87: Host kick in the lobby and non-host permission guard', () => {
      it('allows host to kick a lobby player and rejects non-host attempting to kick another player', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });

        let playersSnap = await roomRef.collection('players').get();
        expect(playersSnap.docs.length).to.equal(3);

        // 1. Over-reach guard: guest1 attempts to kick guest2 (must be rejected with PERMISSION_DENIED)
        let nonHostKickRejected = false;
        try {
          await callFn('handleDisconnect', guest1User.idToken, {
            roomCode,
            disconnectedPlayerId: 'p_g2'
          });
        } catch (err: any) {
          nonHostKickRejected = true;
          expect(err.status).to.equal('PERMISSION_DENIED');
        }
        expect(nonHostKickRejected).to.be.true;

        // Verify guest2 is still present
        const g2Doc = await roomRef.collection('players').doc('p_g2').get();
        expect(g2Doc.exists).to.be.true;

        // 2. Falsifying assertion: host kicks guest1 from the lobby
        await callFn('handleDisconnect', hostUser.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g1',
          reason: 'kick'
        });

        // Assert guest1 doc no longer exists
        const g1DocAfter = await roomRef.collection('players').doc('p_g1').get();
        expect(g1DocAfter.exists).to.be.false;

        // Assert remaining roster is intact (host and guest2)
        playersSnap = await roomRef.collection('players').get();
        expect(playersSnap.docs.length).to.equal(2);
        const playerIds = playersSnap.docs.map(d => d.id);
        expect(playerIds).to.include('p_host');
        expect(playerIds).to.include('p_g2');
      });
    });

    describe('Issue 86: Gate startGame on lobby readiness for all non-host players', () => {
      it('rejects startGame when any non-host is unready, and succeeds when all non-hosts are ready regardless of host lobbyReady', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });

        // Set guest1 ready, but guest2 unready
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: false });

        // 1. Falsifying assertion: 1 of 2 non-hosts is unready -> startGame must throw failed-precondition
        let rejectedUnreadyStart = false;
        try {
          await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        } catch (err: any) {
          rejectedUnreadyStart = true;
          expect(err.status).to.equal('FAILED_PRECONDITION');
        }
        expect(rejectedUnreadyStart).to.be.true;

        // 2. Over-reach guard: Set guest2 ready as well. Host's lobbyReady is still false.
        // startGame must succeed (deadlock guard: host lobbyReady is not required).
        const hostDoc = await roomRef.collection('players').doc('p_host').get();
        expect(hostDoc.data()?.lobbyReady).to.not.be.true;

        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        const startRes = await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        expect(startRes.success).to.be.true;

        const roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
      });
    });

    describe('Issue 85: Quit game in progress and auto-end below 3 players', () => {
      it('flips match to gameOver and preserves remaining scores when 3-player match drops to 2', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true, totalScore: 5 });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true, totalScore: 7 });
        await roomRef.collection('players').doc('p_host').update({ totalScore: 10 });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');

        // 1. Falsifying assertion: In a 3-player match, guest2 leaves mid-match
        await callFn('handleDisconnect', guest2User.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g2'
        });

        // Assert room flips to gameOver
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('gameOver');
        expect(roomSnap.data()?.unmaskDeadline).to.be.null;
        expect(roomSnap.data()?.endTime).to.be.null;

        // Assert remaining players' totalScore values are preserved
        const hostDoc = await roomRef.collection('players').doc('p_host').get();
        const g1Doc = await roomRef.collection('players').doc('p_g1').get();
        expect(hostDoc.data()?.totalScore).to.equal(10);
        expect(g1Doc.data()?.totalScore).to.equal(5);
      });

      it('over-reach guard: 4-player match losing 1 player stays in active phase and decrements totalPlayers to 3', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();
        const guest3User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await callFn('joinRoom', guest3User.idToken, { roomCode, playerName: 'Dave', playerId: 'p_g3' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g3').update({ lobbyReady: true });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');

        // guest3 leaves 4-player match
        await callFn('handleDisconnect', guest3User.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g3'
        });

        // Match stays in truth phase, totalPlayers becomes 3
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
        expect(roomSnap.data()?.totalPlayers).to.equal(3);
      });

      it('over-reach guard: 3-player lobby losing 1 player stays in lobby phase and does not flip to gameOver', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('lobby');

        // guest2 leaves lobby
        await callFn('handleDisconnect', guest2User.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g2'
        });

        // Phase remains lobby
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('lobby');
      });
    });

    describe('Issue 90 / W4: getMyOptionId private option identification', () => {
      it('returns the caller\'s own optionId, returns null for non-author, and rejects cross-player access with permission-denied', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();
        const guest3User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await callFn('joinRoom', guest3User.idToken, { roomCode, playerName: 'Dave', playerId: 'p_g3' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g3').update({ lobbyReady: true });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase: all submit
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice truth', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob truth', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie truth', isTruth: true });
        await callFn('submitAnswer', guest3User.idToken, { roomCode, targetCardId: 'p_g3', authorId: 'p_g3', text: 'Dave truth', isTruth: true });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');
        const assignments = roomSnap.data()?.currentCardAssignments || {};

        // Forgery phase: all submit assigned
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_host'], authorId: 'p_host', text: 'Alice forgery', isTruth: false });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: assignments['p_g1'], authorId: 'p_g1', text: 'Bob forgery', isTruth: false });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: assignments['p_g2'], authorId: 'p_g2', text: 'Charlie forgery', isTruth: false });
        await callFn('submitAnswer', guest3User.idToken, { roomCode, targetCardId: assignments['p_g3'], authorId: 'p_g3', text: 'Dave forgery', isTruth: false });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        const cardId = 'p_host';
        const sealedSnap = await roomRef.collection('sealed').doc(cardId).get();
        const answerAuthors = (sealedSnap.data() as any)?.answerAuthors || {};

        // Find the player who forged p_host's card
        const playerEntries = [
          { id: 'p_host', token: hostUser.idToken },
          { id: 'p_g1', token: guest1User.idToken },
          { id: 'p_g2', token: guest2User.idToken },
          { id: 'p_g3', token: guest3User.idToken },
        ];

        const forgerEntry = playerEntries.find(p => assignments[p.id] === cardId)!;
        const nonAuthorEntry = playerEntries.find(p => p.id !== cardId && assignments[p.id] !== cardId)!;

        // Bound 1: Forger authored a forgery on cardId -> getMyOptionId returns forger's optionId
        const forgerRes = await callFn('getMyOptionId', forgerEntry.token, {
          roomCode,
          cardId,
          playerId: forgerEntry.id
        });
        expect(forgerRes.optionId).to.be.a('string');
        expect(answerAuthors[forgerRes.optionId]).to.equal(forgerEntry.id);

        // Bound 2: Non-author who wrote neither truth nor forgery on cardId receives { optionId: null } without throwing
        const nonAuthorRes = await callFn('getMyOptionId', nonAuthorEntry.token, {
          roomCode,
          cardId,
          playerId: nonAuthorEntry.id
        });
        expect(nonAuthorRes.optionId).to.be.null;

        // Bound 3: Security bound — caller cannot obtain another player's option ID.
        // Calling with a playerId they do not own throws permission-denied.
        let permissionDeniedThrown = false;
        try {
          await callFn('getMyOptionId', nonAuthorEntry.token, {
            roomCode,
            cardId,
            playerId: forgerEntry.id // non-author tries to query forger's ID
          });
        } catch (err: any) {
          permissionDeniedThrown = true;
          expect(err.status).to.equal('PERMISSION_DENIED');
        }
        expect(permissionDeniedThrown).to.be.true;
      });
    });

    describe('Wave J: Prompt Source & Sampling (J1 - Issue 109)', () => {
      it('Issue 109: custom-deck game with totalRounds: 2 advances past round 1 to round 2 without throwing not-found', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          selectedDeckId: 'custom',
          totalRounds: 2,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, {
          roomCode,
          playerName: 'Bob',
          playerId: 'p_g1'
        });
        await callFn('joinRoom', guest2User.idToken, {
          roomCode,
          playerName: 'Charlie',
          playerId: 'p_g2'
        });

        // Seed customPrompts on each player doc
        await roomRef.collection('players').doc('p_host').update({
          customPrompts: ['Alice prompt 1', 'Alice prompt 2'],
          lobbyReady: true
        });
        await roomRef.collection('players').doc('p_g1').update({
          customPrompts: ['Bob prompt 1', 'Bob prompt 2'],
          lobbyReady: true
        });
        await roomRef.collection('players').doc('p_g2').update({
          customPrompts: ['Charlie prompt 1', 'Charlie prompt 2'],
          lobbyReady: true
        });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'custom' });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
        expect(roomSnap.data()?.currentRound).to.equal(1);

        // Submit truth answers
        await callFn('submitAnswer', hostUser.idToken, {
          roomCode,
          targetCardId: 'p_host',
          authorId: 'p_host',
          text: 'Alice Truth',
          isTruth: true
        });
        await callFn('submitAnswer', guest1User.idToken, {
          roomCode,
          targetCardId: 'p_g1',
          authorId: 'p_g1',
          text: 'Bob Truth',
          isTruth: true
        });
        await callFn('submitAnswer', guest2User.idToken, {
          roomCode,
          targetCardId: 'p_g2',
          authorId: 'p_g2',
          text: 'Charlie Truth',
          isTruth: true
        });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');
        const assignments = roomSnap.data()?.currentCardAssignments || {};

        // Submit forgeries
        for (const [holderId, cardId] of Object.entries(assignments)) {
          const pToken = holderId === 'p_host' ? hostUser.idToken : (holderId === 'p_g1' ? guest1User.idToken : guest2User.idToken);
          await callFn('submitAnswer', pToken, {
            roomCode,
            targetCardId: cardId as string,
            authorId: holderId,
            text: `${holderId} forgery on ${cardId}`,
            isTruth: false
          });
        }

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const resolutionOrder = roomSnap.data()?.resolutionOrder as string[];
        expect(resolutionOrder).to.have.lengthOf(3);

        const players = ['p_host', 'p_g1', 'p_g2'];

        // Walk through each of the 3 cards in round 1
        for (let i = 0; i < 3; i++) {
          roomSnap = await roomRef.get();
          expect(roomSnap.data()?.currentPhase).to.equal('vote');
          const currentReader = roomSnap.data()?.currentReaderId;

          const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
          const answerAuthors = (sealedSnap.data() as any)?.answerAuthors || {};
          const truthOpt = Object.entries(answerAuthors).find(([optId, author]) => author === currentReader)![0];

          for (const pid of players) {
            const pToken = pid === 'p_host' ? hostUser.idToken : (pid === 'p_g1' ? guest1User.idToken : guest2User.idToken);
            if (pid === currentReader) {
              await callFn('setReady', pToken, { roomCode, playerId: pid, ready: true });
            } else {
              await callFn('castVote', pToken, {
                roomCode,
                targetCardId: currentReader,
                voterId: pid,
                votedForId: truthOpt
              });
            }
          }

          roomSnap = await roomRef.get();
          expect(roomSnap.data()?.currentPhase).to.equal('reveal');

          // Advance resolution
          await callFn('advanceToNextResolution', hostUser.idToken, { roomCode });
        }

        // After the 3rd card resolution advances, it should advance to round 2 truth phase
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
        expect(roomSnap.data()?.currentRound).to.equal(2);
        const r2Cards = roomSnap.data()?.cards as any[];
        expect(r2Cards).to.have.lengthOf(3);
        for (const card of r2Cards) {
          expect(card.promptText).to.be.a('string').and.not.equal('');
        }
      });

      it('Sentinel containment: custom string does not appear inside rerollPrompt or advanceToNextResolution bodies', async () => {
        const fs = await import('fs');
        const path = await import('path');
        const indexPath = path.resolve(__dirname, '../src/index.ts');
        const source = fs.readFileSync(indexPath, 'utf-8');

        // Extract rerollPrompt function body
        const rerollMatch = source.match(/export const rerollPrompt = onCall\([^)]*\)\s*=>\s*\{([\s\S]*?)\n\}\);\n/);
        expect(rerollMatch, 'rerollPrompt function body extracted').to.not.be.null;
        const rerollBody = rerollMatch![1];
        expect(rerollBody.split('\n').length).to.be.greaterThan(10);
        expect(rerollBody).to.not.include('"custom"');
        expect(rerollBody).to.not.include("'custom'");

        // Extract advanceToNextResolution function body
        const advanceMatch = source.match(/export const advanceToNextResolution = onCall\([^)]*\)\s*=>\s*\{([\s\S]*?)\n\}\);\n/);
        expect(advanceMatch, 'advanceToNextResolution function body extracted').to.not.be.null;
        const advanceBody = advanceMatch![1];
        expect(advanceBody.split('\n').length).to.be.greaterThan(10);
        expect(advanceBody).to.not.include('"custom"');
        expect(advanceBody).to.not.include("'custom'");
      });

      it('Issue 108 (J2): custom game re-roll draws from players contributed pool and never hands back player own prompt', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          selectedDeckId: 'custom',
          totalRounds: 2,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, {
          roomCode,
          playerName: 'Bob',
          playerId: 'p_g1'
        });
        await callFn('joinRoom', guest2User.idToken, {
          roomCode,
          playerName: 'Charlie',
          playerId: 'p_g2'
        });

        const alicePrompts = ['Alice Unique 1', 'Alice Unique 2'];
        const bobPrompts = ['Bob Unique 1', 'Bob Unique 2'];
        const charliePrompts = ['Charlie Unique 1', 'Charlie Unique 2'];

        await roomRef.collection('players').doc('p_host').update({
          customPrompts: alicePrompts,
          lobbyReady: true
        });
        await roomRef.collection('players').doc('p_g1').update({
          customPrompts: bobPrompts,
          lobbyReady: true
        });
        await roomRef.collection('players').doc('p_g2').update({
          customPrompts: charliePrompts,
          lobbyReady: true
        });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'custom' });

        let roomSnap = await roomRef.get();
        let cards = roomSnap.data()?.cards as any[];
        const aliceInitialCard = cards.find(c => c.targetPlayerId === 'p_host');
        expect(aliceInitialCard.promptText).to.not.be.oneOf(alicePrompts, 'Alice should never receive her own prompt on initial draw');

        // Alice re-rolls
        await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });

        roomSnap = await roomRef.get();
        cards = roomSnap.data()?.cards as any[];
        const aliceRerolledCard = cards.find(c => c.targetPlayerId === 'p_host');
        expect(aliceRerolledCard.promptText).to.not.be.oneOf(alicePrompts, 'Alice should never receive her own prompt on re-roll');
        expect(aliceRerolledCard.promptText).to.be.oneOf(
          [...bobPrompts, ...charliePrompts],
          'Alice re-roll should draw from other players contributed pool'
        );
      });

      it('Issue 108 (J2): custom game with insufficient pool falls back to fallbackDeckId gracefully', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          selectedDeckId: 'custom',
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, {
          roomCode,
          playerName: 'Bob',
          playerId: 'p_g1'
        });
        await callFn('joinRoom', guest2User.idToken, {
          roomCode,
          playerName: 'Charlie',
          playerId: 'p_g2'
        });

        // Only Alice contributes 1 prompt; Bob and Charlie contribute none
        await roomRef.collection('players').doc('p_host').update({
          customPrompts: ['Alice Lone Prompt'],
          lobbyReady: true
        });
        await roomRef.collection('players').doc('p_g1').update({
          customPrompts: [],
          lobbyReady: true
        });
        await roomRef.collection('players').doc('p_g2').update({
          customPrompts: [],
          lobbyReady: true
        });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'custom' });

        let roomSnap = await roomRef.get();
        let cards = roomSnap.data()?.cards as any[];
        expect(cards).to.have.lengthOf(3);
        const aliceCard = cards.find(c => c.targetPlayerId === 'p_host');
        // Alice cannot have her own prompt, so Alice gets a fallback prompt
        expect(aliceCard.promptText).to.not.equal('Alice Lone Prompt');

        // Bob re-rolls: pool has no more available non-Bob prompts, so Bob gets fallback prompt
        await callFn('rerollPrompt', guest1User.idToken, { roomCode, playerId: 'p_g1' });
        roomSnap = await roomRef.get();
        cards = roomSnap.data()?.cards as any[];
        const bobCard = cards.find(c => c.targetPlayerId === 'p_g1');
        expect(bobCard.promptText).to.be.a('string').and.not.equal('');
      });

      it('Issue 107 (J3): re-roll samples uniformly from deck excluding only in-play prompts and reaches every available prompt', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        // Derived from the catalogue, not from a deck's current size. Bob and
        // Charlie hold one prompt each for the whole run, so the host can reach
        // every other prompt in the deck across repeated re-rolls.
        const altDeckSize = PromptDecks.getDeckSize(ALT_DECK);
        const reachable = altDeckSize - 2;
        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: ALT_DECK });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');

        const observedPrompts = new Set<string>();
        const totalDraws = 100;
        let sampleCount = 0;

        for (let i = 0; i < totalDraws; i++) {
          const before = await roomRef.get();
          const cardsBefore = before.data()?.cards as any[];
          const hostCardBefore = cardsBefore.find(c => c.targetPlayerId === 'p_host');
          const otherCardsPrompts = new Set(
            cardsBefore.filter(c => c.targetPlayerId !== 'p_host').map(c => c.promptText)
          );

          await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });

          const after = await roomRef.get();
          const hostCardAfter = (after.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
          const prompt = hostCardAfter.promptText;

          // Assert Option B invariant: never hands back what is currently on the table
          expect(prompt).to.not.equal(hostCardBefore.promptText, 're-roll must visibly change current card prompt');
          expect(otherCardsPrompts.has(prompt), 're-roll must never match another player active card').to.be.false;

          observedPrompts.add(prompt);
          sampleCount++;
        }

        // Positive sample size assertion per §5.2
        expect(sampleCount).to.equal(totalDraws);
        expect(sampleCount).to.be.greaterThan(0);

        // Coverage is asserted as a FLOOR, not exact equality. Reaching every one
        // of `reachable` prompts in a fixed number of draws is a coupon-collector
        // problem: it held comfortably for the old 12-prompt deck, but at 25
        // prompts exact equality fails roughly 1 run in 130 purely by chance, and
        // a randomness test that flakes gets deleted by the next agent. A stuck or
        // biased sampler reaches 1-2 prompts, so this floor still fails loudly for
        // the defect the test exists to catch, while the per-draw assertion above
        // enforces the hard Option B guarantee on every single sample.
        expect(observedPrompts.size).to.be.at.least(Math.ceil(reachable * 0.8));
      });

      it('Issue 111 (K1): multi-round match accumulates card summaries into sealed/_summary and publishes matchSummary at game over with no mid-match leak', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        // Set totalRounds = 2
        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, totalRounds: 2, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, totalRounds: 2, selectedDeckId: FALLBACK_DECK });

        // --- ROUND 1: TRUTH PHASE ---
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth R1', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth R1', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth R1', isTruth: true });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');

        // --- ROUND 1: FORGERY PHASE ---
        const cardAssignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        // Bob writes forgery on Alice's card
        const bobTarget = cardAssignments['p_g1'];
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: bobTarget, authorId: 'p_g1', text: 'Bob Lie R1', isTruth: false });
        // Alice writes forgery on her assignment
        const aliceTarget = cardAssignments['p_host'];
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: aliceTarget, authorId: 'p_host', text: 'Alice Lie R1', isTruth: false });
        // Charlie writes forgery on his assignment
        const charlieTarget = cardAssignments['p_g2'];
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: charlieTarget, authorId: 'p_g2', text: 'Charlie Lie R1', isTruth: false });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        const allVotesCast: Array<{
          round: number;
          targetPlayerId: string;
          voterId: string;
          votedForAuthorId: string;
        }> = [];

        // --- ROUND 1: VOTE & REVEAL FOR ALL CARDS ---
        const order = roomSnap.data()?.resolutionOrder as string[];
        for (let i = 0; i < order.length; i++) {
          const currentReader = order[i];
          const curRoomSnap = await roomRef.get();
          const curCard = (curRoomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
          const options = curCard.options as Array<{ id: string; text: string }>;
          const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
          const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

          // Each voter votes for an option not authored by themself
          const voters = [
            { id: 'p_host', token: hostUser.idToken },
            { id: 'p_g1', token: guest1User.idToken },
            { id: 'p_g2', token: guest2User.idToken }
          ];

          for (const voter of voters) {
            if (voter.id !== currentReader) {
              const optToVote = options.find(o => answerAuthors[o.id] !== voter.id);
              if (optToVote) {
                const votedAuthor = answerAuthors[optToVote.id];
                allVotesCast.push({
                  round: 1,
                  targetPlayerId: currentReader,
                  voterId: voter.id,
                  votedForAuthorId: votedAuthor
                });
                await callFn('castVote', voter.token, { roomCode, targetCardId: currentReader, voterId: voter.id, votedForId: optToVote.id });
              }
            }
          }

          // Advance to reveal
          await callFn('advancePhase', hostUser.idToken, { roomCode });

          // Mid-match leak guard: room.matchSummary must be ABSENT mid-match
          const revealSnap = await roomRef.get();
          expect(revealSnap.data()?.matchSummary).to.be.undefined;

          // Advance to next resolution or next round
          await callFn('advanceToNextResolution', hostUser.idToken, { roomCode });
        }

        // Now in Round 2
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
        expect(roomSnap.data()?.currentRound).to.equal(2);
        // Leak guard: still no matchSummary on room document
        expect(roomSnap.data()?.matchSummary).to.be.undefined;

        // --- ROUND 2: TRUTH PHASE ---
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth R2', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth R2', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth R2', isTruth: true });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');

        // --- ROUND 2: FORGERY PHASE ---
        const cardAssignmentsR2 = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(cardAssignmentsR2)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? guest1User : guest2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId} in R2`, isTruth: false });
        }

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        // --- ROUND 2: VOTE & REVEAL ---
        const orderR2 = roomSnap.data()?.resolutionOrder as string[];
        for (let i = 0; i < orderR2.length; i++) {
          const currentReader = orderR2[i];
          const curRoomSnap = await roomRef.get();
          const curCard = (curRoomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
          const options = curCard.options as Array<{ id: string; text: string }>;
          const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
          const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

          const voters = [
            { id: 'p_host', token: hostUser.idToken },
            { id: 'p_g1', token: guest1User.idToken },
            { id: 'p_g2', token: guest2User.idToken }
          ];

          for (const voter of voters) {
            if (voter.id !== currentReader) {
              const optToVote = options.find(o => answerAuthors[o.id] !== voter.id);
              if (optToVote) {
                const votedAuthor = answerAuthors[optToVote.id];
                allVotesCast.push({
                  round: 2,
                  targetPlayerId: currentReader,
                  voterId: voter.id,
                  votedForAuthorId: votedAuthor
                });
                await callFn('castVote', voter.token, { roomCode, targetCardId: currentReader, voterId: voter.id, votedForId: optToVote.id });
              }
            }
          }

          await callFn('advancePhase', hostUser.idToken, { roomCode });
          await callFn('advanceToNextResolution', hostUser.idToken, { roomCode });
        }

        // Match complete! Room is now gameOver
        const finalRoomSnap = await roomRef.get();
        const finalData = finalRoomSnap.data();
        expect(finalData?.currentPhase).to.equal('gameOver');
        expect(finalData?.matchSummary).to.be.an('object');

        // Compute expected best lie fooled count independently from recorded votes:
        const forgeryVoteCounts: Record<string, number> = {};
        for (const v of allVotesCast) {
          if (v.votedForAuthorId !== v.targetPlayerId && v.voterId !== v.votedForAuthorId) {
            const key = `${v.round}:${v.targetPlayerId}:${v.votedForAuthorId}`;
            forgeryVoteCounts[key] = (forgeryVoteCounts[key] || 0) + 1;
          }
        }
        const expectedMaxFooled = Math.max(...Object.values(forgeryVoteCounts), 0);
        expect(expectedMaxFooled).to.be.greaterThan(0);

        // Assert summary details with exact equality computed from test actions
        const summary = finalData?.matchSummary;
        expect(summary.bestLie).to.be.an('object');
        expect(summary.bestLie.fooled).to.equal(expectedMaxFooled);
        expect(summary.bestLie.authorName).to.be.a('string');
        expect(summary.bestLie.text).to.be.a('string');

        expect(summary.cleanestTruth).to.be.an('object');
        expect(summary.theSting).to.be.an('object');

        // Assert sealed/_summary accumulated 6 cards (3 players x 2 rounds)
        const finalSummarySnap = await roomRef.collection('sealed').doc('_summary').get();
        expect(finalSummarySnap.exists).to.be.true;
        const recordedCards = finalSummarySnap.data()?.cards as any[];
        expect(recordedCards).to.have.lengthOf(6);
      });

      it('Issue 111 (K1): disconnect mid-round publishes matchSummary on gameOver', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Player Charlie disconnects, leaving only 2 players -> gameOver
        await callFn('handleDisconnect', guest2User.idToken, { roomCode, disconnectedPlayerId: 'p_g2' });

        const roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('gameOver');
        expect(roomSnap.data()?.matchSummary).to.be.an('object');
      });
    });

    describe('Issue 112 (M1): One shared presence threshold (PRESENCE_STALE_MS = 120_000)', () => {
      it('Site 1 (joinRoom seat re-bind): protects live seats under PRESENCE_STALE_MS and allows reclaim over PRESENCE_STALE_MS', async () => {
        const hostUser = await createAnonUser();
        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const playerRef = db.collection('rooms').doc(roomCode).collection('players').doc('p_host');
        const strangerUser = await createAnonUser();

        // 1. Boundary below PRESENCE_STALE_MS (fresh by 5s) -> stranger rejected with PERMISSION_DENIED
        await playerRef.update({ lastSeen: Date.now() - (PRESENCE_STALE_MS - 5000) });
        try {
          await callFn('joinRoom', strangerUser.idToken, {
            roomCode,
            playerName: 'Attacker',
            playerId: 'p_host'
          });
          expect.fail('Expected joinRoom to fail for non-stale seat');
        } catch (err: any) {
          if (err.name === 'AssertionError') throw err;
          expect(err.status).to.equal('PERMISSION_DENIED');
        }

        // 2. Boundary above PRESENCE_STALE_MS (stale by 5s) -> stranger succeeds in reclaiming seat
        await playerRef.update({ lastSeen: Date.now() - (PRESENCE_STALE_MS + 5000) });
        const reclaimRes = await callFn('joinRoom', strangerUser.idToken, {
          roomCode,
          playerName: 'Reclaimer',
          playerId: 'p_host'
        });
        expect(reclaimRes.role).to.equal('unassigned');
      });

      it('Site 2 (handleDisconnect isDead): rejects third-party disconnect under PRESENCE_STALE_MS and allows it over PRESENCE_STALE_MS', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });

        const g1Ref = roomRef.collection('players').doc('p_g1');

        // 1. Boundary below PRESENCE_STALE_MS (fresh by 5s) -> non-host guest2 cannot disconnect guest1
        await g1Ref.update({ lastSeen: Date.now() - (PRESENCE_STALE_MS - 5000) });
        try {
          await callFn('handleDisconnect', guest2User.idToken, {
            roomCode,
            disconnectedPlayerId: 'p_g1'
          });
          expect.fail('Expected handleDisconnect to reject third-party non-dead disconnect');
        } catch (err: any) {
          if (err.name === 'AssertionError') throw err;
          expect(err.status).to.equal('PERMISSION_DENIED');
        }

        // Verify guest1 is still present in room
        const g1Doc = await g1Ref.get();
        expect(g1Doc.exists).to.be.true;

        // 2. Boundary above PRESENCE_STALE_MS (stale by 5s) -> non-host guest2 CAN trigger disconnect on dead guest1
        await g1Ref.update({ lastSeen: Date.now() - (PRESENCE_STALE_MS + 5000) });
        const disconnectRes = await callFn('handleDisconnect', guest2User.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g1'
        });
        expect(disconnectRes.success).to.be.true;

        // Verify guest1 is now removed
        const g1DocAfter = await g1Ref.get();
        expect(g1DocAfter.exists).to.be.false;
      });

      it('Over-reach guard: below-3 auto-end still fires when player is pruned past PRESENCE_STALE_MS during active game', async () => {
        const hostUser = await createAnonUser();
        const guest1User = await createAnonUser();
        const guest2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guest1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Set Charlie as dead (> PRESENCE_STALE_MS)
        const g2Ref = roomRef.collection('players').doc('p_g2');
        await g2Ref.update({ lastSeen: Date.now() - (PRESENCE_STALE_MS + 5000) });

        // Guest1 triggers disconnect on dead Charlie -> drops room to 2 players -> auto-ends to gameOver
        await callFn('handleDisconnect', guest1User.idToken, { roomCode, disconnectedPlayerId: 'p_g2' });

        const roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('gameOver');
      });
    });

    describe('Wave O: Issue 117 / O1 - answerAuthors isolation across rounds', () => {
      it('O1: answerAuthors map contains exactly card options count in round 2 and getMyOptionId returns valid round 2 option', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();
        const g3User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 3,
          sabotageAnswersCount: 3,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await callFn('joinRoom', g3User.idToken, { roomCode, playerName: 'Dave', playerId: 'p_g3' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g3').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, totalRounds: 2, forgeriesPerCard: 3, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, totalRounds: 2, selectedDeckId: FALLBACK_DECK });

        // --- ROUND 1: TRUTH ---
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice loved eating pancakes for dinner', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob ran three marathons in Tokyo', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie built a telescope from scratch', isTruth: true });
        await callFn('submitAnswer', g3User.idToken, { roomCode, targetCardId: 'p_g3', authorId: 'p_g3', text: 'Dave adopted four stray dogs yesterday', isTruth: true });

        const lieDictionary: Record<string, string[]> = {
          p_host: ['Alice stole ancient golden coins', 'Alice climbed Mount Kilimanjaro alone', 'Alice designed a rocket engine prototype'],
          p_g1: ['Bob invented a new musical instrument', 'Bob wrestled an alligator in Florida', 'Bob slept through an earthquake'],
          p_g2: ['Charlie became a chess grandmaster', 'Charlie founded a secret social club', 'Charlie solved an unsolved math puzzle'],
          p_g3: ['Dave sailed across the Atlantic ocean', 'Dave wrote a bestselling mystery novel', 'Dave discovered a rare dinosaur fossil']
        };

        // --- ROUND 1: FORGERY (3 rotations) ---
        for (let rot = 1; rot <= 3; rot++) {
          const rSnap = await roomRef.get();
          const assignments = rSnap.data()?.currentCardAssignments as Record<string, string>;
          for (const [holderId, targetId] of Object.entries(assignments)) {
            const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : (holderId === 'p_g2' ? g2User : g3User));
            const text = lieDictionary[holderId][rot - 1] + ' r1';
            await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text, isTruth: false });
          }
        }

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        // Verify Round 1 sealed answerAuthors has 4 entries
        const r1SealedHost = await roomRef.collection('sealed').doc('p_host').get();
        const r1Authors = r1SealedHost.data()?.answerAuthors as Record<string, string>;
        expect(Object.keys(r1Authors)).to.have.lengthOf(4);

        // Advance through all 4 cards in Round 1
        const orderR1 = roomSnap.data()?.resolutionOrder as string[];
        for (let i = 0; i < orderR1.length; i++) {
          const curReader = orderR1[i];
          const curRoomSnap = await roomRef.get();
          const curCard = (curRoomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === curReader);
          const options = curCard.options as Array<{ id: string; text: string }>;
          const sealedSnap = await roomRef.collection('sealed').doc(curReader).get();
          const aAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

          const voters = [
            { id: 'p_host', token: hostUser.idToken },
            { id: 'p_g1', token: g1User.idToken },
            { id: 'p_g2', token: g2User.idToken },
            { id: 'p_g3', token: g3User.idToken }
          ];
          for (const v of voters) {
            if (v.id !== curReader) {
              const opt = options.find(o => aAuthors[o.id] !== v.id);
              if (opt) {
                await callFn('castVote', v.token, { roomCode, targetCardId: curReader, voterId: v.id, votedForId: opt.id });
              }
            }
          }
          await callFn('advancePhase', hostUser.idToken, { roomCode });
          await callFn('advanceToNextResolution', hostUser.idToken, { roomCode });
        }

        // --- ROUND 2: TRUTH ---
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
        expect(roomSnap.data()?.currentRound).to.equal(2);

        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice painted a giant mural on brick', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob learned how to fly a helicopter', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie cooked dinner for the president', isTruth: true });
        await callFn('submitAnswer', g3User.idToken, { roomCode, targetCardId: 'p_g3', authorId: 'p_g3', text: 'Dave won a gold medal in snowboarding', isTruth: true });

        // --- ROUND 2: FORGERY (3 rotations) ---
        for (let rot = 1; rot <= 3; rot++) {
          const rSnap = await roomRef.get();
          const assignments = rSnap.data()?.currentCardAssignments as Record<string, string>;
          for (const [holderId, targetId] of Object.entries(assignments)) {
            const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : (holderId === 'p_g2' ? g2User : g3User));
            const text = lieDictionary[holderId][rot - 1] + ' r2';
            await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text, isTruth: false });
          }
        }

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        // PRIMARY ASSERTION: In round 2, sealed answerAuthors MUST have exactly 4 entries (not 8)
        const r2SealedHost = await roomRef.collection('sealed').doc('p_host').get();
        const r2Authors = r2SealedHost.data()?.answerAuthors as Record<string, string>;
        expect(Object.keys(r2Authors)).to.have.lengthOf(4, 'answerAuthors must not accumulate across rounds (expected 4, found ' + Object.keys(r2Authors).length + ')');

        // SYMPTOM ASSERTION: getMyOptionId for Bob on Alice's card must return an option id PRESENT in round 2 card.options
        const r2HostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
        const r2OptionIds = (r2HostCard.options as any[]).map(o => o.id);
        const myOptionRes = await callFn('getMyOptionId', g1User.idToken, { roomCode, cardId: 'p_host', playerId: 'p_g1' });
        expect(myOptionRes.optionId).to.be.a('string');
        expect(r2OptionIds).to.include(myOptionRes.optionId, 'getMyOptionId must return an option ID from round 2 options, not stale round 1');
      });
    });

    describe('Wave O: Issue 113 / O2 - per-card score delta publishing & unmask adjustment', () => {
      it('O2: publishes per-card scoreDeltas including unmask adjustment and keeps unrevealed cards scoreDeltas sealed', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth submissions
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth Answer Unique', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth Answer Unique', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth Answer Unique', isTruth: true });

        // Forgery submissions
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        // Bob writes forgery on Alice's card (or whoever is assigned)
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Deceptive lie by ${holderId}`, isTruth: false });
        }

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        const firstReaderId = (roomSnap.data()?.resolutionOrder as string[])[0];
        const curCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === firstReaderId);
        const options = curCard.options as Array<{ id: string; text: string }>;
        const sealedSnap = await roomRef.collection('sealed').doc(firstReaderId).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

        // Find forgery option and truth option on this card
        const forgeryOpt = options.find(o => answerAuthors[o.id] !== firstReaderId);
        const truthOpt = options.find(o => answerAuthors[o.id] === firstReaderId);
        const forgerId = answerAuthors[forgeryOpt!.id];

        // Voter 1 (non-reader, non-forger) votes for forgery -> fooled
        // Voter 2 (the forger) votes for truth -> finds truth (+2)
        const otherVoterId = ['p_host', 'p_g1', 'p_g2'].find(id => id !== firstReaderId && id !== forgerId)!;
        const otherUser = otherVoterId === 'p_host' ? hostUser : (otherVoterId === 'p_g1' ? g1User : g2User);
        const forgerUser = forgerId === 'p_host' ? hostUser : (forgerId === 'p_g1' ? g1User : g2User);

        await callFn('castVote', otherUser.idToken, { roomCode, targetCardId: firstReaderId, voterId: otherVoterId, votedForId: forgeryOpt!.id });
        await callFn('castVote', forgerUser.idToken, { roomCode, targetCardId: firstReaderId, voterId: forgerId, votedForId: truthOpt!.id });

        // Advance to reveal
        await callFn('advancePhase', hostUser.idToken, { roomCode });

        let revealSnap = await roomRef.get();
        expect(revealSnap.data()?.currentPhase).to.equal('reveal');

        const revealedCards = revealSnap.data()?.cards as any[];
        const activeRevealedCard = revealedCards.find(c => c.targetPlayerId === firstReaderId);
        const unrevealedCard = revealedCards.find(c => c.targetPlayerId !== firstReaderId);

        // LEAK GUARD: unrevealed cards MUST NOT have scoreDeltas
        expect(unrevealedCard.scoreDeltas).to.be.undefined;

        // Wave P (Issue 124): scoreDeltas on active card is withheld during unmask window
        expect(activeRevealedCard.scoreDeltas == null).to.be.true;

        // Now otherVoter makes a revenge unmask guess against forgerId
        await callFn('submitUnmaskGuess', otherUser.idToken, {
          roomCode,
          guesserId: otherVoterId,
          guessedAuthorId: forgerId
        });

        // After successful unmask guess:
        // forger loses 1 (3 - 1 = 2)
        // otherVoter gains 1 (0 + 1 = 1)
        const unmaskUpdatedSnap = await roomRef.get();
        const unmaskCard = (unmaskUpdatedSnap.data()?.cards as any[]).find(c => c.targetPlayerId === firstReaderId);
        expect(unmaskCard.scoreDeltas[forgerId]).to.equal(2, 'Forger net delta must include -1 unmask penalty');
        expect(unmaskCard.scoreDeltas[otherVoterId]).to.equal(1, 'Guesser net delta must include +1 unmask reward');
      });
    });

    describe('Wave O: Issue 115 / O3 - player name snapshotting in match summary', () => {
      it('O3: snapshots player names so departed players display names appear in match highlights at game over', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'BobDeceiver', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'CharlieVictim', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth submissions
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth Answer 12345', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth Answer 12345', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth Answer 12345', isTruth: true });

        // Forgery submissions
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Deceptive lie by ${holderId}`, isTruth: false });
        }

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        const firstReaderId = (roomSnap.data()?.resolutionOrder as string[])[0];
        const curCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === firstReaderId);
        const options = curCard.options as Array<{ id: string; text: string }>;
        const sealedSnap = await roomRef.collection('sealed').doc(firstReaderId).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

        const forgeryOpt = options.find(o => answerAuthors[o.id] !== firstReaderId);
        const truthOpt = options.find(o => answerAuthors[o.id] === firstReaderId);
        const forgerId = answerAuthors[forgeryOpt!.id];

        const otherVoterId = ['p_host', 'p_g1', 'p_g2'].find(id => id !== firstReaderId && id !== forgerId)!;
        const otherUser = otherVoterId === 'p_host' ? hostUser : (otherVoterId === 'p_g1' ? g1User : g2User);
        const forgerUser = forgerId === 'p_host' ? hostUser : (forgerId === 'p_g1' ? g1User : g2User);

        await callFn('castVote', otherUser.idToken, { roomCode, targetCardId: firstReaderId, voterId: otherVoterId, votedForId: forgeryOpt!.id });
        await callFn('castVote', forgerUser.idToken, { roomCode, targetCardId: firstReaderId, voterId: forgerId, votedForId: truthOpt!.id });

        // Advance to reveal so card summary is accumulated into sealed/_summary
        await callFn('advancePhase', hostUser.idToken, { roomCode });

        // Now the forger leaves the game (disconnect / handleDisconnect)
        await callFn('handleDisconnect', forgerUser.idToken, {
          roomCode,
          disconnectedPlayerId: forgerId
        });

        // Player doc for forgerId has been deleted from players collection
        const forgerDoc = await roomRef.collection('players').doc(forgerId).get();
        expect(forgerDoc.exists).to.be.false;

        // Advance through remaining resolution until game over
        const afterLeaveSnap = await roomRef.get();
        const phaseAfterLeave = afterLeaveSnap.data()?.currentPhase;
        if (phaseAfterLeave !== 'gameOver') {
          // If 2 players remain, advance resolution to game over
          await callFn('advancePhase', hostUser.idToken, { roomCode });
        }

        const gameOverSnap = await roomRef.get();
        expect(gameOverSnap.data()?.currentPhase).to.equal('gameOver');
        const matchSummary = gameOverSnap.data()?.matchSummary;
        expect(matchSummary).to.be.an('object');
        expect(matchSummary.bestLie).to.be.an('object');
        expect(matchSummary.bestLie.authorId).to.equal(forgerId);
        // Author name MUST be snapshotted display name, NOT the UUID and NOT "Unknown"
        const expectedName = forgerId === 'p_host' ? 'AliceHost' : (forgerId === 'p_g1' ? 'BobDeceiver' : 'CharlieVictim');
        expect(matchSummary.bestLie.authorName).to.equal(expectedName);
      });
    });

    describe('Wave O: Issue 118 / O4 - placeholder votes rejected & all-placeholder cards skipped', () => {
      it('O4: castVote throws invalid-argument when voting for a placeholder answer', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase: all time out (all become placeholders)
        await callFn('advancePhase', hostUser.idToken, { roomCode });
        
        // Forgery phase: find who is assigned to p_host and submit real forgery
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        const forgerId = Object.keys(assignments).find(holderId => assignments[holderId] === 'p_host')!;
        const forgerUser = forgerId === 'p_host' ? hostUser : (forgerId === 'p_g1' ? g1User : g2User);
        await callFn('submitAnswer', forgerUser.idToken, { roomCode, targetCardId: 'p_host', authorId: forgerId, text: 'Real Forgery', isTruth: false });
        await callFn('advancePhase', hostUser.idToken, { roomCode });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        const aliceCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
        const options = aliceCard.options as Array<{ id: string; text: string }>;
        const placeholderOpt = options.find(o => o.text === 'THE SOUL IS SILENT')!;
        expect(placeholderOpt).to.exist;

        const voterId = ['p_host', 'p_g1', 'p_g2'].find(id => id !== 'p_host' && id !== forgerId)!;
        const voterUser = voterId === 'p_host' ? hostUser : (voterId === 'p_g1' ? g1User : g2User);

        let errorCaught = false;
        try {
          await callFn('castVote', voterUser.idToken, {
            roomCode,
            targetCardId: 'p_host',
            voterId,
            votedForId: placeholderOpt.id
          });
        } catch (e: any) {
          errorCaught = true;
          expect(e.message).to.include('Cannot vote for a placeholder answer');
        }
        expect(errorCaught).to.be.true;
      });

      it('O4: skips card from resolutionOrder when all options on the card are placeholders', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase: Alice and Bob write truths, Charlie times out
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('advancePhase', hostUser.idToken, { roomCode });

        // Forgery phase: Alice writes for Bob, Bob writes for Alice, nobody writes for Charlie
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          if (targetId !== 'p_g2') {
            const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
            await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
          }
        }
        await callFn('advancePhase', hostUser.idToken, { roomCode });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const resolutionOrder = roomSnap.data()?.resolutionOrder as string[];
        // Charlie's card has 100% placeholder options (both truth and forgeries were missing), so it must be skipped from resolutionOrder
        expect(resolutionOrder).to.not.include('p_g2');
        expect(resolutionOrder.length).to.equal(2);
      });
    });

    describe('Wave P: Issue 123 / P3 - server enforces 10-minute presence window', () => {
      it('P3: presence window protects player seen 150s ago (inside 10-minute window)', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Set Bob's lastSeen to 150 seconds ago (inside 10-minute window)
        const recentLastSeen = Date.now() - 150_000;
        await roomRef.collection('players').doc('p_g1').update({ lastSeen: recentLastSeen });

        // Host calls handleDisconnect with reason: 'presence'
        const res = await callFn('handleDisconnect', hostUser.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g1',
          reason: 'presence'
        });

        expect(res.success).to.be.false;
        expect(res.reason).to.equal('still-present');

        // Bob's player document still exists
        const bobSnap = await roomRef.collection('players').doc('p_g1').get();
        expect(bobSnap.exists).to.be.true;
      });

      it('P3: presence window evicts player stale by 601s', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Set Bob's lastSeen to 601 seconds ago
        const staleLastSeen = Date.now() - 601_000;
        await roomRef.collection('players').doc('p_g1').update({ lastSeen: staleLastSeen });

        const res = await callFn('handleDisconnect', hostUser.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g1',
          reason: 'presence'
        });

        expect(res.success).to.be.true;
        const bobSnap = await roomRef.collection('players').doc('p_g1').get();
        expect(bobSnap.exists).to.be.false;
      });

      it('P3: leave reason removes player immediately even when seen 1s ago', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Bob leaves voluntarily
        const res = await callFn('handleDisconnect', g1User.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g1',
          reason: 'leave'
        });

        expect(res.success).to.be.true;
        const bobSnap = await roomRef.collection('players').doc('p_g1').get();
        expect(bobSnap.exists).to.be.false;
      });

      it('P3: kick reason by host removes player immediately even when seen 1s ago', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Host kicks Bob
        const res = await callFn('handleDisconnect', hostUser.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g1',
          reason: 'kick'
        });

        expect(res.success).to.be.true;
        const bobSnap = await roomRef.collection('players').doc('p_g1').get();
        expect(bobSnap.exists).to.be.false;
      });

      it('P3: peer calling presence on fresh player is rejected with permission-denied', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Charlie tries to call handleDisconnect on Bob with reason: 'presence' when Bob is fresh
        let errorCaught = false;
        try {
          await callFn('handleDisconnect', g2User.idToken, {
            roomCode,
            disconnectedPlayerId: 'p_g1',
            reason: 'presence'
          });
        } catch (e: any) {
          errorCaught = true;
          expect(e.message).to.include('Not authorized');
        }
        expect(errorCaught).to.be.true;
      });

      it('P3: reconcile cleans up card when player document is already gone', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Delete Bob's player document directly in Firestore to simulate external cleanup
        await roomRef.collection('players').doc('p_g1').delete();

        // Host calls handleDisconnect with reason: 'reconcile'
        const res = await callFn('handleDisconnect', hostUser.idToken, {
          roomCode,
          disconnectedPlayerId: 'p_g1',
          reason: 'reconcile'
        });

        expect(res.success).to.be.true;
        const roomSnap = await roomRef.get();
        const cardTargetIds = (roomSnap.data()?.cards || []).map((c: any) => c.targetPlayerId);
        expect(cardTargetIds).to.not.include('p_g1');
      });
    });

    describe('Wave O: Issue 121 / O9 - target cannot vote on own card', () => {
      it('O9: castVote rejects vote submission when voterId is targetCardId', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        // Forgery phase
        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
        }

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const currentReader = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        const anOptionId = currentCard.options[0].id;

        // Target tries to vote on their own card
        const targetUser = currentReader === 'p_host' ? hostUser : (currentReader === 'p_g1' ? g1User : g2User);
        let errorCaught = false;
        try {
          await callFn('castVote', targetUser.idToken, {
            roomCode,
            targetCardId: currentReader,
            voterId: currentReader,
            votedForId: anOptionId
          });
        } catch (e: any) {
          errorCaught = true;
          expect(e.message).to.include('Self-voting is not allowed');
        }
        expect(errorCaught).to.be.true;
      });
    });

    describe('Wave P: Issue 125 / P2 - empty resolution order skips vote phase', () => {
      it('P2: skips vote phase directly to gameOver when all cards in round 1 are placeholders', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase: nobody submits -> advance to forgery (fills missing truth with placeholder)
        await callFn('advancePhase', hostUser.idToken, { roomCode });
        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');

        // Forgery phase: nobody submits -> advance
        await callFn('advancePhase', hostUser.idToken, { roomCode });
        roomSnap = await roomRef.get();

        // Must skip vote phase and go directly to gameOver because all cards are placeholders
        expect(roomSnap.data()?.currentPhase).to.equal('gameOver');
        expect(roomSnap.data()?.currentReaderId == null).to.be.true;
      });

      it('P2: multi-round: skips empty vote phase directly to round 2 truth phase', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 2,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Round 1 Truth: nobody submits -> advance to forgery
        await callFn('advancePhase', hostUser.idToken, { roomCode });
        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');

        // Round 1 Forgery: nobody submits -> advance
        await callFn('advancePhase', hostUser.idToken, { roomCode });
        roomSnap = await roomRef.get();

        // Must advance directly to round 2 truth phase
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
        expect(roomSnap.data()?.currentRound).to.equal(2);
        expect(roomSnap.data()?.cards.length).to.equal(3);
      });
    });

    describe('Wave P: Issue 124 / P4 - score delta withholding during unmask window', () => {
      it('P4: withholds score deltas and player score updates until closeUnmaskWindow is called', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        // Forgery phase
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
        }

        // Vote phase
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const currentReader = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);

        // Find the forgery option on current card
        const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;
        const forgeryOpt = currentCard.options.find((o: any) => answerAuthors[o.id] !== currentReader);
        const truthOpt = currentCard.options.find((o: any) => answerAuthors[o.id] === currentReader);

        const voters = ['p_host', 'p_g1', 'p_g2'].filter(id => id !== currentReader);
        const forgerId = answerAuthors[forgeryOpt.id];
        // Voter 1 falls for forgery (fooled)
        const voter1Id = voters.find(id => id !== forgerId)!;
        const voter1User = voter1Id === 'p_host' ? hostUser : (voter1Id === 'p_g1' ? g1User : g2User);
        await callFn('castVote', voter1User.idToken, { roomCode, targetCardId: currentReader, voterId: voter1Id, votedForId: forgeryOpt.id });

        // Voter 2 (forger) votes for truth
        const voter2Id = forgerId;
        const voter2User = voter2Id === 'p_host' ? hostUser : (voter2Id === 'p_g1' ? g1User : g2User);
        await callFn('castVote', voter2User.idToken, { roomCode, targetCardId: currentReader, voterId: voter2Id, votedForId: truthOpt.id });

        // Target calls setReady to transition to reveal
        const targetUser = currentReader === 'p_host' ? hostUser : (currentReader === 'p_g1' ? g1User : g2User);
        await callFn('setReady', targetUser.idToken, { roomCode, playerId: currentReader, ready: true });

        // Reveal phase: unmask window is open because voter 1 was fooled!
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');
        expect(roomSnap.data()?.unmaskDeadline).to.be.greaterThan(0);

        const revealCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        // Falsifying assertion: scoreDeltas is withheld (absent/null) on the public card
        expect(revealCard.scoreDeltas == null).to.be.true;

        // Player totalScores are unchanged (still 0)
        let playersSnap = await roomRef.collection('players').get();
        for (const pDoc of playersSnap.docs) {
          expect(pDoc.data().totalScore || 0).to.equal(0);
        }

        // Sealed subcollection doc contains pendingScoreDeltas
        const sealedDuringUnmask = await roomRef.collection('sealed').doc(currentReader).get();
        expect(sealedDuringUnmask.data()?.pendingScoreDeltas).to.not.be.undefined;

        // Now host calls closeUnmaskWindow after deadline expires
        await roomRef.update({ unmaskDeadline: Date.now() - 1000 });
        const closeRes = await callFn('closeUnmaskWindow', hostUser.idToken, { roomCode });
        expect(closeRes.success).to.be.true;

        // Assert public card now has scoreDeltas populated
        roomSnap = await roomRef.get();
        const closedCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        expect(closedCard.scoreDeltas).to.not.be.undefined;
        expect(closedCard.scoreDeltas[forgerId]).to.be.greaterThan(0);

        // Assert player scores reflect the flushed deltas
        playersSnap = await roomRef.collection('players').get();
        const forgerDoc = playersSnap.docs.find(d => d.id === forgerId);
        expect(forgerDoc?.data().totalScore).to.be.greaterThan(0);

        // Assert pendingScoreDeltas is deleted from sealed doc
        const sealedAfterClose = await roomRef.collection('sealed').doc(currentReader).get();
        expect(sealedAfterClose.data()?.pendingScoreDeltas).to.be.undefined;
      });

      it('P4: flushes score deltas and applies bonuses when all fooled players submit unmask guess', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        // Forgery phase
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
        }

        // Vote phase
        roomSnap = await roomRef.get();
        const currentReader = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);

        const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;
        const forgeryOpt = currentCard.options.find((o: any) => answerAuthors[o.id] !== currentReader);
        const truthOpt = currentCard.options.find((o: any) => answerAuthors[o.id] === currentReader);

        const voters = ['p_host', 'p_g1', 'p_g2'].filter(id => id !== currentReader);
        const forgerId = answerAuthors[forgeryOpt.id];
        const voter1Id = voters.find(id => id !== forgerId)!;
        const voter1User = voter1Id === 'p_host' ? hostUser : (voter1Id === 'p_g1' ? g1User : g2User);
        await callFn('castVote', voter1User.idToken, { roomCode, targetCardId: currentReader, voterId: voter1Id, votedForId: forgeryOpt.id });

        const voter2Id = forgerId;
        const voter2User = voter2Id === 'p_host' ? hostUser : (voter2Id === 'p_g1' ? g1User : g2User);
        await callFn('castVote', voter2User.idToken, { roomCode, targetCardId: currentReader, voterId: voter2Id, votedForId: truthOpt.id });

        const targetUser = currentReader === 'p_host' ? hostUser : (currentReader === 'p_g1' ? g1User : g2User);
        await callFn('setReady', targetUser.idToken, { roomCode, playerId: currentReader, ready: true });

        // Reveal phase: score deltas withheld
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');

        // Fooled voter submits correct unmask guess
        const unmaskRes = await callFn('submitUnmaskGuess', voter1User.idToken, {
          roomCode,
          guesserId: voter1Id,
          guessedAuthorId: forgerId
        });
        expect(unmaskRes.success).to.be.true;

        // Since voter1 was the only fooled voter, unmask window closes and flushes deltas immediately
        roomSnap = await roomRef.get();
        const revealedCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        expect(revealedCard.scoreDeltas).to.not.be.undefined;
        expect(revealedCard.scoreDeltas[voter1Id]).to.equal(1); // unmask bonus
      });

      it('P4: publishes score deltas immediately when nobody is fooled', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        // Forgery phase
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
        }

        // Vote phase: both voters vote for truth
        roomSnap = await roomRef.get();
        const currentReader = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);

        const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;
        const truthOpt = currentCard.options.find((o: any) => answerAuthors[o.id] === currentReader);

        const voters = ['p_host', 'p_g1', 'p_g2'].filter(id => id !== currentReader);
        for (const vId of voters) {
          const user = vId === 'p_host' ? hostUser : (vId === 'p_g1' ? g1User : g2User);
          await callFn('castVote', user.idToken, { roomCode, targetCardId: currentReader, voterId: vId, votedForId: truthOpt.id });
        }

        const targetUser = currentReader === 'p_host' ? hostUser : (currentReader === 'p_g1' ? g1User : g2User);
        await callFn('setReady', targetUser.idToken, { roomCode, playerId: currentReader, ready: true });

        // Reveal phase: nobody fooled -> unmaskDeadline is null, scoreDeltas published immediately
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');
        expect(roomSnap.data()?.unmaskDeadline).to.be.null;

        const revealCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        expect(revealCard.scoreDeltas).to.not.be.undefined;
        expect(revealCard.scoreDeltas[voters[0]]).to.be.greaterThan(0);
      });
    });

    describe('Issue 130 (P5): Casual mode default & configurable timer durations', () => {
      it('createRoom defaults to isTimerDisabled: true and endTime is null on game start', async () => {
        const hostUser = await createAnonUser();
        const guestUser = await createAnonUser();
        const guest2User = await createAnonUser();
        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host'
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        let snap = await roomRef.get();
        expect(snap.data()?.isTimerDisabled).to.be.true;
        expect(snap.data()?.timerSeconds).to.equal(60);

        await callFn('joinRoom', guestUser.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        snap = await roomRef.get();
        expect(snap.data()?.endTime).to.be.null;
      });

      it('rejects timerSeconds outside 15-300 and accepts valid boundaries 15 and 300', async () => {
        const hostUser = await createAnonUser();
        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host'
        });
        const roomCode = createRes.roomCode;

        // Rejected: 14 and 301
        let err14 = false;
        try {
          await callFn('updateLobbySettings', hostUser.idToken, { roomCode, timerSeconds: 14 });
        } catch (e: any) {
          err14 = true;
          expect(e.status).to.equal('INVALID_ARGUMENT');
        }
        expect(err14).to.be.true;

        let err301 = false;
        try {
          await callFn('updateLobbySettings', hostUser.idToken, { roomCode, timerSeconds: 301 });
        } catch (e: any) {
          err301 = true;
          expect(e.status).to.equal('INVALID_ARGUMENT');
        }
        expect(err301).to.be.true;

        // Accepted: 15 and 300
        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, timerSeconds: 15 });
        let snap = await db.collection('rooms').doc(roomCode).get();
        expect(snap.data()?.timerSeconds).to.equal(15);

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, timerSeconds: 300 });
        snap = await db.collection('rooms').doc(roomCode).get();
        expect(snap.data()?.timerSeconds).to.equal(300);
      });

      it('derives truth/forgery at 100% and vote at 75% when timers are enabled', async () => {
        const hostUser = await createAnonUser();
        const guestUser = await createAnonUser();
        const guest2User = await createAnonUser();
        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'Alice',
          playerId: 'p_host',
          isTimerDisabled: false,
          timerSeconds: 40,
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', guestUser.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', guest2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        const nowBefore = Date.now();
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        let snap = await roomRef.get();

        // Truth phase: ~40s (40000ms)
        const truthEndTime = snap.data()?.endTime;
        expect(truthEndTime).to.be.a('number');
        const truthDiff = truthEndTime - nowBefore;
        expect(truthDiff).to.be.within(37000, 44000);

        // Submit truths
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice painted a red sailboat on canvas', isTruth: true });
        await callFn('submitAnswer', guestUser.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob baked twelve chocolate muffins yesterday', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie climbed a snowy mountain in winter', isTruth: true });

        // Forgery rotation 1: ~40s
        const nowForgery = Date.now();
        snap = await roomRef.get();
        expect(snap.data()?.currentPhase).to.equal('forgery');
        const forgeryEndTime = snap.data()?.endTime;
        expect(forgeryEndTime).to.be.a('number');
        const forgeryDiff = forgeryEndTime - nowForgery;
        expect(forgeryDiff).to.be.within(37000, 44000);

        // Submit forgeries (forgery rotation 1 and 2)
        const lieSentences: Record<string, string[]> = {
          'p_host': ['Alice rode an elephant through the jungle', 'Alice swam across the wide blue lake'],
          'p_g1': ['Bob repaired an ancient wooden grandfather clock', 'Bob planted giant sunflowers along the garden fence'],
          'p_g2': ['Charlie played acoustic guitar in the village tavern', 'Charlie caught three rainbow trout in the river'],
        };
        for (let rot = 1; rot <= 2; rot++) {
          const rSnap = await roomRef.get();
          const assignments = rSnap.data()?.currentCardAssignments as Record<string, string>;
          for (const [holderId, targetId] of Object.entries(assignments)) {
            const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? guestUser : guest2User);
            const text = lieSentences[holderId][rot - 1];
            await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text, isTruth: false });
          }
        }

        // Vote phase: ~30s (75% of 40s = 30000ms)
        const nowVote = Date.now();
        snap = await roomRef.get();
        expect(snap.data()?.currentPhase).to.equal('vote');
        const voteEndTime = snap.data()?.endTime;
        expect(voteEndTime).to.be.a('number');
        const voteDiff = voteEndTime - nowVote;
        expect(voteDiff).to.be.within(27000, 34000);
      });
    });

    describe('Wave Q: Issue 133 / Q1 - closeUnmaskWindow deadline guard and permissions', () => {
      async function setupRevealWithFooledPlayer() {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        // Forgery phase
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
        }

        // Vote phase
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const currentReader = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);

        const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;
        const forgeryOpt = currentCard.options.find((o: any) => answerAuthors[o.id] !== currentReader);
        const truthOpt = currentCard.options.find((o: any) => answerAuthors[o.id] === currentReader);

        const voters = ['p_host', 'p_g1', 'p_g2'].filter(id => id !== currentReader);
        const forgerId = answerAuthors[forgeryOpt.id];
        // Voter 1 falls for forgery (fooled)
        const voter1Id = voters.find(id => id !== forgerId)!;
        const voter1User = voter1Id === 'p_host' ? hostUser : (voter1Id === 'p_g1' ? g1User : g2User);
        await callFn('castVote', voter1User.idToken, { roomCode, targetCardId: currentReader, voterId: voter1Id, votedForId: forgeryOpt.id });

        // Voter 2 (forger) votes for truth
        const voter2Id = forgerId;
        const voter2User = voter2Id === 'p_host' ? hostUser : (voter2Id === 'p_g1' ? g1User : g2User);
        await callFn('castVote', voter2User.idToken, { roomCode, targetCardId: currentReader, voterId: voter2Id, votedForId: truthOpt.id });

        // Target calls setReady to transition to reveal
        const targetUser = currentReader === 'p_host' ? hostUser : (currentReader === 'p_g1' ? g1User : g2User);
        await callFn('setReady', targetUser.idToken, { roomCode, playerId: currentReader, ready: true });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');

        return {
          hostUser,
          g1User,
          g2User,
          roomCode,
          roomRef,
          currentReader,
          forgerId,
          fooledVoterId: voter1Id,
          fooledVoterUser: voter1User,
          truthVoterId: voter2Id,
          truthVoterUser: voter2User
        };
      }

      it('F1 — the fix: refuses early close with failed-precondition and leaves deltas and deadline unchanged', async () => {
        const { roomRef, roomCode, currentReader, fooledVoterUser } = await setupRevealWithFooledPlayer();

        const roomSnap = await roomRef.get();
        const initialDeadline = roomSnap.data()?.unmaskDeadline;
        expect(initialDeadline).to.be.greaterThan(Date.now());

        let threw = false;
        try {
          await callFn('closeUnmaskWindow', fooledVoterUser.idToken, { roomCode });
        } catch (e: any) {
          threw = true;
          expect(e.message).to.include('The unmask window has not expired yet');
        }
        expect(threw).to.be.true;

        const freshSnap = await roomRef.get();
        const card = (freshSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        expect(card.scoreDeltas).to.be.undefined;
        expect(freshSnap.data()?.unmaskDeadline).to.equal(initialDeadline);
      });

      it('F2 — the happy path still works when deadline is in the past', async () => {
        const { roomRef, roomCode, currentReader, forgerId, fooledVoterUser } = await setupRevealWithFooledPlayer();

        await roomRef.update({ unmaskDeadline: Date.now() - 1000 });
        const res = await callFn('closeUnmaskWindow', fooledVoterUser.idToken, { roomCode });
        expect(res.success).to.be.true;

        const freshSnap = await roomRef.get();
        expect(freshSnap.data()?.unmaskDeadline).to.equal(0);
        const card = (freshSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        expect(card.scoreDeltas).to.not.be.undefined;
        expect(card.scoreDeltas[forgerId]).to.be.greaterThan(0);
      });

      it('F3 — idempotency: double-call applies scores exactly once by arithmetic', async () => {
        const { roomRef, roomCode, forgerId, truthVoterId, fooledVoterId, g1User, g2User } = await setupRevealWithFooledPlayer();

        await roomRef.update({ unmaskDeadline: Date.now() - 1000 });
        const res1 = await callFn('closeUnmaskWindow', g1User.idToken, { roomCode });
        expect(res1.success).to.be.true;

        const res2 = await callFn('closeUnmaskWindow', g2User.idToken, { roomCode });
        expect(res2.success).to.be.true;
        expect(res2.alreadyClosed).to.be.true;

        const playersSnap = await roomRef.collection('players').get();
        const forgerDoc = playersSnap.docs.find(d => d.id === forgerId);
        const truthVoterDoc = playersSnap.docs.find(d => d.id === truthVoterId);
        const fooledVoterDoc = playersSnap.docs.find(d => d.id === fooledVoterId);

        // Forger got +1 for fooling + 2 for finding truth = 3
        expect(forgerDoc?.data().totalScore).to.equal(3);
        // Truth voter (forger also found truth)
        expect(truthVoterDoc?.data().totalScore).to.equal(3);
        // Fooled voter got 0
        expect(fooledVoterDoc?.data().totalScore || 0).to.equal(0);
      });

      it('F4 — concurrency: simultaneous calls apply scores exactly once', async () => {
        const { roomRef, roomCode, forgerId, hostUser, g1User } = await setupRevealWithFooledPlayer();

        await roomRef.update({ unmaskDeadline: Date.now() - 1000 });
        const results = await Promise.all([
          callFn('closeUnmaskWindow', g1User.idToken, { roomCode }),
          callFn('closeUnmaskWindow', hostUser.idToken, { roomCode })
        ]);

        expect(results[0].success).to.be.true;
        expect(results[1].success).to.be.true;

        const playersSnap = await roomRef.collection('players').get();
        const forgerDoc = playersSnap.docs.find(d => d.id === forgerId);
        expect(forgerDoc?.data().totalScore).to.equal(3);
      });

      it('F5 — over-reach guard: non-member rejected with permission-denied', async () => {
        const { roomRef, roomCode } = await setupRevealWithFooledPlayer();
        const outsider = await createAnonUser();

        // While window is open
        let threwOpen = false;
        try {
          await callFn('closeUnmaskWindow', outsider.idToken, { roomCode });
        } catch (e: any) {
          threwOpen = true;
          expect(e.message).to.include('Caller is not in this room');
        }
        expect(threwOpen).to.be.true;

        // After window expires
        await roomRef.update({ unmaskDeadline: Date.now() - 1000 });
        let threwExpired = false;
        try {
          await callFn('closeUnmaskWindow', outsider.idToken, { roomCode });
        } catch (e: any) {
          threwExpired = true;
          expect(e.message).to.include('Caller is not in this room');
        }
        expect(threwExpired).to.be.true;
      });

      it('F6 — over-reach guard: nobody-fooled card keeps published deltas and returns alreadyClosed', async () => {
        const hostUser = await createAnonUser();
        const g1User = await createAnonUser();
        const g2User = await createAnonUser();

        const createRes = await callFn('createRoom', hostUser.idToken, {
          playerName: 'AliceHost',
          playerId: 'p_host',
          forgeriesPerCard: 1,
          sabotageAnswersCount: 1,
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1User.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2User.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await roomRef.collection('players').doc('p_g1').update({ lobbyReady: true });
        await roomRef.collection('players').doc('p_g2').update({ lobbyReady: true });

        await callFn('updateLobbySettings', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: FALLBACK_DECK });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', g1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', g2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        // Forgery phase
        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
        for (const [holderId, targetId] of Object.entries(assignments)) {
          const user = holderId === 'p_host' ? hostUser : (holderId === 'p_g1' ? g1User : g2User);
          await callFn('submitAnswer', user.idToken, { roomCode, targetCardId: targetId, authorId: holderId, text: `Lie by ${holderId}`, isTruth: false });
        }

        // Vote phase: ALL voters vote for truth (nobody is fooled)
        roomSnap = await roomRef.get();
        const currentReader = roomSnap.data()?.currentReaderId as string;
        const currentCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);

        const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;
        const truthOpt = currentCard.options.find((o: any) => answerAuthors[o.id] === currentReader);

        const voters = ['p_host', 'p_g1', 'p_g2'].filter(id => id !== currentReader);
        for (const vId of voters) {
          const u = vId === 'p_host' ? hostUser : (vId === 'p_g1' ? g1User : g2User);
          await callFn('castVote', u.idToken, { roomCode, targetCardId: currentReader, voterId: vId, votedForId: truthOpt.id });
        }

        const targetUser = currentReader === 'p_host' ? hostUser : (currentReader === 'p_g1' ? g1User : g2User);
        await callFn('setReady', targetUser.idToken, { roomCode, playerId: currentReader, ready: true });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');
        expect(roomSnap.data()?.unmaskDeadline == null).to.be.true;

        const revealCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        const originalDeltas = { ...revealCard.scoreDeltas };
        expect(Object.keys(originalDeltas).length).to.be.greaterThan(0);

        const res = await callFn('closeUnmaskWindow', hostUser.idToken, { roomCode });
        expect(res.success).to.be.true;
        expect(res.alreadyClosed).to.be.true;

        const freshSnap = await roomRef.get();
        const afterCard = (freshSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
        expect(afterCard.scoreDeltas).to.deep.equal(originalDeltas);
      });

      it('F7 — over-reach guard: advanceToNextResolution still flushes pending deltas during an open window', async () => {
        const { roomRef, roomCode, forgerId, hostUser } = await setupRevealWithFooledPlayer();

        const roomSnap = await roomRef.get();
        expect(roomSnap.data()?.unmaskDeadline).to.be.greaterThan(Date.now());

        // Host advances during open unmask window
        await callFn('advanceToNextResolution', hostUser.idToken, { roomCode });

        const playersSnap = await roomRef.collection('players').get();
        const forgerDoc = playersSnap.docs.find(d => d.id === forgerId);
        expect(forgerDoc?.data().totalScore).to.equal(3);
      });
    });

    describe('Wave Q2 — 5-Player Emulator Pre-Flight (§4.4)', () => {
      it('should complete a 5-player match with default 4 forgeries per card and 5 options per card', async () => {
        const p1 = await createAnonUser();
        const p2 = await createAnonUser();
        const p3 = await createAnonUser();
        const p4 = await createAnonUser();
        const p5 = await createAnonUser();

        const users = [
          { id: 'p1', name: 'Alice', user: p1 },
          { id: 'p2', name: 'Bob', user: p2 },
          { id: 'p3', name: 'Charlie', user: p3 },
          { id: 'p4', name: 'Dana', user: p4 },
          { id: 'p5', name: 'Erin', user: p5 }
        ];

        const createRes = await callFn('createRoom', p1.idToken, {
          playerName: 'Alice',
          playerId: 'p1',
          totalRounds: 1,
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        for (let i = 1; i < users.length; i++) {
          await callFn('joinRoom', users[i].user.idToken, {
            roomCode,
            playerName: users[i].name,
            playerId: users[i].id
          });
          await roomRef.collection('players').doc(users[i].id).update({ lobbyReady: true });
        }

        await callFn('updateLobbySettings', p1.idToken, {
          roomCode,
          selectedDeckId: FALLBACK_DECK
        });

        await callFn('startGame', p1.idToken, {
          roomCode,
          selectedDeckId: FALLBACK_DECK
        });

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
        expect(roomSnap.data()?.forgeriesPerCard).to.equal(4);

        // 1. Submit Truths
        const truths: Record<string, string> = {
          p1: 'Alice baked fresh sourdough bread',
          p2: 'Bob climbed Mount Everest in winter',
          p3: 'Charlie sailed across Atlantic Ocean',
          p4: 'Dana played cello in symphony orchestra',
          p5: 'Erin won the national marathon championship'
        };
        for (const u of users) {
          await callFn('submitAnswer', u.user.idToken, {
            roomCode,
            targetCardId: u.id,
            authorId: u.id,
            text: truths[u.id],
            isTruth: true
          });
        }

        // 2. Submit 4 rotations of Forgeries
        const forgeries: Record<string, string[]> = {
          p1: ['wrestled grizzly bear', 'discovered ancient ruins', 'painted Mona Lisa', 'drank molten lava'],
          p2: ['ate ghost peppers', 'skydived without parachute', 'trained wild falcons', 'swallowed fiery swords'],
          p3: ['jumped over canyons', 'dug underground tunnel', 'rode giant whales', 'caught falling meteors'],
          p4: ['tamed golden eagles', 'built wooden rocket', 'drank ocean water', 'flew supersonic jets'],
          p5: ['mined shiny diamonds', 'danced with wolves', 'survived volcanic eruption', 'walked across Antarctica']
        };

        for (let rotation = 0; rotation < 4; rotation++) {
          roomSnap = await roomRef.get();
          expect(roomSnap.data()?.currentPhase).to.equal('forgery');
          const assignments = roomSnap.data()?.currentCardAssignments as Record<string, string>;
          expect(Object.keys(assignments)).to.have.lengthOf(5);

          for (const u of users) {
            const targetId = assignments[u.id];
            expect(targetId).to.be.ok;
            expect(targetId).to.not.equal(u.id);
            await callFn('submitAnswer', u.user.idToken, {
              roomCode,
              targetCardId: targetId,
              authorId: u.id,
              text: forgeries[u.id][rotation],
              isTruth: false
            });
          }
        }

        // 3. Resolution rounds
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const resolutionOrder = roomSnap.data()?.resolutionOrder as string[];
        expect(resolutionOrder).to.have.lengthOf(5);

        for (let cardIdx = 0; cardIdx < resolutionOrder.length; cardIdx++) {
          roomSnap = await roomRef.get();
          expect(roomSnap.data()?.currentPhase).to.equal('vote');
          const currentReader = roomSnap.data()?.currentReaderId as string;
          expect(currentReader).to.equal(resolutionOrder[cardIdx]);

          const card = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === currentReader);
          expect(card.options).to.have.lengthOf(5);

          const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
          const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;

          // All non-reader players vote for an option they did not author
          const voters = users.filter(u => u.id !== currentReader);
          for (const v of voters) {
            const validOption = card.options.find((opt: any) => answerAuthors[opt.id] !== v.id);
            await callFn('castVote', v.user.idToken, {
              roomCode,
              targetCardId: currentReader,
              voterId: v.id,
              votedForId: validOption.id
            });
          }

          // Reader readies up
          const readerUser = users.find(u => u.id === currentReader)!;
          await callFn('setReady', readerUser.user.idToken, {
            roomCode,
            playerId: currentReader,
            ready: true
          });

          roomSnap = await roomRef.get();
          expect(roomSnap.data()?.currentPhase).to.equal('reveal');

          // Advance resolution
          await callFn('advanceToNextResolution', p1.idToken, { roomCode });
        }

        // 4. Verify GameOver and Card author uniqueness
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('gameOver');

        const finalCards = roomSnap.data()?.cards as any[];
        expect(finalCards).to.have.lengthOf(5);

        for (const card of finalCards) {
          expect(card.options).to.have.lengthOf(5);
          const sealedSnap = await roomRef.collection('sealed').doc(card.targetPlayerId).get();
          const answerAuthors = sealedSnap.data()?.answerAuthors as Record<string, string>;
          const authors = card.options.map((opt: any) => answerAuthors[opt.id]);
          const uniqueAuthors = new Set(authors);
          expect(uniqueAuthors.size).to.equal(5);
          for (const u of users) {
            expect(uniqueAuthors.has(u.id)).to.be.true;
          }
        }
      });
    });
  });
});




