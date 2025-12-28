import 'dart:io';
import 'package:http/http.dart' as http;

/// A Simple CORS Proxy to bypass AWS Gateway restrictions on Web.
/// Listens on localhost:9090, forwards to AWS, and adds Access-Control-Allow-Origin.
Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 9090);
  print('🌉 CORS Bridge Active on http://localhost:9090');
  print('🚀 Routing Web Traffic -> AWS...');

  await for (HttpRequest olderReq in server) {
    try {
      if (olderReq.method == 'OPTIONS') {
        _addCorsHeaders(olderReq.response);
        olderReq.response.statusCode = HttpStatus.ok;
        olderReq.response.close();
        continue;
      }

      final awsUrl = Uri.parse('https://do3uf8e3w6.execute-api.ap-south-1.amazonaws.com/prod${olderReq.uri.path}');
      
      // Forward Request
      final client = http.Client();
      final bodyBytes = await olderReq.toList();
      final body = bodyBytes.isNotEmpty ? bodyBytes.first : <int>[];

      final proxyReq = http.Request(olderReq.method, awsUrl);
      proxyReq.headers['Content-Type'] = 'application/json'; // AWS requires this
      if (body.isNotEmpty) {
        proxyReq.bodyBytes = body;
      }

      final proxyResp = await client.send(proxyReq);
      final respBody = await proxyResp.stream.bytesToString();

      // Send Response back to App
      _addCorsHeaders(olderReq.response);
      olderReq.response.statusCode = proxyResp.statusCode;
      olderReq.response.write(respBody);
      await olderReq.response.close();
      
      print('✅ [${olderReq.method}] ${olderReq.uri.path} -> ${proxyResp.statusCode}');
    } catch (e) {
      print('🔴 Proxy Error: $e');
      olderReq.response.statusCode = 500;
      olderReq.response.write('{"error": "$e"}');
      olderReq.response.close();
    }
  }
}

void _addCorsHeaders(HttpResponse response) {
  response.headers.add('Access-Control-Allow-Origin', '*');
  response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
  response.headers.add('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
}
