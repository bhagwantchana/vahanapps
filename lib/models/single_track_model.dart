import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';

class SingleTrackModel {
  final int flag;
  final String message;
  final VehicleRecord? data;

  const SingleTrackModel({
    this.flag = 0,
    this.message = '',
    this.data,
  });

  factory SingleTrackModel.fromJson(Map<String, dynamic> json) {
    return SingleTrackModel(
      flag: toInt(json['flag']),
      message: toStringValue(json['message']),
      data: json['data'] is Map<String, dynamic>
          ? VehicleRecord.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }

  SingleTrackModel copyWith({
    int? flag,
    String? message,
    VehicleRecord? data,
  }) {
    return SingleTrackModel(
      flag: flag ?? this.flag,
      message: message ?? this.message,
      data: data ?? this.data,
    );
  }
}
