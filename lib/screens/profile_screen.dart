import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/services/biometric_auth_service.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/gap_widget.dart';
import 'package:fleet_monitor/widgets/help_sport.dart';
import 'package:fleet_monitor/widgets/profile_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricEnabled = false;
  bool _biometricSupported = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProfileCubit>();
    if (cubit.state.userProfileModel == null) {
      cubit.fetchProfile();
    }
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final enabled = await BiometricAuthService.isEnabled();
    final supported = await BiometricAuthService.isSupported();
    if (!mounted) {
      return;
    }
    setState(() {
      _biometricEnabled = enabled;
      _biometricSupported = supported;
    });
  }

  Future<void> _toggleBiometricLogin(bool enabled) async {
    if (_biometricBusy) {
      return;
    }

    if (!enabled) {
      await BiometricAuthService.setEnabled(false);
      if (!mounted) {
        return;
      }
      setState(() => _biometricEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric login disabled')),
      );
      return;
    }

    if (!_biometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric login is not available on this device'),
        ),
      );
      return;
    }

    setState(() => _biometricBusy = true);
    final authenticated = await BiometricAuthService.authenticate(
      reason: 'Confirm your identity to enable biometric login',
    );
    if (!mounted) {
      return;
    }

    if (authenticated) {
      await BiometricAuthService.setEnabled(true);
      setState(() => _biometricEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric login enabled')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric verification was cancelled')),
      );
    }

    if (mounted) {
      setState(() => _biometricBusy = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthCubit>().signOut();
    if (!mounted) {
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(Assets.images.mylogo.path, height: 30),
        actions: <Widget>[
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.offline),
          ),
          GapWidget(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoadingState && state.userProfileModel == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ProfileErrorState && state.userProfileModel == null) {
              return Center(child: Text('Error: ${state.message}'));
            }

            final userData = state.userProfileModel?.data;
            if (userData == null) {
              return const Center(child: CustomText(text: 'No profile found'));
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: <Widget>[
                  Center(
                    child: Column(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.blueLight,
                          backgroundImage: userData.avatarUrl.isNotEmpty
                              ? NetworkImage(userData.avatarUrl)
                              : null,
                          child: userData.avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person_outline,
                                  size: 42,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userData.fullName.isEmpty ? 'Fleet User' : userData.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (userData.email.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            userData.email,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GapWidget(size: 16),
                  _sectionHeader('Account Settings'),
                  _settingsItem(
                    Icons.person_outline_rounded,
                    'View & Edit Profile',
                    'Change your basic info',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileWidget(),
                        ),
                      );
                    },
                  ),
                  GapWidget(size: 8),
                  _sectionHeader('Security'),
                  _settingsSwitch(
                    Icons.fingerprint_rounded,
                    'System biometric login',
                    _biometricSupported
                        ? 'Use Face ID or fingerprint to unlock the app'
                        : 'Biometric login is not available on this device',
                    value: _biometricEnabled,
                    enabled: _biometricSupported && !_biometricBusy,
                    onChanged: _toggleBiometricLogin,
                  ),
                  _settingsItem(
                    Icons.help_outline_rounded,
                    'Help & Support',
                    'Get in touch with us',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                  GapWidget(size: 16),
                  Text(
                    'App Version 1.0.0',
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
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _settingsSwitch(
    IconData icon,
    String title,
    String subtitle, {
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        secondary: Container(
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
        activeColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
