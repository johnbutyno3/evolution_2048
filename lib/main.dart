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

// Web debug intentionally does not require a dart-define token. WebDebugProvider
// uses the browser-local Firebase App Check debug token mechanism configured in
// web/index.html. Release Web still requires the production Site Key.
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

  if (kIsWeb && !kDebugMode && kFirebaseAppCheckWebSiteKey.isEmpty) {
    throw StateError(
      'FIREBASE_APPCHECK_WEB_SITE_KEY is required for release Web builds.',
    );
  }

  await FirebaseAppCheck.instance.activate(
    providerWeb: (kDebugMode || kFirebaseAppCheckDebug)
        ? WebDebugProvider()
        : ReCaptchaV3Provider(kFirebaseAppCheckWebSiteKey),
    providerAndroid: (kDebugMode || kFirebaseAppCheckDebug)
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: (kDebugMode || kFirebaseAppCheckDebug)
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );

  await FirebaseAuth.instance.authStateChanges().first;

  await SaveManager.initialize();

  runApp(const Rebirth2048App());
}

class Rebirth2048App extends StatelessWidget {
  const Rebirth2048App({super.key});

  Widget _home() {
    if (!SaveManager.hasCompletedOnboarding) {
      return const OnboardingPage();
    }

    if (FirebaseAuth.instance.currentUser == null) {
      return const LoginRegisterPage();
    }

    return const HomePage();
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
