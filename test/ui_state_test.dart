import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruchiserv/core/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'dark_mode': false});
  });

  testWidgets('Systemic UI State Test: Theme Toggle Persists via SettingsProvider',
      (WidgetTester tester) async {
    
    // 1. Force SharedPreferences to initialize
    await SharedPreferences.getInstance();

    // 2. Boot App with SettingsProvider
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: settings.themeMode,
              home: Scaffold(
                body: SwitchListTile(
                  title: const Text("Dark Mode"),
                  value: settings.isDarkMode,
                  onChanged: (val) {
                    settings.setTheme(val);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    // Wait for async load
    await tester.pumpAndSettle();

    // 3. Verify Initial State
    final BuildContext initialContext = tester.element(find.byType(Scaffold));
    expect(Theme.of(initialContext).brightness, Brightness.light);

    // 4. Toggle
    final switchFinder = find.byType(SwitchListTile);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // 5. Verify Build
    final BuildContext darkContext = tester.element(find.byType(Scaffold));
    expect(Theme.of(darkContext).brightness, Brightness.dark);

    // 6. Verify Persistence
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), true);
  });
}
