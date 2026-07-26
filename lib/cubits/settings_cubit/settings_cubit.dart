import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// User-controlled UI preferences: language and theme mode.
///
/// Loads persisted values from SharedPreferences on construction; safe to
/// read the initial state synchronously (defaults to system locale + system
/// theme) and the cubit will emit the persisted values once they load.
class SettingsState {
  const SettingsState({
    this.locale,
    this.themeMode = ThemeMode.system,
    this.dashboardStyle = 'map',
    this.alertFilterMode = 'all',
  });

  /// `null` means "follow device locale". Otherwise an explicit override.
  final Locale? locale;
  final ThemeMode themeMode;

  /// Home dashboard layout in native map mode: 'map' | 'overview'.
  final String dashboardStyle;

  /// Notification filter: 'all' | 'essential' (start/stop + overspeed only).
  final String alertFilterMode;

  SettingsState copyWith({
    Locale? locale,
    bool clearLocale = false,
    ThemeMode? themeMode,
    String? dashboardStyle,
    String? alertFilterMode,
  }) {
    return SettingsState(
      locale: clearLocale ? null : (locale ?? this.locale),
      themeMode: themeMode ?? this.themeMode,
      dashboardStyle: dashboardStyle ?? this.dashboardStyle,
      alertFilterMode: alertFilterMode ?? this.alertFilterMode,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final langCode = await LocalStorage.readValue(PreferencesKey.language);
    final themeStr = await LocalStorage.readValue(PreferencesKey.themeMode);
    final dash = await LocalStorage.readValue(PreferencesKey.dashboardStyle);
    final alerts = await LocalStorage.readValue(PreferencesKey.alertFilterMode);
    if (isClosed) return;
    emit(state.copyWith(
      locale: (langCode == null || langCode.isEmpty)
          ? null
          : Locale(langCode),
      themeMode: _parseThemeMode(themeStr),
      dashboardStyle: (dash == 'overview') ? 'overview' : 'map',
      alertFilterMode: (alerts == 'essential') ? 'essential' : 'all',
    ));
  }

  Future<void> setDashboardStyle(String style) async {
    final normalized = style == 'overview' ? 'overview' : 'map';
    await LocalStorage.setValue(PreferencesKey.dashboardStyle, normalized);
    emit(state.copyWith(dashboardStyle: normalized));
  }

  Future<void> setAlertFilterMode(String mode) async {
    final normalized = mode == 'essential' ? 'essential' : 'all';
    await LocalStorage.setValue(PreferencesKey.alertFilterMode, normalized);
    emit(state.copyWith(alertFilterMode: normalized));
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await LocalStorage.clearValue(PreferencesKey.language);
      emit(state.copyWith(clearLocale: true));
    } else {
      await LocalStorage.setValue(PreferencesKey.language, locale.languageCode);
      emit(state.copyWith(locale: locale));
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await LocalStorage.setValue(PreferencesKey.themeMode, _serializeThemeMode(mode));
    emit(state.copyWith(themeMode: mode));
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
