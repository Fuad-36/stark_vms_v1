import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/login_request.dart';
import 'package:frontend/models/login_response.dart';

void main() {
  group('LoginRequest Model', () {
    test('serializes to JSON correctly', () {
      const request = LoginRequest(
        username: 'admin',
        password: 'Admin@123',
      );
      final json = request.toJson();
      expect(json['username'], 'admin');
      expect(json['password'], 'Admin@123');
    });
  });

  group('LoginResponse Model', () {
    test('deserializes valid JSON correctly', () {
      final json = {
        'token': 'jwt.token.here',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
        'username': 'admin',
      };

      final response = LoginResponse.fromJson(json);
      expect(response.token, 'jwt.token.here');
      expect(response.tokenType, 'Bearer');
      expect(response.expiresIn, 3600);
      expect(response.username, 'admin');
    });

    test('handles string expiresIn gracefully', () {
      final json = {
        'token': 'jwt.token.here',
        'tokenType': 'Bearer',
        'expiresIn': '7200',
        'username': 'operator',
      };

      final response = LoginResponse.fromJson(json);
      expect(response.expiresIn, 7200);
    });

    test('defaults tokenType to Bearer when missing', () {
      final json = {
        'token': 'token123',
        'expiresIn': 3600,
        'username': 'operator',
      };

      final response = LoginResponse.fromJson(json);
      expect(response.tokenType, 'Bearer');
    });

    test('throws FormatException when token is missing or empty', () {
      expect(
        () => LoginResponse.fromJson({'username': 'admin'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LoginResponse.fromJson({'token': '', 'username': 'admin'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when username is missing or empty', () {
      expect(
        () => LoginResponse.fromJson({'token': 'token123'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LoginResponse.fromJson({'token': 'token123', 'username': ''}),
        throwsA(isA<FormatException>()),
      );
    });

    test('serializes to JSON correctly', () {
      const response = LoginResponse(
        token: 'token123',
        tokenType: 'Bearer',
        expiresIn: 3600,
        username: 'admin',
      );
      final json = response.toJson();
      expect(json['token'], 'token123');
      expect(json['tokenType'], 'Bearer');
      expect(json['expiresIn'], 3600);
      expect(json['username'], 'admin');
    });
  });
}
