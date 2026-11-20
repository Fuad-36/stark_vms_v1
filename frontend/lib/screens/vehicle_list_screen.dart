import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/api_error.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/vehicle_empty_view.dart';
import '../widgets/vehicle_error_view.dart';
import '../widgets/vehicle_table.dart';

/// Screen displaying the list of all registered vehicles.
/// Supports desktop table and mobile card layouts, initial loading, empty,
/// error, and refreshing states with real API data.
class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vehicleProvider = context.read<VehicleProvider>();
      if (!vehicleProvider.isLoading &&
          !vehicleProvider.hasVehicles &&
          vehicleProvider.errorMessage == null) {
        vehicleProvider.fetchVehicles();
      }
    });
  }

  Future<void> _handleLogout() async {
    final authProvider = context.read<AuthProvider>();
    final vehicleProvider = context.read<VehicleProvider>();
    final navigator = Navigator.of(context);
    vehicleProvider.reset();
    await authProvider.logout();

    if (mounted) {
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  void _navigateToAddVehicle() {
    Navigator.of(context).pushNamed(AppRoutes.addVehicle);
  }

  void _navigateToEditVehicle(Vehicle vehicle) {
    Navigator.of(context).pushNamed(AppRoutes.editVehicle, arguments: vehicle);
  }

  Future<void> _handleDeleteVehicle(Vehicle vehicle) async {
    if (vehicle.id == null) return;
    final vehicleProvider = context.read<VehicleProvider>();
    final authProvider = context.read<AuthProvider>();

    if (vehicleProvider.isVehicleDeleting(vehicle.id!)) {
      return; // Prevent duplicate deletion request
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Vehicle'),
          content: SingleChildScrollView(
            child: Text(
              'Delete vehicle ${vehicle.vehicleNumber}? This cannot be undone.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await vehicleProvider.deleteVehicle(vehicle.id!);
      if (mounted && authProvider.isAuthenticated) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('Vehicle deleted successfully')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted || !authProvider.isAuthenticated) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      if (e.statusCode == 404) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Vehicle no longer exists')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e.message.isNotEmpty ? e.message : 'Failed to delete vehicle. Please try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted || !authProvider.isAuthenticated) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete vehicle. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();
    final username = authProvider.username ?? 'Administrator';

    Widget bodyContent;
    if (vehicleProvider.isLoading && !vehicleProvider.hasVehicles) {
      // 1. Initial loading state: centered loading indicator
      bodyContent = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (vehicleProvider.errorMessage != null && !vehicleProvider.hasVehicles) {
      // 2. Initial error state: meaningful message + Retry button
      bodyContent = VehicleErrorView(
        errorMessage: vehicleProvider.errorMessage!,
        onRetry: () => vehicleProvider.fetchVehicles(),
      );
    } else if (vehicleProvider.vehicles.isEmpty) {
      // 3. Empty state: clean design with "No vehicles yet"
      bodyContent = VehicleEmptyView(
        onRefresh: () => vehicleProvider.fetchVehicles(),
      );
    } else {
      // 4. Populated state: responsive layout (table on wide screens, cards on narrow)
      bodyContent = LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          if (isDesktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: VehicleTable(
                    vehicles: vehicleProvider.vehicles,
                    onEdit: (vehicle) => _navigateToEditVehicle(vehicle),
                    onDelete: (vehicle) => _handleDeleteVehicle(vehicle),
                    isVehicleDeleting: (id) => vehicleProvider.isVehicleDeleting(id),
                  ),
                ),
              ),
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicleProvider.vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicleProvider.vehicles[index];
                return VehicleCard(
                  vehicle: vehicle,
                  onEdit: () => _navigateToEditVehicle(vehicle),
                  onDelete: () => _handleDeleteVehicle(vehicle),
                  isDeleting: vehicle.id != null && vehicleProvider.isVehicleDeleting(vehicle.id!),
                );
              },
            );
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_shipping_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Stark VMS',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 720) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Vehicle Management',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Refresh Button
          IconButton(
            icon: vehicleProvider.isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: (vehicleProvider.isRefreshing || vehicleProvider.isLoading)
                ? null
                : () => vehicleProvider.refreshVehicles(),
          ),

          // User chip
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 4, left: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >= 720) ...[
                    const SizedBox(width: 6),
                    Text(
                      username,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Logout Action
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            color: theme.colorScheme.error,
            onPressed: authProvider.isLoading ? null : () => _handleLogout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Refreshing progress indicator bar
          if (vehicleProvider.isRefreshing)
            const LinearProgressIndicator(minHeight: 3),

          // Non-blocking refresh error banner with Retry option
          if (vehicleProvider.refreshErrorMessage != null && vehicleProvider.hasVehicles)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      vehicleProvider.refreshErrorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: vehicleProvider.isRefreshing
                        ? null
                        : () => vehicleProvider.refreshVehicles(),
                    child: const Text('Retry'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Dismiss',
                    onPressed: () => vehicleProvider.clearRefreshError(),
                  ),
                ],
              ),
            ),

          Expanded(child: bodyContent),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
        tooltip: 'Add Vehicle',
        onPressed: () => _navigateToAddVehicle(),
      ),
    );
  }
}
