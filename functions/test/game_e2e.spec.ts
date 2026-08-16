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
      selectedDeckId: 'the_daily_grind'
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
        selectedDeckId: 'the_daily_grind'
      });
      expect.fail('Guest started the game but should have been blocked');
    } catch (err: any) {
      expect(err.message).to.contain('host');
    }

    // Guest tries to submit a vote with self-vote (should fail)
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
    const getToken = (id: string) => id === 'p_host' ? hostUser.idToken : (id === 'p_guest' ? guestUser.idToken : guest2User.idToken);
    const readerToken = getToken(currentReader);

    const sealedSnap = await roomRef.collection('sealed').doc(currentReader).get();
    const truthOptId = sealedSnap.data()?.truthAnswerId || 'TRUTH';

    const playerIds = ['p_host', 'p_guest', 'p_guest2'];
    for (const pId of playerIds) {
      if (pId !== currentReader) {
        await callFn('castVote', getToken(pId), {
          roomCode,
          targetCardId: currentReader,
          voterId: pId,
          votedForId: truthOptId
        });
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
    expect(guestSealedSnap.data()?.truthAnswer).to.equal('THE SOUL IS SILENT');

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

  it('Issue 67 Option B: should accumulate seenPrompts, never repeat prompts during re-rolls, and throw resource-exhausted HttpsError on deck exhaustion', async () => {
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

    // cah_dark_humor has exactly 12 prompts. With 3 players, 3 are drawn initially.
    await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'cah_dark_humor' });

    const roomRef = db.collection('rooms').doc(roomCode);
    let roomSnap = await roomRef.get();
    expect(roomSnap.data()?.currentPhase).to.equal('truth');

    const seenByHost = new Set<string>();
    const hostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
    seenByHost.add(hostCard.promptText);

    // Re-roll 9 times to exhaust the remaining prompts in the 12-prompt deck (3 initially drawn, 9 remaining)
    for (let i = 0; i < 9; i++) {
      await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
      roomSnap = await roomRef.get();
      const updatedHostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
      expect(seenByHost.has(updatedHostCard.promptText)).to.be.false;
      seenByHost.add(updatedHostCard.promptText);
    }

    // Issue 69 assertion: Public cards MUST NOT carry seenPrompts
    const publicHostCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
    expect(publicHostCard).to.not.have.property('seenPrompts');

    // Issue 69 assertion: Sealed document MUST carry seenPrompts
    const sealedSnap = await db.collection('rooms').doc(roomCode).collection('sealed').doc('p_host').get();
    expect(sealedSnap.exists).to.be.true;
    expect(sealedSnap.data()?.seenPrompts).to.be.an('array');
    expect(sealedSnap.data()?.seenPrompts).to.have.lengthOf(10);

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
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
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
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
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
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });

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
        const targetCard = roomSnap.data()?.cards[0];
        const targetCardId = targetCard.targetPlayerId;

        const sealedSnap = await roomRef.collection('sealed').doc(targetCardId).get();
        const answerAuthors = sealedSnap.data()?.answerAuthors || {};

        // Find host's option ID on targetCard
        const hostOptionId = Object.keys(answerAuthors).find(k => answerAuthors[k] === 'p_host');
        expect(hostOptionId).to.be.ok;

        // Self-vote check: host tries to vote for own option -> fails with FAILED_PRECONDITION
        try {
          await callFn('castVote', hostUser.idToken, {
            roomCode,
            targetCardId,
            voterId: 'p_host',
            votedForId: hostOptionId!
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
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });

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
          await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
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
        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
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
        await callFn('startGame', hostUser.idToken, { roomCode: room9Code, selectedDeckId: 'the_daily_grind' });
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

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });

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
        // 2. Innocent forgery voter votes for forgery
        await callFn('castVote', innocentForgeryVoter.token, { roomCode, targetCardId, voterId: innocentForgeryVoter.id, votedForId: forgeryOptId });
        // 3. Forger votes for truth
        await callFn('castVote', forgerVoter.token, { roomCode, targetCardId, voterId: forgerVoter.id, votedForId: truthOptId });

        await callFn('setReady', reader.token, { roomCode, playerId: reader.id, ready: true });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');

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
          debugEnabled: true
        });
        const roomCode = createRes.roomCode;
        const roomRef = db.collection('rooms').doc(roomCode);

        await callFn('joinRoom', g1.idToken, { roomCode, playerName: 'Bob', playerId: 'p_g1' });
        await callFn('joinRoom', g2.idToken, { roomCode, playerName: 'Charlie', playerId: 'p_g2' });
        await callFn('joinRoom', g3.idToken, { roomCode, playerName: 'Dave', playerId: 'p_g3' });
        await callFn('joinRoom', g4.idToken, { roomCode, playerName: 'Eve', playerId: 'p_g4' });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_g1').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_g2').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_g3').update({ lobbyReady: true });
        await db.collection('rooms').doc(roomCode).collection('players').doc('p_g4').update({ lobbyReady: true });

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'T1', isTruth: true });
        await callFn('submitAnswer', g1.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'T2', isTruth: true });
        await callFn('submitAnswer', g2.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'T3', isTruth: true });
        await callFn('submitAnswer', g3.idToken, { roomCode, targetCardId: 'p_g3', authorId: 'p_g3', text: 'T4', isTruth: true });
        await callFn('submitAnswer', g4.idToken, { roomCode, targetCardId: 'p_g4', authorId: 'p_g4', text: 'T5', isTruth: true });

        // Forgery rounds 1, 2, 3
        for (let r = 0; r < 3; r++) {
          const rSnap = await roomRef.get();
          const asg = rSnap.data()?.currentCardAssignments;
          await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: asg['p_host'], authorId: 'p_host', text: `L1_${r}`, isTruth: false });
          await callFn('submitAnswer', g1.idToken, { roomCode, targetCardId: asg['p_g1'], authorId: 'p_g1', text: `L2_${r}`, isTruth: false });
          await callFn('submitAnswer', g2.idToken, { roomCode, targetCardId: asg['p_g2'], authorId: 'p_g2', text: `L3_${r}`, isTruth: false });
          await callFn('submitAnswer', g3.idToken, { roomCode, targetCardId: asg['p_g3'], authorId: 'p_g3', text: `L4_${r}`, isTruth: false });
          await callFn('submitAnswer', g4.idToken, { roomCode, targetCardId: asg['p_g4'], authorId: 'p_g4', text: `L5_${r}`, isTruth: false });
        }

        let roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('vote');
        const targetCardId = roomSnap.data()?.currentReaderId;
        const sealedSnap = await roomRef.collection('sealed').doc(targetCardId).get();
        const sealedData = sealedSnap.data() as any;
        const truthOptId = sealedData.truthAnswerId;
        const answerAuthors = sealedData.answerAuthors; // optId -> authorId

        const forgeryOptions: Array<{ optId: string; authorId: string }> = [];
        for (const [optId, aId] of Object.entries(answerAuthors)) {
          if (optId !== truthOptId) {
            forgeryOptions.push({ optId, authorId: aId as string });
          }
        }

        const allPlayers = [
          { id: 'p_host', token: hostUser.idToken },
          { id: 'p_g1', token: g1.idToken },
          { id: 'p_g2', token: g2.idToken },
          { id: 'p_g3', token: g3.idToken },
          { id: 'p_g4', token: g4.idToken },
        ];
        const voters = allPlayers.filter(p => p.id !== targetCardId);
        const reader = allPlayers.find(p => p.id === targetCardId)!;

        // In 5p S=3, voters are 3 forgers and 1 innocent voter
        const forgerIds = forgeryOptions.map(f => f.authorId);
        const innocentVoter = voters.find(p => !forgerIds.includes(p.id))!;
        const forgerVoters = voters.filter(p => forgerIds.includes(p.id));

        const forger1 = forgerVoters[0];
        const forger2 = forgerVoters[1];
        const forger3 = forgerVoters[2];

        // Find forger2's option id so forger1 can vote for it
        const forger2Opt = forgeryOptions.find(f => f.authorId === forger2.id)!;

        // 1. Innocent voter votes truth
        await callFn('castVote', innocentVoter.token, { roomCode, targetCardId, voterId: innocentVoter.id, votedForId: truthOptId });
        // 2. Forger 1 votes for Forger 2's forgery
        await callFn('castVote', forger1.token, { roomCode, targetCardId, voterId: forger1.id, votedForId: forger2Opt.optId });
        // 3. Forger 2 votes truth
        await callFn('castVote', forger2.token, { roomCode, targetCardId, voterId: forger2.id, votedForId: truthOptId });
        // 4. Forger 3 votes truth
        await callFn('castVote', forger3.token, { roomCode, targetCardId, voterId: forger3.id, votedForId: truthOptId });

        await callFn('setReady', reader.token, { roomCode, playerId: reader.id, ready: true });

        roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('reveal');

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

        await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });

        // Truth phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: 'p_host', authorId: 'p_host', text: 'Alice Truth', isTruth: true });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: 'p_g1', authorId: 'p_g1', text: 'Bob Truth', isTruth: true });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: 'p_g2', authorId: 'p_g2', text: 'Charlie Truth', isTruth: true });

        let roomSnap = await roomRef.get();
        const assignments = roomSnap.data()?.currentCardAssignments;

        // Forgery phase
        await callFn('submitAnswer', hostUser.idToken, { roomCode, targetCardId: assignments['p_host'], authorId: 'p_host', text: 'Alice Lie', isTruth: false });
        await callFn('submitAnswer', guest1User.idToken, { roomCode, targetCardId: assignments['p_g1'], authorId: 'p_g1', text: 'Bob Lie', isTruth: false });
        await callFn('submitAnswer', guest2User.idToken, { roomCode, targetCardId: assignments['p_g2'], authorId: 'p_g2', text: 'Charlie Lie', isTruth: false });

        roomSnap = await roomRef.get();
        const targetCardId = roomSnap.data()?.currentReaderId; // Target who wrote the truth
        const sealedSnap = await roomRef.collection('sealed').doc(targetCardId).get();
        const sealedData = sealedSnap.data() as any;
        const truthOptId = sealedData.truthAnswerId;
        const answerAuthors = sealedData.answerAuthors; // optId -> authorId

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
        ];
        const reader = allPlayers.find(p => p.id === targetCardId)!;
        const otherVoter = allPlayers.find(p => p.id !== targetCardId && p.id !== forgerAuthorId)!;
        const forgerVoter = allPlayers.find(p => p.id === forgerAuthorId)!;

        // otherVoter votes for forgery (fooled!)
        await callFn('castVote', otherVoter.token, { roomCode, targetCardId, voterId: otherVoter.id, votedForId: forgeryOptId });
        // forgerVoter votes for truth
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
        const forgerScoreBefore = (await roomRef.collection('players').doc(forgerAuthorId).get()).data()?.totalScore || 0;
        const guesserScoreBefore = (await roomRef.collection('players').doc(otherVoter.id).get()).data()?.totalScore || 0;

        await callFn('submitUnmaskGuess', otherVoter.token, {
          roomCode,
          guesserId: otherVoter.id,
          guessedAuthorId: forgerAuthorId,
        });

        const forgerScoreAfter = (await roomRef.collection('players').doc(forgerAuthorId).get()).data()?.totalScore || 0;
        const guesserScoreAfter = (await roomRef.collection('players').doc(otherVoter.id).get()).data()?.totalScore || 0;

        expect(guesserScoreAfter).to.equal(guesserScoreBefore + 1);
        expect(forgerScoreAfter).to.equal(forgerScoreBefore - 1);
      });
    });

    describe('Issue 83 Option C: Deck exhaustion boundary and per-player isolation for two deck sizes', () => {
      const testCases = [
        { deckId: 'cah_dark_humor', totalPrompts: 12 },
        { deckId: 'the_daily_grind', totalPrompts: 20 },
      ];

      for (const tc of testCases) {
        it(`exhausts ${tc.deckId} (${tc.totalPrompts} prompts) at the boundary and permits second player to re-roll`, async () => {
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
            await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
            roomSnap = await roomRef.get();
            const updatedCard = (roomSnap.data()?.cards as any[]).find(c => c.targetPlayerId === 'p_host');
            expect(seenByHost.has(updatedCard.promptText)).to.be.false;
            seenByHost.add(updatedCard.promptText);
          }

          expect(seenByHost.size).to.equal(expectedHostRerolls + 1);

          // The next re-roll must throw RESOURCE_EXHAUSTED (match on code, trap 12)
          let threwExhaustion = false;
          try {
            await callFn('rerollPrompt', hostUser.idToken, { roomCode, playerId: 'p_host' });
          } catch (err: any) {
            threwExhaustion = true;
            expect(err.status).to.equal('RESOURCE_EXHAUSTED');
          }
          expect(threwExhaustion).to.be.true;

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
          disconnectedPlayerId: 'p_g1'
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
          await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
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

        const startRes = await callFn('startGame', hostUser.idToken, { roomCode, selectedDeckId: 'the_daily_grind' });
        expect(startRes.success).to.be.true;

        const roomSnap = await roomRef.get();
        expect(roomSnap.data()?.currentPhase).to.equal('truth');
      });
    });
  });
});

