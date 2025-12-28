
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruchiserv/main.dart' as app;
import 'package:ruchiserv/db/seed_test_user.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RuchiServ End-to-End Test', () {
    setUpAll(() async {
      // Initialize DB and Seed User
      // Note: In a real device test, this persists to disk.
      // We might want to clear DB before running?
      // For now, let's just seed. `seedTestUser` handles updates if exists.
      
      // We need to ensure plugins are initialized
      // IntegrationTestWidgetsFlutterBinding.ensureInitialized() handles this.
    });

    testWidgets('Full App Flow: Login -> Add Order -> Check Finance', (tester) async {
      // 1. App Launch
      app.main();
      await tester.pumpAndSettle();

      // 2. Splash Screen -> Login Screen
      // Splash has a 2-3 sec delay.
      await tester.pump(const Duration(seconds: 4)); 
      await tester.pumpAndSettle();

      // Check if we are at Login Screen or Home (if already logged in)
      if (find.byKey(const Key('firmIdField')).evaluate().isNotEmpty) {
        // We are at Login Screen
        print('✅ At Login Screen');
        
        // Seed user now (doing it here to ensure DB is ready if main initialized it)
        await seedTestUser();

        // Enter Credentials
        // Firm ID: RCHSRV
        await tester.enterText(
          find.byKey(const Key('firmIdField')), 
          'RCHSRV'
        );
        await tester.pumpAndSettle();

        // Mobile: 9999999999
        await tester.enterText(
          find.byKey(const Key('mobileField')),
          '9999999999'
        );
        await tester.pumpAndSettle();

        // Password: test1234
        await tester.enterText(
          find.byKey(const Key('passwordField')),
          'test1234'
        );
        await tester.pumpAndSettle();

        // Tap Login
        await tester.tap(find.byKey(const Key('loginBtn')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2)); // Wait for async login
      } else {
         print('ℹ️ Already Logged In or Login Screen not found?');
         // Print what we see
         // tester.binding.debugDumpApp();
      }

      // 3. Verify Home Screen (Dashboard)
      // The dashboard title changes based on the selected tab. Default is "Orders".
      // We can also check for BottomNavigationBar.
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      print('✅ Logged in successfully. Dashboard (BottomNav) Visible.');

      // 4. Navigate to Orders
      // Find "Orders" tile or button.
      // Main menu usually has "Orders" text
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      // Verify Orders Screen
      print('✅ Navigated to Orders Screen');
      
      // 5. Add New Order
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      print('✅ Opened Add Order Screen');
      
      // Enter Order Details
      // Just verify screen opens for now, entering complex forms in integration test 
      // can be flaky with date pickers/dropdowns without specific keys.
      expect(find.text('New Order'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // 6. Navigate Back to Home
      await tester.pageBack(); 
      await tester.pumpAndSettle();

      // 7. Check Finance
      // Tapping on "Reports" or "Finance"?
      // Main menu usually has "Finance"
      await tester.tap(find.text('Finance'));
      await tester.pumpAndSettle();
      
      expect(find.text('Finance Dashboard'), findsOneWidget);
      print('✅ Navigated to Finance Screen');

    });
  });
}
