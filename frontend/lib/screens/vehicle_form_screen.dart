import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/api_error.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/vehicle_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Screen for creating and editing vehicles in the Stark VMS system.
/// Supports both Add mode (empty fields) and Edit mode (pre-filled fields).
class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;
  final VehicleService? vehicleService;
  final VehicleProvider? vehicleProvider;
  final AuthProvider? authProvider;

  const VehicleFormScreen({
    super.key,
    this.vehicle,
    this.vehicleService,
    this.vehicleProvider,
    this.authProvider,
  });

  bool get isEdit => vehicle != null;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  static const List<String> supportedVehicleTypes = [
    'CAR',
    'BUS',
    'TRUCK',
    'MOTORCYCLE',
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;

  String? _selectedType;
  String? _vehicleNumberServerError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _vehicleNumberController = TextEditingController(text: vehicle?.vehicleNumber ?? '');
    _brandController = TextEditingController(text: vehicle?.brand ?? '');
    _modelController = TextEditingController(text: vehicle?.model ?? '');
    _yearController = TextEditingController(
      text: vehicle != null ? vehicle.year.toString() : '',
    );

    if (vehicle != null && supportedVehicleTypes.contains(vehicle.type)) {
      _selectedType = vehicle.type;
    }
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_vehicleNumberServerError != null) {
      setState(() {
        _vehicleNumberServerError = null;
      });
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = widget.authProvider ?? context.read<AuthProvider>();
    final vehicleProvider = widget.vehicleProvider ?? context.read<VehicleProvider>();
    final vehicleService = widget.vehicleService ?? vehicleProvider.vehicleService;

    final vehicleNumber = _vehicleNumberController.text.trim().toUpperCase();
    final type = _selectedType!;
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final year = int.parse(_yearController.text.trim());

    final payload = {
      'vehicleNumber': vehicleNumber,
      'type': type,
      'brand': brand,
      'model': model,
      'year': year,
    };

    try {
      final Vehicle result;
      if (widget.isEdit) {
        result = await vehicleService.updateVehicle(widget.vehicle!.id!, payload);
        vehicleProvider.updateVehicleInList(result);
      } else {
        result = await vehicleService.createVehicle(payload);
        vehicleProvider.insertVehicle(result);
      }

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? 'Vehicle updated successfully'
                  : 'Vehicle created successfully',
            ),
          ),
        );
      }

      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 409) {
        // Conflict: Duplicate vehicle number error under vehicle number field
        setState(() {
          _vehicleNumberServerError = e.fieldErrors['vehicleNumber'] ??
              (e.message.isNotEmpty ? e.message : 'Vehicle number already exists');
        });
      } else if (e.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.isNotEmpty ? e.message : 'Access is denied.',
            ),
          ),
        );
      } else if (e.statusCode == 401) {
        // Handled centrally by ApiClient on protected requests
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.isNotEmpty ? e.message : 'An error occurred. Please try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unexpected error occurred. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.isEdit ? 'Edit Vehicle' : 'Add Vehicle';
    final buttonText = widget.isEdit ? 'Update Vehicle' : 'Create Vehicle';
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Vehicle List',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.isEdit
                                      ? 'Modify existing vehicle registration details.'
                                      : 'Register a new vehicle in the fleet.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 24),

                      // 1. Vehicle Number
                      CustomTextField(
                        controller: _vehicleNumberController,
                        label: 'Vehicle Number',
                        hintText: 'e.g. DHAKA-1234',
                        prefixIcon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 20,
                        errorText: _vehicleNumberServerError,
                        onChanged: (_) {
                          if (_vehicleNumberServerError != null) {
                            setState(() {
                              _vehicleNumberServerError = null;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vehicle number is required';
                          }
                          if (value.trim().length > 20) {
                            return 'Vehicle number must not exceed 20 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 2. Type Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedType,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select vehicle type',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              prefixIcon: Icon(
                                Icons.category_outlined,
                                size: 20,
                                color: theme.colorScheme.outline,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.8,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.error,
                                  width: 1.8,
                                ),
                              ),
                            ),
                            items: supportedVehicleTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedType = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vehicle type is required';
                              }
                              if (!supportedVehicleTypes.contains(value)) {
                                return 'Invalid vehicle type';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 3. Brand
                      CustomTextField(
                        controller: _brandController,
                        label: 'Brand',
                        hintText: 'e.g. Toyota',
                        prefixIcon: Icons.directions_car_outlined,
                        maxLength: 50,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Brand is required';
                          }
                          if (value.trim().length > 50) {
                            return 'Brand must not exceed 50 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 4. Model
                      CustomTextField(
                        controller: _modelController,
                        label: 'Model',
                        hintText: 'e.g. Corolla',
                        prefixIcon: Icons.commute_outlined,
                        maxLength: 50,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Model is required';
                          }
                          if (value.trim().length > 50) {
                            return 'Model must not exceed 50 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 5. Year
                      CustomTextField(
                        controller: _yearController,
                        label: 'Year',
                        hintText: 'e.g. 2023',
                        prefixIcon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Year is required';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Please enter a valid year';
                          }
                          if (parsed < 1886) {
                            return 'Year must be at least 1886';
                          }
                          if (parsed > currentYear) {
                            return 'Year must not exceed $currentYear';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          CustomButton(
                            isFullWidth: false,
                            text: buttonText,
                            isLoading: _isSubmitting,
                            icon: widget.isEdit ? Icons.save_outlined : Icons.add,
                            onPressed: _isSubmitting ? null : _submit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
