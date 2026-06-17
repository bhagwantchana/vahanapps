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

  Future<void> fetchVehicleTrack(String imei) async {
    _trackedImei = imei;
    emit(SingleTrackLoadingState(singleTrackModel: state.singleTrackModel));
    try {
      final result = await _repository.fetchVehicleTrack(imei);
      if (isClosed) return;
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

  void _ensureLiveStream(VehicleRecord? vehicle) {
    if (_sseClient != null) return;
    final userId = vehicle?.userId ?? 0;
    if (userId <= 0) return;
    _sseClient = SseClient(userId: userId);
    _sseSub = _sseClient!.stream.listen(_onSseEvent);
    _sseClient!.connect();
  }

  void _onSseEvent(SseEvent event) {
    if (event.event != 'vehicle') return;
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
      satellites: incoming.satellites,
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

  @override
  Future<void> close() async {
    await _sseSub?.cancel();
    await _sseClient?.close();
    return super.close();
  }
}
