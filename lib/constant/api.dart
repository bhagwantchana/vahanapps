class AppUrl {
  static const String baseUrl = 'https://vahanconnect.com/api/';
  static const String login = '${baseUrl}login';
  static const String logout = '${baseUrl}logout';
  static const String dashboard = '${baseUrl}dashboard';
  static const String vehicleList = '${baseUrl}vehicleList';
  static const String vehicleTrack = '${baseUrl}vehicleTrack';
  static const String updateVehicleSettings = '${baseUrl}updateVehicleSettings';
  static const String engineCommand = '${baseUrl}engineCommand';
  static const String alerts = '${baseUrl}alerts';
  static const String markAlertRead = '${baseUrl}markAlertRead';
  static const String myProfile = '${baseUrl}myProfile';
  static const String updateProfile = '${baseUrl}profileUpdate';
  static const String saveFcmToken = '${baseUrl}saveFcmToken';
  static const String tripHistory = '${baseUrl}tripHistory';
  static const String drivers = '${baseUrl}drivers';
  static const String assignDriver = '${baseUrl}assignDriver';
  static const String driverSessions = '${baseUrl}driverSessions';
  static const String startDriverSession = '${baseUrl}startDriverSession';
  static const String endDriverSession = '${baseUrl}endDriverSession';
  static const String documents = '${baseUrl}documents';
  static const String maintenance = '${baseUrl}maintenance';
  static const String vehicleCareMeta = '${baseUrl}vehicleCareMeta';
  static const String reports = '${baseUrl}reports';
  static const String panicAlert = '${baseUrl}panicAlert';
  /// Push the resolved address for a coordinate (legacy — used as
  /// a fallback / backfill path if the geocode endpoint is unreachable).
  static const String cacheAddress = '${baseUrl}cacheAddress';
  /// Reverse-geocode a single coordinate via the server. Server resolves
  /// via Nominatim (with cache) so mobile AND web map ALWAYS render the
  /// SAME string for the same coord — schools/customers on the web see
  /// the identical address as mobile drivers do.
  static const String geocodeAddress = '${baseUrl}geocodeAddress';

  // SSE / live stream endpoint exposed by the Node tracking server on its
  // HTTP port (default 5101). When subscribed, the server pushes one
  // `vehicle` event per GPS fix for every vehicle the user has access to.
  // Polling stays as a fallback if the SSE connection ever drops.
  static const String liveStreamUrl =
      'https://vahanconnect.com:5101/live/stream';

  /// Admin-managed help/support contacts. Returns {emails:[...], phones:[...]}.
  /// Updated from superadmin → Settings → Help & Support Contacts, so the
  /// app can change support details without a release.
  static const String supportContacts = '${baseUrl}supportContacts';

  // Sub-user feature endpoints (primary customer only).
  static const String createSubUser = '${baseUrl}createSubUser';
  static const String listSubUsers = '${baseUrl}listSubUsers';
  static const String deleteSubUser = '${baseUrl}deleteSubUser';
  static const String resetSubUserPassword = '${baseUrl}resetSubUserPassword';
  static const String assignVehiclesToSubUser =
      '${baseUrl}assignVehiclesToSubUser';
  static const String unassignVehicleFromSubUser =
      '${baseUrl}unassignVehicleFromSubUser';
  static const String subUserAssignments = '${baseUrl}subUserAssignments';
}
