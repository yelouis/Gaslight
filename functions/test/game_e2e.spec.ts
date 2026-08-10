import { expect } from 'chai';
import admin from 'firebase-admin';

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

  it('should run a full 2-player game loop successfully', async () => {
    const hostUser = await createAnonUser();
    const guestUser = await createAnonUser();

    // 1. Create Room (debugEnabled = true)
    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
      sabotageAnswersCount: 1,
      debugEnabled: true
    });
    const roomCode = createRes.roomCode;
    expect(roomCode).to.be.a('string').and.have.lengthOf(4);

    // 2. Join Room
    const joinRes = await callFn('joinRoom', guestUser.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
    });
    expect(joinRes.role).to.equal('unassigned');

    // 3. Start Game
    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'the_daily_grind'
    });

    // Verify room has entered truth phase
    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    let roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.equal('truth');
    expect(roomState.cards).to.have.lengthOf(2);

    // 4. Submit Truths
    const hostTruthSub = await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: 'p_host',
      authorId: 'p_host',
      text: 'Alice Real Truth',
      isTruth: true
    });
    expect(hostTruthSub.success).to.be.true;

    // Verify host is ready
    roomSnap = await roomRef.get();
    roomState = roomSnap.data() as any;
    expect(roomState.readyPlayers['p_host']).to.be.true;

    // Guest submits truth, triggers auto-advance to forgery phase
    const guestTruthSub = await callFn('submitAnswer', guestUser.idToken, {
      roomCode,
      targetCardId: 'p_guest',
      authorId: 'p_guest',
      text: 'Bob Real Truth',
      isTruth: true
    });
    expect(guestTruthSub.success).to.be.true;

    // Verify auto-advance to forgery phase & rotation assignments
    roomSnap = await roomRef.get();
    roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.equal('forgery');

    const assignments = roomState.currentCardAssignments;
    const hostTarget = assignments['p_host'];
    const guestTarget = assignments['p_guest'];
    expect(hostTarget).to.be.ok;
    expect(guestTarget).to.be.ok;

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

    // Verify auto-advance to vote phase
    roomSnap = await roomRef.get();
    roomState = roomSnap.data() as any;
    expect(roomState.currentPhase).to.equal('vote');
    expect(roomState.resolutionOrder).to.have.lengthOf(2);

    // Issue 63 / §5: Assert option IDs are opaque random UUIDs and leak neither player IDs nor truth
    const playerIds = ['p_host', 'p_guest'];
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

    // 6. Voting
    const currentReader = roomState.currentReaderId;
    const voter = currentReader === 'p_host' ? 'p_guest' : 'p_host';
    const voterToken = voter === 'p_guest' ? guestUser.idToken : hostUser.idToken;
    const readerToken = currentReader === 'p_host' ? hostUser.idToken : guestUser.idToken;

    // Voter casts vote
    const voteRes = await callFn('castVote', voterToken, {
      roomCode,
      targetCardId: currentReader,
      voterId: voter,
      votedForId: currentReader
    });
    expect(voteRes.success).to.be.true;

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
    let revealIdx = 0;
    for (const card of roomState.cards) {
      for (const opt of card.options) {
        expect(opt.id).to.equal(votePhaseOptionIds[revealIdx++]);
      }
    }

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
        selectedDeckId: 'the_daily_grind'
      });
      expect.fail('Guest started the game but should have been blocked');
    } catch (err: any) {
      expect(err.message).to.contain('host');
    }

    // Guest tries to submit a vote with self-vote (should fail)
    try {
      await callFn('castVote', guestUser.idToken, {
        roomCode,
        targetCardId: 'p_host',
        voterId: 'p_guest',
        votedForId: 'p_guest'
      });
      expect.fail('Self-vote succeeded but should have failed');
    } catch (err: any) {
      expect(err.message).to.contain('Self-voting');
    }
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
    await callFn('joinRoom', guestUserOld.idToken, {
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

    // 4. Guest rejoins with the same stable playerId
    const rejoinRes = await callFn('joinRoom', guestUserNew.idToken, {
      roomCode,
      playerName: 'Bob',
      playerId: 'p_guest'
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
      selectedDeckId: 'the_daily_grind'
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

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'the_daily_grind'
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

    // Advance phase to fill missing guest truth with placeholder -> moves to forgery phase
    await callFn('advancePhase', hostUser.idToken, { roomCode });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('forgery');

    const assignments = roomSnap.data()?.currentCardAssignments;
    const guestCardTarget = assignments['p_host'];

    // Submit host forgery
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId: guestCardTarget,
      authorId: 'p_host',
      text: 'Host lie',
      isTruth: false
    });

    // Advance phase to fill missing guest forgery with placeholder -> moves to vote phase
    await callFn('advancePhase', hostUser.idToken, { roomCode });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('vote');

    // Advance from vote to reveal so sealed answers fold into public card models
    const currentReader = roomSnap.data()?.currentReaderId;
    const voter = currentReader === 'p_host' ? 'p_guest' : 'p_host';
    const voterToken = voter === 'p_guest' ? guestUser.idToken : hostUser.idToken;
    const readerToken = currentReader === 'p_host' ? hostUser.idToken : guestUser.idToken;

    await callFn('castVote', voterToken, {
      roomCode,
      targetCardId: currentReader,
      voterId: voter,
      votedForId: 'TRUTH'
    });
    await callFn('setReady', readerToken, {
      roomCode,
      playerId: currentReader,
      ready: true
    });

    roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('reveal');

    const cardsAfterReveal = roomSnap.data()?.cards as any[];
    const guestCardAfterReveal = cardsAfterReveal.find(c => c.targetPlayerId === 'p_guest');
    expect(guestCardAfterReveal.truthAnswer).to.equal('THE SOUL IS SILENT');

    const hostCardAfterReveal = cardsAfterReveal.find(c => c.targetPlayerId === 'p_host');
    expect(hostCardAfterReveal.truthAnswer).to.equal('Host truth');
    expect(hostCardAfterReveal.sabotageAnswers['p_guest']).to.equal('THE SOUL IS SILENT');
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

    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'the_daily_grind'
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

    await callFn('castVote', voterToken, {
      roomCode,
      targetCardId: readerId,
      voterId: voterId,
      votedForId: forgerId
    });

    await callFn('castVote', forgerToken, {
      roomCode,
      targetCardId: readerId,
      voterId: forgerId,
      votedForId: 'TRUTH'
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
    const initialVoterScore = voterSnap.data()?.totalScore || 0;
    const initialForgerScore = forgerSnap.data()?.totalScore || 0;

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
    expect(voterSnap.data()?.totalScore).to.equal(initialVoterScore + 1);
    expect(forgerSnap.data()?.totalScore).to.equal(initialForgerScore - 1);

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
      expect(e.status).to.equal('FAILED_PRECONDITION');
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
      expect(e.status).to.equal('FAILED_PRECONDITION');
    }
    expect(rejected).to.be.true;
  });

  it('should handle custom deck prompt selection, top-ups, and reroll fallback', async () => {
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
      customPrompts: ['Bob prompt 1']
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

    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'cah_dark_humor' });

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

  it('Issue 67 Option B: should accumulate seenPrompts, never repeat prompts during re-rolls, and throw resource-exhausted HttpsError on deck exhaustion', async () => {
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

    // cah_dark_humor has exactly 12 prompts. With 2 players, 2 are drawn initially.
    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'cah_dark_humor' });

    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    const seenByHost = new Set<string>();
    const hostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
    seenByHost.add(hostCard.promptText);

    // Re-roll 10 times to exhaust the remaining prompts in the 12-prompt deck (2 initially drawn, 10 remaining)
    for (let i = 0; i < 10; i++) {
      await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
      roomSnap = await roomRef.get();
      const updatedHostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
      expect(seenByHost.has(updatedHostCard.promptText)).to.be.false;
      seenByHost.add(updatedHostCard.promptText);
    }

    // The host has now seen 11 prompts (1 initial + 10 re-rolled). The guest has 1 prompt.
    // Total 12 prompts used. The 11th re-roll should fail with resource-exhausted HttpsError.
    let threwExhaustion = false;
    let errorMessage = '';
    try {
      await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
    } catch (e: any) {
      threwExhaustion = true;
      errorMessage = e.message || e.toString() || '';
    }
    expect(threwExhaustion).to.be.true;
    expect(errorMessage).to.include('No more prompts');
  });

  it('should enforce the server-side cap of at most 3 custom prompts per player', async () => {
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
      customPrompts: []
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

    // 1. Create Room (debugEnabled = true)
    const createRes = await callFn('createRoom', hostUser.idToken, {
      playerName: 'Alice',
      playerId: 'p_host',
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

    // 3. Start Game
    await callFn('startGame', hostUser.idToken, {
      roomCode,
      selectedDeckId: 'the_daily_grind'
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

    const roomRef = db.collection('rooms').doc(roomCode);
    const roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('forgery');
    const targetCardId = roomSnap.data()?.currentCardAssignments['p_host'];
    expect(targetCardId).to.be.a('string');

    // 5. Submit first forgery (distinct) -> succeeds
    await callFn('submitAnswer', hostUser.idToken, {
      roomCode,
      targetCardId,
      authorId: 'p_host',
      text: 'sleeping in my bed all day',
      isTruth: false
    });

    // 6. Submit near-duplicate forgery from another player -> rejects
    try {
      await callFn('submitAnswer', guestUser.idToken, {
        roomCode,
        targetCardId,
        authorId: 'p_guest',
        text: 'sleep all day in bed',
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
      targetCardId,
      authorId: 'p_guest',
      text: 'playing video games',
      isTruth: false
    });

    // Verify forgery answers in sealed document (Issue 62 & 63)
    const sealedSnap = await db.collection('rooms').doc(roomCode).collection('sealed').doc(targetCardId).get();
    const sealedData = sealedSnap.data();
    expect(sealedData?.sabotageAnswers['p_host']).to.equal('sleeping in my bed all day');
    expect(sealedData?.sabotageAnswers['p_guest']).to.equal('playing video games');
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

      const roomRef = db.collection('rooms').doc(roomCode);
      await roomRef.update({ sabotageAnswersCount: null });

      try {
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
        expect.fail('Should have thrown failed-precondition for null sabotageAnswersCount');
      } catch (err: any) {
        expect(err.status).to.equal('FAILED_PRECONDITION');
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
      const hostPlayerRef = roomRef.collection('players').doc('p_host');

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

      // Start game so phase is no longer lobby
      await callFn('startGame', hostUser.idToken, {
        roomCode,
        selectedDeckId: 'the_daily_grind'
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

        const roomRef = db.collection('rooms').doc(roomCode);

        // 1. Lobby phase
        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('lobby');

        // 2. Start Game -> Truth phase
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');

        // 3. Submit Truths -> Forgery phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'T1', isTruth: true });
        await callFn('submitAnswer', guestUser.idToken, { roomCode, targetCardId: 'p_guest', authorId: 'p_guest', text: 'T2', isTruth: true });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('forgery');

        // 4. Submit Forgeries -> Vote phase
        const assignments = roomSnap.data()?.currentCardAssignments;
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_host'], authorId: 'p_host', text: 'F1', isTruth: false });
        await callFn('submitAnswer', guestUser.idToken, { roomCode, targetCardId: assignments['p_guest'], authorId: 'p_guest', text: 'F2', isTruth: false });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');

        // 5. Vote -> Reveal phase
        const reader = roomSnap.data()?.currentReaderId;
        const voterToken = reader === 'p_host' ? guestUser.idToken : hostUser.idToken;
        const readerToken = reader === 'p_host' ? hostUser.idToken : guestUser.idToken;
        await callFn('castVote', voterToken, { roomCode, targetCardId: reader, voterId: reader === 'p_host' ? 'p_guest' : 'p_host', votedForId: 'TRUTH' });
        await callFn('setReady', readerToken, { roomCode, playerId: reader, ready: true });
        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');
      });
    });
  });
});
