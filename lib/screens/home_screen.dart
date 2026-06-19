import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/models/dashboard_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/services/assigned_vehicle_reminder_service.dart';
import 'package:fleet_monitor/services/geofence_monitor_service.dart';
import 'package:fleet_monitor/services/lifecycle_refresh.dart';
import 'package:fleet_monitor/services/local_notification.dart';
import 'package:fleet_monitor/widgets/app_logo.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/drawer.dart';
import 'package:fleet_monitor/widgets/live_address_text.dart';
import 'package:fleet_monitor/widgets/native_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSelectTab});

  final ValueChanged<int>? onSelectTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // static const Duration _autoRefreshInterval = Duration(seconds: 3);
  final AssignedVehicleReminderService _vehicleCareService =
      AssignedVehicleReminderService();
  WebViewController? _controller;
  bool isLoading = true;
  String _loadedUrl = '';
  bool _isMapExpanded = false;
  Timer? _autoRefreshTimer;
  // bool _isAutoRefreshing = false;

  // Dashboard refresh: every 45 s while foreground, immediate on resume,
  // cancelled when app backgrounded. Slightly longer cadence than the
  // vehicle list (30 s) because the dashboard aggregates more data and
  // updates less critically.
  late final LifecycleRefresh _lifecycle = LifecycleRefresh(
    onRefresh: () async {
      if (!mounted) return;
      await context.read<HomeCubit>().fetchHomeData();
      if (!mounted) return;
      // Geofence evaluation runs after fresh vehicle data lands. Failures
      // inside the service are silent — never blocks the refresh tick.
      final vehicles =
          context.read<HomeCubit>().state.dashboardModel?.data?.vehicleList ??
              <VehicleRecord>[];
      final strings = AppStrings.of(context);
      await GeofenceMonitorService.instance.evaluate(
        vehicles: vehicles,
        entryLabel: strings.t('geofence_entry_alert'),
        exitLabel: strings.t('geofence_exit_alert'),
      );
    },
    interval: const Duration(seconds: 45),
  );

  @override
  void initState() {
    super.initState();
    final homeCubit = context.read<HomeCubit>();
    if (homeCubit.state.dashboardModel == null) {
      homeCubit.fetchHomeData();
    }
    _lifecycle.start();
    // // _startAutoRefresh();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _syncVehicleCareReminders();
    // });
  }

  // void _startAutoRefresh() {
  //   _autoRefreshTimer?.cancel();
  //   _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
  //     if (!mounted || _isAutoRefreshing) {
  //       return;
  //     }

  //     _isAutoRefreshing = true;
  //     unawaited(_refreshHomeSnapshot());
  //   });
  // }

  // Future<void> _refreshHomeSnapshot() async {
  //   try {
  //     await context.read<HomeCubit>().fetchHomeData();
  //   } finally {
  //     _isAutoRefreshing = false;
  //   }
  // }

  Future<void> _syncVehicleCareReminders() async {
    try {
      final reminders = await _vehicleCareService.collectDueReminders();
      for (final reminder in reminders) {
        await CustomNotificationSoundService().showVehicleCareReminder(
          type: reminder.type.name,
          vehicleId: reminder.vehicleId,
          title: reminder.title,
          body: reminder.body,
        );
        await _vehicleCareService.markReminderSent(reminder);
      }
    } catch (_) {
      // Reminder sync should stay silent and never block the home screen.
    }
  }

  Future<void> _refreshHomeData() async {
    await context.read<HomeCubit>().fetchHomeData();
    await _syncVehicleCareReminders();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Map<String, int> calculateStats(List<VehicleRecord> vehicles) {
    int moving = 0;
    int idle = 0;
    int active = 0; // Total with Ignition ON (Moving + Idle)
    int stopped = 0;

    for (final vehicle in vehicles) {
      if (vehicle.engineOn) {
        active++;
        if (vehicle.speed > 5) {
          moving++;
        } else {
          idle++;
        }
      } else {
        stopped++;
      }
    }

    return <String, int>{
      'moving': moving,
      'idle': idle,
      'active': active,
      'stopped': stopped,
      'total': vehicles.length,
    };
  }

  void _initWebView(String url) {
    // Server regenerates the encrypted token in maps_url on every dashboard
    // fetch, so the URL changes each refresh — but the page runs its own AJAX
    // loop, so we load it exactly once and never reload from Flutter.
    if (_loadedUrl.isNotEmpty) {
      return;
    }
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return;
    }
    // Tell the web map to render in clean embed mode — hides the desktop
    // bottom Total/Running/Idle/Stopped bar so only the map shows on mobile.
    final embedUri = parsed.replace(
      queryParameters: <String, String>{
        ...parsed.queryParameters,
        'embed': '1',
      },
    );

    _loadedUrl = url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
        ),
      );

    _controller!.loadRequest(embedUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AppLogo(),
        actions: <Widget>[
          BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              final dashboardData = state.dashboardModel?.data;
              // Total unread alerts (not just panic) — refreshed after mark-read.
              final alertCount = dashboardData?.unreadAlertCount ?? 0;

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(LucideIcons.bell),
                    if (alertCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            alertCount > 9 ? '9+' : alertCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => widget.onSelectTab?.call(2),
              );
            },
          ),
        ],
      ),
      drawer: AppDrawer(onSelectTab: widget.onSelectTab),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoadingState && state.dashboardModel == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HomeErrorState && state.dashboardModel == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    LucideIcons.alertTriangle,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  CustomText(text: state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshHomeData,
                    child: Text(AppStrings.of(context).t('retry')),
                  ),
                ],
              ),
            );
          }

          final dashboardData = state.dashboardModel?.data;
          final vehicles = dashboardData?.vehicleList ?? <VehicleRecord>[];
          final dashboardMap = dashboardData?.mapsUrl ?? '';
          final mobileMapMode = (dashboardData?.mobileMapMode ?? 'native')
              .toLowerCase();
          // Require a parseable URL — a malformed maps_url must NOT strand the
          // user on the loading placeholder; fall back to the native map.
          final hasWebMap =
              dashboardMap.isNotEmpty && Uri.tryParse(dashboardMap) != null;
          // Map mode comes from the server as mobile_map_mode = 'native' | 'url'
          // (Api.php getMobileMapMode). 'url' => embed the web map in a WebView;
          // 'native' => the in-app MapLibre map. 'webview'/'web' kept as aliases.
          // Fall back to native if web mode is set but no maps URL was provided.
          final wantsWebView =
              (mobileMapMode == 'url' ||
                      mobileMapMode == 'webview' ||
                      mobileMapMode == 'web') &&
                  hasWebMap;
          final useNativeMap = !wantsWebView;

          if (!useNativeMap && dashboardMap.isNotEmpty) {
            _initWebView(dashboardMap);
          }

          final stats = calculateStats(vehicles);

          return RefreshIndicator(
            onRefresh: _refreshHomeData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: <Widget>[
                _buildMapSection(
                  vehicles,
                  useNativeMap,
                  dashboardData?.mobileMapProvider ?? 'maplibre',
                ),
                const SizedBox(height: 16),
                _buildModernStats(stats),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildRecentActivity(dashboardData?.analytics.recentPanicAlerts ?? []),
                const SizedBox(height: 24),
                if (dashboardData != null)
                  _buildPerformanceOverview(dashboardData.analytics),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Bottom sheet shown when a marker is tapped on the native map. Uses
  /// LiveAddressText so the address rendered here is the SAME string the
  /// vehicle list cell shows for the same coordinates (shared coord-keyed
  /// cache). That fixes the "map address vs list address mismatch" the
  /// owner reported on multi-vehicle view.
  /// Red "X days left" / "Expired" pill for the device/plan subscription
  /// expiry, shown in the map-marker bottom sheet. Mirrors the badge on the
  /// vehicle list cards.
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

  void _showVehicleBottomSheet(BuildContext context, VehicleRecord vehicle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = vehicle.isMoving
        ? const Color(0xFF22C55E)
        : (vehicle.isIdle ? Colors.orange : Colors.red);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      isScrollControlled: false,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            vehicle.registrationNumber.isNotEmpty
                                ? vehicle.registrationNumber
                                : vehicle.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (vehicle.showExpiryBadge) ...<Widget>[
                            const SizedBox(height: 6),
                            _buildExpiryBadge(vehicle),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                vehicle.statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${vehicle.speed.round()} km/h',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(LucideIcons.mapPin, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LiveAddressText(
                        latitude: vehicle.latitude,
                        longitude: vehicle.longitude,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Updated: ${vehicle.createdAt.isNotEmpty ? vehicle.createdAt : '—'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.navigation, size: 16),
                    label: const Text('Track Live'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      widget.onSelectTab?.call(1); // Vehicles tab
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapSection(
    List<VehicleRecord> vehicles,
    bool useNativeMap,
    String mapProvider,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * (_isMapExpanded ? 0.65 : 0.32),
            child: useNativeMap
                ? NativeVehicleMap(
                    vehicles: vehicles,
                    emptyTitle: AppStrings.of(context).t('no_vehicles_found'),
                    emptySubtitle: AppStrings.of(context).t('connect_device_hint'),
                    onVehicleTap: (v) => _showVehicleBottomSheet(context, v),
                    mapProvider: mapProvider,
                  )
                : (_controller == null
                    ? _EmptyMapState(title: AppStrings.of(context).t('loading_map'))
                    : WebViewWidget(
                        controller: _controller!,
                        // Claim ALL touch gestures inside the webview's
                        // bounds before the outer ListView gets a chance.
                        // Without this, a pinch-out motion looks like a
                        // vertical scroll to the parent ListView and gets
                        // stolen mid-gesture — so the map could zoom IN
                        // but never zoom OUT. EagerGestureRecognizer says
                        // "this child wins any conflict with the parent".
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                          Factory<EagerGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                      )),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.users, size: 18, color: Color(0xFF4A688A)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vehicles.length} ${AppStrings.of(context).t('vehicles_count')}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          _buildMapStatusMini(Colors.green, '${vehicles.where((v) => v.isMoving).length} ${AppStrings.of(context).t('status_moving')}'),
                          const SizedBox(width: 8),
                          _buildMapStatusMini(Colors.orange, '${vehicles.where((v) => v.isIdle).length} ${AppStrings.of(context).t('status_idle')}'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: GestureDetector(
              onTap: () => setState(() => _isMapExpanded = !_isMapExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isMapExpanded ? LucideIcons.minimize2 : LucideIcons.plus,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isMapExpanded
                          ? AppStrings.of(context).t('minimize')
                          : AppStrings.of(context).t('live'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStatusMini(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildModernStats(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          _buildTotalDonut(stats['total']!, stats['active']!),
          const SizedBox(width: 6),
          Expanded(child: _buildStatItem(LucideIcons.car, AppStrings.of(context).t('status_moving'), stats['moving']!, Colors.green)),
          const SizedBox(width: 6),
          Expanded(child: _buildStatItem(LucideIcons.clock, AppStrings.of(context).t('status_idle'), stats['idle']!, Colors.orange)),
          const SizedBox(width: 6),
          Expanded(child: _buildStatItem(LucideIcons.power, AppStrings.of(context).t('status_stopped'), stats['stopped']!, Colors.red)),
          const SizedBox(width: 6),
          Expanded(child: _buildStatItem(LucideIcons.wifi, AppStrings.of(context).t('devices'), stats['total']!, Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTotalDonut(int total, int active) {
    final activePercentage = total > 0 ? active / total : 0.0;
    return SizedBox(
      width: 65,
      height: 65,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: activePercentage,
              strokeWidth: 5,
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                activePercentage > 0.5 ? Colors.green : Colors.orange,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total.toString(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              Text(
                AppStrings.of(context).t('total'),
                style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF1F4F8);
    final countColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: countColor),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.of(context).t('quick_actions'),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            GestureDetector(
              onTap: () => widget.onSelectTab?.call(1), // Vehicles tab
              child: Text(
                '${AppStrings.of(context).t('view_all')} >',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onSelectTab?.call(1),
                child: _buildActionBtn(LucideIcons.navigation, AppStrings.of(context).t('track_live'), const Color(0xFFE8F5E9), Colors.green),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onSelectTab?.call(3), // Reports tab
                child: _buildActionBtn(LucideIcons.barChart, AppStrings.of(context).t('tab_reports'), const Color(0xFFEDE7F6), Colors.purple),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onSelectTab?.call(2), // Alerts tab
                child: _buildActionBtn(LucideIcons.bell, AppStrings.of(context).t('tab_alerts'), const Color(0xFFFFF3E0), Colors.orange),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<DashboardPanicAlert> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.of(context).t('recent_activity'),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            GestureDetector(
              onTap: () => widget.onSelectTab?.call(2), // Alerts tab
              child: Text(
                '${AppStrings.of(context).t('see_all')} >',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                AppStrings.of(context).t('no_recent_activity'),
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          ...alerts.take(3).map((alert) => _buildActivityItem(
                LucideIcons.alertTriangle,
                alert.vehicleLabel,
                alert.message,
                alert.createdAt,
                Colors.orange,
              )),
      ],
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String sub, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _shortPerfDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  String _perfDateLabel() {
    final sel = context.read<HomeCubit>().selectedDate;
    if (sel == null || _isSameDay(sel, DateTime.now())) {
      return AppStrings.of(context).t('today');
    }
    return _shortPerfDate(sel);
  }

  Future<void> _pickPerformanceDate() async {
    final cubit = context.read<HomeCubit>();
    final now = DateTime.now();
    final initial = cubit.selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
    );
    if (picked != null && mounted) {
      cubit.fetchHomeData(date: picked);
    }
  }

  Widget _buildPerformanceOverview(DashboardAnalytics analytics) {
    final distanceTrend = analytics.distanceTrend;
    final values = distanceTrend.series.isNotEmpty ? distanceTrend.series.first.data : <double>[];
    final totalDistance = values.isNotEmpty ? values.reduce((a, b) => a + b) : 0.0;

    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.of(context).t('performance_overview'),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickPerformanceDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(LucideIcons.calendar, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(_perfDateLabel(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.of(context).t('total_distance'), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            totalDistance >= 1000 ? (totalDistance / 1000).toStringAsFixed(1) : totalDistance.toInt().toString(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(width: 4),
                          Text(
                            totalDistance >= 1000 ? 'km' : 'm',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (values.length >= 2)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: values.last >= values[values.length - 2]
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            values.last >= values[values.length - 2] ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: values.last >= values[values.length - 2] ? Colors.green : Colors.red,
                          ),
                          Text(
                            ' ${((values.last - values[values.length - 2]).abs() / (values[values.length - 2] == 0 ? 1 : values[values.length - 2]) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: values.last >= values[values.length - 2] ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (spots.isEmpty)
                const SizedBox(
                  height: 120,
                  child: Center(child: Text('No distance data available', style: TextStyle(fontSize: 12, color: Colors.grey))),
                )
              else
                SizedBox(
                  height: 120,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.primaryBlue,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }


  // Widget _buildHeatmapSummary(List<DashboardHeatmapPoint> points) {
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: <Widget>[
  //         Row(
  //           children: <Widget>[
  //             const Text(
  //               'Heatmap Hotspots',
  //               style: TextStyle(
  //                 color: AppTheme.primaryBlue,
  //                 fontWeight: FontWeight.w800,
  //                 fontSize: 16,
  //               ),
  //             ),
  //             const Spacer(),
  //             Text(
  //               '${points.length} points',
  //               style: TextStyle(
  //                 color: Colors.grey.shade600,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 12),
  //         if (points.isEmpty)
  //           const Text('No heatmap points found')
  //         else
  //           Wrap(
  //             spacing: 8,
  //             runSpacing: 8,
  //             children: points.take(10).map((point) {
  //               final level = point.hits >= 20
  //                   ? Colors.red
  //                   : point.hits >= 10
  //                   ? Colors.orange
  //                   : AppTheme.primaryBlue;
  //               return Container(
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 10,
  //                   vertical: 8,
  //                 ),
  //                 decoration: BoxDecoration(
  //                   color: level.withValues(alpha: 0.12),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Text(
  //                   '${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)} • ${point.hits}',
  //                   style: TextStyle(
  //                     color: level,
  //                     fontWeight: FontWeight.w700,
  //                     fontSize: 12,
  //                   ),
  //                 ),
  //               );
  //             }).toList(),
  //           ),
  //       ],
  //     ),
  //   );
  // }
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
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
                LucideIcons.map,
                size: 36,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

