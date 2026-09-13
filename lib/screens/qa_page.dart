import 'package:flutter/material.dart';

class QAPage extends StatelessWidget {
  const QAPage({super.key});

  static const _items = [
    (
      'How do I play Rebirth 2048?',
      'Swipe or use the keyboard to move life forms. Matching life forms evolve into the next stage. Reach the chapter target to progress.'
    ),
    (
      'What happens when I discover a creature?',
      'A discovered creature is permanently recorded in your Creature Collection and will remain unlocked after replaying or restarting.'
    ),
    (
      'What are Lives?',
      'Lives allow you to continue playing after a game ends. Membership benefits may change the available life rules.'
    ),
    (
      'What is Gold?',
      'Gold is the in-game currency used for eligible shop purchases such as Lives and Evolution Tools.'
    ),
    (
      'What do the Evolution Tools do?',
      'UNDO rewinds a move, REMOVE removes a selected life form, SWAP exchanges positions, and DUPLICATE creates a copy of a selected life form.'
    ),
    (
      'How do I report a problem?',
      'Open Contact / Feedback from your Personal page and choose Bug Report. You can describe the problem and send it to the game team.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Q&A')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final item in _items)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: const Icon(Icons.help_outline),
                title: Text(item.$1),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item.$2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
