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
