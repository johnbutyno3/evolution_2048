import 'package:flutter/material.dart';

import 'game/screens/evolution_2048_chapters_page.dart';

void main() {
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
      home: const Evolution2048ChaptersPage(),
    );
  }
}
