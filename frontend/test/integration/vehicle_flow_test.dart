import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/api_config.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/vehicle.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/vehicle_provider.dart';
import 'package:frontend/screens/vehicle_form_screen.dart';
import 'package:frontend/screens/vehicle_list_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/token_storage.dart';
import 'package:frontend/services/vehicle_service.dart';
import 'package:frontend/widgets/custom_button.dart';
import 'package:frontend/widgets/custom_text_field.dart';
import 'package:frontend/widgets/vehicle_table.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Vehicle Full CRUD Lifecycle Integration Tests', () {
    late TokenStorage tokenStorage;
    late http.Client mockHttpClient;

    List<Map<String, dynamic>> apiVehicles = [];
    int getVehiclesCallCount = 0;
    int postVehicleCallCount = 0;
    int putVehicleCallCount = 0;
    int deleteVehicleCallCount = 0;
    int nextId = 200;

    int deleteStatusCode = 204;
    String deleteErrorMessage = '';

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'stark_vms_jwt_token': 'integration-valid-jwt',
        'stark_vms_username': 'fleet_manager',
      });
      tokenStorage = TokenStorage();
      ApiConfig.resetBaseUrl();

      getVehiclesCallCount = 0;
      postVehicleCallCount = 0;
      putVehicleCallCount = 0;
      deleteVehicleCallCount = 0;
      deleteStatusCode = 204;
      deleteErrorMessage = '';

      apiVehicles = [
        {
          'id': 101,
          'vehicleNumber': 'DL-01-AB-1234',
          'type': 'CAR',
          'brand': 'Hyundai',
          'model': 'Ioniq 5',
          'year': 2024,
          'createdAt': '2026-11-01T08:00:00.000',
          'updatedAt': '2026-11-01T08:00:00.000',
        },
        {
          'id': 102,
          'vehicleNumber': 'DL-02-CD-5678',
          'type': 'BUS',
          'brand': 'Tata',
          'model': 'Starbus',
          'year': 2023,
          'createdAt': '2026-11-05T10:30:00.000',
          'updatedAt': '2026-11-05T10:30:00.000',
        },
      ];

      mockHttpClient = MockClient((request) async {
        // GET /api/vehicles
        if (request.url.path == '/api/vehicles' && request.method == 'GET') {
          getVehiclesCallCount++;
          return http.Response(
            jsonEncode(apiVehicles),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // POST /api/vehicles
        if (request.url.path == '/api/vehicles' && request.method == 'POST') {
          postVehicleCallCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final created = {
            'id': ++nextId,
            'vehicleNumber': body['vehicleNumber'],
            'type': body['type'],
            'brand': body['brand'],
            'model': body['model'],
            'year': body['year'],
            'createdAt': '2026-11-20T12:00:00.000',
            'updatedAt': '2026-11-20T12:00:00.000',
          };
          apiVehicles.insert(0, created);
          return http.Response(
            jsonEncode(created),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // PUT /api/vehicles/{id}
        if (request.url.path.startsWith('/api/vehicles/') && request.method == 'PUT') {
          putVehicleCallCount++;
          final id = int.parse(request.url.pathSegments.last);
          final body = jsonDecode(request.body) as Map<String, dynamic>;

          final index = apiVehicles.indexWhere((v) => v['id'] == id);
          if (index == -1) {
            return http.Response(
              jsonEncode({
                'timestamp': '2026-11-20T12:00:00',
                'status': 404,
                'error': 'Not Found',
                'message': 'Vehicle not found with id: $id',
                'fieldErrors': {},
              }),
              404,
              headers: {'content-type': 'application/json'},
            );
          }

          final updated = {
            'id': id,
            'vehicleNumber': body['vehicleNumber'],
            'type': body['type'],
            'brand': body['brand'],
            'model': body['model'],
            'year': body['year'],
            'createdAt': apiVehicles[index]['createdAt'],
            'updatedAt': '2026-11-20T14:00:00.000',
          };
          apiVehicles[index] = updated;
          return http.Response(
            jsonEncode(updated),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // DELETE /api/vehicles/{id}
        if (request.url.path.startsWith('/api/vehicles/') && request.method == 'DELETE') {
          deleteVehicleCallCount++;
          final id = int.parse(request.url.pathSegments.last);

          if (deleteStatusCode == 204) {
            apiVehicles.removeWhere((v) => v['id'] == id);
            return http.Response('', 204);
          }

          return http.Response(
            jsonEncode({
              'timestamp': '2026-11-20T12:00:00',
              'status': deleteStatusCode,
              'error': deleteStatusCode == 404 ? 'Not Found' : 'Internal Server Error',
              'message': deleteErrorMessage.isNotEmpty
                  ? deleteErrorMessage
                  : 'Error deleting vehicle $id',
              'fieldErrors': {},
            }),
            deleteStatusCode,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });
    });

    testWidgets('Complete End-to-End Vehicle CRUD Workflow: Load, Create, Edit, Delete, Rollback, 404', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthProvider? currentAuthProvider;
      VehicleProvider? currentVehicleProvider;

      final apiClient = ApiClient(
        httpClient: mockHttpClient,
        tokenStorage: tokenStorage,
        onAuthenticationExpired: () {
          currentAuthProvider?.handleAuthInvalidation();
          currentVehicleProvider?.reset();
        },
      );

      final authService = AuthService(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      final vehicleService = VehicleService(
        apiClient: apiClient,
      );

      final authProvider = AuthProvider(
        authService: authService,
        autoInitialize: false,
      );
      currentAuthProvider = authProvider;

      final vehicleProvider = VehicleProvider(
        vehicleService: vehicleService,
      );
      currentVehicleProvider = vehicleProvider;

      await authProvider.initializeAuth();

      // 1. Load the vehicle list
      await tester.pumpWidget(
        StarkVmsApp(
          authProvider: authProvider,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VehicleListScreen), findsOneWidget);
      expect(find.byType(VehicleTable), findsOneWidget);
      expect(find.text('DL-01-AB-1234'), findsOneWidget);
      expect(find.text('DL-02-CD-5678'), findsOneWidget);
      expect(getVehiclesCallCount, 1);

      // 2. Create a vehicle
      final addVehicleFab = find.widgetWithText(FloatingActionButton, 'Add Vehicle');
      await tester.tap(addVehicleFab);
      await tester.pumpAndSettle();

      expect(find.byType(VehicleFormScreen), findsOneWidget);
      expect(find.text('Add Vehicle'), findsAtLeastNWidgets(1));

      // Fill in fields
      final numberField = find.widgetWithText(CustomTextField, 'Vehicle Number');
      await tester.enterText(find.descendant(of: numberField, matching: find.byType(TextFormField)), 'DL-09-XY-9999');

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAR').last);
      await tester.pumpAndSettle();

      final brandField = find.widgetWithText(CustomTextField, 'Brand');
      await tester.enterText(find.descendant(of: brandField, matching: find.byType(TextFormField)), 'Tesla');

      final modelField = find.widgetWithText(CustomTextField, 'Model');
      await tester.enterText(find.descendant(of: modelField, matching: find.byType(TextFormField)), 'Model 3');

      final yearField = find.widgetWithText(CustomTextField, 'Year');
      await tester.enterText(find.descendant(of: yearField, matching: find.byType(TextFormField)), '2023');

      final createButton = find.widgetWithText(CustomButton, 'Create Vehicle');
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // 3. Verify the new vehicle appears without reloading the page or issuing another GET request
      expect(find.byType(VehicleListScreen), findsOneWidget);
      expect(find.text('Vehicle created successfully'), findsOneWidget);
      expect(find.text('DL-09-XY-9999'), findsOneWidget);
      expect(find.text('Tesla'), findsOneWidget);
      expect(find.text('Model 3'), findsOneWidget);
      expect(postVehicleCallCount, 1);
      expect(getVehiclesCallCount, 1); // Crucial UX requirement: no GET request reload!

      // 4. Edit the vehicle
      final editButtons = find.byTooltip('Edit Vehicle');
      // The newest vehicle is sorted at the top (row 0)
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      expect(find.byType(VehicleFormScreen), findsOneWidget);
      expect(find.text('Edit Vehicle'), findsAtLeastNWidgets(1));
      expect(find.text('DL-09-XY-9999'), findsOneWidget);

      final editBrandField = find.widgetWithText(CustomTextField, 'Brand');
      await tester.enterText(find.descendant(of: editBrandField, matching: find.byType(TextFormField)), 'Tesla Motors');

      final editModelField = find.widgetWithText(CustomTextField, 'Model');
      await tester.enterText(find.descendant(of: editModelField, matching: find.byType(TextFormField)), 'Model 3 Performance');

      final updateButton = find.widgetWithText(CustomButton, 'Update Vehicle');
      await tester.tap(updateButton);
      await tester.pumpAndSettle();

      // 5. Verify the updated information appears immediately after the successful response
      expect(find.byType(VehicleListScreen), findsOneWidget);
      expect(find.text('Vehicle updated successfully'), findsOneWidget);
      expect(find.text('Tesla Motors'), findsOneWidget);
      expect(find.text('Model 3 Performance'), findsOneWidget);
      expect(putVehicleCallCount, 1);
      expect(getVehiclesCallCount, 1); // Still 1! No full reload!

      // 6. Delete the vehicle
      final deleteButtons = find.byTooltip('Delete Vehicle');
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(
        find.text('Delete vehicle DL-09-XY-9999? This cannot be undone.'),
        findsOneWidget,
      );

      final confirmDelete = find.widgetWithText(FilledButton, 'Delete');
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      // 7. Verify it disappears immediately
      expect(find.text('Vehicle deleted successfully'), findsOneWidget);
      expect(find.text('DL-09-XY-9999'), findsNothing);
      expect(deleteVehicleCallCount, 1);
      expect(getVehiclesCallCount, 1); // Still 1!

      // 8. Simulate deletion failure and verify rollback
      deleteStatusCode = 500;
      deleteErrorMessage = 'Failed to delete vehicle due to foreign key constraint';

      // Tap delete on DL-02-CD-5678 (id: 102)
      final deleteBtnForSecond = find.byTooltip('Delete Vehicle').first;
      await tester.tap(deleteBtnForSecond);
      await tester.pumpAndSettle();

      final confirmSecond = find.widgetWithText(FilledButton, 'Delete');
      await tester.tap(confirmSecond);
      await tester.pumpAndSettle();

      // Error message shown and vehicle is rolled back into table!
      expect(find.text('Failed to delete vehicle due to foreign key constraint'), findsOneWidget);
      expect(find.text('DL-02-CD-5678'), findsOneWidget);

      // 9. Simulate 404 and verify the vehicle remains removed
      deleteStatusCode = 404;
      deleteErrorMessage = 'Vehicle not found with id: 102';

      await tester.tap(find.byTooltip('Delete Vehicle').first);
      await tester.pumpAndSettle();

      final confirm404 = find.widgetWithText(FilledButton, 'Delete');
      await tester.tap(confirm404);
      await tester.pumpAndSettle();

      // 404 message shown and vehicle remains removed
      expect(find.text('Vehicle no longer exists'), findsOneWidget);
      expect(find.text('DL-02-CD-5678'), findsNothing);
      expect(getVehiclesCallCount, 1); // Never reloaded full list!
    });
  });
}
