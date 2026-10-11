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

/// Road-lane lateral boundary (metres). Normal road curves rarely deviate more
/// than 6-8 m from the corner chord. Bounding the curve within this lane
/// ensures the polyline and marker never bulge into roadside buildings.
const double kRoadLaneGuardMeters = 8.0;

/// Catmull-Rom position along p1→p2, using p0/p3 as the surrounding tangents.
///
/// Uses centripetal / chord-scaled tangents to eliminate the wild overshoot
/// and loops of uniform Catmull-Rom. When a turn is sharp, lateral deviation is
/// smoothly clamped to the road boundary rather than abruptly snapping to a
/// straight line, eliminating jagged kinks ("teda meda").
MotionPoint catmullRom(
    MotionFix p0, MotionFix p1, MotionFix p2, MotionFix p3, double t,
    {double maxDeviationMeters = kSplineGuardMeters}) {
  if (t <= 0.0) return MotionPoint(p1.lat, p1.lng);
  if (t >= 1.0) return MotionPoint(p2.lat, p2.lng);

  final d01 = distanceMeters(p0.lat, p0.lng, p1.lat, p1.lng);
  final d12 = distanceMeters(p1.lat, p1.lng, p2.lat, p2.lng);
  final d23 = distanceMeters(p2.lat, p2.lng, p3.lat, p3.lng);

  // Centripetal tangent scale factors: scale tangents proportional to segment
  // chord length so a long preceding straightaway never throws a huge tangent
  // into a short turn segment (the primary cause of off-road bulging).
  final w01 = (d01 + d12) > 0 ? (2.0 * d12 / (d01 + d12)) : 1.0;
  final w23 = (d12 + d23) > 0 ? (2.0 * d12 / (d12 + d23)) : 1.0;

  final m1Lat = 0.5 * (p2.lat - p0.lat) * w01;
  final m1Lng = 0.5 * (p2.lng - p0.lng) * w01;
  final m2Lat = 0.5 * (p3.lat - p1.lat) * w23;
  final m2Lng = 0.5 * (p3.lng - p1.lng) * w23;

  final t2 = t * t;
  final t3 = t2 * t;

  final h00 = 2 * t3 - 3 * t2 + 1;
  final h10 = t3 - 2 * t2 + t;
  final h01 = -2 * t3 + 3 * t2;
  final h11 = t3 - t2;

  final lat = h00 * p1.lat + h10 * m1Lat + h01 * p2.lat + h11 * m2Lat;
  final lng = h00 * p1.lng + h10 * m1Lng + h01 * p2.lng + h11 * m2Lng;

  final linLat = p1.lat + (p2.lat - p1.lat) * t;
  final linLng = p1.lng + (p2.lng - p1.lng) * t;

  final dev = distanceMeters(lat, lng, linLat, linLng);
  if (dev > maxDeviationMeters) {
    final scale = maxDeviationMeters / dev;
    return MotionPoint(
      linLat + (lat - linLat) * scale,
      linLng + (lng - linLng) * scale,
    );
  }
  return MotionPoint(lat, lng);
}

/// Analytical tangent heading (degrees, 0-360) along the Catmull-Rom spline at [t].
///
/// Evaluating the curve's velocity derivative dP/dt gives the vehicle's true
/// instantaneous heading everywhere along the curve. This eliminates heading
/// twitching or wobbling when passing waypoints or nearing the end of a segment.
double catmullRomTangentHeading(
    MotionFix p0, MotionFix p1, MotionFix p2, MotionFix p3, double t) {
  final d01 = distanceMeters(p0.lat, p0.lng, p1.lat, p1.lng);
  final d12 = distanceMeters(p1.lat, p1.lng, p2.lat, p2.lng);
  final d23 = distanceMeters(p2.lat, p2.lng, p3.lat, p3.lng);

  final w01 = (d01 + d12) > 0 ? (2.0 * d12 / (d01 + d12)) : 1.0;
  final w23 = (d12 + d23) > 0 ? (2.0 * d12 / (d12 + d23)) : 1.0;

  final m1Lat = 0.5 * (p2.lat - p0.lat) * w01;
  final m1Lng = 0.5 * (p2.lng - p0.lng) * w01;
  final m2Lat = 0.5 * (p3.lat - p1.lat) * w23;
  final m2Lng = 0.5 * (p3.lng - p1.lng) * w23;

  final clampedT = t.clamp(0.0, 1.0);
  final t2 = clampedT * clampedT;

  final dh00 = 6 * t2 - 6 * clampedT;
  final dh10 = 3 * t2 - 4 * clampedT + 1;
  final dh01 = -6 * t2 + 6 * clampedT;
  final dh11 = 3 * t2 - 2 * clampedT;

  final dLat = dh00 * p1.lat + dh10 * m1Lat + dh01 * p2.lat + dh11 * m2Lat;
  final dLng = dh00 * p1.lng + dh10 * m1Lng + dh01 * p2.lng + dh11 * m2Lng;

  if (dLat.abs() < 1e-9 && dLng.abs() < 1e-9) {
    return bearingDegrees(p1.lat, p1.lng, p2.lat, p2.lng);
  }

  final cur = catmullRom(p0, p1, p2, p3, clampedT);
  return bearingDegrees(cur.lat, cur.lng, cur.lat + dLat, cur.lng + dLng);
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

/// Clean lateral multipath noise and GPS jitter from a series of fixes.
///
/// GPS receivers frequently produce single-point multipath bounces (5-20 m to
/// the side of a road before returning). Connecting these raw points produces
/// a zig-zag ("teda meda") trail and causes splines to bulge off-road.
/// This filter detects acute lateral spurs and relaxes them, keeping the line
/// centered on the road.
List<MotionPoint> cleanGpsTrail(List<MotionPoint> pts,
    {double maxSpurMeters = 6.0, double maxDetourRatio = 1.30}) {
  if (pts.length < 3) return List<MotionPoint>.unmodifiable(pts);

  final result = <MotionPoint>[pts.first];
  for (var i = 1; i < pts.length - 1; i++) {
    final prev = result.last;
    final curr = pts[i];
    final next = pts[i + 1];

    final dChord = distanceMeters(prev.lat, prev.lng, next.lat, next.lng);
    final d1 = distanceMeters(prev.lat, prev.lng, curr.lat, curr.lng);
    final d2 = distanceMeters(curr.lat, curr.lng, next.lat, next.lng);

    if (dChord > 2.0 && dChord < 160.0) {
      final detour = (d1 + d2) / dChord;
      final s = (d1 + d2 + dChord) / 2.0;
      final areaSq = s * (s - d1) * (s - d2) * (s - dChord);
      final perp = areaSq > 0 ? (2.0 * math.sqrt(areaSq) / dChord) : 0.0;

      if (perp > maxSpurMeters && detour > maxDetourRatio) {
        final dx = next.lng - prev.lng;
        final dy = next.lat - prev.lat;
        final denom = dy * dy + dx * dx;
        if (denom > 1e-12) {
          final u = (((curr.lat - prev.lat) * dy + (curr.lng - prev.lng) * dx) / denom)
              .clamp(0.1, 0.9);
          final projLat = prev.lat + dy * u;
          final projLng = prev.lng + dx * u;
          result.add(MotionPoint(
            curr.lat + (projLat - curr.lat) * 0.85,
            curr.lng + (projLng - curr.lng) * 0.85,
          ));
          continue;
        }
      }
    }
    result.add(curr);
  }
  result.add(pts.last);
  return result;
}

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
List<MotionPoint> smoothPath(List<MotionPoint> pts,
    {int perSegment = 4, bool cleanJitter = true}) {
  if (pts.length < 3 || perSegment < 2) {
    return List<MotionPoint>.unmodifiable(pts);
  }
  final src = cleanJitter ? cleanGpsTrail(pts) : pts;
  final out = <MotionPoint>[];
  for (var i = 0; i < src.length - 1; i++) {
    final p1 = src[i];
    final p2 = src[i + 1];
    final p0 = i > 0 ? src[i - 1] : p1;
    final p3 = (i + 2) < src.length ? src[i + 2] : p2;
    for (var s = 0; s < perSegment; s++) {
      final t = s / perSegment;
      out.add(catmullRom(
        MotionFix(p0.lat, p0.lng, 0),
        MotionFix(p1.lat, p1.lng, 0),
        MotionFix(p2.lat, p2.lng, 0),
        MotionFix(p3.lat, p3.lng, 0),
        t,
        maxDeviationMeters: kRoadLaneGuardMeters,
      ));
    }
  }
  out.add(src.last);
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

/// Longest we will keep a vehicle moving on dead reckoning alone.
///
/// Measured from an owner recording: gaps between fixes on these devices run
/// 5, 5, 7, 7, 10, 13 and 15 seconds. At 73 km/h a 13-second gap is 264 metres
/// — and the marker sat still for all of it, then jumped. No render cushion
/// fixes that: one big enough to absorb a 15 s gap puts the vehicle 300 m
/// behind, which is the opposite complaint.
///
/// So when the queue runs dry we keep the vehicle rolling along its last known
/// heading at its last known speed, the way a navigation app does, and
/// reconcile when the next fix lands. Past this bound we stop and admit we do
/// not know.
const int kMaxCoastMs = 14000;

/// Below this speed there is nothing to extrapolate — a stopped vehicle must
/// never drift off down the road.
const double kMinCoastKmh = 8;

/// Position [meters] ahead of a point along [bearingDeg].
MotionPoint projectAhead(
    double lat, double lng, double bearingDeg, double meters) {
  if (meters <= 0) return MotionPoint(lat, lng);
  const r = 6371000.0;
  final d = meters / r;
  final b = bearingDeg * math.pi / 180;
  final p1 = lat * math.pi / 180;
  final l1 = lng * math.pi / 180;
  final p2 = math.asin(
      math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(b));
  final l2 = l1 +
      math.atan2(math.sin(b) * math.sin(d) * math.cos(p1),
          math.cos(d) - math.sin(p1) * math.sin(p2));
  return MotionPoint(p2 * 180 / math.pi, l2 * 180 / math.pi);
}

/// How much of a leftover correction still applies [elapsedMs] into the blend.
///
/// When a real fix lands after a coast, the drawn position is wherever dead
/// reckoning guessed and the true position is wherever the vehicle actually
/// went. Snapping between them is the jump we are trying to remove, so the
/// difference is carried as an offset that decays to nothing — the marker
/// slides onto the truth over [kReconcileMs] instead of teleporting onto it.
const int kReconcileMs = 900;

double reconcileFactor(int elapsedMs) {
  if (elapsedMs <= 0) return 1;
  if (elapsedMs >= kReconcileMs) return 0;
  final t = 1 - (elapsedMs / kReconcileMs);
  return t * t; // ease-out: most of the correction goes early
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

/// Keeps a marker's status ICON from flapping.
///
/// isMoving flips at speed > 5, and slow city traffic crosses that line on
/// nearly every fix - 4, 7, 3, 8 km/h - so the icon swapped green/orange
/// every few seconds. On film that reads as the marker BLINKING. The raw
/// status still drives counts and logic everywhere else; only the DRAWN icon
/// waits until a new status has held for [holdMs] before it switches, so a
/// genuine stop shows within ten seconds and a threshold wobble shows
/// nothing at all.
class StatusSmoother {
  final Map<int, String> _shown = <int, String>{};
  final Map<int, String> _candidate = <int, String>{};
  final Map<int, int> _candidateSince = <int, int>{};

  String shownFor(int id, String raw, int nowMs, {int holdMs = 10000}) {
    final shown = _shown[id];
    if (shown == null) {
      _shown[id] = raw;
      return raw;
    }
    if (raw == shown) {
      _candidate.remove(id);
      _candidateSince.remove(id);
      return shown;
    }
    if (_candidate[id] != raw) {
      _candidate[id] = raw;
      _candidateSince[id] = nowMs;
      return shown;
    }
    if (nowMs - (_candidateSince[id] ?? nowMs) >= holdMs) {
      _shown[id] = raw;
      _candidate.remove(id);
      _candidateSince.remove(id);
      return raw;
    }
    return shown;
  }

  void clear() {
    _shown.clear();
    _candidate.clear();
    _candidateSince.clear();
  }
}
