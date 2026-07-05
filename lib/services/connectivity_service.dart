import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// App-wide internet-reachability state — package-free (no `connectivity_plus`).
///
/// Design goals:
///  • No constant polling while online. The network layer calls
///    [reportPossibleConnectionError] when a request fails with a connection
///    error; we then run a real DNS reachability probe before declaring the app
///    offline. A single failed request (server 5xx, one-off timeout) therefore
///    can NOT flash the offline screen — only an actual loss of connectivity.
///  • Auto-recovery: while offline a short timer re-probes every few seconds and
///    flips back to online (and stops polling) the moment the network returns.
///  • On app resume we re-probe once.
///
/// [isOnline] drives the global "No internet" overlay (see
/// `widgets/no_internet_overlay.dart`, wired in `main.dart`). It starts
/// optimistic (`true`) so a healthy launch never flashes the offline screen.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Timer? _recoveryTimer;
  bool _checking = false;
  bool _initialized = false;

  /// Call once during app bootstrap (after the Flutter binding is ready).
  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_verify());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_verify());
    }
  }

  /// Called from the network layer when a request fails with a connection-type
  /// error. We verify actual reachability before declaring the app offline.
  void reportPossibleConnectionError() => unawaited(_verify());

  /// Manual retry from the No-Internet screen.
  Future<void> retry() => _verify();

  Future<bool> _probe() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verify() async {
    if (_checking) return;
    _checking = true;
    try {
      final online = await _probe();
      if (isOnline.value != online) isOnline.value = online;
      if (online) {
        _recoveryTimer?.cancel();
        _recoveryTimer = null;
      } else {
        _recoveryTimer ??= Timer.periodic(
          const Duration(seconds: 4),
          (_) => unawaited(_verify()),
        );
      }
    } finally {
      _checking = false;
    }
  }
}
