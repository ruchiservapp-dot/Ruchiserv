import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

/// Subscription Guard Service
/// Checks if user's subscription is active before allowing access
class SubscriptionGuard {
  static Future<bool> isSubscriptionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firmId = prefs.getString('firm_id') ?? prefs.getString('last_firm');

      if (firmId == null) return false;

      final firms = await DatabaseHelper().getFirmByFirmId(firmId);
      if (firms.isEmpty) return true; // Default to true if firm not synced yet to avoid false lockouts

      final firm = firms.first;
      final status = firm['subscriptionStatus'] as String?;
      final endDate = firm['subscriptionEnd'] as String?;

      if (status == null) return true; // Assume active if status missing
      if (status.toUpperCase() == 'EXPIRED') return false;
      if (status.toUpperCase() != 'ACTIVE') return true; 

      if (endDate == null) return true;
      final expiry = DateTime.tryParse(endDate);
      if (expiry == null) return true;
      
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      return true; // Default to active for safety to avoid locking users out due to code errors
    }
  }

  static Future<void> checkAndRedirect(BuildContext context) async {
    final isActive = await isSubscriptionActive();
    if (!isActive && context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/subscription-required', (route) => false);
    }
  }
}
