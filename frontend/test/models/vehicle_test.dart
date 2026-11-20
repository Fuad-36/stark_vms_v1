import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/vehicle.dart';

void main() {
  group('Vehicle Model Unit Tests', () {
    final validJson = <String, dynamic>{
      'id': 1,
      'vehicleNumber': 'KA-01-HH-1234',
      'type': 'CAR',
      'brand': 'Toyota',
      'model': 'Corolla',
      'year': 2022,
      'createdAt': '2026-11-20T10:30:00.000',
      'updatedAt': '2026-11-20T11:00:00.000',
    };

    test('Valid JSON deserialization populates all fields correctly', () {
      final vehicle = Vehicle.fromJson(validJson);

      expect(vehicle.id, 1);
      expect(vehicle.vehicleNumber, 'KA-01-HH-1234');
      expect(vehicle.type, 'CAR');
      expect(vehicle.brand, 'Toyota');
      expect(vehicle.model, 'Corolla');
      expect(vehicle.year, 2022);
      expect(vehicle.createdAt, DateTime.parse('2026-11-20T10:30:00.000'));
      expect(vehicle.updatedAt, DateTime.parse('2026-11-20T11:00:00.000'));
      expect(vehicle.formattedCreatedAt, '2026-11-20 10:30');
    });

    test('Serialization using actual backend JSON property names', () {
      final vehicle = Vehicle(
        id: 42,
        vehicleNumber: 'MH-02-AB-9876',
        type: 'TRUCK',
        brand: 'Volvo',
        model: 'FH16',
        year: 2020,
        createdAt: DateTime.parse('2026-05-10T08:15:00.000'),
        updatedAt: DateTime.parse('2026-05-11T09:20:00.000'),
      );

      final json = vehicle.toJson();

      expect(json['id'], 42);
      expect(json['vehicleNumber'], 'MH-02-AB-9876');
      expect(json['type'], 'TRUCK');
      expect(json['brand'], 'Volvo');
      expect(json['model'], 'FH16');
      expect(json['year'], 2020);
      expect(json['createdAt'], '2026-05-10T08:15:00.000');
      expect(json['updatedAt'], '2026-05-11T09:20:00.000');
    });

    test('Nullable optional fields (id, createdAt, updatedAt) handled without crashing', () {
      final jsonWithNulls = <String, dynamic>{
        'id': null,
        'vehicleNumber': 'DL-03-CD-5678',
        'type': 'BUS',
        'brand': 'Mercedes-Benz',
        'model': 'Tourismo',
        'year': 2021,
        'createdAt': null,
        'updatedAt': null,
      };

      final vehicle = Vehicle.fromJson(jsonWithNulls);

      expect(vehicle.id, isNull);
      expect(vehicle.vehicleNumber, 'DL-03-CD-5678');
      expect(vehicle.type, 'BUS');
      expect(vehicle.brand, 'Mercedes-Benz');
      expect(vehicle.model, 'Tourismo');
      expect(vehicle.year, 2021);
      expect(vehicle.createdAt, isNull);
      expect(vehicle.updatedAt, isNull);
      expect(vehicle.formattedCreatedAt, '-');
    });

    test('Safe date parsing handles ISO-8601 strings and invalid date formats gracefully', () {
      final jsonWithOddDate = <String, dynamic>{
        'id': 10,
        'vehicleNumber': 'TN-09-EF-4321',
        'type': 'MOTORCYCLE',
        'brand': 'Honda',
        'model': 'CBR',
        'year': 2023,
        'createdAt': 'invalid-date-string',
        'updatedAt': '',
      };

      final vehicle = Vehicle.fromJson(jsonWithOddDate);

      expect(vehicle.createdAt, isNull);
      expect(vehicle.updatedAt, isNull);
      expect(vehicle.formattedCreatedAt, '-');
    });

    test('Year parsing handles int, num, and parseable String representations', () {
      final jsonWithNumYear = Map<String, dynamic>.from(validJson)..['year'] = 2019.0;
      final jsonWithStringYear = Map<String, dynamic>.from(validJson)..['year'] = '2018';

      expect(Vehicle.fromJson(jsonWithNumYear).year, 2019);
      expect(Vehicle.fromJson(jsonWithStringYear).year, 2018);
    });

    group('Missing or invalid required fields throw FormatException without fabricating data', () {
      test('missing vehicleNumber throws FormatException', () {
        final json = Map<String, dynamic>.from(validJson)..remove('vehicleNumber');
        expect(() => Vehicle.fromJson(json), throwsFormatException);
      });

      test('empty or whitespace-only vehicleNumber throws FormatException', () {
        final json = Map<String, dynamic>.from(validJson)..['vehicleNumber'] = '   ';
        expect(() => Vehicle.fromJson(json), throwsFormatException);
      });

      test('missing type throws FormatException', () {
        final json = Map<String, dynamic>.from(validJson)..remove('type');
        expect(() => Vehicle.fromJson(json), throwsFormatException);
      });

      test('missing brand throws FormatException', () {
        final json = Map<String, dynamic>.from(validJson)..remove('brand');
        expect(() => Vehicle.fromJson(json), throwsFormatException);
      });

      test('missing model throws FormatException', () {
        final json = Map<String, dynamic>.from(validJson)..remove('model');
        expect(() => Vehicle.fromJson(json), throwsFormatException);
      });

      test('missing year throws FormatException', () {
        final json = Map<String, dynamic>.from(validJson)..remove('year');
        expect(() => Vehicle.fromJson(json), throwsFormatException);
      });

      test('non-numeric year throws FormatException', () {
        final json = Map<String, dynamic>.from(validJson)..['year'] = 'two-thousand';
        expect(() => Vehicle.fromJson(json), throwsFormatException);
      });
    });

    test('Equality and hashCode contract', () {
      final v1 = Vehicle.fromJson(validJson);
      final v2 = Vehicle.fromJson(validJson);
      final v3 = Vehicle.fromJson(Map<String, dynamic>.from(validJson)..['id'] = 2);

      expect(v1, equals(v2));
      expect(v1.hashCode, equals(v2.hashCode));
      expect(v1, isNot(equals(v3)));
    });
  });
}
