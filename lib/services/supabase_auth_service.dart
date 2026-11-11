import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/services/save_manager.dart';
import 'supabase_backend.dart';

/// Supabase Auth entry points used by the application account flow.
class SupabaseAuthService {
  SupabaseAuthService._();

  /// Must also be allow-listed in Supabase Dashboard > Authentication > URL
  /// Configuration. Android and iOS native projects register this callback.
  static const String nativeOAuthRedirectUri =
      'io.supabase.rebirth2048://login-callback/';

  static GoTrueClient get _auth => SupabaseBackend.client.auth;

  static Session? get currentSession => _auth.currentSession;

  static User? get currentUser => _auth.currentUser;

  /// Logs only event names and session presence; never tokens or credentials.
  static Stream<AuthState> get authStateChanges =>
      _auth.onAuthStateChange
          .map((state) {
            debugPrint(
              '[AUTH_DIAG] event=${state.event.name} '
              'session=${state.session != null} '
              'user=${state.session?.user != null}',
            );
            return state;
          })
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('[AUTH_DIAG] auth stream error: $error');
            Error.throwWithStackTrace(error, stackTrace);
          });

  static Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Starts Google OAuth with the shared native callback URI.
  static Future<bool> signInWithGoogle() => signInWithOAuth(
        provider: OAuthProvider.google,
        redirectTo: nativeOAuthRedirectUri,
      );

  /// Starts Apple OAuth with the shared native callback URI.
  static Future<bool> signInWithApple() => signInWithOAuth(
        provider: OAuthProvider.apple,
        redirectTo: nativeOAuthRedirectUri,
      );

  /// Starts the Supabase-hosted OAuth flow.
  ///
  /// [redirectTo] must be registered in Supabase Auth URL Configuration and
  /// configured as an app deep link for native platforms.
  static Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectTo,
  }) async {
    debugPrint(
      '[AUTH_DIAG] OAuth start provider=${provider.name} '
      'redirect=$redirectTo',
    );
    try {
      final started = await _auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      debugPrint('[AUTH_DIAG] OAuth launch returned started=$started');
      return started;
    } catch (error, stackTrace) {
      debugPrint('[AUTH_DIAG] OAuth launch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    await SaveManager.unbindAccountScope();
  }
}
