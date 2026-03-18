import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  static const LatLng _center = LatLng(28.6139, 77.2090);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _markers.add(
      const Marker(
        markerId: MarkerId('vehicle1'),
        position: _center,
        infoWindow: InfoWindow(title: 'UP14-DX-1234'),
      ),
    );
    
    _polylines.add(
      const Polyline(
        polylineId: PolylineId('route1'),
        points: [
          LatLng(28.6100, 77.2000),
          LatLng(28.6120, 77.2050),
          LatLng(28.6139, 77.2090),
        ],
        color: AppColors.primary,
        width: 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Live Tracking"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map Background
          const GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14,
            ),
            mapType: MapType.normal,
            zoomControlsEnabled: false,
          ),
          
          // Speed Overlay
          Positioned(
            top: 100,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  const Text("Speed", style: TextStyle(fontSize: 10, color: AppColors.grey)),
                  const Text(
                    "65",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const Text("km/h", style: TextStyle(fontSize: 10, color: AppColors.grey)),
                ],
              ),
            ),
          ),
          
          // Bottom Info Card
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d'),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Rajesh Kumar",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              "Truck ID: UP14-DX-1234",
                              style: TextStyle(color: AppColors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {},
                        icon: const Icon(Icons.call, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusItem(Icons.local_gas_station_outlined, "Fuel", "75%"),
                      _statusItem(Icons.history_outlined, "Last Stop", "15m ago"),
                      _statusItem(Icons.timer_outlined, "Trip Time", "2h 45m"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.grey),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
