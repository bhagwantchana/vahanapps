/// A user-defined circular geofence zone, stored locally on the device.
///
/// We don't sync these to the server (that's a Phase 2 feature). Each zone
/// is keyed by a UUID-ish `id` so we can persist per-vehicle entry/exit
/// state without it colliding when zones are renamed.
class GeofenceZone {
  const GeofenceZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.enabled = true,
    this.createdAt = '',
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool enabled;
  final String createdAt;

  GeofenceZone copyWith({
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? enabled,
  }) {
    return GeofenceZone(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        'enabled': enabled,
        'created_at': createdAt,
      };

  factory GeofenceZone.fromJson(Map<String, dynamic> json) {
    return GeofenceZone(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      latitude: (json['lat'] is num) ? (json['lat'] as num).toDouble() : 0.0,
      longitude: (json['lng'] is num) ? (json['lng'] as num).toDouble() : 0.0,
      radiusMeters: (json['radius'] is num) ? (json['radius'] as num).toInt() : 200,
      enabled: json['enabled'] == true || json['enabled'] == 1,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
