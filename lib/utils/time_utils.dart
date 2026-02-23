import 'package:ruchiserv/core/app_logger.dart';
import 'package:intl/intl.dart';

class TimeUtils {
  /// Formats a time string (HH:mm) or TimeOfDay to 12-hour format (6:36 PM)
  static String formatTo12Hour(dynamic time) {
    if (time == null || time.toString().isEmpty) return '-';

    try {
      if (time is String) {
        final parts = time.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return DateFormat('h:mm a')
              .format(DateTime(2026, 1, 1, hour, minute));
        }
      }
      // Add other types if needed (e.g. TimeOfDay)
    } catch (_) {
      AppLogger.error('Caught error: $_');
    }

    return time.toString();
  }
}
