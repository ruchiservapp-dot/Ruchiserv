// lib/services/location_service.dart
// GPS Location Tracking Service for Driver location updates
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import 'connectivity_service.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  
  LocationService._();
  
  Timer? _locationTimer;
  int? _activeDispatchId;
  bool _isTracking = false;

  /// Start tracking location for a dispatch
  Future<bool> startTracking(int dispatchId) async {
    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('📍 Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('📍 Location permission permanently denied');
      return false;
    }

    _activeDispatchId = dispatchId;
    _isTracking = true;

    // Update location immediately
    await _updateLocation();

    // Start 60-second interval updates
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_isTracking) {
        await _updateLocation();
      }
    });

    print('📍 Location tracking started for dispatch $dispatchId');
    return true;
  }

  /// Stop tracking location
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
    _activeDispatchId = null;
    print('📍 Location tracking stopped');
  }

  /// Get current location and update DB + AWS
  Future<void> _updateLocation() async {
    if (_activeDispatchId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final now = DateTime.now().toIso8601String();

      // Update local DB
      final db = await DatabaseHelper().database;
      await db.update('dispatches', {
        'driverLat': lat,
        'driverLng': lng,
        'lastLocationUpdate': now,
      }, where: 'id = ?', whereArgs: [_activeDispatchId]);

      // Sync to AWS for real-time tracking
      if (await ConnectivityService().isOnline()) {
        await AwsApi.callDbHandler(
          method: 'PUT',
          table: 'dispatch_locations',
          data: {
            'dispatchId': _activeDispatchId,
            'lat': lat,
            'lng': lng,
            'timestamp': now,
          },
        );
      }

      print('📍 Location updated: $lat, $lng');
    } catch (e) {
      print('📍 Location error: $e');
    }
  }

  /// Check if currently tracking
  bool get isTracking => _isTracking;
  int? get activeDispatchId => _activeDispatchId;

  /// Get last known location for a dispatch
  static Future<Map<String, dynamic>?> getLastLocation(int dispatchId) async {
    final db = await DatabaseHelper().database;
    final result = await db.query('dispatches', 
      columns: ['driverLat', 'driverLng', 'lastLocationUpdate'],
      where: 'id = ?', 
      whereArgs: [dispatchId],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  /// Get location from AWS (for web tracker)
  static Future<Map<String, dynamic>?> getAwsLocation(int dispatchId) async {
    try {
      final result = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'dispatch_locations',
        filters: {'dispatchId': dispatchId},
      );
      if (result['status'] == 'success' && result['data'] != null) {
        return result['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      print('AWS location error: $e');
    }
    return null;
  }
}
