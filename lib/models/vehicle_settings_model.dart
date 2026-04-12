import 'package:fleet_monitor/models/model_helpers.dart';

class VehicleSettingsModel {
  final int vehicleId;
  final int deviceId;
  final String imei;
  final int notificationEnabled;
  final int overspeedLimit;
  final double geofenceLat;
  final double geofenceLng;
  final int geofenceRadius;
  final int guardActive;
  final double guardLat;
  final double guardLng;
  final int mapSelection;
  final int engineCutoff;
  final String immobilizerState;
  final String immobilizerUpdatedAt;
  final int radiusConfig;
  final int parkingGuard;
  final int nightLockEnabled;
  final String nightLockStart;
  final String nightLockEnd;
  final String nightLockTimezone;
  final int allowEngineControl;
  final int allowHistory;
  final int allowDocuments;
  final int allowDriverSessions;
  final int allowConfig;
  final int allowParkingGuard;
  final int allowNotifications;
  final int showEngineRpm;
  final int showBatteryVoltage;
  final int showDtcCodes;
  final int showEcuMileage;
  final String trackingUrl;
  final String singleMapUrl;
  final String googleTrackingUrl;
  final String historyUrl;
  final String mobileMapMode;
  final int mobileMapTrailMinutes;
  final int mobileMapTrailPoints;

  const VehicleSettingsModel({
    this.vehicleId = 0,
    this.deviceId = 0,
    this.imei = '',
    this.notificationEnabled = 1,
    this.overspeedLimit = 0,
    this.geofenceLat = 0,
    this.geofenceLng = 0,
    this.geofenceRadius = 0,
    this.guardActive = 0,
    this.guardLat = 0,
    this.guardLng = 0,
    this.mapSelection = 0,
    this.engineCutoff = 0,
    this.immobilizerState = 'unlocked',
    this.immobilizerUpdatedAt = '',
    this.radiusConfig = 0,
    this.parkingGuard = 0,
    this.nightLockEnabled = 0,
    this.nightLockStart = '22:00:00',
    this.nightLockEnd = '06:00:00',
    this.nightLockTimezone = 'Asia/Calcutta',
    this.allowEngineControl = 1,
    this.allowHistory = 1,
    this.allowDocuments = 1,
    this.allowDriverSessions = 1,
    this.allowConfig = 1,
    this.allowParkingGuard = 1,
    this.allowNotifications = 1,
    this.showEngineRpm = 0,
    this.showBatteryVoltage = 0,
    this.showDtcCodes = 0,
    this.showEcuMileage = 0,
    this.trackingUrl = '',
    this.singleMapUrl = '',
    this.googleTrackingUrl = '',
    this.historyUrl = '',
    this.mobileMapMode = 'native',
    this.mobileMapTrailMinutes = 120,
    this.mobileMapTrailPoints = 25,
  });

  factory VehicleSettingsModel.fromJson(Map<String, dynamic> json) {
    final linkMap = (json['links'] is Map<String, dynamic>)
        ? json['links'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return VehicleSettingsModel(
      vehicleId: toInt(json['vehicle_id']),
      deviceId: toInt(json['device_id']),
      imei: toStringValue(json['imei']),
      notificationEnabled: toInt(json['v_notification'], fallback: 1),
      overspeedLimit: toInt(json['v_overspeed']),
      geofenceLat: toDouble(json['geofence_lat']),
      geofenceLng: toDouble(json['geofence_lng']),
      geofenceRadius: toInt(json['geofence_radius']),
      guardActive: toInt(json['guard_active']),
      guardLat: toDouble(json['guard_lat']),
      guardLng: toDouble(json['guard_lng']),
      mapSelection: toInt(json['map_selection']),
      engineCutoff: toInt(json['engine_cutoff']),
      immobilizerState: toStringValue(json['immobilizer_state'], fallback: 'unlocked'),
      immobilizerUpdatedAt: toStringValue(json['immobilizer_updated_at']),
      radiusConfig: toInt(json['radius_config']),
      parkingGuard: toInt(json['parking_guard']),
      nightLockEnabled: toInt(json['night_lock_enabled']),
      nightLockStart: toStringValue(json['night_lock_start'], fallback: '22:00:00'),
      nightLockEnd: toStringValue(json['night_lock_end'], fallback: '06:00:00'),
      nightLockTimezone: toStringValue(json['night_lock_timezone'], fallback: 'Asia/Calcutta'),
      allowEngineControl: toInt(json['allow_engine_control'], fallback: 1),
      allowHistory: toInt(json['allow_history'], fallback: 1),
      allowDocuments: toInt(json['allow_documents'], fallback: 1),
      allowDriverSessions: toInt(json['allow_driver_sessions'], fallback: 1),
      allowConfig: toInt(json['allow_config'], fallback: 1),
      allowParkingGuard: toInt(json['allow_parking_guard'], fallback: 1),
      allowNotifications: toInt(json['allow_notifications'], fallback: 1),
      showEngineRpm: toInt(json['show_engine_rpm']),
      showBatteryVoltage: toInt(json['show_battery_voltage']),
      showDtcCodes: toInt(json['show_dtc_codes']),
      showEcuMileage: toInt(json['show_ecu_mileage']),
      trackingUrl: toStringValue(linkMap['tracking_url']),
      singleMapUrl: toStringValue(linkMap['single_map_url']),
      googleTrackingUrl: toStringValue(linkMap['google_tracking_url']),
      historyUrl: toStringValue(linkMap['history_url']),
      mobileMapMode: toStringValue(json['mobile_map_mode'], fallback: 'native'),
      mobileMapTrailMinutes: toInt(json['mobile_map_trail_minutes'], fallback: 120),
      mobileMapTrailPoints: toInt(json['mobile_map_trail_points'], fallback: 25),
    );
  }

  VehicleSettingsModel copyWith({
    int? notificationEnabled,
    int? overspeedLimit,
    double? geofenceLat,
    double? geofenceLng,
    int? geofenceRadius,
    int? guardActive,
    double? guardLat,
    double? guardLng,
    int? parkingGuard,
    String? immobilizerState,
    String? immobilizerUpdatedAt,
    int? nightLockEnabled,
    String? nightLockStart,
    String? nightLockEnd,
    String? nightLockTimezone,
    int? allowEngineControl,
    int? allowHistory,
    int? allowDocuments,
    int? allowDriverSessions,
    int? allowConfig,
    int? allowParkingGuard,
    int? allowNotifications,
    int? showEngineRpm,
    int? showBatteryVoltage,
    int? showDtcCodes,
    int? showEcuMileage,
    String? mobileMapMode,
    int? mobileMapTrailMinutes,
    int? mobileMapTrailPoints,
  }) {
    return VehicleSettingsModel(
      vehicleId: vehicleId,
      deviceId: deviceId,
      imei: imei,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      overspeedLimit: overspeedLimit ?? this.overspeedLimit,
      geofenceLat: geofenceLat ?? this.geofenceLat,
      geofenceLng: geofenceLng ?? this.geofenceLng,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      guardActive: guardActive ?? this.guardActive,
      guardLat: guardLat ?? this.guardLat,
      guardLng: guardLng ?? this.guardLng,
      mapSelection: mapSelection,
      engineCutoff: engineCutoff,
      immobilizerState: immobilizerState ?? this.immobilizerState,
      immobilizerUpdatedAt: immobilizerUpdatedAt ?? this.immobilizerUpdatedAt,
      radiusConfig: radiusConfig,
      parkingGuard: parkingGuard ?? this.parkingGuard,
      nightLockEnabled: nightLockEnabled ?? this.nightLockEnabled,
      nightLockStart: nightLockStart ?? this.nightLockStart,
      nightLockEnd: nightLockEnd ?? this.nightLockEnd,
      nightLockTimezone: nightLockTimezone ?? this.nightLockTimezone,
      allowEngineControl: allowEngineControl ?? this.allowEngineControl,
      allowHistory: allowHistory ?? this.allowHistory,
      allowDocuments: allowDocuments ?? this.allowDocuments,
      allowDriverSessions: allowDriverSessions ?? this.allowDriverSessions,
      allowConfig: allowConfig ?? this.allowConfig,
      allowParkingGuard: allowParkingGuard ?? this.allowParkingGuard,
      allowNotifications: allowNotifications ?? this.allowNotifications,
      showEngineRpm: showEngineRpm ?? this.showEngineRpm,
      showBatteryVoltage: showBatteryVoltage ?? this.showBatteryVoltage,
      showDtcCodes: showDtcCodes ?? this.showDtcCodes,
      showEcuMileage: showEcuMileage ?? this.showEcuMileage,
      trackingUrl: trackingUrl,
      singleMapUrl: singleMapUrl,
      googleTrackingUrl: googleTrackingUrl,
      historyUrl: historyUrl,
      mobileMapMode: mobileMapMode ?? this.mobileMapMode,
      mobileMapTrailMinutes: mobileMapTrailMinutes ?? this.mobileMapTrailMinutes,
      mobileMapTrailPoints: mobileMapTrailPoints ?? this.mobileMapTrailPoints,
    );
  }

  Map<String, dynamic> toUpdatePayload({
    required double fallbackLat,
    required double fallbackLng,
  }) {
    final resolvedGeofenceLat = geofenceRadius > 0
        ? (geofenceLat != 0 ? geofenceLat : fallbackLat)
        : 0;
    final resolvedGeofenceLng = geofenceRadius > 0
        ? (geofenceLng != 0 ? geofenceLng : fallbackLng)
        : 0;
    final resolvedGuardLat = guardActive == 1
        ? (guardLat != 0 ? guardLat : fallbackLat)
        : 0;
    final resolvedGuardLng = guardActive == 1
        ? (guardLng != 0 ? guardLng : fallbackLng)
        : 0;

    return <String, dynamic>{
      'vehicle_id': vehicleId.toString(),
      'imei': imei,
      'v_notification': notificationEnabled.toString(),
      'v_overspeed': overspeedLimit.toString(),
      'geofence_radius': geofenceRadius.toString(),
      'geofence_lat': resolvedGeofenceLat.toStringAsFixed(6),
      'geofence_lng': resolvedGeofenceLng.toStringAsFixed(6),
      'guard_active': guardActive.toString(),
      'guard_lat': resolvedGuardLat.toStringAsFixed(6),
      'guard_lng': resolvedGuardLng.toStringAsFixed(6),
      'night_lock_enabled': nightLockEnabled.toString(),
      'night_lock_start': nightLockStart,
      'night_lock_end': nightLockEnd,
      'night_lock_timezone': nightLockTimezone,
      'allow_engine_control': allowEngineControl.toString(),
      'allow_history': allowHistory.toString(),
      'allow_documents': allowDocuments.toString(),
      'allow_driver_sessions': allowDriverSessions.toString(),
      'allow_config': allowConfig.toString(),
      'allow_parking_guard': allowParkingGuard.toString(),
      'allow_notifications': allowNotifications.toString(),
      'show_engine_rpm': showEngineRpm.toString(),
      'show_battery_voltage': showBatteryVoltage.toString(),
      'show_dtc_codes': showDtcCodes.toString(),
      'show_ecu_mileage': showEcuMileage.toString(),
    };
  }
}
