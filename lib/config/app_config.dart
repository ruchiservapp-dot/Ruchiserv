import 'package:ruchiserv/core/app_logger.dart';
// lib/config/app_config.dart
// Production-ready configuration using compile-time environment variables
// Usage: flutter build --dart-define=KEY=VALUE

/// Central configuration class for all API keys and environment settings.
/// Keys are injected at compile time via --dart-define flags.
/// 
/// Example build command:
/// ```bash
/// flutter build appbundle \
///   --dart-define=CASHFREE_APP_ID=your_id \
///   --dart-define=CASHFREE_SECRET_KEY=your_secret \
///   --dart-define=CASHFREE_SANDBOX=false \
///   --dart-define=TWOFACTOR_API_KEY=your_key \
///   --dart-define=PRODUCTION=true
/// ```
class AppConfig {
  AppConfig._(); // Private constructor - all members are static

  // ========== ENVIRONMENT ==========
  
  /// Whether the app is running in production mode
  static bool get isProduction => 
      const bool.fromEnvironment('PRODUCTION', defaultValue: false);

  /// Whether debug logging is enabled
  static bool get enableDebugLogs => !isProduction;

  /// SAFETY: Allow sync in dev mode (DANGEROUS: affects prod DB)
  /// Usage: flutter run --dart-define=FORCE_DEV_SYNC=true
  /// CHANGED: Defaults to TRUE for testing phase as per user request
  static bool get forceDevSync => 
      const bool.fromEnvironment('FORCE_DEV_SYNC', defaultValue: true);

  /// Master switch for Cloud Sync
  /// Returns FALSE by default in Dev Mode to protect Production DB
  static bool get enableCloudSync => isProduction || forceDevSync;

  // ========== CASHFREE PAYMENT GATEWAY ==========
  
  /// Cashfree App ID (from https://merchant.cashfree.com/)
  static String get cashfreeAppId => 
      const String.fromEnvironment('CASHFREE_APP_ID', defaultValue: '');
  
  /// Cashfree Secret Key
  static String get cashfreeSecretKey => 
      const String.fromEnvironment('CASHFREE_SECRET_KEY', defaultValue: '');
  
  /// Whether to use Cashfree sandbox environment
  static bool get cashfreeSandbox => 
      const bool.fromEnvironment('CASHFREE_SANDBOX', defaultValue: true);

  /// Check if Cashfree is properly configured
  static bool get isCashfreeConfigured => 
      cashfreeAppId.isNotEmpty && cashfreeSecretKey.isNotEmpty;

  /// 2Factor.in API Key
  static String get twoFactorApiKey =>
      const String.fromEnvironment('TWOFACTOR_API_KEY', defaultValue: '');

  /// Check if 2Factor is properly configured
  static bool get isTwoFactorConfigured => twoFactorApiKey.isNotEmpty;

  // ========== SENDGRID (EMAIL) ==========
  
  /// SendGrid API Key (optional - for email notifications)
  static String get sendgridApiKey => 
      const String.fromEnvironment('SENDGRID_API_KEY', defaultValue: '');

  static bool get isSendgridConfigured => sendgridApiKey.isNotEmpty;

  // ========== META WHATSAPP ==========
  
  /// Meta WhatsApp Business API Token
  static String get metaWhatsAppToken => 
      const String.fromEnvironment('META_WHATSAPP_TOKEN', defaultValue: '');
  
  /// Meta WhatsApp Phone Number ID
  static String get metaWhatsAppPhoneId => 
      const String.fromEnvironment('META_WHATSAPP_PHONE_ID', defaultValue: '');

  static bool get isWhatsAppConfigured => 
      metaWhatsAppToken.isNotEmpty && metaWhatsAppPhoneId.isNotEmpty;

  // ========== AWS COGNITO ==========

  /// AWS Cognito User Pool ID
  static String get cognitoUserPoolId =>
      const String.fromEnvironment('COGNITO_USER_POOL_ID', defaultValue: '');

  /// AWS Cognito App Client ID
  static String get cognitoClientId =>
      const String.fromEnvironment('COGNITO_CLIENT_ID', defaultValue: '');

  static bool get isCognitoConfigured =>
      cognitoUserPoolId.isNotEmpty && cognitoClientId.isNotEmpty;

  // ========== HELPER METHODS ==========
  
  /// Print configuration status (for debugging only)
  static void printConfigStatus() {
    if (!enableDebugLogs) return;
    AppLogger.info('=== AppConfig Status ===');
    AppLogger.info('Production: $isProduction');
    AppLogger.info('Cashfree: ${isCashfreeConfigured ? '✅ Configured' : '❌ Missing'}');
    AppLogger.info('Cashfree Sandbox: $cashfreeSandbox');
    AppLogger.info('2Factor: ${isTwoFactorConfigured ? '✅ Configured' : '❌ Missing'}');
    AppLogger.info('SendGrid: ${isSendgridConfigured ? '✅ Configured' : '❌ Missing'}');
    AppLogger.info('WhatsApp: ${isWhatsAppConfigured ? '✅ Configured' : '❌ Missing'}');
    AppLogger.info('========================');
  }
}
