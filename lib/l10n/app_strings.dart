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
    // ----- Subscriptions screen -----
    'subscriptions_title': <String, String>{
      'en': 'Subscriptions',
      'hi': 'सब्सक्रिप्शन',
      'pa': 'ਸਬਸਕ੍ਰਿਪਸ਼ਨ',
    },
    'subscriptions_subtitle': <String, String>{
      'en': 'Tracking plan of every vehicle — renew before it expires.',
      'hi': 'हर वाहन का ट्रैकिंग प्लान — समाप्त होने से पहले नवीनीकरण करें।',
      'pa': 'ਹਰ ਗੱਡੀ ਦਾ ਟ੍ਰੈਕਿੰਗ ਪਲਾਨ — ਖਤਮ ਹੋਣ ਤੋਂ ਪਹਿਲਾਂ ਰੀਨਿਊ ਕਰੋ।',
    },
    'subs_active': <String, String>{
      'en': 'Active',
      'hi': 'सक्रिय',
      'pa': 'ਐਕਟਿਵ',
    },
    'subs_expiring': <String, String>{
      'en': 'Expiring',
      'hi': 'समाप्त हो रहा',
      'pa': 'ਖਤਮ ਹੋ ਰਿਹਾ',
    },
    'subs_expired': <String, String>{
      'en': 'Expired',
      'hi': 'समाप्त',
      'pa': 'ਖਤਮ',
    },
    'subs_valid_till': <String, String>{
      'en': 'Valid till',
      'hi': 'मान्य तक',
      'pa': 'ਵੈਧ ਤੱਕ',
    },
    'subs_no_expiry': <String, String>{
      'en': 'No expiry set',
      'hi': 'कोई समाप्ति तिथि नहीं',
      'pa': 'ਕੋਈ ਮਿਆਦ ਸੈੱਟ ਨਹੀਂ',
    },
    'subs_renew_hint': <String, String>{
      'en': 'To renew a plan, contact support.',
      'hi': 'प्लान नवीनीकरण के लिए सपोर्ट से संपर्क करें।',
      'pa': 'ਪਲਾਨ ਰੀਨਿਊ ਕਰਨ ਲਈ ਸਪੋਰਟ ਨਾਲ ਸੰਪਰਕ ਕਰੋ।',
    },
    'subs_empty': <String, String>{
      'en': 'No vehicles found',
      'hi': 'कोई वाहन नहीं मिला',
      'pa': 'ਕੋਈ ਗੱਡੀ ਨਹੀਂ ਮਿਲੀ',
    },
    // ----- Legal -----
    'privacy_policy': <String, String>{
      'en': 'Privacy Policy',
      'hi': 'गोपनीयता नीति',
      'pa': 'ਪ੍ਰਾਈਵੇਸੀ ਪਾਲਿਸੀ',
    },
    'privacy_policy_subtitle': <String, String>{
      'en': 'How we collect, use and protect your data',
      'hi': 'हम आपका डेटा कैसे एकत्र, उपयोग और सुरक्षित करते हैं',
      'pa': 'ਅਸੀਂ ਤੁਹਾਡਾ ਡਾਟਾ ਕਿਵੇਂ ਇਕੱਠਾ, ਵਰਤੋਂ ਤੇ ਸੁਰੱਖਿਅਤ ਕਰਦੇ ਹਾਂ',
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
    'close': <String, String>{
      'en': 'Close',
      'hi': 'बंद करें',
      'pa': 'ਬੰਦ ਕਰੋ',
    },
    'copy': <String, String>{
      'en': 'Copy',
      'hi': 'कॉपी',
      'pa': 'ਕਾਪੀ',
    },
    'copied': <String, String>{
      'en': 'Copied',
      'hi': 'कॉपी हो गया',
      'pa': 'ਕਾਪੀ ਹੋ ਗਿਆ',
    },
    'share': <String, String>{
      'en': 'Share',
      'hi': 'साझा करें',
      'pa': 'ਸਾਂਝਾ ਕਰੋ',
    },
    'remove': <String, String>{
      'en': 'Remove',
      'hi': 'हटाएं',
      'pa': 'ਹਟਾਓ',
    },
    'send': <String, String>{
      'en': 'Send',
      'hi': 'भेजें',
      'pa': 'ਭੇਜੋ',
    },
    'call': <String, String>{
      'en': 'Call',
      'hi': 'कॉल',
      'pa': 'ਕਾਲ',
    },
    'all': <String, String>{
      'en': 'All',
      'hi': 'सभी',
      'pa': 'ਸਾਰੇ',
    },
    'unread': <String, String>{
      'en': 'Unread',
      'hi': 'बिना पढ़े',
      'pa': 'ਅਣਪੜ੍ਹੇ',
    },
    'update_now': <String, String>{
      'en': 'Update Now',
      'hi': 'अभी अपडेट करें',
      'pa': 'ਹੁਣੇ ਅੱਪਡੇਟ ਕਰੋ',
    },
    'remove_user_q': <String, String>{
      'en': 'Remove {name}?',
      'hi': '{name} को हटाएं?',
      'pa': '{name} ਹਟਾਓ?',
    },
    'share_link_title': <String, String>{
      'en': 'Share link — {name}',
      'hi': 'लिंक साझा करें — {name}',
      'pa': 'ਲਿੰਕ ਸਾਂਝਾ ਕਰੋ — {name}',
    },
    'manage_sub_users': <String, String>{
      'en': 'Manage Sub-Users',
      'hi': 'सब-यूज़र प्रबंधन',
      'pa': 'ਸਬ-ਯੂਜ਼ਰ ਪ੍ਰਬੰਧਨ',
    },
    'add_sub_user': <String, String>{
      'en': 'Add Sub-User',
      'hi': 'सब-यूज़र जोड़ें',
      'pa': 'ਸਬ-ਯੂਜ਼ਰ ਜੋੜੋ',
    },
    'assign_vehicles': <String, String>{
      'en': 'Assign vehicles',
      'hi': 'वाहन असाइन करें',
      'pa': 'ਵਾਹਨ ਸੌਂਪੋ',
    },
    'view_general': <String, String>{
      'en': 'General (full app)',
      'hi': 'जनरल (पूरी ऐप)',
      'pa': 'ਜਨਰਲ (ਪੂਰੀ ਐਪ)',
    },
    'view_student': <String, String>{
      'en': 'Student (map only)',
      'hi': 'स्टूडेंट (सिर्फ़ नक्शा)',
      'pa': 'ਸਟੂਡੈਂਟ (ਸਿਰਫ਼ ਨਕਸ਼ਾ)',
    },
    'assign_to': <String, String>{
      'en': 'Assign to {name}',
      'hi': '{name} को असाइन करें',
      'pa': '{name} ਨੂੰ ਸੌਂਪੋ',
    },
    'no_vehicles_to_assign': <String, String>{
      'en': 'No vehicles to assign.',
      'hi': 'असाइन करने के लिए कोई वाहन नहीं।',
      'pa': 'ਸੌਂਪਣ ਲਈ ਕੋਈ ਵਾਹਨ ਨਹੀਂ।',
    },
    'password_updated': <String, String>{
      'en': 'Password updated',
      'hi': 'पासवर्ड अपडेट हो गया',
      'pa': 'ਪਾਸਵਰਡ ਅੱਪਡੇਟ ਹੋ ਗਿਆ',
    },
    'reset_password_for': <String, String>{
      'en': 'Reset password — {name}',
      'hi': 'पासवर्ड रीसेट — {name}',
      'pa': 'ਪਾਸਵਰਡ ਰੀਸੈੱਟ — {name}',
    },
    'generate_strong_password': <String, String>{
      'en': 'Generate strong password',
      'hi': 'मज़बूत पासवर्ड बनाएं',
      'pa': 'ਮਜ਼ਬੂਤ ਪਾਸਵਰਡ ਬਣਾਓ',
    },
    'assigned_to': <String, String>{
      'en': 'Assigned to {name}',
      'hi': '{name} को असाइन',
      'pa': '{name} ਨੂੰ ਸੌਂਪੇ ਹੋਏ',
    },
    'no_vehicles_assigned_yet': <String, String>{
      'en': 'No vehicles assigned yet',
      'hi': 'अभी कोई वाहन असाइन नहीं',
      'pa': 'ਹਾਲੇ ਕੋਈ ਵਾਹਨ ਨਹੀਂ ਸੌਂਪਿਆ',
    },
    'stop_alert_failed': <String, String>{
      'en': 'Stop alert: {error}',
      'hi': 'स्टॉप अलर्ट: {error}',
      'pa': 'ਸਟਾਪ ਅਲਰਟ: {error}',
    },
    'link_failed': <String, String>{
      'en': 'Could not create link: {error}',
      'hi': 'लिंक नहीं बन सका: {error}',
      'pa': 'ਲਿੰਕ ਨਹੀਂ ਬਣ ਸਕਿਆ: {error}',
    },
    'call_vehicle_q': <String, String>{
      'en': 'Call this vehicle?',
      'hi': 'इस वाहन को कॉल करें?',
      'pa': 'ਇਸ ਵਾਹਨ ਨੂੰ ਕਾਲ ਕਰੀਏ?',
    },
    'no_dialler': <String, String>{
      'en': 'No dialler available on this phone',
      'hi': 'इस फ़ोन में डायलर उपलब्ध नहीं',
      'pa': 'ਇਸ ਫ਼ੋਨ ਵਿੱਚ ਡਾਇਲਰ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'call_failed': <String, String>{
      'en': 'Could not start the call',
      'hi': 'कॉल शुरू नहीं हो सकी',
      'pa': 'ਕਾਲ ਸ਼ੁਰੂ ਨਹੀਂ ਹੋ ਸਕੀ',
    },
    'no_live_location_yet': <String, String>{
      'en': 'No live location for this vehicle yet',
      'hi': 'इस वाहन की लाइव लोकेशन अभी नहीं',
      'pa': 'ਇਸ ਵਾਹਨ ਦੀ ਲਾਈਵ ਲੋਕੇਸ਼ਨ ਹਾਲੇ ਨਹੀਂ',
    },
    'could_not_open_maps': <String, String>{
      'en': 'Could not open maps',
      'hi': 'नक्शा ऐप नहीं खुल सका',
      'pa': 'ਨਕਸ਼ਾ ਐਪ ਨਹੀਂ ਖੁੱਲ੍ਹ ਸਕੀ',
    },
    'live_map_unavailable': <String, String>{
      'en': 'Live map is not available for this vehicle',
      'hi': 'इस वाहन के लिए लाइव नक्शा उपलब्ध नहीं',
      'pa': 'ਇਸ ਵਾਹਨ ਲਈ ਲਾਈਵ ਨਕਸ਼ਾ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'push_notifications': <String, String>{
      'en': 'Push Notifications',
      'hi': 'पुश सूचनाएं',
      'pa': 'ਪੁਸ਼ ਸੂਚਨਾਵਾਂ',
    },
    'parking_guard': <String, String>{
      'en': 'Parking Guard',
      'hi': 'पार्किंग गार्ड',
      'pa': 'ਪਾਰਕਿੰਗ ਗਾਰਡ',
    },
    'night_lock': <String, String>{
      'en': 'Night Lock',
      'hi': 'नाइट लॉक',
      'pa': 'ਨਾਈਟ ਲਾਕ',
    },
    'map_link_unavailable': <String, String>{
      'en': 'Map link not available',
      'hi': 'नक्शा लिंक उपलब्ध नहीं',
      'pa': 'ਨਕਸ਼ਾ ਲਿੰਕ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'no_stop_hide_eta': <String, String>{
      'en': 'No stop (hide ETA)',
      'hi': 'कोई स्टॉप नहीं (ETA छिपाएं)',
      'pa': 'ਕੋਈ ਸਟਾਪ ਨਹੀਂ (ETA ਲੁਕਾਓ)',
    },
    'vehicle_overview': <String, String>{
      'en': 'Vehicle Overview',
      'hi': 'वाहन ओवरव्यू',
      'pa': 'ਵਾਹਨ ਓਵਰਵਿਊ',
    },
    'map_style': <String, String>{
      'en': 'Map style',
      'hi': 'नक्शे की स्टाइल',
      'pa': 'ਨਕਸ਼ੇ ਦੀ ਸਟਾਈਲ',
    },
    'send_panic_title': <String, String>{
      'en': 'Send Panic Alert',
      'hi': 'पैनिक अलर्ट भेजें',
      'pa': 'ਪੈਨਿਕ ਅਲਰਟ ਭੇਜੋ',
    },
    'panic': <String, String>{
      'en': 'Panic',
      'hi': 'पैनिक',
      'pa': 'ਪੈਨਿਕ',
    },
    'no_alerts_yet': <String, String>{
      'en': 'No alerts yet',
      'hi': 'अभी कोई अलर्ट नहीं',
      'pa': 'ਹਾਲੇ ਕੋਈ ਅਲਰਟ ਨਹੀਂ',
    },
    'no_vehicle_for_panic': <String, String>{
      'en': 'No vehicle found to trigger panic alert',
      'hi': 'पैनिक अलर्ट के लिए कोई वाहन नहीं मिला',
      'pa': 'ਪੈਨਿਕ ਅਲਰਟ ਲਈ ਕੋਈ ਵਾਹਨ ਨਹੀਂ ਮਿਲਿਆ',
    },
    'panic_note_hint': <String, String>{
      'en': 'Any emergency context to share',
      'hi': 'आपातकाल की कोई जानकारी',
      'pa': 'ਐਮਰਜੈਂਸੀ ਦੀ ਕੋਈ ਜਾਣਕਾਰੀ',
    },
    'visual_analytics': <String, String>{
      'en': 'Visual Analytics',
      'hi': 'विज़ुअल एनालिटिक्स',
      'pa': 'ਵਿਜ਼ੂਅਲ ਐਨਾਲਿਟਿਕਸ',
    },
    'detailed_report_data': <String, String>{
      'en': 'Detailed Report Data',
      'hi': 'विस्तृत रिपोर्ट डेटा',
      'pa': 'ਵਿਸਤ੍ਰਿਤ ਰਿਪੋਰਟ ਡੇਟਾ',
    },
    'no_chart_data': <String, String>{
      'en': 'No chart data available',
      'hi': 'चार्ट डेटा उपलब्ध नहीं',
      'pa': 'ਚਾਰਟ ਡੇਟਾ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'select_title': <String, String>{
      'en': 'Select {title}',
      'hi': '{title} चुनें',
      'pa': '{title} ਚੁਣੋ',
    },
    'export_unavailable': <String, String>{
      'en': 'Export is not available for this report',
      'hi': 'इस रिपोर्ट के लिए एक्सपोर्ट उपलब्ध नहीं',
      'pa': 'ਇਸ ਰਿਪੋਰਟ ਲਈ ਐਕਸਪੋਰਟ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'export_failed': <String, String>{
      'en': 'Unable to prepare export file',
      'hi': 'एक्सपोर्ट फ़ाइल तैयार नहीं हो सकी',
      'pa': 'ਐਕਸਪੋਰਟ ਫ਼ਾਇਲ ਤਿਆਰ ਨਹੀਂ ਹੋ ਸਕੀ',
    },
    'vehicle_care': <String, String>{
      'en': 'Vehicle Care',
      'hi': 'वाहन देखभाल',
      'pa': 'ਵਾਹਨ ਦੇਖਭਾਲ',
    },
    'maintenance_added': <String, String>{
      'en': 'Maintenance log added successfully',
      'hi': 'मेंटेनेंस लॉग जुड़ गया',
      'pa': 'ਮੇਂਟੇਨੈਂਸ ਲਾਗ ਜੁੜ ਗਿਆ',
    },
    'open_documents': <String, String>{
      'en': 'Open Documents',
      'hi': 'दस्तावेज़ खोलें',
      'pa': 'ਦਸਤਾਵੇਜ਼ ਖੋਲ੍ਹੋ',
    },
    'view_linked_files': <String, String>{
      'en': 'View all linked files',
      'hi': 'सभी जुड़ी फ़ाइलें देखें',
      'pa': 'ਸਾਰੀਆਂ ਜੁੜੀਆਂ ਫ਼ਾਇਲਾਂ ਵੇਖੋ',
    },
    'upload_insurance': <String, String>{
      'en': 'Upload Insurance Document',
      'hi': 'बीमा दस्तावेज़ अपलोड करें',
      'pa': 'ਬੀਮਾ ਦਸਤਾਵੇਜ਼ ਅੱਪਲੋਡ ਕਰੋ',
    },
    'upload_insurance_sub': <String, String>{
      'en': 'Add new insurance file for this vehicle',
      'hi': 'इस वाहन के लिए नई बीमा फ़ाइल जोड़ें',
      'pa': 'ਇਸ ਵਾਹਨ ਲਈ ਨਵੀਂ ਬੀਮਾ ਫ਼ਾਇਲ ਜੋੜੋ',
    },
    'select_file_first': <String, String>{
      'en': 'Please select a file to upload',
      'hi': 'पहले अपलोड के लिए फ़ाइल चुनें',
      'pa': 'ਪਹਿਲਾਂ ਅੱਪਲੋਡ ਲਈ ਫ਼ਾਇਲ ਚੁਣੋ',
    },
    'insurance_uploaded': <String, String>{
      'en': 'Insurance document uploaded',
      'hi': 'बीमा दस्तावेज़ अपलोड हो गया',
      'pa': 'ਬੀਮਾ ਦਸਤਾਵੇਜ਼ ਅੱਪਲੋਡ ਹੋ ਗਿਆ',
    },
    'no_assigned_vehicles': <String, String>{
      'en': 'No assigned vehicles found',
      'hi': 'कोई असाइन किया वाहन नहीं मिला',
      'pa': 'ਕੋਈ ਸੌਂਪਿਆ ਵਾਹਨ ਨਹੀਂ ਮਿਲਿਆ',
    },
    'no_file_for_document': <String, String>{
      'en': 'No file uploaded for this document yet',
      'hi': 'इस दस्तावेज़ की फ़ाइल अभी अपलोड नहीं',
      'pa': 'ਇਸ ਦਸਤਾਵੇਜ਼ ਦੀ ਫ਼ਾਇਲ ਹਾਲੇ ਅੱਪਲੋਡ ਨਹੀਂ',
    },
    'document_link_invalid': <String, String>{
      'en': 'Document link is invalid',
      'hi': 'दस्तावेज़ लिंक अमान्य है',
      'pa': 'ਦਸਤਾਵੇਜ਼ ਲਿੰਕ ਗ਼ਲਤ ਹੈ',
    },
    'open_document': <String, String>{
      'en': 'Open Document',
      'hi': 'दस्तावेज़ खोलें',
      'pa': 'ਦਸਤਾਵੇਜ਼ ਖੋਲ੍ਹੋ',
    },
    'no_documents': <String, String>{
      'en': 'No documents available',
      'hi': 'कोई दस्तावेज़ उपलब्ध नहीं',
      'pa': 'ਕੋਈ ਦਸਤਾਵੇਜ਼ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'no_active_sessions': <String, String>{
      'en': 'No active driver sessions',
      'hi': 'कोई सक्रिय ड्राइवर सेशन नहीं',
      'pa': 'ਕੋਈ ਚਾਲੂ ਡਰਾਇਵਰ ਸੈਸ਼ਨ ਨਹੀਂ',
    },
    'open_vehicle': <String, String>{
      'en': 'Open Vehicle',
      'hi': 'वाहन खोलें',
      'pa': 'ਵਾਹਨ ਖੋਲ੍ਹੋ',
    },
    'driving_score': <String, String>{
      'en': 'Driving Score',
      'hi': 'ड्राइविंग स्कोर',
      'pa': 'ਡਰਾਇਵਿੰਗ ਸਕੋਰ',
    },
    'no_trip_data_day': <String, String>{
      'en': 'No trip data for this day yet.',
      'hi': 'इस दिन का ट्रिप डेटा अभी नहीं।',
      'pa': 'ਇਸ ਦਿਨ ਦਾ ਟ੍ਰਿਪ ਡੇਟਾ ਹਾਲੇ ਨਹੀਂ।',
    },
    'tips': <String, String>{
      'en': 'Tips',
      'hi': 'सुझाव',
      'pa': 'ਸੁਝਾਅ',
    },
    'device_health': <String, String>{
      'en': 'Device Health',
      'hi': 'डिवाइस हेल्थ',
      'pa': 'ਡਿਵਾਈਸ ਹੈਲਥ',
    },
    'no_vehicle_live_yet': <String, String>{
      'en': 'No vehicle with a live location yet',
      'hi': 'अभी किसी वाहन की लाइव लोकेशन नहीं',
      'pa': 'ਹਾਲੇ ਕਿਸੇ ਵਾਹਨ ਦੀ ਲਾਈਵ ਲੋਕੇਸ਼ਨ ਨਹੀਂ',
    },
    'fill_all_fields': <String, String>{
      'en': 'Please fill all fields correctly',
      'hi': 'सभी फ़ील्ड सही भरें',
      'pa': 'ਸਾਰੇ ਫੀਲਡ ਸਹੀ ਭਰੋ',
    },
    'no_distance_data': <String, String>{
      'en': 'No distance data available',
      'hi': 'दूरी का डेटा उपलब्ध नहीं',
      'pa': 'ਦੂਰੀ ਦਾ ਡੇਟਾ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'where_was_it': <String, String>{
      'en': 'Where was it?',
      'hi': 'कहाँ थी?',
      'pa': 'ਕਿੱਥੇ ਸੀ?',
    },
    'open_map': <String, String>{
      'en': 'Open map',
      'hi': 'नक्शा खोलें',
      'pa': 'ਨਕਸ਼ਾ ਖੋਲ੍ਹੋ',
    },
    'biometric_disabled': <String, String>{
      'en': 'Biometric login disabled',
      'hi': 'बायोमेट्रिक लॉगिन बंद',
      'pa': 'ਬਾਇਓਮੈਟ੍ਰਿਕ ਲਾਗਇਨ ਬੰਦ',
    },
    'biometric_enabled': <String, String>{
      'en': 'Biometric login enabled',
      'hi': 'बायोमेट्रिक लॉगिन चालू',
      'pa': 'ਬਾਇਓਮੈਟ੍ਰਿਕ ਲਾਗਇਨ ਚਾਲੂ',
    },
    'biometric_unavailable': <String, String>{
      'en': 'Biometric login is not available on this device',
      'hi': 'इस डिवाइस पर बायोमेट्रिक लॉगिन उपलब्ध नहीं',
      'pa': 'ਇਸ ਡਿਵਾਈਸ ਤੇ ਬਾਇਓਮੈਟ੍ਰਿਕ ਲਾਗਇਨ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'biometric_cancelled': <String, String>{
      'en': 'Biometric verification was cancelled',
      'hi': 'बायोमेट्रिक सत्यापन रद्द हुआ',
      'pa': 'ਬਾਇਓਮੈਟ੍ਰਿਕ ਤਸਦੀਕ ਰੱਦ ਹੋਈ',
    },
    'single_date': <String, String>{
      'en': 'Single date',
      'hi': 'एक तारीख़',
      'pa': 'ਇੱਕ ਤਾਰੀਖ਼',
    },
    'date_range': <String, String>{
      'en': 'Date range',
      'hi': 'तारीख़ सीमा',
      'pa': 'ਤਾਰੀਖ਼ ਦਾਇਰਾ',
    },
    'no_vehicles_available': <String, String>{
      'en': 'No vehicles available',
      'hi': 'कोई वाहन उपलब्ध नहीं',
      'pa': 'ਕੋਈ ਵਾਹਨ ਉਪਲਬਧ ਨਹੀਂ',
    },
    'could_not_open_store': <String, String>{
      'en': 'Could not open the store',
      'hi': 'स्टोर नहीं खुल सका',
      'pa': 'ਸਟੋਰ ਨਹੀਂ ਖੁੱਲ੍ਹ ਸਕਿਆ',
    },
    'label_cost': <String, String>{
      'en': 'Cost',
      'hi': 'लागत',
      'pa': 'ਲਾਗਤ',
    },
    'label_odometer': <String, String>{
      'en': 'Odometer',
      'hi': 'ओडोमीटर',
      'pa': 'ਓਡੋਮੀਟਰ',
    },
    'label_service_type': <String, String>{
      'en': 'Service Type',
      'hi': 'सर्विस प्रकार',
      'pa': 'ਸਰਵਿਸ ਕਿਸਮ',
    },
    'label_service_date': <String, String>{
      'en': 'Service Date',
      'hi': 'सर्विस तारीख़',
      'pa': 'ਸਰਵਿਸ ਤਾਰੀਖ਼',
    },
    'label_notes_opt': <String, String>{
      'en': 'Notes (optional)',
      'hi': 'नोट्स (वैकल्पिक)',
      'pa': 'ਨੋਟਸ (ਵਿਕਲਪਿਕ)',
    },
    'label_status': <String, String>{
      'en': 'Status',
      'hi': 'स्थिति',
      'pa': 'ਸਥਿਤੀ',
    },
    'label_expiry_date': <String, String>{
      'en': 'Expiry Date',
      'hi': 'समाप्ति तारीख़',
      'pa': 'ਮਿਆਦ ਖ਼ਤਮ ਤਾਰੀਖ਼',
    },
    'label_document_number': <String, String>{
      'en': 'Document Number',
      'hi': 'दस्तावेज़ नंबर',
      'pa': 'ਦਸਤਾਵੇਜ਼ ਨੰਬਰ',
    },
    'label_issuing_authority': <String, String>{
      'en': 'Issuing Authority',
      'hi': 'जारीकर्ता',
      'pa': 'ਜਾਰੀ ਕਰਤਾ',
    },
    'label_overspeed_limit': <String, String>{
      'en': 'Overspeed Limit (km/h)',
      'hi': 'ओवरस्पीड सीमा (km/h)',
      'pa': 'ਓਵਰਸਪੀਡ ਹੱਦ (km/h)',
    },
    'label_radius_alert': <String, String>{
      'en': 'Radius Alert (meters)',
      'hi': 'रेडियस अलर्ट (मीटर)',
      'pa': 'ਰੇਡੀਅਸ ਅਲਰਟ (ਮੀਟਰ)',
    },
    'label_select_driver': <String, String>{
      'en': 'Select Driver',
      'hi': 'ड्राइवर चुनें',
      'pa': 'ਡਰਾਇਵਰ ਚੁਣੋ',
    },
    'label_new_password': <String, String>{
      'en': 'New password',
      'hi': 'नया पासवर्ड',
      'pa': 'ਨਵਾਂ ਪਾਸਵਰਡ',
    },
    'data_saver': <String, String>{
      'en': 'Data saver',
      'hi': 'डेटा सेवर',
      'pa': 'ਡਾਟਾ ਸੇਵਰ',
    },
    'data_saver_subtitle': <String, String>{
      'en': 'Refresh less often to use less mobile data',
      'hi': 'कम डेटा खर्च के लिए धीमा रिफ्रेश',
      'pa': 'ਘੱਟ ਡਾਟਾ ਵਰਤੋਂ ਲਈ ਹੌਲੀ ਰਿਫਰੈਸ਼',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    final byKey = _table[key];
    if (byKey == null) return key; // loud fallback so missing keys show up in QA
    return byKey[lang] ?? byKey['en'] ?? key;
  }

  /// t() for strings with runtime values: the table entry carries {token}
  /// placeholders and tf() fills them in AFTER translation, so word order
  /// stays natural in every language ("Remove {name}?" vs "{name} ਹਟਾਓ?").
  String tf(String key, Map<String, String> params) {
    var out = t(key);
    params.forEach((token, value) {
      out = out.replaceAll('{$token}', value);
    });
    return out;
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
