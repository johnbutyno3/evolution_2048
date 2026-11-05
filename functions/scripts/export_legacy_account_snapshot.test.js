'use strict';

const assert = require('node:assert/strict');
const { normalizeAccount } = require('./export_legacy_account_snapshot');

const source = {
  user: { playerName: '  Ocean   Player ', avatarIndex: 12 },
  membership: { type: 'premium', expiresAt: null },
  gold: { balance: 1250 },
  tools: {
    timeRewind: 0,
    revive: 3,
    positionSwap: 2,
    duplicate: 1,
    initialUndoGranted: false,
  },
  life: { lives: 3, regenStartAt: new Date(Date.now() - 5 * 60 * 1000).toISOString() },
  gameProgress: {
    chapterProgress: {
      ocean: { highestValue: 256, score: 12345 },
      tech: { highestValue: 4096, score: 50000 },
      universe: { highestValue: 0, score: 0 },
    },
  },
  collection: {
    ocean: [2, 4, 256],
    technology: [65536],
    space: [131072],
  },
};

const result = normalizeAccount('firebase-uid-example', source);
assert.deepEqual(result.validationErrors, []);
assert.equal(result.membershipReview.legacyTier, 'PREMIUM');
assert.equal(result.membershipReview.requiresApproval, true);
assert.equal(result.payload.profile.playerName, 'Ocean Player');
assert.equal(result.payload.membership.tier, 'FREE', 'Legacy membership is not automatically promoted without purchase evidence.');
assert.equal(result.payload.gold.balance, 1250);
assert.equal(result.payload.tools.UNDO, 1, 'Legacy initial-UNDO grant must be preserved exactly once.');
assert.equal(result.payload.tools.REMOVE, 3);
assert.equal(result.payload.tools.SWAP, 2);
assert.equal(result.payload.tools.DUPLICATE, 1);
assert.equal(result.payload.lives.count, 3);
assert.ok(Date.parse(result.payload.lives.nextRegenAt) > Date.now());
assert.deepEqual(
  result.payload.chapters.map((entry) => [entry.chapterCode, entry.highestStage]),
  [['C1', 8], ['C5', 12], ['C6', 0]],
);
assert.deepEqual(
  result.payload.collection,
  [
    { chapterCode: 'C1', creatureValue: 2 },
    { chapterCode: 'C1', creatureValue: 4 },
    { chapterCode: 'C1', creatureValue: 256 },
    { chapterCode: 'C5', creatureValue: 65536 },
    { chapterCode: 'C6', creatureValue: 131072 },
  ],
);

const invalid = normalizeAccount('bad-uid', {
  user: {},
  membership: {},
  gold: { balance: -1 },
  tools: { timeRewind: -1, revive: 0, positionSwap: 0, duplicate: 0 },
  life: { lives: 7 },
  gameProgress: { chapterProgress: { ocean: { highestValue: 3, score: -1 } } },
  collection: { ocean: [3] },
});
assert.ok(invalid.validationErrors.includes('invalid_gold_balance'));
assert.ok(invalid.validationErrors.includes('invalid_life_count'));
assert.ok(invalid.validationErrors.includes('invalid_tool_quantity:UNDO'));
assert.ok(invalid.validationErrors.includes('invalid_highest_value:C1'));
assert.ok(invalid.validationErrors.includes('invalid_collection_value:C1:3'));

console.log('Firebase legacy export normalization contract passed.');
