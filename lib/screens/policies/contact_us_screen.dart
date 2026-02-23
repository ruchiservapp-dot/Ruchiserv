import 'package:flutter/material.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Us',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text(
              'ELKERON TECHNOLOGIES PRIVATE LIMITED\n\n'
              'If you have any questions or queries, please feel free to reach out to us at:\n\n'
              'Email: info@ekleron.com\n'
              'Phone: +91 9400768440\n\n'
              'Address:\n'
              '371/12, Ekleron towers,\n'
              'Malayattoor, Ernakulam,\n'
              'Kerala, PIN - 683587',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
