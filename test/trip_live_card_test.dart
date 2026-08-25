import 'package:fleet_monitor/services/trip_live_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Trip Live card's lines and its opt-in gate. The notification plugin
/// itself can't run in a test; the text table is a pure function (same
/// pattern as the voice announcer) and the gate is SharedPreferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip Live is OPT-IN — same rule as voice', () {
    test('fresh install: off', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      expect(await TripLiveCard.instance.isEnabled(), isFalse);
    });

    test('only an explicit "1" enables it', () async {
      SharedPreferences.setMockInitialValues(
          const <String, Object>{'trip_live_card_enabled': '1'});
      expect(await TripLiveCard.instance.isEnabled(), isTrue);
    });
  });

  group('the card lines, per language', () {
    test('running / ended in all three languages', () {
      expect(tripLiveText('running', 'en'), 'Trip is running');
      expect(tripLiveText('running', 'pa'), 'ਸਫ਼ਰ ਜਾਰੀ ਹੈ');
      expect(tripLiveText('running', 'hi'), 'सफ़र जारी है');
      expect(tripLiveText('ended', 'pa'), 'ਸਫ਼ਰ ਪੂਰਾ ਹੋਇਆ');
    });

    test('stop line carries name and minutes', () {
      final line = tripLiveText('near_stop_min', 'pa')
          .replaceAll('{stop}', 'Model Town')
          .replaceAll('{min}', '3');
      expect(line, contains('Model Town'));
      expect(line, contains('3'));
    });

    test('every key exists in every language — no silent English leaks', () {
      const keys = <String>[
        'running', 'near_stop_min', 'near_stop', 'overspeed', 'ended',
        'connection_lost',
      ];
      for (final k in keys) {
        for (final lang in <String>['en', 'hi', 'pa']) {
          expect(tripLiveText(k, lang), isNotEmpty, reason: '$k/$lang');
        }
      }
    });

    test('unknown key stays silent, unknown language falls back to English',
        () {
      expect(tripLiveText('nonsense', 'en'), '');
      expect(tripLiveText('running', 'ta'), 'Trip is running');
    });
  });
}
