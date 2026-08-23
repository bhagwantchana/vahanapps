import 'package:fleet_monitor/widgets/single_vehicle_track.dart'
    show SpeedPoint, newestContinuousRun;
import 'package:fleet_monitor/widgets/native_vehicle_map.dart'
    show MapStopPin;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('newestContinuousRun (SpeedPoint pipeline)', () {
    SpeedPoint sp(double lat, double lng, double kmh) =>
        SpeedPoint(LatLng(lat, lng), kmh);

    test('a continuous drive passes through untouched, speeds intact', () {
      // ~110 m per 0.001° of latitude — every step well under the 500 m break.
      final trail = <SpeedPoint>[
        for (var i = 0; i < 6; i++) sp(30.900 + i * 0.001, 75.850, 20.0 + i),
      ];
      final out = newestContinuousRun(trail);
      expect(out.length, 6);
      expect(out.first.kmh, 20.0);
      expect(out.last.kmh, 25.0);
    });

    test('a >500 m gap keeps only the newest continuous run', () {
      final out = newestContinuousRun(<SpeedPoint>[
        sp(30.900, 75.850, 30),
        sp(30.901, 75.850, 32),
        // ~1.1 km jump — an ignition-off pause or the history/live seam.
        sp(30.911, 75.850, 40),
        sp(30.912, 75.850, 42),
      ]);
      expect(out.length, 2);
      expect(out.first.kmh, 40);
      expect(out.last.kmh, 42);
    });

    test('the newest gap wins when there are several', () {
      final out = newestContinuousRun(<SpeedPoint>[
        sp(30.900, 75.850, 10),
        sp(30.930, 75.850, 20), // gap 1
        sp(30.960, 75.850, 30), // gap 2 — everything before this goes
        sp(30.961, 75.850, 35),
      ]);
      expect(out.length, 2);
      expect(out.first.kmh, 30);
    });

    test('tiny inputs come back as-is', () {
      expect(newestContinuousRun(<SpeedPoint>[]), isEmpty);
      final one = <SpeedPoint>[sp(30.9, 75.85, 5)];
      expect(newestContinuousRun(one).length, 1);
    });
  });

  group('MapStopPin', () {
    test('carries exactly what both map engines need', () {
      const pin = MapStopPin(30.91, 75.84, '2. Model Town');
      expect(pin.lat, 30.91);
      expect(pin.lng, 75.84);
      expect(pin.label, '2. Model Town');
    });
  });
}
