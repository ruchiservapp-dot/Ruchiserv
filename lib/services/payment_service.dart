import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../secrets.dart'; 

class PaymentService {
  late Razorpay _razorpay;
  final Function(String paymentId, String? orderId, String? signature) onSuccess;
  final Function(String errorCode, String message) onFailure;

  PaymentService({
    required this.onSuccess,
    required this.onFailure,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  void openCheckout({
    required double amount, // In Rupees
    required String description,
    required String mobile,
    required String email,
    String? orderId, // Razorpay Order ID (optional for now, mandatory for prod)
    bool isRecurring = false, // Subscription
    String? subscriptionId, // If recurring
  }) {
    var options = {
      'key': razorpayKeyId,
      'amount': (amount * 100).toInt(), // Paire
      'name': 'RuchiServ',
      'description': description,
      'prefill': {'contact': mobile, 'email': email},
      'external': {
        'wallets': ['paytm']
      }
    };

    if (isRecurring && subscriptionId != null) {
       options['subscription_id'] = subscriptionId;
       // For subscriptions, amount isn't passed usually in checkout options if plan is fixed, 
       // but for auth transaction it might be. 
       // Razorpay docs say for subscription, pass 'subscription_id' and remove 'amount' if not upfront.
       options.remove('amount'); 
    }
    
    // If we have a backend generated orderId
    if (orderId != null) {
      options['order_id'] = orderId;
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      onFailure('INIT_ERROR', 'Error initializing payment: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // print('Payment Success: ${response.paymentId}');
    onSuccess(
      response.paymentId ?? '',
      response.orderId,
      response.signature
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // print('Payment Error: ${response.code} - ${response.message}');
    onFailure(
      response.code.toString(),
      response.message ?? 'Unknown Error'
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // print('External Wallet: ${response.walletName}');
    // Usually treated as success or pending, but for simplicity we rely on success callback
    // or handle it if needed.
  }
  
  // --- CLIENT-SIDE SUBSCRIPTION MOCK ---
  /// Since we don't have a backend to create Plans/Subscriptions via API,
  /// we simulate it here to allow testing the UI flow.
  /// In Production, this MUST be done on server side.
  Future<String> mockCreateSubscription(String planName) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    // Return a fake subscription ID. 
    // REALITY CHECK: Passing a fake ID to Razorpay SDK will likely cause an "Invalid Subscription ID" error 
    // unless used with Test Key and maybe strict format.
    // However, without a real backend ID, we cannot open the *real* subscription flow.
    // So if this fails, users must know it's due to missing backend.
    return 'sub_mock_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Helper to calculate new end date
  static DateTime calculateNewSubscriptionEndDate({
    required DateTime currentEndDate,
    required String planType, // 'Monthly', 'Yearly'
  }) {
    DateTime base = currentEndDate.isAfter(DateTime.now()) ? currentEndDate : DateTime.now();
    if (planType == 'Monthly') {
      return DateTime(base.year, base.month + 1, base.day);
    } else if (planType == 'Yearly') {
      return DateTime(base.year + 1, base.month, base.day);
    }
    return base.add(const Duration(days: 30));
  }
}
