import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:ruchiserv/main.dart' as app;

/// E2E test for order creation flow
/// Requires user to already be logged in (or login happens first)
void main() {
  patrolTest(
    'User can navigate to Orders screen',
    ($) async {
      app.main();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Login first if on login screen
      if ($(#firmIdField).exists) {
        await $(#firmIdField).enterText('RCHSRV');
        await $(#mobileField).enterText('9999999999');
        await $(#passwordField).enterText('test1234');
        await $.pumpAndSettle();
        await $(#loginBtn).tap();
        await $.pump(const Duration(seconds: 3));
        await $.pumpAndSettle();
      }

      // Should be at main menu now
      expect($(BottomNavigationBar), findsOneWidget);

      // Navigate to Orders
      await $('Orders').tap();
      await $.pumpAndSettle();

      // Verify Orders screen loaded
      expect($('Orders'), findsWidgets);
    },
  );

  patrolTest(
    'User can open new order form',
    ($) async {
      app.main();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Login if needed
      if ($(#firmIdField).exists) {
        await $(#firmIdField).enterText('RCHSRV');
        await $(#mobileField).enterText('9999999999');
        await $(#passwordField).enterText('test1234');
        await $.pumpAndSettle();
        await $(#loginBtn).tap();
        await $.pump(const Duration(seconds: 3));
        await $.pumpAndSettle();
      }

      // Navigate to Orders
      await $('Orders').tap();
      await $.pumpAndSettle();

      // Tap FAB to create new order
      final fab = $(FloatingActionButton);
      if (fab.exists) {
        await fab.tap();
        await $.pumpAndSettle();

        // Verify new order form opened
        expect($('New Order'), findsOneWidget);

        // Go back
        await $.native.pressBack();
        await $.pumpAndSettle();
      }
    },
  );

  patrolTest(
    'User can navigate to Finance screen',
    ($) async {
      app.main();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Login if needed
      if ($(#firmIdField).exists) {
        await $(#firmIdField).enterText('RCHSRV');
        await $(#mobileField).enterText('9999999999');
        await $(#passwordField).enterText('test1234');
        await $.pumpAndSettle();
        await $(#loginBtn).tap();
        await $.pump(const Duration(seconds: 3));
        await $.pumpAndSettle();
      }

      // Navigate to Finance
      await $('Finance').tap();
      await $.pumpAndSettle();

      // Verify Finance screen loaded
      expect($('Finance Dashboard'), findsOneWidget);
    },
  );
}
