import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';

class VehicleListModel {
  final int flag;
  final int count;
  final String message;
  final List<VehicleRecord> data;

  /// Server-computed HMAC for the /live/stream SSE channel (per-user, one sig
  /// covers the whole list). Empty while the tracking server's GPS_SSE_SECRET
  /// is unarmed; REQUIRED once it deploys — without it the stream answers 403.
  final String sseSig;

  const VehicleListModel({
    this.flag = 0,
    this.count = 0,
    this.message = '',
    this.data = const <VehicleRecord>[],
    this.sseSig = '',
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
      sseSig: toStringValue(json['sse_sig']),
    );
  }
}
