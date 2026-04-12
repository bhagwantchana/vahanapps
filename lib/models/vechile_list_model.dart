import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';

class VehicleListModel {
  final int flag;
  final int count;
  final String message;
  final List<VehicleRecord> data;

  const VehicleListModel({
    this.flag = 0,
    this.count = 0,
    this.message = '',
    this.data = const <VehicleRecord>[],
  });

  factory VehicleListModel.fromJson(Map<String, dynamic> json) {
    final vehicles = <VehicleRecord>[];
    if (json['data'] is List) {
      for (final item in json['data'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          vehicles.add(VehicleRecord.fromJson(item));
        }
      }
    }

    return VehicleListModel(
      flag: toInt(json['flag']),
      count: toInt(json['count'], fallback: vehicles.length),
      message: toStringValue(json['message']),
      data: vehicles,
    );
  }
}
