import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../db/aws/aws_api.dart';
import '../db/database_helper.dart';

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
      print("✅ Firebase initialized successfully");
    } catch (e) {
      print("⚠️ Firebase initialization failed or already initialized: $e");
    }

    // 2. Request Permissions
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('User granted notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      print('⚠️ Failed to request notification permission: $e');
    }

    // 3. Get FCM Token
    try {
      final token = await _messaging.getToken();
      print("🔥 FCM Token: $token");
      if (token != null) {
        await saveTokenToBackend(token);
      }
    } catch (e) {
      print("❌ Failed to get FCM token: $e");
    }

    // 3a. Token Refresh Listener
    _messaging.onTokenRefresh.listen((newToken) {
      print("🔄 FCM Token Refreshed: $newToken");
      saveTokenToBackend(newToken);
    });

    // 4. Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground Message: ${message.notification?.title}');
      
      // Show local notification if needed
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // 5. Background Message Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Display a local notification when app is in foreground
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    // Basic setup for local notifications usually requires more init in main.dart
    // For now, we just print, but this is where you'd show a dialog or snackbar
    print("🔔 Notification: ${message.notification?.title} - ${message.notification?.body}");
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
        print("ℹ️ FCM: No user logged in yet, skipping token save.");
        return;
      }



      print("🚀 FCM: Updating local user with new token for $mobile...");
      
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByMobile(firmId, mobile);
      
      if (user != null) {
        final updatedUser = Map<String, dynamic>.from(user);
        updatedUser['fcmToken'] = token;
        updatedUser['updatedAt'] = DateTime.now().toIso8601String();
        
        await dbHelper.updateUser(updatedUser);
        print("✅ FCM Token updated locally. Syncing to cloud via queue...");
      } else {
        print("⚠️ FCM: User not found in local DB. Cannot update token.");
      }
    } catch (e) {
      print("❌ Error saving FCM token to backend: $e");
    }
  }
}

// Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("🌙 Background Message: ${message.messageId}");
}
