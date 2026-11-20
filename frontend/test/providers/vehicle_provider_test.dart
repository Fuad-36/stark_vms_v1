import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/models/vehicle.dart';
import 'package:frontend/providers/vehicle_provider.dart';
import 'package:frontend/services/vehicle_service.dart';

class MockVehicleService implements VehicleService {
  List<Vehicle> vehiclesToReturn = [];
  Vehicle? vehicleToReturnOnCreate;
  Vehicle? vehicleToReturnOnUpdate;
  Exception? exceptionToThrow;
  Exception? deleteExceptionToThrow;
  int callCount = 0;
  int createCallCount = 0;
  int updateCallCount = 0;
  int deleteCallCount = 0;
  Completer<void>? pendingDeleteCompleter;
  Completer<Vehicle>? pendingCreateCompleter;
  Completer<Vehicle>? pendingUpdateCompleter;

  @override
  Future<List<Vehicle>> getVehicles() async {
    callCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return vehiclesToReturn;
  }

  @override
  Future<Vehicle> createVehicle(dynamic request) async {
    createCallCount++;
    if (pendingCreateCompleter != null) {
      return pendingCreateCompleter!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (vehicleToReturnOnCreate != null) {
      return vehicleToReturnOnCreate!;
    }
    return Vehicle(
      id: 99,
      vehicleNumber: request is Vehicle ? request.vehicleNumber : request['vehicleNumber'],
      type: request is Vehicle ? request.type : request['type'],
      brand: request is Vehicle ? request.brand : request['brand'],
      model: request is Vehicle ? request.model : request['model'],
      year: request is Vehicle ? request.year : request['year'],
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Vehicle> updateVehicle(int id, dynamic request) async {
    updateCallCount++;
    if (pendingUpdateCompleter != null) {
      return pendingUpdateCompleter!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (vehicleToReturnOnUpdate != null) {
      return vehicleToReturnOnUpdate!;
    }
    return Vehicle(
      id: id,
      vehicleNumber: request is Vehicle ? request.vehicleNumber : request['vehicleNumber'],
      type: request is Vehicle ? request.type : request['type'],
      brand: request is Vehicle ? request.brand : request['brand'],
      model: request is Vehicle ? request.model : request['model'],
      year: request is Vehicle ? request.year : request['year'],
      createdAt: DateTime.parse('2026-01-01T10:00:00.000'),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteVehicle(int id) async {
    deleteCallCount++;
    if (pendingDeleteCompleter != null) {
      await pendingDeleteCompleter!.future;
    }
    if (deleteExceptionToThrow != null) {
      throw deleteExceptionToThrow!;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
  }
}

void main() {
  group('VehicleProvider Unit Tests', () {
    late MockVehicleService mockService;
    late VehicleProvider provider;

    final sampleVehicles = [
      Vehicle(
        id: 2,
        vehicleNumber: 'KA-02-CD-5678',
        type: 'TRUCK',
        brand: 'Volvo',
        model: 'FH16',
        year: 2023,
        createdAt: DateTime.parse('2026-02-01T10:00:00.000'),
      ),
      Vehicle(
        id: 1,
        vehicleNumber: 'KA-01-AB-1234',
        type: 'CAR',
        brand: 'Honda',
        model: 'City',
        year: 2022,
        createdAt: DateTime.parse('2026-01-01T10:00:00.000'),
      ),
    ];

    setUp(() {
      mockService = MockVehicleService();
      provider = VehicleProvider(vehicleService: mockService);
    });

    test('Initial state is clean', () {
      expect(provider.vehicles, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isRefreshing, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.refreshErrorMessage, isNull);
      expect(provider.hasVehicles, isFalse);
    });

    test('fetchVehicles sets loading and populates vehicles on success', () async {
      mockService.vehiclesToReturn = sampleVehicles;

      final future = provider.fetchVehicles();
      expect(provider.isLoading, isTrue);

      await future;

      expect(provider.isLoading, isFalse);
      expect(provider.vehicles.length, 2);
      expect(provider.vehicles.first.vehicleNumber, 'KA-02-CD-5678');
      expect(provider.errorMessage, isNull);
    });

    test('fetchVehicles captures ApiException message on failure', () async {
      mockService.exceptionToThrow = const ApiException(
        statusCode: 500,
        message: 'Internal server error',
      );

      await provider.fetchVehicles();

      expect(provider.isLoading, isFalse);
      expect(provider.vehicles, isEmpty);
      expect(provider.errorMessage, 'Internal server error');
    });

    test('Create inserts the returned vehicle into local state preserving createdAt DESC, id DESC ordering', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();
      expect(provider.vehicles.length, 2);

      final newVehicle = Vehicle(
        id: 3,
        vehicleNumber: 'DHAKA-NEW-1',
        type: 'CAR',
        brand: 'Toyota',
        model: 'Corolla',
        year: 2024,
        createdAt: DateTime.parse('2026-03-01T10:00:00.000'),
      );
      mockService.vehicleToReturnOnCreate = newVehicle;

      final created = await provider.createVehicle(newVehicle);

      expect(created.id, 3);
      expect(provider.vehicles.length, 3);
      // Newest createdAt must be first (index 0)
      expect(provider.vehicles[0].id, 3);
      expect(provider.vehicles[1].id, 2);
      expect(provider.vehicles[2].id, 1);
    });

    test('Update replaces the matching vehicle in local state preserving list ordering', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();

      final updatedVehicle = Vehicle(
        id: 2,
        vehicleNumber: 'KA-02-UPDATED',
        type: 'TRUCK',
        brand: 'Volvo',
        model: 'FH16',
        year: 2023,
        createdAt: DateTime.parse('2026-02-01T10:00:00.000'),
        updatedAt: DateTime.parse('2026-03-01T12:00:00.000'),
      );
      mockService.vehicleToReturnOnUpdate = updatedVehicle;

      final result = await provider.updateVehicle(2, updatedVehicle);

      expect(result.vehicleNumber, 'KA-02-UPDATED');
      expect(provider.vehicles.length, 2);
      expect(provider.vehicles[0].vehicleNumber, 'KA-02-UPDATED');
      expect(provider.vehicles[1].id, 1);
    });

    test('Update safely handles when vehicle is no longer in local list without exception', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();

      final nonExistent = Vehicle(
        id: 999,
        vehicleNumber: 'UNKNOWN',
        type: 'CAR',
        brand: 'Unknown',
        model: 'Unknown',
        year: 2020,
      );
      mockService.vehicleToReturnOnUpdate = nonExistent;

      final result = await provider.updateVehicle(999, nonExistent);
      expect(result.id, 999);
      expect(provider.vehicles.length, 2);
    });

    test('Delete removes the vehicle immediately (optimistic deletion)', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();
      expect(provider.vehicles.length, 2);

      final deleteFuture = provider.deleteVehicle(2);
      // Immediately removed before service call finishes!
      expect(provider.vehicles.length, 1);
      expect(provider.vehicles.first.id, 1);
      expect(provider.isVehicleDeleting(2), isTrue);

      await deleteFuture;
      expect(provider.vehicles.length, 1);
      expect(provider.isVehicleDeleting(2), isFalse);
    });

    test('Failed delete restores the vehicle at the correct position (rollback)', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();
      expect(provider.vehicles.length, 2);

      mockService.deleteExceptionToThrow = const ApiException(
        statusCode: 500,
        message: 'Server error deleting vehicle',
      );

      await expectLater(
        () => provider.deleteVehicle(2),
        throwsA(isA<ApiException>()),
      );

      // Vehicle was restored to index 0!
      expect(provider.vehicles.length, 2);
      expect(provider.vehicles[0].id, 2);
      expect(provider.vehicles[1].id, 1);
      expect(provider.isVehicleDeleting(2), isFalse);
    });

    test('Delete 404 does not restore the vehicle to local list', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();
      expect(provider.vehicles.length, 2);

      mockService.deleteExceptionToThrow = const ApiException(
        statusCode: 404,
        message: 'Vehicle not found with id: 2',
      );

      await expectLater(
        () => provider.deleteVehicle(2),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );

      // 404 means already gone on server, do not restore!
      expect(provider.vehicles.length, 1);
      expect(provider.vehicles.first.id, 1);
    });

    test('Duplicate delete operations for the same vehicle are prevented', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();

      final completer = Completer<void>();
      mockService.pendingDeleteCompleter = completer;

      final f1 = provider.deleteVehicle(2);
      final f2 = provider.deleteVehicle(2); // Duplicate invocation

      completer.complete();
      await Future.wait([f1, f2]);

      expect(mockService.deleteCallCount, 1);
    });

    test('Logout/reset prevents stale requests from restoring old data', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();

      final completer = Completer<void>();
      mockService.pendingDeleteCompleter = completer;

      mockService.deleteExceptionToThrow = const ApiException(
        statusCode: 500,
        message: 'Failed to delete',
      );

      final deleteFuture = provider.deleteVehicle(2);

      // While delete request is running, user logs out / resets provider!
      provider.reset();
      expect(provider.vehicles, isEmpty);

      completer.complete();
      try {
        await deleteFuture;
      } catch (_) {}

      // Vehicles list must remain empty after reset, rollback was aborted!
      expect(provider.vehicles, isEmpty);
    });

    test('Concurrent updates do not allow an older response to overwrite a newer operation', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();

      final completer1 = Completer<Vehicle>();
      mockService.pendingUpdateCompleter = completer1;

      // Start op 1
      final f1 = provider.updateVehicle(1, {'vehicleNumber': 'FIRST'});

      // Start op 2 immediately with newer data
      mockService.pendingUpdateCompleter = null;
      mockService.vehicleToReturnOnUpdate = Vehicle(
        id: 1,
        vehicleNumber: 'SECOND',
        type: 'CAR',
        brand: 'Honda',
        model: 'City',
        year: 2022,
      );
      final f2 = provider.updateVehicle(1, {'vehicleNumber': 'SECOND'});
      await f2;
      expect(provider.vehicles.firstWhere((v) => v.id == 1).vehicleNumber, 'SECOND');

      // Now op 1 finishes late
      completer1.complete(Vehicle(
        id: 1,
        vehicleNumber: 'FIRST',
        type: 'CAR',
        brand: 'Honda',
        model: 'City',
        year: 2022,
      ));
      await f1;

      // SECOND must NOT be overwritten by FIRST!
      expect(provider.vehicles.firstWhere((v) => v.id == 1).vehicleNumber, 'SECOND');
    });

    test('refreshVehicles updates data silently without clearing existing data during load', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();

      final updatedVehicles = [
        ...sampleVehicles,
        Vehicle(
          id: 3,
          vehicleNumber: 'KA-03-EF-9999',
          type: 'TRUCK',
          brand: 'Volvo',
          model: 'FH',
          year: 2023,
          createdAt: DateTime.parse('2026-03-01T10:00:00.000'),
        ),
      ];
      mockService.vehiclesToReturn = updatedVehicles;

      final refreshFuture = provider.refreshVehicles();
      expect(provider.isRefreshing, isTrue);
      expect(provider.vehicles.length, 2);

      await refreshFuture;

      expect(provider.isRefreshing, isFalse);
      expect(provider.vehicles.length, 3);
      expect(provider.refreshErrorMessage, isNull);
    });

    test('refreshVehicles on failure retains existing vehicles and sets refreshErrorMessage', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();
      expect(provider.vehicles.length, 2);

      mockService.exceptionToThrow = const ApiException(
        statusCode: 0,
        message: 'Network connection lost',
        error: 'NetworkError',
      );

      await provider.refreshVehicles();

      expect(provider.isRefreshing, isFalse);
      expect(provider.vehicles.length, 2);
      expect(provider.refreshErrorMessage, 'Network connection lost');
    });

    test('refreshVehicles prevents overlapping refresh requests', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      final f1 = provider.refreshVehicles();
      final f2 = provider.refreshVehicles();

      await Future.wait([f1, f2]);
      expect(mockService.callCount, 1);
    });

    test('reset clears state', () async {
      mockService.vehiclesToReturn = sampleVehicles;
      await provider.fetchVehicles();
      expect(provider.vehicles, isNotEmpty);

      provider.reset();
      expect(provider.vehicles, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isRefreshing, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.refreshErrorMessage, isNull);
    });
  });
}
