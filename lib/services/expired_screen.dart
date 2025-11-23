import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpiredScreen extends StatelessWidget {
  final String expiryDateText;
  const ExpiredScreen({super.key, required this.expiryDateText});

  Future<void> _contactSupport() async {
    // Update to your support WhatsApp or mailto/call as needed
    final uri = Uri.parse('https://wa.me/0000000000?text=Renew%20RuchiServ%20Subscription');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 56),
                    const SizedBox(height: 16),
                    const Text('Subscription Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Your subscription expired on $expiryDateText and the grace period has ended.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _contactSupport,
                      child: const Text('Contact Support to Renew'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
