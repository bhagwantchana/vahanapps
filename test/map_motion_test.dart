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
}
