const functions = require('./index');
const gameSession = require('./game_session');

Object.assign(functions, gameSession);

module.exports = functions;
