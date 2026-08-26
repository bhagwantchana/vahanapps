import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/repositorys/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// "Today's Activity" — the second home dashboard page. The day so far, at
/// a glance: km driven, trips made, how many vehicles have moved, and the
/// busiest vehicles with a clean km bar each. Same card language as the
/// Fleet Overview page; numbers come from the daily_running report bounded
/// to today, fetched once per screen visit.
class TodayActivityDashboard extends StatefulWidget {
  const TodayActivityDashboard({super.key});

  @override
  State<TodayActivityDashboard> createState() => _TodayActivityDashboardState();
}

class _TodayActivityDashboardState extends State<TodayActivityDashboard>
    with AutomaticKeepAliveClientMixin {
  final ReportRepository _repo = ReportRepository();
  TodayActivity? _data;
  bool _loading = true;

  // Keep the fetched numbers alive across page swipes — the pager rebuilds
  // offstage pages, and refetching a report on every swipe would be waste.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.fetchTodayActivity();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final data = _data ?? const TodayActivity.empty();
    final top = data.vehicles.take(5).toList();
    final maxKm = top.isEmpty
        ? 0.0
        : top.map((v) => v.km).reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Text(
            strings.t('dash_today_title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.t('dash_today_subtitle'),
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            // Hero: the day's kilometres, big and unmissable.
            _card(
              context,
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(LucideIcons.map,
                        size: 30, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data.totalKm.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        strings.t('dash_km_today'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _stat(context, LucideIcons.milestone,
                      '${data.totalTrips}', strings.t('dash_trips_today'),
                      AppColors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat(context, LucideIcons.car,
                      '${data.activeVehicles}', strings.t('dash_active_today'),
                      AppColors.orange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (top.isNotEmpty) ...<Widget>[
              Text(
                strings.t('dash_top_vehicles'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _card(
                context,
                child: Column(
                  children: <Widget>[
                    for (final v in top)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    v.label,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${v.km.toStringAsFixed(1)} km · ${v.trips}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: maxKm > 0 ? v.km / maxKm : 0,
                                minHeight: 6,
                                backgroundColor:
                                    AppTheme.primaryBlue.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              _card(
                context,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text(
                      strings.t('dash_no_activity'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String value, String label,
      Color color) {
    return _card(
      context,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
