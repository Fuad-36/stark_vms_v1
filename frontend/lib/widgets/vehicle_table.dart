import 'package:flutter/material.dart';
import '../models/vehicle.dart';

/// Desktop and wider screen table view for displaying vehicles.
/// Accommodates horizontal scrolling and presents Edit and Delete actions.
class VehicleTable extends StatelessWidget {
  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle>? onEdit;
  final ValueChanged<Vehicle>? onDelete;
  final bool Function(int id)? isVehicleDeleting;

  const VehicleTable({
    super.key,
    required this.vehicles,
    this.onEdit,
    this.onDelete,
    this.isVehicleDeleting,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 64,
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          horizontalMargin: 24,
          columnSpacing: 24,
          columns: const [
            DataColumn(
              label: Text(
                'Vehicle Number',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Brand',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Model',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Year',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Created Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: vehicles.map((vehicle) {
            final isDeleting = vehicle.id != null && (isVehicleDeleting?.call(vehicle.id!) ?? false);

            return DataRow(
              key: ValueKey(vehicle.id ?? vehicle.vehicleNumber),
              cells: [
                DataCell(
                  Text(
                    vehicle.vehicleNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      vehicle.type,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      vehicle.brand,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      vehicle.model,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(vehicle.year.toString())),
                DataCell(Text(vehicle.formattedCreatedAt)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit Vehicle',
                        onPressed: onEdit != null ? () => onEdit!(vehicle) : null,
                      ),
                      isDeleting
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: theme.colorScheme.error,
                              ),
                              tooltip: 'Delete Vehicle',
                              onPressed: onDelete != null ? () => onDelete!(vehicle) : null,
                            ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
