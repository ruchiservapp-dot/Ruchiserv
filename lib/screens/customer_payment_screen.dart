import 'package:ruchiserv/repositories/finance_repository.dart';
import 'package:flutter/material.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/services/cashfree_payment_service.dart';
import 'package:intl/intl.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:ruchiserv/services/upi_service.dart';

class CustomerPaymentScreen extends StatefulWidget {
  final int orderId;
  final double orderAmount;

  const CustomerPaymentScreen({
    super.key,
    required this.orderId,
    required this.orderAmount,
  });

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  String _selectedMethod = 'UPI';
  late CashfreePaymentService _paymentService;
  bool _isLoading = false;
  Map<String, dynamic>? _orderDetails;
  String? _firmUpiId;
  String? _firmName;

  @override
  void initState() {
    super.initState();
    _paymentService = CashfreePaymentService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentError,
    );
    _loadOrderDetails();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    final db = DatabaseHelper();
    final rows = await (await db.database)
        .query('orders', where: 'id = ?', whereArgs: [widget.orderId]);
    if (rows.isNotEmpty) {
      final order = rows.first;
      setState(() {
        _orderDetails = order;
      });

      // Load Firm Details for UPI
      final firmId = order['firmId'] ?? 'DEFAULT';
      final firm = await db.getFirmDetails(firmId.toString());
      if (firm != null) {
        setState(() {
          _firmUpiId = firm['client_upi_id'];
          _firmName = firm['firmName'];
        });
      }
    }
  }

  void _processPayment() {
    if (_orderDetails == null) return;

    if (_selectedMethod == 'Cash') {
      _recordTransaction(mode: 'Cash');
    } else if (_selectedMethod == 'UPI' &&
        _firmUpiId != null &&
        _firmUpiId!.isNotEmpty) {
      // DIRECT UPI FLOW
      _initiateDirectUpi();
    } else {
      // Cashfree Payment (Mandate/Gateway)
      setState(() => _isLoading = true);
      _paymentService.initiatePayment(
        amount: widget.orderAmount,
        customerEmail: _orderDetails!['email'] ?? 'customer@example.com',
        customerPhone: _orderDetails!['mobile'] ?? '9999999999',
        customerName: _orderDetails!['customerName'] ?? 'Customer',
        description: 'Payment for Order #${widget.orderId}',
      );
    }
  }

  Future<void> _initiateDirectUpi() async {
    final amount = widget.orderAmount;
    final note = 'Payment for Order #${widget.orderId}';
    final firmId = _orderDetails!['firmId']?.toString() ?? 'UNK';
    final txnRef = UPIService.generateTransactionRef(firmId);

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      // Desktop/Web QR
      final qrData = UPIService.generateUpiQrData(
        amount: amount,
        transactionNote: note,
        transactionRef: txnRef,
        customMerchantId: _firmUpiId,
        customMerchantName: _firmName,
      );
      _showQrDialog(txnRef, qrData);
    } else {
      // Mobile Intent
      final success = await UPIService.launchUpiPayment(
        amount: amount,
        transactionNote: note,
        transactionRef: txnRef,
        customMerchantId: _firmUpiId,
        customMerchantName: _firmName,
      );
      if (success) {
        _showVerifyDialog(txnRef);
      } else {
        _handlePaymentError('UPI_LAUNCH_FAILED', 'No UPI apps found');
      }
    }
  }

  void _showQrDialog(String refId, String data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Scan to Pay"),
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
            const Text(
              "1. Scan with any UPI app to pay.\n2. Share screenshot on WhatsApp to verify.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _shareScreenshotAndVerify(refId);
              },
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text("Share Screenshot & Verify"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
        ],
      ),
    );
  }

  void _showVerifyDialog(String refId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: const Text(
            "Please share the payment screenshot on WhatsApp to verify your order."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareScreenshotAndVerify(refId);
            },
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text("Share Screenshot"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _shareScreenshotAndVerify(String refId) async {
    // Launch WhatsApp
    await UPIService.launchWhatsAppForVerification(
      amount: widget.orderAmount,
      orderId: 'ORDER-${widget.orderId}',
      transactionRef: refId,
    );

    // Record as Direct UPI (Pending Verification)
    if (mounted) {
      _recordTransaction(mode: 'Direct UPI', txnRef: refId);
    }
  }

  Future<void> _handlePaymentSuccess(String orderId, String? paymentId) async {
    // Check for QR Link from Cashfree
    if (paymentId != null && paymentId.startsWith("QR_CODE:")) {
      final authLink = paymentId.replaceFirst("QR_CODE:", "");
      _showQrDialog(orderId, authLink);
      return;
    }
    // Cashfree Success
    await _recordTransaction(mode: 'Cashfree', txnRef: paymentId ?? orderId);
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

  Future<void> _recordTransaction(
      {required String mode, String? txnRef}) async {
    try {
      final firmId = _orderDetails?['firmId'] ?? 'DEFAULT';

      await FinanceRepository().insertTransaction({
        'firmId': firmId,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'type': 'INCOME', // Income for the Firm
        'amount': widget.orderAmount,
        'category': 'Order Payment',
        'description':
            'Payment for Order #${widget.orderId} via $mode ${txnRef != null ? '(Ref: $txnRef)' : ''}',
        'mode': mode,
        'paymentMode': mode,
        'relatedEntityType': 'ORDER',
        'relatedEntityId': widget.orderId,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccess();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error recording transaction: $e"),
          backgroundColor: Colors.red));
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).paymentSuccessful),
        content: Text(AppLocalizations.of(context).paymentReceivedMsg(
            widget.orderAmount.toStringAsFixed(2), widget.orderId)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // Return true to refresh parent
            },
            child: Text(AppLocalizations.of(context).done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).collectPayment)),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order #${widget.orderId}",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                if (_orderDetails != null) ...[
                  Text("Customer: ${_orderDetails!['customerName']}"),
                ],
                const SizedBox(height: 8),
                Text("Amount: ₹${widget.orderAmount.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 24,
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context).selectPaymentMethod,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Card(
                  elevation: 2,
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'UPI',
                        groupValue: _selectedMethod,
                        onChanged: (val) =>
                            setState(() => _selectedMethod = val!),
                        title: const Text('UPI (0% fee)'),
                        subtitle: const Text('GPay, PhonePe, Paytm'),
                        secondary: const Icon(Icons.qr_code),
                      ),
                      RadioListTile<String>(
                        value: 'Card',
                        groupValue: _selectedMethod,
                        onChanged: (val) =>
                            setState(() => _selectedMethod = val!),
                        title: const Text('Card'),
                        subtitle: const Text('Credit/Debit Card'),
                        secondary: const Icon(Icons.credit_card),
                      ),
                      RadioListTile<String>(
                        value: 'Cash',
                        groupValue: _selectedMethod,
                        onChanged: (val) =>
                            setState(() => _selectedMethod = val!),
                        title: Text(AppLocalizations.of(context).cash),
                        secondary: const Icon(Icons.money),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _orderDetails == null)
                        ? null
                        : _processPayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                        _isLoading
                            ? "Processing..."
                            : AppLocalizations.of(context).collectPayment,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
