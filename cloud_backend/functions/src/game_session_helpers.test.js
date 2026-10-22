'use strict';

const assert = require('node:assert/strict');
const {
  resolveMembership,
  lifeResponse,
} = require('./game_session_helpers');

const now = Date.UTC(2026, 0, 1);
const future = new Date(now + 60_000);
const past = new Date(now - 60_000);

const lifetimePremiumUnderExpiredGolden = resolveMembership({
  type: 'golden',
  expiresAt: past,
  goldenActive: true,
  goldenExpiresAt: past,
  premiumLifetime: true,
}, now);
assert.equal(lifetimePremiumUnderExpiredGolden.active, true);
assert.equal(lifetimePremiumUnderExpiredGolden.type, 'premium');
assert.equal(lifetimePremiumUnderExpiredGolden.infiniteLives, false);
assert.equal(lifetimePremiumUnderExpiredGolden.noAds, true);
assert.equal(lifetimePremiumUnderExpiredGolden.expiresAt, null);

const activeGoldenWithLifetimePremium = resolveMembership({
  type: 'golden',
  expiresAt: future,
  goldenActive: true,
  goldenExpiresAt: future,
  premiumLifetime: true,
}, now);
assert.equal(activeGoldenWithLifetimePremium.type, 'golden');
assert.equal(activeGoldenWithLifetimePremium.infiniteLives, true);
assert.equal(lifeResponse(5, null, activeGoldenWithLifetimePremium).lives, -1);

const expiredGoldenWithoutPremium = resolveMembership({
  type: 'golden',
  expiresAt: past,
  goldenActive: true,
  goldenExpiresAt: past,
  premiumLifetime: false,
}, now);
assert.equal(expiredGoldenWithoutPremium.active, false);
assert.equal(expiredGoldenWithoutPremium.type, null);
assert.equal(expiredGoldenWithoutPremium.noAds, false);

const goldenWithoutExpiry = resolveMembership({
  type: 'golden',
  goldenActive: true,
  premiumLifetime: false,
}, now);
assert.equal(goldenWithoutExpiry.active, false);
assert.equal(goldenWithoutExpiry.type, null);
assert.equal(goldenWithoutExpiry.infiniteLives, false);

const expiringPremiumFallback = resolveMembership({
  type: 'golden',
  goldenActive: true,
  goldenExpiresAt: past,
  premiumLifetime: false,
  premiumExpiresAt: future,
}, now);
assert.equal(expiringPremiumFallback.type, 'premium');
assert.equal(expiringPremiumFallback.infiniteLives, false);
assert.equal(expiringPremiumFallback.noAds, true);

const legacyLifetimePremium = resolveMembership({
  type: 'premium',
  expiresAt: null,
}, now);
assert.equal(legacyLifetimePremium.type, 'premium');
assert.equal(legacyLifetimePremium.premiumLifetime, true);


const goldenWithMalformedExpiry = resolveMembership({
  type: 'golden',
  goldenActive: true,
  goldenExpiresAt: 'not-a-valid-expiry',
  premiumLifetime: false,
}, now);
assert.equal(goldenWithMalformedExpiry.active, false);
assert.equal(goldenWithMalformedExpiry.type, null);
assert.equal(goldenWithMalformedExpiry.infiniteLives, false);

const premiumWithMalformedExpiry = resolveMembership({
  type: 'premium',
  premiumLifetime: false,
  premiumExpiresAt: 'not-a-valid-expiry',
}, now);
assert.equal(premiumWithMalformedExpiry.active, false);
assert.equal(premiumWithMalformedExpiry.type, null);

console.log('Membership entitlement tests passed: malformed expiries fail closed and Golden expiry preserves independent Premium.');
