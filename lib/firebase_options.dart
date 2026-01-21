// File generated manually based on user input
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAEXM6LO5S9Ar0kWa43KrfvRiDBnSfZwfo",
    authDomain: "ruchiserv-kitchen-e26d4.firebaseapp.com",
    projectId: "ruchiserv-kitchen-e26d4",
    storageBucket: "ruchiserv-kitchen-e26d4.firebasestorage.app",
    messagingSenderId: "742769773860",
    appId: "1:742769773860:web:85457eb60e8376f2aaf7b1",
    measurementId: "G-08PPTD6D45",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDkBlF0sSYaKSCEhq6xgm9JfLjZgI_MiKs",
    appId: "1:742769773860:android:c6f83bf794b7e75faaf7b1",
    messagingSenderId: "742769773860",
    projectId: "ruchiserv-kitchen-e26d4",
    storageBucket: "ruchiserv-kitchen-e26d4.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyAAJ7kIkLTLR5FZOhhk_7RyblP7n9raxFg",
    appId: "1:742769773860:ios:e77ce20050b1ec82aaf7b1",
    messagingSenderId: "742769773860",
    projectId: "ruchiserv-kitchen-e26d4",
    storageBucket: "ruchiserv-kitchen-e26d4.firebasestorage.app",
    iosBundleId: "com.example.ruchiserv",
  );

  // macOS uses the same credentials as iOS (Apple ecosystem)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyAAJ7kIkLTLR5FZOhhk_7RyblP7n9raxFg",
    appId: "1:742769773860:ios:e77ce20050b1ec82aaf7b1",
    messagingSenderId: "742769773860",
    projectId: "ruchiserv-kitchen-e26d4",
    storageBucket: "ruchiserv-kitchen-e26d4.firebasestorage.app",
    iosBundleId: "com.example.ruchiserv",
  );
}
