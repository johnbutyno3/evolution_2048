const NORMAL_CAP = 5;
const GENERAL_INTERVAL_MS = 60 * 60 * 1000;
const PREMIUM_INTERVAL_MS = 30 * 60 * 1000;
const MEMBERSHIP_TYPES = new Set(['premium', 'golden']);

function resolveMembership(data) {
  const type = MEMBERSHIP_TYPES.has(data?.type) ? data.type : null;
  const expiresAt = data?.expiresAt ?? null;
  let active = false;

  if (type !== null) {
    if (expiresAt === null) {
      active = true;
    } else if (typeof expiresAt.toMillis === 'function') {
      active = expiresAt.toMillis() > Date.now();
    }
  }

  return {
    active,
    type: active ? type : null,
    expiresAt: active ? expiresAt : null,
    infiniteLives: active && type === 'golden',
    noAds: active,
  };
}

function intervalMs(membership) {
  return membership.type === 'premium'
    ? PREMIUM_INTERVAL_MS
    : GENERAL_INTERVAL_MS;
}

function normalizeLives(value) {
  return Number.isSafeInteger(value) && value >= 0 ? value : NORMAL_CAP;
}

function normalizeRegenStart(value) {
  if (!value || typeof value.toMillis !== 'function') return null;
  return value.toMillis();
}

function regenerate({ lives, regenStartMillis, nowMillis, interval }) {
  if (lives >= NORMAL_CAP) {
    return { lives: NORMAL_CAP, regenStartMillis: null };
  }

  const start = regenStartMillis ?? nowMillis;
  const elapsed = nowMillis - start;
  if (elapsed < interval) {
    return { lives, regenStartMillis: start };
  }

  const recovered = Math.floor(elapsed / interval);
  const nextLives = Math.min(NORMAL_CAP, lives + recovered);
  if (nextLives >= NORMAL_CAP) {
    return { lives: NORMAL_CAP, regenStartMillis: null };
  }

  return {
    lives: nextLives,
    regenStartMillis: start + recovered * interval,
  };
}

function lifeResponse(lives, regenStartMillis, membership) {
  if (membership.infiniteLives) {
    return {
      lives: -1,
      infiniteLives: true,
      membership: membership.type,
      lifeMode: 'golden',
      nextLifeAtMillis: null,
    };
  }

  if (lives >= NORMAL_CAP || regenStartMillis == null) {
    return {
      lives,
      infiniteLives: false,
      membership: membership.type ?? 'general',
      lifeMode: 'normal',
      nextLifeAtMillis: null,
    };
  }

  return {
    lives,
    infiniteLives: false,
    membership: membership.type ?? 'general',
    lifeMode: 'normal',
    nextLifeAtMillis: regenStartMillis + intervalMs(membership),
  };
}

module.exports = {
  NORMAL_CAP,
  MEMBERSHIP_TYPES,
  resolveMembership,
  intervalMs,
  normalizeLives,
  normalizeRegenStart,
  regenerate,
  lifeResponse,
};
