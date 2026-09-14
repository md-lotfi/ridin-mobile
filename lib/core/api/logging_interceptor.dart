import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Professional, zero-dependency Dio Interceptor that prints structured,
/// styled console logs with sanitized credentials and response latencies.
class LoggingInterceptor extends Interceptor {
  final _stopwatches = <RequestOptions, Stopwatch>{};

  static const _sensitiveKeys = {
    'password',
    'password_confirmation',
    'token',
    'fcm_token',
    'secret',
    'current_password',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kDebugMode) {
      return handler.next(options);
    }

    final sw = Stopwatch()..start();
    _stopwatches[options] = sw;

    final url = options.uri.toString();
    final method = options.method.toUpperCase();

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ 🚀 HTTP REQUEST: [$method] $url');

    // Headers
    if (options.headers.isNotEmpty) {
      final sanitizedHeaders = Map<String, dynamic>.from(options.headers).map(
        (key, value) {
          if (key.toLowerCase() == 'authorization' && value is String) {
            final parts = value.split(' ');
            return MapEntry(
              key,
              parts.length > 1 ? '${parts[0]} ***' : '***',
            );
          }
          return MapEntry(key, value);
        },
      );
      debugPrint('│ Headers: $sanitizedHeaders');
    }

    // Query Parameters
    if (options.queryParameters.isNotEmpty) {
      debugPrint('│ QueryParams: ${options.queryParameters}');
    }

    // Body
    if (options.data != null) {
      final sanitized = _sanitizeData(options.data);
      try {
        final prettyJson = const JsonEncoder.withIndent('  ').convert(sanitized);
        debugPrint('│ Body: $prettyJson');
      } catch (_) {
        debugPrint('│ Body: $sanitized');
      }
    }

    debugPrint('└─────────────────────────────────────────────────────────────');

    return handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (!kDebugMode) {
      return handler.next(response);
    }

    final sw = _stopwatches.remove(response.requestOptions);
    final durationMs = sw?.elapsedMilliseconds ?? 0;

    final statusCode = response.statusCode ?? 200;
    final method = response.requestOptions.method.toUpperCase();
    final path = response.requestOptions.uri.path;

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ ✅ HTTP RESPONSE: [$method] $path | Status: $statusCode (${durationMs}ms)');

    if (response.data != null) {
      final sanitized = _sanitizeData(response.data);
      try {
        final prettyJson = const JsonEncoder.withIndent('  ').convert(sanitized);
        final lines = prettyJson.split('\n');
        if (lines.length > 30) {
          final truncated = lines.take(30).join('\n');
          debugPrint('│ Data: $truncated\n│ ... [truncated ${lines.length - 30} lines]');
        } else {
          debugPrint('│ Data: $prettyJson');
        }
      } catch (_) {
        debugPrint('│ Data: $sanitized');
      }
    }

    debugPrint('└─────────────────────────────────────────────────────────────');

    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!kDebugMode) {
      return handler.next(err);
    }

    final sw = _stopwatches.remove(err.requestOptions);
    final durationMs = sw?.elapsedMilliseconds ?? 0;

    final statusCode = err.response?.statusCode ?? 'N/A';
    final method = err.requestOptions.method.toUpperCase();
    final path = err.requestOptions.uri.path;

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ ❌ HTTP ERROR: [$method] $path | Status: $statusCode (${durationMs}ms)');
    debugPrint('│ Type: ${err.type}');

    if (err.response?.data != null) {
      try {
        final prettyJson = const JsonEncoder.withIndent('  ').convert(err.response!.data);
        debugPrint('│ Response Error: $prettyJson');
      } catch (_) {
        debugPrint('│ Response Error: ${err.response?.data}');
      }
    } else {
      debugPrint('│ Message: ${err.message}');
    }

    debugPrint('└─────────────────────────────────────────────────────────────');

    return handler.next(err);
  }

  dynamic _sanitizeData(dynamic data) {
    if (data is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final keyStr = entry.key.toString();
        if (_sensitiveKeys.contains(keyStr.toLowerCase())) {
          sanitized[keyStr] = '***';
        } else if (entry.value is Map || entry.value is List) {
          sanitized[keyStr] = _sanitizeData(entry.value);
        } else {
          sanitized[keyStr] = entry.value;
        }
      }
      return sanitized;
    } else if (data is List) {
      return data.map(_sanitizeData).toList();
    }
    return data;
  }
}
