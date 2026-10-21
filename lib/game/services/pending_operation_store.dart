import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists retry keys and request payloads so an app restart cannot turn an
/// ambiguous server response into a second, unrelated charge.
class PendingOperationStore {
  PendingOperationStore._();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static final Map<String, Future<void>> _operationTails = {};

  static String _storageKey(String namespace, String operationKey, String uid) =>
      'pending_operation_v1:$uid:$namespace:$operationKey';

  static String _payloadStorageKey(
    String namespace,
    String operationKey,
    String uid,
  ) =>
      '${_storageKey(namespace, operationKey, uid)}:payload';

  static String _newOperationId() => List<int>.generate(
        24,
        (_) => math.Random.secure().nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// Serializes identical operation slots so concurrent taps cannot share one
  /// idempotency key. Failed ambiguous calls retain their key for a later retry.
  static Future<T> runExclusive<T>(
    String namespace,
    String operationKey,
    Future<T> Function() action,
  ) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('An authenticated user is required for this operation.');
    }
    final lockKey = '$uid:$namespace:$operationKey';
    final previous = _operationTails[lockKey] ?? Future<void>.value();
    final release = Completer<void>();
    _operationTails[lockKey] = release.future;
    try {
      await previous;
      if (_uid != uid) {
        throw StateError('Account changed while waiting for the pending operation lock.');
      }
      return await action();
    } finally {
      if (identical(_operationTails[lockKey], release.future)) {
        _operationTails.remove(lockKey);
      }
      release.complete();
    }
  }

  static Future<String> getOrCreate(
    String namespace,
    String operationKey,
  ) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('An authenticated user is required for this operation.');
    }
    return _getOrCreateForUid(namespace, operationKey, uid);
  }

  static Future<String> _getOrCreateForUid(
    String namespace,
    String operationKey,
    String uid,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    if (_uid != uid) {
      throw StateError('Account changed while loading the operation ID.');
    }
    final key = _storageKey(namespace, operationKey, uid);
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;

    final operationId = _newOperationId();
    await preferences.setString(key, operationId);
    if (_uid != uid) {
      throw StateError('Account changed while saving the operation ID.');
    }
    return operationId;
  }

  /// Durably records the exact request before the caller contacts the server.
  /// The operation ID is stored first and included in the payload for recovery.
  static Future<String> savePendingPayload(
    String namespace,
    String operationKey,
    Map<String, dynamic> payload,
  ) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('An authenticated user is required for this operation.');
    }
    final operationId = await _getOrCreateForUid(namespace, operationKey, uid);
    if (_uid != uid) {
      throw StateError('Account changed while preparing the pending payload.');
    }
    final preferences = await SharedPreferences.getInstance();
    if (_uid != uid) {
      throw StateError('Account changed before the pending payload could be stored.');
    }
    final record = <String, dynamic>{
      ...payload,
      'namespace': namespace,
      'operationKey': operationKey,
      'operationId': operationId,
    };
    final encoded = jsonEncode(record);
    final stored = await preferences.setString(
      _payloadStorageKey(namespace, operationKey, uid),
      encoded,
    );
    if (!stored) {
      throw StateError('Could not persist the pending operation payload.');
    }
    if (_uid != uid) {
      throw StateError('Account changed after the pending payload was stored.');
    }
    return operationId;
  }

  /// Restores the operation ID embedded in a durable payload if the separate
  /// key was lost. A conflicting existing key is treated as corruption.
  static Future<bool> restoreOperationId(
    String namespace,
    String operationKey,
    String operationId,
  ) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || operationId.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    if (_uid != uid) return false;
    final key = _storageKey(namespace, operationKey, uid);
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) {
      return existing == operationId;
    }
    return preferences.setString(key, operationId);
  }

  /// Finds a pending payload for the signed-in account, optionally restricted
  /// to a chapter. The payload remains until the replacement board is saved.
  static Future<Map<String, dynamic>?> findPendingPayload(
    String namespace, {
    int? chapterIndex,
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    final preferences = await SharedPreferences.getInstance();
    if (_uid != uid) return null;
    final prefix = 'pending_operation_v1:$uid:$namespace:';
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(prefix) || !key.endsWith(':payload')) continue;
      final raw = preferences.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw StateError('Pending operation payload is not a JSON object: $key');
        }
        final payload = Map<String, dynamic>.from(decoded);
        if (chapterIndex != null && payload['chapterIndex'] != chapterIndex) {
          continue;
        }
        return payload;
      } catch (error) {
        // A corrupted pending record is not equivalent to "no pending work".
        // Fail closed so callers cannot create a new session and charge again.
        throw StateError(
          'Pending operation payload is corrupted: $key ($error)',
        );
      }
    }
    return null;
  }

  static Future<void> complete(
    String namespace,
    String operationKey, {
    String? expectedUid,
  }) async {
    final uid = expectedUid ?? _uid;
    if (uid == null || uid.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    // Remove the idempotency key first. If the process is killed between
    // writes, the payload survives and startup can restore the exact operation
    // ID before retrying. Removing the payload first could leave an orphan key
    // that a later operation accidentally reuses after the board was saved.
    await preferences.remove(_storageKey(namespace, operationKey, uid));
    await preferences.remove(_payloadStorageKey(namespace, operationKey, uid));
  }
}
