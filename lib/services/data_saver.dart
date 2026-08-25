import 'package:fleet_monitor/constant/preferences.dart';

/// Data-saver mode: one switch in Profile that slows every foreground poll
/// to a third of its normal cadence.
///
/// The app's periodic refreshes are cheap individually and expensive in
/// aggregate: the home map poll alone is ~900 requests an hour on its 4 s
/// cadence. On an unlimited plan nobody notices; on the prepaid data packs
/// most parents actually use, a morning of watching the bus adds up. The
/// SSE stream is untouched — it is push, the server only sends when
/// something happened, so it is already the cheapest source of truth the
/// app has. Slowing the polls leans harder on it.
///
/// The mode is a plain in-memory flag backed by LocalStorage. It is read
/// synchronously at every timer (re)start — screen opens, app resumes — so
/// flipping the switch takes effect the next time any screen starts its
/// timer, with no restart and no plumbing through constructors.
class DataSaver {
  DataSaver._();

  static const String _storageKey = 'data_saver_on';
  static bool _on = false;

  static bool get isOn => _on;

  /// Load the persisted preference. Called once at app boot, before the
  /// first screen constructs its refresh timers.
  static Future<void> load() async {
    _on = (await LocalStorage.readValue(_storageKey)) == '1';
  }

  static Future<void> set(bool value) async {
    _on = value;
    await LocalStorage.setValue(_storageKey, value ? '1' : '0');
  }

  /// The poll interval a screen should actually use right now.
  static Duration scale(Duration base) => _on ? base * 3 : base;
}
