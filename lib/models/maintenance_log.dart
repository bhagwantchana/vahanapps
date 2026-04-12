import 'package:fleet_monitor/models/model_helpers.dart';

class MaintenanceLog {
  final int id;
  final int vehicleId;
  final String serviceType;
  final String serviceDate;
  final double odometerReading;
  final double cost;

  const MaintenanceLog({
    this.id = 0,
    this.vehicleId = 0,
    this.serviceType = '',
    this.serviceDate = '',
    this.odometerReading = 0,
    this.cost = 0,
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> json) {
    return MaintenanceLog(
      id: toInt(json['id']),
      vehicleId: toInt(json['vehicle_id']),
      serviceType: toStringValue(json['service_type']),
      serviceDate: toStringValue(json['service_date']),
      odometerReading: toDouble(
        json['odometer_reading'] ?? json['odometer'],
      ),
      cost: toDouble(json['cost']),
    );
  }

  DateTime? get serviceDateValue => toDateTime(serviceDate);
}
