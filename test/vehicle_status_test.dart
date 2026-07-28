import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// Status drives the marker colour on the live map â€” green moving, orange idle,
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

  group('offline wins over everything', () {
    test('a fix older than 30 minutes is offline', () {
      final stale = DateTime.now().subtract(const Duration(minutes: 45));
      final v = VehicleRecord(
        id: 1,
        speed: 60,
        acc: 1,
        tsEpochMs: stale.millisecondsSinceEpoch,
      );
      expect(v.statusKey, 'offline',
          reason: 'a stale fix must not be shown as live movement');
    });
  });
}

