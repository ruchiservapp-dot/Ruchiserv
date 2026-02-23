import 'package:ruchiserv/core/app_logger.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackingApiService {
  // Use the same production endpoint
  static const String _baseUrl = 'https://do3uf8e3w6.execute-api.ap-south-1.amazonaws.com';
  static const String _stage = 'prod';

  static Uri _uri(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_baseUrl/$_stage/$clean'); 
  }

  static Future<Map<String, dynamic>> post({
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    AppLogger.info('🚀 Tracking API Request: $uri');
    
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body ?? {}),
      );
      return _decode(res);
    } catch (e) {
      AppLogger.info('🔴 API Error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      if (res.body.isEmpty) return {};
      final decoded = jsonDecode(res.body);
      
      // Handle the case where Lambda returns a nested 'body' string (common in Proxy integration)
      if (decoded is Map<String, dynamic> && decoded.containsKey('body') && decoded['body'] is String) {
          return jsonDecode(decoded['body']);
      }

      return decoded is Map<String, dynamic> ? decoded : {'Items': decoded};
    } catch (e) {
      return {'status': 'error', 'message': 'Decode failed: $e. Body: ${res.body}'};
    }
  }
}
