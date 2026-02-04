import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:ruchiserv/main.dart' as app;

/// Cross-platform authentication flow test using Patrol
/// Tests login flow on iOS, Android, Web, macOS, Linux, Windows
void main() {
  patrolTest(
    'User can login with valid credentials',
    ($) async {
      // 1. Launch the app
      app.main();
      await $.pumpAndSettle();

      // Wait for splash screen
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // 2. Verify we're at login screen
      expect($(#firmIdField), findsOneWidget);
      expect($(#mobileField), findsOneWidget);
      expect($(#passwordField), findsOneWidget);
      expect($(#loginBtn), findsOneWidget);

      // 3. Enter test credentials
      await $(#firmIdField).enterText('RCHSRV');
      await $.pumpAndSettle();

      await $(#mobileField).enterText('9999999999');
      await $.pumpAndSettle();

      await $(#passwordField).enterText('test1234');
      await $.pumpAndSettle();

      // 4. Tap login button
      await $(#loginBtn).tap();
      
      // 5. Wait for login processing
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // 6. Verify home screen (BottomNavigationBar indicates successful login)
      expect($(BottomNavigationBar), findsOneWidget);
    },
  );

  patrolTest(
    'Login shows error for invalid credentials',
    ($) async {
      app.main();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Enter invalid credentials
      await $(#firmIdField).enterText('INVALID');
      await $(#mobileField).enterText('0000000000');
      await $(#passwordField).enterText('wrongpass');
      await $.pumpAndSettle();

      await $(#loginBtn).tap();
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Should still be on login screen (login failed)
      expect($(#loginBtn), findsOneWidget);
    },
  );

  patrolTest(
    'Login form validation works',
    ($) async {
      app.main();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Clear default firm ID and try to login with empty fields
      await $(#firmIdField).enterText('');
      await $(#mobileField).enterText('');
      await $(#passwordField).enterText('');
      await $.pumpAndSettle();

      await $(#loginBtn).tap();
      await $.pumpAndSettle();

      // Should show validation errors (still on login screen)
      expect($(#loginBtn), findsOneWidget);
    },
  );
}
