import 'package:flutter_test/flutter_test.dart';
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

  test('onboarding completion persists', () async {
    expect(SaveManager.hasCompletedOnboarding, isFalse);

    await SaveManager.completeOnboarding();

    expect(SaveManager.hasCompletedOnboarding, isTrue);
  });
}
