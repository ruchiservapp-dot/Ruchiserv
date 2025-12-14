import 'package:flutter/material.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/services/cashfree_payment_service.dart';
import 'package:intl/intl.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

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
    final rows = await (await db.database).query('orders', where: 'id = ?', whereArgs: [widget.orderId]);
    if (rows.isNotEmpty) {
      setState(() {
        _orderDetails = rows.first;
      });
    }
  }

  void _processPayment() {
    if (_orderDetails == null) return;

    if (_selectedMethod == 'Cash') {
      _recordTransaction(mode: 'Cash');
    } else {
      // Cashfree Payment
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

  Future<void> _handlePaymentSuccess(String orderId, String? paymentId) async {
    // Cashfree Success
    await _recordTransaction(mode: 'Cashfree', txnRef: paymentId ?? orderId);
  }

  void _handlePaymentError(String code, String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.paymentFailed(message)), backgroundColor: Colors.red),
    );
  }

  Future<void> _recordTransaction({required String mode, String? txnRef}) async {
    try {
      final firmId = _orderDetails?['firmId'] ?? 'DEFAULT';
      
      await DatabaseHelper().insertTransaction({
        'firmId': firmId,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'type': 'INCOME', // Income for the Firm
        'amount': widget.orderAmount,
        'category': 'Order Payment',
        'description': 'Payment for Order #${widget.orderId} via $mode ${txnRef != null ? '(Ref: $txnRef)' : ''}',
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
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Error recording transaction: $e"), backgroundColor: Colors.red)
      );
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.paymentSuccessful),
        content: Text(AppLocalizations.of(context)!.paymentReceivedMsg(widget.orderAmount.toStringAsFixed(2), widget.orderId)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // Return true to refresh parent
            },
            child: Text(AppLocalizations.of(context)!.done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.collectPayment)),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order #${widget.orderId}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_orderDetails != null) ...[
                  Text("Customer: ${_orderDetails!['customerName']}"),
                ],
                const SizedBox(height: 8),
                Text("Amount: ₹${widget.orderAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                Text(AppLocalizations.of(context)!.selectPaymentMethod, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                Card(
                  elevation: 2,
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'UPI',
                        groupValue: _selectedMethod,
                        onChanged: (val) => setState(() => _selectedMethod = val!),
                        title: const Text('UPI (0% fee)'),
                        subtitle: const Text('GPay, PhonePe, Paytm'),
                        secondary: const Icon(Icons.qr_code),
                      ),
                      RadioListTile<String>(
                        value: 'Card',
                        groupValue: _selectedMethod,
                        onChanged: (val) => setState(() => _selectedMethod = val!),
                        title: const Text('Card'),
                        subtitle: const Text('Credit/Debit Card'),
                        secondary: const Icon(Icons.credit_card),
                      ),
                      RadioListTile<String>(
                        value: 'Cash',
                        groupValue: _selectedMethod,
                        onChanged: (val) => setState(() => _selectedMethod = val!),
                        title: Text(AppLocalizations.of(context)!.cash),
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
                    onPressed: (_isLoading || _orderDetails == null) ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isLoading ? "Processing..." : AppLocalizations.of(context)!.collectPayment, style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
             Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
