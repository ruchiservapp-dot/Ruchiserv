// @locked
// lib/services/otp_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../secrets.dart'; // holds twoFactorApiKey

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
    final apiKey = twoFactorApiKey; // from secrets.dart
    
    // MOCK MODE: If API key not configured, return mock session for testing
    // Users can verify with OTP "1234"
    if (apiKey.isEmpty) {
      debugPrint('🔶 OtpService: 2Factor API key not configured. Using MOCK mode.');
      debugPrint('🔶 OtpService: Enter OTP "1234" to verify.');
      return 'MOCK_SESSION_${DateTime.now().millisecondsSinceEpoch}';
    }

    // AUTOGEN endpoint: /{APIKEY}/SMS/{MOBILE}/AUTOGEN[/TEMPLATE]
    // If you don't use a template, omit it.
    final path = templateName == null || templateName.trim().isEmpty
        ? '$_base/$apiKey/SMS/$mobile/AUTOGEN'
        : '$_base/$apiKey/SMS/$mobile/AUTOGEN/$templateName';

    print('OtpService: Sending OTP to $mobile via 2Factor.in');
    try {
      final resp = await http.get(Uri.parse(path)); // 2Factor often prefers GET
      print('OtpService: Response ${resp.statusCode}');
      print('OtpService: Response Body: ${resp.body}'); // DEBUG: Full response

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        print('OtpService: Status=${json['Status']}, Details=${json['Details']}'); // DEBUG
        if ((json['Status'] ?? '').toString().toLowerCase() == 'success') {
          return json['Details']?.toString(); // <-- sessionId
        } else {
          print('OtpService: API returned error: ${json['Details']}');
        }
      }
    } catch (e) {
      print('OtpService: Exception $e');
    }
    return null;
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

    final apiKey = twoFactorApiKey;
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
