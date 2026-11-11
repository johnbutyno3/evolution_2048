import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import 'game/services/save_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_register_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/home_page.dart';
import 'screens/shop_page.dart';
import 'services/supabase_backend.dart';
import 'services/supabase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase Auth and Edge Functions are the active account path.
  // Only public client keys may be supplied via dart-define.
  final supabaseReady = await SupabaseBackend.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
    ),
  );
  if (!supabaseReady) {
    throw StateError('SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required.');
  }
  debugPrint(
    '[AUTH_DIAG] Supabase initialized '
    'sessionPresent=${SupabaseAuthService.currentSession != null}',
  );

  // Supabase restores its persisted session before the auth router is built.
  await SaveManager.initialize();

  runApp(const Rebirth2048App());
}

class Rebirth2048App extends StatelessWidget {
  const Rebirth2048App({super.key});

  Widget _home() {
    if (!SaveManager.hasCompletedOnboarding) {
      return const OnboardingPage();
    }

    // Wait for Supabase Auth to restore its persisted session before routing.
    return StreamBuilder<AuthState>(
      stream: SupabaseAuthService.authStateChanges,
      builder: (context, snapshot) {
        final currentSession = SupabaseAuthService.currentSession;
        debugPrint(
          '[AUTH_DIAG] router state=${snapshot.connectionState.name} '
          'hasData=${snapshot.hasData} '
          'event=${snapshot.data?.event.name ?? "none"} '
          'streamError=${snapshot.hasError} '
          'sessionPresent=${currentSession != null} '
          'snapshotSession=${snapshot.data?.session != null}',
        );
        if (snapshot.hasError) {
          debugPrint('[AUTH_DIAG] router stream error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            currentSession == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data?.session?.user ??
            SupabaseAuthService.currentUser;
        if (snapshot.hasError || user == null) {
          return const LoginRegisterPage();
        }

        return const HomePage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SaveManager.localeCodeNotifier,
      builder: (context, languageCode, _) {
        return MaterialApp(
          title: 'Rebirth 2048',
          debugShowCheckedModeBanner: false,
          locale: Locale(languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: _home(),
          routes: {'/shop': (_) => const ShopPage()},
        );
      },
    );
  }
}
