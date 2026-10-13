const crypto = require('crypto');

const OPERATION_ID_PATTERN = /^[A-Za-z0-9_-]{12,128}$/;

function createRestartOperationContext({
  uid,
  operationId,
  chapterIndex,
  initialTiles,
  replaySessionId = null,
  replayLog = null,
}) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new TypeError('A valid uid is required.');
  }
  if (typeof operationId !== 'string' ||
      !OPERATION_ID_PATTERN.test(operationId)) {
    const error = new Error('Invalid restart operation ID.');
    error.code = 'invalid-argument';
    throw error;
  }

  const requestFingerprint = crypto.createHash('sha256')
    .update(JSON.stringify({
      chapterIndex,
      initialTiles,
      replaySessionId,
      replayLog,
    }))
    .digest('hex');
  const operationDocId = crypto.createHash('sha256')
    .update(`${uid}:restartGameSession:${operationId}`)
    .digest('hex');
  const sessionId = crypto.createHash('sha256')
    .update(`${uid}:restart-session:${operationId}`)
    .digest('hex')
    .slice(0, 32);

  return { operationDocId, requestFingerprint, sessionId };
}

function restartFingerprintMatches(operation, requestFingerprint) {
  return Boolean(operation) &&
    typeof operation.requestFingerprint === 'string' &&
    operation.requestFingerprint === requestFingerprint;
}

module.exports = {
  OPERATION_ID_PATTERN,
  createRestartOperationContext,
  restartFingerprintMatches,
};
