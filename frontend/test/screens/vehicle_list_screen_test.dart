import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/app_routes.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/models/login_response.dart';
import 'package:frontend/models/vehicle.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/vehicle_provider.dart';
import 'package:frontend/screens/vehicle_form_screen.dart';
import 'package:frontend/screens/vehicle_list_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/vehicle_service.dart';
import 'package:frontend/widgets/vehicle_card.dart';
import 'package:frontend/widgets/vehicle_table.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthServiceForVehicleScreen implements AuthService {
  bool logoutCalled = false;

  @override
  Future<LoginResponse> login(String username, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<String?> getStoredToken() async => 'active-jwt-token';

  @override
  Future<String?> getStoredUsername() async => 'admin_tester';
}

class FakeVehicleService implements VehicleService {
  Completer<List<Vehicle>>? activeCompleter;
  List<Vehicle> vehiclesToReturn = [];
  Exception? exceptionToThrow;
  Exception? deleteExceptionToThrow;
  int callCount = 0;
  int deleteCallCount = 0;
  int? lastDeletedId;
  Completer<void>? pendingDeleteCompleter;

  @override
  Future<List<Vehicle>> getVehicles() async {
    callCount++;
    if (activeCompleter != null) {
      return activeCompleter!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return vehiclesToReturn;
  }

  @override
  Future<Vehicle> createVehicle(dynamic request) async {
    return Vehicle(
      id: 99,
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
    return Vehicle(
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
  Future<void> deleteVehicle(int id) async {
    deleteCallCount++;
    lastDeletedId = id;
    if (pendingDeleteCompleter != null) {
      await pendingDeleteCompleter!.future;
    }
    if (deleteExceptionToThrow != null) {
      throw deleteExceptionToThrow!;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sampleVehicles = [
    Vehicle(
      id: 1,
      vehicleNumber: 'KA-01-AB-1234',
      type: 'CAR',
      brand: 'Toyota',
      model: 'Corolla',
      year: 2021,
      createdAt: DateTime.parse('2026-01-15T09:00:00.000'),
    ),
    Vehicle(
      id: 2,
      vehicleNumber: 'MH-02-CD-5678',
      type: 'TRUCK',
      brand: 'Volvo',
      model: 'FH16',
      year: 2023,
      createdAt: DateTime.parse('2026-03-20T14:30:00.000'),
    ),
  ];

  Widget createWidgetUnderTest({
    required AuthProvider authProvider,
    required VehicleProvider vehicleProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
      ],
      child: MaterialApp(
        navigatorKey: AppRoutes.navigatorKey,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: const VehicleListScreen(),
      ),
    );
  }

  void configureWideViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('VehicleListScreen Widget Tests', () {
    testWidgets('renders initial loading state while request is in progress', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.activeCompleter = Completer<List<Vehicle>>();

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      expect(find.text('No vehicles yet'), findsNothing);
    });

    testWidgets('renders populated vehicle listing in desktop DataTable on wide screen', (tester) async {
      configureWideViewport(tester);

      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = sampleVehicles;

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(VehicleTable), findsOneWidget);
      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.text('MH-02-CD-5678'), findsOneWidget);
      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('Volvo'), findsOneWidget);
      expect(find.text('2021'), findsOneWidget);
      expect(find.text('2023'), findsOneWidget);
    });

    testWidgets('renders empty state when backend returns empty vehicle list', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = [];

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No vehicles yet'), findsOneWidget);
      expect(find.byType(VehicleTable), findsNothing);
    });

    testWidgets('renders error state and retry button works', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.exceptionToThrow = const ApiException(
        statusCode: 500,
        message: 'Could not connect to database',
      );

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Vehicles'), findsOneWidget);
      expect(find.text('Could not connect to database'), findsOneWidget);

      final retryButton = find.widgetWithText(FilledButton, 'Retry');
      expect(retryButton, findsOneWidget);

      fakeVehicleService.exceptionToThrow = null;
      fakeVehicleService.vehiclesToReturn = sampleVehicles;

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.text('Unable to Load Vehicles'), findsNothing);
    });

    testWidgets('refresh keeps existing data visible during refresh', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = sampleVehicles;

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KA-01-AB-1234'), findsOneWidget);

      final refreshCompleter = Completer<List<Vehicle>>();
      fakeVehicleService.activeCompleter = refreshCompleter;

      final refreshButton = find.byTooltip('Refresh');
      await tester.tap(refreshButton);
      await tester.pump();

      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      refreshCompleter.complete(sampleVehicles);
      fakeVehicleService.activeCompleter = null;
      await tester.pumpAndSettle();

      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('refresh failure retains previously displayed vehicles and shows error banner', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = sampleVehicles;

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      fakeVehicleService.exceptionToThrow = const ApiException(
        statusCode: 0,
        message: 'Network timeout during refresh',
      );

      final refreshButton = find.byTooltip('Refresh');
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.text('Network timeout during refresh'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });

    testWidgets('responsive layout renders cards on smaller screens (width < 800)', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = sampleVehicles;

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VehicleCard), findsNWidgets(2));
      expect(find.byType(VehicleTable), findsNothing);
      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.text('Toyota Corolla'), findsOneWidget);
    });

    testWidgets('Delete confirmation dialog displays correct vehicle number and Cancel makes no API request', (tester) async {
      configureWideViewport(tester);

      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = [sampleVehicles.first];

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      final deleteButtons = find.byTooltip('Delete Vehicle');
      expect(deleteButtons, findsOneWidget);
      await tester.tap(deleteButtons);
      await tester.pumpAndSettle();

      // Confirmation dialog displayed with exact required string
      expect(
        find.text('Delete vehicle KA-01-AB-1234? This cannot be undone.'),
        findsOneWidget,
      );

      // Tap Cancel
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Dialog closed, no API request made
      expect(find.text('Delete vehicle KA-01-AB-1234? This cannot be undone.'), findsNothing);
      expect(fakeVehicleService.deleteCallCount, 0);
      expect(find.text('KA-01-AB-1234'), findsOneWidget);
    });

    testWidgets('Confirm delete removes row immediately, calls API, and shows success snackbar', (tester) async {
      configureWideViewport(tester);

      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = [sampleVehicles.first];

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KA-01-AB-1234'), findsOneWidget);

      final deleteButtons = find.byTooltip('Delete Vehicle');
      await tester.tap(deleteButtons);
      await tester.pumpAndSettle();

      final confirmDeleteButton = find.widgetWithText(FilledButton, 'Delete');
      await tester.tap(confirmDeleteButton);
      await tester.pumpAndSettle();

      expect(fakeVehicleService.deleteCallCount, 1);
      expect(fakeVehicleService.lastDeletedId, 1);
      expect(find.text('Vehicle deleted successfully'), findsOneWidget);
      expect(find.text('KA-01-AB-1234'), findsNothing);
    });

    testWidgets('Delete 404 keeps vehicle removed and shows "Vehicle no longer exists"', (tester) async {
      configureWideViewport(tester);

      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = [sampleVehicles.first];
      fakeVehicleService.deleteExceptionToThrow = const ApiException(
        statusCode: 404,
        message: 'Vehicle not found with id: 1',
      );

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      final deleteButtons = find.byTooltip('Delete Vehicle');
      await tester.tap(deleteButtons);
      await tester.pumpAndSettle();

      final confirmDeleteButton = find.widgetWithText(FilledButton, 'Delete');
      await tester.tap(confirmDeleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Vehicle no longer exists'), findsOneWidget);
      // Vehicle remains removed!
      expect(find.text('KA-01-AB-1234'), findsNothing);
    });

    testWidgets('Delete failure rolls back vehicle row and shows error snackbar', (tester) async {
      configureWideViewport(tester);

      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = [sampleVehicles.first];
      fakeVehicleService.deleteExceptionToThrow = const ApiException(
        statusCode: 500,
        message: 'Database failure during deletion',
      );

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      final deleteButtons = find.byTooltip('Delete Vehicle');
      await tester.tap(deleteButtons);
      await tester.pumpAndSettle();

      final confirmDeleteButton = find.widgetWithText(FilledButton, 'Delete');
      await tester.tap(confirmDeleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Database failure during deletion'), findsOneWidget);
      // Restored!
      expect(find.text('KA-01-AB-1234'), findsOneWidget);
    });

    testWidgets('Add Vehicle button navigates to VehicleFormScreen', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = sampleVehicles;

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      final addVehicleFab = find.widgetWithText(FloatingActionButton, 'Add Vehicle');
      expect(addVehicleFab, findsOneWidget);

      await tester.tap(addVehicleFab);
      await tester.pumpAndSettle();

      expect(find.byType(VehicleFormScreen), findsOneWidget);
      expect(find.text('Add Vehicle'), findsAtLeastNWidgets(1));
    });

    testWidgets('Edit Vehicle button navigates to VehicleFormScreen in Edit mode', (tester) async {
      configureWideViewport(tester);

      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = [sampleVehicles.first];

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      final editButton = find.byTooltip('Edit Vehicle');
      expect(editButton, findsOneWidget);

      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.byType(VehicleFormScreen), findsOneWidget);
      expect(find.text('Edit Vehicle'), findsAtLeastNWidgets(1));
      expect(find.text('Update Vehicle'), findsOneWidget);
      expect(find.text('KA-01-AB-1234'), findsOneWidget);
    });

    testWidgets('Logout action calls AuthProvider.logout and resets state', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final auth = AuthProvider(authService: mockAuth, autoInitialize: false);
      await auth.initializeAuth();

      final fakeVehicleService = FakeVehicleService();
      fakeVehicleService.vehiclesToReturn = sampleVehicles;

      final vehicleProvider = VehicleProvider(vehicleService: fakeVehicleService);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authProvider: auth,
          vehicleProvider: vehicleProvider,
        ),
      );
      await tester.pumpAndSettle();

      final logoutButton = find.byTooltip('Sign Out');
      expect(logoutButton, findsOneWidget);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(mockAuth.logoutCalled, isTrue);
      expect(auth.status, AuthStatus.unauthenticated);
    });
  });
}
