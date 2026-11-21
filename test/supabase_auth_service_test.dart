import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/services/supabase_auth_service.dart';

void main() {
  test('native OAuth callback has the expected Android deep-link components', () {
    final callback = Uri.parse(SupabaseAuthService.nativeOAuthRedirectUri);

    expect(callback.scheme, 'io.supabase.rebirth2048');
    expect(callback.host, 'login-callback');
    expect(callback.path, '/');
  });
}
