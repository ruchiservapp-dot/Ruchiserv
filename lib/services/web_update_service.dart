import 'package:ruchiserv/core/app_logger.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Conditional import for web
import 'web_update_stub.dart'
    if (dart.library.html) 'web_update_web.dart' as web_impl;

class WebUpdateService {
  static final WebUpdateService _instance = WebUpdateService._internal();
  factory WebUpdateService() => _instance;
  WebUpdateService._internal();

  String? _currentVersion;
  Timer? _checkTimer;
  bool _isUpdateAvailable = false;

  final _updateController = StreamController<bool>.broadcast();
  Stream<bool> get updateStream => _updateController.stream;

  Future<void> init() async {
    if (!kIsWeb) return;
    
    _currentVersion = await _fetchVersion();
    AppLogger.info('WebUpdateService: Initial version $_currentVersion');
    
    // Start periodic check every 15 minutes
    _checkTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      checkForUpdates();
    });
  }

  Future<String?> _fetchVersion() async {
    try {
      // Add timestamp to prevent browser from caching the JSON itself
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('version.json?v=$timestamp'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['version']?.toString();
      }
    } catch (e) {
      AppLogger.info('WebUpdateService error: $e');
    }
    return null;
  }

  Future<void> checkForUpdates() async {
    if (!kIsWeb || _isUpdateAvailable) return;

    final newVersion = await _fetchVersion();
    if (newVersion != null && _currentVersion != null && newVersion != _currentVersion) {
      AppLogger.info('WebUpdateService: Update detected! Old: $_currentVersion, New: $newVersion');
      _isUpdateAvailable = true;
      _updateController.add(true);
    }
  }

  void forceRefresh() {
    if (kIsWeb) {
      web_impl.reloadPage();
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _updateController.close();
  }
}
