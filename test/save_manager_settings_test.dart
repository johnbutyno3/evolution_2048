import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/services/audio_manager.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
  });

  test('language setting persists and notifies the running app', () async {
    await SaveManager.saveLocaleCode('zh');

    expect(SaveManager.localeCode, 'zh');
    expect(SaveManager.localeCodeNotifier.value, 'zh');

    await SaveManager.saveLocaleCode('unsupported');

    expect(SaveManager.localeCode, 'en');
    expect(SaveManager.localeCodeNotifier.value, 'en');
  });

  test('vibration preference defaults on and persists changes', () async {
    expect(SaveManager.vibrationEnabled, isTrue);

    await SaveManager.saveVibrationEnabled(false);
    expect(SaveManager.vibrationEnabled, isFalse);

    await SaveManager.saveVibrationEnabled(true);
    expect(SaveManager.vibrationEnabled, isTrue);
  });

  test('profile name is trimmed and empty names do not count as a profile', () async {
    await SaveManager.saveProfile(name: '  Ocean Explorer  ');

    expect(SaveManager.profileName, 'Ocean Explorer');
    expect(SaveManager.hasProfile, isTrue);

    await SaveManager.saveProfile(name: '   ');

    expect(SaveManager.profileName, isEmpty);
    expect(SaveManager.hasProfile, isFalse);
  });

  test('avatar index is clamped to supported range', () async {
    await SaveManager.saveAvatarIndex(99);
    expect(SaveManager.avatarIndex, 53);

    await SaveManager.saveAvatarIndex(-1);
    expect(SaveManager.avatarIndex, 0);

    await SaveManager.saveAvatarIndex(12);
    expect(SaveManager.avatarIndex, 12);
  });

  test('audio toggles and volume controls persist clamped values', () async {
    final audio = AudioManager.instance;

    await audio.setMusicEnabled(false);
    await audio.setSfxEnabled(false);
    await audio.setMusicVolume(1.5);
    await audio.setSfxVolume(-0.5);

    final preferences = await SharedPreferences.getInstance();
    expect(audio.musicEnabled, isFalse);
    expect(audio.sfxEnabled, isFalse);
    expect(audio.musicVolume, 1.0);
    expect(audio.sfxVolume, 0.0);
    expect(preferences.getBool('rebirth_2048_music_enabled_v1'), isFalse);
    expect(preferences.getBool('rebirth_2048_sfx_enabled_v1'), isFalse);
    expect(preferences.getDouble('rebirth_2048_music_volume_v1'), 1.0);
    expect(preferences.getDouble('rebirth_2048_sfx_volume_v1'), 0.0);
  });

  test('onboarding completion persists', () async {
    expect(SaveManager.hasCompletedOnboarding, isFalse);

    await SaveManager.completeOnboarding();

    expect(SaveManager.hasCompletedOnboarding, isTrue);
  });
}
