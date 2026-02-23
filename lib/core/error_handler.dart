import 'dart:io';
import 'package:flutter/material.dart';
import 'app_logger.dart';

/// Categorized error types for user-friendly messaging
enum ErrorCategory {
  network, // No internet, timeout, DNS
  auth, // Session expired, invalid credentials
  validation, // Form errors, invalid data
  server, // 500, Lambda errors, DynamoDB issues
  permission, // Forbidden, subscription tier limit
  sync, // Cloud sync failures
  unknown, // Uncategorized
}

class ErrorHandler {
  /// Handle an error with auto-categorization and user-friendly messages.
  /// Logs to Crashlytics in release builds via AppLogger.
  static void handleError(
    BuildContext context,
    dynamic error, {
    String? message,
    StackTrace? stackTrace,
    ErrorCategory? category,
  }) {
    final cat = category ?? _categorize(error);
    final userMessage = message ?? _userMessage(cat, error);

    // Log to Crashlytics (non-fatal) + console in debug
    AppLogger.error(
      '[$cat] $userMessage',
      error,
      stackTrace ?? StackTrace.current,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_iconFor(cat), color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(userMessage)),
          ],
        ),
        backgroundColor: _colorFor(cat),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: cat == ErrorCategory.network
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () {}, // Caller can override via onRetry
              )
            : null,
      ),
    );
  }

  /// Show a success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a warning message
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Private helpers ──────────────────────────────────────────────

  /// Auto-categorize error from its type/message
  static ErrorCategory _categorize(dynamic error) {
    final msg = error.toString().toLowerCase();

    if (error is SocketException ||
        msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('no internet') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('host lookup') ||
        msg.contains('failed host lookup')) {
      return ErrorCategory.network;
    }

    if (msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('session expired') ||
        msg.contains('invalid credentials') ||
        msg.contains('not authenticated') ||
        msg.contains('cognito')) {
      return ErrorCategory.auth;
    }

    if (msg.contains('403') ||
        msg.contains('forbidden') ||
        msg.contains('subscription') ||
        msg.contains('tier') ||
        msg.contains('access denied')) {
      return ErrorCategory.permission;
    }

    if (msg.contains('500') ||
        msg.contains('internal server') ||
        msg.contains('lambda') ||
        msg.contains('dynamodb') ||
        msg.contains('service unavailable')) {
      return ErrorCategory.server;
    }

    if (msg.contains('sync') ||
        msg.contains('pending_sync') ||
        msg.contains('cloud sync')) {
      return ErrorCategory.sync;
    }

    if (msg.contains('validation') ||
        msg.contains('required') ||
        msg.contains('invalid') ||
        msg.contains('format')) {
      return ErrorCategory.validation;
    }

    return ErrorCategory.unknown;
  }

  /// User-friendly message per category
  static String _userMessage(ErrorCategory cat, dynamic error) {
    switch (cat) {
      case ErrorCategory.network:
        return 'No internet connection. Changes saved locally.';
      case ErrorCategory.auth:
        return 'Session expired. Please log in again.';
      case ErrorCategory.validation:
        return 'Please check the entered data and try again.';
      case ErrorCategory.server:
        return 'Server error. Please try again in a moment.';
      case ErrorCategory.permission:
        return 'You don\'t have access to this feature.';
      case ErrorCategory.sync:
        return 'Sync issue. Data saved locally and will sync later.';
      case ErrorCategory.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Icon per error category
  static IconData _iconFor(ErrorCategory cat) {
    switch (cat) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.auth:
        return Icons.lock_outline;
      case ErrorCategory.validation:
        return Icons.error_outline;
      case ErrorCategory.server:
        return Icons.cloud_off;
      case ErrorCategory.permission:
        return Icons.block;
      case ErrorCategory.sync:
        return Icons.sync_problem;
      case ErrorCategory.unknown:
        return Icons.warning_amber;
    }
  }

  /// Color per error category
  static Color _colorFor(ErrorCategory cat) {
    switch (cat) {
      case ErrorCategory.network:
        return const Color(0xFF607D8B); // Blue-Grey
      case ErrorCategory.auth:
        return const Color(0xFFE65100); // Deep Orange
      case ErrorCategory.validation:
        return const Color(0xFFF57C00); // Orange
      case ErrorCategory.server:
        return const Color(0xFFD32F2F); // Red
      case ErrorCategory.permission:
        return const Color(0xFF7B1FA2); // Purple
      case ErrorCategory.sync:
        return const Color(0xFF1565C0); // Blue
      case ErrorCategory.unknown:
        return Colors.redAccent;
    }
  }
}
