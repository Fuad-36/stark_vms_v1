import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/api_error.dart';

void main() {
  group('ApiErrorResponse Model', () {
    test('parses full backend error response correctly', () {
      final json = {
        'timestamp': '2026-11-20T10:00:00',
        'status': 400,
        'error': 'Bad Request',
        'message': 'Validation failed',
        'fieldErrors': {
          'vehicleNumber': 'Vehicle number already exists',
        },
      };

      final error = ApiErrorResponse.fromJson(json);
      expect(error.timestamp, '2026-11-20T10:00:00');
      expect(error.status, 400);
      expect(error.error, 'Bad Request');
      expect(error.message, 'Validation failed');
      expect(error.fieldErrors['vehicleNumber'], 'Vehicle number already exists');
    });

    test('handles empty or missing fieldErrors safely', () {
      final json = {
        'timestamp': '2026-11-20T10:00:00',
        'status': 401,
        'error': 'Unauthorized',
        'message': 'Invalid username or password',
        'fieldErrors': {},
      };

      final error = ApiErrorResponse.fromJson(json);
      expect(error.status, 401);
      expect(error.message, 'Invalid username or password');
      expect(error.fieldErrors, isEmpty);
    });

    test('handles null or missing fields gracefully', () {
      final json = <String, dynamic>{};
      final error = ApiErrorResponse.fromJson(json);
      expect(error.status, 0);
      expect(error.message, 'An unexpected error occurred');
      expect(error.fieldErrors, isEmpty);
    });
  });

  group('ApiException Model', () {
    test('fromResponse extracts data from backend error body', () {
      final body = {
        'timestamp': '2026-11-20T10:00:00',
        'status': 401,
        'error': 'Unauthorized',
        'message': 'Invalid credentials',
        'fieldErrors': {},
      };

      final ex = ApiException.fromResponse(401, body);
      expect(ex.statusCode, 401);
      expect(ex.message, 'Invalid credentials');
      expect(ex.error, 'Unauthorized');
      expect(ex.fieldErrors, isEmpty);
    });

    test('fromResponse defaults message when decoded body is empty or non-map', () {
      final ex404 = ApiException.fromResponse(404, null);
      expect(ex404.statusCode, 404);
      expect(ex404.message, 'Requested resource was not found.');

      final ex500 = ApiException.fromResponse(500, 'Plain error text');
      expect(ex500.statusCode, 500);
      expect(ex500.message, 'An internal server error occurred. Please try again later.');
    });

    test('networkError creates connection failure exception', () {
      final ex = ApiException.networkError('Connection refused');
      expect(ex.statusCode, 0);
      expect(ex.message, 'Connection refused');
      expect(ex.error, 'NetworkError');
    });

    test('timeout creates 408 exception', () {
      final ex = ApiException.timeout();
      expect(ex.statusCode, 408);
      expect(ex.message, contains('timed out'));
    });

    test('malformedResponse creates -1 exception', () {
      final ex = ApiException.malformedResponse();
      expect(ex.statusCode, -1);
      expect(ex.message, contains('invalid response'));
    });
  });
}
