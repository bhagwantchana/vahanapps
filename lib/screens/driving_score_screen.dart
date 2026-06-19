import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:fleet_monitor/services/driving_score.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Client-side driving-safety score for one vehicle over a day. Computed from
/// the trip-history points (speed + time) the API already returns — no new
/// backend. Approximate, but a useful at-a-glance safety rating owners love.
class DrivingScoreScreen extends StatefulWidget {
  const DrivingScoreScreen({super.key, required this.vehicle});

  final VehicleRecord vehicle;

  @override
  State<DrivingScoreScreen> createState() => _DrivingScoreScreenState();
}

class _DrivingScoreScreenState extends State<DrivingScoreScreen> {
  final SingleTrackRepository _repo = SingleTrackRepository();
  bool _loading = true;
  String? _error;
  DrivingScore? _result;
  DateTime _day = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime(_day.year, _day.month, _day.day);
      final isToday = _day.year == DateTime.now().year &&
          _day.month == DateTime.now().month &&
          _day.day == DateTime.now().day;
      final to = isToday ? DateTime.now() : from.add(const Duration(days: 1));
      final points = await _repo.fetchTripHistoryTrail(
        imei: widget.vehicle.imei,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _result = DrivingScore.compute(
          points,
          overspeedLimit: widget.vehicle.overspeedLimit.toDouble(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = picked);
    _load();
  }

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.green;
    if (score >= 70) return AppColors.orange;
    if (score >= 50) return Colors.deepOrange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Driving Score'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Pick day',
            icon: const Icon(LucideIcons.calendar),
            onPressed: _pickDay,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(LucideIcons.cloudOff, size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(LucideIcons.refreshCcw, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final r = _result!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dayLabel =
        '${_day.day.toString().padLeft(2, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.year}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          '${widget.vehicle.displayName}  •  $dayLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
        ),
        const SizedBox(height: 16),
        if (!r.hasData)
          _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('No trip data for this day yet.',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
          )
        else ...<Widget>[
          _scoreCard(r, onSurface),
          const SizedBox(height: 16),
          _statsGrid(r, onSurface),
          const SizedBox(height: 16),
          _tipsCard(r, onSurface),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _scoreCard(DrivingScore r, Color onSurface) {
    final color = _scoreColor(r.score);
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: r.score / 100,
                      strokeWidth: 12,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('${r.score}',
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: color)),
                      Text('/ 100',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(r.rating,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(DrivingScore r, Color onSurface) {
    final items = <List<dynamic>>[
      <dynamic>[LucideIcons.gauge, 'Max speed', '${r.maxSpeed.round()} km/h', Colors.deepOrange],
      <dynamic>[LucideIcons.activity, 'Avg speed', '${r.avgSpeed.round()} km/h', AppColors.accent],
      <dynamic>[LucideIcons.zap, 'Overspeed', '${r.overspeedEvents}', AppColors.red],
      <dynamic>[LucideIcons.trendingDown, 'Hard brake', '${r.harshBrakeEvents}', Colors.redAccent],
      <dynamic>[LucideIcons.trendingUp, 'Hard accel', '${r.harshAccelEvents}', AppColors.orange],
      <dynamic>[LucideIcons.mapPin, 'Data points', '${r.sampleCount}', AppColors.grey],
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: items.map((it) {
        return _card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(it[0] as IconData, color: it[3] as Color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(it[1] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      Text(it[2] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: onSurface)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _tipsCard(DrivingScore r, Color onSurface) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(LucideIcons.lightbulb, size: 18, color: AppColors.orange),
                const SizedBox(width: 8),
                Text('Tips',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            ...r.tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('•  '),
                      Expanded(
                        child: Text(t,
                            style: TextStyle(color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            Text(
              'Score is an approximate guide based on reported trip data.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
