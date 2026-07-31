import 'dart:convert';

import 'package:fleet_monitor/constant/preferences.dart';

/// Last-good API responses, kept so a dropped connection shows the fleet as it
/// last stood instead of an error page.
///
/// These devices are watched from moving vehicles and from schools on patchy
/// rural links, so a request failing is routine rather than exceptional. The
/// app used to answer that with "Connection failed" and an empty list — which
/// reads as "the tracking is broken", not "your phone lost signal for a moment".
///
/// It stores the RAW response body, not a serialized model. VehicleRecord has
/// no toJson, and hand-writing one for sixty fields would drift out of step
/// with fromJson the first time a field is added. Replaying the same bytes
/// through the same parser cannot drift.
class OfflineCache {
  const OfflineCache._();

  static const String _vehicleListKey = 'offline_vehicle_list_v1';
  static const String _vehicleTrackPrefix = 'offline_vehicle_track_v1_';
  static const String _stampSuffix = '_at';

  /// Older than this and we would rather show nothing than a position from
  /// another day. Long enough to cover an overnight app restart with no signal.
  static const Duration maxAge = Duration(hours: 12);

  static Future<void> _write(String key, Map<String, dynamic> body) async {
    try {
      await LocalStorage.setValue(key, jsonEncode(body));
      await LocalStorage.setValue(
        '$key$_stampSuffix',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Caching is best-effort: never let it break a successful fetch.
    }
  }

  static Future<Map<String, dynamic>?> _read(String key) async {
    try {
      final raw = await LocalStorage.readValue(key);
      if (raw == null || raw.isEmpty) return null;
      final stamp =
          int.tryParse(await LocalStorage.readValue('$key$_stampSuffix') ?? '');
      if (stamp == null) return null;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(stamp));
      if (age.isNegative || age > maxAge) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Age of a cached entry, for telling the user how stale the screen is.
  static Future<Duration?> _ageOf(String key) async {
    final stamp =
        int.tryParse(await LocalStorage.readValue('$key$_stampSuffix') ?? '');
    if (stamp == null) return null;
    final age =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(stamp));
    return age.isNegative ? Duration.zero : age;
  }

  static Future<void> saveVehicleList(Map<String, dynamic> body) =>
      _write(_vehicleListKey, body);

  static Future<Map<String, dynamic>?> readVehicleList() =>
      _read(_vehicleListKey);

  static Future<Duration?> vehicleListAge() => _ageOf(_vehicleListKey);

  static Future<void> saveVehicleTrack(String imei, Map<String, dynamic> body) =>
      _write('$_vehicleTrackPrefix$imei', body);

  static Future<Map<String, dynamic>?> readVehicleTrack(String imei) =>
      _read('$_vehicleTrackPrefix$imei');

  /// Drop everything on logout — the next user must never see the previous
  /// user's vehicles, even for the moment before their own list loads.
  static Future<void> clear() async {
    await LocalStorage.clearValue(_vehicleListKey);
    await LocalStorage.clearValue('$_vehicleListKey$_stampSuffix');
  }
}
