import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';

/// "Trip Live" — one pinned card in the notification bar for a bus that is
/// on the road: it appears when the trip starts, quietly rewrites itself as
/// the pushes come in (stop ETA, overspeed), and turns into a dismissible
/// summary when the trip ends. The Ola/Maps trick, done the cheap way.
///
/// EVENT-DRIVEN by design: the card updates when a push arrives — trip
/// start, stop alerts, trip end — never on a timer. A per-second card needs
/// a foreground service and a stream of pushes, which costs battery and
/// data; for a school run the events ARE the story. The one live element is
/// free: Android's chronometer ticks the elapsed time on its own.
///
/// Additive by construction:
///  - OPT-IN, default OFF (same rule as voice: an update must change
///    nothing for anyone who didn't ask).
///  - LOCAL notification on its own LOCAL channel — the server never
///    addresses it, so the cross-module channel contract is untouched.
///  - Android-only; iOS has no ongoing notifications, so it no-ops there.
///  - Fixed high notification ids (880000 + vehicle), far from the
///    hashCode ids the normal alert banners use.
class TripLiveCard {
  TripLiveCard._();
  static final TripLiveCard instance = TripLiveCard._();

  static const String prefKey = 'trip_live_card_enabled';
  static const String _channelId = 'trip_live_local_v1';
  static const int _idBase = 880000;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  Future<bool> isEnabled() async {
    final v = await LocalStorage.readValue(prefKey);
    return v == '1';
  }

  Future<void> setEnabled(bool on) async {
    await LocalStorage.setValue(prefKey, on ? '1' : '0');
    if (!on) {
      // Leave nothing pinned behind a switch the user just turned off —
      // but cancel ONLY this card's ids. cancelAll() would take the normal
      // alert banners down with it.
      final ids = await _activeVids();
      for (final vid in ids) {
        try {
          await _plugin.cancel(id: _idBase + (vid % 1000));
        } catch (_) {}
        await LocalStorage.clearValue('trip_live_start_$vid');
      }
      await LocalStorage.clearValue(_activeKey);
    }
  }

  static const String _activeKey = 'trip_live_active_vids';

  Future<List<int>> _activeVids() async {
    final raw = await LocalStorage.readValue(_activeKey) ?? '';
    return <int>[
      for (final part in raw.split(','))
        if (int.tryParse(part) != null) int.parse(part),
    ];
  }

  Future<void> _rememberVid(int vid) async {
    final ids = await _activeVids();
    if (!ids.contains(vid)) {
      ids.add(vid);
      await LocalStorage.setValue(_activeKey, ids.join(','));
    }
  }

  Future<void> _forgetVid(int vid) async {
    final ids = await _activeVids()
      ..remove(vid);
    await LocalStorage.setValue(_activeKey, ids.join(','));
  }

  /// One light snapshot at push time: current speed from /vehicleTrack and
  /// the address from /geocodeAddress (server-cached). Two short calls per
  /// EVENT for an opt-in card - not a poll, not a stream. Any failure just
  /// means the card shows its event line without the extras.
  Future<({int? speedKmh, String address})> _fetchLive(
      int vid, String imei) async {
    try {
      final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';
      if (token.isEmpty) return (speedKmh: null, address: '');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        headers: <String, String>{'X-Auth-Token': token},
      ));
      final track = await dio.post(
        AppUrl.vehicleTrack,
        data: FormData.fromMap(<String, dynamic>{
          'vehicle_id': vid.toString(),
          'imei': imei,
        }),
      );
      final body = track.data is Map
          ? track.data as Map
          : jsonDecode(track.data.toString()) as Map;
      if ((body['flag'] ?? 0) != 1) return (speedKmh: null, address: '');
      final rec = (body['data'] as Map?) ?? const {};
      final speed =
          double.tryParse((rec['speed'] ?? '').toString())?.round();
      final lat = double.tryParse((rec['latitude'] ?? '').toString());
      final lng = double.tryParse((rec['longitude'] ?? '').toString());
      var address = '';
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        try {
          final geo = await dio.post(
            AppUrl.geocodeAddress,
            data: FormData.fromMap(<String, dynamic>{
              'lat': lat.toString(),
              'lng': lng.toString(),
            }),
          );
          final gbody = geo.data is Map
              ? geo.data as Map
              : jsonDecode(geo.data.toString()) as Map;
          if ((gbody['flag'] ?? 0) == 1) {
            address =
                ((gbody['data'] as Map?)?['address'] ?? '').toString().trim();
          }
        } catch (_) {}
      }
      return (speedKmh: speed, address: address);
    } catch (_) {
      return (speedKmh: null, address: '');
    }
  }

  /// Tap payload: routes straight to the vehicle's own screen. Without it
  /// the tap fell through the deep-link handler's default and landed on the
  /// Alerts tab - the owner's exact complaint.
  String _tapPayload(int vid, String imei) => jsonEncode(<String, String>{
        'notification_kind': 'trip_live',
        'vehicle_id': '$vid',
        'imei': imei,
      });

  Future<void> _ensureChannel() async {
    if (_channelReady || !Platform.isAndroid) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Trip Live',
            description: 'Pinned live-trip status card',
            importance: Importance.low, // silent: the alert banner already rang
            playSound: false,
            enableVibration: false,
          ));
      _channelReady = true;
    } catch (_) {}
  }

  /// Feed every FCM payload through here (both foreground and background
  /// handlers do). Decides whether the card appears, rewrites or resolves.
  /// Never throws — the banner and voice must never depend on this card.
  Future<void> onPush(Map<String, dynamic> data) async {
    try {
      if (!Platform.isAndroid) return;
      if (!await isEnabled()) return;

      final kind =
          (data['notification_kind'] ?? '').toString().trim().toLowerCase();
      final type = (data['alert_type'] ?? '').toString().trim().toLowerCase();
      final vid = int.tryParse((data['vehicle_id'] ?? '').toString()) ?? 0;
      if (vid <= 0) return;

      final lang = await _lang();
      final label = _label(data);
      var imei = (data['imei'] ?? '').toString().trim();
      if (imei.isNotEmpty) {
        await LocalStorage.setValue('trip_live_imei_$vid', imei);
      } else {
        imei = await LocalStorage.readValue('trip_live_imei_$vid') ?? '';
      }

      // The alert push often carries the address it resolved server-side;
      // keep it as the fallback for when the live fetch cannot run (no
      // network in the background isolate, token missing).
      final pushAddress = (data['address'] ?? '').toString().trim();

      if (type == 'ignition_on') {
        final startMs = DateTime.now().millisecondsSinceEpoch;
        await LocalStorage.setValue('trip_live_start_$vid', '$startMs');
        await _rememberVid(vid);
        await _showOngoing(vid, imei, label, tripLiveText('running', lang),
            startMs, fallbackAddress: pushAddress);
        return;
      }

      if (kind == 'stop_arrival') {
        final stop = (data['stop_name'] ?? '').toString().trim();
        final eta = int.tryParse((data['eta_min'] ?? '').toString()) ?? 0;
        final line = eta > 0
            ? tripLiveText('near_stop_min', lang)
                .replaceAll('{stop}', stop)
                .replaceAll('{min}', '$eta')
            : tripLiveText('near_stop', lang).replaceAll('{stop}', stop);
        await _updateIfRunning(vid, imei, label, line);
        return;
      }

      if (type == 'overspeed') {
        await _updateIfRunning(
            vid, imei, label, tripLiveText('overspeed', lang));
        return;
      }

      if (type == 'ignition_off' || type == 'offline') {
        final hadTrip =
            (await LocalStorage.readValue('trip_live_start_$vid')) != null;
        await LocalStorage.clearValue('trip_live_start_$vid');
        await _forgetVid(vid);
        if (!hadTrip) return;
        await _showSummary(
            vid,
            imei,
            label,
            type == 'offline'
                ? tripLiveText('connection_lost', lang)
                : tripLiveText('ended', lang));
      }
    } catch (_) {
      // best-effort, always
    }
  }

  Future<void> _updateIfRunning(
      int vid, String imei, String label, String line) async {
    final saved = await LocalStorage.readValue('trip_live_start_$vid');
    final startMs = int.tryParse(saved ?? '');
    if (startMs == null) return; // no live card to rewrite
    await _showOngoing(vid, imei, label, line, startMs);
  }

  Future<void> _showOngoing(
      int vid, String imei, String label, String line, int startMs,
      {String fallbackAddress = ''}) async {
    await _ensureChannel();

    // The professional half of the card: where the vehicle IS right now and
    // how fast it is going, fetched at the moment of the event.
    var title = label;
    var body = line;
    var expanded = line;
    var address = fallbackAddress;
    if (imei.isNotEmpty) {
      final live = await _fetchLive(vid, imei);
      if (live.speedKmh != null) {
        title = '$label · ${live.speedKmh} km/h';
      }
      if (live.address.isNotEmpty) {
        address = live.address;
      }
    }
    if (address.isNotEmpty) {
      body = address;
      expanded = '$line\n📍 $address';
    }

    await _plugin.show(
      id: _idBase + (vid % 1000),
      title: title,
      body: body,
      payload: _tapPayload(vid, imei),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Trip Live',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          // The one truly live element, and it is free: the system ticks
          // the elapsed trip time with no updates from us at all.
          when: startMs,
          usesChronometer: true,
          showWhen: true,
          category: AndroidNotificationCategory.transport,
          // The alive feel: a softly animating bar while the trip runs.
          showProgress: true,
          indeterminate: true,
          styleInformation: BigTextStyleInformation(
            expanded,
            contentTitle: title,
          ),
        ),
      ),
    );
  }

  Future<void> _showSummary(
      int vid, String imei, String label, String line) async {
    await _ensureChannel();

    // The summary answers "where did it stop?" - one last snapshot.
    var body = line;
    if (imei.isNotEmpty) {
      final live = await _fetchLive(vid, imei);
      if (live.address.isNotEmpty) {
        body = '$line · ${live.address}';
      }
    }

    await _plugin.show(
      id: _idBase + (vid % 1000),
      title: label,
      body: body,
      payload: _tapPayload(vid, imei),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Trip Live',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: false, // the trip is over; let the user swipe it away
          autoCancel: true,
          playSound: false,
          enableVibration: false,
          styleInformation: BigTextStyleInformation(body, contentTitle: label),
        ),
      ),
    );
  }

  Future<String> _lang() async {
    final pref = await LocalStorage.readValue(PreferencesKey.language);
    const supported = <String>{'en', 'hi', 'pa'};
    if (pref != null && supported.contains(pref)) return pref;
    try {
      final sys = Platform.localeName.toLowerCase();
      for (final l in supported) {
        if (sys == l || sys.startsWith('${l}_') || sys.startsWith('$l-')) {
          return l;
        }
      }
    } catch (_) {}
    return 'en';
  }

  String _label(Map<String, dynamic> data) {
    final label = (data['vehicle_label'] ?? '').toString().trim();
    if (label.isNotEmpty) return label;
    final name = (data['vehicle_name'] ?? '').toString().trim();
    return name.isNotEmpty ? name : 'Bus';
  }
}

/// The card's lines, per language — a pure top-level function so tests pin
/// every one without touching the notification plugin (same pattern as the
/// voice announcer's sentences).
String tripLiveText(String key, String lang) {
  const table = <String, Map<String, String>>{
    'running': <String, String>{
      'en': 'Trip is running',
      'hi': 'सफ़र जारी है',
      'pa': 'ਸਫ਼ਰ ਜਾਰੀ ਹੈ',
    },
    'near_stop_min': <String, String>{
      'en': '~{min} min from {stop}',
      'hi': '{stop} से ~{min} मिनट दूर',
      'pa': '{stop} ਤੋਂ ~{min} ਮਿੰਟ ਦੂਰ',
    },
    'near_stop': <String, String>{
      'en': 'Near {stop}',
      'hi': '{stop} के पास',
      'pa': '{stop} ਦੇ ਨੇੜੇ',
    },
    'overspeed': <String, String>{
      'en': 'Overspeed!',
      'hi': 'स्पीड बहुत तेज़!',
      'pa': 'ਸਪੀਡ ਬਹੁਤ ਤੇਜ਼!',
    },
    'ended': <String, String>{
      'en': 'Trip ended',
      'hi': 'सफ़र पूरा हुआ',
      'pa': 'ਸਫ਼ਰ ਪੂਰਾ ਹੋਇਆ',
    },
    'connection_lost': <String, String>{
      'en': 'Connection lost',
      'hi': 'कनेक्शन टूट गया',
      'pa': 'ਕਨੈਕਸ਼ਨ ਟੁੱਟ ਗਿਆ',
    },
  };
  final row = table[key];
  if (row == null) return '';
  return row[lang] ?? row['en'] ?? '';
}
