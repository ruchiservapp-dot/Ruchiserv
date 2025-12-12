import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../secrets.dart';

/// WhatsApp Business API Service
/// Uses official Meta WhatsApp Business Platform API
class WhatsAppService {
  // Meta WhatsApp Business API endpoint
  static const String _baseUrl = 'https://graph.facebook.com/v18.0';
  
  /// Send a text message directly (works without templates for some use cases)
  static Future<bool> sendMessage({
    required String toNumber,
    required String message,
  }) async {
    debugPrint('💬 [WhatsApp] Sending message to: $toNumber');
    debugPrint('   Message: $message');
    
    // Check if credentials are configured
    if (metaWhatsAppToken == 'YOUR_META_ACCESS_TOKEN' || 
        metaWhatsAppPhoneId == 'YOUR_PHONE_NUMBER_ID') {
      debugPrint('⚠️ WhatsApp not configured - using mock mode');
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
    
    try {
      final url = Uri.parse('$_baseUrl/$metaWhatsAppPhoneId/messages');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $metaWhatsAppToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': toNumber.replaceAll('+', '').replaceAll(' ', ''),
          'type': 'text',
          'text': {
            'preview_url': false,
            'body': message,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ WhatsApp sent successfully: ${data['messages']?[0]?['id']}');
        return true;
      } else {
        debugPrint('❌ WhatsApp failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ WhatsApp error: $e');
      return false;
    }
  }
  
  /// Send template message (required for most notifications)
  static Future<bool> sendTemplateMessage({
    required String toNumber,
    required String templateName,
    required String languageCode,
    List<String>? bodyParameters,
  }) async {
    debugPrint('💬 [WhatsApp] Sending template "$templateName" to: $toNumber');
    
    // Check if credentials are configured
    if (metaWhatsAppToken == 'YOUR_META_ACCESS_TOKEN' || 
        metaWhatsAppPhoneId == 'YOUR_PHONE_NUMBER_ID') {
      debugPrint('⚠️ WhatsApp not configured - using mock mode');
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
    
    try {
      final url = Uri.parse('$_baseUrl/$metaWhatsAppPhoneId/messages');
      
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
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $metaWhatsAppToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': toNumber.replaceAll('+', '').replaceAll(' ', ''),
          'type': 'template',
          'template': {
            'name': templateName,
            'language': {'code': languageCode},
            if (components.isNotEmpty) 'components': components,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ WhatsApp template sent: ${data['messages']?[0]?['id']}');
        return true;
      } else {
        debugPrint('❌ WhatsApp template failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ WhatsApp template error: $e');
      return false;
    }
  }

  /// Send order update notification using template
  static Future<bool> sendOrderUpdate({
    required String toNumber,
    required String customerName,
    required String orderStatus,
    String? orderId,
  }) async {
    // Try template first (if configured), fallback to simple message
    try {
      return await sendTemplateMessage(
        toNumber: toNumber,
        templateName: 'order_update',
        languageCode: 'en',
        bodyParameters: [customerName, orderId ?? 'N/A', orderStatus],
      );
    } catch (e) {
      // Fallback to simple text message
      final message = 'Hello $customerName, your order${orderId != null ? " #$orderId" : ""} is now $orderStatus. Thank you!';
      return await sendMessage(toNumber: toNumber, message: message);
    }
  }

  /// Send dispatch notification
  static Future<bool> sendDispatchNotification({
    required String toNumber,
    required String customerName,
    required String deliveryTime,
    String? orderId,
  }) async {
    // Try template first, fallback to simple message
    try {
      return await sendTemplateMessage(
        toNumber: toNumber,
        templateName: 'dispatch_notification',
        languageCode: 'en',
        bodyParameters: [customerName, deliveryTime, orderId ?? 'N/A'],
      );
    } catch (e) {
      // Fallback to simple text message
      final message = 'Hello $customerName, your order${orderId != null ? " #$orderId" : ""} will be delivered by $deliveryTime. Please be available.';
      return await sendMessage(toNumber: toNumber, message: message);
    }
  }
  
  /// Send order confirmation
  static Future<bool> sendOrderConfirmation({
    required String toNumber,
    required String customerName,
    required String orderId,
    required String totalAmount,
  }) async {
    try {
      return await sendTemplateMessage(
        toNumber: toNumber,
        templateName: 'order_confirmation',
        languageCode: 'en',
        bodyParameters: [customerName, orderId, totalAmount],
      );
    } catch (e) {
      final message = 'Dear $customerName, your order #$orderId has been confirmed. Total amount: ₹$totalAmount. Thank you for choosing RuchiServ!';
      return await sendMessage(toNumber: toNumber, message: message);
    }
  }
}
