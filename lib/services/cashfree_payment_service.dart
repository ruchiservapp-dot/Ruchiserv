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
import '../db/aws/aws_api.dart';

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
      final response = await AwsApi.post(
        path: 'dbhandler',
        body: {
          'payment_type': 'ORDER',
          'amount': amount,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'customerName': customerName,
          'orderNote': orderNote,
        },
      );
      
      if (response['order_id'] != null) {
        return {
          'order_id': response['order_id'] ?? '',
          'payment_session_id': response['payment_session_id'] ?? '',
        };
      }
      return null;
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
          // .setNavigationBarBackgroundColor("#0D47A1") // Method not found in this SDK version
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
      final response = await AwsApi.post(
        path: 'dbhandler',
        body: {
          'payment_type': 'SUBSCRIPTION',
          'plan_id': planName,
          'amount': amount,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'customerName': customerName,
        },
      );
      
      if (response['subscriptionId'] != null || response['subscription_id'] != null) {
        return {
          'subscription_id': (response['subscriptionId'] ?? response['subscription_id'] ?? '').toString(),
          'order_id': (response['order_id'] ?? '').toString(),
          'payment_session_id': (response['payment_session_id'] ?? '').toString(),
        };
      }
      return null;
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
  
  /// Trigger a mandate update session
  Future<void> updateMandate(String subscriptionId) async {
    try {
      final response = await AwsApi.post(
        path: 'dbhandler',
        body: {
          'payment_type': 'MANDATE_UPDATE',
          'subscription_id': subscriptionId,
        },
      );
      
      if (response['payment_session_id'] != null) {
        await openCheckout(
          orderId: (response['order_id'] ?? 'update_$subscriptionId').toString(),
          paymentSessionId: response['payment_session_id']!.toString(),
          description: 'Update UPI Mandate',
        );
      }
 else {
        onFailure('UPDATE_ERROR', 'Failed to trigger mandate update');
      }
    } catch (e) {
      onFailure('UPDATE_ERROR', e.toString());
    }
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
