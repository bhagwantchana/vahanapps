import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:latlong2/latlong.dart';

class VehicleTrackPoint {
  final double latitude;
  final double longitude;
  final double speed;
  final double course;
  final String createdAt;

  const VehicleTrackPoint({
    this.latitude = 0,
    this.longitude = 0,
    this.speed = 0,
    this.course = 0,
    this.createdAt = '',
  });

  factory VehicleTrackPoint.fromJson(Map<String, dynamic> json) {
    return VehicleTrackPoint(
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      speed: toDouble(json['speed']),
      course: toDouble(json['course']),
      createdAt: toStringValue(json['created_at']),
    );
  }

  bool get hasPoint => latitude != 0 || longitude != 0;

  LatLng toLatLng() => LatLng(latitude, longitude);
}
