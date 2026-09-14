import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'logging_interceptor.dart';

class ApiClient {
  late final Dio dio;
  static const _androidOptions = AndroidOptions(resetOnError: true);
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
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
          String? token;
          try {
            token = await _storage.read(key: AppConstants.keyAuthToken);
          } catch (_) {
            token = null;
          }
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await _storage.delete(key: AppConstants.keyAuthToken);
            } catch (_) {}
          }
          return handler.next(error);
        },
      ),
      LoggingInterceptor(),
    ]);
  }
}
