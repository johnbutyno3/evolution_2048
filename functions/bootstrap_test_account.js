const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const db = getFirestore();
const PRIMARY_ADMIN_EMAIL = 'johnbutyno3@gmail.com';

exports.bootstrapPrimaryTestAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const callerEmail = request.auth.token?.email?.toLowerCase();
  if (callerEmail !== PRIMARY_ADMIN_EMAIL) {
    throw new HttpsError('permission-denied', 'This bootstrap is restricted to the primary test account.');
  }

  const auth = getAuth();
  const callerUid = request.auth.uid;

  // Make the primary account the only administrator before cleanup.
  await db.collection('users').doc(callerUid).set({
    isAdmin: true,
    updatedAt: require('firebase-admin/firestore').FieldValue.serverTimestamp(),
  }, { merge: true });

  const deleted = [];
  let pageToken;

  do {
    const page = await auth.listUsers(1000, pageToken);
    const otherUsers = page.users.filter((user) => user.uid !== callerUid);

    if (otherUsers.length > 0) {
      await auth.deleteUsers(otherUsers.map((user) => user.uid));
      for (const user of otherUsers) {
        deleted.push(user.uid);
        // Auth deletion does not remove Firestore data. Remove the matching
        // user document and all of its subcollections as part of this cleanup.
        await db.recursiveDelete(db.collection('users').doc(user.uid));
      }
    }

    pageToken = page.pageToken;
  } while (pageToken);

  // This is intentionally a one-time bootstrap operation.
  return {
    ok: true,
    primaryAdminEmail: PRIMARY_ADMIN_EMAIL,
    primaryAdminUid: callerUid,
    deletedAccountCount: deleted.length,
    deletedAccountUids: deleted,
  };
});
