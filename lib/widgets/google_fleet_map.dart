import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/models/nearby_poi_model.dart';
import 'package:fleet_monitor/repositorys/poi_repository.dart';
import 'package:fleet_monitor/widgets/native_vehicle_map.dart' show MapStopPin;
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/widgets/map_motion.dart';
import 'package:fleet_monitor/widgets/marker_placeholder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';

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
    this.trailSpeeds = const <double>[],
    this.stops = const <MapStopPin>[],
    this.bottomInset = 0,
  });

  /// Height of any overlay the HOST draws across the bottom of this map.
  ///
  /// The full-screen view lays a glass vehicle bar over the map, and it was
  /// tall enough to swallow the Re-centre chip whole — the chip appeared on the
  /// inline preview and seemed simply missing on full screen. Google's logo and
  /// attribution live down there too and must not be covered either.
  final double bottomInset;

  final List<VehicleRecord> vehicles;

  /// Single-vehicle mode: when set, the camera continuously follows this
  /// vehicle (until the user pans, then resumes) and [trailPoints] draws its
  /// route line — the same live-tracking behaviour as the web map.
  final int? followVehicleId;

  /// Route/trail polyline points (single-vehicle mode). Empty = no line.
  final List<LatLng> trailPoints;

  /// Optional per-point speeds (km/h), index-aligned with [trailPoints].
  /// When present, the trail is drawn in speed colours — green under 30,
  /// amber to 60, red above — so the line itself tells the story of the
  /// drive. Empty keeps the classic single blue line.
  final List<double> trailSpeeds;

  /// Route stops drawn as small azure pins with their name in the info
  /// window — the child's whole route reads at a glance.
  final List<MapStopPin> stops;

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
    // Google's reference "Night" palette: navy grounds, clearly readable
    // roads and labels. The old #212121 flat dark hid the roads entirely —
    // the owner called it unprofessional, and he was right.
    '[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},'
    '{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},'
    '{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},'
    '{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},'
    '{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},'
    '{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},'
    '{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},'
    '{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},'
    '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},'
    '{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},'
    '{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},'
    '{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},'
    '{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]}]';

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

  /// Which way the map itself is facing. Together with [_tilt] this is the ONE
  /// source of truth for how the followed vehicle must be drawn — see
  /// _addVehicleMarkers.
  double _mapBearing = 0;

  /// Zoom and tilt the FOLLOW camera last commanded.
  ///
  /// The follow move passes the current zoom and tilt straight back, so it can
  /// never change them. If onCameraMove then reports a different zoom, a finger
  /// did it — no timing involved. Deciding this by a programmatic-move deadline
  /// did not work: the deadline was longer than the interval it was re-armed
  /// on, so it never lapsed and every pinch looked like our own move.
  double _commandedZoom = 11;
  double _commandedTilt = 0;
  bool _labelsShown = false;

  // User map controls: theme (default|dark|retro|satellite|terrain), traffic,
  // and single-vehicle navigation mode (3D tilt + heading-up).
  String _mapTheme = 'default';
  bool _traffic = false;

  // ── Roadside POI layer (petrol / speed cameras / tolls) ──────────────────
  // Single-vehicle mode only: it answers "what is on MY route", and a fleet
  // view drowned in fuel pumps helps nobody. Fetched around the vehicle,
  // refreshed when it travels far enough that the old circle is behind it.
  bool _poiOn = false;
  Set<Marker> _poiMarkers = <Marker>{};
  LatLng? _poiCenter;
  bool _poiFetching = false;
  final Map<String, BitmapDescriptor> _poiIconCache = <String, BitmapDescriptor>{};
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

  // Keys whose cached bitmap is only the chevron PLACEHOLDER because the real
  // icon download failed (weak signal). Tracked so (a) the marker can borrow
  // any REAL variant of the same vehicle icon instead of flashing the chevron
  // every time the status flips, and (b) the download is retried — otherwise
  // one bad fetch left a vehicle as an arrow forever.
  final Set<String> _iconPlaceholderKeys = <String>{};
  final Map<String, DateTime> _iconRetryAt = <String, DateTime>{};

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

  // ── Route line ────────────────────────────────────────────────────────────
  // Two faults lived here. The line was drawn straight between fixes ~8 s apart
  // while the marker rode a spline, so the car left its own line at every
  // corner; and it ran right up to the newest RAW fix while the marker renders
  // a cushion behind, so the blue line stuck out past the nose and grew in
  // 8-second jumps ahead of the vehicle.
  //
  // It is also rebuilt from scratch on every setState, which at the old tick
  // rate meant re-serializing 300+ points across the platform channel sixty
  // times a second. Now it is cached: re-smoothed only when the source points
  // change, re-clipped only once the car has moved far enough to see.
  Set<Polyline> _polylines = <Polyline>{};
  List<_TrailRun> _trailRuns = const <_TrailRun>[];
  int _trailSourceLen = -1;
  LatLng? _trailSourceLast;
  LatLng? _trailDrawnAt;
  static const double _trailRebuildMeters = 2.0;

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
  Timer? _fleetTimer;

  bool get _fleetAnimActive =>
      widget.followVehicleId == null &&
      _visible.isNotEmpty &&
      _visible.length <= _fleetAnimMax &&
      !(_zoom < _clusterMaxZoom && _visible.length > 10); // not while clustering

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

  /// While a deliberate animateCamera owns the camera, the per-frame follow
  /// must not touch it.
  ///
  /// This is what made head-up look broken. _toggleNavMode animates to tilt 55;
  /// the animation reports its intermediate tilts through onCameraMove, so
  /// _tilt became 3, then 7, then 11 - and the follow camera, running at 30 Hz
  /// with `tilt: _tilt`, issued a moveCamera at 11 that CANCELLED the animation
  /// and pinned the map there. Within a frame or two of pressing the button the
  /// camera was flat and north-up again while the button sat lit. The button
  /// was never the problem; the follow loop was overwriting it.
  int _cameraLockUntilMs = 0;
  bool get _cameraLocked =>
      DateTime.now().millisecondsSinceEpoch < _cameraLockUntilMs;
  void _lockCamera(int ms) {
    final until = DateTime.now().millisecondsSinceEpoch + ms;
    if (until > _cameraLockUntilMs) _cameraLockUntilMs = until;
    _markProgrammatic(ms);
  }

  bool _followPaused = false;
  Timer? _followResume;

  // Single-vehicle SMOOTH PLAYBACK: buffer incoming fixes and replay the marker
  // through them at real pace, a small cushion behind live — so it glides along
  // the ACTUAL route at the vehicle's real speed with no jerk or corner-cutting
  // (the "hold data + animate" model the operator asked for). A 60 fps ticker
  // drives it.
  /// Marker + camera pushes are rate-limited to this, independently of the
  /// ticker.
  ///
  /// The glide ticker runs at the display refresh rate — 60 Hz, and 120 Hz on
  /// the newer phones — and every tick called _refreshMarkers (a setState that
  /// rebuilds the whole map subtree and re-sends the marker set) plus a
  /// moveCamera. Both cross the platform channel. Two hundred serialized
  /// round-trips a second is far past what google_maps_flutter is built for:
  /// the Android side falls behind, and what the customer sees is a vehicle
  /// that stutters and skips instead of gliding. THIS is the jank, not the
  /// motion maths.
  ///
  /// The maths still runs every tick, so the path stays exact. Only the push is
  /// throttled — 30 Hz is smoother than the device's 8-second reporting will
  /// ever justify.
  static const int _pushIntervalMs = 33;
  int _lastPushMs = 0;

  /// Movement below these is invisible on screen, so it is not worth a rebuild.
  /// A parked vehicle used to re-push its unchanged marker at the full refresh
  /// rate forever — burning battery and channel bandwidth to draw nothing.
  static const double _pushMinMeters = 0.15;
  static const double _pushMinDegrees = 0.25;
  LatLng? _pushedPos;
  double? _pushedBearing;

  /// Map bearing at the last push. The followed car's on-screen rotation is
  /// heading minus this, so the map turning under a STOPPED vehicle changes how
  /// the icon must be drawn even though the vehicle itself has not moved — the
  /// exact case a head-up toggle on a parked vehicle exercises.
  double _pushedMapBearing = 0;

  // ── Dead reckoning ────────────────────────────────────────────────────────
  // Owner recording, 2026-07-26: gaps between fixes ran 5, 5, 7, 7, 10, 13 and
  // 15 seconds. At 73 km/h the 13-second gap is 264 metres, and the marker held
  // still for every one of them before jumping. The playback clock may not run
  // past the newest fix, so once the queue empties there is nothing left to
  // interpolate and it simply stops.
  //
  // Rather than widen the cushion (a 15 s one would leave the vehicle 300 m
  // behind — the opposite complaint), we keep it rolling on its last heading
  // and speed while the queue is dry, and slide it back onto the truth when the
  // next fix lands.
  int _coastStartMs = 0;
  LatLng? _coastAnchor;
  double _coastBearing = 0;
  double _coastMps = 0;

  /// Leftover correction from the last coast, decaying to zero.
  double _reconcileLat = 0;
  double _reconcileLng = 0;
  int _reconcileAtMs = 0;

  LatLng? _followRendered;
  double? _followBearing; // heading computed from actual movement (accurate)
  /// Heading actually drawn. Chases [_followBearing] a few degrees per frame
  /// instead of snapping, so a corner reads as the car turning rather than the
  /// icon flicking round while it slides sideways across the junction.
  double? _renderBearing;
  final List<_Fix> _fixQueue = <_Fix>[];
  int? _playMs; // virtual playback clock (epoch ms), stays cushion-behind live
  int? _lastWallMs;

  /// Gaps between the last few fixes, newest last — feeds [adaptiveCushionMs].
  final List<int> _fixIntervals = <int>[];

  /// Cushion actually in force, and the size we are easing it toward.
  ///
  /// These are separate because the cushion sets the playback clock's ceiling
  /// (`newest fix - cushion`). Widening it in one step lowers that ceiling under
  /// a clock already past it, and the clamp then drags the marker BACKWARDS —
  /// up to ~47 m at 60 km/h the first time the estimate settles. Easing at a
  /// fraction of real time means the marker briefly runs slow instead, which
  /// nobody can see.
  int _cushionMs = kMinCushionMs;
  int _cushionTargetMs = kMinCushionMs;
  static const double _cushionEaseRate = 0.3;
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1), // cadence only; value is unused
  )..addListener(_onGlideTick);

  @override
  void initState() {
    super.initState();
    LocalStorage.readValue('map_traffic_on').then((v) {
      if (mounted && v == '1' && !_traffic) setState(() => _traffic = true);
    });
    LocalStorage.readValue('map_poi_on').then((v) {
      if (mounted && v == '1' && !_poiOn) {
        setState(() => _poiOn = true);
        _refreshMarkers();
      }
    });
    // Map style: whatever the user last chose, nothing more. Auto-night was
    // tried and pulled the same day — the owner's verdict on seeing it was
    // that a map which turns near-black on its own looks broken, not
    // professional. Dark stays strictly an explicit choice in the picker.
    LocalStorage.readValue('map_theme').then((saved) {
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty && saved != _mapTheme) {
        setState(() => _mapTheme = saved);
      }
    });
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
    if (q.isNotEmpty) _noteFixInterval(v.tsEpochMs - q.last.ts);
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
    // Rebuild on real movement ONLY. The old "breathing pulse" also rebuilt
    // every ~240 ms with a DIFFERENT bitmap per frame for moving vehicles —
    // and swapping a Google marker's icon redraws it, which on real phones
    // read as the icon rapidly blinking. The status glow baked into the
    // bitmap carries the "alive" look without any frame cycling.
    if (changed) {
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
    _rebuildTrail();
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
    if (_fixQueue.isNotEmpty) _noteFixInterval(ts - _fixQueue.last.ts);
    _fixQueue.add(_Fix(v.latitude, v.longitude, ts));
    if (_fixQueue.length > 240) _fixQueue.removeAt(0);
  }

  /// Learn how often this fleet's devices actually report, and size the render
  /// cushion to it. Backlog dumps after a dead zone are excluded — those are a
  /// reconnect, not a reporting rate.
  void _noteFixInterval(int gapMs) {
    if (gapMs <= 0 || gapMs > 60000) return;
    _fixIntervals.add(gapMs);
    if (_fixIntervals.length > 20) _fixIntervals.removeAt(0);
    _cushionTargetMs = adaptiveCushionMs(_fixIntervals);
  }

  /// Move the live cushion toward its target by at most a fraction of the frame
  /// time, so the playback ceiling never drops out from under the clock.
  void _easeCushion(int dtMs) {
    if (_cushionMs == _cushionTargetMs || dtMs <= 0) return;
    final step = (dtMs * _cushionEaseRate).ceil();
    if (_cushionTargetMs > _cushionMs) {
      _cushionMs = math.min(_cushionTargetMs, _cushionMs + step);
    } else {
      _cushionMs = math.max(_cushionTargetMs, _cushionMs - step);
    }
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
  /// Delegates to the single rule in VehicleRecord. This used to reimplement it
  /// with a 30-minute offline window, which put every vehicle silent for 8-30
  /// minutes on the `idle` fallthrough: orange, claiming an idling engine on a
  /// device that had gone quiet.
  String _status(VehicleRecord v) => v.statusKey;

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
      {bool selected = false}) async {
    // Selected car = just a touch BIGGER (clean size emphasis) — same modest
    // shadow, so it never turns into a glowing blob.
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
      ..color = shadowColor.withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.5 * _dpr);
    canvas.drawCircle(
      Offset(center.dx, center.dy + (2 * _dpr)),
      (iconPx / 2) * 0.7,
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
      bool selected) async {
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
    final downloadFailed = raw == null;
    raw ??= await buildPlaceholderVehiclePng(color: shadow);
    try {
      final png = await _composePng(raw, shadow, selected: selected);
      if (!mounted) return;
      _iconCache[key] = BitmapDescriptor.bytes(png, imagePixelRatio: _dpr);
      if (downloadFailed) {
        // Remember this is only the chevron and try the real file again in a
        // while — networks come back; the marker shouldn't stay an arrow.
        _iconPlaceholderKeys.add(key);
        _iconRetryAt[key] = DateTime.now().add(const Duration(seconds: 30));
      } else {
        _iconPlaceholderKeys.remove(key);
        _iconRetryAt.remove(key);
      }
      _iconLoading.remove(key);
      _refreshMarkers();
    } catch (_) {
      _iconLoading.remove(key);
    }
  }

  /// The best bitmap available for this vehicle RIGHT NOW: the exact
  /// status/glow variant if it's real, else the base variant, else ANY
  /// already-downloaded variant of the SAME vehicle icon (a green bike beats
  /// a chevron while the red one downloads), else the shared fallback. This
  /// is what stops the marker flip-flopping between the bike and an arrow
  /// every time the status changes on a weak connection.
  BitmapDescriptor? _bestIcon(String iconUrl, String key, String baseKey) {
    final exact = _iconCache[key];
    if (exact != null && !_iconPlaceholderKeys.contains(key)) return exact;
    final base = _iconCache[baseKey];
    if (base != null && !_iconPlaceholderKeys.contains(baseKey)) return base;
    if (iconUrl.isNotEmpty) {
      final prefix = '$iconUrl|';
      for (final entry in _iconCache.entries) {
        if (entry.key.startsWith(prefix) &&
            !_iconPlaceholderKeys.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    return exact ?? base ?? _fallbackIcon;
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

  /// POI marker art, drawn once per type and cached. The petrol pump is a
  /// real little pump — red body, screen, fuel drop, nozzle and hose —
  /// modelled on the reference art the owner picked, because his verdict on
  /// the generic glyph-in-a-circle was "unprofessional". Everything renders
  /// at 4x and DISPLAYS at ~30 dp: the first version passed raw pixels as
  /// logical pixels and covered half the city in orange.
  Future<BitmapDescriptor> _composePoiIcon(String type,
      {String label = ''}) async {
    const double c = 120; // canvas px; display width set on the descriptor
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (type == 'fuel') {
      // Name plate: painted below the pump at 4x, so at display scale it is
      // a ~9.5dp label. White halo keeps it readable on every map style.
      TextPainter? labelTp;
      double canvasW = c;
      const double labelBlock = 46; // fixed, so the anchor stays constant
      if (label.isNotEmpty) {
        labelTp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 560);
        canvasW = math.max(c, labelTp.width + 16);
      }
      // Centre the pump art on the (possibly wider) canvas.
      canvas.save();
      canvas.translate((canvasW - c) / 2, 0);
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
      canvas.drawRRect(
          RRect.fromLTRBR(16, 100, 104, 114, const Radius.circular(6)),
          shadow);
      canvas.drawRRect(
          RRect.fromLTRBR(14, 94, 90, 110, const Radius.circular(7)),
          Paint()..color = const Color(0xFF37424E));
      final body = RRect.fromLTRBR(22, 10, 82, 96, const Radius.circular(12));
      canvas.drawRRect(
          body,
          Paint()
            ..shader = ui.Gradient.linear(
                const Offset(22, 10), const Offset(82, 96), <Color>[
              const Color(0xFFEF5350),
              const Color(0xFFC62828),
            ]));
      canvas.drawRRect(
          RRect.fromLTRBR(32, 20, 72, 44, const Radius.circular(6)),
          Paint()
            ..shader = ui.Gradient.linear(
                const Offset(32, 20), const Offset(72, 44), <Color>[
              const Color(0xFF80DEEA),
              const Color(0xFF1E88E5),
            ]));
      final drop = Path()
        ..moveTo(52, 52)
        ..quadraticBezierTo(66, 70, 60, 80)
        ..arcToPoint(const Offset(44, 80),
            radius: const Radius.circular(9), clockwise: true)
        ..quadraticBezierTo(38, 70, 52, 52)
        ..close();
      canvas.drawPath(drop, Paint()..color = const Color(0xFFFFA726));
      canvas.drawRRect(
          RRect.fromLTRBR(84, 22, 104, 40, const Radius.circular(5)),
          Paint()..color = const Color(0xFFB71C1C));
      final hose = Path()
        ..moveTo(98, 40)
        ..quadraticBezierTo(112, 66, 96, 94);
      canvas.drawPath(
          hose,
          Paint()
            ..color = const Color(0xFF37424E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
      canvas.restore();

      double canvasH = c;
      if (labelTp != null) {
        canvasH = c + labelBlock;
        final tx = (canvasW - labelTp.width) / 2;
        const ty = c + 6;
        // Halo first: same text stroked in white behind the fill.
        final halo = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w700,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 8
                ..color = Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 560);
        halo.paint(canvas, Offset(tx, ty));
        labelTp.paint(canvas, Offset(tx, ty));
      }

      final img = await recorder
          .endRecording()
          .toImage(canvasW.toInt(), canvasH.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      // Display size derives from the canvas so the pump stays 30dp tall
      // whether or not a name plate widened the bitmap.
      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
          width: canvasW / 4);
    }

    final IconData glyph =
        type == 'speed_camera' ? Icons.photo_camera : Icons.toll;
    final Color fill = type == 'speed_camera'
        ? const Color(0xFFDC2626)
        : const Color(0xFF6D28D9);
    const center = Offset(c / 2, c / 2);
    canvas.drawCircle(
        center.translate(0, 3),
        c / 2 - 8,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5));
    canvas.drawCircle(center, c / 2 - 8, Paint()..color = Colors.white);
    canvas.drawCircle(center, c / 2 - 13, Paint()..color = fill);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontSize: c * 0.48,
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    final img = await recorder.endRecording().toImage(c.toInt(), c.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 24);
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
    if (_poiOn && widget.vehicles.length == 1) {
      markers.addAll(_poiMarkers);
      _maybeFetchPois();
    }
    for (final st in widget.stops) {
      markers.add(Marker(
        markerId: MarkerId('stop_${st.lat}_${st.lng}'),
        position: LatLng(st.lat, st.lng),
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        alpha: 0.9,
        anchor: const Offset(0.5, 1.0),
        zIndexInt: 0,
        infoWindow: InfoWindow(title: st.label),
      ));
    }
    if (!mounted) {
      _markers = markers;
      return;
    }
    setState(() => _markers = markers);
  }

  Future<void> _maybeFetchPois() async {
    final v = widget.vehicles.isNotEmpty ? widget.vehicles.first : null;
    if (v == null || (v.latitude == 0 && v.longitude == 0)) return;
    final here = LatLng(v.latitude, v.longitude);
    if (_poiFetching) return;
    final c = _poiCenter;
    if (c != null &&
        distanceMeters(c.latitude, c.longitude, here.latitude, here.longitude) <
            3000) {
      return; // old circle still covers us
    }
    _poiFetching = true;
    try {
      final pois = await PoiRepository().fetchNearby(
        lat: here.latitude,
        lng: here.longitude,
        types: const <String>['fuel', 'speed_camera', 'toll_booth'],
        radiusKm: 8,
        limit: 40,
      );
      if (!mounted) return;
      String labelFor(String t) => t == 'fuel'
          ? 'Petrol Pump'
          : (t == 'speed_camera' ? 'Speed Camera' : 'Toll Plaza');
      // Real coloured badges (a pump IS a pump), not Google's generic
      // teardrop — and anchored dead-centre on the POI's coordinate, so the
      // badge sits ON the spot instead of pointing at it from above, which
      // read as "the pump is in the wrong place".
      // Named pumps carry their name INTO the bitmap (Google markers can't
      // label text any other way), so the key is per-name, not per-type.
      // The cache is bounded: a long drive past many stations would
      // otherwise grow it without limit; recomposing is cheap.
      if (_poiIconCache.length > 80) _poiIconCache.clear();
      String keyFor(NearbyPoi poi) =>
          poi.poiType == 'fuel' && poi.name.isNotEmpty
              ? 'fuel|${poi.name}'
              : poi.poiType;
      for (final NearbyPoi poi in pois) {
        _poiIconCache[keyFor(poi)] ??= await _composePoiIcon(
          poi.poiType,
          label: poi.poiType == 'fuel' ? poi.name : '',
        );
      }
      if (!mounted) return;
      _poiCenter = here;
      _poiMarkers = <Marker>{
        for (final NearbyPoi poi in pois)
          Marker(
            markerId: MarkerId('poi_${poi.poiType}_${poi.lat}_${poi.lng}'),
            position: LatLng(poi.lat, poi.lng),
            icon: _poiIconCache[keyFor(poi)] ?? BitmapDescriptor.defaultMarker,
            // Pump stands ON the spot (base at the coordinate); with a name
            // plate below, the base sits proportionally higher in the
            // bitmap. The small discs sit centred.
            anchor: poi.poiType == 'fuel'
                ? (poi.name.isNotEmpty
                    ? const Offset(0.5, 0.66)
                    : const Offset(0.5, 0.92))
                : const Offset(0.5, 0.5),
            zIndexInt: 0,
            infoWindow: InfoWindow(
              title: poi.name.isNotEmpty ? poi.name : labelFor(poi.poiType),
              snippet: labelFor(poi.poiType),
            ),
          ),
      };
      if (_poiOn) _refreshMarkers();
    } catch (_) {
      // Roadside extras are a nicety — never surface an error for them.
    } finally {
      _poiFetching = false;
    }
  }

  void _addVehicleMarkers(Set<Marker> markers, VehicleRecord v) {
    final status = _status(v);
    // Emphasise the selected car AND the single-vehicle followed car (bigger).
    final selected =
        widget.focusVehicleId == v.id || widget.followVehicleId == v.id;
    // ONE steady bitmap per icon+status+selection. The old breathing pulse
    // cycled three glow bitmaps per moving vehicle and every swap redrew the
    // marker — on real phones that was the icon visibly blinking. Never fall
    // back to the default red pin — only a COMPOSED car bitmap.
    final key = '${v.vehicleIconUrl}|$status${selected ? '|sel' : ''}';
    final icon = _bestIcon(v.vehicleIconUrl, key, key);
    if (icon == null) return;
    // Followed (single) uses the eased glide; fleet uses the fleet ease.
    final pos = (widget.followVehicleId == v.id && _followRendered != null)
        ? _followRendered!
        : (_fleetAnimActive && _renderedFleet.containsKey(v.id))
            ? _renderedFleet[v.id]!
            : LatLng(v.latitude, v.longitude);
    final followed = widget.followVehicleId == v.id;

    // How the followed car is drawn is decided by the CAMERA, not by the nav
    // flags. Billboard-or-flat used to depend on _navMode && followed &&
    // !_followPaused, and rotation assumed the map was already turned to the
    // heading. Those are four things that must agree, and during a head-up
    // toggle they briefly do not: the flags said "flat" while the camera was
    // still pitched at 55, so the icon was laid on the tilted ground plane and
    // came out foreshortened into a squashed smear. That is the "shape goes
    // wrong after toggling head-up off and on".
    //
    // Tilt and bearing cannot disagree with themselves. A pitched camera means
    // billboard, always. And screen-space rotation is heading MINUS the map's
    // own bearing, which is correct whatever the map is doing — turned to the
    // heading (rotation lands on 0, car points up-screen), north-up, paused,
    // or mid-animation between any two of them.
    final tilted = _tilt > 15;
    final navBillboard = followed && tilted;
    // Every car points along its ACTUAL movement bearing, eased. The device's
    // reported course jumps between fixes, and using it on the fleet map made
    // the icon flick round mid-slide instead of turning through the corner.
    // Falls back to the reported course until the vehicle has moved far enough
    // for movement to define a heading.
    final easedBearing = followed
        ? (_renderBearing ?? _followBearing)
        : _fleetBearing[v.id];
    final heading = easedBearing ?? (v.course % 360);
    final rotation =
        navBillboard ? ((heading - _mapBearing) % 360 + 360) % 360 : heading;
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
    // Load when missing — or RE-load when what we cached was only the
    // placeholder and its retry window has passed.
    final placeholderDue = _iconPlaceholderKeys.contains(key) &&
        !(_iconRetryAt[key]?.isAfter(DateTime.now()) ?? false);
    if ((!_iconCache.containsKey(key) || placeholderDue) &&
        !_iconLoading.contains(key)) {
      _iconLoading.add(key);
      unawaited(_loadIcon(key, v.vehicleIconUrl, status, selected));
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
    // Single-vehicle: go STRAIGHT to the nav pose. This used to fit the fleet
    // first (animating to zoom 15, flat and north-up), wait 400 ms, then
    // animate again to zoom 17 with the 3D pitch — so opening a vehicle showed
    // three separate camera moves before it settled. One move, one settle.
    if (widget.followVehicleId != null) {
      final target = _followRendered ?? _firstFollowedPosition();
      if (target == null) return;
      _fitDone = true; // a later fit would yank the camera off the vehicle
      _lockCamera(600);
      try {
        await controller.moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: _navMode ? 17 : 15,
            tilt: _navMode ? 55 : 0,
            bearing: _navMode ? _navBearing() : 0,
          ),
        ));
      } catch (_) {}
      return;
    }
    await _fitToFleet();
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
    // A pinch or a two-finger tilt changed the pose. Our own follow move never
    // can — it hands back the zoom and tilt it was given — so a difference here
    // is a finger, and follow must get out of the way. This is the check that
    // actually holds: the programmatic-move deadline never lapsed, so gestures
    // were being attributed to us and overwritten on the next push.
    if (_cameraLocked) {
      // One of our own animations is flying the camera to a new pose. Track it
      // so that the instant the lock lifts these already agree with reality —
      // otherwise the first frame afterwards reads as a gesture and pauses
      // follow every time the user toggles head-up or re-centres.
      _commandedZoom = pos.zoom;
      _commandedTilt = pos.tilt;
    } else if (widget.followVehicleId != null && !_followPaused) {
      final zoomed = (pos.zoom - _commandedZoom).abs() > 0.01;
      final tilted = (pos.tilt - _commandedTilt).abs() > 0.5;
      if (zoomed || tilted) {
        _pauseFollowForGesture();
      }
    }
    _zoom = pos.zoom;
    _tilt = pos.tilt;
    _mapBearing = pos.bearing;
    final nowClustering = widget.followVehicleId == null &&
        _zoom < _clusterMaxZoom &&
        _visible.length > 10;
    final show = _zoom >= _labelMinZoom;
    if (show != _labelsShown || wasClustering != nowClustering) {
      _labelsShown = show;
      _refreshMarkers();
    }
    // The map turning or pitching changes how the followed car must be drawn
    // even when the car itself is stationary. Without this a parked vehicle
    // kept its old rotation through the whole head-up animation and only
    // corrected on the next fix — which for a parked vehicle is minutes away.
    // _pushPose carries the 33 ms throttle, so an animation cannot flood it.
    if (widget.followVehicleId != null) _pushPose();
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
    _lockCamera(900); // animateCamera below
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
    _lockCamera(900); // animateCamera below
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
  /// Re-smooth the trail when its source points change, and re-clip it to the
  /// vehicle once the vehicle has moved far enough for the tip to shift
  /// visibly. Cheap on most calls; the expensive resample runs once per fix.
  void _rebuildTrail() {
    final src = widget.trailPoints;
    if (src.length < 2) {
      if (_polylines.isNotEmpty) {
        _polylines = <Polyline>{};
        _trailRuns = const <_TrailRun>[];
        _trailSourceLen = -1;
        _trailSourceLast = null;
        _trailDrawnAt = null;
      }
      return;
    }

    // The parent rebuilds this list every frame, so identity tells us nothing —
    // length plus the newest point is what actually changes when a fix lands.
    final sourceChanged =
        src.length != _trailSourceLen || src.last != _trailSourceLast;
    if (sourceChanged) {
      _trailSourceLen = src.length;
      _trailSourceLast = src.last;
      final speeds = widget.trailSpeeds;
      if (speeds.length == src.length && speeds.isNotEmpty) {
        // Split into consecutive same-colour runs BEFORE smoothing; each run
        // starts on the previous run's last point so the line stays joined.
        int bucket(double kmh) => kmh <= 30 ? 0 : (kmh <= 60 ? 1 : 2);
        final runs = <_TrailRun>[];
        var runStart = 0;
        var runBucket = bucket(speeds[0]);
        for (var i = 1; i <= src.length; i++) {
          final b = i < src.length ? bucket(speeds[i]) : -99;
          if (b != runBucket) {
            final from = runStart == 0 ? 0 : runStart - 1; // joint point
            runs.add(_TrailRun(
              runBucket,
              smoothPath(<MotionPoint>[
                for (var j = from; j < i; j++)
                  MotionPoint(src[j].latitude, src[j].longitude),
              ]),
            ));
            runStart = i;
            runBucket = b;
          }
        }
        _trailRuns = runs;
      } else {
        _trailRuns = <_TrailRun>[
          _TrailRun(
            -1,
            smoothPath(<MotionPoint>[
              for (final p in src) MotionPoint(p.latitude, p.longitude),
            ]),
          ),
        ];
      }
    }

    final car = _followRendered;
    if (!sourceChanged && car != null && _trailDrawnAt != null) {
      final moved = distanceMeters(_trailDrawnAt!.latitude,
          _trailDrawnAt!.longitude, car.latitude, car.longitude);
      if (moved < _trailRebuildMeters) return;
    }

    if (_trailRuns.isEmpty) {
      _polylines = <Polyline>{};
      return;
    }

    Color colourFor(int bucket) {
      switch (bucket) {
        case 0:
          return const Color(0xCC2FA719); // easy — brand green
        case 1:
          return const Color(0xDDF59E0B); // brisk — amber
        case 2:
          return const Color(0xE6DC2626); // fast — red
        default:
          return AppTheme.primaryBlue.withValues(alpha: 0.75);
      }
    }

    final polys = <Polyline>{};
    for (var r = 0; r < _trailRuns.length; r++) {
      final run = _trailRuns[r];
      final isLast = r == _trailRuns.length - 1;
      List<LatLng> pts;
      if (isLast && car != null) {
        // Cut the FINAL run where the vehicle actually is and finish it at
        // the nose, so the trail can never lead the car it belongs to.
        final cut = nearestIndexFromEnd(run.pts, car.latitude, car.longitude);
        pts = <LatLng>[
          for (var i = 0; i <= cut; i++) LatLng(run.pts[i].lat, run.pts[i].lng),
          car,
        ];
        _trailDrawnAt = car;
      } else {
        pts = <LatLng>[for (final p in run.pts) LatLng(p.lat, p.lng)];
      }
      if (pts.length < 2) continue;
      polys.add(Polyline(
        polylineId: PolylineId('trail_$r'),
        points: pts,
        color: colourFor(run.bucket),
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }
    _polylines = polys;
  }

  /// Push the freshly-computed pose to the map, but only if it moved enough to
  /// see and only at [_pushIntervalMs]. Everything above this line is pure
  /// maths; everything below crosses the platform channel.
  void _pushPose({bool force = false}) {
    final pos = _followRendered;
    if (pos == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force) {
      if (nowMs - _lastPushMs < _pushIntervalMs) return;
      final prev = _pushedPos;
      final prevBearing = _pushedBearing;
      final bearing = _renderBearing ?? _followBearing;
      final moved = prev == null ||
          distanceMeters(prev.latitude, prev.longitude, pos.latitude,
                  pos.longitude) >
              _pushMinMeters;
      final turned = bearing != null &&
          (prevBearing == null ||
              angleDeltaDegrees(prevBearing, bearing) > _pushMinDegrees);
      final mapTurned =
          angleDeltaDegrees(_pushedMapBearing, _mapBearing) > _pushMinDegrees;
      if (!moved && !turned && !mapTurned) return;
    }
    _lastPushMs = nowMs;
    _pushedPos = pos;
    _pushedBearing = _renderBearing ?? _followBearing;
    _pushedMapBearing = _mapBearing;
    _rebuildTrail();
    _refreshMarkers();
    unawaited(_followCamera());
  }

  void _onGlideTick() {
    if (widget.followVehicleId == null || !_tickerEnabled || !_appActive) return;
    final q = _fixQueue;
    if (q.isEmpty) return;
    if (q.length == 1) {
      _followRendered = LatLng(q.first.lat, q.first.lng);
      _pushPose();
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
    _easeCushion(dt);
    // Stay a cushion behind the newest fix; never run past it. The cushion is
    // sized to how often this device actually reports (see adaptiveCushionMs):
    // a fixed 1800 ms was smaller than the arrival jitter on these ~8 s
    // devices, so playback kept hitting the ceiling and the marker froze until
    // the next packet landed — stop, jump, stop, jump.
    final upper = q.last.ts - _cushionMs;

    // Queue dry: nothing left to interpolate, so keep rolling on the last known
    // heading and speed instead of standing still for the length of the gap.
    // The segment pace alone is not enough to justify coasting. A vehicle that
    // pulls up and parks leaves a last segment still showing 40 km/h, and a
    // parked device only reports every five minutes — so the queue goes dry and
    // we would drive a stationary car 150 m down the road before dragging it
    // back. The device's own current speed has to agree that it is moving.
    final canCoast = _coastMps * 3.6 >= kMinCoastKmh &&
        _followedReportedSpeed() >= kMinCoastKmh;
    if (_playMs! >= upper && canCoast) {
      if (_coastAnchor == null) {
        _coastAnchor = _followRendered;
        _coastStartMs = nowWall;
      }
      final anchor = _coastAnchor;
      if (anchor != null) {
        final coastedMs = nowWall - _coastStartMs;
        if (coastedMs <= kMaxCoastMs) {
          final p = projectAhead(anchor.latitude, anchor.longitude,
              _coastBearing, _coastMps * coastedMs / 1000.0);
          _followRendered = _withReconcile(p.lat, p.lng, nowWall);
        }
        // Past the bound we HOLD the last coasted position. Falling through
        // would recompute from a still-dry queue, which renders the last real
        // fix — fourteen seconds of travel BEHIND where the vehicle is drawn —
        // and the reconcile would then slide it backwards down the road. A
        // stopped marker is bad; one that reverses is worse.
        _pushPose();
        return;
      }
    }

    if (_coastAnchor != null) {
      // A real fix arrived. Carry the gap between where we guessed the vehicle
      // was and where it actually is as a decaying offset, so the marker slides
      // onto the truth rather than teleporting onto it.
      final guessed = _followRendered;
      _coastAnchor = null;
      _coastStartMs = 0;
      if (guessed != null) {
        _reconcileAtMs = nowWall;
        _reconcileLat = guessed.latitude;
        _reconcileLng = guessed.longitude;
      }
    }

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

    // Remember the pace of the segment we are on, so that when the queue runs
    // dry we can carry the vehicle forward at the speed it was actually doing
    // rather than the speed the device last claimed.
    if (b.ts > a.ts) {
      final segMps =
          _distM(a.lat, a.lng, b.lat, b.lng) / ((b.ts - a.ts) / 1000.0);
      if (segMps.isFinite && segMps >= 0 && segMps < 60) _coastMps = segMps;
    }
    _coastBearing = _renderBearing ?? _followBearing ?? _coastBearing;

    final rendered = _followRendered;
    if (rendered != null) {
      _followRendered =
          _withReconcile(rendered.latitude, rendered.longitude, nowWall);
    }

    // Drop fixes we've fully played past (keep the current segment start).
    while (_fixQueue.length > 2 && _fixQueue[1].ts <= _playMs!) {
      _fixQueue.removeAt(0);
    }

    _pushPose();
  }

  /// Blend the leftover dead-reckoning correction into a position.
  ///
  /// At the instant a fix lands the factor is 1, so the marker is drawn exactly
  /// where the coast had put it — no jump. It decays to 0 over kReconcileMs, by
  /// which point the marker is on the real position.
  LatLng _withReconcile(double lat, double lng, int nowMs) {
    if (_reconcileAtMs == 0) return LatLng(lat, lng);
    final f = reconcileFactor(nowMs - _reconcileAtMs);
    if (f <= 0) {
      _reconcileAtMs = 0;
      return LatLng(lat, lng);
    }
    return LatLng(
      lat + (_reconcileLat - lat) * f,
      lng + (_reconcileLng - lng) * f,
    );
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
    // An animation (head-up toggle, re-centre, first open) owns the camera —
    // stay off it until that settles, or we cancel it mid-flight.
    if (_cameraLocked) return;
    final target = _followRendered;
    if (target == null) return;
    // 20 ms, NOT 120. This runs every _pushIntervalMs (33 ms), so a 120 ms mark
    // was re-extended before it could ever expire — the "programmatic" window
    // stayed permanently open while following a moving vehicle, and
    // _onCameraMoveStarted therefore read EVERY real pinch as our own move and
    // never paused follow. The gesture was then overwritten 33 ms later. That
    // is the zoom that would not take.
    _markProgrammatic(20);
    // Remember the pose we are about to command, so _onCameraMove can tell our
    // own move from the user's by what actually changed rather than by timing.
    _commandedZoom = _zoom;
    _commandedTilt = _tilt;
    try {
      // moveCamera (instant) not animateCamera: the pose is ALREADY eased per
      // frame, so animating on top would fight itself and stutter.
      if (_navMode) {
        // Navigation mode: 3D tilt + heading-up (map rotates to travel dir),
        // using the accurate movement bearing when we have it.
        // Same eased heading the marker uses, so the map doesn't swing round
        // faster than the car appears to turn.
        final bearing = _navBearing();
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
    final target = _followRendered ?? _firstFollowedPosition();
    if (controller == null || target == null) return;
    // Hold the follow camera off for the length of the animation. Without this
    // the animation's own intermediate tilts came back through onCameraMove and
    // the 30 Hz follow move re-applied them, cancelling the animation a frame
    // after it started — button lit, map still flat and north-up.
    _lockCamera(1100);
    try {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        _navMode
            ? CameraPosition(
                target: target,
                zoom: 17,
                tilt: 55,
                bearing: _navBearing(),
              )
            : CameraPosition(target: target, zoom: 15, tilt: 0, bearing: 0),
      ));
    } catch (_) {}
  }

  /// Speed the device last reported for the followed vehicle, km/h.
  double _followedReportedSpeed() {
    for (final x in _visible) {
      if (x.id == widget.followVehicleId) return x.speed;
    }
    return 0;
  }

  /// Heading for the nav pose. A stopped vehicle has no movement bearing, so
  /// fall back to the course the device last reported — pointing the map the
  /// way the vehicle is actually parked beats defaulting to north.
  double _navBearing() {
    final moved = _renderBearing ?? _followBearing;
    if (moved != null) return moved;
    for (final x in _visible) {
      if (x.id == widget.followVehicleId) return x.course % 360;
    }
    return 0;
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
            Text(AppStrings.of(context).t('map_style'),
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
    if (picked != null && mounted) {
      setState(() => _mapTheme = picked);
      // An EXPLICIT choice — remembered, and it permanently opts this user
      // out of the automatic night style below (picking 'default' included:
      // that is the user saying "always normal", not "decide for me").
      LocalStorage.setValue('map_theme', picked);
    }
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
    _pauseFollowForGesture();
  }

  /// Stand down so we never fight a finger.
  ///
  /// Reached two ways: a pan, via onCameraMoveStarted, and a pinch or tilt, via
  /// the pose comparison in _onCameraMove — which is the reliable one, since a
  /// gesture that changes the zoom cannot be mistaken for our own move.
  ///
  /// Auto-resume stays as a safety net, but the Re-centre chip is the real
  /// answer: for eight seconds the map used to look frozen with nothing on
  /// screen to say why, and then snap back on its own while the user was still
  /// reading it.
  void _pauseFollowForGesture() {
    if (!_followPaused && mounted) setState(() => _followPaused = true);
    _followResume?.cancel();
    _followResume = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _followPaused = false);
      unawaited(_followCamera());
    });
  }

  /// Return the camera to the vehicle and resume following it.
  void _recenterOnVehicle() {
    _followResume?.cancel();
    setState(() => _followPaused = false);
    final controller = _controller;
    final target = _followRendered ?? _firstFollowedPosition();
    if (controller == null || target == null) return;
    _lockCamera(900);
    try {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: _zoom,
          tilt: _tilt,
          bearing: _navMode ? _navBearing() : 0,
        ),
      ));
    } catch (_) {}
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
    // Built in _rebuildTrail, not here: a fresh Polyline over 300+ points on
    // every rebuild re-crossed the platform channel for a line that had not
    // changed.
    final polylines = _polylines;
    return Stack(
      children: <Widget>[
        GoogleMap(
          // Seed the FIRST frame at the pose we actually want. Opening at
          // zoom 11 and correcting in onMapCreated meant the customer saw a
          // wide regional view flash up before it dived to the vehicle.
          initialCameraPosition: widget.followVehicleId != null
              ? CameraPosition(
                  target: _followRendered ?? _firstFollowedPosition() ?? first,
                  zoom: _navMode ? 17 : 15,
                  tilt: _navMode ? 55 : 0,
                )
              : CameraPosition(target: first, zoom: 11),
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
            bottom: 24 + widget.bottomInset,
          ),
          onTap: (_) => widget.onMapTap?.call(),
          mapType: _resolvedMapType,
          trafficEnabled: _traffic,
          // No 3D building blocks. buildingsEnabled defaults to TRUE, and the
          // moment head-up mode tilts the camera (55 deg) Google extrudes every
          // structure into beige slabs that bury the roads and the vehicle —
          // the owner reported the map "filling up with buildings". Navigation
          // apps keep the tilted view flat for exactly this reason.
          buildingsEnabled: false,
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
                onTap: () {
                  setState(() => _traffic = !_traffic);
                  // Remembered across screens and app restarts — a layer the
                  // user turned on should not silently turn itself off.
                  LocalStorage.setValue('map_traffic_on', _traffic ? '1' : '0');
                },
              ),
              if (widget.vehicles.length == 1) ...<Widget>[
                const SizedBox(height: 8),
                _MapCtrlButton(
                  icon: Icons.local_gas_station_outlined,
                  active: _poiOn,
                  onTap: () {
                    setState(() => _poiOn = !_poiOn);
                    LocalStorage.setValue('map_poi_on', _poiOn ? '1' : '0');
                    if (_poiOn) {
                      _poiCenter = null; // force a fresh fetch around the car
                    }
                    _refreshMarkers();
                  },
                ),
              ],
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
        // Follow is paused after a manual pan, and there was no way to say so
        // and no way to undo it — the camera just sat there for eight seconds
        // and then yanked itself back. Now the state is visible and the user
        // decides when to return.
        if (widget.followVehicleId != null && _followPaused)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + widget.bottomInset,
            child: Center(
              child: Material(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(20),
                elevation: 3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _recenterOnVehicle,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.my_location, size: 15, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Re-centre',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

/// One same-colour stretch of the smoothed trail (bucket -1 = classic blue).
class _TrailRun {
  const _TrailRun(this.bucket, this.pts);
  final int bucket;
  final List<MotionPoint> pts;
}
