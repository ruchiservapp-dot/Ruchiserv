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
    if (apiKey.isEmpty) {
      debugPrint('OtpService: missing 2Factor API key');
      return null;
    }

    // AUTOGEN endpoint: /{APIKEY}/SMS/{MOBILE}/AUTOGEN[/TEMPLATE]
    // If you don’t use a template, omit it.
    final path = templateName == null || templateName.trim().isEmpty
        ? '$_base/$apiKey/SMS/$mobile/AUTOGEN'
        : '$_base/$apiKey/SMS/$mobile/AUTOGEN/$templateName';

    final resp = await http.post(Uri.parse(path));
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if ((json['Status'] ?? '').toString().toLowerCase() == 'success') {
        return json['Details']?.toString(); // <-- sessionId
      }
      debugPrint('OtpService sendOtp failed: ${resp.body}');
    } else {
      debugPrint('OtpService sendOtp HTTP ${resp.statusCode}: ${resp.body}');
    }
    return null;
    }

  /// Verify with sessionId + otp. Returns true when correct.
  static Future<bool> verifyOtp({
    required String sessionId,
    required String otp,
  }) async {
    final apiKey = twoFactorApiKey;
    if (apiKey.isEmpty) return false;

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
