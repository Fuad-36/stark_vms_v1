import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/app_routes.dart';
import 'package:frontend/models/login_response.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/vehicle_list_screen.dart';
import 'package:frontend/services/auth_service.dart';
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest(AuthProvider authProvider) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        navigatorKey: AppRoutes.navigatorKey,
        routes: {
          AppRoutes.login: (context) => const Scaffold(body: Text('Login Screen Destination')),
          AppRoutes.vehicles: (context) => const VehicleListScreen(),
        },
        home: const VehicleListScreen(),
      ),
    );
  }

  group('VehicleListScreen Widget Tests', () {
    testWidgets('renders placeholder dashboard and displays authenticated username', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);
      await provider.initializeAuth();

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      expect(find.text('Stark VMS'), findsOneWidget);
      expect(find.text('Vehicle Management'), findsAtLeastNWidgets(1));
      expect(find.text('admin_tester'), findsOneWidget);
      expect(find.textContaining('Welcome back, admin_tester!'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('logout button invokes logout and navigates to login', (tester) async {
      final mockAuth = MockAuthServiceForVehicleScreen();
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);
      await provider.initializeAuth();

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      // Tap the AppBar logout action
      final logoutButton = find.byTooltip('Sign Out');
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(mockAuth.logoutCalled, isTrue);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(find.text('Login Screen Destination'), findsOneWidget);
    });
  });
}
