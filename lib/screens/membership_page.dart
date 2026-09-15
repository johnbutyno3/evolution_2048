import 'package:flutter/material.dart';

import '../game/services/life_manager.dart';
import '../services/shop_config_service.dart';

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
        const SnackBar(
          content: Text('Real-money payment is not connected yet.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final config = snapshot.data ?? ShopConfigService.defaults;
          final current = LifeManager.membership;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _membershipCard(
                title: 'General',
                description: 'Ads normal · 5 lives',
                price: 'Free',
                current: current == 'general',
              ),
              _membershipCard(
                title: 'Premium',
                description: 'No forced ads · 5 lives · 20 daily Gold',
                price: '\$${ShopConfigService.usdPrice(config, 'premiumUsdPrice')} / month',
                current: current == 'premium',
              ),
              _membershipCard(
                title: 'Golden',
                description: 'Completely ad-free · unlimited lives · 50 daily Gold',
                price: '\$${ShopConfigService.usdPrice(config, 'goldenUsdPrice')} / month',
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
            ? const Chip(label: Text('Current'))
            : FilledButton(
                onPressed: _unavailable,
                child: Text(price),
              ),
      ),
    );
  }
}
