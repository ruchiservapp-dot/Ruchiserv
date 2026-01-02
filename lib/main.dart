import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/encryption_helper.dart'; // COMPLIANCE: PII encryption (Rule C.3)
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'core/locale_provider.dart';

import 'screens/1.4_login_screen.dart'; // Full version with biometrics
import 'screens/main_menu_screen.dart'; // Proper menu navigation
import 'services/cloud_sync_service.dart'; // Background Sync
import 'screens/0.0_splash_screen.dart';
import 'db/seed_dishes.dart'; // Sample dishes and ingredients
// DEV: Uncomment below for development testing
// import 'db/seed_test_user.dart';
// import 'db/seed_november_data.dart';

// COMPLIANCE: Initialize encryption before any database operations
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CRITICAL: Initialize encryption before database access (Rule C.3)
  await EncryptionHelper.initialize();
  
  // Seed sample dishes and ingredients (skips if already seeded)
  await seedDishesAndIngredients();
  
  // DEV: Uncomment below for development testing only
  // await seedTestUser();
  // await seedNovember2025Data();
  
  // SYNC: Start background polling for multi-device sync
  CloudSyncService().startPolling();
  
  runApp(const RuchiServApp());
}

class RuchiServApp extends StatelessWidget {
  const RuchiServApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: 'RuchiServ',
            // App text follows user's language preference
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: const LifecycleWatcher(child: SplashScreen()),
            routes: {
              '/login': (context) => LoginScreen(),
              '/home': (context) => MainMenuScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Helper widget to watch app lifecycle and pause/resume sync
class LifecycleWatcher extends StatefulWidget {
  final Widget child;
  const LifecycleWatcher({super.key, required this.child});

  @override
  State<LifecycleWatcher> createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends State<LifecycleWatcher> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CloudSyncService().setAppForegrounded();
    } else if (state == AppLifecycleState.paused) {
      CloudSyncService().setAppBackgrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
