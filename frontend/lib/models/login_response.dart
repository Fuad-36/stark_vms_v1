/// Represents the successful authentication response from the backend.
class LoginResponse {
  final String token;
  final String tokenType;
  final int expiresIn;
  final String username;

  const LoginResponse({
    required this.token,
    required this.tokenType,
    required this.expiresIn,
    required this.username,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    final tokenType = json['tokenType'] as String? ?? 'Bearer';
    final expiresIn = json['expiresIn'];
    final username = json['username'] as String?;

    if (token == null || token.isEmpty) {
      throw const FormatException('Missing or empty token in login response');
    }
    if (username == null || username.isEmpty) {
      throw const FormatException('Missing or empty username in login response');
    }

    int parsedExpiresIn = 0;
    if (expiresIn is int) {
      parsedExpiresIn = expiresIn;
    } else if (expiresIn is String) {
      parsedExpiresIn = int.tryParse(expiresIn) ?? 0;
    }

    return LoginResponse(
      token: token,
      tokenType: tokenType,
      expiresIn: parsedExpiresIn,
      username: username,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'tokenType': tokenType,
    'expiresIn': expiresIn,
    'username': username,
  };
}
