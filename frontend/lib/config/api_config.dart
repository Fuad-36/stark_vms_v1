/// Configuration for backend API endpoints and networking parameters.
class ApiConfig {
  ApiConfig._();

  /// Default development base URL.
  static const String _defaultBaseUrl = 'http://localhost:8080';

  /// Environment variable or runtime configurable base URL.
  static String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// Current base URL for API requests.
  static String get baseUrl => _baseUrl;

  /// Sets the base URL (useful for testing or dynamic environment switching).
  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Resets the base URL to default.
  static void resetBaseUrl() {
    _baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: _defaultBaseUrl,
    );
  }

  /// Default network request timeout.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Authentication endpoints.
  static const String loginPath = '/api/auth/login';

  /// Full URL for login endpoint.
  static Uri get loginUri => Uri.parse('$baseUrl$loginPath');
}
