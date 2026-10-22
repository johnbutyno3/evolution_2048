const NORMAL_CAP = 5;
const GENERAL_INTERVAL_MS = 40 * 60 * 1000;
const PREMIUM_INTERVAL_MS = 40 * 60 * 1000;
const MEMBERSHIP_TYPES = new Set(['premium', 'golden']);

function toMillis(value) {
  if (value == null) return null;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

function isActiveUntil(value, nowMillis) {
  const expiresAtMillis = toMillis(value);
  return expiresAtMillis === null || expiresAtMillis > nowMillis;
}

function resolveMembership(data, nowMillis = Date.now()) {
  const legacyType = MEMBERSHIP_TYPES.has(data?.type) ? data.type : null;
  const legacyExpiresAt = data?.expiresAt ?? null;

  // Keep independently purchased lifetime Premium separate from a Golden
  // subscription so expiration/revocation of Golden cannot erase Premium.
  const hasExplicitPremiumState =
    typeof data?.premiumLifetime === 'boolean' ||
    Object.prototype.hasOwnProperty.call(data || {}, 'premiumExpiresAt');
  const premiumLifetime = data?.premiumLifetime === true ||
    (!hasExplicitPremiumState &&
      legacyType === 'premium' &&
      legacyExpiresAt == null);
  const premiumExpiresAt = data?.premiumExpiresAt ??
    (!hasExplicitPremiumState && legacyType === 'premium'
      ? legacyExpiresAt
      : null);
  const premiumActive = premiumLifetime ||
    (premiumExpiresAt != null && isActiveUntil(premiumExpiresAt, nowMillis));

  const goldenCandidate = legacyType === 'golden' ||
    data?.goldenActive === true;
  const goldenExpiresAt = data?.goldenExpiresAt ??
    (legacyType === 'golden' ? legacyExpiresAt : null);
  const goldenActive = goldenCandidate &&
    (data?.goldenActive === true && goldenExpiresAt == null
      ? true
      : goldenExpiresAt != null && isActiveUntil(goldenExpiresAt, nowMillis));

  const type = goldenActive ? 'golden' : premiumActive ? 'premium' : null;
  const expiresAt = goldenActive
    ? goldenExpiresAt
    : premiumActive && !premiumLifetime
      ? premiumExpiresAt
      : null;
  const active = type !== null;

  return {
    active,
    type,
    expiresAt,
    premiumLifetime: premiumLifetime,
    goldenActive,
    infiniteLives: goldenActive,
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
