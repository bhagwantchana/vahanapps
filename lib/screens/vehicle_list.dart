import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/models/vechile_list_model.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/single_vehicle_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VehicleListWidget extends StatefulWidget {
  const VehicleListWidget({super.key});
  static const String routeName = "vehicle_listWidget";

  @override
  State<VehicleListWidget> createState() => _VehicleListWidgetState();
}

class _VehicleListWidgetState extends State<VehicleListWidget> {
  final Map<String, String> _addressCache = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Image.asset(Assets.images.mylogo.path, height: 30)),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),

            Expanded(
              child: BlocBuilder<VehicleCubit, VehicleState>(
                builder: (context, state) {
                  if (state is VehicleLoadingState) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final vehicleArray = state.vechileListModel?.data ?? [];

                  /// 🔍 FILTER LOGIC
                  final filteredList = vehicleArray.where((v) {
                    final reg = (v.vRegistrationNo ?? '').toLowerCase();
                    return reg.contains(_searchText);
                  }).toList();

                  if (filteredList.isEmpty) {
                    return const Center(
                      child: CustomText(text: 'No vehicles found'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final data = filteredList[index];
                      return _buildVehicleCard(data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔍 SEARCH BAR
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchText = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: "Search vehicle number...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// 🚗 VEHICLE CARD
  Widget _buildVehicleCard(Data data) {
    final status = getStatus(data);
    final statusColor = getStatusColor(status);
    final engineOn = isEngineOn(data);
    double lat = double.tryParse(data.lastLatitude ?? "0") ?? 0;
    double lng = double.tryParse(data.lastLongitude ?? "0") ?? 0;
    String cacheKey = "$lat,$lng";

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data.vRegistrationNo ?? "",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// STATS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                buildEngineStatus(engineOn),
                _iconData(
                  LucideIcons.gauge,
                  '${data.speed ?? 0} km/h',
                  AppTheme.primaryBlue,
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleDetailScreen(),
                      ),
                    );
                  },
                  child: _iconData(LucideIcons.map, '34%', Colors.orange),
                ),
                _iconData(
                  LucideIcons.signalHigh,
                  'Good',
                  AppTheme.primaryGreen,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            /// LOCATION
            Row(
              children: [
                Icon(LucideIcons.mapPin, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: FutureBuilder<String>(
                    future: _getAddress(lat, lng, cacheKey),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? "Fetching location...",
                        style: const TextStyle(fontSize: 13),
                      );
                    },
                  ),
                ),
                Text(
                  'Now',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ENGINE STATUS
  Widget buildEngineStatus(bool isOn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isOn ? AppTheme.primaryGreen : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isOn ? LucideIcons.key : LucideIcons.powerOff,
            size: 16,
            color: isOn ? AppTheme.primaryGreen : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            isOn ? 'ON' : 'OFF',
            style: TextStyle(
              color: isOn ? AppTheme.primaryGreen : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// STATUS LOGIC
  bool isEngineOn(Data data) {
    int tripId = int.tryParse(data.lastTripId ?? "0") ?? 0;
    int finished = int.tryParse(data.lastTripFinished ?? "0") ?? 0;
    return tripId > 0 && finished == 0;
  }

  String getStatus(Data data) {
    int tripId = int.tryParse(data.lastTripId ?? "0") ?? 0;
    int finished = int.tryParse(data.lastTripFinished ?? "0") ?? 0;
    int speed = int.tryParse(data.lastSpeed ?? "0") ?? 0;

    if (tripId == 0 || finished == 1) return "Stopped";
    if (speed > 0) return "Moving";
    return "Idle";
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Moving":
        return AppTheme.primaryGreen;
      case "Idle":
        return Colors.orange;
      case "Stopped":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// ADDRESS
  Future<String> _getAddress(
    double latitude,
    double longitude,
    String key,
  ) async {
    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      final place = placemarks.first;

      final address = "${place.locality}, ${place.administrativeArea}";
      _addressCache[key] = address;
      return address;
    } catch (_) {
      return "Unknown location";
    }
  }

  /// ICON DATA
  Widget _iconData(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
