import 'dart:async';

import 'package:fleet_monitor/cubits/single_track_cubit/single_track_state.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SingleTrackCubit extends Cubit<SingleTrackState> {
  final VehicleCubit _vehicleCubit;
  StreamSubscription? _vehicleSubscription;
  final SingleTrackRepository _repository = SingleTrackRepository();

  SingleTrackCubit(this._vehicleCubit) : super(SingleTrackInitialState()) {
    _vehicleSubscription = _vehicleCubit.stream.listen((vehicleState) {});
  }
  Future<void> fetchVehicleTrack(String imei) async {
    emit(SingleTrackLoadingState());
    try {
      final result = await _repository.vehicleListFetch(imei);
      emit(SingleTrackLoggedInState(singleTrackModel: result));
    } catch (e) {
      emit(SingleTrackErrorState(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _vehicleSubscription?.cancel();
    return super.close();
  }
}
