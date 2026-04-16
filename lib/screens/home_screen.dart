import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/models/dashboard_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/screens/reports_screen.dart';
import 'package:fleet_monitor/services/assigned_vehicle_reminder_service.dart';
import 'package:fleet_monitor/services/local_notification.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/drawer.dart';
import 'package:fleet_monitor/widgets/native_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  Timer? _autoRefreshTimer;
  // bool _isAutoRefreshing = false;

  @override
  void initState() {
    super.initState();
    final homeCubit = context.read<HomeCubit>();
    if (homeCubit.state.dashboardModel == null) {
      homeCubit.fetchHomeData();
    }
    // _startAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncVehicleCareReminders();
    });
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
    super.dispose();
  }

  Map<String, int> calculateStats(List<VehicleRecord> vehicles) {
    int running = 0;
    int idle = 0;
    int stopped = 0;

    for (final vehicle in vehicles) {
      if (vehicle.isMoving) {
        running++;
      } else if (vehicle.isIdle) {
        idle++;
      } else {
        stopped++;
      }
    }

    return <String, int>{
      'running': running,
      'idle': idle,
      'stopped': stopped,
      'total': vehicles.length,
    };
  }

  void _initWebView(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return;
    }

    _loadedUrl = url;
    _controller ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
        ),
      );

    _controller!.loadRequest(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Image.asset(Assets.images.mylogo.path, height: 30),
        actions: <Widget>[
          BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              final unreadCount =
                  state.dashboardModel?.data?.unreadAlertCount ?? 0;
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const Icon(LucideIcons.bell),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
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
                    child: const Text('Retry'),
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
          final hasWebMap = dashboardMap.isNotEmpty;
          final useNativeMap = mobileMapMode == 'native' && !hasWebMap;

          if (!useNativeMap &&
              dashboardMap.isNotEmpty &&
              dashboardMap != _loadedUrl) {
            _initWebView(dashboardMap);
          }

          final stats = calculateStats(vehicles);

          return RefreshIndicator(
            onRefresh: _refreshHomeData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.34,
                        child: useNativeMap
                            ? NativeVehicleMap(
                                vehicles: vehicles,
                                emptyTitle: vehicles.isEmpty
                                    ? 'No vehicles mapped yet'
                                    : 'Map data not available',
                                emptySubtitle: useNativeMap
                                    ? 'Native map is enabled from superadmin settings'
                                    : 'Switch to native mode to use the built-in map',
                              )
                            : (_controller == null
                                  ? _EmptyMapState(
                                      title: vehicles.isEmpty
                                          ? 'No vehicles mapped yet'
                                          : 'Map link not available',
                                    )
                                  : WebViewWidget(controller: _controller!)),
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: _DashboardChip(
                          icon: Icons.map_outlined,
                          label: vehicles.isEmpty
                              ? 'No live fleet'
                              : '${vehicles.length} vehicles',
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 14,
                        child: _DashboardChip(
                          icon: LucideIcons.activity,
                          label: isLoading ? 'Syncing...' : 'Live',
                        ),
                      ),
                      if (isLoading && _controller != null)
                        Positioned.fill(
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.3),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _buildStatCard(
                      'Total Vehicles',
                      stats['total']!,
                      AppTheme.primaryBlue,
                      LucideIcons.truck,
                    ),
                    _buildStatCard(
                      'Active Devices',
                      stats['running']! + stats['idle']!,
                      AppTheme.primaryGreen,
                      LucideIcons.radioReceiver,
                    ),
                    _buildStatCard(
                      'Running',
                      stats['running']!,
                      AppColors.green,
                      LucideIcons.playCircle,
                    ),
                    _buildStatCard(
                      'Idle',
                      stats['idle']!,
                      Colors.orange,
                      LucideIcons.pauseCircle,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (dashboardData != null) ...<Widget>[
                  _buildSectionCard(
                    title: 'Performance Charts',
                    subtitle: 'Activity trends and fleet balance',
                    child: _buildAnalyticsCharts(dashboardData.analytics),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Hotspot Severity',
                    subtitle:
                        '${dashboardData.analytics.heatmapPoints.length} hotspots grouped by intensity',
                    child: _buildHeatmapSeveritySummary(
                      dashboardData.analytics.heatmapPoints,
                    ),
                  ),
                ],
                if (dashboardData?.reportShortcuts.isNotEmpty ==
                    true) ...<Widget>[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Reports',
                    subtitle: 'Quick access shortcuts',
                    child: _buildReportShortcuts(
                      dashboardData!.reportShortcuts,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EDF4)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildReportShortcuts(List<DashboardShortcut> shortcuts) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: shortcuts
          .map(
            (shortcut) => ActionChip(
              label: Text(shortcut.label),
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.08),
              labelStyle: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w700,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ReportsScreen(initialReportKey: shortcut.key),
                  ),
                );
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildAnalyticsCharts(DashboardAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 180,
          child: _buildLineChart(
            analytics.distanceTrend,
            lineColor: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(height: 180, child: _buildBarChart(analytics.alertTrend)),
      ],
    );
  }

  Widget _buildLineChart(DashboardChart chart, {required Color lineColor}) {
    if (chart.series.isEmpty || chart.series.first.data.isEmpty) {
      return const Center(child: Text('No trend data'));
    }
    final values = chart.series.first.data;
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    final maxY = values.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY * 1.25,
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            color: lineColor,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _buildBarChart(DashboardChart chart) {
    if (chart.series.isEmpty || chart.series.first.data.isEmpty) {
      return const Center(child: Text('No alert data'));
    }
    final values = chart.series.first.data;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < values.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: <BarChartRodData>[
            BarChartRodData(
              toY: values[i],
              width: 14,
              color: AppTheme.primaryGreen,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: groups,
      ),
    );
  }

  Widget _buildHeatmapSeveritySummary(List<DashboardHeatmapPoint> points) {
    final severityCounts = <String, int>{'high': 0, 'medium': 0, 'low': 0};

    for (final point in points) {
      final explicitSeverity = point.severity.trim().toLowerCase();
      if (severityCounts.containsKey(explicitSeverity)) {
        severityCounts[explicitSeverity] =
            severityCounts[explicitSeverity]! + 1;
        continue;
      }

      if (point.hits >= 20) {
        severityCounts['high'] = severityCounts['high']! + 1;
      } else if (point.hits >= 10) {
        severityCounts['medium'] = severityCounts['medium']! + 1;
      } else {
        severityCounts['low'] = severityCounts['low']! + 1;
      }
    }

    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No hotspot points found'),
      );
    }

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: severityCounts['high']!.toDouble(),
        color: AppColors.red,
        radius: 58,
        showTitle: false,
      ),
      PieChartSectionData(
        value: severityCounts['medium']!.toDouble(),
        color: Colors.orange,
        radius: 58,
        showTitle: false,
      ),
      PieChartSectionData(
        value: severityCounts['low']!.toDouble(),
        color: AppTheme.primaryGreen,
        radius: 58,
        showTitle: false,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 56,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    points.length.toString(),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    'Hotspots',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _buildSeverityBadge(
                label: 'High',
                count: severityCounts['high']!,
                color: AppColors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSeverityBadge(
                label: 'Medium',
                count: severityCounts['medium']!,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSeverityBadge(
                label: 'Low',
                count: severityCounts['low']!,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeverityBadge({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapSummary(List<DashboardHeatmapPoint> points) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'Heatmap Hotspots',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${points.length} points',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Text('No heatmap points found')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: points.take(10).map((point) {
                final level = point.hits >= 20
                    ? Colors.red
                    : point.hits >= 10
                    ? Colors.orange
                    : AppTheme.primaryBlue;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: level.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)} • ${point.hits}',
                    style: TextStyle(
                      color: level,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
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
                LucideIcons.map,
                size: 36,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardChip extends StatelessWidget {
  const _DashboardChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
