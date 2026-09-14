import 'package:flutter_test/flutter_test.dart';
import 'package:ridin/core/constants/app_constants.dart';

void main() {
  test('AppConstants contains correct defaults', () {
    expect(AppConstants.appName, 'Ridin');
    expect(AppConstants.defaultLocale, 'fr');
    expect(AppConstants.apiBaseUrl, contains('/api/v1'));
    expect(AppConstants.defaultCentrifugoWsUrl, 'wss://caresocket.raystate.com/connection/websocket');
  });
}
