import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ridin/core/api/api_client.dart';
import 'package:ridin/features/auth/data/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepository safe storage tests', () {
    late ApiClient apiClient;
    late List<RequestOptions> requests;
    late _RejectUnexpectedRequests adapter;
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      apiClient = ApiClient(baseUrl: 'https://api.example.invalid/api/v1');
      adapter = _RejectUnexpectedRequests();
      apiClient.dio.httpClientAdapter = adapter;
      requests = [];
      apiClient.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.path == '/auth/switch-mode' ||
                options.path == '/auth/logout') {
              return handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {}),
              );
            }
            handler.next(options);
          },
        ),
      );
    });

    tearDown(() {
      expect(adapter.unexpectedRequests, isEmpty);
      apiClient.dio.close(force: true);
    });

    test('getCurrentUser returns null when storage is empty', () async {
      final repo = AuthRepository(apiClient: apiClient);
      final user = await repo.getCurrentUser();
      expect(user, isNull);
    });

    test('getAuthToken returns null when token not set', () async {
      final repo = AuthRepository(apiClient: apiClient);
      final token = await repo.getAuthToken();
      expect(token, isNull);
    });

    test('getActiveMode returns null when active mode not set', () async {
      final repo = AuthRepository(apiClient: apiClient);
      final mode = await repo.getActiveMode();
      expect(mode, isNull);
    });

    test('setActiveMode writes and reads active mode properly', () async {
      final repo = AuthRepository(apiClient: apiClient);
      await repo.setActiveMode('driver');
      final mode = await repo.getActiveMode();
      expect(mode, 'driver');
      expect(requests.single.path, '/auth/switch-mode');
      expect(requests.single.data, {'mode': 'driver'});
    });

    test('logout clears secure storage', () async {
      final repo = AuthRepository(apiClient: apiClient);
      await repo.setActiveMode('driver');
      requests.clear();
      await repo.logout();
      expect(requests.single.path, '/auth/logout');
      final mode = await repo.getActiveMode();
      expect(mode, isNull);
    });

    test('changePassword updates user data in storage upon success', () async {
      apiClient.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/auth/change-password')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'message':
                        'Votre mot de passe a été mis à jour avec succès.',
                    'user': {
                      'id': 10,
                      'name': 'Chauffeur Test',
                      'role': 'driver',
                      'must_change_password': false,
                    },
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final repo = AuthRepository(apiClient: apiClient);
      final result = await repo.changePassword(
        currentPassword: 'old_password',
        newPassword: 'new_password123',
        confirmPassword: 'new_password123',
      );

      expect(result['message'], contains('succès'));
      final currentUser = await repo.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!['must_change_password'], false);
    });
  });
}

class _RejectUnexpectedRequests implements HttpClientAdapter {
  final List<String> unexpectedRequests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    unexpectedRequests.add('${options.method} ${options.path}');
    fail(
      'Unexpected HTTP request in storage test: ${options.method} ${options.path}',
    );
  }

  @override
  void close({bool force = false}) {}
}
