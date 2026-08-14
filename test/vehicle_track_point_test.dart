import 'package:fleet_monitor/models/vehicle_track_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trip replay animates whatever tripHistory returns, in array order.
/// These rows are copied from a REAL response (PB08DS1117, 2026-08-04) —
/// PHP serialises every DB column as a string, and the endpoint now also
/// sends a `ts` epoch-ms column for the server-side despike. The model
/// must read the string shape and ignore the extra field, or the replay
/// screen renders an empty track with no error.
void main() {
  group('tripHistory rows parse into track points', () {
    test('the real wire shape: strings for every field, plus ts', () {
      final p = VehicleTrackPoint.fromJson(<String, dynamic>{
        'latitude': '31.206017',
        'longitude': '75.666286',
        'speed': '0',
        'course': '302',
        'acc': '1',
        'battery': '0',
        'created_at': '2026-08-04 06:05:40',
        'ts': '1785803737000',
      });
      expect(p.latitude, closeTo(31.206017, 1e-9));
      expect(p.longitude, closeTo(75.666286, 1e-9));
      expect(p.speed, 0);
      expect(p.course, 302);
      expect(p.createdAt, '2026-08-04 06:05:40');
      expect(p.hasPoint, isTrue);
    });

    test('numeric values (a future JSON-typed server) parse the same', () {
      final p = VehicleTrackPoint.fromJson(<String, dynamic>{
        'latitude': 31.206017,
        'longitude': 75.666286,
        'speed': 42,
        'ts': 1785803737000,
      });
      expect(p.latitude, closeTo(31.206017, 1e-9));
      expect(p.speed, 42);
      expect(p.hasPoint, isTrue);
    });

    test('a 0,0 row is not a point — the screen must skip it', () {
      final p = VehicleTrackPoint.fromJson(<String, dynamic>{
        'latitude': '0.000000',
        'longitude': '0.000000',
        'created_at': '2026-08-04 06:05:40',
      });
      expect(p.hasPoint, isFalse);
    });

    test('missing fields default instead of throwing', () {
      final p = VehicleTrackPoint.fromJson(<String, dynamic>{});
      expect(p.hasPoint, isFalse);
      expect(p.createdAt, '');
    });
  });
}
