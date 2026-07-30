import 'dart:math' as math;

import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/widgets/google_fleet_map.dart';
import 'package:fleet_monitor/widgets/live_address_text.dart';
import 'package:fleet_monitor/widgets/native_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// School / fleet "front look": a FULL-SCREEN native **Google Maps** fleet view.
/// A catchy status bar on top (Total / Running / Idle / Stopped / Offline /
/// Overspeed) filters the map on tap; a recenter button re-fits the fleet.
/// Tapping a vehicle pans to it and slides a compact details card up (address,
/// status, speed, odometer, signal) with Track + Share; the map stays
/// full-screen. `mobile_map_mode = native` shows this; `url` keeps the WebView
/// dashboard, so both options remain available.
class FleetFullMap extends StatefulWidget {
  const FleetFullMap({
    super.key,
    required this.vehicles,
    required this.moveAnimationDuration,
    required this.mapProvider,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.onTrack,
    this.initialFilter = 'all',
    this.onBack,
  });

  final List<VehicleRecord> vehicles;
  final Duration moveAnimationDuration; // kept for API compatibility
  final String mapProvider;
  final String emptyTitle;
  final String emptySubtitle;

  /// Opens the full single-vehicle tracking screen for the sheet's vehicle.
  final void Function(VehicleRecord vehicle)? onTrack;

  /// Pre-selected status filter (e.g. opened from the overview pie chart).
  final String initialFilter;

  /// When set (map opened from the Overview dashboard), a back button appears
  /// to return to the pie chart.
  final VoidCallback? onBack;

  @override
  State<FleetFullMap> createState() => _FleetFullMapState();
}

class _FleetFullMapState extends State<FleetFullMap> {
  int? _selectedId;
  late String _filter = widget.initialFilter; // all|running|idle|stopped|offline|overspeed
  int _recenterTick = 0;

  // Delegate so the counts bar can never disagree with the marker colour: this
  // used its own 30-minute window while statusKey moved to 8.
  bool _isOffline(VehicleRecord v) => v.statusKey == 'offline';

  bool _isOverspeed(VehicleRecord v) =>
      v.overspeedLimit > 0 && v.speed > v.overspeedLimit;

  /// One exclusive bucket per vehicle (offline wins, matching the marker grey).
  String _bucket(VehicleRecord v) {
    if (_isOffline(v)) return 'offline';
    if (v.isMoving) return 'running';
    if (v.isStopped) return 'stopped';
    return 'idle';
  }

  bool _matchesFilter(VehicleRecord v) {
    if (_filter == 'all') return true;
    if (_filter == 'overspeed') return _isOverspeed(v);
    return _bucket(v) == _filter;
  }

  List<VehicleRecord> get _filtered =>
      widget.vehicles.where(_matchesFilter).toList();

  /// Live record for the selected id, re-read every build so the card updates
  /// as positions poll in. Null once the vehicle leaves the filter/set.
  VehicleRecord? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final vehicle in _filtered) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  Map<String, int> get _counts {
    var running = 0, idle = 0, stopped = 0, offline = 0, over = 0;
    for (final v in widget.vehicles) {
      switch (_bucket(v)) {
        case 'offline':
          offline++;
          break;
        case 'running':
          running++;
          break;
        case 'stopped':
          stopped++;
          break;
        default:
          idle++;
      }
      if (_isOverspeed(v)) over++;
    }
    return <String, int>{
      'all': widget.vehicles.length,
      'running': running,
      'idle': idle,
      'stopped': stopped,
      'offline': offline,
      'overspeed': over,
    };
  }

  void _onVehicleTap(VehicleRecord vehicle) {
    setState(() => _selectedId = vehicle.id);
  }

  void _closeSheet() {
    setState(() => _selectedId = null);
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = _filter == filter ? 'all' : filter;
      if (_selectedId != null && _selected == null) {
        _selectedId = null;
      }
    });
  }

  void _recenter() {
    setState(() => _recenterTick++);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final counts = _counts;
    // Map engine follows the superadmin setting (mobile_map_provider): 'google'
    // → native Google Maps; anything else → the free MapLibre map. The bar,
    // card, share, recenter overlays sit on top of whichever engine.
    final useGoogle = widget.mapProvider.toLowerCase() == 'google';
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: useGoogle
              ? GoogleFleetMap(
                  vehicles: _filtered,
                  focusVehicleId: _selectedId,
                  fitKey: _filter,
                  recenterTick: _recenterTick,
                  onVehicleTap: _onVehicleTap,
                  onMapTap: _closeSheet,
                )
              : NativeVehicleMap(
                  vehicles: _filtered,
                  focusVehicle: selected,
                  onVehicleTap: _onVehicleTap,
                  moveAnimationDuration: widget.moveAnimationDuration,
                  emptyTitle: widget.emptyTitle,
                  emptySubtitle: widget.emptySubtitle,
                  mapProvider: widget.mapProvider,
                ),
        ),
        // Status counts bar — tap a chip to filter the map to those vehicles.
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            children: <Widget>[
              if (widget.onBack != null) ...<Widget>[
                _RoundButton(
                  icon: LucideIcons.arrowLeft,
                  onTap: widget.onBack!,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _CountsBar(
                  counts: counts,
                  active: _filter,
                  onSelect: _setFilter,
                ),
              ),
            ],
          ),
        ),
        // Recenter (re-fit fleet) button — Google engine only (MapLibre fits
        // once on load and doesn't expose a re-fit).
        if (useGoogle)
          Positioned(
            right: 14,
            bottom: selected != null ? 292 : 70,
            child: _RoundButton(
              icon: LucideIcons.locateFixed,
              onTap: _recenter,
            ),
          ),
        // Slim live fleet-summary bar (hidden while a vehicle card is open).
        if (selected == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FleetSummaryBar(
              total: counts['all'] ?? 0,
              running: counts['running'] ?? 0,
              offline: counts['offline'] ?? 0,
            ),
          ),
        if (selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _VehicleDetailsCard(
              vehicle: selected,
              onClose: _closeSheet,
              onTrack: widget.onTrack,
            ),
          ),
      ],
    );
  }
}

// ── Top counts bar ──────────────────────────────────────────────────────────
class _CountsBar extends StatelessWidget {
  const _CountsBar({
    required this.counts,
    required this.active,
    required this.onSelect,
  });

  final Map<String, int> counts;
  final String active;
  final void Function(String key) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <List<dynamic>>[
      <dynamic>['all', 'All', AppTheme.primaryBlue],
      <dynamic>['running', 'Running', AppColors.green],
      <dynamic>['idle', 'Idle', AppColors.orange],
      <dynamic>['stopped', 'Stopped', AppColors.red],
      <dynamic>['offline', 'Offline', AppColors.grey],
      <dynamic>['overspeed', 'Overspeed', AppColors.accent],
    ];
    // Light, clean floating pills (no heavy bar) — matches the app's light look.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: <Widget>[
          for (final it in items)
            _CountChip(
              label: it[1] as String,
              count: counts[it[0] as String] ?? 0,
              color: it[2] as Color,
              selected: active == it[0],
              onTap: () => onSelect(it[0] as String),
            ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selected = soft status-tinted pill; unselected = clean white pill. A
    // coloured status dot + bold count keep it readable and light.
    final bg = selected
        ? Color.alphaBlend(color.withValues(alpha: 0.16),
            theme.cardTheme.color ?? theme.cardColor)
        : (theme.cardTheme.color ?? theme.cardColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.9)
                : Colors.black.withValues(alpha: 0.06),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: count.toDouble()),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              builder: (context, value, _) => Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim live fleet-summary bar pinned to the bottom of the map.
class _FleetSummaryBar extends StatelessWidget {
  const _FleetSummaryBar({
    required this.total,
    required this.running,
    required this.offline,
  });

  final int total;
  final int running;
  final int offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Material(
      elevation: 10,
      color: theme.cardTheme.color ?? theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.6),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text('Live',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green)),
              _dot(onSurface),
              _seg('$total', 'tracking', onSurface),
              _dot(onSurface),
              _seg('$running', 'moving', onSurface),
              _dot(onSurface),
              _seg('$offline', 'offline', onSurface),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Text('·',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: c.withValues(alpha: 0.35))),
      );

  Widget _seg(String value, String label, Color onSurface) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: onSurface)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.cardColor,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 22, color: AppTheme.primaryBlue),
        ),
      ),
    );
  }
}

// ── Bottom details card (fixed height — everything fits, no scrolling) ───────
class _VehicleDetailsCard extends StatelessWidget {
  const _VehicleDetailsCard({
    required this.vehicle,
    required this.onClose,
    required this.onTrack,
  });

  final VehicleRecord vehicle;
  final VoidCallback onClose;
  final void Function(VehicleRecord vehicle)? onTrack;

  bool get _isOffline => vehicle.statusKey == 'offline';

  Color get _statusColor {
    if (_isOffline) return AppColors.grey;
    if (vehicle.isStopped) return AppColors.red;
    if (vehicle.isMoving) return AppColors.green;
    return AppColors.orange;
  }

  String get _statusLabel => _isOffline ? 'Offline' : vehicle.statusLabel;

  String get _lastUpdate => vehicle.lastUpdateLabel;

  void _shareLive() {
    final url = vehicle.primaryMapUrl.isNotEmpty
        ? vehicle.primaryMapUrl
        : vehicle.googleTrackingUrl;
    if (url.isEmpty) return;
    Share.share(
      'Track ${vehicle.displayName} live: $url',
      subject: 'Live location — ${vehicle.displayName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final reg = vehicle.registrationNumber.trim();
    final name = vehicle.name.trim().isNotEmpty
        ? vehicle.name.trim()
        : vehicle.displayName;

    return Material(
      elevation: 16,
      color: theme.cardTheme.color ?? theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.only(right: 11),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: vehicle.vehicleIconUrl.isNotEmpty
                        ? Image.network(
                            vehicle.statusIconUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Image.network(
                              vehicle.vehicleIconUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(LucideIcons.car,
                                  size: 20, color: _statusColor),
                            ),
                          )
                        : Icon(LucideIcons.car, size: 20, color: _statusColor),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (reg.isNotEmpty)
                          Text(
                            reg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SpeedGauge(speed: vehicle.speed, color: _statusColor),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(LucideIcons.x,
                        size: 19, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 1, right: 7),
                    child: Icon(LucideIcons.mapPin,
                        size: 15, color: Color(0xFF4A688A)),
                  ),
                  Expanded(
                    child: LiveAddressText(
                      latitude: vehicle.latitude,
                      longitude: vehicle.longitude,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  _MiniStat(
                    icon: LucideIcons.gauge,
                    label: 'Speed',
                    value: '${vehicle.speed.toStringAsFixed(0)} km/h',
                  ),
                  _MiniStat(
                    icon: LucideIcons.milestone,
                    label: 'Odometer',
                    value: vehicle.currentOdometer > 0
                        ? '${vehicle.currentOdometer.toStringAsFixed(0)} km'
                        : '—',
                  ),
                  _MiniStat(
                    icon: LucideIcons.clock,
                    label: 'Updated',
                    value: _lastUpdate,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _MiniStat(
                    icon: LucideIcons.satellite,
                    label: 'GPS',
                    value:
                        vehicle.satellites > 0 ? '${vehicle.satellites}' : '—',
                  ),
                  _MiniStat(
                    icon: LucideIcons.signal,
                    label: 'Network',
                    value: '${vehicle.gsmSignal}/4',
                  ),
                  _MiniStat(
                    icon: LucideIcons.batteryCharging,
                    label: 'Power',
                    value: vehicle.battery > 0 ? '${vehicle.battery}%' : '—',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed:
                            onTrack == null ? null : () => onTrack!(vehicle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(LucideIcons.navigation, size: 18),
                        label: const Text(
                          'Track Live',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    width: 52,
                    child: OutlinedButton(
                      onPressed: _shareLive,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: BorderSide(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.5),
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Icon(LucideIcons.share2, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular speedometer gauge (arc + centre readout) for the card header.
class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({required this.speed, required this.color});

  final double speed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 50,
      height: 50,
      child: CustomPaint(
        painter: _GaugePainter(
          speed: speed.clamp(0, 120).toDouble(),
          max: 120,
          color: color,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                speed.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                ),
              ),
              Text(
                'km/h',
                style: TextStyle(
                  fontSize: 7.5,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.speed, required this.max, required this.color});

  final double speed;
  final double max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const start = math.pi * 0.75; // 135°
    const sweep = math.pi * 1.5; // 270°
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.16);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), start, sweep, false, bg);
    final frac = max <= 0 ? 0.0 : (speed / max).clamp(0.0, 1.0);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
        sweep * frac, false, fg);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.speed != speed || old.color != color;
}

/// Compact stat pill — small so all six fit in the fixed card without scrolling.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 15, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
