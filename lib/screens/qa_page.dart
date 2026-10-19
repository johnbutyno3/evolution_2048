import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class QAPage extends StatelessWidget {
  const QAPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (l10n.qaQuestion1, l10n.qaAnswer1),
      (l10n.qaQuestion2, l10n.qaAnswer2),
      (l10n.qaQuestion3, l10n.qaAnswer3),
      (l10n.qaQuestion4, l10n.qaAnswer4),
      (l10n.qaQuestion5, l10n.qaAnswer5),
      (l10n.qaQuestion6, l10n.qaAnswer6),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qaTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.qaHeading,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final item in items)
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
