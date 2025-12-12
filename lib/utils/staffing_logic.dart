/// Staffing calculation logic for Kerala/South India catering standards.
/// 
/// This class provides functions to calculate the number of service servers
/// needed based on event parameters like pax count, service type, dish count,
/// and counter count.
class StaffingLogic {
  // Service type constants
  static const String buffet = 'BUFFET';
  static const String tableService = 'TABLE_SERVICE';
  static const String hybrid = 'HYBRID';

  /// Calculate the number of servers needed for a catering event.
  ///
  /// [paxCount] - Total number of guests
  /// [serviceType] - One of: 'BUFFET', 'TABLE_SERVICE', or 'HYBRID'
  /// [dishCount] - Total number of unique food items (chafing dishes)
  /// [counterCount] - Number of parallel serving lines/counters (min 1)
  ///
  /// Returns the total number of servers required.
  static int calculateServers({
    required int paxCount,
    required String serviceType,
    required int dishCount,
    required int counterCount,
  }) {
    // Validate inputs
    if (paxCount <= 0) return 0;
    if (dishCount <= 0) return 0;
    if (counterCount <= 0) counterCount = 1; // Minimum 1 counter

    switch (serviceType.toUpperCase()) {
      case buffet:
        return _calculateBuffetServers(dishCount, counterCount);
      case tableService:
        return _calculateTableServiceServers(paxCount, dishCount);
      case hybrid:
        return _calculateHybridServers(paxCount, dishCount, counterCount);
      default:
        // Default to buffet logic
        return _calculateBuffetServers(dishCount, counterCount);
    }
  }

  /// BUFFET Logic:
  /// - Base Staffing: 1 Server per 3 Dishes
  /// - Counter Adjustment: Reduced staff + supervisor per counter
  static int _calculateBuffetServers(int dishCount, int counterCount) {
    // Base: 1 server per 3 dishes
    final baseServers = (dishCount / 3).ceil();
    
    // Adjust for multiple counters
    final adjustedServers = (baseServers / counterCount).ceil();
    
    // Add supervisor/expeditor per counter
    return adjustedServers + counterCount;
  }

  /// TABLE_SERVICE Logic (Guest:Server Ratio) - Reduced to half as requested:
  /// - ≤8 dishes: 1:24 ratio
  /// - 9-14 dishes: 1:20 ratio
  /// - 15+ dishes: 1:16 ratio
  static int _calculateTableServiceServers(int paxCount, int dishCount) {
    if (dishCount <= 8) {
      return (paxCount / 24).ceil();
    } else if (dishCount <= 14) {
      return (paxCount / 20).ceil();
    } else {
      return (paxCount / 16).ceil();
    }
  }

  /// HYBRID Logic (Assisted Buffet):
  /// - Buffet line servers + Table runners (1:50 ratio - reduced to half)
  static int _calculateHybridServers(int paxCount, int dishCount, int counterCount) {
    // Component 1: Full buffet logic
    final buffetServers = _calculateBuffetServers(dishCount, counterCount);
    
    // Component 2: Table runners at 1:50 ratio
    final tableRunners = (paxCount / 50).ceil();
    
    return buffetServers + tableRunners;
  }

  /// Calculate service cost based on staff count and rate
  static double calculateServiceCost({
    required int staffCount,
    required double ratePerStaff,
  }) {
    return staffCount * ratePerStaff;
  }

  /// Calculate counter setup cost
  static double calculateCounterSetupCost({
    required int counterCount,
    required double ratePerCounter,
  }) {
    return counterCount * ratePerCounter;
  }
}
