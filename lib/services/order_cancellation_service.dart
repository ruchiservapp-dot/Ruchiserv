// lib/services/order_cancellation_service.dart
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class OrderCancellationService {
  static final OrderCancellationService _instance = OrderCancellationService._internal();
  factory OrderCancellationService() => _instance;
  OrderCancellationService._internal();

  /// Validate if an order can be cancelled and get dependency summary
  /// Returns a map with validation results and dependency information
  Future<Map<String, dynamic>> validateCancellation({
    required int orderId,
    required String firmId,
  }) async {
    try {
      // Get order dependencies with better error handling
      Map<String, dynamic> dependencies;
      try {
        dependencies = await DatabaseHelper().getOrderDependencies(orderId, firmId);
      } catch (dbError) {
        return {
          'canCancel': false,
          'error': 'Database error: Could not load order details. Please try again.',
        };
      }
      
      if (dependencies.containsKey('error')) {
        return {
          'canCancel': false,
          'error': dependencies['error'],
        };
      }

      final order = dependencies['order'] as Map<String, dynamic>?;
      if (order == null) {
        return {
          'canCancel': false,
          'error': 'Order not found',
        };
      }
      
      // Check if already cancelled
      if ((order['isCancelled'] as int?) == 1) {
        return {
          'canCancel': false,
          'error': 'Order is already cancelled',
          'alreadyCancelled': true,
        };
      }

      // Parse event date
      final eventDateStr = order['date'] as String?;
      if (eventDateStr == null || eventDateStr.isEmpty) {
        return {
          'canCancel': false,
          'error': 'Order has no event date',
        };
      }

      DateTime eventDate;
      try {
        eventDate = DateTime.parse(eventDateStr);
      } catch (e) {
        return {
          'canCancel': false,
          'error': 'Invalid event date format: $eventDateStr',
        };
      }

      // Check if within 48 hours
      final now = DateTime.now();
      final hoursUntilEvent = eventDate.difference(now).inHours;
      final within48Hours = hoursUntilEvent <= 48 && hoursUntilEvent >= 0;

      // Get dependency counts safely
      final dishCount = dependencies['dishCount'] as int? ?? 0;
      final hasDispatch = dependencies['hasDispatch'] as bool? ?? false;
      final dispatchCount = dependencies['dispatchCount'] as int? ?? 0;

      // Build warning message
      final warnings = <String>[];
      
      if (within48Hours) {
        warnings.add('⚠️ Event is in ${hoursUntilEvent} hours - within 48-hour window');
      }
      
      if (dishCount > 0) {
        warnings.add('📋 $dishCount dish(es) linked to this order');
      }
      
      if (hasDispatch) {
        warnings.add('🚚 $dispatchCount dispatch record(s) linked');
      }

      // Note: MRP is calculated on-demand, so we show a general warning
      if (eventDate.isAfter(now)) {
        warnings.add('📊 This order may be included in active MRP calculations');
      }

      return {
        'canCancel': true,
        'within48Hours': within48Hours,
        'hoursUntilEvent': hoursUntilEvent,
        'eventDate': eventDateStr,
        'eventTime': order['eventTime'],
        'dishCount': dishCount,
        'hasDispatch': hasDispatch,
        'dispatchCount': dispatchCount,
        'warnings': warnings,
        'dependencies': dependencies,
      };
    } catch (e) {
      return {
        'canCancel': false,
        'error': 'Validation error: ${e.toString()}',
      };
    }
  }

  /// Cancel an order after validation
  Future<Map<String, dynamic>> cancelOrderWithDependencies({
    required int orderId,
    required String firmId,
    required String userId,
  }) async {
    try {
      // First validate
      final validation = await validateCancellation(
        orderId: orderId,
        firmId: firmId,
      );

      if (!(validation['canCancel'] as bool? ?? false)) {
        return {
          'success': false,
          'error': validation['error'] ?? 'Cannot cancel order',
        };
      }

      // Perform the cancellation
      final success = await DatabaseHelper().cancelOrder(
        orderId,
        firmId: firmId,
        userId: userId,
      );

      if (!success) {
        return {
          'success': false,
          'error': 'Failed to cancel order in database',
        };
      }

      // Log notification attempts (infrastructure only for now)
      await _logNotificationAttempts(
        orderId: orderId,
        firmId: firmId,
        userId: userId,
        dependencies: validation['dependencies'] as Map<String, dynamic>,
      );

      return {
        'success': true,
        'orderId': orderId,
        'cancelledAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Cancellation failed: $e',
      };
    }
  }

  /// Log notification attempts in audit trail
  /// This is infrastructure - actual email/SMS integration would go here
  Future<void> _logNotificationAttempts({
    required int orderId,
    required String firmId,
    required String userId,
    required Map<String, dynamic> dependencies,
  }) async {
    // For now, we just log to audit trail
    // In future, this would trigger actual notifications to:
    // - Suppliers (if ingredients were ordered)
    // - Vendors (if external services contracted)
    // - Contractors (if subcontracted work)
    // - Service staff (if staff assigned)
    // - Transporters (if logistics arranged)
    
    // This is a placeholder for the notification infrastructure
    // Actual implementation would require email/SMS service integration
  }

  /// Format dependency summary for UI display
  String getDependencySummary(Map<String, dynamic> validation) {
    final warnings = validation['warnings'] as List<String>? ?? [];
    
    if (warnings.isEmpty) {
      return 'No dependencies found. Safe to cancel.';
    }
    
    return warnings.join('\n');
  }

  /// Check if event is within warning window (48 hours)
  bool isWithinWarningWindow(DateTime eventDate) {
    final now = DateTime.now();
    final hoursUntilEvent = eventDate.difference(now).inHours;
    return hoursUntilEvent <= 48 && hoursUntilEvent >= 0;
  }

  /// Format event date/time for display
  String formatEventDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateStr);
      final formattedDate = DateFormat('MMM dd, yyyy').format(date);
      
      if (timeStr != null && timeStr.isNotEmpty) {
        return '$formattedDate at $timeStr';
      }
      
      return formattedDate;
    } catch (e) {
      return dateStr;
    }
  }
}
