import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/screens/home_screen.dart';
import 'package:fleet_monitor/screens/profile_screen.dart';
import 'package:fleet_monitor/screens/reports_screen.dart';
import 'package:fleet_monitor/screens/vehicle_list.dart';
import 'package:fleet_monitor/widgets/alerts_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialIndex = 0});

  static const String routeName = 'dashboard_screen';

  final int initialIndex;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4).toInt();
  }

  void _selectTab(int index) {
    if (!mounted) {
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onSelectTab: _selectTab),
      const VehicleListWidget(),
      const AlertsScreen(),
      const ReportsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primaryGreen.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppTheme.primaryGreen : Colors.grey.shade500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? AppTheme.primaryGreen : Colors.grey.shade500,
              size: 22,
            );
          }),
        ),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _selectTab,
            height: 72,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(LucideIcons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.car),
                label: 'Vehicles',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.bell),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart),
                label: 'Reports',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.user),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
