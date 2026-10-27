import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_backend.dart';

class SupabaseAccountException implements Exception {
  const SupabaseAccountException(this.code, this.message, {this.status});

  final String code;
  final String message;
  final int? status;

  @override
  String toString() => '$code: $message';
}

/// Reads the authoritative account snapshot from the trusted Edge Function.
/// This is intentionally read-only; clients cannot grant themselves assets.
class SupabaseAccountService {
  SupabaseAccountService._();

  static Future<Map<String, dynamic>> fetchSnapshot() async {
    final client = SupabaseBackend.client;
    if (client.auth.currentSession == null) {
      throw const SupabaseAccountException(
        'UNAUTHORIZED',
        'Sign in before synchronizing account data.',
        status: 401,
      );
    }

    try {
      final response = await client.functions.invoke(
        'account-snapshot',
        method: HttpMethod.post,
        body: <String, dynamic>{},
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final code = payload['error'] is String
            ? payload['error'] as String
            : 'ACCOUNT_SNAPSHOT_FAILED';
        throw SupabaseAccountException(
          code,
          code == 'ACCOUNT_RESTRICTED' ||
                  code == 'MEMBERSHIP_REQUIRES_REVIEW'
              ? 'Account access is restricted. Support remains available.'
              : 'Could not synchronize account data. Please retry when online.',
          status: response.status,
        );
      }

      if (data is! Map) {
        throw const SupabaseAccountException(
          'INVALID_RESPONSE',
          'The account service returned an invalid response.',
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
          : 'ACCOUNT_SNAPSHOT_FAILED';
      throw SupabaseAccountException(
        code,
        'Could not synchronize account data. Please retry when online.',
        status: error.status,
      );
    } on SupabaseAccountException {
      rethrow;
    } catch (_) {
      throw const SupabaseAccountException(
        'NETWORK_OR_SERVER_ERROR',
        'Could not synchronize account data. Please retry when online.',
      );
    }
  }
}
