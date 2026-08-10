const admin = require('firebase-admin');

// Initialize with ADC for project gaslight-46368
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'gaslight-46368'
});

const db = admin.firestore();

async function main() {
  const args = process.argv.slice(2);
  const isApply = args.includes('--apply');
  const isDryRun = !isApply;

  console.log(`=== STARTING BACKFILL EXPIRES_AT (${isApply ? 'APPLY MODE' : 'DRY-RUN MODE'}) ===`);

  const nowMs = Date.now();
  const twentyFourHoursAgoMs = nowMs - 24 * 60 * 60 * 1000;
  const oneHourFutureTimestamp = admin.firestore.Timestamp.fromMillis(nowMs + 60 * 60 * 1000);

  // 1. Fetch all room documents
  const roomsSnap = await db.collection('rooms').get();
  console.log(`Fetched ${roomsSnap.docs.length} total room documents.`);

  // 2. Identify active room codes (where any player has lastSeen > 24h ago)
  const activeRoomCodes = new Set();
  const allPlayersSnap = await db.collectionGroup('players').get();
  console.log(`Fetched ${allPlayersSnap.docs.length} total player documents across collectionGroup.`);

  for (const playerDoc of allPlayersSnap.docs) {
    const data = playerDoc.data();
    const roomRef = playerDoc.ref.parent.parent;
    const roomCode = roomRef ? roomRef.id : null;
    if (roomCode && data.lastSeen && typeof data.lastSeen === 'number' && data.lastSeen > twentyFourHoursAgoMs) {
      activeRoomCodes.add(roomCode);
    }
  }

  console.log(`Identified ${activeRoomCodes.size} rooms with recent player activity (lastSeen > 24h ago). These rooms will be skipped.`);

  // 3. Process Rooms
  let roomsMissingExpiresAt = 0;
  let roomsSkippedActive = 0;
  let roomsAlreadySet = 0;
  const roomDocsToUpdate = [];

  for (const roomDoc of roomsSnap.docs) {
    const data = roomDoc.data();
    if (data.expiresAt !== undefined) {
      roomsAlreadySet++;
      continue;
    }
    if (activeRoomCodes.has(roomDoc.id)) {
      roomsSkippedActive++;
      continue;
    }
    roomsMissingExpiresAt++;
    roomDocsToUpdate.push(roomDoc.ref);
  }

  // 4. Process Players
  let playersMissingExpiresAt = 0;
  let playersSkippedActive = 0;
  let playersAlreadySet = 0;
  const playerDocsToUpdate = [];

  for (const playerDoc of allPlayersSnap.docs) {
    const data = playerDoc.data();
    const roomRef = playerDoc.ref.parent.parent;
    const roomCode = roomRef ? roomRef.id : null;

    if (data.expiresAt !== undefined) {
      playersAlreadySet++;
      continue;
    }
    if (roomCode && activeRoomCodes.has(roomCode)) {
      playersSkippedActive++;
      continue;
    }
    playersMissingExpiresAt++;
    playerDocsToUpdate.push(playerDoc.ref);
  }

  console.log('\n--- SUMMARY ---');
  console.log(`Rooms missing expiresAt: ${roomsMissingExpiresAt} (Already set: ${roomsAlreadySet}, Skipped active: ${roomsSkippedActive})`);
  console.log(`Players missing expiresAt: ${playersMissingExpiresAt} (Already set: ${playersAlreadySet}, Skipped active: ${playersSkippedActive})`);

  if (isDryRun) {
    console.log('\n[DRY-RUN] No writes were performed. Pass --apply to execute updates.');
    process.exit(0);
  }

  // 5. Apply Updates in Batches of 400
  const allRefsToUpdate = [...roomDocsToUpdate, ...playerDocsToUpdate];
  console.log(`\nExecuting --apply for ${allRefsToUpdate.length} total documents...`);

  let batchCount = 0;
  const BATCH_SIZE = 400;

  for (let i = 0; i < allRefsToUpdate.length; i += BATCH_SIZE) {
    const chunk = allRefsToUpdate.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const ref of chunk) {
      batch.update(ref, { expiresAt: oneHourFutureTimestamp });
    }
    await batch.commit();
    batchCount++;
    console.log(`Committed batch ${batchCount} (${chunk.length} docs).`);
  }

  console.log(`\nSuccessfully backfilled expiresAt on ${allRefsToUpdate.length} documents across ${batchCount} batches.`);
}

main().catch(err => {
  console.error('Backfill script failed:', err);
  process.exit(1);
});
