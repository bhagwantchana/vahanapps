import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// The address shown under a vehicle. Users were seeing raw "30.8832, 75.8351"
/// instead of a street, because the phone resolved every address itself into a
/// RAM-only cache. The server now sends `cached_address` with each row.
///
/// The part that needs pinning is what happens to that address when the
/// vehicle MOVES: LiveAddressText seeds a cache shared by every widget on the
/// same coordinate, so an address that outlives its position does not just
/// mislabel one card — it gets filed under the new coordinate and handed to
/// other vehicles standing there too.
void main() {
  VehicleRecord at(double lat, double lng, {String address = '', int ts = 0}) =>
      VehicleRecord(
        id: 1,
        latitude: lat,
        longitude: lng,
        cachedAddress: address,
        tsEpochMs: ts == 0 ? DateTime.now().millisecondsSinceEpoch : ts,
        hasLiveLocation: true,
      );

  group('the server address arrives on the record', () {
    test('cached_address is read off the payload', () {
      final v = VehicleRecord.fromJson(<String, dynamic>{
        'id': 1,
        'latitude': '30.883438',
        'longitude': '75.780587',
        'cached_address': 'Rajguru Nagar, Ludhiana, Punjab, India',
      });
      expect(v.cachedAddress, 'Rajguru Nagar, Ludhiana, Punjab, India');
    });

    test('a payload without the field is empty, never null', () {
      final v = VehicleRecord.fromJson(<String, dynamic>{'id': 1});
      expect(v.cachedAddress, '');
    });
  });

  group('an address must not outlive the position it describes', () {
    test('kept while the vehicle stays inside the ~110 m bucket', () {
      final parked = at(30.883438, 75.780587, address: 'Rajguru Nagar, Ludhiana');
      // Both round to 30.883 / 75.781 — a few metres, same street, same bucket.
      // (Deliberately not 30.8835: that rounds UP to 30.884 and so is a
      // different bucket despite being metres away. Bucketing by rounding
      // always has that boundary; the server's _coordKey has it too.)
      final nudged = at(30.883460, 75.780600,
          ts: DateTime.now().millisecondsSinceEpoch + 5000);

      final merged = parked.mergeLiveFixFrom(nudged);

      expect(merged.cachedAddress, 'Rajguru Nagar, Ludhiana',
          reason: 'dropping it here would flash raw lat/lng on every fix');
      expect(merged.latitude, nudged.latitude);
    });

    test('DROPPED once the vehicle leaves the bucket', () {
      final wasHere = at(30.883438, 75.780587, address: 'Rajguru Nagar, Ludhiana');
      // ~1 km away — a different street entirely.
      final nowThere = at(30.898000, 75.793000,
          ts: DateTime.now().millisecondsSinceEpoch + 5000);

      final merged = wasHere.mergeLiveFixFrom(nowThere);

      expect(merged.cachedAddress, '',
          reason: 'carrying it over files the OLD street under the NEW '
              'coordinate in a cache shared with every other vehicle there');
      expect(merged.latitude, nowThere.latitude);
    });

    test('a rejected (older) fix changes neither position nor address', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final current = at(30.883438, 75.780587,
          address: 'Rajguru Nagar, Ludhiana', ts: now);
      final stale = at(30.898000, 75.793000, ts: now - 60000);

      final merged = current.mergeLiveFixFrom(stale);

      expect(merged.cachedAddress, 'Rajguru Nagar, Ludhiana');
      expect(merged.latitude, current.latitude);
    });

    test('having no address to begin with stays empty, never null', () {
      final v = at(30.883438, 75.780587);
      final moved = at(30.898000, 75.793000,
          ts: DateTime.now().millisecondsSinceEpoch + 5000);
      expect(v.mergeLiveFixFrom(moved).cachedAddress, '');
    });
  });

  group('a live fix can never move the marker backwards in time', () {
    test('missing epochs fall back to the wall-clock string, not blind accept', () {
      // The "vehicle piche chala janda" case: a buffered fix delivered late,
      // with no trustworthy epoch (old server / distrusted device clock).
      // 'YYYY-MM-DD HH:mm:ss' compares correctly as text.
      final current = VehicleRecord(
        id: 1, latitude: 30.884, longitude: 75.828,
        createdAt: '2026-08-04 08:58:55', hasLiveLocation: true,
      );
      final buffered = VehicleRecord(
        id: 1, latitude: 30.883, longitude: 75.833,
        createdAt: '2026-08-04 08:58:45', hasLiveLocation: true,
      );
      expect(current.acceptsLiveFixFrom(buffered), isFalse,
          reason: 'an older wall-clock fix must not win');

      final newer = VehicleRecord(
        id: 1, latitude: 30.885, longitude: 75.826,
        createdAt: '2026-08-04 08:59:05', hasLiveLocation: true,
      );
      expect(current.acceptsLiveFixFrom(newer), isTrue);
    });

    test('with no timestamps at all, a live fix is still accepted', () {
      // A brand-new record with nothing to compare must not freeze the map.
      final blank = VehicleRecord(id: 1);
      final incoming = VehicleRecord(
          id: 1, latitude: 30.9, longitude: 75.8, hasLiveLocation: true);
      expect(blank.acceptsLiveFixFrom(incoming), isTrue);
    });
  });

  group('bucket comparison matches the server and the widget', () {
    test('agrees with 3-decimal rounding, which is what _coordKey uses', () {
      // Same 3-decimal bucket (30.883, 75.781) despite differing 4th decimals.
      final a = at(30.883438, 75.780587, address: 'Same Street');
      final b = at(30.883100, 75.780900,
          ts: DateTime.now().millisecondsSinceEpoch + 1000);
      expect(a.mergeLiveFixFrom(b).cachedAddress, 'Same Street');

      // Crossing into 30.884 is a different bucket, so the address goes.
      final c = at(30.884600, 75.780587,
          ts: DateTime.now().millisecondsSinceEpoch + 2000);
      expect(a.mergeLiveFixFrom(c).cachedAddress, '');
    });
  });
}
