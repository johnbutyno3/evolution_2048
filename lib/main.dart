import 'package:flutter/material.dart';

import 'game/services/save_manager.dart';
import 'game/services/life_manager.dart';
import 'game/services/gold_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/onboarding_page.dart';
import 'screens/home_page.dart';
import 'screens/shop_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Single-player startup is fully local; no auth or backend bootstrap.

  await SaveManager.initialize();
  await LifeManager.initializeLocal();
  await GoldManager.initializeLocal();

  runApp(const Rebirth2048App());
}

class Rebirth2048App extends StatefulWidget {
  const Rebirth2048App({super.key});

  @override
  State<Rebirth2048App> createState() => _Rebirth2048AppState();
}

class _Rebirth2048AppState extends State<Rebirth2048App> {

  Widget _home() {
    if (!SaveManager.hasCompletedOnboarding) {
      return OnboardingPage(onCompleted: () {
        if (mounted) setState(() {});
      });
    }

    // Guest-first single-player entry: never gate gameplay on an account.
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
