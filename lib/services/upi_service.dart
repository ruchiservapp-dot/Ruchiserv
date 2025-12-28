// lib/services/upi_service.dart
// Direct UPI Intent Service for Subscription Payments
// No payment gateway required - uses native UPI apps

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to launch UPI payment intents
/// Uses the standard UPI deep link format supported by all UPI apps
class UPIService {
  /// Your merchant UPI ID (RuchiServ's receiving account)
  /// TODO: Update this with your actual UPI ID for receiving payments
  static const String merchantUpiId = 'ruchiserv@ybl'; // Replace with your VPA
  static const String merchantName = 'RuchiServ Events';

  /// Launch UPI payment intent
  /// Opens user's UPI app with pre-filled payment details
  /// 
  /// Parameters:
  /// - [amount]: Amount in INR
  /// - [transactionNote]: Description shown in UPI app
  /// - [transactionRef]: Unique reference ID for tracking
  /// 
  /// Returns true if UPI app was launched successfully
  static Future<bool> launchUpiPayment({
    required double amount,
    required String transactionNote,
    required String transactionRef,
  }) async {
    // Build UPI URL
    // Format: upi://pay?pa=<VPA>&pn=<PayeeName>&am=<Amount>&tn=<Note>&tr=<RefID>&cu=<Currency>
    final upiUrl = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': merchantUpiId,          // Payee VPA (receiving UPI ID)
        'pn': merchantName,           // Payee Name
        'am': amount.toStringAsFixed(2), // Amount
        'tn': transactionNote,        // Transaction Note
        'tr': transactionRef,         // Transaction Reference
        'cu': 'INR',                  // Currency
      },
    );

    try {
      // Try to launch UPI app
      if (await canLaunchUrl(upiUrl)) {
        return await launchUrl(
          upiUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('No UPI app found on device');
        return false;
      }
    } catch (e) {
      debugPrint('Error launching UPI: $e');
      return false;
    }
  }

  /// Generate a unique transaction reference
  /// Format: RS-<FirmID>-<Timestamp>
  static String generateTransactionRef(String firmId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Shorten firmId to 8 chars max for cleaner ref
    final shortFirm = firmId.length > 8 ? firmId.substring(0, 8) : firmId;
    return 'RS-$shortFirm-$timestamp';
  }

  /// Calculate subscription amount based on plan
  static double getPlanAmount(String planName) {
    switch (planName.toUpperCase()) {
      case 'BASIC':
        return 999.0;
      case 'PRO':
        return 2499.0;
      case 'ENTERPRISE':
        return 4999.0;
      default:
        return 999.0;
    }
  }

  /// Get plan duration in days
  static int getPlanDurationDays(String planName) {
    // All plans are monthly for now
    return 30;
  }

  /// Calculate new subscription end date
  static DateTime calculateNewEndDate(DateTime? currentEndDate, String planName) {
    final now = DateTime.now();
    final base = (currentEndDate != null && currentEndDate.isAfter(now)) 
        ? currentEndDate 
        : now;
    
    return base.add(Duration(days: getPlanDurationDays(planName)));
  }
}
