import 'dart:async';

import 'package:fleet_monitor/cubits/single_track_cubit/single_track_state.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/models/vehicle_settings_model.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:fleet_monitor/services/sse_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SingleTrackCubit extends Cubit<SingleTrackState> {
  SingleTrackCubit() : super(SingleTrackInitialState());

  final SingleTrackRepository _repository = SingleTrackRepository();

  // Live push: the detail screen subscribes to the same /live/stream SSE the
  // tracking server pushes after every GPS upsert, filtered to the IMEI being
  // viewed. This feeds fresh coords into the map so its eased-glide animation
  // keeps running while the vehicle drives — no polling, no refresh, no flicker.
  SseClient? _sseClient;
  StreamSubscription<SseEvent>? _sseSub;
  String? _trackedImei;
  // Wall-clock of the last LIVE data (SSE event or silent poll success).
  // The detail screen's fallback poll uses this to skip ticks while the SSE
  // push channel is healthy — poll only fills gaps, never duplicates.
  DateTime? _lastLiveAt;

  Future<void> fetchVehicleTrack(String imei) async {
    _trackedImei = imei;
    emit(SingleTrackLoadingState(singleTrackModel: state.singleTrackModel));
    try {
      final result = await _repository.fetchVehicleTrack(imei);
      if (isClosed) return;
      // This IS live data — stamp it so the screen's fallback poll doesn't
      // immediately refetch on its first tick right after this load.
      _lastLiveAt = DateTime.now();
      emit(SingleTrackLoggedInState(singleTrackModel: result));
      _ensureLiveStream(result.data);
    } catch (error) {
      if (isClosed) return;
      emit(
        SingleTrackErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          singleTrackModel: state.singleTrackModel,
        ),
      );
    }
  }

  /// Fallback refresh for the native map: re-fetches the vehicle WITHOUT a
  /// Loading emission (no spinner/blank) so the marker glide is never
  /// interrupted. Skipped while SSE is delivering (fresh within [staleAfter]).
  /// Called on a screen-owned timer — the cubit itself never self-polls.
  Future<void> silentRefreshIfStale({Duration staleAfter = const Duration(seconds: 4)}) async {
    final imei = _trackedImei;
    if (imei == null || imei.isEmpty || isClosed) return;
    final last = _lastLiveAt;
    if (last != null && DateTime.now().difference(last) < staleAfter) return;
    try {
      final result = await _repository.fetchVehicleTrack(imei);
      if (isClosed || _trackedImei != imei) return;
      _lastLiveAt = DateTime.now();
      emit(SingleTrackLoggedInState(singleTrackModel: result));
      _ensureLiveStream(result.data);
    } catch (_) {
      // Silent by design — the next tick or SSE reconnect will recover.
    }
  }

  void _ensureLiveStream(VehicleRecord? vehicle) {
    if (_sseClient != null) {
      // Client exists but may be sitting in a backed-off reconnect wait
      // (app was backgrounded, network dropped). An app-resume lands here
      // via silentRefreshIfStale -> revive the stream within ~1 s instead
      // of waiting out the up-to-30 s backoff. No-op while connected.
      _sseClient!.kick();
      return;
    }
    final userId = vehicle?.userId ?? 0;
    if (userId <= 0) return;
    // sig: server-computed HMAC (armed GPS_SSE_SECRET) from the settings
    // payload — without it the hardened stream rejects the subscription.
    _sseClient = SseClient(userId: userId, sig: vehicle?.settings?.sseSig ?? '');
    _sseSub = _sseClient!.stream.listen(_onSseEvent);
    _sseClient!.connect();
  }

  void _onSseEvent(SseEvent event) {
    if (event.event != 'vehicle') return;
    _lastLiveAt = DateTime.now();
    _applyLiveUpdate(event.data);
  }

  void _applyLiveUpdate(Map<String, dynamic> payload) {
    if (isClosed) return;
    final model = state.singleTrackModel;
    final current = model?.data;
    if (current == null) return;

    VehicleRecord incoming;
    try {
      incoming = VehicleRecord.fromJson(payload);
    } catch (_) {
      return;
    }
    // Only apply the push for the vehicle currently on screen.
    final wantImei = _trackedImei ?? current.imei;
    if (incoming.imei.isEmpty || incoming.imei != wantImei) return;

    final merged = current.copyWith(
      latitude: incoming.latitude,
      longitude: incoming.longitude,
      speed: incoming.speed,
      course: incoming.course,
      acc: incoming.acc,
      battery: incoming.battery,
      gsmSignal: incoming.gsmSignal,
      // SSE pushes omit satellites → keep the prior GPS-lock count instead of
      // letting a default 0 wipe it.
      satellites: incoming.satellites > 0 ? incoming.satellites : current.satellites,
      createdAt: incoming.createdAt,
      hasLiveLocation: true,
    );

    // Emit LoggedIn (NOT Loading) so the map updates in place and glides —
    // never a spinner/blank that would read as a refresh.
    emit(SingleTrackLoggedInState(singleTrackModel: model!.copyWith(data: merged)));
  }

  Future<bool> updateVehicleSettings({
    required VehicleRecord vehicle,
    required VehicleSettingsModel settings,
  }) async {
    emit(SingleTrackLoadingState(singleTrackModel: state.singleTrackModel));
    try {
      final updatedSettings = await _repository.updateVehicleSettings(
        settings.toUpdatePayload(
          fallbackLat: vehicle.latitude,
          fallbackLng: vehicle.longitude,
        ),
      );
      if (isClosed) return false;

      final refreshedVehicle = vehicle.copyWith(
        settings: updatedSettings,
        notificationEnabled: updatedSettings.notificationEnabled,
        overspeedLimit: updatedSettings.overspeedLimit,
        geofenceRadius: updatedSettings.geofenceRadius,
        geofenceLat: updatedSettings.geofenceLat,
        geofenceLng: updatedSettings.geofenceLng,
        guardActive: updatedSettings.guardActive,
        guardLat: updatedSettings.guardLat,
        guardLng: updatedSettings.guardLng,
        parkingGuard: updatedSettings.parkingGuard,
      );

      emit(
        SingleTrackLoggedInState(
          singleTrackModel:
              state.singleTrackModel?.copyWith(data: refreshedVehicle) ??
              SingleTrackStateHelpers.wrapVehicle(refreshedVehicle),
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        SingleTrackErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          singleTrackModel: state.singleTrackModel,
        ),
      );
      return false;
    }
  }

  Future<bool> sendEngineCommand({
    required VehicleRecord vehicle,
    required String action,
  }) async {
    emit(SingleTrackLoadingState(singleTrackModel: state.singleTrackModel));
    try {
      final updatedSettings = await _repository.sendEngineCommand(
        vehicleId: vehicle.id,
        imei: vehicle.imei,
        action: action,
      );
      if (isClosed) return false;

      final refreshedVehicle = vehicle.copyWith(
        settings: updatedSettings,
        immobilizerState: updatedSettings.immobilizerState,
        immobilizerUpdatedAt: updatedSettings.immobilizerUpdatedAt,
        nightLockEnabled: updatedSettings.nightLockEnabled,
        nightLockStart: updatedSettings.nightLockStart,
        nightLockEnd: updatedSettings.nightLockEnd,
        nightLockTimezone: updatedSettings.nightLockTimezone,
      );

      emit(
        SingleTrackLoggedInState(
          singleTrackModel:
              state.singleTrackModel?.copyWith(data: refreshedVehicle) ??
              SingleTrackStateHelpers.wrapVehicle(refreshedVehicle),
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        SingleTrackErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          singleTrackModel: state.singleTrackModel,
        ),
      );
      return false;
    }
  }

  /// Tear down the live stream + tracked-vehicle state. Called on logout so we
  /// don't keep streaming the previous user's vehicle, and so the next
  /// fetchVehicleTrack re-connects cleanly for the new user (the _sseClient
  /// null-guard would otherwise block reconnection until an app restart).
  Future<void> stopLiveStream() async {
    await _sseSub?.cancel();
    _sseSub = null;
    await _sseClient?.close();
    _sseClient = null;
    _trackedImei = null;
    _lastLiveAt = null;
  }

  /// Full logout teardown: stop the stream AND clear tracked state.
  Future<void> reset() async {
    await stopLiveStream();
    emit(SingleTrackInitialState());
  }

  @override
  Future<void> close() async {
    await stopLiveStream();
    return super.close();
  }
}
