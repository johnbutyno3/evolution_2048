'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

if (getApps().length === 0) initializeApp();
const db = getFirestore();

const MAX_MESSAGE_LENGTH = 4000;
const MAX_SUBJECT_LENGTH = 160;

function casesRef() {
  return db.collection('support_cases');
}

function caseRef(caseId) {
  if (typeof caseId !== 'string' || !/^[A-Za-z0-9_-]{10,128}$/.test(caseId)) {
    throw new HttpsError('invalid-argument', 'Invalid support case ID.');
  }
  return casesRef().doc(caseId);
}

async function requireIdentity(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required.');
  }
  const uid = request.auth.uid;
  const userSnapshot = await db.collection('users').doc(uid).get();
  return { uid, isAdmin: userSnapshot.data()?.isAdmin === true };
}

function normalizeMessage(value) {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'Message text is required.');
  }
  const message = value.trim();
  if (!message || message.length > MAX_MESSAGE_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `Message must contain 1 to ${MAX_MESSAGE_LENGTH} characters.`,
    );
  }
  return message;
}

// Intentionally does not call enforceSensitiveOperation: a locked or
// restricted player must retain a path to appeal and communicate with support.
exports.openSupportCase = onCall(async (request) => {
  const { uid } = await requireIdentity(request);
  const subject = typeof request.data?.subject === 'string'
    ? request.data.subject.trim()
    : '';
  const message = normalizeMessage(request.data?.message);

  if (!subject || subject.length > MAX_SUBJECT_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `Subject must contain 1 to ${MAX_SUBJECT_LENGTH} characters.`,
    );
  }

  const caseDocument = casesRef().doc();
  const firstMessage = caseDocument.collection('messages').doc();
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.create(caseDocument, {
    caseId: caseDocument.id,
    uid,
    subject,
    status: 'open',
    createdAt: now,
    updatedAt: now,
    lastMessageAt: now,
    lastMessageSender: 'player',
    messageCount: 1,
  });
  batch.create(firstMessage, {
    messageId: firstMessage.id,
    senderUid: uid,
    senderRole: 'player',
    text: message,
    createdAt: now,
  });
  await batch.commit();

  return { caseId: caseDocument.id, status: 'open' };
});

exports.sendSupportMessage = onCall(async (request) => {
  const { uid, isAdmin } = await requireIdentity(request);
  const ref = caseRef(request.data?.caseId);
  const message = normalizeMessage(request.data?.message);
  const messageRef = ref.collection('messages').doc();
  const now = FieldValue.serverTimestamp();

  // Validate status and append the message in one transaction. This prevents
  // a player message racing with an admin close operation and landing after
  // the case has already been closed.
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throw new HttpsError('not-found', 'Support case was not found.');
    }

    const supportCase = snapshot.data() || {};
    if (!isAdmin && supportCase.uid !== uid) {
      throw new HttpsError('permission-denied', 'This support case belongs to another account.');
    }
    if (supportCase.status === 'closed') {
      throw new HttpsError('failed-precondition', 'This support case is closed.');
    }

    transaction.create(messageRef, {
      messageId: messageRef.id,
      senderUid: uid,
      senderRole: isAdmin ? 'admin' : 'player',
      text: message,
      createdAt: now,
    });
    transaction.update(ref, {
      updatedAt: now,
      lastMessageAt: now,
      lastMessageSender: isAdmin ? 'admin' : 'player',
      messageCount: FieldValue.increment(1),
    });
  });

  return { caseId: ref.id, messageId: messageRef.id };
});

exports.listMySupportCases = onCall(async (request) => {
  const { uid } = await requireIdentity(request);
  const requestedLimit = request.data?.limit;
  const limit = Number.isInteger(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 50)
    : 20;
  const snapshot = await casesRef()
    .where('uid', '==', uid)
    .orderBy('updatedAt', 'desc')
    .limit(limit)
    .get();

  return {
    cases: snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        caseId: doc.id,
        subject: data.subject,
        status: data.status,
        createdAt: data.createdAt?.toDate?.().toISOString() ?? null,
        updatedAt: data.updatedAt?.toDate?.().toISOString() ?? null,
        lastMessageSender: data.lastMessageSender ?? null,
        messageCount: data.messageCount ?? 0,
      };
    }),
  };
});

exports.listSupportMessages = onCall(async (request) => {
  const { uid, isAdmin } = await requireIdentity(request);
  const ref = caseRef(request.data?.caseId);
  const supportSnapshot = await ref.get();

  if (!supportSnapshot.exists) {
    throw new HttpsError('not-found', 'Support case was not found.');
  }
  if (!isAdmin && supportSnapshot.data()?.uid !== uid) {
    throw new HttpsError('permission-denied', 'This support case belongs to another account.');
  }

  const requestedLimit = request.data?.limit;
  const limit = Number.isInteger(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 100)
    : 50;
  const snapshot = await ref.collection('messages')
    .orderBy('createdAt', 'asc')
    .limitToLast(limit)
    .get();

  return {
    caseId: ref.id,
    status: supportSnapshot.data()?.status ?? 'open',
    messages: snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        messageId: doc.id,
        senderRole: data.senderRole,
        text: data.text,
        createdAt: data.createdAt?.toDate?.().toISOString() ?? null,
      };
    }),
  };
});

exports.setSupportCaseStatusAdmin = onCall(async (request) => {
  const { uid, isAdmin } = await requireIdentity(request);
  if (!isAdmin) {
    throw new HttpsError('permission-denied', 'Admin access is required.');
  }

  const ref = caseRef(request.data?.caseId);
  const status = request.data?.status;
  if (status !== 'open' && status !== 'closed') {
    throw new HttpsError('invalid-argument', 'Status must be open or closed.');
  }

  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new HttpsError('not-found', 'Support case was not found.');
  }

  await ref.update({
    status,
    updatedAt: FieldValue.serverTimestamp(),
    statusChangedAt: FieldValue.serverTimestamp(),
    statusChangedBy: uid,
  });

  return { caseId: ref.id, status };
});

exports.listSupportCasesAdmin = onCall(async (request) => {
  const { isAdmin } = await requireIdentity(request);
  if (!isAdmin) {
    throw new HttpsError('permission-denied', 'Admin access is required.');
  }
  const requestedLimit = request.data?.limit;
  const limit = Number.isInteger(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 100)
    : 50;
  const status = request.data?.status;
  let query = casesRef().orderBy('updatedAt', 'desc');
  if (status === 'open' || status === 'closed') {
    query = casesRef().where('status', '==', status).orderBy('updatedAt', 'desc');
  }
  const snapshot = await query.limit(limit).get();

  return {
    cases: snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        caseId: doc.id,
        uid: data.uid,
        subject: data.subject,
        status: data.status,
        createdAt: data.createdAt?.toDate?.().toISOString() ?? null,
        updatedAt: data.updatedAt?.toDate?.().toISOString() ?? null,
        lastMessageSender: data.lastMessageSender ?? null,
        messageCount: data.messageCount ?? 0,
      };
    }),
  };
});
