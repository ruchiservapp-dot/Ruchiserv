import 'package:ruchiserv/core/app_logger.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      AppLogger.info('BioService: canCheck=$canCheck, isSupported=$isSupported');
      return canCheck || isSupported;
    } catch (e) {
      AppLogger.info('BioService: canCheckBiometrics Error: $e');
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      AppLogger.info('BioService: Authenticating...');
      final result = await _auth.authenticate(
        localizedReason: 'Please authenticate to login',
      );
      AppLogger.info('BioService: Authenticate result: $result');
      return result;
    } catch (e) {
      AppLogger.info('BioService: Authenticate Error: $e');
      return false;
    }
  }
}
