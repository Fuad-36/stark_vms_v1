import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_routes.dart';
import 'providers/auth_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate dependencies and wire the centralized 401 auth invalidation callback
  final tokenStorage = TokenStorage();
  late final AuthProvider authProvider;

  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onAuthenticationExpired: () {
      authProvider.handleAuthInvalidation();
    },
  );

  final authService = AuthService(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
  );

  authProvider = AuthProvider(
    authService: authService,
    autoInitialize: true,
  );

  runApp(StarkVmsApp(authProvider: authProvider));
}

/// Root application widget for Stark VMS.
class StarkVmsApp extends StatelessWidget {
  final AuthProvider authProvider;

  const StarkVmsApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: AuthNavigationListener(
        child: MaterialApp(
          title: 'Stark VMS',
          debugShowCheckedModeBanner: false,
          navigatorKey: AppRoutes.navigatorKey,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          initialRoute: AppRoutes.root,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E40AF), // Deep Enterprise Blue
              brightness: Brightness.light,
            ),
            fontFamily: 'Roboto',
            cardTheme: CardThemeData(
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
