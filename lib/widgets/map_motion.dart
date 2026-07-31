import 'dart:math' as math;

/// Motion maths shared by the live maps: how a marker moves BETWEEN GPS fixes.
///
/// Devices report every ~8 s, so almost everything the user sees between two
/// fixes is interpolation. Kept in its own file (rather than private to the map
/// widget) so the behaviour can be unit-tested without a map or a device.

/// One GPS fix on the playback queue.
class MotionFix {
  const MotionFix(this.lat, this.lng, this.ts);
  final double lat;
  final double lng;
  final int ts; // epoch ms
}

/// A point on the interpolated path.
class MotionPoint {
  const MotionPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Metres between two coordinates (haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Compass bearing (degrees, 0-360) from one coordinate to another.
double bearingDegrees(double lat1, double lng1, double lat2, double lng2) {
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dl = (lng2 - lng1) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) -
      math.sin(p1) * math.cos(p2) * math.cos(dl);
  return ((math.atan2(y, x) * 180 / math.pi) + 360) % 360;
}

/// Shortest angular distance between two headings, 0-180. Handles the 359°→1°
/// wrap, which a plain subtraction reads as a 358° swing.
double angleDeltaDegrees(double from, double to) {
  final diff = (((to - from) % 360) + 540) % 360 - 180;
  return diff.abs();
}

/// Maximum metres the spline may stray from the straight line before we give up
/// on it. A sharp direction change can make Catmull-Rom overshoot well off the
/// road; a slightly cut corner beats a wild loop.
const double kSplineGuardMeters = 25;

/// Catmull-Rom position along p1→p2, using p0/p3 as the surrounding tangents.
///
/// A straight lerp cuts the corner — that is the "sideways slide" through a
/// junction, where the marker leaves the road and slides diagonally to the next
/// fix. The spline arcs through the turn instead. At the queue edges p0/p3
/// collapse onto the segment ends and this degenerates to the straight line.
MotionPoint catmullRom(
    MotionFix p0, MotionFix p1, MotionFix p2, MotionFix p3, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  double axis(double v0, double v1, double v2, double v3) =>
      0.5 *
      ((2 * v1) +
          (-v0 + v2) * t +
          (2 * v0 - 5 * v1 + 4 * v2 - v3) * t2 +
          (-v0 + 3 * v1 - 3 * v2 + v3) * t3);

  final lat = axis(p0.lat, p1.lat, p2.lat, p3.lat);
  final lng = axis(p0.lng, p1.lng, p2.lng, p3.lng);
  final linLat = p1.lat + (p2.lat - p1.lat) * t;
  final linLng = p1.lng + (p2.lng - p1.lng) * t;
  if (distanceMeters(lat, lng, linLat, linLng) > kSplineGuardMeters) {
    return MotionPoint(linLat, linLng);
  }
  return MotionPoint(lat, lng);
}

/// Shortest-path angular interpolation, handling the 359°→1° wrap. Easing the
/// drawn heading instead of snapping is what makes a corner read as the car
/// turning rather than the icon flicking round mid-slide.
double lerpAngle(double from, double to, double t) {
  final diff = (((to - from) % 360) + 540) % 360 - 180;
  return ((from + diff * t) % 360 + 360) % 360;
}

/// Lag past the cushion that forces a hard snap to live. Beyond this the marker
/// is showing history, not a live position.
const int kMaxLagMs = 8000;

/// Lag past the cushion where playback runs at 2x to close the gap smoothly.
const int kCatchUpMs = 2000;

/// Resample a route line through the SAME Catmull-Rom curve the marker rides.
///
/// The trail was drawn as raw straight segments between fixes ~8 s apart while
/// the marker moved along a spline, so at every junction the car visibly left
/// its own line and cut inside the corner. Feeding both through one curve is
/// what puts the vehicle exactly on the road it has just driven.
///
/// [perSegment] points are emitted per input segment. Four is plenty: it is the
/// corners that need the extra vertices, and a straight run resamples to points
/// that lie on the straight line anyway.
List<MotionPoint> smoothPath(List<MotionPoint> pts, {int perSegment = 4}) {
  if (pts.length < 3 || perSegment < 2) {
    return List<MotionPoint>.unmodifiable(pts);
  }
  final out = <MotionPoint>[];
  for (var i = 0; i < pts.length - 1; i++) {
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p0 = i > 0 ? pts[i - 1] : p1;
    final p3 = (i + 2) < pts.length ? pts[i + 2] : p2;
    for (var s = 0; s < perSegment; s++) {
      final t = s / perSegment;
      out.add(catmullRom(
        MotionFix(p0.lat, p0.lng, 0),
        MotionFix(p1.lat, p1.lng, 0),
        MotionFix(p2.lat, p2.lng, 0),
        MotionFix(p3.lat, p3.lng, 0),
        t,
      ));
    }
  }
  out.add(pts.last);
  return out;
}

/// How far back from the end of [pts] the vehicle currently sits.
///
/// The marker renders a cushion BEHIND the newest fix, but the trail is built
/// from raw fixes right up to that newest one — so the blue line ran roughly a
/// cushion's worth of travel past the car's nose (about 30 m at 60 km/h) and
/// grew in visible 8-second jumps ahead of it. Cutting the line here and ending
/// it at the rendered position puts the nose exactly on the tip.
///
/// Only the last [lookback] points are searched: the vehicle is always near the
/// end, and scanning a 300-point trail every frame is wasted work.
int nearestIndexFromEnd(List<MotionPoint> pts, double lat, double lng,
    {int lookback = 60}) {
  if (pts.isEmpty) return -1;
  final start = pts.length - lookback < 0 ? 0 : pts.length - lookback;
  var bestIdx = pts.length - 1;
  var bestDist = double.infinity;
  for (var i = start; i < pts.length; i++) {
    final d = distanceMeters(pts[i].lat, pts[i].lng, lat, lng);
    if (d < bestDist) {
      bestDist = d;
      bestIdx = i;
    }
  }
  return bestIdx;
}

/// Smallest cushion the playback clock can hold and still run continuously.
const int kMinCushionMs = 1200;

/// Largest cushion we will accept. Past this the marker is far enough behind
/// that the lag itself becomes the complaint.
const int kMaxCushionMs = 4000;

/// Render cushion sized to how often THIS device actually reports.
///
/// A fixed 1800 ms cushion was the "vehicle doesn't move properly" report.
/// Playback may never run past the newest fix, so whenever a fix arrived later
/// than the cushion could absorb, the marker hit the ceiling and FROZE, then
/// lurched when the packet landed — stop, jump, stop, jump. These devices
/// report about every 8 s with heavy jitter, so 1800 ms was hit constantly.
///
/// Sizing the cushion at 60% of the median observed interval keeps the clock
/// continuously fed without imposing a fixed lag on devices that report often:
/// at today's ~8 s it clamps to 4 s, and if the reporting interval is ever cut
/// to 4 s it follows down to 2.4 s on its own, with no code change.
int adaptiveCushionMs(List<int> intervalsMs) {
  if (intervalsMs.isEmpty) return kMinCushionMs;
  final sorted = List<int>.from(intervalsMs)..sort();
  final median = sorted[sorted.length ~/ 2];
  final scaled = (median * 0.6).round();
  if (scaled < kMinCushionMs) return kMinCushionMs;
  if (scaled > kMaxCushionMs) return kMaxCushionMs;
  return scaled;
}

/// Advance the playback clock by one frame.
///
/// The clock runs at 1x wall time, so any lag it acquires would otherwise be
/// PERMANENT — 1x can never catch up to 1x. Devices buffer through a GSM gap
/// and dump several fixes at once, which used to leave the marker crawling
/// through minutes-old positions while the vehicle was streets away.
///
/// [playMs] current clock, [dtMs] wall time since the last frame, [upperMs] the
/// newest fix minus the render cushion, [floorMs] the oldest fix still queued.
int advancePlaybackClock({
  required int playMs,
  required int dtMs,
  required int upperMs,
  required int floorMs,
}) {
  final lag = upperMs - playMs;
  var next = lag > kMaxLagMs
      ? upperMs // hopeless backlog — jump to live rather than crawl
      : playMs + (lag > kCatchUpMs ? dtMs * 2 : dtMs);
  if (next > upperMs) next = upperMs;
  if (next < floorMs) next = floorMs;
  return next;
}
