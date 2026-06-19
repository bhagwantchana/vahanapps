import 'package:fleet_monitor/models/vehicle_track_point.dart';

/// A driving-behaviour summary computed CLIENT-SIDE from a vehicle's trip
/// history points (speed + timestamp per point). The score is an APPROXIMATE
/// guide — event detection granularity is limited by how often the device
/// reports — but it gives owners a useful at-a-glance safety rating.
class DrivingScore {
  final int score; // 0-100
  final String rating; // Excellent / Good / Fair / Poor / No data
  final int overspeedEvents;
  final int harshAccelEvents;
  final int harshBrakeEvents;
  final double maxSpeed;
  final double avgSpeed;
  final int sampleCount;
  final List<String> tips;

  const DrivingScore({
    required this.score,
    required this.rating,
    required this.overspeedEvents,
    required this.harshAccelEvents,
    required this.harshBrakeEvents,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.sampleCount,
    required this.tips,
  });

  bool get hasData => sampleCount >= 2;

  static DrivingScore compute(
    List<VehicleTrackPoint> points, {
    double overspeedLimit = 0,
  }) {
    final pts = points.where((p) => p.speed >= 0).toList();
    if (pts.length < 2) {
      return const DrivingScore(
        score: 100,
        rating: 'No data',
        overspeedEvents: 0,
        harshAccelEvents: 0,
        harshBrakeEvents: 0,
        maxSpeed: 0,
        avgSpeed: 0,
        sampleCount: 0,
        tips: <String>['Not enough trip data yet to rate driving.'],
      );
    }

    double maxSpeed = 0;
    double sumMovingSpeed = 0;
    int movingCount = 0;
    int overspeed = 0;
    int harshAccel = 0;
    int harshBrake = 0;
    final limit = overspeedLimit > 0 ? overspeedLimit : 0;

    for (var i = 0; i < pts.length; i++) {
      final s = pts[i].speed;
      if (s > maxSpeed) maxSpeed = s;
      if (s > 2) {
        sumMovingSpeed += s;
        movingCount++;
      }
      if (limit > 0 && s > limit) overspeed++;
      if (i > 0) {
        final prev = pts[i - 1].speed;
        final dt = _seconds(pts[i - 1].createdAt, pts[i].createdAt);
        if (dt > 0 && dt <= 30) {
          final accel = (s - prev) / dt; // km/h per second
          if (accel > 8) {
            harshAccel++;
          } else if (accel < -10) {
            harshBrake++;
          }
        }
      }
    }

    final avg = movingCount > 0 ? sumMovingSpeed / movingCount : 0.0;

    var score = 100;
    score -= (overspeed * 3).clamp(0, 35);
    score -= (harshBrake * 4).clamp(0, 30);
    score -= (harshAccel * 3).clamp(0, 20);
    score = score.clamp(0, 100);

    final rating = score >= 85
        ? 'Excellent'
        : score >= 70
            ? 'Good'
            : score >= 50
                ? 'Fair'
                : 'Poor';

    final tips = <String>[];
    if (overspeed > 0) {
      tips.add('Reduce overspeeding — $overspeed time(s) over the limit.');
    }
    if (harshBrake > 0) {
      tips.add('Brake more gradually — $harshBrake hard-braking event(s).');
    }
    if (harshAccel > 0) {
      tips.add('Accelerate smoothly — $harshAccel hard-acceleration event(s).');
    }
    if (tips.isEmpty) {
      tips.add('Smooth and safe driving — keep it up!');
    }

    return DrivingScore(
      score: score,
      rating: rating,
      overspeedEvents: overspeed,
      harshAccelEvents: harshAccel,
      harshBrakeEvents: harshBrake,
      maxSpeed: maxSpeed,
      avgSpeed: avg,
      sampleCount: pts.length,
      tips: tips,
    );
  }

  static double _seconds(String a, String b) {
    final ta = DateTime.tryParse(a.replaceFirst(' ', 'T'));
    final tb = DateTime.tryParse(b.replaceFirst(' ', 'T'));
    if (ta == null || tb == null) return 0;
    return tb.difference(ta).inSeconds.toDouble();
  }
}
