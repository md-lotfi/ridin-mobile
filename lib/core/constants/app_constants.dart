class AppConstants {
  static const String appName = 'Ridin';
  static const String defaultLocale = 'fr';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.9:8000/api/v1',
  );
  static const String defaultCentrifugoWsUrl =
      'wss://caresocket.raystate.com/connection/websocket';

  // Secure Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserData = 'user_data';
  static const String keyActiveMode = 'active_mode';
  static const String keyCentrifugoToken = 'centrifugo_token';
  static const String keyCentrifugoWsUrl = 'centrifugo_ws_url';
  static const String keyOfflineBreadcrumbs = 'offline_breadcrumbs';
}
