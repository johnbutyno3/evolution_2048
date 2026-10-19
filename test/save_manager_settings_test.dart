import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/services/audio_preferences.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('audio preferences load defaults and persist toggles and volumes', () async {
    final defaults = await AudioPreferences.load();
    expect(defaults.musicEnabled, isTrue);
    expect(defaults.sfxEnabled, isTrue);
    expect(defaults.musicVolume, 0.35);
    expect(defaults.sfxVolume, 0.55);

    await AudioPreferences.saveMusicEnabled(false);
    await AudioPreferences.saveSfxEnabled(false);
    expect(await AudioPreferences.saveMusicVolume(1.5), 1.0);
    expect(await AudioPreferences.saveSfxVolume(-0.5), 0.0);

    final restored = await AudioPreferences.load();
    expect(restored.musicEnabled, isFalse);
    expect(restored.sfxEnabled, isFalse);
    expect(restored.musicVolume, 1.0);
    expect(restored.sfxVolume, 0.0);
  });

  test('onboarding completion persists', () async {
    expect(SaveManager.hasCompletedOnboarding, isFalse);

    await SaveManager.completeOnboarding();

    expect(SaveManager.hasCompletedOnboarding, isTrue);
  });
}
