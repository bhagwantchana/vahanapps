import 'dart:io';

import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/services/geofence_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';

/// Evaluates user-defined geofences against the current vehicle snapshot
/// and fires a local notification each time a vehicle crosses a zone
/// boundary. Designed to be cheap to call — invoke it on every dashboard /
/// vehicle-list refresh.
///
/// State is persisted per (zone × vehicle) so transitions survive app
/// restarts. First sighting inside or outside a zone is a no-op (we only
/// alert on a *change*).
class GeofenceMonitorService {
  GeofenceMonitorService._();
  static final GeofenceMonitorService instance = GeofenceMonitorService._();

  static const String _channelId = 'fleet_monitor_geofence_local_v1';
  static const String _channelName = 'VahanConnect Local Geofence';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Distance _distance = const Distance();
  bool _channelReady = false;

  Future<void> _ensureChannel() async {
    if (_channelReady || !Platform.isAndroid) {
      _channelReady = true;
      return;
    }
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Alerts when your vehicles enter or leave saved zones',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _channelReady = true;
  }

  /// Walks every enabled zone × every vehicle with live location and emits
  /// a notification on each entry/exit transition. Failures are swallowed —
  /// geofencing should never block the refresh loop.
  Future<void> evaluate({
    required List<VehicleRecord> vehicles,
    required String entryLabel,
    required String exitLabel,
  }) async {
    try {
      final zones = await GeofenceStorage.loadAll();
      if (zones.isEmpty) return;
      await _ensureChannel();

      for (final zone in zones) {
        if (!zone.enabled) continue;
        final zoneCenter = LatLng(zone.latitude, zone.longitude);

        for (final vehicle in vehicles) {
          if (!vehicle.hasLiveLocation) continue;
          if (vehicle.latitude == 0 && vehicle.longitude == 0) continue;

          final vehiclePoint = LatLng(vehicle.latitude, vehicle.longitude);
          final meters = _distance.as(LengthUnit.Meter, zoneCenter, vehiclePoint);
          final inside = meters <= zone.radiusMeters;

          final previous = await GeofenceStorage.getInsideState(zone.id, vehicle.id);
          if (previous == null) {
            // First observation — record state but don't alert. Avoids
            // notification spam on app first-launch with vehicles already
            // sitting inside saved zones.
            await GeofenceStorage.setInsideState(zone.id, vehicle.id, inside);
            continue;
          }

          if (previous == inside) continue;

          await GeofenceStorage.setInsideState(zone.id, vehicle.id, inside);
          await _fireAlert(
            zoneName: zone.name,
            vehicleLabel: vehicle.displayName,
            isEntry: inside,
            entryLabel: entryLabel,
            exitLabel: exitLabel,
          );
        }
      }
    } catch (_) {
      // Silent: geofence evaluation should never crash the refresh tick.
    }
  }

  Future<void> _fireAlert({
    required String zoneName,
    required String vehicleLabel,
    required bool isEntry,
    required String entryLabel,
    required String exitLabel,
  }) async {
    final verb = isEntry ? entryLabel : exitLabel;
    final body = '$vehicleLabel $verb $zoneName';
    final id = (zoneName + vehicleLabel + (isEntry ? 'in' : 'out')).hashCode;

    if (Platform.isAndroid) {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Alerts when your vehicles enter or leave saved zones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      await _plugin.show(
        id: id,
        title: zoneName,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
      return;
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: id,
      title: zoneName,
      body: body,
      notificationDetails: const NotificationDetails(iOS: iosDetails),
    );
  }
}
