import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app entry does not expose a sign-in screen or OAuth callback', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(mainSource, isNot(contains('LoginRegisterPage')));
    expect(mainSource, contains('return const HomePage();'));
    expect(
      File('lib/screens/login_register_page.dart').existsSync(),
      isFalse,
    );
    expect(manifest, isNot(contains('login-callback')));
  });
}
