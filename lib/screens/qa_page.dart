import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class QAPage extends StatelessWidget {
  const QAPage({super.key});



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <(String, String)>[
      (l10n.faqQuestion1, l10n.faqAnswer1),
      (l10n.faqQuestion2, l10n.faqAnswer2),
      (l10n.faqQuestion3, l10n.faqAnswer3),
      (l10n.faqQuestion4, l10n.faqAnswer4),
      (l10n.faqQuestion5, l10n.faqAnswer5),
      (l10n.faqQuestion6, l10n.faqAnswer6),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.qaTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocalizations.of(context)!.faqTitle,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
