import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/alerts_cubit/alerts_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/cubits/settings_cubit/settings_cubit.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/screens/web_page_screen.dart';
import 'package:fleet_monitor/services/biometric_auth_service.dart';
import 'package:fleet_monitor/widgets/app_logo.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/drawer.dart';
import 'package:fleet_monitor/widgets/gap_widget.dart';
import 'package:fleet_monitor/widgets/help_sport.dart';
import 'package:fleet_monitor/widgets/profile_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onSelectTab, this.isStudent = false});

  /// Lets the shared drawer switch dashboard tabs from this screen.
  final ValueChanged<int>? onSelectTab;

  /// Locked "student" sub-user mode: no sidebar drawer (which would expose
  /// Dashboard/Vehicles/etc. with no way back), a plain back button instead of
  /// the hamburger, and no Account Settings section. Everything else (name,
  /// security, preferences) stays.
  final bool isStudent;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Biometric login disabled')));
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
      // setEnabled is async — re-check mounted before touching context.
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Biometric login enabled')));
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
    // Capture cubits synchronously, then stop the live SSE streams before
    // clearing the session — the root-scoped cubits otherwise keep streaming
    // the old user and block the next user from reconnecting until restart.
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
    if (!mounted) {
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Student mode: no drawer at all (it would expose the full app menu with
      // no route back to the locked map).
      drawer: widget.isStudent ? null : AppDrawer(onSelectTab: widget.onSelectTab),
      appBar: AppBar(
        title: const AppLogo(),
        leading: widget.isStudent
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
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
            if (state is ProfileLoadingState &&
                state.userProfileModel == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ProfileErrorState && state.userProfileModel == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load your profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.read<ProfileCubit>().fetchProfile(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(AppStrings.of(context).t('retry')),
                      ),
                    ],
                  ),
                ),
              );
            }

            final userData = state.userProfileModel?.data;
            if (userData == null) {
              return Center(child: CustomText(text: AppStrings.of(context).t('no_profile_found')));
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
                          userData.fullName.isEmpty
                              ? AppStrings.of(context).t('fleet_user')
                              : userData.fullName,
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
                  // Account Settings (view/edit profile) is hidden for a
                  // locked student sub-user.
                  if (!widget.isStudent) ...<Widget>[
                    _sectionHeader(AppStrings.of(context).t('account_settings')),
                    _settingsItem(
                      Icons.person_outline_rounded,
                      AppStrings.of(context).t('view_edit_profile'),
                      AppStrings.of(context).t('change_basic_info'),
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
                  ],
                  _sectionHeader(AppStrings.of(context).t('security')),
                  _settingsSwitch(
                    Icons.fingerprint_rounded,
                    AppStrings.of(context).t('biometric_login'),
                    _biometricSupported
                        ? AppStrings.of(context).t('biometric_login_subtitle')
                        : AppStrings.of(context).t('biometric_unsupported'),
                    value: _biometricEnabled,
                    enabled: _biometricSupported && !_biometricBusy,
                    onChanged: _toggleBiometricLogin,
                  ),
                  _settingsItem(
                    Icons.help_outline_rounded,
                    AppStrings.of(context).t('help_support'),
                    AppStrings.of(context).t('help_support_subtitle'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                  _settingsItem(
                    Icons.privacy_tip_outlined,
                    AppStrings.of(context).t('privacy_policy'),
                    AppStrings.of(context).t('privacy_policy_subtitle'),
                    onTap: () {
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
                  GapWidget(size: 8),
                  _sectionHeader(AppStrings.of(context).t('preferences')),
                  _buildLanguageTile(),
                  _buildThemeTile(),
                  GapWidget(size: 16),
                  Text(
                    '${AppStrings.of(context).t('app_version')} 1.0.0',
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
        color: Theme.of(context).cardTheme.color ?? Colors.white,
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

  Widget _buildLanguageTile() {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final strings = AppStrings.of(context);
        final label = _localeLabel(strings, settings.locale);
        return _settingsItem(
          Icons.language_rounded,
          strings.t('language'),
          label,
          onTap: _showLanguagePicker,
        );
      },
    );
  }

  Widget _buildThemeTile() {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final strings = AppStrings.of(context);
        return _settingsItem(
          Icons.brightness_6_rounded,
          strings.t('theme'),
          _themeLabel(strings, settings.themeMode),
          onTap: _showThemePicker,
        );
      },
    );
  }

  String _localeLabel(AppStrings strings, Locale? locale) {
    if (locale == null) return strings.t('language_system');
    switch (locale.languageCode) {
      case 'hi':
        return strings.t('language_hindi');
      case 'pa':
        return strings.t('language_punjabi');
      default:
        return strings.t('language_english');
    }
  }

  String _themeLabel(AppStrings strings, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return strings.t('theme_light');
      case ThemeMode.dark:
        return strings.t('theme_dark');
      case ThemeMode.system:
        return strings.t('theme_system');
    }
  }

  Future<void> _showLanguagePicker() async {
    final cubit = context.read<SettingsCubit>();
    final current = cubit.state.locale?.languageCode;
    final strings = AppStrings.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _languageOption(sheetCtx, 'system', strings.t('language_system'), current == null),
              _languageOption(sheetCtx, 'en', strings.t('language_english'), current == 'en'),
              _languageOption(sheetCtx, 'hi', strings.t('language_hindi'), current == 'hi'),
              _languageOption(sheetCtx, 'pa', strings.t('language_punjabi'), current == 'pa'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    if (selected == 'system') {
      await cubit.setLocale(null);
    } else {
      await cubit.setLocale(Locale(selected));
    }
  }

  Widget _languageOption(BuildContext ctx, String code, String label, bool selected) {
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.grey,
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => Navigator.pop(ctx, code),
    );
  }

  Future<void> _showThemePicker() async {
    final cubit = context.read<SettingsCubit>();
    final current = cubit.state.themeMode;
    final strings = AppStrings.of(context);
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _themeOption(sheetCtx, ThemeMode.system, strings.t('theme_system'), current),
              _themeOption(sheetCtx, ThemeMode.light, strings.t('theme_light'), current),
              _themeOption(sheetCtx, ThemeMode.dark, strings.t('theme_dark'), current),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await cubit.setThemeMode(selected);
  }

  Widget _themeOption(BuildContext ctx, ThemeMode mode, String label, ThemeMode current) {
    final selected = mode == current;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.grey,
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => Navigator.pop(ctx, mode),
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
        color: Theme.of(context).cardTheme.color ?? Colors.white,
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
        activeThumbColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
