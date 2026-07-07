import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Live vehicle map rendered with **MapLibre GL Native** vector tiles from
/// **OpenFreeMap** — completely free: no API key, no billing account, no
/// sign-up. This is the "professional, Google-Maps-look, smooth, no
/// tile-refresh" map the operator asked for, without any paid service:
///   • Vector tiles → pinch-zoom is continuous and never re-tiles / goes
///     blurry the way the old raster (flutter_map) layers did.
///   • Markers are "3D-on-the-road" car icons: the vehicle's own icon baked
///     into a bitmap with a soft ground shadow, laid on the map and rotated
///     to its heading, so it looks like it is actually driving, top-down.
///   • Position changes glide via an eased lerp (no teleporting) and the
///     camera follows the focused vehicle until the user pans/zooms.
///
/// No native API keys are required (OpenFreeMap needs none). For maximum
/// reliability in production the OpenFreeMap style/tiles can later be
/// self-hosted on the existing server and [_styleUrl] pointed at it.
class NativeVehicleMap extends StatefulWidget {
  const NativeVehicleMap({
    super.key,
    required this.vehicles,
    this.focusVehicle,
    this.trailPoints = const <ll.LatLng>[],
    this.emptyTitle = 'No vehicles mapped yet',
    this.emptySubtitle = 'Live map will appear once a vehicle is tracked',
    this.followFocusedVehicle = false,
    this.animateMarkers = true,
    this.moveAnimationDuration = const Duration(milliseconds: 900),
    this.onVehicleTap,
    this.mapProvider = 'maplibre',
  });

  final List<VehicleRecord> vehicles;
  final VehicleRecord? focusVehicle;
  final List<ll.LatLng> trailPoints;
  final String emptyTitle;
  final String emptySubtitle;
  final bool followFocusedVehicle;
  final bool animateMarkers;

  /// How long a marker takes to glide from its current rendered position to a
  /// freshly received position. The single-vehicle detail map keeps the snappy
  /// 900 ms default; the home overview passes ~the poll interval (e.g. 4.5 s)
  /// so the marker is *always* gliding — it re-targets from the current
  /// interpolated point on each poll, giving continuous motion with no
  /// visible move-then-freeze.
  final Duration moveAnimationDuration;

  /// Called when a vehicle marker is tapped. Host screen typically opens a
  /// bottom sheet showing the vehicle's address (via LiveAddressText so it
  /// matches the list cell), speed, last-update time and a Track button.
  final void Function(VehicleRecord vehicle)? onVehicleTap;

  /// Map style from superadmin Settings → "Default Map Engine". Both options
  /// now render through MapLibre's smooth vector renderer; the value only
  /// picks the OpenFreeMap base style — 'satellite'/'dark' → the "positron"
  /// muted style, anything else → the colourful, Google-like "liberty" style.
  final String mapProvider;

  @override
  State<NativeVehicleMap> createState() => _NativeVehicleMapState();
}

class _NativeVehicleMapState extends State<NativeVehicleMap>
    with SingleTickerProviderStateMixin {
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);
  static const String _fallbackImageName = 'veh_fallback';
  static const double _epsilon = 0.0000015;

  final Dio _dio = Dio();
  MapLibreMapController? _controller;
  bool _styleReady = false;

  /// Registered MapLibre image names (one per distinct vehicle-icon URL).
  final Set<String> _registeredImages = <String>{};

  /// vehicleId → live Symbol on the map.
  final Map<int, Symbol> _symbols = <int, Symbol>{};

  /// vehicleIds whose Symbol is mid-creation, so we never add twice.
  final Set<int> _addingSymbols = <int>{};

  /// Last geometry actually pushed to a symbol — lets us skip channel chatter
  /// for parked vehicles during the animation loop.
  final Map<int, LatLng> _lastPushed = <int, LatLng>{};

  Line? _trailLine;

  final Map<int, LatLng> _renderedPositions = <int, LatLng>{};
  Map<int, LatLng> _animationStart = <int, LatLng>{};
  Map<int, LatLng> _animationEnd = <int, LatLng>{};

  /// Heading (course) is interpolated alongside position so turns glide
  /// instead of snapping at each SSE packet — the "really driving" feel.
  final Map<int, double> _renderedCourse = <int, double>{};
  Map<int, double> _courseStart = <int, double>{};
  Map<int, double> _courseEnd = <int, double>{};
  final Map<int, double> _lastPushedCourse = <int, double>{};

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: widget.moveAnimationDuration,
  )..addListener(_handleAnimationTick);

  double _dpr = 2.0;
  bool _rebuildBusy = false;
  bool _rebuildDirty = false;

  LatLng? _lastCameraTarget;
  /// Flips true the first time the user pans / pinch-zooms. Once set, the
  /// camera stops auto-recentering so we never fight the user's gesture.
  bool _userInteracted = false;
  // Pending auto-resume of camera follow after the user stops touching the
  // map (see _onCameraIdle). Cancelled by any new gesture and on dispose.
  Timer? _followResumeTimer;
  /// Guards camera moves we trigger ourselves so they aren't mistaken for a
  /// user gesture in [_onCameraMove].
  bool _programmaticMove = false;
  bool _initialFitDone = false;

  String get _styleUrl {
    switch (widget.mapProvider) {
      case 'satellite':
      case 'dark':
        return 'https://tiles.openfreemap.org/styles/positron';
      default:
        return 'https://tiles.openfreemap.org/styles/liberty';
    }
  }

  @override
  void initState() {
    super.initState();
    _seedInitialPositions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
  }

  @override
  void didUpdateWidget(covariant NativeVehicleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Keep the glide length in sync if the caller changes it at runtime.
    if (oldWidget.moveAnimationDuration != widget.moveAnimationDuration) {
      _animationController.duration = widget.moveAnimationDuration;
    }

    // A new vehicle to follow → allow the camera to recentre on it once.
    if (oldWidget.focusVehicle?.id != widget.focusVehicle?.id) {
      _userInteracted = false;
    }

    if (_styleReady) {
      _rebuild();
      _animateToLatestPositions();
    }
  }

  @override
  void dispose() {
    _followResumeTimer?.cancel();
    _animationController.dispose();
    // Release the map controller listener + the Dio client so the disposed
    // State isn't retained via the controller's listener list and the
    // underlying HttpClient is freed (this widget mounts on Home + every
    // detail screen — leaks would accumulate).
    _controller?.onSymbolTapped.remove(_handleSymbolTapped);
    _controller = null;
    _dio.close(force: true);
    super.dispose();
  }

  // ── Vehicle helpers ────────────────────────────────────────────────────

  List<VehicleRecord> get _visibleVehicles {
    return widget.vehicles.where((vehicle) => vehicle.hasLiveLocation).toList();
  }

  bool get _hasVisibleVehicles => _visibleVehicles.isNotEmpty;

  LatLng _toLatLng(VehicleRecord vehicle) {
    return LatLng(vehicle.latitude, vehicle.longitude);
  }

  String _imageName(VehicleRecord vehicle) {
    final url = vehicle.vehicleIconUrl.trim();
    return url.isEmpty ? _fallbackImageName : 'veh_${url.hashCode}';
  }

  LatLng _lerpLatLng(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + ((end.latitude - start.latitude) * t),
      start.longitude + ((end.longitude - start.longitude) * t),
    );
  }

  double _manhattan(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() + (a.longitude - b.longitude).abs();
  }

  /// Shortest-path angle interpolation (handles the 350°→10° wrap) so the car
  /// turns the short way and never spins all the way around.
  double _lerpAngle(double start, double end, double t) {
    var delta = (end - start) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    var result = (start + delta * t) % 360;
    if (result < 0) result += 360;
    return result;
  }

  /// Target heading for a vehicle this update. Keeps the last rendered heading
  /// while stopped so a parked car holds its orientation instead of snapping
  /// to north.
  double _targetCourse(VehicleRecord vehicle) {
    if (vehicle.isMoving) {
      return vehicle.course % 360;
    }
    return _renderedCourse[vehicle.id] ?? (vehicle.course % 360);
  }

  /// Subtle 3D camera pitch for the single focused vehicle — reveals the
  /// liberty style's built-in 3D buildings for a premium, Google-tracking
  /// look. The multi-vehicle fleet overview stays flat top-down.
  double _focusTilt() {
    return widget.followFocusedVehicle && widget.focusVehicle != null
        ? 45.0
        : 0.0;
  }

  double _zoomLevel() {
    if (widget.focusVehicle?.hasLiveLocation == true) {
      return 16.5;
    }
    if (_visibleVehicles.length > 1) {
      return 11.2;
    }
    if (_visibleVehicles.length == 1) {
      return 14.8;
    }
    return 5.0;
  }

  LatLng? _centerPoint() {
    final focus = widget.focusVehicle;
    if (focus != null && focus.hasLiveLocation) {
      return _renderedPositions[focus.id] ?? _toLatLng(focus);
    }
    if (_visibleVehicles.isEmpty) {
      return null;
    }
    final points = _visibleVehicles.map(_toLatLng).toList();
    final avgLat =
        points.map((point) => point.latitude).reduce((a, b) => a + b) /
            points.length;
    final avgLng =
        points.map((point) => point.longitude).reduce((a, b) => a + b) /
            points.length;
    return LatLng(avgLat, avgLng);
  }

  void _seedInitialPositions() {
    _renderedPositions
      ..clear()
      ..addEntries(
        _visibleVehicles.map(
          (vehicle) => MapEntry<int, LatLng>(vehicle.id, _toLatLng(vehicle)),
        ),
      );
    _renderedCourse
      ..clear()
      ..addEntries(
        _visibleVehicles.map(
          (vehicle) => MapEntry<int, double>(vehicle.id, vehicle.course % 360),
        ),
      );
  }

  // ── Map / style lifecycle ──────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onSymbolTapped.add(_handleSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    _styleReady = true;

    // Vehicle markers must always be visible — never hidden by MapLibre's
    // default label/icon collision detection.
    await controller.setSymbolIconAllowOverlap(true);
    await controller.setSymbolIconIgnorePlacement(true);

    await _rebuild();

    if (!mounted || _controller == null) {
      return;
    }

    if (widget.followFocusedVehicle) {
      final target = _focusTarget();
      if (target != null) {
        _programmaticMove = true;
        _lastCameraTarget = target;
        // Animate to a pitched camera so the 3D buildings stand up (premium
        // navigation look). moveCamera follow later preserves this tilt.
        await _controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: target,
              zoom: _zoomLevel(),
              tilt: _focusTilt(),
            ),
          ),
        );
      }
    } else {
      await _fitToVehicles();
    }
  }

  // ── Marker bitmaps ─────────────────────────────────────────────────────

  Future<void> _ensureImages(List<VehicleRecord> vehicles) async {
    final controller = _controller;
    if (controller == null || !_styleReady) {
      return;
    }

    // Always have the fallback registered first.
    if (!_registeredImages.contains(_fallbackImageName)) {
      final bytes = await _composeIconBytes('');
      if (!mounted || _controller == null) {
        return;
      }
      await _controller!.addImage(_fallbackImageName, bytes);
      _registeredImages.add(_fallbackImageName);
    }

    for (final vehicle in vehicles) {
      final name = _imageName(vehicle);
      if (_registeredImages.contains(name)) {
        continue;
      }
      final bytes = await _composeIconBytes(vehicle.vehicleIconUrl.trim());
      if (!mounted || _controller == null) {
        return;
      }
      await _controller!.addImage(name, bytes);
      _registeredImages.add(name);
    }
  }

  Future<Uint8List> _composeIconBytes(String url) async {
    Uint8List raw;
    try {
      if (url.isEmpty) {
        raw = (await rootBundle.load('assets/images/map.png'))
            .buffer
            .asUint8List();
      } else {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        raw = (data == null || data.isEmpty)
            ? (await rootBundle.load('assets/images/map.png'))
                .buffer
                .asUint8List()
            : Uint8List.fromList(data);
      }
    } catch (_) {
      raw =
          (await rootBundle.load('assets/images/map.png')).buffer.asUint8List();
    }
    return _renderMarkerPng(raw);
  }

  /// Draws the icon bytes centered on a transparent canvas with a soft,
  /// near-circular ground shadow beneath. The shadow is kept circular on
  /// purpose: because the marker rotates with heading (iconRotate), an
  /// elliptical shadow would visibly spin, whereas a circle reads as a
  /// natural grounding shadow at any rotation. Composited at the device
  /// pixel ratio so it stays crisp on hi-dpi screens (iconSize = 1.0).
  Future<Uint8List> _renderMarkerPng(Uint8List raw) async {
    final iconPx = (40 * _dpr).round();
    final canvasPx = (54 * _dpr).round();

    // Decode at the icon's NATIVE size so we know its true aspect ratio. The
    // old code forced targetWidth == targetHeight, which squashed every
    // non-square vehicle sprite into a square (the "stretched vehicle" bug).
    final codec = await ui.instantiateImageCodec(raw);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = canvasPx.toDouble();
    final center = Offset(size / 2, size / 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 * _dpr);
    canvas.drawCircle(
      Offset(center.dx, center.dy + (3 * _dpr)),
      (iconPx / 2) * 0.6,
      shadowPaint,
    );

    // Fit the icon INSIDE the iconPx box preserving aspect ratio (letter-boxed,
    // never stretched), centered on the canvas. A wide truck/car sprite stays
    // proportional instead of being mashed into a square.
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

  // ── Symbols (add / remove / move) ──────────────────────────────────────

  /// Registers any new icons, adds symbols for new vehicles, removes symbols
  /// for vehicles that disappeared, and redraws the trail. Serialized so two
  /// data updates can't race on the symbol manager.
  Future<void> _rebuild() async {
    final controller = _controller;
    if (controller == null || !_styleReady) {
      return;
    }
    if (_rebuildBusy) {
      _rebuildDirty = true;
      return;
    }
    _rebuildBusy = true;
    try {
      final visible = _visibleVehicles;
      await _ensureImages(visible);
      if (!mounted || _controller == null) {
        return;
      }

      final visibleIds = visible.map((v) => v.id).toSet();

      // Remove vanished vehicles.
      final goneIds =
          _symbols.keys.where((id) => !visibleIds.contains(id)).toList();
      for (final id in goneIds) {
        final symbol = _symbols.remove(id);
        _lastPushed.remove(id);
        _lastPushedCourse.remove(id);
        if (symbol != null) {
          try {
            await _controller!.removeSymbol(symbol);
          } catch (_) {}
        }
      }

      // Add new vehicles.
      for (final vehicle in visible) {
        if (_symbols.containsKey(vehicle.id) ||
            _addingSymbols.contains(vehicle.id)) {
          continue;
        }
        _addingSymbols.add(vehicle.id);
        final geometry = _renderedPositions[vehicle.id] ?? _toLatLng(vehicle);
        final rotation = _renderedCourse[vehicle.id] ?? (vehicle.course % 360);
        try {
          final symbol = await _controller!.addSymbol(
            SymbolOptions(
              geometry: geometry,
              iconImage: _imageName(vehicle),
              iconSize: 1.0,
              iconAnchor: 'center',
              iconRotate: rotation,
            ),
            <String, dynamic>{'vid': vehicle.id},
          );
          _symbols[vehicle.id] = symbol;
          _lastPushed[vehicle.id] = geometry;
          _lastPushedCourse[vehicle.id] = rotation;
        } catch (_) {
          // ignore — will retry on the next data update
        } finally {
          _addingSymbols.remove(vehicle.id);
        }
      }

      await _drawTrail();
    } finally {
      _rebuildBusy = false;
      if (_rebuildDirty) {
        _rebuildDirty = false;
        unawaited(_rebuild());
      }
    }
  }

  void _updateSymbolPositions() {
    final controller = _controller;
    if (controller == null || !_styleReady) {
      return;
    }
    for (final vehicle in _visibleVehicles) {
      final symbol = _symbols[vehicle.id];
      if (symbol == null) {
        continue;
      }
      final position = _renderedPositions[vehicle.id];
      if (position == null) {
        continue;
      }
      final rotation = _renderedCourse[vehicle.id] ?? (vehicle.course % 360);
      final last = _lastPushed[vehicle.id];
      final lastCourse = _lastPushedCourse[vehicle.id];
      final posSame = last != null && _manhattan(last, position) < _epsilon;
      final rotSame = lastCourse != null && (lastCourse - rotation).abs() < 0.5;
      // Skip channel chatter only when BOTH position and heading are stable
      // (e.g. a parked car) — otherwise a pure turn would not redraw.
      if (posSame && rotSame) {
        continue;
      }
      _lastPushed[vehicle.id] = position;
      _lastPushedCourse[vehicle.id] = rotation;
      // Fire-and-forget — awaiting per frame would serialize the channel.
      unawaited(_safeUpdateSymbol(controller, symbol, position, rotation));
    }
  }

  Future<void> _safeUpdateSymbol(
    MapLibreMapController controller,
    Symbol symbol,
    LatLng position,
    double rotation,
  ) async {
    try {
      await controller.updateSymbol(
        symbol,
        SymbolOptions(geometry: position, iconRotate: rotation),
      );
    } catch (_) {}
  }

  Future<void> _drawTrail() async {
    final controller = _controller;
    if (controller == null || !_styleReady) {
      return;
    }

    if (_trailLine != null) {
      try {
        await controller.removeLine(_trailLine!);
      } catch (_) {}
      _trailLine = null;
    }

    if (widget.trailPoints.length < 2) {
      return;
    }

    final points = widget.trailPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    try {
      _trailLine = await controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: _hex(AppTheme.primaryBlue),
          lineWidth: 5.0,
          lineOpacity: 0.45,
          lineJoin: 'round',
        ),
      );
    } catch (_) {}
  }

  String _hex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  void _handleSymbolTapped(Symbol symbol) {
    final onTap = widget.onVehicleTap;
    if (onTap == null) {
      return;
    }
    final vid = symbol.data?['vid'];
    if (vid is! int) {
      return;
    }
    for (final vehicle in widget.vehicles) {
      if (vehicle.id == vid) {
        onTap(vehicle);
        return;
      }
    }
  }

  // ── Movement animation ─────────────────────────────────────────────────

  void _animateToLatestPositions() {
    final visible = _visibleVehicles;
    final nextPositions = <int, LatLng>{
      for (final vehicle in visible) vehicle.id: _toLatLng(vehicle),
    };
    final nextCourses = <int, double>{
      for (final vehicle in visible) vehicle.id: _targetCourse(vehicle),
    };

    // Nothing actually moved (e.g. a parked fleet re-emitting the same SSE
    // position on every poll) → don't restart the controller. Re-running
    // forward(from: 0) each tick was causing visible marker jitter for idle
    // vehicles and needless work.
    if (!_animationController.isAnimating &&
        _sameLatLngMap(nextPositions, _renderedPositions) &&
        _sameDoubleMap(nextCourses, _renderedCourse)) {
      return;
    }

    _renderedPositions
        .removeWhere((vehicleId, _) => !nextPositions.containsKey(vehicleId));
    _renderedCourse
        .removeWhere((vehicleId, _) => !nextPositions.containsKey(vehicleId));

    if (!widget.animateMarkers) {
      nextPositions.forEach((vehicleId, target) {
        _renderedPositions[vehicleId] = target;
      });
      nextCourses.forEach((vehicleId, target) {
        _renderedCourse[vehicleId] = target;
      });
      _updateSymbolPositions();
      if (widget.followFocusedVehicle) {
        _followCamera();
      }
      return;
    }

    // Re-target the glide from where each marker CURRENTLY is (the live
    // interpolated pose in _renderedPositions, kept fresh by _handleAnimationTick)
    // toward the new fix — even when a glide is still in flight. Restarting from
    // the current pose (not snapping to the raw fix) means fast position polls
    // (~4 s) re-aim continuously with no jump, so the marker never freezes or
    // teleports between updates.
    _animationStart = <int, LatLng>{};
    _animationEnd = nextPositions;
    _courseStart = <int, double>{};
    _courseEnd = nextCourses;
    nextPositions.forEach((vehicleId, target) {
      _animationStart[vehicleId] = _renderedPositions[vehicleId] ?? target;
    });
    nextCourses.forEach((vehicleId, target) {
      _courseStart[vehicleId] = _renderedCourse[vehicleId] ?? target;
    });

    _animationController.forward(from: 0);
  }

  /// True when two id→position maps have the same keys and effectively the
  /// same coordinates (≈0.1 m). Used to skip redundant marker re-animations.
  bool _sameLatLngMap(Map<int, LatLng> a, Map<int, LatLng> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) {
        return false;
      }
      if ((entry.value.latitude - other.latitude).abs() > 1e-6 ||
          (entry.value.longitude - other.longitude).abs() > 1e-6) {
        return false;
      }
    }
    return true;
  }

  bool _sameDoubleMap(Map<int, double> a, Map<int, double> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || (entry.value - other).abs() > 0.5) {
        return false;
      }
    }
    return true;
  }

  void _handleAnimationTick() {
    if (!mounted) {
      return;
    }
    final easedT = Curves.easeOutCubic.transform(_animationController.value);
    final nextFrame = <int, LatLng>{};
    _animationEnd.forEach((vehicleId, endPoint) {
      final startPoint = _animationStart[vehicleId] ?? endPoint;
      nextFrame[vehicleId] = _lerpLatLng(startPoint, endPoint, easedT);
    });
    final nextCourseFrame = <int, double>{};
    _courseEnd.forEach((vehicleId, endCourse) {
      final startCourse = _courseStart[vehicleId] ?? endCourse;
      nextCourseFrame[vehicleId] = _lerpAngle(startCourse, endCourse, easedT);
    });

    _renderedPositions
      ..clear()
      ..addAll(nextFrame);
    _renderedCourse
      ..clear()
      ..addAll(nextCourseFrame);

    _updateSymbolPositions();

    if (widget.followFocusedVehicle) {
      _followCamera();
    }
  }

  // ── Camera ─────────────────────────────────────────────────────────────

  LatLng? _focusTarget() {
    final focus = widget.focusVehicle;
    if (focus != null && focus.hasLiveLocation) {
      return _renderedPositions[focus.id] ?? _toLatLng(focus);
    }
    if (_visibleVehicles.length == 1) {
      final vehicle = _visibleVehicles.first;
      return _renderedPositions[vehicle.id] ?? _toLatLng(vehicle);
    }
    return null;
  }

  void _followCamera() {
    final controller = _controller;
    if (controller == null ||
        !_styleReady ||
        !widget.followFocusedVehicle ||
        _userInteracted) {
      return;
    }
    final target = _focusTarget();
    if (target == null) {
      return;
    }
    if (_lastCameraTarget != null &&
        _manhattan(_lastCameraTarget!, target) < _epsilon) {
      return;
    }
    _programmaticMove = true;
    _lastCameraTarget = target;
    unawaited(_safeMoveCamera(controller, target));
  }

  Future<void> _safeMoveCamera(
    MapLibreMapController controller,
    LatLng target,
  ) async {
    try {
      await controller.moveCamera(CameraUpdate.newLatLng(target));
    } catch (_) {}
  }

  Future<void> _fitToVehicles() async {
    final controller = _controller;
    if (controller == null || _initialFitDone) {
      return;
    }
    final points = _visibleVehicles
        .map((vehicle) => _renderedPositions[vehicle.id] ?? _toLatLng(vehicle))
        .where((point) => point.latitude != 0 || point.longitude != 0)
        .toList();
    if (points.length < 2) {
      return;
    }
    _initialFitDone = true;
    _programmaticMove = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsFromPoints(points),
          left: 50,
          top: 50,
          right: 50,
          bottom: 50,
        ),
      );
    } catch (_) {}
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _onCameraMove(CameraPosition position) {
    if (!_programmaticMove && !_userInteracted) {
      _userInteracted = true;
    }
    // A fresh user gesture cancels any pending follow-resume so the camera
    // never snatches control back mid-exploration.
    if (!_programmaticMove) {
      _followResumeTimer?.cancel();
      _followResumeTimer = null;
    }
  }

  void _onCameraIdle() {
    _programmaticMove = false;
    // Follow auto-resume: a single accidental pan used to disengage the
    // camera FOREVER (nothing reset _userInteracted on the single-vehicle
    // screen). After 10s of no touching, glide back onto the vehicle —
    // the behaviour users know from the web tracker's follow mode.
    if (widget.followFocusedVehicle && _userInteracted) {
      _followResumeTimer?.cancel();
      _followResumeTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        _userInteracted = false;
        _followCamera();
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_hasVisibleVehicles) {
      return _buildEmptyState(context);
    }

    final center = _centerPoint() ?? _defaultCenter;

    return Stack(
      children: <Widget>[
        MapLibreMap(
          // Re-create the platform view if the chosen base style changes.
          key: ValueKey<String>(_styleUrl),
          styleString: _styleUrl,
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: _zoomLevel(),
            tilt: _focusTilt(),
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          trackCameraPosition: true,
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
          // 3D-capable view: tilt + rotate gestures let the operator orbit the
          // (liberty) 3D buildings for a premium, Google-tracking feel. The
          // focused single vehicle starts pitched (see _focusTilt); the fleet
          // overview stays flat top-down. Pinch-zoom + drag stay smooth on the
          // vector renderer.
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          compassEnabled: false,
          myLocationEnabled: false,
          minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
          // Native attribution "i" button stays bottom-right but is covered by
          // our own static credit below (see the Positioned overlay).
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
          // Win any gesture fight with a parent scroll view so pinch-out is
          // never misread as a vertical scroll.
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
          },
        ),
        // Cover the native MapLibre attribution "i" button (bottom-right). Its
        // popup's links opened in a non-Activity context and crashed the app,
        // and operators found the dialog intrusive on the dashboard. This
        // tap-absorbing overlay swallows taps over that hotspot so the native
        // dialog never opens, while showing a clean static OSM/OpenFreeMap
        // credit (attribution stays compliant and can never crash). Belt =
        // MapLibreMap.useHybridComposition in main.dart; this is the suspenders.
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: SizedBox(
              width: 138,
              height: 42,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  color: Colors.white.withValues(alpha: 0.62),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color cardColor = theme.cardColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? <Color>[cardColor, theme.scaffoldBackgroundColor]
              : const <Color>[Color(0xFFF8FBFD), Color(0xFFF1F6F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 36,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.emptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.emptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
