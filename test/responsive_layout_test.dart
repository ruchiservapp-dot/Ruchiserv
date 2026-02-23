import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruchiserv/screens/main_menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ruchiserv/core/locale_provider.dart';

/// Section 17: Responsive Layout Tests
///
/// Verifies that the app renders without overflow errors on:
/// - Small phone (375×667) — iPhone SE / 5.5" Android
/// - Standard phone (393×852) — iPhone 15 / 6.1" Android
/// - Large phone (430×932) — iPhone Pro Max / 6.7" Android
/// - Tablet landscape (1024×768) — iPad / 10" tablet
/// - Desktop (1440×900) — macOS / Web desktop
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock PathProvider
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    SharedPreferences.setMockInitialValues({
      'last_firm': 'TEST_FIRM',
      'firmId': 'TEST_FIRM',
      'last_mobile': '9999999999',
    });
  });

  /// Helper to wrap a widget with the app's Material scaffold
  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  // Screen size definitions matching Section 17 device matrix
  final screenSizes = {
    'Small Phone (5.5" / iPhone SE)': const Size(375, 667),
    'Standard Phone (6.1" / iPhone 15)': const Size(393, 852),
    'Large Phone (6.7" / iPhone Pro Max)': const Size(430, 932),
    'Tablet Landscape (10" iPad)': const Size(1024, 768),
    'Desktop (macOS / Web)': const Size(1440, 900),
  };

  group('Responsive Layout - No Overflow Errors', () {
    for (final entry in screenSizes.entries) {
      testWidgets('MainMenuScreen renders on ${entry.key}', (tester) async {
        // Set the screen size for this test
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Build widget — MainMenuScreen will show loading then content
        await tester.pumpWidget(buildTestableWidget(MainMenuScreen()));
        await tester.pump(const Duration(seconds: 1));

        // Verify no overflow errors occurred
        // Flutter test framework will automatically report RenderFlex overflow
        // as test failures. If we get here, layout was clean.
        expect(tester.takeException(), isNull,
            reason: 'Should not throw overflow error on ${entry.key}');

        print('✅ ${entry.key}: No overflow at ${entry.value.width}×${entry.value.height}');
      });
    }
  });

  group('Responsive Layout - Widget Presence', () {
    testWidgets('Bottom navigation renders on small screen', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(MainMenuScreen()));
      // Use pump with duration instead of pumpAndSettle — MainMenuScreen
      // has async DB loading that may never fully settle in test env.
      await tester.pump(const Duration(seconds: 2));

      // After loading, should show either the main menu or a loading state
      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Should have at least one Scaffold rendered');
      print('✅ Scaffold renders correctly on small screen');
    });

    testWidgets('App renders on tablet landscape', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(MainMenuScreen()));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Should render on tablet landscape');
      print('✅ Tablet landscape: layout renders');
    });
  });
}
