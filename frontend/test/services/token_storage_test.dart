import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TokenStorage', () {
    late TokenStorage tokenStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = TokenStorage();
    });

    test('returns null when no token is stored', () async {
      final token = await tokenStorage.getToken();
      expect(token, isNull);
    });

    test('saves and retrieves JWT token correctly', () async {
      await tokenStorage.saveToken('jwt.sample.token');
      final token = await tokenStorage.getToken();
      expect(token, 'jwt.sample.token');
    });

    test('deletes JWT token correctly', () async {
      await tokenStorage.saveToken('jwt.sample.token');
      await tokenStorage.deleteToken();
      final token = await tokenStorage.getToken();
      expect(token, isNull);
    });

    test('saves and retrieves username correctly', () async {
      await tokenStorage.saveUsername('admin');
      final username = await tokenStorage.getUsername();
      expect(username, 'admin');
    });

    test('clearSession clears both token and username', () async {
      await tokenStorage.saveToken('jwt.sample.token');
      await tokenStorage.saveUsername('admin');

      await tokenStorage.clearSession();

      expect(await tokenStorage.getToken(), isNull);
      expect(await tokenStorage.getUsername(), isNull);
    });

    test('returns null when stored token is whitespace only', () async {
      SharedPreferences.setMockInitialValues({
        'stark_vms_jwt_token': '   ',
      });
      final token = await tokenStorage.getToken();
      expect(token, isNull);
    });
  });
}
