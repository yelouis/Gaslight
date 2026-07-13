import * as fs from 'fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

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
});
