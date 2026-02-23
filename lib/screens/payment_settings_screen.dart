import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  bool _cashfreeEnabled = true;
  bool _upiEnabled = true;
  bool _cardEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _cashfreeEnabled = sp.getBool('payment_cashfree') ?? true;
      _upiEnabled = sp.getBool('payment_upi') ?? true;
      _cardEnabled = sp.getBool('payment_card') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, bool val) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Payment Gateway", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      Text("Cashfree", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("0% UPI fees • Integrated", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text("Cashfree Payments"),
            subtitle: const Text("Enable Cashfree for customer payments"),
            value: _cashfreeEnabled,
            onChanged: (val) {
               setState(() => _cashfreeEnabled = val);
               _saveSetting('payment_cashfree', val);
            },
          ),
          SwitchListTile(
            title: const Text("UPI (0% fee)"),
            subtitle: const Text("Enable UPI payments via Cashfree"),
            value: _upiEnabled,
            onChanged: (val) {
               setState(() => _upiEnabled = val);
               _saveSetting('payment_upi', val);
            },
          ),
          SwitchListTile(
            title: const Text("Card Payments"),
            subtitle: const Text("Accept Credit/Debit cards (1.9% fee)"),
            value: _cardEnabled,
            onChanged: (val) {
               setState(() => _cardEnabled = val);
               _saveSetting('payment_card', val);
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Test Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              // Mock payment
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Test Mode Active"),
                  content: const Text("Cashfree SDK is in sandbox mode. Use test card 4111 1111 1111 1111 for testing."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.payment),
            label: const Text("Test Payment Info"),
          ),
        ],
      ),
    );
  }
}
