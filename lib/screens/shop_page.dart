import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import 'gold_page.dart';
import 'tools_page.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.shop),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ShopEntry(
            icon: Icons.monetization_on_outlined,
            title: AppLocalizations.of(context)!.shopGold,
            subtitle: AppLocalizations.of(context)!.shopGoldSubtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GoldPage(),
                ),
              );
            },
          ),
          _ShopEntry(
            icon: Icons.build_outlined,
            title: AppLocalizations.of(context)!.shopTools,
            subtitle: AppLocalizations.of(context)!.shopToolsSubtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ToolsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShopEntry extends StatelessWidget {
  const _ShopEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(icon, size: 34),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
