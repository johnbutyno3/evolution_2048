import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'game/services/gold_manager.dart';
import 'game/services/life_manager.dart';
import 'game/services/save_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_register_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/profile_page.dart';
import 'screens/home_page.dart';
import 'screens/shop_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FirebaseAuth restores the persisted session asynchronously. Wait for
  // its first state event before deciding whether to show login or HomePage.
  // Otherwise a valid signed-in account can look signed out on a cold start.
  await FirebaseAuth.instance.authStateChanges().first;

  await SaveManager.initialize();
  await LifeManager.initialize();
  await GoldManager.initialize();

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

    if (!SaveManager.hasProfile) {
      return const ProfilePage();
    }

    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rebirth 2048',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en', 'US')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: _home(),
      routes: {
        '/shop': (_) => const ShopPage(),
      },
    );
  }
}

