import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/screens/assigned_vehicle_maintenance_screen.dart';
import 'package:fleet_monitor/screens/document_vault_screen.dart';
import 'package:fleet_monitor/screens/driver_sessions_screen.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onSelectTab});

  final ValueChanged<int>? onSelectTab;

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthCubit>().signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final user = state.userProfileModel?.data;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[AppColors.primary, Color(0xFF2563EB)],
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        backgroundImage: user?.avatarUrl.isNotEmpty == true
                            ? NetworkImage(user!.avatarUrl)
                            : null,
                        child: user?.avatarUrl.isNotEmpty == true
                            ? null
                            : const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user?.fullName.isNotEmpty == true
                                  ? user!.fullName
                                  : 'Fleet User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _drawerItem(
              context,
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(0);
              },
            ),
            _drawerItem(
              context,
              icon: Icons.directions_car_outlined,
              title: 'Vehicles',
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(1);
              },
            ),
            _drawerItem(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Alerts',
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(2);
              },
            ),
            _drawerItem(
              context,
              icon: Icons.bar_chart_rounded,
              title: 'Reports',
              onTap: () {
                Navigator.pop(context);
                if (onSelectTab != null) {
                  onSelectTab?.call(3);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportsScreen(),
                    ),
                  );
                }
              },
            ),
            _drawerItem(
              context,
              icon: Icons.badge_outlined,
              title: 'Driver Sessions',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DriverSessionsScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.build_circle_outlined,
              title: 'Vehicle Care',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AssignedVehicleMaintenanceScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.folder_copy_outlined,
              title: 'Document Vault',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DocumentVaultScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.person_outline,
              title: 'Profile',
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(4);
              },
            ),
            const Divider(),
            const Spacer(),
            _drawerItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              color: Colors.red,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color color = AppColors.primary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: color),
      ),
      onTap: onTap,
    );
  }
}
