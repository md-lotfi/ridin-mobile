import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'logging_interceptor.dart';

class ApiClient {
  late final Dio dio;
  static const _androidOptions = AndroidOptions(resetOnError: true);
  final FlutterSecureStorage _storage;
  final _sessionEnded = StreamController<int>.broadcast(sync: true);
  Future<void>? _invalidating;
  int _generation = 0;
  Future<void> _storageTail = Future<void>.value();

  int get sessionGeneration => _generation;
  Stream<int> get sessionEnded => _sessionEnded.stream;

  ApiClient({String? baseUrl, FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: _androidOptions) {
    final apiUrl = baseUrl ?? AppConstants.apiBaseUrl;
    if (kReleaseMode && Uri.parse(apiUrl).scheme != 'https') {
      throw StateError('A production HTTPS API_BASE_URL is required.');
    }
    dio = Dio(
      BaseOptions(
        baseUrl: apiUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final generation = _generation;
          options.extra['session_generation'] = generation;
          final publicAuth =
              options.path == '/auth/login' ||
              options.path == '/auth/register-parent';
          try {
            final token = publicAuth
                ? null
                : await _storage.read(key: AppConstants.keyAuthToken);
            if (generation != _generation) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                ),
              );
            }
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            await endSession();
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.requestOptions.extra['session_generation'] !=
              _generation) {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                type: DioExceptionType.cancel,
              ),
            );
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['session_generation'] == _generation &&
              error.requestOptions.headers.containsKey('Authorization')) {
            await endSession();
          }
          handler.next(error);
        },
      ),
      LoggingInterceptor(),
    ]);
  }

  void activateSession() => _generation++;

  Future<void> persistSession(
    int generation,
    Future<void> Function() persist, {
    bool activate = false,
  }) {
    final future = _storageTail.then((_) async {
      if (generation != _generation) throw StateError('Session changed');
      await persist();
      if (generation != _generation) throw StateError('Session changed');
      if (activate) activateSession();
    });
    _storageTail = future.catchError((_) {});
    return future;
  }

  Future<void> endSession() {
    final pending = _invalidating;
    if (pending != null) return pending;
    _generation++;
    final future = _storageTail.then((_) => _clearSession());
    _storageTail = future.catchError((_) {});
    final tracked = future.whenComplete(() => _invalidating = null);
    _invalidating = tracked;
    _sessionEnded.add(_generation);
    return tracked;
  }

  Future<void> _clearSession() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyOfflineBreadcrumbs);
    } catch (_) {}
  }
}
