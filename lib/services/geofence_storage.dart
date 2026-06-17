import 'dart:convert';

import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/geofence_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's geofence list as a single JSON blob in
/// SharedPreferences. Small N (typically < 50 zones) — no need for sqflite.
class GeofenceStorage {
  static Future<List<GeofenceZone>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PreferencesKey.geofencesJson);
    if (raw == null || raw.isEmpty) return <GeofenceZone>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GeofenceZone>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(GeofenceZone.fromJson)
          .toList();
    } catch (_) {
      return <GeofenceZone>[];
    }
  }

  static Future<void> saveAll(List<GeofenceZone> zones) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(zones.map((z) => z.toJson()).toList());
    await prefs.setString(PreferencesKey.geofencesJson, encoded);
  }

  static Future<void> upsert(GeofenceZone zone) async {
    final list = await loadAll();
    final idx = list.indexWhere((z) => z.id == zone.id);
    if (idx >= 0) {
      list[idx] = zone;
    } else {
      list.add(zone);
    }
    await saveAll(list);
  }

  static Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((z) => z.id == id);
    await saveAll(list);
    // Also wipe any cached entry/exit state for this zone — otherwise a
    // re-created zone with the same generated ID would inherit stale state.
    final prefs = await SharedPreferences.getInstance();
    final stateKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('${PreferencesKey.geofenceStatePrefix}${id}_'))
        .toList();
    for (final k in stateKeys) {
      await prefs.remove(k);
    }
  }

  /// Last-known "is vehicle inside this zone" cached value, used to detect
  /// entry/exit transitions on the next refresh tick.
  static Future<bool?> getInsideState(String zoneId, int vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${PreferencesKey.geofenceStatePrefix}${zoneId}_$vehicleId';
    if (!prefs.containsKey(key)) return null;
    return prefs.getBool(key);
  }

  static Future<void> setInsideState(
      String zoneId, int vehicleId, bool inside) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${PreferencesKey.geofenceStatePrefix}${zoneId}_$vehicleId';
    await prefs.setBool(key, inside);
  }
}
