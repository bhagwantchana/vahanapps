import 'dart:async';

import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/models/vechile_list_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/repositorys/vehicle_repository.dart';
import 'package:fleet_monitor/services/offline_cache.dart';
import 'package:fleet_monitor/services/sse_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VehicleCubit extends Cubit<VehicleState> {
  VehicleCubit() : super(VehicleInitialState());

  final VehicleRepository _vehicleRepository = VehicleRepository();

  // Server-Sent Events client. Connects to the tracking server's
  // /live/stream?user_id=N once we know the user — every device packet that
  // arrives at the tracking server is broadcast to the dashboard within
  // milliseconds, so the multi-vehicle list / map refresh without the user
  // pulling-to-refresh or waiting for the 60-second polling cycle. This is
  // the smooth UX the owner wanted (Uber/Zepto-style live updates).
  SseClient? _sseClient;
  StreamSubscription<SseEvent>? _sseSubscription;

  /// Same protection the single-vehicle screen has: a list poll refreshes
  /// everything, but a record whose fix is OLDER than the one already on
  /// screen must not drag its marker backwards — the response raced a
  /// fresher SSE push, or a clock-distrusted device's server row stepped
  /// back on an interleaved backfill. Fresh payload wins for every field
  /// EXCEPT the live fix; the newest position always stays.
  VehicleListModel _keepNewestFixes(VehicleListModel fresh) {
    final current = state.vechileListModel?.data;
    if (current == null || current.isEmpty || fresh.data.isEmpty) {
      return fresh;
    }
    final byId = <int, VehicleRecord>{for (final v in current) v.id: v};
    var changed = false;
    final merged = fresh.data.map((incoming) {
      final old = byId[incoming.id];
      if (old == null || old.acceptsLiveFixFrom(incoming)) return incoming;
      changed = true;
      return incoming.withLiveFieldsFrom(old);
    }).toList();
    if (!changed) return fresh;
    return VehicleListModel(
      flag: fresh.flag,
      count: fresh.count,
      message: fresh.message,
      data: merged,
      sseSig: fresh.sseSig,
    );
  }

  Future<void> fetchVehicles() async {
    emit(VehicleLoadingState(vechileListModel: state.vechileListModel));

    // COLD-START PAINT. The disk cache used to be consulted only when the
    // network FAILED, which meant every app open stared at a spinner for as
    // long as the request took - on morning cell coverage, seconds. The last
    // known fleet is on disk right now and is exactly what the map showed
    // when the app was last closed, so paint it immediately, flagged with
    // its age; the fresh answer replaces it the moment it lands, and
    // _keepNewestFixes already guarantees the swap can't step any marker
    // backwards.
    if (state.vechileListModel == null) {
      final cached = await OfflineCache.readVehicleList();
      if (cached != null && !isClosed && state.vechileListModel == null) {
        try {
          emit(VehicleLoggedInState(
            vechileListModel: VehicleListModel.fromJson(cached),
            cachedAge: await OfflineCache.vehicleListAge() ?? Duration.zero,
          ));
        } catch (_) {
          // A corrupt cache row must never block the real fetch below.
        }
      }
    }

    try {
      final result = await _vehicleRepository.fetchVehicles();
      if (isClosed) return;
      emit(VehicleLoggedInState(vechileListModel: _keepNewestFixes(result)));
      _ensureLiveStream(result);
    } on CachedFleetException catch (cached) {
      // Network is down but we have a last-good fleet. Show it, flagged as
      // stale — an empty error page reads as "tracking is broken" when the
      // truth is that the phone lost signal for a moment.
      if (isClosed) return;
      emit(VehicleLoggedInState(
        vechileListModel: cached.model,
        cachedAge: cached.age ?? Duration.zero,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(
        VehicleErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          vechileListModel: state.vechileListModel,
        ),
      );
    }
  }

  /// Open the SSE channel once we know the user_id (derived from the first
  /// vehicle row). Idempotent — only the first call actually connects.
  void _ensureLiveStream(VehicleListModel result) {
    if (_sseClient != null) return;
    if (result.data.isEmpty) return;
    final userId = result.data.first.userId;
    if (userId <= 0) return;

    // sig: server-computed HMAC (empty while GPS_SSE_SECRET is unarmed).
    // Same pattern as single_track_cubit — without it the stream answers 403
    // the day the secret deploys and every fielded binary loses live updates.
    _sseClient = SseClient(userId: userId, sig: result.sseSig);
    _sseSubscription = _sseClient!.stream.listen(_onSseEvent);
    _sseClient!.connect();
  }

  void _onSseEvent(SseEvent event) {
    // Tracking server pushes a `vehicle` event after every packet upsert —
    // payload is the same shape as one row of the /vehicleList response.
    if (event.event != 'vehicle') return;
    _applyVehicleUpdate(event.data);
  }

  void _applyVehicleUpdate(Map<String, dynamic> payload) {
    // SSE can deliver an event in the window between close() cancelling the
    // subscription and the cancel completing — guard against emit-after-close.
    if (isClosed) return;
    final current = state.vechileListModel;
    if (current == null) return;

    final VehicleRecord incoming;
    try {
      incoming = VehicleRecord.fromJson(payload);
    } catch (_) {
      return;
    }
    if (incoming.id <= 0) return;

    var matched = false;
    final updatedList = <VehicleRecord>[
      for (final v in current.data)
        if (v.id == incoming.id)
          () {
            matched = true;
            // Preserve list-only fields the SSE payload may not include
            // (legacyMultiMapUrl etc.) by merging via copyWith — coords /
            // speed / acc come fresh from the wire.
            return v.mergeLiveFixFrom(incoming);
          }()
        else
          v,
    ];
    if (!matched) {
      // Unknown vehicle in feed — likely a freshly added device on the
      // server. Skip silently; the next polling cycle picks it up.
      return;
    }

    emit(VehicleLoggedInState(
      vechileListModel: VehicleListModel(
        flag: current.flag,
        count: current.count,
        message: current.message,
        data: updatedList,
        sseSig: current.sseSig,
      ),
    ));
  }

  /// Tear down the SSE subscription. Called from the app's auth-clear flow
  /// (logout) so we don't keep streaming for the old user after a logout.
  Future<void> stopLiveStream() async {
    await _sseSubscription?.cancel();
    _sseSubscription = null;
    await _sseClient?.close();
    _sseClient = null;
  }

  /// Full logout teardown: stop the stream AND clear state, so the next user
  /// never sees the previous user's vehicles on first paint (this cubit is
  /// root-scoped and not recreated between logins).
  Future<void> reset() async {
    await stopLiveStream();
    // The offline copy has to go too, or the next user's first paint could be
    // served the previous user's fleet from disk.
    await OfflineCache.clear();
    emit(VehicleInitialState());
  }

  @override
  Future<void> close() async {
    await stopLiveStream();
    return super.close();
  }
}
