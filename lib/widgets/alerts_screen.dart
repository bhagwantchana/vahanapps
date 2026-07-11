import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/alerts_cubit/alerts_cubit.dart';
import 'package:fleet_monitor/cubits/alerts_cubit/alerts_state.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/models/alert_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/repositorys/alerts_repository.dart';
import 'package:fleet_monitor/widgets/app_logo.dart';
import 'package:fleet_monitor/widgets/drawer.dart';
import 'package:fleet_monitor/widgets/single_vehicle_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.onSelectTab});

  /// Lets the shared drawer switch dashboard tabs from this screen.
  final ValueChanged<int>? onSelectTab;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertsRepository _alertsRepository = AlertsRepository();
  bool _isPanicSending = false;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<AlertsCubit>();
    if (cubit.state.alertListModel == null) {
      cubit.fetchAlerts();
    }
  }

  Future<void> _refreshAlerts() async {
    // Cache the cubits before awaiting — once we suspend, the widget can
    // unmount and `context.read` after that point throws.
    final alertsCubit = context.read<AlertsCubit>();
    final homeCubit = context.read<HomeCubit>();
    await alertsCubit.fetchAlerts(unreadOnly: _unreadOnly);
    await homeCubit.fetchHomeData();
  }

  Future<void> _openAlert(AlertItem alert) async {
    final alertsCubit = context.read<AlertsCubit>();
    final homeCubit = context.read<HomeCubit>();
    final trackCubit = context.read<SingleTrackCubit>();

    if (!alert.isRead) {
      await alertsCubit.markAsRead(alert.id);
      await homeCubit.fetchHomeData();
    }

    if (alert.imei.isEmpty) {
      return;
    }

    await trackCubit.fetchVehicleTrack(alert.imei);
    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const VehicleDetailScreen()),
    );
  }

  Future<void> _sendPanicAlert() async {
    final vehicleCubit = context.read<VehicleCubit>();
    if (vehicleCubit.state.vechileListModel == null) {
      await vehicleCubit.fetchVehicles();
    }

    if (!mounted) {
      return;
    }

    final vehicles =
        vehicleCubit.state.vechileListModel?.data ?? <VehicleRecord>[];
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No vehicle found to trigger panic alert'),
        ),
      );
      return;
    }

    var selectedVehicle = vehicles.first;
    final noteController = TextEditingController();

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Send Panic Alert',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedVehicle.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Vehicle'),
                    items: vehicles
                        .map(
                          (vehicle) => DropdownMenuItem<int>(
                            value: vehicle.id,
                            child: Text(vehicle.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() {
                        selectedVehicle = vehicles.firstWhere(
                          (vehicle) => vehicle.id == value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Any emergency context to share',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.sos),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                          ),
                          onPressed: () => Navigator.pop(sheetContext, true),
                          label: const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (proceed != true || !mounted) {
      return;
    }

    setState(() => _isPanicSending = true);
    try {
      final message = await _alertsRepository.sendPanicAlert(
        vehicleId: selectedVehicle.id,
        note: noteController.text,
        latitude: selectedVehicle.latitude == 0
            ? null
            : selectedVehicle.latitude,
        longitude: selectedVehicle.longitude == 0
            ? null
            : selectedVehicle.longitude,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _refreshAlerts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPanicSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: AppDrawer(onSelectTab: widget.onSelectTab),
      appBar: AppBar(
        title: const AppLogo(),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilterChip(
                  selected: !_unreadOnly,
                  label: const Text('All'),
                  onSelected: (_) {
                    setState(() => _unreadOnly = false);
                    context.read<AlertsCubit>().fetchAlerts(unreadOnly: false);
                  },
                ),
                FilterChip(
                  selected: _unreadOnly,
                  label: const Text('Unread'),
                  onSelected: (_) {
                    setState(() => _unreadOnly = true);
                    context.read<AlertsCubit>().fetchAlerts(unreadOnly: true);
                  },
                ),
                // Wrap already supplies spacing:10 between children, so no
                // manual SizedBox / left margin is needed here.
                ElevatedButton.icon(
                    onPressed: _isPanicSending ? null : _sendPanicAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isPanicSending
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sos, size: 16),
                    label: const Text('Panic'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<AlertsCubit, AlertsState>(
              builder: (context, state) {
                final alerts = state.alertListModel?.data ?? <AlertItem>[];
                // Count reflects what's actually shown (the latest page), not the
                // full server-side unread total — so the header matches the list.
                final shownUnread = alerts.where((a) => !a.isRead).length;
                final headerText = _unreadOnly
                    ? 'Unread alerts: ${alerts.length}'
                    : (shownUnread > 0
                        ? 'Showing ${alerts.length} alerts • $shownUnread unread'
                        : 'Showing ${alerts.length} alerts');

                if (state is AlertsLoadingState && alerts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is AlertsErrorState && alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _refreshAlerts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (alerts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshAlerts,
                    child: ListView(
                      children: <Widget>[
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: const Center(child: Text('No alerts yet')),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: alerts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            headerText,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      final alert = alerts[index - 1];
                      return _buildAlertCard(alert);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    final accentColor = _alertColor(alert.alertType);
    final icon = _alertIcon(alert.alertType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAlert(alert),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(width: 6, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Icon(icon, size: 18, color: accentColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    alert.displayVehicle.isNotEmpty
                                        ? alert.displayVehicle
                                        : 'Vehicle Alert',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryBlue,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTimestamp(alert.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Text(
                            alert.displayType,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (!alert.isRead) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'NEW',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.message.isNotEmpty
                            ? alert.message
                            : 'Tap to open this vehicle',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      if (alert.latitude != 0 ||
                          alert.longitude != 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Icon(
                              LucideIcons.mapPin,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _alertIcon(String alertType) {
    switch (alertType) {
      case 'ignition_on':
        return LucideIcons.keyRound;
      case 'ignition_off':
        return LucideIcons.powerOff;
      case 'geofence_enter':
      case 'geofence_exit':
        return LucideIcons.mapPin;
      case 'parking_guard':
        return LucideIcons.shieldAlert;
      case 'overspeed':
        return LucideIcons.gauge;
      case 'sos':
        return LucideIcons.siren;
      default:
        return LucideIcons.bell;
    }
  }

  Color _alertColor(String alertType) {
    switch (alertType) {
      case 'ignition_on':
        return AppColors.green;
      case 'ignition_off':
        return AppColors.red;
      case 'geofence_enter':
      case 'geofence_exit':
      case 'parking_guard':
        return AppColors.orange;
      case 'overspeed':
        return Colors.deepOrange;
      case 'sos':
        return AppColors.red;
      default:
        return AppTheme.primaryBlue;
    }
  }

  String _formatTimestamp(String createdAt) {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      return createdAt;
    }
    return '${parsed.day.toString().padLeft(2, '0')} ${_monthLabel(parsed.month)}, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _monthLabel(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
