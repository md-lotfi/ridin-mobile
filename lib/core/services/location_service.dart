import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  Future<bool> checkAndRequestPermissions() async {
    final status = await Permission.locationAlways.status;
    if (status.isGranted) return true;

    final locWhenInUse = await Permission.locationWhenInUse.request();
    if (locWhenInUse.isGranted) {
      final locAlways = await Permission.locationAlways.request();
      return locAlways.isGranted || locWhenInUse.isGranted;
    }

    return false;
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Stream every 5 meters
      ),
    );
  }

  Future<void> saveBreadcrumbOffline({
    required double latitude,
    required double longitude,
    required double speed,
    required double heading,
    required DateTime recordedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList(AppConstants.keyOfflineBreadcrumbs) ?? [];

    final item = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'recorded_at': recordedAt.toIso8601String(),
    });

    cached.add(item);
    await prefs.setStringList(AppConstants.keyOfflineBreadcrumbs, cached);
  }

  Future<List<Map<String, dynamic>>> popOfflineBreadcrumbs() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList(AppConstants.keyOfflineBreadcrumbs) ?? [];

    if (cached.isEmpty) return [];

    await prefs.remove(AppConstants.keyOfflineBreadcrumbs);

    return cached
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  void stopListening() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
