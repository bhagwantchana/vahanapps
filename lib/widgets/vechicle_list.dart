import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VechicleListWidget extends StatefulWidget {
  const VechicleListWidget({super.key});
  static const String routeName = "VechicleListWidget";

  @override
  State<VechicleListWidget> createState() => _VechicleListWidgetState();
}

class _VechicleListWidgetState extends State<VechicleListWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterTabs(),
            Expanded(
              child: BlocConsumer<HomeCubit, HomeState>(
                listener: (context, state) {
                  if (state is HomeLoggedInState) {}
                },
                builder: (context, state) {
                  if (state is HomeLoadingState) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final vehicleArray = state.vechileListModel?.data ?? [];
                  if (vehicleArray.isEmpty) {
                    return const Center(
                      child: CustomText(text: 'No vehicles found'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: vehicleArray.length,
                    itemBuilder: (context, index) {
                      final data = vehicleArray[index];
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FleetMonitor360',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Global Fleet Intelligence',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _profileAvatar(),
          const SizedBox(width: 12),
          _notificationBell(),
        ],
      ),
    );
  }

  Widget _profileAvatar() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: const CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.lightGrey,
        backgroundImage: AssetImage(
          'assets/images/profile_placeholder.png',
        ), // Replace with actual profile image
      ),
    );
  }

  Widget _notificationBell() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.blueLight.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none,
            color: AppColors.accent,
            size: 24,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const TextField(
          decoration: InputDecoration(
            icon: Icon(Icons.search, color: AppColors.grey),
            hintText: 'Search vehicle number or driver...',
            hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'label': 'All', 'count': null},
      {'label': 'Running', 'count': 8, 'color': AppColors.green},
      {'label': 'Idle', 'count': 3, 'color': AppColors.orange},
      {'label': 'Stopped', 'count': 4, 'color': AppColors.red},
      {'label': 'Offline', 'count': null},
    ];

    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final bool isActive = index == 0; // Temporary logic
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter['color'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: filter['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Text(
                    "${filter['label']}${filter['count'] != null ? ' (${filter['count']})' : ''}",
                    style: TextStyle(
                      color: isActive ? AppColors.accent : AppColors.secondary,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              selected: isActive,
              onSelected: (bool selected) {},
              backgroundColor: AppColors.white,
              selectedColor: AppColors.blueLight.withValues(alpha: 0.5),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isActive ? AppColors.accent : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleCard(dynamic data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.vRegistrationNo ?? "PB10 AB 1234",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              // _buildStatusChip(data.vStatus ?? "MOVING"),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildEngineStatus(true),
              const SizedBox(width: 12),
              _buildIconValue(
                Icons.speed_outlined,
                "${data.lastSpeed ?? '65'} km/h",
              ),
              const SizedBox(width: 12),
              _buildFuelStatus(0.78),
              const SizedBox(width: 12),
              _buildIconValue(Icons.straighten, "45.2k km"),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationRow(data.vName ?? "Ludhiana Highway", "2 min ago"),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final bool isMoving = status.toUpperCase() == "MOVING";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMoving ? AppColors.green : AppColors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 8),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineStatus(bool isOn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOn ? AppColors.greenLight : AppColors.redLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_circle_down,
            color: isOn ? AppColors.green : AppColors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isOn ? 'ON' : 'OFF',
            style: TextStyle(
              color: isOn ? AppColors.green : AppColors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconValue(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.secondary, size: 18),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFuelStatus(double level) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_gas_station_outlined,
          color: AppColors.secondary,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          "${(level * 100).toInt()}%",
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: LinearProgressIndicator(
            value: level,
            backgroundColor: AppColors.lightGrey,
            color: AppColors.green,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(String location, String lastUpdate) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: AppColors.green, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            location,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          "Last Update: ",
          style: TextStyle(
            color: AppColors.secondary.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Text(
          lastUpdate,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
