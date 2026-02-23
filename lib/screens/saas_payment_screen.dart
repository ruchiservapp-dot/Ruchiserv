import 'package:ruchiserv/core/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/services/cashfree_payment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:ruchiserv/services/upi_service.dart';
import 'package:ruchiserv/services/subscription_service.dart';

class SaaSPaymentScreen extends StatefulWidget {
  const SaaSPaymentScreen({super.key});

  @override
  State<SaaSPaymentScreen> createState() => _SaaSPaymentScreenState();
}

class _SaaSPaymentScreenState extends State<SaaSPaymentScreen> {
  String _selectedPlan = 'Monthly';
  String _selectedMethod = 'Mandate'; // 'Mandate' or 'Direct'
  bool _isLoading = false;
  late CashfreePaymentService _paymentService;
  String? _currentSubscriptionId;
  String? _currentExpiry;

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
    _checkCurrentSubscription();
  }

  Future<void> _checkCurrentSubscription() async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'DEFAULT';
    final firmDetails = await DatabaseHelper().getFirmDetails(firmId);

    if (firmDetails != null) {
      setState(() {
        _currentSubscriptionId =
            firmDetails['txnId']; // Using txnId as a fallback for subId
        _currentExpiry = firmDetails['subscriptionEnd'];
      });
    }
  }

  Future<void> _updateMandate() async {
    if (_currentSubscriptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("No active subscription found to update.")),
      );
      return;
    }
    setState(() => _isLoading = true);
    await _paymentService.updateMandate(_currentSubscriptionId!);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _proceedToPayment() async {
    AppLogger.info(
        'SaaSPayment: Proceeding to payment via $_selectedMethod...');
    setState(() => _isLoading = true);

    final sp = await SharedPreferences.getInstance();
    final mobile = sp.getString('last_mobile') ?? '9999999999';
    final email = sp.getString('last_email') ?? 'user@example.com';
    final name = sp.getString('last_name') ?? 'User';
    final amount = _plans[_selectedPlan]!['price'] as double;

    if (_selectedMethod == 'Direct') {
      // DIRECT UPI FLOW
      final firmId = sp.getString('last_firm') ?? 'UNK';
      final txnRef = UPIService.generateTransactionRef(firmId);
      final note = 'SaaS Subscription: $_selectedPlan';

      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        // Desktop/Web QR
        final qrData = UPIService.generateUpiQrData(
            amount: amount, transactionNote: note, transactionRef: txnRef);
        _showQrDialog(txnRef, qrData, isDirect: true);
      } else {
        // Mobile Intent
        final success = await UPIService.launchUpiPayment(
            amount: amount, transactionNote: note, transactionRef: txnRef);
        if (success) {
          _showVerifySelection(txnRef);
        } else {
          _handlePaymentError('UPI_LAUNCH_ERROR', 'Could not open UPI apps');
        }
      }
      return;
    }

    // MANDATE FLOW (CASHFREE)
    _paymentService.initiateSubscription(
      planName: _selectedPlan,
      amount: amount,
      customerEmail: email,
      customerPhone: mobile,
      customerName: name,
    );
  }

  void _showVerifySelection(String refId) {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: const Text(
            "If you have completed the payment in your UPI app, click verify to activate your subscription."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _verifyAndActivate(refId);
              },
              child: const Text("Verify Payment")),
        ],
      ),
    );
  }

  void _showQrDialog(String refId, String data, {bool isDirect = false}) {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isDirect ? "Scan to Pay (Direct UPI)" : "Scan to Pay"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isDirect
                  ? "Scan and pay using any UPI app. Subscription will activate after verification."
                  : "Scan this QR code with any UPI app to setup your auto-pay subscription.",
              textAlign: TextAlign.center,
            ),
            if (!isDirect && data.startsWith('http'))
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(data);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text("Open Payment Link"),
              ),
            if (isDirect) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "After payment, please share the screenshot on WhatsApp to verify.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _submitManualVerification(refId),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text("Share Screenshot & Verify"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          if (!isDirect) // Only show standard verify for Gateway/Mandate
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _verifyAndActivate(refId);
              },
              child: const Text("Verify Payment"),
            ),
        ],
      ),
    );
  }

  Future<void> _submitManualVerification(String refId) async {
    Navigator.pop(context); // Close QR Dialog
    setState(() => _isLoading = true);

    try {
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'UNK';

      // 1. Grant Local Extension (7 Days)
      await SubscriptionService().grantManualExtension(firmId);

      // 2. Launch WhatsApp
      final amount = _plans[_selectedPlan]!['price'] as double;
      await UPIService.launchWhatsAppForVerification(
          amount: amount,
          orderId: _currentSubscriptionId ?? 'NEW_SUB',
          transactionRef: refId);

      setState(() => _isLoading = false);

      // 3. Show Success Dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Verification Pending"),
            content: const Text(
              "Your subscription has been extended by 7 days while we verify your payment.\n\n"
              "Please ensure you have sent the screenshot on WhatsApp.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close Dialog
                  Navigator.pop(context); // Close Screen
                },
                child: const Text("Continue"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _handlePaymentError('MANUAL_VERIFY_ERROR', 'Error: $e');
    }
  }

  Future<void> _handlePaymentSuccess(String orderId, String? paymentId) async {
    if (!mounted) return;

    // Check if this is a Web/Desktop flow start (QR Code)
    if (paymentId != null && paymentId.startsWith("QR_CODE:")) {
      final authLink = paymentId.replaceFirst("QR_CODE:", "");
      _showQrDialog(orderId, authLink);
      return;
    }

    // Mobile SDK Flow (Immediate Success)
    await _verifyAndActivate(orderId);
  }

  Future<void> _verifyAndActivate(String refId) async {
    setState(() => _isLoading = true);

    // Verify with Backend
    final isValid = await _paymentService.verifySubscription(refId);

    if (!isValid) {
      _handlePaymentError('VERIFY_FAILED',
          'Payment verification failed. If payment was successful, please wait 2 minutes or contact support.');
      return;
    }

    try {
      final sp = await SharedPreferences.getInstance();

      // Calculate new date for UI display
      String currentEndStr = DateTime.now().toIso8601String();
      if (_currentExpiry != null) {
        currentEndStr = _currentExpiry!;
      }

      DateTime currentEnd = DateTime.tryParse(currentEndStr) ?? DateTime.now();
      if (currentEnd.isBefore(DateTime.now())) {
        currentEnd = DateTime.now();
      }

      final newEndArr = CashfreePaymentService.calculateNewSubscriptionEndDate(
          currentEndDate: currentEnd, planType: _selectedPlan);
      final newEnd = newEndArr;
      final newEndStr = DateFormat('yyyy-MM-dd').format(newEnd);

      // Update Local Preferences for immediate Auth check success
      await sp.setString('subscription_expiry', newEndStr);

      setState(() => _isLoading = false);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).subscriptionActivated),
            content:
                Text(AppLocalizations.of(context).planActiveUntil(newEndStr)),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.of(context).pop(); // Close Payment Screen
                },
                child: Text(AppLocalizations.of(context).continueBtn),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _handlePaymentError('UI_ERROR', 'Error updating UI: $e');
    }
  }

  void _handlePaymentError(String code, String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context).paymentFailed(message)),
          backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseSubscription)),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    l10n.selectStartPlan,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                // Plans
                ..._plans.entries.map((entry) {
                  final plan = entry.key;
                  final details = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: _selectedPlan == plan ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _selectedPlan == plan
                            ? Colors.indigo
                            : Colors.grey.shade300,
                        width: _selectedPlan == plan ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: plan,
                      groupValue: _selectedPlan,
                      onChanged: (val) => setState(() => _selectedPlan = val!),
                      title: Text(plan,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle:
                          Text("₹${details['price']} / ${details['duration']}"),
                      secondary: details['discount'] != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(details['discount'],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            )
                          : null,
                    ),
                  );
                }),

                const SizedBox(height: 24),
                const Text("Payment Method",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300)),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'Mandate',
                        groupValue: _selectedMethod,
                        onChanged: (val) =>
                            setState(() => _selectedMethod = val!),
                        title: const Text("UPI Auto-Pay (Recommended)",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            "Automatic monthly renewal using UPI Mandate."),
                        secondary: const Icon(Icons.sync, color: Colors.indigo),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        value: 'Direct',
                        groupValue: _selectedMethod,
                        onChanged: (val) =>
                            setState(() => _selectedMethod = val!),
                        title: const Text("One-time UPI Payment"),
                        subtitle: const Text(
                            "Direct payment via GPay, PhonePe, etc. Manual renewal."),
                        secondary: const Icon(Icons.account_balance_wallet,
                            color: Colors.indigo),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                if (_currentExpiry != null) ...[
                  Center(
                    child: Text(
                      "Current Plan active until $_currentExpiry",
                      style: const TextStyle(
                          color: Colors.indigo, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _proceedToPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _selectedMethod == 'Mandate'
                          ? "ENABLE AUTO-PAY (₹${_plans[_selectedPlan]!['price']})"
                          : "PAY ₹${_plans[_selectedPlan]!['price']} NOW",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
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
