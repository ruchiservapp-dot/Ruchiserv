// lib/services/subscription_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';

/// Enforces F.1 Subscription Gate Mandate
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  /// Check subscription status for a firm
  /// Returns: 'active', 'grace_period', or 'locked'
  Future<String> checkSubscriptionStatus(String firmId) async {
    final db = DatabaseHelper();
    final firms = await db.database.then((d) => d.query(
          'firms',
          where: 'firmId = ?',
          whereArgs: [firmId],
          limit: 1,
        ));

    if (firms.isEmpty) return 'locked'; // Unknown firm -> Lock

    final firm = firms.first;
    final expiryStr = firm['subscriptionExpiry'] as String?;
    final graceEndStr = firm['gracePeriodEnd'] as String?;

    if (expiryStr == null)
      return 'active'; // No expiry set (e.g. free tier or new)

    final now = DateTime.now();
    final expiry = DateTime.parse(expiryStr);

    // Active: Not yet expired
    if (now.isBefore(expiry)) {
      return 'active';
    }

    // Grace Period: Expired but within grace window (default 5 days)
    // If gracePeriodEnd is set in DB, use it. Otherwise calculate 5 days from expiry.
    final graceEnd = graceEndStr != null
        ? DateTime.parse(graceEndStr)
        : expiry.add(const Duration(days: 5));

    if (now.isBefore(graceEnd)) {
      return 'grace_period';
    }

    // Locked: Expired and past grace period
    return 'locked';
  }

  /// Get days remaining until expiry (or negative if expired)
  Future<int?> getDaysRemaining(String firmId) async {
    final db = DatabaseHelper();
    final firms = await db.database.then((d) => d.query(
          'firms',
          where: 'firmId = ?',
          whereArgs: [firmId],
          limit: 1,
        ));

    if (firms.isEmpty) return null;

    final expiryStr = firms.first['subscriptionExpiry'] as String?;
    if (expiryStr == null) return null;

    final expiry = DateTime.parse(expiryStr);
    return expiry.difference(DateTime.now()).inDays;
  }

  /// Get days remaining in grace period
  Future<int> getGraceDaysRemaining(String firmId) async {
    final db = DatabaseHelper();
    final firms = await db.database.then((d) => d.query(
          'firms',
          where: 'firmId = ?',
          whereArgs: [firmId],
          limit: 1,
        ));

    if (firms.isEmpty) return 0;

    final firm = firms.first;
    final expiryStr = firm['subscriptionExpiry'] as String?;
    final graceEndStr = firm['gracePeriodEnd'] as String?;

    if (expiryStr == null) return 0;

    final expiry = DateTime.parse(expiryStr);
    final graceEnd = graceEndStr != null
        ? DateTime.parse(graceEndStr)
        : expiry.add(const Duration(days: 5));

    return graceEnd.difference(DateTime.now()).inDays;
  }

  /// Check if the firm is in read-only mode (Grace Period or Locked)
  static Future<bool> isReadOnly(String firmId) async {
    final status = await SubscriptionService().checkSubscriptionStatus(firmId);
    return status == 'grace_period' || status == 'locked';
  }

  /// Validate a promo code against backend
  Future<Map<String, dynamic>> validatePromoCode(
      String code, String planId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentFirmId = prefs.getString('last_firm') ?? 'UNKNOWN';

      final response = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'subscription/validate-promo',
        firmId: currentFirmId, // Required for Lambda authentication
        data: {
          'code': code.toUpperCase(),
          'planId': planId,
        },
      );

      if (response['error'] != null) {
        return {'valid': false, 'error': response['error']};
      }

      return response;
    } catch (e) {
      return {'valid': false, 'error': 'Validation failed: $e'};
    }
  }

  /// Create a subscription with backend
  Future<Map<String, dynamic>> createSubscription({
    required String firmId,
    required String planId,
    required String billingCycle,
    String? promoCode,
  }) async {
    try {
      final response = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'subscription/create',
        firmId: firmId, // Required for Lambda authentication
        data: {
          'firmId': firmId,
          'planId': planId,
          'billingCycle': billingCycle,
          if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
        },
      );

      return response;
    } catch (e) {
      return {'error': 'Failed to create subscription: $e'};
    }
  }

  /// Grant a temporary extension (e.g. while awaiting manual verification)
  /// Extends expiry by 7 days locally and marks status as PENDING_VERIFICATION
  Future<void> grantManualExtension(String firmId) async {
    final db = DatabaseHelper();

    // 1. Get current expiry
    final firms = await db.database.then((d) => d.query(
          'firms',
          where: 'firmId = ?',
          whereArgs: [firmId],
          limit: 1,
        ));

    if (firms.isEmpty) return;

    final currentExpiryStr = firms.first['subscriptionExpiry'] as String?;
    DateTime newExpiry;

    if (currentExpiryStr != null) {
      final current = DateTime.parse(currentExpiryStr);
      // If already expired, start 7 days from NOW. If not, add 7 days to current.
      if (current.isBefore(DateTime.now())) {
        newExpiry = DateTime.now().add(const Duration(days: 7));
      } else {
        newExpiry = current.add(const Duration(days: 7));
      }
    } else {
      // No expiry? Start 7 days from now
      newExpiry = DateTime.now().add(const Duration(days: 7));
    }

    // 2. Update Local DB
    await db.updateFirmDetails(firmId, {
      'subscriptionExpiry': newExpiry.toIso8601String(),
      'subscriptionStatus': 'PENDING_VERIFICATION', // New status flag
    });

    // 3. Update Shared Prefs for immediate access
    final sp = await SharedPreferences.getInstance();
    await sp.setString('subscription_expiry', newExpiry.toIso8601String());
  }
}
