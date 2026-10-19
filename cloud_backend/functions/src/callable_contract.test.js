'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '../../..');
const frontendFiles = [
  'lib/services/player_progress_service.dart',
  'lib/game/services/life_manager.dart',
  'lib/game/services/gold_manager.dart',
  'lib/game/services/tool_manager.dart',
];
const frontendCallables = new Set();

for (const relativePath of frontendFiles) {
  const filePath = path.join(repoRoot, relativePath);
  const source = fs.readFileSync(filePath, 'utf8');
  const pattern = /httpsCallable\s*\(\s*['"]([^'"]+)['"]\s*\)/g;
  for (const match of source.matchAll(pattern)) {
    frontendCallables.add(match[1]);
  }
}

const sourceDir = __dirname;
const backendCallables = new Set();
for (const name of fs.readdirSync(sourceDir)) {
  if (!name.endsWith('.js') || name.endsWith('.test.js')) continue;
  const source = fs.readFileSync(path.join(sourceDir, name), 'utf8');
  const pattern = /exports\.([A-Za-z0-9_]+)\s*=\s*onCall\s*\(/g;
  for (const match of source.matchAll(pattern)) {
    backendCallables.add(match[1]);
  }
}

const missing = [...frontendCallables].filter((name) => !backendCallables.has(name));
assert.deepEqual(
  missing,
  [],
  `Frontend calls missing backend callable exports: ${missing.join(', ')}`,
);
console.log(`Callable contract OK: ${frontendCallables.size} frontend callables have backend exports.`);
