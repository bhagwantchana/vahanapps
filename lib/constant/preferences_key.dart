class PreferencesKey {
  static const String isLogin = 'isLogin';
  static const String token = 'token';
  static const String fcmToken = 'fcmToken';
  static const String biometricEnabled = 'biometricEnabled';
  static const String vehicleCareReminderPrefix = 'vehicleCareReminder';
  static const String language = 'app_language';
  static const String themeMode = 'app_theme_mode';
  // Home dashboard layout: 'map' (full-screen fleet map) | 'overview' (status
  // pie chart). Only applies in native map mode.
  static const String dashboardStyle = 'app_dashboard_style';
  // Notification filter: 'all' (every alert) | 'essential' (only ignition
  // start/stop + overspeed). Cuts notification noise per the owner's request.
  static const String alertFilterMode = 'app_alert_filter_mode';
  static const String geofencesJson = 'app_geofences_v1';
  static const String geofenceStatePrefix = 'app_geofence_state_';
  // Sub-user feature: '1' if the logged-in user is a sub-user (read-only
  // mode); '0' (or missing) for a primary customer. Cached locally so the
  // UI can gate engine/edit/settings without a network round-trip.
  static const String isSubUser = 'isSubUser';
  static const String viewMode = 'viewMode';
  static const String username = 'username';
}
