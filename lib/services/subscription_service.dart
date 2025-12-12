// lib/services/subscription_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

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

    if (expiryStr == null) return 'active'; // No expiry set (e.g. free tier or new)

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
}
