import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/models/login_response.dart';
import 'package:frontend/models/vehicle.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/vehicle_provider.dart';
import 'package:frontend/screens/vehicle_form_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/vehicle_service.dart';
import 'package:frontend/widgets/custom_button.dart';
import 'package:frontend/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthServiceForForm implements AuthService {
  @override
  Future<LoginResponse> login(String username, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getStoredToken() async => 'active-jwt-token';

  @override
  Future<String?> getStoredUsername() async => 'admin_tester';
}

class FakeVehicleServiceForForm implements VehicleService {
  Completer<Vehicle>? pendingCompleter;
  Vehicle? vehicleToReturnOnCreate;
  Vehicle? vehicleToReturnOnUpdate;
  Exception? exceptionToThrow;
  int createCallCount = 0;
  int updateCallCount = 0;
  dynamic lastPayload;

  @override
  Future<List<Vehicle>> getVehicles() async => [];

  @override
  Future<Vehicle> createVehicle(dynamic request) async {
    createCallCount++;
    lastPayload = request;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return vehicleToReturnOnCreate ??
        Vehicle(
          id: 50,
          vehicleNumber: request['vehicleNumber'],
          type: request['type'],
          brand: request['brand'],
          model: request['model'],
          year: request['year'],
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<Vehicle> updateVehicle(int id, dynamic request) async {
    updateCallCount++;
    lastPayload = request;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return vehicleToReturnOnUpdate ??
        Vehicle(
          id: id,
          vehicleNumber: request['vehicleNumber'],
          type: request['type'],
          brand: request['brand'],
          model: request['model'],
          year: request['year'],
          createdAt: DateTime.parse('2026-01-01T10:00:00.000'),
          updatedAt: DateTime.now(),
        );
  }

  @override
  Future<void> deleteVehicle(int id) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final existingVehicle = Vehicle(
    id: 1,
    vehicleNumber: 'DHAKA-5555',
    type: 'TRUCK',
    brand: 'Volvo',
    model: 'FH16',
    year: 2021,
    createdAt: DateTime.parse('2026-01-15T09:00:00.000'),
    updatedAt: DateTime.parse('2026-01-15T09:00:00.000'),
  );

  Widget createWidgetUnderTest({
    Vehicle? vehicle,
    required AuthProvider authProvider,
    required VehicleProvider vehicleProvider,
    required VehicleService vehicleService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
      ],
      child: MaterialApp(
        home: VehicleFormScreen(
          vehicle: vehicle,
          vehicleService: vehicleService,
          vehicleProvider: vehicleProvider,
          authProvider: authProvider,
        ),
      ),
    );
  }

  void configureTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('VehicleFormScreen Widget Tests', () {
    testWidgets('Add mode initialization renders empty fields, Add Vehicle title and Create Vehicle button', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Vehicle'), findsAtLeastNWidgets(1));
      expect(find.text('Create Vehicle'), findsOneWidget);
      expect(find.text('Update Vehicle'), findsNothing);

      final textFields = tester.widgetList<TextFormField>(find.byType(TextFormField));
      for (final field in textFields) {
        expect(field.controller?.text, isEmpty);
      }
    });

    testWidgets('Edit mode initialization pre-fills fields from supplied vehicle and displays Edit Vehicle title', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          vehicle: existingVehicle,
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Vehicle'), findsAtLeastNWidgets(1));
      expect(find.text('Update Vehicle'), findsOneWidget);
      expect(find.text('Create Vehicle'), findsNothing);

      expect(find.text('DHAKA-5555'), findsOneWidget);
      expect(find.text('TRUCK'), findsOneWidget);
      expect(find.text('Volvo'), findsOneWidget);
      expect(find.text('FH16'), findsOneWidget);
      expect(find.text('2021'), findsOneWidget);
    });

    testWidgets('Dropdown contains exactly the four supported enum values: CAR, BUS, TRUCK, MOTORCYCLE', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('CAR').last, findsOneWidget);
      expect(find.text('BUS').last, findsOneWidget);
      expect(find.text('TRUCK').last, findsOneWidget);
      expect(find.text('MOTORCYCLE').last, findsOneWidget);
    });

    testWidgets('Required field validation fails when submitting empty form', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(CustomButton, 'Create Vehicle');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Vehicle number is required'), findsOneWidget);
      expect(find.text('Vehicle type is required'), findsOneWidget);
      expect(find.text('Brand is required'), findsOneWidget);
      expect(find.text('Model is required'), findsOneWidget);
      expect(find.text('Year is required'), findsOneWidget);

      expect(fakeService.createCallCount, 0);
    });

    testWidgets('Field length validations for vehicleNumber, brand, and model', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      final longNumber = 'A' * 21;
      final longBrand = 'B' * 51;
      final longModel = 'C' * 51;

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), longNumber);
      await tester.enterText(textFields.at(1), longBrand);
      await tester.enterText(textFields.at(2), longModel);

      final saveButton = find.widgetWithText(CustomButton, 'Create Vehicle');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Vehicle number must not exceed 20 characters'), findsOneWidget);
      expect(find.text('Brand must not exceed 50 characters'), findsOneWidget);
      expect(find.text('Model must not exceed 50 characters'), findsOneWidget);
      expect(fakeService.createCallCount, 0);
    });

    testWidgets('Year boundary validation ensures minimum 1886 and maximum current calendar year', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      final yearField = find.widgetWithText(CustomTextField, 'Year');

      // Test below 1886
      await tester.enterText(find.descendant(of: yearField, matching: find.byType(TextFormField)), '1885');
      final saveButton = find.widgetWithText(CustomButton, 'Create Vehicle');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Year must be at least 1886'), findsOneWidget);

      // Test future year
      final futureYear = DateTime.now().year + 1;
      await tester.enterText(find.descendant(of: yearField, matching: find.byType(TextFormField)), futureYear.toString());
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Year must not exceed ${DateTime.now().year}'), findsOneWidget);

      // Test non-numeric input
      await tester.enterText(find.descendant(of: yearField, matching: find.byType(TextFormField)), 'not-a-number');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid year'), findsOneWidget);
    });

    testWidgets('Duplicate vehicle number error (409) appears beneath vehicle number field and clears on user edit', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      fakeService.exceptionToThrow = const ApiException(
        statusCode: 409,
        message: 'Vehicle number DHAKA-1234 already exists',
        fieldErrors: {'vehicleNumber': 'Vehicle number DHAKA-1234 already exists'},
      );
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      final numberField = find.widgetWithText(CustomTextField, 'Vehicle Number');
      await tester.enterText(find.descendant(of: numberField, matching: find.byType(TextFormField)), 'DHAKA-1234');

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAR').last);
      await tester.pumpAndSettle();

      final brandField = find.widgetWithText(CustomTextField, 'Brand');
      await tester.enterText(find.descendant(of: brandField, matching: find.byType(TextFormField)), 'Toyota');

      final modelField = find.widgetWithText(CustomTextField, 'Model');
      await tester.enterText(find.descendant(of: modelField, matching: find.byType(TextFormField)), 'Corolla');

      final yearField = find.widgetWithText(CustomTextField, 'Year');
      await tester.enterText(find.descendant(of: yearField, matching: find.byType(TextFormField)), '2022');

      final saveButton = find.widgetWithText(CustomButton, 'Create Vehicle');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Vehicle number DHAKA-1234 already exists'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.enterText(find.descendant(of: numberField, matching: find.byType(TextFormField)), 'DHAKA-1235');
      await tester.pumpAndSettle();

      expect(find.text('Vehicle number DHAKA-1234 already exists'), findsNothing);
    });

    testWidgets('Save button is disabled with loading indicator while submitting', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      final completer = Completer<Vehicle>();
      fakeService.pendingCompleter = completer;

      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      final numberField = find.widgetWithText(CustomTextField, 'Vehicle Number');
      await tester.enterText(find.descendant(of: numberField, matching: find.byType(TextFormField)), 'DHAKA-1234');

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAR').last);
      await tester.pumpAndSettle();

      final brandField = find.widgetWithText(CustomTextField, 'Brand');
      await tester.enterText(find.descendant(of: brandField, matching: find.byType(TextFormField)), 'Toyota');

      final modelField = find.widgetWithText(CustomTextField, 'Model');
      await tester.enterText(find.descendant(of: modelField, matching: find.byType(TextFormField)), 'Corolla');

      final yearField = find.widgetWithText(CustomTextField, 'Year');
      await tester.enterText(find.descendant(of: yearField, matching: find.byType(TextFormField)), '2022');

      final saveButton = find.byType(CustomButton);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      final button = tester.widget<CustomButton>(saveButton);
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);

      completer.complete(
        Vehicle(
          id: 50,
          vehicleNumber: 'DHAKA-1234',
          type: 'CAR',
          brand: 'Toyota',
          model: 'Corolla',
          year: 2022,
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Failed submission (500) displays error snackbar and preserves entered values without navigating away', (tester) async {
      configureTestViewport(tester);
      final auth = AuthProvider(authService: MockAuthServiceForForm(), autoInitialize: false);
      await auth.initializeAuth();
      final fakeService = FakeVehicleServiceForForm();
      fakeService.exceptionToThrow = const ApiException(
        statusCode: 500,
        message: 'Internal server error while saving vehicle',
      );
      final vehicleProvider = VehicleProvider(vehicleService: fakeService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
          vehicleService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      final numberField = find.widgetWithText(CustomTextField, 'Vehicle Number');
      await tester.enterText(find.descendant(of: numberField, matching: find.byType(TextFormField)), 'DHAKA-1234');

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAR').last);
      await tester.pumpAndSettle();

      final brandField = find.widgetWithText(CustomTextField, 'Brand');
      await tester.enterText(find.descendant(of: brandField, matching: find.byType(TextFormField)), 'Toyota');

      final modelField = find.widgetWithText(CustomTextField, 'Model');
      await tester.enterText(find.descendant(of: modelField, matching: find.byType(TextFormField)), 'Corolla');

      final yearField = find.widgetWithText(CustomTextField, 'Year');
      await tester.enterText(find.descendant(of: yearField, matching: find.byType(TextFormField)), '2022');

      final saveButton = find.widgetWithText(CustomButton, 'Create Vehicle');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Internal server error while saving vehicle'), findsOneWidget);
      expect(find.text('DHAKA-1234'), findsOneWidget);
      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('Corolla'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);
      expect(find.byType(VehicleFormScreen), findsOneWidget);
    });
  });
}
