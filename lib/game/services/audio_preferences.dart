import 'package:shared_preferences/shared_preferences.dart';

class AudioPreferencesSnapshot {
  const AudioPreferencesSnapshot({
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.musicVolume,
    required this.sfxVolume,
  });

  final bool musicEnabled;
  final bool sfxEnabled;
  final double musicVolume;
  final double sfxVolume;
}

class AudioPreferences {
  AudioPreferences._();

  static const String musicEnabledKey = 'rebirth_2048_music_enabled_v1';
  static const String sfxEnabledKey = 'rebirth_2048_sfx_enabled_v1';
  static const String musicVolumeKey = 'rebirth_2048_music_volume_v1';
  static const String sfxVolumeKey = 'rebirth_2048_sfx_volume_v1';

  static Future<AudioPreferencesSnapshot> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AudioPreferencesSnapshot(
      musicEnabled: preferences.getBool(musicEnabledKey) ?? true,
      sfxEnabled: preferences.getBool(sfxEnabledKey) ?? true,
      musicVolume: (preferences.getDouble(musicVolumeKey) ?? 0.35)
          .clamp(0.0, 1.0).toDouble(),
      sfxVolume: (preferences.getDouble(sfxVolumeKey) ?? 0.55)
          .clamp(0.0, 1.0).toDouble(),
    );
  }

  static Future<void> saveMusicEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(musicEnabledKey, value);
  }

  static Future<void> saveSfxEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(sfxEnabledKey, value);
  }

  static Future<double> saveMusicVolume(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(musicVolumeKey, normalized);
    return normalized;
  }

  static Future<double> saveSfxVolume(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(sfxVolumeKey, normalized);
    return normalized;
  }
}
