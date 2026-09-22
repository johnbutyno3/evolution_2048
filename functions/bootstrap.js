const functions = require('./index');
const gameSession = require('./game_session');
const life = require('./life');
const toolInventoryDefaults = require('./tool_inventory_defaults');

Object.assign(functions, gameSession, life, toolInventoryDefaults);
const adminTest = require('./admin_test');
const bootstrapTestAccount = require('./bootstrap_test_account');
Object.assign(functions, adminTest, bootstrapTestAccount);

module.exports = functions;
