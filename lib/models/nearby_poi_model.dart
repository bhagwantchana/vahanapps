/// One row from api/nearbyPois — a world POI (petrol pump, EV charger,
/// toll booth, speed camera, traffic light) near a vehicle, with the
/// server-computed distance from the query point.
class NearbyPoi {
  final String poiType;
  final double lat;
  final double lng;
  final String name;
  final String brand;
  final String meta;
  final double distanceKm;

  const NearbyPoi({
    this.poiType = '',
    this.lat = 0,
    this.lng = 0,
    this.name = '',
    this.brand = '',
    this.meta = '',
    this.distanceKm = 0,
  });

  factory NearbyPoi.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;
    return NearbyPoi(
      poiType: (json['poi_type'] ?? '').toString(),
      lat: toDouble(json['lat']),
      lng: toDouble(json['lng']),
      name: (json['name'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      meta: (json['meta'] ?? '').toString(),
      distanceKm: toDouble(json['distance_km']),
    );
  }

  /// Display label — name, else brand, else a readable type.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (brand.trim().isNotEmpty) return brand.trim();
    switch (poiType) {
      case 'fuel':
        return 'Petrol Pump';
      case 'ev_charging':
        return 'EV Charging Station';
      case 'toll_booth':
        return 'Toll Plaza';
      case 'speed_camera':
        return 'Speed Camera';
      case 'traffic_signals':
        return 'Traffic Light';
      default:
        return 'Point of Interest';
    }
  }

  bool get supportsCng => meta.contains('cng=1');
}
