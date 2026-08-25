import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';

/// Speaks alerts out loud — "Vehicle started." — using the phone's own
/// text-to-speech. No server audio, no quota, works offline once the device
/// TTS voice is installed.
///
/// Platform truth, stated up front: Android speaks in the FOREGROUND and from
/// the FCM BACKGROUND handler (the handler's short execution window is enough
/// for one sentence). iOS only speaks while the app is open — iOS does not
/// let a background push start audio, and pretending otherwise would just be
/// a silent failure.
///
/// The sentence building is a PURE top-level function so tests can pin every
/// alert type and the registration spelling without touching a TTS engine.

/// Preference key: '1' = speak alerts, anything else = silent.
///
/// OPT-IN by owner decision: the default is OFF, so nothing changes for
/// anyone until they flip "Voice alerts" on in Profile. A phone suddenly
/// talking after an app update would surprise far more users than it delights.
const String kVoiceAlertsPrefKey = 'voice_alerts_enabled';

/// The full spoken sentence for an FCM payload, or '' for payloads that
/// should stay silent (unknown types, wallet noise, empty pushes).
///
/// SHORT by owner decision (2026-08-15): just the event — "Vehicle started."
/// No vehicle name, no spelled-out registration. The first version spoke
/// "Vehicle BUS, number P B 0 8 D S 1 1 1 7, has started" and hearing it in
/// real use was the review: too long. WHICH vehicle is on the banner the
/// phone is already showing.
/// Which language the voice should SPEAK: the in-app language choice wins
/// ('app_language' pref: en/hi/pa), and when the user left it on "system"
/// the phone's own locale decides. Pure, so the priority is pinned in tests.
String resolveVoiceLang(String? savedPref, String platformLocale) {
  const supported = <String>{'en', 'hi', 'pa'};
  final pref = (savedPref ?? '').trim().toLowerCase();
  if (supported.contains(pref)) return pref;
  final sys = platformLocale.trim().toLowerCase();
  for (final lang in supported) {
    if (sys == lang || sys.startsWith('${lang}_') || sys.startsWith('$lang-')) {
      return lang;
    }
  }
  return 'en';
}

/// The spoken sentences, per alert type, per language. The English column is
/// the original wording, byte-for-byte — the existing tests pin it. Hindi and
/// Punjabi are written in their own scripts because that is what the hi-IN /
/// pa-IN TTS voices actually read; romanised text comes out mangled.
const Map<String, Map<String, String>> _voiceTable =
    <String, Map<String, String>>{
  'stop_arrival': <String, String>{
    'en': 'Bus is arriving at {stop}.',
    'hi': 'बस {stop} पहुंच रही है।',
    'pa': 'ਬੱਸ {stop} ਪਹੁੰਚ ਰਹੀ ਹੈ।',
  },
  'stop_arrival_generic': <String, String>{
    'en': 'Bus is arriving at your stop.',
    'hi': 'बस आपके स्टॉप पहुंच रही है।',
    'pa': 'ਬੱਸ ਤੁਹਾਡੇ ਸਟਾਪ ਪਹੁੰਚ ਰਹੀ ਹੈ।',
  },
  'ignition_on': <String, String>{
    'en': 'Vehicle started.',
    'hi': 'गाड़ी चालू हुई।',
    'pa': 'ਗੱਡੀ ਚਾਲੂ ਹੋਈ।',
  },
  'ignition_off': <String, String>{
    'en': 'Vehicle stopped.',
    'hi': 'गाड़ी बंद हुई।',
    'pa': 'ਗੱਡੀ ਬੰਦ ਹੋਈ।',
  },
  'overspeed': <String, String>{
    'en': 'Overspeed alert.',
    'hi': 'स्पीड बहुत तेज़ है।',
    'pa': 'ਸਪੀਡ ਬਹੁਤ ਤੇਜ਼ ਹੈ।',
  },
  'sos': <String, String>{
    'en': 'Emergency! S O S alert.',
    'hi': 'आपातकाल! एस ओ एस अलर्ट।',
    'pa': 'ਐਮਰਜੈਂਸੀ! ਐਸ ਓ ਐਸ ਅਲਰਟ।',
  },
  'geofence_enter': <String, String>{
    'en': 'Vehicle entered the allowed area.',
    'hi': 'गाड़ी इलाके में दाखिल हुई।',
    'pa': 'ਗੱਡੀ ਇਲਾਕੇ ਵਿੱਚ ਦਾਖਲ ਹੋਈ।',
  },
  'geofence_exit': <String, String>{
    'en': 'Alert. Vehicle left the allowed area.',
    'hi': 'सावधान। गाड़ी इलाके से बाहर गई।',
    'pa': 'ਸਾਵਧਾਨ। ਗੱਡੀ ਇਲਾਕੇ ਤੋਂ ਬਾਹਰ ਗਈ।',
  },
  'power_cut': <String, String>{
    'en': 'Alert. Vehicle power cut.',
    'hi': 'सावधान। गाड़ी की पावर कट गई।',
    'pa': 'ਸਾਵਧਾਨ। ਗੱਡੀ ਦੀ ਪਾਵਰ ਕੱਟੀ ਗਈ।',
  },
  'tampering': <String, String>{
    'en': 'Alert. Possible tampering.',
    'hi': 'सावधान। छेड़छाड़ का शक है।',
    'pa': 'ਸਾਵਧਾਨ। ਛੇੜਛਾੜ ਦਾ ਸ਼ੱਕ ਹੈ।',
  },
  'low_battery': <String, String>{
    'en': 'Vehicle battery low.',
    'hi': 'गाड़ी की बैटरी कम है।',
    'pa': 'ਗੱਡੀ ਦੀ ਬੈਟਰੀ ਘੱਟ ਹੈ।',
  },
  'parking_guard': <String, String>{
    'en': 'Alert! Vehicle moving in parking guard.',
    'hi': 'सावधान! खड़ी गाड़ी हिल रही है।',
    'pa': 'ਸਾਵਧਾਨ! ਖੜ੍ਹੀ ਗੱਡੀ ਹਿੱਲ ਰਹੀ ਹੈ।',
  },
  'towing': <String, String>{
    'en': 'Alert! Vehicle may be getting towed.',
    'hi': 'सावधान! गाड़ी टो हो सकती है।',
    'pa': 'ਸਾਵਧਾਨ! ਗੱਡੀ ਟੋਅ ਹੋ ਸਕਦੀ ਹੈ।',
  },
  'speed_camera': <String, String>{
    'en': 'Speed camera ahead.',
    'hi': 'आगे स्पीड कैमरा है।',
    'pa': 'ਅੱਗੇ ਸਪੀਡ ਕੈਮਰਾ ਹੈ।',
  },
  'harsh_brake': <String, String>{
    'en': 'Harsh braking.',
    'hi': 'ज़ोरदार ब्रेक।',
    'pa': 'ਜ਼ੋਰਦਾਰ ਬ੍ਰੇਕ।',
  },
  'harsh_accel': <String, String>{
    'en': 'Harsh acceleration.',
    'hi': 'एकदम तेज़ रफ़्तार।',
    'pa': 'ਇੱਕਦਮ ਤੇਜ਼ ਰਫ਼ਤਾਰ।',
  },
  'harsh_corner': <String, String>{
    'en': 'Harsh cornering.',
    'hi': 'तेज़ मोड़।',
    'pa': 'ਤੇਜ਼ ਮੋੜ।',
  },
  'offline': <String, String>{
    'en': 'Vehicle offline.',
    'hi': 'गाड़ी ऑफलाइन है।',
    'pa': 'ਗੱਡੀ ਆਫਲਾਈਨ ਹੈ।',
  },
  'device_back_online': <String, String>{
    'en': 'Vehicle back online.',
    'hi': 'गाड़ी वापस ऑनलाइन है।',
    'pa': 'ਗੱਡੀ ਵਾਪਸ ਆਨਲਾਈਨ ਹੈ।',
  },
  'idle': <String, String>{
    'en': 'Vehicle idling.',
    'hi': 'गाड़ी खड़ी चालू है।',
    'pa': 'ਗੱਡੀ ਖੜ੍ਹੀ ਚਾਲੂ ਹੈ।',
  },
};

String _voice(String key, String lang) {
  final row = _voiceTable[key];
  if (row == null) return '';
  return row[lang] ?? row['en'] ?? '';
}

String buildSpokenSentence(Map<String, dynamic> data, {String lang = 'en'}) {
  final kind = (data['notification_kind'] ?? '').toString().trim().toLowerCase();
  final type = (data['alert_type'] ?? '').toString().trim().toLowerCase();

  // Stop arrival first — its alert_type is geofence_enter on the wire (that
  // channel exists on every fielded phone) but the SENTENCE must be its own.
  // The stop's name stays: that is the answer a parent is listening for.
  if (kind == 'stop_arrival') {
    final stop = (data['stop_name'] ?? '').toString().trim();
    return stop.isEmpty
        ? _voice('stop_arrival_generic', lang)
        : _voice('stop_arrival', lang).replaceAll('{stop}', stop);
  }

  return _voice(type, lang); // wallet / account / unknown types stay silent
}

class VoiceAnnouncer {
  VoiceAnnouncer._();
  static final VoiceAnnouncer instance = VoiceAnnouncer._();

  FlutterTts? _tts;
  String _readyLang = '';

  static const Map<String, String> _ttsLocales = <String, String>{
    'en': 'en-IN',
    'hi': 'hi-IN',
    'pa': 'pa-IN',
  };

  /// Which of en/hi/pa this phone's TTS engine can actually voice, walking
  /// the cascade pa -> hi -> en. Punjabi is the one that is genuinely absent
  /// on some engines; a Punjabi-speaking listener understands the Hindi
  /// sentence, and both beat silently failing. en is never checked - it is
  /// the floor.
  Future<String> _speakableLang(String wanted) async {
    final order = wanted == 'pa'
        ? const <String>['pa', 'hi', 'en']
        : (wanted == 'hi' ? const <String>['hi', 'en'] : const <String>['en']);
    final probe = _tts ?? FlutterTts();
    _tts = probe;
    for (final lang in order) {
      if (lang == 'en') return 'en';
      try {
        final available =
            await probe.isLanguageAvailable(_ttsLocales[lang]!);
        if (available == true) return lang;
      } catch (_) {
        // A probe that throws must not kill the voice - keep walking down.
      }
    }
    return 'en';
  }

  Future<void> _ensureReady(String lang) async {
    if (_readyLang == lang && _tts != null) return;
    final tts = _tts ?? FlutterTts();
    // The regional voices read their own scripts and Indian place names
    // naturally; en-IN is present on effectively every Indian Android.
    // Slightly slow rate: these sentences are heard once, across a room.
    try { await tts.setLanguage(_ttsLocales[lang] ?? 'en-IN'); } catch (_) {}
    try { await tts.setSpeechRate(0.45); } catch (_) {}
    try { await tts.setVolume(1.0); } catch (_) {}
    // Two alerts close together must BOTH be heard: queue the second instead
    // of cutting the first off mid-plate (Android; iOS ignores the call).
    try { await tts.setQueueMode(1); } catch (_) {}
    // speak() resolves when the sentence FINISHES, not when it starts — this
    // is what keeps the FCM background handler's isolate alive long enough
    // for the whole sentence instead of being torn down mid-word.
    try { await tts.awaitSpeakCompletion(true); } catch (_) {}
    _tts = tts;
    _readyLang = lang;
  }

  Future<bool> isEnabled() async {
    final v = await LocalStorage.readValue(kVoiceAlertsPrefKey);
    return v == '1'; // opt-in: absent/anything-else = silent
  }

  Future<void> setEnabled(bool on) async {
    await LocalStorage.setValue(kVoiceAlertsPrefKey, on ? '1' : '0');
    if (!on) {
      try { await _tts?.stop(); } catch (_) {}
    }
  }

  /// Speak the sentence for an FCM payload. Never throws: a TTS engine that
  /// is missing, busy or mid-update must not take a notification down with it
  /// — the banner and sound have already been shown by the caller.
  Future<void> announce(Map<String, dynamic> data) async {
    try {
      if (!await isEnabled()) return;
      // The app's language choice decides the voice; on "system" the phone's
      // own locale does. Read here (not cached) because this also runs in the
      // FCM background isolate, where no cubit exists.
      final pref = await LocalStorage.readValue(PreferencesKey.language);
      String platformLocale = '';
      try { platformLocale = Platform.localeName; } catch (_) {}
      final wanted = resolveVoiceLang(pref, platformLocale);
      // Sentence language must MATCH the voice language: Punjabi text through
      // a Hindi voice comes out mangled, so when the engine lacks the wanted
      // voice both fall back together.
      final lang = await _speakableLang(wanted);
      final sentence = buildSpokenSentence(data, lang: lang);
      if (sentence.isEmpty) return;
      await _ensureReady(lang);
      await _tts?.speak(sentence);
    } catch (_) {
      // voice is best-effort, always
    }
  }
}
