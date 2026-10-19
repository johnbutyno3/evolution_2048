import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists retry keys so a process restart cannot turn an ambiguous server
/// response into a second, unrelated charge.
class PendingOperationStore {
  PendingOperationStore._();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String _storageKey(String namespace, String operationKey, String uid) =>
      'pending_operation_v1:$uid:$namespace:$operationKey';

  static String _newOperationId() => List<int>.generate(
        24,
        (_) => math.Random.secure().nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static Future<String> getOrCreate(
    String namespace,
    String operationKey,
  ) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('An authenticated user is required for this operation.');
    }
    final preferences = await SharedPreferences.getInstance();
    final key = _storageKey(namespace, operationKey, uid);
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;

    final operationId = _newOperationId();
    await preferences.setString(key, operationId);
    return operationId;
  }

  static Future<void> complete(String namespace, String operationKey) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey(namespace, operationKey, uid));
  }
}
