import 'package:flutter/material.dart';

/// Lightweight string-table localisation. We didn't go the full ARB
/// + `gen-l10n` route because the existing app has hundreds of hardcoded
/// strings and migrating them all in one go would block the rebuild.
///
/// Instead, this map-based table:
///  • Ships with English, Hindi, and Punjabi out of the box.
///  • Auto-picks the user's device locale via `AppStrings.of(context)`.
///  • Lets you add new keys incrementally — call sites that haven't
///    been migrated keep working in English exactly as before.
///
/// To add a new translatable string:
///   1. Add the key to all three maps below (`en`, `hi`, `pa`).
///   2. In your widget: `AppStrings.of(context).t('your_key')`.
///   3. Fallbacks: missing key → returns the key itself (loud-failure
///      so you notice in QA), missing locale → falls back to English.
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(const Locale('en'));
  }

  static const Locale _english = Locale('en');
  static const Locale _hindi = Locale('hi');
  static const Locale _punjabi = Locale('pa');

  static const List<Locale> supportedLocales = <Locale>[
    _english,
    _hindi,
    _punjabi,
  ];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static const Map<String, Map<String, String>> _table = <String, Map<String, String>>{
    'app_name': <String, String>{
      'en': 'VahanConnect',
      'hi': 'वाहन कनेक्ट',
      'pa': 'ਵਾਹਨ ਕਨੈਕਟ',
    },
    'login': <String, String>{
      'en': 'Login',
      'hi': 'लॉगिन',
      'pa': 'ਲੌਗਇਨ',
    },
    'logout': <String, String>{
      'en': 'Logout',
      'hi': 'लॉग आउट',
      'pa': 'ਲੌਗਆਉਟ',
    },
    'username_or_mobile': <String, String>{
      'en': 'Username or Mobile Number',
      'hi': 'उपयोगकर्ता नाम या मोबाइल नंबर',
      'pa': 'ਯੂਜ਼ਰਨੇਮ ਜਾਂ ਮੋਬਾਈਲ ਨੰਬਰ',
    },
    'password': <String, String>{
      'en': 'Password',
      'hi': 'पासवर्ड',
      'pa': 'ਪਾਸਵਰਡ',
    },
    'forgot_password': <String, String>{
      'en': 'Forgot Password?',
      'hi': 'पासवर्ड भूल गए?',
      'pa': 'ਪਾਸਵਰਡ ਭੁੱਲ ਗਏ?',
    },
    'dashboard': <String, String>{
      'en': 'Dashboard',
      'hi': 'डैशबोर्ड',
      'pa': 'ਡੈਸ਼ਬੋਰਡ',
    },
    'vehicles': <String, String>{
      'en': 'Vehicles',
      'hi': 'वाहन',
      'pa': 'ਗੱਡੀਆਂ',
    },
    'alerts': <String, String>{
      'en': 'Alerts',
      'hi': 'अलर्ट',
      'pa': 'ਅਲਰਟ',
    },
    'reports': <String, String>{
      'en': 'Reports',
      'hi': 'रिपोर्ट',
      'pa': 'ਰਿਪੋਰਟਾਂ',
    },
    'profile': <String, String>{
      'en': 'Profile',
      'hi': 'प्रोफ़ाइल',
      'pa': 'ਪ੍ਰੋਫਾਈਲ',
    },
    'status_moving': <String, String>{
      'en': 'Moving',
      'hi': 'चल रही है',
      'pa': 'ਚੱਲ ਰਹੀ ਹੈ',
    },
    'status_idle': <String, String>{
      'en': 'Idle',
      'hi': 'निष्क्रिय',
      'pa': 'ਵਿਹਲੀ',
    },
    'status_stopped': <String, String>{
      'en': 'Stopped',
      'hi': 'रुकी हुई',
      'pa': 'ਰੁਕੀ ਹੋਈ',
    },
    'status_offline': <String, String>{
      'en': 'Offline',
      'hi': 'ऑफ़लाइन',
      'pa': 'ਔਫਲਾਈਨ',
    },
    'no_vehicles_found': <String, String>{
      'en': 'No vehicles found',
      'hi': 'कोई वाहन नहीं मिला',
      'pa': 'ਕੋਈ ਗੱਡੀ ਨਹੀਂ ਮਿਲੀ',
    },
    'retry': <String, String>{
      'en': 'Retry',
      'hi': 'दोबारा कोशिश करें',
      'pa': 'ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ',
    },
    'no_internet_title': <String, String>{
      'en': 'No Internet Connection',
      'hi': 'इंटरनेट कनेक्शन नहीं है',
      'pa': 'ਇੰਟਰਨੈੱਟ ਕਨੈਕਸ਼ਨ ਨਹੀਂ ਹੈ',
    },
    'no_internet_message': <String, String>{
      'en': 'Please check your connection and try again.',
      'hi': 'कृपया अपना कनेक्शन जांचें और दोबारा कोशिश करें।',
      'pa': 'ਆਪਣਾ ਕਨੈਕਸ਼ਨ ਚੈੱਕ ਕਰੋ ਅਤੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।',
    },
    'cancel': <String, String>{
      'en': 'Cancel',
      'hi': 'रद्द करें',
      'pa': 'ਰੱਦ ਕਰੋ',
    },
    'confirm': <String, String>{
      'en': 'Confirm',
      'hi': 'पुष्टि करें',
      'pa': 'ਪੁਸ਼ਟੀ ਕਰੋ',
    },
    'last_seen': <String, String>{
      'en': 'Last seen',
      'hi': 'अंतिम बार देखा गया',
      'pa': 'ਆਖਰੀ ਵਾਰ ਦੇਖਿਆ',
    },
    'engine_start': <String, String>{
      'en': 'Engine Start',
      'hi': 'इंजन शुरू करें',
      'pa': 'ਇੰਜਣ ਚਾਲੂ ਕਰੋ',
    },
    'engine_stop': <String, String>{
      'en': 'Engine Stop',
      'hi': 'इंजन बंद करें',
      'pa': 'ਇੰਜਣ ਬੰਦ ਕਰੋ',
    },
    'login_error_default': <String, String>{
      'en': 'Login failed. Please check your username and password.',
      'hi': 'लॉगिन विफल। कृपया अपना उपयोगकर्ता नाम और पासवर्ड जांचें।',
      'pa': 'ਲੌਗਇਨ ਫੇਲ੍ਹ। ਆਪਣਾ ਯੂਜ਼ਰਨੇਮ ਅਤੇ ਪਾਸਵਰਡ ਚੈੱਕ ਕਰੋ।',
    },
    // ----- Settings (language + theme) -----
    'language': <String, String>{
      'en': 'Language',
      'hi': 'भाषा',
      'pa': 'ਭਾਸ਼ਾ',
    },
    'language_system': <String, String>{
      'en': 'System default',
      'hi': 'सिस्टम डिफ़ॉल्ट',
      'pa': 'ਸਿਸਟਮ ਡਿਫਾਲਟ',
    },
    'language_english': <String, String>{
      'en': 'English',
      'hi': 'अंग्रेज़ी',
      'pa': 'ਅੰਗਰੇਜ਼ੀ',
    },
    'language_hindi': <String, String>{
      'en': 'Hindi',
      'hi': 'हिंदी',
      'pa': 'ਹਿੰਦੀ',
    },
    'language_punjabi': <String, String>{
      'en': 'Punjabi',
      'hi': 'पंजाबी',
      'pa': 'ਪੰਜਾਬੀ',
    },
    'appearance': <String, String>{
      'en': 'Appearance',
      'hi': 'दिखावट',
      'pa': 'ਦਿੱਖ',
    },
    'theme': <String, String>{
      'en': 'Theme',
      'hi': 'थीम',
      'pa': 'ਥੀਮ',
    },
    'theme_light': <String, String>{
      'en': 'Light',
      'hi': 'लाइट',
      'pa': 'ਲਾਈਟ',
    },
    'theme_dark': <String, String>{
      'en': 'Dark',
      'hi': 'डार्क',
      'pa': 'ਡਾਰਕ',
    },
    'theme_system': <String, String>{
      'en': 'Follow system',
      'hi': 'सिस्टम के अनुसार',
      'pa': 'ਸਿਸਟਮ ਅਨੁਸਾਰ',
    },
    'preferences': <String, String>{
      'en': 'Preferences',
      'hi': 'प्राथमिकताएँ',
      'pa': 'ਤਰਜੀਹਾਂ',
    },
    // ----- Filter chips (vehicle list) -----
    'filter_all': <String, String>{
      'en': 'All',
      'hi': 'सभी',
      'pa': 'ਸਾਰੀਆਂ',
    },
    'filter_offline': <String, String>{
      'en': 'Offline',
      'hi': 'ऑफ़लाइन',
      'pa': 'ਔਫਲਾਈਨ',
    },
    'filter_low_battery': <String, String>{
      'en': 'Low Battery',
      'hi': 'कम बैटरी',
      'pa': 'ਘੱਟ ਬੈਟਰੀ',
    },
    // ----- Geofence -----
    'geofence_zones': <String, String>{
      'en': 'Geofence Zones',
      'hi': 'जियोफ़ेंस ज़ोन',
      'pa': 'ਜੀਓਫੈਂਸ ਜ਼ੋਨ',
    },
    'geofence_add': <String, String>{
      'en': 'Add Zone',
      'hi': 'ज़ोन जोड़ें',
      'pa': 'ਜ਼ੋਨ ਜੋੜੋ',
    },
    'geofence_edit': <String, String>{
      'en': 'Edit Zone',
      'hi': 'ज़ोन संपादित करें',
      'pa': 'ਜ਼ੋਨ ਸੋਧੋ',
    },
    'geofence_name': <String, String>{
      'en': 'Zone Name',
      'hi': 'ज़ोन का नाम',
      'pa': 'ਜ਼ੋਨ ਦਾ ਨਾਮ',
    },
    'geofence_radius_meters': <String, String>{
      'en': 'Radius (meters)',
      'hi': 'त्रिज्या (मीटर)',
      'pa': 'ਘੇਰਾ (ਮੀਟਰ)',
    },
    'geofence_latitude': <String, String>{
      'en': 'Latitude',
      'hi': 'अक्षांश',
      'pa': 'ਅਕਸ਼ਾਂਸ਼',
    },
    'geofence_longitude': <String, String>{
      'en': 'Longitude',
      'hi': 'देशांतर',
      'pa': 'ਲੰਬਕਾਰ',
    },
    'geofence_no_zones': <String, String>{
      'en': 'No zones yet. Tap + to add one.',
      'hi': 'अभी कोई ज़ोन नहीं। जोड़ने के लिए + दबाएँ।',
      'pa': 'ਕੋਈ ਜ਼ੋਨ ਨਹੀਂ। ਜੋੜਨ ਲਈ + ਦਬਾਓ।',
    },
    'geofence_entry_alert': <String, String>{
      'en': 'entered',
      'hi': 'में दाखिल हुई',
      'pa': 'ਵਿੱਚ ਦਾਖ਼ਲ ਹੋਈ',
    },
    'geofence_exit_alert': <String, String>{
      'en': 'left',
      'hi': 'से बाहर निकली',
      'pa': 'ਤੋਂ ਬਾਹਰ ਨਿਕਲੀ',
    },
    'geofence_use_current_location': <String, String>{
      'en': 'Use vehicle location',
      'hi': 'वाहन का स्थान उपयोग करें',
      'pa': 'ਗੱਡੀ ਦੀ ਥਾਂ ਵਰਤੋ',
    },
    'enabled': <String, String>{
      'en': 'Enabled',
      'hi': 'सक्षम',
      'pa': 'ਚਾਲੂ',
    },
    'save': <String, String>{
      'en': 'Save',
      'hi': 'सहेजें',
      'pa': 'ਸੇਵ ਕਰੋ',
    },
    'delete': <String, String>{
      'en': 'Delete',
      'hi': 'हटाएँ',
      'pa': 'ਮਿਟਾਓ',
    },
    // ----- Trip replay -----
    'trip_replay': <String, String>{
      'en': 'Trip Replay',
      'hi': 'ट्रिप रीप्ले',
      'pa': 'ਟਰਿੱਪ ਰੀਪਲੇਅ',
    },
    'trip_replay_today': <String, String>{
      'en': 'Replay Today',
      'hi': 'आज का रीप्ले',
      'pa': 'ਅੱਜ ਦਾ ਰੀਪਲੇਅ',
    },
    'play': <String, String>{
      'en': 'Play',
      'hi': 'चलाएँ',
      'pa': 'ਚਲਾਓ',
    },
    'pause': <String, String>{
      'en': 'Pause',
      'hi': 'रोकें',
      'pa': 'ਰੋਕੋ',
    },
    'speed': <String, String>{
      'en': 'Speed',
      'hi': 'गति',
      'pa': 'ਗਤੀ',
    },
    'no_trip_data': <String, String>{
      'en': 'No trip points available for today',
      'hi': 'आज के लिए कोई ट्रिप डेटा उपलब्ध नहीं',
      'pa': 'ਅੱਜ ਲਈ ਕੋਈ ਟਰਿੱਪ ਡਾਟਾ ਨਹੀਂ',
    },
    // ----- Bottom navigation / tabs -----
    'tab_home': <String, String>{
      'en': 'Home',
      'hi': 'होम',
      'pa': 'ਹੋਮ',
    },
    'tab_vehicles': <String, String>{
      'en': 'Vehicles',
      'hi': 'वाहन',
      'pa': 'ਗੱਡੀਆਂ',
    },
    'tab_alerts': <String, String>{
      'en': 'Alerts',
      'hi': 'अलर्ट',
      'pa': 'ਅਲਰਟ',
    },
    'tab_reports': <String, String>{
      'en': 'Reports',
      'hi': 'रिपोर्ट',
      'pa': 'ਰਿਪੋਰਟਾਂ',
    },
    'tab_profile': <String, String>{
      'en': 'Profile',
      'hi': 'प्रोफ़ाइल',
      'pa': 'ਪ੍ਰੋਫਾਈਲ',
    },
    // ----- Drawer items -----
    'drawer_driver_sessions': <String, String>{
      'en': 'Driver Sessions',
      'hi': 'ड्राइवर सत्र',
      'pa': 'ਡਰਾਈਵਰ ਸੈਸ਼ਨ',
    },
    'drawer_vehicle_care': <String, String>{
      'en': 'Vehicle Care',
      'hi': 'वाहन देखभाल',
      'pa': 'ਗੱਡੀ ਦੀ ਦੇਖਭਾਲ',
    },
    'drawer_documents': <String, String>{
      'en': 'Document Vault',
      'hi': 'दस्तावेज़ वॉल्ट',
      'pa': 'ਦਸਤਾਵੇਜ਼ ਵਾਲਟ',
    },
    'fleet_user': <String, String>{
      'en': 'Fleet User',
      'hi': 'फ़्लीट यूज़र',
      'pa': 'ਫਲੀਟ ਯੂਜ਼ਰ',
    },
    // ----- Vehicle list / card -----
    'search_vehicle_hint': <String, String>{
      'en': 'Search by vehicle number, name or driver',
      'hi': 'वाहन नंबर, नाम या ड्राइवर से खोजें',
      'pa': 'ਗੱਡੀ ਨੰਬਰ, ਨਾਮ ਜਾਂ ਡਰਾਈਵਰ ਨਾਲ ਖੋਜੋ',
    },
    'track': <String, String>{
      'en': 'Track',
      'hi': 'ट्रैक',
      'pa': 'ਟਰੈਕ',
    },
    'stop': <String, String>{
      'en': 'Stop',
      'hi': 'रोकें',
      'pa': 'ਰੋਕੋ',
    },
    'speed_label': <String, String>{
      'en': 'Speed',
      'hi': 'गति',
      'pa': 'ਗਤੀ',
    },
    'battery': <String, String>{
      'en': 'Battery',
      'hi': 'बैटरी',
      'pa': 'ਬੈਟਰੀ',
    },
    'engine': <String, String>{
      'en': 'Engine',
      'hi': 'इंजन',
      'pa': 'ਇੰਜਣ',
    },
    'on': <String, String>{
      'en': 'ON',
      'hi': 'चालू',
      'pa': 'ਚਾਲੂ',
    },
    'off': <String, String>{
      'en': 'OFF',
      'hi': 'बंद',
      'pa': 'ਬੰਦ',
    },
    'last_trip': <String, String>{
      'en': 'Last Trip',
      'hi': 'पिछली यात्रा',
      'pa': 'ਪਿਛਲੀ ਯਾਤਰਾ',
    },
    'device_id': <String, String>{
      'en': 'Device ID',
      'hi': 'डिवाइस आईडी',
      'pa': 'ਡਿਵਾਈਸ ਆਈਡੀ',
    },
    'updated_label': <String, String>{
      'en': 'Updated',
      'hi': 'अपडेट',
      'pa': 'ਅਪਡੇਟ',
    },
    'min_ago': <String, String>{
      'en': 'min ago',
      'hi': 'मिनट पहले',
      'pa': 'ਮਿੰਟ ਪਹਿਲਾਂ',
    },
    'hr_ago': <String, String>{
      'en': 'hr ago',
      'hi': 'घंटे पहले',
      'pa': 'ਘੰਟੇ ਪਹਿਲਾਂ',
    },
    'days_ago': <String, String>{
      'en': 'days ago',
      'hi': 'दिन पहले',
      'pa': 'ਦਿਨ ਪਹਿਲਾਂ',
    },
    'now': <String, String>{
      'en': 'now',
      'hi': 'अभी',
      'pa': 'ਹੁਣੇ',
    },
    'vehicles_count': <String, String>{
      'en': 'Vehicles',
      'hi': 'वाहन',
      'pa': 'ਗੱਡੀਆਂ',
    },
    // ----- Home screen sections -----
    'quick_actions': <String, String>{
      'en': 'Quick Actions',
      'hi': 'त्वरित कार्य',
      'pa': 'ਤੁਰੰਤ ਕਾਰਵਾਈਆਂ',
    },
    'view_all': <String, String>{
      'en': 'View All',
      'hi': 'सभी देखें',
      'pa': 'ਸਾਰੇ ਵੇਖੋ',
    },
    'see_all': <String, String>{
      'en': 'See All',
      'hi': 'सभी देखें',
      'pa': 'ਸਾਰੇ ਵੇਖੋ',
    },
    'track_live': <String, String>{
      'en': 'Track Live',
      'hi': 'लाइव ट्रैक',
      'pa': 'ਲਾਈਵ ਟਰੈਕ',
    },
    'recent_activity': <String, String>{
      'en': 'Recent Activity',
      'hi': 'हाल की गतिविधि',
      'pa': 'ਤਾਜ਼ਾ ਗਤੀਵਿਧੀ',
    },
    'no_recent_activity': <String, String>{
      'en': 'No recent activity found',
      'hi': 'कोई हालिया गतिविधि नहीं मिली',
      'pa': 'ਕੋਈ ਤਾਜ਼ਾ ਗਤੀਵਿਧੀ ਨਹੀਂ ਮਿਲੀ',
    },
    'performance_overview': <String, String>{
      'en': 'Performance Overview',
      'hi': 'प्रदर्शन अवलोकन',
      'pa': 'ਪ੍ਰਦਰਸ਼ਨ ਜਾਇਜ਼ਾ',
    },
    'today': <String, String>{
      'en': 'Today',
      'hi': 'आज',
      'pa': 'ਅੱਜ',
    },
    'total_distance': <String, String>{
      'en': 'Total Distance',
      'hi': 'कुल दूरी',
      'pa': 'ਕੁੱਲ ਦੂਰੀ',
    },
    'total': <String, String>{
      'en': 'Total',
      'hi': 'कुल',
      'pa': 'ਕੁੱਲ',
    },
    'devices': <String, String>{
      'en': 'Devices',
      'hi': 'डिवाइस',
      'pa': 'ਡਿਵਾਈਸ',
    },
    'loading_map': <String, String>{
      'en': 'Loading Map...',
      'hi': 'मानचित्र लोड हो रहा है...',
      'pa': 'ਨਕਸ਼ਾ ਲੋਡ ਹੋ ਰਿਹਾ ਹੈ...',
    },
    'connect_device_hint': <String, String>{
      'en': 'Connect a device to track',
      'hi': 'ट्रैक करने के लिए डिवाइस कनेक्ट करें',
      'pa': 'ਟਰੈਕ ਕਰਨ ਲਈ ਡਿਵਾਈਸ ਜੋੜੋ',
    },
    'minimize': <String, String>{
      'en': 'Minimize',
      'hi': 'छोटा करें',
      'pa': 'ਛੋਟਾ ਕਰੋ',
    },
    'live': <String, String>{
      'en': 'Live',
      'hi': 'लाइव',
      'pa': 'ਲਾਈਵ',
    },
    // ----- Profile -----
    'account_settings': <String, String>{
      'en': 'Account Settings',
      'hi': 'खाता सेटिंग्स',
      'pa': 'ਖਾਤਾ ਸੈਟਿੰਗਾਂ',
    },
    'view_edit_profile': <String, String>{
      'en': 'View & Edit Profile',
      'hi': 'प्रोफ़ाइल देखें और संपादित करें',
      'pa': 'ਪ੍ਰੋਫਾਈਲ ਵੇਖੋ ਅਤੇ ਸੋਧੋ',
    },
    'change_basic_info': <String, String>{
      'en': 'Change your basic info',
      'hi': 'अपनी मूल जानकारी बदलें',
      'pa': 'ਆਪਣੀ ਮੁੱਢਲੀ ਜਾਣਕਾਰੀ ਬਦਲੋ',
    },
    'security': <String, String>{
      'en': 'Security',
      'hi': 'सुरक्षा',
      'pa': 'ਸੁਰੱਖਿਆ',
    },
    'biometric_login': <String, String>{
      'en': 'System biometric login',
      'hi': 'सिस्टम बायोमेट्रिक लॉगिन',
      'pa': 'ਸਿਸਟਮ ਬਾਇਓਮੈਟ੍ਰਿਕ ਲੌਗਇਨ',
    },
    'biometric_login_subtitle': <String, String>{
      'en': 'Use Face ID or fingerprint to unlock the app',
      'hi': 'ऐप अनलॉक करने के लिए Face ID या फ़िंगरप्रिंट का उपयोग करें',
      'pa': 'ਐਪ ਅਨਲੌਕ ਕਰਨ ਲਈ Face ID ਜਾਂ ਫਿੰਗਰਪ੍ਰਿੰਟ ਵਰਤੋ',
    },
    'biometric_unsupported': <String, String>{
      'en': 'Biometric login is not available on this device',
      'hi': 'इस डिवाइस पर बायोमेट्रिक लॉगिन उपलब्ध नहीं है',
      'pa': 'ਇਸ ਡਿਵਾਈਸ ਤੇ ਬਾਇਓਮੈਟ੍ਰਿਕ ਲੌਗਇਨ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'help_support': <String, String>{
      'en': 'Help & Support',
      'hi': 'सहायता और समर्थन',
      'pa': 'ਮਦਦ ਅਤੇ ਸਪੋਰਟ',
    },
    'help_support_subtitle': <String, String>{
      'en': 'Get in touch with us',
      'hi': 'हमसे संपर्क करें',
      'pa': 'ਸਾਡੇ ਨਾਲ ਸੰਪਰਕ ਕਰੋ',
    },
    'app_version': <String, String>{
      'en': 'App Version',
      'hi': 'ऐप संस्करण',
      'pa': 'ਐਪ ਵਰਜਨ',
    },
    'no_profile_found': <String, String>{
      'en': 'No profile found',
      'hi': 'कोई प्रोफ़ाइल नहीं मिली',
      'pa': 'ਕੋਈ ਪ੍ਰੋਫਾਈਲ ਨਹੀਂ ਮਿਲੀ',
    },
    'change': <String, String>{
      'en': 'Change',
      'hi': 'बदलें',
      'pa': 'ਬਦਲੋ',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    final byKey = _table[key];
    if (byKey == null) return key; // loud fallback so missing keys show up in QA
    return byKey[lang] ?? byKey['en'] ?? key;
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppStrings.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<AppStrings> load(Locale locale) async {
    // Pick the closest supported locale by language code only; ignore
    // country variants (so en_IN behaves like en).
    final matched = AppStrings.supportedLocales.firstWhere(
      (l) => l.languageCode == locale.languageCode,
      orElse: () => const Locale('en'),
    );
    return AppStrings(matched);
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
