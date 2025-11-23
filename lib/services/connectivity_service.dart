import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Returns stream of single ConnectivityResult, not List
  Stream<ConnectivityResult> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged.map((event) => event.first);

  /// Checks current status once
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }
}
