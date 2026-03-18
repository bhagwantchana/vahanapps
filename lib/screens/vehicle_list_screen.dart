import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicles = [
      {'id': 'UP14-DX-1234', 'driver': 'Rajesh Kumar', 'status': 'Moving', 'loc': 'Sector 62, Noida', 'speed': '45 km/h'},
      {'id': 'DL3C-BK-5678', 'driver': 'Amit Singh', 'status': 'Idle', 'loc': 'Rohini, Delhi', 'speed': '0 km/h'},
      {'id': 'HR26-CU-9012', 'driver': 'Suresh Raina', 'status': 'Moving', 'loc': 'Cyber City, Gurgaon', 'speed': '60 km/h'},
      {'id': 'UP32-EF-4321', 'driver': 'Vikram Singh', 'status': 'Offline', 'loc': 'Lucknow, UP', 'speed': '0 km/h'},
      {'id': 'DL1S-AG-8765', 'driver': 'Mohit Sharma', 'status': 'Moving', 'loc': 'Dwarka, Delhi', 'speed': '30 km/h'},
      {'id': 'MH01-ZX-9999', 'driver': 'Sanjay Dutt', 'status': 'Idle', 'loc': 'Andheri, Mumbai', 'speed': '0 km/h'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Inventory"),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _filterChip("All", true),
                _filterChip("Moving", false),
                _filterChip("Idle", false),
                _filterChip("Offline", false),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: vehicles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return CustomCard(
                  onTap: () {},
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle['id']!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    vehicle['driver']!,
                                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          StatusBadge(status: vehicle['status']!),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoItem(Icons.location_on_outlined, vehicle['loc']!),
                          _infoItem(Icons.speed_outlined, vehicle['speed']!),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {},
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.lightGrey),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.grey),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppColors.darkGrey),
        ),
      ],
    );
  }
}
