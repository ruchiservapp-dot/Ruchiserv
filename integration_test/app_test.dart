import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruchiserv/screens/add_order_screen.dart';
import 'package:ruchiserv/screens/finance_screen.dart';
import 'package:ruchiserv/screens/main_menu_screen.dart';
import 'package:ruchiserv/screens/orders_calendar_screen.dart';
import 'package:ruchiserv/main.dart' as app;
import 'package:ruchiserv/db/seed_test_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _localAuthChannel = MethodChannel(
  'plugins.flutter.io/local_auth',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RuchiServ End-to-End Test', () {
    setUpAll(() async {
      // Keep integration flow deterministic by disabling biometric prompts.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_localAuthChannel, (methodCall) async {
        switch (methodCall.method) {
          case 'canCheckBiometrics':
          case 'deviceSupportsBiometrics':
          case 'isDeviceSupported':
            return false;
          case 'getAvailableBiometrics':
          case 'getEnrolledBiometrics':
            return <String>[];
          case 'authenticate':
          case 'authenticateWithBiometrics':
            return false;
          case 'stopAuthentication':
            return true;
          default:
            return null;
        }
      });
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_localAuthChannel, null);
    });

    testWidgets('Full App Flow: Login -> Add Order -> Check Finance',
        (tester) async {
      // Ensure deterministic startup state.
      await seedTestUser();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 1. App Launch
      app.main();
      await tester.pumpAndSettle();

      // 2. Splash Screen -> Login Screen
      // Splash has a 2-3 sec delay.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Check if we are at Login Screen or Home
      if (find.byKey(const Key('firmIdField')).evaluate().isNotEmpty) {
        print('✅ At Login Screen');

        // Enter credentials for seeded Admin.
        await tester.enterText(
          find.byKey(const Key('firmIdField')),
          'RCHSRV',
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('mobileField')),
          '9999999999',
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('passwordField')),
          'test1234',
        );
        await tester.pumpAndSettle();

        // Tap Login
        await tester.tap(find.byKey(const Key('loginBtn')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2)); // Wait for async login
      } else {
        print('ℹ️ Login screen not shown; continuing with current session.');
      }

      // Dismiss optional prompts (e.g., biometric enrollment) if shown.
      Future<void> dismissOptionalDialogs() async {
        if (find.byType(AlertDialog).evaluate().isEmpty) return;
        final notNow = find.text('Not Now');
        final cancel = find.text('Cancel');
        if (notNow.evaluate().isNotEmpty) {
          await tester.tap(notNow.first);
        } else if (cancel.evaluate().isNotEmpty) {
          await tester.tap(cancel.first);
        } else if (find.byType(TextButton).evaluate().isNotEmpty) {
          await tester.tap(find.byType(TextButton).first);
        }
        await tester.pumpAndSettle();
      }

      await dismissOptionalDialogs();

      // 3. Verify Home Screen shell.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(MainMenuScreen), findsOneWidget);
      print('✅ Logged in successfully. Main menu visible.');

      // 4. Navigate to Orders
      expect(find.text('Orders'), findsWidgets);
      await tester.tap(find.text('Orders').first);
      await tester.pumpAndSettle();
      await dismissOptionalDialogs();

      expect(find.byType(OrderCalendarScreen), findsOneWidget);
      print('✅ Navigated to Orders screen');

      // 5. Add New Order
      expect(find.byIcon(Icons.add), findsWidgets);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await dismissOptionalDialogs();

      expect(find.byType(AddOrderScreen), findsOneWidget);
      print('✅ Opened Add Order screen');

      await tester.pageBack();
      await tester.pumpAndSettle();

      // 6. Navigate back if still on Orders details.
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 7. Check Finance
      expect(find.text('Finance'), findsWidgets);
      await tester.tap(find.text('Finance').first);
      await tester.pumpAndSettle();
      await dismissOptionalDialogs();

      expect(find.byType(FinanceScreen), findsOneWidget);
      print('✅ Navigated to Finance screen');
    });
  });
}
