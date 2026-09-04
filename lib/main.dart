import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'game/screens/evolution_2048_page.dart';
import 'game/services/save_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SaveManager.initialize();

  runApp(const Rebirth2048App());
}

class Rebirth2048App extends StatelessWidget {
  const Rebirth2048App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rebirth 2048',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: SaveManager.hasCompletedOnboarding
          ? const Evolution2048Page()
          : const OnboardingPage(),
    );
  }
}
