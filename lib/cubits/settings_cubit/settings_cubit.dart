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
  });

  /// `null` means "follow device locale". Otherwise an explicit override.
  final Locale? locale;
  final ThemeMode themeMode;

  SettingsState copyWith({
    Locale? locale,
    bool clearLocale = false,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      locale: clearLocale ? null : (locale ?? this.locale),
      themeMode: themeMode ?? this.themeMode,
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
    emit(state.copyWith(
      locale: (langCode == null || langCode.isEmpty)
          ? null
          : Locale(langCode),
      themeMode: _parseThemeMode(themeStr),
    ));
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
