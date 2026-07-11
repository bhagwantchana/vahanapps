import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/cubits/alerts_cubit/alerts_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/screens/assigned_vehicle_maintenance_screen.dart';
import 'package:fleet_monitor/screens/document_vault_screen.dart';
import 'package:fleet_monitor/screens/driver_sessions_screen.dart';
import 'package:fleet_monitor/screens/geofence_screen.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/screens/reports_screen.dart';
import 'package:fleet_monitor/screens/sub_users_screen.dart';
import 'package:fleet_monitor/screens/subscriptions_screen.dart';
import 'package:fleet_monitor/screens/trip_replay_screen.dart';
import 'package:fleet_monitor/screens/web_page_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onSelectTab});

  final ValueChanged<int>? onSelectTab;

  Future<void> _logout(BuildContext context) async {
    // Stop live SSE streams before clearing the session so the next user
    // reconnects cleanly (root-scoped cubits don't close on logout).
    // Reset all root-scoped data cubits + stop streams BEFORE clearing the
    // session, so the next user never sees the previous user's data on first paint.
    final vehicleCubit = context.read<VehicleCubit>();
    final trackCubit = context.read<SingleTrackCubit>();
    final homeCubit = context.read<HomeCubit>();
    final alertsCubit = context.read<AlertsCubit>();
    final profileCubit = context.read<ProfileCubit>();
    final authCubit = context.read<AuthCubit>();
    await vehicleCubit.reset();
    await trackCubit.reset();
    homeCubit.reset();
    alertsCubit.reset();
    profileCubit.reset();
    await authCubit.signOut();
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
                                  : AppStrings.of(context).t('fleet_user'),
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
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
            _drawerItem(
              context,
              icon: Icons.dashboard_outlined,
              title: AppStrings.of(context).t('dashboard'),
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(0);
              },
            ),
            _drawerItem(
              context,
              icon: Icons.directions_car_outlined,
              title: AppStrings.of(context).t('tab_vehicles'),
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(1);
              },
            ),
            _drawerItem(
              context,
              icon: Icons.notifications_active_outlined,
              title: AppStrings.of(context).t('tab_alerts'),
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(2);
              },
            ),
            _drawerItem(
              context,
              icon: Icons.bar_chart_rounded,
              title: AppStrings.of(context).t('tab_reports'),
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
              title: AppStrings.of(context).t('drawer_driver_sessions'),
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
            // Manage Sub-Users — only the primary account holder sees this.
            // Sub-users themselves get the row hidden + the server rejects
            // the endpoint even if they reach it manually.
            FutureBuilder<bool>(
              future: _isPrimary(),
              initialData: false,
              builder: (context, snap) {
                if (snap.data != true) return const SizedBox.shrink();
                return _drawerItem(
                  context,
                  icon: Icons.supervisor_account_outlined,
                  title: 'Manage Sub-Users',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, SubUsersScreen.routeName);
                  },
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.build_circle_outlined,
              title: AppStrings.of(context).t('drawer_vehicle_care'),
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
              title: AppStrings.of(context).t('drawer_documents'),
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
              icon: Icons.share_location_outlined,
              title: AppStrings.of(context).t('geofence_zones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const GeofenceScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.play_circle_outline_rounded,
              title: AppStrings.of(context).t('trip_replay'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const TripReplayScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.workspace_premium_outlined,
              title: AppStrings.of(context).t('subscriptions_title'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SubscriptionsScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.privacy_tip_outlined,
              title: AppStrings.of(context).t('privacy_policy'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => WebPageScreen(
                      title: AppStrings.of(context).t('privacy_policy'),
                      url: 'https://vahanconnect.com/privacy-policy',
                    ),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.person_outline,
              title: AppStrings.of(context).t('profile'),
              onTap: () {
                Navigator.pop(context);
                onSelectTab?.call(4);
              },
            ),
                ],
              ),
            ),
            const Divider(height: 1),
            _drawerItem(
              context,
              icon: Icons.logout,
              title: AppStrings.of(context).t('logout'),
              color: Colors.red,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Returns true if the logged-in user is a PRIMARY customer (the
  /// original account holder). Sub-users have `isSubUser=1` saved at
  /// login and never see the "Manage Sub-Users" drawer entry.
  Future<bool> _isPrimary() async {
    final raw = await LocalStorage.readValue(PreferencesKey.isSubUser);
    return raw != '1';
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    // Resolve the row tint:
    //  • Explicit `color` (e.g. Colors.red for Logout) always wins.
    //  • Light mode falls back to AppColors.primary (the brand navy).
    //  • Dark mode falls back to white so the row stays legible on the
    //    dark drawer surface — the brand navy disappears against it.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolved = color ??
        (isDark ? Colors.white : AppColors.primary);
    return ListTile(
      leading: Icon(icon, color: resolved),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: resolved),
      ),
      onTap: onTap,
    );
  }
}
