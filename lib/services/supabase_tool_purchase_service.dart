import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_backend.dart';

class SupabaseToolPurchaseException implements Exception {
  const SupabaseToolPurchaseException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class SupabaseToolPurchaseService {
  SupabaseToolPurchaseService._();

  static final Random _random = Random.secure();
  static final Map<String, String> _pendingRequestIds = {};
  static final Map<String, Future<String>> _pendingRequestIdLoads = {};

  static Future<String> _requestIdFor(String requestKey) {
    return _pendingRequestIdLoads.putIfAbsent(requestKey, () async {
      final preferences = await SharedPreferences.getInstance();
      final storageKey = 'supabase_pending_tool_purchase:$requestKey';
      final existing = preferences.getString(storageKey);
      if (existing != null &&
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}
  static String _newRequestId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<Map<String, dynamic>> purchase({
    required String toolCode,
    required int quantity,
  }) async {
    final client = SupabaseBackend.client;
    if (client.auth.currentSession == null) {
      throw const SupabaseToolPurchaseException(
        'UNAUTHORIZED',
        'Sign in before purchasing tools.',
      );
    }

    final requestKey = '$toolCode:$quantity';
    try {
      // Persist the idempotency key before sending money-related requests. If
      // the app closes after the server commits but before the response arrives,
      // the next attempt reuses this key and receives the original transaction.
      final requestId = await _requestIdFor(requestKey);
      final response = await client.functions.invoke(
        'purchase-tool-package',
        method: HttpMethod.post,
        body: <String, dynamic>{
          'toolCode': toolCode,
          'quantity': quantity,
          'idempotencyKey': requestId,
        },
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final code = payload['error'] is String
            ? payload['error'] as String
            : 'TOOL_PURCHASE_FAILED';
        throw SupabaseToolPurchaseException(code, _friendlyMessage(code));
      }
      if (data is! Map) {
        throw const SupabaseToolPurchaseException(
          'INVALID_RESPONSE',
          'The tool purchase service returned an invalid response.',
        );
      }
      final result = Map<String, dynamic>.from(data);
      if (result['toolCode'] != toolCode ||
          result['quantity'] != quantity ||
          result['balance'] is! num ||
          result['uses'] is! num ||
          (result['balance'] as num).toInt() < 0 ||
          (result['uses'] as num).toInt() < quantity) {
        throw const SupabaseToolPurchaseException(
          'INVALID_RESPONSE',
          'The tool purchase service returned inconsistent account values.',
        );
      }
      _pendingRequestIds.remove(requestKey);
      _pendingRequestIdLoads.remove(requestKey);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('supabase_pending_tool_purchase:$requestKey');
      return result;
    } on FunctionException catch (error) {
      final details = error.details;
      final payload = details is Map
          ? Map<String, dynamic>.from(details)
          : <String, dynamic>{};
      final code = payload['error'] is String
          ? payload['error'] as String
          : 'TOOL_PURCHASE_FAILED';
      throw SupabaseToolPurchaseException(code, _friendlyMessage(code));
    } on SupabaseToolPurchaseException {
      rethrow;
    } catch (_) {
      throw const SupabaseToolPurchaseException(
        'NETWORK_OR_SERVER_ERROR',
        'Could not verify the purchase. No local wallet change was applied.',
      );
    }
  }

  static String _friendlyMessage(String code) {
    switch (code) {
      case 'UNAUTHORIZED':
        return 'Please sign in again.';
      case 'PURCHASE_SAFETY_STORAGE_UNAVAILABLE':
        return 'Purchase protection could not be saved. Please retry.';
      case 'INSUFFICIENT_GOLD':
        return 'Not enough Gold for this purchase.';
      case 'FREE_SINGLE_TOOL_ONLY':
        return 'FREE members can only purchase one tool at a time.';
      case 'GOLDEN_UNDO_UNLIMITED':
        return 'GOLDEN members have unlimited UNDO.';
      case 'ACCOUNT_RESTRICTED':
      case 'MEMBERSHIP_REQUIRES_REVIEW':
        return 'Account access is restricted. Support remains available.';
      case 'IDEMPOTENCY_CONFLICT':
        return 'This purchase request conflicts with an earlier request.';
      default:
        return 'Tool purchase could not be completed. Please retry online.';
    }
  }
}
, caseSensitive: false).hasMatch(existing)) {
        _pendingRequestIds[requestKey] = existing;
        return existing;
      }

      final generated = _newRequestId();
      final saved = await preferences.setString(storageKey, generated);
      if (!saved) {
        throw const SupabaseToolPurchaseException(
          'PURCHASE_SAFETY_STORAGE_UNAVAILABLE',
          'Purchase protection could not be saved. Please retry.',
        );
      }
      _pendingRequestIds[requestKey] = generated;
      return generated;
    });
  }

  static String _newRequestId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<Map<String, dynamic>> purchase({
    required String toolCode,
    required int quantity,
  }) async {
    final client = SupabaseBackend.client;
    if (client.auth.currentSession == null) {
      throw const SupabaseToolPurchaseException(
        'UNAUTHORIZED',
        'Sign in before purchasing tools.',
      );
    }

    final requestKey = '$toolCode:$quantity';
    final requestId = _pendingRequestIds.putIfAbsent(requestKey, _newRequestId);
    try {
      final response = await client.functions.invoke(
        'purchase-tool-package',
        method: HttpMethod.post,
        body: <String, dynamic>{
          'toolCode': toolCode,
          'quantity': quantity,
          'idempotencyKey': requestId,
        },
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final code = payload['error'] is String
            ? payload['error'] as String
            : 'TOOL_PURCHASE_FAILED';
        throw SupabaseToolPurchaseException(code, _friendlyMessage(code));
      }
      if (data is! Map) {
        throw const SupabaseToolPurchaseException(
          'INVALID_RESPONSE',
          'The tool purchase service returned an invalid response.',
        );
      }
      final result = Map<String, dynamic>.from(data);
      if (result['toolCode'] != toolCode ||
          result['quantity'] != quantity ||
          result['balance'] is! num ||
          result['uses'] is! num ||
          (result['balance'] as num).toInt() < 0 ||
          (result['uses'] as num).toInt() < quantity) {
        throw const SupabaseToolPurchaseException(
          'INVALID_RESPONSE',
          'The tool purchase service returned inconsistent account values.',
        );
      }
      _pendingRequestIds.remove(requestKey);
      return result;
    } on FunctionException catch (error) {
      final details = error.details;
      final payload = details is Map
          ? Map<String, dynamic>.from(details)
          : <String, dynamic>{};
      final code = payload['error'] is String
          ? payload['error'] as String
          : 'TOOL_PURCHASE_FAILED';
      throw SupabaseToolPurchaseException(code, _friendlyMessage(code));
    } on SupabaseToolPurchaseException {
      rethrow;
    } catch (_) {
      throw const SupabaseToolPurchaseException(
        'NETWORK_OR_SERVER_ERROR',
        'Could not verify the purchase. No local wallet change was applied.',
      );
    }
  }

  static String _friendlyMessage(String code) {
    switch (code) {
      case 'UNAUTHORIZED':
        return 'Please sign in again.';
      case 'INSUFFICIENT_GOLD':
        return 'Not enough Gold for this purchase.';
      case 'FREE_SINGLE_TOOL_ONLY':
        return 'FREE members can only purchase one tool at a time.';
      case 'GOLDEN_UNDO_UNLIMITED':
        return 'GOLDEN members have unlimited UNDO.';
      case 'ACCOUNT_RESTRICTED':
      case 'MEMBERSHIP_REQUIRES_REVIEW':
        return 'Account access is restricted. Support remains available.';
      case 'IDEMPOTENCY_CONFLICT':
        return 'This purchase request conflicts with an earlier request.';
      default:
        return 'Tool purchase could not be completed. Please retry online.';
    }
  }
}
