import 'dart:io';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            /// 🔥 PROFILE HEADER
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final user = state.userProfileModel?.data;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF2563EB)],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: _getImage(user?.image),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${user?.firstName ?? ""} ${user?.lastName ?? ""}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            Text(
                              user?.email ?? "",
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

            /// 🔹 MENU ITEMS
            _drawerItem(
              context,
              icon: Icons.dashboard_outlined,
              title: "Dashboard",
              onTap: () {
                Navigator.pop(context);
              },
            ),

            _drawerItem(
              context,
              icon: Icons.directions_car_outlined,
              title: "Vehicles",
              onTap: () {
                Navigator.pop(context);
              },
            ),

            _drawerItem(
              context,
              icon: Icons.map_outlined,
              title: "Live Tracking",
              onTap: () {
                Navigator.pop(context);
              },
            ),

            _drawerItem(
              context,
              icon: Icons.person_outline,
              title: "Profile",
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const Divider(),

            _drawerItem(
              context,
              icon: Icons.settings_outlined,
              title: "Settings",
              onTap: () {},
            ),

            const Spacer(),

            /// 🔴 LOGOUT
            _drawerItem(
              context,
              icon: Icons.logout,
              title: "Logout",
              color: Colors.red,
              onTap: () async {
                await LocalStorage.clearAll();
                if (!context.mounted) return;

                Navigator.popUntil(context, (route) => route.isFirst);
                Navigator.pushNamed(context, LoginScreen.routeName);
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// 🔧 Drawer Item
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

  /// 🖼 Image handler
  ImageProvider _getImage(String? image) {
    if (image == null || image.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }

    if (image.startsWith("http")) {
      return NetworkImage(image);
    }

    return FileImage(File(image));
  }
}
