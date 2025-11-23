import 'package:flutter/material.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool isSyncing;
  final bool hasError;
  final String? message;

  const SyncStatusWidget({
    super.key,
    required this.isSyncing,
    this.hasError = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSyncing && !hasError) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: hasError ? Colors.redAccent : Colors.blueAccent,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasError ? Icons.cloud_off : Icons.sync,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            message ??
                (hasError ? "Sync failed. Retrying..." : "Syncing with server..."),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
