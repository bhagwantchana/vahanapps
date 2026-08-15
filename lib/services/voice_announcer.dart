import 'package:flutter_tts/flutter_tts.dart';
import 'package:fleet_monitor/constant/preferences.dart';

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
String buildSpokenSentence(Map<String, dynamic> data) {
  final kind = (data['notification_kind'] ?? '').toString().trim().toLowerCase();
  final type = (data['alert_type'] ?? '').toString().trim().toLowerCase();

  // Stop arrival first — its alert_type is geofence_enter on the wire (that
  // channel exists on every fielded phone) but the SENTENCE must be its own.
  // The stop's name stays: that is the answer a parent is listening for.
  if (kind == 'stop_arrival') {
    final stop = (data['stop_name'] ?? '').toString().trim();
    return stop.isEmpty
        ? 'Bus is arriving at your stop.'
        : 'Bus is arriving at $stop.';
  }

  switch (type) {
    case 'ignition_on':
      return 'Vehicle started.';
    case 'ignition_off':
      return 'Vehicle stopped.';
    case 'overspeed':
      return 'Overspeed alert.';
    case 'sos':
      return 'Emergency! S O S alert.';
    case 'geofence_enter':
      return 'Vehicle entered the allowed area.';
    case 'geofence_exit':
      return 'Alert. Vehicle left the allowed area.';
    case 'power_cut':
      return 'Alert. Vehicle power cut.';
    case 'tampering':
      return 'Alert. Possible tampering.';
    case 'low_battery':
      return 'Vehicle battery low.';
    // Safety types a listener should not have to read a banner for: a guarded
    // car that moved, a tow, a device going dark. Same tbl_alerts enum names
    // the server sends (normalizeAlertType).
    case 'parking_guard':
      return 'Alert! Vehicle moving in parking guard.';
    case 'towing':
      return 'Alert! Vehicle may be getting towed.';
    case 'speed_camera':
      return 'Speed camera ahead.';
    case 'harsh_brake':
      return 'Harsh braking.';
    case 'harsh_accel':
      return 'Harsh acceleration.';
    case 'harsh_corner':
      return 'Harsh cornering.';
    case 'offline':
      return 'Vehicle offline.';
    case 'device_back_online':
      return 'Vehicle back online.';
    case 'idle':
      return 'Vehicle idling.';
    default:
      return ''; // wallet / account / unknown types stay silent
  }
}

class VoiceAnnouncer {
  VoiceAnnouncer._();
  static final VoiceAnnouncer instance = VoiceAnnouncer._();

  FlutterTts? _tts;
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    final tts = FlutterTts();
    // en-IN reads Indian registrations and place names most naturally and is
    // present on effectively every Indian Android. Slightly slow rate: these
    // sentences carry a spelled-out number the listener needs to catch.
    try { await tts.setLanguage('en-IN'); } catch (_) {}
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
    _ready = true;
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
      final sentence = buildSpokenSentence(data);
      if (sentence.isEmpty) return;
      await _ensureReady();
      await _tts?.speak(sentence);
    } catch (_) {
      // voice is best-effort, always
    }
  }
}
