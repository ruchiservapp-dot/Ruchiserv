import 'package:ruchiserv/core/app_logger.dart';
import '../db/aws/aws_api.dart';

/// Email Notification Service (Real Implementation via SES)
class EmailService {
  
  /// Send Order Confirmation Email
  /// This uses the transactional template on the backend.
  static Future<bool> sendOrderConfirmation({
    required Map<String, dynamic> orderData,
    required List<Map<String, dynamic>> dishes,
  }) async {
    final toEmail = orderData['email'];
    if (toEmail == null || toEmail.toString().isEmpty) {
      AppLogger.info('🚫 Email skipped: No customer email provided');
      return false;
    }

    AppLogger.info('📧 [EMAIL] Sending order confirmation to: $toEmail');

    try {
      final payload = {
        'type': 'ORDER',
        'to': toEmail,
        'data': {
          'firmId': orderData['firmId'],
          'order': orderData,
          'dishes': dishes,
        }
      };

      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'messaging/transactional/send',
        firmId: orderData['firmId'],
        data: payload,
      );

      if (resp['error'] != null) {
        AppLogger.error('❌ Email Backend Error: ${resp['error']}');
        return false;
      }
      
      AppLogger.success('✅ Email Sent Successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Email Service Error: $e');
      return false;
    }
  }

  /// Send Password Reset Email
  static Future<bool> sendPasswordResetEmail({
    required String firmId,
    required String toEmail,
    required String resetCode,
  }) async {
    AppLogger.info('📧 [EMAIL] Sending password reset to: $toEmail');
    
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'messaging/email/send',
        firmId: firmId,
        data: {
          'to': toEmail,
          'subject': 'RuchiServ Password Reset',
          'body': 'Your password reset code is: $resetCode\n\nIf you did not request this, please ignore this email.',
          'html_body': '<h2>Password Reset Request</h2><p>Your password reset code is: <strong>$resetCode</strong></p><p>If you did not request this, please ignore this email.</p>',
        },
      );

      if (resp['error'] != null) {
        AppLogger.error('❌ Password Reset Email Error: ${resp['error']}');
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.error('❌ Password Reset Email Exception: $e');
      return false;
    }
  }

  /// Send Invoice Email
  static Future<bool> sendInvoice({
    required String firmId,
    required String toEmail,
    required String invoiceNumber,
    required String invoiceData, // Can be HTML content or link
  }) async {
    AppLogger.info('📧 [EMAIL] Sending invoice to: $toEmail');
    
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'messaging/email/send',
        firmId: firmId,
        data: {
          'to': toEmail,
          'subject': 'Invoice #$invoiceNumber from RuchiServ',
          'body': 'Please find your invoice details below:\n\n$invoiceData',
          'html_body': invoiceData.contains('<') ? invoiceData : null,
        },
      );

      if (resp['error'] != null) {
        AppLogger.error('❌ Invoice Email Error: ${resp['error']}');
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.error('❌ Invoice Email Exception: $e');
      return false;
    }
  }
}
