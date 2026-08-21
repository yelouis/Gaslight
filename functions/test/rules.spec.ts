import * as fs from 'fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

describe('Firestore Security Rules', () => {
  let testEnv: any;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'gaslight-rules-test',
      firestore: {
        rules: fs.readFileSync('../firestore.rules', 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  it('SEC1: should deny collection enumeration (list) on /rooms for authenticated client', async () => {
    /*
     * Falsification run with allow read: if true (granting list):
     * Expected: assertFails on getDocs(collection(db, 'rooms'))
     * Observed failure on current rules:
     *   Error: Expected request to fail, but it succeeded.
     *   at pr.then._a (functions/node_modules/@firebase/rules-unit-testing/src/util.ts:138:9)
     *   at async Context.<anonymous> (functions/test/rules.spec.ts:43:5)
     */
    const authContext = testEnv.authenticatedContext('alice');
    const db = authContext.firestore();

    // 1. Falsification: collection enumeration on /rooms must be denied
    await assertFails(getDocs(collection(db, 'rooms')));

    // 2. Over-reach guard 1: getDoc on a specific room document must still succeed
    await assertSucceeds(getDoc(doc(db, 'rooms/TEST')));

    // 3. Over-reach guard 2: getDocs on /rooms/{code}/players must still succeed
    await assertSucceeds(getDocs(collection(db, 'rooms/TEST/players')));
  });

  it('SEC1: should deny collection enumeration (list) on /rooms for unauthenticated client', async () => {
    const unauthContext = testEnv.unauthenticatedContext();
    const db = unauthContext.firestore();

    // 1. Falsification: collection enumeration on /rooms must be denied
    await assertFails(getDocs(collection(db, 'rooms')));

    // 2. Over-reach guard 1: getDoc on a specific room document must still succeed
    await assertSucceeds(getDoc(doc(db, 'rooms/TEST')));

    // 3. Over-reach guard 2: getDocs on /rooms/{code}/players must still succeed
    await assertSucceeds(getDocs(collection(db, 'rooms/TEST/players')));
  });

  it('should deny room document writes by clients', async () => {
    const context = testEnv.authenticatedContext('alice');
    const roomRef = doc(context.firestore(), 'rooms/TEST');
    await assertFails(setDoc(roomRef, { currentPhase: 'lobby' }));
  });

  it('should deny player creation by clients', async () => {
    const context = testEnv.authenticatedContext('alice');
    const playerRef = doc(context.firestore(), 'rooms/TEST/players/alice_id');
    await assertFails(setDoc(playerRef, { name: 'Alice', authUid: 'alice' }));
  });

  it('should deny player deletion by clients', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const adminPlayerRef = doc(adminContext.firestore(), 'rooms/TEST/players/alice_id');
      await setDoc(adminPlayerRef, { name: 'Alice', authUid: 'alice' });
    });

    const userContext = testEnv.authenticatedContext('alice');
    const playerRef = doc(userContext.firestore(), 'rooms/TEST/players/alice_id');
    await assertFails(deleteDoc(playerRef));
  });

  it('should allow cosmetic updates by player owner', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const adminPlayerRef = doc(adminContext.firestore(), 'rooms/TEST/players/alice_id');
      await setDoc(adminPlayerRef, {
        id: 'alice_id',
        name: 'Alice',
        authUid: 'alice',
        totalScore: 10,
        role: 'unassigned',
        lobbyReady: false
      });
    });

    const userContext = testEnv.authenticatedContext('alice');
    const playerRef = doc(userContext.firestore(), 'rooms/TEST/players/alice_id');
    await assertSucceeds(updateDoc(playerRef, { name: 'Alice New Name', lobbyReady: true }));
  });

  it('should deny updates if owner tries to change protected fields', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const adminPlayerRef = doc(adminContext.firestore(), 'rooms/TEST/players/alice_id');
      await setDoc(adminPlayerRef, {
        id: 'alice_id',
        name: 'Alice',
        authUid: 'alice',
        totalScore: 10,
        role: 'unassigned',
        lobbyReady: false
      });
    });

    const userContext = testEnv.authenticatedContext('alice');
    const playerRef = doc(userContext.firestore(), 'rooms/TEST/players/alice_id');
    await assertFails(updateDoc(playerRef, { totalScore: 100 }));
    await assertFails(updateDoc(playerRef, { role: 'saboteur' }));
  });

  it('should deny updates by other users', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const adminPlayerRef = doc(adminContext.firestore(), 'rooms/TEST/players/alice_id');
      await setDoc(adminPlayerRef, {
        id: 'alice_id',
        name: 'Alice',
        authUid: 'alice',
        totalScore: 10,
        role: 'unassigned',
        lobbyReady: false
      });
    });

    const userContext = testEnv.authenticatedContext('bob');
    const playerRef = doc(userContext.firestore(), 'rooms/TEST/players/alice_id');
    await assertFails(updateDoc(playerRef, { name: 'Bob Changing Name' }));
  });

  it('should allow writing customPrompts by owner and deny modifications to protected fields alongside it', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const adminPlayerRef = doc(adminContext.firestore(), 'rooms/TEST/players/alice_id');
      await setDoc(adminPlayerRef, {
        id: 'alice_id',
        name: 'Alice',
        authUid: 'alice',
        totalScore: 10,
        role: 'unassigned',
        lobbyReady: false
      });
    });

    const userContext = testEnv.authenticatedContext('alice');
    const playerRef = doc(userContext.firestore(), 'rooms/TEST/players/alice_id');

    await assertSucceeds(updateDoc(playerRef, { customPrompts: ['Prompt 1', 'Prompt 2'] }));

    await assertFails(updateDoc(playerRef, { customPrompts: ['Prompt 3'], totalScore: 20 }));

    const bobContext = testEnv.authenticatedContext('bob');
    const bobPlayerRef = doc(bobContext.firestore(), 'rooms/TEST/players/alice_id');
    await assertFails(updateDoc(bobPlayerRef, { customPrompts: ['Bob prompt'] }));
  });

  it('client cannot write expiresAt on its own player document', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const adminPlayerRef = doc(adminContext.firestore(), 'rooms/TEST/players/alice_id');
      await setDoc(adminPlayerRef, {
        id: 'alice_id',
        name: 'Alice',
        authUid: 'alice',
        totalScore: 10,
        lastSeen: 100
      });
    });

    const userContext = testEnv.authenticatedContext('alice');
    const playerRef = doc(userContext.firestore(), 'rooms/TEST/players/alice_id');

    // Deny expiresAt write
    await assertFails(updateDoc(playerRef, { expiresAt: Date.now() + 10000 }));

    // Allow lastSeen update
    await assertSucceeds(updateDoc(playerRef, { lastSeen: Date.now() }));
  });

  it('should deny client reads and writes on sealed subcollection', async () => {
    const userContext = testEnv.authenticatedContext('alice');
    const sealedRef = doc(userContext.firestore(), 'rooms/TEST/sealed/card_1');
    const getDoc = (await import('firebase/firestore')).getDoc;
    await assertFails(getDoc(sealedRef));
    await assertFails(setDoc(sealedRef, { truthAnswer: 'secret' }));
  });
});
