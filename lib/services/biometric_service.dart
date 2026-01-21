import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      print('BioService: canCheck=$canCheck, isSupported=$isSupported');
      return canCheck || isSupported;
    } catch (e) {
      print('BioService: canCheckBiometrics Error: $e');
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      print('BioService: Authenticating...');
      final result = await _auth.authenticate(
        localizedReason: 'Please authenticate to login',
      );
      print('BioService: Authenticate result: $result');
      return result;
    } catch (e) {
      print('BioService: Authenticate Error: $e');
      return false;
    }
  }
}
