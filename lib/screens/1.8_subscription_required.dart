import 'package:flutter/material.dart';

class SubscriptionRequiredScreen extends StatelessWidget {
  final bool adminInGrace;
  final DateTime? expiry;

  const SubscriptionRequiredScreen({
    super.key,
    required this.adminInGrace,
    this.expiry,
  });

  @override
  Widget build(BuildContext context) {
    final expiredOn = expiry == null
        ? 'Unknown'
        : '${expiry!.day}/${expiry!.month}/${expiry!.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Required'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock, size: 72, color: Colors.orange.shade700),
              const SizedBox(height: 16),
              Text(
                adminInGrace
                    ? 'Your plan expired on $expiredOn.\nAdmin grace is active.\nPlease renew now.'
                    : 'Your firm\'s subscription has expired.\nPlease ask an admin to renew.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigate to your in-app purchase / payment or show instructions.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Renewal flow coming soon…')),
                  );
                },
                icon: const Icon(Icons.payment),
                label: const Text('Renew Subscription'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
