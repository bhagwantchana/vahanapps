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

  /// Bounded timeouts: icon downloads now also happen mid-session (first
  /// time a status variant is needed) inside _rebuild, and a black-holed
  /// request with Dio's default infinite timeouts would stall trail redraw
  /// and symbol add/remove until the OS socket gives up.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));
  MapLibreMapController? _controller;
  bool _styleReady = false;

  /// Bumped on every style (re)load. A _rebuild pass that started against an
  /// older style bails after each await instead of committing dead symbols /
  /// image names into the caches _onStyleLoaded just cleared.
  int _styleGeneration = 0;

  /// Registered MapLibre image names (one per distinct vehicle-icon URL +
  /// status variant) whose bytes are the REAL downloaded icon.
  final Set<String> _registeredImages = <String>{};

  /// Names currently backed by the bundled placeholder because every
  /// download candidate failed (e.g. offline at first sight of a variant).
  /// Kept out of [_registeredImages] so a later tick retries the download
  /// and heals the marker in place.
  final Set<String> _placeholderImages = <String>{};

  /// Last failed download attempt per image name. Retries honour a cooldown
  /// so a dead icon host (or a permanently-missing icon file) costs at most
  /// one attempt per cooldown window instead of stalling _rebuild with
  /// timeout-bound requests on every data tick.
  final Map<String, DateTime> _iconFailedAt = <String, DateTime>{};
  static const Duration _iconRetryCooldown = Duration(seconds: 45);

  /// vehicleId → live Symbol on the map.
  final Map<int, Symbol> _symbols = <int, Symbol>{};

  /// vehicleIds whose Symbol is mid-creation, so we never add twice.
  final Set<int> _addingSymbols = <int>{};

  /// Last geometry actually pushed to a symbol — lets us skip channel chatter
  /// for parked vehicles during the animation loop.
  final Map<int, LatLng> _lastPushed = <int, LatLng>{};

  Line? _trailLine;
  // Geometry currently drawn for the trail. _rebuild() runs on every data
  // tick (SSE push + the 5s silent poll); redrawing the line each time made
  // it BLINK — the map looked like it "refreshed" every few seconds even for
  // a parked vehicle. We diff against this and skip / update-in-place instead.
  List<LatLng> _renderedTrailPoints = <LatLng>[];

  final Map<int, LatLng> _renderedPositions = <int, LatLng>{};
  Map<int, LatLng> _animationStart = <int, LatLng>{};
  Map<int, LatLng> _animationEnd = <int, LatLng>{};

  /// Heading (course) is interpolated alongside position so turns glide
  /// instead of snapping at each SSE packet — the "really driving" feel.
  final Map<int, double> _renderedCourse = <int, double>{};
  Map<int, double> _courseStart = <int, double>{};
  Map<int, double> _courseEnd = <int, double>{};
  final Map<int, double> _lastPushedCourse = <int, double>{};

  /// Icon image name currently applied to each symbol — lets the status-
  /// colored icon swap (moving/idle/stopped/offline) skip the channel when
  /// nothing changed, so a parked vehicle never re-pushes its image.
  final Map<int, String> _lastPushedIcon = <int, String>{};

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

  /// Image name for a vehicle at a given status. The status is passed in
  /// (snapshotted once per _rebuild pass) rather than derived here, so
  /// _ensureImages, addSymbol and the swap loop always agree on the SAME
  /// name even if the wall clock crosses the 30-min offline boundary
  /// between them mid-pass.
  String _imageName(VehicleRecord vehicle, String status) {
    final url = vehicle.vehicleIconUrl.trim();
    if (url.isEmpty) {
      return _fallbackImageName;
    }
    return 'veh_${url.hashCode}_$status';
  }

  /// Same status buckets as the webmaps' getVehicleStatus(): a fix older
  /// than 30 minutes is offline (grey), ACC off is stopped (red), >5 km/h
  /// is moving (green), otherwise idle (orange). The offline gate uses the
  /// epoch `ts` the wire carries — NEVER the created_at string, which is a
  /// zone-less server-local timestamp that parsed phone-local flags every
  /// live vehicle offline (the exact incident the webmaps documented and
  /// fixed the same way). No ts on the record → no offline bucket, so a
  /// missing field can never paint a moving vehicle grey.
  String _vehicleStatus(VehicleRecord vehicle) {
    final tsMs = vehicle.tsEpochMs;
    if (tsMs > 0 &&
        DateTime.now().millisecondsSinceEpoch - tsMs > 30 * 60 * 1000) {
      return 'offline';
    }
    if (vehicle.isStopped) {
      return 'stopped';
    }
    if (vehicle.isMoving) {
      return 'moving';
    }
    return 'idle';
  }

  /// URL of the pre-generated status-colored variant that the webmaps also
  /// use: assets/icons/car.png → assets/icons/status/car_moving.png. Falls
  /// back to the plain icon at download time if the variant doesn't exist.
  String _statusIconUrl(String iconUrl, String status) {
    final slash = iconUrl.lastIndexOf('/');
    if (slash < 0) {
      return '';
    }
    final dir = iconUrl.substring(0, slash);
    final file = iconUrl.substring(slash + 1);
    final dot = file.lastIndexOf('.');
    final stem = dot > 0 ? file.substring(0, dot) : file;
    return '$dir/status/${stem}_$status.png';
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

    // A (re)loaded style wipes all annotations — forget the old trail handle
    // so _drawTrail re-adds it instead of diffing against a line that's gone.
    _trailLine = null;
    _renderedTrailPoints = <LatLng>[];

    // The same applies to style IMAGES and symbols: a style (re)load — e.g.
    // the map-provider setting flipping between liberty and positron, which
    // recreates the platform view via the ValueKey — starts with zero
    // registered images and zero annotations. Stale caches here would make
    // _ensureImages skip re-registering and the add loop skip re-adding,
    // leaving every marker invisible until the screen is left.
    _styleGeneration++;
    _registeredImages.clear();
    _placeholderImages.clear();
    _iconFailedAt.clear();
    _symbols.clear();
    _addingSymbols.clear();
    _lastPushed.clear();
    _lastPushedCourse.clear();
    _lastPushedIcon.clear();

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

  Future<void> _ensureImages(
    List<VehicleRecord> vehicles,
    Map<int, String> statusById,
    int generation,
  ) async {
    final controller = _controller;
    if (controller == null || !_styleReady) {
      return;
    }

    // Always have the fallback registered first.
    if (!_registeredImages.contains(_fallbackImageName)) {
      final (bytes, _) = await _composeIconBytes(const <String>[]);
      if (!mounted || _controller == null || generation != _styleGeneration) {
        return;
      }
      try {
        await _controller!.addImage(_fallbackImageName, bytes);
      } catch (_) {
        return; // transient channel failure — retry on the next data tick
      }
      if (generation != _styleGeneration) {
        // Style reloaded mid-push: the bytes landed in the dead style. Do
        // NOT mark registered in the new generation's (cleared) cache.
        return;
      }
      _registeredImages.add(_fallbackImageName);
    }

    // Names already attempted in THIS pass — several vehicles often share
    // one icon+status, and on the failure path the name wouldn't reach
    // _registeredImages, so without this each sharer would re-pay the full
    // download timeout inside a single pass.
    final attempted = <String>{};

    for (final vehicle in vehicles) {
      final status = statusById[vehicle.id];
      if (status == null) {
        continue;
      }
      final name = _imageName(vehicle, status);
      if (_registeredImages.contains(name) || attempted.contains(name)) {
        continue;
      }
      final url = vehicle.vehicleIconUrl.trim();
      if (url.isEmpty) {
        continue; // fallback image already registered above
      }
      final failedAt = _iconFailedAt[name];
      if (failedAt != null &&
          DateTime.now().difference(failedAt) < _iconRetryCooldown) {
        continue; // recently failed — don't stall this pass, retry later
      }
      attempted.add(name);
      // Status-colored variant first (what the webmaps show), plain icon as
      // the fallback — so a missing variant can never break a marker.
      final (bytes, fetched) = await _composeIconBytes(<String>[
        _statusIconUrl(url, status),
        url,
      ]);
      if (!mounted || _controller == null || generation != _styleGeneration) {
        return;
      }
      if (fetched) {
        _iconFailedAt.remove(name);
      } else {
        _iconFailedAt[name] = DateTime.now();
        if (_placeholderImages.contains(name)) {
          // Placeholder is already in the style — nothing new to push.
          continue;
        }
      }
      try {
        await _controller!.addImage(name, bytes);
      } catch (_) {
        // Push failed WITHOUT a style reload (e.g. surface teardown while
        // backgrounding). Clear the cooldown so the next tick retries
        // immediately — otherwise new symbols could point at a missing
        // image for the whole cooldown window.
        _iconFailedAt.remove(name);
        return;
      }
      if (generation != _styleGeneration) {
        // Style reloaded mid-push: bytes landed in the dead style — bail
        // without committing so the new generation re-registers cleanly.
        return;
      }
      if (fetched) {
        // Real icon bytes — done for the session.
        _registeredImages.add(name);
        _placeholderImages.remove(name);
      } else {
        // Transient failure (dead zone / server blip): the bundled bytes
        // keep the marker visible, but do NOT cache the name as registered —
        // after the cooldown the download is retried, and addImage under
        // the same name replaces the placeholder in the style, healing the
        // marker in place. The swap loop's registered-image gate also keeps
        // an already-correct icon from being downgraded to this placeholder.
        _placeholderImages.add(name);
      }
    }
  }

  /// Downloads and renders the first candidate URL that works; falls back to
  /// the bundled asset when every candidate fails (or none were given). The
  /// bool is true when a candidate actually rendered (or none were
  /// requested), false when every candidate failed and the bundled
  /// placeholder was used. The decode/render runs INSIDE the per-candidate
  /// try: a 200 response with a non-image body (error page, corrupt PNG)
  /// counts as a failed candidate instead of throwing out of _rebuild.
  Future<(Uint8List, bool)> _composeIconBytes(List<String> candidateUrls) async {
    for (final url in candidateUrls) {
      if (url.isEmpty) {
        continue;
      }
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        if (data == null || data.isEmpty) {
          continue;
        }
        return (await _renderMarkerPng(Uint8List.fromList(data)), true);
      } catch (_) {
        // bad candidate (network error or undecodable body) — try the next
      }
    }
    final raw =
        (await rootBundle.load('assets/images/map.png')).buffer.asUint8List();
    return (await _renderMarkerPng(raw), candidateUrls.isEmpty);
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
      // Style generation this pass belongs to. If the style reloads while an
      // await below is in flight (map-provider flip recreating the platform
      // view), the pass must NOT commit its dead symbols / image names into
      // the caches _onStyleLoaded just cleared — the dirty re-run rebuilds
      // everything against the fresh style instead.
      final gen = _styleGeneration;
      final visible = _visibleVehicles;
      // Snapshot each vehicle's status ONCE for this whole pass so image
      // registration, addSymbol and the swap loop can never disagree on the
      // icon name (the offline bucket is wall-clock dependent).
      final statusById = <int, String>{
        for (final vehicle in visible) vehicle.id: _vehicleStatus(vehicle),
      };
      await _ensureImages(visible, statusById, gen);
      if (!mounted || _controller == null || gen != _styleGeneration) {
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
        _lastPushedIcon.remove(id);
        if (symbol != null) {
          try {
            await _controller!.removeSymbol(symbol);
          } catch (_) {}
          if (!mounted || _controller == null || gen != _styleGeneration) {
            return;
          }
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
        final iconName =
            _imageName(vehicle, statusById[vehicle.id] ?? 'stopped');
        try {
          final symbol = await _controller!.addSymbol(
            SymbolOptions(
              geometry: geometry,
              iconImage: iconName,
              iconSize: 1.0,
              iconAnchor: 'center',
              iconRotate: rotation,
            ),
            <String, dynamic>{'vid': vehicle.id},
          );
          if (gen != _styleGeneration) {
            // Style reloaded mid-add: this symbol belongs to the dead style.
            // Drop it (best effort) instead of committing it to the caches —
            // the dirty re-run re-adds against the fresh style.
            try {
              await _controller?.removeSymbol(symbol);
            } catch (_) {}
            return;
          }
          _symbols[vehicle.id] = symbol;
          _lastPushed[vehicle.id] = geometry;
          _lastPushedCourse[vehicle.id] = rotation;
          _lastPushedIcon[vehicle.id] = iconName;
        } catch (_) {
          // ignore — will retry on the next data update
        } finally {
          _addingSymbols.remove(vehicle.id);
        }
      }

      // Swap the status-colored icon in place when a vehicle's status
      // changed (moving green / idle orange / stopped red / offline grey —
      // the same variants the webmaps show). updateSymbol touches ONLY
      // iconImage: geometry, rotation and the glide animation are untouched,
      // so there is no jump and no blink. Skipped entirely while the image
      // name is unchanged — a parked fleet costs nothing per tick.
      for (final vehicle in visible) {
        final symbol = _symbols[vehicle.id];
        if (symbol == null) {
          continue;
        }
        final iconName =
            _imageName(vehicle, statusById[vehicle.id] ?? 'stopped');
        if (_lastPushedIcon[vehicle.id] == iconName) {
          continue;
        }
        // Never point a symbol at an image that isn't registered — that
        // would blank the marker. _ensureImages above registers current
        // statuses; if it bailed early, keep the old icon this tick.
        if (!_registeredImages.contains(iconName)) {
          continue;
        }
        _lastPushedIcon[vehicle.id] = iconName;
        try {
          await _controller!.updateSymbol(
            symbol,
            SymbolOptions(iconImage: iconName),
          );
        } catch (_) {
          // Push failed → forget it so the next data tick retries instead
          // of the stale color sticking for the whole session.
          _lastPushedIcon.remove(vehicle.id);
        }
        if (!mounted || _controller == null || gen != _styleGeneration) {
          return;
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

    final points = widget.trailPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    // Unchanged since the last draw → do NOTHING. This is the fix for the
    // "map refreshes every few seconds" report: without it, every SSE push
    // and every 5s silent poll removed + re-added the line, blinking it.
    if (_sameTrail(points, _renderedTrailPoints)) {
      return;
    }

    // Too few points to draw a line → drop any existing one.
    if (points.length < 2) {
      if (_trailLine != null) {
        try {
          await controller.removeLine(_trailLine!);
        } catch (_) {}
        _trailLine = null;
      }
      _renderedTrailPoints = points;
      return;
    }

    // Update the existing line's geometry IN PLACE (no blink) as the trail
    // grows while driving; only add a fresh line when there isn't one yet.
    if (_trailLine != null) {
      try {
        await controller.updateLine(_trailLine!, LineOptions(geometry: points));
      } catch (_) {
        // Fall back to a fresh line if the in-place update fails.
        _trailLine = null;
      }
    }
    if (_trailLine == null) {
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
      } catch (_) {
        // Draw FAILED (transient platform-channel error). Leave
        // _renderedTrailPoints STALE so the next _drawTrail() fails the
        // _sameTrail guard and RETRIES the add — otherwise committing the
        // cache here would make the guard skip every retry and the trail
        // would stay hidden for the whole session until the vehicle moves.
        return;
      }
    }
    // Only reached after a SUCCESSFUL updateLine or addLine.
    _renderedTrailPoints = points;
  }

  /// True when two trail point lists are effectively identical (same length,
  /// same coordinates). Lets _drawTrail skip redundant redraws that blink.
  bool _sameTrail(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if ((a[i].latitude - b[i].latitude).abs() > 1e-6 ||
          (a[i].longitude - b[i].longitude).abs() > 1e-6) {
        return false;
      }
    }
    return true;
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
