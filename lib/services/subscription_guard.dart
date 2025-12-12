import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

/// Subscription Guard Service
/// Checks if user's subscription is active before allowing access
class SubscriptionGuard {
  static Future<bool> isSubscriptionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firmId = prefs.getString('firmId');
      
      if (firmId == null) return false;
      
      final firms = await DatabaseHelper().getFirmByFirmId(firmId);
      if (firms.isEmpty) return false;
      
      final firm = firms.first;
      final status = firm['subscriptionStatus'] as String?;
      final endDate = firm['subscriptionEnd'] as String?;
      
      if (status == null || endDate == null) return false;
      if (status.toLowerCase() != 'active') return false;
      
      final expiry = DateTime.parse(endDate);
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      return false; // Default to false for safety
    }
  }

  static Future<void> checkAndRedirect(BuildContext context) async {
    final isActive = await isSubscriptionActive();
    if (!isActive && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/subscription-required', (route) => false);
    }
  }
}
