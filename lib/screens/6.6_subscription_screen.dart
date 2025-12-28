import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../db/database_helper.dart';
import '../services/upi_service.dart';
import '../services/permission_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  String _currentPlan = 'Free Trial';
  String _expiryDate = '';
  int _daysRemaining = 0;
  String _userRole = 'Staff';
  String? _firmId;
  String? _clientUpiId;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    setState(() => _isLoading = true);
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');
    final role = await PermissionService.instance.getUserRole();
    
    _firmId = firmId;
    _userRole = role;
    
    // Load subscription details from database
    if (firmId != null) {
      final firmData = await DatabaseHelper().getFirmDetails(firmId);
      if (firmData != null) {
        final planName = firmData['subscription_plan']?.toString() ?? 'Free Trial';
        final endDateStr = firmData['subscription_end_date']?.toString();
        _clientUpiId = firmData['client_upi_id']?.toString();
        
        setState(() {
          _currentPlan = planName;
          if (endDateStr != null && endDateStr.isNotEmpty) {
            final expiry = DateTime.parse(endDateStr);
            _expiryDate = endDateStr.substring(0, 10);
            _daysRemaining = expiry.difference(DateTime.now()).inDays;
          } else {
            _expiryDate = 'Not Set';
            _daysRemaining = 0;
          }
          _isLoading = false;
        });
        return;
      }
    }
    
    // Fallback to SharedPreferences (legacy)
    final expiryStr = sp.getString('subscription_expiry');
    setState(() {
      _currentPlan = 'Free Trial';
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        _expiryDate = expiryStr.substring(0, 10);
        _daysRemaining = expiry.difference(DateTime.now()).inDays;
      } else {
        _expiryDate = 'Not Set';
        _daysRemaining = 0;
      }
      _isLoading = false;
    });
  }

  bool get _isAdmin => _userRole.toLowerCase() == 'admin';

  Future<void> _handleUpgrade(String planName, double amount) async {
    // Check if UPI ID is set
    if (_clientUpiId == null || _clientUpiId!.isEmpty) {
      _showUpiIdMissingDialog();
      return;
    }

    // Show payment dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UPIPaymentDialog(
        planName: planName,
        amount: amount,
        clientUpiId: _clientUpiId!,
        firmId: _firmId ?? 'UNKNOWN',
      ),
    );

    if (confirmed == true) {
      // Reload subscription data
      await _loadSubscription();
    }
  }

  void _showUpiIdMissingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UPI ID Required'),
        content: const Text(
          'Please set your UPI ID in Firm Profile before subscribing.\n\n'
          'Go to: Settings → Firm Profile → Subscription Settings',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscription Management"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Plan Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade800, Colors.blue.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Current Plan",
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentPlan,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Expires On", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text(_expiryDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _daysRemaining <= 5 ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _daysRemaining > 0 ? "$_daysRemaining Days Left" : "Expired",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Admin-only notice
                  if (!_isAdmin) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Only Admins can upgrade the subscription plan.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  const Text("Available Plans", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  _buildPlanCard(
                    title: "Basic",
                    price: "₹999 / month",
                    amount: 999.0,
                    features: ["Up to 5 Users", "Basic Reports", "Inventory Management"],
                    isCurrent: _currentPlan.toLowerCase() == 'basic',
                    color: Colors.orange,
                  ),
                  _buildPlanCard(
                    title: "Pro",
                    price: "₹2499 / month",
                    amount: 2499.0,
                    features: ["Unlimited Users", "Advanced Analytics", "Priority Support", "Multi-branch"],
                    isCurrent: _currentPlan.toLowerCase() == 'pro',
                    color: Colors.purple,
                  ),
                  _buildPlanCard(
                    title: "Enterprise",
                    price: "₹4999 / month",
                    amount: 4999.0,
                    features: ["Dedicated Server", "Custom Integrations", "24/7 Support"],
                    isCurrent: _currentPlan.toLowerCase() == 'enterprise',
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required double amount,
    required List<String> features,
    required bool isCurrent,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 24),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(f),
                ],
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAdmin ? () => _handleUpgrade(title, amount) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(_isAdmin ? (isCurrent ? "Renew Plan" : "Upgrade Now") : "Admin Only"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for handling UPI Payment flow
class _UPIPaymentDialog extends StatefulWidget {
  final String planName;
  final double amount;
  final String clientUpiId;
  final String firmId;

  const _UPIPaymentDialog({
    required this.planName,
    required this.amount,
    required this.clientUpiId,
    required this.firmId,
  });

  @override
  State<_UPIPaymentDialog> createState() => _UPIPaymentDialogState();
}

class _UPIPaymentDialogState extends State<_UPIPaymentDialog> {
  final _utrController = TextEditingController();
  int _step = 1; // 1: Confirm, 2: Enter UTR, 3: Success
  String? _transactionRef;
  bool _isProcessing = false;

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  Future<void> _launchUpiPayment() async {
    setState(() => _isProcessing = true);
    
    _transactionRef = UPIService.generateTransactionRef(widget.firmId);
    
    final launched = await UPIService.launchUpiPayment(
      amount: widget.amount,
      transactionNote: 'RuchiServ ${widget.planName} Plan',
      transactionRef: _transactionRef!,
    );
    
    setState(() => _isProcessing = false);
    
    if (launched) {
      // Move to UTR entry step
      setState(() => _step = 2);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No UPI app found. Please install GPay, PhonePe, or Paytm.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitPayment() async {
    final utr = _utrController.text.trim();
    if (utr.isEmpty || utr.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid UTR number'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      // Calculate new end date
      final newEndDate = UPIService.calculateNewEndDate(null, widget.planName);
      
      // Update local database
      await DatabaseHelper().updateFirmDetails(widget.firmId, {
        'subscription_plan': widget.planName,
        'subscription_end_date': newEndDate.toIso8601String(),
      });
      
      // TODO: Send payment details to AWS for verification
      // await SubscriptionService().submitPaymentDetails(
      //   firmId: widget.firmId,
      //   utr: utr,
      //   amount: widget.amount,
      //   planName: widget.planName,
      //   transactionRef: _transactionRef,
      // );
      
      setState(() {
        _step = 3; // Success
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_step == 3 ? '✅ Payment Successful' : 'Subscribe to ${widget.planName}'),
      content: SizedBox(
        width: 300,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_step == 1) {
      // Confirm step
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount: ₹${widget.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('You will be redirected to your UPI app to complete the payment.'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your UPI ID', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(widget.clientUpiId, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_step == 2) {
      // UTR entry step
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment completed? Enter the UTR/Reference number from your UPI app:'),
          const SizedBox(height: 16),
          TextField(
            controller: _utrController,
            decoration: const InputDecoration(
              labelText: 'UTR / Reference Number',
              hintText: 'e.g., 123456789012',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.receipt_long),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Text(
            'You can find this in your UPI app under transaction history.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    } else {
      // Success step
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text('Your ${widget.planName} plan is now active!', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Payment will be verified within 24 hours.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  List<Widget> _buildActions() {
    if (_step == 1) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _launchUpiPayment,
          child: _isProcessing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Pay Now'),
        ),
      ];
    } else if (_step == 2) {
      return [
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _submitPayment,
          child: _isProcessing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ];
    } else {
      return [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Done'),
        ),
      ];
    }
  }
}
