import 'package:flutter/material.dart';

import '../game/services/gold_manager.dart';
import '../l10n/app_localizations.dart';

class GoldPage extends StatefulWidget {
  const GoldPage({super.key});

  @override
  State<GoldPage> createState() => _GoldPageState();
}

class _GoldPageState extends State<GoldPage> {
  late Future<int?> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = GoldManager.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gold)),
      body: FutureBuilder<int?>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monetization_on, size: 34),
                  title: Text(l10n.goldBalanceTitle),
                  trailing: Text(
                    '${GoldManager.balance}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(l10n.shopGold),
                  subtitle: Text(l10n.paymentUnavailable),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
