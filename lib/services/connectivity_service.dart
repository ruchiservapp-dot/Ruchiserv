import 'package:ruchiserv/core/app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Cache the mapped stream as a broadcast stream and provide it as a static instance.
  // This prevents StreamBuilder from receiving a new stream instance on every rebuild,
  // which causes an infinite unsubscribe/subscribe -> initial event -> rebuild loop.
  static final Stream<ConnectivityResult> _connectivityStream =
      Connectivity().onConnectivityChanged.map((event) => event.first).asBroadcastStream();

  Stream<ConnectivityResult> get onConnectivityChanged => _connectivityStream;

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
      AppLogger.info('Connectivity check failed: $e');
      return false;
    }
  }
}
