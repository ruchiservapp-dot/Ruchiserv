// lib/secrets.dart
// ⚠️ DEPRECATED: This file is kept for backward compatibility only.
// All new code should use AppConfig from lib/config/app_config.dart
// 
// For production builds, use --dart-define flags:
// flutter build appbundle --dart-define=CASHFREE_APP_ID=xxx ...
// 
// See .env.example for all available configuration options.

import 'config/app_config.dart';

/// @deprecated Use [AppConfig.twoFactorApiKey] instead
String get twoFactorApiKey => AppConfig.twoFactorApiKey;

/// @deprecated Use [AppConfig.cashfreeAppId] instead
String get cashfreeAppId => AppConfig.cashfreeAppId;

/// @deprecated Use [AppConfig.cashfreeSecretKey] instead
String get cashfreeSecretKey => AppConfig.cashfreeSecretKey;

/// @deprecated Use [AppConfig.cashfreeSandbox] instead
bool get cashfreeSandboxMode => AppConfig.cashfreeSandbox;

/// @deprecated Use [AppConfig.sendgridApiKey] instead
String get sendgridApiKey => AppConfig.sendgridApiKey;

/// @deprecated Use [AppConfig.metaWhatsAppToken] instead
String get metaWhatsAppToken => AppConfig.metaWhatsAppToken;

/// @deprecated Use [AppConfig.metaWhatsAppPhoneId] instead
String get metaWhatsAppPhoneId => AppConfig.metaWhatsAppPhoneId;

// Twilio is no longer used - removed
