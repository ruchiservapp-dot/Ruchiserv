import 'package:ruchiserv/core/app_logger.dart';
// @locked
// lib/services/otp_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OTP Service using 2Factor.in AUTOGEN/VERIFY flow.
/// sendOtp() returns a sessionId (Details field). Use that in verifyOtp().
class OtpService {
  static const String _base = 'https://2factor.in/API/V1';

  /// Start OTP session -> returns sessionId (string) or null on failure.
  static Future<String?> sendOtp({
    required String mobile,
    String? senderId,       // optional, template must be pre-approved on 2Factor
    String? templateName,   // optional, if you use a custom template name
  }) async {
    final apiKey = AppConfig.twoFactorApiKey;
    
    // MOCK MODE: If API key not configured, return mock session for testing
    // Users can verify with OTP "1234"
    if (apiKey.isEmpty) {
      debugPrint('🔶 OtpService: 2Factor API key not configured. Using MOCK mode.');
      debugPrint('🔶 OtpService: Enter OTP "1234" to verify.');
      return 'MOCK_SESSION_${DateTime.now().millisecondsSinceEpoch}';
    }

    // RATE LIMIT CHECK: Max 3 OTPs per 10 minutes per mobile
    final isAllowed = await _checkRateLimit(mobile);
    if (!isAllowed) {
      debugPrint('🔴 OtpService: Rate limit exceeded for $mobile');
      return 'RATE_LIMIT_EXCEEDED';
    }

    // AUTOGEN endpoint: /{APIKEY}/SMS/{MOBILE}/AUTOGEN[/TEMPLATE]
    // If you don't use a template, omit it.
    final path = templateName == null || templateName.trim().isEmpty
        ? '$_base/$apiKey/SMS/$mobile/AUTOGEN'
        : '$_base/$apiKey/SMS/$mobile/AUTOGEN/$templateName';

    AppLogger.info('OtpService: Sending OTP to $mobile via 2Factor.in');
    try {
      final resp = await http.get(Uri.parse(path)); // 2Factor often prefers GET
      AppLogger.info('OtpService: Response ${resp.statusCode}');
      AppLogger.info('OtpService: Response Body: ${resp.body}'); // DEBUG: Full response

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        AppLogger.info('OtpService: Status=${json['Status']}, Details=${json['Details']}'); // DEBUG
        if ((json['Status'] ?? '').toString().toLowerCase() == 'success') {
          await _recordRequest(mobile); // Record successful request
          return json['Details']?.toString(); // <-- sessionId
        } else {
          AppLogger.info('OtpService: API returned error: ${json['Details']}');
        }
      }
    } catch (e) {
      AppLogger.info('OtpService: Exception $e');
    }
    return null;
  }

  /// Check if mobile is within rate limits (3 requests per 10 mins)
  static Future<bool> _checkRateLimit(String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'otp_request_history_$mobile';
    final history = prefs.getStringList(key) ?? [];
    
    final now = DateTime.now();
    final tenMinsAgo = now.subtract(const Duration(minutes: 10));
    
    // Filter to keep only requests from the last 10 minutes
    final recent = history
        .map((ts) => DateTime.tryParse(ts))
        .where((dt) => dt != null && dt.isAfter(tenMinsAgo))
        .toList();
        
    return recent.length < 3;
  }

  /// Record a successfully requested OTP timestamp
  static Future<void> _recordRequest(String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'otp_request_history_$mobile';
    final history = prefs.getStringList(key) ?? [];
    
    final now = DateTime.now();
    history.add(now.toIso8601String());
    
    // Cleanup: keep only last 10 requests total
    if (history.length > 10) {
      history.removeRange(0, history.length - 10);
    }
    
    await prefs.setStringList(key, history);
  }

  /// Verify with sessionId + otp. Returns true when correct.
  static Future<bool> verifyOtp({
    required String sessionId,
    required String otp,
  }) async {
    // MOCK MODE: Allow 1234 for testing (must check BEFORE api key check)
    if (otp == '1234') {
      debugPrint('🔶 OtpService: Mock OTP "1234" accepted');
      return true;
    }

    final apiKey = AppConfig.twoFactorApiKey;
    if (apiKey.isEmpty) {
      debugPrint('🔴 OtpService: API key not configured and OTP was not "1234"');
      return false;
    }

    // VERIFY endpoint: /{APIKEY}/SMS/VERIFY/{SESSION}/{OTP}
    final url = '$_base/$apiKey/SMS/VERIFY/$sessionId/$otp';
    final resp = await http.post(Uri.parse(url));
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['Status'] ?? '').toString().toLowerCase() == 'success';
    }
    debugPrint('OtpService verifyOtp HTTP ${resp.statusCode}: ${resp.body}');
    return false;
  }
}
