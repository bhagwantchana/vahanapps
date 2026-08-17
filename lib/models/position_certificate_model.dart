/// Where one vehicle was at one moment, with the honesty about precision
/// that makes it usable as evidence.
///
/// A GPS log is not continuous — trackers report every few seconds while
/// moving and go quiet when parked — so "the position at 14:22" is really
/// "the nearest recorded fix, 40 seconds before". [accuracyNote] says that
/// in words, and it is the line that has to survive being read aloud in an
/// insurance or police dispute.
class PositionCertificate {
  PositionCertificate({
    required this.vehicleLabel,
    required this.imei,
    required this.requestedTime,
    required this.fixTime,
    required this.gapSeconds,
    required this.accuracyNote,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.address,
    required this.mapUrl,
    required this.generatedAt,
  });

  final String vehicleLabel;
  final String imei;
  final String requestedTime;
  final String fixTime;
  final int gapSeconds;
  final String accuracyNote;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final String address;
  final String mapUrl;
  final String generatedAt;

  bool get wasMoving => speedKmh > 1;

  static double _asDouble(dynamic v) =>
      v == null ? 0 : double.tryParse(v.toString()) ?? 0;

  factory PositionCertificate.fromJson(Map<String, dynamic> json) {
    final d = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PositionCertificate(
      vehicleLabel: (d['vehicle_label'] ?? '').toString(),
      imei: (d['imei'] ?? '').toString(),
      requestedTime: (d['requested_time'] ?? '').toString(),
      fixTime: (d['fix_time'] ?? '').toString(),
      gapSeconds: int.tryParse((d['gap_seconds'] ?? 0).toString()) ?? 0,
      accuracyNote: (d['accuracy_note'] ?? '').toString(),
      latitude: _asDouble(d['latitude']),
      longitude: _asDouble(d['longitude']),
      speedKmh: _asDouble(d['speed_kmh']),
      address: (d['address'] ?? '').toString(),
      mapUrl: (d['map_url'] ?? '').toString(),
      generatedAt: (d['generated_at'] ?? '').toString(),
    );
  }

  /// Plain-text form for sharing into WhatsApp, email or a claim form —
  /// deliberately self-contained, including the accuracy note, so it cannot
  /// be forwarded as a stronger claim than the data supports.
  String toShareText() {
    final buffer = StringBuffer()
      ..writeln('VEHICLE POSITION RECORD')
      ..writeln('')
      ..writeln('Vehicle: $vehicleLabel')
      ..writeln('Device IMEI: $imei')
      ..writeln('')
      ..writeln('Requested time: $requestedTime')
      ..writeln('Recorded at:    $fixTime')
      ..writeln(accuracyNote)
      ..writeln('')
      ..writeln('Location: ${address.isEmpty ? "—" : address}')
      ..writeln('Coordinates: $latitude, $longitude')
      ..writeln(
          'Speed: ${speedKmh.toStringAsFixed(0)} km/h${wasMoving ? " (moving)" : " (stationary)"}')
      ..writeln('Map: $mapUrl')
      ..writeln('')
      ..writeln('Generated $generatedAt by VahanConnect');
    return buffer.toString();
  }
}
