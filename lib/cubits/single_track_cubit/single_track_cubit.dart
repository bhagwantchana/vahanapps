import 'package:fleet_monitor/cubits/single_track_cubit/single_track_state.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/models/vehicle_settings_model.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SingleTrackCubit extends Cubit<SingleTrackState> {
  SingleTrackCubit() : super(SingleTrackInitialState());

  final SingleTrackRepository _repository = SingleTrackRepository();

  Future<void> fetchVehicleTrack(String imei) async {
    emit(SingleTrackLoadingState(singleTrackModel: state.singleTrackModel));
    try {
      final result = await _repository.fetchVehicleTrack(imei);
      emit(SingleTrackLoggedInState(singleTrackModel: result));
    } catch (error) {
      emit(
        SingleTrackErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          singleTrackModel: state.singleTrackModel,
        ),
      );
    }
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
      emit(
        SingleTrackErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          singleTrackModel: state.singleTrackModel,
        ),
      );
      return false;
    }
  }
}
