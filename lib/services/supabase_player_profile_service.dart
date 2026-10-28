import '../game/services/save_manager.dart';
import 'supabase_backend.dart';

class SupabasePlayerProfileException implements Exception {
  const SupabasePlayerProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Profile access through Supabase Auth + the user's own RLS-protected row.
/// This service is intentionally separate until the app's auth cutover.
class SupabasePlayerProfileService {
  SupabasePlayerProfileService._();

  static String _requireUserId() {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw const SupabasePlayerProfileException(
        'Sign in before accessing the player profile.',
      );
    }
    return user.id;
  }

  static int _safeAvatarIndex(dynamic value) {
    if (value is num) return value.toInt().clamp(0, 53);
    return 0;
  }

  static String? _readName(Map<String, dynamic> row) {
    final value = row['display_name'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static Future<String?> ensureProfile() async {
    final client = SupabaseBackend.client;
    final userId = _requireUserId();
    final row = await client
        .from('profiles')
        .select('user_id, display_name, avatar_index, locale_code')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      throw const SupabasePlayerProfileException(
        'Player profile is not initialized on the server.',
      );
    }

    final profile = Map<String, dynamic>.from(row);
    final name = _readName(profile);
    await SaveManager.savePlayerId(userId);
    await SaveManager.saveAvatarIndex(_safeAvatarIndex(profile['avatar_index']));
    final locale = profile['locale_code'];
    if (locale is String) await SaveManager.saveLocaleCode(locale);
    if (name != null) await SaveManager.saveProfile(name: name);
    return name;
  }

  static Future<bool> updatePlayerName(String name) async {
    final trimmed = name.trim().replaceAll(RegExp(r'\\s+'), ' ');
    if (trimmed.isEmpty ||
        trimmed.length > 30 ||
        trimmed.toUpperCase() == 'PLAYER') {
      return false;
    }

    final client = SupabaseBackend.client;
    final userId = _requireUserId();
    final row = await client
        .from('profiles')
        .update(<String, dynamic>{'display_name': trimmed})
        .eq('user_id', userId)
        .select('user_id, display_name, avatar_index')
        .maybeSingle();

    if (row == null) {
      throw const SupabasePlayerProfileException(
        'Profile name could not be saved on the server.',
      );
    }
    final profile = Map<String, dynamic>.from(row);
    final serverName = _readName(profile);
    if (serverName == null) {
      throw const SupabasePlayerProfileException(
        'Profile name was not returned by the server.',
      );
    }
    await SaveManager.saveProfile(name: serverName);
    await SaveManager.savePlayerId(userId);
    await SaveManager.saveAvatarIndex(_safeAvatarIndex(profile['avatar_index']));
    return true;
  }

  static Future<void> updateAvatarIndex(int index) async {
    final client = SupabaseBackend.client;
    final userId = _requireUserId();
    final safeIndex = index.clamp(0, 53);
    final row = await client
        .from('profiles')
        .update(<String, dynamic>{'avatar_index': safeIndex})
        .eq('user_id', userId)
        .select('avatar_index')
        .maybeSingle();

    if (row == null) {
      throw const SupabasePlayerProfileException(
        'Avatar could not be saved on the server.',
      );
    }
    final profile = Map<String, dynamic>.from(row);
    await SaveManager.saveAvatarIndex(_safeAvatarIndex(profile['avatar_index']));
  }
}
