import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Premium Network Error Widget with retry capability and offline indicator.
class NetworkErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isOffline;

  const NetworkErrorWidget({
    super.key,
    this.message = 'Network connection lost. Please check your internet.',
    required this.onRetry,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with soft background circle
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isOffline ? Colors.orange : AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOffline ? Icons.signal_wifi_off_rounded : Icons.cloud_off_rounded,
                size: 64,
                color: isOffline ? Colors.orange : AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            
            // Title
            Text(
              isOffline ? 'You are offline' : 'Cloud Connection Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.white : AppColors.black,
                  ),
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mediumGrey,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 40),
            
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text('RETRY CONNECTION', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            
            if (isOffline) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Some screens might allow viewing cached data while offline
                  Navigator.of(context).pop();
                },
                child: const Text('VIEW OFFLINE DATA'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
