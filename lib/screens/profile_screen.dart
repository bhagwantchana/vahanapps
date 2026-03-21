import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/gap_widget.dart';
import 'package:fleet_monitor/widgets/help_sport.dart';
import 'package:fleet_monitor/widgets/profile_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(Assets.images.mylogo.path, height: 30),
        actions: [
          IconButton(
            onPressed: () async {
              await LocalStorage.clearAll();
              if (!context.mounted) return;
              Navigator.popUntil(context, (route) => route.isFirst);
              Navigator.pushNamed(context, LoginScreen.routeName);
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.offline),
          ),
          GapWidget(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoadingState) {
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
                      "Loading your profile...",
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
            if (state is ProfileErrorState) {
              return Center(child: Text("Error: ${state.message}"));
            }
            final userData = state.userProfileModel?.data;

            if (userData == null) {
              return const Center(child: CustomText(text: 'No profile found'));
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(userData.image!),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "${userData.firstName!} ${userData.lastName!}",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GapWidget(size: 16),
                  _sectionHeader("Account Settings"),
                  _settingsItem(
                    Icons.person_outline_rounded,
                    "View & Edit Profile",
                    "Change your basic info",
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const ProfileWidget(),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  _settingsItem(
                    Icons.help_outline_rounded,
                    "Help & Support",
                    "Get in touch with us",
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              const HelpSupportScreen(),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  GapWidget(size: 16),
                  Text(
                    "App Version 1.0.0",
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _settingsItem(
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.grey),
        ),
        trailing:
            trailing ??
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
        onTap: onTap,
      ),
    );
  }
}
