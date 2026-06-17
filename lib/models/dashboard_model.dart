import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';

class DashboardModel {
  final int flag;
  final String message;
  final DashboardData? data;

  const DashboardModel({
    this.flag = 0,
    this.message = '',
    this.data,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      flag: toInt(json['flag']),
      message: toStringValue(json['message']),
      data: json['data'] is Map<String, dynamic>
          ? DashboardData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardData {
  final List<VehicleRecord> vehicleList;
  final int vehicleCount;
  final int unreadAlertCount;
  final String mapsUrl;
  final String legacyMapsUrl;
  final String mobileMapMode;
  /// Universal map engine ('maplibre' | 'google'). Set in superadmin
  /// Settings → "Default Map Engine". NativeVehicleMap swaps its tile
  /// URL template at runtime based on this value so the WHOLE fleet uses
  /// one consistent map style.
  final String mobileMapProvider;
  final int mobileMapTrailMinutes;
  final int mobileMapTrailPoints;
  final UserProfileData? profile;
  final DashboardAnalytics analytics;
  final List<DashboardShortcut> reportShortcuts;

  const DashboardData({
    this.vehicleList = const <VehicleRecord>[],
    this.vehicleCount = 0,
    this.unreadAlertCount = 0,
    this.mapsUrl = '',
    this.legacyMapsUrl = '',
    this.mobileMapMode = 'native',
    this.mobileMapProvider = 'maplibre',
    this.mobileMapTrailMinutes = 120,
    this.mobileMapTrailPoints = 25,
    this.profile,
    this.analytics = const DashboardAnalytics(),
    this.reportShortcuts = const <DashboardShortcut>[],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final vehicleItems = <VehicleRecord>[];
    if (json['vehicleList'] is List) {
      for (final item in json['vehicleList'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          vehicleItems.add(VehicleRecord.fromJson(item));
        }
      }
    }

    final shortcuts = <DashboardShortcut>[];
    if (json['report_shortcuts'] is List) {
      for (final item in json['report_shortcuts'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          shortcuts.add(DashboardShortcut.fromJson(item));
        }
      }
    }

    return DashboardData(
      vehicleList: vehicleItems,
      vehicleCount: toInt(json['vehicle_count'], fallback: vehicleItems.length),
      unreadAlertCount: toInt(json['unread_alert_count']),
      mapsUrl: toStringValue(json['maps_url']),
      legacyMapsUrl: toStringValue(json['legacy_maps_url']),
      mobileMapMode: toStringValue(json['mobile_map_mode'], fallback: 'native'),
      mobileMapProvider: toStringValue(json['mobile_map_provider'], fallback: 'maplibre'),
      mobileMapTrailMinutes: toInt(json['mobile_map_trail_minutes'], fallback: 120),
      mobileMapTrailPoints: toInt(json['mobile_map_trail_points'], fallback: 25),
      profile: json['profile'] is Map<String, dynamic>
          ? UserProfileData.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      analytics: json['analytics'] is Map<String, dynamic>
          ? DashboardAnalytics.fromJson(json['analytics'] as Map<String, dynamic>)
          : const DashboardAnalytics(),
      reportShortcuts: shortcuts,
    );
  }
}

class DashboardShortcut {
  final String key;
  final String label;

  const DashboardShortcut({
    this.key = '',
    this.label = '',
  });

  factory DashboardShortcut.fromJson(Map<String, dynamic> json) {
    return DashboardShortcut(
      key: toStringValue(json['key']),
      label: toStringValue(json['label']),
    );
  }
}

class DashboardAnalytics {
  final DashboardStatusBreakdown statusBreakdown;
  final DashboardChart distanceTrend;
  final DashboardChart alertTrend;
  final List<DashboardHeatmapPoint> heatmapPoints;
  final DashboardMaintenanceSnapshot maintenanceSnapshot;
  final List<DashboardPanicAlert> recentPanicAlerts;

  const DashboardAnalytics({
    this.statusBreakdown = const DashboardStatusBreakdown(),
    this.distanceTrend = const DashboardChart(),
    this.alertTrend = const DashboardChart(),
    this.heatmapPoints = const <DashboardHeatmapPoint>[],
    this.maintenanceSnapshot = const DashboardMaintenanceSnapshot(),
    this.recentPanicAlerts = const <DashboardPanicAlert>[],
  });

  factory DashboardAnalytics.fromJson(Map<String, dynamic> json) {
    final points = <DashboardHeatmapPoint>[];
    if (json['heatmap_points'] is List) {
      for (final item in json['heatmap_points'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          points.add(DashboardHeatmapPoint.fromJson(item));
        }
      }
    }

    final panicAlerts = <DashboardPanicAlert>[];
    if (json['recent_panic_alerts'] is List) {
      for (final item in json['recent_panic_alerts'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          panicAlerts.add(DashboardPanicAlert.fromJson(item));
        }
      }
    }

    return DashboardAnalytics(
      statusBreakdown: json['status_breakdown'] is Map<String, dynamic>
          ? DashboardStatusBreakdown.fromJson(
              json['status_breakdown'] as Map<String, dynamic>,
            )
          : const DashboardStatusBreakdown(),
      distanceTrend: json['distance_trend'] is Map<String, dynamic>
          ? DashboardChart.fromJson(json['distance_trend'] as Map<String, dynamic>)
          : const DashboardChart(),
      alertTrend: json['alert_trend'] is Map<String, dynamic>
          ? DashboardChart.fromJson(json['alert_trend'] as Map<String, dynamic>)
          : const DashboardChart(),
      heatmapPoints: points,
      maintenanceSnapshot: json['maintenance_snapshot'] is Map<String, dynamic>
          ? DashboardMaintenanceSnapshot.fromJson(
              json['maintenance_snapshot'] as Map<String, dynamic>,
            )
          : const DashboardMaintenanceSnapshot(),
      recentPanicAlerts: panicAlerts,
    );
  }
}

class DashboardStatusBreakdown {
  final int moving;
  final int idle;
  final int stopped;

  const DashboardStatusBreakdown({
    this.moving = 0,
    this.idle = 0,
    this.stopped = 0,
  });

  factory DashboardStatusBreakdown.fromJson(Map<String, dynamic> json) {
    return DashboardStatusBreakdown(
      moving: toInt(json['moving']),
      idle: toInt(json['idle']),
      stopped: toInt(json['stopped']),
    );
  }
}

class DashboardChart {
  final List<String> categories;
  final List<DashboardSeries> series;

  const DashboardChart({
    this.categories = const <String>[],
    this.series = const <DashboardSeries>[],
  });

  factory DashboardChart.fromJson(Map<String, dynamic> json) {
    final categories = <String>[];
    if (json['categories'] is List) {
      for (final item in json['categories'] as List<dynamic>) {
        categories.add(toStringValue(item));
      }
    }

    final chartSeries = <DashboardSeries>[];
    if (json['series'] is List) {
      for (final item in json['series'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          chartSeries.add(DashboardSeries.fromJson(item));
        }
      }
    }

    return DashboardChart(
      categories: categories,
      series: chartSeries,
    );
  }
}

class DashboardSeries {
  final String name;
  final List<double> data;

  const DashboardSeries({
    this.name = '',
    this.data = const <double>[],
  });

  factory DashboardSeries.fromJson(Map<String, dynamic> json) {
    final points = <double>[];
    if (json['data'] is List) {
      for (final item in json['data'] as List<dynamic>) {
        points.add(toDouble(item));
      }
    }

    return DashboardSeries(
      name: toStringValue(json['name']),
      data: points,
    );
  }
}

class DashboardHeatmapPoint {
  final double latitude;
  final double longitude;
  final int hits;
  final String label;
  final String severity;

  const DashboardHeatmapPoint({
    this.latitude = 0,
    this.longitude = 0,
    this.hits = 0,
    this.label = '',
    this.severity = '',
  });

  factory DashboardHeatmapPoint.fromJson(Map<String, dynamic> json) {
    return DashboardHeatmapPoint(
      latitude: toDouble(json['latitude'] ?? json['lat']),
      longitude: toDouble(json['longitude'] ?? json['lng']),
      hits: toInt(json['hits'] ?? json['intensity']),
      label: toStringValue(json['label']),
      severity: toStringValue(json['severity']),
    );
  }
}

class DashboardMaintenanceSnapshot {
  final int overdue;
  final int dueSoon;
  final int tracked;

  const DashboardMaintenanceSnapshot({
    this.overdue = 0,
    this.dueSoon = 0,
    this.tracked = 0,
  });

  factory DashboardMaintenanceSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardMaintenanceSnapshot(
      overdue: toInt(json['overdue']),
      dueSoon: toInt(json['due_soon']),
      tracked: toInt(json['tracked']),
    );
  }
}

class DashboardPanicAlert {
  final int id;
  final String vehicleLabel;
  final String message;
  final String createdAt;

  const DashboardPanicAlert({
    this.id = 0,
    this.vehicleLabel = '',
    this.message = '',
    this.createdAt = '',
  });

  factory DashboardPanicAlert.fromJson(Map<String, dynamic> json) {
    final vehicleLabel = toStringValue(json['vehicle_label']);
    return DashboardPanicAlert(
      id: toInt(json['id']),
      vehicleLabel: vehicleLabel.isNotEmpty
          ? vehicleLabel
          : 'Vehicle #${toInt(json['vehicle_id'])}',
      message: toStringValue(json['message']),
      createdAt: toStringValue(json['created_at']),
    );
  }
}
