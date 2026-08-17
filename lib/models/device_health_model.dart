/// One tracker's diagnosis, as judged server-side by Device_health_model.
///
/// The server does the judging on purpose: the thresholds ("20 power-cut
/// alerts in 3 days means a loose wire") are operational knowledge that
/// changes as we learn more, and a fielded app cannot be updated to match.
class DeviceHealth {
  DeviceHealth({
    required this.deviceId,
    required this.vehicleId,
    required this.imei,
    required this.label,
    required this.severity,
    required this.code,
    required this.reason,
    required this.action,
    required this.lastUpdated,
    required this.powerCutAlerts,
    required this.tamperingAlerts,
  });

  final int deviceId;
  final int vehicleId;
  final String imei;
  final String label;

  /// 'critical' | 'warning' | 'info' | 'ok'
  final String severity;

  /// Machine-readable cause: never_reported, offline_long, wiring_fault,
  /// tamper_flood, offline_short, weak_gps, healthy.
  final String code;

  /// Plain sentence for the owner: what is wrong.
  final String reason;

  /// Plain sentence for the owner: what fixes it. Empty when healthy.
  final String action;

  final String lastUpdated;
  final int powerCutAlerts;
  final int tamperingAlerts;

  bool get isHealthy => severity == 'ok';

  static int _asInt(dynamic v) =>
      v == null ? 0 : int.tryParse(v.toString()) ?? 0;

  factory DeviceHealth.fromJson(Map<String, dynamic> json) {
    return DeviceHealth(
      deviceId: _asInt(json['device_id']),
      vehicleId: _asInt(json['vehicle_id']),
      imei: (json['imei'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      severity: (json['severity'] ?? 'ok').toString(),
      code: (json['code'] ?? 'healthy').toString(),
      reason: (json['reason'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      lastUpdated: (json['last_updated'] ?? '').toString(),
      powerCutAlerts: _asInt(json['power_cut_alerts']),
      tamperingAlerts: _asInt(json['tampering_alerts']),
    );
  }
}

/// A feature this account owns but has never switched on. Night Lock and
/// stop alerts were both live with zero users — built, working, unknown.
class UnusedFeatureHint {
  UnusedFeatureHint({
    required this.key,
    required this.title,
    required this.body,
    required this.cta,
  });

  final String key;
  final String title;
  final String body;
  final String cta;

  factory UnusedFeatureHint.fromJson(Map<String, dynamic> json) {
    return UnusedFeatureHint(
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      cta: (json['cta'] ?? '').toString(),
    );
  }
}

class DeviceHealthReport {
  DeviceHealthReport({
    required this.devices,
    required this.hints,
    required this.critical,
    required this.warning,
    required this.info,
    required this.ok,
  });

  final List<DeviceHealth> devices;
  final List<UnusedFeatureHint> hints;
  final int critical;
  final int warning;
  final int info;
  final int ok;

  int get needsAttention => critical + warning;

  factory DeviceHealthReport.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final summary =
        (data['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final list = (data['devices'] as List<dynamic>?) ?? <dynamic>[];
    final hintList =
        (data['unused_features'] as List<dynamic>?) ?? <dynamic>[];

    int count(String key) =>
        int.tryParse((summary[key] ?? 0).toString()) ?? 0;

    return DeviceHealthReport(
      devices: list
          .whereType<Map<String, dynamic>>()
          .map(DeviceHealth.fromJson)
          .toList(),
      hints: hintList
          .whereType<Map<String, dynamic>>()
          .map(UnusedFeatureHint.fromJson)
          .toList(),
      critical: count('critical'),
      warning: count('warning'),
      info: count('info'),
      ok: count('ok'),
    );
  }
}
