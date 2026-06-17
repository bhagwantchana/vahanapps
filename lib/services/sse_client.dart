import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fleet_monitor/constant/api.dart';
import 'package:flutter/foundation.dart';

/// One parsed Server-Sent Event. We split off the SSE protocol so the rest
/// of the app sees a normal Stream of typed events.
class SseEvent {
  const SseEvent({required this.event, required this.data});
  final String event;
  final Map<String, dynamic> data;
}

/// Minimal Server-Sent Events client built on dart:io HttpClient — no
/// third-party dependency. Connects to the tracking server's
/// `/live/stream?user_id=N` endpoint and yields decoded `vehicle` events
/// so the UI can update markers in real-time instead of polling.
///
/// Reconnects automatically with exponential backoff (capped at 30 s) when
/// the connection drops — keeps the live map "warm" through network
/// changes, signal loss, server restarts.
class SseClient {
  SseClient({required this.userId});

  final int userId;

  final _controller = StreamController<SseEvent>.broadcast();
  StreamSubscription<List<int>>? _subscription;
  HttpClient? _client;
  bool _stopped = false;
  // Guards against a reconnect storm: onError, onDone, the catch and the
  // non-200 path can all fire for one drop (cancelOnError + onDone), each
  // scheduling its own delayed connect() → multiple live HttpClients for the
  // same user. Only ever allow one pending reconnect.
  bool _reconnectScheduled = false;
  // Synchronous in-flight guard: the `_subscription != null` check alone leaves
  // a window (during the awaits, before listen()) where a re-entrant connect()
  // could close the client the first connect() is still awaiting.
  bool _connecting = false;
  Duration _reconnectDelay = const Duration(seconds: 1);

  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  /// Public stream — every `vehicle` event the server pushes is decoded
  /// from JSON and yielded here. Consumers `listen()` and update state.
  Stream<SseEvent> get stream => _controller.stream;

  /// Open the connection. Idempotent — calling again while already
  /// connected is a no-op.
  Future<void> connect() async {
    if (_stopped) return;
    if (_subscription != null) return;
    if (_reconnectScheduled) return; // a reconnect is already pending
    if (_connecting) return; // a connect() is already in flight
    _connecting = true;

    try {
      // Defensively close any half-open client before opening a new one.
      _client?.close(force: true);
      _client = HttpClient();
      final uri = Uri.parse('${AppUrl.liveStreamUrl}?user_id=$userId');
      final request = await _client!.getUrl(uri);
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      final response = await request.close();

      if (response.statusCode != 200) {
        _scheduleReconnect();
        return;
      }

      // Reset backoff on successful connect.
      _reconnectDelay = const Duration(seconds: 1);

      // SSE delivers events as text frames separated by blank lines. Each
      // frame has lines of the form `event: <name>` and `data: <body>`.
      String pendingEvent = '';
      final pendingData = StringBuffer();

      _subscription = response.listen(
        (chunk) {
          final text = utf8.decode(chunk, allowMalformed: true);
          for (final line in text.split('\n')) {
            final trimmed = line.trimRight();
            if (trimmed.isEmpty) {
              // Frame boundary — dispatch if we collected anything.
              if (pendingData.isNotEmpty) {
                _emit(pendingEvent, pendingData.toString());
              }
              pendingEvent = '';
              pendingData.clear();
              continue;
            }
            if (trimmed.startsWith(':')) {
              // SSE comment / keep-alive ping. Ignore.
              continue;
            }
            if (trimmed.startsWith('event:')) {
              pendingEvent = trimmed.substring(6).trim();
            } else if (trimmed.startsWith('data:')) {
              if (pendingData.isNotEmpty) pendingData.write('\n');
              pendingData.write(trimmed.substring(5).trim());
            }
          }
        },
        onError: (Object error) {
          if (kDebugMode) {
            // Only print errors in debug builds — in production these are
            // expected during network changes and would just spam logs.
            // ignore: avoid_print
            print('SSE stream error: $error');
          }
          _scheduleReconnect();
        },
        onDone: () {
          _subscription = null;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _emit(String event, String dataJson) {
    if (event.isEmpty || dataJson.isEmpty) return;
    try {
      final decoded = jsonDecode(dataJson);
      if (decoded is Map<String, dynamic>) {
        _controller.add(SseEvent(event: event, data: decoded));
      }
    } catch (_) {
      // Server occasionally sends `hello` keep-alives etc. — ignore parse
      // failures rather than crashing the stream.
    }
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    if (_reconnectScheduled) return; // one reconnect already pending
    _reconnectScheduled = true;
    _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;

    final delay = _reconnectDelay;
    _reconnectDelay = Duration(
      milliseconds:
          (_reconnectDelay.inMilliseconds * 2).clamp(1000, _maxReconnectDelay.inMilliseconds),
    );
    Future<void>.delayed(delay, () {
      _reconnectScheduled = false;
      if (!_stopped) connect();
    });
  }

  /// Tear down. Call from State.dispose() or when user logs out.
  Future<void> close() async {
    _stopped = true;
    await _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
    await _controller.close();
  }
}
