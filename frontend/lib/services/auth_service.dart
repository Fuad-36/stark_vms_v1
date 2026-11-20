import '../config/api_config.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// Service responsible for authentication operations (login, logout, session persistence).
class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _tokenStorage = tokenStorage ?? TokenStorage(),
        _apiClient = apiClient ?? ApiClient(tokenStorage: tokenStorage);

  /// Authenticates with the backend using [username] and [password].
  ///
  /// On success, deserializes [LoginResponse], persists the JWT token and username,
  /// and returns the [LoginResponse].
  /// Setting [authenticated] to false ensures no Authorization header is attached.
  Future<LoginResponse> login(String username, String password) async {
    final request = LoginRequest(
      username: username.trim(),
      password: password,
    );

    final responseData = await _apiClient.post(
      ApiConfig.loginPath,
      body: request.toJson(),
      authenticated: false,
    );

    if (responseData is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response format received from login endpoint');
    }

    final loginResponse = LoginResponse.fromJson(responseData);

    // Persist JWT token and username
    await _tokenStorage.saveToken(loginResponse.token);
    await _tokenStorage.saveUsername(loginResponse.username);

    return loginResponse;
  }

  /// Clears persisted authentication credentials.
  Future<void> logout() async {
    await _tokenStorage.clearSession();
  }

  /// Checks if a persisted JWT token exists.
  Future<String?> getStoredToken() => _tokenStorage.getToken();

  /// Retrieves the persisted username if available.
  Future<String?> getStoredUsername() => _tokenStorage.getUsername();
}
