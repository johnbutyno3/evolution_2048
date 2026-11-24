import 'package:flutter/material.dart';

import '../game/services/life_manager.dart';
import '../services/shop_config_service.dart';
import '../l10n/app_localizations.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  late Future<Map<String, dynamic>> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = ShopConfigService.load();
  }

  void _unavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.paymentUnavailable),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.membership)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final config = snapshot.data ?? ShopConfigService.defaults;
          final current = LifeManager.membership;
          final goldenPrice = current == 'premium'
              ? '\$${ShopConfigService.usdPrice(config, 'goldenUpgradeUsdPrice')} · Upgrade'
              : '\$${ShopConfigService.usdPrice(config, 'goldenUsdPrice')} · Permanent';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _membershipCard(
                title: AppLocalizations.of(context)!.membershipGeneral,
                description: AppLocalizations.of(context)!.membershipGeneralDescription,
                price: AppLocalizations.of(context)!.membershipGeneral,
                current: current == 'general',
              ),
              _membershipCard(
                title: AppLocalizations.of(context)!.membershipPremium,
                description: AppLocalizations.of(context)!.membershipPremiumDescription,
                price: '\$${ShopConfigService.usdPrice(config, 'premiumUsdPrice')} · Permanent',
                current: current == 'premium',
              ),
              _membershipCard(
                title: AppLocalizations.of(context)!.membershipGolden,
                description: AppLocalizations.of(context)!.membershipGoldenDescription,
                price: goldenPrice,
                current: current == 'golden',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _membershipCard({
    required String title,
    required String description,
    required String price,
    required bool current,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.workspace_premium_outlined, size: 34),
        title: Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(description),
        ),
        trailing: current
            ? Chip(label: Text(AppLocalizations.of(context)!.currentLabel))
            : FilledButton(
                onPressed: _unavailable,
                child: Text(price),
              ),
      ),
    );
  }
}
