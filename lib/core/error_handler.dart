import 'package:flutter/material.dart';
import 'app_logger.dart';

class ErrorHandler {
  static void handleError(BuildContext context, dynamic error, {String? message}) {
    AppLogger.error(error.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Something went wrong!'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
