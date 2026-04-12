import 'package:fleet_monitor/models/active_driver_model.dart';
import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/vehicle_settings_model.dart';

class VehicleRecord {
  final int id;
  final int userId;
  final int vendorId;
  final int driverId;
  final String registrationNumber;
  final String name;
  final String model;
  final String typeName;
  final String imei;
  final int deviceId;
  final String vehicleIcon;
  final String vehicleIconUrl;
  final String deviceModel;
  final String protocol;
  final String port;
  final double latitude;
  final double longitude;
  final double speed;
  final double course;
  final int acc;
  final int battery;
  final int overspeedLimit;
  final int notificationEnabled;
  final int guardActive;
  final double guardLat;
  final double guardLng;
  final double geofenceLat;
  final double geofenceLng;
  final int geofenceRadius;
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
  final double engineRpm;
  final double batteryVoltage;
  final String dtcCodes;
  final double ecuMileage;
  final double currentOdometer;
  final double vOdometer;
  final int maintenanceIntervalDays;
  final int maintenanceIntervalKm;
  final String trackingUrl;
  final String singleMapUrl;
  final String googleTrackingUrl;
  final String historyUrl;
  final String multiMapUrl;
  final String legacyMultiMapUrl;
  final String createdAt;
  final bool hasLiveLocation;
  final ActiveDriverModel? activeDriver;
  final VehicleSettingsModel? settings;

  const VehicleRecord({
    this.id = 0,
    this.userId = 0,
    this.vendorId = 0,
    this.driverId = 0,
    this.registrationNumber = '',
    this.name = '',
    this.model = '',
    this.typeName = '',
    this.imei = '',
    this.deviceId = 0,
    this.vehicleIcon = '',
    this.vehicleIconUrl = '',
    this.deviceModel = '',
    this.protocol = '',
    this.port = '',
    this.latitude = 0,
    this.longitude = 0,
    this.speed = 0,
    this.course = 0,
    this.acc = 0,
    this.battery = 0,
    this.overspeedLimit = 0,
    this.notificationEnabled = 1,
    this.guardActive = 0,
    this.guardLat = 0,
    this.guardLng = 0,
    this.geofenceLat = 0,
    this.geofenceLng = 0,
    this.geofenceRadius = 0,
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
    this.engineRpm = 0,
    this.batteryVoltage = 0,
    this.dtcCodes = '',
    this.ecuMileage = 0,
    this.currentOdometer = 0,
    this.vOdometer = 0,
    this.maintenanceIntervalDays = 0,
    this.maintenanceIntervalKm = 0,
    this.trackingUrl = '',
    this.singleMapUrl = '',
    this.googleTrackingUrl = '',
    this.historyUrl = '',
    this.multiMapUrl = '',
    this.legacyMultiMapUrl = '',
    this.createdAt = '',
    this.hasLiveLocation = false,
    this.activeDriver,
    this.settings,
  });

  factory VehicleRecord.fromJson(Map<String, dynamic> json) {
    return VehicleRecord(
      id: toInt(json['id']),
      userId: toInt(json['user_id']),
      vendorId: toInt(json['created_by']),
      driverId: toInt(json['driver_id']),
      registrationNumber: toStringValue(json['v_registration_no']),
      name: toStringValue(json['v_name']),
      model: toStringValue(json['v_model']),
      typeName: toStringValue(json['v_type_name']),
      imei: toStringValue(json['imei']),
      deviceId: toInt(json['device_id']),
      vehicleIcon: toStringValue(json['vehicle_icon']),
      vehicleIconUrl: toStringValue(json['vehicle_icon_url']),
      deviceModel: toStringValue(json['device_model']),
      protocol: toStringValue(json['protocol']),
      port: toStringValue(json['port']),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      speed: toDouble(json['speed']),
      course: toDouble(json['course']),
      acc: toInt(json['acc']),
      battery: toInt(json['battery']),
      overspeedLimit: toInt(json['v_overspeed']),
      notificationEnabled: toInt(
        json['notification_enabled'] ?? json['v_notification'],
        fallback: 1,
      ),
      guardActive: toInt(json['guard_active']),
      guardLat: toDouble(json['guard_lat']),
      guardLng: toDouble(json['guard_lng']),
      geofenceLat: toDouble(json['geofence_lat']),
      geofenceLng: toDouble(json['geofence_lng']),
      geofenceRadius: toInt(json['geofence_radius']),
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
      engineRpm: toDouble(json['engine_rpm'] ?? json['rpm']),
      batteryVoltage: toDouble(json['battery_voltage']),
      dtcCodes: toStringValue(json['dtc_codes'] ?? json['dtc']),
      ecuMileage: toDouble(json['ecu_mileage']),
      currentOdometer: toDouble(json['current_odometer']),
      vOdometer: toDouble(json['v_odometer']),
      maintenanceIntervalDays: toInt(json['maintenance_interval_days']),
      maintenanceIntervalKm: toInt(json['maintenance_interval_km']),
      trackingUrl: toStringValue(json['tracking_url']),
      singleMapUrl: toStringValue(json['single_map_url']),
      googleTrackingUrl: toStringValue(json['google_tracking_url']),
      historyUrl: toStringValue(json['history_url']),
      multiMapUrl: toStringValue(json['multi_map_url']),
      legacyMultiMapUrl: toStringValue(json['legacy_multi_map_url']),
      createdAt: toStringValue(json['created_at']),
      hasLiveLocation: json['has_live_location'] != null
          ? toBoolFlag(json['has_live_location'])
          : (toDouble(json['latitude']) != 0 || toDouble(json['longitude']) != 0),
      activeDriver: json['active_driver'] is Map<String, dynamic>
          ? ActiveDriverModel.fromJson(json['active_driver'] as Map<String, dynamic>)
          : null,
      settings: json['settings'] is Map<String, dynamic>
          ? VehicleSettingsModel.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
    );
  }

  VehicleRecord copyWith({
    VehicleSettingsModel? settings,
    int? notificationEnabled,
    int? guardActive,
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
    double? engineRpm,
    double? batteryVoltage,
    String? dtcCodes,
    double? ecuMileage,
    double? currentOdometer,
    double? vOdometer,
    int? maintenanceIntervalDays,
    int? maintenanceIntervalKm,
    int? overspeedLimit,
    int? geofenceRadius,
    double? geofenceLat,
    double? geofenceLng,
    double? guardLat,
    double? guardLng,
    ActiveDriverModel? activeDriver,
  }) {
    return VehicleRecord(
      id: id,
      userId: userId,
      vendorId: vendorId,
      driverId: driverId,
      registrationNumber: registrationNumber,
      name: name,
      model: model,
      typeName: typeName,
      imei: imei,
      deviceId: deviceId,
      vehicleIcon: vehicleIcon,
      vehicleIconUrl: vehicleIconUrl,
      deviceModel: deviceModel,
      protocol: protocol,
      port: port,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      course: course,
      acc: acc,
      battery: battery,
      overspeedLimit: overspeedLimit ?? this.overspeedLimit,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      guardActive: guardActive ?? this.guardActive,
      guardLat: guardLat ?? this.guardLat,
      guardLng: guardLng ?? this.guardLng,
      geofenceLat: geofenceLat ?? this.geofenceLat,
      geofenceLng: geofenceLng ?? this.geofenceLng,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
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
      engineRpm: engineRpm ?? this.engineRpm,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      dtcCodes: dtcCodes ?? this.dtcCodes,
      ecuMileage: ecuMileage ?? this.ecuMileage,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      vOdometer: vOdometer ?? this.vOdometer,
      maintenanceIntervalDays:
          maintenanceIntervalDays ?? this.maintenanceIntervalDays,
      maintenanceIntervalKm:
          maintenanceIntervalKm ?? this.maintenanceIntervalKm,
      trackingUrl: trackingUrl,
      singleMapUrl: singleMapUrl,
      googleTrackingUrl: googleTrackingUrl,
      historyUrl: historyUrl,
      multiMapUrl: multiMapUrl,
      legacyMultiMapUrl: legacyMultiMapUrl,
      createdAt: createdAt,
      hasLiveLocation: hasLiveLocation,
      activeDriver: activeDriver ?? this.activeDriver,
      settings: settings ?? this.settings,
    );
  }

  bool get engineOn => acc > 0;

  bool get isMoving => engineOn && speed > 5;

  bool get isIdle => engineOn && speed <= 5;

  bool get isStopped => !engineOn;

  bool get isImmobilized =>
      immobilizerState == 'locked' || immobilizerState == 'pending_lock';

  bool get isImmobilizerBusy =>
      immobilizerState == 'pending_lock' || immobilizerState == 'pending_restore';

  String get statusLabel {
    if (isStopped) {
      return 'Stopped';
    }
    if (isMoving) {
      return 'Moving';
    }
    return 'Idle';
  }

  String get displayName => registrationNumber.isNotEmpty ? registrationNumber : name;

  String get primaryMapUrl =>
      trackingUrl.isNotEmpty ? trackingUrl : singleMapUrl;
}
