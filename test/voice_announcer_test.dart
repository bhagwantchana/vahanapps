import 'package:fleet_monitor/services/voice_announcer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sentences a parent/driver HEARS. The TTS engine itself can't run in a
/// test, but every sentence is built by a pure function, so what gets spoken
/// is pinned here. SHORT by owner decision (2026-08-15): just the event —
/// no vehicle name, no spelled-out registration. WHICH vehicle is on the
/// banner the phone is already showing.
void main() {
  group('voice is OPT-IN — owner decision', () {
    // A fresh install / update must behave exactly like the old app: silent.
    // Speaking only starts for the user who flipped the Profile toggle.
    TestWidgetsFlutterBinding.ensureInitialized();

    test('fresh install is silent', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      expect(await VoiceAnnouncer.instance.isEnabled(), isFalse);
    });

    test('only an explicit "1" enables it', () async {
      SharedPreferences.setMockInitialValues(
          const <String, Object>{'voice_alerts_enabled': '1'});
      expect(await VoiceAnnouncer.instance.isEnabled(), isTrue);
    });

    test('junk values stay silent', () async {
      SharedPreferences.setMockInitialValues(
          const <String, Object>{'voice_alerts_enabled': 'yes'});
      expect(await VoiceAnnouncer.instance.isEnabled(), isFalse);
    });
  });

  group('the sentences match the events — and stay SHORT', () {
    Map<String, dynamic> data(String type, {String? kind, String? stop}) =>
        <String, dynamic>{
          'alert_type': type,
          if (kind != null) 'notification_kind': kind,
          if (stop != null) 'stop_name': stop,
          'vehicle_label': 'BUS (PB08DS1117-R2)',
          'vehicle_name': 'BUS',
        };

    test('started / stopped — the exact ask, nothing more', () {
      expect(buildSpokenSentence(data('ignition_on')), 'Vehicle started.');
      expect(buildSpokenSentence(data('ignition_off')), 'Vehicle stopped.');
    });

    test('the name and plate are NEVER spoken, even when the payload has them',
        () {
      for (final t in ['ignition_on', 'overspeed', 'sos', 'power_cut']) {
        final s = buildSpokenSentence(data(t));
        expect(s, isNot(contains('BUS')), reason: '$t spoke the name');
        expect(s, isNot(contains('P B 0 8')), reason: '$t spelled the plate');
      }
    });

    test('stop arrival beats its wire alert_type and keeps the STOP name', () {
      // On the wire stop alerts ride geofence_enter (that channel exists on
      // every fielded phone) — the SENTENCE must still be about the stop,
      // and the stop's name is the answer the parent is listening for.
      final s = buildSpokenSentence(
          data('geofence_enter', kind: 'stop_arrival', stop: 'Phagwara Road'));
      expect(s, 'Bus is arriving at Phagwara Road.');
    });

    test('sos is unmistakably an emergency', () {
      expect(buildSpokenSentence(data('sos')), startsWith('Emergency!'));
    });

    test('wallet/account noise stays SILENT', () {
      for (final t in ['wallet_credit', 'recharge_request', 'account_created', '']) {
        expect(buildSpokenSentence(data(t)), '',
            reason: '$t must not be spoken aloud');
      }
    });

    test('every safety type in the alerts enum has a voice', () {
      // A listener should never have to read the banner for these. The list
      // mirrors tbl_alerts' vehicle-safety values; wallet/account noise is
      // pinned silent above.
      for (final t in [
        'parking_guard', 'towing', 'speed_camera',
        'harsh_brake', 'harsh_accel', 'harsh_corner',
        'offline', 'device_back_online', 'idle',
      ]) {
        expect(buildSpokenSentence(data(t)), isNotEmpty,
            reason: '$t must be spoken');
      }
    });

    test('parking guard and towing are urgent', () {
      expect(buildSpokenSentence(data('parking_guard')), startsWith('Alert!'));
      expect(buildSpokenSentence(data('towing')), startsWith('Alert!'));
    });
  });

  group('the voice speaks the app language', () {
    Map<String, dynamic> data(String type, {String? kind, String? stop}) =>
        <String, dynamic>{
          'alert_type': type,
          if (kind != null) 'notification_kind': kind,
          if (stop != null) 'stop_name': stop,
        };

    test('the in-app choice wins over the phone locale', () {
      expect(resolveVoiceLang('pa', 'en_US'), 'pa');
      expect(resolveVoiceLang('hi', 'pa_IN'), 'hi');
      expect(resolveVoiceLang('en', 'hi_IN'), 'en');
    });

    test('"system" (no pref) follows the phone', () {
      expect(resolveVoiceLang(null, 'pa_IN'), 'pa');
      expect(resolveVoiceLang('', 'hi_IN'), 'hi');
      expect(resolveVoiceLang(null, 'en_IN'), 'en');
      expect(resolveVoiceLang(null, 'fr_FR'), 'en');
      expect(resolveVoiceLang('junk', 'de_DE'), 'en');
    });

    test('start/stop in Punjabi and Hindi — the exact ask', () {
      expect(buildSpokenSentence(data('ignition_on'), lang: 'pa'),
          'ਗੱਡੀ ਚਾਲੂ ਹੋਈ।');
      expect(buildSpokenSentence(data('ignition_off'), lang: 'pa'),
          'ਗੱਡੀ ਬੰਦ ਹੋਈ।');
      expect(buildSpokenSentence(data('ignition_on'), lang: 'hi'),
          'गाड़ी चालू हुई।');
      expect(buildSpokenSentence(data('ignition_off'), lang: 'hi'),
          'गाड़ी बंद हुई।');
    });

    test('stop arrival keeps the stop name in every language', () {
      final pa = buildSpokenSentence(
          data('geofence_enter', kind: 'stop_arrival', stop: 'Model Town'),
          lang: 'pa');
      expect(pa, contains('Model Town'));
      expect(pa, contains('ਬੱਸ'));
      final hi = buildSpokenSentence(
          data('geofence_enter', kind: 'stop_arrival', stop: 'Model Town'),
          lang: 'hi');
      expect(hi, contains('Model Town'));
      expect(hi, contains('बस'));
    });

    test('every safety type has a sentence in all three languages', () {
      const types = <String>[
        'ignition_on', 'ignition_off', 'overspeed', 'sos', 'geofence_enter',
        'geofence_exit', 'power_cut', 'tampering', 'low_battery',
        'parking_guard', 'towing', 'speed_camera', 'harsh_brake',
        'harsh_accel', 'harsh_corner', 'offline', 'device_back_online',
        'idle',
      ];
      for (final t in types) {
        for (final lang in <String>['en', 'hi', 'pa']) {
          expect(buildSpokenSentence(data(t), lang: lang), isNotEmpty,
              reason: '$t has no $lang voice');
        }
      }
    });

    test('wallet noise stays silent in every language', () {
      for (final lang in <String>['en', 'hi', 'pa']) {
        expect(buildSpokenSentence(data('wallet_credit'), lang: lang), '');
      }
    });

    test('an unknown language falls back to English, never to silence', () {
      expect(buildSpokenSentence(data('ignition_on'), lang: 'ta'),
          'Vehicle started.');
    });
  });
}
