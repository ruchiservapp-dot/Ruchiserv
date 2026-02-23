import 'package:ruchiserv/core/app_logger.dart';
// @locked
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../db/aws/aws_api.dart';
import '../db/database_helper.dart';
import 'cloud_sync_service.dart';

// @locked - Core Push-Pull architecture. Do not modify without full understanding.

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Initialize Firebase
    // Uses the generated DefaultFirebaseOptions for Web/Android/iOS
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.info("✅ Firebase initialized successfully");
    } catch (e) {
      AppLogger.info("⚠️ Firebase initialization failed or already initialized: $e");
    }

    // 2. Request Permissions
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.info('User granted notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to request notification permission: $e');
    }

    // 3. Get FCM Token
    try {
      final token = await _messaging.getToken();
      AppLogger.info("🔥 FCM Token: $token");
      if (token != null) {
        await saveTokenToBackend(token);
      }
    } catch (e) {
      AppLogger.info("❌ Failed to get FCM token: $e");
    }

    // 3a. Token Refresh Listener
    _messaging.onTokenRefresh.listen((newToken) {
      AppLogger.info("🔄 FCM Token Refreshed: $newToken");
      saveTokenToBackend(newToken);
    });

    // 4. Foreground Message Handler - PUSH-PULL SYNC TRIGGER
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      AppLogger.info('📩 Foreground Message: ${message.data}');
      
      // Handle SYNC payload from server
      await _handleSyncMessage(message.data);
      
      // Show local notification if needed (for visible notifications)
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // 5. Background Message Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Handle SYNC payloads from the server to trigger real-time data sync
  static Future<void> _handleSyncMessage(Map<String, dynamic> data) async {
    final type = data['type'];
    final table = data['table'];
    
    if (type == 'SYNC' && table != null) {
      AppLogger.info('🔄 Push-Pull: Received SYNC signal for table "$table"');
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final firmId = prefs.getString('last_firm');
        
        if (firmId != null) {
          // Trigger immediate sync for the specified table
          await CloudSyncService().syncTableFromCloud(table, firmId);
          AppLogger.success('✅ Push-Pull: Synced "$table" successfully');
        } else {
          AppLogger.warning('⚠️ Push-Pull: No firm ID, skipping sync');
        }
      } catch (e) {
        AppLogger.error('❌ Push-Pull: Sync failed for "$table": $e');
      }
    }
  }

  /// Display a local notification when app is in foreground
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    // Basic setup for local notifications usually requires more init in main.dart
    // For now, we just print, but this is where you'd show a dialog or snackbar
    AppLogger.info("🔔 Notification: ${message.notification?.title} - ${message.notification?.body}");
  }

  /// Save FCM token to the User table in AWS
  static Future<void> saveTokenToBackend(String token, {String? firmId, String? mobile}) async {
    try {
      if (firmId == null || mobile == null) {
        final sp = await SharedPreferences.getInstance();
        firmId ??= sp.getString('last_firm');
        mobile ??= sp.getString('last_mobile');
      }

      if (firmId == null || mobile == null) {
        AppLogger.info("ℹ️ FCM: No user logged in yet, skipping token save.");
        return;
      }



      AppLogger.info("🚀 FCM: Updating local user with new token for $mobile...");
      
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByMobile(firmId, mobile);
      
      if (user != null) {
        final updatedUser = Map<String, dynamic>.from(user);
        updatedUser['fcmToken'] = token;
        updatedUser['updatedAt'] = DateTime.now().toIso8601String();
        
        await dbHelper.updateUser(updatedUser);
        AppLogger.info("✅ FCM Token updated locally. Syncing to cloud via queue...");
      } else {
        AppLogger.info("⚠️ FCM: User not found in local DB. Cannot update token.");
      }
    } catch (e) {
      AppLogger.info("❌ Error saving FCM token to backend: $e");
    }
  }
}

// Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppLogger.info("🌙 Background Message: ${message.data}");
  
  // Handle SYNC in background as well
  final type = message.data['type'];
  final table = message.data['table'];
  
  if (type == 'SYNC' && table != null) {
    AppLogger.info('🔄 Background Push-Pull: Received SYNC signal for table "$table"');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final firmId = prefs.getString('last_firm');
      
      if (firmId != null) {
        await CloudSyncService().syncTableFromCloud(table, firmId);
        AppLogger.success('✅ Background Push-Pull: Synced "$table" successfully');
      }
    } catch (e) {
      AppLogger.error('❌ Background Push-Pull: Sync failed: $e');
    }
  }
}

