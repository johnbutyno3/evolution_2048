import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'game/services/save_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_register_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/home_page.dart';
import 'screens/shop_page.dart';
import 'services/supabase_backend.dart';

// Web debug can optionally receive a locally supplied, already-registered
// debug token. The token must never be committed to source control.
const kFirebaseAppCheckWebDebugToken = String.fromEnvironment(
  'FIREBASE_APPCHECK_WEB_DEBUG_TOKEN',
  defaultValue: '',
);

// Web debug intentionally does not require a dart-define token. WebDebugProvider
// uses the browser-local Firebase App Check debug token mechanism configured in
// web/index.html when no explicit token is supplied. Release Web still requires
// the production Site Key.
const kFirebaseAppCheckWebSiteKey = String.fromEnvironment(
  'FIREBASE_APPCHECK_WEB_SITE_KEY',
  defaultValue: '',
);

// Release builds use production App Check providers by default. Test APKs that
// are sideloaded (and therefore cannot satisfy Play Integrity) must explicitly
// opt into the debug provider with --dart-define=FIREBASE_APPCHECK_DEBUG=true.
const kFirebaseAppCheckDebug = bool.fromEnvironment(
  'FIREBASE_APPCHECK_DEBUG',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase is being introduced service-by-service. Keep the existing Firebase
  // authentication path until every dependent service has been migrated.
  // Only public client keys may be supplied via dart-define.
  await SupabaseBackend.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
    ),
  );

  if (kIsWeb && !kDebugMode && kFirebaseAppCheckWebSiteKey.isEmpty) {
    throw StateError(
      'FIREBASE_APPCHECK_WEB_SITE_KEY is required for release Web builds.',
    );
  }

  await FirebaseAppCheck.instance.activate(
    providerWeb: (kDebugMode || kFirebaseAppCheckDebug)
        ? WebDebugProvider(
            debugToken: kFirebaseAppCheckWebDebugToken.isNotEmpty
                ? kFirebaseAppCheckWebDebugToken
                : null,
          )
        : ReCaptchaV3Provider(kFirebaseAppCheckWebSiteKey),
    providerAndroid: (kDebugMode || kFirebaseAppCheckDebug)
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: (kDebugMode || kFirebaseAppCheckDebug)
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );

  // Do not block app startup on the first Web Auth state event. Firebase Auth
  // initializes asynchronously in the browser; waiting here can leave the
  // whole Flutter app blank when the Web Auth layer reports a transient init
  // error. The UI reads currentUser when it builds and Auth continues to manage
  // its state normally after startup.
  await SaveManager.initialize();

  runApp(const Rebirth2048App());
}

class Rebirth2048App extends StatelessWidget {
  const Rebirth2048App({super.key});

  Widget _home() {
    if (!SaveManager.hasCompletedOnboarding) {
      return const OnboardingPage();
    }

    // Firebase Auth restores a persisted session asynchronously. Reading
    // currentUser only once can route a returning player to LoginRegisterPage
    // before that restoration finishes. React to the first auth-state event
    // instead, and do not present the game until the account state is known.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
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
