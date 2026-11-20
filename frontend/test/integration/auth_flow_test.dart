import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/api_config.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/vehicle_list_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/token_storage.dart';
import 'package:frontend/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('End-to-End Authentication Flow Integration Tests', () {
    late TokenStorage tokenStorage;
    late http.Client mockHttpClient;
    bool return401OnProtected = false;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = TokenStorage();
      ApiConfig.resetBaseUrl();
      return401OnProtected = false;

      mockHttpClient = MockClient((request) async {
        // Mock Login Endpoint
        if (request.url.path == ApiConfig.loginPath) {
          final body = jsonDecode(request.body);
          if (body['username'] == 'admin' && body['password'] == 'Admin@123') {
            return http.Response(
              jsonEncode({
                'token': 'integration-jwt-token-999',
                'tokenType': 'Bearer',
                'expiresIn': 3600,
                'username': 'admin',
              }),
              200,
            );
          } else {
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
          }
        }

        // Mock Protected Endpoint
        if (request.url.path.startsWith('/api/vehicles')) {
          if (return401OnProtected) {
            return http.Response(
              jsonEncode({
                'timestamp': '2026-11-20T10:00:00',
                'status': 401,
                'error': 'Unauthorized',
                'message': 'JWT token expired or invalid',
                'fieldErrors': {},
              }),
              401,
            );
          }
          return http.Response(jsonEncode([]), 200);
        }

        return http.Response('Not Found', 404);
      });
    });

    testWidgets('Complete Authentication Lifecycle', (tester) async {
      // Setup API client, AuthService, and AuthProvider wiring
      AuthProvider? currentAuthProvider;
      final apiClient = ApiClient(
        httpClient: mockHttpClient,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          currentAuthProvider?.handleAuthInvalidation();
        },
      );

      final authService = AuthService(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      final authProvider = AuthProvider(
        authService: authService,
        autoInitialize: false,
      );
      currentAuthProvider = authProvider;

      // 1. Application starts without a token
      expect(await tokenStorage.getToken(), isNull);
      await authProvider.initializeAuth();
      expect(authProvider.status, AuthStatus.unauthenticated);

      await tester.pumpWidget(StarkVmsApp(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Verify Login Screen is displayed
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Stark VMS'), findsOneWidget);
      expect(find.text('Sign in to your vehicle management account'), findsOneWidget);

      // 2. Login with valid credentials
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'admin');
      await tester.enterText(textFields.last, 'Admin@123');

      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      // 3. JWT is persisted in TokenStorage
      final persistedToken = await tokenStorage.getToken();
      expect(persistedToken, 'integration-jwt-token-999');
      expect(await tokenStorage.getUsername(), 'admin');

      // 4. Authenticated screen becomes accessible
      expect(find.byType(VehicleListScreen), findsOneWidget);
      expect(find.text('Vehicle Management'), findsAtLeastNWidgets(1));
      expect(find.text('admin'), findsOneWidget);

      // 5. Browser refresh simulation:
      // A new provider instance inspects persistent storage without making network calls
      final refreshedAuthProvider = AuthProvider(
        authService: authService,
        autoInitialize: false,
      );
      currentAuthProvider = refreshedAuthProvider;
      await refreshedAuthProvider.initializeAuth();
      expect(refreshedAuthProvider.status, AuthStatus.authenticated);
      expect(refreshedAuthProvider.token, 'integration-jwt-token-999');
      expect(refreshedAuthProvider.username, 'admin');

      await tester.pumpWidget(StarkVmsApp(authProvider: refreshedAuthProvider));
      await tester.pumpAndSettle();

      // Still on vehicle list screen after reload
      expect(find.byType(VehicleListScreen), findsOneWidget);

      // 6. Protected request receiving 401 invalidates authentication
      return401OnProtected = true;

      // Make protected request that receives 401
      expect(
        () => apiClient.get('/api/vehicles'),
        throwsA(isA<ApiException>()),
      );

      // Wait a microtask for callback execution
      await tester.pump();
      await tester.pumpAndSettle();

      // 7. User is redirected to login with expiration message
      expect(refreshedAuthProvider.status, AuthStatus.unauthenticated);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('Your session has expired. Please log in again.'),
        findsOneWidget,
      );

      // 8. Re-login and explicit logout clears token and state
      return401OnProtected = false;
      final reLoginTextFields = find.byType(TextFormField);
      await tester.enterText(reLoginTextFields.first, 'admin');
      await tester.enterText(reLoginTextFields.last, 'Admin@123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleListScreen), findsOneWidget);
      expect(await tokenStorage.getToken(), isNotNull);

      // Tap logout action
      final logoutButton = find.byTooltip('Sign Out');
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Token and state cleared, redirected to login
      expect(await tokenStorage.getToken(), isNull);
      expect(await tokenStorage.getUsername(), isNull);
      expect(refreshedAuthProvider.status, AuthStatus.unauthenticated);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
