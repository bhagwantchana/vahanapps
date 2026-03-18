import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Greeting & Profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Good Morning, Ashok",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                      Text(
                        "Here's your fleet status today",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.grey,
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      const SizedBox(width: 12),
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Text("AV", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: "Search vehicle or driver...",
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Map Section
              Text(
                "Live Tracking",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      const GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(28.6139, 77.2090),
                          zoom: 12,
                        ),
                        mapType: MapType.normal,
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: FloatingActionButton.small(
                          onPressed: () {},
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Metric Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: const [
                  MetricTile(
                    label: "Total Vehicles",
                    value: "24",
                    icon: Icons.local_shipping_rounded,
                    iconColor: AppColors.primary,
                  ),
                  MetricTile(
                    label: "Active",
                    value: "18",
                    icon: Icons.flash_on_rounded,
                    iconColor: AppColors.moving,
                  ),
                  MetricTile(
                    label: "Idle",
                    value: "4",
                    icon: Icons.pause_rounded,
                    iconColor: AppColors.idle,
                  ),
                  MetricTile(
                    label: "Offline",
                    value: "2",
                    icon: Icons.power_settings_new_rounded,
                    iconColor: AppColors.offline,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Activity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Activity",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text("View All"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final activities = [
                    {'id': 'UP14-DX-1234', 'loc': 'Sector 62, Noida', 'status': 'Moving', 'time': '2 mins ago'},
                    {'id': 'DL3C-BK-5678', 'loc': 'Rohini, Delhi', 'status': 'Idle', 'time': '15 mins ago'},
                    {'id': 'HR26-CU-9012', 'loc': 'Cyber City, Gurgaon', 'status': 'Moving', 'time': 'Just now'},
                  ];
                  final item = activities[index];
                  return CustomCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['id']!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                item['loc']!,
                                style: TextStyle(color: AppColors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(status: item['status']!),
                            const SizedBox(height: 4),
                            Text(
                              item['time']!,
                              style: const TextStyle(fontSize: 10, color: AppColors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
