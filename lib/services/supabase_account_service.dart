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

/// A validated view of server-owned entitlements. This object can only be
/// constructed from a structurally valid account-snapshot response.
class SupabaseAccountSnapshot {
  const SupabaseAccountSnapshot({
    required this.userId,
    required this.displayName,
    required this.avatarIndex,
    required this.localeCode,
    required this.membershipTier,
    required this.membershipStatus,
    required this.gold,
    required this.lifeCount,
    required this.unlimitedLives,
    required this.nextRegenAt,
    required this.tools,
    required this.serverTime,
  });

  final String userId;
  final String displayName;
  final int avatarIndex;
  final String localeCode;
  final String membershipTier;
  final String membershipStatus;
  final int gold;
  final int lifeCount;
  final bool unlimitedLives;
  final DateTime? nextRegenAt;
  final Map<String, int> tools;
  final DateTime serverTime;

  static int _nonNegativeInt(dynamic value, String field) {
    final parsed = value is int
        ? value
        : value is num && value.isFinite && value == value.roundToDouble()
        ? value.toInt()
        : value is String
        ? int.tryParse(value)
        : null;
    if (parsed == null || parsed < 0) {
      throw SupabaseAccountException(
        'INVALID_RESPONSE',
        'The account service returned an invalid $field value.',
      );
    }
    return parsed;
  }

  static SupabaseAccountSnapshot parse(Map<String, dynamic> data) {
    final userId = data['userId'];
    final displayName = data['displayName'];
    final avatarIndex = _nonNegativeInt(data['avatarIndex'], 'avatarIndex');
    final localeCode = data['localeCode'];
    final accountStatus = data['accountStatus'];
    final membership = data['membership'];
    final lives = data['lives'];
    final rawTools = data['tools'];
    final serverTime = DateTime.tryParse(data['serverTime']?.toString() ?? '');

    if (userId is! String || userId.isEmpty ||
        displayName is! String ||
        localeCode is! String ||
        !const {'en', 'zh'}.contains(localeCode) ||
        accountStatus != 'active' ||
        membership is! Map ||
        lives is! Map ||
        rawTools is! Map ||
        serverTime == null ||
        avatarIndex > 53) {
      throw const SupabaseAccountException(
        'INVALID_RESPONSE',
        'The account service returned an incomplete account snapshot.',
      );
    }

    final tier = membership['tier'];
    final status = membership['status'];
    if (tier is! String ||
        !const {'FREE', 'PREMIUM', 'GOLDEN'}.contains(tier) ||
        status is! String ||
        !const {'active', 'revoked'}.contains(status) ||
        (status == 'revoked' && tier != 'FREE')) {
      // The Edge Function must downgrade revoked entitlements to FREE and
      // return 423 for memberships under review. Never accept a success
      // payload that grants stale or disputed paid entitlements.
      throw const SupabaseAccountException(
        'INVALID_RESPONSE',
        'The account service returned invalid membership information.',
      );
    }

    final unlimited = lives['unlimited'];
    if (unlimited is! bool) {
      throw const SupabaseAccountException(
        'INVALID_RESPONSE',
        'The account service returned invalid life entitlements.',
      );
    }
    final lifeCount = _nonNegativeInt(lives['count'], 'lives.count');
    final expectedUnlimited = tier == 'PREMIUM' || tier == 'GOLDEN';
    if (unlimited != expectedUnlimited) {
      throw const SupabaseAccountException(
        'INVALID_RESPONSE',
        'Membership and life entitlements do not agree.',
      );
    }
    final gold = _nonNegativeInt(data['gold'], 'gold');
    final rawNextRegen = lives['nextRegenAt'];
    final nextRegenAt = rawNextRegen == null
        ? null
        : DateTime.tryParse(rawNextRegen.toString());
    if (rawNextRegen != null && nextRegenAt == null) {
      throw const SupabaseAccountException(
        'INVALID_RESPONSE',
        'The account service returned an invalid life regeneration time.',
      );
    }

    final tools = <String, int>{};
    for (final code in const ['UNDO', 'REMOVE', 'SWAP', 'DUPLICATE']) {
      tools[code] = _nonNegativeInt(rawTools[code], 'tools.$code');
    }

    return SupabaseAccountSnapshot(
      userId: userId,
      displayName: displayName,
      avatarIndex: avatarIndex,
      localeCode: localeCode,
      membershipTier: tier,
      membershipStatus: status,
      gold: gold,
      lifeCount: lifeCount,
      unlimitedLives: unlimited,
      nextRegenAt: nextRegenAt,
      tools: Map.unmodifiable(tools),
      serverTime: serverTime,
    );
  }
}

/// Reads the authoritative account snapshot from the trusted Edge Function.
/// The response is validated before any caller can use it as entitlements.
class SupabaseAccountService {
  SupabaseAccountService._();

  static Future<SupabaseAccountSnapshot> fetchSnapshot() async {
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
      final snapshot = SupabaseAccountSnapshot.parse(
        Map<String, dynamic>.from(data),
      );
      final authenticatedUserId = client.auth.currentUser?.id;
      if (authenticatedUserId == null || snapshot.userId != authenticatedUserId) {
        throw const SupabaseAccountException(
          'ACCOUNT_ID_MISMATCH',
          'The returned account does not match the signed-in user.',
        );
      }
      return snapshot;
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
