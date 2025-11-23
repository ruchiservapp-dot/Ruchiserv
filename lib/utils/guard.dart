import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

Future<bool> guardWrite(BuildContext context, String firmId) async {
  final readOnly = await SubscriptionService.isReadOnly(firmId);

  if (readOnly) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Read-only during grace period')),
      );
    }
    return false;
  }
  return true;
}
