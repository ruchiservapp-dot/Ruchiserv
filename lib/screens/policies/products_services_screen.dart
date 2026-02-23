import 'package:flutter/material.dart';

class ProductsServicesScreen extends StatelessWidget {
  const ProductsServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products & Services')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Products & Services',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text(
              'Products & Services offered by ELKERON TECHNOLOGIES PRIVATE LIMITED:\n\n'
              'RuchiServ SaaS Platform\n'
              'RuchiServ is an advanced Software-as-a-Service solution engineered to streamline enterprise event operations, kitchen logistics, and workforce management.\n\n'
              'Key Modules & Offerings:\n'
              '- Advanced Event & Order Management\n'
              '- Real-time Cloud Synchronization\n'
              '- Multi-device Support (Mobile, Tablet, Web)\n'
              '- Staff Attendance & Assignment Tracking\n'
              '- Kitchen Operations (BOM) & Inventory\n'
              '- Integrated Customer Quotations & Portals\n'
              '- Live Dispatch & Delivery Tracking\n'
              '- Detailed Financial Reporting & Analytics\n\n'
              'Our platform is designed to provide high reliability, availability, and seamless scalability for your business operations.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
