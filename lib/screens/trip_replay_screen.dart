import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/models/vehicle_track_point.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Trip replay: pick a vehicle, fetch its track points for the chosen
/// window, then animate a marker along the polyline on a high-framerate,
/// butter-smooth FlutterMap canvas with play/pause and 1×/2×/4× speed controls.
class TripReplayScreen extends StatefulWidget {
  const TripReplayScreen({
    super.key,
    this.initialVehicle,
    this.initialFrom,
    this.initialTo,
  });

  final VehicleRecord? initialVehicle;

  /// Optional pre-selected window. Defaults to TODAY (00:00 → now) when null.
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<TripReplayScreen> createState() => _TripReplayScreenState();
}

class _TripReplayScreenState extends State<TripReplayScreen>
    with SingleTickerProviderStateMixin {
  final SingleTrackRepository _repo = SingleTrackRepository();
  final MapController _mapController = MapController();

  VehicleRecord? _vehicle;
  List<VehicleTrackPoint> _points = <VehicleTrackPoint>[];
  bool _loading = false;
  String _error = '';

  /// Index of the segment START point. The marker is animated between
  /// `_points[_currentIndex]` and `_points[_currentIndex + 1]`, with the
  /// fraction stored on `_animController.value`.
  int _currentIndex = 0;
  bool _playing = false;
  double _speedMultiplier = 1;

  /// Drives the per-segment interpolation. One full forward pass advances
  /// the marker exactly one GPS sample, then we bump `_currentIndex` and
  /// restart from 0. Duration scales with the speed multiplier.
  late final AnimationController _animController;

  /// Smoothed heading the marker is rotated by. Tracks the segment bearing
  /// but eased over a few frames so that sharp turns don't snap the icon.
  double _displayedBearing = 0;

  /// The selected history window. Defaults to TODAY; the calendar button lets
  /// the user pick a single day or a date range.
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: _segmentDuration,
    )
      ..addListener(_onAnimTick)
      ..addStatusListener(_onAnimStatus);

    final now = DateTime.now();
    _from = widget.initialFrom ?? DateTime(now.year, now.month, now.day);
    _to = widget.initialTo ?? now;

    _vehicle = widget.initialVehicle;
    if (_vehicle != null) {
      _loadTrail();
    }
  }

  @override
  void dispose() {
    _animController
      ..removeListener(_onAnimTick)
      ..removeStatusListener(_onAnimStatus)
      ..dispose();
    super.dispose();
  }

  Duration get _segmentDuration =>
      Duration(milliseconds: (400 / _speedMultiplier).round());

  void _onAnimTick() {
    if (!mounted) return;
    // Ease the displayed bearing towards the segment's true bearing — keeps
    // the icon from snapping on sharp direction changes.
    final target = _segmentBearing(_currentIndex);
    _displayedBearing = _easeBearing(_displayedBearing, target, 0.20);

    // Pan the camera to track the marker every frame smoothly on Flutter's Dart engine.
    try {
      _mapController.move(_animatedPoint, _mapController.camera.zoom);
    } catch (_) {
      // Map detached or before first layout
    }
    setState(() {});
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_currentIndex < _points.length - 2) {
      _currentIndex++;
      _animController.forward(from: 0);
    } else {
      // Reached the final sample — park the marker there.
      _currentIndex = _points.length - 1;
      setState(() => _playing = false);
    }
  }

  Future<void> _loadTrail() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;
    _animController.stop();
    _animController.value = 0;
    setState(() {
      _loading = true;
      _error = '';
      _points = <VehicleTrackPoint>[];
      _currentIndex = 0;
      _playing = false;
    });

    try {
      final fetched = await _repo.fetchTripHistoryTrail(
        imei: vehicle.imei,
        from: _from,
        to: _to,
      );
      final points = _dedupeConsecutive(fetched);
      if (!mounted) return;
      setState(() {
        _points = points;
        _loading = false;
        _displayedBearing = _segmentBearing(0);
      });

      if (points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final polyline = points.map((p) => p.toLatLng()).toList();
          final bounds = LatLngBounds.fromPoints(polyline);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 180),
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<VehicleTrackPoint> _dedupeConsecutive(List<VehicleTrackPoint> pts) {
    if (pts.length < 2) return pts;
    final out = <VehicleTrackPoint>[pts.first];
    for (var i = 1; i < pts.length; i++) {
      final a = out.last.toLatLng();
      final b = pts[i].toLatLng();
      if ((a.latitude - b.latitude).abs() > 1e-7 ||
          (a.longitude - b.longitude).abs() > 1e-7) {
        out.add(pts[i]);
      }
    }
    return out;
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _dayEnd(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _windowLabel() {
    String dm(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    if (_isSameDay(_from, _to)) {
      final now = DateTime.now();
      if (_isSameDay(_from, now)) return 'Today';
      return dm(_from);
    }
    return '${dm(_from)} - ${dm(_to)}';
  }

  Future<void> _pickWindow() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    final range = picked;
    if (!mounted) return;
    setState(() {
      _from = _dayStart(range.start);
      _to = _isSameDay(range.end, now) ? now : _dayEnd(range.end);
    });
    _loadTrail();
  }

  void _togglePlay() {
    if (_points.length < 2) return;
    if (_playing) {
      _animController.stop();
      setState(() => _playing = false);
      return;
    }
    if (_currentIndex >= _points.length - 1) {
      _currentIndex = 0;
      _animController.value = 0;
      _displayedBearing = _segmentBearing(0);
      _mapController.move(_points[0].toLatLng(), _mapController.camera.zoom);
    }
    setState(() => _playing = true);
    _animController.forward(from: _animController.value);
  }

  void _setSpeed(double mult) {
    setState(() => _speedMultiplier = mult);
    _animController.duration = _segmentDuration;
    if (_playing) {
      _animController.forward(from: _animController.value);
    }
  }

  LatLng get _animatedPoint {
    if (_points.isEmpty) return const LatLng(0, 0);
    if (_currentIndex >= _points.length - 1) return _points.last.toLatLng();
    final a = _points[_currentIndex].toLatLng();
    final b = _points[_currentIndex + 1].toLatLng();
    final t = _animController.value;
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  double _segmentBearing(int index) {
    if (_points.length < 2) return _displayedBearing;
    final i = index.clamp(0, _points.length - 2);
    final a = _points[i].toLatLng();
    final b = _points[i + 1].toLatLng();
    if (a.latitude == b.latitude && a.longitude == b.longitude) {
      return _displayedBearing;
    }
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _easeBearing(double current, double target, double t) {
    double delta = target - current;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return (current + delta * t + 360) % 360;
  }

  List<Polyline> _speedColouredRuns(List<LatLng> travelled) {
    if (travelled.length < 2) return const <Polyline>[];
    Color colourFor(double kmh) => kmh <= 30
        ? const Color(0xFF16A34A)
        : (kmh <= 60 ? const Color(0xFFEAB308) : const Color(0xFFEF4444));
    double speedAt(int i) =>
        _points[i < _currentIndex ? i : _currentIndex].speed;

    final runs = <Polyline>[];
    var runStart = 0;
    var runColour = colourFor(speedAt(0));
    for (var i = 1; i <= travelled.length; i++) {
      final c = i < travelled.length ? colourFor(speedAt(i)) : null;
      if (c != runColour) {
        final from = runStart == 0 ? 0 : runStart - 1;
        if (i - from >= 2) {
          runs.add(Polyline(
            points: travelled.sublist(from, i),
            color: runColour,
            strokeWidth: 4,
          ));
        }
        runStart = i;
        if (c != null) runColour = c;
      }
    }
    return runs;
  }

  static IconData _vehicleIconData(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('truck') || t.contains('lorry') || t.contains('tipper')) {
      return LucideIcons.truck;
    }
    if (t.contains('bus')) return LucideIcons.bus;
    if (t.contains('bike') || t.contains('motorcycle') || t.contains('scooter')) {
      return LucideIcons.bike;
    }
    return LucideIcons.car;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('trip_replay')),
      ),
      body: _vehicle == null
          ? _VehiclePicker(
              onPick: (v) {
                setState(() => _vehicle = v);
                _loadTrail();
              },
            )
          : Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            _vehicleIconData(_vehicle!.vehicleType),
                            size: 19,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _vehicle!.registrationNumber.isNotEmpty
                                  ? _vehicle!.registrationNumber
                                  : _vehicle!.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_vehicle!.vehicleType.isNotEmpty ? _vehicle!.vehicleType : 'Vehicle'} • ${_vehicle!.name.isNotEmpty ? _vehicle!.name : _vehicle!.displayName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loading ? null : _pickWindow,
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(_windowLabel()),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _vehicle = null),
                        child: Text(AppStrings.of(context).t('change')),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildMap()),
                _buildControls(strings),
              ],
            ),
    );
  }

  Widget _buildMap() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 44),
              const SizedBox(height: 16),
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTrail,
                child: Text(AppStrings.of(context).t('retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_points.isEmpty) {
      return Center(
        child: Text(
          AppStrings.of(context).t('no_trip_data'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final polyline = _points.map((p) => p.toLatLng()).toList();
    final travelled = <LatLng>[
      ...polyline.sublist(0, _currentIndex + 1),
      _animatedPoint,
    ];
    final remaining = <LatLng>[
      _animatedPoint,
      ...polyline.sublist(_currentIndex + 1),
    ];

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: polyline.first,
            initialZoom: 14,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.vahanconnect.fleet_monitor',
            ),
            PolylineLayer(
              polylines: <Polyline>[
                ..._speedColouredRuns(travelled),
                Polyline(
                  points: remaining,
                  color: Colors.grey.withValues(alpha: 0.45),
                  strokeWidth: 3.5,
                ),
              ],
            ),
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: polyline.first,
                  child: const Icon(Icons.flag, color: Colors.green, size: 28),
                ),
                Marker(
                  point: polyline.last,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 28),
                ),
                Marker(
                  point: _animatedPoint,
                  width: 54,
                  height: 54,
                  child: Transform.rotate(
                    angle: _displayedBearing * math.pi / 180,
                    child: _VehicleMarker(vehicle: _vehicle!),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'replay_fit',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 3,
            tooltip: 'Fit route in view',
            onPressed: () {
              if (polyline.isNotEmpty) {
                final bounds = LatLngBounds.fromPoints(polyline);
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.fromLTRB(40, 40, 40, 180),
                  ),
                );
              }
            },
            child: const Icon(LucideIcons.maximize2, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(AppStrings strings) {
    if (_points.isEmpty) return const SizedBox.shrink();
    final point = _points[_currentIndex];
    final progress = _points.length <= 1
        ? 1.0
        : (_currentIndex + _animController.value) / (_points.length - 1);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildSpeedGraph(),
          Slider(
            value: progress.clamp(0, 1),
            onChanged: (v) {
              final wasPlaying = _playing;
              _animController.stop();
              final i = (v * (_points.length - 1)).round();
              setState(() {
                _currentIndex = i;
                _playing = false;
                _displayedBearing = _segmentBearing(i);
              });
              _animController.value = 0;
              try {
                _mapController.move(
                    _points[i].toLatLng(), _mapController.camera.zoom);
              } catch (_) {}
              if (wasPlaying && i < _points.length - 1) {
                setState(() => _playing = true);
                _animController.forward(from: 0);
              }
            },
          ),
          Row(
            children: <Widget>[
              IconButton(
                iconSize: 36,
                onPressed: _togglePlay,
                icon: Icon(
                  _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: AppTheme.primaryBlue,
                ),
                tooltip: _playing ? strings.t('pause') : strings.t('play'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Point ${_currentIndex + 1} / ${_points.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    Text(
                      '${point.speed.toStringAsFixed(1)} km/h  •  ${point.createdAt}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              _speedChip(1),
              const SizedBox(width: 4),
              _speedChip(2),
              const SizedBox(width: 4),
              _speedChip(4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGraph() {
    if (_points.length < 2) return const SizedBox.shrink();
    var maxSpeed = 1.0;
    final spots = <FlSpot>[];
    for (var i = 0; i < _points.length; i++) {
      final s = _points[i].speed.toDouble();
      if (s > maxSpeed) maxSpeed = s;
      spots.add(FlSpot(i.toDouble(), s));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 54,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxSpeed * 1.15,
            minX: 0,
            maxX: (_points.length - 1).toDouble(),
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 2,
                color: AppTheme.primaryBlue,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                ),
              ),
            ],
            extraLinesData: ExtraLinesData(
              verticalLines: <VerticalLine>[
                VerticalLine(
                  x: _currentIndex.toDouble(),
                  color: AppColors.orange,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _speedChip(double mult) {
    final selected = _speedMultiplier == mult;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _setSpeed(mult),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${mult.toInt()}x',
          style: TextStyle(
            color: selected ? Colors.white : colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Clean vehicle marker with drop shadow and high-DPI scaling.
class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.vehicle});

  final VehicleRecord vehicle;

  @override
  Widget build(BuildContext context) {
    final hasIcon = vehicle.vehicleIconUrl.isNotEmpty;
    final fallback = Icon(
      _TripReplayScreenState._vehicleIconData(vehicle.vehicleType),
      color: AppTheme.primaryBlue,
      size: 42,
    );
    if (!hasIcon) return fallback;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CachedNetworkImage(
        imageUrl: vehicle.vehicleIconUrl,
        fit: BoxFit.contain,
        placeholder: (c, u) => fallback,
        errorWidget: (c, u, e) => fallback,
      ),
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({required this.onPick});
  final ValueChanged<VehicleRecord> onPick;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VehicleCubit, VehicleState>(
      builder: (context, state) {
        final vehicles = state.vechileListModel?.data ?? <VehicleRecord>[];
        if (vehicles.isEmpty) {
          if (state is VehicleLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(child: Text(AppStrings.of(context).t('no_vehicles_available')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final v = vehicles[i];
            return ListTile(
              leading: SizedBox(
                width: 40,
                height: 40,
                child: v.vehicleIconUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: v.vehicleIconUrl,
                        fit: BoxFit.contain,
                        errorWidget: (c, u, e) =>
                            Icon(_TripReplayScreenState._vehicleIconData(v.vehicleType)),
                      )
                    : Icon(_TripReplayScreenState._vehicleIconData(v.vehicleType)),
              ),
              title: Text(
                v.registrationNumber.isNotEmpty
                    ? v.registrationNumber
                    : v.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${v.vehicleType.isNotEmpty ? v.vehicleType : 'Vehicle'} • ${v.name.isNotEmpty ? v.name : v.displayName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPick(v),
            );
          },
        );
      },
    );
  }
}
