import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/api_exception.dart';

class AuthRepository {
  final ApiClient apiClient;
  static const _androidOptions = AndroidOptions(resetOnError: true);
  final FlutterSecureStorage storage;

  AuthRepository({required this.apiClient, FlutterSecureStorage? storage})
    : storage =
          storage ?? const FlutterSecureStorage(aOptions: _androidOptions);

  Future<String?> _safeRead(String key) async {
    try {
      return await storage.read(key: key);
    } catch (_) {
      try {
        await storage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  Future<void> _safeWrite(String key, String? value) async {
    if (value == null) return;
    try {
      await storage.write(key: key, value: value);
    } catch (_) {
      try {
        await storage.deleteAll();
        await storage.write(key: key, value: value);
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    String? fcmToken,
  }) async {
    try {
      await apiClient.endSession();
      final generation = apiClient.sessionGeneration;
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'login': login,
          'password': password,
          'fcm_token': fcmToken,
          'device_name': 'Ridin Flutter App',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final centrifugo = data['centrifugo'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final role =
          user['active_mode'] as String? ?? user['role'] as String? ?? 'parent';
      await apiClient.persistSession(generation, () async {
        await _safeWrite(AppConstants.keyAuthToken, token);
        await _safeWrite(AppConstants.keyUserData, jsonEncode(user));
        await _safeWrite(AppConstants.keyActiveMode, role);
        await _safeWrite(AppConstants.keyCentrifugoToken, centrifugo['token']);
        await _safeWrite(AppConstants.keyCentrifugoWsUrl, centrifugo['ws_url']);
      }, activate: true);
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException.fromError(e);
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final generation = apiClient.sessionGeneration;
    try {
      final response = await apiClient.dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        await apiClient.persistSession(
          generation,
          () => _safeWrite(AppConstants.keyUserData, jsonEncode(user)),
        );
      }

      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException.fromError(e);
    }
  }

  Future<Map<String, dynamic>> registerParent({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? fcmToken,
  }) async {
    try {
      await apiClient.endSession();
      final generation = apiClient.sessionGeneration;
      final response = await apiClient.dio.post(
        '/auth/register-parent',
        data: {
          'name': name,
          'phone': phone,
          'password': password,
          if (email != null && email.isNotEmpty) 'email': email,
          'fcm_token': fcmToken,
          'device_name': 'Ridin Flutter App (Parent)',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final centrifugo = data['centrifugo'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      await apiClient.persistSession(generation, () async {
        await _safeWrite(AppConstants.keyAuthToken, token);
        await _safeWrite(AppConstants.keyUserData, jsonEncode(user));
        await _safeWrite(AppConstants.keyActiveMode, 'parent');
        await _safeWrite(AppConstants.keyCentrifugoToken, centrifugo['token']);
        await _safeWrite(AppConstants.keyCentrifugoWsUrl, centrifugo['ws_url']);
      }, activate: true);
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException.fromError(e);
    }
  }

  Future<void> logout() async {
    final token = await getAuthToken();
    await apiClient.endSession();
    try {
      await apiClient.dio.post(
        '/auth/logout',
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> refreshSession() async {
    final generation = apiClient.sessionGeneration;
    final response = await apiClient.dio.get('/auth/session');
    final user = Map<String, dynamic>.from(response.data['user'] as Map);
    user['allowed_modes'] = response.data['allowed_modes'];
    await apiClient.persistSession(
      generation,
      () => _safeWrite(AppConstants.keyUserData, jsonEncode(user)),
    );
    return user;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final rawUser = await _safeRead(AppConstants.keyUserData);
    if (rawUser == null) return null;
    try {
      return jsonDecode(rawUser) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getActiveMode() async {
    return await _safeRead(AppConstants.keyActiveMode);
  }

  Future<String?> getCentrifugoToken() async {
    return await _safeRead(AppConstants.keyCentrifugoToken);
  }

  Future<String?> getCentrifugoWsUrl() async {
    return await _safeRead(AppConstants.keyCentrifugoWsUrl);
  }

  Future<String?> getAuthToken() async {
    return await _safeRead(AppConstants.keyAuthToken);
  }

  Future<void> setActiveMode(String mode) async {
    final generation = apiClient.sessionGeneration;
    await apiClient.dio.post('/auth/switch-mode', data: {'mode': mode});
    await apiClient.persistSession(
      generation,
      () => _safeWrite(AppConstants.keyActiveMode, mode),
    );
  }
}
