import 'dart:async'; // Add runZonedGuarded
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_logger.dart'; // Ensure import
import 'core/app_theme.dart';
import 'core/encryption_helper.dart'; // COMPLIANCE: PII encryption (Rule C.3)
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'core/locale_provider.dart';

import 'screens/login_screen.dart'; // Full version with biometrics
import 'screens/main_menu_screen.dart'; // Proper menu navigation
import 'services/cloud_sync_service.dart'; // Background Sync
import 'services/fcm_service.dart'; // Notification Service
import 'screens/splash_screen.dart';
import 'services/web_update_service.dart';
import 'db/seed_dishes.dart'; // Sample dishes and ingredients
import 'screens/add_order_screen.dart';
import 'services/session_service.dart';
import 'services/app_update_service.dart'; // Added AppUpdateService
import 'package:firebase_core/firebase_core.dart'; // Added FirebaseCore import if needed
import 'firebase_options.dart';
import 'screens/create_firm_screen.dart';

const bool _isIntegrationTest =
    bool.fromEnvironment('INTEGRATION_TEST', defaultValue: false);

// COMPLIANCE: Initialize encryption before any database operations
Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    var crashlyticsEnabled = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      crashlyticsEnabled = Firebase.apps.isNotEmpty && !kIsWeb;
    } catch (e) {
      debugPrint('Firebase initialization unavailable: $e');
    }

    // CRITICAL: Initialize encryption before database access (Rule C.3)
    await EncryptionHelper.initialize();

    // Keep test boot deterministic by skipping push/update initialization.
    if (!_isIntegrationTest) {
      await FcmService.initialize();
      await AppUpdateService().initialize(); // Initialize Version Check
    }

    // CRASHLYTICS: Catch synchronous Flutter errors
    if (!_isIntegrationTest) {
      FlutterError.onError = (errorDetails) {
        if (crashlyticsEnabled) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        } else {
          FlutterError.presentError(errorDetails);
        }
      };
    }

    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'UNKNOWN';
    final userId = sp.getString('user_id') ?? 'GUEST';
    if (crashlyticsEnabled && !_isIntegrationTest) {
      FirebaseCrashlytics.instance.setCustomKey('firmId', firmId);
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
    }

    // Pass all uncaught async errors to Crashlytics
    if (!_isIntegrationTest) {
      PlatformDispatcher.instance.onError = (error, stack) {
        if (crashlyticsEnabled) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        }
        debugPrint('Unhandled async error: $error\n$stack');
        return false;
      };
    }

    // Seed sample dishes and ingredients (skips if already seeded)
    await seedDishesAndIngredients();

    // SYNC: Start background polling for multi-device sync
    if (!_isIntegrationTest) {
      CloudSyncService().startPolling();
    }

    // WEB UPDATE: Check for new versions periodically
    if (!_isIntegrationTest) {
      await WebUpdateService().init();
    }

    runApp(const RuchiServApp());
  }, (error, stack) {
    // Catch errors outside Flutter construct
    if (Firebase.apps.isNotEmpty && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      debugPrint('Unhandled zoned error: $error\n$stack');
    }
  });
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
            title: 'Ruchiserv Kitchen',
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
            navigatorKey: SessionService.navigatorKey, // Add navigator key
            builder: (context, child) {
              // Version check on app start
              if (child != null && !_isIntegrationTest) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AppUpdateService().checkForUpdate(context);
                });
              }

              // Global interaction listener for session timeout
              return SessionTimeoutListener(
                child: SafeArea(
                  // Don't add bottom padding — bottom nav handles that
                  bottom: false,
                  child: WebUpdateWrapper(child: child!),
                ),
              );
            },
            home: const LifecycleWatcher(child: SplashScreen()),
            routes: {
              '/login': (context) => LoginScreen(),
              '/home': (context) => MainMenuScreen(),
              '/register': (context) => CreateFirmScreen(),
              '/verify': (context) => VerificationContainer(),
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

class _LifecycleWatcherState extends State<LifecycleWatcher>
    with WidgetsBindingObserver {
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
      _checkAndStartSession();
    } else if (state == AppLifecycleState.paused) {
      CloudSyncService().setAppBackgrounded();
    }
  }

  /// Start session monitoring if user is logged in
  Future<void> _checkAndStartSession() async {
    final sp = await SharedPreferences.getInstance();
    final hasToken = sp.getString('jwt_token') != null;
    if (hasToken) {
      SessionService.startSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkAndStartSession(); // Also check on initial build
    return widget.child;
  }
}

class VerificationContainer extends StatelessWidget {
  const VerificationContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI Verification (Dynamic Width)')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('Testing Dynamic Width (90% of screen) + Single Line'),
              const SizedBox(height: 20),
              DishRowItem(
                dish: {'name': 'Biryani', 'rate': 250, 'pax': 10, 'cost': 2500},
                suggestions: const [
                  {
                    'id': 1,
                    'name':
                        'Chicken Biryani Special Edition with Very Long Name That Should Truncate',
                    'rate': 300
                  },
                  {
                    'id': 2,
                    'name': 'Mutton Biryani Deluxe Large Portion',
                    'rate': 500
                  },
                  {
                    'id': 3,
                    'name': 'Veg Biryani Family Pack Extra Spicy',
                    'rate': 200
                  },
                  {'id': 4, 'name': 'Short Name', 'rate': 350},
                ],
                category: 'Main Course',
                index: 0,
                totalPax: 10,
                parentSetState: (fn) => fn(),
                recalculateTotals: () {},
                onDelete: (idx) {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebUpdateWrapper extends StatefulWidget {
  final Widget child;
  const WebUpdateWrapper({super.key, required this.child});

  @override
  State<WebUpdateWrapper> createState() => _WebUpdateWrapperState();
}

class _WebUpdateWrapperState extends State<WebUpdateWrapper> {
  bool _showUpdateBanner = false;

  @override
  void initState() {
    super.initState();
    WebUpdateService().updateStream.listen((available) {
      if (mounted) {
        setState(() => _showUpdateBanner = available);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showUpdateBanner)
          Material(
            color: Colors.orange,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.update, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'A new version is available!',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => WebUpdateService().forceRefresh(),
                      child: const Text('REFRESH NOW',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
