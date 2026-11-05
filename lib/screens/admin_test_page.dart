import 'package:flutter/material.dart';

import '../services/admin_service.dart';

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
            body: Center(child: Text('Administrator access required.')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Test Controls')),
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
