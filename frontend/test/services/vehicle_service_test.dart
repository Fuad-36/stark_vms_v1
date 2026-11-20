import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/token_storage.dart';
import 'package:frontend/services/vehicle_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VehicleService Unit Tests', () {
    late TokenStorage tokenStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({'stark_vms_jwt_token': 'test-jwt-token'});
      tokenStorage = TokenStorage();
    });

    test('Successful response containing multiple vehicles parses correctly', () async {
      final mockData = [
        {
          'id': 1,
          'vehicleNumber': 'KA-01-AB-1234',
          'type': 'CAR',
          'brand': 'Toyota',
          'model': 'Corolla',
          'year': 2021,
          'createdAt': '2026-01-15T09:00:00.000',
          'updatedAt': '2026-01-15T09:00:00.000',
        },
        {
          'id': 2,
          'vehicleNumber': 'KA-02-CD-5678',
          'type': 'TRUCK',
          'brand': 'Volvo',
          'model': 'FH16',
          'year': 2023,
          'createdAt': '2026-02-20T14:30:00.000',
          'updatedAt': '2026-02-20T14:30:00.000',
        },
      ];

      final client = MockClient((request) async {
        expect(request.url.path, '/api/vehicles');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-jwt-token');

        return http.Response(
          jsonEncode(mockData),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      final vehicles = await service.getVehicles();

      expect(vehicles.length, 2);
      expect(vehicles[0].vehicleNumber, 'KA-01-AB-1234');
      expect(vehicles[0].type, 'CAR');
      expect(vehicles[0].brand, 'Toyota');
      expect(vehicles[1].vehicleNumber, 'KA-02-CD-5678');
      expect(vehicles[1].type, 'TRUCK');
      expect(vehicles[1].brand, 'Volvo');
    });

    test('Successful empty response returns an empty list without error', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      final vehicles = await service.getVehicles();

      expect(vehicles, isEmpty);
    });

    test('Successful createVehicle POST request sends correct payload and headers and returns parsed vehicle', () async {
      final createdJson = {
        'id': 10,
        'vehicleNumber': 'DHAKA-1234',
        'type': 'CAR',
        'brand': 'Toyota',
        'model': 'Camry',
        'year': 2022,
        'createdAt': '2026-11-20T10:00:00.000',
        'updatedAt': '2026-11-20T10:00:00.000',
      };

      final client = MockClient((request) async {
        expect(request.url.path, '/api/vehicles');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer test-jwt-token');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['vehicleNumber'], 'DHAKA-1234');
        expect(body['type'], 'CAR');
        expect(body['brand'], 'Toyota');
        expect(body['model'], 'Camry');
        expect(body['year'], 2022);

        return http.Response(
          jsonEncode(createdJson),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      final result = await service.createVehicle({
        'vehicleNumber': 'DHAKA-1234',
        'type': 'CAR',
        'brand': 'Toyota',
        'model': 'Camry',
        'year': 2022,
      });

      expect(result.id, 10);
      expect(result.vehicleNumber, 'DHAKA-1234');
      expect(result.type, 'CAR');
      expect(result.brand, 'Toyota');
      expect(result.model, 'Camry');
      expect(result.year, 2022);
      expect(result.createdAt, isNotNull);
    });

    test('Successful updateVehicle PUT request sends correct payload and returns updated vehicle', () async {
      final updatedJson = {
        'id': 10,
        'vehicleNumber': 'DHAKA-9999',
        'type': 'BUS',
        'brand': 'Scania',
        'model': 'Touring',
        'year': 2024,
        'createdAt': '2026-11-20T10:00:00.000',
        'updatedAt': '2026-11-20T11:00:00.000',
      };

      final client = MockClient((request) async {
        expect(request.url.path, '/api/vehicles/10');
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer test-jwt-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['vehicleNumber'], 'DHAKA-9999');
        expect(body['type'], 'BUS');
        expect(body['brand'], 'Scania');
        expect(body['model'], 'Touring');
        expect(body['year'], 2024);

        return http.Response(
          jsonEncode(updatedJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      final result = await service.updateVehicle(10, {
        'vehicleNumber': 'DHAKA-9999',
        'type': 'BUS',
        'brand': 'Scania',
        'model': 'Touring',
        'year': 2024,
      });

      expect(result.id, 10);
      expect(result.vehicleNumber, 'DHAKA-9999');
      expect(result.type, 'BUS');
      expect(result.brand, 'Scania');
    });

    test('Successful deleteVehicle sends DELETE /api/vehicles/{id} and succeeds on 204 No Content', () async {
      bool deleteCalled = false;

      final client = MockClient((request) async {
        expect(request.url.path, '/api/vehicles/10');
        expect(request.method, 'DELETE');
        expect(request.headers['Authorization'], 'Bearer test-jwt-token');
        deleteCalled = true;

        return http.Response('', 204);
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await service.deleteVehicle(10);
      expect(deleteCalled, isTrue);
    });

    test('HTTP 409 Conflict on createVehicle throws ApiException with fieldErrors', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'timestamp': '2026-11-20T12:00:00',
            'status': 409,
            'error': 'Conflict',
            'message': 'Vehicle number DHAKA-1234 already exists',
            'fieldErrors': {'vehicleNumber': 'Vehicle number DHAKA-1234 already exists'},
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.createVehicle({
          'vehicleNumber': 'DHAKA-1234',
          'type': 'CAR',
          'brand': 'Toyota',
          'model': 'Camry',
          'year': 2022,
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.fieldErrors['vehicleNumber'], 'fieldErrors', contains('already exists')),
        ),
      );
    });

    test('HTTP 404 on updateVehicle throws ApiException with 404 status', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'timestamp': '2026-11-20T12:00:00',
            'status': 404,
            'error': 'Not Found',
            'message': 'Vehicle not found with id: 999',
            'fieldErrors': {},
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.updateVehicle(999, {
          'vehicleNumber': 'DHAKA-9999',
          'type': 'CAR',
          'brand': 'Toyota',
          'model': 'Camry',
          'year': 2022,
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Vehicle not found with id: 999'),
        ),
      );
    });

    test('HTTP 404 on deleteVehicle throws ApiException with 404 status', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'timestamp': '2026-11-20T12:00:00',
            'status': 404,
            'error': 'Not Found',
            'message': 'Vehicle not found with id: 999',
            'fieldErrors': {},
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.deleteVehicle(999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Vehicle not found with id: 999'),
        ),
      );
    });

    test('HTTP 401 triggers centralized authentication invalidation and throws ApiException', () async {
      bool authExpiredCalled = false;

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'timestamp': '2026-11-20T12:00:00',
            'status': 401,
            'error': 'Unauthorized',
            'message': 'Token expired',
            'fieldErrors': {},
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: client,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          authExpiredCalled = true;
        },
      );
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.getVehicles(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      // Microtask yield to allow async invalidation callback
      await Future.microtask(() {});
      expect(authExpiredCalled, isTrue);
    });

    test('HTTP 403 authorization error throws ApiException without invalidating auth session', () async {
      bool authExpiredCalled = false;

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'timestamp': '2026-11-20T12:00:00',
            'status': 403,
            'error': 'Forbidden',
            'message': 'Access is denied',
            'fieldErrors': {},
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: client,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          authExpiredCalled = true;
        },
      );
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.getVehicles(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );

      await Future.microtask(() {});
      expect(authExpiredCalled, isFalse);
    });

    test('HTTP 500 throws ApiException with server error details', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'timestamp': '2026-11-20T12:00:00',
            'status': 500,
            'error': 'Internal Server Error',
            'message': 'Database connection failed',
            'fieldErrors': {},
          }),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.getVehicles(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'Database connection failed'),
        ),
      );
    });

    test('Network failure throws ApiException.networkError', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Failed to connect to localhost:8080');
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.getVehicles(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.error, 'error', 'NetworkError'),
        ),
      );
    });

    test('Network timeout throws ApiException.timeout', () async {
      final client = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.getVehicles(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 408)
              .having((e) => e.error, 'error', 'Timeout'),
        ),
      );
    });

    test('Malformed JSON response throws ApiException.malformedResponse', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><body>502 Bad Gateway</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.getVehicles(),
        throwsA(
          isA<ApiException>().having((e) => e.error, 'error', 'MalformedResponse'),
        ),
      );
    });

    test('Unexpected JSON response format (e.g. object instead of array) throws ApiException', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'unexpected': 'object'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: client, tokenStorage: tokenStorage);
      final service = VehicleService(apiClient: apiClient);

      await expectLater(
        () => service.getVehicles(),
        throwsA(
          isA<ApiException>().having((e) => e.error, 'error', 'MalformedResponse'),
        ),
      );
    });
  });
}
