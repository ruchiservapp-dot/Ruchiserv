import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final body = {
    'method': 'GET',
    'table': 'ruchiserv_data',
    'data': null,
    'filters': {
      'pk': 'RUCHV4CT',
      'sk_prefix': 'users#'
    },
    'firmId': 'RUCHV4CT'
  };
  
  print('Sending: ${jsonEncode(body)}');
  
  final res = await http.post(
    Uri.parse('https://do3uf8e3w6.execute-api.ap-south-1.amazonaws.com/prod/dbhandler'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  
  print('Response: ${res.statusCode} ${res.body}');
}
