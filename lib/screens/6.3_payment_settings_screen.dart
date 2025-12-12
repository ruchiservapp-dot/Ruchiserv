import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  bool _razorpayEnabled = true;
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
      _razorpayEnabled = sp.getBool('payment_razorpay') ?? true;
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
          const Text("Payment Gateways", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text("Razorpay"),
            subtitle: const Text("Enable Razorpay for customer payments"),
            value: _razorpayEnabled,
            onChanged: (val) {
               setState(() => _razorpayEnabled = val);
               _saveSetting('payment_razorpay', val);
            },
          ),
          SwitchListTile(
            title: const Text("UPI"),
            subtitle: const Text("Enable UPI payments"),
            value: _upiEnabled,
            onChanged: (val) {
               setState(() => _upiEnabled = val);
               _saveSetting('payment_upi', val);
            },
          ),
          SwitchListTile(
            title: const Text("Card Payments"),
            subtitle: const Text("Accept Credit/Debit cards"),
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
                  title: const Text("Payment Successful!"),
                  content: const Text("Mock payment gateway: Transaction ID #MOCK123456"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.payment),
            label: const Text("Test Payment (Mock)"),
          ),
        ],
      ),
    );
  }
}
