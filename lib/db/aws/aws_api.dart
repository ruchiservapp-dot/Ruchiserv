import 'dart:convert';
import 'package:http/http.dart' as http;

/// Minimal API client for your API Gateway (adjust base/stage).
class AwsApi {
  // ✅ Set your base + stage
  static const String _baseUrl = 'https://42x75cturc.execute-api.ap-south-1.amazonaws.com';
  static const String _stage = 'prod';

  static Uri _uri(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_baseUrl/$_stage/$clean');
  }

  static Future<Map<String, dynamic>> get({required String path}) async {
    final res = await http.get(_uri(path), headers: {'Content-Type': 'application/json'});
    return _decode(res);
  }

  static Future<Map<String, dynamic>> post({
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final res = await http.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final map = jsonDecode(res.body);
      if (map is Map<String, dynamic>) return map;
      return {'status': 'error', 'message': 'Invalid JSON'};
    } catch (_) {
      return {'status': 'error', 'message': 'Decode failed', 'code': res.statusCode};
    }
  }
}
