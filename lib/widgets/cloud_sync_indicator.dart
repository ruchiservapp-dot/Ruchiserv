import 'package:flutter/material.dart';
import '../services/cloud_sync_service.dart';

class CloudSyncIndicator extends StatelessWidget {
  const CloudSyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CloudSyncService().isSyncing,
      builder: (context, isSyncing, child) {
        if (isSyncing) {
          return const Tooltip(
            message: 'Syncing to cloud...',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                ),
              ),
            ),
          );
        }

        return const Tooltip(
          message: 'All data synced',
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.cloud_done, color: Colors.greenAccent, size: 20),
          ),
        );
      },
    );
  }
}
