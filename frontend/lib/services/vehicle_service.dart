import '../models/api_error.dart';
import '../models/vehicle.dart';
import 'api_client.dart';

/// Service responsible for vehicle data retrieval, creation, updating, and deletion from the backend API.
/// Reuses [ApiClient] which automatically attaches the stored Bearer token
/// and triggers centralized 401 auth invalidation when expired.
class VehicleService {
  final ApiClient _apiClient;

  VehicleService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Retrieves the list of all vehicles from the backend `GET /api/vehicles`.
  /// Propagates [ApiException] on network or server failures.
  Future<List<Vehicle>> getVehicles() async {
    final dynamic response = await _apiClient.get('/api/vehicles');

    if (response is List) {
      final vehicles = <Vehicle>[];
      for (final item in response) {
        if (item is Map<String, dynamic>) {
          vehicles.add(Vehicle.fromJson(item));
        } else if (item is Map) {
          vehicles.add(Vehicle.fromJson(Map<String, dynamic>.from(item)));
        } else {
          throw ApiException.malformedResponse(
            'Invalid vehicle element in response: expected object but got ${item.runtimeType}',
          );
        }
      }
      return vehicles;
    }

    if (response == null) {
      return <Vehicle>[];
    }

    throw ApiException.malformedResponse(
      'Unexpected response format: expected a JSON array from /api/vehicles',
    );
  }

  /// Creates a new vehicle via `POST /api/vehicles`.
  /// Accepts either a [Vehicle] or a `Map<String, dynamic>` payload.
  /// Returns the newly created [Vehicle] with server-generated ID and timestamps.
  Future<Vehicle> createVehicle(dynamic request) async {
    final Map<String, dynamic> body;
    if (request is Vehicle) {
      body = {
        'vehicleNumber': request.vehicleNumber,
        'type': request.type,
        'brand': request.brand,
        'model': request.model,
        'year': request.year,
      };
    } else if (request is Map<String, dynamic>) {
      body = request;
    } else if (request is Map) {
      body = Map<String, dynamic>.from(request);
    } else {
      throw ArgumentError('request must be a Vehicle or Map<String, dynamic>');
    }

    final dynamic response = await _apiClient.post('/api/vehicles', body: body);
    if (response is Map<String, dynamic>) {
      return Vehicle.fromJson(response);
    } else if (response is Map) {
      return Vehicle.fromJson(Map<String, dynamic>.from(response));
    }

    throw ApiException.malformedResponse(
      'Unexpected response format: expected a JSON object for created vehicle',
    );
  }

  /// Updates an existing vehicle via `PUT /api/vehicles/{id}`.
  /// Accepts the vehicle [id] and either a [Vehicle] or `Map<String, dynamic>` payload.
  /// Returns the updated [Vehicle].
  Future<Vehicle> updateVehicle(int id, dynamic request) async {
    final Map<String, dynamic> body;
    if (request is Vehicle) {
      body = {
        'vehicleNumber': request.vehicleNumber,
        'type': request.type,
        'brand': request.brand,
        'model': request.model,
        'year': request.year,
      };
    } else if (request is Map<String, dynamic>) {
      body = request;
    } else if (request is Map) {
      body = Map<String, dynamic>.from(request);
    } else {
      throw ArgumentError('request must be a Vehicle or Map<String, dynamic>');
    }

    final dynamic response = await _apiClient.put('/api/vehicles/$id', body: body);
    if (response is Map<String, dynamic>) {
      return Vehicle.fromJson(response);
    } else if (response is Map) {
      return Vehicle.fromJson(Map<String, dynamic>.from(response));
    }

    throw ApiException.malformedResponse(
      'Unexpected response format: expected a JSON object for updated vehicle',
    );
  }

  /// Deletes a vehicle via `DELETE /api/vehicles/{id}`.
  /// Backend returns 204 No Content.
  Future<void> deleteVehicle(int id) async {
    await _apiClient.delete('/api/vehicles/$id');
  }
}
