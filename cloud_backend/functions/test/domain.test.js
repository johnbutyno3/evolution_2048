'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const domain = require('../src/domain');

test('life regeneration adds elapsed lives but never regenerates above five', () => {
  const now = 100 * domain.LIFE_REGEN_INTERVAL_MS;
  assert.deepEqual(domain.regenerateLives({
    lives: 2, nextLifeAtMillis: now - 2 * domain.LIFE_REGEN_INTERVAL_MS, nowMillis: now,
  }), { lives: 5, nextLifeAtMillis: null });
});

test('life regeneration leaves countdown untouched before expiry', () => {
  assert.deepEqual(domain.regenerateLives({
    lives: 3, nextLifeAtMillis: 5000, nowMillis: 4999,
  }), { lives: 3, nextLifeAtMillis: 5000 });
});

test('Golden membership yields unlimited lives and no countdown', () => {
  assert.deepEqual(domain.createLifeResponse({
    lives: 1, membership: 'golden', expiresAtMillis: 9000, nextLifeAtMillis: 8000, nowMillis: 1000,
  }), {
    lives: -1, infiniteLives: true, membership: 'golden', lifeMode: 'golden', nextLifeAtMillis: null,
  });
});

test('expired Golden membership is treated as normal membership state', () => {
  assert.equal(domain.createLifeResponse({
    lives: 3, membership: 'golden', expiresAtMillis: 10, nextLifeAtMillis: 100, nowMillis: 20,
  }).infiniteLives, false);
});

test('chapter indexes are bounded to six chapters', () => {
  assert.equal(domain.validateChapterIndex(5), 5);
  assert.throws(() => domain.validateChapterIndex(6), { code: 'invalid-argument' });
});

test('tool names are allow-listed', () => {
  assert.equal(domain.normalizeToolType('timeRewind'), 'timeRewind');
  assert.throws(() => domain.normalizeToolType('adminGrant'), { code: 'invalid-argument' });
});

test('creature discovery accepts powers of two only', () => {
  assert.equal(domain.validateCreatureValue(4096), 4096);
  assert.throws(() => domain.validateCreatureValue(12), { code: 'invalid-argument' });
});

test('chapter aliases normalize to stable storage keys', () => {
  assert.equal(domain.normalizeChapterKey('chapter5Tech'), 'technology');
  assert.equal(domain.normalizeChapterKey('chapter6Universe'), 'space');
});
