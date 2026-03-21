import 'package:fleet_monitor/models/dashboard_model.dart';

abstract class HomeState {
  final DashboardModel? dashboardModel;
  HomeState({this.dashboardModel});
}

class HomeInitialState extends HomeState {}

class HomeLoadingState extends HomeState {
  HomeLoadingState({super.dashboardModel});
}

class HomeLoggedInState extends HomeState {
  HomeLoggedInState({super.dashboardModel});
}

class HomeLoggedOutState extends HomeState {}

class HomeErrorState extends HomeState {
  final String message;
  HomeErrorState(this.message);
}
