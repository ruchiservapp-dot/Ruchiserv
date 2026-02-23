// lib/services/upi_service.dart
// Direct UPI Intent Service for Subscription Payments
// No payment gateway required - uses native UPI apps

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to launch UPI payment intents
/// Uses the standard UPI deep link format supported by all UPI apps
class UPIService {
  /// Your merchant UPI ID (RuchiServ's receiving account for SaaS subscriptions)
  /// Dummy ID as requested - will be updated later
  static const String merchantUpiId = 'ruchiserv@ybl'; 
  static const String merchantName = 'RuchiServ SaaS';

  /// Get the UPI deep link URL string
  /// Format: upi://pay?pa=<VPA>&pn=<PayeeName>&am=<Amount>&tn=<Note>&tr=<RefID>&cu=<Currency>
  static String getUpiUrl({
    required double amount,
    required String transactionNote,
    required String transactionRef,
    String? customMerchantId,
    String? customMerchantName,
  }) {
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': customMerchantId ?? merchantUpiId,    // Use custom ID if provided (e.g. for Firm-level pay)
        'pn': customMerchantName ?? merchantName,   // Payee Name
        'am': amount.toStringAsFixed(2),            // Amount
        'tn': transactionNote,                       // Transaction Note
        'tr': transactionRef,                        // Transaction Reference
        'cu': 'INR',                                 // Currency
      },
    ).toString();
  }

  /// Launch UPI payment intent
  /// Opens user's UPI app with pre-filled payment details
  static Future<bool> launchUpiPayment({
    required double amount,
    required String transactionNote,
    required String transactionRef,
    String? customMerchantId,
    String? customMerchantName,
  }) async {
    final upiUrlStr = getUpiUrl(
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
      customMerchantId: customMerchantId,
      customMerchantName: customMerchantName,
    );
    final upiUrl = Uri.parse(upiUrlStr);

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

  /// Generate UPI QR Data (Same as Intent URL)
  static String generateUpiQrData({
    required double amount,
    required String transactionNote,
    required String transactionRef,
    String? customMerchantId,
    String? customMerchantName,
  }) {
    return getUpiUrl(
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
      customMerchantId: customMerchantId,
      customMerchantName: customMerchantName,
    );
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
      case 'MONTHLY':
        return 999.0;
      case 'YEARLY':
        return 9999.0;
      default:
        return 999.0;
    }
  }

  /// Get plan duration in days
  static int getPlanDurationDays(String planName) {
    if (planName.toUpperCase() == 'YEARLY') return 365;
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

  /// Launch WhatsApp with a verification message
  static Future<void> launchWhatsAppForVerification({
    required double amount,
    required String orderId,
    String? transactionRef,
  }) async {
    // 1. Build the message
    final message = Uri.encodeComponent(
      "Hi RuchiServ, I have made a payment of ₹$amount for Order/Sub ID: $orderId.\n"
      "Ref: ${transactionRef ?? 'N/A'}\n\n"
      "Here is the payment screenshot attached below:"
    );

    // 2. RuchiServ Support Number (Hardwired for now)
    // TODO: Move to AppConfig if needed
    const supportNumber = "919074067332"; // Replace with actual support number if different

    // 3. Create URL
    final url = "https://wa.me/$supportNumber?text=$message";
    
    // 4. Launch
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch WhatsApp: $url");
    }
  }
}
