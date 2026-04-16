import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/single_vehicle_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VehicleListWidget extends StatefulWidget {
  const VehicleListWidget({super.key});

  static const String routeName = 'vehicle_listWidget';

  @override
  State<VehicleListWidget> createState() => _VehicleListWidgetState();
}

class _VehicleListWidgetState extends State<VehicleListWidget> {
  static const Duration _autoRefreshInterval = Duration(seconds: 3);
  final TextEditingController _searchController = TextEditingController();
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;
  String _searchText = '';

  Future<void> _sendEngineCommand(VehicleRecord vehicle, String action) async {
    final cubit = context.read<SingleTrackCubit>();
    final saved = await cubit.sendEngineCommand(
      vehicle: vehicle,
      action: action,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? '${action == 'immobilize' ? 'Engine stop' : 'Engine start'} request queued for ${vehicle.displayName}'
              : 'Unable to process engine command',
        ),
      ),
    );
    if (saved) {
      await context.read<VehicleCubit>().fetchVehicles();
    }
  }

  @override
  void initState() {
    super.initState();
    final cubit = context.read<VehicleCubit>();
    if (cubit.state.vechileListModel == null) {
      cubit.fetchVehicles();
    }
    // _startAutoRefresh();
  }

  // void _startAutoRefresh() {
  //   _autoRefreshTimer?.cancel();
  //   _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
  //     if (!mounted || _isAutoRefreshing) {
  //       return;
  //     }
  //     _isAutoRefreshing = true;
  //     unawaited(_refreshVehicles());
  //   });
  // }

  Future<void> _refreshVehicles() async {
    try {
      await context.read<VehicleCubit>().fetchVehicles();
    } finally {
      _isAutoRefreshing = false;
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Image.asset(Assets.images.mylogo.path, height: 30)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildSearchBar(),
            Expanded(
              child: BlocBuilder<VehicleCubit, VehicleState>(
                builder: (context, state) {
                  final vehicles =
                      state.vechileListModel?.data ?? <VehicleRecord>[];
                  final filteredVehicles = vehicles.where((vehicle) {
                    final query = _searchText.trim().toLowerCase();
                    if (query.isEmpty) {
                      return true;
                    }

                    return vehicle.registrationNumber.toLowerCase().contains(
                          query,
                        ) ||
                        vehicle.name.toLowerCase().contains(query) ||
                        vehicle.imei.toLowerCase().contains(query);
                  }).toList();

                  if (state is VehicleLoadingState && vehicles.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is VehicleErrorState && vehicles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _refreshVehicles(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (filteredVehicles.isEmpty) {
                    return const Center(
                      child: CustomText(text: 'No vehicles found'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshVehicles,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = filteredVehicles[index];
                        return _buildVehicleCard(vehicle);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchText = value),
        decoration: InputDecoration(
          hintText: 'Search by vehicle number, name, or IMEI',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleRecord vehicle) {
    final statusColor = getStatusColor(vehicle.statusLabel);
    final canControlEngine =
        vehicle.allowEngineControl == 1 && vehicle.engineCutoff == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1.5),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(vehicle),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // --- Header ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildVehicleIcon(vehicle),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          vehicle.registrationNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        Text(
                          vehicle.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(vehicle.statusLabel, statusColor),
                ],
              ),
              const SizedBox(height: 20),

              // --- Telemetry Grid ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _buildTelemetryItem(
                      icon: LucideIcons.gauge,
                      value: '${vehicle.speed.round()} km/h',
                      label: 'Speed',
                      color: AppTheme.primaryBlue,
                    ),
                    _divider(),
                    _buildTelemetryItem(
                      icon: LucideIcons.batteryMedium,
                      value: '${vehicle.battery}%',
                      label: 'Battery',
                      color: _getBatteryColor(vehicle.battery),
                    ),
                    _buildTelemetryItem(
                      icon: vehicle.engineOn
                          ? LucideIcons.activity
                          : LucideIcons.power,
                      value: vehicle.engineOn ? 'ON' : 'OFF',
                      label: 'ACC',
                      color: vehicle.engineOn
                          ? AppTheme.primaryGreen
                          : Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Driver Info (If Active) ---
              if (vehicle.activeDriver?.isActive == true) ...<Widget>[
                _buildDriverSection(vehicle),
                const SizedBox(height: 20),
              ],

              // --- Actions ---
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildActionButton(
                      onTap: () => _navigateToDetail(vehicle),
                      icon: LucideIcons.map,
                      label: 'Live Track',
                      color: AppTheme.primaryBlue,
                      isOutline: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (canControlEngine)
                    Expanded(
                      child: _buildActionButton(
                        onTap: vehicle.isImmobilizerBusy
                            ? null
                            : () => _sendEngineCommand(
                                vehicle,
                                vehicle.isImmobilized
                                    ? 'restore'
                                    : 'immobilize',
                              ),
                        icon: vehicle.isImmobilized
                            ? LucideIcons.playCircle
                            : LucideIcons.stopCircle,
                        label: vehicle.isImmobilized
                            ? 'Start Engine'
                            : 'Stop Engine',
                        color: vehicle.isImmobilized
                            ? AppTheme.primaryGreen
                            : Colors.red,
                        isLoading: vehicle.isImmobilizerBusy,
                      ),
                    ),
                ],
              ),

              // --- Footer Info ---
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    LucideIcons.clock,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Last Update: ${_formatUpdatedAt(vehicle.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (vehicle.imei.isNotEmpty)
                    Text(
                      'ID: ${vehicle.imei}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

  void _navigateToDetail(VehicleRecord vehicle) {
    context.read<SingleTrackCubit>().fetchVehicleTrack(vehicle.imei);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const VehicleDetailScreen(),
      ),
    );
  }

  Widget _divider() => Container(
    height: 30,
    width: 1,
    color: Colors.grey.withValues(alpha: 0.2),
  );

  Widget _buildVehicleIcon(VehicleRecord vehicle) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CachedNetworkImage(
          imageUrl: vehicle.vehicleIconUrl,
          placeholder: (context, url) => const Icon(
            LucideIcons.truck,
            color: AppTheme.primaryBlue,
            size: 24,
          ),
          errorWidget: (context, url, error) => const Icon(
            LucideIcons.truck,
            color: AppTheme.primaryBlue,
            size: 24,
          ),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverSection(VehicleRecord vehicle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'DRIVING NOW',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  vehicle.activeDriver!.displayName,
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (vehicle.activeDriver!.identificationMethod.isNotEmpty)
            _buildStatusBadge(
              vehicle.activeDriver!.identificationMethod,
              AppTheme.primaryGreen,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required Color color,
    bool isOutline = false,
    bool isLoading = false,
  }) {
    final effectiveColor = onTap == null ? Colors.grey : color;

    if (isOutline) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveColor,
          side: BorderSide(color: effectiveColor),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: effectiveColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 60) {
      return AppTheme.primaryGreen;
    }
    if (level > 20) {
      return Colors.orange;
    }
    return Colors.red;
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Moving':
        return AppTheme.primaryGreen;
      case 'Idle':
        return Colors.orange;
      case 'Stopped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatUpdatedAt(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return 'Now';
    }
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
