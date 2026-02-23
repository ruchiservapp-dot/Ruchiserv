import 'package:flutter_test/flutter_test.dart';
import 'package:ruchiserv/config/app_config.dart';

void main() {
  test('Cashfree Sandbox Configuration Verification', () {
    print('--- Cashfree Config Verification ---');
    print('App ID: ${AppConfig.cashfreeAppId}');
    print('Sandbox Mode: ${AppConfig.cashfreeSandbox}');
    print('Is Configured: ${AppConfig.isCashfreeConfigured}');
    
    // We expect these to be true ONLY if run with the correct --dart-define flags
    // This test is meant to be run via scripts/run_with_cashfree.sh or similar
    expect(AppConfig.cashfreeAppId, isNotEmpty, reason: 'Cashfree App ID should not be empty');
    expect(AppConfig.cashfreeSecretKey, isNotEmpty, reason: 'Cashfree Secret Key should not be empty');
    expect(AppConfig.cashfreeSandbox, isTrue, reason: 'Cashfree should be in Sandbox mode');
    expect(AppConfig.isCashfreeConfigured, isTrue, reason: 'AppConfig.isCashfreeConfigured should be true');
    
    print('✅ Cashfree Sandbox Configuration Verified!');
  });
}
