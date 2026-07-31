import 'package:fleet_monitor/widgets/map_motion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motion maths behind the live map: how the marker moves BETWEEN GPS fixes.
/// Devices report every ~8 s, so this is what the customer actually watches.
void main() {
  group('cornering — no sideways slide', () {
    // A right-angle turn, the shape that produced the complaint: the vehicle
    // runs east, then turns north. ~110 m per 0.001 degree at this latitude.
    const west = MotionFix(30.7000, 76.7000, 0);
    const corner = MotionFix(30.7000, 76.7020, 8000);
    const north = MotionFix(30.7020, 76.7020, 16000);
    const beyond = MotionFix(30.7040, 76.7020, 24000);

    test('curve leaves the straight line through the corner', () {
      // Mid-segment, straight-line interpolation sits exactly on the chord.
      final straightLat = corner.lat + (north.lat - corner.lat) * 0.5;
      final straightLng = corner.lng + (north.lng - corner.lng) * 0.5;
      final curved = catmullRom(west, corner, north, beyond, 0.5);

      final deviation = distanceMeters(
          curved.lat, curved.lng, straightLat, straightLng);

      // It must actually bend — a few metres of arc is the whole point.
      expect(deviation, greaterThan(2.0),
          reason: 'curve collapsed onto the straight line — corner still cut');
      // ...but never wander off the road.
      expect(deviation, lessThanOrEqualTo(kSplineGuardMeters));
    });

    test('endpoints stay pinned to the real fixes', () {
      final start = catmullRom(west, corner, north, beyond, 0.0);
      final end = catmullRom(west, corner, north, beyond, 1.0);
      // The curve may not invent positions at the fixes themselves.
      expect(distanceMeters(start.lat, start.lng, corner.lat, corner.lng),
          lessThan(0.5));
      expect(distanceMeters(end.lat, end.lng, north.lat, north.lng),
          lessThan(0.5));
    });

    test('guard rejects a spline that overshoots off-road', () {
      // A hairpin: tangents point hard away, which makes raw Catmull-Rom
      // overshoot far past the segment.
      const p0 = MotionFix(30.7000, 76.8000, 0);
      const p1 = MotionFix(30.7000, 76.7000, 8000);
      const p2 = MotionFix(30.7010, 76.7000, 16000);
      const p3 = MotionFix(30.7010, 76.8000, 24000);

      final curved = catmullRom(p0, p1, p2, p3, 0.5);
      final straightLat = p1.lat + (p2.lat - p1.lat) * 0.5;
      final straightLng = p1.lng + (p2.lng - p1.lng) * 0.5;

      expect(
        distanceMeters(curved.lat, curved.lng, straightLat, straightLng),
        lessThanOrEqualTo(kSplineGuardMeters),
        reason: 'overshoot guard did not fire — marker would loop off-road',
      );
    });

    test('straight road stays straight', () {
      const a = MotionFix(30.7000, 76.7000, 0);
      const b = MotionFix(30.7000, 76.7010, 8000);
      const c = MotionFix(30.7000, 76.7020, 16000);
      const d = MotionFix(30.7000, 76.7030, 24000);

      final mid = catmullRom(a, b, c, d, 0.5);
      final straightLng = b.lng + (c.lng - b.lng) * 0.5;
      expect(distanceMeters(mid.lat, mid.lng, b.lat, straightLng),
          lessThan(0.5),
          reason: 'spline wobbled on a straight road');
    });
  });

  group('heading eases instead of snapping', () {
    test('a 90 degree turn is not taken in one frame', () {
      final afterOneFrame = lerpAngle(0, 90, 16 / 240); // one 60 fps frame
      expect(afterOneFrame, greaterThan(0));
      expect(afterOneFrame, lessThan(15),
          reason: 'heading snapped — icon would flick round mid-slide');
    });

    test('takes the short way across the 360 boundary', () {
      // 350° -> 10° is +20°, not -340°.
      final stepped = lerpAngle(350, 10, 0.5);
      // Halfway the short way is 0/360.
      final offZero = (stepped % 360);
      final delta = offZero > 180 ? 360 - offZero : offZero;
      expect(delta, lessThan(1.0),
          reason: 'took the long way round — icon would spin backwards');
    });

    test('converges on the target and stays in range', () {
      var h = 0.0;
      for (var i = 0; i < 200; i++) {
        h = lerpAngle(h, 270, 16 / 240);
        expect(h, inInclusiveRange(0, 360));
      }
      expect((h - 270).abs(), lessThan(1.0));
    });
  });

  group('playback clock — the regression that showed stale positions', () {
    test('a buffered backlog snaps to live instead of crawling', () {
      // Device was in a GSM dead zone and dumped 3 minutes of fixes at once.
      final next = advancePlaybackClock(
        playMs: 0,
        dtMs: 16,
        upperMs: 180000,
        floorMs: 0,
      );
      expect(next, 180000,
          reason: 'clock crawled through the backlog — the reported bug');
    });

    test('a small gap is closed by speeding up, not jumping', () {
      final next = advancePlaybackClock(
        playMs: 0,
        dtMs: 100,
        upperMs: 4000, // 4 s behind: over catch-up, under snap
        floorMs: 0,
      );
      expect(next, 200, reason: 'expected 2x catch-up');
    });

    test('normal running advances at real time', () {
      final next = advancePlaybackClock(
        playMs: 0,
        dtMs: 100,
        upperMs: 1000, // within the catch-up budget
        floorMs: 0,
      );
      expect(next, 100);
    });

    test('never runs past live', () {
      final next = advancePlaybackClock(
        playMs: 900,
        dtMs: 500,
        upperMs: 1000,
        floorMs: 0,
      );
      expect(next, 1000);
    });

    test('lag can never become permanent', () {
      // The old code advanced at exactly 1x, so a 30 s lag stayed 30 s forever.
      var play = 0;
      var upper = 30000; // 30 s behind at the start
      for (var frame = 0; frame < 400; frame++) {
        play = advancePlaybackClock(
          playMs: play,
          dtMs: 16,
          upperMs: upper,
          floorMs: 0,
        );
        upper += 16; // live edge advances in real time too
      }
      expect(upper - play, lessThanOrEqualTo(kCatchUpMs),
          reason: 'clock never caught up — marker would stay behind forever');
    });
  });

  group('the route line follows the same curve the marker rides', () {
    // The right-angle turn again, as a plain list of positions.
    const path = <MotionPoint>[
      MotionPoint(30.7000, 76.7000),
      MotionPoint(30.7000, 76.7020),
      MotionPoint(30.7020, 76.7020),
      MotionPoint(30.7040, 76.7020),
    ];

    test('resampling adds vertices through the corner', () {
      final smooth = smoothPath(path, perSegment: 4);
      expect(smooth.length, greaterThan(path.length));
    });

    test('it keeps the real start and end pinned', () {
      final smooth = smoothPath(path);
      expect(smooth.first.lat, closeTo(path.first.lat, 1e-9));
      expect(smooth.first.lng, closeTo(path.first.lng, 1e-9));
      expect(smooth.last.lat, closeTo(path.last.lat, 1e-9));
      expect(smooth.last.lng, closeTo(path.last.lng, 1e-9));
    });

    test('the smoothed line leaves the chord at the corner', () {
      // The whole point: a straight line cuts the corner, and the marker (which
      // rides the spline) then visibly leaves its own trail through junctions.
      final smooth = smoothPath(path, perSegment: 8);
      var maxOffset = 0.0;
      for (final p in smooth) {
        // Distance from the corner vertex; the arc rounds inside it.
        final d = distanceMeters(p.lat, p.lng, 30.7000, 76.7020);
        if (d > maxOffset) maxOffset = d;
      }
      expect(maxOffset, greaterThan(0));
    });

    test('a straight run stays straight', () {
      const straight = <MotionPoint>[
        MotionPoint(30.7000, 76.7000),
        MotionPoint(30.7000, 76.7010),
        MotionPoint(30.7000, 76.7020),
        MotionPoint(30.7000, 76.7030),
      ];
      for (final p in smoothPath(straight)) {
        expect(p.lat, closeTo(30.7000, 1e-6));
      }
    });

    test('too few points to curve are returned untouched', () {
      const two = <MotionPoint>[
        MotionPoint(30.7, 76.7),
        MotionPoint(30.8, 76.8),
      ];
      expect(smoothPath(two).length, 2);
      expect(smoothPath(const <MotionPoint>[]).length, 0);
    });
  });

  group('the trail is cut at the vehicle, never past it', () {
    // The marker renders a cushion behind the newest fix, so the raw trail ran
    // ~30 m past its nose at 60 km/h and grew in jumps ahead of the car.
    const line = <MotionPoint>[
      MotionPoint(30.7000, 76.7000),
      MotionPoint(30.7000, 76.7010),
      MotionPoint(30.7000, 76.7020),
      MotionPoint(30.7000, 76.7030),
      MotionPoint(30.7000, 76.7040),
    ];

    test('a vehicle mid-line cuts the points ahead of it', () {
      final cut = nearestIndexFromEnd(line, 30.7000, 76.7020);
      expect(cut, 2);
      expect(cut, lessThan(line.length - 1),
          reason: 'the line would still lead the vehicle');
    });

    test('a vehicle at the live edge keeps the whole line', () {
      expect(nearestIndexFromEnd(line, 30.7000, 76.7040), line.length - 1);
    });

    test('an empty line reports nothing to cut', () {
      expect(nearestIndexFromEnd(const <MotionPoint>[], 30.7, 76.7), -1);
    });

    test('only the tail is searched, so an early revisit cannot rewind it', () {
      // A route that loops back near its own start: without the lookback bound
      // the cut would jump to the beginning and erase the whole trail.
      const loop = <MotionPoint>[
        MotionPoint(30.7000, 76.7000),
        MotionPoint(30.7100, 76.7100),
        MotionPoint(30.7200, 76.7200),
        MotionPoint(30.7300, 76.7300),
      ];
      final cut = nearestIndexFromEnd(loop, 30.7000, 76.7000, lookback: 2);
      expect(cut, greaterThanOrEqualTo(loop.length - 2));
    });
  });

  group('the render cushion is sized to how often the device reports', () {
    // A fixed 1800 ms cushion was the "vehicle doesn't move properly" report:
    // playback may never run past the newest fix, so any fix later than the
    // cushion could absorb froze the marker until the packet landed.
    test('todays ~8 s devices get the full cushion', () {
      final cushion =
          adaptiveCushionMs(<int>[8000, 7600, 8400, 8100, 7900]);
      expect(cushion, kMaxCushionMs);
    });

    test('a 4 s reporting interval needs less lag, with no code change', () {
      // Median of [3800, 4000, 4000, 4100, 4200] is 4000 → 60% → 2400 ms.
      final cushion = adaptiveCushionMs(<int>[4000, 4200, 3800, 4100, 4000]);
      expect(cushion, 2400);
      expect(cushion, lessThan(kMaxCushionMs));
    });

    test('a fast device is still held to the floor', () {
      expect(adaptiveCushionMs(<int>[500, 600, 550]), kMinCushionMs);
    });

    test('no samples yet falls back to the floor', () {
      expect(adaptiveCushionMs(<int>[]), kMinCushionMs);
    });

    test('one late packet does not blow the cushion out', () {
      // Median, not mean: a single 40 s gap must not drag everyone's lag up.
      expect(adaptiveCushionMs(<int>[4000, 4000, 40000, 4000, 4000]), 2400);
    });
  });

  group('heading changes are measured the short way round', () {
    test('the 359 to 1 wrap is two degrees, not 358', () {
      expect(angleDeltaDegrees(359, 1), closeTo(2, 1e-9));
      expect(angleDeltaDegrees(1, 359), closeTo(2, 1e-9));
    });

    test('a real turn reads its true size', () {
      expect(angleDeltaDegrees(90, 180), closeTo(90, 1e-9));
    });

    test('no turn is zero', () {
      expect(angleDeltaDegrees(42, 42), closeTo(0, 1e-9));
    });
  });
}
