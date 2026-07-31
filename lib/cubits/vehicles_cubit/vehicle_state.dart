import 'package:fleet_monitor/models/vechile_list_model.dart';

abstract class VehicleState {
  final VehicleListModel? vechileListModel;
  VehicleState({this.vechileListModel});
}

class VehicleInitialState extends VehicleState {}

class VehicleLoadingState extends VehicleState {
  VehicleLoadingState({super.vechileListModel});
}

class VehicleLoggedInState extends VehicleState {
  VehicleLoggedInState({super.vechileListModel, this.cachedAge});

  /// Set when this list came from the offline cache because the network was
  /// unreachable — the age of that cached copy. Null on a live fetch. Screens
  /// use it to say the data is stale instead of passing it off as live.
  final Duration? cachedAge;

  bool get isFromCache => cachedAge != null;
}

class VehicleLoggedOutState extends VehicleState {}

class VehicleErrorState extends VehicleState {
  final String message;
  VehicleErrorState(this.message, {super.vechileListModel});
}
