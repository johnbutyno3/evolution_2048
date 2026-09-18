import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'game/services/gold_manager.dart';
import 'game/services/life_manager.dart';
import 'game/services/save_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_register_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/home_page.dart';
import 'screens/shop_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerWeb: WebDebugProvider(),
  );

  // FirebaseAuth restores the persisted session asynchronously. Wait for
  // its first state event before deciding whether to show login or HomePage.
  // Otherwise a valid signed-in account can look signed out on a cold start.
  await FirebaseAuth.instance.authStateChanges().first;

  // Development builds automatically restore the dedicated developer
  // Firebase session, so repeated test launches do not require manual login.
  if (kDebugMode && FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'dev@rebirth2048.local',
        password: 'Rebirth2048Dev!',
      );
      await SaveManager.setDeveloperMode(true);
    } on FirebaseAuthException {
      // Fall back to the normal login/register screen if the developer
      // account is unavailable in the current Firebase project.
    }
  }

  await SaveManager.initialize();

  // Life and Gold are server-authoritative and require authentication.
  // Do not call their protected functions before a signed-in user exists.
  // After login, HomePage initializes them for the authenticated session.
  if (FirebaseAuth.instance.currentUser != null) {
    await LifeManager.initialize();
    await GoldManager.initialize();
  }

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
