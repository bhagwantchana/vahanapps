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
  VehicleLoggedInState({super.vechileListModel});
}

class VehicleLoggedOutState extends VehicleState {}

class VehicleErrorState extends VehicleState {
  final String message;
  VehicleErrorState(this.message);
}
