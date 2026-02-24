import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../core/settings_provider.dart';
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  // Local state removed, using SettingsProvider via Consumer


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Payment Gateway",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Cashfree info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Cashfree",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("0% UPI fees • Integrated",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return Column(
                children: [
                  SwitchListTile(
                    title: const Text("Cashfree Payments"),
                    subtitle: const Text("Enable Cashfree for customer payments"),
                    value: settings.paymentCashfree,
                    onChanged: (val) {
                      settings.setPaymentCashfree(val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text("UPI (0% fee)"),
                    subtitle: const Text("Enable UPI payments via Cashfree"),
                    value: settings.paymentUpi,
                    onChanged: (val) {
                      settings.setPaymentUpi(val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text("Card Payments"),
                    subtitle: const Text("Accept Credit/Debit cards (1.9% fee)"),
                    value: settings.paymentCard,
                    onChanged: (val) {
                      settings.setPaymentCard(val);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
