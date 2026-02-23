import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_logger.dart';
import 'dart:io';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _isUpdateDialogShowing = false;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _remoteConfig.setDefaults({
        'min_app_version': '1.0.0',
        'update_url_android': 'https://play.google.com/store/apps/details?id=com.ruchiserv.app',
        'update_url_ios': 'https://apps.apple.com/app/ruchiserv/id6470000000',
      });
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      AppLogger.error('Failed to initialize Remote Config: $e');
    }
  }

  Future<void> checkForUpdate(BuildContext context) async {
    if (_isUpdateDialogShowing) return;
    
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final minVersion = _remoteConfig.getString('min_app_version');

    if (_isVersionBelow(currentVersion, minVersion)) {
      if (!context.mounted) return;
      _isUpdateDialogShowing = true;
      _showUpdateDialog(context);
    }
  }

  bool _isVersionBelow(String current, String min) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> minParts = min.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      int c = currentParts.length > i ? currentParts[i] : 0;
      int m = minParts.length > i ? minParts[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: const Text(
            'A newer version of RuchiServ is required to continue. Please update to the latest version.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final urlString = Platform.isAndroid 
                    ? _remoteConfig.getString('update_url_android')
                    : _remoteConfig.getString('update_url_ios');
                final url = Uri.parse(urlString);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
