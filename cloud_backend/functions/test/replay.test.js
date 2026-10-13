'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { validateReplay, targetForChapter, permittedTools } = require('../src/replay');

const initial = [2, 2, null, null, ...Array(12).fill(null)];

test('chapter targets and tool permissions are server-defined', () => {
  assert.equal(targetForChapter(0), 4096);
  assert.equal(targetForChapter(5), 131072);
  assert.deepEqual(permittedTools(0), ['timeRewind']);
  assert.throws(() => targetForChapter(6), { code: 'invalid-argument' });
});

test('replay rejects a forged initial board', () => {
  assert.throws(() => validateReplay({
    replayLog: { version: 1, initialTiles: [4096, 2, ...Array(14).fill(null)], events: [] },
    chapterIndex: 0, requireCompletion: false,
  }), { code: 'invalid-argument' });
});

test('replay requires the session initial board to match', () => {
  assert.throws(() => validateReplay({
    replayLog: { version: 1, initialTiles: initial, events: [] },
    chapterIndex: 0, expectedInitialTiles: [4, 2, ...Array(14).fill(null)], requireCompletion: false,
  }), /does not match session/);
});

test('replay rejects events after target completion', () => {
  const board = [2048, 2048, null, null, ...Array(12).fill(null)];
  const replayLog = {
    version: 1, initialTiles: board,
    events: [{ type: 'move', direction: 'left', spawnIndex: -1, spawnValue: -1 },
      { type: 'move', direction: 'right', spawnIndex: -1, spawnValue: -1 }],
  };
  assert.throws(() => validateReplay({ replayLog, chapterIndex: 0 }), { code: 'invalid-argument' });
});

test('a non-completing replay returns server-calculated score and highest value', () => {
  const replayLog = {
    version: 1, initialTiles: initial,
    events: [{ type: 'move', direction: 'left', spawnIndex: 2, spawnValue: 2 }],
  };
  const result = validateReplay({ replayLog, chapterIndex: 0, requireCompletion: false });
  assert.equal(result.score, 4);
  assert.equal(result.highestValue, 4);
  assert.deepEqual(result.finalBoard.slice(0, 4), [4, 2, null, null]);
});
