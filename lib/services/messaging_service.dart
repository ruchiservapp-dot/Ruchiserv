import 'email_service.dart';
import 'package:ruchiserv/core/app_logger.dart';
import 'dart:convert';
import '../db/aws/aws_api.dart';
import '../db/database_helper.dart';

class MessagingService {
  // Singleton
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  /// Send Order Confirmation Email (Fire & Forget)
  /// Send Order Confirmation Email (Fire & Forget)
  Future<void> sendOrderConfirmation(Map<String, dynamic> order, List<Map<String, dynamic>> dishes) async {
    // Delegate to centralized EmailService
    // We ignore the boolean return since this is fire-and-forget for the caller
    await EmailService.sendOrderConfirmation(
      orderData: order, 
      dishes: dishes
    );
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
        AppLogger.info('🚫 PO Email skipped: No vendor email found');
        return;
      }

      // Fetch Items
      final items = await db.getPoItems(po['id']);

      AppLogger.info('📧 Triggering PO Email #${po['poNumber']}...');

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
        firmId: po['firmId'], // Required for Lambda authentication
        data: payload,
      );

    } catch (e) {
      AppLogger.error('❌ PO Email Exception: $e');
    }
  }
}
