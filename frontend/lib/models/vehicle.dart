/// Domain model representing a Vehicle in the Stark VMS system.
/// Derived strictly from the backend VehicleResponse contract.
class Vehicle {
  final int? id;
  final String vehicleNumber;
  final String type;
  final String brand;
  final String model;
  final int year;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vehicle({
    this.id,
    required this.vehicleNumber,
    required this.type,
    required this.brand,
    required this.model,
    required this.year,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to deserialize a [Vehicle] from backend JSON.
  /// Validates required fields and safely parses dates.
  /// Throws [FormatException] if required fields are missing or invalid,
  /// without fabricating default vehicle values.
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Validate required: vehicleNumber
    final rawVehicleNumber = json['vehicleNumber'];
    if (rawVehicleNumber == null || rawVehicleNumber is! String || rawVehicleNumber.trim().isEmpty) {
      throw const FormatException('Missing or invalid required field: vehicleNumber');
    }

    // Validate required: type
    final rawType = json['type'];
    if (rawType == null || rawType is! String || rawType.trim().isEmpty) {
      throw const FormatException('Missing or invalid required field: type');
    }

    // Validate required: brand
    final rawBrand = json['brand'];
    if (rawBrand == null || rawBrand is! String || rawBrand.trim().isEmpty) {
      throw const FormatException('Missing or invalid required field: brand');
    }

    // Validate required: model
    final rawModel = json['model'];
    if (rawModel == null || rawModel is! String || rawModel.trim().isEmpty) {
      throw const FormatException('Missing or invalid required field: model');
    }

    // Validate required: year
    final rawYear = json['year'];
    final int year;
    if (rawYear is int) {
      year = rawYear;
    } else if (rawYear is num) {
      year = rawYear.toInt();
    } else if (rawYear is String) {
      final parsed = int.tryParse(rawYear);
      if (parsed == null) {
        throw const FormatException('Invalid year: must be a valid integer');
      }
      year = parsed;
    } else {
      throw const FormatException('Missing or invalid required field: year');
    }

    // Optional id
    final rawId = json['id'];
    int? id;
    if (rawId is int) {
      id = rawId;
    } else if (rawId is num) {
      id = rawId.toInt();
    } else if (rawId is String) {
      id = int.tryParse(rawId);
    }

    // Safe date parsing for createdAt
    DateTime? createdAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt != null && rawCreatedAt is String && rawCreatedAt.trim().isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }

    // Safe date parsing for updatedAt
    DateTime? updatedAt;
    final rawUpdatedAt = json['updatedAt'];
    if (rawUpdatedAt != null && rawUpdatedAt is String && rawUpdatedAt.trim().isNotEmpty) {
      updatedAt = DateTime.tryParse(rawUpdatedAt);
    }

    return Vehicle(
      id: id,
      vehicleNumber: rawVehicleNumber.trim(),
      type: rawType.trim(),
      brand: rawBrand.trim(),
      model: rawModel.trim(),
      year: year,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Serializes the [Vehicle] into a JSON-compatible map matching the backend contract.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleNumber': vehicleNumber,
      'type': type,
      'brand': brand,
      'model': model,
      'year': year,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Formatted creation date and time for human-readable display.
  String get formattedCreatedAt {
    if (createdAt == null) return '-';
    final date = createdAt!;
    final yearStr = date.year.toString().padLeft(4, '0');
    final monthStr = date.month.toString().padLeft(2, '0');
    final dayStr = date.day.toString().padLeft(2, '0');
    final hourStr = date.hour.toString().padLeft(2, '0');
    final minuteStr = date.minute.toString().padLeft(2, '0');
    return '$yearStr-$monthStr-$dayStr $hourStr:$minuteStr';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          vehicleNumber == other.vehicleNumber &&
          type == other.type &&
          brand == other.brand &&
          model == other.model &&
          year == other.year &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      vehicleNumber.hashCode ^
      type.hashCode ^
      brand.hashCode ^
      model.hashCode ^
      year.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Vehicle(id: $id, vehicleNumber: $vehicleNumber, type: $type, brand: $brand, model: $model, year: $year, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
