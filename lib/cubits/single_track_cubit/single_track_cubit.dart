import 'dart:async';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_state.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SingleTrackCubit extends Cubit<SingleTrackState> {
  final SingleTrackRepository _repository = SingleTrackRepository();

  SingleTrackCubit() : super(SingleTrackInitialState());

  Future<void> fetchVehicleTrack(String imei) async {
    emit(SingleTrackLoadingState());
    try {
      final result = await _repository.vehicleListFetch(imei);
      emit(SingleTrackLoggedInState(singleTrackModel: result));
    } catch (e) {
      emit(SingleTrackErrorState(e.toString()));
    }
  }
}
