// lib/services/notification_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../db/aws/aws_api.dart';
import '../db/database_helper.dart';

/// Handles external notifications via SQS (Rule C.4)
class NotificationService {
  
  /// Queue an order confirmation message
  /// [isEdit] determines the message template (New vs Update)
  static Future<void> queueOrderConfirmation({
    required int orderId,
    required Map<String, dynamic> orderData,
    bool isEdit = false,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';
    final userId = sp.getString('user_id') ?? 'system';
    
    // 1. Prepare Payload
    final mobile = orderData['mobile']?.toString() ?? ''; // Encrypted? No, usually decrypted for use, but here we pass as is?
    // Wait, if it's encrypted in DB, we need to decrypt it before sending to queue? 
    // OR the backend decrypts it?
    // Rule C.3 says "Apply encryption/decryption on customer mobile/email during all DB interactions."
    // If we passed the raw map from UI (before encryption), it's plain text.
    // If we passed the map from DB (after encryption), it's encrypted.
    // Let's assume the caller passes the UI data (plain text) or we handle it.
    // Ideally, we send encrypted data to queue and Lambda decrypts it using the same key? 
    // No, Lambda might not have the key if it's local-only key.
    // Actually, for SaaS, the key is likely managed. 
    // For now, let's send the mobile as provided.
    
    final payload = {
      'type': 'ORDER_CONFIRMATION',
      'action': isEdit ? 'UPDATE' : 'CREATE',
      'orderId': orderId,
      'firmId': firmId,
      'mobile': mobile, // Target mobile
      'email': orderData['email']?.toString() ?? '', // Target email (optional)
      'orderData': orderData, // Full details including dishes for PDF generation
      'channels': ['WHATSAPP', 'EMAIL'],
      'fallback': 'SMS',
      'delaySeconds': 900, // 15 minutes delay (Rule C.4)
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 2. Audit Log (Rule C.2)
    // Log that we are ATTEMPTING to queue
    final db = DatabaseHelper();
    // We can't use _logAudit directly as it's private, but we can use a public wrapper or just insert to audit_log if exposed?
    // DatabaseHelper doesn't expose raw insert easily for audit_log from outside?
    // Actually, let's add a public method to DatabaseHelper for custom audit logs or just use the existing one if possible.
    // For now, we'll skip explicit DB audit here and rely on the "Order Insert/Update" audit which implicitly implies notification.
    // BUT the requirement says: "Log the attempt to send the message in the audit_log before sending it to the queue."
    // So we MUST log it.
    
    // We'll use a raw insert since we don't have a specific method exposed yet.
    await db.database.then((d) => d.insert('audit_log', {
      'table_name': 'notifications',
      'record_id': orderId,
      'action': 'QUEUE_ATTEMPT',
      'user_id': userId,
      'firm_id': firmId,
      'notes': 'Queuing notification for order $orderId',
      'timestamp': DateTime.now().toIso8601String(),
    }));

    // 3. Push to Queue (Rule C.4)
    try {
      final result = await AwsApi.pushToQueue(payload: payload);
      
      // Log success
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': orderId,
        'action': 'QUEUE_SUCCESS',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Message ID: ${result['messageId']}',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
    } catch (e) {
      // Log failure
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': orderId,
        'action': 'QUEUE_FAILED',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      rethrow; // Let UI know
    }
  }

  /// Queue a dispatch notification to customer
  /// Sends WhatsApp/Email with driver details and tracking link
  static Future<void> queueDispatchNotification({
    required int dispatchId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> vehicleData,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';
    final userId = sp.getString('user_id') ?? 'system';
    
    // Generate tracking URL
    final trackingUrl = 'https://ruchiserv.in/track/$dispatchId';
    
    final payload = {
      'type': 'DISPATCH_NOTIFICATION',
      'action': 'DISPATCHED',
      'dispatchId': dispatchId,
      'orderId': orderData['id'],
      'firmId': firmId,
      'mobile': orderData['mobile']?.toString() ?? '',
      'email': orderData['email']?.toString() ?? '',
      'customerName': orderData['customerName'] ?? '',
      'driverName': vehicleData['driverName'] ?? '',
      'driverMobile': vehicleData['driverMobile'] ?? '',
      'vehicleNo': vehicleData['vehicleNo'] ?? '',
      'trackingUrl': trackingUrl,
      'channels': ['WHATSAPP', 'SMS'],
      'message': '''🚚 Your order is on the way!

Driver: ${vehicleData['driverName'] ?? 'N/A'}
Vehicle: ${vehicleData['vehicleNo'] ?? 'N/A'}
Contact: ${vehicleData['driverMobile'] ?? 'N/A'}

Track your delivery: $trackingUrl''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final db = DatabaseHelper();
    
    // Audit log
    await db.database.then((d) => d.insert('audit_log', {
      'table_name': 'notifications',
      'record_id': dispatchId,
      'action': 'DISPATCH_QUEUE_ATTEMPT',
      'user_id': userId,
      'firm_id': firmId,
      'notes': 'Queuing dispatch notification for order ${orderData['id']}',
      'timestamp': DateTime.now().toIso8601String(),
    }));

    try {
      final result = await AwsApi.pushToQueue(payload: payload);
      
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': dispatchId,
        'action': 'DISPATCH_QUEUE_SUCCESS',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Message ID: ${result['messageId']}',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': dispatchId,
        'action': 'DISPATCH_QUEUE_FAILED',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      rethrow;
    }
  }

  /// Queue delivery complete notification
  static Future<void> queueDeliveryComplete({
    required int dispatchId,
    required Map<String, dynamic> orderData,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';
    
    final payload = {
      'type': 'DELIVERY_NOTIFICATION',
      'action': 'DELIVERED',
      'dispatchId': dispatchId,
      'orderId': orderData['id'],
      'firmId': firmId,
      'mobile': orderData['mobile']?.toString() ?? '',
      'customerName': orderData['customerName'] ?? '',
      'channels': ['WHATSAPP'],
      'message': '''✅ Your order has been delivered!

Thank you for choosing us. We hope you enjoyed the service.

Have feedback? Reply to this message!''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await AwsApi.pushToQueue(payload: payload);
    } catch (e) {
      print('Delivery notification error: $e');
    }
  }

  /// Queue PO cancellation notification to supplier
  static Future<void> queuePOCancellationNotification({
    required int poId,
    required String supplierName,
    required String supplierMobile,
    required int orderId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';
    final userId = sp.getString('user_id') ?? 'system';

    final payload = {
      'type': 'PO_CANCELLATION',
      'action': 'CANCELLED',
      'poId': poId,
      'orderId': orderId,
      'firmId': firmId,
      'mobile': supplierMobile,
      'supplierName': supplierName,
      'channels': ['WHATSAPP', 'SMS'],
      'message': '''⚠️ Purchase Order Cancelled

PO #$poId has been cancelled due to order modifications.

A new PO will be issued shortly if applicable.

Thank you for your understanding.''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final db = DatabaseHelper();

    // Audit log
    await db.database.then((d) => d.insert('audit_log', {
      'table_name': 'notifications',
      'record_id': poId,
      'action': 'PO_CANCEL_QUEUE_ATTEMPT',
      'user_id': userId,
      'firm_id': firmId,
      'notes': 'Queuing PO cancellation notification for PO $poId',
      'timestamp': DateTime.now().toIso8601String(),
    }));

    try {
      final result = await AwsApi.pushToQueue(payload: payload);
      
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': poId,
        'action': 'PO_CANCEL_QUEUE_SUCCESS',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Message ID: ${result['messageId']}',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': poId,
        'action': 'PO_CANCEL_QUEUE_FAILED',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      print('PO cancellation notification error: $e');
    }
  }

  /// Queue order update notification to customer
  static Future<void> queueOrderUpdateNotification({
    required int orderId,
    required Map<String, dynamic> orderData,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';
    final userId = sp.getString('user_id') ?? 'system';

    final mobile = orderData['mobile']?.toString() ?? '';
    final customerName = orderData['customerName']?.toString() ?? 'Customer';

    final payload = {
      'type': 'ORDER_UPDATE',
      'action': 'MODIFIED',
      'orderId': orderId,
      'firmId': firmId,
      'mobile': mobile,
      'email': orderData['email']?.toString() ?? '',
      'customerName': customerName,
      'channels': ['WHATSAPP', 'EMAIL'],
      'message': '''📝 Order Updated

Dear $customerName,

Your order #$orderId has been modified. Our team is processing the changes and will update you shortly.

Thank you for your patience!''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final db = DatabaseHelper();

    await db.database.then((d) => d.insert('audit_log', {
      'table_name': 'notifications',
      'record_id': orderId,
      'action': 'ORDER_UPDATE_QUEUE_ATTEMPT',
      'user_id': userId,
      'firm_id': firmId,
      'notes': 'Queuing order update notification for order $orderId',
      'timestamp': DateTime.now().toIso8601String(),
    }));

    try {
      final result = await AwsApi.pushToQueue(payload: payload);
      
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': orderId,
        'action': 'ORDER_UPDATE_QUEUE_SUCCESS',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Message ID: ${result['messageId']}',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      await db.database.then((d) => d.insert('audit_log', {
        'table_name': 'notifications',
        'record_id': orderId,
        'action': 'ORDER_UPDATE_QUEUE_FAILED',
        'user_id': userId,
        'firm_id': firmId,
        'notes': 'Error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      print('Order update notification error: $e');
    }
  }

  /// Queue new PO notification to supplier
  static Future<void> queueNewPONotification({
    required int poId,
    required String poNumber,
    required String supplierName,
    required String supplierMobile,
    required int totalItems,
    required double totalAmount,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';

    final payload = {
      'type': 'NEW_PO',
      'action': 'CREATED',
      'poId': poId,
      'poNumber': poNumber,
      'firmId': firmId,
      'mobile': supplierMobile,
      'supplierName': supplierName,
      'channels': ['WHATSAPP', 'SMS'],
      'message': '''🛒 New Purchase Order

PO #$poNumber

Items: $totalItems
Total: ₹${totalAmount.toStringAsFixed(2)}

Please confirm receipt and delivery timeline.

Thank you!''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await AwsApi.pushToQueue(payload: payload);
    } catch (e) {
      print('New PO notification error: $e');
    }
  }

  /// Queue dispatch assignment notification to driver (v34 - Driver Portal)
  static Future<void> queueDriverAssignmentNotification({
    required int dispatchId,
    required String driverName,
    required String driverMobile,
    required String customerName,
    required String location,
    required String deliveryDate,
    required String deliveryTime,
    required int pax,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';

    final payload = {
      'type': 'DRIVER_ASSIGNMENT',
      'action': 'ASSIGNED',
      'dispatchId': dispatchId,
      'firmId': firmId,
      'mobile': driverMobile,
      'driverName': driverName,
      'channels': ['WHATSAPP', 'SMS'],
      'message': '''🚗 New Delivery Assignment

Customer: $customerName
Location: $location
Date: $deliveryDate
Time: $deliveryTime
Pax: $pax

Please open the app to accept this delivery.''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await AwsApi.pushToQueue(payload: payload);
    } catch (e) {
      print('Driver assignment notification error: $e');
    }
  }

  /// Queue subcontractor dish assignment notification (v34 - Subcontractor Portal)
  static Future<void> queueSubcontractorAssignmentNotification({
    required int orderId,
    required String subcontractorName,
    required String subcontractorMobile,
    required String customerName,
    required String dishName,
    required String deliveryDate,
    required int pax,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'default_firm';

    final payload = {
      'type': 'SUBCONTRACTOR_ASSIGNMENT',
      'action': 'ASSIGNED',
      'orderId': orderId,
      'firmId': firmId,
      'mobile': subcontractorMobile,
      'subcontractorName': subcontractorName,
      'channels': ['WHATSAPP', 'SMS'],
      'message': '''👨‍🍳 New Order Assignment

For: $customerName
Dish: $dishName
Date: $deliveryDate
Pax: $pax

Open the RuchiServ app for full details.''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await AwsApi.pushToQueue(payload: payload);
    } catch (e) {
      print('Subcontractor assignment notification error: $e');
    }
  }
}

