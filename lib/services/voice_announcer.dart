import 'package:flutter_tts/flutter_tts.dart';
import 'package:fleet_monitor/constant/preferences.dart';

/// Speaks alerts out loud — "Vehicle P B 0 8, D S 1 1 1 7 has started" —
/// using the phone's own text-to-speech. No server audio, no quota, works
/// offline once the device TTS voice is installed.
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

/// A registration number the way a HUMAN says it, not the way a TTS engine
/// mangles it. "PB08DS1117-R2" read as a word is garbage; spelled character
/// by character with spacing — "P B 0 8 D S 1 1 1 7" — every engine gets it
/// right. The "-R2" fleet suffix is an internal label, not part of the
/// number plate, so it is dropped.
String spellRegistration(String registration) {
  var plate = registration.trim().toUpperCase();
  final suffix = plate.indexOf('-');
  if (suffix > 0) plate = plate.substring(0, suffix);
  final out = <String>[];
  for (final ch in plate.split('')) {
    if (RegExp(r'[A-Z0-9]').hasMatch(ch)) out.add(ch);
  }
  return out.join(' ');
}

/// The vehicle part of the sentence. vehicle_label from the server is
/// "BUS (PB08EH5298-R16)" — name plus registration; speak the name and spell
/// the plate. Falls back through name-only and plain "Vehicle".
String _spokenVehicle(Map<String, dynamic> data) {
  final label = (data['vehicle_label'] ?? '').toString();
  final name = (data['vehicle_name'] ?? '').toString().trim();

  final regMatch = RegExp(r'\(([^)]+)\)').firstMatch(label);
  final plate = regMatch != null ? spellRegistration(regMatch.group(1)!) : '';

  if (name.isNotEmpty && plate.isNotEmpty) return 'Vehicle $name, number $plate,';
  if (plate.isNotEmpty) return 'Vehicle number $plate';
  if (name.isNotEmpty) return 'Vehicle $name';
  return 'Vehicle';
}

/// The full spoken sentence for an FCM payload, or '' for payloads that
/// should stay silent (unknown types, wallet noise, empty pushes).
String buildSpokenSentence(Map<String, dynamic> data) {
  final kind = (data['notification_kind'] ?? '').toString().trim().toLowerCase();
  final type = (data['alert_type'] ?? '').toString().trim().toLowerCase();
  final vehicle = _spokenVehicle(data);

  // Stop arrival first — its alert_type is geofence_enter on the wire (that
  // channel exists on every fielded phone) but the SENTENCE must be its own.
  if (kind == 'stop_arrival') {
    final stop = (data['stop_name'] ?? '').toString().trim();
    return stop.isEmpty
        ? '$vehicle is arriving at your stop.'
        : '$vehicle is arriving at $stop.';
  }

  switch (type) {
    case 'ignition_on':
      return '$vehicle has started.';
    case 'ignition_off':
      return '$vehicle has stopped.';
    case 'overspeed':
      return 'Overspeed alert. $vehicle is driving too fast.';
    case 'sos':
      return 'Emergency! S O S alert from $vehicle.';
    case 'geofence_enter':
      return '$vehicle has entered the allowed area.';
    case 'geofence_exit':
      return 'Alert. $vehicle has left the allowed area.';
    case 'power_cut':
      return 'Alert. Power has been cut on $vehicle.';
    case 'tampering':
      return 'Alert. Possible tampering with $vehicle.';
    case 'low_battery':
      return '$vehicle battery is low.';
    // Safety types a listener should not have to read a banner for: a guarded
    // car that moved, a tow, a device going dark. Same tbl_alerts enum names
    // the server sends (normalizeAlertType).
    case 'parking_guard':
      return 'Alert! $vehicle is moving while parking guard is on.';
    case 'towing':
      return 'Alert! $vehicle may be getting towed.';
    case 'speed_camera':
      return '$vehicle, speed camera ahead.';
    case 'harsh_brake':
      return '$vehicle braked harshly.';
    case 'harsh_accel':
      return '$vehicle accelerated harshly.';
    case 'harsh_corner':
      return '$vehicle took a corner too fast.';
    case 'offline':
      return '$vehicle has gone offline.';
    case 'device_back_online':
      return '$vehicle is back online.';
    case 'idle':
      return '$vehicle is idling with the engine on.';
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
