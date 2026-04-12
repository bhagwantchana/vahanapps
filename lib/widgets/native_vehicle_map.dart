import 'dart:math' as math;

import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class NativeVehicleMap extends StatefulWidget {
  const NativeVehicleMap({
    super.key,
    required this.vehicles,
    this.focusVehicle,
    this.trailPoints = const <LatLng>[],
    this.emptyTitle = 'No vehicles mapped yet',
    this.emptySubtitle = 'Live map will appear once a vehicle is tracked',
    this.followFocusedVehicle = false,
    this.animateMarkers = true,
  });

  final List<VehicleRecord> vehicles;
  final VehicleRecord? focusVehicle;
  final List<LatLng> trailPoints;
  final String emptyTitle;
  final String emptySubtitle;
  final bool followFocusedVehicle;
  final bool animateMarkers;

  @override
  State<NativeVehicleMap> createState() => _NativeVehicleMapState();
}

class _NativeVehicleMapState extends State<NativeVehicleMap>
    with SingleTickerProviderStateMixin {
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);
  static const Duration _animationDuration = Duration(milliseconds: 900);

  final MapController _mapController = MapController();
  final Map<int, LatLng> _renderedPositions = <int, LatLng>{};
  Map<int, LatLng> _animationStart = <int, LatLng>{};
  Map<int, LatLng> _animationEnd = <int, LatLng>{};

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: _animationDuration,
  )..addListener(_handleAnimationTick);

  LatLng? _lastCameraTarget;
  double? _lastCameraZoom;
  bool _cameraBootstrapScheduled = false;

  @override
  void initState() {
    super.initState();
    _seedInitialPositions();
    if (widget.followFocusedVehicle) {
      _scheduleCameraSync(force: true);
    }
  }

  @override
  void didUpdateWidget(covariant NativeVehicleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animateToLatestPositions();
    if (widget.followFocusedVehicle &&
        (oldWidget.focusVehicle?.id != widget.focusVehicle?.id ||
            oldWidget.followFocusedVehicle != widget.followFocusedVehicle)) {
      _scheduleCameraSync(force: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<VehicleRecord> get _visibleVehicles {
    return widget.vehicles.where((vehicle) => vehicle.hasLiveLocation).toList();
  }

  bool get _hasVisibleVehicles => _visibleVehicles.isNotEmpty;

  LatLng _toLatLng(VehicleRecord vehicle) {
    return LatLng(vehicle.latitude, vehicle.longitude);
  }

  bool _samePoint(LatLng a, LatLng b) {
    return a.latitude == b.latitude && a.longitude == b.longitude;
  }

  LatLng _lerpLatLng(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + ((end.latitude - start.latitude) * t),
      start.longitude + ((end.longitude - start.longitude) * t),
    );
  }

  double _distanceBetween(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() + (a.longitude - b.longitude).abs();
  }

  double _zoomLevel() {
    if (widget.focusVehicle?.hasLiveLocation == true) {
      return 16.0;
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

  Color _statusColor(VehicleRecord vehicle) {
    if (vehicle.isMoving) {
      return AppTheme.primaryGreen;
    }
    if (vehicle.isIdle) {
      return Colors.orange;
    }
    return Colors.red;
  }

  String _displayLabel(VehicleRecord vehicle) {
    if (vehicle.displayName.isNotEmpty) {
      return vehicle.displayName;
    }
    return 'Vehicle ${vehicle.id}';
  }

  void _seedInitialPositions() {
    _renderedPositions
      ..clear()
      ..addEntries(
        _visibleVehicles.map(
          (vehicle) => MapEntry<int, LatLng>(vehicle.id, _toLatLng(vehicle)),
        ),
      );
  }

  void _animateToLatestPositions() {
    final visible = _visibleVehicles;
    final nextPositions = <int, LatLng>{
      for (final vehicle in visible) vehicle.id: _toLatLng(vehicle),
    };

    _renderedPositions.removeWhere((vehicleId, _) => !nextPositions.containsKey(vehicleId));

    if (!_animationController.isAnimating || !widget.animateMarkers) {
      var hasChanges = false;
      nextPositions.forEach((vehicleId, target) {
        final current = _renderedPositions[vehicleId];
        if (current == null || !_samePoint(current, target)) {
          hasChanges = true;
        }
        _renderedPositions[vehicleId] = target;
      });

      if (hasChanges && mounted) {
        setState(() {});
      }

      if (widget.followFocusedVehicle) {
        _scheduleCameraSync(force: true);
      }
      return;
    }

    _animationStart = <int, LatLng>{};
    _animationEnd = nextPositions;
    nextPositions.forEach((vehicleId, target) {
      _animationStart[vehicleId] = _renderedPositions[vehicleId] ?? target;
    });

    _animationController.forward(from: 0);
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

    _renderedPositions
      ..clear()
      ..addAll(nextFrame);

    setState(() {});

    if (widget.followFocusedVehicle) {
      _syncCamera();
    }
  }

  void _scheduleCameraSync({bool force = false}) {
    if (!widget.followFocusedVehicle) {
      return;
    }

    if (_cameraBootstrapScheduled && !force) {
      return;
    }

    _cameraBootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraBootstrapScheduled = false;
      if (mounted) {
        _syncCamera(force: force);
      }
    });
  }

  void _syncCamera({bool force = false}) {
    if (!widget.followFocusedVehicle) {
      return;
    }

    final focus = widget.focusVehicle;
    LatLng? target;

    if (focus != null && focus.hasLiveLocation) {
      target = _renderedPositions[focus.id] ?? _toLatLng(focus);
    } else if (_visibleVehicles.length == 1) {
      final vehicle = _visibleVehicles.first;
      target = _renderedPositions[vehicle.id] ?? _toLatLng(vehicle);
    }

    if (target == null) {
      return;
    }

    final zoom = _zoomLevel();
    if (!force &&
        _lastCameraTarget != null &&
        _distanceBetween(_lastCameraTarget!, target) < 0.00001 &&
        _lastCameraZoom == zoom) {
      return;
    }

    try {
      _mapController.move(target, zoom);
      _lastCameraTarget = target;
      _lastCameraZoom = zoom;
    } catch (_) {
      // Camera sync is best-effort only.
    }
  }

  Widget _markerIcon(VehicleRecord vehicle) {
    final iconUrl = vehicle.vehicleIconUrl.trim();
    final iconFallback = const AssetImage('assets/images/map.png');
    final statusColor = _statusColor(vehicle);
    final rotation = (vehicle.course % 360) * math.pi / 180;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Transform.rotate(
                angle: rotation,
                child: iconUrl.isNotEmpty
                    ? Image.network(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image(image: iconFallback, fit: BoxFit.cover);
                        },
                      )
                    : Image(image: iconFallback, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _displayLabel(vehicle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasVisibleVehicles) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF8FBFD), Color(0xFFF1F6F3)],
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
                  color: Colors.white,
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlue,
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

    final center = _centerPoint() ?? _defaultCenter;
    final markers = _visibleVehicles
        .map(
          (vehicle) => Marker(
            point: _renderedPositions[vehicle.id] ?? _toLatLng(vehicle),
            width: 110,
            height: 70,
            child: _markerIcon(vehicle),
          ),
        )
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _zoomLevel(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'fleet_monitor',
        ),
        if (widget.trailPoints.length > 1)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: widget.trailPoints,
                strokeWidth: 4.5,
                color: AppTheme.primaryBlue.withValues(alpha: 0.38),
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
