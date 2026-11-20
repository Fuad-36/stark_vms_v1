import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/api_config.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ApiClient', () {
    late TokenStorage tokenStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = TokenStorage();
      ApiConfig.resetBaseUrl();
    });

    test('attaches Authorization header when token is present on authenticated request', () async {
      await tokenStorage.saveToken('test-jwt-token');

      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );

      final result = await apiClient.get('/api/protected/resource');
      expect(result['status'], 'ok');
      expect(capturedAuthHeader, 'Bearer test-jwt-token');
    });

    test('does NOT attach Authorization header when authenticated is false', () async {
      await tokenStorage.saveToken('test-jwt-token');

      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );

      await apiClient.post(ApiConfig.loginPath, authenticated: false);
      expect(capturedAuthHeader, isNull);
    });

    test('handles 200 OK JSON responses successfully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'success'}), 200);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );

      final response = await apiClient.get('/api/test');
      expect(response['message'], 'success');
    });

    test('converts 400 Bad Request with field errors into ApiException', () async {
      final mockClient = MockClient((request) async {
        final errorBody = {
          'timestamp': '2026-11-20T10:00:00',
          'status': 400,
          'error': 'Bad Request',
          'message': 'Validation failed',
          'fieldErrors': {'username': 'Username is required'},
        };
        return http.Response(jsonEncode(errorBody), 400);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );

      expect(
        () => apiClient.post('/api/test', body: {}),
        throwsA(predicate((e) =>
            e is ApiException &&
            e.statusCode == 400 &&
            e.message == 'Validation failed' &&
            e.fieldErrors['username'] == 'Username is required')),
      );
    });

    test('triggers onAuthenticationExpired on 401 for protected API request', () async {
      int invalidationCount = 0;
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 401,
            'error': 'Unauthorized',
            'message': 'Token expired',
          }),
          401,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          invalidationCount++;
        },
      );

      expect(
        () => apiClient.get('/api/protected/vehicles'),
        throwsA(isA<ApiException>()),
      );

      // Wait a microtask cycle for invalidation callback
      await Future.delayed(Duration.zero);
      expect(invalidationCount, 1);
    });

    test('does NOT trigger onAuthenticationExpired on 401 from login endpoint', () async {
      int invalidationCount = 0;
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 401,
            'error': 'Unauthorized',
            'message': 'Invalid username or password',
          }),
          401,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          invalidationCount++;
        },
      );

      expect(
        () => apiClient.post(ApiConfig.loginPath, authenticated: false),
        throwsA(isA<ApiException>()),
      );

      await Future.delayed(Duration.zero);
      expect(invalidationCount, 0);
    });

    test('does NOT trigger onAuthenticationExpired on 403 Forbidden', () async {
      int invalidationCount = 0;
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 403,
            'error': 'Forbidden',
            'message': 'Access is denied',
          }),
          403,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          invalidationCount++;
        },
      );

      expect(
        () => apiClient.get('/api/protected/admin-only'),
        throwsA(isA<ApiException>()),
      );

      await Future.delayed(Duration.zero);
      expect(invalidationCount, 0);
    });

    test('deduplicates multiple concurrent 401 responses', () async {
      int invalidationCount = 0;
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 401, 'message': 'Session expired'}),
          401,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          invalidationCount++;
        },
      );

      // Fire concurrent protected requests and attach expectations immediately
      final future1 = apiClient.get('/api/protected/1');
      final future2 = apiClient.get('/api/protected/2');

      expect(future1, throwsA(isA<ApiException>()));
      expect(future2, throwsA(isA<ApiException>()));

      await Future.wait([
        future1.catchError((_) => null),
        future2.catchError((_) => null),
      ]);

      await Future.delayed(Duration.zero);
      expect(invalidationCount, 1);
    });

    test('handles network exceptions gracefully', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );

      expect(
        () => apiClient.get('/api/test'),
        throwsA(predicate((e) =>
            e is ApiException &&
            e.statusCode == 0 &&
            e.error == 'NetworkError')),
      );
    });

    test('handles malformed JSON gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>502 Bad Gateway</body></html>', 502);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );

      expect(
        () => apiClient.get('/api/test'),
        throwsA(predicate((e) =>
            e is ApiException &&
            e.statusCode == 502 &&
            e.message.contains('502 Bad Gateway'))),
      );
    });
  });
}
