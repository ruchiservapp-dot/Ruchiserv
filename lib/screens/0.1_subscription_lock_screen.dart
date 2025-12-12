// lib/screens/0.1_subscription_lock_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionLockScreen extends StatelessWidget {
  final String firmId;
  final int daysOverdue;

  const SubscriptionLockScreen({
    super.key,
    required this.firmId,
    required this.daysOverdue,
  });

  Future<void> _contactSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@ruchiserv.com',
      query: 'subject=Subscription Renewal for Firm $firmId',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // F.1 Mandate: No close button, full blocking overlay
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Subscription Expired',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your subscription for firm $firmId expired $daysOverdue days ago.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access to RuchiServ is locked until renewal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _contactSupport,
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Contact Support to Renew'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
