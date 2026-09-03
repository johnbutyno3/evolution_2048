import 'package:flutter/material.dart';

import 'game/screens/evolution_2048_page.dart';
import 'game/services/save_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const Evolution2048Page(),
    );
  }
}
