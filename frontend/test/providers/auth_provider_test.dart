import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/models/login_response.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthService implements AuthService {
  String? storedToken;
  String? storedUsername;
  bool shouldFailLogin = false;
  String failureMessage = 'Invalid username or password';

  @override
  Future<LoginResponse> login(String username, String password) async {
    if (shouldFailLogin) {
      throw ApiException(statusCode: 401, message: failureMessage);
    }
    storedToken = 'fake-jwt-token';
    storedUsername = username;
    return LoginResponse(
      token: storedToken!,
      tokenType: 'Bearer',
      expiresIn: 3600,
      username: username,
    );
  }

  @override
  Future<void> logout() async {
    storedToken = null;
    storedUsername = null;
  }

  @override
  Future<String?> getStoredToken() async => storedToken;

  @override
  Future<String?> getStoredUsername() async => storedUsername;
}

void main() {
  group('AuthProvider', () {
    late FakeAuthService fakeAuthService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeAuthService = FakeAuthService();
    });

    test('initializes to unauthenticated when no stored token exists', () async {
      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );

      expect(provider.status, AuthStatus.initializing);

      await provider.initializeAuth();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, false);
      expect(provider.token, isNull);
    });

    test('initializes to authenticated when stored token exists', () async {
      fakeAuthService.storedToken = 'persisted-token';
      fakeAuthService.storedUsername = 'persisted-user';

      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );

      await provider.initializeAuth();

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.isAuthenticated, true);
      expect(provider.token, 'persisted-token');
      expect(provider.username, 'persisted-user');
    });

    test('login success updates status and clears error', () async {
      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );
      await provider.initializeAuth();

      final success = await provider.login('admin', 'Admin@123');

      expect(success, true);
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.isAuthenticated, true);
      expect(provider.token, 'fake-jwt-token');
      expect(provider.username, 'admin');
      expect(provider.errorMessage, isNull);
    });

    test('login failure sets errorMessage and retains unauthenticated state', () async {
      fakeAuthService.shouldFailLogin = true;
      fakeAuthService.failureMessage = 'Invalid username or password';

      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );
      await provider.initializeAuth();

      final success = await provider.login('admin', 'wrong');

      expect(success, false);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, false);
      expect(provider.errorMessage, 'Invalid username or password');
    });

    test('prevents overlapping duplicate login calls', () async {
      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );
      await provider.initializeAuth();

      // Initiate first login and immediate second login
      final future1 = provider.login('admin', 'Admin@123');
      final future2 = provider.login('admin', 'Admin@123');

      final results = await Future.wait([future1, future2]);
      // One succeeds, second duplicate is rejected immediately
      expect(results, containsAll([true, false]));
    });

    test('logout clears credentials and transitions to unauthenticated', () async {
      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );
      await provider.initializeAuth();
      await provider.login('admin', 'Admin@123');

      expect(provider.isAuthenticated, true);

      await provider.logout();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, false);
      expect(provider.token, isNull);
      expect(provider.username, isNull);
    });

    test('handleAuthInvalidation clears state and provides expiration message', () async {
      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );
      await provider.initializeAuth();
      await provider.login('admin', 'Admin@123');

      await provider.handleAuthInvalidation();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, false);
      expect(provider.token, isNull);
      expect(provider.errorMessage, contains('expired'));
    });

    test('clearError resets error message', () async {
      fakeAuthService.shouldFailLogin = true;
      final provider = AuthProvider(
        authService: fakeAuthService,
        autoInitialize: false,
      );
      await provider.initializeAuth();
      await provider.login('admin', 'wrong');

      expect(provider.errorMessage, isNotNull);
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });
  });
}
