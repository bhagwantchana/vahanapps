import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/nearby_poi_model.dart';
import 'package:fleet_monitor/repositorys/poi_repository.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Nearby" — world POIs around the VEHICLE's live position (petrol pumps,
/// EV chargers, toll plazas, speed cameras, traffic lights). Data comes from
/// tbl_pois (OpenStreetMap import) via api/nearbyPois. Tapping an entry opens
/// the phone's maps app with driving directions to that POI.
class NearbyPoisScreen extends StatefulWidget {
  const NearbyPoisScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.vehicleName = '',
  });

  final double lat;
  final double lng;
  final String vehicleName;

  @override
  State<NearbyPoisScreen> createState() => _NearbyPoisScreenState();
}

class _NearbyPoisScreenState extends State<NearbyPoisScreen> {
  static const List<_PoiCategory> _categories = <_PoiCategory>[
    _PoiCategory('fuel', 'Petrol Pump', LucideIcons.fuel),
    _PoiCategory('ev_charging', 'EV Charging', LucideIcons.plugZap),
    _PoiCategory('toll_booth', 'Toll Plaza', LucideIcons.landmark),
    _PoiCategory('speed_camera', 'Speed Camera', LucideIcons.camera),
    _PoiCategory('traffic_signals', 'Traffic Light', LucideIcons.lightbulb),
  ];

  final PoiRepository _repository = PoiRepository();
  String _selectedType = 'fuel';
  bool _isLoading = true;
  String _error = '';
  List<NearbyPoi> _pois = <NearbyPoi>[];

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
      final pois = await _repository.fetchNearby(
        lat: widget.lat,
        lng: widget.lng,
        types: <String>[_selectedType],
        radiusKm: _selectedType == 'traffic_signals' ? 5 : 25,
      );
      if (!mounted) return;
      setState(() {
        _pois = pois;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openDirections(NearbyPoi poi) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${poi.lat},${poi.lng}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps app')),
      );
    }
  }

  IconData _iconFor(String poiType) {
    for (final category in _categories) {
      if (category.type == poiType) return category.icon;
    }
    return LucideIcons.mapPin;
  }

  String _distanceLabel(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.vehicleName.isNotEmpty
        ? 'Nearby — ${widget.vehicleName}'
        : 'Nearby';

    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category.type == _selectedType;
                return ChoiceChip(
                  avatar: Icon(
                    category.icon,
                    size: 16,
                    color: selected ? Colors.white : AppTheme.primaryBlue,
                  ),
                  label: Text(category.label),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : null,
                  ),
                  selectedColor: AppTheme.primaryBlue,
                  selected: selected,
                  onSelected: (_) {
                    if (_selectedType == category.type) return;
                    setState(() => _selectedType = category.type);
                    _load();
                  },
                );
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(LucideIcons.wifiOff, size: 40, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_pois.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing found near the vehicle for this category.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: _pois.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final poi = _pois[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Icon(
                  _iconFor(poi.poiType),
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              title: Text(
                poi.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                <String>[
                  _distanceLabel(poi.distanceKm),
                  if (poi.supportsCng) 'CNG available',
                ].join(' · '),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                LucideIcons.navigation,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
              onTap: () => _openDirections(poi),
            ),
          );
        },
      ),
    );
  }
}

class _PoiCategory {
  const _PoiCategory(this.type, this.label, this.icon);

  final String type;
  final String label;
  final IconData icon;
}
