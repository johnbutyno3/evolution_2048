const functions = require('./index');
const gameSession = require('./game_session');
const life = require('./life');
const toolInventoryDefaults = require('./tool_inventory_defaults');

Object.assign(functions, gameSession, life, toolInventoryDefaults);

module.exports = functions;
