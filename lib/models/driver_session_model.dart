import 'package:fleet_monitor/models/model_helpers.dart';

class DriverSessionModel {
  final int id;
  final int vendorId;
  final int driverId;
  final int vehicleId;
  final int deviceId;
  final int customerId;
  final String sessionCode;
  final String identificationMethod;
  final String status;
  final String startedAt;
  final String endedAt;
  final String notes;
  final String driverName;
  final String driverCode;
  final String registrationNumber;
  final String vehicleName;
  final String imei;

  const DriverSessionModel({
    this.id = 0,
    this.vendorId = 0,
    this.driverId = 0,
    this.vehicleId = 0,
    this.deviceId = 0,
    this.customerId = 0,
    this.sessionCode = '',
    this.identificationMethod = '',
    this.status = '',
    this.startedAt = '',
    this.endedAt = '',
    this.notes = '',
    this.driverName = '',
    this.driverCode = '',
    this.registrationNumber = '',
    this.vehicleName = '',
    this.imei = '',
  });

  factory DriverSessionModel.fromJson(Map<String, dynamic> json) {
    return DriverSessionModel(
      id: toInt(json['id']),
      vendorId: toInt(json['vendor_id']),
      driverId: toInt(json['driver_id']),
      vehicleId: toInt(json['vehicle_id']),
      deviceId: toInt(json['device_id']),
      customerId: toInt(json['customer_id']),
      sessionCode: toStringValue(json['session_code']),
      identificationMethod: toStringValue(json['identification_method']),
      status: toStringValue(json['status']),
      startedAt: toStringValue(json['started_at']),
      endedAt: toStringValue(json['ended_at']),
      notes: toStringValue(json['notes']),
      driverName: toStringValue(json['driver_name']),
      driverCode: toStringValue(json['driver_code']),
      registrationNumber: toStringValue(json['v_registration_no']),
      vehicleName: toStringValue(json['v_name']),
      imei: toStringValue(json['imei']),
    );
  }

  String get displayVehicle {
    if (registrationNumber.isNotEmpty && vehicleName.isNotEmpty) {
      return '$registrationNumber - $vehicleName';
    }
    if (registrationNumber.isNotEmpty) {
      return registrationNumber;
    }
    return vehicleName;
  }

  String get displayDriver {
    if (driverName.isNotEmpty && driverCode.isNotEmpty) {
      return '$driverName ($driverCode)';
    }
    if (driverName.isNotEmpty) {
      return driverName;
    }
    return driverCode;
  }
}
