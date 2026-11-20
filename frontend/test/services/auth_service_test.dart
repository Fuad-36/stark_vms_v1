import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/api_config.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthService', () {
    late TokenStorage tokenStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = TokenStorage();
      ApiConfig.resetBaseUrl();
    });

    test('login succeeds and persists token & username', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, ApiConfig.loginPath);
        final body = jsonDecode(request.body);
        expect(body['username'], 'admin');
        expect(body['password'], 'Admin@123');

        return http.Response(
          jsonEncode({
            'token': 'mock-jwt-token-xyz',
            'tokenType': 'Bearer',
            'expiresIn': 3600,
            'username': 'admin',
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );
      final authService = AuthService(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      final response = await authService.login('admin', 'Admin@123');

      expect(response.token, 'mock-jwt-token-xyz');
      expect(response.username, 'admin');

      // Verify persistence in TokenStorage
      expect(await tokenStorage.getToken(), 'mock-jwt-token-xyz');
      expect(await tokenStorage.getUsername(), 'admin');
    });

    test('login failure throws ApiException and does not persist token', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'timestamp': '2026-11-20T10:00:00',
            'status': 401,
            'error': 'Unauthorized',
            'message': 'Invalid username or password',
            'fieldErrors': {},
          }),
          401,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
      );
      final authService = AuthService(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      expect(
        () => authService.login('admin', 'wrong-pass'),
        throwsA(predicate((e) =>
            e is ApiException &&
            e.statusCode == 401 &&
            e.message == 'Invalid username or password')),
      );

      expect(await tokenStorage.getToken(), isNull);
    });

    test('logout clears stored token and username', () async {
      await tokenStorage.saveToken('existing-token');
      await tokenStorage.saveUsername('admin');

      final authService = AuthService(
        tokenStorage: tokenStorage,
      );

      await authService.logout();

      expect(await tokenStorage.getToken(), isNull);
      expect(await tokenStorage.getUsername(), isNull);
    });
  });
}
