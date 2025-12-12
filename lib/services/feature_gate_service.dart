// Feature Gate Service - Subscription Tier Feature Gating
// Controls which features are available based on subscription tier
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

class FeatureGateService {
  static FeatureGateService? _instance;
  static FeatureGateService get instance => _instance ??= FeatureGateService._();
  FeatureGateService._();

  // Cached tier
  String? _cachedTier;
  List<String>? _cachedFeatures;

  // Subscription Tier Pricing (hardwired)
  static const tierPricing = {
    'BASIC': 1499,
    'PRO': 2499,
    'ENTERPRISE': 0, // Custom pricing
  };

  // Feature-tier mapping
  static const tierFeatures = {
    'BASIC': [
      'ORDERS',
      'CALENDAR',
      'KITCHEN',
      'INVENTORY',
      'BASIC_REPORTS',
      'STAFF_VIEW',
    ],
    'PRO': [
      'ORDERS',
      'CALENDAR',
      'KITCHEN',
      'INVENTORY',
      'DISPATCH',
      'WHATSAPP',
      'EMAIL',
      'ALL_REPORTS',
      'STAFF',
      'SUPPLIERS',
      'SUBCONTRACTORS',
      'FINANCE',
    ],
    'ENTERPRISE': [
      'ALL', // Includes everything
      'GPS_TRACKING',
      'ANALYTICS',
      'MULTI_BRANCH',
      'API_ACCESS',
      'PRIORITY_SUPPORT',
      'CUSTOM_INTEGRATIONS',
    ],
  };

  // Human readable feature names
  static const featureNames = {
    'ORDERS': 'Order Management',
    'CALENDAR': 'Calendar View',
    'KITCHEN': 'Kitchen Operations',
    'INVENTORY': 'Inventory Management',
    'DISPATCH': 'Dispatch & Logistics',
    'WHATSAPP': 'WhatsApp Notifications',
    'EMAIL': 'Email Notifications',
    'GPS_TRACKING': 'GPS Tracking',
    'ANALYTICS': 'Advanced Analytics',
    'ALL_REPORTS': 'All Reports',
    'BASIC_REPORTS': 'Basic Reports',
    'STAFF': 'Staff Management',
    'STAFF_VIEW': 'Staff View Only',
    'FINANCE': 'Finance Module',
    'SUPPLIERS': 'Supplier Management',
    'SUBCONTRACTORS': 'Subcontractor Management',
    'MULTI_BRANCH': 'Multi-Branch Support',
    'API_ACCESS': 'API Access',
    'PRIORITY_SUPPORT': 'Priority Support',
    'CUSTOM_INTEGRATIONS': 'Custom Integrations',
  };

  /// Initialize tier after login
  Future<void> initialize() async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');
    
    if (firmId == null) return;
    
    final db = await DatabaseHelper().database;
    final firms = await db.query('firms', 
      where: 'firmId = ?', 
      whereArgs: [firmId],
      limit: 1,
    );
    
    if (firms.isNotEmpty) {
      final firm = firms.first;
      _cachedTier = firm['subscriptionTier'] as String? ?? 'BASIC';
      
      // Get custom enabled features or use tier defaults
      final customFeatures = firm['enabledFeatures'] as String?;
      if (customFeatures != null && customFeatures.isNotEmpty) {
        _cachedFeatures = customFeatures.split(',');
      } else {
        _cachedFeatures = tierFeatures[_cachedTier] ?? tierFeatures['BASIC']!;
      }
      
      // Cache in SharedPreferences
      await sp.setString('subscription_tier', _cachedTier!);
      await sp.setStringList('enabled_features', _cachedFeatures!);
    }
  }

  /// Clear cached tier on logout
  Future<void> clear() async {
    _cachedTier = null;
    _cachedFeatures = null;
    
    final sp = await SharedPreferences.getInstance();
    await sp.remove('subscription_tier');
    await sp.remove('enabled_features');
  }

  /// Get current subscription tier
  Future<String> getCurrentTier() async {
    if (_cachedTier != null) return _cachedTier!;
    final sp = await SharedPreferences.getInstance();
    return sp.getString('subscription_tier') ?? 'BASIC';
  }

  /// Check if a feature is enabled for current tier
  Future<bool> isFeatureEnabled(String feature) async {
    final tier = await getCurrentTier();
    
    // Enterprise has access to everything
    if (tier == 'ENTERPRISE') return true;
    
    // Check cached features
    if (_cachedFeatures != null) {
      if (_cachedFeatures!.contains('ALL')) return true;
      return _cachedFeatures!.contains(feature);
    }
    
    // Check from SharedPreferences
    final sp = await SharedPreferences.getInstance();
    final features = sp.getStringList('enabled_features') ?? [];
    if (features.contains('ALL')) return true;
    return features.contains(feature);
  }

  /// Get all enabled features
  Future<List<String>> getEnabledFeatures() async {
    if (_cachedFeatures != null) return _cachedFeatures!;
    
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList('enabled_features') ?? [];
  }

  /// Get required tier for a feature
  static String getRequiredTier(String feature) {
    if (tierFeatures['BASIC']!.contains(feature)) return 'BASIC';
    if (tierFeatures['PRO']!.contains(feature)) return 'PRO';
    return 'ENTERPRISE';
  }

  /// Get tier price
  static int getTierPrice(String tier) {
    return tierPricing[tier] ?? 0;
  }

  /// Get tier display name
  static String getTierDisplayName(String tier) {
    switch (tier) {
      case 'BASIC': return 'Basic - ₹1,499/month';
      case 'PRO': return 'Pro - ₹2,499/month';
      case 'ENTERPRISE': return 'Enterprise - Custom Pricing';
      default: return tier;
    }
  }

  /// Check if upgrade is available
  Future<bool> canUpgrade() async {
    final tier = await getCurrentTier();
    return tier != 'ENTERPRISE';
  }

  /// Get next tier for upgrade
  Future<String?> getNextTier() async {
    final tier = await getCurrentTier();
    switch (tier) {
      case 'BASIC': return 'PRO';
      case 'PRO': return 'ENTERPRISE';
      default: return null;
    }
  }
}
