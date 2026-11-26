import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline app has no Firebase, Supabase, or Google Sign-In dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    final lockfile = File('pubspec.lock').readAsStringSync().toLowerCase();
    final appGradle =
        File('android/app/build.gradle.kts').readAsStringSync().toLowerCase();
    final rootGradle =
        File('android/build.gradle.kts').readAsStringSync().toLowerCase();
    final settingsGradle =
        File('android/settings.gradle.kts').readAsStringSync().toLowerCase();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync()
            .toLowerCase();
    final main = File('lib/main.dart').readAsStringSync().toLowerCase();

    for (final source in [
      pubspec,
      lockfile,
      appGradle,
      rootGradle,
      settingsGradle,
      manifest,
      main,
    ]) {
      expect(source, isNot(contains('firebase')));
      expect(source, isNot(contains('supabase')));
      expect(source, isNot(contains('google_sign_in')));
      expect(source, isNot(contains('google-services')));
    }

    expect(main, isNot(contains('signinauth')));
    expect(main, isNot(contains('firebase.initializeapp')));
    expect(main, isNot(contains('supabase.initialize')));
  });
}
