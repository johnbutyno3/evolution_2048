import 'supabase_player_profile_service.dart';

class PlayerProfileException implements Exception {
  const PlayerProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlayerProfileService {
  PlayerProfileService._();

  static Future<void> updateAvatarIndex(int index) async {
    try {
      await SupabasePlayerProfileService.updateAvatarIndex(index);
    } on SupabasePlayerProfileException catch (error) {
      throw PlayerProfileException(error.message);
    } catch (_) {
      throw const PlayerProfileException('Avatar could not be saved. Please retry online.');
    }
  }

  static Future<String?> ensureProfile() async {
    try {
      return await SupabasePlayerProfileService.ensureProfile();
    } on SupabasePlayerProfileException catch (error) {
      throw PlayerProfileException(error.message);
    } catch (_) {
      throw const PlayerProfileException('Profile service request failed.');
    }
  }

  static Future<bool> updatePlayerName(String name) async {
    try {
      return await SupabasePlayerProfileService.updatePlayerName(name);
    } on SupabasePlayerProfileException catch (error) {
      throw PlayerProfileException(error.message);
    } catch (_) {
      throw const PlayerProfileException('Profile service request failed.');
    }
  }
}
