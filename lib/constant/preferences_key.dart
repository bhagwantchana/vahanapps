class PreferencesKey {
  static const String isLogin = 'isLogin';
  static const String token = 'token';
  static const String fcmToken = 'fcmToken';
  static const String biometricEnabled = 'biometricEnabled';
  static const String vehicleCareReminderPrefix = 'vehicleCareReminder';
  static const String language = 'app_language';
  static const String themeMode = 'app_theme_mode';
  static const String geofencesJson = 'app_geofences_v1';
  static const String geofenceStatePrefix = 'app_geofence_state_';
  // Sub-user feature: '1' if the logged-in user is a sub-user (read-only
  // mode); '0' (or missing) for a primary customer. Cached locally so the
  // UI can gate engine/edit/settings without a network round-trip.
  static const String isSubUser = 'isSubUser';
  static const String username = 'username';
}
