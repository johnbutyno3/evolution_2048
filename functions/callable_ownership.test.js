const assert = require('assert');
const fs = require('fs');
const path = require('path');

const functionsDir = __dirname;
const callableOwners = new Map();
const sourceFiles = fs.readdirSync(functionsDir)
  .filter((name) => name.endsWith('.js') && !name.endsWith('.test.js'));

for (const fileName of sourceFiles) {
  const filePath = path.join(functionsDir, fileName);
  const source = fs.readFileSync(filePath, 'utf8');
  const pattern = /exports\.([A-Za-z0-9_]+)\s*=\s*onCall\s*\(/g;

  let match;
  while ((match = pattern.exec(source)) !== null) {
    const callableName = match[1];
    const previousOwner = callableOwners.get(callableName);
    assert.strictEqual(
      previousOwner,
      undefined,
      `Duplicate callable owner: ${callableName} in ${previousOwner} and ${fileName}`,
    );
    callableOwners.set(callableName, fileName);
  }
}

const requiredOwners = {
  startGameSession: 'index.js',
  resumeGameSession: 'index.js',
  completeChapter: 'index.js',
  restartGameSession: 'game_session.js',
  abandonGameSession: 'game_session.js',
  getLifeState: 'life.js',
  consumeLife: 'life.js',
  refundLife: 'life.js',
  getToolInventory: 'tool_inventory_defaults.js',
  purchaseTool: 'tool_inventory_defaults.js',
  adminSetAllToolsEnabled: 'admin_test.js',
  adminGetTestAccountState: 'admin_test.js',
};

for (const [callableName, expectedOwner] of Object.entries(requiredOwners)) {
  assert.strictEqual(
    callableOwners.get(callableName),
    expectedOwner,
    `Callable ${callableName} must be owned by ${expectedOwner}`,
  );
}

console.log(`Callable ownership audit passed: ${callableOwners.size} callables.`);
