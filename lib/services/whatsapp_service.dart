import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'pdf_service.dart';
import '../db/aws/aws_api.dart';

/// WhatsApp Service (Secure Backend Integration)
class WhatsAppService {
  
  /// Send template message via Secure Backend
  static Future<bool> sendTemplateMessage({
    required String toNumber,
    required String templateName,
    required String languageCode,
    List<String>? bodyParameters,
  }) async {
    debugPrint('💬 [WhatsApp] Requesting Backend to send "$templateName" to: $toNumber');
    
    try {
      // Build template components
      final components = <Map<String, dynamic>>[];
      if (bodyParameters != null && bodyParameters.isNotEmpty) {
        components.add({
          'type': 'body',
          'parameters': bodyParameters.map((param) => {
            'type': 'text',
            'text': param,
          }).toList(),
        });
      }

      // Call Backend
      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'messaging/whatsapp/send',
        data: {
          'to': toNumber,
          'template': templateName,
          'language': languageCode,
          'components': components,
        },
      );
      
      if (resp['error'] != null) {
        debugPrint('❌ WhatsApp Backend Error: ${resp['error']}');
        return false;
      }
      
      debugPrint('✅ WhatsApp Backend Triggered Successfully');
      return true;

    } catch (e) {
      debugPrint('❌ WhatsApp Service Error: $e');
      return false;
    }
  }

  /// Send order update notification
  static Future<bool> sendOrderUpdate({
    required String toNumber,
    required String customerName,
    required String orderStatus,
    String? orderId,
  }) async {
    // Try Backend API First
    final success = await sendTemplateMessage(
      toNumber: toNumber,
      templateName: 'order_update', // Ensure this template exists in Meta
      languageCode: 'en_US',
      bodyParameters: [customerName, orderId ?? 'N/A', orderStatus],
    );
    
    if (success) return true;

    // Fallback: Launch App
    debugPrint('⚠️ WhatsApp API failed, falling back to URL launcher...');
    final message = 'Hello $customerName, updates for your order${orderId != null ? " #$orderId" : ""}. Status: $orderStatus. Thank you!';
    return await _launchWhatsApp(toNumber, message);
  }

  /// Send dispatch notification
  static Future<bool> sendDispatchNotification({
    required String toNumber,
    required String customerName,
    required String deliveryTime,
    String? orderId,
    String? trackingLink,
  }) async {
    final success = await sendTemplateMessage(
      toNumber: toNumber,
      templateName: 'dispatch_notification',
      languageCode: 'en_US',
      bodyParameters: [customerName, deliveryTime, orderId ?? 'N/A'],
    );

    if (success) return true;

    // Fallback
    String message = 'Hello $customerName, your order${orderId != null ? " #$orderId" : ""} will be delivered by $deliveryTime.';
    if (trackingLink != null) message += '\nTrack here: $trackingLink';
    message += '\nPlease be available.';
    return await _launchWhatsApp(toNumber, message);
  }
  
  /// Send order confirmation (Text + PDF)
  static Future<bool> sendOrderConfirmation({
    required String toNumber,
    required String customerName,
    required String orderId,
    required String totalAmount,
    required String date,
    required String time,
    required String pax,
    required String cateringName, // {{7}}
    required String cateringPhone, // {{8}} - In Body
    required Map<String, dynamic> orderData, // NEW: Full order data for PDF
    required List<Map<String, dynamic>> dishes, // NEW: Dishes for PDF
  }) async {
    try {
      debugPrint('📄 Generating PDF for Order #$orderId...');
      
      // 1. Generate PDF from Order data using PdfService
      final pdfBytes = await PdfService.generateOrderPdfBytes(orderData, dishes);
      
      if (pdfBytes != null) {
         // 2. Prepare Base64
         final pdfBase64 = base64Encode(pdfBytes);
         
         debugPrint('🚀 Sending Text+PDF via Backend...');
         final resp = await AwsApi.callDbHandler(
            method: 'POST',
            table: 'messaging/whatsapp/send_order_pdf',
            data: {
              'to': toNumber,
              'pdf_base64': pdfBase64,
              // Text Params: {{1}}..{{8}}
              'text_params': [
                 orderId,
                 customerName, 
                 date, 
                 time, 
                 pax, 
                 totalAmount,
                 cateringName,
                 cateringPhone 
              ],
              // PDF Params: {{1}} (Order ID)
              'pdf_params': [orderId]
            }
         );
         
         if (resp['success'] == true) {
            debugPrint('✅ WhatsApp (Text+PDF) Sent!');
            return true;
         }
         debugPrint('⚠️ Backend Warning: ${resp['warning'] ?? resp['error']}');
      } else {
        debugPrint('❌ PDF Generation Failed. Sending Text Only fallback.');
      }
      
    } catch (e) {
      debugPrint('❌ PDF/Backend Error: $e');
    }

    // Fallback: Send Simple Text Template (if backend/PDF failed)
    debugPrint('⚠️ Falling back to Text-Only Template...');
    final success = await sendTemplateMessage(
      toNumber: toNumber,
      templateName: 'order_status_update',
      languageCode: 'en_US',
      // Params 1-8
      bodyParameters: [orderId, customerName, date, time, pax, totalAmount, cateringName, cateringPhone],
    );

    if (success) return true;

    // Ultimate Fallback: Launch WhatsApp URL
    final message = 'Dear $customerName, your order #$orderId is confirmed!\n\n📅 Date: $date\n⏰ Time: $time\n👥 Pax: $pax\n💰 Amount: ₹$totalAmount\n\n📞 Call: $cateringPhone\n\nThank you for choosing $cateringName!';
    return await _launchWhatsApp(toNumber, message);
  }

  /// Launch WhatsApp App with pre-filled message (Fallback)
  static Future<bool> _launchWhatsApp(String phone, String message) async {
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone'; // Default to India
      
      final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Launcher error: $e');
      return false;
    }
  }
}

