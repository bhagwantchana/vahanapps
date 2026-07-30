import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/widgets/map_motion.dart';
import 'package:fleet_monitor/widgets/marker_placeholder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native **Google Maps** fleet overview (the owner wants the real Google look,
/// not the OSM/MapLibre tiles). Every vehicle is a CLEAN car marker — its own
/// icon laid flat on the road, rotated to heading, with a soft ground shadow
/// tinted the live STATUS colour (moving green / idle orange / stopped red /
/// offline grey). No ring/circle overlay. When zoomed in, each car also carries
/// a small "frosted glass" registration-number label (a SECOND, non-rotating
/// marker) so the operator can read which vehicle is which.
///
/// Requires a valid "Maps SDK for Android/iOS" key (see AndroidManifest.xml
/// meta-data `com.google.android.geo.API_KEY` → res/values/strings.xml). A
/// missing/wrong key renders a blank grey map.
class GoogleFleetMap extends StatefulWidget {
  const GoogleFleetMap({
    super.key,
    required this.vehicles,
    this.focusVehicleId,
    this.onVehicleTap,
    this.onMapTap,
    this.fitKey,
    this.recenterTick = 0,
    this.followVehicleId,
    this.trailPoints = const <LatLng>[],
  });

  final List<VehicleRecord> vehicles;

  /// Single-vehicle mode: when set, the camera continuously follows this
  /// vehicle (until the user pans, then resumes) and [trailPoints] draws its
  /// route line — the same live-tracking behaviour as the web map.
  final int? followVehicleId;

  /// Route/trail polyline points (single-vehicle mode). Empty = no line.
  final List<LatLng> trailPoints;

  /// The user-selected vehicle: the camera pans to it (clean — no ring). Null
  /// clears the selection (no camera move).
  final int? focusVehicleId;

  final void Function(VehicleRecord vehicle)? onVehicleTap;

  /// Tapping empty map (not a marker) — used to dismiss the details sheet.
  final VoidCallback? onMapTap;

  /// Changes whenever the caller wants the camera to re-fit to the current
  /// vehicle set (e.g. a status filter was tapped). Same value across polls =
  /// no refit, so a live fleet isn't constantly re-framed.
  final String? fitKey;

  /// Bump to force a re-fit to the whole current set (the recenter button).
  final int recenterTick;

  @override
  State<GoogleFleetMap> createState() => _GoogleFleetMapState();
}

// Compact Google Maps night + retro themes for the theme picker.
const String _darkStyle =
    '[{"elementType":"geometry","stylers":[{"color":"#212121"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#9aa4ad"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#b5b5b5"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#e0d18c"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#152431"}]}]';
const String _retroStyle =
    '[{"elementType":"geometry","stylers":[{"color":"#ebe3cd"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#523735"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f1e6"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#f5f1e6"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#fdfcf8"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f8c967"}]},{"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#b9d3c2"}]}]';

/// One buffered GPS fix (single-vehicle smooth playback).
class _Fix {
  const _Fix(this.lat, this.lng, this.ts);
  final double lat;
  final double lng;
  final int ts; // epoch ms of the fix
}

class _GoogleFleetMapState extends State<GoogleFleetMap>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Battery: the fleet ease/pulse ticker must not run while this map is off
  // the visible tab (IndexedStack → TickerMode off) or the app is backgrounded.
  bool _tickerEnabled = true;
  bool _appActive = true;
  static const LatLng _defaultCenter = LatLng(30.9, 75.8);
  // Reg labels are only worth showing once the cars are far enough apart to
  // read — below this zoom they'd overlap into noise, so we hide them.
  static const double _labelMinZoom = 12.5;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  GoogleMapController? _controller;
  double _dpr = 2.0;
  double _zoom = 11;
  /// Camera pitch, tracked from onCameraMove so the follow camera can preserve
  /// whatever the user has set instead of re-imposing a fixed value each frame.
  double _tilt = 0;
  bool _labelsShown = false;

  // User map controls: theme (default|dark|retro|satellite|terrain), traffic,
  // and single-vehicle navigation mode (3D tilt + heading-up).
  String _mapTheme = 'default';
  bool _traffic = false;
  bool _navMode = false;

  MapType get _resolvedMapType {
    switch (_mapTheme) {
      case 'satellite':
        return MapType.hybrid;
      case 'terrain':
        return MapType.terrain;
      default:
        return MapType.normal;
    }
  }

  String? get _resolvedStyle {
    switch (_mapTheme) {
      case 'dark':
        return _darkStyle;
      case 'retro':
        return _retroStyle;
      default:
        return null; // default = full-detail Google styling
    }
  }

  /// icon-url|status → composed car bitmap. Kept for the session so a parked
  /// fleet never re-composes.
  final Map<String, BitmapDescriptor> _iconCache = <String, BitmapDescriptor>{};
  final Set<String> _iconLoading = <String>{};
  BitmapDescriptor? _fallbackIcon;

  /// registration text → composed glass label bitmap.
  final Map<String, BitmapDescriptor> _labelCache =
      <String, BitmapDescriptor>{};
  final Set<String> _labelLoading = <String>{};

  /// count → composed cluster-bubble bitmap.
  final Map<int, BitmapDescriptor> _clusterCache = <int, BitmapDescriptor>{};
  final Set<int> _clusterLoading = <int>{};
  // Below this zoom (fleet mode only), overlapping vehicles collapse into a
  // numbered cluster bubble; tapping it zooms in to split them.
  static const double _clusterMaxZoom = 11.5;

  Set<Marker> _markers = <Marker>{};
  bool _fitDone = false;

  // Fleet "alive" animation (small fleets only, so it never janks a big one):
  // markers ease between fixes (#2) and running cars breathe a status glow (#1).
  static const int _fleetAnimMax = 25;
  final Map<int, LatLng> _renderedFleet = <int, LatLng>{};

  /// Per-vehicle playback for the FLEET map. The single-vehicle view has had
  /// curved motion and eased heading for a while; this map — the one the
  /// operator actually watches — was still doing a straight lerp toward the
  /// newest fix and drawing the device's raw course, which is exactly the
  /// "slides sideways through the corner" report.
  final Map<int, List<MotionFix>> _fleetQueues = <int, List<MotionFix>>{};
  final Map<int, int> _fleetPlayMs = <int, int>{};
  final Map<int, double> _fleetBearing = <int, double>{};
  int? _fleetLastWallMs;
  int _pulseTick = 0;
  Timer? _fleetTimer;

  bool get _fleetAnimActive =>
      widget.followVehicleId == null &&
      _visible.isNotEmpty &&
      _visible.length <= _fleetAnimMax &&
      !(_zoom < _clusterMaxZoom && _visible.length > 10); // not while clustering

  // 4-step breathing sequence (up-down) → glow index 0..2.
  int get _glowFrame => const <int>[0, 1, 2, 1][(_pulseTick ~/ 3) % 4];

  // Single-vehicle follow: pan with the vehicle, but pause for 8s after the
  // user manually moves the camera so we never fight their gesture.
  /// Programmatic camera moves are marked with a short DEADLINE, not a boolean.
  ///
  /// A flag broke on its own: _toggleNavMode set it and started a ~300 ms
  /// animateCamera, but the 60 fps follow camera cleared it within one frame.
  /// The animation's own onCameraMoveStarted then looked like a user gesture
  /// and paused follow for 8 seconds - during which the camera froze while the
  /// marker kept moving. In nav mode that is exactly the reported "vehicle
  /// slides sideways and its nose points away from the polyline": the car is
  /// drawn pointing up-screen while the map is stuck on a stale bearing.
  int _programmaticUntilMs = 0;
  bool get _programmaticMove =>
      DateTime.now().millisecondsSinceEpoch < _programmaticUntilMs;
  void _markProgrammatic(int ms) {
    final until = DateTime.now().millisecondsSinceEpoch + ms;
    if (until > _programmaticUntilMs) _programmaticUntilMs = until;
  }

  bool _followPaused = false;
  Timer? _followResume;

  // Single-vehicle SMOOTH PLAYBACK: buffer incoming fixes and replay the marker
  // through them at real pace, a small cushion behind live — so it glides along
  // the ACTUAL route at the vehicle's real speed with no jerk or corner-cutting
  // (the "hold data + animate" model the operator asked for). A 60 fps ticker
  // drives it.
  LatLng? _followRendered;
  double? _followBearing; // heading computed from actual movement (accurate)
  /// Heading actually drawn. Chases [_followBearing] a few degrees per frame
  /// instead of snapping, so a corner reads as the car turning rather than the
  /// icon flicking round while it slides sideways across the junction.
  double? _renderBearing;
  final List<_Fix> _fixQueue = <_Fix>[];
  int? _playMs; // virtual playback clock (epoch ms), stays cushion-behind live
  int? _lastWallMs;
  static const int _cushionMs = 1800; // render this far behind the newest fix
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1), // cadence only; value is unused
  )..addListener(_onGlideTick);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preloadFallback();
    _refreshMarkers();
    // ~12 fps driver for the fleet ease + running-pulse (gated to small fleets).
    _fleetTimer =
        Timer.periodic(const Duration(milliseconds: 40), (_) => _fleetAnimTick());
    // Continuous 60 fps follow ticker for the single-vehicle screen.
    if (widget.followVehicleId != null) {
      _glide.repeat();
      // Heading-up by default when following one vehicle: that is what a
      // driver expects from a navigation view, and the button is right there
      // to switch back to north-up.
      _navMode = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foreground only — stop the animation work when the app is backgrounded.
    _appActive = state == AppLifecycleState.resumed;
  }

  /// Buffer a vehicle's newest fix for the fleet playback, with the same guards
  /// the single-vehicle queue uses.
  void _enqueueFleetFix(VehicleRecord v) {
    if (v.latitude == 0 && v.longitude == 0) return;
    if (v.tsEpochMs <= 0) return; // server fix time only, never the phone clock
    final q = _fleetQueues.putIfAbsent(v.id, () => <MotionFix>[]);
    if (q.isNotEmpty && v.tsEpochMs <= q.last.ts) return;
    if (q.isNotEmpty) {
      final last = q.last;
      final meters =
          distanceMeters(last.lat, last.lng, v.latitude, v.longitude);
      final secs = (v.tsEpochMs - last.ts) / 1000.0;
      // Reconnect-aware: an implausible SHORT hop is a glitch, a long one is a
      // device flushing the backlog it buffered through a dead zone.
      if (secs > 0 &&
          meters > 150 &&
          meters < 2000 &&
          (meters / secs) * 3.6 > 220) {
        return;
      }
    }
    q.add(MotionFix(v.latitude, v.longitude, v.tsEpochMs));
    if (q.length > 60) q.removeAt(0);
  }

  void _fleetAnimTick() {
    if (!mounted || !_tickerEnabled || !_appActive) return; // idle when hidden
    if (!_fleetAnimActive) {
      // Stop interpolating, but KEEP the buffers. This gate flips when zoom
      // crosses the clustering threshold, and throwing the queues away there
      // meant every zoom out-and-back rebuilt them from nothing - the marker
      // snapped to its raw position with a visible lurch. Only the rendered
      // positions are dropped, so markers fall back to raw coordinates while
      // clustered and pick the motion straight back up on the way in.
      if (_renderedFleet.isNotEmpty) _renderedFleet.clear();
      return;
    }
    final list = _visible;
    final nowWall = DateTime.now().millisecondsSinceEpoch;
    final dt = nowWall - (_fleetLastWallMs ?? nowWall);
    _fleetLastWallMs = nowWall;
    var changed = false;

    for (final v in list) {
      _enqueueFleetFix(v);
      final q = _fleetQueues[v.id];
      if (q == null || q.isEmpty) continue;

      if (q.length == 1) {
        final only = LatLng(q.first.lat, q.first.lng);
        if (_renderedFleet[v.id] != only) {
          _renderedFleet[v.id] = only;
          changed = true;
        }
        continue;
      }

      // Same playback clock the follow view uses: paced by DEVICE fix time,
      // held a cushion behind live, and allowed to catch up so a lag can never
      // become permanent.
      var play = _fleetPlayMs[v.id] ?? (q.last.ts - _cushionMs);
      play = advancePlaybackClock(
        playMs: play,
        dtMs: dt,
        upperMs: q.last.ts - _cushionMs,
        floorMs: q.first.ts,
      );
      _fleetPlayMs[v.id] = play;

      var i = 0;
      while (i < q.length - 1 && q[i + 1].ts <= play) {
        i++;
      }
      final a = q[i];
      final b = q[i + 1 < q.length ? i + 1 : i];

      if (b.ts <= a.ts) {
        _renderedFleet[v.id] = LatLng(b.lat, b.lng);
      } else if ((a.lat - b.lat).abs() > 0.02 || (a.lng - b.lng).abs() > 0.02) {
        _renderedFleet[v.id] = LatLng(b.lat, b.lng); // teleport → snap
        _fleetPlayMs[v.id] = b.ts;
      } else {
        final f = ((play - a.ts) / (b.ts - a.ts)).clamp(0.0, 1.0);
        // CURVED, not straight. A straight lerp cuts the corner, and cutting
        // the corner IS the sideways slide through a junction.
        final p0 = i > 0 ? q[i - 1] : a;
        final p3 = (i + 2) < q.length ? q[i + 2] : b;
        final p = catmullRom(p0, a, b, p3, f);
        _renderedFleet[v.id] = LatLng(p.lat, p.lng);

        // Heading from real movement, sampled slightly ahead so the vehicle
        // noses into the turn, then eased toward that target instead of the
        // device's raw course snapping.
        if (distanceMeters(a.lat, a.lng, b.lat, b.lng) > 3) {
          final ahead = catmullRom(p0, a, b, p3, (f + 0.08).clamp(0.0, 1.0));
          final target =
              distanceMeters(p.lat, p.lng, ahead.lat, ahead.lng) > 0.5
                  ? bearingDegrees(p.lat, p.lng, ahead.lat, ahead.lng)
                  : bearingDegrees(a.lat, a.lng, b.lat, b.lng);
          final cur = _fleetBearing[v.id];
          _fleetBearing[v.id] = cur == null
              ? target
              : lerpAngle(cur, target, (dt / 240).clamp(0.0, 1.0));
        }
      }

      while (q.length > 2 && q[1].ts <= play) {
        q.removeAt(0);
      }
      changed = true;
    }

    _renderedFleet.removeWhere((id, _) => !list.any((v) => v.id == id));
    _fleetQueues.removeWhere((id, _) => !list.any((v) => v.id == id));
    _fleetPlayMs.removeWhere((id, _) => !list.any((v) => v.id == id));
    _fleetBearing.removeWhere((id, _) => !list.any((v) => v.id == id));
    final prevFrame = (_pulseTick ~/ 3) % 4;
    _pulseTick = (_pulseTick + 1) % 1000000;
    final curFrame = (_pulseTick ~/ 3) % 4;
    final hasMoving = list.any((v) => _status(v) == 'moving');
    // Rebuild on real movement, or when the pulse frame flips (~240 ms).
    if (changed || (hasMoving && prevFrame != curFrame)) {
      _refreshMarkers();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    // Depending on TickerMode registers a rebuild when this map goes off/on the
    // visible tab, so the animation ticker can idle while offstage.
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(covariant GoogleFleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshMarkers();
    if (oldWidget.focusVehicleId != widget.focusVehicleId) {
      unawaited(_centerOnFocus());
    }
    if (oldWidget.fitKey != widget.fitKey ||
        oldWidget.recenterTick != widget.recenterTick) {
      _fitDone = false;
      unawaited(_fitToFleet());
    }
    // Start/stop the follow ticker + reset the playback buffer as follow mode
    // (or the followed vehicle) changes.
    if (oldWidget.followVehicleId != widget.followVehicleId) {
      _fixQueue.clear();
      _playMs = null;
      _lastWallMs = null;
      _followRendered = null;
      _followBearing = null;
      _renderBearing = null;
      if (widget.followVehicleId != null) {
        if (!_glide.isAnimating) _glide.repeat();
      } else {
        _glide.stop();
      }
    }
    // Buffer every fresh fix for the single-vehicle playback.
    if (widget.followVehicleId != null) _enqueueFollowFix();
  }

  void _enqueueFollowFix() {
    final id = widget.followVehicleId;
    if (id == null) return;
    VehicleRecord? v;
    for (final x in _visible) {
      if (x.id == id) {
        v = x;
        break;
      }
    }
    if (v == null) return;
    if (v.latitude == 0 && v.longitude == 0) return; // invalid fix
    // Server fix time only. Falling back to the PHONE clock mixed two clocks in
    // one queue: a phone running ahead of the server stamped an entry the real
    // (older) server timestamps could never beat, and the `ts <= last.ts` guard
    // below then dropped every following fix — the marker froze for good.
    if (v.tsEpochMs <= 0) return;
    final ts = v.tsEpochMs;
    // Only buffer a genuinely newer fix (a parked poll re-sends the same ts).
    if (_fixQueue.isNotEmpty && ts <= _fixQueue.last.ts) return;
    // GPS OUTLIER FILTER: a fix implying an impossible ground speed over a
    // short interval is a glitch — drop it so the marker never teleports/wiggles.
    // Capped at 2 km: `ts` is server RECEIVE time, so a device that buffered
    // through a dead zone and dumped its backlog lands a large distance under a
    // tiny receive-time delta. That reads as an impossible speed but is a
    // genuine reconnect, and dropping it stalled the marker for the whole
    // catch-up. Past 2 km we accept and let the playback teleport-snap handle it.
    if (_fixQueue.isNotEmpty) {
      final last = _fixQueue.last;
      final meters = _distM(last.lat, last.lng, v.latitude, v.longitude);
      final secs = (ts - last.ts) / 1000.0;
      if (secs > 0 &&
          meters > 150 &&
          meters < 2000 &&
          (meters / secs) * 3.6 > 220) {
        return; // implausible short hop → GPS error
      }
    }
    _fixQueue.add(_Fix(v.latitude, v.longitude, ts));
    if (_fixQueue.length > 240) _fixQueue.removeAt(0);
  }

  static double _distM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  static double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final rLat1 = lat1 * math.pi / 180;
    final rLat2 = lat2 * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(rLat2);
    final x = math.cos(rLat1) * math.sin(rLat2) -
        math.sin(rLat1) * math.cos(rLat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _followResume?.cancel();
    _fleetTimer?.cancel();
    _glide.dispose();
    _dio.close(force: true);
    _controller?.dispose();
    super.dispose();
  }

  List<VehicleRecord> get _visible =>
      widget.vehicles.where((v) => v.hasLiveLocation).toList();

  // ── Status ──────────────────────────────────────────────────────────────
  String _status(VehicleRecord v) {
    final ts = v.tsEpochMs;
    if (ts > 0 && DateTime.now().millisecondsSinceEpoch - ts > 30 * 60 * 1000) {
      return 'offline';
    }
    if (v.isStopped) return 'stopped';
    if (v.isMoving) return 'moving';
    return 'idle';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'offline':
        return AppColors.grey;
      case 'stopped':
        return AppColors.red;
      case 'moving':
        return AppColors.green;
      default:
        return AppColors.orange;
    }
  }

  String _statusIconUrl(String iconUrl, String status) {
    final slash = iconUrl.lastIndexOf('/');
    if (slash < 0) return '';
    final dir = iconUrl.substring(0, slash);
    final file = iconUrl.substring(slash + 1);
    final dot = file.lastIndexOf('.');
    final stem = dot > 0 ? file.substring(0, dot) : file;
    return '$dir/status/${stem}_$status.png';
  }

  // ── Car marker bitmaps ────────────────────────────────────────────────────
  Future<void> _preloadFallback() async {
    try {
      // A status-coloured chevron, NOT assets/images/map.png — that asset is a
      // green folded-map illustration, so every vehicle rendered as a picture
      // of a map until its real icon downloaded.
      final raw = await buildPlaceholderVehiclePng(color: AppColors.grey);
      final png = await _composePng(raw, AppColors.grey);
      if (!mounted) return;
      _fallbackIcon = BitmapDescriptor.bytes(png, imagePixelRatio: _dpr);
      _refreshMarkers();
    } catch (_) {}
  }

  /// Car icon centred on a transparent canvas with a soft, status-coloured
  /// ground shadow beneath — the clean "on-the-road" look with just a status
  /// glow (no ring). Aspect ratio preserved so trucks/cars never squash.
  Future<Uint8List> _composePng(Uint8List raw, Color shadowColor,
      {bool selected = false, double glowScale = 1.0}) async {
    // Selected car = just a touch BIGGER (clean size emphasis) — same modest
    // shadow, so it never turns into a glowing blob. glowScale > 1 = the running
    // "pulse" frame (a subtle breathing halo).
    final iconPx = ((selected ? 60 : 52) * _dpr).round();
    final canvasPx = ((selected ? 80 : 74) * _dpr).round();

    final codec = await ui.instantiateImageCodec(raw);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = canvasPx.toDouble();
    final center = Offset(size / 2, size / 2);

    final shadowPaint = Paint()
      ..color = shadowColor.withValues(
          alpha: (0.4 * (glowScale > 1 ? 1.1 : 1.0)).clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.5 * _dpr * glowScale);
    canvas.drawCircle(
      Offset(center.dx, center.dy + (2 * _dpr)),
      (iconPx / 2) * 0.7 * glowScale,
      shadowPaint,
    );

    final srcW = image.width.toDouble();
    final srcH = image.height.toDouble();
    final longest = srcW > srcH ? srcW : srcH;
    final scale = longest > 0 ? (iconPx / longest) : 1.0;
    final dstRect = Rect.fromCenter(
      center: center,
      width: srcW * scale,
      height: srcH * scale,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, srcW, srcH),
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(canvasPx, canvasPx);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    rendered.dispose();
    return bytes!.buffer.asUint8List();
  }

  Future<void> _loadIcon(String key, String iconUrl, String status,
      bool selected,
      {double glowScale = 1.0}) async {
    final shadow = _statusColor(status);
    Uint8List? raw;
    final candidates = <String>[
      if (iconUrl.isNotEmpty) _statusIconUrl(iconUrl, status),
      if (iconUrl.isNotEmpty) iconUrl,
    ];
    for (final url in candidates) {
      if (url.isEmpty) continue;
      try {
        final resp = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = resp.data;
        if (data != null && data.isNotEmpty) {
          raw = Uint8List.fromList(data);
          break;
        }
      } catch (_) {}
    }
    // Icon still downloading (or missing on the server) — show a status-coloured
    // chevron rather than the folded-map asset the old fallback used.
    raw ??= await buildPlaceholderVehiclePng(color: shadow);
    try {
      final png = await _composePng(raw, shadow,
          selected: selected, glowScale: glowScale);
      if (!mounted) return;
      _iconCache[key] = BitmapDescriptor.bytes(png, imagePixelRatio: _dpr);
      _iconLoading.remove(key);
      _refreshMarkers();
    } catch (_) {
      _iconLoading.remove(key);
    }
  }

  // ── Registration "glass" label bitmaps ────────────────────────────────────
  /// A small frosted-glass pill with the reg text, transparent padding on top
  /// so the pill hangs just BELOW the car when anchored at (0.5, 0.0).
  Future<Uint8List> _composeLabel(String reg) async {
    final fontSize = 11.5 * _dpr;
    final padH = 8.0 * _dpr;
    final padV = 3.5 * _dpr;
    final topPad = 20.0 * _dpr; // gap so the pill sits under the car

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
    ))
      ..pushStyle(ui.TextStyle(color: const Color(0xFF14304A)))
      ..addText(reg);
    final para = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 600));
    final textW = para.maxIntrinsicWidth;
    final textH = para.height;
    para.layout(ui.ParagraphConstraints(width: textW.ceilToDouble()));

    final pillW = textW + padH * 2;
    final pillH = textH + padV * 2;
    final canvasW = pillW.ceil();
    final canvasH = (topPad + pillH).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, topPad, pillW, pillH),
      Radius.circular(pillH / 2),
    );
    // soft shadow
    canvas.drawRRect(
      pillRect.shift(Offset(0, 1.0 * _dpr)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * _dpr),
    );
    // frosted glass fill + hairline border
    canvas.drawRRect(
      pillRect,
      Paint()..color = Colors.white.withValues(alpha: 0.86),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * _dpr
        ..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawParagraph(para, Offset(padH, topPad + padV));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(canvasW, canvasH);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    return bytes!.buffer.asUint8List();
  }

  Future<void> _loadLabel(String reg) async {
    try {
      final png = await _composeLabel(reg);
      if (!mounted) return;
      _labelCache[reg] = BitmapDescriptor.bytes(png, imagePixelRatio: _dpr);
      _labelLoading.remove(reg);
      _refreshMarkers();
    } catch (_) {
      _labelLoading.remove(reg);
    }
  }

  // ── Markers ───────────────────────────────────────────────────────────────
  void _refreshMarkers() {
    final markers = <Marker>{};
    final list = _visible;
    // Fleet mode + zoomed out + enough vehicles → cluster overlapping cars.
    final doCluster = widget.followVehicleId == null &&
        _zoom < _clusterMaxZoom &&
        list.length > 10;
    if (doCluster) {
      _addClusterMarkers(markers, list);
    } else {
      for (final v in list) {
        _addVehicleMarkers(markers, v);
      }
    }
    if (!mounted) {
      _markers = markers;
      return;
    }
    setState(() => _markers = markers);
  }

  void _addVehicleMarkers(Set<Marker> markers, VehicleRecord v) {
    final status = _status(v);
    // Emphasise the selected car AND the single-vehicle followed car (bigger).
    final selected =
        widget.focusVehicleId == v.id || widget.followVehicleId == v.id;
    // Running-car breathing pulse (small fleets only): cycle 3 glow frames.
    final pulse = status == 'moving' && _fleetAnimActive && !selected;
    final glowIdx = pulse ? _glowFrame : -1;
    final glowScale = pulse ? const <double>[0.85, 1.2, 1.55][glowIdx] : 1.0;
    final key =
        '${v.vehicleIconUrl}|$status${selected ? '|sel' : ''}${pulse ? '|g$glowIdx' : ''}';
    // Never fall back to the default red pin — only a COMPOSED car bitmap.
    //
    // The running "breathing" pulse gives each vehicle THREE glow variants, and
    // each is composed lazily. Any frame whose variant was not ready yet fell
    // straight through to the grey placeholder (or skipped the marker
    // entirely), which is the blinking: at a 40 ms tick the pulse advances
    // faster than the compositor can keep up. Degrade to the SAME icon without
    // the glow first - it is effectively always cached - so the vehicle never
    // vanishes or flashes grey while a cosmetic variant is still rendering.
    final baseKey = '${v.vehicleIconUrl}|$status${selected ? '|sel' : ''}';
    final icon = _iconCache[key] ?? _iconCache[baseKey] ?? _fallbackIcon;
    if (icon == null) return;
    // Followed (single) uses the eased glide; fleet uses the fleet ease.
    final pos = (widget.followVehicleId == v.id && _followRendered != null)
        ? _followRendered!
        : (_fleetAnimActive && _renderedFleet.containsKey(v.id))
            ? _renderedFleet[v.id]!
            : LatLng(v.latitude, v.longitude);
    // In navigation mode the followed car is a BILLBOARD (flat:false) so the
    // camera tilt never foreshortens/stretches it; the heading-up map already
    // conveys direction, so it points straight up.
    final followed = widget.followVehicleId == v.id;
    // Billboard (points up-screen) is only honest while the camera is actually
    // tracking the heading. If follow is paused the map bearing is frozen, so an
    // up-pointing car would face somewhere the road does not go - draw it flat
    // on its real bearing instead.
    final navBillboard = _navMode && followed && !_followPaused;
    // Every car points along its ACTUAL movement bearing, eased. The device's
    // reported course jumps between fixes, and using it on the fleet map made
    // the icon flick round mid-slide instead of turning through the corner.
    // Falls back to the reported course until the vehicle has moved far enough
    // for movement to define a heading.
    final easedBearing = followed
        ? (_renderBearing ?? _followBearing)
        : _fleetBearing[v.id];
    final rotation = navBillboard
        ? 0.0
        : (easedBearing ?? (v.course % 360));
    markers.add(
      Marker(
        markerId: MarkerId(v.id.toString()),
        position: pos,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        rotation: rotation,
        flat: !navBillboard,
        zIndexInt: selected ? 3 : 1,
        onTap: () => widget.onVehicleTap?.call(v),
      ),
    );
    if (!_iconCache.containsKey(key) && !_iconLoading.contains(key)) {
      _iconLoading.add(key);
      unawaited(_loadIcon(key, v.vehicleIconUrl, status, selected,
          glowScale: glowScale));
    }

    // Reg-number glass label — a SECOND, non-rotating marker just below the
    // car, only when zoomed in enough to read them.
    final reg = v.registrationNumber.trim();
    if (_labelsShown && reg.isNotEmpty) {
      final labelIcon = _labelCache[reg];
      if (labelIcon != null) {
        markers.add(
          Marker(
            markerId: MarkerId('lbl_${v.id}'),
            position: pos,
            icon: labelIcon,
            anchor: const Offset(0.5, 0.0),
            flat: false,
            zIndexInt: selected ? 4 : 2,
            onTap: () => widget.onVehicleTap?.call(v),
          ),
        );
      } else if (!_labelLoading.contains(reg)) {
        _labelLoading.add(reg);
        unawaited(_loadLabel(reg));
      }
    }
  }

  void _addClusterMarkers(Set<Marker> markers, List<VehicleRecord> list) {
    // Geo-grid whose cell shrinks as you zoom in, so clusters split naturally.
    final cellDeg =
        0.9 / math.pow(2, (_zoom - 8).clamp(0, 14).toDouble()).toDouble();
    final groups = <String, List<VehicleRecord>>{};
    for (final v in list) {
      final gx = (v.latitude / cellDeg).floor();
      final gy = (v.longitude / cellDeg).floor();
      (groups['${gx}_$gy'] ??= <VehicleRecord>[]).add(v);
    }
    groups.forEach((k, g) {
      if (g.length == 1) {
        _addVehicleMarkers(markers, g.first);
        return;
      }
      var lat = 0.0, lng = 0.0;
      for (final v in g) {
        lat += v.latitude;
        lng += v.longitude;
      }
      final centroid = LatLng(lat / g.length, lng / g.length);
      final count = g.length;
      final icon = _clusterCache[count];
      if (icon != null) {
        markers.add(
          Marker(
            markerId: MarkerId('cluster_$k'),
            position: centroid,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 5,
            onTap: () async {
              final c = _controller;
              if (c == null) return;
              try {
                await c.animateCamera(CameraUpdate.newLatLngZoom(
                    centroid, (_zoom + 2.5).clamp(3, 20).toDouble()));
              } catch (_) {}
            },
          ),
        );
      } else if (!_clusterLoading.contains(count)) {
        // Not composed yet → trigger it, skip this frame (no red-pin flash).
        _clusterLoading.add(count);
        unawaited(_loadCluster(count));
      }
    });
  }

  Future<Uint8List> _composeCluster(int count) async {
    final label = count > 99 ? '99+' : '$count';
    final diameter = ((count > 9 ? 52 : 46) * _dpr);
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: 15 * _dpr,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    ))
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText(label);
    final para = builder.build()
      ..layout(ui.ParagraphConstraints(width: diameter));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(diameter / 2, diameter / 2);
    final inner = diameter / 2 - 4 * _dpr;
    // Soft outer glow.
    canvas.drawCircle(
      c,
      diameter / 2,
      Paint()
        ..color = AppTheme.primaryBlue.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _dpr),
    );
    // Glossy radial-gradient fill (lighter top-left → deep blue).
    final grad = ui.Gradient.radial(
      Offset(c.dx - inner * 0.3, c.dy - inner * 0.35),
      inner * 1.4,
      <Color>[const Color(0xFF5B93CC), AppTheme.primaryBlue],
    );
    canvas.drawCircle(c, inner, Paint()..shader = grad);
    // Crisp white ring.
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * _dpr
        ..color = Colors.white,
    );
    canvas.drawParagraph(para, Offset(0, c.dy - para.height / 2));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(diameter.ceil(), diameter.ceil());
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    return bytes!.buffer.asUint8List();
  }

  Future<void> _loadCluster(int count) async {
    try {
      final png = await _composeCluster(count);
      if (!mounted) return;
      _clusterCache[count] = BitmapDescriptor.bytes(png, imagePixelRatio: _dpr);
      _clusterLoading.remove(count);
      _refreshMarkers();
    } catch (_) {
      _clusterLoading.remove(count);
    }
  }

  // ── Camera ────────────────────────────────────────────────────────────────
  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    await _fitToFleet();
    // Nav mode is the default when following one vehicle, but its pitch and
    // zoom are only applied on TOGGLE now that the follow camera preserves
    // whatever the user has set. Without this the default view opened flat and
    // north-up while the button read as active.
    if (widget.followVehicleId != null && _navMode) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final target = _followRendered ?? _firstFollowedPosition();
      if (!mounted || target == null) return;
      _markProgrammatic(900);
      try {
        await controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: 17,
            tilt: 55,
            bearing: _renderBearing ?? _followBearing ?? 0,
          ),
        ));
      } catch (_) {}
    }
  }

  /// Position of the followed vehicle straight from the data, for the first
  /// frame before the playback buffer has produced anything.
  LatLng? _firstFollowedPosition() {
    for (final v in _visible) {
      if (v.id == widget.followVehicleId) {
        return LatLng(v.latitude, v.longitude);
      }
    }
    return null;
  }

  void _onCameraMove(CameraPosition pos) {
    final wasClustering = widget.followVehicleId == null &&
        _zoom < _clusterMaxZoom &&
        _visible.length > 10;
    _zoom = pos.zoom;
    _tilt = pos.tilt;
    final nowClustering = widget.followVehicleId == null &&
        _zoom < _clusterMaxZoom &&
        _visible.length > 10;
    final show = _zoom >= _labelMinZoom;
    if (show != _labelsShown || wasClustering != nowClustering) {
      _labelsShown = show;
      _refreshMarkers();
    }
  }

  Future<void> _fitToFleet() async {
    final controller = _controller;
    if (controller == null || _fitDone) return;
    final pts = _visible
        .map((v) => LatLng(v.latitude, v.longitude))
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();
    if (pts.isEmpty) return;
    _fitDone = true;
    _markProgrammatic(900); // animateCamera below
    if (pts.length == 1) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(pts.first, 15),
        );
      } catch (_) {}
      return;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(_bounds(pts), 60),
      );
    } catch (_) {}
  }

  LatLngBounds _bounds(List<LatLng> pts) {
    var south = pts.first.latitude;
    var north = pts.first.latitude;
    var west = pts.first.longitude;
    var east = pts.first.longitude;
    for (final p in pts) {
      south = p.latitude < south ? p.latitude : south;
      north = p.latitude > north ? p.latitude : north;
      west = p.longitude < west ? p.longitude : west;
      east = p.longitude > east ? p.longitude : east;
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  Future<void> _centerOnFocus() async {
    final controller = _controller;
    final id = widget.focusVehicleId;
    if (controller == null || id == null) return;
    VehicleRecord? focus;
    for (final v in _visible) {
      if (v.id == id) {
        focus = v;
        break;
      }
    }
    if (focus == null) return;
    _markProgrammatic(900); // animateCamera below
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(focus.latitude, focus.longitude)),
      );
    } catch (_) {}
  }

  // ── Single-vehicle continuous follow ──────────────────────────────────────
  // Runs every frame (~60 fps): ease the rendered pose a fraction toward the
  // latest fix, and move the camera to match. Because it always chases the
  // freshest target, the marker + map glide continuously with no start/stop
  // jerk — the Google-Maps navigation feel.
  void _onGlideTick() {
    if (widget.followVehicleId == null || !_tickerEnabled || !_appActive) return;
    final q = _fixQueue;
    if (q.isEmpty) return;
    if (q.length == 1) {
      _followRendered = LatLng(q.first.lat, q.first.lng);
      _refreshMarkers();
      unawaited(_followCamera());
      return;
    }

    final nowWall = DateTime.now().millisecondsSinceEpoch;
    // Seed at the NEWEST fix, not the oldest. Devices buffer during a GSM gap
    // and then dump several fixes at once, so the queue can span minutes the
    // moment the screen opens. Starting at q.first replayed that whole backlog
    // at 1x — the marker crawled through minutes-old positions while the real
    // vehicle was streets away.
    _playMs ??= q.last.ts - _cushionMs;
    final dt = nowWall - (_lastWallMs ?? nowWall);
    _lastWallMs = nowWall;
    // Stay a fixed cushion behind the newest fix; never run past it.
    final upper = q.last.ts - _cushionMs;
    // Clock advance + catch-up — see advancePlaybackClock in map_motion.dart,
    // where the behaviour is unit-tested.
    _playMs = advancePlaybackClock(
      playMs: _playMs!,
      dtMs: dt,
      upperMs: upper,
      floorMs: q.first.ts,
    );

    // Segment [a,b] bracketing the playback clock.
    var i = 0;
    while (i < q.length - 1 && q[i + 1].ts <= _playMs!) {
      i++;
    }
    final a = q[i];
    final b = q[i + 1 < q.length ? i + 1 : i];
    if (b.ts <= a.ts) {
      _followRendered = LatLng(b.lat, b.lng);
    } else if ((a.lat - b.lat).abs() > 0.02 || (a.lng - b.lng).abs() > 0.02) {
      // Teleport (reconnect / glitch): snap across the gap, don't crawl.
      _followRendered = LatLng(b.lat, b.lng);
      _playMs = b.ts;
    } else {
      final f = ((_playMs! - a.ts) / (b.ts - a.ts)).clamp(0.0, 1.0);
      // Curved (Catmull-Rom) interpolation using the fixes either side of the
      // segment. A straight lerp cuts the corner, which is exactly the
      // "sideways slide" through a junction — the marker leaves the road and
      // slides diagonally to the next fix. The spline arcs through the turn
      // instead. p0/p3 fall back to the segment ends at the queue edges, where
      // Catmull-Rom degenerates to the old straight line.
      final p0 = i > 0 ? q[i - 1] : a;
      final p3 = (i + 2) < q.length ? q[i + 2] : b;
      _followRendered = _catmullRom(p0, a, b, p3, f);
      // Heading from ACTUAL movement (accurate; device course can be noisy).
      // Sampled slightly ahead on the same curve so the icon points where it is
      // about to go — the car noses into the corner like a real vehicle.
      // Hold the last heading while effectively stationary so a parked car
      // doesn't spin.
      if (_distM(a.lat, a.lng, b.lat, b.lng) > 3) {
        final ahead = _catmullRom(p0, a, b, p3, (f + 0.08).clamp(0.0, 1.0));
        final here = _followRendered!;
        _followBearing = _distM(here.latitude, here.longitude,
                    ahead.latitude, ahead.longitude) >
                0.5
            ? _bearing(
                here.latitude, here.longitude, ahead.latitude, ahead.longitude)
            : _bearing(a.lat, a.lng, b.lat, b.lng);
      }
    }

    // Ease the DRAWN heading toward the target instead of snapping. ~240 ms to
    // close the gap keeps a turn readable without lagging the actual motion.
    final target = _followBearing;
    if (target != null) {
      final cur = _renderBearing;
      _renderBearing =
          cur == null ? target : lerpAngle(cur, target, (dt / 240).clamp(0.0, 1.0));
    }

    // Drop fixes we've fully played past (keep the current segment start).
    while (_fixQueue.length > 2 && _fixQueue[1].ts <= _playMs!) {
      _fixQueue.removeAt(0);
    }

    _refreshMarkers();
    unawaited(_followCamera());
  }

  /// Curved position along the segment — see [catmullRom] in map_motion.dart,
  /// where the behaviour is unit-tested.
  static LatLng _catmullRom(_Fix p0, _Fix p1, _Fix p2, _Fix p3, double t) {
    final p = catmullRom(
      MotionFix(p0.lat, p0.lng, p0.ts),
      MotionFix(p1.lat, p1.lng, p1.ts),
      MotionFix(p2.lat, p2.lng, p2.ts),
      MotionFix(p3.lat, p3.lng, p3.ts),
      t,
    );
    return LatLng(p.lat, p.lng);
  }

  Future<void> _followCamera() async {
    final controller = _controller;
    if (controller == null || widget.followVehicleId == null || _followPaused) {
      return;
    }
    final target = _followRendered;
    if (target == null) return;
    _markProgrammatic(120); // instant moveCamera below
    try {
      // moveCamera (instant) not animateCamera: the pose is ALREADY eased per
      // frame, so animating on top would fight itself and stutter.
      if (_navMode) {
        // Navigation mode: 3D tilt + heading-up (map rotates to travel dir),
        // using the accurate movement bearing when we have it.
        // Same eased heading the marker uses, so the map doesn't swing round
        // faster than the car appears to turn.
        double bearing = _renderBearing ?? _followBearing ?? 0;
        if ((_renderBearing ?? _followBearing) == null) {
          for (final x in _visible) {
            if (x.id == widget.followVehicleId) {
              bearing = x.course % 360;
              break;
            }
          }
        }
        // Carry the user's CURRENT zoom and tilt through, never a fixed pair.
        // Hard-coding zoom 17 / tilt 55 here re-applied them 60 times a second,
        // so a pinch-zoom was yanked back on the very next frame - the map
        // fought the gesture and the vehicle lurched out of view.
        await controller.moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: _zoom,
            tilt: _tilt,
            bearing: bearing,
          ),
        ));
      } else {
        await controller.moveCamera(CameraUpdate.newLatLng(target));
      }
    } catch (_) {}
  }

  void _toggleNavMode() {
    setState(() => _navMode = !_navMode);
    final controller = _controller;
    final target = _followRendered;
    if (controller == null || target == null) return;
    _markProgrammatic(900); // animateCamera below
    // Pitch and zoom are applied ONCE here, on the way in and on the way out.
    // The per-frame follow camera deliberately carries whatever the user has
    // since set (see _followCamera) so it never fights a pinch.
    try {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        _navMode
            ? CameraPosition(
                target: target,
                zoom: 17,
                tilt: 55,
                bearing: _renderBearing ?? _followBearing ?? 0,
              )
            : CameraPosition(target: target, zoom: 15, tilt: 0, bearing: 0),
      ));
    } catch (_) {}
  }

  Future<void> _openThemePicker() async {
    final options = <List<String>>[
      <String>['default', 'Default'],
      <String>['dark', 'Night'],
      <String>['retro', 'Retro'],
      <String>['satellite', 'Satellite'],
      <String>['terrain', 'Terrain'],
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 14),
            const Text('Map style',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final o in options)
              ListTile(
                leading: Icon(
                  _mapTheme == o[0]
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _mapTheme == o[0] ? AppTheme.primaryBlue : Colors.grey,
                ),
                title: Text(o[1],
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, o[0]),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _mapTheme = picked);
  }

  Future<void> _shareSnapshot() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final bytes = await controller.takeSnapshot();
      if (bytes == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/vc_location_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(<XFile>[XFile(file.path)],
          text: 'Vehicle location');
    } catch (_) {}
  }

  void _onCameraMoveStarted() {
    if (_programmaticMove || widget.followVehicleId == null) return;
    // A real user gesture → pause follow, resume after they stop exploring.
    _followPaused = true;
    _followResume?.cancel();
    _followResume = Timer(const Duration(seconds: 8), () {
      _followPaused = false;
      if (mounted) unawaited(_followCamera());
    });
  }

  void _onCameraIdle() {
    // Re-group clusters for the settled zoom (grid cells depend on zoom).
    if (widget.followVehicleId == null && _visible.length > 10) {
      _refreshMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _visible.isNotEmpty
        ? LatLng(_visible.first.latitude, _visible.first.longitude)
        : _defaultCenter;
    final polylines = <Polyline>{};
    if (widget.trailPoints.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('trail'),
          points: widget.trailPoints,
          color: AppTheme.primaryBlue.withValues(alpha: 0.75),
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }
    return Stack(
      children: <Widget>[
        GoogleMap(
          initialCameraPosition: CameraPosition(target: first, zoom: 11),
          // Default theme = null style = FULL-detail Google map; dark/retro
          // themes apply a style (only meaningful on the normal base map).
          style: _resolvedMapType == MapType.normal ? _resolvedStyle : null,
          onMapCreated: _onMapCreated,
          onCameraMove: _onCameraMove,
          onCameraMoveStarted: _onCameraMoveStarted,
          onCameraIdle: _onCameraIdle,
          markers: _markers,
          polylines: polylines,
          // Keep the fit-bounds framing + Google logo clear of the top counts
          // bar and bottom controls/card, so nothing hides under the overlays.
          padding: EdgeInsets.only(
            top: widget.followVehicleId == null ? 56 : 12,
            bottom: 24,
          ),
          onTap: (_) => widget.onMapTap?.call(),
          mapType: _resolvedMapType,
          trafficEnabled: _traffic,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
          },
        ),
        // Map controls: theme picker, live traffic, snapshot-share, and (single
        // vehicle) 3D navigation mode.
        Positioned(
          top: 62,
          right: 12,
          child: Column(
            children: <Widget>[
              _MapCtrlButton(
                icon: Icons.layers_outlined,
                active: _mapTheme != 'default',
                onTap: _openThemePicker,
              ),
              const SizedBox(height: 8),
              _MapCtrlButton(
                icon: Icons.traffic_outlined,
                active: _traffic,
                onTap: () => setState(() => _traffic = !_traffic),
              ),
              const SizedBox(height: 8),
              _MapCtrlButton(
                icon: Icons.ios_share,
                active: false,
                onTap: _shareSnapshot,
              ),
              if (widget.followVehicleId != null) ...<Widget>[
                const SizedBox(height: 8),
                _MapCtrlButton(
                  icon: Icons.navigation,
                  active: _navMode,
                  onTap: _toggleNavMode,
                ),
              ],
            ],
          ),
        ),
        // Empty state — fleet mode with no locatable vehicles.
        if (widget.followVehicleId == null && _visible.isEmpty)
          const IgnorePointer(child: _EmptyMapOverlay()),
      ],
    );
  }
}

class _EmptyMapOverlay extends StatelessWidget {
  const _EmptyMapOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: (theme.cardTheme.color ?? theme.cardColor)
              .withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.location_off_outlined,
                size: 30, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              'No vehicles to show',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Live vehicles will appear here',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular map-control button (satellite / traffic).
class _MapCtrlButton extends StatelessWidget {
  const _MapCtrlButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: active ? AppTheme.primaryBlue : (theme.cardTheme.color ?? theme.cardColor),
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 20,
            color: active ? Colors.white : AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }
}
