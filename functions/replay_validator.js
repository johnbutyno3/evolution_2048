'use strict';

const MAX_REPLAY_VERSION = 1;
const BOARD_SIZE = 4;
const BOARD_CELLS = 16;
const MAX_EVENTS = 5000;
const TOOL_TYPES = new Set(['revive', 'timeRewind', 'positionSwap', 'duplicate']);

function fail(reason, details = {}) {
  const error = new Error(reason);
  error.code = 'INVALID_REPLAY';
  error.details = details;
  throw error;
}

function isPowerOfTwo(value) {
  return Number.isInteger(value) && value >= 2 && (value & (value - 1)) === 0;
}

function cloneBoard(board) {
  return board.slice();
}

function boardKey(board) {
  return board.map((value) => value ?? 0).join(',');
}

function validateIndex(index) {
  if (!Number.isInteger(index) || index < 0 || index >= BOARD_CELLS) {
    fail('Board index is invalid.', { index });
  }
}

function validateChapter(chapterIndex) {
  if (!Number.isInteger(chapterIndex) || chapterIndex < 0 || chapterIndex > 5) {
    fail('Chapter index is invalid.', { chapterIndex });
  }
}

function targetForChapter(chapterIndex) {
  return 2 ** (chapterIndex + 12);
}

function allowedToolsForChapter(chapterIndex) {
  return [
    ['timeRewind'],
    ['timeRewind', 'revive'],
    ['timeRewind', 'revive', 'positionSwap'],
    ['timeRewind', 'revive', 'positionSwap', 'duplicate'],
    ['timeRewind', 'revive', 'positionSwap', 'duplicate'],
    ['timeRewind'],
  ][chapterIndex];
}

function validateInitialTiles(initialTiles, target) {
  if (!Array.isArray(initialTiles) || initialTiles.length !== BOARD_CELLS) {
    fail('Initial board must contain exactly 16 cells.');
  }

  let nonEmpty = 0;
  for (const value of initialTiles) {
    if (value === null) continue;

    // GameEngine starts every new board with exactly two tiles, each 2 or 4.
    // Rejecting every other value prevents a forged replay from starting at a
    // later evolution stage.
    if (value !== 2 && value !== 4) {
      fail('Initial tile value must be 2 or 4.', { value, target });
    }

    nonEmpty += 1;
  }

  if (nonEmpty !== 2) {
    fail('Initial board must contain exactly two tiles.', { nonEmpty });
  }
}

function applyMove(board, direction, target) {
  if (!['up', 'down', 'left', 'right'].includes(direction)) {
    fail('Move direction is invalid.', { direction });
  }

  const before = cloneBoard(board);
  let mergeScore = 0;

  const readLine = (line) => {
    const values = [];
    for (let position = 0; position < BOARD_SIZE; position += 1) {
      let row;
      let column;
      if (direction === 'left') {
        row = line; column = position;
      } else if (direction === 'right') {
        row = line; column = BOARD_SIZE - 1 - position;
      } else if (direction === 'up') {
        row = position; column = line;
      } else {
        row = BOARD_SIZE - 1 - position; column = line;
      }
      values.push(board[row * BOARD_SIZE + column]);
    }
    return values.filter((value) => value !== null);
  };

  const writeLine = (line, merged) => {
    for (let position = 0; position < BOARD_SIZE; position += 1) {
      let row;
      let column;
      if (direction === 'left') {
        row = line; column = position;
      } else if (direction === 'right') {
        row = line; column = BOARD_SIZE - 1 - position;
      } else if (direction === 'up') {
        row = position; column = line;
      } else {
        row = BOARD_SIZE - 1 - position; column = line;
      }
      board[row * BOARD_SIZE + column] = position < merged.length ? merged[position] : null;
    }
  };

  for (let line = 0; line < BOARD_SIZE; line += 1) {
    const values = readLine(line);
    const merged = [];
    for (let position = 0; position < values.length; ) {
      const current = values[position];
      const next = values[position + 1];
      if (next !== undefined && next === current && current < target) {
        const value = current * 2;
        merged.push(value);
        mergeScore += value;
        position += 2;
      } else {
        merged.push(current);
        position += 1;
      }
    }
    writeLine(line, merged);
  }

  return {
    changed: boardKey(before) !== boardKey(board),
    mergeScore,
  };
}

function validateSpawn(board, spawnIndex, spawnValue) {
  if (!Number.isInteger(spawnIndex) || !Number.isInteger(spawnValue)) {
    fail('Move spawn data is missing or invalid.');
  }
  validateIndex(spawnIndex);
  if (board[spawnIndex] !== null) {
    fail('Spawn position is not empty.', { spawnIndex });
  }
  if (spawnValue !== 2 && spawnValue !== 4) {
    fail('Spawn value must be 2 or 4.', { spawnValue });
  }
  board[spawnIndex] = spawnValue;
}

function validateOptionalSpawn(board, event, reason) {
  const hasIndex = Object.prototype.hasOwnProperty.call(event, 'spawnIndex');
  const hasValue = Object.prototype.hasOwnProperty.call(event, 'spawnValue');
  if (hasIndex !== hasValue) {
    fail(`${reason} spawn data must contain both fields or neither.`);
  }
  if (hasIndex) validateSpawn(board, event.spawnIndex, event.spawnValue);
}

function highestValue(board, current) {
  return Math.max(current, ...board.filter((value) => value !== null));
}

function replayGame({ replayLog, chapterIndex, targetValue, allowedTools }) {
  validateChapter(chapterIndex);
  const target = targetValue ?? targetForChapter(chapterIndex);
  if (!Number.isInteger(target) || target !== targetForChapter(chapterIndex)) {
    fail('Target value is invalid.', { target, chapterIndex });
  }

  if (!replayLog || typeof replayLog !== 'object') fail('Replay log is missing.');
  if (replayLog.version !== MAX_REPLAY_VERSION) {
    fail('Replay log version is unsupported.', { version: replayLog.version });
  }
  if (replayLog.chapter !== undefined && replayLog.chapter !== null) {
    const expectedNames = ['ocean', 'land', 'sky', 'history', 'tech', 'universe'];
    if (replayLog.chapter !== expectedNames[chapterIndex]) {
      fail('Replay chapter does not match the session.', { replayChapter: replayLog.chapter, chapterIndex });
    }
  }

  const events = replayLog.events;
  if (!Array.isArray(events) || events.length > MAX_EVENTS) {
    fail('Replay event count is invalid.', { count: Array.isArray(events) ? events.length : null });
  }

  const board = replayLog.initialTiles.slice();
  validateInitialTiles(board, target);

  const permitted = new Set(
    Array.isArray(allowedTools) ? allowedTools : allowedToolsForChapter(chapterIndex),
  );
  for (const tool of permitted) {
    if (!TOOL_TYPES.has(tool)) fail('Unknown permitted tool.', { tool });
  }

  let score = 0;
  let penalty = 0;
  let highest = highestValue(board, 0);
  let previous = null;
  let completed = board.includes(target);
  const toolUsage = { revive: 0, timeRewind: 0, positionSwap: 0, duplicate: 0 };

  for (let eventNumber = 0; eventNumber < events.length; eventNumber += 1) {
    const event = events[eventNumber];
    if (!event || typeof event !== 'object' || typeof event.type !== 'string') {
      fail('Replay event is invalid.', { eventNumber });
    }
    if (completed) {
      fail('Replay contains events after chapter completion.', { eventNumber });
    }

    switch (event.type) {
      case 'move': {
        const beforeBoard = cloneBoard(board);
        const beforeScore = score;
        const result = applyMove(board, event.direction, target);
        if (!result.changed) {
          previous = null;
          if (Object.prototype.hasOwnProperty.call(event, 'spawnIndex') ||
              Object.prototype.hasOwnProperty.call(event, 'spawnValue')) {
            if (event.spawnIndex !== -1 || event.spawnValue !== -1) {
              fail('An unchanged move cannot contain a spawn.');
            }
          }
          continue;
        }

        previous = { board: beforeBoard, score: beforeScore };
        score += result.mergeScore;
        highest = highestValue(board, highest);

        const spawnIndex = event.spawnIndex;
        const spawnValue = event.spawnValue;
        if (spawnIndex === -1 && spawnValue === -1) {
          if (!board.every((value) => value !== null) && !board.includes(target)) {
            fail('A successful non-final move must spawn a tile.', { eventNumber });
          }
        } else {
          validateSpawn(board, spawnIndex, spawnValue);
          highest = highestValue(board, highest);
        }

        if (board.includes(target)) completed = true;
        break;
      }

      case 'revive': {
        if (!permitted.has('revive')) fail('REMOVE is not allowed in this chapter.');
        validateIndex(event.index);
        if (board[event.index] === null) fail('REMOVE target is empty.');
        const removedValue = board[event.index];
        board[event.index] = null;
        score = Math.max(0, score - removedValue);
        penalty += removedValue;
        validateOptionalSpawn(board, event, 'REMOVE');
        highest = highestValue(board, highest);
        toolUsage.revive += 1;
        break;
      }

      case 'timeRewind': {
        if (!permitted.has('timeRewind')) fail('UNDO is not allowed in this chapter.');
        if (previous === null) fail('UNDO requires a previous successful move.');
        const revertedScore = Math.max(0, score - previous.score);
        board.splice(0, board.length, ...previous.board);
        score = previous.score;
        penalty += revertedScore;
        previous = null;
        toolUsage.timeRewind += 1;
        highest = highestValue(board, highest);
        break;
      }

      case 'positionSwap': {
        if (!permitted.has('positionSwap')) fail('SWAP is not allowed in this chapter.');
        validateIndex(event.firstIndex);
        validateIndex(event.secondIndex);
        if (event.firstIndex === event.secondIndex) fail('SWAP positions must differ.');
        if (board[event.firstIndex] === null || board[event.secondIndex] === null) {
          fail('SWAP requires two existing tiles.');
        }
        const penaltyValue = board[event.firstIndex] + board[event.secondIndex];
        [board[event.firstIndex], board[event.secondIndex]] =
          [board[event.secondIndex], board[event.firstIndex]];
        score = Math.max(0, score - penaltyValue);
        penalty += penaltyValue;
        highest = highestValue(board, highest);
        toolUsage.positionSwap += 1;
        break;
      }

      case 'duplicate': {
        if (!permitted.has('duplicate')) fail('DUPLICATE is not allowed in this chapter.');
        validateIndex(event.sourceIndex);
        validateIndex(event.targetIndex);
        if (event.sourceIndex === event.targetIndex) fail('DUPLICATE positions must differ.');
        const source = board[event.sourceIndex];
        if (source === null || board[event.targetIndex] !== null) {
          fail('DUPLICATE requires an existing source and empty target.');
        }
        board[event.targetIndex] = source;
        score = Math.max(0, score - source);
        penalty += source;
        highest = highestValue(board, highest);
        toolUsage.duplicate += 1;
        break;
      }

      default:
        fail('Unknown replay event type.', { eventNumber, type: event.type });
    }
  }

  if (!completed || !board.includes(target)) {
    fail('Replay did not reach the chapter target.', { target, highest });
  }

  return {
    valid: true,
    score,
    highestValue: highest,
    targetValue: target,
    toolUsage,
    toolPenaltyTotal: penalty,
    finalBoard: board,
    eventCount: events.length,
  };
}

module.exports = {
  replayGame,
  allowedToolsForChapter,
  targetForChapter,
  MAX_EVENTS,
};
