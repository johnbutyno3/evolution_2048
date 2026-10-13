'use strict';

const NORMAL_LIFE_CAP = 5;
const LIFE_REGEN_INTERVAL_MS = 40 * 60 * 1000;
const GAME_SESSION_TTL_MS = 2 * 60 * 60 * 1000;
const MAX_CHAPTER_INDEX = 5;
const CHAPTER_STAGE_COUNTS = Object.freeze([12, 13, 14, 15, 16, 17]);
const TOOL_TYPES = Object.freeze(['revive', 'timeRewind', 'positionSwap', 'duplicate']);
const CHAPTER_KEYS = Object.freeze({
  ocean: 'ocean', land: 'land', sky: 'sky', history: 'history',
  tech: 'technology', technology: 'technology',
  universe: 'space', space: 'space',
  chapter1Ocean: 'ocean', chapter2Land: 'land', chapter3Sky: 'sky',
  chapter4History: 'history', chapter5Tech: 'technology',
  chapter6Space: 'space', chapter6Universe: 'space',
});

function requireInteger(value, name, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    const error = new TypeError(name + ' must be an integer between ' + min + ' and ' + max + '.');
    error.code = 'invalid-argument';
    throw error;
  }
  return value;
}

function requireUid(uid) {
  if (typeof uid !== 'string' || uid.trim().length === 0 || uid.length > 128) {
    const error = new TypeError('Authenticated user is required.');
    error.code = 'unauthenticated';
    throw error;
  }
  return uid;
}

function normalizeMembership(raw) {
  return ['general', 'premium', 'golden'].includes(raw) ? raw : 'general';
}

function isGoldenMembership(membership, expiresAtMillis, nowMillis = Date.now()) {
  return membership === 'golden' &&
    (expiresAtMillis == null || (Number.isFinite(expiresAtMillis) && expiresAtMillis > nowMillis));
}

function regenerateLives({ lives, nextLifeAtMillis, nowMillis = Date.now(), cap = NORMAL_LIFE_CAP }) {
  requireInteger(lives, 'lives', { min: 0 });
  requireInteger(nowMillis, 'nowMillis');
  requireInteger(cap, 'cap', { min: 1, max: NORMAL_LIFE_CAP });
  if (lives >= cap || nextLifeAtMillis == null) {
    return { lives, nextLifeAtMillis: lives >= cap ? null : nextLifeAtMillis };
  }
  requireInteger(nextLifeAtMillis, 'nextLifeAtMillis');
  if (nowMillis < nextLifeAtMillis) return { lives, nextLifeAtMillis };
  const elapsedIntervals = 1 + Math.floor((nowMillis - nextLifeAtMillis) / LIFE_REGEN_INTERVAL_MS);
  const recovered = Math.min(cap - lives, elapsedIntervals);
  const updatedLives = lives + recovered;
  return {
    lives: updatedLives,
    nextLifeAtMillis: updatedLives >= cap
      ? null
      : nextLifeAtMillis + recovered * LIFE_REGEN_INTERVAL_MS,
  };
}

function validateChapterIndex(index) {
  return requireInteger(index, 'chapterIndex', { min: 0, max: MAX_CHAPTER_INDEX });
}

function normalizeToolType(type) {
  if (!TOOL_TYPES.includes(type)) {
    const error = new TypeError('Invalid tool type.');
    error.code = 'invalid-argument';
    throw error;
  }
  return type;
}

function normalizeChapterKey(key) {
  if (typeof key !== 'string' || !Object.prototype.hasOwnProperty.call(CHAPTER_KEYS, key)) {
    const error = new TypeError('Invalid chapter key.');
    error.code = 'invalid-argument';
    throw error;
  }
  return CHAPTER_KEYS[key];
}

function validateCreatureValue(value) {
  requireInteger(value, 'value', { min: 2, max: 2 ** 17 });
  if ((value & (value - 1)) !== 0) {
    const error = new TypeError('Creature value must be a power of two.');
    error.code = 'invalid-argument';
    throw error;
  }
  return value;
}

function createLifeResponse({ lives, membership = 'general', expiresAtMillis = null, nextLifeAtMillis = null, nowMillis = Date.now() }) {
  const golden = isGoldenMembership(membership, expiresAtMillis, nowMillis);
  return {
    lives: golden ? -1 : lives,
    infiniteLives: golden,
    membership: normalizeMembership(membership),
    lifeMode: golden ? 'golden' : 'normal',
    nextLifeAtMillis: golden ? null : nextLifeAtMillis,
  };
}

module.exports = {
  NORMAL_LIFE_CAP, LIFE_REGEN_INTERVAL_MS, GAME_SESSION_TTL_MS,
  MAX_CHAPTER_INDEX, CHAPTER_STAGE_COUNTS, TOOL_TYPES,
  requireInteger, requireUid, normalizeMembership, isGoldenMembership,
  regenerateLives, validateChapterIndex, normalizeToolType,
  normalizeChapterKey, validateCreatureValue, createLifeResponse,
};
