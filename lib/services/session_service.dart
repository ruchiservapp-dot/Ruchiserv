import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_logger.dart';

/// Manage user session timeout and inactivity
class SessionService {
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kLastUsername = 'last_username';
  
  static const int _timeoutMinutes = 30;
  
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static DateTime? _lastActivity;
  static Timer? _timeoutTimer;
  static bool _isSessionActive = false;

  /// Start monitoring user activity
  static void startSession() {
    if (_isSessionActive) return;
    
    _isSessionActive = true;
    _lastActivity = DateTime.now();
    
    // Check for timeout every minute
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkTimeout();
    });
    
    AppLogger.info('Session monitoring started');
  }

  /// Stop monitoring (e.g. on logout)
  static void stopSession() {
    _isSessionActive = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Record user activity (touch, scroll, keypress)
  static void recordActivity() {
    _lastActivity = DateTime.now();
  }

  /// Check if session expired
  static Future<void> _checkTimeout() async {
    if (!_isSessionActive || _lastActivity == null) return;
    
    final sp = await SharedPreferences.getInstance();
    final role = sp.getString('last_role')?.toUpperCase() ?? 'STAFF';
    
    // Admin/Owner get 6 hours, others get 30 mins
    final int timeout = (role == 'ADMIN' || role == 'OWNER') ? 360 : _timeoutMinutes;
    
    final diff = DateTime.now().difference(_lastActivity!);
    if (diff.inMinutes >= timeout) {
      _handleLogout();
    }
  }

  /// Perform auto-logout
  static Future<void> _handleLogout() async {
    AppLogger.warning('Session timed out after $_timeoutMinutes minutes inactivity');
    stopSession();
    
    // Clear session data but keep firm/username for quick re-login
    final sp = await SharedPreferences.getInstance();
    await sp.remove('jwt_token');
    await sp.remove('user_id');
    
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      // Show session expired dialog and redirect to login
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Session Expired'),
          content: const Text('You have been logged out due to inactivity.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Close dialog
                navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // --- Biometric/Username Helpers ---

  static Future<void> setBiometricEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kBiometricEnabled, enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kBiometricEnabled) ?? false;
  }

  static Future<void> saveLastUsername(String username) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastUsername, username);
  }

  static Future<String?> lastUsername() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLastUsername);
  }
}

/// Widget to wrap the entire app and detect user interactions
class SessionTimeoutListener extends StatelessWidget {
  final Widget child;
  
  const SessionTimeoutListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionService.recordActivity(),
      onPointerMove: (_) => SessionService.recordActivity(),
      onPointerUp: (_) => SessionService.recordActivity(),
      child: child,
    );
  }
}
