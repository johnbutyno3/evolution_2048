const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

const auth = getAuth();
const db = getFirestore();

const uid = 'jp4wzawyjVaIcJIpIQXSSjj7mIv2';

async function main() {
  const user = await auth.getUser(uid);

  console.log('User:', user.email);
  console.log('UID:', user.uid);

  await auth.setCustomUserClaims(uid, {
    role: 'tester',
  });

  await db
    .collection('users')
    .doc(uid)
    .set({
      role: 'tester',
    }, { merge: true });

  console.log('');
  console.log('================================');
  console.log('Tester role configured successfully');
  console.log('Email:', user.email);
  console.log('UID:', uid);
  console.log('role: tester');
  console.log('================================');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
