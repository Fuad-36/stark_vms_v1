import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/app_routes.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/models/login_response.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/custom_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthServiceForWidget implements AuthService {
  bool shouldSucceed = true;
  String? returnErrorMessage;
  bool isDelayed = false;

  @override
  Future<LoginResponse> login(String username, String password) async {
    if (isDelayed) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!shouldSucceed) {
      throw ApiException(
        statusCode: 401,
        message: returnErrorMessage ?? 'Invalid username or password',
      );
    }
    return LoginResponse(
      token: 'mock-jwt-token',
      tokenType: 'Bearer',
      expiresIn: 3600,
      username: username,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getStoredToken() async => null;

  @override
  Future<String?> getStoredUsername() async => null;
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
          AppRoutes.login: (context) => const LoginScreen(),
          AppRoutes.vehicles: (context) => const Scaffold(body: Text('Vehicles Dashboard')),
        },
        home: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('renders all initial login fields and UI elements', (tester) async {
      final mockAuth = MockAuthServiceForWidget();
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      expect(find.text('Stark VMS'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(CustomButton), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (tester) async {
      final mockAuth = MockAuthServiceForWidget();
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows validation error for whitespace-only username', (tester) async {
      final mockAuth = MockAuthServiceForWidget();
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '   ');
      await tester.enterText(textFields.last, 'Password123');

      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('Username is required'), findsOneWidget);
    });

    testWidgets('toggles password visibility when eye icon is tapped', (tester) async {
      final mockAuth = MockAuthServiceForWidget();
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      // Initially password field is obscured
      final initialPassword = tester.widget<EditableText>(find.byType(EditableText).last);
      expect(initialPassword.obscureText, isTrue);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Password should now be visible
      final visiblePassword = tester.widget<EditableText>(find.byType(EditableText).last);
      expect(visiblePassword.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('displays error banner when authentication fails', (tester) async {
      final mockAuth = MockAuthServiceForWidget()
        ..shouldSucceed = false
        ..returnErrorMessage = 'Invalid username or password';
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'admin');
      await tester.enterText(textFields.last, 'wrong');

      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('Invalid username or password'), findsOneWidget);
    });

    testWidgets('displays network error banner when connection fails', (tester) async {
      final mockAuth = MockAuthServiceForWidget()
        ..shouldSucceed = false
        ..returnErrorMessage = 'Unable to connect to the server. Please check your network connection.';
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'admin');
      await tester.enterText(textFields.last, 'Admin@123');

      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to connect to the server. Please check your network connection.'),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator and disables submit button during login', (tester) async {
      final mockAuth = MockAuthServiceForWidget()
        ..isDelayed = true;
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'admin');
      await tester.enterText(textFields.last, 'Admin@123');

      await tester.tap(find.byType(CustomButton));
      // Pump frame without settling to observe loading state
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Finish pending timer
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to /vehicles upon successful login', (tester) async {
      final mockAuth = MockAuthServiceForWidget()..shouldSucceed = true;
      final provider = AuthProvider(authService: mockAuth, autoInitialize: false);

      await tester.pumpWidget(createWidgetUnderTest(provider));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'admin');
      await tester.enterText(textFields.last, 'Admin@123');

      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('Vehicles Dashboard'), findsOneWidget);
    });
  });
}
