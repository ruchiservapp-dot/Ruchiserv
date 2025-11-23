// lib/db/aws/aws_config.dart
import 'dart:core';

/// Central place for all AWS URLs & paths.
/// We keep it flexible so you can change stage or paths later without touching call sites.
class AwsConfig {
  /// Your API Gateway base URL (no trailing slash)
  static const String baseUrl = 'https://42x75cturc.execute-api.ap-south-1.amazonaws.com';

  /// API Gateway stage. If you don’t use stages, set this to '' (empty).
  static const String stage = 'prod';

  /// Single universal DB handler route (Lambda) for CREATE/READ/UPDATE/DELETE.
  /// If your route name differs, change it here only.
  static const String dbHandlerPath = '/dbhandler';

  /// External REST-style routes (OTP, WhatsApp, Billing, etc.)
  static const String otpSendPath = '/otp/send';
  static const String otpVerifyPath = '/otp/verify';
  static const String whatsappOrderConfirmPath = '/whatsapp/order-confirmation';

  /// Build a full Uri by joining base + optional stage + path.
  /// - path should start with '/' (e.g. '/otp/send')
  /// - query can be null
  static Uri buildUri(String path, {Map<String, dynamic>? query}) {
    final String stagePart = (stage.isEmpty) ? '' : '/$stage';
    final String full = '$baseUrl$stagePart$path';
    return Uri.parse(full).replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));
  }

  /// Convenience getters
  static Uri get dbHandlerUri => buildUri(dbHandlerPath);
  static Uri get otpSendUri => buildUri(otpSendPath);
  static Uri get otpVerifyUri => buildUri(otpVerifyPath);
  static Uri get whatsappOrderConfirmUri => buildUri(whatsappOrderConfirmPath);
}
