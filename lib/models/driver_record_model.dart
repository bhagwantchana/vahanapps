import 'package:fleet_monitor/models/model_helpers.dart';

class DriverRecordModel {
  final int id;
  final int vendorId;
  final String name;
  final String phone;
  final String driverCode;
  final String licenseNo;
  final int status;

  const DriverRecordModel({
    this.id = 0,
    this.vendorId = 0,
    this.name = '',
    this.phone = '',
    this.driverCode = '',
    this.licenseNo = '',
    this.status = 0,
  });

  factory DriverRecordModel.fromJson(Map<String, dynamic> json) {
    return DriverRecordModel(
      id: toInt(json['id']),
      vendorId: toInt(json['vendor_id']),
      name: toStringValue(json['name']),
      phone: toStringValue(json['phone']),
      driverCode: toStringValue(json['driver_code']),
      licenseNo: toStringValue(json['license_no']),
      status: toInt(json['status'], fallback: 1),
    );
  }

  String get displayLabel {
    if (name.isNotEmpty && driverCode.isNotEmpty) {
      return '$name ($driverCode)';
    }
    if (name.isNotEmpty) {
      return name;
    }
    return driverCode;
  }
}
