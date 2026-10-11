import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/alerts_cubit/alerts_cubit.dart';
import 'package:fleet_monitor/cubits/alerts_cubit/alerts_state.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/screens/home_screen.dart';
import 'package:fleet_monitor/screens/profile_screen.dart';
import 'package:fleet_monitor/screens/reports_screen.dart';
import 'package:fleet_monitor/screens/vehicle_list.dart';
import 'package:fleet_monitor/services/local_notification.dart';
import 'package:fleet_monitor/widgets/alerts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    // Dashboard is only reachable post-auth (splash biometric pass or fresh
    // login) — open the notification deep-link gate and flush any payload
    // stashed by a terminated-state tap. Post-frame so the flush navigates on
    // a settled stack (splash's pushReplacement has already run).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CustomNotificationSoundService().markLaunchGateOpen();
    });
  }

  void _selectTab(int index) {
    if (!mounted) {
      return;
    }
    setState(() => _currentIndex = index);
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
    Widget? badge,
  }) {
    final selected = _currentIndex == index;
    final primaryColor = AppTheme.primaryGreen;
    final inactiveColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_currentIndex != index) {
              HapticFeedback.lightImpact();
              _selectTab(index);
            }
          },
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? primaryColor.withValues(alpha: isDark ? 0.16 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      AnimatedScale(
                        scale: selected ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          icon,
                          size: 21,
                          color: selected ? primaryColor : inactiveColor,
                        ),
                      ),
                      if (badge != null)
                        Positioned(
                          right: -7,
                          top: -3,
                          child: badge,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? primaryColor : inactiveColor,
                    letterSpacing: selected ? -0.2 : -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: selected ? 12 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: selected ? primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onSelectTab: _selectTab),
      VehicleListWidget(onSelectTab: _selectTab),
      AlertsScreen(onSelectTab: _selectTab),
      ReportsScreen(onSelectTab: _selectTab),
      ProfileScreen(onSelectTab: _selectTab),
    ];

    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ??
              (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              children: <Widget>[
                _buildNavItem(
                  index: 0,
                  icon: LucideIcons.home,
                  label: strings.t('tab_home'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 1,
                  icon: LucideIcons.car,
                  label: strings.t('tab_vehicles'),
                  isDark: isDark,
                ),
                BlocBuilder<AlertsCubit, AlertsState>(
                  builder: (context, alertState) {
                    final unread = alertState.alertListModel?.meta.unreadCount ?? 0;
                    Widget? badge;
                    if (unread > 0) {
                      badge = Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      );
                    }
                    return _buildNavItem(
                      index: 2,
                      icon: LucideIcons.bell,
                      label: strings.t('tab_alerts'),
                      isDark: isDark,
                      badge: badge,
                    );
                  },
                ),
                _buildNavItem(
                  index: 3,
                  icon: LucideIcons.barChart2,
                  label: strings.t('tab_reports'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 4,
                  icon: LucideIcons.user,
                  label: strings.t('tab_profile'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
