import 'package:flutter_test/flutter_test.dart';
import 'package:ruchiserv/db/aws/aws_api.dart';

void main() {
  test('Check AWS User Sync', () async {
    const firmId = 'RUCHIOW1D'; 
    const altFirmId = 'RUCHOW1D'; 

    print('🔍 Checking AWS for main Firm: $firmId');
    await _checkFirm(firmId);

    print('\n🔍 Checking AWS for alternative Firm: $altFirmId');
    await _checkFirm(altFirmId);
  });
}

Future<void> _checkFirm(String firmId) async {
    final targetMobile = '1122334455';
    try {
      print('--- 🔍 Deep Scan for PK: $firmId ---');
      // Query purely by PK to see EVERYTHING
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
         print('❌ ABSOLUTELY NO DATA found for PK: $firmId');
      } else {
         print('✅ FOUND ${items.length} items for $firmId.');
         
         bool found = false;
         for (var item in items) {
           final sk = item['sk'] ?? 'NO_SK';
           final role = item['role'] ?? item['table_name'] ?? 'Unknown';
           
           // Check if this item is related to our target mobile
           if (sk.toString().contains(targetMobile) || item['mobile'] == targetMobile) {
             print('   ****** FOUND TARGET ******');
             print('   - SK: $sk');
             print('   - Role: $role');
             print('   - Mobile: ${item['mobile']}');
             print('   - Data: $item');
             found = true;
           }
         }
         
         if (!found) {
           print('❌ Target Driver $targetMobile NOT found in $firmId');
         }
      }
    } catch (e) {
      print('❌ Exception checking $firmId: $e');
    }
}
