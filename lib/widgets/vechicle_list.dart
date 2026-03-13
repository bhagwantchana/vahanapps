import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/models/vechile_list_model.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VechicleListWidget extends StatefulWidget {
  const VechicleListWidget({super.key});
  static const String routeName = "VechicleListWidget";

  @override
  State<VechicleListWidget> createState() => _VechicleListWidgetState();
}

class _VechicleListWidgetState extends State<VechicleListWidget> {
  final Map<String, String> _addressCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: BlocConsumer<HomeCubit, HomeState>(
                listener: (context, state) {},
                builder: (context, state) {
                  if (state is HomeLoadingState) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Loading your fleet...",
                            style: TextStyle(
                              color: AppColors.secondary.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final vehicleArray = state.vechileListModel?.data ?? [];

                  if (vehicleArray.isEmpty) {
                    return const Center(
                      child: CustomText(text: 'No vehicles found'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: vehicleArray.length,
                    itemBuilder: (context, index) {
                      final data = vehicleArray[index];
                      // Staggered fade and slide animation
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        key: ValueKey(data.vRegistrationNo),
                        builder: (context, value, child) {
                          // Delay the start of animation for each item
                          final staggerDuration = (index * 0.1).clamp(0.0, 1.0);
                          final animatedValue = (value - staggerDuration).clamp(
                            0.0,
                            1.0,
                          );

                          return Opacity(
                            opacity: animatedValue,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - animatedValue)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildVehicleCard(data),
                      );
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

  /// SEARCH BAR
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.accent, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search fleet...',
                  hintStyle: TextStyle(
                    color: AppColors.grey,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// VEHICLE CARD
  Widget _buildVehicleCard(Data data) {
    bool isEngineOn = data.tripStatus == "1";

    double speed = double.tryParse(data.lastSpeed ?? "0") ?? 0;

    double lat = double.tryParse(data.lastLatitude ?? "0") ?? 0;

    double lng = double.tryParse(data.lastLongitude ?? "0") ?? 0;

    String cacheKey = "$lat,$lng";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            // Future: Details navigation
          },
          splashColor: AppColors.accent.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Row(
                  children: [
                    /// ICON
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.lightGrey.withValues(alpha: 0.3),
                            AppColors.lightGrey.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.network(
                        data.vehicleIconUrl ?? "",
                        width: 32,
                        height: 32,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.directions_car,
                          color: AppColors.secondary,
                          size: 28,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    /// VEHICLE DETAILS
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.vRegistrationNo ?? "",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${data.vName ?? ""} ${data.vModel ?? ""}",
                            style: TextStyle(
                              color: AppColors.secondary.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// STATUS INDICATOR (Optional pulse effect could be added)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isEngineOn ? AppColors.green : AppColors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isEngineOn ? AppColors.green : AppColors.red)
                                    .withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// SPEED ROW
                /// INFO ROW
                Row(
                  children: [
                    _buildEngineStatus(isEngineOn),
                    const SizedBox(width: 12),
                    _buildIconValue(
                      Icons.speed_outlined,
                      "${speed.toStringAsFixed(0)} km/h",
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Live",
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// LOCATION SECTION WITH DIVIDER
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: FutureBuilder<String>(
                    future: _getAddress(lat, lng, cacheKey),
                    builder: (context, snapshot) {
                      String location = snapshot.data ?? "Fetching location...";
                      return Column(
                        children: [_buildLocationRow(location, "2 min ago")],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ADDRESS FETCHER WITH CACHE
  Future<String> _getAddress(
    double latitude,
    double longitude,
    String key,
  ) async {
    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      Placemark place = placemarks.first;
      String address = "${place.locality}, ${place.administrativeArea}";
      _addressCache[key] = address;
      return address;
    } catch (e) {
      return "Unknown location";
    }
  }

  /// ENGINE STATUS
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

  /// ICON + VALUE
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

  /// LOCATION ROW
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
