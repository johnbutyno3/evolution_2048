      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.update(purchaseRef, {
      provider,
      transactionId,
      status: 'pending',
    });

    return { purchaseId, status: 'pending' };
  });
});

async function consumeLifeInTransaction(transaction, uid, membershipSnapshot = null) {
  const lifeRef = db.collection('users').doc(uid).collection('life').doc('current');
  const resolvedMembershipSnapshot = membershipSnapshot ??
    await transaction.get(membershipRef(uid));
  const membership = resolveMembership(resolvedMembershipSnapshot.data() || {});
  const lifeSnapshot = await transaction.get(lifeRef);
  const data = lifeSnapshot.data() || {};
  let lives = normalizeLives(data.lives);
  let regenStartMillis = normalizeRegenStart(data.regenStartAt);
  const nowMillis = Date.now();

  if (membership.infiniteLives) {
    transaction.set(lifeRef, {
      lives: NORMAL_CAP,
      regenStartAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return lifeResponse(NORMAL_CAP, null, membership);
  }

  const regenerated = regenerate({
    lives,
    regenStartMillis,
    nowMillis,
    interval: intervalMs(membership),
  });
  lives = regenerated.lives;
  regenStartMillis = regenerated.regenStartMillis;

  if (lives <= 0) {
    throw new HttpsError('failed-precondition', 'No lives available.');
  }

  lives -= 1;
  if (lives < NORMAL_CAP && regenStartMillis == null) {
    regenStartMillis = nowMillis;
  }

  transaction.set(lifeRef, {
    lives,
    regenStartAt: regenStartMillis == null
      ? null
      : Timestamp.fromMillis(regenStartMillis),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return lifeResponse(lives, regenStartMillis, membership);
}
{