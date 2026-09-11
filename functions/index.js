const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();
setGlobalOptions({ region: 'us-central1' });

const db = getFirestore();
const MAX_CHAPTER_INDEX = 5;

const TARGETS = [4096, 8192, 16384, 32768, 65536, 131072];

exports.completeChapter = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication is required to update chapter progress.',
    );
  }

  const data = request.data || {};
  const chapterIndex = data.chapterIndex;
  const highestValue = data.highestValue;
  const score = data.score;

  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 ||
      chapterIndex > MAX_CHAPTER_INDEX) {
    throw new HttpsError('invalid-argument', 'Invalid chapter index.');
  }

  if (!Number.isInteger(highestValue) || highestValue < 0) {
    throw new HttpsError('invalid-argument', 'Invalid highest value.');
  }

  if (!Number.isInteger(score) || score < 0) {
    throw new HttpsError('invalid-argument', 'Invalid score.');
  }

  const uid = request.auth.uid;
  const progressRef = db
    .collection('users')
    .doc(uid)
    .collection('progress')
    .doc('game');

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(progressRef);
    const current = snapshot.data() || {};
    const currentUnlocked = Number.isInteger(current.unlockedChapterIndex)
      ? Math.min(Math.max(current.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
      : 0;

    if (chapterIndex > currentUnlocked) {
      throw new HttpsError(
        'permission-denied',
        'Chapter is not unlocked.',
      );
    }

    if (highestValue < TARGETS[chapterIndex]) {
      throw new HttpsError(
        'failed-precondition',
        'Chapter target has not been reached.',
      );
    }

    const nextUnlocked = Math.min(
      MAX_CHAPTER_INDEX,
      Math.max(currentUnlocked, chapterIndex + 1),
    );

    transaction.set(
      progressRef,
      {
        unlockedChapterIndex: nextUnlocked,
        [`chapter_${chapterIndex}_completed`]: true,
        [`chapter_${chapterIndex}_highestValue`]: highestValue,
        [`chapter_${chapterIndex}_bestScore`]: score,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { unlockedChapterIndex: nextUnlocked };
  });
});
