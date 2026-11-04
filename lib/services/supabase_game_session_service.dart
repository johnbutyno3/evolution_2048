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
/// IDs are supplied by the caller and must be UUIDs; no Firebase session IDs
/// should be passed into this API. The initial board must contain exactly two
/// non-null values (2 or 4) and fourteen null cells.
class SupabaseGameSessionService {
  SupabaseGameSessionService._();

  static Future<Map<String, dynamic>> startGameSession({
    required String requestId,
    required String gameId,
    required String chapterCode,
    required List<int?> initialTiles,
    String? previousGameId,
  }) async {
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
