import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static bool _isTracking = false;
  static bool _hasPermission = false;

  /// Request location permission from the user
  static Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    _hasPermission = status.isGranted;
    return _hasPermission;
  }

  /// Start tracking user location
  static Future<void> startTracking() async {
    if (!_hasPermission) {
      await requestPermission();
    }
    _isTracking = true;
    debugPrint('Location tracking started');
  }

  /// Stop tracking user location
  static void stopTracking() {
    _isTracking = false;
    debugPrint('Location tracking stopped');
  }

  /// Check if currently tracking location
  static bool get isTracking => _isTracking;

  /// Dispose resources
  static void dispose() {
    stopTracking();
  }

  /// Update user location on server
  static Future<void> updateUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    // Stub implementation - location would be sent to server
    debugPrint('Location update: $latitude, $longitude');
  }

  /// Stream of location updates
  static Stream<Map<String, dynamic>> get locationStream {
    // Stub implementation - would return location updates
    return Stream.empty();
  }
}
