import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Analytics"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analytics Overview
            Row(
              children: [
                _summaryItem("Total Distance", "12,450 km", Icons.route_outlined),
                const SizedBox(width: 16),
                _summaryItem("Avg. Fuel", "8.5 L/100km", Icons.local_gas_station_rounded),
              ],
            ),
            const SizedBox(height: 24),
            
            // Distance Chart
            Text(
              "Daily Distance (km)",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: CustomCard(
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: true, topTitles: AxisTitles(), rightTitles: AxisTitles()),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: AppColors.primary)]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: AppColors.primary)]),
                      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 14, color: AppColors.primary)]),
                      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 12, color: AppColors.primary)]),
                      BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 10, color: AppColors.secondary)]),
                      BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 16, color: AppColors.primary)]),
                      BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 18, color: AppColors.primary)]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Fuel Usage Chart
            Text(
              "Fuel Consumption (Liters)",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: CustomCard(
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 30),
                          FlSpot(1, 28),
                          FlSpot(2, 35),
                          FlSpot(3, 40),
                          FlSpot(4, 32),
                          FlSpot(5, 38),
                          FlSpot(6, 42),
                        ],
                        isCurved: true,
                        color: AppColors.secondary,
                        barWidth: 4,
                        belowBarData: BarAreaData(show: true, color: AppColors.secondary.withOpacity(0.2)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Performance Metrics
            Text(
              "Fleet Performance",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _performanceTile("Total Trips", "154", "12% more than last month"),
            const SizedBox(height: 12),
            _performanceTile("Avg. Speed", "52 km/h", "Steady performance"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _performanceTile(String label, String value, String subLabel) {
    return CustomCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subLabel, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
        ],
      ),
    );
  }
}

// Extension to add height to CustomCard easily
extension on CustomCard {
  Widget get withHeight => SizedBox(height: 250, child: this);
}

// Updated CustomCard to accept height for convenience here
class CustomCardWithHeight extends StatelessWidget {
  final Widget child;
  final double height;
  const CustomCardWithHeight({super.key, required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: SizedBox(height: height, child: child),
    );
  }
}
// I will just use a SizedBox around CustomCard in the main build instead of modifying common_widgets for now to keep it clean.
// I already did: CustomCard(height: 250, ...) wait, my CustomCard doesn't have height.
// I'll adjust the implementation in ReportsScreen to use SizedBox.
