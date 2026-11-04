import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_backend.dart';

class SupabaseGameSessionException implements Exception {
  const SupabaseGameSessionException(this.code, this.message, {this.status});

  final String code;
  final String message;
  final int? status;

  @override
  String toString() => '$code: $message';
}

/// Supabase transport for authoritative game-session operations.
class SupabaseGameSessionService {
  SupabaseGameSessionService._();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static void _requireUuid(String value, String field) {
    if (!_uuidPattern.hasMatch(value)) {
      throw ArgumentError.value(value, field, 'Expected a UUID.');
    }
  }

  static void _requireChapter(String value) {
    if (!const {'C1', 'C2', 'C3', 'C4', 'C5', 'C6'}.contains(value)) {
      throw ArgumentError.value(value, 'chapterCode');
    }
  }

  static void _requireInitialTiles(List<int?> tiles) {
    if (tiles.length != 16 ||
        tiles.where((value) => value != null).length != 2 ||
        tiles.any((value) => value != null && value != 2 && value != 4)) {
      throw ArgumentError.value(
        tiles,
        'initialTiles',
        'Expected sixteen cells containing exactly two 2/4 tiles.',
      );
    }
  }

  static void _requireReplayLog(Map<String, dynamic> replayLog) {
    if (replayLog.isEmpty || replayLog.length > 32) {
      throw ArgumentError.value(replayLog, 'replayLog');
    }
    final encoded = jsonEncode(replayLog);
    if (utf8.encode(encoded).length > 1024 * 1024) {
      throw ArgumentError.value(
        replayLog,
        'replayLog',
        'Replay log exceeds 1 MB.',
      );
    }
  }

  static Future<Map<String, dynamic>> startGameSession({
    required String requestId,
    required String gameId,
    required String chapterCode,
    required List<int?> initialTiles,
    String? previousGameId,
  }) async {
    _requireUuid(requestId, 'requestId');
    _requireUuid(gameId, 'gameId');
    if (previousGameId != null) {
      _requireUuid(previousGameId, 'previousGameId');
    }
    _requireChapter(chapterCode);
    _requireInitialTiles(initialTiles);
    return _invoke(
      'start-game-session',
      <String, dynamic>{
        'requestId': requestId,
        'gameId': gameId,
        'chapterCode': chapterCode,
        'previousGameId': previousGameId,
        'initialTiles': initialTiles,
      },
    );
  }

  static Future<Map<String, dynamic>> restartGameSession({
    required String requestId,
    required String gameId,
    required String previousGameId,
    required String eventId,
    required String chapterCode,
    required List<int?> initialTiles,
    required Map<String, dynamic> replayLog,
  }) async {
    _requireUuid(requestId, 'requestId');
    _requireUuid(gameId, 'gameId');
    _requireUuid(previousGameId, 'previousGameId');
    _requireUuid(eventId, 'eventId');
    _requireChapter(chapterCode);
    _requireInitialTiles(initialTiles);
    _requireReplayLog(replayLog);
    return _invoke(
      'restart-game-session',
      <String, dynamic>{
        'requestId': requestId,
        'gameId': gameId,
        'previousGameId': previousGameId,
        'eventId': eventId,
        'chapterCode': chapterCode,
        'initialTiles': initialTiles,
        'replayLog': replayLog,
      },
    );
  }

  static Future<Map<String, dynamic>> resumeGameSession({
    required String gameId,
  }) async {
    _requireUuid(gameId, 'gameId');
    return _invoke(
      'resume-game-session',
      <String, dynamic>{'gameId': gameId},
    );
  }

  static Future<Map<String, dynamic>> finishChapter({
    required String gameId,
    required String eventId,
    required Map<String, dynamic> replayLog,
  }) async {
    _requireUuid(gameId, 'gameId');
    _requireUuid(eventId, 'eventId');
    _requireReplayLog(replayLog);
    return _invoke(
      'finish-game-chapter',
      <String, dynamic>{
        'gameId': gameId,
        'eventId': eventId,
        'replayLog': replayLog,
      },
    );
  }

  static Future<Map<String, dynamic>> abandonGameSession({
    required String gameId,
    required String eventId,
    required String reason,
    required Map<String, dynamic> replayLog,
  }) async {
    if (reason != 'GAME_OVER' && reason != 'PLAYER_ABANDONED') {
      throw ArgumentError.value(reason, 'reason');
    }
    _requireUuid(gameId, 'gameId');
    _requireUuid(eventId, 'eventId');
    _requireReplayLog(replayLog);
    return _invoke(
      'abandon-game-session',
      <String, dynamic>{
        'gameId': gameId,
        'eventId': eventId,
        'reason': reason,
        'replayLog': replayLog,
      },
    );
  }

  static Future<Map<String, dynamic>> saveCheckpoint({
    required String gameId,
    required int eventSequence,
    required Map<String, dynamic> checkpoint,
  }) async {
    _requireUuid(gameId, 'gameId');
    if (eventSequence < 1) {
      throw ArgumentError.value(eventSequence, 'eventSequence');
    }
    if (utf8.encode(jsonEncode(checkpoint)).length > 262144) {
      throw ArgumentError.value(
        checkpoint,
        'checkpoint',
        'Checkpoint exceeds 256 KB.',
      );
    }
    return _invoke(
      'save-game-checkpoint',
      <String, dynamic>{
        'gameId': gameId,
        'eventSequence': eventSequence,
        'checkpoint': checkpoint,
      },
    );
  }

  static Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final client = SupabaseBackend.client;
    if (client.auth.currentSession == null) {
      throw const SupabaseGameSessionException(
        'UNAUTHORIZED',
        'Sign in before synchronizing game state.',
        status: 401,
      );
    }

    try {
      final response = await client.functions.invoke(
        functionName,
        method: HttpMethod.post,
        body: body,
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final code = payload['error'] is String
            ? payload['error'] as String
            : 'GAME_SESSION_REQUEST_FAILED';
        throw SupabaseGameSessionException(
          code,
          _friendlyMessage(code),
          status: response.status,
        );
      }
      if (data is! Map) {
        throw const SupabaseGameSessionException(
          'INVALID_RESPONSE',
          'The game session service returned an invalid response.',
        );
      }
      return Map<String, dynamic>.from(data);
    } on FunctionException catch (error) {
      final details = error.details;
      final payload = details is Map
          ? Map<String, dynamic>.from(details)
          : <String, dynamic>{};
      final code = payload['error'] is String
          ? payload['error'] as String
          : 'GAME_SESSION_REQUEST_FAILED';
      throw SupabaseGameSessionException(
        code,
        _friendlyMessage(code),
        status: error.status,
      );
    } on SupabaseGameSessionException {
      rethrow;
    } catch (_) {
      throw const SupabaseGameSessionException(
        'NETWORK_OR_SERVER_ERROR',
        'Could not synchronize game state. Local progress remains available.',
      );
    }
  }

  static String _friendlyMessage(String code) {
    switch (code) {
      case 'REPLAY_VALIDATION_FAILED':
        return 'Game replay could not be validated. Please retry.';
      case 'ACCOUNT_RESTRICTED':
      case 'MEMBERSHIP_REQUIRES_REVIEW':
        return 'Account access is restricted. Support remains available.';
      case 'OUT_OF_LIVES':
        return 'No lives remain. Wait for regeneration before starting a new game.';
      case 'ACTIVE_SESSION_EXISTS':
        return 'An active game session already exists. Resume it before starting another.';
      case 'PREVIOUS_SESSION_MUST_BE_SETTLED':
        return 'Finish or safely abandon the previous game before starting another.';
      case 'CHECKPOINT_SEQUENCE_CONFLICT':
        return 'A different checkpoint already exists for this operation sequence.';
      default:
        return 'Could not synchronize game state. Please retry when online.';
    }
  }
}
