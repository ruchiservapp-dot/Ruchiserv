import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Returns stream of single ConnectivityResult, not List
  Stream<ConnectivityResult> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged.map((event) => event.first);

  // Helper for testing
  static bool? testOnlineStatus;

  /// Checks current status once
  Future<bool> isOnline() async {
    if (testOnlineStatus != null) return testOnlineStatus!;
    
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);
    } catch (e) {
      // If platform channel fails (e.g. during test without mock), assume offline or handle gracefully
      print('Connectivity check failed: $e');
      return false;
    }
  }
}
