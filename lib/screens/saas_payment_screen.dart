import 'package:flutter/material.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/services/payment_service.dart';
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
  late PaymentService _paymentService;

  final Map<String, Map<String, dynamic>> _plans = {
    'Monthly': {'price': 999.0, 'duration': '1 Month'},
    'Yearly': {'price': 9999.0, 'duration': '12 Months', 'discount': '17% OFF'},
  };

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService(
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
    
    // 2. Mock Create Subscription (Backend Simulation)
    final planName = _selectedPlan;
    final subID = await _paymentService.mockCreateSubscription(planName);

    // 3. Open Checkout
    _paymentService.openCheckout(
      amount: _plans[planName]!['price'] as double,
      description: 'Subscription for $planName Plan',
      mobile: mobile,
      email: email,
      isRecurring: true,
      subscriptionId: subID,
    );
    
    // Loading state remains true until callback (or we can set false if sync, but Razorpay is async UI)
    // Actually, Razorpay opens an activity/overlay. We can reset loading now or keep it until success/failure.
    // Keeping it true might block UI behind the overlay which is fine.
  }

  Future<void> _handlePaymentSuccess(String paymentId, String? orderId, String? signature) async {
    if (!mounted) return;
    
    try {
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'DEFAULT';
      
      // Calculate new dates
      // For now, assume current expiry is NOW if not found, or fetch from DB.
      // Ideally fetch current expiry from DB to extend it.
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
      
      final newEnd = PaymentService.calculateNewSubscriptionEndDate(
        currentEndDate: currentEnd,
        planType: _selectedPlan
      );
      
      final newEndStr = DateFormat('yyyy-MM-dd').format(newEnd);
      
      // Update DB - Subscription
      await DatabaseHelper().updateFirmSubscription(
        firmId: firmId,
        plan: _selectedPlan,
        endDate: newEndStr, // Store as yyyy-MM-dd for consistency with Auth check
        status: 'Active',
        txnId: paymentId
      );
      
      // Log Transaction (Expense for Firm)
      await DatabaseHelper().insertTransaction({
        'firmId': firmId,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'type': 'EXPENSE',
        'amount': _plans[_selectedPlan]!['price'],
        'category': 'Subscription',
        'description': 'Paid for $_selectedPlan Plan (Txn: $paymentId)',
        'mode': 'UPI', // Assuming Razorpay UPI for now
        'paymentMode': 'Razorpay',
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
