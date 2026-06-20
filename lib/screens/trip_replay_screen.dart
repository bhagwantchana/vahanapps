import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
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
/// window, then animate a marker along the polyline with play/pause and
/// 1×/2×/4× speed controls. Uses the existing `fetchTripHistoryTrail` API.
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
  /// but eased over a few frames so that sharp turns don't snap the icon
  /// — that's the difference between an "okay" replay and a polished one.
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
      Duration(milliseconds: (500 / _speedMultiplier).round());

  void _onAnimTick() {
    if (!mounted) return;
    // Ease the displayed bearing towards the segment's true bearing — keeps
    // the icon from snapping on sharp direction changes.
    final target = _segmentBearing(_currentIndex);
    _displayedBearing = _easeBearing(_displayedBearing, target, 0.18);
    // Pan the camera to track the marker every frame. Calling move() before
    // setState avoids a double layout pass — the FlutterMap reads the new
    // centre during the rebuild below. This is what makes the playback feel
    // continuous instead of snapping at segment boundaries.
    try {
      _mapController.move(_animatedPoint, _mapController.camera.zoom);
    } catch (_) {
      // move()/camera throw "You need to have the FlutterMap ..." when the map
      // isn't attached to the controller this frame (tick fired before the
      // first layout, or after the map detached during a screen transition).
      // Skip the pan for this frame; the next tick tracks the marker fine.
    }
    setState(() {});
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_currentIndex < _points.length - 2) {
      _currentIndex++;
      _animController.forward(from: 0);
      // Camera already tracks the marker every tick — no extra move needed
      // here, otherwise we'd cause a jitter on the segment hand-off.
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
      // Drop consecutive duplicate coordinates (a parked vehicle re-reporting
      // the same fix). Zero-length segments would otherwise burn a full
      // animation step doing nothing, making playback feel like it stalls.
      final points = _dedupeConsecutive(fetched);
      if (!mounted) return;
      setState(() {
        _points = points;
        _loading = false;
        _displayedBearing = _segmentBearing(0);
      });
      // Centre on the first point so the user sees something even before
      // they tap play. flutter_map throws if we move before a tile is laid
      // out, so wrap in a post-frame callback.
      if (points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.move(points.first.toLatLng(), 14);
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

  /// Short label for the active window, e.g. "Today", "14/06", "12/06 – 14/06".
  String _windowLabel() {
    String dm(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    if (_isSameDay(_from, _to)) {
      return _isSameDay(_from, DateTime.now()) ? 'Today' : dm(_from);
    }
    return '${dm(_from)} – ${dm(_to)}';
  }

  /// Lets the user replay a single day or a date range. Defaults stay TODAY.
  Future<void> _pickWindow() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(LucideIcons.calendar),
              title: const Text('Single date'),
              onTap: () => Navigator.pop(ctx, 'single'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Date range'),
              onTap: () => Navigator.pop(ctx, 'range'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final now = DateTime.now();
    final first = DateTime(now.year - 3);
    if (choice == 'single') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _from.isAfter(now) ? now : _from,
        firstDate: first,
        lastDate: now,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _from = _dayStart(picked);
        _to = _isSameDay(picked, now) ? now : _dayEnd(picked);
      });
    } else {
      final range = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(
          start: _dayStart(_from),
          end: _to.isAfter(now) ? now : _to,
        ),
        firstDate: first,
        lastDate: now,
      );
      if (range == null || !mounted) return;
      setState(() {
        _from = _dayStart(range.start);
        _to = _isSameDay(range.end, now) ? now : _dayEnd(range.end);
      });
    }
    _loadTrail();
  }

  void _togglePlay() {
    if (_points.length < 2) return;
    if (_playing) {
      _animController.stop();
      setState(() => _playing = false);
      return;
    }
    // If we sit on the last sample, restart from the beginning.
    if (_currentIndex >= _points.length - 1) {
      _currentIndex = 0;
      _animController.value = 0;
      _displayedBearing = _segmentBearing(0);
      _mapController.move(
          _points[0].toLatLng(), _mapController.camera.zoom);
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

  /// Linear interpolation between consecutive GPS samples. Good enough at
  /// city scale where samples are seconds apart — no need for great-circle
  /// maths.
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

  /// Initial bearing (in degrees, 0–360, 0 = north, clockwise) from the
  /// start of the segment beginning at `index` to its end. Returns the
  /// previous segment's bearing when `index` is the last sample so the
  /// icon doesn't flip on the final point.
  double _segmentBearing(int index) {
    if (_points.length < 2) return _displayedBearing;
    final i = index.clamp(0, _points.length - 2);
    final a = _points[i].toLatLng();
    final b = _points[i + 1].toLatLng();
    if (a.latitude == b.latitude && a.longitude == b.longitude) {
      // Vehicle parked — keep the previous heading rather than snap to 0.
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

  /// Linear shortest-path ease between two compass bearings. Handles the
  /// 359° → 1° wrap so the marker turns 2° clockwise instead of 358°
  /// counter-clockwise.
  double _easeBearing(double current, double target, double t) {
    double delta = target - current;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return (current + delta * t + 360) % 360;
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
                      const Icon(LucideIcons.car, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _vehicle!.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loading ? null : _pickWindow,
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(_windowLabel()),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
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
              Icon(LucideIcons.alertTriangle, color: Colors.red, size: 44),
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
    // Build a "travelled so far" polyline that includes the interpolated
    // marker position as its final vertex — that way the blue trail visibly
    // grows under the moving icon instead of jumping by whole segments.
    final travelled = <LatLng>[
      ...polyline.sublist(0, _currentIndex + 1),
      _animatedPoint,
    ];
    final remaining = <LatLng>[
      _animatedPoint,
      ...polyline.sublist(_currentIndex + 1),
    ];

    return FlutterMap(
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
            Polyline(
              points: travelled,
              color: AppTheme.primaryBlue,
              strokeWidth: 4,
            ),
            Polyline(
              points: remaining,
              color: Colors.grey.withValues(alpha: 0.5),
              strokeWidth: 3,
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
              width: 56,
              height: 56,
              // The PNG icons are designed nose-up (0° = north). Bearing is
              // already measured clockwise from north, which is exactly what
              // Transform.rotate expects (positive = clockwise on screen).
              child: Transform.rotate(
                angle: _displayedBearing * math.pi / 180,
                child: _VehicleMarker(vehicle: _vehicle!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(AppStrings strings) {
    if (_points.isEmpty) return const SizedBox.shrink();
    final point = _points[_currentIndex];
    // Progress includes the in-segment animation fraction so the slider
    // thumb glides smoothly during playback instead of stepping per sample.
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
              _mapController.move(
                  _points[i].toLatLng(), _mapController.camera.zoom);
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
                icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: AppTheme.primaryBlue),
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

/// Clean vehicle marker — just the vehicle's own icon, nothing else.
/// No background, no halo, no drop shadow (BoxShadow on a transparent PNG
/// container draws a rectangle behind the icon which reads as a dark blob).
class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.vehicle});

  final VehicleRecord vehicle;

  @override
  Widget build(BuildContext context) {
    final hasIcon = vehicle.vehicleIconUrl.isNotEmpty;
    const fallback = Icon(
      LucideIcons.car,
      color: AppTheme.primaryBlue,
      size: 40,
    );
    if (!hasIcon) return fallback;

    return CachedNetworkImage(
      imageUrl: vehicle.vehicleIconUrl,
      fit: BoxFit.contain,
      placeholder: (c, u) => fallback,
      errorWidget: (c, u, e) => fallback,
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
          return const Center(child: Text('No vehicles available'));
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
                            const Icon(LucideIcons.car),
                      )
                    : const Icon(LucideIcons.car),
              ),
              title: Text(v.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(v.imei),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPick(v),
            );
          },
        );
      },
    );
  }
}
