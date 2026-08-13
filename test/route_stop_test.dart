import 'package:fleet_monitor/models/route_stop_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "My Stop" payloads. CodeIgniter returns every DB column as a STRING,
/// so the parsers must survive '31.20605400' and '120' — a naive `as int`
/// here would crash the tracking screen the moment stops exist.
void main() {
  group('RouteStop parses CI string payloads', () {
    test('a real routeStops row', () {
      final s = RouteStop.fromJson(<String, dynamic>{
        'id': '5',
        'vehicle_id': '47',
        'name': 'Phagwara Road Stop',
        'latitude': '31.18811700',
        'longitude': '75.68866900',
        'seq': '5',
        'radius_m': '120',
      });
      expect(s.id, 5);
      expect(s.name, 'Phagwara Road Stop');
      expect(s.latitude, closeTo(31.188117, 1e-6));
      expect(s.radiusM, 120);
      expect(s.displayName, 'Phagwara Road Stop');
    });

    test('an unnamed mined stop falls back to coordinates', () {
      final s = RouteStop.fromJson(<String, dynamic>{
        'id': 9,
        'name': '  ',
        'latitude': 31.2222,
        'longitude': 75.6512,
      });
      expect(s.displayName, '31.2222, 75.6512');
    });
  });

  group('StopEta', () {
    test('a real answer', () {
      final e = StopEta.fromJson(<String, dynamic>{
        'eta': <String, dynamic>{
          'eta_seconds': 312,
          'eta_minutes': 5,
          'based_on_days': 4,
        },
        'reason': '',
        'bus': <String, dynamic>{'last_updated': '2026-08-14 06:40:11'},
      });
      expect(e.hasEta, isTrue);
      expect(e.etaMinutes, 5);
      expect(e.basedOnDays, 4);
    });

    test('the honest "history cannot answer" shape', () {
      // The server sends eta:null + a reason rather than inventing a number;
      // the card must read that as no-ETA, not as 0 minutes.
      final e = StopEta.fromJson(<String, dynamic>{
        'eta': null,
        'reason': 'no_history',
        'bus': <String, dynamic>{'last_updated': '2026-08-14 06:40:11'},
      });
      expect(e.hasEta, isFalse);
      expect(e.reason, 'no_history');
    });

    test('a completely empty payload does not crash', () {
      final e = StopEta.fromJson(const <String, dynamic>{});
      expect(e.hasEta, isFalse);
    });
  });
}
