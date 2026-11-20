import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/login_response.dart';
import '../services/auth_service.dart';

/// Explicit authentication statuses for the application lifecycle.
enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
}

/// Provider managing authentication state, login, logout, and token restoration.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initializing;
  bool _isLoading = false;
  String? _username;
  String? _token;
  String? _errorMessage;

  AuthProvider({AuthService? authService, bool autoInitialize = true})
      : _authService = authService ?? AuthService() {
    if (autoInitialize) {
      initializeAuth();
    }
  }

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isInitializing => _status == AuthStatus.initializing;
  String? get username => _username;
  String? get token => _token;
  String? get errorMessage => _errorMessage;

  /// Initializes authentication state by inspecting persistent storage.
  /// Does not make unnecessary network calls.
  Future<void> initializeAuth() async {
    _status = AuthStatus.initializing;
    notifyListeners();

    try {
      final storedToken = await _authService.getStoredToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        _token = storedToken;
        _username = await _authService.getStoredUsername();
        _status = AuthStatus.authenticated;
      } else {
        _token = null;
        _username = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _token = null;
      _username = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  /// Attempts to authenticate with the provided credentials.
  /// Prevents concurrent or overlapping login submissions.
  Future<bool> login(String username, String password) async {
    if (_isLoading) {
      return false; // Prevent duplicate concurrent requests
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final LoginResponse response = await _authService.login(username, password);
      _token = response.token;
      _username = response.username;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during login.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs out the user, clears stored credentials, and notifies listeners.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } finally {
      _token = null;
      _username = null;
      _errorMessage = null;
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Triggered when the API client encounters a 401 on a protected request.
  /// Clears stored credentials and resets state to unauthenticated safely.
  Future<void> handleAuthInvalidation() async {
    if (_status == AuthStatus.unauthenticated) {
      return; // Already unauthenticated; idempotent
    }

    try {
      await _authService.logout();
    } catch (_) {}

    _token = null;
    _username = null;
    _errorMessage = 'Your session has expired. Please log in again.';
    _status = AuthStatus.unauthenticated;
    _isLoading = false;
    notifyListeners();
  }

  /// Clears any active error message.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
