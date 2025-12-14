import 'package:flutter/material.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/services/cashfree_payment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class SaaSPaymentScreen extends StatefulWidget {
  const SaaSPaymentScreen({super.key});

  @override
  State<SaaSPaymentScreen> createState() => _SaaSPaymentScreenState();
}

class _SaaSPaymentScreenState extends State<SaaSPaymentScreen> {
  String _selectedPlan = 'Monthly';
  bool _isLoading = false;
  late CashfreePaymentService _paymentService;

  final Map<String, Map<String, dynamic>> _plans = {
    'Monthly': {'price': 999.0, 'duration': '1 Month'},
    'Yearly': {'price': 9999.0, 'duration': '12 Months', 'discount': '17% OFF'},
  };

  @override
  void initState() {
    super.initState();
    _paymentService = CashfreePaymentService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentError,
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _proceedToPayment() async {
    setState(() => _isLoading = true);

    // 1. Get User Info for Pre-fill
    final sp = await SharedPreferences.getInstance();
    final mobile = sp.getString('last_mobile') ?? '9999999999';
    final email = sp.getString('last_email') ?? 'user@example.com'; 
    final name = sp.getString('last_name') ?? 'User';
    
    // 2. Initiate Subscription via Cashfree
    final planName = _selectedPlan;
    _paymentService.initiateSubscription(
      planName: planName,
      amount: _plans[planName]!['price'] as double,
      customerEmail: email,
      customerPhone: mobile,
      customerName: name,
    );
  }

  Future<void> _handlePaymentSuccess(String orderId, String? paymentId) async {
    if (!mounted) return;
    
    try {
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'DEFAULT';
      
      // Calculate new dates
      String currentEndStr = DateTime.now().toIso8601String();
      final firmDetails = await DatabaseHelper().getFirmDetails(firmId);
      if (firmDetails != null && firmDetails['subscriptionEnd'] != null) {
        currentEndStr = firmDetails['subscriptionEnd'];
      }
      
      DateTime currentEnd = DateTime.tryParse(currentEndStr) ?? DateTime.now();
      // If expired, start from now
      if (currentEnd.isBefore(DateTime.now())) {
        currentEnd = DateTime.now();
      }
      
      final newEnd = CashfreePaymentService.calculateNewSubscriptionEndDate(
        currentEndDate: currentEnd,
        planType: _selectedPlan
      );
      
      final newEndStr = DateFormat('yyyy-MM-dd').format(newEnd);
      final txnRef = paymentId ?? orderId;
      
      // Update DB - Subscription
      await DatabaseHelper().updateFirmSubscription(
        firmId: firmId,
        plan: _selectedPlan,
        endDate: newEndStr,
        status: 'Active',
        txnId: txnRef
      );
      
      // Log Transaction (Expense for Firm)
      await DatabaseHelper().insertTransaction({
        'firmId': firmId,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'type': 'EXPENSE',
        'amount': _plans[_selectedPlan]!['price'],
        'category': 'Subscription',
        'description': 'Paid for $_selectedPlan Plan (Txn: $txnRef)',
        'mode': 'UPI',
        'paymentMode': 'Cashfree',
        'relatedEntityType': 'PLATFORM',
        'relatedEntityId': null,
      });

      // Update Local Preferences for immediate Auth check success
      await sp.setString('subscription_expiry', newEndStr);

      setState(() => _isLoading = false);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.subscriptionActivated),
            content: Text(AppLocalizations.of(context)!.planActiveUntil(newEndStr)),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.of(context).pop(); // Close Payment Screen
                },
                child: Text(AppLocalizations.of(context)!.continueBtn),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _handlePaymentError('DB_ERROR', 'Database update failed: $e');
    }
  }

  void _handlePaymentError(String code, String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.paymentFailed(message)), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.chooseSubscription)),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context)!.selectStartPlan,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // UPI Benefits banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('0% UPI Transaction fees', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ..._plans.entries.map((entry) {
                  final plan = entry.key;
                  final details = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: _selectedPlan == plan ? 8 : 2,
                    shape: _selectedPlan == plan 
                        ? RoundedRectangleBorder(side: const BorderSide(color: Colors.indigo, width: 2), borderRadius: BorderRadius.circular(12))
                        : null,
                    child: RadioListTile<String>(
                      value: plan,
                      groupValue: _selectedPlan,
                      onChanged: (val) => setState(() => _selectedPlan = val!),
                      title: Text(plan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("₹${details['price']} / ${details['duration']}"),
                          if (details['discount'] != null)
                            Text(
                              details['discount'],
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _proceedToPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(AppLocalizations.of(context)!.payBtn("₹${_plans[_selectedPlan]!['price']}"), style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
