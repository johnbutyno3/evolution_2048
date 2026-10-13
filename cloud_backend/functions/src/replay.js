'use strict';

// Server-side replay simulation. Client-reported score/highest tile are never trusted.
const MAX_REPLAY_VERSION = 1;
const CELL_COUNT = 16;
const MAX_EVENTS = 5000;
const CHAPTERS = Object.freeze(['ocean', 'land', 'sky', 'history', 'tech', 'universe']);
const TOOLS = Object.freeze(['revive', 'timeRewind', 'positionSwap', 'duplicate']);

function invalid(message, details = {}) {
  const error = new TypeError(message);
  error.code = 'invalid-argument';
  error.details = details;
  throw error;
}
function indexOf(value, label) {
  if (!Number.isInteger(value) || value < 0 || value >= CELL_COUNT) invalid(label + ' is out of range.', { value });
}
function targetForChapter(chapterIndex) {
  if (!Number.isInteger(chapterIndex) || chapterIndex < 0 || chapterIndex > 5) invalid('Invalid chapter index.');
  return 2 ** (chapterIndex + 12);
}
function permittedTools(chapterIndex, testOverride = false) {
  if (testOverride) return [...TOOLS];
  return [
    ['timeRewind'],
    ['timeRewind', 'revive'],
    ['timeRewind', 'revive', 'positionSwap'],
    ['timeRewind', 'revive', 'positionSwap', 'duplicate'],
    ['timeRewind', 'revive', 'positionSwap', 'duplicate'],
    ['timeRewind'],
  ][chapterIndex];
}
function clone(board) { return board.slice(); }
function key(board) { return board.map((v) => v === null ? 0 : v).join(':'); }
function highest(board, prior = 0) {
  return board.reduce((max, value) => value === null ? max : Math.max(max, value), prior);
}
function validateBoard(board) {
  if (!Array.isArray(board) || board.length !== CELL_COUNT) invalid('Replay initialTiles must contain 16 cells.');
  let count = 0;
  for (const value of board) {
    if (value === null) continue;
    if (value !== 2 && value !== 4) invalid('Initial tiles must be 2 or 4.');
    count += 1;
  }
  if (count !== 2) invalid('Initial board must contain exactly two tiles.');
}
function move(board, direction, target) {
  if (!['up', 'down', 'left', 'right'].includes(direction)) invalid('Invalid move direction.');
  const before = key(board);
  let points = 0;
  for (let line = 0; line < 4; line += 1) {
    const cells = [];
    for (let p = 0; p < 4; p += 1) {
      const row = direction === 'left' || direction === 'right' ? line :
        (direction === 'up' ? p : 3 - p);
      const col = direction === 'up' || direction === 'down' ? line :
        (direction === 'left' ? p : 3 - p);
      cells.push(row * 4 + col);
    }
    const values = cells.map((i) => board[i]).filter((v) => v !== null);
    const merged = [];
    for (let i = 0; i < values.length;) {
      if (i + 1 < values.length && values[i] === values[i + 1] && values[i] < target) {
        const value = values[i] * 2;
        merged.push(value);
        points += value;
        i += 2;
      } else {
        merged.push(values[i]);
        i += 1;
      }
    }
    cells.forEach((cell, p) => { board[cell] = p < merged.length ? merged[p] : null; });
  }
  return { changed: key(board) !== before, points };
}
function spawn(board, event) {
  const hasIndex = Object.hasOwn(event, 'spawnIndex');
  const hasValue = Object.hasOwn(event, 'spawnValue');
  if (hasIndex !== hasValue) invalid('Spawn must include both index and value.');
  if (!hasIndex) return;
  indexOf(event.spawnIndex, 'spawnIndex');
  if (board[event.spawnIndex] !== null) invalid('Spawn cell is not empty.');
  if (event.spawnValue !== 2 && event.spawnValue !== 4) invalid('Spawn value must be 2 or 4.');
  board[event.spawnIndex] = event.spawnValue;
}

function validateReplay({ replayLog, chapterIndex, expectedInitialTiles, requireCompletion = true, tools }) {
  const target = targetForChapter(chapterIndex);
  if (!replayLog || typeof replayLog !== 'object' || replayLog.version !== MAX_REPLAY_VERSION) {
    invalid('Missing or unsupported replay log.');
  }
  if (replayLog.chapter != null && replayLog.chapter !== CHAPTERS[chapterIndex]) invalid('Replay chapter mismatch.');
  const events = replayLog.events;
  if (!Array.isArray(events) || events.length > MAX_EVENTS) invalid('Replay event count is invalid.');
  const board = clone(replayLog.initialTiles);
  validateBoard(board);
  if (expectedInitialTiles && (expectedInitialTiles.length !== board.length ||
      expectedInitialTiles.some((value, i) => value !== board[i]))) {
    invalid('Replay initial board does not match session.');
  }
  const allowed = new Set(tools || permittedTools(chapterIndex));
  for (const tool of allowed) if (!TOOLS.includes(tool)) invalid('Unknown tool permission.');
  let score = 0;
  let penalty = 0;
  let maxTile = highest(board);
  let previousMove = null;
  let completed = board.includes(target);
  const toolUsage = { revive: 0, timeRewind: 0, positionSwap: 0, duplicate: 0 };

  for (let eventNumber = 0; eventNumber < events.length; eventNumber += 1) {
    const event = events[eventNumber];
    if (!event || typeof event !== 'object' || typeof event.type !== 'string') invalid('Invalid replay event.', { eventNumber });
    if (completed) invalid('Replay contains actions after completion.', { eventNumber });
    if (event.type === 'move') {
      const priorBoard = clone(board);
      const priorScore = score;
      const result = move(board, event.direction, target);
      if (!result.changed) {
        previousMove = null;
        if ((Object.hasOwn(event, 'spawnIndex') || Object.hasOwn(event, 'spawnValue')) &&
            !(event.spawnIndex === -1 && event.spawnValue === -1)) invalid('Unchanged move cannot spawn.');
        continue;
      }
      previousMove = { board: priorBoard, score: priorScore };
      score += result.points;
      maxTile = highest(board, maxTile);
      if (event.spawnIndex === -1 && event.spawnValue === -1) {
        if (board.some((v) => v === null) && !board.includes(target)) invalid('Successful move must spawn a tile.');
      } else {
        if (!Object.hasOwn(event, 'spawnIndex') || !Object.hasOwn(event, 'spawnValue')) {
          invalid('Successful move must include spawn data or the explicit -1/-1 final-move marker.');
        }
        spawn(board, event);
        maxTile = highest(board, maxTile);
      }
      completed = board.includes(target);
    } else if (event.type === 'revive') {
      if (!allowed.has('revive')) invalid('revive is not allowed in this chapter.');
      indexOf(event.index, 'index');
      if (board[event.index] === null) invalid('revive target is empty.');
      const removed = board[event.index];
      board[event.index] = null;
      score = Math.max(0, score - removed);
      penalty += removed;
      spawn(board, event);
      maxTile = highest(board, maxTile);
      toolUsage.revive += 1;
    } else if (event.type === 'timeRewind') {
      if (!allowed.has('timeRewind')) invalid('timeRewind is not allowed in this chapter.');
      if (!previousMove) invalid('timeRewind requires a previous successful move.');
      const revertedScore = Math.max(0, score - previousMove.score);
      board.splice(0, board.length, ...previousMove.board);
      score = Math.max(0, previousMove.score - revertedScore);
      penalty += revertedScore;
      previousMove = null;
      maxTile = highest(board, maxTile);
      toolUsage.timeRewind += 1;
    } else if (event.type === 'positionSwap') {
      if (!allowed.has('positionSwap')) invalid('positionSwap is not allowed in this chapter.');
      indexOf(event.firstIndex, 'firstIndex'); indexOf(event.secondIndex, 'secondIndex');
      if (event.firstIndex === event.secondIndex || board[event.firstIndex] === null || board[event.secondIndex] === null) invalid('Invalid swap positions.');
      const cost = board[event.firstIndex] + board[event.secondIndex];
      [board[event.firstIndex], board[event.secondIndex]] = [board[event.secondIndex], board[event.firstIndex]];
      score = Math.max(0, score - cost); penalty += cost; maxTile = highest(board, maxTile);
      toolUsage.positionSwap += 1;
    } else if (event.type === 'duplicate') {
      if (!allowed.has('duplicate')) invalid('duplicate is not allowed in this chapter.');
      indexOf(event.sourceIndex, 'sourceIndex'); indexOf(event.targetIndex, 'targetIndex');
      const value = board[event.sourceIndex];
      if (event.sourceIndex === event.targetIndex || value === null || board[event.targetIndex] !== null) invalid('Invalid duplicate positions.');
      board[event.targetIndex] = value;
      score = Math.max(0, score - value); penalty += value; maxTile = highest(board, maxTile);
      toolUsage.duplicate += 1;
    } else {
      invalid('Unknown replay event type.', { eventNumber, type: event.type });
    }
  }
  if (requireCompletion && (!completed || !board.includes(target))) invalid('Replay did not reach chapter target.', { target, maxTile });
  return { valid: true, score, highestValue: maxTile, targetValue: target, toolUsage, toolPenaltyTotal: penalty, finalBoard: board, eventCount: events.length };
}

module.exports = { validateReplay, permittedTools, targetForChapter, MAX_EVENTS };
