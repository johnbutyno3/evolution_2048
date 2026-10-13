'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const domain = require('../src/domain');

test('all public tool types are explicitly allow-listed', () => {
  assert.deepEqual([...domain.TOOL_TYPES].sort(), ['duplicate', 'positionSwap', 'revive', 'timeRewind'].sort());
});

test('session lifetime is two hours and regeneration interval is forty minutes', () => {
  assert.equal(domain.GAME_SESSION_TTL_MS, 2 * 60 * 60 * 1000);
  assert.equal(domain.LIFE_REGEN_INTERVAL_MS, 40 * 60 * 1000);
});

test('uid validation rejects missing identities', () => {
  assert.throws(() => domain.requireUid(''), { code: 'unauthenticated' });
});

test('chapter aliases reject unknown values instead of creating arbitrary collection keys', () => {
  assert.throws(() => domain.normalizeChapterKey('admin'), { code: 'invalid-argument' });
});
