import 'package:cached_network_image/cached_network_image.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Subscriptions tab — the tracking plan of every vehicle in one place:
/// which plan is due when, sorted most-urgent first (expired → expiring →
/// active), with the same red/orange/green status language the vehicle
/// cards already use for the expiry badge.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  static const String routeName = 'subscriptions_screen';

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    // Pushed from the drawer, so the shared VehicleCubit is normally already
    // primed by the dashboard's vehicle tab — fetch only when it genuinely
    // has nothing AND nothing is in flight (avoids the duplicate-request
    // trap that same-frame guard-and-fetch caused as a bottom tab).
    final cubit = context.read<VehicleCubit>();
    if (cubit.state.vechileListModel == null &&
        cubit.state is! VehicleLoadingState) {
      cubit.fetchVehicles();
    }
  }

  Future<void> _refresh() async {
    await context.read<VehicleCubit>().fetchVehicles();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${_months[date.month - 1]} ${date.year}';
  }

  /// Sort: expired first (most overdue on top), then by days-to-expiry
  /// ascending, vehicles without an expiry date last.
  List<VehicleRecord> _sorted(List<VehicleRecord> vehicles) {
    final list = List<VehicleRecord>.of(vehicles);
    list.sort((a, b) {
      final da = a.daysToExpiry;
      final db = b.daysToExpiry;
      if (da == null && db == null) {
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      }
      if (da == null) return 1;
      if (db == null) return -1;
      if (da != db) return da.compareTo(db);
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return list;
  }

  Color _statusColor(VehicleRecord v) {
    if (v.isExpired) return AppColors.red;
    if (v.isExpiringSoon) return AppColors.orange;
    if (v.daysToExpiry == null) return AppColors.grey;
    return AppColors.green;
  }

  Color _statusColorLight(VehicleRecord v) {
    if (v.isExpired) return AppColors.redLight;
    if (v.isExpiringSoon) return AppColors.orangeLight;
    if (v.daysToExpiry == null) return AppColors.lightGrey;
    return AppColors.greenLight;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          strings.t('subscriptions_title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: BlocBuilder<VehicleCubit, VehicleState>(
        builder: (context, state) {
          final vehicles = state.vechileListModel?.data ?? <VehicleRecord>[];

          if (state is VehicleLoadingState && vehicles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final sorted = _sorted(vehicles);
          final expired = vehicles.where((v) => v.isExpired).length;
          final expiring = vehicles.where((v) => v.isExpiringSoon).length;
          final active = vehicles
              .where((v) => v.daysToExpiry != null && !v.isExpired && !v.isExpiringSoon)
              .length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                Text(
                  strings.t('subscriptions_subtitle'),
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _statTile(strings.t('subs_active'), active,
                          AppColors.green, AppColors.greenLight, LucideIcons.badgeCheck),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statTile(strings.t('subs_expiring'), expiring,
                          AppColors.orange, AppColors.orangeLight, LucideIcons.timer),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statTile(strings.t('subs_expired'), expired,
                          AppColors.red, AppColors.redLight, LucideIcons.alertTriangle),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        children: <Widget>[
                          Icon(LucideIcons.car, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            strings.t('subs_empty'),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...sorted.map((v) => _subscriptionCard(v, strings)),
                const SizedBox(height: 8),
                _renewHint(strings),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statTile(
    String label,
    int count,
    Color color,
    Color colorLight,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: colorLight, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 1),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionCard(VehicleRecord vehicle, AppStrings strings) {
    final color = _statusColor(vehicle);
    final colorLight = _statusColorLight(vehicle);
    final expiry = vehicle.expiryDateValue;
    final badge = vehicle.daysToExpiry == null
        ? strings.t('subs_no_expiry')
        : vehicle.expiryBadgeLabel.isNotEmpty
            ? vehicle.expiryBadgeLabel
            : strings.t('subs_active');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Status accent bar — same visual cue as the vehicle list rows.
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorLight.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: vehicle.vehicleIconUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: vehicle.vehicleIconUrl,
                                errorWidget: (_, __, ___) =>
                                    Icon(LucideIcons.car, size: 20, color: color),
                              )
                            : Icon(LucideIcons.car, size: 20, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              vehicle.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (vehicle.name.isNotEmpty &&
                                vehicle.name != vehicle.displayName) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                vehicle.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Icon(LucideIcons.calendar,
                                    size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    expiry != null
                                        ? '${strings.t('subs_valid_till')} ${_formatDate(expiry)}'
                                        : strings.t('subs_no_expiry'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
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

  Widget _renewHint(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: <Widget>[
          Icon(LucideIcons.headphones, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.t('subs_renew_hint'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
