import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OfficerDashboardScreen extends StatelessWidget {
  const OfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Officer Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/scanner'),
              child: const Text('Open QR Scanner'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Manage Events (Coming Soon)'),
            ),
          ],
        ),
      ),
    );
  }
}
