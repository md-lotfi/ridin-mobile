import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridin/core/errors/api_exception.dart';

void main() {
  group('ApiException unit tests', () {
    test('parses Laravel 422 validation error with multiple fields correctly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/auth/register-driver'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register-driver'),
          statusCode: 422,
          data: {
            'message': 'The given data was invalid.',
            'errors': {
              'invite_code': ['Code d\'invitation de bus invalide ou inexistant.'],
              'phone': ['Ce numéro de téléphone est déjà associé à un compte.'],
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final exception = ApiException.fromDioError(dioError);

      expect(exception.statusCode, 422);
      expect(exception.code, 'VALIDATION_ERROR');
      expect(exception.message, 'Code d\'invitation de bus invalide ou inexistant.');
      expect(exception.validationErrors, isNotNull);
      expect(exception.validationErrors!['phone'], ['Ce numéro de téléphone est déjà associé à un compte.']);

      final formatted = exception.formattedErrors;
      expect(formatted, contains('• Code d\'invitation de bus invalide ou inexistant.'));
      expect(formatted, contains('• Ce numéro de téléphone est déjà associé à un compte.'));
      expect(exception.toString(), exception.message);
    });

    test('parses 401 unauthorized response correctly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
          data: {'message': 'Unauthenticated.'},
        ),
        type: DioExceptionType.badResponse,
      );

      final exception = ApiException.fromDioError(dioError);

      expect(exception.statusCode, 401);
      expect(exception.code, 'UNAUTHENTICATED');
      expect(exception.message, 'Unauthenticated.');
    });

    test('parses 403 forbidden response correctly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/fleet/radar'),
        response: Response(
          requestOptions: RequestOptions(path: '/fleet/radar'),
          statusCode: 403,
          data: {'message': 'Accès réservé aux gestionnaires de flotte.'},
        ),
        type: DioExceptionType.badResponse,
      );

      final exception = ApiException.fromDioError(dioError);

      expect(exception.statusCode, 403);
      expect(exception.code, 'FORBIDDEN');
      expect(exception.message, 'Accès réservé aux gestionnaires de flotte.');
    });

    test('parses 500 internal server error cleanly', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/trips/start'),
        response: Response(
          requestOptions: RequestOptions(path: '/trips/start'),
          statusCode: 500,
          data: '<html>Server Error</html>',
        ),
        type: DioExceptionType.badResponse,
      );

      final exception = ApiException.fromDioError(dioError);

      expect(exception.statusCode, 500);
      expect(exception.code, 'SERVER_ERROR');
      expect(exception.message, contains('Erreur interne du serveur (500)'));
    });

    test('handles connection timeout error', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionTimeout,
      );

      final exception = ApiException.fromDioError(dioError);

      expect(exception.code, 'TIMEOUT');
      expect(exception.message, contains('Délai d\'attente dépassé'));
    });

    test('handles connection network error', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );

      final exception = ApiException.fromDioError(dioError);

      expect(exception.code, 'CONNECTION_ERROR');
      expect(exception.message, contains('Impossible de joindre le serveur Ridin'));
    });
  });
}
