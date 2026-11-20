import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/vehicle_form_screen.dart';
import '../screens/vehicle_list_screen.dart';

/// Centralized route constants and route generation for Stark VMS.
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String login = '/login';
  static const String vehicles = '/vehicles';
  static const String addVehicle = '/vehicles/new';
  static const String editVehicle = '/vehicles/edit';

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Generates routes with authentication checks.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        final authProvider = Provider.of<AuthProvider>(context);

        // While initializing, show splash screen to avoid flash of wrong screen
        if (authProvider.isInitializing) {
          return const _SplashScreen();
        }

        switch (settings.name) {
          case login:
            // Prevent authenticated users from visiting login screen
            if (authProvider.isAuthenticated) {
              return const VehicleListScreen();
            }
            return const LoginScreen();

          case vehicles:
            // Guard protected route: redirect unauthenticated users to login
            if (!authProvider.isAuthenticated) {
              return const LoginScreen();
            }
            return const VehicleListScreen();

          case addVehicle:
          case editVehicle:
            // Guard protected route: redirect unauthenticated users to login
            if (!authProvider.isAuthenticated) {
              return const LoginScreen();
            }
            final vehicle = settings.arguments as Vehicle?;
            return VehicleFormScreen(vehicle: vehicle);

          case root:
          default:
            // Route resolver based on current authentication state
            return authProvider.isAuthenticated
                ? const VehicleListScreen()
                : const LoginScreen();
        }
      },
    );
  }
}

/// Root widget that listens to [AuthProvider] and coordinates route transitions,
/// preventing navigation loops and ensuring browser history clears on logout.
class AuthNavigationListener extends StatefulWidget {
  final Widget child;

  const AuthNavigationListener({super.key, required this.child});

  @override
  State<AuthNavigationListener> createState() => _AuthNavigationListenerState();
}

class _AuthNavigationListenerState extends State<AuthNavigationListener> {
  AuthStatus? _previousStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final currentStatus = authProvider.status;

    if (_previousStatus != null && _previousStatus != currentStatus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (currentStatus == AuthStatus.unauthenticated) {
          AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        } else if (currentStatus == AuthStatus.authenticated) {
          AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.vehicles,
            (route) => false,
          );
        }
      });
    }

    _previousStatus = currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Clean loading screen displayed while restoring authentication state.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_filled,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading Stark VMS...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
