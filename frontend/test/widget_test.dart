import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('StarkVmsApp loads smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final tokenStorage = TokenStorage();
    final authService = AuthService(tokenStorage: tokenStorage);
    final authProvider = AuthProvider(
      authService: authService,
      autoInitialize: false,
    );
    await authProvider.initializeAuth();

    await tester.pumpWidget(StarkVmsApp(authProvider: authProvider));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Stark VMS'), findsOneWidget);
  });
}
