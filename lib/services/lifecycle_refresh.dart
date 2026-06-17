import 'dart:async';

import 'package:flutter/material.dart';

/// Lifecycle-aware data refresh helper. Lets a screen:
///
/// - Auto-refresh on **app resume** from background (so the user lands on
///   fresh data instead of whatever was on screen 10 minutes ago).
/// - Optionally **poll** at a fixed interval while the app is in foreground.
/// - **Cancel** the poll timer when the app pauses, so we don't waste
///   network and battery while the user isn't looking. A 30 s poll left
///   running through an overnight 8 hour sleep would be ~960 useless
///   requests otherwise.
///
/// Usage from inside `State.initState()`:
/// ```dart
/// late final LifecycleRefresh _lifecycle = LifecycleRefresh(
///   onRefresh: () async {
///     if (!mounted) return;
///     await context.read<VehicleCubit>().fetchVehicles();
///   },
///   interval: const Duration(seconds: 30),
/// )..start();
/// ```
/// Remember to `dispose()` it from `State.dispose()`.
class LifecycleRefresh extends WidgetsBindingObserver {
  LifecycleRefresh({
    required this.onRefresh,
    this.interval = const Duration(seconds: 30),
  });

  final Future<void> Function() onRefresh;
  final Duration interval;

  Timer? _timer;
  bool _started = false;
  bool _refreshing = false;

  /// Runs [onRefresh] but skips if a previous run hasn't finished yet — on a
  /// slow network the async refresh can take longer than the poll interval,
  /// and overlapping ticks would stack duplicate network + geofence work.
  Future<void> _runRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await onRefresh();
    } finally {
      _refreshing = false;
    }
  }

  /// Begin observing the app lifecycle and (if interval > 0) start the
  /// foreground polling timer.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  /// Stop observing + cancel the timer. Idempotent.
  void dispose() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
  }

  void _startTimer() {
    _cancelTimer();
    if (interval <= Duration.zero) return;
    _timer = Timer.periodic(interval, (_) => _runRefresh());
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Immediate refresh on return-to-foreground so the user doesn't
        // wait for the next interval tick to see fresh data.
        _runRefresh();
        _startTimer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        _cancelTimer();
        break;
    }
  }
}
