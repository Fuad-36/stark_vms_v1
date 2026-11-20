import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_routes.dart';
import 'providers/auth_provider.dart';
import 'providers/vehicle_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/token_storage.dart';
import 'services/vehicle_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate dependencies and wire the centralized 401 auth invalidation callback
  final tokenStorage = TokenStorage();
  late final AuthProvider authProvider;
  late final VehicleProvider vehicleProvider;

  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onAuthenticationExpired: () {
      authProvider.handleAuthInvalidation();
      vehicleProvider.reset();
    },
  );

  final authService = AuthService(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
  );

  final vehicleService = VehicleService(
    apiClient: apiClient,
  );

  authProvider = AuthProvider(
    authService: authService,
    autoInitialize: true,
  );

  vehicleProvider = VehicleProvider(
    vehicleService: vehicleService,
  );

  runApp(
    StarkVmsApp(
      authProvider: authProvider,
      vehicleProvider: vehicleProvider,
    ),
  );
}

/// Root application widget for Stark VMS.
class StarkVmsApp extends StatelessWidget {
  final AuthProvider authProvider;
  final VehicleProvider? vehicleProvider;

  const StarkVmsApp({
    super.key,
    required this.authProvider,
    this.vehicleProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<VehicleProvider>.value(
          value: vehicleProvider ?? VehicleProvider(),
        ),
      ],
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
