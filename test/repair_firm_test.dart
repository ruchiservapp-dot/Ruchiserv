import 'package:flutter_test/flutter_test.dart';
import 'package:ruchiserv/db/aws/aws_api.dart';

void main() {
  test('Repair Firm Metadata', () async {
    const firmId = 'RUCHOW1D'; 
    print('🛠️ Repairing Firm Metadata for: $firmId');
    
    try {
      final firmData = {
        'pk': firmId,
        'sk': 'firms#$firmId',
        'firmId': firmId,
        'firmName': 'RuchiServ Events', // Default name
        'mobile': '9988776655', // Based on the user record found
        'subscriptionStatus': 'ACTIVE',
        'subscriptionTier': 'ENTERPRISE',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'table_name': 'firms',
      };

      final resp = await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'ruchiserv_data',
        firmId: firmId,
        data: firmData,
      );
      
      if (resp['error'] == null) {
        print('✅ Firm record inserted successfully!');
      } else {
        print('❌ Failed to insert firm record: ${resp['error']}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  });
}
