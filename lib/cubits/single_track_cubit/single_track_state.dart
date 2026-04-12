import 'package:fleet_monitor/models/single_track_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';

abstract class SingleTrackState {
  final SingleTrackModel? singleTrackModel;

  const SingleTrackState({this.singleTrackModel});
}

class SingleTrackInitialState extends SingleTrackState {}

class SingleTrackLoadingState extends SingleTrackState {
  const SingleTrackLoadingState({super.singleTrackModel});
}

class SingleTrackLoggedInState extends SingleTrackState {
  const SingleTrackLoggedInState({super.singleTrackModel});
}

class SingleTrackLoggedOutState extends SingleTrackState {}

class SingleTrackErrorState extends SingleTrackState {
  final String message;

  const SingleTrackErrorState(this.message, {super.singleTrackModel});
}

class SingleTrackStateHelpers {
  static SingleTrackModel wrapVehicle(VehicleRecord vehicle) {
    return SingleTrackModel(flag: 1, data: vehicle);
  }
}
