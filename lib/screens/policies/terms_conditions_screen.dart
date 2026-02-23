import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terms & Conditions',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text(
              'Welcome to RuchiServ, a product by ELKERON TECHNOLOGIES PRIVATE LIMITED.\n\n'
              'By using our SaaS platform ("Service"), you agree to the following terms and conditions:\n\n'
              '1. Acceptance of Terms\n'
              'By accessing or using RuchiServ, you agree to be bound by these Terms. If you disagree, do not use the Service.\n\n'
              '2. Subscription & SaaS Services\n'
              'RuchiServ provides subscription-based software services. Features and availability may change over time based on continued platform development.\n\n'
              '3. User Responsibilities\n'
              'You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account. Unlawful use is strictly prohibited.\n\n'
              '4. Payment Terms\n'
              'Subscriptions are billed in advance on a recurring basis as per your chosen plan.\n\n'
              '5. Limitation of Liability\n'
              'ELKERON TECHNOLOGIES PRIVATE LIMITED shall not be liable for any indirect, incidental, or consequential damages arising out of your use of the Service.\n\n'
              '6. Governing Law\n'
              'These terms shall be governed by the laws of India, under the jurisdiction of Ernakulam, Kerala.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
