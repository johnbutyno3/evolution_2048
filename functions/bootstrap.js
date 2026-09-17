const functions = require('./index');
const gameSession = require('./game_session');
const life = require('./life');

Object.assign(functions, gameSession, life);

module.exports = functions;
