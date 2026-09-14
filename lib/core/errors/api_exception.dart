import 'dart:io';
import 'package:dio/dio.dart';

/// Professional API Exception domain model that parses Dio and HTTP errors
/// into localized, human-friendly messages and structured validation error maps.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, List<String>>? validationErrors;
  final dynamic rawResponse;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.validationErrors,
    this.rawResponse,
  });

  /// Factory to construct an [ApiException] from a [DioException].
  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          message: 'Délai d\'attente dépassé. Veuillez vérifier votre connexion internet.',
          code: 'TIMEOUT',
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Impossible de joindre le serveur Ridin. Vérifiez votre réseau ou le serveur.',
          code: 'CONNECTION_ERROR',
        );

      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'Erreur de sécurité SSL lors de la connexion.',
          code: 'BAD_CERTIFICATE',
        );

      case DioExceptionType.cancel:
        return const ApiException(
          message: 'La requête a été annulée.',
          code: 'CANCELLED',
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);

      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const ApiException(
            message: 'Aucune connexion internet disponible.',
            code: 'NO_INTERNET',
          );
        }
        return ApiException(
          message: error.message?.isNotEmpty == true
              ? error.message!
              : 'Une erreur inattendue est survenue.',
          code: 'UNKNOWN',
        );
    }
  }

  /// Parses server HTTP responses (e.g. Laravel 422, 401, 403, 404, 500).
  static ApiException _handleBadResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final data = response?.data;

    // Handle Laravel Validation Error (HTTP 422)
    if (statusCode == 422 && data is Map<String, dynamic>) {
      final errorsMap = <String, List<String>>{};
      String? firstError;

      if (data['errors'] is Map<String, dynamic>) {
        final rawErrors = data['errors'] as Map<String, dynamic>;
        for (final entry in rawErrors.entries) {
          if (entry.value is List) {
            final list = (entry.value as List).map((e) => e.toString()).toList();
            errorsMap[entry.key] = list;
            if (firstError == null && list.isNotEmpty) {
              firstError = list.first;
            }
          } else if (entry.value is String) {
            errorsMap[entry.key] = [entry.value.toString()];
            firstError ??= entry.value.toString();
          }
        }
      }

      final mainMessage = firstError ??
          (data['message'] as String?) ??
          'Les données saisies sont invalides.';

      return ApiException(
        message: mainMessage,
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        validationErrors: errorsMap.isNotEmpty ? errorsMap : null,
        rawResponse: data,
      );
    }

    // Handle 401 Unauthorized
    if (statusCode == 401) {
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Identifiants incorrects ou session expirée.';
      return ApiException(
        message: msg,
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        rawResponse: data,
      );
    }

    // Handle 403 Forbidden
    if (statusCode == 403) {
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Accès refusé. Vous n\'avez pas l\'autorisation requise.';
      return ApiException(
        message: msg,
        statusCode: 403,
        code: 'FORBIDDEN',
        rawResponse: data,
      );
    }

    // Handle 404 Not Found
    if (statusCode == 404) {
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'La ressource demandée est introuvable.';
      return ApiException(
        message: msg,
        statusCode: 404,
        code: 'NOT_FOUND',
        rawResponse: data,
      );
    }

    // Handle 429 Rate Limiting
    if (statusCode == 429) {
      return const ApiException(
        message: 'Trop de requêtes envoyées. Veuillez patienter un instant.',
        statusCode: 429,
        code: 'RATE_LIMITED',
      );
    }

    // Handle 500+ Internal Server Errors
    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        message: 'Erreur interne du serveur ($statusCode). Veuillez réessayer plus tard.',
        statusCode: statusCode,
        code: 'SERVER_ERROR',
        rawResponse: data,
      );
    }

    // Fallback: extract 'message' if present
    if (data is Map && data['message'] is String) {
      return ApiException(
        message: data['message'] as String,
        statusCode: statusCode,
        code: 'API_ERROR',
        rawResponse: data,
      );
    }

    return ApiException(
      message: 'Erreur réseau ($statusCode). Veuillez réessayer.',
      statusCode: statusCode,
      code: 'HTTP_ERROR',
      rawResponse: data,
    );
  }

  /// General factory from any error object.
  factory ApiException.fromError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    if (error is DioException) {
      return ApiException.fromDioError(error);
    }
    return ApiException(
      message: error?.toString() ?? 'Une erreur inconnue est survenue.',
      code: 'GENERIC_ERROR',
    );
  }

  /// Formatted multi-line summary of all validation errors.
  String get formattedErrors {
    if (validationErrors == null || validationErrors!.isEmpty) {
      return message;
    }
    final buffer = StringBuffer();
    for (final entry in validationErrors!.entries) {
      for (final err in entry.value) {
        buffer.writeln('• $err');
      }
    }
    return buffer.toString().trim();
  }

  @override
  String toString() => message;
}
