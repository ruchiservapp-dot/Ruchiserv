
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://do3uf8e3w6.execute-api.ap-south-1.amazonaws.com/prod';
  final firmId = 'RUCHIC5M';
  final mobile = '9400768440'; // From context/history if possible, or I'll check all users

  print('🔍 Checking AWS for Firm: $firmId');

  try {
    // 1. Check Firm
    final firmResp = await http.post(
      Uri.parse('$baseUrl/dbhandler'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'method': 'GET',
        'table': 'ruchiserv_data',
        'firmId': firmId,
        'filters': {
          'pk': firmId,
          'sk': 'firms#$firmId',
        },
      }),
    );
    print('Firm Response: ${firmResp.body}');

    // 2. Check Users for this firm
    final usersResp = await http.post(
      Uri.parse('$baseUrl/dbhandler'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'method': 'GET',
        'table': 'ruchiserv_data',
        'firmId': firmId,
        'filters': {
          'pk': firmId,
          // We can't easily query by SK prefix without a specific sk_op if the lambda supports it
          // But AuthService uses specific sk for login
        },
      }),
    );
    print('Users Response (All for PK): ${usersResp.body}');

    // 5. Check for Orders (Unified & Legacy)
    print('\n📦 Checking for Orders for $firmId...');
    final ordersResp = await http.post(
      Uri.parse('$baseUrl/dbhandler'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'method': 'GET',
        'table': 'ruchiserv_data',
        'firmId': firmId,
        'filters': {
          'pk': firmId,
          'sk_prefix': 'orders#',
        },
      }),
    );
    print('Unified Orders Response: ${ordersResp.body}');

    final legacyOrdersResp = await http.post(
      Uri.parse('$baseUrl/dbhandler'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'method': 'GET',
        'table': 'orders',
        'firmId': firmId,
      }),
    );
    print('Legacy Orders Response: ${legacyOrdersResp.body}');

  } catch (e) {
    print('❌ Error: $e');
  }
}
