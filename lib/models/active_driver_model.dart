import 'package:fleet_monitor/models/model_helpers.dart';

class ActiveDriverModel {
  final int driverId;
  final String name;
  final String driverCode;
  final int sessionId;
  final String identificationMethod;
  final String identifiedAt;

  const ActiveDriverModel({
    this.driverId = 0,
    this.name = '',
    this.driverCode = '',
    this.sessionId = 0,
    this.identificationMethod = '',
    this.identifiedAt = '',
  });

  factory ActiveDriverModel.fromJson(Map<String, dynamic> json) {
    return ActiveDriverModel(
      driverId: toInt(json['driver_id']),
      name: toStringValue(json['name']),
      driverCode: toStringValue(json['driver_code']),
      sessionId: toInt(json['session_id']),
      identificationMethod: toStringValue(json['identification_method']),
      identifiedAt: toStringValue(json['identified_at']),
    );
  }

  bool get isActive => driverId > 0 || sessionId > 0;

  String get displayName {
    if (name.isNotEmpty && driverCode.isNotEmpty) {
      return '$name ($driverCode)';
    }
    if (name.isNotEmpty) {
      return name;
    }
    return driverCode;
  }
}
