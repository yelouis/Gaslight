import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";

export const DEFAULT_ROOM_EXPIRY_LIMIT = 100;
export const DEFAULT_ORPHAN_SWEEP_LIMIT = 100;
export const DEFAULT_AUTH_USERS_LIMIT = 500;
export const DEFAULT_AUTH_RETENTION_MS = 24 * 60 * 60 * 1000; // 24 hours

export interface CleanupOptions {
  dryRun?: boolean;
  maxRoomsPerRun?: number;
  maxOrphansPerRun?: number;
  maxUsersPerRun?: number;
  authRetentionMs?: number;
  now?: Timestamp;
}

export interface CleanupResult {
  dryRun: boolean;
  roomsScanned: number;
  roomsDeleted: number;
  orphanSubtreesScanned: number;
  orphanSubtreesSwept: number;
  authUsersScanned: number;
  authUsersReferenced: number;
  authUsersEligible: number;
  authUsersDeleted: number;
  errors: string[];
}

/**
 * Core cleanup routine for expired rooms, orphaned subtrees, and stale anonymous auth users.
 */
export async function runCleanup(
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth,
  options: CleanupOptions = {}
): Promise<CleanupResult> {
  const dryRun = options.dryRun !== undefined ? options.dryRun : (process.env.CLEANUP_DRY_RUN === "false" ? false : true);
  const maxRooms = options.maxRoomsPerRun ?? DEFAULT_ROOM_EXPIRY_LIMIT;
  const maxOrphans = options.maxOrphansPerRun ?? DEFAULT_ORPHAN_SWEEP_LIMIT;
  const maxUsers = options.maxUsersPerRun ?? DEFAULT_AUTH_USERS_LIMIT;
  const authRetentionMs = options.authRetentionMs ?? DEFAULT_AUTH_RETENTION_MS;
  const now = options.now ?? Timestamp.now();
  const nowMs = now.toMillis();

  const result: CleanupResult = {
    dryRun,
    roomsScanned: 0,
    roomsDeleted: 0,
    orphanSubtreesScanned: 0,
    orphanSubtreesSwept: 0,
    authUsersScanned: 0,
    authUsersReferenced: 0,
    authUsersEligible: 0,
    authUsersDeleted: 0,
    errors: [],
  };

  // 1. Query and delete expired rooms
  try {
    const expiredSnap = await db
      .collection("rooms")
      .where("expiresAt", "<=", now)
      .limit(maxRooms)
      .get();

    result.roomsScanned = expiredSnap.size;

    for (const doc of expiredSnap.docs) {
      if (!dryRun) {
        await db.recursiveDelete(doc.ref);
      }
      result.roomsDeleted++;
    }
  } catch (err: any) {
    const msg = `Error querying/deleting expired rooms: ${err?.message || err}`;
    console.error(msg);
    result.errors.push(msg);
  }

  // 2. Sweep orphaned subtrees (rooms whose parent document does not exist, but subcollections remain)
  try {
    const allRoomRefs = await db.collection("rooms").listDocuments();
    for (const roomRef of allRoomRefs) {
      if (result.orphanSubtreesScanned >= maxOrphans) {
        break;
      }
      result.orphanSubtreesScanned++;

      const snap = await roomRef.get();
      if (!snap.exists) {
        const subcollections = await roomRef.listCollections();
        if (subcollections.length > 0) {
          if (!dryRun) {
            await db.recursiveDelete(roomRef);
          }
          result.orphanSubtreesSwept++;
        }
      }
    }
  } catch (err: any) {
    const msg = `Error sweeping orphaned room subtrees: ${err?.message || err}`;
    console.error(msg);
    result.errors.push(msg);
  }

  // 3. Purge stale anonymous auth users
  // CRITICAL: Compute live referenced authUids AFTER steps 1 and 2, so only surviving rooms are considered.
  try {
    const activeAuthUids = new Set<string>();
    const survivingRoomRefs = await db.collection("rooms").listDocuments();
    for (const roomRef of survivingRoomRefs) {
      const snap = await roomRef.get();
      if (snap.exists) {
        const playersSnap = await roomRef.collection("players").get();
        for (const pDoc of playersSnap.docs) {
          const pData = pDoc.data();
          if (pData && typeof pData.authUid === "string" && pData.authUid.length > 0) {
            activeAuthUids.add(pData.authUid);
          }
        }
      }
    }

    const uidsToDelete: string[] = [];
    let pageToken: string | undefined = undefined;

    do {
      const listResult = await auth.listUsers(1000, pageToken);
      pageToken = listResult.pageToken;

      for (const user of listResult.users) {
        if (result.authUsersScanned >= maxUsers) {
          break;
        }
        result.authUsersScanned++;

        // Only consider anonymous users (providerData.length === 0)
        const isAnonymous = !user.providerData || user.providerData.length === 0;
        if (!isAnonymous) {
          continue;
        }

        // Determine last active timestamp
        const lastRefresh = user.metadata.lastRefreshTime ? new Date(user.metadata.lastRefreshTime).getTime() : 0;
        const lastSignIn = user.metadata.lastSignInTime ? new Date(user.metadata.lastSignInTime).getTime() : 0;
        const creation = user.metadata.creationTime ? new Date(user.metadata.creationTime).getTime() : 0;
        const lastActiveTime = Math.max(lastRefresh, lastSignIn, creation);

        const isStale = lastActiveTime > 0 && lastActiveTime <= (nowMs - authRetentionMs);
        if (!isStale) {
          continue;
        }

        // Check if referenced by an active player document in a surviving room
        if (activeAuthUids.has(user.uid)) {
          result.authUsersReferenced++;
          continue;
        }

        result.authUsersEligible++;
        uidsToDelete.push(user.uid);
      }
    } while (pageToken && result.authUsersScanned < maxUsers);

    if (!dryRun && uidsToDelete.length > 0) {
      // deleteUsers accepts max 1000 per call
      for (let i = 0; i < uidsToDelete.length; i += 1000) {
        const batch = uidsToDelete.slice(i, i + 1000);
        const deleteResult = await auth.deleteUsers(batch);
        result.authUsersDeleted += deleteResult.successCount;
        if (deleteResult.failureCount > 0) {
          for (const err of deleteResult.errors) {
            result.errors.push(`Failed to delete auth user: ${err.error.message}`);
          }
        }
      }
    }
  } catch (err: any) {
    const msg = `Error purging anonymous auth users: ${err?.message || err}`;
    console.error(msg);
    result.errors.push(msg);
  }

  // Structured Logging
  console.log(
    `[CLEANUP] Completed run: dryRun=${result.dryRun}, ` +
    `roomsScanned=${result.roomsScanned}, roomsDeleted=${result.roomsDeleted}, ` +
    `orphanSubtreesScanned=${result.orphanSubtreesScanned}, ` +
    `orphanSubtreesSwept=${result.orphanSubtreesSwept}, ` +
    `authUsersScanned=${result.authUsersScanned}, authUsersReferenced=${result.authUsersReferenced}, ` +
    `authUsersEligible=${result.authUsersEligible}, authUsersDeleted=${result.authUsersDeleted}, ` +
    `errors=${result.errors.length}`
  );

  return result;
}

export const cleanupDaily = onSchedule(
  {
    schedule: "every day 04:00",
    timeZone: "America/Los_Angeles",
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  async () => {
    const db = admin.firestore();
    const auth = admin.auth();
    await runCleanup(db, auth);
  }
);
