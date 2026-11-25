import '../game/services/save_manager.dart';

/// Local-only profile settings. No account or remote profile is created.
class PlayerProfileService {
  PlayerProfileService._();

  static Future<void> updateAvatarIndex(int index) =>
      SaveManager.saveAvatarIndex(index);

  static Future<String?> ensureProfile() async => SaveManager.playerId;

  static Future<bool> updatePlayerName(String name) async {
    await SaveManager.saveProfile(name: name);
    return true;
  }
}
