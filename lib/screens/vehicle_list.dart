import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/services/geofence_monitor_service.dart';
import 'package:fleet_monitor/services/lifecycle_refresh.dart';
import 'package:fleet_monitor/widgets/app_logo.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/drawer.dart';
import 'package:fleet_monitor/widgets/live_address_text.dart';
import 'package:fleet_monitor/widgets/single_vehicle_track.dart';
import 'package:fleet_monitor/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VehicleListWidget extends StatefulWidget {
  const VehicleListWidget({super.key, this.onSelectTab});
  static const String routeName = 'vehicle_listWidget';
  final ValueChanged<int>? onSelectTab;
  @override
  State<VehicleListWidget> createState() => _VehicleListWidgetState();
}

class _VehicleListWidgetState extends State<VehicleListWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _autoRefreshTimer;
  String _searchText = '';
  // Auto-refresh the vehicle list every 30 s while in foreground, and on
  // every app resume. Cancels itself when the app is paused so we don't
  // burn data / battery while the user isn't looking.
  late final LifecycleRefresh _lifecycle = LifecycleRefresh(
    onRefresh: () async {
      if (!mounted) return;
      await context.read<VehicleCubit>().fetchVehicles();
      if (!mounted) return;
      // Evaluate user-defined geofences against the fresh snapshot. The
      // service swallows its own errors so a missing zone file / bad data
      // can never break the refresh loop.
      final vehicles =
          context.read<VehicleCubit>().state.vechileListModel?.data ??
              <VehicleRecord>[];
      final strings = AppStrings.of(context);
      await GeofenceMonitorService.instance.evaluate(
        vehicles: vehicles,
        entryLabel: strings.t('geofence_entry_alert'),
        exitLabel: strings.t('geofence_exit_alert'),
      );
    },
    interval: const Duration(seconds: 30),
  );

  @override
  void initState() {
    super.initState();
    final cubit = context.read<VehicleCubit>();
    if (cubit.state.vechileListModel == null) {
      cubit.fetchVehicles();
    }
    _lifecycle.start();
  }

  Future<void> _refreshVehicles() async {
    await context.read<VehicleCubit>().fetchVehicles();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _lifecycle.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _filterStatus = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: AppDrawer(onSelectTab: widget.onSelectTab),
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AppLogo(),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.bell, color: Color(0xFF1A1A1A)),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<VehicleCubit, VehicleState>(
        builder: (context, state) {
          final vehicles = state.vechileListModel?.data ?? <VehicleRecord>[];
          final stats = _calculateStats(vehicles);
          final filteredVehicles = vehicles.where((vehicle) {
            final query = _searchText.trim().toLowerCase();
            final matchesSearch = query.isEmpty ||
                vehicle.registrationNumber.toLowerCase().contains(query) ||
                vehicle.name.toLowerCase().contains(query) ||
                vehicle.imei.toLowerCase().contains(query);

            final matchesStatus = _filterStatus == 'All' ||
                (_filterStatus == 'Moving' && vehicle.isMoving) ||
                (_filterStatus == 'Idle' && vehicle.isIdle) ||
                (_filterStatus == 'Stopped' && vehicle.isStopped) ||
                (_filterStatus == 'Offline' && _isOffline(vehicle)) ||
                (_filterStatus == 'LowBattery' && _isLowBattery(vehicle)) ||
                (_filterStatus == 'Overspeed' && _isOverspeed(vehicle));

            return matchesSearch && matchesStatus;
          }).toList();

          return Column(
            children: <Widget>[
              _buildTopSearchRow(),
              _buildStatusFilterRow(stats),
              Expanded(
                child: state is VehicleLoadingState && vehicles.isEmpty
                    ? ListView.builder(
                        // 6 skeleton rows = 1 viewport's worth. Layout-aware
                        // placeholders feel premium on slow / first-launch
                        // networks instead of a lonely centred spinner.
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: 6,
                        itemBuilder: (context, index) => const SkeletonVehicleRow(),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshVehicles,
                        child: filteredVehicles.isEmpty
                            ? Center(child: CustomText(text: AppStrings.of(context).t('no_vehicles_found')))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: filteredVehicles.length,
                                itemBuilder: (context, index) => _buildModernVehicleCard(filteredVehicles[index]),
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, int> _calculateStats(List<VehicleRecord> vehicles) {
    int moving = 0;
    int idle = 0;
    int stopped = 0;
    int offline = 0;
    int lowBattery = 0;
    int overspeed = 0;
    for (var v in vehicles) {
      if (v.isMoving) {
        moving++;
      } else if (v.isIdle) {
        idle++;
      } else {
        stopped++;
      }
      if (_isOffline(v)) offline++;
      if (_isLowBattery(v)) lowBattery++;
      if (_isOverspeed(v)) overspeed++;
    }
    return {
      'total': vehicles.length,
      'moving': moving,
      'idle': idle,
      'stopped': stopped,
      'offline': offline,
      'lowBattery': lowBattery,
      'overspeed': overspeed,
    };
  }

  // A vehicle is "offline" when the device hasn't reported a real position
  // recently. We use the `hasLiveLocation` flag the API already sets — true
  // means lat/lng is non-zero AND fresh per the backend's threshold.
  bool _isOffline(VehicleRecord v) => !v.hasLiveLocation;

  // Battery is a 0–100 integer on the device payload. Below 20 flags as
  // "low" — same threshold used by most fleet tools.
  bool _isLowBattery(VehicleRecord v) => v.battery > 0 && v.battery < 20;

  // Vehicle is currently exceeding its configured overspeed limit. Skip
  // when no limit set (overspeedLimit <= 0) or the vehicle isn't actually
  // moving (a stopped car can't be speeding).
  bool _isOverspeed(VehicleRecord v) =>
      v.overspeedLimit > 0 && v.speed > v.overspeedLimit && v.isMoving;

  Widget _buildTopSearchRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = Theme.of(context).cardTheme.color ?? Colors.white;
    final fieldBg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final borderColor =
        isDark ? Colors.white12 : const Color(0xFFE0E0E0);
    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchText = v),
                decoration: InputDecoration(
                  hintText: AppStrings.of(context).t('search_vehicle_hint'),
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF9E9E9E)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.slidersHorizontal, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterRow(Map<String, int> stats) {
    final strings = AppStrings.of(context);
    final rowBg = Theme.of(context).cardTheme.color ?? Colors.white;
    // (filterKey, localisedLabel, count, accentColor)
    final chips = <(String, String, int, Color)>[
      ('All', strings.t('filter_all'), stats['total']!, const Color(0xFF003366)),
      ('Moving', strings.t('status_moving'), stats['moving']!, Colors.green),
      ('Idle', strings.t('status_idle'), stats['idle']!, Colors.orange),
      ('Stopped', strings.t('status_stopped'), stats['stopped']!, Colors.red),
      ('Offline', strings.t('filter_offline'), stats['offline']!, Colors.grey),
      ('LowBattery', strings.t('filter_low_battery'), stats['lowBattery']!, Colors.deepOrange),
      ('Overspeed', 'Overspeed', stats['overspeed']!, Colors.red.shade700),
    ];
    return Container(
      color: rowBg,
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips
            .map((c) => _buildFilterChip(c.$1, c.$2, c.$3, c.$4))
            .toList(),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, int count, Color color) {
    final isSelected = _filterStatus == filterKey;
    final activeColor = filterKey == 'All' ? const Color(0xFF001F3F) : color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final chipBorder = isDark ? Colors.white24 : const Color(0xFFE0E0E0);
    final chipFg = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => setState(() => _filterStatus = filterKey),
      child: Container(
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : chipBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : chipFg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (count > 0 || filterKey == 'All') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : activeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernVehicleCard(VehicleRecord vehicle) {
    final statusColor = getStatusColor(vehicle.statusLabel);
    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ?? Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildVehicleImage(vehicle),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.registrationNumber, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: titleColor)),
                    if (vehicle.showExpiryBadge) ...<Widget>[
                      const SizedBox(height: 5),
                      _buildExpiryBadge(vehicle),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(_localizedStatus(strings, vehicle.statusLabel), style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11)),
                        const SizedBox(width: 10),
                        // GSM signal mini-bars (0-4). Lets operators spot
                        // weak-connectivity devices at a glance in the
                        // fleet list without drilling into each one.
                        Icon(
                          vehicle.gsmSignal >= 1
                              ? LucideIcons.wifi
                              : LucideIcons.wifiOff,
                          size: 12,
                          color: vehicle.gsmSignal >= 3
                              ? Colors.green
                              : (vehicle.gsmSignal >= 2
                                  ? Colors.orange
                                  : Colors.red.shade400),
                        ),
                        const SizedBox(width: 6),
                        // GPS lock dot — green if 5+ sats (solid), orange
                        // if 3-4 (weak), red/grey if < 3.
                        Icon(
                          LucideIcons.satellite,
                          size: 11,
                          color: vehicle.satellites >= 5
                              ? Colors.green
                              : (vehicle.satellites >= 3
                                  ? Colors.orange
                                  : Colors.grey.shade400),
                        ),
                        if (vehicle.satellites > 0) ...<Widget>[
                          const SizedBox(width: 2),
                          Text(
                            '${vehicle.satellites}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 35, color: const Color(0xFFF1F4F8)),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LiveAddressText(
                            latitude: vehicle.latitude,
                            longitude: vehicle.longitude,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showFullAddressModal(vehicle),
                          child: Icon(
                            LucideIcons.info,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('${strings.t('updated_label')} ${_formatUpdatedAtShort(vehicle.createdAt, strings)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricTile(LucideIcons.gauge, '${vehicle.speed.round()}', 'km/h', strings.t('speed_label'), Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile(LucideIcons.activity, vehicle.currentOdometer.toStringAsFixed(0), 'km', 'ODOMETER', Colors.purple)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile(LucideIcons.power, vehicle.engineOn ? strings.t('on') : strings.t('off'), '', strings.t('engine'), vehicle.engineOn ? Colors.green : Colors.red)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F4F8)),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ODOMETER', style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  Text('${vehicle.currentOdometer.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: const Color(0xFFF1F4F8)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TYPE', style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    Text(vehicle.typeName.isNotEmpty ? vehicle.typeName : '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildBtn(LucideIcons.navigation, strings.t('track'), const Color(0xFFE3F2FD), Colors.blue, () => _navigateToDetail(vehicle)),
            ],
          ),
        ],
      ),
    );
  }

  /// Red "X days left" / "Expired" pill for the device/plan subscription
  /// expiry. Only rendered when the vehicle is within the 7-day window or
  /// already expired (vehicle.showExpiryBadge). Expired = solid red; expiring
  /// soon = red text on a light-red tint.
  Widget _buildExpiryBadge(VehicleRecord vehicle) {
    final bool expired = vehicle.isExpired;
    const Color red = Color(0xFFE53935);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: expired ? red : red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: expired
            ? null
            : Border.all(color: red.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            expired ? Icons.error_outline_rounded : Icons.access_time_rounded,
            size: 12,
            color: expired ? Colors.white : red,
          ),
          const SizedBox(width: 4),
          Text(
            vehicle.expiryBadgeLabel,
            style: TextStyle(
              color: expired ? Colors.white : red,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleImage(VehicleRecord vehicle) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(color: const Color(0xFFF1F4F8), borderRadius: BorderRadius.circular(10)),
      child: CachedNetworkImage(
        imageUrl: vehicle.vehicleIconUrl,
        fit: BoxFit.contain,
        errorWidget: (c, u, e) => Icon(LucideIcons.truck, color: Colors.blue, size: 20),
      ),
    );
  }

  Widget _buildMetricTile(IconData icon, String val, String unit, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF1F4F8);
    final valColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: valColor)),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 1),
                      Text(unit, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 7, color: Colors.grey.shade500, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
        ],
      ),
    );
  }

  Widget _buildBtn(IconData icon, String label, Color bg, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _formatUpdatedAtShort(String value, AppStrings strings) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return strings.t('now');
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${strings.t('min_ago')}';
    if (diff.inHours < 24) return '${diff.inHours} ${strings.t('hr_ago')}';
    return '${diff.inDays} ${strings.t('days_ago')}';
  }

  // Maps the engine-derived English status label coming out of VehicleRecord
  // back to a translated string for display. Filtering still uses the
  // English keys so the lookup logic stays language-independent.
  String _localizedStatus(AppStrings strings, String label) {
    switch (label) {
      case 'Moving':
        return strings.t('status_moving');
      case 'Idle':
        return strings.t('status_idle');
      case 'Stopped':
        return strings.t('status_stopped');
      default:
        return label;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Moving': return Colors.green;
      case 'Idle': return Colors.orange;
      case 'Stopped': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showFullAddressModal(VehicleRecord vehicle) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.mapPin,
                    color: AppTheme.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicle.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LiveAddressText(
              latitude: vehicle.latitude,
              longitude: vehicle.longitude,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.5,
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 14),
            Text(
              'Coordinates: ${vehicle.latitude.toStringAsFixed(6)}, ${vehicle.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(VehicleRecord vehicle) {
    context.read<SingleTrackCubit>().fetchVehicleTrack(vehicle.imei);
    Navigator.push(context, MaterialPageRoute<void>(builder: (context) => const VehicleDetailScreen()));
  }
}
