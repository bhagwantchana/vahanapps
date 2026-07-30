import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// Status drives the marker colour on the live map — green moving, orange idle,
/// red stopped, grey offline. Getting it wrong is the most visible failure the
/// product has: a school watching a running bus painted red as "Stopped".
void main() {
  // ACC bit off, but the vehicle is clearly on the road. OBD and PT06 units
  // flicker or stick that bit, and tbl_device.acc can lag behind the live fix.
  VehicleRecord movingWithAccOff({int speed = 60}) => VehicleRecord(
        id: 1,
        speed: speed.toDouble(),
        acc: 0,
        tsEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

  group('a vehicle with real road speed is moving', () {
    test('60 km/h with ACC off is NOT stopped', () {
      final v = movingWithAccOff();
      expect(v.isStopped, isFalse,
          reason: 'running bus would render as a red Stopped marker');
      expect(v.isMoving, isTrue);
      expect(v.statusKey, 'moving');
    });

    test('60 km/h with ACC off is not idle either', () {
      expect(movingWithAccOff().isIdle, isFalse);
    });

    test('ACC on and moving is still moving', () {
      final v = VehicleRecord(
        id: 1,
        speed: 60,
        acc: 1,
        tsEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      expect(v.statusKey, 'moving');
    });
  });

  group('stationary vehicles keep their old behaviour', () {
    test('engine on, not moving = idle', () {
      final v = VehicleRecord(
        id: 1,
        speed: 0,
        acc: 1,
        tsEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      expect(v.statusKey, 'idle');
      expect(v.isIdle, isTrue);
      expect(v.isStopped, isFalse);
    });

    test('engine off, not moving = stopped', () {
      final v = VehicleRecord(
        id: 1,
        speed: 0,
        acc: 0,
        tsEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      expect(v.statusKey, 'stopped');
      expect(v.isStopped, isTrue);
    });

    test('GPS jitter below the threshold is not called moving', () {
      final v = VehicleRecord(
        id: 1,
        speed: 3, // parked drift
        acc: 0,
        tsEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      expect(v.isMoving, isFalse);
      expect(v.statusKey, 'stopped');
    });
  });

  group('the three states never overlap', () {
    test('exactly one of moving/idle/stopped holds', () {
      for (final speed in <double>[0, 3, 5, 6, 40, 120]) {
        for (final acc in <int>[0, 1]) {
          final v = VehicleRecord(
            id: 1,
            speed: speed,
            acc: acc,
            tsEpochMs: DateTime.now().millisecondsSinceEpoch,
          );
          final live = <bool>[v.isMoving, v.isIdle, v.isStopped]
              .where((f) => f)
              .length;
          expect(live, 1,
              reason: 'speed=$speed acc=$acc produced $live states');
        }
      }
    });
  });

  group('a stale fix must not be painted as a live status', () {
    VehicleRecord agedFix(Duration age, {double speed = 0, int acc = 1}) =>
        VehicleRecord(
          id: 1,
          speed: speed,
          acc: acc,
          tsEpochMs:
              DateTime.now().subtract(age).millisecondsSinceEpoch,
        );

    test('45 minutes old is offline', () {
      expect(agedFix(const Duration(minutes: 45), speed: 60).statusKey,
          'offline',
          reason: 'a stale fix must not be shown as live movement');
    });

    test('12 minutes old is offline, not idle', () {
      // The bug the schools hit: bus idles at the gate, pulls away, signal
      // drops. The old 30-minute window kept insisting "idle" the whole time.
      expect(agedFix(const Duration(minutes: 12)).statusKey, 'offline',
          reason: 'app claimed idle from a fix minutes old while driving');
    });

    test('a parked vehicle on its 5-minute write interval stays idle', () {
      // Must not grey out vehicles that are simply parked — the server only
      // writes their position every 5 minutes by design.
      expect(agedFix(const Duration(minutes: 6)).statusKey, 'idle',
          reason: 'parked vehicles would flicker to offline');
    });

    test('a fresh fix is unaffected', () {
      expect(agedFix(const Duration(seconds: 20), speed: 60).statusKey,
          'moving');
    });
  });

  group('statusKey is the one exhaustive rule every surface buckets by', () {
    // The regression this group exists to stop: isMoving/isIdle/isStopped are
    // stale-aware, so ALL THREE go false past staleFixMs. Widgets that carried
    // their own 30-minute offline gate then fell through to `idle` and painted
    // a vehicle silent for ten minutes orange — an idling engine on a device
    // that had stopped speaking. Anything bucketing vehicles must use
    // statusKey, which always answers, and answers exactly once.
    List<VehicleRecord> fleet() => <VehicleRecord>[
          for (final ageMinutes in <int>[0, 1, 6, 9, 12, 25, 31, 90])
            for (final speed in <double>[0, 3, 6, 70])
              for (final acc in <int>[0, 1])
                VehicleRecord(
                  id: 1,
                  speed: speed,
                  acc: acc,
                  tsEpochMs: DateTime.now()
                      .subtract(Duration(minutes: ageMinutes))
                      .millisecondsSinceEpoch,
                ),
        ];

    test('always one of the four keys, never anything else', () {
      for (final v in fleet()) {
        expect(
          <String>['moving', 'idle', 'stopped', 'offline'],
          contains(v.statusKey),
        );
      }
    });

    test('buckets are exclusive, so counts sum to the fleet', () {
      final vehicles = fleet();
      var moving = 0, idle = 0, stopped = 0, offline = 0;
      for (final v in vehicles) {
        switch (v.statusKey) {
          case 'moving':
            moving++;
            break;
          case 'idle':
            idle++;
            break;
          case 'stopped':
            stopped++;
            break;
          default:
            offline++;
        }
      }
      expect(moving + idle + stopped + offline, vehicles.length,
          reason: 'a chip would show a count its own filtered list disagrees with');
    });

    test('the 8-30 minute window is offline, never idle', () {
      // Exactly the window three widgets used to leave on the idle fallthrough.
      for (final minutes in <int>[9, 12, 20, 29]) {
        final v = VehicleRecord(
          id: 1,
          speed: 0,
          acc: 0,
          tsEpochMs: DateTime.now()
              .subtract(Duration(minutes: minutes))
              .millisecondsSinceEpoch,
        );
        expect(v.statusKey, 'offline', reason: '$minutes min old');
        expect(v.statusLabel, 'Offline');
      }
    });

    test('statusLabel always agrees with statusKey', () {
      const labels = <String, String>{
        'moving': 'Moving',
        'idle': 'Idle',
        'stopped': 'Stopped',
        'offline': 'Offline',
      };
      for (final v in fleet()) {
        expect(v.statusLabel, labels[v.statusKey]);
      }
    });
  });

  group('a live push must not overwrite a newer fix with an older one', () {
    VehicleRecord at(DateTime when, {double speed = 0}) => VehicleRecord(
          id: 1,
          imei: '868999999999901',
          speed: speed,
          acc: 1,
          latitude: 31.3,
          longitude: 75.5,
          tsEpochMs: when.millisecondsSinceEpoch,
          hasLiveLocation: true,
        );

    test('a newer fix is applied', () {
      final now = DateTime.now();
      final current = at(now.subtract(const Duration(seconds: 8)));
      final merged = current.mergeLiveFixFrom(at(now, speed: 42));
      expect(merged.speed, 42);
      expect(merged.tsEpochMs, at(now).tsEpochMs);
    });

    test('an older fix is rejected and returns the record unchanged', () {
      // Identity matters: SingleTrackCubit uses it to tell an applied push from
      // a dropped one, and only stamps _lastLiveAt on the former. Stamping on a
      // drop suppressed the 5 s poll that would have recovered the frozen map.
      final now = DateTime.now();
      final current = at(now, speed: 42);
      final merged =
          current.mergeLiveFixFrom(at(now.subtract(const Duration(minutes: 2))));
      expect(identical(merged, current), isTrue);
    });

    test('a push with no timestamp still applies when it carries a position', () {
      final current = at(DateTime.now());
      final incoming = VehicleRecord(
        id: 1,
        imei: '868999999999901',
        speed: 15,
        acc: 1,
        latitude: 31.31,
        longitude: 75.51,
        hasLiveLocation: true,
      );
      expect(current.mergeLiveFixFrom(incoming).speed, 15);
    });

    test('satellites and createdAt survive a push that omits them', () {
      final now = DateTime.now();
      final current = VehicleRecord(
        id: 1,
        imei: '868999999999901',
        satellites: 11,
        createdAt: '2026-07-30 04:10:00',
        tsEpochMs: now.subtract(const Duration(seconds: 8)).millisecondsSinceEpoch,
        hasLiveLocation: true,
      );
      final merged = current.mergeLiveFixFrom(at(now, speed: 30));
      expect(merged.satellites, 11);
      expect(merged.createdAt, '2026-07-30 04:10:00');
    });
  });
}

