import 'package:flutter_test/flutter_test.dart';
import 'package:ruchiserv/db/aws/aws_api.dart';

void main() {
  test('Inspect Firm Record', () async {
    const firmId = 'RUCHOW1D'; 
    print('🔍 Inspecting AWS for Firm: $firmId');
    
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'ruchiserv_data',
        firmId: firmId,
        filters: {
          'pk': firmId,
        },
      );
      
      final items = resp['Items'] as List?;
      if (items == null || items.isEmpty) {
         print('❌ No data found for PK: $firmId');
      } else {
         print('✅ Found ${items.length} items for $firmId.');
         for (var item in items) {
           final sk = item['sk']?.toString() ?? 'NO_SK';
           print('   - SK: $sk');
           if (sk.startsWith('firms#')) {
             print('     🏢 FIRM RECORD FOUND!');
           }
         }
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  });
}
