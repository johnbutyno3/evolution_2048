import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_backend.dart';

/// Supabase Auth entry points for the staged Firebase migration.
/// The UI is not switched over until dependent Firebase services are migrated.
class SupabaseAuthService {
  SupabaseAuthService._();

  static GoTrueClient get _auth => SupabaseBackend.client.auth;

  static Session? get currentSession => _auth.currentSession;

  static User? get currentUser => _auth.currentUser;

  static Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

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

  /// Starts the Supabase-hosted OAuth flow.
  ///
  /// [redirectTo] must be registered in Supabase Auth URL Configuration and
  /// configured as an app deep link for native platforms.
  static Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectTo,
  }) {
    return _auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  static Future<void> signOut() => _auth.signOut();
}
