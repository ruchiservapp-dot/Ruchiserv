// lib/services/cashfree_payment_service.dart
// Cashfree Payment Gateway Integration for RuchiServ
// Replacing Razorpay with Cashfree for 0% UPI fees

import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

/// Cashfree Payment Service for handling one-time and subscription payments
class CashfreePaymentService {
  final CFPaymentGatewayService _paymentGateway = CFPaymentGatewayService();
  
  // Callbacks
  final Function(String orderId, String? paymentId) onSuccess;
  final Function(String errorCode, String message) onFailure;

  CashfreePaymentService({
    required this.onSuccess,
    required this.onFailure,
  }) {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _paymentGateway.setCallback(
      (orderId) {
        // Payment successful
        onSuccess(orderId, null);
      },
      (error, orderId) {
        // Payment failed
        onFailure(
          error.getCode()?.toString() ?? 'UNKNOWN',
          error.getMessage() ?? 'Payment failed',
        );
      },
    );
  }

  void dispose() {
    // Cleanup if needed
  }

  /// Get the current environment based on sandbox mode setting
  CFEnvironment get _environment => 
      AppConfig.cashfreeSandbox ? CFEnvironment.SANDBOX : CFEnvironment.PRODUCTION;

  /// Create a payment session on backend (MOCK for now)
  /// In production, this should call your backend API which creates order via Cashfree API
  Future<Map<String, String>?> createPaymentSession({
    required double amount,
    required String customerEmail,
    required String customerPhone,
    required String customerName,
    String? orderNote,
  }) async {
    try {
      // MOCK: In production, call your backend API
      // Your backend should:
      // 1. Call Cashfree's Create Order API
      // 2. Return the order_id and payment_session_id
      
      // For now, return mock data for testing UI flow
      // This will NOT work for actual payments without a real backend
      final mockOrderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
      
      // In production, your backend returns this
      return {
        'order_id': mockOrderId,
        'payment_session_id': 'session_mock_${DateTime.now().millisecondsSinceEpoch}',
      };
      
      /* PRODUCTION CODE - Uncomment when backend is ready
      final response = await http.post(
        Uri.parse('YOUR_BACKEND_URL/payments/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'customerName': customerName,
          'orderNote': orderNote,
        }),
      );
      
      if (response.statusCode == 200) {
        return Map<String, String>.from(jsonDecode(response.body));
      }
      return null;
      */
    } catch (e) {
      debugPrint('Error creating payment session: $e');
      return null;
    }
  }

  /// Open Cashfree checkout for payment
  Future<void> openCheckout({
    required String orderId,
    required String paymentSessionId,
    double? amount, // For display purposes
    String? description,
  }) async {
    try {
      // Create session
      var session = CFSessionBuilder()
          .setEnvironment(_environment)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      // Configure theme
      var theme = CFThemeBuilder()
          .setNavigationBarBackgroundColor("#0D47A1")
          .setNavigationBarTextColor("#FFFFFF")
          .setButtonBackgroundColor("#0D47A1")
          .setButtonTextColor("#FFFFFF")
          .setPrimaryTextColor("#000000")
          .setSecondaryTextColor("#666666")
          .build();

      // Build checkout payment
      var dropPayment = CFDropCheckoutPaymentBuilder()
          .setSession(session)
          .setTheme(theme)
          .build();

      // Start payment
      _paymentGateway.doPayment(dropPayment);
    } on CFException catch (e) {
      onFailure('SDK_ERROR', e.message);
    } catch (e) {
      onFailure('INIT_ERROR', 'Error initializing payment: $e');
    }
  }

  /// Initiate a one-time payment (for customer order payments)
  Future<void> initiatePayment({
    required double amount,
    required String customerEmail,
    required String customerPhone,
    required String customerName,
    String? description,
  }) async {
    // Create payment session
    final session = await createPaymentSession(
      amount: amount,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      customerName: customerName,
      orderNote: description,
    );

    if (session == null) {
      onFailure('SESSION_ERROR', 'Could not create payment session');
      return;
    }

    // Open checkout
    await openCheckout(
      orderId: session['order_id']!,
      paymentSessionId: session['payment_session_id']!,
      amount: amount,
      description: description,
    );
  }

  /// Create subscription for recurring payments (SaaS)
  /// In production, call your backend which uses Cashfree Subscriptions API
  Future<Map<String, String>?> createSubscription({
    required String planName,
    required double amount,
    required String customerEmail,
    required String customerPhone,
    required String customerName,
  }) async {
    try {
      // MOCK: In production, call your backend API for Cashfree Subscriptions
      final mockSubId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
      
      return {
        'subscription_id': mockSubId,
        'order_id': 'order_$mockSubId',
        'payment_session_id': 'session_$mockSubId',
      };
      
      /* PRODUCTION CODE - Your backend should:
      1. Create a Subscription Plan if not exists
      2. Create a Subscription for the customer
      3. Return the authorization link or session
      
      final response = await http.post(
        Uri.parse('YOUR_BACKEND_URL/subscriptions/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'planName': planName,
          'amount': amount,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'customerName': customerName,
        }),
      );
      
      if (response.statusCode == 200) {
        return Map<String, String>.from(jsonDecode(response.body));
      }
      return null;
      */
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      return null;
    }
  }

  /// Initiate subscription payment
  Future<void> initiateSubscription({
    required String planName,
    required double amount,
    required String customerEmail,
    required String customerPhone,
    required String customerName,
  }) async {
    final sub = await createSubscription(
      planName: planName,
      amount: amount,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      customerName: customerName,
    );

    if (sub == null) {
      onFailure('SUB_ERROR', 'Could not create subscription');
      return;
    }

    await openCheckout(
      orderId: sub['order_id']!,
      paymentSessionId: sub['payment_session_id']!,
      amount: amount,
      description: 'Subscription: $planName Plan',
    );
  }

  /// Helper to calculate new end date for subscription
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
