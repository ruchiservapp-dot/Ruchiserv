import 'package:flutter/material.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing Information')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pricing Information', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text(
              'ELKERON TECHNOLOGIES PRIVATE LIMITED provides straightforward subscription pricing for RuchiServ.\n\n'
              'SaaS Subscription Model:\n'
              '- We operate on a customized subscription model based on feature requirements and usage limits.\n'
              '- Pricing tiers are billed on a recurring monthly or annual basis.\n'
              '- Detailed pricing plans are available in your business dashboard.\n\n'
              'Transaction & Gateway Fees:\n'
              'If utilizing integrated payment gateways through RuchiServ to collect your customer funds, standard gateway transaction fees apply directly to those amounts.\n\n'
              'All pricing quotes are stated exclusive of GST and other applicable taxes unless explicitly mentioned.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
