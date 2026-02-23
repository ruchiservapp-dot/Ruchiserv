import 'package:flutter/material.dart';

class RefundCancellationScreen extends StatelessWidget {
  const RefundCancellationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refund & Cancellation Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Refund & Cancellation Policy',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text(
              'ELKERON TECHNOLOGIES PRIVATE LIMITED adheres to a strict yet fair cancellation and refund policy for the RuchiServ SaaS platform.\n\n'
              'Cancellation Policy:\n'
              '- Customers may cancel their subscription at any time via their account dashboard or by contacting info@ekleron.com.\n'
              '- Cancellations take effect at the end of the current billing cycle. Access to the Service is retained until that billing cycle concludes.\n\n'
              'Refund Policy:\n'
              '- We do not offer prorated refunds for mid-cycle cancellations.\n'
              '- In the event of an erroneous or duplicate charge, please report the issue to our support team within 7 days of the transaction. Verified disputes are eligible for a full refund processed within 5-7 business days to the original payment source.\n'
              '- No retroactive refunds will be provided for subscription cycles that have already been utilized.\n\n'
              'For further assistance regarding billing, please reach us at +91 9400768440.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
