import 'package:fleet_monitor/models/single_track_model.dart';

abstract class SingleTrackState {
  final SingleTrackModel? singleTrackModel;
  SingleTrackState({this.singleTrackModel});
}

class SingleTrackInitialState extends SingleTrackState {}

class SingleTrackLoadingState extends SingleTrackState {
  SingleTrackLoadingState({super.singleTrackModel});
}

class SingleTrackLoggedInState extends SingleTrackState {
  SingleTrackLoggedInState({super.singleTrackModel});
}

class SingleTrackLoggedOutState extends SingleTrackState {}

class SingleTrackErrorState extends SingleTrackState {
  final String message;
  SingleTrackErrorState(this.message);
}
