import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/models/geofence_zone.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/services/geofence_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// CRUD screen for client-side geofence zones. No backend involved — zones
/// live in SharedPreferences and are evaluated locally on each refresh by
/// `GeofenceMonitorService.evaluate(...)`.
class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  List<GeofenceZone> _zones = <GeofenceZone>[];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final zones = await GeofenceStorage.loadAll();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('geofence_zones')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(null),
        icon: const Icon(Icons.add),
        label: Text(strings.t('geofence_add')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(LucideIcons.alertTriangle,
                            color: Colors.red, size: 44),
                        const SizedBox(height: 16),
                        Text(_error, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _reload,
                          child: Text(strings.t('retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : _zones.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(LucideIcons.mapPin, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          strings.t('geofence_no_zones'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _zones.length,
                  itemBuilder: (_, i) => _buildZoneCard(_zones[i]),
                ),
    );
  }

  Widget _buildZoneCard(GeofenceZone zone) {
    final strings = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.mapPin, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(zone.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${zone.latitude.toStringAsFixed(5)}, '
                  '${zone.longitude.toStringAsFixed(5)}  •  '
                  '${zone.radiusMeters} m',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: zone.enabled,
            onChanged: (val) async {
              await GeofenceStorage.upsert(zone.copyWith(enabled: val));
              await _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _openEditor(zone),
            tooltip: strings.t('geofence_edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            tooltip: strings.t('delete'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(zone.name),
                      content: Text('${strings.t('delete')}?'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(strings.t('cancel')),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(strings.t('delete')),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!ok) return;
              await GeofenceStorage.delete(zone.id);
              await _reload();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(GeofenceZone? existing) async {
    final saved = await showModalBottomSheet<GeofenceZone>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _GeofenceEditor(initial: existing),
    );
    if (saved == null) return;
    await GeofenceStorage.upsert(saved);
    await _reload();
  }
}

class _GeofenceEditor extends StatefulWidget {
  const _GeofenceEditor({this.initial});
  final GeofenceZone? initial;

  @override
  State<_GeofenceEditor> createState() => _GeofenceEditorState();
}

class _GeofenceEditorState extends State<_GeofenceEditor> {
  late final TextEditingController _name;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final z = widget.initial;
    _name = TextEditingController(text: z?.name ?? '');
    _lat = TextEditingController(text: z?.latitude.toString() ?? '');
    _lng = TextEditingController(text: z?.longitude.toString() ?? '');
    _radius = TextEditingController(text: (z?.radiusMeters ?? 200).toString());
    _enabled = z?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  void _useVehicleLocation() async {
    final vehicles = context.read<VehicleCubit>().state.vechileListModel?.data ??
        <VehicleRecord>[];
    final liveVehicles =
        vehicles.where((v) => v.hasLiveLocation && (v.latitude != 0 || v.longitude != 0))
            .toList();
    if (liveVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicle with a live location yet')),
      );
      return;
    }
    final picked = await showModalBottomSheet<VehicleRecord>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: liveVehicles
              .map(
                (v) => ListTile(
                  leading: const Icon(LucideIcons.car),
                  title: Text(v.displayName),
                  subtitle: Text(
                    '${v.latitude.toStringAsFixed(5)}, '
                    '${v.longitude.toStringAsFixed(5)}',
                  ),
                  onTap: () => Navigator.pop(ctx, v),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _lat.text = picked.latitude.toString();
      _lng.text = picked.longitude.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.initial == null
                ? strings.t('geofence_add')
                : strings.t('geofence_edit'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: strings.t('geofence_name')),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration:
                      InputDecoration(labelText: strings.t('geofence_latitude')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration:
                      InputDecoration(labelText: strings.t('geofence_longitude')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BlocBuilder<VehicleCubit, VehicleState>(
            builder: (ctx, state) {
              final any =
                  (state.vechileListModel?.data ?? <VehicleRecord>[]).isNotEmpty;
              if (!any) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _useVehicleLocation,
                  icon: const Icon(LucideIcons.mapPin, size: 16),
                  label: Text(strings.t('geofence_use_current_location')),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _radius,
            keyboardType: TextInputType.number,
            decoration:
                InputDecoration(labelText: strings.t('geofence_radius_meters')),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: Text(strings.t('enabled')),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(strings.t('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(strings.t('save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _name.text.trim();
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = int.tryParse(_radius.text.trim());
    if (name.isEmpty || lat == null || lng == null || radius == null || radius <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly')),
      );
      return;
    }
    final id = widget.initial?.id ??
        'gz_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
      context,
      GeofenceZone(
        id: id,
        name: name,
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
        enabled: _enabled,
        createdAt:
            widget.initial?.createdAt ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
