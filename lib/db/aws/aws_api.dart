import 'dart:convert';
import 'package:http/http.dart' as http;

/// Minimal API client for your API Gateway (adjust base/stage).
class AwsApi {
  // ✅ Set your base + stage
  static const String _baseUrl = 'https://zgcy1tisjc.execute-api.ap-south-1.amazonaws.com/prod';
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
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path).replace(queryParameters: query);
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> put({
    required String path,
    required Map<String, dynamic> body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path).replace(queryParameters: query);
    final res = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> delete({
    required String path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path).replace(queryParameters: query);
    final res = await http.delete(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(res);
  }

  /// Wrapper for the single-lambda pattern
  static Future<Map<String, dynamic>> callDbHandler({
    required String method,
    required String table,
    Map<String, dynamic>? data,
    Map<String, dynamic>? filters,
  }) async {
    return post(
      path: '/dbhandler',
      body: {
        'method': method,
        'table': table,
        'data': data,
        'filters': filters,
      },
    );
  }

  /// COMPLIANCE: Rule C.4 - Offload to SQS
  static Future<Map<String, dynamic>> pushToQueue({
    required Map<String, dynamic> payload,
  }) async {
    // Real integration: POST to Lambda Function URL (Producer)
    const functionUrl = 'https://ajajqugtitbljslq4kvfs33rcy0njifc.lambda-url.ap-south-1.on.aws/';
    
    try {
      final res = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      return _decode(res);
    } catch (e) {
      print('🔴 [SQS Error] Failed to push to queue: $e');
      return {
        'status': 'error',
        'message': 'Failed to queue notification: $e',
      };
    }
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
