import { expect } from 'chai';
import admin from 'firebase-admin';
import { Timestamp } from 'firebase-admin/firestore';
import { runCleanup } from '../src/cleanup';

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
const auth = admin.auth();

describe('Nightly Cleanup Unit & Emulator Tests (U5 / Issue 143)', () => {
  beforeEach(async () => {
    // Clear any rooms created previously
    const rooms = await db.collection('rooms').listDocuments();
    for (const r of rooms) {
      await db.recursiveDelete(r);
    }
  });

  it('(a) should recursively delete expired room and all its subcollections (players, sealed, embeddings)', async () => {
    const roomId = 'EXP1';
    const roomRef = db.collection('rooms').doc(roomId);

    // Create expired room (expiresAt 1 hour in the past)
    const pastTimestamp = Timestamp.fromMillis(Date.now() - 3600 * 1000);
    await roomRef.set({
      code: roomId,
      phase: 'lobby',
      expiresAt: pastTimestamp,
    });

    // Populate subcollections
    await roomRef.collection('players').doc('p1').set({ id: 'p1', name: 'Alice', authUid: 'uid_alice' });
    await roomRef.collection('sealed').doc('s1').set({ secret: 'truth' });
    await roomRef.collection('embeddings').doc('e1').set({ vector: [0.1, 0.2] });

    // Verify subcollections exist
    expect((await roomRef.collection('players').get()).size).to.equal(1);
    expect((await roomRef.collection('sealed').get()).size).to.equal(1);
    expect((await roomRef.collection('embeddings').get()).size).to.equal(1);

    // Run cleanup in live mode (dryRun: false)
    const result = await runCleanup(db, auth, {
      dryRun: false,
      now: Timestamp.now(),
    });

    expect(result.roomsDeleted).to.be.at.least(1);

    // Assert parent document is gone
    const parentSnap = await roomRef.get();
    expect(parentSnap.exists).to.be.false;

    // Assert all three subcollections are completely deleted
    const playersSnap = await roomRef.collection('players').get();
    const sealedSnap = await roomRef.collection('sealed').get();
    const embeddingsSnap = await roomRef.collection('embeddings').get();

    expect(playersSnap.size).to.equal(0);
    expect(sealedSnap.size).to.equal(0);
    expect(embeddingsSnap.size).to.equal(0);
  });

  it('(b) should NOT touch non-expired rooms (Over-reach guard)', async () => {
    const roomId = 'LIVE1';
    const roomRef = db.collection('rooms').doc(roomId);

    // Create live room (expiresAt 8 hours in the future)
    const futureTimestamp = Timestamp.fromMillis(Date.now() + 8 * 3600 * 1000);
    await roomRef.set({
      code: roomId,
      phase: 'truth',
      expiresAt: futureTimestamp,
    });

    await roomRef.collection('players').doc('p1').set({ id: 'p1', name: 'Bob', authUid: 'uid_bob' });

    const result = await runCleanup(db, auth, {
      dryRun: false,
      now: Timestamp.now(),
    });

    expect(result.roomsDeleted).to.equal(0);
    expect(result.roomsScanned).to.equal(0);

    // Parent and subcollections must remain intact
    const parentSnap = await roomRef.get();
    expect(parentSnap.exists).to.be.true;

    const playersSnap = await roomRef.collection('players').get();
    expect(playersSnap.size).to.equal(1);
  });

  it('(c) should sweep orphaned subtrees where parent document is missing (e.g. BGHW case)', async () => {
    const roomId = 'ORPH1';
    const roomRef = db.collection('rooms').doc(roomId);

    // Do NOT create the parent document (or delete it directly without recursiveDelete)
    // Only create subcollections
    await roomRef.collection('sealed').doc('s1').set({ secret: 'leftover_secret' });
    await roomRef.collection('players').doc('p1').set({ id: 'p1', name: 'Ghost' });

    // Verify parent does not exist but subcollection docs exist
    expect((await roomRef.get()).exists).to.be.false;
    expect((await roomRef.collection('sealed').get()).size).to.equal(1);

    const result = await runCleanup(db, auth, {
      dryRun: false,
      now: Timestamp.now(),
    });

    expect(result.orphanSubtreesSwept).to.be.at.least(1);

    // Assert subcollections were swept
    expect((await roomRef.collection('sealed').get()).size).to.equal(0);
    expect((await roomRef.collection('players').get()).size).to.equal(0);
  });

  it('(d) should NOT delete anonymous user referenced by an active room (Over-reach guard)', async () => {
    // Create an anonymous user
    const liveUser = await auth.createUser({});
    const liveUid = liveUser.uid;

    // Create a live room referencing liveUid
    const roomId = 'LIVE_REF';
    const roomRef = db.collection('rooms').doc(roomId);
    await roomRef.set({
      code: roomId,
      phase: 'lobby',
      expiresAt: Timestamp.fromMillis(Date.now() + 3600 * 1000),
    });
    await roomRef.collection('players').doc('p1').set({
      id: 'p1',
      name: 'ActivePlayer',
      authUid: liveUid,
    });

    // Run cleanup with auth retention = 0 (eligible for deletion if unreferenced)
    const result = await runCleanup(db, auth, {
      dryRun: false,
      authRetentionMs: 0,
      now: Timestamp.now(),
    });

    expect(result.authUsersReferenced).to.be.at.least(1);

    // User must still exist in auth
    const fetchedUser = await auth.getUser(liveUid);
    expect(fetchedUser.uid).to.equal(liveUid);

    // Cleanup user afterwards
    await auth.deleteUser(liveUid);
  });

  it('(e) should purge old unreferenced anonymous users', async () => {
    // Create an unreferenced anonymous user
    const staleUser = await auth.createUser({});
    const staleUid = staleUser.uid;

    // Run cleanup with authRetentionMs = 0 so all unreferenced anonymous users qualify
    const result = await runCleanup(db, auth, {
      dryRun: false,
      authRetentionMs: 0,
      now: Timestamp.now(),
    });

    expect(result.authUsersDeleted).to.be.at.least(1);

    // User must no longer exist in auth
    try {
      await auth.getUser(staleUid);
      expect.fail('User should have been deleted');
    } catch (err: any) {
      expect(err.code).to.equal('auth/user-not-found');
    }
  });

  it('(f) with DRY_RUN=true should delete NOTHING and log eligible counts', async () => {
    const roomId = 'DRY1';
    const roomRef = db.collection('rooms').doc(roomId);
    const pastTimestamp = Timestamp.fromMillis(Date.now() - 3600 * 1000);
    await roomRef.set({
      code: roomId,
      phase: 'lobby',
      expiresAt: pastTimestamp,
    });
    await roomRef.collection('players').doc('p1').set({ id: 'p1', name: 'Alice' });

    // Create an unreferenced anon user
    const anonUser = await auth.createUser({});
    const anonUid = anonUser.uid;

    const result = await runCleanup(db, auth, {
      dryRun: true,
      authRetentionMs: 0,
      now: Timestamp.now(),
    });

    expect(result.dryRun).to.be.true;
    expect(result.roomsScanned).to.be.at.least(1);
    expect(result.roomsDeleted).to.be.at.least(1); // Planned in count
    expect(result.authUsersDeleted).to.equal(0); // Actual deletions are 0

    // Verify room and subcollection STILL exist on disk
    expect((await roomRef.get()).exists).to.be.true;
    expect((await roomRef.collection('players').get()).size).to.equal(1);

    // Verify user STILL exists in auth
    const fetched = await auth.getUser(anonUid);
    expect(fetched.uid).to.equal(anonUid);

    // Cleanup
    await auth.deleteUser(anonUid);
  });

  it('(g) should honour maxOrphansPerRun cap, bound scan count, and sweep remaining orphans on subsequent run (Issue 146 / Part B)', async () => {
    const o1 = db.collection('rooms').doc('ORPH_CAP_1');
    const o2 = db.collection('rooms').doc('ORPH_CAP_2');
    const o3 = db.collection('rooms').doc('ORPH_CAP_3');

    // Seed 3 orphaned subtrees (no parent doc, only subcollections)
    await o1.collection('sealed').doc('s1').set({ data: '1' });
    await o2.collection('sealed').doc('s2').set({ data: '2' });
    await o3.collection('sealed').doc('s3').set({ data: '3' });

    expect((await o1.get()).exists).to.be.false;
    expect((await o2.get()).exists).to.be.false;
    expect((await o3.get()).exists).to.be.false;

    // Run cleanup with maxOrphansPerRun: 1
    const cappedResult = await runCleanup(db, auth, {
      dryRun: false,
      maxOrphansPerRun: 1,
      now: Timestamp.now(),
    });

    expect(cappedResult.orphanSubtreesScanned).to.equal(1);
    expect(cappedResult.orphanSubtreesSwept).to.equal(1);

    // Count remaining orphaned subcollections
    let remainingOrphans = 0;
    if ((await o1.collection('sealed').get()).size > 0) remainingOrphans++;
    if ((await o2.collection('sealed').get()).size > 0) remainingOrphans++;
    if ((await o3.collection('sealed').get()).size > 0) remainingOrphans++;
    expect(remainingOrphans).to.equal(2);

    // Run cleanup with default cap to sweep all remaining
    const fullResult = await runCleanup(db, auth, {
      dryRun: false,
      now: Timestamp.now(),
    });

    expect(fullResult.orphanSubtreesSwept).to.equal(2);

    expect((await o1.collection('sealed').get()).size).to.equal(0);
    expect((await o2.collection('sealed').get()).size).to.equal(0);
    expect((await o3.collection('sealed').get()).size).to.equal(0);
  });

  it('(h) should bound orphanSubtreesScanned to maxOrphansPerRun across mixed live and orphaned rooms', async () => {
    // Seed 2 live rooms and 2 orphaned rooms
    const live1 = db.collection('rooms').doc('LIVE_MIX_1');
    const live2 = db.collection('rooms').doc('LIVE_MIX_2');
    const orph1 = db.collection('rooms').doc('ORPH_MIX_1');
    const orph2 = db.collection('rooms').doc('ORPH_MIX_2');

    await live1.set({ code: 'LIVE_MIX_1', phase: 'lobby', expiresAt: Timestamp.fromMillis(Date.now() + 3600 * 1000) });
    await live2.set({ code: 'LIVE_MIX_2', phase: 'lobby', expiresAt: Timestamp.fromMillis(Date.now() + 3600 * 1000) });
    await orph1.collection('sealed').doc('s1').set({ data: '1' });
    await orph2.collection('sealed').doc('s2').set({ data: '2' });

    const cappedResult = await runCleanup(db, auth, {
      dryRun: false,
      maxOrphansPerRun: 2,
      now: Timestamp.now(),
    });

    expect(cappedResult.orphanSubtreesScanned).to.equal(2);
  });
});
