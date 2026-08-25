import 'package:fleet_monitor/models/device_health_model.dart';
import 'package:fleet_monitor/repositorys/device_health_repository.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';

/// "Device Health" — the trackers themselves, not the vehicles.
///
/// Every fault shown here was already detectable from data the platform
/// stores; it simply had nowhere to appear. A device that has never sent a
/// packet is the worst case precisely because it is silent: no data means no
/// alerts, so a paying customer can go weeks with no tracking and nothing
/// anywhere says so. That is what this screen exists to make impossible.
class DeviceHealthScreen extends StatefulWidget {
  const DeviceHealthScreen({super.key});

  static const String routeName = '/device-health';

  @override
  State<DeviceHealthScreen> createState() => _DeviceHealthScreenState();
}

class _DeviceHealthScreenState extends State<DeviceHealthScreen> {
  final DeviceHealthRepository _repository = DeviceHealthRepository();
  bool _isLoading = true;
  String _error = '';
  DeviceHealthReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final report = await _repository.fetchHealth();
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load device health. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  static const Map<String, Color> _severityColor = <String, Color>{
    'critical': Color(0xFFD32F2F),
    'warning': Color(0xFFED6C02),
    'info': Color(0xFF0288D1),
    'ok': Color(0xFF2E7D32),
  };

  static IconData _iconFor(String code) {
    switch (code) {
      case 'never_reported':
        return LucideIcons.plugZap;
      case 'offline_long':
      case 'offline_short':
        return LucideIcons.wifiOff;
      case 'wiring_fault':
        return LucideIcons.zap;
      case 'tamper_flood':
        return LucideIcons.shieldAlert;
      case 'weak_gps':
        return LucideIcons.satellite;
      default:
        return LucideIcons.checkCircle2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).t('device_health')),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final report = _report;
    if (_error.isNotEmpty || report == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error.isEmpty ? 'No data.' : _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ],
      );
    }

    // Healthy devices are collapsed into a single line at the bottom: a list
    // of twenty "reporting normally" rows buries the two that need work.
    final problems =
        report.devices.where((DeviceHealth d) => !d.isHealthy).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _summaryCard(report),
        const SizedBox(height: 16),
        if (problems.isEmpty)
          _allClearCard()
        else
          ...problems.map(_deviceCard),
        if (report.ok > 0) ...<Widget>[
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${report.ok} device(s) reporting normally',
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ),
        ],
        if (report.hints.isNotEmpty) ...<Widget>[
          const SizedBox(height: 26),
          const Text(
            'Not switched on yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Included in your account — nothing extra to buy.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ...report.hints.map(_hintCard),
        ],
      ],
    );
  }

  Widget _summaryCard(DeviceHealthReport report) {
    final needs = report.needsAttention;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: needs > 0
            ? const Color(0xFFD32F2F).withValues(alpha: 0.06)
            : const Color(0xFF2E7D32).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            needs > 0 ? LucideIcons.alertTriangle : LucideIcons.checkCircle2,
            color: needs > 0 ? _severityColor['critical'] : _severityColor['ok'],
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  needs > 0
                      ? '$needs device(s) need attention'
                      : 'All devices healthy',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  needs > 0
                      ? 'A tracker with a fault sends no alerts at all — that silence is why these are worth fixing first.'
                      : 'Every tracker is reporting and wired correctly.',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _allClearCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: const Column(
        children: <Widget>[
          Icon(LucideIcons.checkCircle2, size: 44, color: Color(0xFF2E7D32)),
          SizedBox(height: 12),
          Text(
            'Nothing to fix',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  /// Where each unused feature is actually configured. Deliberately a
  /// sentence, not a button that deep-links: Night Lock is per-vehicle and
  /// stops are per-route, so there is no single screen to jump to — telling
  /// the owner where to look beats a link that lands on the wrong vehicle.
  static String _whereToSetUp(String key) {
    switch (key) {
      case 'night_lock':
        return 'Vehicles → open a vehicle → Night Lock';
      case 'route_stops':
        return 'Ask your admin to add the route stops for your buses';
      default:
        return '';
    }
  }

  Widget _hintCard(UnusedFeatureHint hint) {
    final where = _whereToSetUp(hint.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0288D1).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0288D1).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(LucideIcons.sparkles,
                  size: 18, color: Color(0xFF0288D1)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  hint.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint.body,
            style: const TextStyle(
              fontSize: 12.8,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          if (where.isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                const Icon(LucideIcons.arrowRight,
                    size: 14, color: Color(0xFF0288D1)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    where,
                    style: const TextStyle(
                      fontSize: 12.3,
                      color: Color(0xFF0288D1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _deviceCard(DeviceHealth d) {
    final color = _severityColor[d.severity] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(d.code), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      d.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.reason,
                      style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (d.action.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(LucideIcons.wrench,
                      size: 15, color: Colors.black45),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.action,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'IMEI ${d.imei}',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
