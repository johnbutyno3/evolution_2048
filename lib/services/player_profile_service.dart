import 'supabase_player_profile_service.dart';
import '../game/services/save_manager.dart';
import 'supabase_backend.dart';

class PlayerProfileException implements Exception {
  const PlayerProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlayerProfileService {
  PlayerProfileService._();

  static Future<void> updateAvatarIndex(int index) async {
    if (!SupabaseBackend.isAuthenticated) {
      await SaveManager.saveAvatarIndex(index);
      return;
    }
    try {
      await SupabasePlayerProfileService.updateAvatarIndex(index);
    } on SupabasePlayerProfileException catch (error) {
      throw PlayerProfileException(error.message);
    } catch (_) {
      throw const PlayerProfileException('Avatar could not be saved. Please retry online.');
    }
  }

  static Future<String?> ensureProfile() async {
    if (!SupabaseBackend.isAuthenticated) return null;
    try {
      return await SupabasePlayerProfileService.ensureProfile();
    } on SupabasePlayerProfileException catch (error) {
      throw PlayerProfileException(error.message);
    } catch (_) {
      throw const PlayerProfileException('Profile service request failed.');
    }
  }

  static Future<bool> updatePlayerName(String name) async {
    if (!SupabaseBackend.isAuthenticated) {
      await SaveManager.saveProfile(name: name);
      return true;
    }
    try {
      return await SupabasePlayerProfileService.updatePlayerName(name);
    } on SupabasePlayerProfileException catch (error) {
      throw PlayerProfileException(error.message);
    } catch (_) {
      throw const PlayerProfileException('Profile service request failed.');
    }
  }
}
