import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The "Overview" home dashboard: a status donut chart (Running / Idle /
/// Stopped / Offline) with the fleet total in the centre, plus tappable count
/// tiles. Tapping a slice or a tile opens the full fleet map filtered to just
/// those vehicles. Selected via Settings → Dashboard style; the other option is
/// the full-screen map.
class OverviewDashboard extends StatelessWidget {
  const OverviewDashboard({
    super.key,
    required this.vehicles,
    required this.onOpenMap,
  });

  final List<VehicleRecord> vehicles;

  /// Opens the fleet map filtered to [filter] (all|running|idle|stopped|
  /// offline|overspeed).
  final void Function(String filter) onOpenMap;

  // isMoving is stale-aware, so a fix minutes old can no longer raise an
  // overspeed flag — the speed it carries is not a claim about right now.
  bool _isOverspeed(VehicleRecord v) =>
      v.overspeedLimit > 0 && v.speed > v.overspeedLimit && v.isMoving;

  /// One exclusive bucket per vehicle, so the tiles always sum to the fleet.
  /// The map calls it `moving`; this dashboard's tile is labelled `running`.
  String _bucket(VehicleRecord v) {
    final key = v.statusKey;
    return key == 'moving' ? 'running' : key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var running = 0, idle = 0, stopped = 0, offline = 0, over = 0;
    for (final v in vehicles) {
      switch (_bucket(v)) {
        case 'running':
          running++;
          break;
        case 'stopped':
          stopped++;
          break;
        case 'offline':
          offline++;
          break;
        default:
          idle++;
      }
      if (_isOverspeed(v)) over++;
    }
    final total = vehicles.length;

    // Pie sections in a fixed order so touch indices map back to a status.
    final order = <List<dynamic>>[
      <dynamic>['running', running, AppColors.green],
      <dynamic>['idle', idle, AppColors.orange],
      <dynamic>['stopped', stopped, AppColors.red],
      <dynamic>['offline', offline, AppColors.grey],
    ];
    final sections = <PieChartSectionData>[
      for (final s in order)
        if ((s[1] as int) > 0)
          PieChartSectionData(
            value: (s[1] as int).toDouble(),
            color: s[2] as Color,
            title: '${s[1]}',
            radius: 46,
            titleStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
    ];
    // Which statuses are actually drawn (matches touch indices).
    final drawn = <String>[
      for (final s in order)
        if ((s[1] as int) > 0) s[0] as String,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Text(
          'Fleet Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a status to see those vehicles on the map',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 18),
        _card(
          context,
          child: SizedBox(
            height: 230,
            child: sections.isEmpty
                ? Center(
                    child: Text('No vehicles yet',
                        style: TextStyle(color: Colors.grey.shade600)),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 62,
                          sectionsSpace: 3,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              if (event is! FlTapUpEvent) return;
                              final idx =
                                  response?.touchedSection?.touchedSectionIndex;
                              if (idx == null || idx < 0 || idx >= drawn.length) {
                                return;
                              }
                              onOpenMap(drawn[idx]);
                            },
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Total',
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
        const SizedBox(height: 16),
        // Tappable status tiles.
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.6,
          children: <Widget>[
            _tile(context, 'Running', running, AppColors.green,
                LucideIcons.navigation, () => onOpenMap('running')),
            _tile(context, 'Idle', idle, AppColors.orange, LucideIcons.pauseCircle,
                () => onOpenMap('idle')),
            _tile(context, 'Stopped', stopped, AppColors.red,
                LucideIcons.octagon, () => onOpenMap('stopped')),
            _tile(context, 'Offline', offline, AppColors.grey,
                LucideIcons.wifiOff, () => onOpenMap('offline')),
            _tile(context, 'Overspeed', over, AppColors.accent,
                LucideIcons.gauge, () => onOpenMap('overspeed')),
            _tile(context, 'All Vehicles', total, AppTheme.primaryBlue,
                LucideIcons.map, () => onOpenMap('all')),
          ],
        ),
      ],
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

  Widget _tile(BuildContext context, String label, int count, Color color,
      IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
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
}
