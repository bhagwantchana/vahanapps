import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/repositorys/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// "Safety Score" — the third home dashboard page. One honest 0-100 ring for
/// the whole fleet over the last seven days, the event counts that made it,
/// and the vehicles generating them. Same card language as Fleet Overview;
/// a clean week reads 100 and says so.
class SafetyDashboard extends StatefulWidget {
  const SafetyDashboard({super.key});

  @override
  State<SafetyDashboard> createState() => _SafetyDashboardState();
}

class _SafetyDashboardState extends State<SafetyDashboard>
    with AutomaticKeepAliveClientMixin {
  final ReportRepository _repo = ReportRepository();
  SafetySummary? _data;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.fetchSafetySummary();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.green;
    if (score >= 50) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final data = _data;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Text(
            strings.t('dash_safety_title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.t('dash_safety_subtitle'),
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (data == null)
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
            )
          else ...<Widget>[
            // Hero: the score ring, fleet total in the centre — the same
            // visual weight the Overview page gives its donut.
            _card(
              context,
              child: SizedBox(
                height: 190,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: data.score / 100,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _scoreColor(data.score)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${data.score}',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            strings.t('dash_safety_of_100'),
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
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.6,
              children: <Widget>[
                _tile(context, strings.t('dash_overspeed'),
                    data.count('overspeed'), AppColors.accent,
                    LucideIcons.gauge),
                _tile(
                    context,
                    strings.t('dash_harsh_events'),
                    data.count('harsh_brake') +
                        data.count('harsh_accel') +
                        data.count('harsh_corner'),
                    AppColors.orange,
                    LucideIcons.zap),
                _tile(
                    context,
                    strings.t('dash_power_tamper'),
                    data.count('power_cut') + data.count('tampering'),
                    AppColors.red,
                    LucideIcons.plugZap),
                _tile(context, strings.t('dash_geofence_exits'),
                    data.count('geofence_exit'), AppTheme.primaryBlue,
                    LucideIcons.mapPin),
              ],
            ),
            const SizedBox(height: 16),
            if (data.vehicles.isNotEmpty) ...<Widget>[
              Text(
                strings.t('dash_needs_attention'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _card(
                context,
                child: Column(
                  children: <Widget>[
                    for (final v in data.vehicles)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: <Widget>[
                            Icon(LucideIcons.car,
                                size: 18, color: Colors.grey.shade500),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                v.label,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                strings.tf('dash_n_events',
                                    {'n': '${v.events}'}),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.red,
                                ),
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
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(LucideIcons.shieldCheck,
                            color: AppColors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          strings.t('dash_clean_week'),
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String label, int value, Color color,
      IconData icon) {
    return _card(
      context,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$value',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 10.5,
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
