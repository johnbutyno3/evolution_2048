import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/services/supabase_auth_service.dart';

void main() {
  test('native OAuth redirect matches the registered app callback', () {
    expect(
      SupabaseAuthService.nativeOAuthRedirectUri,
      'io.supabase.rebirth2048://login-callback/',
    );
  });
}
