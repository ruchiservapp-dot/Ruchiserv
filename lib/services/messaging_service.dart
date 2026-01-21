import 'dart:convert';
import '../db/aws/aws_api.dart';
import '../db/database_helper.dart';

class MessagingService {
  // Singleton
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  /// Send Order Confirmation Email (Fire & Forget)
  Future<void> sendOrderConfirmation(Map<String, dynamic> order, List<Map<String, dynamic>> dishes) async {
    try {
      final email = order['email'];
      if (email == null || email.toString().isEmpty) {
        print('🚫 Email skipped: No customer email provided');
        return;
      }

      print('📧 Triggering Order Confirmation Email for Order #${order['id']}...');

      final payload = {
        'type': 'ORDER',
        'to': email,
        'data': {
          'firmId': order['firmId'],
          'order': order,
          'dishes': dishes,
        }
      };

      // Call Lambda directly
      await AwsApi.callDbHandler(
        method: 'POST',
        table: 'messaging/transactional/send',
        data: payload,
      ).then((resp) {
        if (resp['error'] != null) {
          print('❌ Email Error: ${resp['error']}');
        } else {
          print('✅ Email Queued Successfully');
        }
      });

    } catch (e) {
      print('❌ Email Exception: $e');
    }
  }

  /// Send Purchase Order Email (Fire & Forget)
  Future<void> sendPurchaseOrder(Map<String, dynamic> po) async {
    try {
      // Fetch Vendor Email first
      final db = DatabaseHelper();
      // Assuming 'vendorDetails' or query suppliers table. 
      // For now, if PO map has email, use it. If not, try to fetch.
      // NOTE: RuchiServ PO structure might purely rely on ID linkage.
      // Let's assume we need to pass vendor details or fetch them.
      
      // OPTIMIZATION: Does PO map have vendor email?
      // If not, we might need to fetch supplier.
      // Let's act defensively.
      
      String? vendorEmail = po['vendorEmail'];
      if (vendorEmail == null) {
          // Try to get from Supplier DB if supplierId present
          if (po['supplierId'] != null) {
             final supplier = await db.getSupplierById(po['supplierId']);
             vendorEmail = supplier?['email'];
          }
      }

      if (vendorEmail == null || vendorEmail.isEmpty) {
        print('🚫 PO Email skipped: No vendor email found');
        return;
      }

      // Fetch Items
      final items = await db.getPoItems(po['id']);

      print('📧 Triggering PO Email #${po['poNumber']}...');

      final payload = {
        'type': 'PO',
        'to': vendorEmail,
        'data': {
          'firmId': po['firmId'],
          'po': po,
          'items': items,
        }
      };

      await AwsApi.callDbHandler(
        method: 'POST',
        table: 'messaging/transactional/send',
        data: payload,
      );

    } catch (e) {
      print('❌ PO Email Exception: $e');
    }
  }
}
