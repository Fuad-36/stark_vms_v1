import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for managing persistent JWT token and user session data.
///
/// NOTE ON SECURITY:
/// On Flutter Web, [SharedPreferences] persists data using browser localStorage.
/// Browser-side localStorage is accessible to client-side JavaScript and does NOT
/// provide HttpOnly cookie-level protection against Cross-Site Scripting (XSS).
/// Sensitive tokens must never be logged or exposed outside authenticated operations.
class TokenStorage {
  static const String _tokenKey = 'stark_vms_jwt_token';
  static const String _usernameKey = 'stark_vms_username';

  final SharedPreferences? _prefsInstance;

  TokenStorage([this._prefsInstance]);

  Future<SharedPreferences> get _prefs async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  /// Persists the JWT [token].
  Future<void> saveToken(String token) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_tokenKey, token);
    } catch (_) {
      // Handle storage failure gracefully without crashing
    }
  }

  /// Retrieves the stored JWT token, or null if not present or invalid.
  Future<String?> getToken() async {
    try {
      final prefs = await _prefs;
      final token = prefs.getString(_tokenKey);
      if (token == null || token.trim().isEmpty) {
        return null;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Removes the stored JWT token.
  Future<void> deleteToken() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_tokenKey);
    } catch (_) {
      // Handle storage failure gracefully
    }
  }

  /// Persists the authenticated [username].
  Future<void> saveUsername(String username) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_usernameKey, username);
    } catch (_) {
      // Handle storage failure gracefully
    }
  }

  /// Retrieves the persisted username, or null if not present.
  Future<String?> getUsername() async {
    try {
      final prefs = await _prefs;
      final username = prefs.getString(_usernameKey);
      if (username == null || username.trim().isEmpty) {
        return null;
      }
      return username;
    } catch (_) {
      return null;
    }
  }

  /// Clears all session credentials (token and username).
  Future<void> clearSession() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_tokenKey);
      await prefs.remove(_usernameKey);
    } catch (_) {
      // Handle storage failure gracefully
    }
  }
}
