import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Minimal API client for your API Gateway (adjust base/stage).
class AwsApi {
  // ✅ New cost-optimized serverless API (Dec 2024)
  static const String _baseUrl = 'https://do3uf8e3w6.execute-api.ap-south-1.amazonaws.com';
  static const String _stage = 'prod';

  /// JWT Token for authentication (Cognito)
  static String? _authToken;

  /// Update the token after login
  static void setAuthToken(String token) {
    _authToken = token;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  static Uri _uri(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    
    // HACK: Use Local Bridge for Web to fix CORS (Only for local development)
    bool useProxy = false; 
    if (!kReleaseMode && useProxy) {
      return Uri.parse('http://localhost:9090/$clean');
    }
    
    return Uri.parse('$_baseUrl/$_stage/$clean'); 
  }

  static Future<Map<String, dynamic>> get({required String path}) async {
    final res = await http.get(_uri(path), headers: _headers);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> post({
    required String path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path).replace(queryParameters: query);
    print('🚀 AWS POST Request: $uri'); // DEBUG
    final res = await http.post(
      uri,
      headers: _headers,
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
      headers: _headers,
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
      headers: _headers,
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
    String? firmId, // NEW: Required for authenticated requests
  }) async {
    return post(
      path: '/dbhandler',
      body: {
        'method': method,
        'table': table,
        'data': data,
        'filters': filters,
        if (firmId != null) 'firmId': firmId, // NEW: Include in body for Lambda auth
      },
    );
  }

  /// Optimized GSI query helper (Phase 2)
  static Future<Map<String, dynamic>> queryGsi({
    required String table,
    required String indexName,
    required String pkValue,
    String? skValue,
    String? skValueEnd,
    String skOp = 'eq',
  }) async {
    return callDbHandler(
      method: 'GET',
      table: table,
      filters: {
        'index_name': indexName,
        'gsi_pk': pkValue,
        if (skValue != null) 'gsi_sk': skValue,
        if (skValueEnd != null) 'gsi_sk_end': skValueEnd,
        if (skValue != null) 'sk_op': skOp,
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
        headers: _headers,
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
    print('📥 AWS Raw Response: "${res.body}" (Status: ${res.statusCode})'); // DEBUG
    try {
      final decoded = jsonDecode(res.body);
      print('🤔 Decoded Type: ${decoded.runtimeType}'); // DEBUG
      
      if (decoded is Map<String, dynamic>) return decoded;
      // Handle List responses (e.g., query results from Lambda)
      if (decoded is List) {
        return {'Items': decoded};
      }
      return {'status': 'error', 'message': 'Invalid JSON format (Expected Map, got ${decoded.runtimeType})'};
    } catch (e) {
      print('🔴 Decode Error Body: "${res.body}"'); // DEBUG
      return {'status': 'error', 'message': 'Decode failed: $e. Body: ${res.body}', 'code': res.statusCode};
    }
  }
}
