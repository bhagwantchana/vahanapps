import 'package:fleet_monitor/models/active_driver_model.dart';
import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/vehicle_settings_model.dart';

class VehicleRecord {
  /// How old a fix may be before the app stops claiming to know what the
  /// vehicle is doing. ONE threshold for every map, list and counter — see
  /// [statusKey], which is the only status rule any surface should apply.
  ///
  /// Several widgets used to carry their own 30-minute window while the
  /// tracking server calls a device offline after 3 (GPS_OFFLINE_AFTER_SECONDS),
  /// leaving a 27-minute gap in which the map painted a confident colour from a
  /// fix that was minutes old. Real GPS gaps mid-drive run 3-9 minutes on this
  /// fleet, so the classic failure was: a bus halts at a school gate (correctly
  /// orange, engine idling), pulls away, its signal drops — and the map kept
  /// insisting "idle" for the whole gap while the bus was driving. Grey is the
  /// honest answer there.
  ///
  /// Floor is set by the server's parked-vehicle write interval
  /// (GPS_STATIONARY_SAVE_INTERVAL_SECONDS, 5 min): anything shorter would grey
  /// out every legitimately parked vehicle.
  static const int staleFixMs = 8 * 60 * 1000;

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
  /// GSM signal strength reported by the device (0-4 on GT06 / PT06).
  /// 0 = no signal, 4 = excellent. Surfaced as bars on the single-vehicle
  /// detail screen so operators can correlate "no live update" with weak
  /// cellular instead of guessing.
  final int gsmSignal;
  /// GPS satellites locked at last fix. Higher is better (>= 5 means a
  /// solid 3D fix). Shown next to GPS LIVE/FIX badge.
  final int satellites;
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
  /// Last-fix time as epoch milliseconds (`ts` on the wire — SSE pushes and
  /// the vehicle APIs both carry it). Timezone-proof, unlike [createdAt],
  /// which is a zone-less server-local string: the webmaps hit exactly this
  /// (every vehicle flagged offline when the string parsed browser-local)
  /// and gate on the epoch instead. 0 = not provided.
  final int tsEpochMs;
  /// Device/plan subscription expiry (tbl_device.expiry_date). Drives the
  /// red "X days left" / "Expired" badge on the vehicle cards.
  final String expiryDate;
  final bool hasLiveLocation;

  /// Voice monitor, carried on every list row so the map's vehicle card can
  /// offer the action without a second request. [simMsisdn] is '' unless the
  /// tracker is flagged audio-capable AND a real number is on file, so
  /// [canCallVehicle] is the only check a caller needs.
  final int isCallDevice;
  final String simMsisdn;

  /// Street address the SERVER already had for this coordinate, sent with the
  /// row itself. '' when the server has nothing cached yet.
  ///
  /// Before this existed the phone resolved every vehicle's address on its own,
  /// into a cache that only lived in RAM — so every cold start showed raw
  /// "30.8832, 75.8351" until each lookup returned. Seeding [LiveAddressText]
  /// with this means the address is on screen in the first frame.
  final String cachedAddress;
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
    this.gsmSignal = 0,
    this.satellites = 0,
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
    this.tsEpochMs = 0,
    this.expiryDate = '',
    this.hasLiveLocation = false,
    this.isCallDevice = 0,
    this.simMsisdn = '',
    this.cachedAddress = '',
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
      gsmSignal: toInt(json['gsm_signal']),
      satellites: toInt(json['satellites']),
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
      tsEpochMs: toInt(json['ts']),
      expiryDate: toStringValue(json['expiry_date']),
      isCallDevice: toInt(json['is_call_device']),
      simMsisdn: toStringValue(json['sim_msisdn']),
      cachedAddress: toStringValue(json['cached_address']),
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
    // Live-feed fields — SSE pushes these after every device packet so the
    // map / list refresh without polling. Older copyWith signatures
    // didn't accept these, so SSE updates silently kept the stale values.
    double? latitude,
    double? longitude,
    double? speed,
    double? course,
    int? acc,
    int? battery,
    int? gsmSignal,
    int? satellites,
    String? createdAt,
    int? tsEpochMs,
    bool? hasLiveLocation,
    String? cachedAddress,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      course: course ?? this.course,
      acc: acc ?? this.acc,
      battery: battery ?? this.battery,
      gsmSignal: gsmSignal ?? this.gsmSignal,
      satellites: satellites ?? this.satellites,
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
      createdAt: createdAt ?? this.createdAt,
      tsEpochMs: tsEpochMs ?? this.tsEpochMs,
      expiryDate: expiryDate,
      isCallDevice: isCallDevice,
      simMsisdn: simMsisdn,
      cachedAddress: cachedAddress ?? this.cachedAddress,
      hasLiveLocation: hasLiveLocation ?? this.hasLiveLocation,
      activeDriver: activeDriver ?? this.activeDriver,
      settings: settings ?? this.settings,
    );
  }

  /// Both conditions for offering voice monitoring: the tracker has a
  /// microphone, and we hold a number the server has already validated.
  bool get canCallVehicle => isCallDevice == 1 && simMsisdn.trim().isNotEmpty;

  bool get engineOn => acc > 0;

  /// The last fix is older than [staleFixMs], so nothing derived from it is
  /// worth painting as a live status.
  bool get isLiveStale {
    final ts = tsEpochMs;
    return ts > 0 && DateTime.now().millisecondsSinceEpoch - ts > staleFixMs;
  }

  /// Real road speed means the vehicle is moving, whatever the ACC bit says.
  /// OBD and PT06 units flicker or stick that bit, and a bus doing 60 km/h
  /// rendering as a red "Stopped" marker is the worst thing the map can do.
  ///
  /// These three are STALE-AWARE: all three are false once the fix ages past
  /// [staleFixMs], because "moving" and "stopped" are both claims about right
  /// now. That makes them safe defaults but means they are NOT an exhaustive
  /// set — never bucket a vehicle with `if (isMoving) … else if (isIdle) …
  /// else stopped`, because a stale vehicle silently lands in the last branch.
  /// Use [statusKey], which is exhaustive and has the offline case.
  bool get isMoving => !isLiveStale && speed > 5;

  bool get isIdle => !isLiveStale && !isMoving && engineOn;

  bool get isStopped => !isLiveStale && !isMoving && !engineOn;

  bool acceptsLiveFixFrom(VehicleRecord incoming) {
    if (incoming.tsEpochMs <= 0 || tsEpochMs <= 0) {
      // No epoch on one side (old server / distrusted device clock). Before
      // accepting blindly, try the server wall-clock string: 'YYYY-MM-DD
      // HH:mm:ss' compares correctly as text, and an out-of-order buffered
      // fix accepted here is a marker visibly stepping BACKWARDS on both
      // maps — the exact "vehicle piche chala janda" the owner reported.
      if (incoming.createdAt.isNotEmpty && createdAt.isNotEmpty) {
        return incoming.createdAt.compareTo(createdAt) >= 0;
      }
      return incoming.hasLiveLocation;
    }
    return incoming.tsEpochMs >= tsEpochMs;
  }

  VehicleRecord withLiveFieldsFrom(VehicleRecord source) {
    return copyWith(
      latitude: source.latitude,
      longitude: source.longitude,
      speed: source.speed,
      course: source.course,
      acc: source.acc,
      battery: source.battery,
      gsmSignal: source.gsmSignal,
      satellites: source.satellites > 0 ? source.satellites : satellites,
      createdAt: source.createdAt.isNotEmpty ? source.createdAt : createdAt,
      tsEpochMs: source.tsEpochMs > 0 ? source.tsEpochMs : tsEpochMs,
      hasLiveLocation: source.hasLiveLocation || hasLiveLocation,
      // A live fix carries no address of its own. Keep the server's while the
      // vehicle is still inside the same ~110 m bucket — that is genuinely the
      // same street, and dropping it would flash raw coordinates on every fix.
      //
      // Once it leaves the bucket the address is simply wrong, and it must NOT
      // travel with the record: LiveAddressText seeds a cache shared by every
      // widget on that coordinate, so carrying it over would file the old
      // street under the new position and hand it to other vehicles too.
      // Cleared here, so the widget falls through to a real lookup.
      cachedAddress: _sameAddressBucket(source) ? cachedAddress : '',
    );
  }

  /// True when [source]'s position rounds into the same ~110 m bucket as this
  /// one — the same granularity the server keys tbl_address_cache by and the
  /// widget keys its in-memory cache by, so all three agree on what "the same
  /// place" means.
  bool _sameAddressBucket(VehicleRecord source) {
    return source.latitude.toStringAsFixed(3) == latitude.toStringAsFixed(3) &&
        source.longitude.toStringAsFixed(3) == longitude.toStringAsFixed(3);
  }

  VehicleRecord mergeLiveFixFrom(VehicleRecord incoming) {
    if (!acceptsLiveFixFrom(incoming)) {
      return this;
    }
    return withLiveFieldsFrom(incoming);
  }

  // ── Device/plan expiry → red badge on the vehicle cards ──────────────────
  /// Parsed expiry date, or null when the device has no valid expiry set.
  DateTime? get expiryDateValue {
    final raw = expiryDate.trim();
    if (raw.isEmpty || raw.startsWith('0000')) {
      return null;
    }
    return DateTime.tryParse(raw.contains('T') ? raw : raw.replaceFirst(' ', 'T'));
  }

  /// Whole days from today until the plan expires. Negative = already expired,
  /// 0 = expires today, null = no expiry date on the device.
  int? get daysToExpiry {
    final exp = expiryDateValue;
    if (exp == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(exp.year, exp.month, exp.day);
    return expDay.difference(today).inDays;
  }

  bool get isExpired {
    final d = daysToExpiry;
    return d != null && d < 0;
  }

  /// Within the 7-day warning window (0..7 days left, not yet expired).
  bool get isExpiringSoon {
    final d = daysToExpiry;
    return d != null && d >= 0 && d <= 7;
  }

  /// Show the red expiry badge when expiring soon OR already expired.
  bool get showExpiryBadge => isExpired || isExpiringSoon;

  /// Short badge text: "Expired" / "Expires today" / "N days left".
  String get expiryBadgeLabel {
    final d = daysToExpiry;
    if (d == null) {
      return '';
    }
    if (d < 0) {
      return 'Expired';
    }
    if (d == 0) {
      return 'Expires today';
    }
    if (d == 1) {
      return '1 day left';
    }
    return '$d days left';
  }

  bool get isImmobilized =>
      immobilizerState == 'locked' || immobilizerState == 'pending_lock';

  // Time-bound the pending state so a stuck pending_lock / pending_restore
  // doesn't permanently disable the Start/Stop button. The tracking server's
  // optimistic-ACK watchdog flips pending states to their final form within
  // ~60s when the device is alive; this 90s window is the safety net for
  // when the watchdog is slow or the device's clock skews the timestamp.
  bool get isImmobilizerBusy {
    if (immobilizerState != 'pending_lock' &&
        immobilizerState != 'pending_restore') {
      return false;
    }
    if (immobilizerUpdatedAt.isEmpty) {
      return false;
    }
    final updatedAt = DateTime.tryParse(
      immobilizerUpdatedAt.contains('T')
          ? immobilizerUpdatedAt
          : immobilizerUpdatedAt.replaceFirst(' ', 'T'),
    );
    if (updatedAt == null) {
      return false;
    }
    return DateTime.now().difference(updatedAt).inSeconds < 90;
  }

  String get displayName => registrationNumber.isNotEmpty ? registrationNumber : name;

  String get primaryMapUrl =>
      trackingUrl.isNotEmpty ? trackingUrl : singleMapUrl;

  /// "Just now" / "5m ago" / "2h ago", derived from [tsEpochMs].
  ///
  /// Never render `createdAt` directly. That is the server's own wall clock as
  /// a plain string, and the box runs on UTC — so a phone in IST showed a fix
  /// as 5h30 old the moment it arrived ("Updated: 02:27" at 07:57 local). The
  /// epoch in [tsEpochMs] is unambiguous, and a relative label sidesteps the
  /// question of whose timezone to print in.
  String get lastUpdateLabel {
    final ts = tsEpochMs;
    if (ts <= 0) return '—';
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// THE status rule. `offline` | `stopped` | `moving` | `idle`, in that
  /// precedence, exactly one of which always holds.
  ///
  /// Every map, card, counter and filter must route through this. When widgets
  /// each carried their own copy they drifted apart: three of them kept a
  /// 30-minute offline window, so a vehicle silent for ten minutes fell past
  /// their gate, found isStopped and isMoving both false, and landed on the
  /// `idle` fallthrough — the map painted it orange, claiming an idling engine
  /// on a device that had not spoken in ten minutes.
  String get statusKey {
    if (isLiveStale) {
      return 'offline';
    }
    if (isStopped) return 'stopped';
    if (isMoving) return 'moving';
    return 'idle';
  }

  /// Human label for [statusKey] — Offline / Stopped / Moving / Idle.
  String get statusLabel {
    switch (statusKey) {
      case 'offline':
        return 'Offline';
      case 'stopped':
        return 'Stopped';
      case 'moving':
        return 'Moving';
      default:
        return 'Idle';
    }
  }

  /// Status-coloured variant of [vehicleIconUrl]
  /// (`…/status/<stem>_<status>.png`) — moving green / idle orange / stopped
  /// red / offline grey, the same coloured icons the map uses. Falls back to
  /// the plain icon URL if a variant is missing.
  String get statusIconUrl {
    final url = vehicleIconUrl.trim();
    final slash = url.lastIndexOf('/');
    if (slash < 0) return url;
    final dir = url.substring(0, slash);
    final file = url.substring(slash + 1);
    final dot = file.lastIndexOf('.');
    final stem = dot > 0 ? file.substring(0, dot) : file;
    return '$dir/status/${stem}_$statusKey.png';
  }
}
