import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../db/aws/aws_api.dart'; // keep if you already have this
import '../screens/system/expired_screen.dart';

/// Phase-1 Subscription Rules:
/// - Warn daily when <5 days left (active)
/// - 5-day grace after expiry: READ-ONLY (no add/edit/delete)
/// - After grace: BLOCKED (cannot use app)
class SubscriptionService {
  static const int graceDays = 5;

  /// Call this after login (and on auto-login), before entering Home.
  static Future<void> enforceOnLogin({
    required BuildContext context,
    required String firmId,
  }) async {
    final info = await _fetchAndCacheSubscription(firmId);
    _actOnState(context, info);
  }

  /// To be used on app resume if you want (optional)
  static Future<void> enforceSilently(BuildContext context, String firmId) async {
    final info = await _getCached(firmId);
    if (info == null) return;
    _actOnState(context, info, showWarningOnlyIfDue: true);
  }

  /// Whether the UI should be read-only (grace mode).
  static Future<bool> isReadOnly(String firmId) async {
    final info = await _getCached(firmId);
    if (info == null) return false;
    return info.state == _SubState.grace;
  }

  /// ------ internals ------

  static Future<_SubInfo?> _getCached(String firmId) async {
    final db = DatabaseHelper();
    final rows = await db.getFirmByFirmId(firmId);
    if (rows.isEmpty) return null;

    final r = rows.first;
    final status = (r['subscriptionStatus'] as String?)?.toLowerCase() ?? 'active';
    final endIso = (r['subscriptionEnd'] as String?) ?? '';
    DateTime? end;
    try {
      end = DateTime.parse(endIso);
    } catch (_) {}

    final now = DateTime.now();
    if (end == null) {
      // if unknown, assume blocked (safe)
      return _SubInfo(state: _SubState.blocked, daysLeft: 0, endDate: now);
    }

    if (status != 'active') {
      // disabled/terminated -> blocked
      return _SubInfo(state: _SubState.blocked, daysLeft: 0, endDate: end);
    }

    // Active path
    final daysToEnd = end.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (daysToEnd >= 0) {
      // Active, maybe warning
      return _SubInfo(state: _SubState.active, daysLeft: daysToEnd, endDate: end);
    }

    // Expired -> check grace
    final graceEnd = end.add(const Duration(days: graceDays));
    if (!now.isAfter(graceEnd)) {
      final daysLeftGrace = graceEnd.difference(DateTime(now.year, now.month, now.day)).inDays;
      return _SubInfo(state: _SubState.grace, daysLeft: daysLeftGrace, endDate: end);
    }

    return _SubInfo(state: _SubState.blocked, daysLeft: 0, endDate: end);
  }

  static Future<_SubInfo> _fetchAndCacheSubscription(String firmId) async {
    // 1) Try AWS (if available)
    Map<String, dynamic>? cloud;
    try {
      final res = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'firms',
        params: {'firmId': firmId},
      );
      if ((res['status']?.toString().toLowerCase() ?? '') == 'success') {
        if (res['data'] is List && (res['data'] as List).isNotEmpty) {
          cloud = Map<String, dynamic>.from((res['data'] as List).first);
        } else if (res['data'] is Map) {
          cloud = Map<String, dynamic>.from(res['data']);
        }
      }
    } catch (_) {
      // ignore AWS failures; fall back to local
    }

    // 2) Decide final record
    final db = DatabaseHelper();
    if (cloud != null) {
      // Normalize expected keys (snake_case or camelCase tolerant)
      final status = (cloud['subscription_status'] ?? cloud['subscriptionStatus'] ?? 'Active').toString();
      final end = (cloud['subscription_end'] ?? cloud['subscriptionEnd'] ?? '').toString();
      final start = (cloud['subscription_start'] ?? cloud['subscriptionStart'] ?? '').toString();

      await db.upsertFirmSubscription(
        firmId: firmId,
        status: status,
        startIso: start,
        endIso: end,
      );
    }

    final info = await _getCached(firmId);
    // Safety fallback
    return info ?? _SubInfo(state: _SubState.active, daysLeft: 30, endDate: DateTime.now().add(const Duration(days: 30)));
  }

  static void _actOnState(BuildContext context, _SubInfo info, {bool showWarningOnlyIfDue = false}) {
    // A) Active: Show warning popup if <5 days left
    if (info.state == _SubState.active) {
      if (info.daysLeft < 5) {
        _showWarningOncePerLogin(context, info, showOnlyIfDue: showWarningOnlyIfDue);
      }
      return;
    }

    // B) Grace (read-only): show banner popup once per login
    if (info.state == _SubState.grace) {
      _showGraceInfo(context, info, showOnlyIfDue: showWarningOnlyIfDue);
      return;
    }

    // C) Blocked: push the Expired screen and replace
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ExpiredScreen(
        expiryDateText: DateFormat('d MMM yyyy').format(info.endDate),
      )),
      (route) => false,
    );
  }

  static DateTime? _lastShown; // in-memory throttle (per run)

  static void _showWarningOncePerLogin(BuildContext context, _SubInfo info, {bool showOnlyIfDue = false}) {
    if (showOnlyIfDue && _lastShown != null && DateUtils.isSameDay(_lastShown!, DateTime.now())) {
      return;
    }
    _lastShown = DateTime.now();
    final days = info.daysLeft;
    final msg = "Your subscription will expire in $days day${days == 1 ? '' : 's'}. Please contact support to renew.";
    _dialog(context, title: 'Subscription Expiring', message: msg);
  }

  static void _showGraceInfo(BuildContext context, _SubInfo info, {bool showOnlyIfDue = false}) {
    if (showOnlyIfDue && _lastShown != null && DateUtils.isSameDay(_lastShown!, DateTime.now())) {
      return;
    }
    _lastShown = DateTime.now();
    final msg = "Your subscription expired on ${DateFormat('d MMM yyyy').format(info.endDate)}.\n"
        "You are in a 5-day grace period with read-only access.";
    _dialog(context, title: 'Grace Period Active', message: msg);
  }

  static Future<void> _dialog(BuildContext context, {required String title, required String message}) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

enum _SubState { active, grace, blocked }

class _SubInfo {
  final _SubState state;
  final int daysLeft; // in active (<5) or grace mode
  final DateTime endDate;

  _SubInfo({required this.state, required this.daysLeft, required this.endDate});
}
