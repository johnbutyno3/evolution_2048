import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../l10n/app_localizations.dart';

class AdminTestPage extends StatelessWidget {
  const AdminTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminService.checkAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != true) {
          return const Scaffold(
            body: Center(child: Text(AppLocalizations.of(context)!.adminRequired)),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.of(context)!.testControlsTitle)),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Legacy Firebase test controls have been disabled. '
              'Supabase administrator controls will be restored after '
              'the corresponding secure Edge Functions are implemented.',
            ),
          ),
        );
      },
    );
  }
}
