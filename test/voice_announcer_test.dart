import 'package:fleet_monitor/services/voice_announcer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sentences a parent/driver HEARS. The TTS engine itself can't run in a
/// test, but every sentence is built by a pure function, so what gets spoken
/// is pinned here — including the part that motivated the feature: the
/// vehicle NUMBER, spelled so any TTS engine reads it correctly.
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

  group('registration is spelled, not mangled', () {
    test('a real fleet plate', () {
      // "PB08DS1117" read as one word is garbage; spelled it is unambiguous.
      expect(spellRegistration('PB08DS1117-R2'), 'P B 0 8 D S 1 1 1 7');
    });

    test('fleet -R suffix is dropped (not part of the number plate)', () {
      expect(spellRegistration('PB08EH5298-R16'), 'P B 0 8 E H 5 2 9 8');
    });

    test('lowercase and stray spaces survive', () {
      expect(spellRegistration(' pb08cx4088 '), 'P B 0 8 C X 4 0 8 8');
    });
  });

  group('the sentences match the events', () {
    Map<String, dynamic> data(String type, {String? kind, String? stop}) =>
        <String, dynamic>{
          'alert_type': type,
          if (kind != null) 'notification_kind': kind,
          if (stop != null) 'stop_name': stop,
          'vehicle_label': 'BUS (PB08DS1117-R2)',
          'vehicle_name': 'BUS',
        };

    test('started / stopped — the exact ask', () {
      expect(buildSpokenSentence(data('ignition_on')),
          'Vehicle BUS, number P B 0 8 D S 1 1 1 7, has started.');
      expect(buildSpokenSentence(data('ignition_off')),
          'Vehicle BUS, number P B 0 8 D S 1 1 1 7, has stopped.');
    });

    test('overspeed says so before the number', () {
      final s = buildSpokenSentence(data('overspeed'));
      expect(s, startsWith('Overspeed alert.'));
      expect(s, contains('P B 0 8 D S 1 1 1 7'));
    });

    test('stop arrival beats its wire alert_type', () {
      // On the wire stop alerts ride geofence_enter (that channel exists on
      // every fielded phone) — the SENTENCE must still be about the stop.
      final s = buildSpokenSentence(
          data('geofence_enter', kind: 'stop_arrival', stop: 'Phagwara Road'));
      expect(s, contains('is arriving at Phagwara Road'));
      expect(s, isNot(contains('allowed area')));
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
        final s = buildSpokenSentence(data(t));
        expect(s, isNotEmpty, reason: '$t must be spoken');
        expect(s, contains('BUS'), reason: '$t must name the vehicle');
      }
    });

    test('parking guard and towing are urgent', () {
      expect(buildSpokenSentence(data('parking_guard')), startsWith('Alert!'));
      expect(buildSpokenSentence(data('towing')), startsWith('Alert!'));
    });

    test('a payload with no vehicle info still reads sensibly', () {
      expect(
        buildSpokenSentence(<String, dynamic>{'alert_type': 'ignition_on'}),
        'Vehicle has started.',
      );
    });
  });
}
