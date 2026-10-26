import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'ridin_transit_alerts';
  static const String channelName = 'Alertes Trajet Ridin';
  static const String channelDescription = 'Notifications prioritaires pour les approches et montées de bus scolaire';

  Future<void> clearSessionAlerts() async {
    if (!_isInitialized) return;
    await _notificationsPlugin.cancelAll();
  }

  /// Initialize notifications plugin and create high-priority notification channel
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        }
      },
    );

    // Create Android High-Priority Channel
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidPlugin.createNotificationChannel(androidChannel);

      // Request Android 13+ Notification Permission
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Notification permission request error: $e');
        }
      }
    }

    _isInitialized = true;
  }

  /// Show an immediate high-priority Heads-Up notification
  Future<void> showTransitAlert({
    int id = 100,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Ridin Alerte',
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  /// Synchronize device push token with backend
  Future<void> syncDeviceToken(ApiClient apiClient) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('ridin_device_fcm_token');

      if (token == null) {
        token = 'dev_token_${DateTime.now().millisecondsSinceEpoch}_m53';
        await prefs.setString('ridin_device_fcm_token', token);
      }

      await apiClient.dio.post('/auth/fcm-token', data: {
        'fcm_token': token,
      });

      if (kDebugMode) {
        debugPrint('Device push token synced successfully: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Device token sync error: $e');
      }
    }
  }
}
