import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Style 3 — Executive Telematics & Cards Dashboard.
///
/// Designed for fleet managers who want immediate live vitals, quick-status
/// drill-downs, an active-vehicle live stream, and 1-tap tracking without
/// having to hunt through maps or long lists.
class CardsDashboard extends StatelessWidget {
  const CardsDashboard({
    super.key,
    required this.vehicles,
    required this.onOpenMap,
    required this.onTrack,
    this.onSelectTab,
  });

  final List<VehicleRecord> vehicles;
  final void Function(String filter) onOpenMap;
  final void Function(VehicleRecord vehicle) onTrack;
  final ValueChanged<int>? onSelectTab;

  @override
  Widget build(BuildContext context) {

    var moving = 0;
    var idle = 0;
    var stopped = 0;
    var offline = 0;
    var overspeed = 0;
    var maxSpeed = 0.0;

    final activeVehicles = <VehicleRecord>[];

    for (final v in vehicles) {
      final key = v.statusKey;
      switch (key) {
        case 'moving':
          moving++;
          activeVehicles.add(v);
          if (v.speed > maxSpeed) maxSpeed = v.speed;
          break;
        case 'idle':
          idle++;
          activeVehicles.add(v);
          break;
        case 'stopped':
          stopped++;
          break;
        case 'offline':
          offline++;
          break;
      }
      if (v.overspeedLimit > 0 && v.speed > v.overspeedLimit && v.isMoving) {
        overspeed++;
      }
    }

    final total = vehicles.length;
    final activeCount = moving + idle;
    final activePct = total > 0 ? ((activeCount / total) * 100).round() : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        // ── 1. Hero Fleet Pulse Card ─────────────────────────────────────
        _buildHeroPulseCard(
          context,
          total: total,
          moving: moving,
          idle: idle,
          stopped: stopped,
          offline: offline,
          activePct: activePct,
        ),
        const SizedBox(height: 16),

        // ── 2. Interactive Status Grid (4 Cards) ─────────────────────────
        Row(
          children: <Widget>[
            Expanded(
              child: _buildStatusCard(
                context,
                title: 'Moving',
                count: moving,
                subtitle: 'Active on road',
                icon: LucideIcons.navigation,
                color: Colors.green,
                onTap: () => onOpenMap('running'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                context,
                title: 'Idling',
                count: idle,
                subtitle: 'Engine running',
                icon: LucideIcons.pauseCircle,
                color: Colors.orange,
                onTap: () => onOpenMap('idle'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _buildStatusCard(
                context,
                title: 'Stopped',
                count: stopped,
                subtitle: 'Parked & safe',
                icon: LucideIcons.octagon,
                color: Colors.red,
                onTap: () => onOpenMap('stopped'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                context,
                title: 'Offline',
                count: offline,
                subtitle: '> 2 hrs silent',
                icon: LucideIcons.wifiOff,
                color: Colors.grey.shade600,
                onTap: () => onOpenMap('offline'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── 3. Fleet Map Radar / Launch Card ─────────────────────────────
        _buildFleetRadarCard(context, total: total, moving: moving),
        const SizedBox(height: 20),

        // ── 4. Active Vehicles Live Stream (if any moving/idling) ────────
        if (activeVehicles.isNotEmpty) ...[
          _buildActiveVehiclesSection(context, activeVehicles),
          const SizedBox(height: 20),
        ],

        // ── 5. Fleet Vitals Bar ──────────────────────────────────────────
        _buildFleetVitalsBar(
          context,
          maxSpeed: maxSpeed,
          overspeed: overspeed,
          activeCount: activeCount,
        ),
        const SizedBox(height: 20),

        // ── 6. Quick Action Shortcuts ────────────────────────────────────
        _buildQuickShortcuts(context),
      ],
    );
  }

  Widget _buildHeroPulseCard(
    BuildContext context, {
    required int total,
    required int moving,
    required int idle,
    required int stopped,
    required int offline,
    required int activePct,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0D253F), Color(0xFF1B3B6F), Color(0xFF285390)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0D253F).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE FLEET TELEMATICS',
                style: TextStyle(
                  color: Color(0xFF80D8FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activePct% Active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  total == 1 ? 'Vehicle Registered' : 'Vehicles in Fleet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Progress bar of the fleet composition
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 7,
              child: total == 0
                  ? Container(color: Colors.white24)
                  : Row(
                      children: <Widget>[
                        if (moving > 0)
                          Expanded(
                            flex: moving,
                            child: Container(color: Colors.green),
                          ),
                        if (idle > 0)
                          Expanded(
                            flex: idle,
                            child: Container(color: Colors.orange),
                          ),
                        if (stopped > 0)
                          Expanded(
                            flex: stopped,
                            child: Container(color: Colors.red),
                          ),
                        if (offline > 0)
                          Expanded(
                            flex: offline,
                            child: Container(color: Colors.grey.shade400),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          // Miniature pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _heroPill(Colors.green, 'Running', moving),
              _heroPill(Colors.orange, 'Idle', idle),
              _heroPill(Colors.red, 'Stopped', stopped),
              _heroPill(Colors.grey.shade300, 'Offline', offline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(Color dotColor, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$count $label',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.cardTheme.color ?? (isDark ? const Color(0xFF1E2630) : Colors.white),
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.25 : 0.15),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  Icon(
                    LucideIcons.arrowUpRight,
                    size: 15,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
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

  Widget _buildFleetRadarCard(BuildContext context, {required int total, required int moving}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, Color(0xFF003366)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.map, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Full Fleet Live Map',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  moving > 0
                      ? '$moving vehicles moving right now'
                      : 'View all $total vehicles on interactive map',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => onOpenMap('all'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Open',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveVehiclesSection(BuildContext context, List<VehicleRecord> active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(LucideIcons.activity, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                const Text(
                  'Active Vehicles Now',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${active.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => onOpenMap('running'),
              child: const Text(
                'View on map',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final v = active[i];
              final isMoving = v.isMoving;
              final statusColor = isMoving ? Colors.green : Colors.orange;

              return Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: statusColor.withValues(alpha: 0.12),
                          child: Icon(
                            isMoving ? LucideIcons.navigation : LucideIcons.pause,
                            size: 13,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            v.displayName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isMoving ? '${v.speed.round()} km/h' : 'IDLE',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      v.name.isNotEmpty && v.name != v.registrationNumber
                          ? v.name
                          : (v.typeName.isNotEmpty ? v.typeName : 'Vehicle'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Updated: ${v.lastUpdateLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => onTrack(v),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Track',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  LucideIcons.arrowUpRight,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFleetVitalsBar(
    BuildContext context, {
    required double maxSpeed,
    required int overspeed,
    required int activeCount,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _vitalItem(
            icon: LucideIcons.gauge,
            val: '${maxSpeed.round()} km/h',
            label: 'Top Speed',
            color: maxSpeed > 80 ? Colors.red : Colors.blue,
          ),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _vitalItem(
            icon: LucideIcons.zap,
            val: '$activeCount',
            label: 'Ignition On',
            color: Colors.orange,
          ),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _vitalItem(
            icon: LucideIcons.shieldAlert,
            val: '$overspeed',
            label: 'Speed Alerts',
            color: overspeed > 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _vitalItem({
    required IconData icon,
    required String val,
    required String label,
    required Color color,
  }) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
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
    );
  }

  Widget _buildQuickShortcuts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Quick Shortcuts',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _shortcutTile(
                icon: LucideIcons.car,
                label: 'All Vehicles',
                color: const Color(0xFF1E88E5),
                onTap: () {
                  if (onSelectTab != null) onSelectTab!(1);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _shortcutTile(
                icon: LucideIcons.barChart2,
                label: 'Trip Reports',
                color: const Color(0xFF8E24AA),
                onTap: () {
                  if (onSelectTab != null) onSelectTab!(3);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _shortcutTile(
                icon: LucideIcons.bell,
                label: 'Live Alerts',
                color: const Color(0xFFFB8C00),
                onTap: () {
                  if (onSelectTab != null) onSelectTab!(2);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _shortcutTile(
                icon: LucideIcons.mapPin,
                label: 'Full Map',
                color: const Color(0xFF43A047),
                onTap: () => onOpenMap('all'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shortcutTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
