import 'package:fleet_monitor/models/vechile_list_model.dart';

abstract class HomeState {
  final VehicleListModel? vechileListModel;
  HomeState({this.vechileListModel});
}

class HomeInitialState extends HomeState {}

class HomeLoadingState extends HomeState {
  HomeLoadingState({super.vechileListModel});
}

class HomeLoggedInState extends HomeState {
  HomeLoggedInState({super.vechileListModel});
}

class HomeLoggedOutState extends HomeState {}

class HomeErrorState extends HomeState {
  final String message;
  HomeErrorState(this.message);
}
