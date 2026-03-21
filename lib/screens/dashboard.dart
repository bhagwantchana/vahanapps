import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/screens/home_screen.dart';
import 'package:fleet_monitor/screens/profile_screen.dart';
import 'package:fleet_monitor/screens/vehicle_list.dart';
import 'package:fleet_monitor/widgets/alerts_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  static const String routeName = "dashboard_screen";
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    VehicleListWidget(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: Colors.grey.shade400,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.home),
              activeIcon: Icon(LucideIcons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.car),
              activeIcon: Icon(LucideIcons.car),
              label: 'Vehicles',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.bell),
              activeIcon: Icon(LucideIcons.bell),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.user),
              activeIcon: Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
