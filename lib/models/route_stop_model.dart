import 'package:fleet_monitor/models/model_helpers.dart';

/// One stop on a vehicle's route, as defined (or mined from GPS history and
/// approved) in the superadmin panel.
class RouteStop {
  const RouteStop({
    this.id = 0,
    this.name = '',
    this.latitude = 0,
    this.longitude = 0,
    this.seq = 0,
    this.radiusM = 120,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int seq;
  final int radiusM;

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: toInt(json['id']),
      name: toStringValue(json['name']),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      seq: toInt(json['seq']),
      radiusM: toInt(json['radius_m']),
    );
  }

  /// What the picker shows when the school hasn't named the stop yet.
  String get displayName =>
      name.trim().isNotEmpty
          ? name.trim()
          : '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}

/// The server's answer to "how many minutes away is the bus" — computed from
/// the bus's own previous days on this route (backtested: median error
/// 1.6 min, p90 6.1 min, biased slightly early — the safe direction).
class StopEta {
  const StopEta({
    this.etaMinutes,
    this.etaSeconds,
    this.basedOnDays = 0,
    this.reason = '',
    this.busUpdatedAt = '',
  });

  /// null = history can't answer right now; show "--", never a made-up number.
  final int? etaMinutes;
  final int? etaSeconds;
  final int basedOnDays;
  final String reason;
  final String busUpdatedAt;

  bool get hasEta => etaMinutes != null;

  factory StopEta.fromJson(Map<String, dynamic> json) {
    final eta = json['eta'];
    final bus = json['bus'];
    return StopEta(
      etaMinutes: eta is Map ? toInt(eta['eta_minutes']) : null,
      etaSeconds: eta is Map ? toInt(eta['eta_seconds']) : null,
      basedOnDays: eta is Map ? toInt(eta['based_on_days']) : 0,
      reason: toStringValue(json['reason']),
      busUpdatedAt: bus is Map ? toStringValue(bus['last_updated']) : '',
    );
  }
}
