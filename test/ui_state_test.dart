import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruchiserv/core/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'dark_mode': false});
  });

  testWidgets('Systemic UI State Test: Dark Mode Toggle Persists globally',
      (WidgetTester tester) async {
    
    // 1. Force SharedPreferences to initialize synchronously for the test
    await SharedPreferences.getInstance();

    // 2. Boot a brutally stripped-down Material App isolating ONLY the ThemeProvider
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: Consumer<ThemeProvider>(
          builder: (context, theme, child) {
            return MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: theme.themeMode,
              home: Scaffold(
                body: SwitchListTile(
                  title: const Text("Dark Mode"),
                  value: theme.isDarkMode,
                  onChanged: (val) {
                    theme.setTheme(val);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    // Wait for the Provider constructor to finish its async SharedPreferences read
    await tester.pumpAndSettle();

    // 3. Verify Initial State is Light Mode
    final BuildContext initialContext = tester.element(find.byType(Scaffold));
    expect(Theme.of(initialContext).brightness, Brightness.light);

    // 4. Find the Dark Mode switch and tap it
    final switchFinder = find.byType(SwitchListTile);
    expect(switchFinder, findsOneWidget);
    
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // 5. Verify the App rebuilt in Dark Mode physically
    final BuildContext darkContext = tester.element(find.byType(Scaffold));
    expect(Theme.of(darkContext).brightness, Brightness.dark);

    // 6. Verify SharedPreferences saved the state correctly
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), true);
  });
}
