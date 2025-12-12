// lib/services/geo_fence_service.dart
// SERVICE: GPS GEO-FENCING FOR STAFF ATTENDANCE
// Uses Haversine formula to calculate distance between two GPS coordinates

import 'dart:math';
import 'package:geolocator/geolocator.dart';

class GeoFenceService {
  static final GeoFenceService _instance = GeoFenceService._internal();
  factory GeoFenceService() => _instance;
  GeoFenceService._internal();

  static GeoFenceService get instance => _instance;

  /// Earth's radius in meters
  static const double _earthRadius = 6371000;

  /// Calculate distance between two GPS points using Haversine formula
  /// Returns distance in meters
  double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
              sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return _earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  /// Check if a point is within the geo-fence radius of the kitchen
  bool isWithinGeoFence({
    required double staffLat,
    required double staffLng,
    required double kitchenLat,
    required double kitchenLng,
    required double radiusMeters,
  }) {
    final distance = calculateDistance(
      lat1: staffLat,
      lng1: staffLng,
      lat2: kitchenLat,
      lng2: kitchenLng,
    );
    return distance <= radiusMeters;
  }

  /// Get the distance as a formatted string (e.g., "150 m" or "1.2 km")
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Request location permission and get current position
  /// Returns null if permission denied or location unavailable
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position with high accuracy
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      print('❌ [GeoFenceService] Error getting position: $e');
      return null;
    }
  }

  /// Check if location services are available and permission granted
  Future<LocationStatus> checkLocationStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationStatus.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return LocationStatus.permissionDenied;
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationStatus.permissionDeniedForever;
      }

      return LocationStatus.ready;
    } catch (e) {
      return LocationStatus.error;
    }
  }

  /// Get user-friendly message for location status
  String getStatusMessage(LocationStatus status) {
    switch (status) {
      case LocationStatus.ready:
        return 'Location ready';
      case LocationStatus.serviceDisabled:
        return 'Please enable location services';
      case LocationStatus.permissionDenied:
        return 'Location permission required';
      case LocationStatus.permissionDeniedForever:
        return 'Location permission permanently denied. Please enable in Settings.';
      case LocationStatus.error:
        return 'Unable to access location';
    }
  }
}

enum LocationStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}
