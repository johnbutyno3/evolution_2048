'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migration = fs.readFileSync(
  path.join(__dirname, '../../supabase/migrations/20261105120000_legacy_account_import.sql'),
  'utf8',
);

assert.ok(migration.split('\n').length < 500, 'Legacy import migration must not contain duplicated SQL fragments.');
assert.equal(
  (migration.match(/create or replace function public\.import_legacy_firebase_account/g) || []).length,
  1,
  'The migration must define the import RPC exactly once.',
);
assert.equal((migration.match(/for v_code, v_quantity in/g) || []).length, 1);
assert.equal((migration.match(/for v_chapter in/g) || []).length, 1);
assert.equal((migration.match(/for v_value in/g) || []).length, 1);
assert.match(migration, /LEGACY_MEMBERSHIP_REQUIRES_MANUAL_APPROVAL/);
assert.match(migration, /SUPABASE_ACCOUNT_NOT_PRISTINE_FOR_IMPORT/);
assert.match(migration, /grant execute on function public\.import_legacy_firebase_account[\s\S]*?to service_role;/);
assert.doesNotMatch(
  migration,
  /case when \(v_chapter ->> 'completed'\)::boolean then now\(\)/,
  'The migration must not invent a legacy chapter completion timestamp.',
);

console.log('Legacy import SQL contract passed: single RPC, guarded imports, and no duplicate fragments.');
