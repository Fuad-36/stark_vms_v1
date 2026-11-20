import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

/// Provider managing state for vehicle listing, loading, error, and CRUD operations.
class VehicleProvider extends ChangeNotifier {
  final VehicleService _vehicleService;

  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _refreshErrorMessage;

  /// Tracks vehicles currently undergoing deletion to prevent duplicate requests.
  final Set<int> _deletingVehicleIds = <int>{};

  /// Tracks active session/generation to discard stale async responses after reset/logout.
  int _sessionGeneration = 0;

  /// Tracks update operation sequence per vehicle to prevent out-of-order updates.
  final Map<int, int> _vehicleUpdateOperations = <int, int>{};
  int _operationCounter = 0;

  VehicleProvider({VehicleService? vehicleService})
      : _vehicleService = vehicleService ?? VehicleService();

  VehicleService get vehicleService => _vehicleService;
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  String? get refreshErrorMessage => _refreshErrorMessage;
  bool get hasVehicles => _vehicles.isNotEmpty;

  /// Checks if a vehicle with [id] is currently being deleted.
  bool isVehicleDeleting(int id) => _deletingVehicleIds.contains(id);

  /// Sorts vehicles preserving backend contract: createdAt DESC, then id DESC.
  static int compareVehicles(Vehicle a, Vehicle b) {
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;
    if (aCreated != null && bCreated != null) {
      final cmp = bCreated.compareTo(aCreated);
      if (cmp != 0) return cmp;
    } else if (aCreated != null && bCreated == null) {
      return -1;
    } else if (aCreated == null && bCreated != null) {
      return 1;
    }

    final aId = a.id ?? 0;
    final bId = b.id ?? 0;
    return bId.compareTo(aId);
  }

  void _sortVehicles() {
    _vehicles.sort(compareVehicles);
  }

  /// Loads vehicles on initial screen entry or retry.
  Future<void> fetchVehicles() async {
    if (_isLoading) return;

    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _vehicleService.getVehicles();
      if (session != _sessionGeneration) return;
      _vehicles = List.from(result);
      _sortVehicles();
      _errorMessage = null;
    } on ApiException catch (e) {
      if (session != _sessionGeneration) return;
      _errorMessage = e.message;
    } catch (_) {
      if (session != _sessionGeneration) return;
      _errorMessage = 'An unexpected error occurred while loading vehicles.';
    } finally {
      if (session == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Refreshes vehicle data while keeping currently displayed vehicles visible.
  Future<void> refreshVehicles() async {
    if (_isRefreshing || _isLoading) return;

    final session = _sessionGeneration;
    _isRefreshing = true;
    _refreshErrorMessage = null;
    notifyListeners();

    try {
      final result = await _vehicleService.getVehicles();
      if (session != _sessionGeneration) return;
      _vehicles = List.from(result);
      _sortVehicles();
      _errorMessage = null;
      _refreshErrorMessage = null;
    } on ApiException catch (e) {
      if (session != _sessionGeneration) return;
      _refreshErrorMessage = e.message;
    } catch (_) {
      if (session != _sessionGeneration) return;
      _refreshErrorMessage = 'Failed to refresh vehicles. Please try again.';
    } finally {
      if (session == _sessionGeneration) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  /// Inserts a newly created vehicle into local state preserving ordering:
  /// `createdAt DESC`, then `id DESC`.
  void insertVehicle(Vehicle vehicle) {
    _vehicles.removeWhere((v) => v.id != null && v.id == vehicle.id);
    _vehicles.add(vehicle);
    _sortVehicles();
    _errorMessage = null;
    notifyListeners();
  }

  /// Creates a vehicle via the service and updates local state.
  Future<Vehicle> createVehicle(dynamic request) async {
    final session = _sessionGeneration;
    final created = await _vehicleService.createVehicle(request);
    if (session == _sessionGeneration) {
      insertVehicle(created);
    }
    return created;
  }

  /// Replaces the matching vehicle in the local list, preserving ordering.
  void updateVehicleInList(Vehicle vehicle) {
    final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index != -1) {
      _vehicles[index] = vehicle;
      notifyListeners();
    }
  }

  /// Updates a vehicle via the service and updates local state.
  Future<Vehicle> updateVehicle(int id, dynamic request) async {
    final session = _sessionGeneration;
    final opId = ++_operationCounter;
    _vehicleUpdateOperations[id] = opId;

    final updated = await _vehicleService.updateVehicle(id, request);

    if (session == _sessionGeneration && _vehicleUpdateOperations[id] == opId) {
      updateVehicleInList(updated);
    }
    return updated;
  }

  /// Optimistically deletes a vehicle:
  /// 1. Immediately removes from local list and notifies listeners.
  /// 2. Sends DELETE request.
  /// 3. If 404: retains removal.
  /// 4. If other failure: rolls back vehicle to its original position.
  Future<void> deleteVehicle(int id) async {
    if (_deletingVehicleIds.contains(id)) {
      return; // Prevent duplicate deletion request
    }

    final session = _sessionGeneration;
    final originalIndex = _vehicles.indexWhere((v) => v.id == id);
    final Vehicle? removedVehicle = originalIndex != -1 ? _vehicles[originalIndex] : null;

    if (originalIndex != -1) {
      _vehicles.removeAt(originalIndex);
      _deletingVehicleIds.add(id);
      notifyListeners();
    }

    try {
      await _vehicleService.deleteVehicle(id);
    } on ApiException catch (e) {
      if (session != _sessionGeneration) rethrow;

      if (e.statusCode == 404) {
        // Vehicle no longer exists on server: keep removed, do not rollback
        rethrow;
      }

      // Other failure: rollback to original position
      if (removedVehicle != null && !_vehicles.any((v) => v.id == id)) {
        final restoreIndex = originalIndex.clamp(0, _vehicles.length);
        _vehicles.insert(restoreIndex, removedVehicle);
        notifyListeners();
      }
      rethrow;
    } catch (e) {
      if (session != _sessionGeneration) rethrow;

      // Rollback to original position on network or other failures
      if (removedVehicle != null && !_vehicles.any((v) => v.id == id)) {
        final restoreIndex = originalIndex.clamp(0, _vehicles.length);
        _vehicles.insert(restoreIndex, removedVehicle);
        notifyListeners();
      }
      rethrow;
    } finally {
      _deletingVehicleIds.remove(id);
      if (session == _sessionGeneration) {
        notifyListeners();
      }
    }
  }

  /// Clears the non-blocking refresh error message.
  void clearRefreshError() {
    if (_refreshErrorMessage != null) {
      _refreshErrorMessage = null;
      notifyListeners();
    }
  }

  /// Resets state (e.g., when signing out).
  void reset() {
    _sessionGeneration++;
    _vehicles = [];
    _deletingVehicleIds.clear();
    _vehicleUpdateOperations.clear();
    _isLoading = false;
    _isRefreshing = false;
    _errorMessage = null;
    _refreshErrorMessage = null;
    notifyListeners();
  }
}
